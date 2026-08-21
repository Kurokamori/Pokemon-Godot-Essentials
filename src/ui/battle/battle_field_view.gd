class_name BattleFieldView
extends Control
## Draws the visual battlefield

const FIELD_SIZE: Vector2 = Vector2(512.0, 384.0)

## The middle of each side's platform
const PLAYER_BASE_POSITION: Vector2 = Vector2(128.0, 304.0)
const FOE_BASE_POSITION: Vector2 = Vector2(384.0, 176.0)

## How far a battle position stands from the middle of its side's platform
const BATTLER_OFFSETS: Array[Array] = [
	[Vector2.ZERO, Vector2.ZERO],
	[Vector2(-48.0, 0.0), Vector2(48.0, 0.0), Vector2(32.0, 16.0), Vector2(-32.0, -16.0)],
	[
		Vector2(-80.0, 0.0), Vector2(80.0, 0.0), Vector2(0.0, 8.0),
		Vector2(0.0, -8.0), Vector2(80.0, 16.0), Vector2(-80.0, -16.0),
	],
]

##  How far a battle position stands from the middle of its side's platform, for the trainers standing behind their Pokemon. 
const TRAINER_OFFSETS: Array[Array] = [
	[Vector2.ZERO, Vector2.ZERO],
	[Vector2(-48.0, 0.0), Vector2(48.0, 0.0), Vector2(32.0, 0.0), Vector2(-32.0, -16.0)],
	[
		Vector2(-80.0, 0.0), Vector2(80.0, 0.0), Vector2(0.0, 0.0),
		Vector2(0.0, -8.0), Vector2(80.0, 0.0), Vector2(-80.0, -16.0),
	],
]

const PLAYER_TRAINER_POSITION: Vector2 = Vector2(128.0, 288.0)
const FOE_TRAINER_POSITION: Vector2 = Vector2(384.0, 182.0)

## Top left corner of each side's first info panel
const FOE_PANEL_POSITION: Vector2 = Vector2(8.0, 36.0)
const PLAYER_PANEL_POSITION: Vector2 = Vector2(312.0, 192.0)

## How far a panel sits from the first one on its side, indexed the same way as [constant BATTLER_OFFSETS]
const PANEL_OFFSETS: Array[Array] = [
	[Vector2.ZERO, Vector2.ZERO],
	[Vector2(-12.0, -20.0), Vector2(12.0, -34.0), Vector2(0.0, 34.0), Vector2(0.0, 20.0)],
	[
		Vector2(-12.0, -42.0), Vector2(12.0, -46.0), Vector2(-6.0, 4.0),
		Vector2(6.0, 0.0), Vector2(0.0, 50.0), Vector2(0.0, 46.0),
	],
]

## Gap left between the row of Poke Balls and the panels it sits beside.
const PANEL_GAP: float = 4.0
const PANEL_WIDTH: float = 192.0

## Size of one frame of a trainer's back sprite sheet, which holds the throwing animation.
const TRAINER_BACK_FRAME: int = 160

const SCENE_PATH: String = "res://scenes/battle/battle_field_view.tscn"

var battle: Battle = null

@onready var _backdrop: TextureRect = %Backdrop
@onready var _foe_base: TextureRect = %FoeBase
@onready var _player_base: TextureRect = %PlayerBase
@onready var _behind_layer: Control = %BehindLayer
@onready var _sprite_layer: Control = %SpriteLayer
@onready var _panel_layer: Control = %PanelLayer
@onready var _flash_layer: ColorRect = %FlashLayer
@onready var _animation_player: BattleAnimationPlayer = %AnimationPlayer
var _resting_position: Vector2 = Vector2.ZERO
var _shaking: bool = false

## Battler sprites indexed by battle position.
var _sprites: Array[BattlerSprite] = []

## Info panels indexed by battle position.
var _panels: Array[BattlerInfoPanel] = []

## Trainer sprites: the player's own at index 0, then one per opposing trainer.
var _trainers: Array[TextureRect] = []

## The row of Poke Balls for each side.
var _party_bars: Array[BattlePartyBar] = []

const INFO_PANEL_SCENE: PackedScene = preload("res://scenes/battle/battler_info_panel.tscn")



