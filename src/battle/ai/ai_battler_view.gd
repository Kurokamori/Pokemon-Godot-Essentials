class_name AIBattlerView
extends RefCounted
## Read-only questions the AI asks about a battler, and about a reserve that is not on the field yet.

## Moves that attack with a stat other than the user's own Attack, 
## so the user's Attack stage is beside the point for them.
const BORROWED_ATTACK_CODES: Array[StringName] = [
	&"UseUserDefenseInsteadOfUserAttack", &"UseTargetAttackInsteadOfUserAttack",
]

## Moves that hit the target's Defense with a special attack, 
## so the target's Special Defense stage is beside the point for them.
const BORROWED_DEFENSE_CODES: Array[StringName] = [
	&"UseTargetDefenseInsteadOfTargetSpDef",
]

## Moves that get better the faster their user is, or the more stages it has banked. 
## Raising Speed is worth more to a battler that knows one.
const LIKES_HIGH_SPEED_CODES: Array[StringName] = [
	&"PowerHigherWithUserFasterThanTarget", &"PowerHigherWithUserPositiveStatStages",
]

## Moves that get better the slower their user is, or the more stages the target has banked
## the reason not to raise a stat in front of one.
const PUNISHES_HIGH_STATS_CODES: Array[StringName] = [
	&"PowerHigherWithTargetFasterThanUser", &"PowerHigherWithTargetPositiveStatStages",
]

## Moves that hit twice as hard while their user is poisoned, burned or paralysed
const FACADE_CODES: Array[StringName] = [&"DoublePowerIfUserPoisonedBurnedParalyzed"]

## Moves that pass a status problem to whoever they are aimed at, which is a reason not to leave one on a battler that knows one.
const STATUS_PASSING_CODES: Array[StringName] = [&"GiveUserStatusToTarget"]

## Moves whose power rises while the target has a status problem, so inflicting one is worth more to a side that knows one.
const LIKES_STATUSED_TARGET_CODES: Array[StringName] = [
	&"DoublePowerIfTargetStatusProblem", &"DoublePowerIfTargetPoisoned",
	&"DoublePowerIfTargetAsleepCureTarget", &"DoublePowerIfTargetParalyzedCureTarget",
	&"HealUserByHalfOfDamageDoneIfTargetAsleep", &"StartDamageTargetEachTurnIfTargetAsleep",
]

## The stat as the AI reckons it, stages included.
## Use effective speed so status, field effects and held items are included.
static func rough_stat(battler: Battler, stat: StringName) -> int:
	if battler == null:
		return 1
	if stat == &"SPEED":
		return battler.effective_speed()
	return battler.effective_stat(stat)

## Whether [param first] acts before [param second] on speed alone, Trick Room included. 
## Priority belongs to the move and is asked about separately.
static func faster_than(battle: Battle, first: Battler, second: Battler) -> bool:
	if first == null or second == null:
		return false
	var mine: int = rough_stat(first, &"SPEED")
	var theirs: int = rough_stat(second, &"SPEED")
	if mine == theirs:
		return false
	var reversed: bool = battle != null and battle.field.has_effect(BattleEffects.TRICK_ROOM)
	return mine < theirs if reversed else mine > theirs

static func positive_stat_stages(battler: Battler) -> int:
	if battler == null:
		return 0
	var total: int = 0
	for stat: StringName in Battler.STAT_STAGE_IDS:
		total += maxi(battler.get_stat_stage(stat), 0)
	return total

# === What It Knows ===

## Runs [param predicate] over every move that still has PP, stopping at the first `true`. 
## The predicate takes one [PokemonMove].
static func check_moves(battler: Battler, predicate: Callable) -> bool:
	if battler == null:
		return false
	for move: PokemonMove in battler.moves():
		if move == null:
			continue
		if move.pp <= 0 and move.total_pp() > 0:
			continue
		if bool(predicate.call(move)):
			return true
	return false

## Whether the battler knows any move whose effect is one of [param codes]
static func has_move_with_function(battler: Battler, codes: Array) -> bool:
	return check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		return record != null and codes.has(record.function_code)
	)

