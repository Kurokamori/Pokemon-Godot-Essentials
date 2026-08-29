class_name AIGeneralScores
extends RefCounted
## The judgements that apply to every move rather than to any one effect.

## Abilities that hurt whoever touches their holder.
const PUNISHES_CONTACT: Array[StringName] = [&"ROUGHSKIN", &"IRONBARBS"]

## Abilities that may leave a status or a stat drop on whoever touches them.
const RISKS_ON_CONTACT: Array[StringName] = [
	&"STATIC", &"FLAMEBODY", &"POISONPOINT", &"CUTECHARM", &"EFFECTSPORE",
	&"GOOEY", &"TANGLINGHAIR", &"ROUGHSKIN", &"IRONBARBS", &"AFTERMATH",
	&"MUMMY", &"WANDERINGSPIRIT", &"PICKPOCKET",
]

## Held items that hurt whoever touches their holder.
const PUNISHING_ITEMS: Array[StringName] = [&"ROCKYHELMET"]

## Abilities that survive a hit that would otherwise knock their holder out.
const SURVIVES_A_KO: Array[StringName] = [&"STURDY"]

## Held items that do the same.
const SURVIVING_ITEMS: Array[StringName] = [&"FOCUSSASH"]

## Things that turn a super-effective hit to their holder's advantage.
const REWARDS_SUPER_EFFECTIVE: Array[StringName] = [&"WEAKNESSPOLICY", &"ENIGMABERRY"]

## Abilities that make the first hit on their holder do nothing.
const SHRUGS_OFF_A_HIT: Array[StringName] = [&"DISGUISE", &"ICEFACE"]

## Abilities that ignore the attacker's stat stages, which is what makes setting up against one a wasted turn.
const IGNORES_STAT_STAGES: Array[StringName] = [&"UNAWARE"]

## Abilities that make a stat drop aimed at their holder pointless.
const IGNORES_STAT_DROPS: Array[StringName] = [
	&"CLEARBODY", &"WHITESMOKE", &"FULLMETALBODY", &"MIRRORARMOR",
]

## Abilities that turn a stat drop into a gain.
const INVERTS_STAT_DROPS: Array[StringName] = [&"CONTRARY"]

## Abilities whose holder answers a stat drop by raising a stat of its own.
const ANSWERS_STAT_DROPS: Array[StringName] = [&"DEFIANT", &"COMPETITIVE"]

## Abilities that react to being hit.
const REACTS_TO_BEING_HIT: Array[StringName] = [
	&"COLORCHANGE", &"ANGERPOINT", &"JUSTIFIED", &"RATTLED", &"STEAMENGINE",
	&"WATERCOMPACTION", &"STAMINA", &"BERSERK", &"WEAKARMOR", &"CURSEDBODY",
	&"EMERGENCYEXIT", &"WIMPOUT", &"GULPMISSILE", &"ILLUSION",
]

## Held items that do something when their holder is hit by any move at all.
const REACTS_TO_BEING_HIT_ITEMS: Array[StringName] = [
	&"REDCARD", &"EJECTBUTTON", &"WEAKNESSPOLICY", &"ABSORBBULB",
	&"CELLBATTERY", &"SNOWBALL", &"LUMINOUSMOSS", &"AIRBALLOON", &"ENIGMABERRY",
	&"JABOCABERRY", &"ROWAPBERRY", &"KEEBERRY", &"MARANGABERRY", &"EJECTPACK",
]

## Abilities that reward their holder for landing a blow, which is a reason to prefer one.
const REWARDS_DEALING_A_HIT: Array[StringName] = [
	&"POISONTOUCH", &"MAGICIAN", &"MOXIE", &"BEASTBOOST", &"CHILLINGNEIGH",
	&"GRIMNEIGH", &"ASONECHILLINGNEIGH", &"ASONEGRIMNEIGH", &"SOULHEART",
	&"STENCH",
]

## Items that add a chance of flinching to any damaging move.
const FLINCHING_ITEMS: Array[StringName] = [&"KINGSROCK", &"RAZORFANG"]

## The move that bounces a status move straight back.
const MAGIC_COAT_CODES: Array[StringName] = [&"BounceBackProblemCausingStatusMoves"]

## The move that steals a beneficial status move.
const SNATCH_CODES: Array[StringName] = [&"StealAndUseBeneficialStatusMove"]

## The move that guards a whole side against priority.
const QUICK_GUARD_CODES: Array[StringName] = [&"ProtectUserSideFromPriorityMoves"]

## Items that lock their holder into the move it picks, so the choice matters more than usual.
const CHOICE_ITEMS: Array[StringName] = [&"CHOICEBAND", &"CHOICESPECS", &"CHOICESCARF"]

## Trick, which is the one status move worth being Choiced into.
const TRICK_CODES: Array[StringName] = [&"UserTargetSwapItems"]

