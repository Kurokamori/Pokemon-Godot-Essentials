@tool
class_name GameMap
extends Node2D

## A single game map as a scene

const GROUND_NODE_NAME: String = "Ground"
const OVERHEAD_NODE_NAME: String = "Overhead"
const MARKERS_NODE_NAME: String = "Markers"
const EVENTS_NODE_NAME: String = "Events"
const CHARACTERS_NODE_NAME: String = "Character"
const SPAWNS_NODE_NAME: String = "Spawns"

# TODO: Create and add here the template
const TEMPLATE_PATH: String = ""

## A signal emitted when the map is loaded and ready, it will not be emitted in this script.
@warning_ignore("unused_signal")
signal map_ready()

@export_group("Identity")
@export var map_id: int = 0

@export var display_name: String = ""

## The map size in cells
@export var size: Vector2i = Vector2i(20, 15)

@export var tileset_id: int = 0

@export_group("Audio")
## Track name under `assets/audio/bgm/`
@export var bgm: String = ""
@export var autoplay_bgm: bool = true

## Ambient loop track under `assets/audio/bgs/`
@export var bgs: String = ""
@export var autoplay_bgs: bool = true

@export_group("Encounters")
## Average amount of steps it takes to get an encounter
@export var encounter_steps: int = 30

## If this map borrows its encounters from another map, this is the id
@export var encounter_map_id: int = 0

## Which autotile atlas this layout was mapped with
## Autotiles used to occupy one atlas column per variant
@export var autotile_layout: int = 0

@export_group("Editor")
## Debug setting
## Draws collision and terrain overlays during runtime
@export var show_markers_in_game: bool = false


## Field this map belongs to
## `null` while the map is being editted
var field: MapController = null


var _ground_root: Node2D = null
var _overhead_root: Node2D = null
var _markers_root: Node2D = null 
var _events_root: Node2D = null
var _characters_root: Node2D = null
var _spawns_root: Node2D = null
var _collision_markers: Node2D =  null
var _terrain_markers: Node2D = null

var _events: Array[MapEvent] = []

var _passability_order: Array[TileMapLayer] = []



func _ready() -> void:
	_bind_nodes()
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	MapGrid.verify_settings()
	_collect_layers()
	_collect_events()
	if _markers_root != null:
		_markers_root.visible = show_markers_in_game
	if get_tree() != null and get_tree().current_scene == self:
		_boot_standalone()
	
# === Structure ===

func events_root() -> Node2D:
	_ensure_bounds()
	return _events_root
	
func characters_root() -> Node2D:
	_ensure_bounds()
	return _characters_root if _characters_root != null else self
	
func collision_marker_layer() -> TileMapLayer:
	_ensure_bounds()
	return _collision_markers
	
func terrain_marker_layer() -> TileMapLayer:
	_ensure_bounds()
	return _terrain_markers
	
## Every tile layer in drawing order
## Bottom child of `Ground` first -- top layer of `Overhead` last
func tile_layers() -> Array[TileMapLayer]:
	_ensure_bounds()
	var result: Array[TileMapLayer] = []
	_append_layers(result, _ground_root)
	_append_layers(result, _overhead_root)
	return result
	
## Resolves the tileset the map draws with from the baked [TileSet] when [member tileset_id] is unset
func source_tileset_id() -> int:
	if tileset_id > 0:
		return tileset_id
	for layer: TileMapLayer in tile_layers():
		if layer.tile_set == null:
			continue
		var file_stem: String = layer.tile_set.resource_path.get_file().get_basename()
		var num: String = file_stem.trim_prefix("tileset_")
		if num != file_stem and num.is_valid_int():
			return int(num)
	return 0
	
# === Events ===

func refresh_events() -> void:
	_collect_events()
	if field != null:
		field.adopt_map_events(self)
		
## The events on this map, minus any that have been freed since the list was collected.
func events() -> Array[MapEvent]:
	for index: int in range(_events.size() - 1, -1, -1):
		if not is_instance_valid(_events[index]):
			_events.remove_at(index)
	return _events


func events_at(cell: Vector2i) -> Array[MapEvent]:
	var result: Array[MapEvent] = []
	for event: MapEvent in events():
		if event.tile_position == cell:
			result.append(event)
	return result


## The event addressed by a command's event number.
func event_by_id(event_id: int) -> MapEvent:
	for event: MapEvent in events():
		if event.event_id == event_id:
			return event
	return null


func event_by_name(event_name: StringName) -> MapEvent:
	for event: MapEvent in events():
		if StringName(event.name) == event_name or StringName(event.event_name) == event_name:
			return event
	return null
	
# === Spawns ===

## The spawn point called [param spawn_name]
## Returns `null` if no such thing exists
func find_spawn(spawn_name: StringName) -> SpawnPoint:
	if String(spawn_name).is_empty():
		return null
	for node: Node in find_children("*", "SpawnPoint", true, false):
		var spawn: SpawnPoint = node as SpawnPoint
		if spawn != null and spawn.identifier() == spawn_name:
			return spawn
	return null


