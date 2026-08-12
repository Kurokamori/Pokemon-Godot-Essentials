@tool
class_name TrainerData
extends GameDataResource

## A specific trainer battle roster.

## ID of a [TrainerTypeData] record
@export var trainer_type: StringName = &""

## Version used for telling apart alternate teams and rematches
@export var version: int = 0

## Items that this trainer uses during battle, one entry per item use
@export var items: Array[StringName] = []

## Text played on loss
@export_multiline var lose_text: String = ""

@export var pokemon: Array[TrainerPokemon] = []

## Builds the record ID for looking up the trainer, using the triple (trainer type, name, version)
static func make_id(type_id: StringName, trainer_name: String, trainer_version: int) -> StringName:
	return StringName("%s|%s|%d" % [type_id, trainer_name, trainer_version])
	
## Translated loss text in the player's language
func get_translated_lose_text() -> String:
	return translate_field(lose_text)
