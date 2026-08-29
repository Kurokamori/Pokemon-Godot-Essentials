class_name AIEffectScores
extends RefCounted
## What a move's declared effect is worth, read off the [MoveEffect] itself.

## Berries that shrug a status problem off the moment it lands, keyed by the status they answer.
const STATUS_CURING_BERRIES: Dictionary = {
	&"SLEEP": [&"CHESTOBERRY", &"LUMBERRY"],
	&"POISON": [&"PECHABERRY", &"LUMBERRY"],
	&"BURN": [&"RAWSTBERRY", &"LUMBERRY"],
	&"PARALYSIS": [&"CHERIBERRY", &"LUMBERRY"],
	&"FROZEN": [&"ASPEARBERRY", &"LUMBERRY"],
}

## Abilities whose holder gets something out of having a status problem, so handing it one is doing it a favour.
const ENJOYS_STATUS: Array[StringName] = [
	&"GUTS", &"MARVELSCALE", &"QUICKFEET", &"TOXICBOOST", &"FLAREBOOST",
]

## Abilities that shake a status problem off again on their own.
const SHAKES_OFF_STATUS: Array[StringName] = [&"SHEDSKIN"]

## What a status problem is worth before anything is added or taken away.
const STATUS_BASE_WORTH: Dictionary = {
	&"SLEEP": 15,
	&"POISON": 15,
	&"BURN": 15,
	&"FROZEN": 15,
	# Paralysis.
	&"PARALYSIS": 10,
}

# === Against One Target ===

## Everything the move does to [param context]'s target, added to [param score].
static func against_target(context: AIContext, score: int) -> int:
	if context.target == null:
		return score
	var adjusted: int = score
	adjusted = _status(context, adjusted)
	adjusted = _flinch(context, adjusted)
	adjusted = _confusion(context, adjusted)
	adjusted = _attraction(context, adjusted)
	if not context.effect.target_stat_changes.is_empty():
		adjusted = AIStatScores.score_changes(
			context, context.target, context.effect.target_stat_changes, true, adjusted)
	adjusted = _forced_switch(context, adjusted)
	adjusted = _one_hit_knockout(context, adjusted)
	return adjusted

static func _status(context: AIContext, score: int) -> int:
	var status: StringName = context.effect.status_to_inflict
	if status.is_empty():
		return score
	var target: Battler = context.target
	var useless: int = AIScores.USELESS if context.is_status_move() else score
	if not target.can_take_status(status, context.user):
		return useless
	if target.has_effect(BattleEffects.YAWN) and status == &"SLEEP":
		return useless
	if _will_cure_at_once(context, status):
		return useless
	var secondary: int = AIMoveView.additional_effect_adjustment(
		context.battle, context.user, target, context.record)
	if secondary == AIMoveView.EFFECT_NEGATED:
		return useless

	var adjusted: int = score + secondary + int(STATUS_BASE_WORTH.get(status, 10))
	# Anything on the user's side that hits harder against a hurt target.
	for ally: Battler in context.same_side_as(context.user.side_index()):
		if AIBattlerView.has_move_with_function(ally, AIBattlerView.LIKES_STATUSED_TARGET_CODES):
			adjusted += 5
	adjusted += _status_specific(context, status)

	if not context.ignores_target_ability():
		for ability: StringName in ENJOYS_STATUS:
			if target.has_ability(ability):
				adjusted -= 8
				break
		for ability: StringName in SHAKES_OFF_STATUS:
			if target.has_ability(ability):
				adjusted -= 8
				break
		if target.has_ability(&"SYNCHRONIZE"):
			adjusted -= 20
	if AIBattlerView.has_move_with_function(target, AIBattlerView.FACADE_CODES):
		adjusted -= 5
	if AIBattlerView.has_move_with_function(target, AIBattlerView.STATUS_PASSING_CODES):
		adjusted -= 15
	if AIBattlerView.wants_status(context.battle, target, status):
		adjusted -= 20
	return adjusted

