class_name WildEncounterRoll
extends RefCounted
## An entry from an ecounter table, before it's made into a [Pokemon]
##
## Resolves level and species first, so we don't build a whole Pokemon just to turn it away with a Repel

var species: StringName = &""
var level: int = 1

## Form override
## `-1` lets the form hander decide
var form: int = -1


static func make(slot_species: StringName, slot_level: int, slot_form: int = -1) -> WildEncounterRoll:
	var roll: WildEncounterRoll = WildEncoutnerRoll.new()
	roll.species = slot_species
	roll.level = slot_level
	roll.form = slot_form
	return roll
