class_name MoveEffectsStatExtras

## The stat moves that pick their own targets or work on base stats rather than on stages.

## The most times Stockpile can be used before it has to be spent.
const MAX_STOCKPILE: int = 3

## How much of the user's maximum HP Swallow restores at each Stockpile level.
const SWALLOW_FRACTIONS: Array[float] = [0.25, 0.5, 1.0]

static func register_all() -> void:
	MoveEffects.register(&"RaisePlusMinusUserAndAlliesAtkSpAtk1",
		PlusMinusEffect.new([&"ATTACK", &"SPECIAL_ATTACK"]))
	MoveEffects.register(&"RaisePlusMinusUserAndAlliesDefSpDef1",
		PlusMinusEffect.new([&"DEFENSE", &"SPECIAL_DEFENSE"]))
	MoveEffects.register(&"RaiseGroundedGrassBattlersAtkSpAtk1",
		GrassBattlersEffect.new([&"ATTACK", &"SPECIAL_ATTACK"], true))
	MoveEffects.register(&"RaiseGrassBattlersDef1",
		GrassBattlersEffect.new([&"DEFENSE"], false))
	MoveEffects.register(&"LowerPoisonedTargetAtkSpAtkSpd1", VenomDrenchEffect.new())
	MoveEffects.register(&"UserTargetSwapBaseSpeed",
		SwapBaseStatsEffect.new([&"SPEED"], "%s switched Speed with its target!"))
	MoveEffects.register(&"UserTargetAverageBaseAtkSpAtk",
		AverageBaseStatsEffect.new([&"ATTACK", &"SPECIAL_ATTACK"], "%s shared its power with the target!"))
	MoveEffects.register(&"UserTargetAverageBaseDefSpDef",
		AverageBaseStatsEffect.new([&"DEFENSE", &"SPECIAL_DEFENSE"], "%s shared its guard with the target!"))
	MoveEffects.register(&"UserSwapBaseAtkDef", PowerTrickEffect.new())
	MoveEffects.register(&"UserAddStockpileRaiseDefSpDef1", StockpileEffect.new())
	MoveEffects.register(&"PowerDependsOnUserStockpile", SpitUpEffect.new())
	MoveEffects.register(&"HealUserDependingOnUserStockpile", SwallowEffect.new())

## Gives back Stockpile's stages, then clears its count.
static func score_chosen_targets(
	user: Battler, chosen: Array[Battler], stats: Array[StringName], base: int
) -> int:
	if chosen.is_empty():
		return AIScores.USELESS
	var worth: int = 0
	for battler: Battler in chosen:
		var direction: int = 1 if battler.side_index() == user.side_index() else -1
		for stat: StringName in stats:
			if battler.can_raise_stat(stat):
				worth += 10 * direction
	if worth == 0:
		return AIScores.USELESS
	return base + worth

static func spend_stockpile(battle: Battle, user: Battler) -> void:
	var defense: int = int(user.get_effect(BattleEffects.STOCKPILE_DEFENSE))
	if defense > 0:
		battle.change_stat_stage(user, &"DEFENSE", -defense, user)
	var special: int = int(user.get_effect(BattleEffects.STOCKPILE_SPECIAL_DEFENSE))
	if special > 0:
		battle.change_stat_stage(user, &"SPECIAL_DEFENSE", -special, user)
	user.clear_effect(BattleEffects.STOCKPILE)
	user.clear_effect(BattleEffects.STOCKPILE_DEFENSE)
	user.clear_effect(BattleEffects.STOCKPILE_SPECIAL_DEFENSE)

# === Effect Types ==

## Gear Up and Magnetic Flux, which only help allies with Plus or Minus.
class PlusMinusEffect extends MoveEffect:
	var _stats: Array[StringName]

	func _init(stats: Array[StringName]) -> void:
		_stats = stats

	func override_targets(battle: Battle, user: Battler, _targets: Array[Battler], _move: MoveData) -> Array[Battler]:
		var chosen: Array[Battler] = []
		for candidate: Battler in battle.allies_of(user) + [user]:
			if candidate.has_ability(&"PLUS") or candidate.has_ability(&"MINUS"):
				chosen.append(candidate)
		return chosen

	func can_be_used(battle: Battle, user: Battler, _move: MoveData) -> bool:
		return not override_targets(battle, user, [] as Array[Battler], null).is_empty()

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		var raised: bool = false
		for stat: StringName in _stats:
			if battle.change_stat_stage(target, stat, 1, user):
				raised = true
		return raised

## The targets are chosen by the move rather than aimed at, so nothing is declared for the generic stat scoring to read.

	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		return MoveEffectsStatExtras.score_chosen_targets(
			user, override_targets(battle, user, [] as Array[Battler], null), _stats, base)

