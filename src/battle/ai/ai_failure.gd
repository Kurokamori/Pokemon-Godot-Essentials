class_name AIFailure
extends RefCounted
## Whether a move is already known to fail, before it is scored at all.
## Predict certain failures only for trainers with [constant AISkill.PREDICT_MOVE_FAILURE].

## Whether the move cannot work at all this round, whoever it is aimed at.
static func will_fail(context: AIContext) -> bool:
	var user: Battler = context.user
	var record: MoveData = context.record
	if record == null:
		return true
	var usable_asleep: bool = context.effect.usable_while_asleep()
	if user.pokemon.status == &"SLEEP" and user.pokemon.status_count > 1 and not usable_asleep:
		return true
	if user.pokemon.status != &"SLEEP" and usable_asleep:
		return true
	var weather: StringName = context.battle.field.effective_weather(context.battle) \
		if context.battle != null else &"None"
	var move_type: StringName = context.move_type()
	if weather == &"HeavyRain" and move_type == &"FIRE":
		return true
	if weather == &"HarshSun" and move_type == &"WATER":
		return true
	if not context.effect.failure_is_known_when_choosing():
		return false
	return _refuses(context, func() -> bool:
		return not context.effect.can_be_used(context.battle, user, record)
	)

## Whether the move cannot do anything to this particular target.
static func will_fail_against(context: AIContext) -> bool:
	var target: Battler = context.target
	if target == null:
		return false
	var record: MoveData = context.record
	var move_type: StringName = context.move_type()

	if context.is_damaging():
		var effectiveness: float = DamageCalculator.type_effectiveness(
			context.battle, context.user, target, record, move_type)
		if effectiveness == 0.0:
			return true

	if context.battle != null:
		var priority: int = AIMoveView.rough_priority(context.battle, context.user, record)
		if priority > 0 and context.opposes(target):
			if context.battle.field.terrain == &"Psychic" and not target.is_airborne():
				return true
			for guard: Battler in context.same_side_as(target.side_index()):
				if guard.has_ability(&"DAZZLING") or guard.has_ability(&"QUEENLYMAJESTY"):
					return true
		if GameSettings.data.mechanics_generation >= 7 and record.is_status():
			if context.user.has_ability(&"PRANKSTER") and target.has_type(&"DARK") \
					and context.opposes(target):
				return true

	# A powder does nothing to something it cannot stick to.
	if record.is_powder_move():
		if target.has_type(&"GRASS") or target.has_ability(&"OVERCOAT") \
				or target.held_item() == &"SAFETYGOGGLES":
			return true

	# A status move cannot reach through a substitute.
	if record.is_status() and target.has_substitute() and target != context.user:
		if not record.ignores_substitute():
			return true

	if not context.effect.failure_is_known_when_choosing():
		return false
	return _refuses(context, func() -> bool:
		return not context.effect.succeeds_against(context.battle, context.user, target, record)
	)

## Runs a refusal check on the [MoveEffect] and puts back whatever it wrote.
static func _refuses(context: AIContext, question: Callable) -> bool:
	var remembered: String = context.effect.failure_message
	var refused: bool = bool(question.call())
	context.effect.failure_message = remembered
	return refused
