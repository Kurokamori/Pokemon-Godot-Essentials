@tool
class_name EncounterSlot
extends Resource

## One wild Pokemon entry within an [EncounterData] table.

## Relative weight against the other slots of the same encounter type.
@export_range(1, 1000) var weight: int = 10

## The name of the species in this slot.
@export var species: StringName = &""

## Minimum level of the encounter.
@export_range(1, 100) var min_level: int = 5

## Maximum level of the encounter.
@export_range(1, 100) var max_level: int = 5

## Optional form override, `-1` means it is decided by the species handler.
@export_range(-1, 255) var form: int = -1


func roll_level(rng: RandomNumberGenerator) -> int:
	if max_level <= min_level:
		return min_level
	return rng.randi_range(min_level, max_level)