# === Against One Target ===

## Every general judgement that is about the target, added to [param score].
static func against_target(context: AIContext, score: int) -> int:
	if context.target == null:
		return score
	var adjusted: int = score
	adjusted = _predicted_damage(context, adjusted)
	adjusted = _predicted_accuracy(context, adjusted)
	adjusted = _defender_hardware(context, adjusted)
	adjusted = _status_move_turned_away(context, adjusted)
	adjusted = _stat_change_answered(context, adjusted)
	adjusted = _reactions_on_hit(context, adjusted)
	adjusted = _dying_wish(context, adjusted)
	adjusted = _priority_against_a_faster_target(context, adjusted)
	adjusted = _external_flinch(context, adjusted)
	adjusted = _thaws_the_target(context, adjusted)
	adjusted = _shiny_wild_target(context, adjusted)
	return adjusted

## How hard the move actually hits
static func _predicted_damage(context: AIContext, score: int) -> int:
	if not context.is_damaging():
		return score
	var damage: int = AIMoveView.rough_damage(
		context.battle, context.user, context.target, context.record, context.effect)
	if damage <= 0:
		return score
	var health: int = AIMoveView.effective_health(context.target)
	var share: float = float(damage) / float(health)
	if context.target.has_substitute():
		return score + mini(int(15.0 * share), 20)
	var adjusted: int = score + mini(int(25.0 * share), 30)
	if context.has_flag(AISkill.HP_AWARE) and float(damage) > float(context.target.hp()) * 1.1:
		adjusted += 10
		# A multi-hit move gets through the two things that would otherwise stop a knockout, because only the first hit is stopped.
		if context.effect.maximum_hits > 1 and context.target.hp() == context.target.total_hp():
			if _has_any(context.target, SURVIVES_A_KO, SURVIVING_ITEMS, context):
				adjusted += 8
	return adjusted

static func _predicted_accuracy(context: AIContext, score: int) -> int:
	var accuracy: int = AIMoveView.rough_accuracy(
		context.battle, context.user, context.target, context.record, context.effect)
	if accuracy >= 90:
		return score
	return score - int(0.25 * float(100 - accuracy))

## What the defender is carrying that makes a landed hit a mistake anyway.
static func _defender_hardware(context: AIContext, score: int) -> int:
	if not context.is_damaging() or not context.skill.is_high():
		return score
	var target: Battler = context.target
	var ability: StringName = context.readable_target_ability()
	var item: StringName = target.held_item()
	var adjusted: int = score

	if AbilityEffects.makes_contact(context.user, context.record):
		if PUNISHES_CONTACT.has(ability):
			adjusted -= 25
		elif RISKS_ON_CONTACT.has(ability):
			adjusted -= 12
		if PUNISHING_ITEMS.has(item):
			adjusted -= 25

	var damage: int = AIMoveView.rough_damage(
		context.battle, context.user, target, context.record, context.effect)
	if damage >= target.hp() and target.hp() == target.total_hp():
		if SURVIVES_A_KO.has(ability) or SURVIVING_ITEMS.has(item):
			adjusted -= 70

	if SHRUGS_OFF_A_HIT.has(ability):
		adjusted -= 45

	var effectiveness: float = DamageCalculator.type_effectiveness(
		context.battle, context.user, target, context.record, context.move_type())
	if effectiveness > 1.0 and REWARDS_SUPER_EFFECTIVE.has(item):
		adjusted -= 20
	return adjusted

## A status move that comes straight back at the user is the worst move there is.
static func _status_move_turned_away(context: AIContext, score: int) -> int:
	if context.is_damaging() or not context.skill.is_high():
		return score
	var target: Battler = context.target
	var ability: StringName = context.readable_target_ability()
	if MoveEffects.can_be_magic_coated(context.record):
		if ability == &"MAGICBOUNCE":
			return AIScores.USELESS
		if AIBattlerView.has_move_with_function(target, MAGIC_COAT_CODES):
			if AIBattlerView.can_attack(target):
				return score - 7
	if ability == &"SOUNDPROOF" and context.record.is_sound_move():
		return AIScores.USELESS
	if ability == &"OVERCOAT" and context.record.is_powder_move():
		return AIScores.USELESS
	return score

## What the target would do about a stat drop aimed at it.
static func _stat_change_answered(context: AIContext, score: int) -> int:
	if not context.skill.is_high() or context.effect.target_stat_changes.is_empty():
		return score
	var ability: StringName = context.readable_target_ability()
	if ability.is_empty():
		return score
	var drops: bool = false
	for stat: StringName in context.effect.target_stat_changes:
		if int(context.effect.target_stat_changes[stat]) < 0:
			drops = true
			break
	if not drops:
		return score
	if INVERTS_STAT_DROPS.has(ability):
		return AIScores.USELESS
	if ANSWERS_STAT_DROPS.has(ability):
		return score - 50
	if IGNORES_STAT_DROPS.has(ability):
		return AIScores.USELESS
	return score

