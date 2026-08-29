class_name MoveEffects

## Registry mapping a move's function code to its [MoveEffect].

## Effect libraries, each of which registers the codes it covers.
const LIBRARIES: Array[String] = [
	"res://src/battle/move_effects_library.gd",
	"res://src/battle/move_effects_calling.gd",
	"res://src/battle/move_effects_multi_turn.gd",
	"res://src/battle/move_effects_stat_extras.gd",
	"res://src/battle/move_effects_item_extras.gd",
	"res://src/battle/move_effects_order_extras.gd",
	"res://src/battle/move_effects_misc_extras.gd",
	"res://src/battle/move_effects_lingering.gd",
	"res://src/battle/move_effects_gimmicks.gd",
]

## Stat name fragments as they appear in function codes, longest first so that `SpAtk` is matched before `Atk`.
const STAT_TOKENS: Array = [
	["MainStats", [&"ATTACK", &"DEFENSE", &"SPECIAL_ATTACK", &"SPECIAL_DEFENSE", &"SPEED"]],
	["SpAtk", [&"SPECIAL_ATTACK"]],
	["SpDef", [&"SPECIAL_DEFENSE"]],
	["Accuracy", [&"ACCURACY"]],
	["Evasion", [&"EVASION"]],
	["Attack", [&"ATTACK"]],
	["Defense", [&"DEFENSE"]],
	["Speed", [&"SPEED"]],
	["Atk", [&"ATTACK"]],
	["Def", [&"DEFENSE"]],
	["Spd", [&"SPEED"]],
	["Acc", [&"ACCURACY"]],
	["Eva", [&"EVASION"]],
]

## Status names as they appear in function codes.
const STATUS_TOKENS: Dictionary = {
	"BadPoison": &"POISON",
	"Poison": &"POISON",
	"Burn": &"BURN",
	"Paralyze": &"PARALYSIS",
	"Sleep": &"SLEEP",
	"Freeze": &"FROZEN",
}

const WEATHER_TOKENS: Dictionary = {
	"StartRainWeather": &"Rain",
	"StartSunWeather": &"Sun",
	"StartSandstormWeather": &"Sandstorm",
	"StartHailWeather": &"Hail",
}

const TERRAIN_TOKENS: Dictionary = {
	"StartElectricTerrain": &"Electric",
	"StartGrassyTerrain": &"Grassy",
	"StartMistyTerrain": &"Misty",
	"StartPsychicTerrain": &"Psychic",
}

const HAZARD_TOKENS: Dictionary = {
	"AddSpikesToFoeSide": [BattleEffects.SPIKES, 3],
	"AddToxicSpikesToFoeSide": [BattleEffects.TOXIC_SPIKES, 2],
	"AddStealthRocksToFoeSide": [BattleEffects.STEALTH_ROCK, 1],
	"AddStickyWebToFoeSide": [BattleEffects.STICKY_WEB, 1],
}

## Side-wide effects, as `[effect, turns]`.
const SIDE_EFFECT_TOKENS: Dictionary = {
	"StartWeakenPhysicalDamageAgainstUserSide": [BattleEffects.REFLECT, 5],
	"StartWeakenSpecialDamageAgainstUserSide": [BattleEffects.LIGHT_SCREEN, 5],
	"StartWeakenDamageAgainstUserSideIfHail": [BattleEffects.AURORA_VEIL, 5],
	"StartUserSideImmunityToInflictedStatus": [BattleEffects.SAFEGUARD, 5],
	"StartUserSideImmunityToStatStageLowering": [BattleEffects.MIST, 5],
	"StartUserSideDoubleSpeed": [BattleEffects.TAILWIND, 4],
	"StartPreventCriticalHitsAgainstUserSide": [BattleEffects.LUCKY_CHANT, 5],
	"ProtectUserSideFromPriorityMoves": [BattleEffects.QUICK_GUARD, 1],
	"ProtectUserSideFromMultiTargetDamagingMoves": [BattleEffects.WIDE_GUARD, 1],
	"ProtectUserSideFromStatusMoves": [BattleEffects.CRAFTY_SHIELD, 1],
	"ProtectUserSideFromDamagingMovesIfUserFirstTurn": [BattleEffects.MAT_BLOCK, 1],
}

