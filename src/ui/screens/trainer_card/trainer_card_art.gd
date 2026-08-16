@tool
class_name TrainerCardArt extends TextureRect
## A picture on a Trainer Card that depends on who the player is.

## The card itself, backdrop, and decorations are all this node. 
## It names a graphic and optionally a female variant. 
## An empty name leaves the node empty rather than failing.

## The picture loads in the editor too, so a face can be laid out over the real card instead of guessing.

## Graphic under `assets/graphics/ui/`, without its extension.
@export var graphic: String = "":
	set(value):
		graphic = value
		_refresh()

## Female variant graphic. 
## Empty means use [member graphic] for everyone.
@export var female_graphic: String = "":
	set(value):
		female_graphic = value
		_refresh()

## Version the editor shows while laying out a face.
@export var editor_shows_female: bool = false:
	set(value):
		editor_shows_female = value
		_refresh()

func _ready():
	_refresh()

func _get_configuration_warnings() -> PackedStringArray:
	if graphic.is_empty():
		return ["Name a graphic under assets/graphics/ui/."]
	if Assets.texture(AssetIndex.CATEGORY_UI, graphic) == null:
		return ["No graphic found under assets/graphics/ui/ named '%s'." % graphic]
	return []

func bind_trainer_card():
	_refresh()

func _refresh():
	var female = editor_shows_female if Engine.is_editor_hint() else _player_is_female()
	var wanted = female_graphic if female and not female_graphic.is_empty() else graphic
	texture = Assets.texture(AssetIndex.CATEGORY_UI, wanted) if not wanted.is_empty() else null
	if Engine.is_editor_hint():
		update_configuration_warnings()

static func _player_is_female() -> bool:
	return GameState != null and GameState.player != null and GameState.player.is_female()
