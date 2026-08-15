@tool
class_name MysteryGiftData
extends GameDataResource

## One Mystery Gift
##
## There's currently no HTTPS/Online delivery service for mystery gifts, so currently
## mystery gifts are ported locally and stored in the game data, and accessed through the PC
## 
## The record id is the gift number as text, so it can be called either by:
## `pbReceiveMysteryGift(3)`
## or `Database.mystery_gift(3)`
## And they refer to the same thing.
##
## TODO: Add proper network support for mystery gifts.

## The mystery gift number
@export var gift_id: int = 0

## What the player is actually told they received
@export_multiline var description: String = ""

## Items given to the player by this mystery gift
## An array of resources (item_id, quanitity) pairs kept as resources for easier editting
@export var items: Array[MysteryGiftItem] = []

## The Pokemon given by the gift (if there is one)
## Left empty if the Mystery Gift is only items
@export var species: StringName = &""

## The Level of the Pokemon given by the gift (if there is one)
## Left empty if the Mystery Gift is only items
@export_range(1, 255) var level: int = 5

## The nickname of the Pokemon given to you by the gift if there is one,
## Leaving it empty provides the Pokemon unnamed, and the player is able to name it like any other
@export var nickname: String = ""

## Item the gifted pokemon is holding if there is one and it's holding something,
## Left empty for no held item or no Pokemon
@export var held_item: StringName = &""

## The Ribbon of the Pokemon given by the gift, if there is one and it has a ribbon,
@export var ribbon: StringName = &""


## Creates the record id or the Mystery Gift [param number]
static func make_id(number: int) -> StringName:
	return StringName(str(number))
	
## Returns `true` if this Mystery Gift contains a Pokemon
func gives_pokemon() -> bool:
	return not species.is_empty() and Database.has_record(Database.CATEGORY_SPECIES, species)
	
## Creates the Pokemon this game hands over
## Returns `null` if this Mystery Gift is only items
func build_pokemon(owner: PokemonOwner) -> Pokemon:
	if not gives_pokemon():
		return null
	var pokemon: Pokemon = Pokemon.create(species, level, owner)
	if not nickname.is_empty():
		pokemon.nickname = nickname
	if not held_item.is_empty():
		pokemon.held_item = held_item
	if not ribbon.is_empty():
		pokemon.give_ribbon(ribbon)
	pokemon.obtain_method = Pokemon.ObtainMethod.FATEFUL_ENCOUNTER
	pokemon.obtain_text = display_name
	return pokemon
	
func get_translated_description() -> String:
	return translate_field(description)