func _ready() -> void:
	_animation_player.use_screen(_flash_layer, self)

func set_shake_offset(offset: Vector2) -> void:
	if offset == Vector2.ZERO:
		if _shaking:
			position = _resting_position
			_shaking = false
		return
	if not _shaking:
		_resting_position = position
		_shaking = true
	position = _resting_position + offset

## Builds the sprites and panels for [param source]'s field
func build(source: Battle) -> void:
	battle = source
	_load_backdrop()
	for slot: int in range(battle.battlers_per_side * 2):
		var sprite: BattlerSprite = BattlerSprite.new()
		sprite.position = position_of(slot)
		_sprite_layer.add_child(sprite)
		_sprites.append(sprite)
		var panel: BattlerInfoPanel = INFO_PANEL_SCENE.instantiate()
		panel.show_hp_numbers = slot % 2 == 0 and battle.battlers_per_side == 1
		_panel_layer.add_child(panel)
		_panels.append(panel)
	_build_party_bars()
	refresh()

## Builds the rows of pokeballs displaying how many mons each side has
func _build_party_bars() -> void:
	for side: int in range(2):
		var bar: BattlePartyBar = BattlePartyBar.new()
		bar.reversed = side == 1
		bar.visible = (not battle.opponent_trainers.is_empty()) if side == 1 			else not battle.is_safari_battle()
		_panel_layer.add_child(bar)
		_party_bars.append(bar)

## The ground point battle position [param slot] stands on
func position_of(slot: int) -> Vector2:
	var anchor: Vector2 = FOE_BASE_POSITION if slot % 2 == 1 else PLAYER_BASE_POSITION
	var per_side: int = clampi(battle.battlers_per_side if battle != null else 1, 1, 3)
	return anchor + _offset_from(BATTLER_OFFSETS[per_side - 1], slot)

func _offset_from(table: Array, index: int) -> Vector2:
	return table[index] if index >= 0 and index < table.size() else Vector2.ZERO

func _lay_out_panels() -> void:
	@warning_ignore("integer_division")
	var per_side: int = clampi(_panels.size() / 2, 1, 3)
	var offsets: Array = PANEL_OFFSETS[per_side - 1]
	var foe_bottom: float = FOE_PANEL_POSITION.y
	var player_top: float = PLAYER_PANEL_POSITION.y
	for slot: int in range(_panels.size()):
		var panel: BattlerInfoPanel = _panels[slot]
		_size_panel(panel)
		var on_foe_side: bool = slot % 2 == 1
		var anchor: Vector2 = FOE_PANEL_POSITION if on_foe_side else PLAYER_PANEL_POSITION
		panel.position = anchor + _offset_from(offsets, slot)
		if on_foe_side:
			foe_bottom = maxf(foe_bottom, panel.position.y + panel.size.y)
		else:
			player_top = minf(player_top, panel.position.y)

	if _party_bars.size() > 1:
		_party_bars[1].position = Vector2(FOE_PANEL_POSITION.x, foe_bottom + PANEL_GAP)
	if not _party_bars.is_empty():
		var bar_height: float = _party_bars[0].get_combined_minimum_size().y
		_party_bars[0].position = Vector2(
			PLAYER_PANEL_POSITION.x, player_top - bar_height - PANEL_GAP)

## Gives a panel a definite size as nothing technically lays it out
func _size_panel(panel: BattlerInfoPanel) -> void:
	panel.size = Vector2(PANEL_WIDTH, panel.get_combined_minimum_size().y)

func _load_backdrop() -> void:
	var record: EnvironmentData = Database.environment(battle.field.environment)
	var base_name: String = record.battle_base if record != null and not record.battle_base.is_empty() else "field"
	_backdrop.texture = _first_backdrop(_backdrop_candidates(base_name))
	_player_base.texture = _first_backdrop([base_name + "_base0", "field_base0"])
	_foe_base.texture = _first_backdrop([base_name + "_base1", "field_base1"])
	_place_base(_player_base, PLAYER_BASE_POSITION, 1.0)
	_place_base(_foe_base, FOE_BASE_POSITION, 0.5)

