class_name AISwitching
extends RefCounted
## Whether a trainer pulls a Pokemon out, and which one it sends in instead.
## Switching considers status, field effects, damage and useful resistances.

## Whether [param battler] should leave the field rather than act.
static func should_switch(battle: Battle, battler: Battler, skill: AISkill) -> bool:
	if battle == null or battler == null:
		return false
	if battle.is_wild_battle() and not battler.is_player_side():
		return false
	if battler.is_trapped():
		return false
	if not skill.has_flag(AISkill.CONSIDER_SWITCHING):
		return false
	var reserves: Array[Pokemon] = available_reserves(battle, battler)
	if reserves.is_empty():
		return false
	# Nothing on the other side can act, so this is a free round: take it.
	if skill.is_high():
		var any_foe_can_act: bool = false
		for foe: Battler in battle.opposing_battlers(battler):
			if AIBattlerView.can_attack(foe):
				any_foe_can_act = true
				break
		if not any_foe_can_act:
			return false
	if not _wants_to_leave(battle, battler, skill, reserves):
		return false
	if skill.is_medium() and _wants_to_stay_anyway(battle, battler, skill, reserves):
		return false
	return true

## The reserves this side could legally send in.
static func available_reserves(battle: Battle, battler: Battler) -> Array[Pokemon]:
	var found: Array[Pokemon] = []
	var side: int = battler.side_index()
	var party: PokemonParty = battle.get_party(side)
	var active: Array[int] = battle.active_party_slots(side)
	for slot: int in range(party.size()):
		if active.has(slot):
			continue
		var candidate: Pokemon = party.get_member(slot)
		if candidate != null and candidate.is_able():
			found.append(candidate)
	return found

# === Reasons To Leave ===

static func _wants_to_leave(
	battle: Battle, battler: Battler, skill: AISkill, reserves: Array[Pokemon]
) -> bool:
	if _about_to_faint_from_perish_song(battler):
		return true
	if _round_will_hurt_badly(battle, battler, skill):
		return true
	if _switching_would_cure_or_heal(battle, battler, skill, reserves):
		return true
	if _drowsy_and_useless_asleep(battle, battler, skill):
		return true
	if _asleep_and_useless(battle, battler, skill):
		return true
	if _cannot_act_at_all(battle, battler, skill):
		return true
	if _cannot_touch_the_foe(battle, battler, reserves):
		return true
	if _a_reserve_could_absorb_the_threat(battle, battler, skill, reserves):
		return true
	if _foe_has_a_powerful_answer(battle, battler, skill):
		return true
	return false

## The count is at one, so staying means fainting.
static func _about_to_faint_from_perish_song(battler: Battler) -> bool:
	return int(battler.get_effect(BattleEffects.PERISH_SONG)) == 1

## The end of the round will take a serious share of what is left, or will take something that switching out would remove.
static func _round_will_hurt_badly(battle: Battle, battler: Battler, skill: AISkill) -> bool:
	var incoming: int = AIEndOfRound.damage_for(battle, battler)
	if incoming <= 0:
		return false
	if float(incoming) >= float(battler.hp()) * 0.5:
		return true
	if float(incoming) >= float(battler.total_hp()) * 0.25:
		return true
	if not skill.is_high():
		return false
	if battler.has_effect(BattleEffects.LEECH_SEED) and RNG.decide_percent(50):
		return true
	if battler.has_effect(BattleEffects.NIGHTMARE) or battler.has_effect(BattleEffects.CURSE):
		return true
	# Toxic gets worse every round it is left alone, and switching resets it to ordinary poison.
	if battler.is_badly_poisoned() and not battler.has_ability(&"POISONHEAL"):
		@warning_ignore("integer_division")
		var ordinary: int = maxi(battler.total_hp() / 8, 1)
		var counter: int = int(battler.get_effect(BattleEffects.TOXIC_COUNTER)) + 1
		@warning_ignore("integer_division")
		var next_dose: int = maxi(battler.total_hp() * counter / 16, 1)
		if battler.hp() <= next_dose and battler.hp() > ordinary:
			return true
		if next_dose > ordinary * 2:
			return true
	return false

## Abilities that clear a status problem or restore health on the way out.
const CURES_ON_SWITCH: Array[StringName] = [&"NATURALCURE"]

