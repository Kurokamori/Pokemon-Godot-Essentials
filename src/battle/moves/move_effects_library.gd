class_name MoveEffectsLibrary

## The move effects that need more than the generic parser can express.

## Conditions for the `DoublePowerIf...` family, keyed by function code.
const DOUBLE_POWER_CONDITIONS: Dictionary = {
	&"DoublePowerIfTargetPoisoned": "target_poisoned",
	&"DoublePowerIfTargetStatusProblem": "target_status",
	&"DoublePowerIfTargetHPLessThanHalf": "target_half_hp",
	&"DoublePowerIfTargetActed": "target_acted",
	&"DoublePowerIfTargetNotActed": "target_not_acted",
	&"DoublePowerIfTargetLostHPThisTurn": "target_lost_hp",
	&"DoublePowerIfUserLostHPThisTurn": "user_lost_hp",
	&"DoublePowerIfUserHasNoItem": "user_no_item",
	&"DoublePowerIfUserLastMoveFailed": "user_move_failed",
	&"DoublePowerIfUserPoisonedBurnedParalyzed": "user_status",
	&"DoublePowerIfUserStatsLoweredThisTurn": "user_stats_lowered",
	&"DoublePowerIfAllyFaintedLastTurn": "ally_fainted",
	&"DoublePowerInElectricTerrain": "electric_terrain",
	&"DoublePowerIfTargetUnderground": "target_underground",
	&"DoublePowerIfTargetUnderwater": "target_underwater",
	&"DoublePowerIfTargetInSky": "target_in_sky",
	&"DoublePowerIfTargetAsleepCureTarget": "target_asleep",
	&"DoublePowerIfTargetParalyzedCureTarget": "target_paralyzed",
	&"BindTargetDoublePowerIfTargetUnderwater": "target_underwater",
	&"FlinchTargetDoublePowerIfTargetInSky": "target_in_sky",
}

## Effects that simply set a timed volatile effect on the target.
const TARGET_EFFECT_MOVES: Dictionary = {
	&"DisableTargetLastMoveUsed": [BattleEffects.DISABLE, 4],
	&"DisableTargetStatusMoves": [BattleEffects.TAUNT, 3],
	&"DisableTargetHealingMoves": [BattleEffects.HEAL_BLOCK, 5],
	&"DisableTargetSoundMoves": [BattleEffects.THROAT_CHOP, 2],
	&"DisableTargetUsingSameMoveConsecutively": [BattleEffects.TORMENT, 999],
	&"DisableTargetUsingDifferentMove": [BattleEffects.ENCORE, 3],
	&"DisableTargetMovesKnownByUser": [BattleEffects.IMPRISON, 999],
	&"StartTargetCannotUseItem": [BattleEffects.EMBARGO, 5],
	&"StartDamageTargetEachTurnIfTargetAsleep": [BattleEffects.NIGHTMARE, 999],
	&"StartNegateTargetEvasionStatStageAndDarkImmunity": [BattleEffects.MIRACLE_EYE, 999],
	&"StartNegateTargetEvasionStatStageAndGhostImmunity": [BattleEffects.FORESIGHT, 999],
	&"StartTargetAirborneAndAlwaysHitByMoves": [BattleEffects.TELEKINESIS, 3],
	&"TrapTargetInBattle": [BattleEffects.MEAN_LOOK, 999],
	&"TrapTargetInBattleMainEffect": [BattleEffects.MEAN_LOOK, 999],
	&"BindTarget": [BattleEffects.TRAPPING, 5],
	&"TrapTargetInBattleLowerTargetDefSpDef1EachTurn": [BattleEffects.TRAPPING, 5],
}

## Effects that set a timed volatile effect on the user.
const USER_EFFECT_MOVES: Dictionary = {
	&"StartHealUserEachTurn": [BattleEffects.AQUA_RING, 999],
	&"StartHealUserEachTurnTrapUserInBattle": [BattleEffects.INGRAIN, 999],
	&"StartUserAirborne": [BattleEffects.MAGNET_RISE, 5],
	&"EnsureNextMoveAlwaysHits": [BattleEffects.LOCK_ON, 2],
	&"EnsureNextCriticalHit": [BattleEffects.LASER_FOCUS, 2],
	&"RaiseUserCriticalHitRate2": [BattleEffects.FOCUS_ENERGY, 999],
	&"UserEnduresFaintingThisTurn": [BattleEffects.ENDURE, 1],
	&"RedirectAllMovesToUser": [BattleEffects.FOLLOW_ME, 1],
	&"BounceBackProblemCausingStatusMoves": [BattleEffects.MAGIC_COAT, 1],
	&"StealAndUseBeneficialStatusMove": [BattleEffects.SNATCH, 1],
	&"MultiTurnAttackPreventSleeping": [BattleEffects.UPROAR, 3],
	&"RaiseUserDefense1CurlUpUser": [BattleEffects.DEFENSE_CURL, 999],
	&"RaiseUserEvasion2MinimizeUser": [BattleEffects.MINIMIZE, 999],
}

## Field-wide effects, keyed by function code.
const FIELD_EFFECT_MOVES: Dictionary = {
	&"StartGravity": [BattleEffects.GRAVITY, 5],
	&"StartSlowerBattlersActFirst": [BattleEffects.TRICK_ROOM, 5],
	&"StartNegateHeldItems": [BattleEffects.MAGIC_ROOM, 5],
	&"StartSwapAllBattlersBaseDefensiveStats": [BattleEffects.WONDER_ROOM, 5],
	&"TrapAllBattlersInBattleForOneTurn": [BattleEffects.FAIRY_LOCK, 2],
	&"StartWeakenElectricMoves": [BattleEffects.MUD_SPORT, 5],
	&"StartWeakenFireMoves": [BattleEffects.WATER_SPORT, 5],
	&"NormalMovesBecomeElectric": [BattleEffects.ION_DELUGE, 1],
}

## Moves that set the target's types outright.
const SET_TARGET_TYPE_MOVES: Dictionary = {
	&"SetTargetTypesToWater": &"WATER",
	&"SetTargetTypesToPsychic": &"PSYCHIC",
}

## Moves that add a type to the target.
const ADD_TARGET_TYPE_MOVES: Dictionary = {
	&"AddGrassTypeToTarget": &"GRASS",
	&"AddGhostTypeToTarget": &"GHOST",
}

## Registers everything in this library into [MoveEffects].

