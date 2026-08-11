@tool
class_name AbilityData
extends GameDataResource

## A Pokemon Ability.
## Behaviour libes in [AbilityEffects];
## This record is only the presentation data and flags.

@export_multiline("Ability Description") var description: String = ""

## The ability description in the player's language.
func get_translated_name() -> String:
	return translate_field(description)