## Abilities that cure one particular status problem, keyed by the status.
const CURES_ONE_STATUS: Dictionary = {
	&"IMMUNITY": &"POISON",
	&"INSOMNIA": &"SLEEP",
	&"VITALSPIRIT": &"SLEEP",
	&"LIMBER": &"PARALYSIS",
	&"MAGMAARMOR": &"FROZEN",
	&"WATERBUBBLE": &"BURN",
	&"WATERVEIL": &"BURN",
}

## Natural Cure and Regenerator both make leaving worth something in itself.
static func _switching_would_cure_or_heal(
	battle: Battle, battler: Battler, skill: AISkill, reserves: Array[Pokemon]
) -> bool:
	if battler.ability_suppressed:
		return false
	var hazards: int = entry_hazard_damage(battle, battler.pokemon, battler.side_index())
	if hazards >= battler.hp():
		return false
	var ability: StringName = battler.ability()
	if ability == &"REGENERATOR":
		return _regenerator_is_worth_it(battle, battler, skill, hazards)
	var cures: bool = CURES_ON_SWITCH.has(ability)
	if not cures and CURES_ONE_STATUS.has(ability):
		cures = StringName(CURES_ONE_STATUS[ability]) == battler.pokemon.status
	if not cures or battler.pokemon.status == &"NONE":
		return false
	if AIBattlerView.wants_status(battle, battler, battler.pokemon.status):
		return false
	# Waking up this round anyway.
	if battler.pokemon.status == &"SLEEP" and battler.pokemon.status_count <= 1:
		return false
	if float(hazards) >= float(battler.total_hp()) * 0.25:
		return false
	# Curing a poisoning is pointless when Toxic Spikes will just re-apply it.
	if battler.pokemon.status == &"POISON" and not _any_reserve_has_type(reserves, &"POISON"):
		var layers: int = int(battle.get_side(battler.side_index()).get_effect(BattleEffects.TOXIC_SPIKES))
		if layers >= 2:
			return false
		if layers == 1 and not battler.is_badly_poisoned():
			return false
	# A status problem that still lets the battler act is not worth a whole turn while it is healthy.
	var disabling: bool = battler.pokemon.status == &"SLEEP" or battler.pokemon.status == &"FROZEN"
	if not disabling and battler.hp_fraction() >= 0.5:
		return false
	return RNG.decide_percent(70)

static func _regenerator_is_worth_it(
	battle: Battle, battler: Battler, skill: AISkill, hazards: int
) -> bool:
	if float(hazards) >= float(battler.total_hp()) / 3.0:
		return false
	if battler.hp_fraction() >= 0.5:
		return false
	# Not worth healing when there is something in front of it worth finishing.
	if AIBattlerView.has_damaging_move(battler):
		for foe: Battler in battle.opposing_battlers(battler):
			if foe.hp_fraction() < 1.0 / 3.0:
				return false
	if skill.is_high() and battler.total_positive_stages() >= 2:
		return false
	return RNG.decide_percent(70)

## Yawning, and asleep is no use to it.
static func _drowsy_and_useless_asleep(battle: Battle, battler: Battler, skill: AISkill) -> bool:
	if not battler.has_effect(BattleEffects.YAWN):
		return false
	if not battler.can_take_status(&"SLEEP"):
		return false
	return _sleep_would_waste_it(battle, battler, skill)

## Already asleep, and not waking up soon.
static func _asleep_and_useless(battle: Battle, battler: Battler, skill: AISkill) -> bool:
	if battler.pokemon.status != &"SLEEP" or battler.pokemon.status_count <= 2:
		return false
	# A battler that knows Rest expects to be asleep and is not stuck.
	if AIBattlerView.has_move_with_function(battler, REST_CODES):
		return false
	if not _sleep_would_waste_it(battle, battler, skill):
		return false
	return RNG.decide_percent(50)

## Rest, which is a reason to be asleep on purpose.
const REST_CODES: Array[StringName] = [&"HealUserFullyAndFallAsleep"]

## Abilities that get their holder out of sleep without any help.
const WAKES_ITSELF: Array[StringName] = [
	&"INSOMNIA", &"VITALSPIRIT", &"NATURALCURE", &"REGENERATOR", &"SHEDSKIN",
]