## Setting up in front of something that will not look at the numbers.
static func _setting_up_against_unaware(context: AIContext, score: int) -> int:
	if not context.skill.is_high() or context.effect.user_stat_changes.is_empty():
		return score
	var raises: bool = false
	for stat: StringName in context.effect.user_stat_changes:
		if int(context.effect.user_stat_changes[stat]) <= 0:
			continue
		if stat != &"SPEED" and stat != &"EVASION":
			raises = true
	if not raises:
		return score
	for foe: Battler in context.foes_of(context.user.side_index()):
		if IGNORES_STAT_STAGES.has(foe.ability()):
			return score - 45
	return score

## Abilities and items that fire when their holder is hit, on either side.
static func _reactions_on_hit(context: AIContext, score: int) -> int:
	if not context.skill.is_high() or not context.is_damaging():
		return score
	if context.target.has_substitute():
		return score
	var adjusted: int = score
	if not context.ignores_target_ability() and REACTS_TO_BEING_HIT.has(context.target.ability()):
		adjusted -= 8
	if REACTS_TO_BEING_HIT_ITEMS.has(context.target.held_item()):
		adjusted -= 8
	if REWARDS_DEALING_A_HIT.has(context.user.ability()):
		adjusted += 8
	return adjusted

## Knocking out something that has arranged to take the killer with it.
static func _dying_wish(context: AIContext, score: int) -> int:
	if not context.is_damaging():
		return score
	if not context.skill.is_high() and not context.has_flag(AISkill.HP_AWARE):
		return score
	var target: Battler = context.target
	var bonded: bool = target.has_effect(BattleEffects.DESTINY_BOND)
	var grudging: bool = target.has_effect(BattleEffects.GRUDGE)
	if not bonded and not grudging:
		return score
	if not AIMoveView.moves_first(context.battle, context.user, target, context.record):
		return score
	var damage: int = AIMoveView.rough_damage(
		context.battle, context.user, target, context.record, context.effect)
	if float(damage) <= float(target.hp()) * 1.1:
		return score
	var alone: bool = context.battle != null \
		and context.battle.get_party(context.user.side_index()).able_count() <= 1
	if bonded:
		return score - 20 - (10 if alone else 0)
	return score - 15 - (7 if alone else 0)

## A priority move is worth more against something that would otherwise go first.
static func _priority_against_a_faster_target(context: AIContext, score: int) -> int:
	if not context.skill.is_high():
		return score
	if not AIBattlerView.faster_than(context.battle, context.target, context.user):
		return score
	if AIMoveView.rough_priority(context.battle, context.user, context.record) <= 0:
		return score
	var adjusted: int = score
	if context.has_flag(AISkill.HP_AWARE) and context.user.hp_fraction() < 1.0 / 3.0:
		adjusted += 8
	if context.is_damaging():
		var damage: int = AIMoveView.rough_damage(
			context.battle, context.user, context.target, context.record, context.effect)
		if damage >= context.target.hp():
			adjusted += 8
	# A side that can put up a Quick Guard may take the priority away entirely.
	for foe: Battler in context.foes_of(context.user.side_index()):
		if AIBattlerView.has_move_with_function(foe, QUICK_GUARD_CODES):
			adjusted -= 5
	return adjusted

## A King's Rock adds a flinch to a move that has none of its own.
static func _external_flinch(context: AIContext, score: int) -> int:
	if not context.skill.is_medium() or not context.is_damaging():
		return score
	if context.effect.causes_flinch or context.target.has_substitute():
		return score
	if not AIBattlerView.faster_than(context.battle, context.user, context.target):
		return score
	var carries: bool = FLINCHING_ITEMS.has(context.user.held_item()) \
		or context.user.has_ability(&"STENCH")
	if not carries:
		return score
	if not context.ignores_target_ability():
		if context.target.has_ability(&"INNERFOCUS") or context.target.has_ability(&"SHIELDDUST"):
			return score
	var adjusted: int = score + 8
	if context.effect.maximum_hits > 1:
		adjusted += 5
	return adjusted

## Waking a frozen target up is doing it a favour.
static func _thaws_the_target(context: AIContext, score: int) -> int:
	if not context.skill.is_medium() or context.target.pokemon.status != &"FROZEN":
		return score
	if context.move_type() == &"FIRE":
		return score - 20
	if GameSettings.data.mechanics_generation >= 6 and context.record.thaws_user():
		return score - 20
	return score