static func register_all() -> void:
	_register_double_power()
	_register_simple_effects()
	_register_stat_stage_tricks()
	_register_item_tricks()
	_register_type_tricks()
	_register_hp_tricks()
	_register_counters()
	_register_removal()
	_register_ability_tricks()
	_register_protections()
	_register_grounding()
	_register_no_ops()

static func _register_double_power() -> void:
	for code: StringName in DOUBLE_POWER_CONDITIONS:
		var condition: String = DOUBLE_POWER_CONDITIONS[code]
		var effect: DoublePowerEffect = DoublePowerEffect.new(condition)
		# Preserve any secondary effect the generic parser would also apply.
		if code == &"BindTargetDoublePowerIfTargetUnderwater":
			effect.applies_trapping = true
		if code == &"FlinchTargetDoublePowerIfTargetInSky":
			effect.causes_flinch = true
		if code == &"DoublePowerIfTargetAsleepCureTarget":
			effect.cures_target_after = &"SLEEP"
		if code == &"DoublePowerIfTargetParalyzedCureTarget":
			effect.cures_target_after = &"PARALYSIS"
		MoveEffects.register(code, effect)

static func _register_simple_effects() -> void:
	for code: StringName in TARGET_EFFECT_MOVES:
		var entry: Array = TARGET_EFFECT_MOVES[code]
		MoveEffects.register(code, ApplyEffectEffect.new(entry[0], entry[1], ApplyEffectEffect.Scope.TARGET))
	for code: StringName in USER_EFFECT_MOVES:
		var entry: Array = USER_EFFECT_MOVES[code]
		MoveEffects.register(code, ApplyEffectEffect.new(entry[0], entry[1], ApplyEffectEffect.Scope.USER))
	for code: StringName in FIELD_EFFECT_MOVES:
		var entry: Array = FIELD_EFFECT_MOVES[code]
		MoveEffects.register(code, ApplyEffectEffect.new(entry[0], entry[1], ApplyEffectEffect.Scope.FIELD))

	MoveEffects.register(&"StartLeechSeedTarget", LeechSeedEffect.new())
	MoveEffects.register(&"StartPerishCountsForAllBattlers", PerishSongEffect.new())
	MoveEffects.register(&"TrapUserAndTargetInBattle", TrapBothEffect.new())
	MoveEffects.register(&"CannotMakeTargetFaint", FalseSwipeEffect.new())
	MoveEffects.register(&"MaxUserAttackLoseHalfOfTotalHP", BellyDrumEffect.new())
	MoveEffects.register(&"HealUserDependingOnWeather", WeatherHealEffect.new())
	MoveEffects.register(&"HealUserDependingOnSandstorm", WeatherHealEffect.new())
	MoveEffects.register(&"HealTargetDependingOnGrassyTerrain", WeatherHealEffect.new())
	MoveEffects.register(&"CureTargetBurn", CureStatusEffect.new(&"BURN", false))
	MoveEffects.register(&"CureUserBurnPoisonParalysis", CureStatusEffect.new(&"ANY", true))
	MoveEffects.register(&"CureUserPartyStatus", CurePartyStatusEffect.new())
	MoveEffects.register(&"CureTargetStatusHealUserHalfOfTotalHP", CureStatusEffect.new(&"ANY", false))
	MoveEffects.register(&"GiveUserStatusToTarget", PsychoShiftEffect.new())

static func _register_stat_stage_tricks() -> void:
	MoveEffects.register(&"ResetTargetStatStages", StatStageEffect.new("reset_target"))
	MoveEffects.register(&"ResetAllBattlersStatStages", StatStageEffect.new("reset_all"))
	MoveEffects.register(&"InvertTargetStatStages", StatStageEffect.new("invert_target"))
	MoveEffects.register(&"UserCopyTargetStatStages", StatStageEffect.new("copy"))
	MoveEffects.register(&"UserStealTargetPositiveStatStages", StatStageEffect.new("steal"))
	MoveEffects.register(&"UserTargetSwapStatStages", StatStageEffect.new("swap_all"))
	MoveEffects.register(&"UserTargetSwapAtkSpAtkStages", StatStageEffect.new("swap_offense"))
	MoveEffects.register(&"UserTargetSwapDefSpDefStages", StatStageEffect.new("swap_defense"))
	MoveEffects.register(&"RaiseTargetRandomStat2", StatStageEffect.new("random_target"))

static func _register_item_tricks() -> void:
	MoveEffects.register(&"RemoveTargetItem", ItemTrickEffect.new("knock_off"))
	MoveEffects.register(&"UserTakesTargetItem", ItemTrickEffect.new("steal"))
	MoveEffects.register(&"TargetTakesUserItem", ItemTrickEffect.new("give"))
	MoveEffects.register(&"UserTargetSwapItems", ItemTrickEffect.new("swap"))
	MoveEffects.register(&"RestoreUserConsumedItem", ItemTrickEffect.new("recycle"))
	MoveEffects.register(&"DestroyTargetBerryOrGem", ItemTrickEffect.new("destroy_berry"))
	MoveEffects.register(&"CorrodeTargetItem", ItemTrickEffect.new("knock_off"))
	MoveEffects.register(&"UserConsumeTargetBerry", ItemTrickEffect.new("eat_berry"))

static func _register_type_tricks() -> void:
	for code: StringName in SET_TARGET_TYPE_MOVES:
		MoveEffects.register(code, TypeChangeEffect.new("set_target", SET_TARGET_TYPE_MOVES[code]))
	for code: StringName in ADD_TARGET_TYPE_MOVES:
		MoveEffects.register(code, TypeChangeEffect.new("add_target", ADD_TARGET_TYPE_MOVES[code]))
	MoveEffects.register(&"SetUserTypesToTargetTypes", TypeChangeEffect.new("copy_target", &""))
	MoveEffects.register(&"SetUserTypesToUserMoveType", TypeChangeEffect.new("user_move_type", &""))
	MoveEffects.register(&"UserLosesFireType", TypeChangeEffect.new("lose_fire", &"FIRE"))
	MoveEffects.register(&"SetUserTypesBasedOnEnvironment", TypeChangeEffect.new("environment", &""))

static func _register_hp_tricks() -> void:
	MoveEffects.register(&"LowerTargetHPToUserHP", EndeavorEffect.new())
	MoveEffects.register(&"UserTargetAverageHP", PainSplitEffect.new())
	MoveEffects.register(&"RandomlyDamageOrHealTarget", PresentEffect.new())

