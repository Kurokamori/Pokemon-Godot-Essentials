@tool
class_name TownMapDecoration
extends Resource

## A graphic placed on top of the map
## Such as an island that only appears once the player knows about it

## Square that the graphic's top left corner sits on
@export var position: Vector2i = Vector2i.ZERO

## Image under `assets/graphics/ui/Town Map/`
## Omits extension
@export var graphic: String = ""

## Switch that controls whether or not this graphic is drawn.
## Must be ON for graphic to draw, `0` means it's always drawn.
##
## Wall maps / Display maps disregard this and instead show whether [member shown_on_wall_map]
@export var visibility_switch: int = 0

## Whether this decoration is drawn on a wall map / decoration map
@export var shown_on_wall_map: bool = false


## Decides whether this decoration should be drawn now
func is_visible(wall_map: bool) -> bool:
	if graphic.is_empty():
		return false
	if wall_map:
		return shown_on_wall_map
	return visibility_switch <= 0 or GameState.get_switch(visibility_switch)
