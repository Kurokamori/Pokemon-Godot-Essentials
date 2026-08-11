@tool
class_name GrowthRateData
extends GameDataResource

## expierence curve (stored as a precomputed table.)

## Total expierence needed to reach each level.
## Index 0 is unused, and holds `-1`
## Intex 1 holds `0`.
@export var exp_values: PackedInt32Array = PackedInt32Array()


## Total expierence required to be at a given level ( [param level] )
func minimum_exp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	if level >= exp_values.size():
		return exp_values[exp_values.size() - 1]
	return exp_values[level]
	
## The level a Pokemon with [param exp] total experience.
func level_from_exp(experience: int) -> int:
	var max_level: int = exp_values.size() - 1
	for level: int in range(1, max_level + 1):
		if experience < exp_values[level]:
			return level - 1
	return max_level
	
## Experience still needed to reach the next level, or `0` at the cap.
func exp_to_next_level(experience: int) -> int:
	var level: int = level_from_exp(experience)
	if level >= exp_values.size() - 1:
		return 0
	return exp_values[level + 1] - experience
	
	
## Progress through the current level, in the range 0.0 to 1.0.
func level_progress(experience: int) -> float:
	var level: int = level_from_exp(experience)
	if level >= exp_values.size() - 1:
		return 1.0
	var start: int = exp_values[level]
	var finish: int = exp_values[level + 1]
	if finish <= start:
		return 1.0
	return clampf(float(experience - start) / float(finish - start), 0.0, 1.0)
	
func maximum_level() -> int:
	return exp_values.size() - 1
