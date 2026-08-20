class_name MapController
extends Node2D

## Manages what map is loaded, the player standing on it, and anything that needs to survive a map change

## Emitted once a map scene is in place and its events are loaded
signal map_loaded(map: GameMap)

## Emitted when a map threshold with no warp or fade is crossed
signal map_crossed(map: GameMap)

## Emitted each time a player finishes a step
signal player_moved(cell: Vector2i)

## Emitted when a wild battle is about to begin.
signal encounter_triggered(wild: Array[Pokemon], encounter_type: StringName)


## Emitted for each line of dialogue
## Answered by message box's [method acknowledge_message]
signal message_requested(text: String)

## Emitted when a choice is offered
signal choices_requested(prompt: String, options: Array, cancel_index: int, default_index: int)

signal message_acknowledged()
signal choice_submitted()


## The field on which the game currently is
## For the [Field] helpers that scripted events use
static var current: MapController = null

@onready var _map_root: MapNeighbourhood = %MapRoot
@onready var _interpreter: EventInterpreter = %Interpreter
@onready var player: PlayerCharacter = %Player

var current_map: GameMap = null

## The line of characters walking behind the player
var followers: FollowerTrain = null

var pokemon_followers: PokemonFollowers = null

## The wild encounter tables of the map the player is on and its counters
var encounters: MapEncounters = MapEncounters.new()

## Guards against an autorun page that never ends
const AUTORUN_RESTART_LIMIT: int = 200

## Passed as a warp's arrival walk to let the destination decide what happens
const AUTO_WALK: int = 0

## Passed as a warp's arrival walk to leave the player standing where they land.
const NO_WALK: int = -1

var _running_event: MapEvent = null

## The direction the player is being carried in while they are on a waterfall,
## or `0` when they are not on one
var _waterfall_direction: int = 0

## Where the floor of a freshly generated random dungeon put the player
var _dungeon_entry: Vector2i = RandomDungeon.NOT_A_DUNGEON
var _transferring: bool = false
var _choice_result: int = -1
var _autorun_restarts: int = 0

## Common event numbers whose parallel run is in flight
var _parallel_common_events: Dictionary = {}
var _last_autorun: MapEvent = null
var _shadow_sources: Array[ShadowSource] = []
var _shadow_sources_are_current: bool = false

## How far the camera has been scrolled away from the player in pixels
var _scroll_offset: Vector2 = Vector2.ZERO

## How far the screen shake has the camera pushed sideways this frame
var _shake_offset: float = 0.0

var _scroll_tween: Tween = null


func _ready() -> void:
	current = self
	followers = FollowerTrain.new(self)
	pokemon_followers = PokemonFollowers.new(self, followers)
	pokemon_followers.attach()
	_interpreter.map = self
	player.map = self
	player.step_finished.connect(_on_player_step_finished)
	player.direction_changed.connect(_on_player_direction_changed)
	_map_root.map_added.connect(_on_map_added)
	_map_root.map_removed.connect(_on_map_removed)
	set_process(true)


func _exit_tree() -> void:
	if pokemon_followers != null:
		pokemon_followers.detach()
	if current == self:
		current = null


func _process(_delta: float) -> void:
	if current_map == null or is_busy():
		return
	_run_pending_autorun()
	_run_pending_parallels()
	_run_pending_common_events()


func interpreter() -> EventInterpreter:
	return _interpreter


# === Map Loading === 

## Loads the map scene [param scene] and puts the player on [param spawn]
func load_map(scene: PackedScene, spawn: Vector2i, facing: int = GridCharacter.Direction.DOWN) -> void:
	if scene == null:
		push_error("MapController: asked to load a map that does not exist.")
		return
	var instance: GameMap = scene.instantiate() as GameMap
	if instance == null:
		push_error("MapController: %s is not a map scene; its root needs the GameMap script." % scene.resource_path)
		return
	adopt_map(instance, spawn, facing)

## Loads the map registered under [param target_map_id]
func load_map_id(target_map_id: int, spawn: Vector2i, facing: int = GridCharacter.Direction.DOWN) -> void:
	var scene: PackedScene = MapIndex.get_index().load_map(target_map_id)
	if scene == null:
		return
	load_map(scene, spawn, facing)