static func _register_counters() -> void:
	MoveEffects.register(&"CounterPhysicalDamage", CounterEffect.new(MoveData.Category.PHYSICAL, 2.0))
	MoveEffects.register(&"CounterSpecialDamage", CounterEffect.new(MoveData.Category.SPECIAL, 2.0))
	MoveEffects.register(&"CounterDamagePlusHalf", CounterEffect.new(-1, 1.5))

static func _register_removal() -> void:
	MoveEffects.register(&"RemoveScreens", RemovalEffect.new("screens"))
	MoveEffects.register(&"RemoveProtections", RemovalEffect.new("protections"))
	MoveEffects.register(&"RemoveProtectionsBypassSubstitute", RemovalEffect.new("protections"))
	MoveEffects.register(&"HoopaRemoveProtectionsBypassSubstituteLowerUserDef1", RemovalEffect.new("protections"))
	MoveEffects.register(&"RemoveTerrain", RemovalEffect.new("terrain"))
	MoveEffects.register(&"RemoveUserBindingAndEntryHazards", RemovalEffect.new("hazards"))
	MoveEffects.register(&"LowerTargetEvasion1RemoveSideEffects", RemovalEffect.new("defog"))

## Roost and the two moves that knock a target out of the air.
static func _register_grounding() -> void:
	MoveEffects.register(&"HealUserHalfOfTotalHPLoseFlyingTypeThisTurn", RoostEffect.new())
	MoveEffects.register(&"EffectivenessIncludesFlyingType", FlyingPressEffect.new())
	MoveEffects.register(&"HealUserPositionNextTurn", WishEffect.new())
	MoveEffects.register(&"AddMoneyGainedFromBattle", PayDayEffect.new())
	MoveEffects.register(&"DoubleMoneyGainedFromBattle", HappyHourEffect.new())
	for code: StringName in [&"HitsTargetInSkyGroundsTarget", &"HitsTargetInSky"]:
		MoveEffects.register(code, GroundTargetEffect.new())

static func _register_protections() -> void:
	for code: StringName in ProtectionEffect.KINDS:
		MoveEffects.register(code, ProtectionEffect.new(StringName(ProtectionEffect.KINDS[code])))

static func _register_ability_tricks() -> void:
	MoveEffects.register(&"NegateTargetAbility", AbilityTrickEffect.new("suppress"))
	MoveEffects.register(&"NegateTargetAbilityIfTargetActed", AbilityTrickEffect.new("suppress"))
	MoveEffects.register(&"SetTargetAbilityToSimple", AbilityTrickEffect.new("set_simple"))
	MoveEffects.register(&"SetTargetAbilityToInsomnia", AbilityTrickEffect.new("set_insomnia"))
	MoveEffects.register(&"SetTargetAbilityToUserAbility", AbilityTrickEffect.new("copy_to_target"))
	MoveEffects.register(&"SetUserAbilityToTargetAbility", AbilityTrickEffect.new("copy_to_user"))
	MoveEffects.register(&"UserTargetSwapAbilities", AbilityTrickEffect.new("swap"))
	MoveEffects.register(&"IgnoreTargetAbility", MoveEffect.new())
	MoveEffects.register(&"CategoryDependsOnHigherDamageIgnoreTargetAbility", MoveEffect.new())

## Moves that intentionally do nothing beyond a message.
static func _register_no_ops() -> void:
	for code: StringName in [
		&"DoesNothingCongratulations", &"DoesNothingFailsIfNoAlly",
		&"DoesNothingUnusableInGravity",
		&"CannotBeRedirected",
	]:
		MoveEffects.register(code, MoveEffect.new())

# === Effect Types ==

## Doubles a move's power when a named condition holds.
class DoublePowerEffect extends MoveEffect:
	var _condition: String = ""
	var applies_trapping: bool = false
	var cures_target_after: StringName = &""

	func _init(condition: String) -> void:
		_condition = condition

	func base_power(battle: Battle, user: Battler, target: Battler, move: MoveData) -> int:
		return move.power * 2 if _holds(battle, user, target) else move.power

	func _holds(battle: Battle, user: Battler, target: Battler) -> bool:
		match _condition:
			"target_poisoned": return target.pokemon.status == &"POISON"
			"target_status": return target.pokemon.status != &"NONE"
			"target_half_hp": return target.hp_fraction() <= 0.5
			"target_acted": return target.has_acted
			"target_not_acted": return not target.has_acted
			"target_lost_hp": return target.took_damage_this_turn
			"user_lost_hp": return user.took_damage_this_turn
			"user_no_item": return user.held_item().is_empty()
			"user_move_failed": return user.last_move_failed
			"user_status": return user.pokemon.status in [&"POISON", &"BURN", &"PARALYSIS"]
			"user_stats_lowered": return user.stats_lowered_this_turn
			"ally_fainted": return battle.get_party(user.side_index()).able_count() < battle.get_party(user.side_index()).size()
			"electric_terrain": return battle.field.terrain == &"Electric"
			"target_underground": return target.get_effect_id(BattleEffects.INVULNERABLE) == &"Underground"
			"target_underwater": return target.get_effect_id(BattleEffects.INVULNERABLE) == &"Underwater"
			"target_in_sky": return target.get_effect_id(BattleEffects.INVULNERABLE) == &"Sky"
			"target_asleep": return target.is_asleep()
			"target_paralyzed": return target.pokemon.status == &"PARALYSIS"
		return false

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		if applies_trapping and not target.has_effect(BattleEffects.TRAPPING):
			target.set_effect(BattleEffects.TRAPPING, 5)
			target.set_effect(BattleEffects.TRAPPING_USER, user.index)
		if not cures_target_after.is_empty() and target.pokemon.status == cures_target_after:
			target.cure_status()

