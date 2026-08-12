@tool
class_name RibbonData
extends GameDataResource

## A ribbon which can be awarded to a Pokemon.

## Index that places the ribbon on the ribbon sprite sheet
@export var icon_position: int = 0

@export_multiline var description: String = ""


## The ribbon description in the player's langauge.
func get_translated_description() -> String:
	return translate_field(description)
