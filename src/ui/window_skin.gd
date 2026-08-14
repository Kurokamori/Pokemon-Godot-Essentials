class_name WindowSkin
extends RefCounted
## Creates a Godot Stylebox out of the Essentials graphics
##
## The body is measured from the images as not all images are centred 16x16 block.
##
## Loaded skins are cached by asset name

## What layout the source image uses, for backwards compatibility.
enum Format {
	## 192x128 or 128x128 sheet with separate background and frame blocks.
	RPG_MAKER,
	## Any other size, using the Essentials layout.
	ESSENTIALS,
}

## RPG Maker frame corner size.
const RPG_CORNER: int = 16

## Size of the composited RPG Maker patch.
const RPG_PATCH_SIZE: int = RPG_CORNER * 4

## Default Essentials body size.
const ESSENTIALS_BODY: int = 16

## Selection cursor size and border in an RPG Maker sheet.
const CURSOR_SIZE: int = 32
const CURSOR_MARGIN: int = 2

## Maximum per-channel change accepted while measuring the body.
const CONTINUITY: float = 0.06

## Minimum border width accepted by the body measurement.
const MINIMUM_BORDER: int = 3

## Width and height of the body slice in a rebuilt Essentials patch.
const CENTRE_SLICE: int = 2

## Minimum content padding.
const MINIMUM_PADDING: int = 8

## Number of frames in the message-pause animation.
const PAUSE_FRAME_COUNT: int = 4
const PAUSE_FRAME_SIZE: int = 16

## Skins keyed by asset name.
static var _cache: Dictionary = {}

## Asset name this skin was loaded from.
var skin_name: String = ""
var format: Format = Format.ESSENTIALS
var source: Texture2D = null

var _panel_stylebox: StyleBoxTexture = null
var _cursor_stylebox: StyleBoxTexture = null
var _pause_frames: Array[AtlasTexture] = []

## X origin of the RPG Maker frame block: 128 normally, 64 for VX.
var _frame_origin: int = 128

## Nine-patch margins in source pixels: left, top, right, bottom.
var _margins: Vector4i = Vector4i(ESSENTIALS_BODY, ESSENTIALS_BODY, ESSENTIALS_BODY, ESSENTIALS_BODY)

## Measured body block in an Essentials-layout sheet.
var _body: Rect2i = Rect2i()


## Loads a windowskin by asset name, using the cache when possible.
static func load_skin(asset_name: String) -> WindowSkin:
	if asset_name.is_empty():
		return null
	var key: String = asset_name.to_lower()
	if _cache.has(key):
		return _cache[key]
	var texture: Texture2D = Assets.texture(AssetIndex.CATEGORY_WINDOWSKINS, asset_name)
	if texture == null:
		return null
	var skin: WindowSkin = WindowSkin.new()
	skin._setup(asset_name, texture)
	_cache[key] = skin
	return skin

## Builds a skin from an existing texture without using the asset index.
static func from_texture(texture: Texture2D, asset_name: String = "") -> WindowSkin:
	if texture == null:
		return null
	var skin: WindowSkin = WindowSkin.new()
	skin._setup(asset_name, texture)
	return skin

## Clears the decoded skin cache.
static func clear_cache() -> void:
	_cache.clear()

func _setup(asset_name: String, texture: Texture2D) -> void:
	skin_name = asset_name
	source = texture
	var size: Vector2i = texture.get_size()
	if size.x == 192 and size.y == 128:
		format = Format.RPG_MAKER
		_frame_origin = 128
		_margins = Vector4i(RPG_CORNER, RPG_CORNER, RPG_CORNER, RPG_CORNER)
	elif size.x == 128 and size.y == 128:
		format = Format.RPG_MAKER
		_frame_origin = 64
		_margins = Vector4i(RPG_CORNER, RPG_CORNER, RPG_CORNER, RPG_CORNER)
	else:
		format = Format.ESSENTIALS
		_measure_essentials_body(size)