## Applies a timed volatile effect to the user, the target or the field.
class ApplyEffectEffect extends MoveEffect:
	enum Scope { USER, TARGET, FIELD }

	var _effect: StringName
	var _turns: int
	var _scope: Scope

	func _init(effect_name: StringName, turns: int, scope: Scope) -> void:
		_effect = effect_name
		_turns = turns
		_scope = scope

	func apply_status_move(battle: Battle, user: Battler, target: Battler, move: MoveData) -> bool:
		if _apply(battle, user, target):
			return true
		return super.apply_status_move(battle, user, target, move)

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		_apply(battle, user, target)

	## Scores this effect for its intended side.
	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		match _scope:
			Scope.USER:
				if user.has_effect(_effect):
					return AIScores.USELESS
				return base + 20
			Scope.TARGET:
				if target.has_effect(_effect):
					return AIScores.USELESS
				return _target_effect_score(target, base)
			Scope.FIELD:
				if battle.field.has_effect(_effect):
					return AIScores.USELESS
				if _effect == BattleEffects.TRICK_ROOM:
					var slower: bool = user.effective_speed() < target.effective_speed()
					return base + (80 if slower else -70)
				return base + 20
		return base

## What one of the target-side effects is worth, for the handful whose value the battle can actually judge.
	func _target_effect_score(target: Battler, base: int) -> int:
		var score: int = base
		match _effect:
			BattleEffects.ENCORE:
				if target.last_move_used.is_empty():
					return 1
				var locked: MoveData = Database.move(target.last_move_used)
				score += 40 if locked != null and locked.is_status() else -20
			BattleEffects.TAUNT:
				score += 30
			BattleEffects.DISABLE:
				if target.last_move_used.is_empty():
					return 1
				score += 20
			BattleEffects.NIGHTMARE:
				if target.pokemon.status != &"SLEEP":
					return 1
				score += 40
			BattleEffects.MEAN_LOOK, BattleEffects.TRAPPING:
				score += 20
		if target.turns_active > 2:
			score -= 20
		return score

	func _apply(battle: Battle, user: Battler, target: Battler) -> bool:
		match _scope:
			Scope.USER:
				if user.has_effect(_effect):
					return false
				user.set_effect(_effect, _turns)
				if _effect == BattleEffects.LOCK_ON:
					user.set_effect(BattleEffects.LOCK_ON_TARGET, target.index)
				return true
			Scope.TARGET:
				if target.has_effect(_effect):
					return false
				target.set_effect(_effect, _turns)
				if _effect == BattleEffects.DISABLE:
					target.set_effect(BattleEffects.DISABLE_MOVE, target.last_move_used)
				if _effect == BattleEffects.ENCORE:
					target.set_effect(BattleEffects.ENCORE_MOVE, target.last_move_used)
				if _effect == BattleEffects.TRAPPING:
					target.set_effect(BattleEffects.TRAPPING_USER, user.index)
				return true
			Scope.FIELD:
				if battle.field.has_effect(_effect):
					battle.field.clear_effect(_effect)
					return true
				battle.field.set_effect(_effect, _turns)
				return true
		return false

