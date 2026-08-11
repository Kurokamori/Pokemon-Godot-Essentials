@tool
class_name GenderRatioData
extends GameDataResource

## How likely a species is to be female.

## Chance out of 256 of being female.
## `-1` marks a genderless species.
@export_range(-1, 256) var female_chance: int = 128

## `true` for species that are always male.
@export var always_male: bool = false

## `true` for species that are always female.
@export var always_female: bool = false

## `true` for species that have no gender.
@export var genderless: bool = false


func is_single_gendered() -> bool:
	return always_male or always_female or genderless
