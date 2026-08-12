@tool
class_name TrainerTypeData
extends GameDataResource

## A type of trainer such as Ace or Gym Leader

enum Gender {
	MALE = 0,
	FEMALE = 1,
	UNKNOWN = 2,
}

@export var gender: Gender = Gender.UNKNOWN

## Prize money is whatever this value is multiplied by the level of the last used Pokemon.
@export var base_money: int = 30

## The quality of the AI  from 0 (random) to 100 (always best decision)
@export_range(0, 100) var skill_level: int = 30

@export_group("Audio")
## Music played during the pre-battle
## Empty uses map default
@export var intro_bgm: String = ""
@export var battle_bgm: String = ""
@export var victory_bgm: String = ""
