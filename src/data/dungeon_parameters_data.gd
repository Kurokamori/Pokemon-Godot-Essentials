@tool
class_name DungeonParametersData
extends Resource

## Layout rules for one style of procedurally generated dungeons.
## Each dungeon is laid out as a grid of cells -- each cell may contain a room,
## rooms are joined by corridors.

## Area name this parameter set belongs to, e.g. &"cave"
@export var area: StringName = &""

## Dungeon version.
@export var version: int = 0


@export_group("Grid")
## How many cells across horizontal
@export_range(1, 32) var cell_count_x: int = 5

## How many cells down vertical
@export_range(1, 32) var cell_count_y: int = 4

## Size of the cells horizontally
@export_range(4, 64) var cell_width: int = 10

## Size of the cells vertically
@export_range(4, 64) var cell_height: int = 10


@export_group("Rooms")
## the minimum width of a room.
@export_range(1, 64) var room_min_width: int = 5

## The minimum height of a room.
@export_range(1, 64) var room_min_height: int = 5

## The maximum width of a room.
@export_range(1, 64) var room_max_width: int = 9

## The maximum height of a room.
@export_range(1, 64) var room_max_height: int = 9

## Percentage chance that a given cell contains a room.
@export_range(0, 100) var room_chance: int = 70

## How rooms are distributed across the grid, such as full / outskirts
@export var room_layout: StringName = &"full"


@export_group("Corridors")
@export_range(1, 16) var corridor_width: int = 2

## Allows corridors to be offset from teh centre of a cell.
@export var random_corridor_shift: bool = true

## How cells are connected, e.g. full/branches
@export var node_layout: StringName = &"full"

#Extra connections added after the spanning tree (creating loops)
@export_range(0, 32) var extra_connections_count: int = 2


@export_group("Decorations")
@export_range(0, 32) var floor_patch_radius: int = 2
@export_range(0, 100) var floor_patch_chance: int = 50
@export_range(0, 100) var floor_patch_smooth_rate: int = 25
@export var floor_decoration_density: int = 50
@export var floor_decoration_large_density: int = 200
@export var void_decoration_density: int = 50
@export var void_decoration_large_density: int = 200

## Fixed seed for reporducible layouts. `0` uses a random seed.
@export var rng_seed: int = 0
