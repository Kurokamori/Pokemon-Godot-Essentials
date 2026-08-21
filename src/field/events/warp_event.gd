@tool
class_name WarpEvent
extends MapEvent
## A doorway, a staircase, or the edge of a route: standing on it sends the player somewhere else.

## The scene to send the player to. 
## Takes priority over [member target_map_id]
@export var target_map: PackedScene = null

## Map number to send the player to, used when [member target_map] is empty
@export var target_map_id: int = 0

## Name of the [SpawnPoint] on the destination map to arrive at.
@export var target_spawn: StringName = &""

## Exact cell to arrive at
## `(-1, -1)` leaves the choice to [member target_spawn].
@export var target_cell: Vector2i = Vector2i(-1, -1)

## Which way the player faces on arrival. `0` uses the spawn point's own facing.
@export_enum("Keep:0", "Down:2", "Left:4", "Right:6", "Up:8") var arrival_facing: int = 0

@export_group("Presentation")
## Whether it fades through black rather than cutting straight over
@export var fade: bool = true

## Sound effect played as the player leaves, e.g. `Door enter`.
@export var sound: String = ""

@export_group("Walks")
## The step the player takes into this warp before it fire
@export_enum("Auto:0", "None:-1", "Down:2", "Left:4", "Right:6", "Up:8") var departure_walk: int = 0

## How many cells that walk covers, when [member departure_walk] names a direction
@export_range(1, 8) var departure_steps: int = 1

## The step the player takes on arriving at the other end.
## `Auto` lets the destination decide.
@export_enum("Auto:0", "None:-1", "Down:2", "Left:4", "Right:6", "Up:8") var arrival_walk: int = 0

@export_group("Activation")
## Whether this event fires when the player steps on it
@export var on_touch: bool = true


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	passable = on_touch

func active_trigger() -> EventPage.Trigger:
	return EventPage.Trigger.PLAYER_TOUCH if on_touch else EventPage.Trigger.ACTION_BUTTON

func has_action() -> bool:
	return is_active() and (target_map != null or target_map_id > 0)

func run() -> void:
	if map == null:
		return
	await _walk_in()
	if target_map != null:
		await map.warp_to_scene(target_map, target_spawn, target_cell, arrival_facing, fade, arrival_walk)
		return
	if target_map_id <= 0:
		push_error("WarpEvent '%s' has no destination." % display_name())
		return
	var scene: PackedScene = MapIndex.get_index().load_map(target_map_id)
	if scene == null:
		return
	await map.warp_to_scene(scene, target_spawn, target_cell, arrival_facing, fade, arrival_walk)

## Walks the player into the warp before it takes them anywhere
func _walk_in() -> void:
	var player: PlayerCharacter = map.player
	var door: MapEvent = Door.at(map, tile_position)
	var steps: Array[int] = _departure_steps(player)
	if steps.is_empty():
		if not sound.is_empty():
			AudioManager.play_se(sound)
		return
	if door != null:
		await Door.open(door, sound if not sound.is_empty() else Door.OPEN_SOUND)
	elif not sound.is_empty():
		AudioManager.play_se(sound)
	for direction: int in steps:
		await player.force_step(direction as GridCharacter.Direction)
	await Door.close(door)

## The steps that lead the player into this warp: one per cell
func _departure_steps(player: PlayerCharacter) -> Array[int]:
	if player == null:
		return []
	if departure_walk < 0:
		return []
	if departure_walk > 0:
		var named: Array[int] = []
		for index: int in range(maxi(departure_steps, 1)):
			named.append(departure_walk)
		return named
	var offset: Vector2i = tile_position - player.tile_position
	if offset == Vector2i.ZERO:
		return []
	var walked: Array[int] = []
	var horizontal: int = GridCharacter.Direction.RIGHT if offset.x > 0 else GridCharacter.Direction.LEFT
	for index: int in range(absi(offset.x)):
		walked.append(horizontal)
	var vertical: int = GridCharacter.Direction.DOWN if offset.y > 0 else GridCharacter.Direction.UP
	for index: int in range(absi(offset.y)):
		walked.append(vertical)
	return walked

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super._get_configuration_warnings()
	if target_map == null and target_map_id <= 0:
		warnings.append("This warp has no destination. Set Target Map, or Target Map Id for an imported warp.")
	if target_map == null and target_map_id > 0 and String(target_spawn).is_empty() and target_cell.x < 0:
		warnings.append("This warp names a map number but no spawn point or cell, so the destination is a guess.")
	return warnings