static var _effects: Dictionary = {}
static var _unhandled: Dictionary = {}
static var _initialised: bool = false

## Returns the effect for [param code], building it on first use.


## Function codes whose moves put HP back on the user or on an ally, which is what Heal Block stops and what Triage hurries.
const HEALING_CODES: Array[StringName] = [
	&"HealUserHalfOfTotalHP",
	&"HealUserHalfOfTotalHPLoseFlyingTypeThisTurn",
	&"HealUserDependingOnWeather",
	&"HealUserDependingOnSandstorm",
	&"HealUserDependingOnUserStockpile",
	&"HealUserFullyAndFallAsleep",
	&"HealUserAndAlliesQuarterOfTotalHP",
	&"HealUserAndAlliesQuarterOfTotalHPCureStatus",
	&"HealUserByTargetAttackLowerTargetAttack1",
	&"HealUserPositionNextTurn",
	&"HealTargetHalfOfTotalHP",
	&"HealTargetDependingOnGrassyTerrain",
	&"HealAllyOrDamageFoe",
	&"CureTargetStatusHealUserHalfOfTotalHP",
	&"UserFaintsHealAndCureReplacement",
	&"UserFaintsHealAndCureReplacementRestorePP",
]

## Returns `true` when [param record] is a move that restores HP, which is what Heal Block stops and what Triage hurries.
static func is_healing_move(record: MoveData) -> bool:
	if record == null:
		return false
	if record.is_healing_move():
		return true
	return get_effect(record.function_code).restores_hp

## Foe-targeting status moves that Magic Coat and Magic Bounce do NOT send back, 
## because they do not cause their target a problem.
const NOT_BOUNCED_CODES: Array[StringName] = [
	&"RaiseTargetAtkSpAtk2",
	&"TargetActsNext",
	&"TransformUserIntoTarget",
	&"ReplaceMoveWithTargetLastMoveUsed",
	&"ReplaceMoveThisBattleWithTargetLastMoveUsed",
	&"SetUserAbilityToTargetAbility",
	&"SetUserTypesToTargetTypes",
	&"SetUserTypesToResistLastAttack",
	&"UserCopyTargetStatStages",
	&"UseLastMoveUsedByTarget",
	&"UseMoveTargetIsAboutToUse",
	&"UseMoveDependingOnEnvironment",
	&"TargetUsesItsLastUsedMoveAgain",
	&"TargetTakesUserItem",
	&"EnsureNextMoveAlwaysHits",
	&"UserTargetSwapAbilities",
	&"UserTargetSwapItems",
	&"UserTargetSwapAtkSpAtkStages",
	&"UserTargetSwapDefSpDefStages",
	&"UserTargetSwapStatStages",
	&"UserTargetSwapBaseSpeed",
	&"UserTargetAverageBaseAtkSpAtk",
	&"UserTargetAverageBaseDefSpDef",
	&"UserTargetAverageHP",
]