## The part of a status score that is particular to which status it is.
static func _status_specific(context: AIContext, status: StringName) -> int:
	var target: Battler = context.target
	var adjusted: int = 0
	match status:
		&"SLEEP":
			if AIBattlerView.check_moves(target, func(move: PokemonMove) -> bool:
				var record: MoveData = move.data()
				return record != null and MoveEffects.get_effect(record.function_code).usable_while_asleep()
			):
				adjusted -= 8
			if target.has_ability(&"EARLYBIRD"):
				adjusted -= 10
			for ally: Battler in context.same_side_as(context.user.side_index()):
				if ally.has_ability(&"BADDREAMS"):
					adjusted += 10
		&"POISON", &"BURN":
			if context.has_flag(AISkill.HP_AWARE):
				adjusted += int(15.0 * target.hp_fraction())
			if not AIBattlerView.takes_indirect_damage(target):
				adjusted -= 20
			if status == &"BURN":
				if not target.has_ability(&"GUTS") and AIBattlerView.has_physical_move(target):
					adjusted += 8
					if not AIBattlerView.has_special_move(target):
						adjusted += 8
				if target.has_ability(&"HEATPROOF"):
					adjusted -= 5
			elif target.has_ability(&"MERCILESS"):
				adjusted -= 10
			for ally: Battler in context.same_side_as(context.user.side_index()):
				if status == &"POISON" and ally.has_ability(&"MERCILESS"):
					adjusted += 10
		&"PARALYSIS":
			if AIBattlerView.faster_than(context.battle, target, context.user):
				var theirs: int = AIBattlerView.rough_stat(target, &"SPEED")
				var mine: int = AIBattlerView.rough_stat(context.user, &"SPEED")
				var factor: int = 2 if GameSettings.data.mechanics_generation >= 7 else 4
				if theirs < mine * factor:
					adjusted += 15
			if int(target.get_effect(BattleEffects.CONFUSION)) > 1:
				adjusted += 7
			if target.has_effect(BattleEffects.ATTRACT):
				adjusted += 7
		&"FROZEN":
			adjusted += 5
	return adjusted

## Whether the target is carrying the Berry for this status
static func _will_cure_at_once(context: AIContext, status: StringName) -> bool:
	if not STATUS_CURING_BERRIES.has(status):
		return false
	var held: StringName = context.target.held_item()
	for berry: StringName in STATUS_CURING_BERRIES[status]:
		if held == berry:
			return true
	return false

static func _flinch(context: AIContext, score: int) -> int:
	if not context.effect.causes_flinch:
		return score
	var target: Battler = context.target
	if not AIMoveView.moves_first(context.battle, context.user, target, context.record):
		return score
	if target.has_substitute():
		return score
	if not context.ignores_target_ability():
		if target.has_ability(&"INNERFOCUS") or target.has_ability(&"SHIELDDUST"):
			return score
	return score + 15

static func _confusion(context: AIContext, score: int) -> int:
	if not context.effect.causes_confusion:
		return score
	var target: Battler = context.target
	if target.has_effect(BattleEffects.CONFUSION):
		return AIScores.USELESS if context.is_status_move() else score
	if not context.ignores_target_ability() and target.has_ability(&"OWNTEMPO"):
		return AIScores.USELESS if context.is_status_move() else score
	if context.battle != null and context.battle.field.terrain == &"Misty" and not target.is_airborne():
		return AIScores.USELESS if context.is_status_move() else score
	var adjusted: int = score + 15
	if target.held_item() == &"PERSIMBERRY" or target.held_item() == &"LUMBERRY":
		return AIScores.USELESS if context.is_status_move() else score
	if target.has_effect(BattleEffects.ATTRACT):
		adjusted += 5
	if target.pokemon.status == &"PARALYSIS":
		adjusted += 5
	return adjusted