## Puts an already-built map scene into the field
func adopt_map(map: GameMap, spawn: Vector2i, facing: int = GridCharacter.Direction.DOWN) -> void:
	_unload_current_map()
	_dungeon_entry = RandomDungeon.build(map)
	var arrival: Vector2i = _dungeon_entry if _dungeon_entry != RandomDungeon.NOT_A_DUNGEON else spawn
	current_map = map
	_map_root.set_anchor(map)

	_park_player_on(map, arrival, facing)
	player.refresh_charset()
	followers.put_on_player()
	if not GameState.followers_hidden:
		followers.reveal()
	pokemon_followers.refresh(true)

	GameState.set_map(map.map_id, arrival, facing)
	encounters.setup(map.encounter_table_id())

	if not GameState.is_diving():
		FieldMoves.release_surface_probe()
	_refresh_neighbourhood()

	reset_scroll()
	_update_camera_limits()
	_snap_camera()
	_start_map_audio()
	_autorun_restarts = 0
	_last_autorun = null
	map.map_ready.emit()
	map_loaded.emit(map)

## Hands every event on [param map] a way back to the field
func adopt_map_events(map: GameMap) -> void:
	for event: MapEvent in map.events():
		event.map = self
		event.refresh_page()

func map_id() -> int:
	return current_map.map_id if current_map != null else 0


# === Map ===

## [param cell], counted on [param map], said in world cells
func to_world_cell(map: GameMap, cell: Vector2i) -> Vector2i:
	return _map_root.to_world(map, cell)

## [param world_cell] in [param map]'s own cells
func to_map_cell(map: GameMap, world_cell: Vector2i) -> Vector2i:
	return _map_root.to_map(map, world_cell)

## The map [param world_cell] belongs to
## Returns `null` if there is no map there
func map_at_world(world_cell: Vector2i) -> GameMap:
	return _map_root.map_at(world_cell)

## Every map in the field, the one the player is on first
func loaded_maps() -> Array[GameMap]:
	return _map_root.maps()


# === Shadow Sources ====

## The lamps on every stitched map, which is what [DynamicShadows] casts from
func shadow_sources() -> Array[ShadowSource]:
	if _shadow_sources_are_current:
		return _shadow_sources
	_shadow_sources = ShadowSources.collect(_all_field_events())
	_shadow_sources_are_current = true
	return _shadow_sources

## Forgets the cached lamps, so the next character to ask finds them again
func invalidate_shadow_sources() -> void:
	_shadow_sources_are_current = false


# === Warping ===

## Moves the player to another map, fading through black
func warp_to_scene(scene: PackedScene, spawn_name: StringName = &"", cell: Vector2i = Vector2i(-1, -1),
		facing: int = 0, fade: bool = true, walk: int = AUTO_WALK) -> void:
	if scene == null:
		push_error("MapController: a warp has no destination scene.")
		return
	_transferring = true
	if fade:
		await SceneRouter.fade_out()
	load_map(scene, Vector2i.ZERO, facing if facing > 0 else int(player.facing))
	var spawn: SpawnPoint = _place_player(spawn_name, cell, facing)
	var door: MapEvent = Door.at(self, player.tile_position)
	var direction: int = _arrival_direction(spawn, walk, door)
	player.visible = direction <= 0 or door == null
	if fade:
		await SceneRouter.fade_in()
	await _walk_in(door, direction, _arrival_steps(spawn, walk))
	_transferring = false

## Moves the player to the map registered under [param map_id]
func warp_to_map_id(target_map_id: int, cell: Vector2i, facing: int = 0, fade: bool = true,
		walk: int = AUTO_WALK) -> void:
	var scene: PackedScene = MapIndex.get_index().load_map(target_map_id)
	if scene == null:
		return
	await warp_to_scene(scene, &"", cell, facing, fade, walk)

## Moves the player somewhere else on the map they are already on
func move_player_to(cell: Vector2i, facing: int = 0) -> void:
	player.tile_position = cell
	player.position = MapGrid.cell_to_pixel(cell)
	if facing > 0:
		player.facing = facing as GridCharacter.Direction
	GameState.set_map(map_id(), cell, int(player.facing))

# === Queries ===

## Returns `true` when [param character] may step from [param from] to [param to].
func is_passable(character: GridCharacter, from: Vector2i, to: Vector2i, direction: int) -> bool:
	if current_map == null:
		return true
	var home: GameMap = character.home_map if character != null and character.home_map != null else current_map
	return is_step_allowed(home, from, to, direction, character)

