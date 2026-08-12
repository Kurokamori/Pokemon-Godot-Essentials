@tool
class_name MoveData
extends GameDataResource

## A move definition.
## The behaviour attached to [member function_code] is implemented in [MoveEffects]
## Everything here is inert data.

enum Category {
	PHYSICAL = 0,
	SPECIAL = 1,
	STATUS = 2,
}

@export var type: StringName = &"NORMAL"
@export var category: Category = Category.STATUS

## Base power.
## `0` for status moves.
## `1` for moves with variable power.
@export_range(0, 999) var power: int = 0

## Acuracy percentage.
## `0` means the move never misses.
@export_range(0, 100) var accuracy: int = 100

## Maximum PP before PP Ups.
## `0` means that the move has unlimited PP. 
## (Used by struggle and the like)
@export_range(0, 99) var total_pp: int = 5

## ID of a [TargetData] record describing who this move can target.
@export var target: StringName = &"NearOther"

@export_range(-8, 8) var priority: int = 0

## Selects the effect implementation registered in [MoveEffects]
@export var function_code: StringName = &"None"

## Percentage chance of the move's secondary effect being activated.
## `0` means the effect is either guaranteed or handled by the effect implementation.
@export_range(0, 100) var effect_chance: int = 0

@export_multiline var description: String = ""


## Check Functions

func is_physical() -> bool:
	return category == Category.PHYSICAL
	
func is_special() -> bool:
	return category == Category.SPECIAL
	
func is_status() -> bool:
	return category == Category.STATUS
	
func is_damaging() -> bool:
	return category != Category.STATUS
	

func makes_contact() -> bool:
	return has_flag(&"Contact")
	
func is_sound_move() -> bool:
	return has_flag(&"Sound")
	
func is_punching_move() -> bool:
	return has_flag(&"Punching")
	
func is_biting_move() -> bool:
	return has_flag(&"Biting")
	
func is_pulse_move() -> bool:
	return has_flag(&"Pulse")
	
func is_bomb_move() -> bool:
	return has_flag(&"Bomb")
	
func is_powder_move() -> bool:
	return has_flag(&"Powder")
	
func is_dance_move() -> bool:
	return has_flag(&"Dance")
	
func is_healing_move() -> bool:
	return has_flag(&"Healing")
	
func is_recharging_move() -> bool:
	return has_flag(&"Recharging")
	
func can_be_protected_against() -> bool:
	return has_flag(&"CanProtect")
	
func can_be_magic_coated() -> bool:
	return has_flag(&"CanMagicCoat")
	
func can_be_snatched() -> bool:
	return has_flag(&"CanSnatch")
	
func can_be_mirrored() -> bool:
	return has_flag(&"CanMirrorMove")
	
func is_high_crit_move() -> bool:
	return has_flag(&"HighCritcalHitRate")
	
func always_crits() -> bool:
	return has_flag(&"AlwaysCriticalHit")
	
func ignores_substitute() -> bool:
	return has_flag(&"IgnoreSubstitute")
	
func thaws_user() -> bool:
	return has_flag(&"ThawsUser")
	

## The move description in the player's langauge.
func get_translated_description() -> String:
	return translate_field(description)