## Status moves Snatch steals, by the rule Snatch itself states: 
const SNATCHABLE_CODES: Array[StringName] = [
	# Stat boosts on the user alone.
	&"RaiseUserAtk1Spd2", &"RaiseUserAtkAcc1", &"RaiseUserAtkDef1",
	&"RaiseUserAtkDefAcc1", &"RaiseUserAtkSpAtk1", &"RaiseUserAtkSpAtk1Or2InSun",
	&"RaiseUserAtkSpd1", &"RaiseUserAttack1", &"RaiseUserAttack2",
	&"RaiseUserCriticalHitRate2", &"RaiseUserDefSpDef1", &"RaiseUserDefense1",
	&"RaiseUserDefense1CurlUpUser", &"RaiseUserDefense2", &"RaiseUserDefense3",
	&"RaiseUserEvasion1", &"RaiseUserEvasion2MinimizeUser",
	&"RaiseUserMainStats1LoseThirdOfTotalHP", &"RaiseUserMainStats1TrapUserInBattle",
	&"RaiseUserSpAtk2", &"RaiseUserSpAtk3", &"RaiseUserSpAtkSpDef1",
	&"RaiseUserSpAtkSpDefSpd1", &"RaiseUserSpDef1PowerUpElectricMove",
	&"RaiseUserSpDef2", &"RaiseUserSpeed2", &"RaiseUserSpeed2LowerUserWeight",
	&"MaxUserAttackLoseHalfOfTotalHP", &"LowerUserDefSpDef1RaiseUserAtkSpAtkSpd2",
	&"TwoTurnAttackRaiseUserSpAtkSpDefSpd2", &"UserConsumeBerryRaiseDefense2",
	&"UserAddStockpileRaiseDefSpDef1",
	# Health and status put back on the user.
	&"HealUserHalfOfTotalHP", &"HealUserHalfOfTotalHPLoseFlyingTypeThisTurn",
	&"HealUserDependingOnWeather", &"HealUserDependingOnSandstorm",
	&"HealUserDependingOnUserStockpile", &"HealUserFullyAndFallAsleep",
	&"HealUserPositionNextTurn", &"HealUserAndAlliesQuarterOfTotalHP",
	&"HealUserAndAlliesQuarterOfTotalHPCureStatus",
	&"CureUserBurnPoisonParalysis", &"CureUserPartyStatus",
	&"StartHealUserEachTurn", &"StartHealUserEachTurnTrapUserInBattle",
	&"UserFaintsHealAndCureReplacement", &"UserFaintsHealAndCureReplacementRestorePP",
	# Cover put up over the user's own side.
	&"StartWeakenPhysicalDamageAgainstUserSide", &"StartWeakenSpecialDamageAgainstUserSide",
	&"StartWeakenDamageAgainstUserSideIfHail", &"StartUserSideImmunityToInflictedStatus",
	&"StartUserSideImmunityToStatStageLowering", &"StartPreventCriticalHitsAgainstUserSide",
	&"StartUserSideDoubleSpeed",
	# The rest of what a Pokemon does to itself and nobody else.
	&"UserMakeSubstitute", &"StartUserAirborne", &"EnsureNextCriticalHit",
	&"SetUserTypesBasedOnEnvironment", &"SetUserTypesToUserMoveType",
	&"UserSwapBaseAtkDef", &"RestoreUserConsumedItem", &"DoubleMoneyGainedFromBattle",
	# Raises that reach the user's allies as well, which Snatch still takes.
	&"RaiseAlliesAtkDef1", &"RaiseTargetAttack1",
	&"RaisePlusMinusUserAndAlliesAtkSpAtk1", &"RaisePlusMinusUserAndAlliesDefSpDef1",
	# The side-wide shields, which the thief raises over its own side instead.
	&"ProtectUserSideFromPriorityMoves", &"ProtectUserSideFromMultiTargetDamagingMoves",
	&"ProtectUserSideFromDamagingMovesIfUserFirstTurn",
	# Aimed at somebody else and good for the user, which is the shape Snatch
	# was made for.
	&"CureTargetStatusHealUserHalfOfTotalHP", &"DisableTargetMovesKnownByUser",
	&"RemoveUserBindingAndEntryHazards",
	# Single-stat raises
	&"RaiseUserAccuracy1", &"RaiseUserAccuracy2", &"RaiseUserAccuracy3",
	&"RaiseUserAttack3", &"RaiseUserEvasion2", &"RaiseUserEvasion3",
	&"RaiseUserMainStats1", &"RaiseUserSpAtk1", &"RaiseUserSpDef1", &"RaiseUserSpDef3",
	&"RaiseUserSpeed1", &"RaiseUserSpeed3",
	&"TypeDependsOnUserMorpekoFormRaiseUserSpeed1",
]

## Function codes for Ground moves that hit airborne targets.
const HITS_AIRBORNE_CODES: Array[StringName] = [&"HitsTargetInSkyGroundsTarget"]

## Function codes whose moves leave their user spending the next turn getting its breath back.
const RECHARGING_CODES: Array[StringName] = [&"AttackAndSkipNextTurn"]

## Function codes that hit semi-invulnerable targets by state.
const REACHES_OUT_OF_REACH_CODES: Dictionary = {
	&"Sky": [
		&"HitsTargetInSky",
		&"HitsTargetInSkyGroundsTarget",
		&"DoublePowerIfTargetInSky",
		&"FlinchTargetDoublePowerIfTargetInSky",
		&"ConfuseTargetAlwaysHitsInRainHitsTargetInSky",
		&"ParalyzeTargetAlwaysHitsInRainHitsTargetInSky",
	],
	&"Underground": [
		&"DoublePowerIfTargetUnderground",
		&"RandomPowerDoublePowerIfTargetUnderground",
		&"OHKOHitsUndergroundTarget",
	],
	&"Underwater": [
		&"BindTargetDoublePowerIfTargetUnderwater",
		&"DoublePowerIfTargetUnderwater",
	],
	&"Vanished": [],
}