## The shared half of the two sleep reasons: whether being asleep would actually cost this battler anything.
static func _sleep_would_waste_it(battle: Battle, battler: Battler, skill: AISkill) -> bool:
	if AIBattlerView.wants_status(battle, battler, &"SLEEP"):
		return false
	for ability: StringName in WAKES_ITSELF:
		if battler.has_ability(ability):
			return false
	if battler.has_ability(&"HYDRATION"):
		var weather: StringName = battle.field.effective_weather(battle)
		if weather == &"Rain" or weather == &"HeavyRain":
			return false
	if battler.has_ability(&"EARLYBIRD") or battler.has_ability(&"MARVELSCALE"):
		return false
	var held: StringName = battler.held_item()
	if held == &"CHESTOBERRY" or held == &"LUMBERRY":
		return false
	for ally: Battler in battle.allies_of(battler):
		if ally.has_ability(&"HEALER"):
			return false
	# Leaving would throw away everything it has banked.
	if skill.is_high() and battler.total_positive_stages() >= 2:
		return false
	return true

## Every move it knows is unusable, and it is not doing anything else useful by standing there.
static func _cannot_act_at_all(battle: Battle, battler: Battler, skill: AISkill) -> bool:
	if not skill.is_medium() or battler.turns_active < 2:
		return false
	if not battler.usable_moves().is_empty():
		return false
	if battler.has_effect(BattleEffects.DESTINY_BOND) or battler.has_effect(BattleEffects.GRUDGE):
		return false
	if battler.has_substitute():
		# A substitute is worth standing behind unless a foe can go through it.
		var pierced: bool = false
		for foe: Battler in battle.opposing_battlers(battler):
			if AIBattlerView.check_moves(foe, func(move: PokemonMove) -> bool:
				var record: MoveData = move.data()
				return record != null and record.ignores_substitute()
			):
				pierced = true
				break
		if not pierced:
			return false
	return true

## Moves that go through an absorbing Ability, which is why knowing one means the battler is not helpless after all.
const IGNORES_ABILITY_CODES: Array[StringName] = [
	&"IgnoreTargetAbility", &"CategoryDependsOnHigherDamageIgnoreTargetAbility",
]

## Everything it can throw is swallowed by the other side's Abilities, and a reserve could do better.
static func _cannot_touch_the_foe(battle: Battle, battler: Battler, reserves: Array[Pokemon]) -> bool:
	if battler.turns_active < 2 or AbilityEffects.ignores_abilities(battler):
		return false
	for foe: Battler in battle.opposing_battlers(battler):
		if AIEndOfRound.damage_for(battle, foe) > 0:
			return false
		if _can_hurt(battle, battler, foe):
			return false
	for candidate: Pokemon in reserves:
		for foe: Battler in battle.opposing_battlers(battler):
			if _pokemon_has_landing_move(foe, candidate):
				return true
	return false

static func _can_hurt(battle: Battle, battler: Battler, foe: Battler) -> bool:
	return AIBattlerView.check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		if record == null or record.is_status():
			return false
		if IGNORES_ABILITY_CODES.has(record.function_code):
			return true
		var effect: MoveEffect = MoveEffects.get_effect(record.function_code)
		var move_type: StringName = DamageCalculator.move_type_for(battle, battler, foe, record, effect)
		return not AIBattlerView.absorbs_move(foe, record, move_type)
	)

## Whether [param candidate] knows anything [param foe] would not simply swallow. Asked of a reserve, which has no [Battler] and so no live move type.
static func _pokemon_has_landing_move(foe: Battler, candidate: Pokemon) -> bool:
	for move: PokemonMove in candidate.moves:
		var record: MoveData = move.data() if move != null else null
		if record == null or record.is_status():
			continue
		if IGNORES_ABILITY_CODES.has(record.function_code):
			return true
		if not AIBattlerView.absorbs_move(foe, record, record.type):
			return true
	return false

