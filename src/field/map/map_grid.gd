@tool
class_name MapGrid
## The tile grid every overworld scene is laid out on.
## Positions on the map are managed as cells rather than pixels, everything must be able to convert between the two.

## Side of one tile in pixels.
## This has to be set independant of the Game Settings because the autoload cannot be read in editor, and would return 0
# TODO: Check if there's a way to fix this.
const TILE_SIZE: int = 32

const DIRECTION_VECTORS: Dictionary = {
	2: Vector2i(0, 1),
	4: Vector2i(-1, 0),
	6: Vector2i(1, 0),
	8: Vector2i(0, -1),
}


static func cell_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)

## The centre of [param cell]
static func cell_centre(cell: Vector2i) -> Vector2:
	return cell_to_pixel(cell) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5

## The cell containing [param pixel]. 
## Negative coords foor away from zero, so anything left of origin is `-1`
static func pixel_to_cell(pixel: Vector2) -> Vector2i:
	return Vector2i(floori(pixel.x / float(TILE_SIZE)), floori(pixel.y / float(TILE_SIZE)))

## Snaps [param pixel] to the top-left corner of the cell that contains it.
static func snap(pixel: Vector2) -> Vector2:
	return cell_to_pixel(pixel_to_cell(pixel))

static func direction_vector(direction: int) -> Vector2i:
	return DIRECTION_VECTORS.get(direction, Vector2i.ZERO)

static func opposite_direction(direction: int) -> int:
	match direction:
		2: return 8
		8: return 2
		4: return 6
		6: return 4
	return 2

## Reports a mismatch between editor constant tile size and the settings resource setting so that runtime errors can be caught.
static func verify_settings() -> void:
	if Engine.is_editor_hint():
		return
	if GameSettings.data == null or GameSettings.data.tile_size == TILE_SIZE:
		return
	push_error("MapGrid: game_settings.tres says tiles are %d px but maps are laid out on a %d px grid." % [
		GameSettings.data.tile_size, TILE_SIZE,
	])