## Whether the battler knows a damaging move of any of [param types], 
## read as the type the move would actually come out as.
static func has_damaging_move_of_type(battle: Battle, battler: Battler, types: Array) -> bool:
	return check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		if record == null or not record.is_damaging():
			return false
		var effect: MoveEffect = MoveEffects.get_effect(record.function_code)
		return types.has(DamageCalculator.move_type_for(battle, battler, battler, record, effect))
	)

## The same question about a single type, which is how most callers ask it.
static func has_damaging_move_of(battle: Battle, battler: Battler, type_id: StringName) -> bool:
	return has_damaging_move_of_type(battle, battler, [type_id])

static func has_damaging_move(battler: Battler) -> bool:
	return check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		return record != null and record.is_damaging()
	)

## Whether the battler has a physical move whose damage its own Attack decides.
## Body Press and Foul Play are left out, because raising or lowering the holder's Attack does nothing to either.
static func has_physical_move(battler: Battler) -> bool:
	return check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		if record == null or not record.is_physical():
			return false
		return not BORROWED_ATTACK_CODES.has(record.function_code)
	)

static func has_special_move(battler: Battler) -> bool:
	return check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		return record != null and record.is_special()
	)

## Whether the battler has a special move that the target's Special Defense actually defends against.
static func has_special_move_hitting_special_defense(battler: Battler) -> bool:
	return check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		if record == null or not record.is_special():
			return false
		return not BORROWED_DEFENSE_CODES.has(record.function_code)
	)

## Whether the battler has a move the target's Defense defends against 
## either a physical move or one of the special moves that hits Defense anyway.
static func has_defense_targeting_move(battler: Battler) -> bool:
	return check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		if record == null:
			return false
		if record.is_physical():
			return true
		return BORROWED_DEFENSE_CODES.has(record.function_code)
	)

## The lowest accuracy among the battler's moves, ignoring the ones that never miss and the one-hit knockouts.
static func lowest_accuracy(battler: Battler) -> int:
	if battler == null:
		return 100
	var lowest: int = 100
	for move: PokemonMove in battler.moves():
		var record: MoveData = move.data() if move != null else null
		if record == null or record.accuracy <= 0:
			continue
		if MoveEffects.get_effect(record.function_code).is_ohko:
			continue
		lowest = mini(lowest, record.accuracy)
	return lowest

# === What It Can Do ===

## Whether the battler is in a state that lets it attack at all this round.
static func can_attack(battler: Battler) -> bool:
	if battler == null or battler.is_fainted():
		return false
	if battler.has_effect(BattleEffects.MULTI_TURN_ATTACK):
		return false
	if battler.pokemon.status == &"SLEEP" and battler.pokemon.status_count > 1:
		return false
	if battler.pokemon.status == &"FROZEN":
		return false
	if battler.truant_acted_last_round and battler.has_ability(&"TRUANT"):
		return false
	if battler.has_effect(BattleEffects.FLINCH):
		return false
	return true

## Whether damage that does not come from a move reaches the battler
static func takes_indirect_damage(battler: Battler) -> bool:
	return battler != null and not battler.has_ability(&"MAGICGUARD")

## Whether healing would do the battler any good right now.
static func can_heal(battler: Battler) -> bool:
	if battler == null or battler.is_fainted():
		return false
	if battler.hp() >= battler.total_hp():
		return false
	return not battler.has_effect(BattleEffects.HEAL_BLOCK)

## Whether the battler's Ability makes the move bounce off it entirely.
static func absorbs_move(battler: Battler, record: MoveData, move_type: StringName) -> bool:
	if battler == null or record == null or battler.ability_suppressed:
		return false
	return _ability_absorbs(battler.ability(), battler.types(), record, move_type)

## The same question asked of a reserve, which has no [Battler] to ask.
static func pokemon_absorbs_move(pkmn: Pokemon, record: MoveData, move_type: StringName) -> bool:
	if pkmn == null or record == null:
		return false
	return _ability_absorbs(pkmn.ability_id(), pkmn.types(), record, move_type)

