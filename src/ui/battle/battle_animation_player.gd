class_name BattleAnimationPlayer
extends Control
## Plays a [BattleAnimationData] over the battlefield.

const FRAMES_PER_SECOND: float = BattleAnimationData.FRAMES_PER_SECOND

## How the sprites a cel can borrow are addressed.
class Actor extends RefCounted:
	var sprite: BattlerSprite = null
	
	var centre: Vector2 = Vector2.ZERO

	func _init(source: BattlerSprite = null) -> void:
		sprite = source
		if source != null:
			centre = source.centre_point()

var is_playing: bool = false

## What an animation's flashes and shakes are worked out by
var _effects: BattleAnimationEffects = BattleAnimationEffects.new()

## The rectangle a screen flash is painted on, and the field a shake moves.
var _screen_flash: ColorRect = null
var _field: BattleFieldView = null

## Pool of reusable cel sprites
var _cels: Array[Sprite2D] = []
var _sheet_frames: Array[AtlasTexture] = []



func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

## Plays [param animation] with [param user] attacking [param target]
func play(animation: BattleAnimationData, user: Actor, target: Actor) -> void:
	if animation == null or animation.frame_count() == 0:
		return
	is_playing = true
	_load_sheet(animation)
	_effects.begin(animation)
	var borrowed: Dictionary = {}
	for index: int in range(animation.frame_count()):
		_draw_frame(animation, index, user, target, borrowed)
		_play_sounds(animation, index)
		_effects.enter_frame(index)
		_apply_effects(user, target)
		await get_tree().create_timer(1.0 / FRAMES_PER_SECOND).timeout
		_effects.advance()
	while _effects.is_busy():
		_apply_effects(user, target)
		await get_tree().create_timer(1.0 / FRAMES_PER_SECOND).timeout
		_effects.advance()
	_clear_effects(user, target)
	_release_borrowed(borrowed)
	_hide_all_cels()
	is_playing = false

## The two things needed outside of reach
func use_screen(flash: ColorRect, field: BattleFieldView) -> void:
	_screen_flash = flash
	_field = field

## Plays the animation registered under [param id]
## Returns `false` if there isn't one
func play_by_id(id: StringName, user: Actor, target: Actor) -> bool:
	if not Database.has_record(Database.CATEGORY_BATTLE_ANIMATIONS, id):
		return false
	var animation: BattleAnimationData = Database.battle_animation(id)
	if animation == null:
		return false
	await play(animation, user, target)
	return true

func _load_sheet(animation: BattleAnimationData) -> void:
	_sheet_frames.clear()
	if animation.graphic.is_empty():
		return
	var sheet: Texture2D = Assets.texture(AssetIndex.CATEGORY_ANIMATIONS, animation.graphic)
	if sheet == null:
		sheet = Assets.texture(AssetIndex.CATEGORY_BATTLE_ANIMATIONS, animation.graphic)
	if sheet == null:
		return
	var cell: int = animation.cel_side_or_default()
	var columns: int = animation.sheet_columns_or_default(sheet.get_width())
	var rows: int = maxi(sheet.get_height() / cell, 1)
	for row: int in range(rows):
		for column: int in range(columns):
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(column * cell, row * cell), Vector2(cell, cell))
			frame.filter_clip = true
			_sheet_frames.append(frame)

func _draw_frame(animation: BattleAnimationData, index: int, user: Actor, target: Actor, borrowed: Dictionary) -> void:
	var count: int = animation.cel_count(index)
	var drawn: int = 0
	for cel: int in range(count):
		var pattern: int = int(animation.cel_field(index, cel, BattleAnimationData.CEL_PATTERN))
		if pattern < 0:
			var actor: Actor = user if pattern == BattleAnimationData.PATTERN_USER else target
			_apply_to_battler(animation, index, cel, actor, user, target, borrowed)
			continue
		_draw_picture(animation, index, cel, drawn, user, target)
		drawn += 1
	for spare: int in range(drawn, _cels.size()):
		_cels[spare].visible = false

