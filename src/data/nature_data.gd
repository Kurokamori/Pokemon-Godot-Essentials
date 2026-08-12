@tool
class_name NatureData
extends GameDataResource

## Defines a nature and its Stat Multiplier.

## Percentage modifiers are keyed by stat id.
## Example : {&"ATTACK": 10, &"DEFENSE": -10}
## Empty dictionary means that it's a neutral nature.
@export var stat_changes: Dictionary = {}

## Returns the multiplier which is applied to [param stat]
func get_stat_multiplier(stat: StringName) -> float:
	if not stat_changes.has(stat):
		return 1.0
	return 1.0 + (float(stat_changes[stat]) / 100)
	
func is_neutral() -> bool:
	return stat_changes.is_empty()
	
## The stat that this nature raises, or an empty [StringName]
func get_raised_stat() -> StringName:
	for stat: StringName in stat_changes:
		if int(stat_changes[stat]) > 0:
			return stat
	return &""
	
## The stat that this nature lowers, or an empty [StringName]
func get_lowered_stat() -> StringName:
	for stat: StringName in stat_changes:
		if int(stat_changes[stat]) < 0:
			return stat
	return &""