## Returns `true` when [param character] may step from [param from] to [param to], both counted on [param home].
func is_step_allowed(home: GameMap, from: Vector2i, to: Vector2i, direction: int,
		character: GridCharacter = null) -> bool:
	var from_world: Vector2i = to_world_cell(home, from)
	var to_world: Vector2i = to_world_cell(home, to)
	var leaving: GameMap = map_at_world(from_world)
	var entering: GameMap = map_at_world(to_world)
	if entering == null:
		return false
	if leaving == null:
		leaving = entering

	var target_terrain: TerrainTagData = entering.terrain_at(to_map_cell(entering, to_world))
	if target_terrain != null and target_terrain.ignore_passability:
		return not is_occupied_at(character, to_world)

	if character == player and GameState.is_surfing():
		if target_terrain != null and target_terrain.can_surf_freely():
			return not is_occupied_at(character, to_world)

	if not leaving.cell_allows(to_map_cell(leaving, from_world), direction):
		return false
	if not entering.cell_allows(to_map_cell(entering, to_world), MapGrid.opposite_direction(direction)):
		return false
	if is_occupied_at(character, to_world):
		return false
	return true

## Returns `true` when somebody other than [param character] is standing on [param world_cell]
func is_occupied_at(character: GridCharacter, world_cell: Vector2i) -> bool:
	for map: GameMap in loaded_maps():
		var local: Vector2i = to_map_cell(map, world_cell)
		if map.is_occupied_locally(character, local):
			return true
	if player != null and is_instance_valid(player) and player != character:
		if player.world_cell() == world_cell:
			return true
	return false

func is_standable(cell: Vector2i) -> bool:
	if current_map == null:
		return true
	return is_standable_at(to_world_cell(current_map, cell))

## Returns `true` when anybody could stand on [param world_cell]
func is_standable_at(world_cell: Vector2i) -> bool:
	var map: GameMap = map_at_world(world_cell)
	if map == null:
		return false
	return map.cell_allows(to_map_cell(map, world_cell), 0)

func terrain_at(cell: Vector2i) -> TerrainTagData:
	if current_map == null:
		return null
	return terrain_at_world(to_world_cell(current_map, cell))

func terrain_at_world(world_cell: Vector2i) -> TerrainTagData:
	var map: GameMap = map_at_world(world_cell)
	if map == null:
		return null
	return map.terrain_at(to_map_cell(map, world_cell))

func is_bush(cell: Vector2i) -> bool:
	if current_map == null:
		return false
	var world: Vector2i = to_world_cell(current_map, cell)
	var map: GameMap = map_at_world(world)
	return map != null and map.is_bush(to_map_cell(map, world))

func is_deep_bush(cell: Vector2i) -> bool:
	if current_map == null:
		return false
	return is_deep_bush_at(to_world_cell(current_map, cell))

func is_deep_bush_at(world_cell: Vector2i) -> bool:
	var map: GameMap = map_at_world(world_cell)
	return map != null and map.is_deep_bush(to_map_cell(map, world_cell))

func is_bush_at(world_cell: Vector2i) -> bool:
	var map: GameMap = map_at_world(world_cell)
	return map != null and map.is_bush(to_map_cell(map, world_cell))

func is_counter(cell: Vector2i) -> bool:
	if current_map == null:
		return false
	var world: Vector2i = to_world_cell(current_map, cell)
	var map: GameMap = map_at_world(world)
	return map != null and map.is_counter(to_map_cell(map, world))

func events_at(cell: Vector2i) -> Array[MapEvent]:
	if current_map == null:
		return []
	return events_at_world(to_world_cell(current_map, cell))

## Every event standing on [param world_cell]
func events_at_world(world_cell: Vector2i) -> Array[MapEvent]:
	var result: Array[MapEvent] = []
	for map: GameMap in loaded_maps():
		result.append_array(map.events_at(to_map_cell(map, world_cell)))
	return result

## The events on the map the player is standing on
func all_events() -> Array[MapEvent]:
	if current_map == null:
		return []
	return current_map.events()

## Every event on every map in the field
func every_event() -> Array[MapEvent]:
	var result: Array[MapEvent] = []
	for map: GameMap in loaded_maps():
		result.append_array(map.events())
	return result

func event_by_id(event_id: int) -> MapEvent:
	if current_map == null:
		return null
	return current_map.event_by_id(event_id)

# === Running Events ===