## Returns `true` when Magic Coat and Magic Bounce send [param record] back at whoever used it.
static func can_be_magic_coated(record: MoveData) -> bool:
	if record == null:
		return false
	if record.can_be_magic_coated():
		return true
	if not record.is_status() or NOT_BOUNCED_CODES.has(record.function_code):
		return false
	var target: TargetData = Database.target(record.target)
	if target == null:
		return false
	if target.affects_user_side or target.includes_user:
		return false
	return target.targets_foe or target.affects_foe_side

## Returns `true` when Snatch steals [param record] out from under its user.
static func can_be_snatched(record: MoveData) -> bool:
	if record == null:
		return false
	if record.can_be_snatched():
		return true
	return record.is_status() and SNATCHABLE_CODES.has(record.function_code)

## Returns `true` when [param record] reaches a target that is off the ground
static func hits_airborne(record: MoveData) -> bool:
	if record == null:
		return false
	return record.has_flag(&"HitsAirborne") or HITS_AIRBORNE_CODES.has(record.function_code)

## Returns `true` when a move can hit a target in the given semi-invulnerable state.
static func reaches_out_of_reach_target(record: MoveData, state: StringName) -> bool:
	if record == null or state.is_empty():
		return true
	var codes: Array = REACHES_OUT_OF_REACH_CODES.get(state, [])
	return codes.has(record.function_code)

## Returns `true` when using [param record] costs its user the turn after it as well.
static func is_recharging_move(record: MoveData) -> bool:
	if record == null:
		return false
	return record.is_recharging_move() or RECHARGING_CODES.has(record.function_code)

static func get_effect(code: StringName) -> MoveEffect:
	_ensure_initialised()
	if _effects.has(code):
		return _effects[code]
	var built: MoveEffect = _build_from_code(code)
	_effects[code] = built
	return built

## Registers a custom effect, replacing any built-in one.
static func register(code: StringName, effect: MoveEffect) -> void:
	_ensure_initialised()
	effect.code = code
	if HEALING_CODES.has(code):
		effect.restores_hp = true
	_effects[code] = effect

## Function codes that fell through to the generic damaging behaviour.
static func unhandled_codes() -> Array[StringName]:
	var result: Array[StringName] = []
	for code: StringName in _unhandled:
		result.append(code)
	result.sort()
	return result

## Builds every effect up front and reports how many codes are fully handled.
static func audit() -> Dictionary:
	_ensure_initialised()
	var handled: int = 0
	var total: int = 0
	for move_id: StringName in Database.get_ids(Database.CATEGORY_MOVES):
		var move: MoveData = Database.move(move_id)
		if move == null:
			continue
		total += 1
		get_effect(move.function_code)
		if not _unhandled.has(move.function_code):
			handled += 1
	return {
		"moves": total,
		"handled": handled,
		"unhandled_codes": unhandled_codes(),
	}

static func _ensure_initialised() -> void:
	if _initialised:
		return
	_initialised = true
	_register_special()

# === Generic Parsing ==

static func _build_from_code(code: StringName) -> MoveEffect:
	var effect: MoveEffect = MoveEffect.new()
	effect.code = code
	var text: String = String(code)
	var recognised: bool = text == "None"

	if _parse_multi_hit(text, effect):
		recognised = true
	if _parse_two_turn(text, effect):
		recognised = true
	if _parse_recoil(text, effect):
		recognised = true
	if _parse_drain(text, effect):
		recognised = true
	if _parse_healing(text, effect):
		recognised = true
	if _parse_status(text, effect):
		recognised = true
	if _parse_stat_changes(text, effect):
		recognised = true
	if _parse_field(text, effect):
		recognised = true
	if _parse_structure(text, effect):
		recognised = true
	if _parse_fixed_damage(text, effect):
		recognised = true

	if not recognised:
		_unhandled[code] = true
	effect.restores_hp = HEALING_CODES.has(code)
	return effect

