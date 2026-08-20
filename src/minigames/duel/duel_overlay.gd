class_name DuelOverlay
extends Control
## The two health bars a duel is fought with

@onready var _player_panel: PanelContainer = %PlayerPanel
@onready var _opponent_panel: PanelContainer = %OpponentPanel
@onready var _player_name_label: Label = %PlayerNameLabel
@onready var _opponent_name_label: Label = %OpponentNameLabel
@onready var _player_health_label: Label = %PlayerHealthLabel
@onready var _opponent_health_label: Label = %OpponentHealthLabel
@onready var _player_health_bar: ProgressBar = %PlayerHealthBar
@onready var _opponent_health_bar: ProgressBar = %OpponentHealthBar
@onready var _player_portrait: TextureRect = %PlayerPortrait
@onready var _opponent_portrait: TextureRect = %OpponentPortrait
@onready var _flash: ColorRect = %Flash

var _maximum_health: int = 10



## Sets up both health bars
func begin(
	player_name: String, opponent_name: String, maximum_health: int,
	player_sprite: Texture2D, opponent_sprite: Texture2D
) -> void:
	_maximum_health = maxi(maximum_health, 1)
	_player_name_label.text = player_name
	_opponent_name_label.text = opponent_name
	_player_portrait.texture = player_sprite
	_player_portrait.visible = player_sprite != null
	_opponent_portrait.texture = opponent_sprite
	_opponent_portrait.visible = opponent_sprite != null
	for bar: ProgressBar in [_player_health_bar, _opponent_health_bar]:
		bar.max_value = float(_maximum_health)
		bar.value = float(_maximum_health)
	show_health(_maximum_health, _maximum_health)
	_flash.color.a = 0.0
	_player_panel.visible = true
	_opponent_panel.visible = true

func show_health(player_health: int, opponent_health: int) -> void:
	_player_health_bar.value = float(clampi(player_health, 0, _maximum_health))
	_opponent_health_bar.value = float(clampi(opponent_health, 0, _maximum_health))
	_player_health_label.text = "HP %d" % maxi(player_health, 0)
	_opponent_health_label.text = "HP %d" % maxi(opponent_health, 0)

func flash(seconds: float, colour: Color = Color.WHITE) -> void:
	if seconds <= 0.0:
		return
	_flash.color = Color(colour.r, colour.g, colour.b, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", 0.75, seconds * 0.5)
	tween.tween_property(_flash, "color:a", 0.0, seconds * 0.5)
	await tween.finished