## Rototiller and Flower Shield, which help every Grass-type on the field.
class GrassBattlersEffect extends MoveEffect:
	var _stats: Array[StringName]
	var _grounded_only: bool

	func _init(stats: Array[StringName], grounded_only: bool) -> void:
		_stats = stats
		_grounded_only = grounded_only

	func override_targets(battle: Battle, _user: Battler, _targets: Array[Battler], _move: MoveData) -> Array[Battler]:
		var chosen: Array[Battler] = []
		for candidate: Battler in battle.all_active_battlers():
			if not candidate.has_type(&"GRASS"):
				continue
			if candidate.has_effect(BattleEffects.INVULNERABLE):
				continue
			if _grounded_only and candidate.is_airborne():
				continue
			chosen.append(candidate)
		return chosen

	func can_be_used(battle: Battle, user: Battler, _move: MoveData) -> bool:
		return not override_targets(battle, user, [] as Array[Battler], null).is_empty()

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		var raised: bool = false
		for stat: StringName in _stats:
			if battle.change_stat_stage(target, stat, 1, user):
				raised = true
		return raised

## The targets are chosen by the move rather than aimed at, so nothing is declared for the generic stat scoring to read.

	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		return MoveEffectsStatExtras.score_chosen_targets(
			user, override_targets(battle, user, [] as Array[Battler], null), _stats, base)

