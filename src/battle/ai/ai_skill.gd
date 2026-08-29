class_name AISkill
extends RefCounted
## What one trainer knows

## The three boundaries, in the numbers the trainer data is written in.
## -.
## - [constant MEDIUM]: [constant CONSIDER_SWITCHING] and [constant HP_AWARE].
## - [constant HIGH]: read by the judgements directly rather than through a flag — the target's Ability and held item
## and the harder switching rules.
## - [constant BEST]: [constant RESERVE_LAST_POKEMON], and the trainer always takes the best move it found.

const MEDIUM: int = 32
const HIGH: int = 48
const BEST: int = 100

## Skill given to a wild Pokemon.
const WILD: int = 25

const WILD_LEGENDARY: int = MEDIUM

## Species flags that make a wild Pokemon count as a legendary for the rule above.
const LEGENDARY_FLAGS: Array[StringName] = [&"Legendary", &"Mythical", &"UltraBeast"]

# === Skill Flags ===

## The trainer works out in advance that a move would fail, and does not pick it.
const PREDICT_MOVE_FAILURE: StringName = &"PredictMoveFailure"

## The trainer scores its moves at all. Without it every move is worth the same and the choice is a coin toss.
const SCORE_MOVES: StringName = &"ScoreMoves"

## The trainer prefers a move that reaches more than one battler.
const PREFER_MULTI_TARGET_MOVES: StringName = &"PreferMultiTargetMoves"

## The trainer weighs how much health the user and the target have left.
const HP_AWARE: StringName = &"HPAware"

## The trainer will switch a Pokemon out rather than always attacking.
const CONSIDER_SWITCHING: StringName = &"ConsiderSwitching"

## The trainer keeps its last Pokemon back for as long as it can.
const RESERVE_LAST_POKEMON: StringName = &"ReserveLastPokemon"

## The trainer sends out the earliest-listed Pokemon it can rather than choosing.
const USE_POKEMON_IN_ORDER: StringName = &"UsePokemonInOrder"

## Every flag the engine itself reads.
const ENGINE_FLAGS: Array[StringName] = [
	PREDICT_MOVE_FAILURE, SCORE_MOVES, PREFER_MULTI_TARGET_MOVES, HP_AWARE,
	CONSIDER_SWITCHING, RESERVE_LAST_POKEMON, USE_POKEMON_IN_ORDER,
]

## What a trainer record writes in front of a flag name to take that flag away.
const NEGATION_PREFIX: String = "Anti"

## The skill number this was built from.
var skill: int = 0

var flags: Array[StringName] = []

## The skill of a trainer with no record behind it
static func of(level: int, trainer_flags: Array[StringName] = []) -> AISkill:
	var built: AISkill = AISkill.new()
	built.skill = level
	built._set_up_flags(trainer_flags)
	return built

## The skill in force for whoever is choosing [param battler]'s action.
static func for_battler(battle: Battle, battler: Battler) -> AISkill:
	if battle == null or battler == null:
		return AISkill.of(WILD)
	return for_side(battle, battler.side_index(), battler)

## The skill in force querried from the side rather than of a battler.
## Choose skill from the side when the active battler has already fainted.
static func for_side(battle: Battle, side: int, battler: Battler = null) -> AISkill:
	if battle == null:
		return AISkill.of(WILD)
	if battle.is_wild_battle() and side != 0:
		return _for_wild(battler)
	var best: int = 0
	var gathered: Array[StringName] = []
	for trainer: TrainerData in battle.opponent_trainers:
		var record: TrainerTypeData = Database.trainer_type(trainer.trainer_type)
		if record != null:
			best = maxi(best, record.skill_level)
		for flag: StringName in trainer.flags:
			if not gathered.has(flag):
				gathered.append(flag)
	return AISkill.of(best, gathered)

## The skill a wild Pokemon fights at.
static func _for_wild(battler: Battler) -> AISkill:
	if battler == null or not GameSettings.data.smarter_wild_legendary_pokemon:
		return AISkill.of(WILD)
	var record: SpeciesData = battler.species_data()
	if record != null:
		for flag: StringName in LEGENDARY_FLAGS:
			if record.has_flag(flag):
				return AISkill.of(WILD_LEGENDARY)
	return AISkill.of(WILD)

## Hands out the flags, adds the trainer's own, then removes every flag the trainer wrote an `Anti` entry for.
func _set_up_flags(trainer_flags: Array[StringName]) -> void:
	flags.clear()
	if skill > 0:
		flags.append(PREDICT_MOVE_FAILURE)
		flags.append(SCORE_MOVES)
		flags.append(PREFER_MULTI_TARGET_MOVES)
	if is_medium():
		flags.append(CONSIDER_SWITCHING)
		flags.append(HP_AWARE)
	else:
		flags.append(USE_POKEMON_IN_ORDER)
	if is_best():
		flags.append(RESERVE_LAST_POKEMON)
	for flag: StringName in trainer_flags:
		if not flags.has(flag):
			flags.append(flag)
	var kept: Array[StringName] = []
	for flag: StringName in flags:
		if flags.has(StringName(NEGATION_PREFIX + String(flag))):
			continue
		kept.append(flag)
	flags = kept

func has_flag(flag: StringName) -> bool:
	return flags.has(flag)

func is_medium() -> bool:
	return skill >= MEDIUM

func is_high() -> bool:
	return skill >= HIGH

func is_best() -> bool:
	return skill >= BEST

func move_score_threshold() -> float:
	return 0.6 + (0.35 * sqrt(float(mini(skill, 100)) / 100.0))
