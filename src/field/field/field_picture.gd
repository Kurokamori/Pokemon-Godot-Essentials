class_name FieldPicture
extends Sprite2D
## One of the numbered pictures an imported event draws over the map.

const SCENE_PATH: String = "res://scenes/field/field_picture.tscn"

## Origin `0` puts the picture's top-left corner on its position; `1` puts its middle there.
const ORIGIN_TOP_LEFT: int = 0
const ORIGIN_CENTRE: int = 1

## Blend modes, as RPG Maker numbers them.
const BLEND_NORMAL: int = 0
const BLEND_ADD: int = 1
const BLEND_SUBTRACT: int = 2

## Frames a second the commands' durations are quoted in.
const FRAMES_PER_SECOND: float = 60.0

## Degrees one unit of Rotate Picture's speed turns the picture each frame.
const DEGREES_PER_ROTATION_SPEED: float = 2.0

## The picture number this node is drawn for, which is how an event addresses it.

var number: int = 0

## Degrees a second the picture is spinning, from Rotate Picture.

var rotation_speed: float = 0.0

## Cancels an earlier move when a new one starts.

var _move_tween: Tween = null
## The tween running a Change Picture Tone, kept for the same reason.

var _tone_tween: Tween = null
## The tint the picture is drawn with, before its opacity is applied.

var _tone: Color = Color.WHITE

func _process(delta: float) -> void:
	if is_zero_approx(rotation_speed):
		return
	rotation += deg_to_rad(rotation_speed * delta)

## Draws [param picture_name] from the `pictures` asset category and puts it where Show Picture says.
func show_graphic(
	picture_name: String,
	origin: int,
	screen_position: Vector2,
	zoom: Vector2,
	opacity: int,
	blend: int
) -> bool:
	_cancel_tweens()
	rotation = 0.0
	rotation_speed = 0.0
	_tone = Color.WHITE
	texture = Assets.texture(AssetIndex.CATEGORY_PICTURES, picture_name)
	if texture == null:
		visible = false
		return false
	visible = true
	set_origin(origin)
	place(screen_position, zoom, opacity)
	set_blend(blend)
	return true

## Places the picture immediately with the given zoom and opacity.
func place(screen_position: Vector2, zoom: Vector2, opacity: int) -> void:
	position = screen_position
	scale = zoom / 100.0
	_apply_opacity(opacity)

## Slides the picture to a new position, zoom and opacity over [param frames], which is Move Picture.
func move_to(
	screen_position: Vector2,
	zoom: Vector2,
	opacity: int,
	blend: int,
	frames: int
) -> void:
	_cancel_move()
	set_blend(blend)
	if frames <= 0:
		place(screen_position, zoom, opacity)
		return
	var seconds: float = float(frames) / FRAMES_PER_SECOND
	var target: Color = _tone
	target.a = clampf(float(opacity) / 255.0, 0.0, 1.0)
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.tween_property(self, "position", screen_position, seconds)
	_move_tween.tween_property(self, "scale", zoom / 100.0, seconds)
	_move_tween.tween_property(self, "modulate", target, seconds)

## Starts or stops the picture spinning.
func set_rotation_speed(speed: float) -> void:
	# Anticlockwise in RPG Maker is a decreasing angle in Godot, whose y axis points the other way.
	rotation_speed = -speed * DEGREES_PER_ROTATION_SPEED * FRAMES_PER_SECOND

## Tints the picture over [param frames], which is Change Picture Tone.
func change_tone(tone: Color, frames: int) -> void:
	_cancel_tone()
	var target: Color = tone
	target.a = modulate.a
	if frames <= 0:
		_tone = tone
		modulate = target
		return
	_tone = tone
	_tone_tween = create_tween()
	_tone_tween.tween_property(self, "modulate", target, float(frames) / FRAMES_PER_SECOND)

func set_origin(origin: int) -> void:
	centered = origin == ORIGIN_CENTRE

func set_blend(blend: int) -> void:
	match blend:
		BLEND_ADD:
			material = _blend_material(CanvasItemMaterial.BLEND_MODE_ADD)
		BLEND_SUBTRACT:
			material = _blend_material(CanvasItemMaterial.BLEND_MODE_SUB)
		_:
			material = null

## Takes the picture off screen and puts it back in the pool unused.
func clear() -> void:
	_cancel_tweens()
	number = 0
	texture = null
	visible = false
	rotation = 0.0
	rotation_speed = 0.0
	material = null
	_tone = Color.WHITE
	modulate = Color.WHITE

func _apply_opacity(opacity: int) -> void:
	var colour: Color = _tone
	colour.a = clampf(float(opacity) / 255.0, 0.0, 1.0)
	modulate = colour

static func _blend_material(mode: CanvasItemMaterial.BlendMode) -> CanvasItemMaterial:
	var blend_material: CanvasItemMaterial = CanvasItemMaterial.new()
	blend_material.blend_mode = mode
	return blend_material

func _cancel_tweens() -> void:
	_cancel_move()
	_cancel_tone()

func _cancel_move() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null

func _cancel_tone() -> void:
	if _tone_tween != null and _tone_tween.is_valid():
		_tone_tween.kill()
	_tone_tween = null
