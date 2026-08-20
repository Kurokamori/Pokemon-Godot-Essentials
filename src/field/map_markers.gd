@tool
class_name MapMarkers
## The overlay tiles which can be drawn to override what the artwork defaults to

enum Collision {
	NONE = -1,
	BLOCKED = 0,
	OPEN = 1,
	BLOCK_NORTH = 2,
	BLOCK_SOUTH = 3,
	BLOCK_WEST = 4,
	BLOCK_EAST = 5,
	BUSH = 6,
	COUNTER = 7,
	PLAIN = 8,
}

const COLLISION_COUNT: int = 9

const COLLISION_NAMES: Array[String] = [
	"Blocked", "Open", "Block North", "Block South", "Block West", "Block East",
	"Bush", "Counter", "Plain",
]

## Pallette colors for marker art, in the same order as the constants
const COLLISION_COLORS: Array[Color] = [
	Color(0.85, 0.16, 0.20, 0.72),
	Color(0.24, 0.78, 0.32, 0.72),
	Color(0.94, 0.62, 0.16, 0.72),
	Color(0.94, 0.62, 0.16, 0.72),
	Color(0.94, 0.62, 0.16, 0.72),
	Color(0.94, 0.62, 0.16, 0.72),
	Color(0.32, 0.70, 0.28, 0.72),
	Color(0.90, 0.80, 0.24, 0.72),
	Color(0.55, 0.58, 0.62, 0.72),
]

## Custom data layer holding the [enum Collision] value of a marker tile.
const COLLISION_KEY: String = "collision_marker"

## Custom data layer holding the terrain tag number of a terrain marker tile.
const TERRAIN_KEY: String = "terrain_tag"

const COLLISION_TILESET_PATH: String = "res://assets/tilesets/markers/collision_markers.tres"
const TERRAIN_TILESET_PATH: String = "res://assets/tilesets/markers/terrain_markers.tres"
const COLLISION_TEXTURE_PATH: String = "res://assets/tilesets/markers/collision_markers.png"
const TERRAIN_TEXTURE_PATH: String = "res://assets/tilesets/markers/terrain_markers.png"

const MARKER_SOURCE_ID: int = 0


static func collision_atlas_coords(marker: Collision) -> Vector2i:
	return Vector2i(int(marker), 0)

## The [enum Collision] painted at [param cell], or [constant Collision.NONE].
static func collision_at(layer: TileMapLayer, cell: Vector2i) -> Collision:
	if layer == null or layer.tile_set == null:
		return Collision.NONE
	var tile: TileData = layer.get_cell_tile_data(cell)
	if tile == null:
		return Collision.NONE
	var value: Variant = tile.get_custom_data(COLLISION_KEY)
	if value == null or typeof(value) != TYPE_INT:
		return Collision.NONE
	return int(value) as Collision

## The terrain tag number painted at [param cell], or `-1` when none is.
static func terrain_at(layer: TileMapLayer, cell: Vector2i) -> int:
	if layer == null or layer.tile_set == null:
		return -1
	var tile: TileData = layer.get_cell_tile_data(cell)
	if tile == null:
		return -1
	var value: Variant = tile.get_custom_data(TERRAIN_KEY)
	if value == null or typeof(value) != TYPE_INT:
		return -1
	return int(value)

## Returns `true` when [param marker] stops a character entering the cell while moving in [param direction].
static func blocks_direction(marker: Collision, direction: int) -> bool:
	match marker:
		Collision.BLOCKED:
			return true
		Collision.BLOCK_NORTH:
			return direction == 8
		Collision.BLOCK_SOUTH:
			return direction == 2
		Collision.BLOCK_WEST:
			return direction == 4
		Collision.BLOCK_EAST:
			return direction == 6
	return false

## Returns `true` when [param marker] resolves passability on its own
static func decides_passability(marker: Collision) -> bool:
	return marker in [
		Collision.BLOCKED, Collision.OPEN, Collision.BLOCK_NORTH,
		Collision.BLOCK_SOUTH, Collision.BLOCK_WEST, Collision.BLOCK_EAST,
	]
