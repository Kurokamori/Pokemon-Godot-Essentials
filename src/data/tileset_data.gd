@tool
class_name TilesetData
extends GameDataResource

## A tileset
## What images it draws from, the per-tile passabiliy, priority, and terrain tags that overworld will read.
##
## Tile numbering follows the RPG Maker XP convention the maps 

const TILES_PER_ROW: int = 8
const AUTOTILE_VARIANTS: int = 48

## Side of one tile as pixels
## What turns a baked strip's width into a number of columns
const TILE_SIDE: int = 32
const FIRST_AUTOTILE_TILE: int = AUTOTILE_VARIANTS
const FIRST_REGULAR_TILE: int = 384

@export var tileset_id: int = 0

## Name of the main tileset image under `assets/graphics/autotiles/`
@export var tileset_name: String = ""

## Up to seven autotile image names under `assets/graphics/autotiles/`
@export var autotile_names: Array[String] = []

@export_group("Backdrop")
## Panorama drawn behind the map, under `assets/graphics/panoramas/`
@export var panorama_name: String = ""

## Grees the panorama's colours are turned around a hue wheel from `0` to `359`
@export_range(0, 359) var panorama_hue: int = 0

## Fog drawn over the map, under `assets/graphics/fogs/`
@export var fog_name: String = ""

## Degrees the panorama's colours are turned around on a hue wheel from `0` to `359`
@export_range(0, 359) var fog_hue: int = 0

## Opacity / Transparency of the fog drawn
@export_range(0, 255) var fog_opacity: int = 64

## How the fog is drawn over whatever is behind it:
## `0` Normally
## `1` Added
## `2` Subtracted
@export_range(0, 2) var fog_blend_type: int = 0

## How much the fog image is scaled up as a percentage
@export var fog_zoom: int = 100

## How fast the fog drifts from left to right across the map (In RPG Maker's Units)
@export var fog_sx: int = 0
## How fast the fog drifts from top to bottom across the map (In RPG Maker's Units)
@export var fog_sy: int = 0

@export_group("Per-tile Data")
## Passage bits per tile id:
## 1 blocks moving down,
## 2 blocks moving left,
## 4 blocks moving right,
## 8 blocks moving up,
## 0x40 marks a bush tile
## 0x80 marks a counter
@export var passages: PackedInt32Array = PackedInt32Array()

## Draw priority per tile id
## `0` draws bellow the player
## Higher values draw above the player
@export var priorities: PackedInt32Array = PackedInt32Array()

## Terrain tag number per tile id
## Resolves through [TerrainTagData]
@export var terrain_tags: PackedInt32Array = PackedInt32Array()


static func is_autotile(tile_id: int) -> bool:
	return tile_id >= FIRST_AUTOTILE_TILE and tile_id < FIRST_REGULAR_TILE
	
## Which of the seven autotile slots a tile id belongs to (or `-1`)
static func autotile_slot(tile_id: int) -> int:
	if not is_autotile(tile_id):
		return -1
	return (tile_id / AUTOTILE_VARIANTS) - 1
	
## The variant index within an autotile slot.
static func autotile_variant(tile_id: int) -> int:
	return tile_id % AUTOTILE_VARIANTS
	
## Position of a regular tile in the main tileset image
static func tile_atlas_coords(tile_id: int) -> Vector2i:
	var index: int = tile_id - FIRST_REGULAR_TILE
	return Vector2i(index % TILES_PER_ROW, index / TILES_PER_ROW)
	
func get_passage(tile_id: int) -> int:
	if tile_id < 0 or tile_id >= passages.size():
		return 0
	return passages[tile_id]
	
func get_priority(tile_id: int) -> int:
	if tile_id < 0 or tile_id >= priorities.size():
		return 0
	return priorities[tile_id]
	
func get_terrain_tag(tile_id: int) -> int:
	if tile_id < 0 or tile_id >= terrain_tags.size():
		return 0
	return terrain_tags[tile_id]
	
## Checks if movement is allowed entering from [param direction]
## Using the RPG Maker direction numbers (2 down, 4 left, 6 right, 8 up)
func blocks_direction(tile_id: int, direction: int) -> bool:
	var passage: int = get_passage(tile_id)
	match direction:
		2: return (passage & 0x01) != 0
		4: return (passage & 0x02) != 0
		6: return (passage & 0x04) != 0
		8: return (passage & 0x08) != 0
	return false
	
## Returns if a tile is walled off on all four sides, treated as outright impassable
func blocks_all_directions(tile_id: int) -> bool:
	return (get_passage(tile_id) & 0x0f) == 0x0f
	
func is_bush_tile(tile_id: int) -> bool:
	return(get_passage(tile_id) & 0x40) != 0

func is_counter_tile(tile_id: int) -> bool:
	return (get_passage(tile_id) & 0x80) != 0