## Where the player spawns if there's no more specific spawn point requested
func default_spawn() -> SpawnPoint:
	var named: SpawnPoint = find_spawn(SpawnPoint.DEFAULT_NAME)
	if named != null:
		return named
	for node: Node in find_children("*", "SpawnPoint", true, false):
		return node as SpawnPoint
	return null


## The encounter table number this map uses.
func encounter_table_id() -> int:
	return encounter_map_id if encounter_map_id > 0 else map_id
		
# === Bounds ===

func bounds() -> Rect2i:
	return Rect2i(Vector2i.ZERO, size)
	
func is_inside(cell: Vector2i) -> bool:
	return bounds().has_point(cell)
	
func pixel_size() -> Vector2i:
	return size * MapGrid.TILE_SIZE
	
## The smallest rect covering every tile
## Used by the editor when sizing artowrk to [member size]
func used_cell_rect() -> Rect2i:
	var result: Rect2i = Rect2i()
	var first: bool = true
	for layer: TileMapLayer in tile_layers():
		var used: Rect2i = layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		result = used if first else result.merge(used)
		first = false
	return result
	
# === Passability ===

## Checks the validity of a [param character] move from [param from] to [param to] in [param direction]
## If the map belongs to a field it querries the field, since it can't know if the player is stepping off a map onto another
func is_passable(character: GridCharacter, from: Vector2i, to: Vector2i, direction: int) -> bool:
	if field != null:
		return field.is_step_allowed(self, from, to, direction, character)
	return is_passable_locally(character, from, to, direction)


## The map's local resolution, without considering stitched maps
func is_passable_locally(character: GridCharacter, from: Vector2i, to: Vector2i, direction: int) -> bool:
	if not is_inside(to):
		return false

	var target_terrain: TerrainTagData = terrain_at(to)
	if target_terrain != null and target_terrain.ignore_passability:
		return not is_occupied(character, to)

	if not cell_allows(from, direction):
		return false
	if not cell_allows(to, MapGrid.opposite_direction(direction)):
		return false
	if is_occupied(character, to):
		return false
	return true


## Returns `true` if a character can stand on [param cell] at all
func is_standable(cell: Vector2i) -> bool:
	if not is_inside(cell):
		return false
	return cell_allows(cell, 0)


## Returns `true` when movement in [param direction] is allowed through [param cell].
## Pass `0` to ask whether the cell is walkable at all.
func cell_allows(cell: Vector2i, direction: int) -> bool:
	var marker: MapMarkers.Collision = MapMarkers.collision_at(collision_marker_layer(), cell)
	if MapMarkers.decides_passability(marker):
		if marker == MapMarkers.Collision.OPEN:
			return true
		return not MapMarkers.blocks_direction(marker, direction)
	return _tiles_allow(cell, direction)


## The artwork's own passability resolution, read from the top down.
func _tiles_allow(cell: Vector2i, direction: int) -> bool:
	_ensure_layers()
	for layer: TileMapLayer in _passability_order:
		var tile: TileData = layer.get_cell_tile_data(cell)
		if tile == null:
			continue
		var passage: int = TileFlags.read(layer, cell, TileFlags.PASSAGE, 0)
		if TileFlags.blocks_direction(passage, direction):
			return false
		if TileFlags.blocks_all_directions(passage):
			return false
		if TileFlags.read(layer, cell, TileFlags.PRIORITY, 0) == 0:
			return true
	return true


## Returns `true` when a character other than [param character] is standing on [param cell] and would be in the way.
func is_occupied(character: GridCharacter, cell: Vector2i) -> bool:
	if field != null:
		return field.is_occupied_at(character, field.to_world_cell(self, cell))
	return is_occupied_locally(character, cell)


## The events this map itself is holding
func is_occupied_locally(character: GridCharacter, cell: Vector2i) -> bool:
	for event: MapEvent in events():
		if event == character or event.is_passable_now():
			continue
		if event.tile_position == cell:
			return true
	return false
	
# === Terrain ===

## The terrain at [param cell].
func terrain_at(cell: Vector2i) -> TerrainTagData:
	return Database.terrain_tag_by_number(terrain_number_at(cell))


func terrain_number_at(cell: Vector2i) -> int:
	_ensure_layers()
	var painted: int = MapMarkers.terrain_at(terrain_marker_layer(), cell)
	if painted >= 0:
		return painted
	for layer: TileMapLayer in _passability_order:
		var tag: int = TileFlags.read(layer, cell, TileFlags.TERRAIN_TAG, 0)
		if tag > 0:
			return tag
	return 0


