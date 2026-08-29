class_name AIStatScores
extends RefCounted
## What changing a battler's stat stages is worth.
## The.

const DIMINISHING_STAGE: int = 2

## What [param changes] applied to [param subject] is worth, added to [param score].
## [param changes] is a `{stat: stages}` dictionary as [MoveEffect] declares it, positive for a raise and negative for a drop.
## [param whole_effect] says whether the stat change is the entire point of the move.
static func score_changes(
	context: AIContext, subject: Battler, changes: Dictionary, whole_effect: bool, score: int
) -> int:
	if subject == null or changes.is_empty():
		return score
	var entire: bool = whole_effect and not context.is_damaging()
	var raises: Dictionary = {}
	var drops: Dictionary = {}
	for stat: StringName in changes:
		var stages: int = int(changes[stat])
		if stages > 0:
			raises[stat] = stages
		elif stages < 0:
			drops[stat] = -stages

	var adjusted: int = score
	var anything_happened: bool = false
	if not raises.is_empty():
		var after_raises: int = _score_raises(context, subject, raises, entire, adjusted)
		if after_raises != AIScores.USELESS:
			anything_happened = true
			adjusted = after_raises
	if not drops.is_empty():
		var after_drops: int = _score_drops(context, subject, drops, entire, adjusted)
		if after_drops != AIScores.USELESS:
			anything_happened = true
			adjusted = after_drops
	if not anything_happened:
		return AIScores.USELESS if entire else score
	return adjusted

## Whether the battler being changed wants the change to be a good thing.
## `1` when a raise on this battler helps the user's side and `-1` when it hurts it.
static func desire_multiplier(context: AIContext, subject: Battler) -> int:
	if context.opposes(subject):
		return -1
	var data: TargetData = Database.target(context.record.target) if context.record != null else null
	if data != null and data.targets_foe and subject != context.user:
		return -1
	return 1

# === Raising ===

static func _score_raises(
	context: AIContext, subject: Battler, raises: Dictionary, whole_effect: bool, score: int
) -> int:
	var desire: int = desire_multiplier(context, subject)
	# Contrary reads the whole thing backwards, so a raise aimed at it is scored as the drop it will become.
	if _has_contrary(context, subject):
		if desire > 0 and whole_effect:
			return AIScores.USELESS
		return _score_drops(context, subject, raises, whole_effect, score, true)

	var secondary: int = AIMoveView.additional_effect_adjustment(
		context.battle, context.user, subject, context.record)
	if secondary == AIMoveView.EFFECT_NEGATED:
		return score
	if _about_to_faint(context, subject):
		return AIScores.USELESS if whole_effect else score
	# Stages.
	if not AIBattlerView.has_move_with_function(subject, AIBattlerView.LIKES_HIGH_SPEED_CODES):
		if _every_foe_is_unaware(context, subject):
			return AIScores.USELESS if whole_effect else score

	var real: Dictionary = _achievable(context, subject, raises, true)
	if real.is_empty():
		return AIScores.USELESS if whole_effect else score

	var adjusted: int = score + secondary
	adjusted = _generic(context, subject, real, desire, adjusted)
	for stat: StringName in real:
		adjusted = _one_raise(context, subject, stat, int(real[stat]), desire, adjusted)
	return adjusted

## Whether raising this stat would do the battler any good at all.
static func raise_worthwhile(context: AIContext, subject: Battler, stat: StringName) -> bool:
	if not subject.can_raise_stat(stat):
		return false
	# A battler that will pass the stages on, or that fights with them directly, always wants more.
	if AIBattlerView.has_move_with_function(subject, PASSES_OR_USES_STAGES_CODES):
		return true
	match stat:
		&"ATTACK":
			return AIBattlerView.has_physical_move(subject)
		&"SPECIAL_ATTACK":
			return AIBattlerView.has_special_move(subject)
		&"DEFENSE":
			for foe: Battler in context.foes_of(subject.side_index()):
				if AIBattlerView.has_defense_targeting_move(foe):
					return true
			return false
		&"SPECIAL_DEFENSE":
			for foe: Battler in context.foes_of(subject.side_index()):
				if AIBattlerView.has_special_move_hitting_special_defense(foe):
					return true
			return false
		&"SPEED":
			if AIBattlerView.has_move_with_function(subject, AIBattlerView.LIKES_HIGH_SPEED_CODES):
				return true
			return _speed_race_is_winnable(context, subject)
		&"ACCURACY":
			if AIBattlerView.lowest_accuracy(subject) < 90:
				return true
			if subject.get_stat_stage(&"ACCURACY") < 0:
				return true
			for foe: Battler in context.foes_of(subject.side_index()):
				if foe.get_stat_stage(&"EVASION") > 0:
					return true
			return false
	return true