## Moves one of the real battler sprites the way the animation says to
func _apply_to_battler(animation: BattleAnimationData, index: int, cel: int, actor: Actor, user: Actor, target: Actor, borrowed: Dictionary) -> void:
	if actor == null or actor.sprite == null:
		return
	if not borrowed.has(actor.sprite):
		borrowed[actor.sprite] = {
			"position": actor.sprite.position,
			"size_factor": actor.sprite.size_factor,
			"modulate": actor.sprite.modulate,
			"material": actor.sprite.material,
		}
	actor.sprite.size_factor = maxf(animation.cel_field(index, cel, BattleAnimationData.CEL_ZOOM_X) / 100.0, 0.01)
	actor.sprite.position = _restore_ground(actor, _place(animation, index, cel, user, target))
	var opacity: float = animation.cel_field(index, cel, BattleAnimationData.CEL_OPACITY) / 255.0
	actor.sprite.modulate = Color(1.0, 1.0, 1.0, clampf(opacity, 0.0, 1.0))
	BattleAnimationData.dress(actor.sprite,
		int(animation.cel_field(index, cel, BattleAnimationData.CEL_BLEND)),
		animation.cel_tone(index, cel))

## Turns a cel's centre point back into the ground point
func _restore_ground(actor: Actor, centre: Vector2) -> Vector2:
	var offset: Vector2 = actor.sprite.centre_point() - actor.sprite.position
	return centre - offset

func _draw_picture(animation: BattleAnimationData, index: int, cel: int, slot: int, user: Actor, target: Actor) -> void:
	var sprite: Sprite2D = _cel_sprite(slot)
	var pattern: int = int(animation.cel_field(index, cel, BattleAnimationData.CEL_PATTERN))
	if pattern < 0 or pattern >= _sheet_frames.size():
		sprite.visible = false
		return
	sprite.texture = _sheet_frames[pattern]
	sprite.visible = true
	sprite.position = _place(animation, index, cel, user, target)
	var zoom_x: float = animation.cel_field(index, cel, BattleAnimationData.CEL_ZOOM_X) / 100.0
	var zoom_y: float = animation.cel_field(index, cel, BattleAnimationData.CEL_ZOOM_Y) / 100.0
	if animation.cel_field(index, cel, BattleAnimationData.CEL_MIRROR) > 0.0:
		zoom_x = -zoom_x
	sprite.scale = Vector2(zoom_x, zoom_y)
	sprite.rotation = -deg_to_rad(animation.cel_field(index, cel, BattleAnimationData.CEL_ANGLE))
	var opacity: float = animation.cel_field(index, cel, BattleAnimationData.CEL_OPACITY) / 255.0
	sprite.modulate = Color(1.0, 1.0, 1.0, clampf(opacity, 0.0, 1.0))
	sprite.z_index = 1 if animation.cel_field(index, cel, BattleAnimationData.CEL_PRIORITY) > 0.0 else -1
	BattleAnimationData.dress(sprite,
		int(animation.cel_field(index, cel, BattleAnimationData.CEL_BLEND)),
		animation.cel_tone(index, cel))

## Where a cel drawn at its authored coordinates belongs on the real field
func _place(animation: BattleAnimationData, index: int, cel: int, user: Actor, target: Actor) -> Vector2:
	var drawn: Vector2 = Vector2(
		animation.cel_field(index, cel, BattleAnimationData.CEL_X),
		animation.cel_field(index, cel, BattleAnimationData.CEL_Y),
	)
	var focus: int = int(animation.cel_field(index, cel, BattleAnimationData.CEL_FOCUS))
	match focus:
		BattleAnimationData.FOCUS_USER:
			if user != null:
				return drawn + (user.centre - BattleAnimationData.AUTHORED_USER_POSITION)
		BattleAnimationData.FOCUS_TARGET:
			if target != null:
				return drawn + (target.centre - BattleAnimationData.AUTHORED_TARGET_POSITION)
		BattleAnimationData.FOCUS_USER_AND_TARGET:
			if user != null and target != null:
				return _between(drawn, user.centre, target.centre)
	return drawn

