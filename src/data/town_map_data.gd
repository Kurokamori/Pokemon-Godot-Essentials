@tool
class_name TownMapData
extends GameDataResource

## One region map image and its labeled points.
## The record id is the region number.
##
## The image is divided into squares of [member square_size]
## Every position is stored here (a point, decoration, town_map_position)
## Every position is counted in the squares, and not in pixels.
##
## [method columns] and [method rows] are measured from the art

## Number of squares across a region map is assumed to have if an image is missing
## this allows the map to still be useable if there's no image.
const FALLBACK_COLUMNS: int = 30
const FALLBACK_ROWS: int = 30

@export var region: int = 0

## Image for the map under `assets/graphics/ui/Town Map/`
## Without an extension
@export var filename: String = ""

@export var background: String = ""

## Size of a square of the map image (in pixels)
@export var square_size: Vector2i = Vector2i(16, 16)

## Points on the map
@export var points: Array[TownMapPoint] = []

## Graphics laid over the map [TownMapDecoration]
@export var decorations: Array[TownMapDecoration] = []


## The region map image (or `null` if the poject doesn't have one)
func texture() -> Texture2D:
	if filename.is_empty():
		return null
	return Assets.texture(AssetIndex.CATEGORY_UI, "Town Map/%s" % filename.get_basename())
	
func graphic(graphic_name: String) -> Texture2D:
	if graphic_name.is_empty():
		return null
	return Assets.texture(AssetIndex.CATEGORY_UI, "Town Map/%s" % graphic_name.get_basename())
	
func columns() -> int:
	var image: Texture2D = texture()
	if image == null or square_size.x <= 0:
		return FALLBACK_COLUMNS
	return maxi(image.get_width() / square_size.x, 1)
	
func rows() -> int:
	var image : Texture2D = texture()
	if image == null or square_size.y <= 0:
		return FALLBACK_ROWS
	return maxi(image.get_height() / square_size.y, 1)
	

## Gets the size of the map in pixels, regardless of whether there's an actual image to measure
func pixel_size() -> Vector2i:
	return Vector2i(columns() * square_size.x, rows() * square_size.y)
	
## Whether or not [param position] is a square of this map.
func contains(position: Vector2i) -> bool:
	return (
		position.x >= 0 and position.y >= 0
		and position.x < columns() and position.y < rows()
	)
	
## Gets a point at a location -- returns `null` if there's no point
func get_point_at(position: Vector2i) -> TownMapPoint:
	for point: TownMapPoint in points:
		if point.position == position:
			return point
	return null
	
## [param position] point that the player is allowed to read or `null`
func get_visible_point_at(position: Vector2i, wall_map: bool = false) -> TownMapPoint:
	var point: TownMapPoint = get_point_at(position)
	if point == null or not point.is_visible(wall_map):
		return null
	return point
	
## All the points that Fly could take the player to, in listed order.
func fly_destinations(wall_map: bool = false) -> Array[TownMapPoint]:
	var destinations: Array[TownMapPoint] = []
	for point: TownMapPoint in points:
		if point.is_fly_destination() and point.is_visible(wall_map):
			destinations.append(point)
	return destinations