## `true` while an event, a warp or a battle owns the game
func is_busy() -> bool:
	if _waterfall_direction != 0:
		return true
	return _running_event != null or _transferring or _interpreter.is_running()

func running_event() -> MapEvent:
	return _running_event

func run_event(event: MapEvent) -> void:
	if event == null or is_busy() or not event.is_active():
		return
	_running_event = event
	_suspend_player(true)
	await event.run()
	if _running_event == event:
		_running_event = null
		_suspend_player(false)

# === Dialogue ===

## Shows one message and waits for the player to read it
func say(text: String) -> void:
	if not message_requested.has_connections():
		push_warning("MapController: no message window is listening; skipping '%s'." % text)
		return
	message_requested.emit(text)
	await message_acknowledged

## Offers [param options] and returns the index chosen
func ask(
	options: Array,
	prompt: String = "",
	cancel_index: int = ParsedMessage.CANCEL_DISALLOWED,
	default_index: int = 0
) -> int:
	if not choices_requested.has_connections():
		push_warning("MapController: no message window is listening; cancelling a choice.")
		return -1
	_choice_result = -1
	choices_requested.emit(prompt, options, cancel_index, default_index)
	await choice_submitted
	return _choice_result

func acknowledge_message() -> void:
	message_acknowledged.emit()

func submit_choice(index: int) -> void:
	_choice_result = index
	choice_submitted.emit()

# === Camera ===

## Scrolls the view [param cells] away from the player over [param seconds]
func scroll_map(cells: Vector2, seconds: float) -> Tween:
	var target: Vector2 = _scroll_offset + cells * float(MapGrid.TILE_SIZE)
	_cancel_scroll()
	if seconds <= 0.0:
		set_scroll_offset(target)
		return null
	_scroll_tween = create_tween()
	_scroll_tween.tween_method(set_scroll_offset, _scroll_offset, target, seconds)
	return _scroll_tween

func reset_scroll() -> void:
	_cancel_scroll()
	set_scroll_offset(Vector2.ZERO)

func set_scroll_offset(offset: Vector2) -> void:
	_scroll_offset = offset
	_apply_camera_offset()

func scroll_offset() -> Vector2:
	return _scroll_offset

## How far sideways the screen shake wants the camera this frame
## Shake and scroll cannot both write to the camera at once so this stops them from clashing
func set_shake_offset(pixels: float) -> void:
	if is_equal_approx(_shake_offset, pixels):
		return
	_shake_offset = pixels
	_apply_camera_offset()

# === Waterfall ===

## `true` while the player is being carried up or down a waterfall
func is_on_waterfall() -> bool:
	return _waterfall_direction != 0

## Carries the player [param direction] for as long as the waterfall is under them
func begin_waterfall(direction: GridCharacter.Direction) -> void:
	if _waterfall_direction != 0 or player == null:
		return
	_waterfall_direction = direction
	var was_passable: bool = player.passable
	player.passable = true
	while true:
		var before: Vector2i = player.tile_position
		await player.force_step(direction)
		if player.tile_position == before:
			break
		var terrain: TerrainTagData = terrain_at(player.tile_position)
		if terrain == null or not (terrain.waterfall or terrain.waterfall_crest):
			break
	player.passable = was_passable
	_waterfall_direction = 0
	_leave_water_if_needed(player.tile_position)

# === Encounters ===

func check_encounter() -> void:
	if is_busy() or current_map == null or encounters == null:
		return
	if GameState.party.able_count() == 0:
		return
	var cell: Vector2i = player.tile_position
	var terrain: TerrainTagData = terrain_at(cell)
	if not encounters.can_encounter_here(terrain):
		return
	var encounter_type: StringName = encounters.current_encounter_type(terrain)
	if encounter_type.is_empty():
		return
	var repel_active: bool = GameState.is_repel_active()
	if not encounters.encounter_triggered(encounter_type, repel_active):
		return
	var wild: Array[Pokemon] = encounters.build_encounter(encounter_type, terrain, repel_active)
	if wild.is_empty():
		return
	GameState.steps_since_encounter = 0
	encounter_triggered.emit(wild, encounter_type)
	
	# === Internals ===
	
func _on_map_added(map: GameMap) -> void:
	map.field = self
	map.refresh_events()
	invalidate_shadow_sources()

func _on_map_removed(map: GameMap) -> void:
	if map == current_map:
		_release_running_event()
	map.field = null
	for event: MapEvent in map.events():
		event.map = null
	invalidate_shadow_sources()

