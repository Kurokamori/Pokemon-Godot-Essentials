class_name SpriteSheetIcon
extends TextureRect
## A texture, drawn one frame at a time, from a horizontal sprite sheet.
## [method Assets.sprite_sheet_frames] slices the spritesheet.
## An icon remains on its first frame unless [method set_animating] is enabled.

## Seconds a frame is held while animating
const DEFAULT_FRAME_SECONDS: float = 0.5

## How long a given frame is held in a spritesheet if not the default of 0.5s
@export var frame_seconds: float = DEFAULT_FRAME_SECONDS

var _frames: Array[AtlasTexture] = []
var _frame_index: int = 0
var _elapsed: float = 0.0
var _animating: bool = false

func _ready() -> void:
	_update_processing()

func _process(delta: float) -> void:
	if frame_seconds <= 0.0:
		return
	_elapsed += delta
	if _elapsed < frame_seconds:
		return
	_elapsed -= frame_seconds
	_show_frame((_frame_index + 1) % _frames.size())

# === Contents ===

## Shows [param sheet], remaining on its first frame.
## Passing `null` clears the sprite.
func set_sheet(sheet: Texture2D) -> void:
	_frames = Assets.sprite_sheet_frames(sheet)
	_elapsed = 0.0
	_show_frame(0)
	_update_processing()

## Clears the icon and stops all animations.
func clear_icon() -> void:
	set_animating(false)
	set_sheet(null)

## Returns the size of one frame, or `Vector2.ZERO` when no sheet is loaded.
func frame_size() -> Vector2:
	return _frames[0].get_size() if not _frames.is_empty() else Vector2.ZERO

func frame_count() -> int:
	return _frames.size()

# === Animation ===

## Starts or stops a frame cycle.
## Stopping returns the resting frame instead of leaving the icon mid-animation.
func set_animating(value: bool) -> void:
	if _animating == value:
		return
	_animating = value
	_elapsed = 0.0
	if not value:
		_show_frame(0)
	_update_processing()

func is_animating() -> bool:
	return _animating

# === Internals ===

func _show_frame(index: int) -> void:
	_frame_index = index
	texture = _frames[index] if index < _frames.size() else null

func _update_processing() -> void:
	set_process(_animating and _frames.size() > 1)