## Returns `true` when the cell is long grass
func is_bush(cell: Vector2i) -> bool:
	var marker: MapMarkers.Collision = MapMarkers.collision_at(collision_marker_layer(), cell)
	if marker == MapMarkers.Collision.BUSH:
		return true
	if marker == MapMarkers.Collision.PLAIN:
		return false
	return _any_tile_has_passage_flag(cell, TileFlags.IS_BUSH)


## Returns `true` when the cell is grass tall enough to hide a character's legs rather than only their ankles.
func is_deep_bush(cell: Vector2i) -> bool:
	var terrain: TerrainTagData = terrain_at(cell)
	return terrain != null and terrain.deep_bush


## Returns `true` when the cell is a counter the player may talk across.
func is_counter(cell: Vector2i) -> bool:
	var marker: MapMarkers.Collision = MapMarkers.collision_at(collision_marker_layer(), cell)
	if marker == MapMarkers.Collision.COUNTER:
		return true
	if marker == MapMarkers.Collision.PLAIN:
		return false
	return _any_tile_has_passage_flag(cell, TileFlags.IS_COUNTER)


func _any_tile_has_passage_flag(cell: Vector2i, flag: int) -> bool:
	_ensure_layers()
	for layer: TileMapLayer in _passability_order:
		if (TileFlags.read(layer, cell, TileFlags.PASSAGE, 0) & flag) != 0:
			return true
	return false
	
# === Internals ===

func _bind_nodes() -> void:
	_ground_root = get_node_or_null(NodePath(GROUND_NODE_NAME)) as Node2D
	_overhead_root = get_node_or_null(NodePath(OVERHEAD_NODE_NAME)) as Node2D
	_markers_root = get_node_or_null(NodePath(MARKERS_NODE_NAME)) as Node2D
	_events_root = get_node_or_null(NodePath(EVENTS_NODE_NAME)) as Node2D
	_characters_root = get_node_or_null(NodePath(CHARACTERS_NODE_NAME)) as Node2D
	_events_root = get_node_or_null(NodePath(EVENTS_NODE_NAME)) as Node2D
	if _markers_root != null:
		_collision_markers = _markers_root.get_node_or_null(^"Collision") as TileMapLayer
		_terrain_markers = _markers_root.get_node_or_null(^"Terrain") as TileMapLayer

func _ensure_bounds() -> void:
	if _ground_root == null:
		_bind_nodes()
		
func _append_layers(into: Array[TileMapLayer], root: Node2D) -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		if layer != null:
			into.append(layer)
			
## Builds the layer order.
## Allows unloaded maps to respond to certain questions
func _ensure_layers() -> void:
	if _passability_order.is_empty():
		_collect_layers()
		
## Collects the layers for the passability order
func _collect_layers() -> void:
	_ensure_bounds()
	_passability_order.clear()
	var overhead: Array[TileMapLayer] = []
	var ground: Array[TileMapLayer] = []
	_append_layers(overhead, _overhead_root)
	_append_layers(ground, _ground_root)
	overhead.reverse()
	ground.reverse()
	_passability_order.append_array(overhead)
	_passability_order.append_array(ground)
	
## Collects the map's events
func _collect_events() -> void:
	_ensure_bounds()
	_events.clear()
	if _events_root == null:
		return
	for node: Node in _events_root.find_children("*", "MapEvent", true, false):
		var event: MapEvent = node as MapEvent
		if event == null:
			continue
		event.map_scene = self
		event.home_map = self
		_events.append(event)
		
# === Standalone ===

## Wraps this map in the overworld and starts playing it which allows users to edit a map and launch it directly
func _boot_standalone() -> void:
	print("GameMap: running '%s' on its own; wrapping it in the overworld." % display_name)
	call_deferred("_do_boot_standalone")


func _do_boot_standalone() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if not GameState.has_session():
		GameState.start_new_game("Tester", PokemonOwner.Gender.MALE)
	var scene: PackedScene = load(Overworld.SCENE_PATH)
	if scene == null:
		push_error("GameMap: %s is missing, so the map cannot be played on its own." % Overworld.SCENE_PATH)
		return
	var overworld: Overworld = scene.instantiate() as Overworld
	overworld.startup_map = self
	var parent: Node = get_parent()
	if parent != null:
		parent.remove_child(self)
	tree.root.add_child(overworld)
	tree.current_scene = overworld


# === Editor Helper ===

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	for required: String in [GROUND_NODE_NAME, OVERHEAD_NODE_NAME, EVENTS_NODE_NAME, CHARACTERS_NODE_NAME]:
		if get_node_or_null(NodePath(required)) == null:
			warnings.append("This map has no '%s' node. Start new maps from %s." % [required, TEMPLATE_PATH])
	if map_id <= 0:
		warnings.append("Map Id is 0. Give the map a number so warps, metadata and saves can find it.")
	if size.x <= 0 or size.y <= 0:
		warnings.append("Size must be at least one tile in each direction.")
	return warnings
