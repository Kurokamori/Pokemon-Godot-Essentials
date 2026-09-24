class_name FieldPictures
## The way an event reaches the numbered pictures drawn over the map.

## The layer the overworld is drawing pictures on, or `null` outside it.
static func layer() -> PictureLayer:
	var overworld: Overworld = Overworld.current
	return overworld.picture_layer() if overworld != null else null

## Draws [param picture_name] as picture [param number].
static func show(
	number: int,
	picture_name: String,
	origin: int = FieldPicture.ORIGIN_TOP_LEFT,
	screen_position: Vector2 = Vector2.ZERO,
	zoom: Vector2 = Vector2(100.0, 100.0),
	opacity: int = 255,
	blend: int = FieldPicture.BLEND_NORMAL
) -> void:
	var pictures: PictureLayer = layer()
	if pictures != null:
		pictures.show_picture(number, picture_name, origin, screen_position, zoom, opacity, blend)

## Slides picture [param number] to a new position, zoom and opacity over [param frames].
static func move(
	number: int,
	frames: int,
	origin: int = FieldPicture.ORIGIN_TOP_LEFT,
	screen_position: Vector2 = Vector2.ZERO,
	zoom: Vector2 = Vector2(100.0, 100.0),
	opacity: int = 255,
	blend: int = FieldPicture.BLEND_NORMAL
) -> void:
	var pictures: PictureLayer = layer()
	if pictures != null:
		pictures.move_picture(number, frames, origin, screen_position, zoom, opacity, blend)

## Spins picture [param number] at RPG Maker's rotation speed, or stops it with a speed of zero.
static func rotate(number: int, speed: float) -> void:
	var pictures: PictureLayer = layer()
	if pictures != null:
		pictures.rotate_picture(number, speed)

## Tints picture [param number] over [param frames].
static func tone(number: int, colour: Color, frames: int) -> void:
	var pictures: PictureLayer = layer()
	if pictures != null:
		pictures.tone_picture(number, colour, frames)

static func erase(number: int) -> void:
	var pictures: PictureLayer = layer()
	if pictures != null:
		pictures.erase_picture(number)

## Takes every picture off screen.
static func erase_all() -> void:
	var pictures: PictureLayer = layer()
	if pictures != null:
		pictures.erase_all()

## How many pictures are on screen right now.
static func shown_count() -> int:
	var pictures: PictureLayer = layer()
	return pictures.shown_count() if pictures != null else 0