static func _ability_absorbs(
	ability: StringName, types: Array[StringName], record: MoveData, move_type: StringName
) -> bool:
	match ability:
		&"BULLETPROOF":
			return record.is_bomb_move()
		&"SOUNDPROOF":
			return record.is_sound_move()
		&"FLASHFIRE":
			return move_type == &"FIRE"
		&"LIGHTNINGROD", &"MOTORDRIVE", &"VOLTABSORB":
			return move_type == &"ELECTRIC"
		&"SAPSIPPER":
			return move_type == &"GRASS"
		&"STORMDRAIN", &"WATERABSORB", &"DRYSKIN":
			return move_type == &"WATER"
		&"WONDERGUARD":
			return Database.type_effectiveness(move_type, types) <= 1.0
	return false

## Whether a reserve counts as airborne, for entry hazards and Ground moves.
static func pokemon_airborne(battle: Battle, pkmn: Pokemon) -> bool:
	if pkmn == null:
		return false
	if pkmn.held_item == &"IRONBALL":
		return false
	if battle != null and battle.field.has_effect(BattleEffects.GRAVITY):
		return false
	if pkmn.has_type(&"FLYING"):
		return true
	if pkmn.ability_id() == &"LEVITATE":
		return true
	return pkmn.held_item == &"AIRBALLOON"

## Whether Toxic Spikes would poison a reserve as it comes in.
static func pokemon_can_be_poisoned(battle: Battle, pkmn: Pokemon) -> bool:
	if pkmn == null:
		return false
	if battle != null and battle.field.terrain == &"Misty":
		return false
	if pkmn.has_type(&"POISON") or pkmn.has_type(&"STEEL"):
		return false
	match pkmn.ability_id():
		&"IMMUNITY", &"PASTELVEIL", &"COMATOSE", &"SHIELDSDOWN":
			return false
		&"FLOWERVEIL":
			return not pkmn.has_type(&"GRASS")
		&"LEAFGUARD":
			if battle != null and (battle.field.weather == &"Sun" or battle.field.weather == &"HarshSun"):
				return false
	return true

## What a move of [param move_type] would be worth against [param defender], without needing a move record.
static func effectiveness_of_type_against(
	battle: Battle, move_type: StringName, defender: Battler, attacker: Battler = null
) -> float:
	if defender == null or move_type.is_empty():
		return 1.0
	var defending: Array[StringName] = defender.types()
	var grounded: bool = defender.held_item() == &"IRONBALL"
	if battle != null and battle.field.has_effect(BattleEffects.GRAVITY):
		grounded = true
	if grounded and move_type == &"GROUND":
		defending = _without(defending, &"FLYING")
	var multiplier: float = Database.type_effectiveness(move_type, defending)
	if multiplier == 0.0 and defender.has_type(&"GHOST"):
		if move_type == &"NORMAL" or move_type == &"FIGHTING":
			if defender.has_effect(BattleEffects.FORESIGHT):
				multiplier = 1.0
			elif attacker != null and attacker.has_ability(&"SCRAPPY"):
				multiplier = 1.0
	return multiplier

static func _without(types: Array[StringName], removed: StringName) -> Array[StringName]:
	var kept: Array[StringName] = []
	for type_id: StringName in types:
		if type_id != removed:
			kept.append(type_id)
	if kept.is_empty():
		kept.append(&"NORMAL")
	return kept

# === Status Appetite ===

## Whether the battler would rather have [param new_status] than not.
## Guts, Quick Feet, Poison Heal and their kind turn a status problem into an advantage.
static func wants_status(_battle: Battle, battler: Battler, new_status: StringName) -> bool:
	if battler == null or new_status == &"NONE":
		return true
	match battler.ability():
		&"GUTS", &"QUICKFEET":
			if new_status != &"SLEEP" and new_status != &"FROZEN":
				return true
		&"MARVELSCALE":
			return true
		&"FLAREBOOST":
			if new_status == &"BURN":
				return true
		&"TOXICBOOST", &"POISONHEAL":
			if new_status == &"POISON":
				return true
		&"MAGICGUARD":
			if new_status == &"POISON" or new_status == &"BURN":
				return true
	if new_status == &"SLEEP":
		var sleeps_through: bool = check_moves(battler, func(move: PokemonMove) -> bool:
			var record: MoveData = move.data()
			return record != null and MoveEffects.get_effect(record.function_code).usable_while_asleep()
		)
		if sleeps_through:
			return true
	if has_move_with_function(battler, FACADE_CODES):
		if new_status == &"POISON" or new_status == &"BURN" or new_status == &"PARALYSIS":
			return true
	return false
