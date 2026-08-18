@tool
class_name PlayerCharacter
extends GridCharacter
## The player's overworld character

enum Pose {
	NORMAL = 0,
	RUNNING = 1,
	FISHING = 2,
}

signal interacted_with(event: MapEvent)

## Default seconds per tile at each movement speed
const DEFAULT_WALK_SECONDS: float = 0.25
const DEFAULT_RUN_SECONDS: float = 0.14
const DEFAULT_CYCLE_SECONDS: float = 0.10

const SCENE_PATH: String = "res://scenes/field/player_character.tscn"

## Set to `false` while a cutscene or menu owns the input
var accepts_input: bool = true

@onready var _camera: Camera2D = %MapCamera
@onready var _surf_base: SurfBase = %SurfBase

var _turn_delay: float = 0.0

var _consume_accept: bool = false

var _pose: Pose = Pose.NORMAL


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	seconds_per_tile = walk_seconds()
	refresh_charset()

## Seconds the player takes to cross one tile, walking
static func walk_seconds() -> float:
	return _speed_or(GameSettings.data.walk_frames_per_tile, DEFAULT_WALK_SECONDS)

## Seconds the player takes to cross one tile, running
static func run_seconds() -> float:
	return _speed_or(GameSettings.data.run_frames_per_tile, DEFAULT_RUN_SECONDS)

## Seconds the player takes to cross one tile, cycling
static func cycle_seconds() -> float:
	return _speed_or(GameSettings.data.cycle_frames_per_tile, DEFAULT_CYCLE_SECONDS)

func camera() -> Camera2D:
	return _camera

## Input is read before the walk cycle is advanced
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_read_input(delta)
	super._process(delta)
	if not Engine.is_editor_hint():
		_ride_the_bob()

## Puts the player into [param pose] and redraws them.
func set_pose(new_pose: Pose) -> void:
	if _pose == new_pose:
		return
	_pose = new_pose
	refresh_charset()

func pose() -> Pose:
	return _pose
	
func casts_dynamic_shadow() -> bool:
	return true

## Reloads the sprite from the player's metadata record, for wherever they are and whatever they are doing.
func refresh_charset() -> void:
	if GameState.player == null:
		return
	var metadata: PlayerMetadataData = Database.player_metadata(GameState.player.character_id)
	if metadata == null:
		return
	var wanted: String = _charset_for(metadata)
	if wanted != charset_name():
		set_charset(wanted)
	if _surf_base != null:
		_surf_base.refresh()

# === Internals ===

static func _speed_or(setting: float, fallback: float) -> float:
	return setting if setting > 0.0 else fallback
	
## Keeps the player in step with the thing they are riding on
func _ride_the_bob() -> void:
	if not _surf_base.visible:
		if sprite_lift != 0:
			sprite_lift = 0
		return
	if not lock_pattern:
		pattern = _surf_base.bob_frame()
	sprite_lift = _surf_base.bob_height()

func _read_input(delta: float) -> void:
	if _turn_delay > 0.0:
		_turn_delay -= delta
	if not accepts_input or (map != null and map.is_busy()):
		_consume_accept = true
		return
	if is_moving:
		return
	if _consume_accept:
		if Input.is_action_pressed("ui_accept"):
			return
		_consume_accept = false
	if Input.is_action_just_pressed("ui_accept"):
		_interact()
		return
	var direction: int = _read_direction()
	if direction == 0:
		return
	_update_speed()
	if facing != direction and _turn_delay <= 0.0 and not Input.is_action_pressed("game_run"):
		facing = direction as Direction
		_turn_delay = 0.06
		return
	_attempt_step(direction as Direction)

func _read_direction() -> int:
	if Input.is_action_pressed("ui_up"):
		return Direction.UP
	if Input.is_action_pressed("ui_down"):
		return Direction.DOWN
	if Input.is_action_pressed("ui_left"):
		return Direction.LEFT
	if Input.is_action_pressed("ui_right"):
		return Direction.RIGHT
	return 0

## Picks the speed this step is taken at
func _update_speed() -> void:
	if GameState.is_cycling():
		seconds_per_tile = cycle_seconds()
		return
	var can_run: bool = GameState.player != null and GameState.player.has_running_shoes
	var holding: bool = Input.is_action_pressed("game_run")
	var running: bool = can_run and (holding != GameSettings.data.run_by_default)
	seconds_per_tile = run_seconds() if running else walk_seconds()
	if _pose != Pose.FISHING:
		set_pose(Pose.RUNNING if running else Pose.NORMAL)