## Measures the body in an Essentials-layout sheet and sets its margins.
##
## The default body is centered, but some skins use a larger or off-center body.
## The measured span avoids stretching a strip of the frame into the window interior.
## 
## Starting at the middle pixel, the span grows across the body and then vertically. 
## The test allows the gradients used by these frames.
##
## The narrower border is used on both sides to keep the rebuilt patch symmetrical.
##  Unreliable measurements fall back to the centered body.
func _measure_essentials_body(size: Vector2i) -> void:
	var formula_x: int = maxi((size.x - ESSENTIALS_BODY) / 2, 0)
	var formula_y: int = maxi((size.y - ESSENTIALS_BODY) / 2, 0)
	_margins = Vector4i(formula_x, formula_y, formula_x, formula_y)
	_body = Rect2i(formula_x, formula_y, ESSENTIALS_BODY, ESSENTIALS_BODY)

	var image: Image = _source_image()
	if image == null or size.x < 4 or size.y < 4:
		return
	var centre: Vector2i = size / 2
	var body_colour: Color = image.get_pixelv(centre)
	if body_colour.a < 1.0:
		return

	var left: int = centre.x
	var previous: Color = body_colour
	while left > 0 and _continues(image.get_pixel(left - 1, centre.y), previous):
		left -= 1
		previous = image.get_pixel(left, centre.y)
	var right: int = centre.x
	previous = body_colour
	while right < size.x - 1 and _continues(image.get_pixel(right + 1, centre.y), previous):
		right += 1
		previous = image.get_pixel(right, centre.y)

	var top: int = centre.y
	previous = body_colour
	while top > 0 and _row_continues(image, top - 1, left, right, previous):
		top -= 1
		previous = image.get_pixel(left, top)
	var bottom: int = centre.y
	previous = body_colour
	while bottom < size.y - 1 and _row_continues(image, bottom + 1, left, right, previous):
		bottom += 1
		previous = image.get_pixel(left, bottom)

	# Require a usable border and a non-empty body.
	var near: Vector2i = Vector2i(left, top)
	var far: Vector2i = Vector2i(size.x - 1 - right, size.y - 1 - bottom)
	if near.x < MINIMUM_BORDER or near.y < MINIMUM_BORDER:
		return
	if far.x < MINIMUM_BORDER or far.y < MINIMUM_BORDER:
		return
	if right - left < 1 or bottom - top < 1:
		return

	var border: Vector2i = Vector2i(mini(near.x, far.x), mini(near.y, far.y))
	_margins = Vector4i(border.x, border.y, border.x, border.y)
	_body = Rect2i(left, top, right - left + 1, bottom - top + 1)

## Returns whether a pixel continues the current surface.
##
## Gradients are allowed; sharp color changes mark a border.
func _continues(colour: Color, previous: Color) -> bool:
	if colour.a < 1.0:
		return false
	return maxf(maxf(absf(colour.r - previous.r), absf(colour.g - previous.g)),
			absf(colour.b - previous.b)) <= CONTINUITY

## Returns whether a row continues the body across the measured span.
##
## The row must also continue from the previous body color to avoid crossing into a solid border band.
func _row_continues(image: Image, y: int, from: int, to: int, previous: Color) -> bool:
	var first: Color = image.get_pixel(from, y)
	if not _continues(first, previous):
		return false
	for x: int in range(from + 1, to + 1):
		if not image.get_pixel(x, y).is_equal_approx(first):
			return false
	return true

## Returns the border margins in left, top, right, bottom order.
func border_margins() -> Vector4i:
	return _margins

## Returns the window stylebox.
func panel_stylebox() -> StyleBoxTexture:
	if _panel_stylebox == null:
		_panel_stylebox = _build_panel_stylebox()
	return _panel_stylebox

## Returns the window stylebox with additional content padding.
func panel_stylebox_with_padding(extra: Vector2i) -> StyleBoxTexture:
	var style: StyleBoxTexture = panel_stylebox().duplicate() as StyleBoxTexture
	_set_content_margins(style, extra)
	return style

## Applies content padding while enforcing the minimum gap.
func _set_content_margins(style: StyleBoxTexture, extra: Vector2i) -> void:
	style.content_margin_left = float(maxi(_margins.x + extra.x, MINIMUM_PADDING))
	style.content_margin_top = float(maxi(_margins.y + extra.y, MINIMUM_PADDING))
	style.content_margin_right = float(maxi(_margins.z + extra.x, MINIMUM_PADDING))
	style.content_margin_bottom = float(maxi(_margins.w + extra.y, MINIMUM_PADDING))

## Returns the RPG Maker selection cursor
## Returns null for Essentials skins
func cursor_stylebox() -> StyleBoxTexture:
	if format != Format.RPG_MAKER:
		return null
	if _cursor_stylebox == null:
		_cursor_stylebox = _build_cursor_stylebox()
	return _cursor_stylebox