## The backdrops to try, from best on, in canonical order
func _backdrop_candidates(base_name: String) -> Array:
	var candidates: Array = []
	var override: String = GameState.battleback_override
	if not override.is_empty():
		candidates.append(override + "_bg")
		candidates.append(override)
	if GameState.is_surfing() or GameState.is_diving():
		candidates.append("water_bg")
	var metadata: MapMetadataData = GameState.current_map_metadata()
	if metadata != null and not metadata.battle_background.is_empty():
		candidates.append(metadata.battle_background + "_bg")
	candidates.append(base_name + "_bg")
	candidates.append("field_bg")
	return candidates

func _first_backdrop(candidates: Array) -> Texture2D:
	for candidate: String in candidates:
		if candidate.is_empty():
			continue
		var texture: Texture2D = Assets.texture(AssetIndex.CATEGORY_BATTLEBACKS, candidate)
		if texture != null:
			return texture
	return null

## Puts a platform under the middle of a side
func _place_base(node: TextureRect, ground: Vector2, vertical_anchor: float) -> void:
	if node.texture == null:
		node.visible = false
		return
	node.visible = true
	var size_of: Vector2 = node.texture.get_size()
	node.size = size_of
	node.position = ground - Vector2(size_of.x * 0.5, size_of.y * vertical_anchor)


# === Battlers ===

func refresh() -> void:
	if battle == null:
		return
	var player_side_hidden: bool = battle.is_safari_battle()
	for slot: int in range(_sprites.size()):
		var drawn: Battler = null if player_side_hidden and slot % 2 == 0 else battle.get_battler(slot)
		_sprites[slot].position = position_of(slot)
		_sprites[slot].bind(drawn, slot % 2 == 0)
		_panels[slot].bind(drawn)
		_panels[slot].visible = _panels[slot].visible and _sprites[slot].is_on_field()
	for side: int in range(_party_bars.size()):
		if _party_bars[side].visible:
			_party_bars[side].bind(battle.get_party(side), battle.get_side(side).seen_party_slots, side == 1)
	_lay_out_panels()

func play_send_out(battler: Battler, animated: bool) -> void:
	var sprite: BattlerSprite = sprite_for(battler)
	if sprite == null:
		return
	if animated:
		battler.pokemon.play_cry()
		await sprite.play_appear()
	else:
		sprite.reveal()
	var panel: BattlerInfoPanel = panel_for(battler)
	if panel != null:
		panel.bind(battler)

## Shows or hides the info panels and the rows of Poke Balls together
func set_panels_visible(shown: bool) -> void:
	_panel_layer.visible = shown

## How many positions the field was built with
func position_count() -> int:
	return _sprites.size()

## How many trainer sprites are currently on the field
func trainer_count() -> int:
	var total: int = 0
	for sprite: TextureRect in _trainers:
		if sprite != null and sprite.visible:
			total += 1
	return total

## The row of Poke Balls for [param side]
## Returns `null` when that side has none
func party_bar_for(side: int) -> BattlePartyBar:
	return _party_bars[side] if side >= 0 and side < _party_bars.size() else null

func sprite_for(battler: Battler) -> BattlerSprite:
	if battler == null or battler.index < 0 or battler.index >= _sprites.size():
		return null
	return _sprites[battler.index]

func panel_for(battler: Battler) -> BattlerInfoPanel:
	if battler == null or battler.index < 0 or battler.index >= _panels.size():
		return null
	return _panels[battler.index]

## An [BattleAnimationPlayer.Actor] for [param battler]
## `null` if not on screen
func actor_for(battler: Battler) -> BattleAnimationPlayer.Actor:
	var sprite: BattlerSprite = sprite_for(battler)
	return BattleAnimationPlayer.Actor.new(sprite) if sprite != null else null

## Plays the animation registered for [param move]
## With fallback to a generic lunge when there isn't one
func play_move_animation(user: Battler, targets: Array[Battler], move: MoveData) -> void:
	var target: Battler = targets[0] if not targets.is_empty() else user
	var played: bool = false
	if move != null:
		var opposing: bool = not user.is_player_side()
		if opposing:
			played = await _animation_player.play_by_id(
				BattleAnimationData.id_for_move(move.id, true), actor_for(user), actor_for(target))
		if not played:
			played = await _animation_player.play_by_id(
				BattleAnimationData.id_for_move(move.id, false), actor_for(user), actor_for(target))
	if not played:
		await sprite_for(user).play_lunge()
	for hit: Battler in targets:
		var sprite: BattlerSprite = sprite_for(hit)
		if sprite != null:
			sprite.play_hit()
	if not targets.is_empty():
		await get_tree().create_timer(0.16).timeout