## Maps a point drawn between the authored attacker and target onto the line between the real ones
func _between(drawn: Vector2, user_centre: Vector2, target_centre: Vector2) -> Vector2:
	var authored: Vector2 = BattleAnimationData.AUTHORED_TARGET_POSITION - BattleAnimationData.AUTHORED_USER_POSITION
	var actual: Vector2 = target_centre - user_centre
	var authored_length: float = authored.length()
	if authored_length < 0.001:
		return drawn
	var relative: Vector2 = drawn - BattleAnimationData.AUTHORED_USER_POSITION
	var along: float = relative.dot(authored) / (authored_length * authored_length)
	var across: float = relative.cross(authored) / authored_length
	var direction: Vector2 = actual.normalized() if actual.length() > 0.001 else Vector2.RIGHT
	var perpendicular: Vector2 = Vector2(direction.y, -direction.x)
	return user_centre + direction * (along * actual.length()) + perpendicular * across

## Paints this frame's flashes and moves the field by this frame's shake
func _apply_effects(user: Actor, target: Actor) -> void:
	if _screen_flash != null:
		_screen_flash.color = _effects.tint_of(BattleAnimationData.FLASH_SCREEN)
	_tint_actor(user, _effects.tint_of(BattleAnimationData.FLASH_USER))
	_tint_actor(target, _effects.tint_of(BattleAnimationData.FLASH_TARGET))
	if target != null and target.sprite != null:
		target.sprite.set_hidden_by_animation(_effects.hides_target())
	if _field != null:
		_field.set_shake_offset(_effects.shake_offset())

## Puts everything an animation's effects touched back the way it was
func _clear_effects(user: Actor, target: Actor) -> void:
	if _screen_flash != null:
		_screen_flash.color = Color(0.0, 0.0, 0.0, 0.0)
	_tint_actor(user, Color(0.0, 0.0, 0.0, 0.0))
	_tint_actor(target, Color(0.0, 0.0, 0.0, 0.0))
	if target != null and target.sprite != null:
		target.sprite.set_hidden_by_animation(false)
	if _field != null:
		_field.set_shake_offset(Vector2.ZERO)

func _tint_actor(actor: Actor, tint: Color) -> void:
	if actor == null or actor.sprite == null or not is_instance_valid(actor.sprite):
		return
	actor.sprite.set_flash(tint)

func _play_sounds(animation: BattleAnimationData, index: int) -> void:
	for timing: int in range(animation.timing_frames.size()):
		if animation.timing_frames[timing] != index:
			continue
		AudioManager.play_se(
			animation.timing_sounds[timing],
			float(animation.timing_volumes[timing]) / 100.0,
			float(animation.timing_pitches[timing]) / 100.0,
		)

func _cel_sprite(slot: int) -> Sprite2D:
	while _cels.size() <= slot:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_cels.append(sprite)
	return _cels[slot]

func _hide_all_cels() -> void:
	for sprite: Sprite2D in _cels:
		sprite.visible = false

## Puts every sprite the animation borrowed back where it was
func _release_borrowed(borrowed: Dictionary) -> void:
	for sprite: Variant in borrowed:
		var battler_sprite: BattlerSprite = sprite as BattlerSprite
		if battler_sprite == null or not is_instance_valid(battler_sprite):
			continue
		var saved: Dictionary = borrowed[sprite]
		battler_sprite.position = saved["position"]
		battler_sprite.size_factor = saved["size_factor"]
		battler_sprite.modulate = saved["modulate"]
		battler_sprite.material = saved["material"]
