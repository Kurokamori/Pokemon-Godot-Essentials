class_name AIFieldScores
extends RefCounted
## What changing the weather or the terrain is worth.
## Score weather and terrain by their effect on every battler.

## Held items that make weather last longer, keyed by the weather they extend.
const WEATHER_EXTENDERS: Dictionary = {
	&"Sun": &"HEATROCK",
	&"Rain": &"DAMPROCK",
	&"Sandstorm": &"SMOOTHROCK",
	&"Hail": &"ICYROCK",
}

## Abilities that come into their own in each weather.
const WEATHER_ABILITIES: Dictionary = {
	&"Sun": [&"CHLOROPHYLL", &"FLOWERGIFT", &"FORECAST", &"HARVEST", &"LEAFGUARD", &"SOLARPOWER"],
	&"Rain": [&"DRYSKIN", &"FORECAST", &"HYDRATION", &"RAINDISH", &"SWIFTSWIM"],
	&"Sandstorm": [&"SANDFORCE", &"SANDRUSH", &"SANDVEIL"],
	&"Hail": [&"FORECAST", &"ICEBODY", &"SLUSHRUSH", &"SNOWCLOAK", &"ICEFACE"],
}

## Abilities that the weather turns against their holder.
const WEATHER_PUNISHED_ABILITIES: Dictionary = {
	&"Sun": [&"DRYSKIN"],
}

## Moves that want each weather up.
const WEATHER_GOOD_MOVES: Dictionary = {
	&"Sun": [
		&"HealUserDependingOnWeather", &"RaiseUserAtkSpAtk1Or2InSun",
		&"TwoTurnAttackOneTurnInSun", &"TypeAndPowerDependOnWeather",
	],
	&"Rain": [
		&"ConfuseTargetAlwaysHitsInRainHitsTargetInSky",
		&"ParalyzeTargetAlwaysHitsInRainHitsTargetInSky", &"TypeAndPowerDependOnWeather",
	],
	&"Sandstorm": [&"HealUserDependingOnSandstorm", &"TypeAndPowerDependOnWeather"],
	&"Hail": [
		&"FreezeTargetAlwaysHitsInHail", &"StartWeakenDamageAgainstUserSideIfHail",
		&"TypeAndPowerDependOnWeather",
	],
	&"ShadowSky": [&"TypeAndPowerDependOnWeather"],
}

## Moves each weather gets in the way of.
const WEATHER_BAD_MOVES: Dictionary = {
	&"Sun": [
		&"ConfuseTargetAlwaysHitsInRainHitsTargetInSky",
		&"ParalyzeTargetAlwaysHitsInRainHitsTargetInSky",
	],
	&"Rain": [&"HealUserDependingOnWeather", &"TwoTurnAttackOneTurnInSun"],
	&"Sandstorm": [&"HealUserDependingOnWeather", &"TwoTurnAttackOneTurnInSun"],
	&"Hail": [&"HealUserDependingOnWeather", &"TwoTurnAttackOneTurnInSun"],
}

## Seeds that trigger on each terrain.
const TERRAIN_SEEDS: Dictionary = {
	&"Electric": &"ELECTRICSEED",
	&"Grassy": &"GRASSYSEED",
	&"Misty": &"MISTYSEED",
	&"Psychic": &"PSYCHICSEED",
}

## Abilities each terrain turns on.
const TERRAIN_ABILITIES: Dictionary = {
	&"Electric": [&"SURGESURFER"],
	&"Grassy": [&"GRASSPELT"],
}

## Moves each terrain improves.
const TERRAIN_GOOD_MOVES: Dictionary = {
	&"Electric": [&"DoublePowerInElectricTerrain"],
	&"Grassy": [&"HealTargetDependingOnGrassyTerrain", &"HigherPriorityInGrassyTerrain"],
	&"Misty": [&"UserFaintsPowersUpInMistyTerrainExplosive"],
	&"Psychic": [&"HitsAllFoesAndPowersUpInPsychicTerrain"],
}

## Moves each terrain gets in the way of.
const TERRAIN_BAD_MOVES: Dictionary = {
	&"Grassy": [
		&"DoublePowerIfTargetUnderground", &"LowerTargetSpeed1WeakerInGrassyTerrain",
		&"RandomPowerDoublePowerIfTargetUnderground",
	],
}

## Moves that read whatever the terrain or the surroundings happen to be, 
## so any change at all is worth something to whoever knows one.
const TERRAIN_READING_MOVES: Array[StringName] = [
	&"EffectDependsOnEnvironment", &"SetUserTypesBasedOnEnvironment",
	&"TypeAndPowerDependOnTerrain", &"UseMoveDependingOnEnvironment",
]