func _unload_current_map() -> void:
	if current_map == null:
		return
	_release_running_event()
	if player != null and is_instance_valid(player) and player.get_parent() != self:
		player.reparent(self)
	player.home_map = null
	# Followers live under the map's characters node, so they have to come away
	# with the player rather than being freed along with the map they were on.
	followers.detach_from_map(self)
	_map_root.clear()
	current_map = null

## Puts the player on [param map] at [param cell], in that map's own cells
func _park_player_on(map: GameMap, cell: Vector2i, facing: int, keep_camera: bool = false) -> void:
	var characters: Node2D = map.characters_root()
	var destination: Vector2 = MapGrid.cell_to_pixel(cell)
	if player.get_parent() != characters:

		player.position = destination + (_camera_lag() if keep_camera else Vector2.ZERO)
		player.reparent(characters, false)
	player.map = self
	player.home_map = map
	player.tile_position = cell
	player.position = destination
	if facing > 0:
		player.facing = facing as GridCharacter.Direction

	player.refresh_bush_depth()

## How far the view is currently trailing the camera's own position
func _camera_lag() -> Vector2:
	var camera: Camera2D = player.camera()
	if camera == null or not camera.position_smoothing_enabled:
		return Vector2.ZERO
	return camera.get_screen_center_position() - camera.global_position
	
## Loads and drops the maps stitched around the one the player is on
func _refresh_neighbourhood() -> void:
	_map_root.refresh(_view_size_in_cells())

## How much of the map fits on screen, rounded up to whole cells
func _view_size_in_cells() -> Vector2i:
	var camera: Camera2D = player.camera()
	if camera == null:
		return Vector2i.ZERO
	var view: Vector2 = camera.get_viewport_rect().size / camera.zoom
	return Vector2i(
		ceili(view.x / float(MapGrid.TILE_SIZE)),
		ceili(view.y / float(MapGrid.TILE_SIZE))
	)

	
## Which way the player walks once they have arrived, or `0` for staying put
func _arrival_direction(spawn: SpawnPoint, requested: int, door: MapEvent) -> int:
	if requested != AUTO_WALK:
		return maxi(requested, 0)
	if spawn != null and spawn.walk_out > 0:
		return spawn.walk_out
	return int(Door.EXIT_DIRECTION) if door != null else 0

func _arrival_steps(spawn: SpawnPoint, requested: int) -> int:
	if requested == AUTO_WALK and spawn != null and spawn.walk_out > 0:
		return maxi(spawn.walk_out_steps, 1)
	return 1

## Walks the player out of the cell they arrived on
## If there is a door it opens and closes
func _walk_in(door: MapEvent, direction: int, steps: int) -> void:
	if direction <= 0:
		player.visible = true
		return
	await Door.open(door)
	player.visible = true
	for index: int in range(steps):
		await _walk_player(direction as GridCharacter.Direction)
	await Door.close(door)
	GameState.set_map(map_id(), player.tile_position, int(player.facing))

func _walk_player(direction: GridCharacter.Direction) -> void:
	var target: Vector2i = player.tile_position + MapGrid.direction_vector(int(direction))
	if await player.step(direction):
		return
	if is_standable(target):
		await player.force_step(direction)
	
func _update_camera_limits() -> void:
	var camera: Camera2D = player.camera()
	if camera == null or current_map == null:
		return
	var bounds: Rect2i = _camera_bounds_in_pixels()
	var view: Vector2 = camera.get_viewport_rect().size / camera.zoom

	var limit_left: int = bounds.position.x
	var limit_top: int = bounds.position.y
	var limit_right: int = bounds.end.x
	var limit_bottom: int = bounds.end.y

	if bounds.size.x < int(view.x):
		var centre_x: int = bounds.position.x + roundi(bounds.size.x * 0.5)
		var half_x: int = roundi(view.x * 0.5)
		limit_left = centre_x - half_x
		limit_right = centre_x + half_x
	if bounds.size.y < int(view.y):
		var centre_y: int = bounds.position.y + roundi(bounds.size.y * 0.5)
		var half_y: int = roundi(view.y * 0.5)
		limit_top = centre_y - half_y
		limit_bottom = centre_y + half_y

	camera.limit_left = limit_left
	camera.limit_top = limit_top
	camera.limit_right = limit_right
	camera.limit_bottom = limit_bottom
	camera.limit_smoothed = true
	
