@tool
class_name TrainerCardPortrait extends TextureRect
## The player's sprite on a Trainer Card.

## It comes from their starting character choice, so adding more characters gets their art here too.

## The editor shows [member editor_preview_trainer] instead since no player exists during layout.

## Show back sprite — the battle-shoulder view — rather than front.
@export var back_sprite: bool = false:
	set(value):
		back_sprite = value
		_refresh()

## Trainer type shown by the editor while laying out a face.
@export var editor_preview_trainer: StringName = &"POKEMONTRAINER_Red":
	set(value):
		editor_preview_trainer = value
		_refresh()


func _ready():
	_refresh()

func bind_trainer_card():
	_refresh()

func _refresh():
	texture = Assets.trainer_sprite(_sprite_name())

## Sheet to draw.
## A back sprite appends "_back" like BattleFieldView names its art.
func _sprite_name() -> StringName:
	var trainer_type = editor_preview_trainer
	if not Engine.is_editor_hint() and GameState != null and GameState.player != null:
		trainer_type = GameState.player.trainer_type()
	if trainer_type.is_empty():
		return &""
	return StringName(String(trainer_type) + "_back") if back_sprite else trainer_type