## The other side's best move is one a reserve is immune to and this one is not.
static func _a_reserve_could_absorb_the_threat(
	battle: Battle, battler: Battler, skill: AISkill, reserves: Array[Pokemon]
) -> bool:
	if not skill.is_medium():
		return false
	if battler.get_stat_stage(&"EVASION") >= 3:
		return false
	if battle.neutralizing_gas_active():
		return false
	var best: MoveData = null
	var best_power: int = 0
	for foe: Battler in battle.opposing_battlers(battler):
		for move: PokemonMove in foe.moves():
			var record: MoveData = move.data() if move != null else null
			if record == null or record.is_status():
				continue
			var power: int = record.power
			if MoveEffects.get_effect(record.function_code).is_ohko:
				power = 100
			if power > best_power:
				best_power = power
				best = record
	if best == null or best_power < 70:
		return false
	if AIBattlerView.absorbs_move(battler, best, best.type):
		return false
	for candidate: Pokemon in reserves:
		if AIBattlerView.pokemon_absorbs_move(candidate, best, best.type):
			return RNG.decide_percent(30)
	return false

## A foe has just landed something powerful and super-effective, and this one is already hurt.
static func _foe_has_a_powerful_answer(battle: Battle, battler: Battler, skill: AISkill) -> bool:
	if not skill.is_high() or battler.hp_fraction() >= 0.5:
		return false
	for foe: Battler in battle.opposing_battlers(battler):
		if absi(foe.level() - battler.level()) > 5:
			continue
		var last: MoveData = battle.resolve_move(foe.last_move_used)
		if last == null or last.is_status() or last.power < 70:
			continue
		var effectiveness: float = AIBattlerView.effectiveness_of_type_against(
			battle, last.type, battler, foe)
		if effectiveness <= 1.0:
			continue
		if RNG.decide_percent(50 if last.power > 90 else 25):
			return true
	return false

# === Reasons To Stay ===

static func _wants_to_stay_anyway(
	battle: Battle, battler: Battler, skill: AISkill, reserves: Array[Pokemon]
) -> bool:
	# Leaving is pointless when coming back in would be fatal and nothing can clear the way.
	var hazards: int = entry_hazard_damage(battle, battler.pokemon, battler.side_index())
	if hazards >= battler.hp():
		var clearable: bool = false
		for candidate: Pokemon in reserves:
			for move: PokemonMove in candidate.moves:
				var record: MoveData = move.data() if move != null else null
				if record != null and HAZARD_CLEARING_CODES.has(record.function_code):
					clearable = true
					break
			if clearable:
				break
		if not clearable:
			return true
	# It has an answer in its hands already.
	if int(battler.get_effect(BattleEffects.PERISH_SONG)) != 1:
		if _has_super_effective_move(battle, battler, skill) and RNG.decide_percent(50):
			return true
	# It has too much banked to walk away from.
	if battler.total_positive_stages() >= 4:
		return true
	return false

## Moves that sweep the entry hazards away.
const HAZARD_CLEARING_CODES: Array[StringName] = [
	&"RemoveUserBindingAndEntryHazards", &"LowerTargetEvasion1RemoveSideEffects",
]

static func _has_super_effective_move(battle: Battle, battler: Battler, skill: AISkill) -> bool:
	return AIBattlerView.check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		if record == null or record.is_status():
			return false
		var move_type: StringName = record.type
		if skill.is_medium():
			var effect: MoveEffect = MoveEffects.get_effect(record.function_code)
			move_type = DamageCalculator.move_type_for(battle, battler, battler, record, effect)
		for foe: Battler in battle.opposing_battlers(battler):
			if AIBattlerView.effectiveness_of_type_against(battle, move_type, foe, battler) > 1.0:
				return true
		return false
	)

# === Choosing Who Comes In ===

## The party slot to send out for [param side], or `-1` when nothing is worth sending.
## [param.
static func choose_replacement(battle: Battle, side: int, skill: AISkill, forced: bool = true) -> int:
	var party: PokemonParty = battle.get_party(side)
	var active: Array[int] = battle.active_party_slots(side)
	var last_slot: int = _last_able_slot(party)
	var rated: Array = []
	for slot: int in range(party.size()):
		if active.has(slot):
			continue
		var candidate: Pokemon = party.get_member(slot)
		if candidate == null or not candidate.is_able():
			continue
		# The ace is kept back for as long as there is anybody else.
		if skill.has_flag(AISkill.RESERVE_LAST_POKEMON) and slot == last_slot:
			if not forced or not rated.is_empty():
				continue
		rated.append({"slot": slot, "score": rate_replacement(battle, side, candidate, skill)})
		if skill.has_flag(AISkill.USE_POKEMON_IN_ORDER):
			break
	if rated.is_empty():
		return -1
	rated.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return int(first["score"]) > int(second["score"])
	)
	# A trainer choosing rather than replacing a fainted Pokemon does not switch into something rated worse than the one it already has out.
	if skill.is_high() and not forced and int(rated[0]["score"]) < AIScores.BASE:
		return -1
	return int(rated[0]["slot"])

