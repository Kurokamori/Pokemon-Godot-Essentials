@tool
class_name MapConnectionSet
extends Resource

## Every joining between maps / map edges / in the project.
##
## Connections live in one file rather than on the maps themselves to avoid argument.

const PATH: String = "res://data/map_connections.tres"

@export var connections: Array[MapConnection] = []:
	set(value):
		connections = value
		_by_map.clear()
		

static var _cached: MapConnectionSet = null

## `{int map_id: Array[MapConnection]}` which is built on first use.
var _by_map: Dictionary = {}


## The project's connections which are loaded once.
## Answers with an empty set rather then `null` when the file is missing so a project with no connections still runs.
static func get_connections() -> MapConnectionSet:
	if _cached != null:
		return _cached
	if ResourceLoader.exists(PATH):
		_cached = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_REUSE) as MapConnectionSet
	if _cached == null:
		_cached = MapConnectionSet.new()
	return _cached
	
## Invalidates the cached copy which allows an edit to be picked up without restarting.
static func invalidate() -> void:
	_cached = null
	
## Rebuilds the per-map lookup.
## Call after changing [member connections] in place rather than assigning a new array.
func refresh() -> void:
	_by_map.clear()
	
func _ensure_lookup() -> void:
	if not _by_map.is_empty():
		return
	for connection: MapConnection in connections:
		if connection == null or not connection.is_well_formed():
			continue
		_remember(connection.map_id, connection)
		_remember(connection.target_map_id, connection)
		
func _remember(map_id: int, connection: MapConnection) -> void:
	if not _by_map.has(map_id):
		_by_map[map_id] = [] as Array[MapConnection]
		var list: Array[MapConnection] = _by_map[map_id]
		list.append(connection)
		
## Lists all the connections that touch [param map_id]
func for_map(map_id: int) -> Array[MapConnection]:
	_ensure_lookup()
	return _by_map.get(map_id, [] as Array[MapConnection])
	
func has_any(map_id: int) -> bool:
	return not for_map(map_id).is_empty()
	
## Maps (by number) which take part in at least one connection, in ascending order.
func map_ids() ->  Array[int]:
	_ensure_lookup()
	var result: Array[int] = []
	for key: Variant in _by_map:
		result.append(int(key))
	result.sort()
	return result
	
## Which connection joins these two maps. Returns `null` if there is no such connection.
func between(a: int, b: int) -> MapConnection:
	for connection: MapConnection in for_map(a):
		if connection.other_map(a) == b:
			return connection
	return null
	
	
func add(connection: MapConnection) -> void:
	if connection == null:
		return
	connections.append(connection)
	refresh()
	
## Drops all connections which join these two maps and returns how many were deleted.
func remove_between(a: int, b: int) -> int:
	var kept: Array[MapConnection] = []
	var dropped: int = 0
	for connection: MapConnection in connections:
		if connection != null and connection.joins(a) and connection.other_map(a) == b:
			dropped += 1
			continue
		kept.append(connection)
	connections = kept
	return dropped
	
## Drops all connections which touch a given map ( [param map_id] ) and returns how many were deleted.
func remove_map(map_id: int) -> int:
	var kept: Array[MapConnection] = []
	var dropped: int = 0
	for connection: MapConnection in connections:
		if connection != null and connection.joins(map_id):
			dropped += 1
			continue
		kept.append(connection)
	connections = kept
	return dropped
	
## Sorts the records so a saved file reads in map order.
func sort() -> void:
	connections.sort_custom(func(a: MapConnection, b: MapConnection) -> bool:
		if a == null or b == null:
			return b == null
		if a.map_id != b.map_id:
			return a.map_id < b.map_id
		if a.target_map_id != b.target_map_id:
			return a.target_map_id < b.target_map_id
		return a.offset < b.offset
		)
	refresh()
	
## Everything wrong with the set as one line each.
## Malformed record and maps joined twice over.
func problems() -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	for connection: MapConnection in connections:
		if connection == null:
			result.append("There is an empty row in the connection list.")
			continue
		var trouble: String = connection.problem()
		if not trouble.is_empty():
			result.append("%s: %s" % [connection.describe(), trouble])
			continue
		var key: String = "%d-%d" % [mini(connection.map_id, connection.target_map_id), maxi(connection.map_id, connection.target_map_id)]
		if seen.has(key):
			result.append("Maps %d and %d are connected more than once." % [connection.map_id, connection.target_map_id])
			continue
		seen[key] = true
	return result
