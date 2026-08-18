class_name MapPlacement
extends RefCounted
## Where a single map sits in a layout

var map_id: int = 0

## Top left corner, in cells, relative to the map layout
var origin: Vector2i = Vector2i.ZERO

var size: Vector2i = Vector2i.ZERO

## How many connections were followed to reach this map.
var depth: int = 0

func _init(id: int = 0, at: Vector2i = Vector2i.ZERO, of_size: Vector2i = Vector2i.ZERO, from_depth: int = 0) -> void:
	map_id = id
	origin = at
	size = of_size
	depth = from_depth

func rect() -> Rect2i:
	return Rect2i(origin, size)

func contains(cell: Vector2i) -> bool:
	return rect().has_point(cell)

## The same placement seen from a different anchor.
func shifted(by: Vector2i) -> MapPlacement:
	return MapPlacement.new(map_id, origin + by, size, depth)
