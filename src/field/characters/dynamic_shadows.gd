class_name DynamicShadows
extends Node2D
## The shadows a charcter/entity casts

const Z_INDEX: int = -1

## `opacity = self_opactiy * 13000 / ((distance_squared * 370 / distance_max) + 6000)` on a scale of 0-255
const FALLOFF_NUMERATOR: float = 13000.0
const FALLOFF_SCALE: float = 370.0
const FALLOFF_FLOOR: float = 6000.0

const ALPHA_SCALE: float = 255.0

## Bellow this the shadow simply doesn't draw, because why would it
const MINIMUM_ALPHA: float = 0.02

const SHADOW_COLOUR: Color = Color(0.04, 0.04, 0.08)

const BACK_FACING_DEGREES: float = 90.0

## What row the shadow uses for the corresponding character row
const FLIPPED_ROWS: Dictionary = {
	GridCharacter.Direction.DOWN: GridCharacter.Direction.UP,
	GridCharacter.Direction.UP: GridCharacter.Direction.DOWN,
	GridCharacter.Direction.LEFT: GridCharacter.Direction.RIGHT,
	GridCharacter.Direction.RIGHT: GridCharacter.Direction.LEFT,
}

var _caster: GridCharacter = null

var _sprites: Array[Sprite2D] = []



func _ready() -> void:
	z_index = Z_INDEX
	_caster = get_parent() as GridCharacter
	set_process(false)
	
func refresh(sources: Array[ShadowSource]) -> void:
	if _caster == null or not _caster.visible:
		_hide_from(0)
		return
	var sprite: Sprite2D = _caster.get_node_or_null(
		NodePath(GridCharacter.SPRITE_NODE_NAME)) as Sprite2D
	if sprite == null or sprite.texture == null:
		_hide_from(0)
		return
	var feet: Vector2 = _feet_position()
	var used: int = 0
	for source: ShadowSource in sources:
		if not source.is_lit() or source.event == _caster:
			continue
		var cast_shadow: Sprite2D = _shadow_for(used, sprite, source, feet)
		if cast_shadow != null:
			used += 1
	_hide_from(used)
	
# === Internals ===

func _feet_position() -> Vector2:
	return _caster.global_position + Vector2(
		float(MapGrid.TILE_SIZE) * 0.5, float(MapGrid.TILE_SIZE))
		
func _shadow_for(index: int, sprite: Sprite2D, source: ShadowSource,
		feet: Vector2) -> Sprite2D:
	var to_light: Vector2 = source.light_position() - feet
	if to_light.length() > source.distance_max:
		return null
	var alpha: float = _alpha_for(to_light, source)
	if alpha < MINIMUM_ALPHA:
		return null
	var rotation_radians: float = atan2(-to_light.x, to_light.y)
	if not _within_arc(rotation_radians, source):
		return null
	var cast_shadow: Sprite2D = _sprite_at(index)
	var frame: Vector2i = _caster.frame_size()
	cast_shadow.texture = sprite.texture
	cast_shadow.region_enabled = sprite.region_enabled
	cast_shadow.region_rect = _region_for(sprite, frame, rotation_radians)
	cast_shadow.modulate = Color(SHADOW_COLOUR, alpha)
	cast_shadow.offset = Vector2(-float(frame.x) * 0.5, -float(frame.y))
	cast_shadow.position = Vector2(float(MapGrid.TILE_SIZE) * 0.5, float(MapGrid.TILE_SIZE))
	cast_shadow.rotation = rotation_radians
	cast_shadow.visible = true
	return cast_shadow
	
func _alpha_for(to_light: Vector2, source: ShadowSource) -> float:
	if source.distance_max <= 0.0:
		return 0.0
	var distance_squared: float = to_light.length_squared()
	var denominator: float = (distance_squared * FALLOFF_SCALE / source.distance_max) + FALLOFF_FLOOR
	var opacity: float = source.opacity * FALLOFF_NUMERATOR / denominator
	return clampf(opacity / ALPHA_SCALE, 0.0, 1.0)
	
## Measured anti-clockwise from due right, the sprite's angle +90deg wrapped to 360
func _within_arc(rotation_radians: float, source: ShadowSource) -> bool:
	if is_zero_approx(source.angle_min) and is_zero_approx(source.angle_max):
		return true
	var trigonometric: float = fposmod(-rad_to_deg(rotation_radians) + 90.0, 360.0)
	if source.angle_min < source.angle_max:
		return trigonometric >= source.angle_min and trigonometric <= source.angle_max
	return trigonometric >= source.angle_min or trigonometric <= source.angle_max
	
## The part of the character sheet the shadow's frame shows
func _region_for(sprite: Sprite2D, frame: Vector2i, rotation_radians: float) -> Rect2:
	var region: Rect2 = sprite.region_rect
	if absf(rad_to_deg(rotation_radians)) <= BACK_FACING_DEGREES:
		return region
	var flipped: GridCharacter.Direction = FLIPPED_ROWS.get(
		_caster.facing, _caster.facing) as GridCharacter.Direction
	var row: int = int(GridCharacter.DIRECTION_ROWS.get(flipped, 0))
	return Rect2(Vector2(region.position.x, float(row * frame.y)), region.size)
	
## Shadow [param index], made if this character has not needed it yet
func _sprite_at(index: int) -> Sprite2D:
	while _sprites.size() <= index:
		var made: Sprite2D = Sprite2D.new()
		made.name = "CastShadow%d" % _sprites.size()
		made.centered = false
		made.visible = false
		add_child(made)
		_sprites.append(made)
	return _sprites[index]

## Hides every shadow from [param index] on
func _hide_from(index: int) -> void:
	for slot: int in range(index, _sprites.size()):
		_sprites[slot].visible = false