class LeechSeedEffect extends MoveEffect:

	func succeeds_against(_battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		return not target.has_type(&"GRASS") and not target.has_effect(BattleEffects.LEECH_SEED)

## Evaluates the value of the move, based on the remaining health of the mon.
	func ai_score(_battle: Battle, _user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target.has_type(&"GRASS") or target.has_effect(BattleEffects.LEECH_SEED):
			return AIScores.USELESS
		return base + int(60.0 * target.hp_fraction())

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		target.set_effect(BattleEffects.LEECH_SEED, user.index + 1)
		battle.announce(Loc.line("{target} was seeded!", {"target": target.battle_name()}))
		return true

class PerishSongEffect extends MoveEffect:

	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if user.has_effect(BattleEffects.PERISH_SONG):
			return AIScores.USELESS
		var ours: int = battle.get_party(user.side_index()).able_count()
		var theirs: int = battle.get_party(user.opposing_side_index()).able_count()
		return base + 30 * (ours - theirs)

	func apply_status_move(battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> bool:
		var applied: bool = false
		for battler: Battler in battle.all_active_battlers():
			if battler.has_effect(BattleEffects.PERISH_SONG) or battler.has_ability(&"SOUNDPROOF"):
				continue
			battler.set_effect(BattleEffects.PERISH_SONG, 4)
			applied = true
		if applied:
			battle.announce("All battlers will faint in three turns!")
		return applied

class TrapBothEffect extends MoveEffect:

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		user.set_effect(BattleEffects.MEAN_LOOK, 999)
		target.set_effect(BattleEffects.MEAN_LOOK, 999)

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.is_trapped():
			return base
		var ours: int = battle.get_party(user.side_index()).able_count()
		var theirs: int = battle.get_party(target.side_index()).able_count()
		return base + 10 * (theirs - ours) + int(20.0 * (user.hp_fraction() - target.hp_fraction()))

class FalseSwipeEffect extends MoveEffect:

	func final_damage_multiplier(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> float:
		return 1.0

	func fixed_damage(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> int:
		# Never lethal: the battle caps damage at one less than current HP.
		return -1

	func succeeds_against(_battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		return target.hp() > 0

	func ai_score(_battle: Battle, _user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return base
		return base - int(40.0 * (1.0 - target.hp_fraction()))

class BellyDrumEffect extends MoveEffect:

	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if user.hp() <= user.total_hp() / 2:
			return AIScores.USELESS
		if user.get_stat_stage(&"ATTACK") >= GameSettings.data.max_stat_stage:
			return AIScores.USELESS
		return base + (90 if user.hp_fraction() > 0.9 else 20)

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		if user.hp() <= user.total_hp() / 2:
			return false
		if user.get_stat_stage(&"ATTACK") >= GameSettings.data.max_stat_stage:
			return false
		user.take_damage(user.total_hp() / 2)
		user.change_stat_stage(&"ATTACK", GameSettings.data.max_stat_stage * 2)
		battle.announce(Loc.line("{pokemon} maximised its Attack!", {"pokemon": user.battle_name()}))
		return true

## Synthesis, Moonlight and Morning Sun: healing that scales with the weather.
class WeatherHealEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		if user.hp() >= user.total_hp():
			return false
		var fraction: float = 0.5
		match battle.field.effective_weather(battle):
			&"Sun", &"HarshSun":
				fraction = 2.0 / 3.0
			&"Rain", &"HeavyRain", &"Sandstorm", &"Hail":
				fraction = 0.25
		if battle.field.terrain == &"Grassy":
			fraction = maxf(fraction, 2.0 / 3.0)
		user.restore_hp(maxi(int(float(user.total_hp()) * fraction), 1))
		battle.announce(Loc.line("{pokemon} regained health!", {"pokemon": user.battle_name()}))
		return true

	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, _base: int) -> int:
		if not AIBattlerView.can_heal(user):
			return AIScores.USELESS
		var fraction: float = 0.5
		match battle.field.effective_weather(battle):
			&"Sun", &"HarshSun":
				fraction = 2.0 / 3.0
			&"Rain", &"HeavyRain", &"Sandstorm", &"Hail":
				fraction = 0.25
		if battle.field.terrain == &"Grassy":
			fraction = maxf(fraction, 2.0 / 3.0)
		var restored: float = minf(fraction, 1.0 - user.hp_fraction())
		if restored < 0.15:
			return AIScores.USELESS
		return AIScores.BASE + int(100.0 * restored)

class CureStatusEffect extends MoveEffect:
	var _status: StringName
	var _on_user: bool

	func _init(status_id: StringName, on_user: bool) -> void:
		_status = status_id
		_on_user = on_user

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		var subject: Battler = user if _on_user else target
		if subject.pokemon.status == &"NONE":
			return false
		if _status != &"ANY" and subject.pokemon.status != _status:
			return false
		subject.cure_status()
		battle.announce(Loc.line("{subject}'s status was cured!", {"subject": subject.battle_name()}))
		return true

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		var subject: Battler = user if _on_user else target
		if subject == null or subject.pokemon.status == &"NONE":
			return AIScores.USELESS
		if _status != &"ANY" and subject.pokemon.status != _status:
			return AIScores.USELESS
		if subject.side_index() != user.side_index():
			return AIScores.USELESS
		if AIBattlerView.wants_status(battle, subject, subject.pokemon.status):
			return AIScores.USELESS
		var stopping: bool = subject.pokemon.status == &"SLEEP" or subject.pokemon.status == &"FROZEN"
		return base + (40 if stopping else 15)

class CurePartyStatusEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		var cured: bool = false
		for pkmn: Pokemon in battle.get_party(user.side_index()).members:
			if pkmn.status != &"NONE":
				pkmn.heal_status()
				cured = true
		if cured:
			battle.announce("The party's status problems were cured!")
		return cured

## Worth a share per Pokemon it would clear
	func ai_score(_battle_unused: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		var battle: Battle = user.battle
		if battle == null:
			return base
		var afflicted: int = 0
		for pkmn: Pokemon in battle.get_party(user.side_index()).members:
			if pkmn != null and pkmn.status != &"NONE":
				afflicted += 1
		if afflicted == 0:
			return AIScores.USELESS
		return base + 20 * mini(afflicted, 3)

class PsychoShiftEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		if user.pokemon.status == &"NONE":
			return false
		var status: StringName = user.pokemon.status
		if not target.inflict_status(status, user.pokemon.status_count, user):
			return false
		user.cure_status()
		battle.announce_status(target, status)
		return true

	## Scores the item exchange for both battlers.
	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or user.pokemon.status == &"NONE":
			return AIScores.USELESS
		if not target.can_take_status(user.pokemon.status, user):
			return AIScores.USELESS
		if AIBattlerView.wants_status(battle, user, user.pokemon.status):
			return AIScores.USELESS
		if AIBattlerView.wants_status(battle, target, user.pokemon.status):
			return base
		return base + 40

## The stat-stage manipulation moves: Haze, Topsy-Turvy, Psych Up and the swaps.
class StatStageEffect extends MoveEffect:
	var _mode: String

	func _init(mode: String) -> void:
		_mode = mode

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		match _mode:
			"reset_target":
				target.reset_stat_stages()
			"reset_all":
				for battler: Battler in battle.all_active_battlers():
					battler.reset_stat_stages()
			"invert_target":
				for stat: StringName in Battler.STAT_STAGE_IDS:
					target.stat_stages[stat] = -target.get_stat_stage(stat)
			"copy":
				for stat: StringName in Battler.STAT_STAGE_IDS:
					user.stat_stages[stat] = target.get_stat_stage(stat)
			"steal":
				var stolen: bool = false
				for stat: StringName in Battler.STAT_STAGE_IDS:
					var stage: int = target.get_stat_stage(stat)
					if stage <= 0:
						continue
					user.change_stat_stage(stat, stage)
					target.stat_stages[stat] = 0
					stolen = true
				if not stolen:
					return false
			"swap_all":
				_swap(user, target, Battler.STAT_STAGE_IDS)
			"swap_offense":
				_swap(user, target, [&"ATTACK", &"SPECIAL_ATTACK"])
			"swap_defense":
				_swap(user, target, [&"DEFENSE", &"SPECIAL_DEFENSE"])
			"random_target":
				var candidates: Array[StringName] = []
				for stat: StringName in Battler.STAT_STAGE_IDS:
					if target.get_stat_stage(stat) < GameSettings.data.max_stat_stage:
						candidates.append(stat)
				if candidates.is_empty():
					return false
				target.change_stat_stage(candidates[RNG.below(candidates.size())], 2)
		battle.announce("Stat changes were shuffled!")
		return true

	func _swap(user: Battler, target: Battler, stats: Array) -> void:
		for stat: StringName in stats:
			var held: int = user.get_stat_stage(stat)
			user.stat_stages[stat] = target.get_stat_stage(stat)
			target.stat_stages[stat] = held

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		var mine: int = AIBattlerView.positive_stat_stages(user)
		var theirs: int = AIBattlerView.positive_stat_stages(target) if target != null else 0
		match _mode:
			"reset_target", "invert_target":
				if target == null:
					return AIScores.USELESS
				var net: int = _net_stages(target)
				if net == 0:
					return AIScores.USELESS
				var hostile: int = 1 if target.side_index() != user.side_index() else -1
				return base + 12 * net * hostile
			"reset_all":
				var difference: int = 0
				for battler: Battler in battle.all_active_battlers():
					var weight: int = -1 if battler.side_index() == user.side_index() else 1
					difference += _net_stages(battler) * weight
				if difference == 0:
					return AIScores.USELESS
				return base + 12 * difference
			"copy":
				if theirs <= 0:
					return AIScores.USELESS
				return base + 12 * (theirs - mine)
			"steal":
				if target == null or theirs <= 0:
					return AIScores.USELESS
				return base + 15 * theirs
			"swap_all", "swap_offense", "swap_defense":
				if target == null:
					return AIScores.USELESS
				var gain: int = _net_stages(target) - _net_stages(user)
				if gain <= 0:
					return AIScores.USELESS
				return base + 12 * gain
			"random_target":
				if target == null or target.side_index() != user.side_index():
					return AIScores.USELESS
				return base + 10
		return base

	func _net_stages(battler: Battler) -> int:
		var total: int = 0
		for stat: StringName in Battler.STAT_STAGE_IDS:
			total += battler.get_stat_stage(stat)
		return total

## Knock Off, Thief, Trick, Bestow, Recycle and Incinerate.
class ItemTrickEffect extends MoveEffect:
	var _mode: String

	func _init(mode: String) -> void:
		_mode = mode

	## What the exchange is worth, from [AIRatings].
	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return base
		var mine: int = AIRatings.for_item(user, user.held_item())
		var theirs: int = AIRatings.for_item(user, target.held_item())
		match _mode:
			"knock_off", "destroy_berry":
				return base + 5 * AIRatings.for_item(target, target.held_item())
			"steal":
				if target.held_item().is_empty() or not user.held_item().is_empty():
					return AIScores.USELESS
				return base + 5 * theirs
			"give":
				if user.held_item().is_empty() or not target.held_item().is_empty():
					return AIScores.USELESS
				return base - 5 * mine
			"swap":
				if user.held_item().is_empty() and target.held_item().is_empty():
					return AIScores.USELESS
				return base + 5 * (theirs - mine)
			"recycle":
				return base if not user.consumed_item.is_empty() else AIScores.USELESS
		return base

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		_apply(battle, user, target)

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		return _apply(battle, user, target)

	func _apply(battle: Battle, user: Battler, target: Battler) -> bool:
		match _mode:
			"knock_off":
				if target.held_item().is_empty() or target.has_ability(&"STICKYHOLD"):
					return false
				var lost: StringName = target.consume_item(false)
				battle.announce(Loc.line("{target} lost its {lost}!", {"target": target.battle_name(), "lost": _item_name(lost)}))
				return true
			"steal":
				if target.held_item().is_empty() or not user.held_item().is_empty():
					return false
				if target.has_ability(&"STICKYHOLD"):
					return false
				var stolen: StringName = target.consume_item(false)
				user.pokemon.held_item = stolen
				battle.announce("%s stole %s's %s!" % [user.battle_name(), target.battle_name(), _item_name(stolen)])
				return true
			"give":
				if user.held_item().is_empty() or not target.held_item().is_empty():
					return false
				target.pokemon.held_item = user.consume_item(false)
				return true
			"swap":
				if user.held_item().is_empty() and target.held_item().is_empty():
					return false
				if target.has_ability(&"STICKYHOLD"):
					return false
				var held: StringName = user.pokemon.held_item
				user.pokemon.held_item = target.pokemon.held_item
				target.pokemon.held_item = held
				battle.announce(Loc.line("{pokemon} swapped items with {target}!", {"pokemon": user.battle_name(), "target": target.battle_name()}))
				return true
			"recycle":
				if not user.held_item().is_empty() or user.consumed_item.is_empty():
					return false
				user.pokemon.held_item = user.consumed_item
				user.consumed_item = &""
				return true
			"destroy_berry", "eat_berry":
				var record: ItemData = Database.item(target.held_item())
				if record == null or not record.is_berry():
					return false
				target.consume_item(false)
				return true
		return false

	func _item_name(item_id: StringName) -> String:
		var record: ItemData = Database.item(item_id)
		return record.display_name if record != null else String(item_id)

## Soak, Trick-or-Treat, Conversion and friends.
class TypeChangeEffect extends MoveEffect:
	var _mode: String
	var _type: StringName

	func _init(mode: String, type_id: StringName) -> void:
		_mode = mode
		_type = type_id

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		match _mode:
			"set_target":
				if target.types() == [_type]:
					return false
				target.type_override = [_type]
			"add_target":
				if target.has_type(_type):
					return false
				var updated: Array[StringName] = target.types()
				updated.append(_type)
				target.type_override = updated
			"copy_target":
				user.type_override = target.types()
			"user_move_type":
				if user.moves().is_empty():
					return false
				var record: MoveData = user.moves()[0].data()
				if record == null:
					return false
				user.type_override = [record.type]
			"lose_fire":
				if not user.has_type(&"FIRE"):
					return false
				var remaining: Array[StringName] = []
				for type_id: StringName in user.types():
					if type_id != &"FIRE":
						remaining.append(type_id)
				user.type_override = remaining if not remaining.is_empty() else [&"NORMAL"] as Array[StringName]
			"environment":
				user.type_override = [_type_for_environment(battle.field.environment)]
		battle.announce(Loc.line("{target}'s type changed!", {"target": (target.battle_name() if _mode.begins_with("set") or _mode.begins_with("add") else user.battle_name())}))
		return true

## Checks if rewriting the type would actually improve the user's battle abilities.
	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		match _mode:
			"set_target":
				if target == null or target.types() == [_type]:
					return AIScores.USELESS
				if target.side_index() == user.side_index():
					return AIScores.USELESS
				# Worth doing when the user's own moves hit the new type harder.
				var before: float = _best_effectiveness(battle, user, target.types())
				var after: float = _best_effectiveness(battle, user, [_type] as Array[StringName])
				return base + int(30.0 * (after - before))
			"add_target":
				if target == null or target.has_type(_type):
					return AIScores.USELESS
				if target.side_index() == user.side_index():
					return AIScores.USELESS
				return base + 15
			"user_move_type", "copy_target", "environment":
				return base + 5
			"lose_fire":
				return base if user.has_type(&"FIRE") else AIScores.USELESS
		return base

## The best multiplier any of the battler's damaging moves would get against a set of defending types.
	func _best_effectiveness(battle: Battle, battler: Battler, types: Array[StringName]) -> float:
		var best: float = 0.0
		for move: PokemonMove in battler.moves():
			var record: MoveData = move.data() if move != null else null
			if record == null or not record.is_damaging():
				continue
			var effect: MoveEffect = MoveEffects.get_effect(record.function_code)
			var move_type: StringName = DamageCalculator.move_type_for(
				battle, battler, battler, record, effect)
			best = maxf(best, Database.type_effectiveness(move_type, types))
		return best

	func _type_for_environment(environment: StringName) -> StringName:
		match environment:
			&"Grass", &"TallGrass", &"Forest": return &"GRASS"
			&"Sand", &"Desert": return &"GROUND"
			&"Rock", &"Cave": return &"ROCK"
			&"MovingWater", &"StillWater", &"Underwater": return &"WATER"
			&"Snow", &"Ice": return &"ICE"
			&"Volcano": return &"FIRE"
			&"Sky": return &"FLYING"
		return &"NORMAL"

class EndeavorEffect extends MoveEffect:

	func succeeds_against(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		return target.hp() > user.hp()

	func fixed_damage(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> int:
		return maxi(target.hp() - user.hp(), 1)

## Worth what it would actually take off, which is everything above the user's own health.
	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.hp() <= user.hp():
			return AIScores.USELESS
		var share: float = float(target.hp() - user.hp()) / float(maxi(target.hp(), 1))
		return base + int(40.0 * share)

class PainSplitEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		var average: int = (user.hp() + target.hp()) / 2
		user.pokemon.hp = mini(average, user.total_hp())
		target.pokemon.hp = mini(average, target.total_hp())
		battle.announce("The battlers shared their pain!")
		return true

	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.side_index() == user.side_index():
			return AIScores.USELESS
		@warning_ignore("integer_division")
		var average: int = (user.hp() + target.hp()) / 2
		var gained: int = mini(average, user.total_hp()) - user.hp()
		if gained <= 0:
			return AIScores.USELESS
		return base + int(60.0 * float(gained) / float(maxi(user.total_hp(), 1)))

class PresentEffect extends MoveEffect:

	func base_power(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> int:
		var roll: int = RNG.below(100)
		if roll < 40:
			return 40
		if roll < 70:
			return 80
		if roll < 80:
			return 120
		return 1

## The power averaged over the four outcomes, because [method base_power] rolls and [BattleAI] must not.
	func expected_base_power(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> int:
		return 52

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		if damage <= 1:
			target.restore_hp(target.total_hp() / 4)
			battle.announce(Loc.line("{target} regained health!", {"target": target.battle_name()}))

	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return base
		if target.side_index() == user.side_index():
			return base + (20 if AIBattlerView.can_heal(target) else -40)
		return base - 15

## Counter, Mirror Coat and Metal Burst.
class CounterEffect extends MoveEffect:
	var _category: int
	var _multiplier: float

	func _init(category: int, multiplier: float) -> void:
		_category = category
		_multiplier = multiplier

	func succeeds_against(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		if user.damage_taken_this_turn <= 0:
			return false
		return _category < 0 or user.last_damage_category == _category

	## This cannot be checked until the user has been hit.
	func failure_is_known_when_choosing() -> bool:
		return false

## A bet that the foe attacks, and with the right half of its moveset.
	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return base
		var expected: bool = false
		match _category:
			MoveData.Category.PHYSICAL:
				expected = AIBattlerView.has_physical_move(target)
			MoveData.Category.SPECIAL:
				expected = AIBattlerView.has_special_move(target)
			_:
				expected = AIBattlerView.has_damaging_move(target)
		if not expected:
			return AIScores.USELESS
		var worst: float = 0.0
		for move: PokemonMove in target.moves():
			var record: MoveData = move.data() if move != null else null
			if record == null or not record.is_damaging():
				continue
			var effect: MoveEffect = MoveEffects.get_effect(record.function_code)
			worst = maxf(worst, float(AIMoveView.rough_damage(battle, target, user, record, effect)))
		if worst >= float(user.hp()):
			return AIScores.USELESS
		return base + 10 - 15 * mini(user.consecutive_move_uses, 3)

	func fixed_damage(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> int:
		return maxi(int(float(user.damage_taken_this_turn) * _multiplier), 1)

## Defog, Haze-adjacent field clearing and Rapid Spin.
class RoostEffect extends MoveEffect:

	func _init() -> void:
		heal_fraction = 0.5
		restores_hp = true

	func succeeds_against(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		return user.hp() < user.total_hp()

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		@warning_ignore("integer_division")
		var healed: int = maxi(user.total_hp() / 2, 1)
		if user.restore_hp(healed) <= 0:
			return false
		user.set_effect(BattleEffects.ROOST, 1)
		battle.announce(Loc.line("{pokemon} regained health!", {"pokemon": user.battle_name()}))
		return true

## Half the user's health back, at the price of standing on the ground for the rest of the round.
	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if not user.has_type(&"FLYING"):
			return base
		var grounded: int = 0
		for foe: Battler in battle.opposing_battlers(user):
			if AIBattlerView.has_damaging_move_of(battle, foe, &"GROUND"):
				grounded += 1
		return base - 25 * grounded

## Smack Down and Thousand Arrows: a blow that brings its target down to earth and keeps it there.
class GroundTargetEffect extends MoveEffect:

	func on_after_all_hits(
		battle: Battle, _user: Battler, target: Battler, _move: MoveData, damage: int
	) -> void:
		if damage <= 0 or target.is_fainted() or not target.is_airborne():
			return
		target.set_effect(BattleEffects.SMACK_DOWN, 999)
		battle.announce(Loc.line("{pokemon} fell straight down!", {"pokemon": target.battle_name()}))

## Flying Press, which counts as Fighting and Flying at once.
class FlyingPressEffect extends MoveEffect:

	func extra_effectiveness_type() -> StringName:
		return &"FLYING"

class WishEffect extends MoveEffect:

	func _init() -> void:
		restores_hp = true

	func succeeds_against(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		return int(battle.effects_at_position(user.index).get(BattleEffects.WISH_COUNTER, 0)) <= 0

	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if user.hp_fraction() > 0.9:
			return AIScores.USELESS
		return base

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		var slot: Dictionary = battle.effects_at_position(user.index)
		if int(slot.get(BattleEffects.WISH_COUNTER, 0)) > 0:
			return false
		@warning_ignore("integer_division")
		slot[BattleEffects.WISH_AMOUNT] = maxi(user.total_hp() / 2, 1)
		slot[BattleEffects.WISH_COUNTER] = 2
		slot[BattleEffects.WISH_MAKER] = user.battle_name()
		battle.announce(Loc.line("{pokemon} made a wish!", {"pokemon": user.battle_name()}))
		return true

## Pay Day: coins scattered on the floor, picked up when the battle is won.
class PayDayEffect extends MoveEffect:

	func on_after_all_hits(
		battle: Battle, user: Battler, _target: Battler, _move: MoveData, damage: int
	) -> void:
		if damage <= 0:
			return
		battle.scattered_money += user.level() * 5
		battle.announce("Coins scattered everywhere!")

	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		return base + (5 if user.is_player_side() else -5)

## Happy Hour: twice the prize money for winning.
class HappyHourEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		if battle.doubled_winnings:
			return false
		battle.doubled_winnings = true
		battle.announce(Loc.line("Everyone is caught up in a happy mood!", {
			"pokemon": user.battle_name(),
		}))
		return true

## Doubles the prize money and nothing else, so it costs a whole round and does not help win the fight.
	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if battle.doubled_winnings or not user.is_player_side():
			return AIScores.USELESS
		return base - 20

## Puts a shield up for the round.
class ProtectionEffect extends MoveEffect:

	## The function codes this covers, and what each shield does back.
	const KINDS: Dictionary = {
		&"ProtectUser": "plain",
		&"ProtectUserBanefulBunker": "poison",
		&"ProtectUserFromDamagingMovesKingsShield": "lower_attack",
		&"ProtectUserFromDamagingMovesObstruct": "lower_defense",
		&"ProtectUserFromTargetingMovesSpikyShield": "spikes",
	}

## The highest the failure denominator climbs to.
	const MAXIMUM_RATE: int = 8

	var kind: StringName = &"plain"

	func _init(of_kind: StringName = &"plain") -> void:
		kind = of_kind
		is_protect_move = true

## Worth most on the first go and less each time
	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		var rate: int = maxi(int(user.get_effect(BattleEffects.PROTECT_RATE)), 1)
		if rate <= 1:
			return base
		return int(float(base) / float(rate))

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		var rate: int = maxi(int(user.get_effect(BattleEffects.PROTECT_RATE)), 1)
		if rate > 1 and RNG.below(rate) != 0:
			user.set_effect(BattleEffects.PROTECT_RATE, 1)
			failure_message = Loc.line("But it failed!")
			return false
		user.set_effect(BattleEffects.PROTECT, kind)
		user.set_effect(BattleEffects.PROTECT_RATE, mini(rate * 2, MAXIMUM_RATE))
		battle.announce(Loc.line("{pokemon} protected itself!", {"pokemon": user.battle_name()}))
		return true

class RemovalEffect extends MoveEffect:
	var _mode: String

	func _init(mode: String) -> void:
		_mode = mode

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		_apply(battle, user, target)

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		return _apply(battle, user, target)

	func _apply(battle: Battle, user: Battler, target: Battler) -> bool:
		match _mode:
			"screens":
				battle.get_side(target.side_index()).clear_screens()
				battle.announce("The screens shattered!")
				return true
			"protections":
				target.clear_effect(BattleEffects.PROTECT)
				battle.get_side(target.side_index()).clear_protections()
				return true
			"terrain":
				if battle.field.terrain == &"None":
					return false
				battle.field.set_terrain(&"None", 0)
				battle.announce("The terrain returned to normal!")
				return true
			"hazards":
				battle.get_side(user.side_index()).clear_hazards()
				user.clear_effect(BattleEffects.TRAPPING)
				user.clear_effect(BattleEffects.LEECH_SEED)
				return true
			"defog":
				battle.get_side(target.side_index()).clear_hazards()
				battle.get_side(target.side_index()).clear_screens()
				battle.field.set_terrain(&"None", 0)
				return true
		return false

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		var found: int = 0
		match _mode:
			"screens":
				if target != null:
					found = _screen_count(battle.get_side(target.side_index()))
			"protections":
				found = 1 if target != null and target.has_effect(BattleEffects.PROTECT) else 0
			"terrain":
				found = 1 if battle.field.terrain != &"None" else 0
			"hazards":
				found = _hazard_count(battle.get_side(user.side_index()))
				if user.has_effect(BattleEffects.TRAPPING) or user.has_effect(BattleEffects.LEECH_SEED):
					found += 1
			"defog":
				if target != null:
					var side: BattleSide = battle.get_side(target.side_index())
					found = _hazard_count(side) + _screen_count(side)
				if battle.field.terrain != &"None":
					found += 1
		if found == 0:
			return base if _clears_by_hitting() else AIScores.USELESS
		return base + 20 * mini(found, 3)

## Returns `true` for the clearing moves that also deal damage, which are the ones worth using even with nothing to clear.
	func _clears_by_hitting() -> bool:
		return _mode == "hazards" or _mode == "screens"

	func _hazard_count(side: BattleSide) -> int:
		var found: int = 0
		for effect: StringName in [BattleEffects.SPIKES, BattleEffects.TOXIC_SPIKES,
				BattleEffects.STEALTH_ROCK, BattleEffects.STICKY_WEB]:
			if side.has_effect(effect):
				found += 1
		return found

	func _screen_count(side: BattleSide) -> int:
		var found: int = 0
		for effect: StringName in [BattleEffects.REFLECT, BattleEffects.LIGHT_SCREEN,
				BattleEffects.AURORA_VEIL]:
			if side.has_effect(effect):
				found += 1
		return found

## Gastro Acid, Worry Seed, Skill Swap, Role Play and Entrainment.
class AbilityTrickEffect extends MoveEffect:
	var _mode: String

	func _init(mode: String) -> void:
		_mode = mode

	## Scores the exchange by each battler's resulting ability.
	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return base
		var mine: int = AIRatings.for_ability(battle, user, user.ability())
		var theirs: int = AIRatings.for_ability(battle, target, target.ability())
		match _mode:
			"suppress":
				if target.ability_suppressed:
					return AIScores.USELESS
				return base + 5 * theirs
			"set_simple":
				var to_an_ally: bool = user.side_index() == target.side_index()
				return base + (10 if to_an_ally else -10)
			"set_insomnia":
				return base + 5 * maxi(theirs, 0)
			"copy_to_target":
				return base - 5 * AIRatings.for_ability(battle, target, user.ability())
			"copy_to_user":
				return base + 5 * (AIRatings.for_ability(battle, user, target.ability()) - mine)
			"swap":
				return base + 5 * (theirs - mine)
		return base

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		match _mode:
			"suppress":
				if target.ability_suppressed:
					return false
				target.ability_suppressed = true
			"set_simple":
				target.ability_override = &"SIMPLE"
			"set_insomnia":
				target.ability_override = &"INSOMNIA"
			"copy_to_target":
				target.ability_override = user.ability()
			"copy_to_user":
				user.ability_override = target.ability()
			"swap":
				var held: StringName = user.ability()
				user.ability_override = target.ability()
				target.ability_override = held
		battle.announce("An ability was changed!")
		return true