## Returns the RPG Maker message-pause frames
## Otherwise returns an empty `Array`
func pause_frames() -> Array[AtlasTexture]:
	if format != Format.RPG_MAKER:
		return []
	if _pause_frames.is_empty():
		_pause_frames = _build_pause_frames()
	return _pause_frames

func has_cursor() -> bool:
	return format == Format.RPG_MAKER

# === Construction ===

func _build_panel_stylebox() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	if format == Format.RPG_MAKER:
		style.texture = _composite_rpg_maker_patch()
		style.region_rect = Rect2(0, 0, RPG_PATCH_SIZE, RPG_PATCH_SIZE)
		# Both the frame and its background scale with the window.
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	else:
		style.texture = _composite_essentials_patch()
		style.region_rect = Rect2(Vector2.ZERO, style.texture.get_size())
		# Stretch gradients to avoid seams between repeated tiles.
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.texture_margin_left = float(_margins.x)
	style.texture_margin_top = float(_margins.y)
	style.texture_margin_right = float(_margins.z)
	style.texture_margin_bottom = float(_margins.w)
	_set_content_margins(style, Vector2i.ZERO)
	return style

## Composites an RPG Maker background and frame into a nine-patchable image.
func _composite_rpg_maker_patch() -> ImageTexture:
	var sheet: Image = _source_image()
	if sheet == null:
		return null
	var background_size: int = _frame_origin
	var background: Image = sheet.get_region(Rect2i(0, 0, background_size, background_size))
	background.resize(RPG_PATCH_SIZE, RPG_PATCH_SIZE, Image.INTERPOLATE_BILINEAR)

	var patch: Image = Image.create_empty(RPG_PATCH_SIZE, RPG_PATCH_SIZE, false, Image.FORMAT_RGBA8)
	patch.blit_rect(background, Rect2i(0, 0, RPG_PATCH_SIZE, RPG_PATCH_SIZE), Vector2i.ZERO)

	# VX includes a tiled overlay that sits below the frame.
	if background_size == 64:
		var blinds: Image = sheet.get_region(Rect2i(0, 64, 64, 64))
		_tile_over(patch, blinds)

	var frame: Image = sheet.get_region(Rect2i(_frame_origin, 0, 64, 64))
	_blend_frame(patch, frame)
	return ImageTexture.create_from_image(patch)

## Rebuilds an Essentials-layout sheet as a tight nine-patch.
## Edges are sampled beside the measured body span.
func _composite_essentials_patch() -> ImageTexture:
	var image: Image = _source_image()
	if image == null:
		return null
	var size: Vector2i = image.get_size()
	var near: Vector2i = Vector2i(_margins.x, _margins.y)
	var far: Vector2i = Vector2i(_margins.z, _margins.w)
	var patch_size: Vector2i = near + far + Vector2i(CENTRE_SLICE, CENTRE_SLICE)
	var patch: Image = Image.create_empty(patch_size.x, patch_size.y, false, Image.FORMAT_RGBA8)
	patch.fill(Color.TRANSPARENT)

	var body_centre: Vector2i = _body.position + (_body.size / 2)
	var slice: Vector2i = Vector2i(CENTRE_SLICE, CENTRE_SLICE)
	var right_edge: int = size.x - far.x
	var bottom_edge: int = size.y - far.y
	var patch_right: int = near.x + CENTRE_SLICE
	var patch_bottom: int = near.y + CENTRE_SLICE

	# Copy the corners without scaling.
	patch.blit_rect(image, Rect2i(0, 0, near.x, near.y), Vector2i.ZERO)
	patch.blit_rect(image, Rect2i(right_edge, 0, far.x, near.y), Vector2i(patch_right, 0))
	patch.blit_rect(image, Rect2i(0, bottom_edge, near.x, far.y), Vector2i(0, patch_bottom))
	patch.blit_rect(image, Rect2i(right_edge, bottom_edge, far.x, far.y), Vector2i(patch_right, patch_bottom))

	# Copy edge slices beside the body.
	patch.blit_rect(image, Rect2i(body_centre.x, 0, CENTRE_SLICE, near.y), Vector2i(near.x, 0))
	patch.blit_rect(image, Rect2i(body_centre.x, bottom_edge, CENTRE_SLICE, far.y), Vector2i(near.x, patch_bottom))
	patch.blit_rect(image, Rect2i(0, body_centre.y, near.x, CENTRE_SLICE), Vector2i(0, near.y))
	patch.blit_rect(image, Rect2i(right_edge, body_centre.y, far.x, CENTRE_SLICE), Vector2i(patch_right, near.y))

	# Keep a small body slice for the stretchable center.
	patch.blit_rect(image, Rect2i(body_centre, slice), near)
	return ImageTexture.create_from_image(patch)

