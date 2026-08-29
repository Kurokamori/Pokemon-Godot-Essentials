class_name AIContext
extends RefCounted
## Everything one scoring pass is about

var battle: Battle = null

## The battler whose action is being chosen.
var user: Battler = null

## The battler the move is being weighed against, 
## `null` for a move aimed at the field or at the user's own side.
var target: Battler = null
var record: MoveData = null
var effect: MoveEffect = null
var skill: AISkill = null

static func make(
	of_battle: Battle, by_user: Battler, against: Battler,
	move: MoveData, move_effect: MoveEffect, of_skill: AISkill
) -> AIContext:
	var built: AIContext = AIContext.new()
	built.battle = of_battle
	built.user = by_user
	built.target = against
	built.record = move
	built.effect = move_effect
	built.skill = of_skill
	return built

## The same context aimed at somebody else, for scoring a spread move one target at a time.
func against_target(other: Battler) -> AIContext:
	return AIContext.make(battle, user, other, record, effect, skill)

func has_flag(flag: StringName) -> bool:
	return skill != null and skill.has_flag(flag)

## A battler for [method MoveEffect.ai_score] to be told about when the move has no target of its own.
## Use the nearest foe when an effect needs a target for a field or self-targeting move.
func representative_target() -> Battler:
	if target != null:
		return target
	if battle != null:
		var foes: Array[Battler] = battle.opposing_battlers(user)
		if not foes.is_empty():
			return foes[0]
	return user

## The type the move would come out as this use.
func move_type() -> StringName:
	if record == null:
		return &"NORMAL"
	var against: Battler = target if target != null else user
	return DamageCalculator.move_type_for(battle, user, against, record, effect)

## Returns `true` when this particular use deals damage. 
func is_damaging() -> bool:
	if record == null or not record.is_damaging():
		return false
	return effect.is_damaging_this_use(battle, user, record)

func is_status_move() -> bool:
	return not is_damaging()

## Whether [param battler] is on the other side from the one choosing.
func opposes(battler: Battler) -> bool:
	return battler != null and user != null and battler.side_index() != user.side_index()

## Every battler on the far side from [param side]
func foes_of(side: int) -> Array[Battler]:
	var found: Array[Battler] = []
	if battle == null:
		return found
	for battler: Battler in battle.all_active_battlers():
		if battler.side_index() != side:
			found.append(battler)
	return found

## Every battler on [param side]
func same_side_as(side: int) -> Array[Battler]:
	var found: Array[Battler] = []
	if battle == null:
		return found
	for battler: Battler in battle.all_active_battlers():
		if battler.side_index() == side:
			found.append(battler)
	return found

## Whether the user's Ability lets it ignore the target's
func ignores_target_ability() -> bool:
	return user != null and AbilityEffects.ignores_abilities(user)

## The target's Ability as the user can act on it — empty when the user is carrying a Mold Breaker
func readable_target_ability() -> StringName:
	if target == null or ignores_target_ability():
		return &""
	return target.ability()