## What sending [param candidate] in would be worth, starting at [constant AIScores.BASE] so that a rating below it means "worse than nothing".
static func rate_replacement(battle: Battle, side: int, candidate: Pokemon, skill: AISkill) -> int:
	var score: int = AIScores.BASE
	var hazards: int = entry_hazard_damage(battle, candidate, side)
	if hazards >= candidate.hp:
		score -= 50
	elif hazards > 0:
		score -= int(50.0 * float(hazards) / float(maxi(candidate.hp, 1)))
	var own_side: BattleSide = battle.get_side(side)
	if candidate.held_item != &"HEAVYDUTYBOOTS" and not AIBattlerView.pokemon_airborne(battle, candidate):
		if own_side.has_effect(BattleEffects.TOXIC_SPIKES):
			if AIBattlerView.pokemon_can_be_poisoned(battle, candidate):
				score -= 20
		if own_side.has_effect(BattleEffects.STICKY_WEB):
			score -= 15

	var foes: Array[Battler] = []
	for battler: Battler in battle.all_active_battlers():
		if battler.side_index() != side:
			foes.append(battler)

	# What the other side has just shown it can do to this one.
	for foe: Battler in foes:
		if foe.last_move_used.is_empty():
			continue
		var last: MoveData = battle.resolve_move(foe.last_move_used)
		if last == null or last.is_status():
			continue
		var effectiveness: float = Database.type_effectiveness(last.type, candidate.types())
		score -= int(float(last.power) * effectiveness / 5.0)

	# And what this one could do back.
	for move: PokemonMove in candidate.moves:
		var record: MoveData = move.data() if move != null else null
		if record == null or record.power == 0:
			continue
		if move.pp <= 0 and move.total_pp() > 0:
			continue
		for foe: Battler in foes:
			if AIBattlerView.pokemon_absorbs_move(foe.pokemon, record, record.type):
				continue
			var effectiveness: float = Database.type_effectiveness(record.type, foe.types())
			score += int(float(record.power) * effectiveness / 10.0)

	if skill.is_medium():
		score += int(float(candidate.level()))
	return score

## The damage the entry hazards on [param side] would do to [param candidate] as it comes in.
static func entry_hazard_damage(battle: Battle, candidate: Pokemon, side: int) -> int:
	if candidate == null or battle == null:
		return 0
	if candidate.ability_id() == &"MAGICGUARD" or candidate.held_item == &"HEAVYDUTYBOOTS":
		return 0
	var own_side: BattleSide = battle.get_side(side)
	var total: int = 0
	if own_side.has_effect(BattleEffects.STEALTH_ROCK):
		var effectiveness: float = Database.type_effectiveness(&"ROCK", candidate.types())
		if effectiveness > 0.0:
			total += int(float(candidate.total_hp) * effectiveness / 8.0)
	var spikes: int = int(own_side.get_effect(BattleEffects.SPIKES))
	if spikes > 0 and not AIBattlerView.pokemon_airborne(battle, candidate):
		var divisors: Array[int] = [8, 6, 4]
		@warning_ignore("integer_division")
		total += candidate.total_hp / divisors[clampi(spikes - 1, 0, 2)]
	return total

static func _last_able_slot(party: PokemonParty) -> int:
	var found: int = -1
	for slot: int in range(party.size()):
		var candidate: Pokemon = party.get_member(slot)
		if candidate != null and candidate.is_able():
			found = slot
	return found

static func _any_reserve_has_type(reserves: Array[Pokemon], type_id: StringName) -> bool:
	for candidate: Pokemon in reserves:
		if candidate.has_type(type_id):
			return true
	return false
