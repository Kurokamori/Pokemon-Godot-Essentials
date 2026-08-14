@tool
class_name PokemonMail
extends Resource

## A letter which is attached to a held Mail Item.

@export var item: StringName = &""
@export_multiline var message: String = ""
@export var sender: String = ""

## The up to three pokemon whos icons decorate this mail letter - Pokemon 1
@export var poke1: StringName = &""
## The up to three pokemon whos icons decorate this mail letter - Pokemon 2
@export var poke2: StringName = &""
## The up to three pokemon whos icons decorate this mail letter - Pokemon 3
@export var poke3: StringName = &""

static func create(item_id: StringName, text: String, sender_name: String) -> PokemonMail:
	var letter: PokemonMail = PokemonMail.new()
	letter.item = item_id
	letter.message = text
	letter.sender = sender_name
	return letter
	
func to_dict() -> Dictionary:
	return {
		"item": String(item),
		"message": message,
		"sender": sender,
		"poke1": String(poke1),
		"poke2": String(poke2),
		"poke3": String(poke3),
	}


static func from_dict(source: Dictionary) -> PokemonMail:
	var letter: PokemonMail = PokemonMail.new()
	letter.item = StringName(source.get("item", ""))
	letter.message = String(source.get("message", ""))
	letter.sender = String(source.get("sender", ""))
	letter.poke1 = StringName(source.get("poke1", ""))
	letter.poke2 = StringName(source.get("poke2", ""))
	letter.poke3 = StringName(source.get("poke3", ""))
	return letter