static func _speed_race_is_winnable(context: AIContext, subject: Battler) -> bool:
	var mine: int = AIBattlerView.rough_stat(subject, &"SPEED")
	for foe: Battler in context.foes_of(subject.side_index()):
		var theirs: int = AIBattlerView.rough_stat(foe, &"SPEED")
		if mine < theirs and float(mine) * 2.5 > float(theirs):
			return true
	return false

static func _one_raise(
	context: AIContext, subject: Battler, stat: StringName, stages: int, desire: int, score: int
) -> int:
	var old_stage: int = subject.get_stat_stage(stat)
	var gain: float = _stage_ratio(stat, old_stage, old_stage + stages) * float(desire)
	var adjusted: int = score
	var opposing: int = 1 if context.opposes(subject) else desire

	match stat:
		&"ATTACK":
			if old_stage >= DIMINISHING_STAGE and stages == 1:
				adjusted -= 10 * opposing
			else:
				adjusted += int(float(8 if AIBattlerView.has_special_move(subject) else 12) * gain)
		&"SPECIAL_ATTACK":
			if old_stage >= DIMINISHING_STAGE and stages == 1:
				adjusted -= 10 * opposing
			else:
				adjusted += int(float(8 if AIBattlerView.has_physical_move(subject) else 12) * gain)
		&"DEFENSE", &"SPECIAL_DEFENSE":
			if old_stage >= DIMINISHING_STAGE and stages == 1:
				adjusted -= 10 * opposing
			else:
				adjusted += int(10.0 * gain)
		&"SPEED":
			adjusted += _speed_raise_bonus(context, subject, stages, gain)
			if AIBattlerView.has_move_with_function(subject, AIBattlerView.LIKES_HIGH_SPEED_CODES):
				adjusted += int(5.0 * gain)
			for foe: Battler in context.foes_of(subject.side_index()):
				if AIBattlerView.has_move_with_function(foe, AIBattlerView.PUNISHES_HIGH_STATS_CODES):
					adjusted -= int(5.0 * gain)
			if subject.has_ability(&"SPEEDBOOST"):
				adjusted -= 15 * opposing
		&"ACCURACY":
			if old_stage >= DIMINISHING_STAGE and stages == 1:
				adjusted -= 10 * opposing
			elif AIBattlerView.lowest_accuracy(subject) < 90:
				adjusted += int(10.0 * gain)
		&"EVASION":
			for foe: Battler in context.foes_of(subject.side_index()):
				if AIEndOfRound.damage_for(context.battle, foe) > 0:
					adjusted += int(5.0 * gain)
			if old_stage >= DIMINISHING_STAGE and stages == 1:
				adjusted -= 10 * opposing
			else:
				adjusted += int(10.0 * gain)
	return _stage_hoarding_adjustment(context, subject, stages, desire, adjusted)

## Extra worth in a Speed raise that actually wins a race, as against one that merely narrows it.
static func _speed_raise_bonus(context: AIContext, subject: Battler, stages: int, gain: float) -> int:
	var mine: int = AIBattlerView.rough_stat(subject, &"SPEED")
	for foe: Battler in context.foes_of(subject.side_index()):
		var theirs: int = AIBattlerView.rough_stat(foe, &"SPEED")
		if theirs <= mine:
			continue
		if float(theirs) > float(mine) * 2.5:
			continue
		if float(theirs) < float(mine) * float(stages + 2) / 2.0:
			return int(15.0 * gain)
		return int(8.0 * gain)
	return 0

# === Dropping ===