## Venom Drench, which only works on poisoned targets.
class VenomDrenchEffect extends MoveEffect:
	const LOWERED_STATS: Array[StringName] = [&"ATTACK", &"SPECIAL_ATTACK", &"SPEED"]

	func succeeds_against(_battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		return target.pokemon.status == &"POISON"

## Scores Venom Drench only against poisoned targets.

	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.pokemon.status != &"POISON":
			return AIScores.USELESS
		if target.side_index() == user.side_index():
			return AIScores.USELESS
		var room: int = 0
		for stat: StringName in LOWERED_STATS:
			if target.can_lower_stat(stat, user):
				room += 1
		if room == 0:
			return AIScores.USELESS
		return base + 12 * room

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		var lowered: bool = false
		for stat: StringName in LOWERED_STATS:
			if battle.change_stat_stage(target, stat, -1, user):
				lowered = true
		return lowered

## Speed Swap, which exchanges base stats between the user and the target.
class SwapBaseStatsEffect extends MoveEffect:
	var _stats: Array[StringName]
	var _message: String

	func _init(stats: Array[StringName], message: String) -> void:
		_stats = stats
		_message = message

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		for stat: StringName in _stats:
			var held: int = user.base_stat(stat)
			user.set_base_stat(stat, target.base_stat(stat))
			target.set_base_stat(stat, held)
		battle.announce(_message % user.battle_name())
		return true

## Worth exactly the difference it makes, so it is a good move for something slow facing something fast and a gift the other way about.

	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.side_index() == user.side_index():
			return AIScores.USELESS
		var gained: int = 0
		for stat: StringName in _stats:
			gained += target.base_stat(stat) - user.base_stat(stat)
		if gained <= 0:
			return AIScores.USELESS
		return base + mini(gained / 4, 40)

## Power Split and Guard Split, which average base stats between the two.
class AverageBaseStatsEffect extends MoveEffect:
	var _stats: Array[StringName]
	var _message: String

	func _init(stats: Array[StringName], message: String) -> void:
		_stats = stats
		_message = message

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		for stat: StringName in _stats:
			var averaged: int = (user.base_stat(stat) + target.base_stat(stat)) / 2
			user.set_base_stat(stat, averaged)
			target.set_base_stat(stat, averaged)
		battle.announce(_message % user.battle_name())
		return true

## Averaging is worth doing only to something better than the user at the stats being averaged, and it hands the difference back if it is not.

	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.side_index() == user.side_index():
			return AIScores.USELESS
		var difference: int = 0
		for stat: StringName in _stats:
			difference += target.base_stat(stat) - user.base_stat(stat)
		if difference <= 0:
			return AIScores.USELESS
		return base + mini(difference / 6, 30)

## Power Trick, which swaps the user's own Attack and Defense, and swaps them back when used again.
class PowerTrickEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		if user.has_effect(BattleEffects.POWER_TRICK):
			user.clear_effect(BattleEffects.POWER_TRICK)
		else:
			user.set_effect(BattleEffects.POWER_TRICK, 1)
		battle.announce(Loc.line("{pokemon} switched its Attack and Defense!", {"pokemon": user.battle_name()}))
		return true

## Worth doing to something whose Defense is well above its Attack and that has a physical move to spend the new Attack on, and worth undoing when it is already the wrong way round.

	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if user.has_effect(BattleEffects.POWER_TRICK):
			return AIScores.USELESS
		if not AIBattlerView.has_physical_move(user):
			return AIScores.USELESS
		var gained: int = user.base_stat(&"DEFENSE") - user.base_stat(&"ATTACK")
		if gained <= 0:
			return AIScores.USELESS
		return base + mini(gained / 4, 40)

## Stockpile, which stacks up to three times and raises both defences each time.
class StockpileEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		if int(user.get_effect(BattleEffects.STOCKPILE)) < MoveEffectsStatExtras.MAX_STOCKPILE:
			return true
		failure_message = Loc.line("{pokemon} can't stockpile any more!", {"pokemon": user.battle_name()})
		return false

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		var count: int = int(user.get_effect(BattleEffects.STOCKPILE)) + 1
		user.set_effect(BattleEffects.STOCKPILE, count)
		battle.announce("%s stockpiled %d!" % [user.battle_name(), count])
		if battle.change_stat_stage(user, &"DEFENSE", 1, user):
			user.set_effect(BattleEffects.STOCKPILE_DEFENSE,
				int(user.get_effect(BattleEffects.STOCKPILE_DEFENSE)) + 1)
		if battle.change_stat_stage(user, &"SPECIAL_DEFENSE", 1, user):
			user.set_effect(BattleEffects.STOCKPILE_SPECIAL_DEFENSE,
				int(user.get_effect(BattleEffects.STOCKPILE_SPECIAL_DEFENSE)) + 1)
		return true

## Both defences up and something banked for Spit Up or Swallow, so it is worth stacking early and worth nothing once it is full.

	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		var stacked: int = int(user.get_effect(BattleEffects.STOCKPILE))
		if stacked >= MoveEffectsStatExtras.MAX_STOCKPILE:
			return AIScores.USELESS
		return base + 15 - 5 * stacked

## Spit Up, whose power is a hundred per stockpiled level and which spends the whole stockpile afterwards.
class SpitUpEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		if int(user.get_effect(BattleEffects.STOCKPILE)) > 0:
			return true
		failure_message = "But it failed to spit up a thing!"
		return false

	func base_power(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> int:
		return maxi(100 * int(user.get_effect(BattleEffects.STOCKPILE)), 1)

	## Scores the lost Stockpile defenses as a cost.

	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		var stacked: int = int(user.get_effect(BattleEffects.STOCKPILE))
		if stacked <= 0:
			return AIScores.USELESS
		return base + 10 * (stacked - 2)

	func on_after_all_hits(battle: Battle, user: Battler, _target: Battler, _move: MoveData, _damage: int) -> void:
		if user.is_fainted() or not user.has_effect(BattleEffects.STOCKPILE):
			return
		battle.announce(Loc.line("{pokemon}'s stockpiled effect wore off!", {"pokemon": user.battle_name()}))
		MoveEffectsStatExtras.spend_stockpile(battle, user)

## Swallow, which turns the stockpile into health.
class SwallowEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		if int(user.get_effect(BattleEffects.STOCKPILE)) <= 0:
			failure_message = "But it failed to swallow a thing!"
			return false
		if user.hp() < user.total_hp() and not user.has_effect(BattleEffects.HEAL_BLOCK):
			return true
		if user.has_effect(BattleEffects.STOCKPILE_DEFENSE) or user.has_effect(BattleEffects.STOCKPILE_SPECIAL_DEFENSE):
			return true
		return false

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		var level: int = clampi(int(user.get_effect(BattleEffects.STOCKPILE)), 1, MoveEffectsStatExtras.MAX_STOCKPILE)
		if not user.has_effect(BattleEffects.HEAL_BLOCK):
			var fraction: float = MoveEffectsStatExtras.SWALLOW_FRACTIONS[level - 1]
			if user.restore_hp(maxi(int(float(user.total_hp()) * fraction), 1)) > 0:
				battle.announce(Loc.line("{pokemon}'s HP was restored.", {"pokemon": user.battle_name()}))
		battle.announce(Loc.line("{pokemon}'s stockpiled effect wore off!", {"pokemon": user.battle_name()}))
		MoveEffectsStatExtras.spend_stockpile(battle, user)
		return true

## Scores Swallow by the HP it can restore.

	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		var stacked: int = int(user.get_effect(BattleEffects.STOCKPILE))
		if stacked <= 0 or not AIBattlerView.can_heal(user):
			return AIScores.USELESS
		var level: int = clampi(stacked, 1, MoveEffectsStatExtras.MAX_STOCKPILE)
		var fraction: float = MoveEffectsStatExtras.SWALLOW_FRACTIONS[level - 1]
		var restored: float = minf(fraction, 1.0 - user.hp_fraction())
		if restored < 0.15:
			return AIScores.USELESS
		return base + int(100.0 * restored)