func play_common_animation(animation_name: StringName, battler: Battler) -> void:
	var actor: BattleAnimationPlayer.Actor = actor_for(battler)
	await _animation_player.play_by_id(BattleAnimationData.id_for_common(animation_name), actor, actor)


# === Trainers ===

## Shows the trainer standing on [param side], if there is one to show
func show_trainer(side: int) -> void:
	if side == 0:
		_place_trainer(0, _back_frame(_player_back_sheet(), 0), trainer_position_of(0, 0, 1))
		return
	if battle == null:
		return
	var count: int = battle.opponent_trainers.size()
	for index: int in range(count):
		_place_trainer(index + 1,
			Assets.trainer_sprite(battle.opponent_trainers[index].trainer_type),
			trainer_position_of(1, index, count))

## The ground point trainer [param index] of [param side] stands on
## With account for the proper [param count]
func trainer_position_of(side: int, index: int, count: int) -> Vector2:
	var anchor: Vector2 = FOE_TRAINER_POSITION if side == 1 else PLAYER_TRAINER_POSITION
	var offsets: Array = TRAINER_OFFSETS[clampi(count, 1, 3) - 1]
	return anchor + _offset_from(offsets, index * 2 + side)

## Puts one trainer sprite on the field, standing on [param ground]
func _place_trainer(slot: int, texture: Texture2D, ground: Vector2) -> void:
	if texture == null:
		return
	while _trainers.size() <= slot:
		_trainers.append(null)
	var sprite: TextureRect = _trainers[slot]
	if sprite == null:
		sprite = TextureRect.new()
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_behind_layer.add_child(sprite)
		_trainers[slot] = sprite
	sprite.texture = texture
	sprite.visible = true
	var drawn: Vector2 = texture.get_size()
	sprite.size = drawn
	sprite.position = ground - Vector2(drawn.x * 0.5, drawn.y)

func _player_back_sheet() -> Texture2D:
	var trainer_type: StringName = GameState.player.trainer_type() if GameState != null and GameState.player != null else &""
	if trainer_type.is_empty():
		return null
	return Assets.trainer_sprite(StringName(String(trainer_type) + "_back"))

func _back_frame(sheet: Texture2D, index: int) -> Texture2D:
	if sheet == null:
		return null
	var frame_width: int = TRAINER_BACK_FRAME
	if sheet.get_height() > 0:
		frame_width = sheet.get_height()
	@warning_ignore("integer_division")
	var count: int = maxi(sheet.get_width() / frame_width, 1)
	var frame: AtlasTexture = AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(Vector2(float(clampi(index, 0, count - 1) * frame_width), 0.0),
		Vector2(float(frame_width), float(sheet.get_height())))
	frame.filter_clip = true
	return frame

## Runs the player's throwing animation, then slides them off the left
func play_player_throw() -> void:
	var sprite: TextureRect = _trainers[0] if not _trainers.is_empty() else null
	if sprite == null or not sprite.visible:
		return
	var sheet: Texture2D = _player_back_sheet()
	if sheet != null:
		for frame: int in range(1, 5):
			sprite.texture = _back_frame(sheet, frame)
			await get_tree().create_timer(0.07).timeout
	await hide_trainer(0)

## Slides every trainer on [param side] off the screen.
func hide_trainer(side: int) -> void:
	var moving: Array[TextureRect] = []
	for slot: int in range(_trainers.size()):
		var sprite: TextureRect = _trainers[slot]
		if sprite == null or not sprite.visible:
			continue
		if (slot == 0) != (side == 0):
			continue
		moving.append(sprite)
	if moving.is_empty():
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for sprite: TextureRect in moving:
		tween.tween_property(sprite, "position:x",
			-sprite.size.x if side == 0 else FIELD_SIZE.x, 0.28)
	await tween.finished
	for sprite: TextureRect in moving:
		sprite.visible = false
