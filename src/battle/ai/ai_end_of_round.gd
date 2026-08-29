class_name AIEndOfRound
extends RefCounted
## How much health a battler will lose — or gain — when this round finishes.
## A POSTIVE number is damage, and NEGATIVE number is healing


const CERTAIN_FAINT: int = 999_999

## The health [param battler] will be down by when the round ends.
static func damage_for(battle: Battle, battler: Battler) -> int:
	if battle == null or battler == null or battler.is_fainted():
		return 0
	if int(battler.get_effect(BattleEffects.PERISH_SONG)) == 1:
		return CERTAIN_FAINT
	var total: int = 0
	total += _weather(battle, battler)
	total += _status(battler)
	total += _field_and_side(battle, battler)
	total += _volatile(battle, battler)
	total += _held_item(battler)
	total += _ability(battle, battler)
	return total

## What the weather does, both the chip damage and the Abilities
static func _weather(battle: Battle, battler: Battler) -> int:
	var weather: StringName = battle.field.effective_weather(battle)
	var total: int = 0
	if weather == &"Sandstorm" or weather == &"Hail":
		if takes_weather_damage(battler, weather):
			total += _share(battler, 16)
	return total

## The same rule [method Battle._takes_weather_damage] applies, 
## read instead of called because that one is private to the battle.
static func takes_weather_damage(battler: Battler, weather: StringName) -> bool:
	match weather:
		&"Sandstorm":
			if battler.has_type(&"ROCK") or battler.has_type(&"GROUND") or battler.has_type(&"STEEL"):
				return false
		&"Hail":
			if GameSettings.data.mechanics_generation >= 9:
				return false
			if battler.has_type(&"ICE"):
				return false
		_:
			return false
	if AbilityEffects.blocks_weather_damage(battler, weather):
		return false
	return not ItemEffects.blocks_weather_damage(battler, weather)

## Poison, a burn and a nightmare.
static func _status(battler: Battler) -> int:
	if not AIBattlerView.takes_indirect_damage(battler):
		return 0
	var total: int = 0
	match battler.pokemon.status:
		&"POISON":
			if battler.has_ability(&"POISONHEAL"):
				return -_share(battler, 8)
			if battler.is_badly_poisoned():
				var counter: int = mini(int(battler.get_effect(BattleEffects.TOXIC_COUNTER)) + 1, 16)
				@warning_ignore("integer_division")
				total += maxi(battler.total_hp() * counter / 16, 1)
			else:
				total += _share(battler, 8)
		&"BURN":
			var divisor: int = 16 if GameSettings.data.mechanics_generation >= 7 else 8
			total += _share(battler, divisor)
	if battler.pokemon.status == &"SLEEP" and battler.has_effect(BattleEffects.NIGHTMARE):
		total += _share(battler, 4)
	return total

## The terrain underfoot and the effects the side is standing in.
static func _field_and_side(battle: Battle, battler: Battler) -> int:
	var total: int = 0
	if battle.field.terrain == &"Grassy" and not battler.is_airborne():
		if AIBattlerView.can_heal(battler):
			total -= _share(battler, 16)
	var side: BattleSide = battle.get_side(battler.side_index())
	if side.has_effect(BattleEffects.SEA_OF_FIRE):
		if not battler.has_type(&"FIRE") and AIBattlerView.takes_indirect_damage(battler):
			total += _share(battler, 8)
	return total

## Everything the battler is personally under: a seed, a bind, a curse, a ring.
static func _volatile(battle: Battle, battler: Battler) -> int:
	var total: int = 0
	var indirect: bool = AIBattlerView.takes_indirect_damage(battler)
	if battler.has_effect(BattleEffects.LEECH_SEED) and indirect:
		total += _share(battler, 8)
	if battler.has_effect(BattleEffects.CURSE) and indirect:
		total += _share(battler, 4)
	if battler.has_effect(BattleEffects.TRAPPING) and indirect:
		var divisor: int = 8 if GameSettings.data.mechanics_generation >= 6 else 16
		if battler.held_item() == &"BINDINGBAND":
			divisor = 6 if GameSettings.data.mechanics_generation >= 6 else 8
		total += _share(battler, divisor)
	if AIBattlerView.can_heal(battler):
		var boost: float = 1.3 if battler.held_item() == &"BIGROOT" else 1.0
		if battler.has_effect(BattleEffects.AQUA_RING):
			total -= int(float(_share(battler, 16)) * boost)
		if battler.has_effect(BattleEffects.INGRAIN):
			total -= int(float(_share(battler, 16)) * boost)
	if battle != null:
		var position: Dictionary = battle.effects_at_position(battler.index)
		if int(position.get(BattleEffects.WISH_COUNTER, 0)) == 1 and AIBattlerView.can_heal(battler):
			total -= int(position.get(BattleEffects.WISH_AMOUNT, 0))
	return total

static func _held_item(battler: Battler) -> int:
	match battler.held_item():
		&"LEFTOVERS":
			return -_share(battler, 16) if AIBattlerView.can_heal(battler) else 0
		&"BLACKSLUDGE":
			if battler.has_type(&"POISON"):
				return -_share(battler, 16) if AIBattlerView.can_heal(battler) else 0
			return _share(battler, 8) if AIBattlerView.takes_indirect_damage(battler) else 0
		&"STICKYBARB":
			return _share(battler, 8) if AIBattlerView.takes_indirect_damage(battler) else 0
	return 0

## The Abilities that read the weather at the end of the round
static func _ability(battle: Battle, battler: Battler) -> int:
	var weather: StringName = battle.field.effective_weather(battle)
	var sunny: bool = weather == &"Sun" or weather == &"HarshSun"
	var rainy: bool = weather == &"Rain" or weather == &"HeavyRain"
	match battler.ability():
		&"DRYSKIN":
			if sunny and AIBattlerView.takes_indirect_damage(battler):
				return _share(battler, 8)
			if rainy and AIBattlerView.can_heal(battler):
				return -_share(battler, 8)
		&"SOLARPOWER":
			if sunny and AIBattlerView.takes_indirect_damage(battler):
				return _share(battler, 8)
		&"RAINDISH":
			if rainy and AIBattlerView.can_heal(battler):
				return -_share(battler, 16)
		&"ICEBODY":
			if weather == &"Hail" and AIBattlerView.can_heal(battler):
				return -_share(battler, 16)
	return 0

static func _share(battler: Battler, divisor: int) -> int:
	return maxi(battler.total_hp() / divisor, 1)
