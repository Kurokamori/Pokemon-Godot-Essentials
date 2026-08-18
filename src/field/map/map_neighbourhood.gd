class_name MapNeighbourhood
extends Node2D
## Manages map connections, the current map and any connections it may have by handling their position
## Outsources cell meaning/passability/events to [MapController]
##
## Every map has a local frame (From top left down) - MapNeighbourhood adds a global one, shared by
## every map in a field at once.

## Emitted when a map has been added to the field
signal map_added(map: GameMap)

## Emitted just before a map is freed from the scene
signal map_removed(map: GameMap)

## Emitted whenever the layout is rebuilt
signal layout_changed()


## The distance beyond the camera at which a map loads, so it's loaded by the time it's seen
const LOAD_MARGIN: int = 4

## The map the world frame is measured from
var anchor: GameMap = null

## `{int map_id: GameMap}`
## One per map in the field, the anchor included
var _loaded: Dictionary = {}

## `{int map_id: MapStitcher.Placement}`
## Measured from the anchor
var _layout: Dictionary = {}

## The world cells area maps are kept loaded for
var _kept: Rect2i = Rect2i()


# === Anchor ===

## Places [param map] in the field as the player's map, replacing whatever was their
## Adopted so that individual maps can be run as scenes
func set_anchor(map: GameMap) -> void:
	if map != null and _loaded.get(map.map_id) == map:
		_loaded.erase(map.map_id)
		remove_child(map)
	clear()
	if map == null:
		return
	anchor = map
	_loaded[map.map_id] = map
	map.position = Vector2.ZERO
	add_child(map)
	map_added.emit(map)
	_rebuild_layout()
	layout_changed.emit()
	
func clear() -> void:
	for map_id: int in _loaded.keys():
		_drop(map_id)
	_loaded.clear()
	_layout.clear()
	_kept = Rect2i()
	anchor = null

## Makes the [param map] which is already in the field, the map the player is on
func make_current(map: GameMap) -> void:
	if map == null or map == anchor or not _loaded.has(map.map_id):
		return
	var keep_at: Vector2i = origin_of(map)
	anchor = map
	_layout = MapStitcher.shifted(MapStitcher.layout_around(map.map_id), keep_at)
	_kept = Rect2i()
	_apply_positions()
	layout_changed.emit()


func anchor_map_id() -> int:
	return anchor.map_id if anchor != null else 0


## Returns `true` when the anchor has anything joined to it at all
func is_stitched() -> bool:
	return _layout.size() > 1
	
# === Loading ===

func refresh(view: Vector2i) -> void:
	if anchor == null:
		return
	var margin: Vector2i = view + Vector2i(LOAD_MARGIN, LOAD_MARGIN)
	var wanted_area: Rect2i = _anchor_rect().grow_individual(margin.x, margin.y, margin.x, margin.y)
	if wanted_area == _kept:
		return
	_kept = wanted_area

	var wanted: Dictionary = {}
	for placement: MapPlacement in MapStitcher.within(_layout, wanted_area):
		wanted[placement.map_id] = true

	for map_id: int in _loaded.keys():
		if not wanted.has(map_id) and map_id != anchor.map_id:
			_drop(map_id)

	var arrived: bool = false
	for key: Variant in wanted:
		var map_id: int = int(key)
		if _loaded.has(map_id):
			continue
		if _load(map_id):
			arrived = true
	if arrived:
		layout_changed.emit()

# === Frame ===

func origin_of(map: GameMap) -> Vector2i:
	if map == null:
		return Vector2i.ZERO
	var placement: MapPlacement = _layout.get(map.map_id)
	return placement.origin if placement != null else Vector2i.ZERO


## [param cell], counted on [param map], as world cells.
func to_world(map: GameMap, cell: Vector2i) -> Vector2i:
	return cell + origin_of(map)

## [param cell], counted on [parma map], as the map's cells.
func to_map(map: GameMap, world_cell: Vector2i) -> Vector2i:
	return world_cell - origin_of(map)
	
## Which map the [param world_cell] is one, or `null` if it's not a cell belonging to a map
func map_at(world_cell: Vector2i) -> GameMap:
	if anchor != null and _contains(anchor, world_cell):
		return anchor
	for key: Variant in _loaded:
		var map: GameMap = _loaded[key]
		if map != null and is_instance_valid(map) and _contains(map, world_cell):
			return map
	return null
	
## All maps on the field, starting with anchor
func maps() -> Array[GameMap]:
	var result: Array[GameMap] = []
	if anchor != null and is_instance_valid(anchor):
		result.append(anchor)
	for key: Variant in _loaded:
		var map: GameMap = _loaded[key]
		if map != null and is_instance_valid(map) and map != anchor:
			result.append(map)
	return result
	
func map_by_id(map_id: int) -> GameMap:
	var map: GameMap = _loaded.get(map_id)
	return map if map != null and is_instance_valid(map) else null
	
func camera_bounds() -> Rect2i:
	if anchor == null:
		return Rect2i()
	if _layout.is_empty():
		return Rect2i(Vector2i.ZERO, anchor.size)
	return MapStitcher.camera_bounds(_layout, anchor.map_id)

func layout() -> Dictionary:
	return _layout
	
# === Internals ===

func _load(map_id: int) -> bool:
	var placement: MapPlacement = _layout.get(map_id)
	if placement == null:
		return false
	var scene: PackedScene = MapIndex.get_index().load_map(map_id)
	if scene == null:
		return false
	var map: GameMap = scene.instantiate() as GameMap
	if map == null:
		push_error("MapNeighbourhood: map %d is not a map scene; its root needs the GameMap script." % map_id)
		return false
	if map.size != placement.size:
		push_warning(
			"MapNeighbourhood: the index says map %d is %s but the scene says %s. Run Project > Tools > Rebuild Map Index."
			% [map_id, placement.size, map.size]
		)
	map.position = MapGrid.cell_to_pixel(placement.origin)
	_loaded[map_id] = map
	add_child(map)
	map_added.emit(map)
	return true


func _drop(map_id: int) -> void:
	var map: GameMap = _loaded.get(map_id)
	if map == null or not is_instance_valid(map):
		_loaded.erase(map_id)
		return
	map_removed.emit(map)
	_loaded.erase(map_id)
	remove_child(map)
	map.queue_free()

func _apply_positions() -> void:
	for key: Variant in _loaded:
		var map: GameMap = _loaded[key]
		var placement: MapPlacement = _layout.get(int(key))
		if map == null or not is_instance_valid(map) or placement == null:
			continue
		map.position = MapGrid.cell_to_pixel(placement.origin)


func _anchor_rect() -> Rect2i:
	if anchor == null:
		return Rect2i()
	var placement: MapPlacement = _layout.get(anchor.map_id)
	return placement.rect() if placement != null else Rect2i(Vector2i.ZERO, anchor.size)

func _rebuild_layout() -> void:
	_layout.clear()
	_kept = Rect2i()
	if anchor == null:
		return
	_layout = MapStitcher.layout_around(anchor.map_id)
	if _layout.is_empty():
		_layout[anchor.map_id] = MapPlacement.new(anchor.map_id, Vector2i.ZERO, anchor.size, 0)
	_apply_positions()
	
func _contains(map: GameMap, world_cell: Vector2i) -> bool:
	return map.is_inside(to_map(map, world_cell))
