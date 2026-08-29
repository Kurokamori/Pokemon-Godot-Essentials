class_name AIMoveView
extends RefCounted
## What one move would do this round, worked out without rolling for any of it.
## Nothing here changes anything, and nothing here calls [RNG].

## The priority the move would resolve at in this battler's hands, Prankster and Grassy Glide included.
static func rough_priority(battle: Battle, user: Battler, record: MoveData) -> int:
	if record == null:
		return 0
	if battle == null:
		return record.priority
	return record.priority + battle.priority_bonus_for(user, record)

## Whether [param user] would act before [param target] with this move, priority, Trick Room and a slower-acting Ability all included.
static func moves_first(battle: Battle, user: Battler, target: Battler, record: MoveData) -> bool:
	var mine: int = rough_priority(battle, user, record)
	var theirs: int = 0
	if battle != null:
		var queued: BattleAction = battle.action_for(target.index)
		if queued != null and queued.move != null:
			theirs = rough_priority(battle, target, queued.move.data())
	if mine != theirs:
		return mine > theirs
	if user.has_ability(&"STALL"):
		return false
	if target.has_ability(&"STALL"):
		return true
	return AIBattlerView.faster_than(battle, user, target)

## The damage the move would do to [param target] over all of its hits.
## Returns `0` if it's a damage that does nothing
static func rough_damage(
	battle: Battle, user: Battler, target: Battler, record: MoveData, effect: MoveEffect
) -> int:
	if record == null or target == null or not record.is_damaging():
		return 0
	if not effect.is_damaging_this_use(battle, user, record):
		return 0
	var result: DamageCalculator.DamageResult = DamageCalculator.estimate(
		battle, user, target, record, effect)
	if result.immune:
		return 0
	return result.damage * maxi(rough_hit_count(user, effect), 1)

## How many times this move is likely to hit, notably for moves like Furry Swipes or Beat Up etc.
static func rough_hit_count(user: Battler, effect: MoveEffect) -> int:
	return effect.expected_hit_count(user)

## The move's chance of connecting, as a percentage.
static func rough_accuracy(
	battle: Battle, user: Battler, target: Battler, record: MoveData, effect: MoveEffect
) -> int:
	if record == null or target == null:
		return 100
	return DamageCalculator.hit_chance(battle, user, target, record, effect)

## What the target would be worth taking down: its substitute's remaining health when it is behind one, and its own otherwise.
static func effective_health(target: Battler) -> int:
	if target == null:
		return 1
	if target.has_substitute():
		return maxi(int(target.get_effect(BattleEffects.SUBSTITUTE)), 1)
	return maxi(target.hp(), 1)

# === Secondary Effects ===

## Returned by [method additional_effect_adjustment] when the move's secondary effect will not happen at all, 
## so nothing about it should be scored.
const EFFECT_NEGATED: int = -999

## What the move's secondary effect is worth to the score before the effect itself is looked at.
## - [constant EFFECT_NEGATED] when Sheer Force or Shield Dust will cancel it, so the caller must not score the effect at all.
## - `5` when Serene Grace or a Pledge rainbow will make it twice as likely.
## - `0` otherwise, including for a move whose effect is not a secondary one.
static func additional_effect_adjustment(
	battle: Battle, user: Battler, target: Battler, record: MoveData
) -> int:
	if record == null or record.effect_chance <= 0:
		return 0
	if user.has_ability(&"SHEERFORCE"):
		return EFFECT_NEGATED
	if target != null and target != user and not AbilityEffects.ignores_abilities(user):
		if target.has_ability(&"SHIELDDUST"):
			return EFFECT_NEGATED
	if record.effect_chance >= 100:
		return 0
	if user.has_ability(&"SERENEGRACE"):
		return 5
	if battle != null and battle.get_side(user.side_index()).has_effect(BattleEffects.RAINBOW):
		return 5
	return 0