static func _attraction(context: AIContext, score: int) -> int:
	if not context.effect.causes_attraction:
		return score
	var target: Battler = context.target
	if target.has_effect(BattleEffects.ATTRACT):
		return AIScores.USELESS if context.is_status_move() else score
	if target.pokemon.is_genderless() or context.user.pokemon.is_genderless():
		return AIScores.USELESS if context.is_status_move() else score
	if target.pokemon.gender() == context.user.pokemon.gender():
		return AIScores.USELESS if context.is_status_move() else score
	if not context.ignores_target_ability() and target.has_ability(&"OBLIVIOUS"):
		return AIScores.USELESS if context.is_status_move() else score
	return score + 15

## Roar,.
static func _forced_switch(context: AIContext, score: int) -> int:
	if not context.effect.switches_out_target:
		return score
	var target: Battler = context.target
	if not target.can_be_forced_out():
		return AIScores.USELESS if context.is_status_move() else score
	if context.battle != null:
		var party: PokemonParty = context.battle.get_party(target.side_index())
		if party.able_count() <= context.battle.active_battlers_on_side(target.side_index()).size():
			return AIScores.USELESS if context.is_status_move() else score
	# Worth exactly as much as what it undoes.
	return score + 10 * AIBattlerView.positive_stat_stages(target)

static func _one_hit_knockout(context: AIContext, score: int) -> int:
	if not context.effect.is_ohko:
		return score
	var target: Battler = context.target
	if target.level() > context.user.level():
		return AIScores.FAIL
	if not context.ignores_target_ability() and target.has_ability(&"STURDY"):
		return AIScores.USELESS
	return score + 20

# === The Whole Move ===

## Everything the move does that is not aimed at a particular battler, added to [param score].
static func for_whole_move(context: AIContext, score: int) -> int:
	var adjusted: int = score
	if not context.effect.user_stat_changes.is_empty():
		adjusted = AIStatScores.score_changes(
			context, context.user, context.effect.user_stat_changes, true, adjusted)
	adjusted = _ally_stat_changes(context, adjusted)
	adjusted = _healing(context, adjusted)
	adjusted = _cost(context, adjusted)
	adjusted = _weather_and_terrain(context, adjusted)
	adjusted = _hazard(context, adjusted)
	adjusted = _side_effect(context, adjusted)
	adjusted = _protection(context, adjusted)
	adjusted = _self_switch(context, adjusted)
	adjusted = _charging(context, adjusted)
	return adjusted

static func _ally_stat_changes(context: AIContext, score: int) -> int:
	if context.effect.ally_stat_changes.is_empty() or context.battle == null:
		return score
	var adjusted: int = score
	for ally: Battler in context.battle.allies_of(context.user):
		adjusted = AIStatScores.score_changes(
			context, ally, context.effect.ally_stat_changes, false, adjusted)
	return adjusted

static func _healing(context: AIContext, score: int) -> int:
	if context.effect.heal_fraction <= 0.0:
		return score
	if not AIBattlerView.can_heal(context.user):
		return AIScores.USELESS
	var missing: float = 1.0 - context.user.hp_fraction()
	var restored: float = minf(context.effect.heal_fraction, missing)
	if restored < 0.15:
		return AIScores.USELESS
	var adjusted: int = score + int(100.0 * restored)
	var incoming: int = AIEndOfRound.damage_for(context.battle, context.user)
	if incoming > 0 and float(incoming) >= restored * float(context.user.total_hp()):
		adjusted -= 30
	return adjusted

static func _cost(context: AIContext, score: int) -> int:
	var adjusted: int = score
	if context.effect.hp_cost_fraction > 0.0:
		if context.user.hp_fraction() <= context.effect.hp_cost_fraction:
			return AIScores.FAIL
		adjusted -= int(40.0 * context.effect.hp_cost_fraction)
	if context.effect.user_faints:
		adjusted -= 40
		if context.battle != null:
			var ours: int = context.battle.get_party(context.user.side_index()).able_count()
			var theirs: int = context.battle.get_party(context.user.opposing_side_index()).able_count()
			if ours <= 1 and theirs > 1:
				return AIScores.USELESS
	return adjusted

