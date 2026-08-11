@tool
class_name DungeonTilesetData
extends GameDataResource

## Maps the abstract tile roles used by the dungeon generator onto concrete tile ids in a tileset.
## The record id is the tileset number.

@export var tileset_id: int = 0

@export_group("Layout Rules")

@export var snap_to_large_grid: bool = false

@export var large_void_tiles: bool = false

@export var large_wall_tiles: bool = false

@export var large_floor_tiles: bool = false

## Walls are two tiles rather than one.
@export var double_walls: bool = true

@export var floor_patch_under_walls: bool = true

@export var thin_north_wall_offset: int = 0

## Maps a role name such as a `floor`, `void` or `wall_1` to an array of `[tile_id, is_wall]` pairs the generator may choose between.
@export var tile_type_ids: Dictionary = {}


## Returns the candiate tile ids registered for [param role].
func get_tiles_for(role: StringName) -> Array:
	if not tile_type_ids.has(role):
		return []
	return tile_type_ids[role]
