@tool
class_name TypeData
extends GameDataResource

## A Pokemon type such as Fire or Water
##
## Matchups are expressed from the defending side
## [member weaknesses] lists all attacking types that deal double damage to this type.

## Row/Column that is used when drawing this type's icon
@export var icon_position: int = 0

## This is set to `true` to mark this type as 'Special' for the pre-Gen 4 proper split
@export var special_type: bool = false

## This marks this type as a psudo type which is used internally and hidden from the player
@export var pseudo_type: bool = false

@export_group("Defensive Matchups")
## Which attacking types deal double damage to this type
@export var weaknesses: Array[StringName] = []

## Which attacknig types deal half damage to this type
@export var resistances: Array[StringName] = []

## Attacking types that deal no damage to this type
@export var immunities: Array[StringName] = []


## Returns what the damage multiplier applied when this type is attacked by type [param attacking_type]
## Returns `0.0` `0.5` `1.0` `2.0`
func effectiveness_against_self(attacking_type: StringName) -> float:
	if immunities.has(attacking_type):
		return 0.0
	if weaknesses.has(attacking_type):
		return 2.0
	if resistances.has(attacking_type):
		return 0.5
	return 1.0
