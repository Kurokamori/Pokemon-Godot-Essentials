class_name MapStitcher
extends RefCounted
## Manages the actual determination of map stitching (which maps sit next to eachother)
## Everything is measured in cells.

## Depth of connection (for building diagnal relationships)
const DEFAULT_DEPTH: int = 2

## The maximum depth to follow any connection regardless of where it leads
const UNLIMITED_DEPTH: int = 1 << 30

## Which maps are reachable from [param root_map_id], as `{int map_id: MapPlacement}`
static func layout_around(
	root_map_id: int,
	depth: int = DEFAULT_DEPTH,
	connections: MapConnectionSet = null,
	index: MapIndex = null
) -> Dictionary:
	var joins: MapConnectionSet = connections if connections != null else MapConnectionSet.get_connections()
	var maps: MapIndex = index if index != null else MapIndex.get_index()

	var result: Dictionary = {}
	var root_size: Vector2i = maps.map_size(root_map_id)
	if root_size == Vector2i.ZERO:
		return result
	result[root_map_id] = MapPlacement.new(root_map_id, Vector2i.ZERO, root_size, 0)

	var frontier: Array[int] = [root_map_id]
	while not frontier.is_empty():
		var next: Array[int] = []
		for map_id: int in frontier:
			var here: MapPlacement = result[map_id]
			if here.depth >= depth:
				continue
			for connection: MapConnection in joins.for_map(map_id):
				var neighbour: int = connection.other_map(map_id)
				if result.has(neighbour):
					continue
				var neighbour_size: Vector2i = maps.map_size(neighbour)
				if neighbour_size == Vector2i.ZERO:
					continue
				var offset: Vector2i = connection.placement_from(map_id, here.size, neighbour_size)
				result[neighbour] = MapPlacement.new(neighbour, here.origin + offset, neighbour_size, here.depth + 1)
				next.append(neighbour)
		frontier = next
	return result
	
## Shifts every placement by [param by] cells
static func shifted(layout: Dictionary, by: Vector2i) -> Dictionary:
	if by == Vector2i.ZERO:
		return layout
	var result: Dictionary = {}
	for key: Variant in layout:
		result[key] = (layout[key] as MapPlacement).shifted(by)
	return result
	
## Remeasures the layout from [param map_id] so that map sits at the origin
static func rebased(layout: Dictionary, map_id: int) -> Dictionary:
	if not layout.has(map_id):
		return layout
	return shifted(layout, -(layout[map_id] as MapPlacement).origin)
	
## The maps in [param layout] whose artwork can reach [param area]
## Nearest first
static func within(layout: Dictionary, area: Rect2i) -> Array[MapPlacement]:
	var result: Array[MapPlacement] = []
	for key: Variant in layout:
		var placement: MapPlacement = layout[key]
		if placement.rect().intersects(area):
			result.append(placement)
	result.sort_custom(func(a: MapPlacement, b: MapPlacement) -> bool: return a.depth < b.depth)
	return result
	
## What map owns [param cell], checks map [param prefer] first so that if the cell is owned by two, 
## it returns the prefered map (generally for checking the map the player is ON first)
static func map_at(layout: Dictionary, cell: Vector2i, prefer: int = 0) -> int:
	if prefer != 0 and layout.has(prefer) and (layout[prefer] as MapPlacement).contains(cell):
		return prefer
	for key: Variant in layout:
		if (layout[key] as MapPlacement).contains(cell):
			return int(key)
	return 0
	
# === Camera ===

## How far, in cells, the map may travel, around the map at the origin
static func camera_bounds(layout: Dictionary, root_map_id: int) -> Rect2i:
	if not layout.has(root_map_id):
		return Rect2i()
	var base: Rect2i = (layout[root_map_id] as MapPlacement).rect()
	var north: int = _reach(layout, root_map_id, MapConnection.Edge.NORTH)
	var south: int = _reach(layout, root_map_id, MapConnection.Edge.SOUTH)
	var west: int = _reach(layout, root_map_id, MapConnection.Edge.WEST)
	var east: int = _reach(layout, root_map_id, MapConnection.Edge.EAST)
	return Rect2i(
		base.position - Vector2i(west, north),
		base.size + Vector2i(west + east, north + south)
	)
	
