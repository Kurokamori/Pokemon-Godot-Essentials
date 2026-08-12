@tool
class_name StatData
extends GameDataResource

## A Pokemon stat.
## Covers both the base 6 persistent stats (hp/attack/defense/sp. attack/ sp. defense/speed)
## As well as the battle only stats (accuracy and evasion)

enum StatType{
	## HP -- Has a value but no battle stat stage.
	MAIN = 0,
	## Attack/Defense/Sp.Attack/Sp.Defense/Speed -- has a value and a battle stat stage.
	MAIN_BATTLE = 1,
	## Accuracy and Evasion -- stat stage only.
	BATTLE = 2,
}

@export var type: StatType = StatType.MAIN_BATTLE

## Abreviation used in tight / narrow UI layouts
@export var name_brief: String = ""

## The order that these stats orginally appeared in the PBS files.
# TODO: Do I still need this?
@export var pbs_order: int = -1


## When the stat has a numeric value on a Pokemon
func is_persistent() -> bool:
	return type == StatType.MAIN or type == StatType.MAIN_BATTLE
	
## When the stat can be raised or lowered in battle.
func has_stat_stages() -> bool:
	return type == StatType.MAIN_BATTLE or type == StatType.BATTLE
	
## The abbreviated stat name, translated to the player's language.
func get_translated_name_brief() -> String: 
	if name_brief.is_empty():
		return get_translated_name()
	return translate_field(name_brief)
