@tool
class_name ItemData
extends GameDataResource

## Any bag item.
## Usage behaviour is registered in [ItemEffects]

enum FieldUse {
	NONE = 0,
	ON_POKEMON = 1,
	DIRECT = 2,
	TM = 3,
	HM = 4,
	TR = 5,
}

enum BattleUse {
	NONE = 0,
	ON_POKEMON = 1,
	ON_MOVE = 2,
	ON_BATTLER = 3,
	ON_FOE = 4,
	DIRECT = 5,
}


## The pluralized name of this item
@export var name_plural: String = ""

## Name used when the item is counted in portions (such as Berry for berries)
@export var portion_name: String = ""

## Plural portion name.
@export var portion_name_plural: String = ""

## 1-based bag pocket index.
## Further implemented in [BagPockets]
@export_range(1, 16) var pocket: int = 1

@export var price: int = 0
@export var sell_price: int = 0
@export var bp_price: int = 1

@export var field_use: FieldUse = FieldUse.NONE
@export var battle_use: BattleUse = BattleUse.NONE

## This is `true` when using the item would consume it.
@export var consumable: bool = true

## Set this to `true` when the bag should show the count for this item.
## Defaults to the opposite of the [method is_important] when left unset.
@export var show_quantity: bool = true

## The move taught by a TM/HM/TR, or the move called by an item such as a berry with a fixed move.
@export var move: StringName = &""

@export_multiline var description: String = ""


func is_tm() -> bool:
	return field_use == FieldUse.TM
	
func is_hm() -> bool:
	return field_use == FieldUse.HM
	
func is_tr() -> bool:
	return field_use == FieldUse.TR
	
func is_machine() -> bool:
	return is_hm() or is_tm() or is_tr()
	
func is_mail() -> bool:
	return has_flag(&"Mail") or has_flag(&"IconMail")
	
func is_poke_ball() -> bool:
	return has_flag(&"PokeBall") or has_flag(&"SnagBall")
	
func is_snag_ball() -> bool:
	return has_flag(&"SnagBall")
	
func is_berry() -> bool:
	return has_flag(&"Berry")
	
func is_key_item() -> bool:
	return has_flag(&"KeyItem")
	
func is_evolutiion_stone() -> bool:
	return has_flag(&"EvolutionStone")
	
func is_gem() -> bool:
	return has_flag(&"TypeGem")
	
func is_held_item() -> bool:
	return has_flag(&"Fling") or get_fling_power() > 0
	
## Defines that an item cannot be sold, tossed, or held.
func is_important() -> bool:
	return is_key_item() or is_hm() or is_tm()
	
func get_fling_power() -> int:
	var value: String = get_flag_value(&"FLing", "0")
	return int(value) if value.is_valid_int() else 0
	
## The type Natural Gift takes from this Berry
## From `NaturalGift_TYPE_POWER` flag.
## Empty when a berry has no Natural Gift entry.
func get_natural_gift_type() -> StringName:
	var value: String = get_flag_value(&"NaturalGift", "")
	var seperator: int = value.rfind("_")
	if seperator < 0:
		return StringName(value)
	return StringName(value.substr(0, seperator))
	
## The base power Natural Gift has with this Berry or `0` when it has none.
func get_natural_gift_power() -> int:
	var value: String = get_flag_value(&"NaturalGift", "")
	var seperator: int = value.rfind("_")
	if seperator < 0:
		return 0
	var power: String = value.substr(seperator + 1)
	return int(power) if power.is_valid_int() else 0
	
## Source-Language Name, sincular or plural to match [param quantity].
func get_display_name(quantity: int = 1) -> String:
	if quantity == 1 or name_plural.is_empty():
		return display_name
	return name_plural
	
## The name of the item in the player's selected singular or plural (Matching [param quantity] )
##
## Languages don't always have a clean singular/plural split
## TODO : Fix the fact that we have a bipolar split of plurality for langauges like Russian. How? Great question.
##
## Currently uses whatever plural is suplied irreverant of quantity.
func get_translated_display_name(quantity: int = 1) -> String:
	if quantity == 1 or name_plural.is_empty():
		return get_translated_name()
	return translate_field(name_plural)