# === Utilities and Internals ===
## Every map connected to [param root_map_id] creates an understanding of the atlas
static func component_around(
	root_map_id: int,
	connections: MapConnectionSet = null,
	index: MapIndex = null
) -> Dictionary:
	return layout_around(root_map_id, UNLIMITED_DEPTH, connections, index)


## Every connected region in the project, as an array of layouts, each keyed by map number.
## Regions of a single map are left out: there is nothing to stitch.
static func components(
	connections: MapConnectionSet = null,
	index: MapIndex = null
) -> Array[Dictionary]:
	var joins: MapConnectionSet = connections if connections != null else MapConnectionSet.get_connections()
	var maps: MapIndex = index if index != null else MapIndex.get_index()
	var result: Array[Dictionary] = []
	var visited: Dictionary = {}
	for root: int in joins.map_ids():
		if visited.has(root) or not maps.has_map(root):
			continue
		var layout: Dictionary = component_around(root, joins, maps)
		for key: Variant in layout:
			visited[int(key)] = true
		if layout.size() > 1:
			result.append(layout)
	return result

## Every issue with the connection data, one line each
static func problems(connections: MapConnectionSet = null, index: MapIndex = null) -> Array[String]:
	var joins: MapConnectionSet = connections if connections != null else MapConnectionSet.get_connections()
	var maps: MapIndex = index if index != null else MapIndex.get_index()
	var result: Array[String] = joins.problems()

	for connection: MapConnection in joins.connections:
		if connection == null or not connection.is_well_formed():
			continue
		for map_id: int in [connection.map_id, connection.target_map_id]:
			if not maps.has_map(map_id):
				result.append("%s: there is no map %d." % [connection.describe(), map_id])
			elif maps.map_size(map_id) == Vector2i.ZERO:
				result.append("Map %d has no size in the index; rebuild it." % map_id)

	var visited: Dictionary = {}
	for root: int in joins.map_ids():
		if visited.has(root) or not maps.has_map(root):
			continue
		var layout: Dictionary = component_around(root, joins, maps)
		var ids: Array[int] = []
		for key: Variant in layout:
			visited[int(key)] = true
			ids.append(int(key))
		ids.sort()
		for first: int in range(ids.size()):
			for second: int in range(first + 1, ids.size()):
				var one: MapPlacement = layout[ids[first]]
				var two: MapPlacement = layout[ids[second]]
				if one.rect().intersects(two.rect()):
					result.append("Maps %d and %d end up on top of each other: %s overlaps %s." % [
						one.map_id, two.map_id, one.rect(), two.rect(),
					])
	return result

## How far past [param edge] of the root map the camera may go
static func _reach(layout: Dictionary, root_map_id: int, edge: MapConnection.Edge) -> int:
	var base: Rect2i = (layout[root_map_id] as MapPlacement).rect()
	var horizontal: bool = MapConnection.is_horizontal_edge(edge)
	var span_start: int = base.position.x if horizontal else base.position.y
	var span_end: int = base.end.x if horizontal else base.end.y
	var furthest: int = 0

	for key: Variant in layout:
		if int(key) == root_map_id:
			continue
		var rect: Rect2i = (layout[key] as MapPlacement).rect()
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var depth: int = 0
		match edge:
			MapConnection.Edge.NORTH:
				if rect.end.y != base.position.y:
					continue
				depth = base.position.y - rect.position.y
			MapConnection.Edge.SOUTH:
				if rect.position.y != base.end.y:
					continue
				depth = rect.end.y - base.end.y
			MapConnection.Edge.WEST:
				if rect.end.x != base.position.x:
					continue
				depth = base.position.x - rect.position.x
			MapConnection.Edge.EAST:
				if rect.position.x != base.end.x:
					continue
				depth = rect.end.x - base.end.x
		if depth <= 0:
			continue
		var overlap_start: int = maxi(rect.position.x if horizontal else rect.position.y, span_start)
		var overlap_end: int = mini(rect.end.x if horizontal else rect.end.y, span_end)
		if overlap_end <= overlap_start:
			continue
		furthest = maxi(furthest, depth)

	return furthest
