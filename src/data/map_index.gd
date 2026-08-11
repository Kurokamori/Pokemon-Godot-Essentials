@tool
class_name MapIndex
extends Resource

## Where every map scene lives by its map number.
##
## Warp made in the editor points directly at a [PackedScene]
## However
## "Transfer Player" command names map by number
## Metadata records and encoutner tables and save file all do too.
##
## This index relates the map scenes with their value.

const INDEX_PATH: String = "res://game/maps/_map_index.tres"

## Scene path per map number, as `{int: String}`
@export var paths: Dictionary = {}

## Display name per map number, as `{int: String}`
## Used for editor tooling and debug output
@export var names: Dictionary = {}

## Size of a map in cells, as `{int: Vector2i}`
##
## Stiching connected maps requires knowing how big a map is before deciding whether to load it,
## so the size is kept rather than read out of every scene each time the player takes a step.
@export var sizes: Dictionary = {}

static var _cached: MapIndex = null

## The project's index, loaded once.
## Returns an empty index rather than `null` when the file is missing.
static func get_index() -> MapIndex:
	if _cached != null:
		return _cached
	if ResourceLoader.exists(INDEX_PATH):
		_cached = ResourceLoader.load(INDEX_PATH, "", ResourceLoader.CACHE_MODE_REUSE) as MapIndex
	if _cached == null:
		_cached = MapIndex.new()
		push_warning("MapIndex : %s is missing." % INDEX_PATH)
	return _cached
	
## Invalidates the cached copy allowing for rebuilds to pick up changes without restart.
static func invalidate() -> void:
	_cached = null
	
func has_map(map_id: int) -> bool:
	return paths.has(map_id)
	
func scene_path(map_id: int) -> String:
	return String(paths.get(map_id, ""))
	
func map_name(map_id: int) -> String:
	return String(names.get(map_id, ""))
	
## The size of [param map_id] in cells OR zero when the index predates sizes being recorded and needs rebuilding.
func map_size(map_id: int) -> Vector2i:
	return sizes.get(map_id, Vector2i.ZERO)
	
## Loads the associated scene for [param map_id], or `null` when it's not indexed.
func load_map(map_id: int) -> PackedScene:
	var path: String = scene_path(map_id)
	if path.is_empty():
		push_error("MapIndex: there is not a map scene registered for map %d" % map_id)
		return null
	if not ResourceLoader.exists(path):
		push_error("MapIndex: map %d points at %s, however it does not exist." % [map_id, path])
		return null
	return ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	
## All map ids /numbers/ in ascending order.
func map_ids() -> Array[int]:
	var result: Array[int] = []
	for key: Variant in paths:
		result.append(int(key))
	result.sort()
	return result
	
func size() -> int:
	return paths.size()
	
func register(map_id: int, path: String, display_name: String, dimensions: Vector2i = Vector2i.ZERO) -> void:
	paths[map_id] = path
	names[map_id] = display_name
	sizes[map_id] = dimensions