static func _score_drops(
	context: AIContext, subject: Battler, drops: Dictionary, whole_effect: bool, score: int,
	ignore_contrary: bool = false
) -> int:
	var desire: int = -desire_multiplier(context, subject)
	if not ignore_contrary and _has_contrary(context, subject):
		if desire > 0 and whole_effect:
			return AIScores.USELESS
		return _score_raises(context, subject, drops, whole_effect, score)

	var secondary: int = AIMoveView.additional_effect_adjustment(
		context.battle, context.user, subject, context.record)
	if secondary == AIMoveView.EFFECT_NEGATED:
		return score
	if _about_to_faint(context, subject):
		return AIScores.USELESS if whole_effect else score
	if _every_foe_is_unaware(context, subject):
		return AIScores.USELESS if whole_effect else score

	var real: Dictionary = _achievable(context, subject, drops, false)
	if real.is_empty():
		return AIScores.USELESS if whole_effect else score

	var adjusted: int = score + secondary
	adjusted = _generic(context, subject, real, desire, adjusted)
	# An Ability that answers a stat drop with a stat raise of its own turns the move into a favour.
	if context.opposes(subject) and not context.ignores_target_ability():
		if subject.has_ability(&"DEFIANT") or subject.has_ability(&"COMPETITIVE"):
			adjusted -= 10
	for stat: StringName in real:
		adjusted = _one_drop(context, subject, stat, int(real[stat]), desire, adjusted)
	return adjusted

## Whether lowering this stat would take anything away from the battler.
static func drop_worthwhile(context: AIContext, subject: Battler, stat: StringName) -> bool:
	if not subject.can_lower_stat(stat, context.user):
		return false
	match stat:
		&"ATTACK":
			return AIBattlerView.has_physical_move(subject)
		&"SPECIAL_ATTACK":
			return AIBattlerView.has_special_move(subject)
		&"DEFENSE":
			for foe: Battler in context.foes_of(subject.side_index()):
				if AIBattlerView.has_defense_targeting_move(foe):
					return true
			return false
		&"SPECIAL_DEFENSE":
			for foe: Battler in context.foes_of(subject.side_index()):
				if AIBattlerView.has_special_move_hitting_special_defense(foe):
					return true
			return false
		&"SPEED":
			if AIBattlerView.has_move_with_function(subject, AIBattlerView.LIKES_HIGH_SPEED_CODES):
				return true
			var mine: int = AIBattlerView.rough_stat(subject, &"SPEED")
			for foe: Battler in context.foes_of(subject.side_index()):
				var theirs: int = AIBattlerView.rough_stat(foe, &"SPEED")
				if mine > theirs and float(mine) < float(theirs) * 2.5:
					return true
			return false
		&"ACCURACY":
			return AIBattlerView.lowest_accuracy(subject) <= 100 and AIBattlerView.has_damaging_move(subject)
	return true

static func _one_drop(
	context: AIContext, subject: Battler, stat: StringName, stages: int, desire: int, score: int
) -> int:
	var old_stage: int = subject.get_stat_stage(stat)
	var loss: float = _stage_ratio(stat, old_stage - stages, old_stage) * float(desire)
	var adjusted: int = score
	var opposing: int = 1 if context.opposes(subject) else desire

	match stat:
		&"ATTACK":
			if old_stage <= -DIMINISHING_STAGE and stages == 1:
				adjusted -= 10 * opposing
			else:
				adjusted += int(float(8 if AIBattlerView.has_special_move(subject) else 12) * loss)
		&"SPECIAL_ATTACK":
			if old_stage <= -DIMINISHING_STAGE and stages == 1:
				adjusted -= 10 * opposing
			else:
				adjusted += int(float(8 if AIBattlerView.has_physical_move(subject) else 12) * loss)
		&"DEFENSE", &"SPECIAL_DEFENSE", &"ACCURACY", &"EVASION":
			if old_stage <= -DIMINISHING_STAGE and stages == 1:
				adjusted -= 10 * opposing
			else:
				adjusted += int(10.0 * loss)
		&"SPEED":
			adjusted += _speed_drop_bonus(context, subject, stages, loss)
			for foe: Battler in context.foes_of(subject.side_index()):
				if AIBattlerView.has_move_with_function(foe, AIBattlerView.LIKES_HIGH_SPEED_CODES):
					adjusted += int(5.0 * loss)
			if subject.has_ability(&"SPEEDBOOST"):
				adjusted -= 15 * opposing
	return _stage_hoarding_adjustment(context, subject, stages, desire, adjusted)

## Extra worth in a Speed drop that actually loses the target the race.
static func _speed_drop_bonus(context: AIContext, subject: Battler, stages: int, loss: float) -> int:
	var mine: int = AIBattlerView.rough_stat(subject, &"SPEED")
	for foe: Battler in context.foes_of(subject.side_index()):
		var theirs: int = AIBattlerView.rough_stat(foe, &"SPEED")
		if mine < theirs:
			continue
		if float(mine) > float(theirs) * 2.5:
			continue
		if float(mine) < float(theirs) * 2.0 / float(stages + 2):
			return int(15.0 * loss)
		return int(8.0 * loss)
	return 0

