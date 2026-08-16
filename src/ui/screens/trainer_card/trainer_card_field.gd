@tool
class_name TrainerCardField extends Label
## One thing a Trainer Card says about the player, chosen in the inspector.

## The dropdown uses [constant TrainerCardFields.FIELDS], so adding a field there finds it without touching this script.

## In the editor the node shows its field name in angle brackets sized to the real text.

## What this label says.
## One name from [TrainerCardFields]. 
## Declared through _get_property_list instead of @export so the inspector sees the live list.
var field: StringName = &"":
	set(value):
		field = value
		_refresh_editor_preview()

## Prefix for the value, e.g. "No. ". 
## Empty if none.
@export var prefix: String = ""

## Suffix for the value, e.g. " steps". 
## Empty if none.
@export var suffix: String = ""

## Display when the field has nothing to say — outside a session or before the player does it.
@export var fallback: String = ""


func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "field",
		"type": TYPE_STRING_NAME,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": TrainerCardFields.hint_string(),
	}]

func _ready():
	if Engine.is_editor_hint():
		_refresh_editor_preview()

func _get_configuration_warnings() -> PackedStringArray:
	if field.is_empty():
		return ["Pick a field for this label to show."]
	if not TrainerCardFields.exists(field):
		return ["No Trainer Card field called '%s'." % field]
	return []

func bind_trainer_card():
	var written = TrainerCardFields.value(field)
	if written.is_empty():
		text = fallback
		return
	text = prefix + written + suffix

## Shows the editor preview instead of live text, for editor previews
func _refresh_editor_preview():
	if not Engine.is_editor_hint():
		return
	text = "<%s>" % field if not field.is_empty() else "<field>"
	update_configuration_warnings()