## Nobody wants to knock out the shiny one.
static func _shiny_wild_target(context: AIContext, score: int) -> int:
	if context.battle == null or not context.battle.is_wild_battle():
		return score
	if not context.opposes(context.target):
		return score
	if not context.target.pokemon.is_shiny():
		return score
	return score - 20

# === The Whole Move ===

## Every general judgement that is not about a particular target.
static func for_whole_move(context: AIContext, score: int) -> int:
	var adjusted: int = score
	adjusted = _setting_up_against_unaware(context, adjusted)
	adjusted = _thawing_move_while_frozen(context, adjusted)
	adjusted = _could_be_snatched(context, adjusted)
	adjusted = _suits_a_choice_item(context, adjusted)
	adjusted = _either_side_out_of_reserves(context, adjusted)
	adjusted = _dance_against_a_dancer(context, adjusted)
	adjusted = _shadow_move(context, adjusted)
	adjusted = _low_pp(context, adjusted)
	return adjusted

## A frozen battler should use the move that thaws it, and not the others.
static func _thawing_move_while_frozen(context: AIContext, score: int) -> int:
	if not context.skill.is_medium() or context.user.pokemon.status != &"FROZEN":
		return score
	if context.record.thaws_user():
		return score + 20
	if AIBattlerView.check_moves(context.user, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		return record != null and record.thaws_user()
	):
		return score - 20
	return score

## A beneficial status move can be taken out of the user's hands.
static func _could_be_snatched(context: AIContext, score: int) -> int:
	if context.is_damaging() or not MoveEffects.can_be_snatched(context.record):
		return score
	if context.battle == null:
		return score
	for battler: Battler in context.battle.all_active_battlers():
		if battler == context.user:
			continue
		if AIBattlerView.has_move_with_function(battler, SNATCH_CODES):
			return score - 7
	return score

## Being locked into one move for the rest of the battle makes the choice a different question: coverage, accuracy and PP matter far more than usual.
static func _suits_a_choice_item(context: AIContext, score: int) -> int:
	if not context.skill.is_medium():
		return score
	var locked: bool = CHOICE_ITEMS.has(context.user.held_item()) \
		or context.user.has_ability(&"GORILLATACTICS")
	if not locked:
		return score
	if context.is_damaging():
		var adjusted: int = score
		var move_type: StringName = context.move_type()
		# A move something is outright immune to is a move that could be locked into and then wasted.
		for type_id: StringName in Database.get_ids(Database.CATEGORY_TYPES):
			var record: TypeData = Database.type(type_id)
			if record != null and record.effectiveness_against_self(move_type) == 0.0:
				adjusted -= 8
		if context.record.accuracy > 0:
			adjusted -= int(0.4 * float(100 - context.record.accuracy))
		if context.record.total_pp <= 5:
			adjusted -= 10
		return adjusted
	if TRICK_CODES.has(context.record.function_code):
		return score
	return score - 25

## Opportunism and desperation, which pull in the same direction.
static func _either_side_out_of_reserves(context: AIContext, score: int) -> int:
	if not context.skill.is_medium() or not context.is_damaging() or context.battle == null:
		return score
	var ours: int = _reserve_count(context.battle, context.user.side_index())
	var theirs: int = _reserve_count(context.battle, context.user.opposing_side_index())
	# A good trainer that is behind on numbers plays properly rather than swinging for the fences.
	if context.skill.is_high() and theirs > ours:
		return score
	if theirs == 0:
		return score + 10
	if ours == 0:
		return score + 5
	return score

static func _reserve_count(battle: Battle, side: int) -> int:
	var party: PokemonParty = battle.get_party(side)
	return maxi(party.able_count() - battle.active_battlers_on_side(side).size(), 0)

## Dancer copies the move straight back.
static func _dance_against_a_dancer(context: AIContext, score: int) -> int:
	if not context.record.is_dance_move() or context.battle == null:
		return score
	var adjusted: int = score
	for foe: Battler in context.foes_of(context.user.side_index()):
		if foe.has_ability(&"DANCER"):
			adjusted -= 10
	return adjusted

static func _shadow_move(context: AIContext, score: int) -> int:
	return score + 10 if context.move_type() == &"SHADOW" else score

## The last PP of a move is worth keeping for when it is needed.
static func _low_pp(context: AIContext, score: int) -> int:
	for move: PokemonMove in context.user.moves():
		if move == null or move.data() == null:
			continue
		if move.data().id == context.record.id and move.pp <= 1:
			return score - 5
	return score

## Whether the battler has any of [param abilities] or any of [param items].
static func _has_any(
	battler: Battler, abilities: Array[StringName], items: Array[StringName], context: AIContext
) -> bool:
	if not context.ignores_target_ability():
		for ability: StringName in abilities:
			if battler.has_ability(ability):
				return true
	for item: StringName in items:
		if battler.held_item() == item:
			return true
	return false
