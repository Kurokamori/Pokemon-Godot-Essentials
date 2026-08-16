class_name ArrowTexture
## Draws the small triangles the message and choice windows point with.

enum Direction { UP, DOWN }

## Side of the square the arrow triangle is drawn
const BOX_SIZE: int = 16

## Width of the triangle within its square
const ARROW_WIDTH: int = 11
## Height of the triangle within its square
const ARROW_HEIGHT: int = 6


## One triangle, [param direction] pointing, in a [constant BOX_SIZE] square.
## [param offset] shifts it down the square, which is what makes it bob.
static func triangle(direction: Direction, colour: Color, offset: int = 0) -> ImageTexture:
	var image: Image = Image.create_empty(BOX_SIZE, BOX_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var left: int = (BOX_SIZE - ARROW_WIDTH) / 2
	var top: int = ((BOX_SIZE - ARROW_HEIGHT) / 2) + offset
	for row: int in range(ARROW_HEIGHT):
		var step: int = row if direction == Direction.DOWN else ARROW_HEIGHT - 1 - row
		var inset: int = int(round(float(step) * float(ARROW_WIDTH - 1) * 0.5 / float(ARROW_HEIGHT)))
		var y: int = top + row
		if y < 0 or y >= BOX_SIZE:
			continue
		for column: int in range(left + inset, left + ARROW_WIDTH - inset):
			image.set_pixel(column, y, colour)
	return ImageTexture.create_from_image(image)

## The four frames of the bobbing "press a button" arrow
static func bobbing_frames(colour: Color, bob: int = 2) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for offset: int in [0, 1, bob, 1]:
		frames.append(triangle(Direction.DOWN, colour, offset))
	return frames