static func _parse_multi_hit(text: String, effect: MoveEffect) -> bool:
	if text.contains("HitTwoToFiveTimes"):
		effect.minimum_hits = 2
		effect.maximum_hits = 5
		return true
	if text.contains("HitThreeTimes"):
		effect.minimum_hits = 3
		effect.maximum_hits = 3
		return true
	if text.contains("HitTwoTimes"):
		effect.minimum_hits = 2
		effect.maximum_hits = 2
		return true
	return false

static func _parse_two_turn(text: String, effect: MoveEffect) -> bool:
	if not text.contains("TwoTurnAttack"):
		return false
	effect.is_two_turn = true
	if text.contains("InvulnerableInSky"):
		effect.invulnerable_state = &"Sky"
		effect.charge_message = "%s flew up high!"
	elif text.contains("InvulnerableUnderground"):
		effect.invulnerable_state = &"Underground"
		effect.charge_message = "%s burrowed its way under the ground!"
	elif text.contains("InvulnerableUnderwater"):
		effect.invulnerable_state = &"Underwater"
		effect.charge_message = "%s hid underwater!"
	elif text.contains("Invulnerable"):
		effect.invulnerable_state = &"Vanished"
		effect.charge_message = "%s vanished instantly!"
	else:
		effect.charge_message = "%s is glowing!"
	return true

static func _parse_recoil(text: String, effect: MoveEffect) -> bool:
	if text.contains("RecoilThirdOfDamageDealt"):
		effect.recoil_fraction = 1.0 / 3.0
		return true
	if text.contains("RecoilQuarterOfDamageDealt"):
		effect.recoil_fraction = 0.25
		return true
	if text.contains("RecoilHalfOfDamageDealt"):
		effect.recoil_fraction = 0.5
		return true
	return false

static func _parse_drain(text: String, effect: MoveEffect) -> bool:
	if text.contains("HealUserByThreeQuartersOfDamageDone"):
		effect.drain_fraction = 0.75
		return true
	if text.contains("HealUserByHalfOfDamageDone"):
		effect.drain_fraction = 0.5
		return true
	return false

static func _parse_healing(text: String, effect: MoveEffect) -> bool:
	if text.contains("HealUserHalfOfTotalHP"):
		effect.heal_fraction = 0.5
		return true
	if text.contains("HealTargetHalfOfTotalHP"):
		effect.heal_fraction = 0.5
		return true
	if text.contains("HealUserAndAlliesQuarterOfTotalHP"):
		effect.heal_fraction = 0.25
		return true
	if text.contains("UserLosesHalfOfTotalHP"):
		effect.hp_cost_fraction = 0.5
		return true
	if text.contains("UserFaints"):
		effect.user_faints = true
		return true
	return false

static func _parse_status(text: String, effect: MoveEffect) -> bool:
	var recognised: bool = false
	for token: String in STATUS_TOKENS:
		if not text.contains(token + "Target"):
			continue
		effect.status_to_inflict = STATUS_TOKENS[token]
		effect.status_is_severe = token == "BadPoison"
		recognised = true
		break
	if text.contains("FlinchTarget"):
		effect.causes_flinch = true
		recognised = true
	if text.contains("ConfuseTarget"):
		effect.causes_confusion = true
		recognised = true
	if text.contains("AttractTarget"):
		effect.causes_attraction = true
		recognised = true
	return recognised

## Parses stat-change codes such as `RaiseUserAtkDef1` or `RaiseUserAtk1Spd2`.
static func _parse_stat_changes(text: String, effect: MoveEffect) -> bool:
	var recognised: bool = false
	for direction: String in ["Raise", "Lower"]:
		var start: int = text.find(direction)
		while start >= 0:
			var step_sign: int = 1 if direction == "Raise" else -1
			var remainder: String = text.substr(start + direction.length())
			var subject: String = ""
			for candidate: String in ["UserAndAllies", "AllBattlers", "Allies", "User", "Target"]:
				if remainder.begins_with(candidate):
					subject = candidate
					remainder = remainder.substr(candidate.length())
					break
			if subject.is_empty():
				start = text.find(direction, start + 1)
				continue
			var changes: Dictionary = _parse_stat_list(remainder)
			if changes.is_empty():
				start = text.find(direction, start + 1)
				continue
			var destination: Dictionary
			match subject:
				"User": destination = effect.user_stat_changes
				"Target": destination = effect.target_stat_changes
				"Allies", "UserAndAllies": destination = effect.ally_stat_changes
				_: destination = effect.target_stat_changes
			for stat: StringName in changes:
				destination[stat] = int(changes[stat]) * step_sign
			if subject == "UserAndAllies":
				for stat: StringName in changes:
					effect.user_stat_changes[stat] = int(changes[stat]) * step_sign
			recognised = true
			start = text.find(direction, start + 1)
	if recognised:
		effect.stat_change_is_main_effect = true
	return recognised