## What starting [param weather] would be worth to [param context]'s user.
## [param starting] is `true` when the move is what puts the weather up
static func for_weather(context: AIContext, weather: StringName, starting: bool = true) -> int:
	if context.battle == null or weather.is_empty() or weather == &"None":
		return 0
	if context.battle.field.is_weather_suppressed(context.battle):
		return 0
	var total: int = 0
	if starting and WEATHER_EXTENDERS.has(weather):
		if context.user.held_item() == StringName(WEATHER_EXTENDERS[weather]):
			total += 4
	for battler: Battler in context.battle.all_active_battlers():
		var direction: int = -1 if context.opposes(battler) else 1
		total += _weather_for_battler(context, battler, weather) * direction
	return total

static func _weather_for_battler(context: AIContext, battler: Battler, weather: StringName) -> int:
	var total: int = 0
	match weather:
		&"Sun", &"HarshSun":
			if AIBattlerView.has_damaging_move_of(context.battle, battler, &"FIRE"):
				total += 10
			if AIBattlerView.has_damaging_move_of(context.battle, battler, &"WATER"):
				total -= 10
		&"Rain", &"HeavyRain":
			if AIBattlerView.has_damaging_move_of(context.battle, battler, &"WATER"):
				total += 10
			if AIBattlerView.has_damaging_move_of(context.battle, battler, &"FIRE"):
				total -= 10
		&"Sandstorm":
			if AIEndOfRound.takes_weather_damage(battler, weather):
				total -= 10
			if battler.has_type(&"ROCK"):
				total += 10
		&"Hail":
			if AIEndOfRound.takes_weather_damage(battler, weather):
				total -= 10
		&"ShadowSky":
			if AIBattlerView.has_damaging_move_of(context.battle, battler, &"SHADOW"):
				total += 10
	if not context.skill.is_medium() or battler.held_item() == &"UTILITYUMBRELLA":
		return total
	if WEATHER_ABILITIES.has(weather) and _has_any_ability(battler, WEATHER_ABILITIES[weather]):
		total += 5
	if WEATHER_PUNISHED_ABILITIES.has(weather) and _has_any_ability(battler, WEATHER_PUNISHED_ABILITIES[weather]):
		total -= 5
	if WEATHER_GOOD_MOVES.has(weather) and AIBattlerView.has_move_with_function(battler, WEATHER_GOOD_MOVES[weather]):
		total += 5
	if WEATHER_BAD_MOVES.has(weather) and AIBattlerView.has_move_with_function(battler, WEATHER_BAD_MOVES[weather]):
		total -= 5
	return total

## What starting [param terrain] would be worth to [param context]'s user.
static func for_terrain(context: AIContext, terrain: StringName, starting: bool = true) -> int:
	if context.battle == null or terrain.is_empty() or terrain == &"None":
		return 0
	var total: int = 0
	if starting and context.user.held_item() == &"TERRAINEXTENDER":
		total += 4
	for battler: Battler in context.battle.all_active_battlers():
		if battler.is_airborne():
			continue
		var direction: int = -1 if context.opposes(battler) else 1
		total += _terrain_for_battler(context, battler, terrain) * direction
	return total

static func _terrain_for_battler(context: AIContext, battler: Battler, terrain: StringName) -> int:
	var total: int = 0
	match terrain:
		&"Electric":
			if battler.pokemon.status == &"NONE":
				total += 8
			if battler.has_effect(BattleEffects.YAWN):
				total += 10
			if AIBattlerView.has_damaging_move_of(context.battle, battler, &"ELECTRIC"):
				total += 10
		&"Grassy":
			total += 8
			if AIBattlerView.has_damaging_move_of(context.battle, battler, &"GRASS"):
				total += 10
		&"Misty":
			if battler.pokemon.status == &"NONE" or not battler.has_effect(BattleEffects.CONFUSION):
				total += 8
			if AIBattlerView.has_damaging_move_of(context.battle, battler, &"DRAGON"):
				total -= 10
		&"Psychic":
			if AIBattlerView.check_moves(battler, func(move: PokemonMove) -> bool:
				var found: MoveData = move.data()
				return found != null and found.priority > 0
			):
				total -= 10
			if AIBattlerView.has_damaging_move_of(context.battle, battler, &"PSYCHIC"):
				total += 10
	if TERRAIN_SEEDS.has(terrain) and battler.held_item() == StringName(TERRAIN_SEEDS[terrain]):
		total += 8
	if not context.skill.is_medium():
		return total
	if battler.has_ability(&"MIMICRY"):
		total += 5
	if TERRAIN_ABILITIES.has(terrain) and _has_any_ability(battler, TERRAIN_ABILITIES[terrain]):
		total += 8
	if AIBattlerView.has_move_with_function(battler, TERRAIN_READING_MOVES):
		total += 5
	if TERRAIN_GOOD_MOVES.has(terrain) and AIBattlerView.has_move_with_function(battler, TERRAIN_GOOD_MOVES[terrain]):
		total += 5
	if TERRAIN_BAD_MOVES.has(terrain) and AIBattlerView.has_move_with_function(battler, TERRAIN_BAD_MOVES[terrain]):
		total -= 5
	return total

static func _has_any_ability(battler: Battler, abilities: Array) -> bool:
	for ability: StringName in abilities:
		if battler.has_ability(ability):
			return true
	return false