func _apply_camera_offset() -> void:
	var camera: Camera2D = player.camera() if player != null else null
	if camera == null:
		return
	camera.offset = _scroll_offset + Vector2(_shake_offset, 0.0)

func _cancel_scroll() -> void:
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = null

## Puts the camera exactly where it belongs, with no smoothing on the way
func _snap_camera() -> void:
	var camera: Camera2D = player.camera()
	if camera == null:
		return
	camera.reset_smoothing()
	camera.force_update_scroll()

func _camera_bounds_in_pixels() -> Rect2i:
	var cells: Rect2i = Rect2i(to_world_cell(current_map, Vector2i.ZERO), current_map.size)
	var metadata: MapMetadataData = Database.map_metadata(current_map.map_id)
	if metadata == null or not metadata.snap_edges:
		var stitched: Rect2i = _map_root.camera_bounds()
		if stitched.size.x > 0 and stitched.size.y > 0:
			cells = stitched
	return Rect2i(cells.position * MapGrid.TILE_SIZE, cells.size * MapGrid.TILE_SIZE)

func _start_map_audio() -> void:
	if current_map == null:
		return
	if current_map.autoplay_bgm and not current_map.bgm.is_empty():
		AudioManager.play_bgm(current_map.bgm)
	if current_map.autoplay_bgs and not current_map.bgs.is_empty():
		AudioManager.play_bgs(current_map.bgs)
	
	## Runs a touch event the player has just stepped onto
func _leave_water_if_needed(cell: Vector2i) -> void:
	if not GameState.is_surfing() or _waterfall_direction != 0:
		return
	var terrain: TerrainTagData = terrain_at(cell)
	if terrain != null and terrain.can_surf_freely():
		return
	FieldMoves.end_surf()
	
func _start_descent_if_needed() -> void:
	if _waterfall_direction != 0 or player.facing != GridCharacter.Direction.DOWN:
		return
	var terrain: TerrainTagData = terrain_at(player.tile_position)
	if terrain == null or not (terrain.waterfall or terrain.waterfall_crest):
		return
	GameState.stats.waterfalls_descended += 1
	await begin_waterfall(GridCharacter.Direction.DOWN)

	
	## Turning on the spot counts as a step for encounters
func _on_player_direction_changed(_direction: GridCharacter.Direction) -> void:
	if player.is_moving:
		return
	check_encounter()

## Returns `true` when one was started
func _check_touch_events(cell: Vector2i) -> bool:
	if is_busy():
		return false
	for event: MapEvent in events_at(cell):
		var trigger: EventPage.Trigger = event.active_trigger()
		if trigger != EventPage.Trigger.PLAYER_TOUCH and trigger != EventPage.Trigger.EVENT_TOUCH:
			continue
		if not event.is_over_trigger() or not event.has_action():
			continue
		run_event(event)
		return true
	return false
	
func _on_player_step_finished(_cell: Vector2i) -> void:
	_cross_seam_if_needed()
	var cell: Vector2i = player.tile_position
	GameState.map_position = cell
	GameState.take_step()
	player_moved.emit(cell)
	pokemon_followers.on_player_stepped()
	followers.on_player_stepped()
	OverworldEffects.play_for_step(self, cell, terrain_at(cell), player)
	_leave_water_if_needed(cell)
	await _start_descent_if_needed()
	var event_started: bool = _check_touch_events(cell)
	if not event_started:
		check_encounter()
		
## Hands the player over to [param map], which the neighbourhood already holds
func _cross_onto(map: GameMap) -> void:
	var world: Vector2i = to_world_cell(current_map, player.tile_position)
	current_map = map
	_map_root.make_current(map)
	_park_player_on(map, to_map_cell(map, world), 0, true)

	GameState.set_map(map.map_id, player.tile_position, int(player.facing))
	encounters.setup(map.encounter_table_id())
	_refresh_neighbourhood()
	_update_camera_limits()
	_start_map_audio()
	_autorun_restarts = 0
	_last_autorun = null
	map_crossed.emit(map)

## Moves the player onto the stitched neighbour they have just stepped onto (if they did)
func _cross_seam_if_needed() -> void:
	if current_map == null or not _map_root.is_stitched():
		return
	if current_map.is_inside(player.tile_position):
		return
	var world: Vector2i = to_world_cell(current_map, player.tile_position)
	var entered: GameMap = map_at_world(world)
	if entered == null or entered == current_map:
		return
	_cross_onto(entered)