## Reads a run of stat tokens with their magnitudes, e.g.
static func _parse_stat_list(text: String) -> Dictionary:
	var changes: Dictionary = {}
	var pending: Array[StringName] = []
	var position: int = 0
	while position < text.length():
		var matched: bool = false
		for entry: Array in STAT_TOKENS:
			var token: String = entry[0]
			if not text.substr(position).begins_with(token):
				continue
			for stat: StringName in entry[1]:
				pending.append(stat)
			position += token.length()
			matched = true
			break
		if matched:
			continue
		var character: String = text[position]
		if character.is_valid_int() and not pending.is_empty():
			var magnitude: int = int(character)
			for stat: StringName in pending:
				changes[stat] = magnitude
			pending.clear()
			position += 1
			continue
		break
	return changes

static func _parse_field(text: String, effect: MoveEffect) -> bool:
	for token: String in WEATHER_TOKENS:
		if text.contains(token):
			effect.weather_to_start = WEATHER_TOKENS[token]
			return true
	for token: String in TERRAIN_TOKENS:
		if text.contains(token):
			effect.terrain_to_start = TERRAIN_TOKENS[token]
			return true
	for token: String in HAZARD_TOKENS:
		if text.contains(token):
			effect.hazard_to_add = HAZARD_TOKENS[token][0]
			effect.hazard_max_layers = HAZARD_TOKENS[token][1]
			return true
	for token: String in SIDE_EFFECT_TOKENS:
		if text.contains(token):
			effect.side_effect_to_start = SIDE_EFFECT_TOKENS[token][0]
			effect.side_effect_turns = SIDE_EFFECT_TOKENS[token][1]
			return true
	return false

static func _parse_structure(text: String, effect: MoveEffect) -> bool:
	var recognised: bool = false
	if text.begins_with("ProtectUser") and not text.contains("Side"):
		effect.is_protect_move = true
		recognised = true
	if text.contains("SwitchOutUser"):
		effect.switches_out_user = true
		recognised = true
	if text.contains("SwitchOutTarget"):
		effect.switches_out_target = true
		recognised = true
	if text.contains("AttackAndSkipNextTurn"):
		effect.recharges_after = true
		recognised = true
	if text.contains("AlwaysCriticalHit"):
		effect.always_crits_flag = true
		recognised = true
	if text.contains("IgnoreTargetDefSpDefEvaStatStages"):
		effect.ignores_defensive_stages_flag = true
		recognised = true
	return recognised

static func _parse_fixed_damage(text: String, effect: MoveEffect) -> bool:
	if text.contains("FixedDamage20"):
		effect.fixed_damage_amount = 20
		return true
	if text.contains("FixedDamage40"):
		effect.fixed_damage_amount = 40
		return true
	if text.contains("FixedDamageHalfTargetHP"):
		effect.fixed_damage_is_half_target_hp = true
		return true
	if text.contains("FixedDamageUserLevel"):
		effect.fixed_damage_is_user_level = true
		return true
	if text.begins_with("OHKO"):
		effect.is_ohko = true
		effect.never_misses_flag = false
		return true
	return false

# === Bespoke Effects ==

static func _register_special() -> void:
	register(&"None", MoveEffect.new())

	_register_variable_power()
	_register_stat_swaps()
	_register_type_changing()
	_register_utility()
	for library_path: String in LIBRARIES:
		var library: GDScript = load(library_path)
		if library != null:
			library.register_all()

