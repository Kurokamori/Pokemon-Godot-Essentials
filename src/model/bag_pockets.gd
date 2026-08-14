class_name BagPockets
## Names and Arangement of bag pockets
##
## Pocket numbers match the `pocket` field of [ItemData]

const ITEMS: int = 1
const MEDICINE: int = 2
const POKE_BALLS: int = 3
const TMS: int = 4
const BERRIES: int = 5
const MAIL: int = 6
const BATTLE_ITEMS: int = 7
const KEY_ITEMS: int = 8

const COUNT: int = 8

const NAMES: Dictionary = {
	ITEMS: "Items",
	MEDICINE: "Medicine",
	POKE_BALLS: "Poke Balls",
	TMS: "TMs & HMs",
	BERRIES: "Berries",
	MAIL: "Mail",
	BATTLE_ITEMS: "Battle Items",
	KEY_ITEMS: "Key Items",
}

## The pocket in the source language
## Use this for anything comparing the name of pockets rather than displaying them
static func name_of(pocket: int) -> String:
	return NAMES.get(pocket, "Pokcet %d" % pocket)
	
## The pocket name translated to the player's language
static func translated_name_of(pocket: int) -> String:
	if NAMES.has(pocket):
		return Loc.line(String(NAMES[pocket]))
	return Loc.line("Pocket {number}", {"number": pocket})
	
static func all() -> Array[int]:
	return [ITEMS, MEDICINE, POKE_BALLS, TMS, BERRIES, MAIL, BATTLE_ITEMS, KEY_ITEMS]