static func _weather_and_terrain(context: AIContext, score: int) -> int:
	var adjusted: int = score
	var weather: StringName = context.effect.weather_to_start
	if not weather.is_empty():
		if context.battle.field.weather == weather:
			return AIScores.USELESS
		adjusted += AIFieldScores.for_weather(context, weather)
	var terrain: StringName = context.effect.terrain_to_start
	if not terrain.is_empty():
		if context.battle.field.terrain == terrain:
			return AIScores.USELESS
		adjusted += AIFieldScores.for_terrain(context, terrain)
	return adjusted

static func _hazard(context: AIContext, score: int) -> int:
	var hazard: StringName = context.effect.hazard_to_add
	if hazard.is_empty() or context.battle == null:
		return score
	var side: BattleSide = context.battle.get_side(context.user.opposing_side_index())
	var layers: int = int(side.get_effect(hazard))
	if layers >= context.effect.hazard_max_layers:
		return AIScores.USELESS
	var party: PokemonParty = context.battle.get_party(context.user.opposing_side_index())
	var reserves: int = party.able_count() - context.battle.active_battlers_on_side(
		context.user.opposing_side_index()).size()
	if reserves <= 0:
		return AIScores.USELESS
	return score + 20 + 10 * mini(reserves, 3) - 10 * layers

static func _side_effect(context: AIContext, score: int) -> int:
	var effect_id: StringName = context.effect.side_effect_to_start
	if effect_id.is_empty() or context.battle == null:
		return score
	var side: BattleSide = context.battle.get_side(context.user.side_index())
	if side.has_effect(effect_id):
		return AIScores.USELESS
	var adjusted: int = score + 20
	match effect_id:
		BattleEffects.REFLECT:
			for foe: Battler in context.foes_of(context.user.side_index()):
				if AIBattlerView.has_physical_move(foe):
					adjusted += 15
		BattleEffects.LIGHT_SCREEN:
			for foe: Battler in context.foes_of(context.user.side_index()):
				if AIBattlerView.has_special_move(foe):
					adjusted += 15
		BattleEffects.AURORA_VEIL:
			if context.battle.field.effective_weather(context.battle) != &"Hail":
				return AIScores.FAIL
			adjusted += 25
		BattleEffects.TAILWIND:
			for foe: Battler in context.foes_of(context.user.side_index()):
				if AIBattlerView.faster_than(context.battle, foe, context.user):
					adjusted += 20
					break
		BattleEffects.SAFEGUARD, BattleEffects.MIST:
			adjusted += 5
	if context.user.turns_active < 2:
		adjusted += 10
	return adjusted

static func _protection(context: AIContext, score: int) -> int:
	if not context.effect.is_protect_move:
		return score
	if context.user.has_effect(BattleEffects.PROTECT):
		return AIScores.FAIL
	var spent: int = mini(context.user.consecutive_move_uses, 3)
	var adjusted: int = score + 25 - 25 * spent
	if AIEndOfRound.damage_for(context.battle, context.user) < 0:
		adjusted += 10
	for foe: Battler in context.foes_of(context.user.side_index()):
		if foe.has_effect(BattleEffects.OUTRAGE):
			adjusted += 15
	return adjusted

static func _self_switch(context: AIContext, score: int) -> int:
	if not context.effect.switches_out_user or context.battle == null:
		return score
	var party: PokemonParty = context.battle.get_party(context.user.side_index())
	var reserves: int = party.able_count() - context.battle.active_battlers_on_side(
		context.user.side_index()).size()
	if reserves <= 0:
		return score
	var adjusted: int = score + 10
	adjusted -= 8 * AIBattlerView.positive_stat_stages(context.user)
	if float(AIEndOfRound.damage_for(context.battle, context.user)) >= float(context.user.hp()) * 0.5:
		adjusted += 15
	return adjusted

static func _charging(context: AIContext, score: int) -> int:
	var adjusted: int = score
	if context.effect.is_two_turn and not context.user.has_effect(BattleEffects.TWO_TURN_ATTACK):
		adjusted -= 20
		if context.user.held_item() == &"POWERHERB":
			adjusted += 25
	if context.effect.recharges_after:
		adjusted -= 15
	return adjusted