static func _register_variable_power() -> void:
	register(&"PowerHigherWithUserHP", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, _target: Battler) -> int:
			return maxi(int(150.0 * user.hp_fraction()), 1)
	))
	register(&"PowerLowerWithUserHP", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, _target: Battler) -> int:
			var fraction: float = user.hp_fraction()
			if fraction < 0.0417: return 200
			if fraction < 0.1042: return 150
			if fraction < 0.2083: return 100
			if fraction < 0.3542: return 80
			if fraction < 0.6875: return 40
			return 20
	))
	register(&"PowerHigherWithTargetHP", VariablePowerEffect.new(
		func(_battle: Battle, _user: Battler, target: Battler) -> int:
			return maxi(int(120.0 * target.hp_fraction()), 1)
	))
	register(&"PowerHigherWithUserHappiness", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, _target: Battler) -> int:
			return clampi(user.pokemon.happiness * 10 / 25, 1, 102)
	))
	register(&"PowerLowerWithUserHappiness", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, _target: Battler) -> int:
			return clampi((255 - user.pokemon.happiness) * 10 / 25, 1, 102)
	))
	register(&"PowerHigherWithUserPositiveStatStages", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, _target: Battler) -> int:
			return 20 + (user.total_positive_stages() * 20)
	))
	register(&"PowerHigherWithTargetPositiveStatStages", VariablePowerEffect.new(
		func(_battle: Battle, _user: Battler, target: Battler) -> int:
			return 60 + (target.total_positive_stages() * 20)
	))
	register(&"PowerHigherWithLessPP", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, _target: Battler) -> int:
			var move: PokemonMove = user.pokemon.get_move(&"TRUMPCARD")
			var remaining: int = move.pp if move != null else 0
			match remaining:
				0: return 200
				1: return 80
				2: return 60
				3: return 50
			return 40
	))
	register(&"PowerHigherWithTargetWeight", VariablePowerEffect.new(
		func(_battle: Battle, _user: Battler, target: Battler) -> int:
			var weight: int = target.weight()
			if weight >= 2000: return 120
			if weight >= 1000: return 100
			if weight >= 500: return 80
			if weight >= 250: return 60
			if weight >= 100: return 40
			return 20
	))
	register(&"PowerHigherWithUserHeavierThanTarget", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, target: Battler) -> int:
			var ratio: float = float(user.weight()) / maxf(float(target.weight()), 1.0)
			if ratio >= 5.0: return 120
			if ratio >= 4.0: return 100
			if ratio >= 3.0: return 80
			if ratio >= 2.0: return 60
			return 40
	))
	register(&"PowerHigherWithUserFasterThanTarget", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, target: Battler) -> int:
			var ratio: int = user.effective_speed() / maxi(target.effective_speed(), 1)
			return clampi(40 + (ratio * 20), 40, 150)
	))
	register(&"PowerHigherWithTargetFasterThanUser", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, target: Battler) -> int:
			var ratio: int = target.effective_speed() / maxi(user.effective_speed(), 1)
			if ratio >= 4: return 150
			if ratio >= 3: return 120
			if ratio >= 2: return 80
			if ratio >= 1: return 60
			return 40
	))
	register(&"PowerHigherWithConsecutiveUse", VariablePowerEffect.new(
		func(_battle: Battle, user: Battler, _target: Battler) -> int:
			return mini(20 * (1 << mini(user.consecutive_move_uses, 4)), 320)
	))

static func _register_stat_swaps() -> void:
	register(&"UseTargetDefenseInsteadOfTargetSpDef", DefendingStatEffect.new(&"DEFENSE"))
	register(&"UseUserDefenseInsteadOfUserAttack", AttackingStatEffect.new(&"DEFENSE"))
	register(&"UseTargetAttackInsteadOfUserAttack", FoulPlayEffect.new())

static func _register_type_changing() -> void:
	register(&"TypeDependsOnUserIVs", HiddenPowerEffect.new())
	register(&"TypeAndPowerDependOnWeather", WeatherBallEffect.new())
	register(&"TypeAndPowerDependOnTerrain", TerrainPulseEffect.new())
	register(&"TypeDependsOnUserPlate", ItemTypeEffect.new())
	register(&"TypeDependsOnUserDrive", ItemTypeEffect.new())
	register(&"TypeDependsOnUserMemory", ItemTypeEffect.new())
	register(&"TypeIsUserFirstType", UserTypeEffect.new())
	register(&"NormalMovesBecomeElectric", MoveEffect.new())