func _place_player(spawn_name: StringName, cell: Vector2i, facing: int) -> SpawnPoint:
	if current_map == null:
		return null
	if _dungeon_entry != RandomDungeon.NOT_A_DUNGEON:
		move_player_to(_dungeon_entry, facing)
		return null
	var destination: Vector2i = cell
	var direction: int = facing
	var arrived_at: SpawnPoint = null
	if not String(spawn_name).is_empty():
		var spawn: SpawnPoint = current_map.find_spawn(spawn_name)
		if spawn == null:
			push_warning("MapController: map '%s' has no spawn point called '%s'." % [
				current_map.display_name, spawn_name,
			])
		else:
			arrived_at = spawn
			destination = spawn.cell()
			if direction <= 0:
				direction = int(spawn.facing)
	if destination.x < 0 or destination.y < 0:
		var fallback: SpawnPoint = current_map.default_spawn()
		if fallback != null:
			arrived_at = fallback
			destination = fallback.cell()
			if direction <= 0:
				direction = int(fallback.facing)
		else:
			destination = Vector2i.ZERO
	move_player_to(destination, direction)
	return arrived_at
		
# === Internals - Running ===

## Lets go of the event that is running when its map is unloaded
func _release_running_event() -> void:
	if _running_event == null:
		return
	_running_event = null
	_suspend_player(false)

func _suspend_player(suspended: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.accepts_input = not suspended

## Every event in the field, on the map the player is standing on and on every map neighbor
func _all_field_events() -> Array[MapEvent]:
	var found: Array[MapEvent] = []
	for map: GameMap in _map_root.maps():
		found.append_array(map.events())
	return found

func _run_pending_autorun() -> void:
	for event: MapEvent in _all_field_events():
		if not event.is_active() or event.active_trigger() != EventPage.Trigger.AUTORUN:
			continue
		if not event.has_action():
			continue
		if event == _last_autorun:
			_autorun_restarts += 1
		else:
			_autorun_restarts = 0
		_last_autorun = event
		if _autorun_restarts > AUTORUN_RESTART_LIMIT:
			push_error("MapController: autorun event '%s' never turns itself off; stopping it." % event.display_name())
			event.erase()
			return
		run_event(event)
		return
	_last_autorun = null
	_autorun_restarts = 0

func _run_pending_parallels() -> void:
	for event: MapEvent in _all_field_events():
		if not event.is_active() or event.active_trigger() != EventPage.Trigger.PARALLEL:
			continue
		if event.is_parallel_running() or not event.has_action():
			continue
		_run_parallel(event)

## Runs the common events that run themselves
func _run_pending_common_events() -> void:
	if is_busy():
		return
	var autorun: CommonEventData = CommonEvents.pending_autorun()
	if autorun != null:
		_run_common_event_blocking(autorun)
		return
	for record: CommonEventData in CommonEvents.pending_parallel():
		if _parallel_common_events.has(record.event_id):
			continue
		_run_common_event_alongside(record)

func _run_common_event_blocking(record: CommonEventData) -> void:
	_suspend_player(true)
	await CommonEvents.run_now(_interpreter, record.event_id)
	_suspend_player(false)

## A parallel common event registered while it runs, and unregistered at the end
func _run_common_event_alongside(record: CommonEventData) -> void:
	var side_interpreter: EventInterpreter = EventInterpreter.new()
	side_interpreter.name = "ParallelCommonEvent_%d" % record.event_id
	side_interpreter.map = self
	add_child(side_interpreter)
	_parallel_common_events[record.event_id] = true
	await CommonEvents.run_now(side_interpreter, record.event_id)
	_parallel_common_events.erase(record.event_id)
	side_interpreter.queue_free()

## Parallel pages get their own interpretter to not stall the main game one
func _run_parallel(event: MapEvent) -> void:
	var side_interpreter: EventInterpreter = EventInterpreter.new()
	side_interpreter.name = "ParallelInterpreter_%s" % event.name
	side_interpreter.map = self
	add_child(side_interpreter)
	event.set_parallel_interpreter(side_interpreter)
	var page: EventPage = event.current_page()
	if page != null:
		await page.run(event)
	if is_instance_valid(event):
		event.set_parallel_interpreter(null)
	side_interpreter.queue_free()