## Draws a 64x64 RPG Maker frame onto the patch.
func _blend_frame(patch: Image, frame: Image) -> void:
	var far: int = RPG_PATCH_SIZE - RPG_CORNER
	var span: int = RPG_PATCH_SIZE - (RPG_CORNER * 2)

	var top: Image = frame.get_region(Rect2i(16, 0, 32, 16))
	top.resize(span, RPG_CORNER, Image.INTERPOLATE_NEAREST)
	patch.blend_rect(top, Rect2i(0, 0, span, RPG_CORNER), Vector2i(RPG_CORNER, 0))

	var bottom: Image = frame.get_region(Rect2i(16, 48, 32, 16))
	bottom.resize(span, RPG_CORNER, Image.INTERPOLATE_NEAREST)
	patch.blend_rect(bottom, Rect2i(0, 0, span, RPG_CORNER), Vector2i(RPG_CORNER, far))

	var left: Image = frame.get_region(Rect2i(0, 16, 16, 32))
	left.resize(RPG_CORNER, span, Image.INTERPOLATE_NEAREST)
	patch.blend_rect(left, Rect2i(0, 0, RPG_CORNER, span), Vector2i(0, RPG_CORNER))

	var right: Image = frame.get_region(Rect2i(48, 16, 16, 32))
	right.resize(RPG_CORNER, span, Image.INTERPOLATE_NEAREST)
	patch.blend_rect(right, Rect2i(0, 0, RPG_CORNER, span), Vector2i(far, RPG_CORNER))

	var corner_rect: Rect2i = Rect2i(0, 0, RPG_CORNER, RPG_CORNER)
	patch.blend_rect(frame.get_region(Rect2i(0, 0, 16, 16)), corner_rect, Vector2i(0, 0))
	patch.blend_rect(frame.get_region(Rect2i(48, 0, 16, 16)), corner_rect, Vector2i(far, 0))
	patch.blend_rect(frame.get_region(Rect2i(0, 48, 16, 16)), corner_rect, Vector2i(0, far))
	patch.blend_rect(frame.get_region(Rect2i(48, 48, 16, 16)), corner_rect, Vector2i(far, far))

## Tiles [param tile] across [param target].
func _tile_over(target: Image, tile: Image) -> void:
	var tile_size: Vector2i = tile.get_size()
	if tile_size.x <= 0 or tile_size.y <= 0:
		return
	var y: int = 0
	while y < target.get_height():
		var x: int = 0
		while x < target.get_width():
			target.blend_rect(tile, Rect2i(Vector2i.ZERO, tile_size), Vector2i(x, y))
			x += tile_size.x
		y += tile_size.y

func _build_cursor_stylebox() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = source
	style.region_rect = Rect2(float(_frame_origin), 64.0, float(CURSOR_SIZE), float(CURSOR_SIZE))
	style.texture_margin_left = float(CURSOR_MARGIN)
	style.texture_margin_right = float(CURSOR_MARGIN)
	style.texture_margin_top = float(CURSOR_MARGIN)
	style.texture_margin_bottom = float(CURSOR_MARGIN)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style

func _build_pause_frames() -> Array[AtlasTexture]:
	var frames: Array[AtlasTexture] = []
	var origins: Array[Vector2i] = [
		Vector2i(_frame_origin + 32, 64),
		Vector2i(_frame_origin + 48, 64),
		Vector2i(_frame_origin + 32, 80),
		Vector2i(_frame_origin + 48, 80),
	]
	for index: int in range(PAUSE_FRAME_COUNT):
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = source
		frame.region = Rect2(
			Vector2(origins[index]),
			Vector2(PAUSE_FRAME_SIZE, PAUSE_FRAME_SIZE),
		)
		frames.append(frame)
	return frames

## Returns a writable RGBA copy of the skin image for compositing.
func _source_image() -> Image:
	var image: Image = source.get_image()
	if image == null:
		push_warning("WindowSkin: '%s' has no readable image data." % skin_name)
		return null
	image = image.duplicate() as Image
	if image.is_compressed():
		if image.decompress() != OK:
			push_warning("WindowSkin: '%s' could not be decompressed." % skin_name)
			return null
	image.convert(Image.FORMAT_RGBA8)
	return image