static func _register_utility() -> void:
	register(&"UserMakeSubstitute", SubstituteEffect.new())
	register(&"HealUserFullyAndFallAsleep", RestEffect.new())

	var explosion: MoveEffect = MoveEffect.new()
	explosion.user_faints = true
	register(&"UserFaintsExplosive", explosion)
	register(&"UserFaintsPowersUpInMistyTerrainExplosive", explosion)
	register(&"UserLosesHalfOfTotalHPExplosive", explosion)

# === Effect Classes ==

## Substitute: a quarter of the user's health for a decoy that soaks up everything until it breaks.
class SubstituteEffect extends MoveEffect:

	func _init() -> void:
		hp_cost_fraction = 0.25

	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if user.has_substitute():
			return AIScores.USELESS
		if user.hp_fraction() <= hp_cost_fraction:
			return AIScores.USELESS
		return base + int(70.0 * (user.hp_fraction() - hp_cost_fraction))

## Rest: full health and a full cure, at the cost of two rounds asleep.
class RestEffect extends MoveEffect:

	func _init() -> void:
		heal_fraction = 1.0

	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if user.hp() >= user.total_hp():
			return AIScores.USELESS
		if user.hp_fraction() > 0.5:
			return AIScores.USELESS
		return base + int(120.0 * (1.0 - user.hp_fraction()))

## An effect whose base power is produced by a callable.
class VariablePowerEffect extends MoveEffect:
	var _power: Callable

	func _init(power_function: Callable) -> void:
		_power = power_function

	func base_power(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> int:
		return maxi(_power.call(battle, user, target), 1)

## An effect that attacks against a different defensive stat.
class DefendingStatEffect extends MoveEffect:
	var _stat: StringName

	func _init(stat: StringName) -> void:
		_stat = stat

	func defending_stat(_move: MoveData, _default_stat: StringName) -> StringName:
		return _stat

## An effect that attacks using a different offensive stat.
class AttackingStatEffect extends MoveEffect:
	var _stat: StringName

	func _init(stat: StringName) -> void:
		_stat = stat

	func attacking_stat(_move: MoveData, _default_stat: StringName) -> StringName:
		return _stat

## Foul Play, which uses the target's Attack.
class FoulPlayEffect extends MoveEffect:

	func stat_source(_user: Battler, target: Battler) -> Battler:
		return target

class HiddenPowerEffect extends MoveEffect:

	func effective_type(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> StringName:
		return user.pokemon.hidden_power()["type"]

	func base_power(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> int:
		if GameSettings.data.mechanics_generation >= 6:
			return 60
		return int(user.pokemon.hidden_power()["power"])

class WeatherBallEffect extends MoveEffect:

	func effective_type(battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> StringName:
		match battle.field.effective_weather(battle):
			&"Sun", &"HarshSun": return &"FIRE"
			&"Rain", &"HeavyRain": return &"WATER"
			&"Sandstorm": return &"ROCK"
			&"Hail": return &"ICE"
		return move.type

	func base_power(battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> int:
		return move.power * 2 if battle.field.effective_weather(battle) != &"None" else move.power

class TerrainPulseEffect extends MoveEffect:

	func effective_type(battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> StringName:
		match battle.field.terrain:
			&"Electric": return &"ELECTRIC"
			&"Grassy": return &"GRASS"
			&"Misty": return &"FAIRY"
			&"Psychic": return &"PSYCHIC"
		return move.type

	func base_power(battle: Battle, user: Battler, _target: Battler, move: MoveData) -> int:
		if battle.field.terrain != &"None" and not user.is_airborne():
			return move.power * 2
		return move.power

## Judgment, Techno Blast and Multi-Attack, whose type follows the held item.
class ItemTypeEffect extends MoveEffect:

	func effective_type(_battle: Battle, user: Battler, _target: Battler, move: MoveData) -> StringName:
		var item: StringName = user.held_item()
		if item.is_empty():
			return move.type
		for type_id: StringName in FormHandlers.TYPE_ITEM_FORMS:
			if FormHandlers.TYPE_ITEM_FORMS[type_id].has(item):
				return type_id
		return move.type

## Revelation Dance, which takes the user's primary type.
class UserTypeEffect extends MoveEffect:

	func effective_type(_battle: Battle, user: Battler, _target: Battler, move: MoveData) -> StringName:
		var user_types: Array[StringName] = user.types()
		return user_types[0] if not user_types.is_empty() else move.type
