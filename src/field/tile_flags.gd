@tool
class_name TileFlags
## Per-tile facts a baked map [TileSet] carries

## [TerrainTagData] tag number
const TERRAIN_TAG: String = "terrain_tag"

## Passage bits;
## see `BLOCKS_*` constants bellow
const PASSAGE: String = "passage"

## Draw priority
## `0` draws bellow the characters
const PRIORITY: String = 'priority'

const TILE_ID: String = "tile_id"

const DATA_LAYERS: Array[String] = [TERRAIN_TAG, PASSAGE, PRIORITY, TILE_ID]

const BLOCKS_DOWN: int = 0x01
const BLOCKS_LEFT: int = 0x02
const BLOCKS_RIGHT: int = 0x04
const BLOCKS_UP: int = 0x08
const BLOCKS_ALL: int = 0x0f
const IS_BUSH: int = 0x40
const IS_COUNTER: int = 0x80

## Returns `true` if the tile wiht [param passage] stops a character entering while moving in [param direction]
static func blocks_direction(passage: int, direction: int) -> bool:
	match direction:
		2: return (passage & BLOCKS_DOWN) != 0
		4: return (passage & BLOCKS_LEFT) != 0
		6: return (passage & BLOCKS_RIGHT) != 0
		8: return (passage & BLOCKS_UP) != 0
	return false
	
static func blocks_all_directions(passage: int) -> bool:
	return (passage & BLOCKS_ALL) == BLOCKS_ALL

static func is_bush(passage: int) -> bool:
	return (passage & IS_BUSH) != 0

static func is_counter(passage: int) -> bool:
	return (passage & IS_COUNTER) != 0
	
## Reads a single custom data value from a  tile at [param cell]
## returns [param fallback] when the cell is empty
static func read(layer: TileMapLayer, cell: Vector2i, key: String, fallback: int) -> int:
	if layer == null or layer.tile_set == null:
		return fallback
	var tile: TileData = layer.get_cell_tile_data(cell)
	if tile == null:
		return fallback
	var value: Variant = tile.get_custom_data(key)
	if value == null or typeof(value) != TYPE_INT:
		return fallback
	return int(value)

## Where a tile sorts, against the characters
static func y_sort_origin_for(priority: int) -> int:
	if priority <= 0:
		return 0
	return (priority - 1) * MapGrid.TILE_SIZE
