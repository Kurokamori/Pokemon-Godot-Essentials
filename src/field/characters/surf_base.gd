@tool
class_name SurfBase
extends Sprite2D
## What the player rides when surfing or diving

const SURF_SHEET: String = "base_surf"
const DIVE_SHEET: String = "base_dive"

const BOB_SECONDS: float = 1.5
const BOB_HEIGHT: int = 2
const BOB_FRAMES: int = 4

## Bob frames at or above which the rider is up rather than down
const BOB_RISEN_FRAME: int = 2

## How far down the surf base graphic sits relative to the rider's own cell
const VERTICAL_OFFSET: int = 16

var _elapsed: float = 0.0

var _frame: int = 0


func _ready() -> void:
	centered = false
	region_enabled = true
	visible = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_elapsed = fmod(_elapsed + delta, BOB_SECONDS)
	_frame = int(float(BOB_FRAMES) * _elapsed / BOB_SECONDS) % BOB_FRAMES
	refresh()

func bob_height() -> int:
	return BOB_HEIGHT if visible and _frame >= BOB_RISEN_FRAME else 0

func bob_frame() -> int:
	return _frame

## Redraws the base for where the player is and which way they are facing
func refresh() -> void:
	var sheet: String = _sheet_for_state()
	if sheet.is_empty():
		visible = false
		return
	var art: Texture2D = GridCharacter.charset_texture(sheet)
	if art == null:
		visible = false
		return
	visible = true
	texture = art
	var size: Vector2i = Vector2i(
		art.get_width() / BOB_FRAMES, art.get_height() / GridCharacter.DIRECTION_ROWS.size())
	var rider: GridCharacter = get_parent() as GridCharacter
	var row: int = 0
	if rider != null:
		row = int(GridCharacter.DIRECTION_ROWS.get(rider.facing, 0))
	region_rect = Rect2(Vector2(_frame * size.x, row * size.y), size)
	offset = Vector2(
		float(MapGrid.TILE_SIZE - size.x) / 2.0,
		float(MapGrid.TILE_SIZE - size.y + VERTICAL_OFFSET))


## Which base graphic is needed
func _sheet_for_state() -> String:
	if GameState == null:
		return ""
	if GameState.is_diving():
		return DIVE_SHEET
	if GameState.is_surfing():
		return SURF_SHEET
	return ""