func _attempt_step(direction: Direction) -> void:
	turn(direction)
	var target: Vector2i = tile_position + Vector2i(DIRECTION_VECTORS[direction])
	if await _try_ledge(direction, target):
		return
	if not can_enter(target, direction):
		if _trigger_touch_events(target):
			return
		if await FieldMoves.offer_surf():
			return
		_bump()
		return
	await _move_to(target)

## Starts a touch event on [param cell] that the player cannot stand on.
## Returns `true` when one was started.
func _trigger_touch_events(cell: Vector2i) -> bool:
	if map == null or map.is_busy():
		return false
	for event: MapEvent in map.events_at(cell):
		var trigger: EventPage.Trigger = event.active_trigger()
		if trigger != EventPage.Trigger.PLAYER_TOUCH and trigger != EventPage.Trigger.EVENT_TOUCH:
			continue
		if event.is_over_trigger() or not event.has_action():
			continue
		map.run_event(event)
		return true
	return false

## Try jumping a ledge (confirm valid direction)
func _try_ledge(direction: Direction, target: Vector2i) -> bool:
	if map == null:
		return false
	var terrain: TerrainTagData = map.terrain_at(target)
	if terrain == null or not terrain.ledge:
		return false
	if direction != Direction.DOWN:
		return false
	AudioManager.play_se("Player jump")
	await jump(Vector2i(DIRECTION_VECTORS[direction]) * 2)
	return true

func _bump() -> void:
	AudioManager.play_se("Player bump")
	if GameState.stats != null:
		GameState.stats.bump_count += 1

## Presses the action button checked in the following order:
## Under player -> Next to Player -> Past Counter (if there's a counter)
func _interact() -> void:
	if map == null:
		return
	if _start_action_event(tile_position, true):
		return
	var ahead: Vector2i = tile_ahead()
	if _start_action_event(ahead, false):
		return
	if await _talk_to_follower(ahead):
		return
	if map.is_counter(ahead):
		if _start_action_event(tile_ahead(2), false):
			return
	var moves: HiddenMoves = HiddenMoves.for_field()
	if _facing_strength_boulder():
		await moves.offer_strength()
		return
	if await FieldMoves.offer_dive():
		return
	if await moves.offer_waterfall():
		return
	await FieldMoves.offer_surf()

## Talks to a follower standing on [param cell]. 
## Returns true if one existed and said something
func _talk_to_follower(cell: Vector2i) -> bool:
	if map == null or map.followers == null:
		return false
	var follower: FollowerCharacter = map.followers.at_cell(cell)
	if follower == null:
		return false
	accepts_input = false
	var spoke: bool = await follower.talk_to(self)
	accepts_input = true
	return spoke

## Returns `true` when the event in front of the player is one Strength effects
func _facing_strength_boulder() -> bool:
	if map == null:
		return false
	for event: MapEvent in map.events_at(tile_ahead()):
		if event.erased or not event.is_active():
			continue
		var label: String = event.display_name().to_lower().replace(" ", "")
		if label.contains(HiddenMoves.STRENGTH_BOULDER_MARKER):
			return true
	return false

## Runs an action-button event on [param cell]. 
## [param standing_on] selects which events count: 
## The one the player is standing on or the one the player is facing
func _start_action_event(cell: Vector2i, standing_on: bool) -> bool:
	for event: MapEvent in map.events_at(cell):
		if event.active_trigger() != EventPage.Trigger.ACTION_BUTTON:
			continue
		if not event.has_action():
			continue
		if event.is_over_trigger() != standing_on:
			continue
		if not standing_on:
			event.turn_towards(self)
		interacted_with.emit(event)
		map.run_event(event)
		return true
	return false

## Selects the correct sheet for the player, with fallbacks
func _charset_for(metadata: PlayerMetadataData) -> String:
	var on_water: bool = GameState.is_surfing() or GameState.is_diving()
	if _pose == Pose.FISHING:
		var casting: String = metadata.surf_fish_charset if on_water else metadata.fish_charset
		if not casting.is_empty():
			return casting
	match GameState.movement_state:
		GameState.MovementState.CYCLING:
			return metadata.cycle_charset
		GameState.MovementState.SURFING:
			return metadata.surf_charset
		GameState.MovementState.DIVING:
			var diving: String = metadata.dive_charset
			return diving if not diving.is_empty() else metadata.surf_charset
	if _pose == Pose.RUNNING and not metadata.run_charset.is_empty():
		return metadata.run_charset
	return metadata.walk_charset