# === Shared ===

## The.
static func _generic(
	context: AIContext, subject: Battler, changes: Dictionary, desire: int, score: int
) -> int:
	var stages: int = 0
	for stat: StringName in changes:
		stages += int(changes[stat])
	var adjusted: int = score
	# Setting up is what the first two rounds are for.
	if context.user.turns_active < 2 and context.is_status_move():
		adjusted += stages * desire * 5
	if context.has_flag(AISkill.HP_AWARE):
		if subject != context.user:
			adjusted += int(float(stages * desire) * (context.user.hp_fraction() * 100.0 - 50.0) / 8.0)
		adjusted += int(float(stages * desire) * (subject.hp_fraction() * 100.0 - 50.0) / 8.0)
	return adjusted

## Stored Power gets better the more stages its owner has banked, and Punishment gets better the more the other side has.
static func _stage_hoarding_adjustment(
	context: AIContext, subject: Battler, stages: int, desire: int, score: int
) -> int:
	var adjusted: int = score
	if AIBattlerView.has_move_with_function(subject, STORED_POWER_CODES):
		adjusted += 5 * stages * desire
	for foe: Battler in context.foes_of(subject.side_index()):
		if AIBattlerView.has_move_with_function(foe, PUNISHMENT_CODES):
			adjusted -= 5 * stages * desire
	return adjusted

## Which of the wanted changes would actually happen, and by how many stages once Simple has doubled them and the ceiling has taken its cut.
static func _achievable(
	context: AIContext, subject: Battler, wanted: Dictionary, raising: bool
) -> Dictionary:
	var limit: int = GameSettings.data.max_stat_stage
	var real: Dictionary = {}
	for stat: StringName in wanted:
		var worthwhile: bool = raise_worthwhile(context, subject, stat) if raising \
			else drop_worthwhile(context, subject, stat)
		if not worthwhile:
			continue
		var stages: int = int(wanted[stat])
		if not context.ignores_target_ability() and subject.has_ability(&"SIMPLE"):
			stages *= 2
		var headroom: int = limit - subject.get_stat_stage(stat) if raising \
			else limit + subject.get_stat_stage(stat)
		stages = mini(stages, headroom)
		if stages > 0:
			real[stat] = stages
	return real

## How much the stat actually changes by, as a multiplier of what it was.
## Use the same stage tables as [Battler] when valuing stat changes.
static func _stage_ratio(stat: StringName, lower_stage: int, upper_stage: int) -> float:
	var table: Array[float] = Battler.ACCURACY_STAGE_MULTIPLIERS if stat == &"ACCURACY" \
		or stat == &"EVASION" else Battler.STAGE_MULTIPLIERS
	@warning_ignore("integer_division")
	var limit: int = (table.size() - 1) / 2
	var low: float = table[clampi(lower_stage + limit, 0, table.size() - 1)]
	var high: float = table[clampi(upper_stage + limit, 0, table.size() - 1)]
	if low <= 0.0:
		return 0.0
	return (high / low) - 1.0

static func _has_contrary(context: AIContext, subject: Battler) -> bool:
	if context.ignores_target_ability():
		return false
	return subject.has_ability(&"CONTRARY")

## Whether the battler will be gone before the stages could matter.
static func _about_to_faint(context: AIContext, subject: Battler) -> bool:
	return AIEndOfRound.damage_for(context.battle, subject) >= subject.hp()

## Whether every battler that would be looking at these stages has Unaware, which makes the whole exercise pointless.
static func _every_foe_is_unaware(context: AIContext, subject: Battler) -> bool:
	var foes: Array[Battler] = context.foes_of(subject.side_index())
	if foes.is_empty():
		return false
	for foe: Battler in foes:
		if not foe.has_ability(&"UNAWARE"):
			return false
	return true

## Moves that hand stat stages on, or fight with them directly, so a battler that knows one always wants more.
const PASSES_OR_USES_STAGES_CODES: Array[StringName] = [
	&"SwitchOutUserPassOnEffects", &"PowerHigherWithUserPositiveStatStages",
]

## Moves that get stronger the more stages their user has banked.
const STORED_POWER_CODES: Array[StringName] = [&"PowerHigherWithUserPositiveStatStages"]

## Moves that get stronger the more stages their target has banked.
const PUNISHMENT_CODES: Array[StringName] = [&"PowerHigherWithTargetPositiveStatStages"]
