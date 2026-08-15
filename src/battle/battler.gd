class_name Battler
extends RefCounted
## A Pokemon and its temporary state while it is in battle.

const STAT_STAGE_IDS: Array[StringName] = [
	&"ATTACK", &"DEFENSE", &"SPECIAL_ATTACK", &"SPECIAL_DEFENSE", &"SPEED",
	&"ACCURACY", &"EVASION",
]

## Multipliers for stat stages -6 to +6, for Attack-like stats.
const STAGE_MULTIPLIERS: Array[float] = [
	2.0 / 8.0, 2.0 / 7.0, 2.0 / 6.0, 2.0 / 5.0, 2.0 / 4.0, 2.0 / 3.0, 1.0,
	3.0 / 2.0, 4.0 / 2.0, 5.0 / 2.0, 6.0 / 2.0, 7.0 / 2.0, 8.0 / 2.0,
]

## Multipliers for stat stages -6 to +6, for accuracy and evasion.
const ACCURACY_STAGE_MULTIPLIERS: Array[float] = [
	3.0 / 9.0, 3.0 / 8.0, 3.0 / 7.0, 3.0 / 6.0, 3.0 / 5.0, 3.0 / 4.0, 1.0,
	4.0 / 3.0, 5.0 / 3.0, 6.0 / 3.0, 7.0 / 3.0, 8.0 / 3.0, 9.0 / 3.0,
]

signal fainted()
signal hp_changed(old_hp: int, new_hp: int)
signal stat_stage_changed(stat: StringName, change: int)

## The party Pokemon this battler represents.
var pokemon: Pokemon = null

## Battle position; even indices are the player's side and odd indices are the opposing side.
var index: int = 0

## The battle this battler belongs to.
var battle: Battle = null

## Party slot this battler was sent out from.
var party_index: int = 0

var stat_stages: Dictionary = {}
## Volatile effects keyed by the names in [BattleEffects].
var effects: Dictionary = {}

@export_group("Overrides")
## Type list while transformed or type-changed. Empty uses the species types.
var type_override: Array[StringName] = []

## Ability suppressed by Gastro Acid or replaced by Skill Swap.
var ability_override: StringName = &""
var ability_suppressed: bool = false

## Species shown and used for weight while transformed.
var transformed_into: Pokemon = null

## Base stats replaced by Power Split, Guard Split, Speed Swap, or Transform.
var stat_overrides: Dictionary = {}

## Replacement moves used by Transform and Mimic; empty means use the real moveset.
var move_override: Array[PokemonMove] = []

@export_group("Turn State")
## `true` once this battler has acted this round.
var has_acted: bool = false

## Damage taken so far this round, used by Counter, Bide and Assurance.
var damage_taken_this_turn: int = 0

## Category of the last damage taken this round.
var last_damage_category: int = -1

## Battle position of the last attacker, used by faint reactions such as Aftermath and Moxie.
var last_attacker_index: int = -1

## Id of the move that last dealt damage to this battler, or empty.
var last_move_taken: StringName = &""

## `true` when this battler was damaged by a move this round.
var took_damage_this_turn: bool = false

## `true` when a physical move damaged this battler this round, for Shell Trap.
var took_physical_hit: bool = false

## The move used last round, for Encore, Disable and Torment.
var last_move_used: StringName = &""

## The move used the round before, for Mirror Move.
var last_move_used_sketch: StringName = &""

## The last normally chosen move, used by Mirror Move, Sketch, Mimic, Instruct, and Spite.
var last_regular_move_used: StringName = &""

## Battler index [member last_regular_move_used] was aimed at, or `-1`.
var last_regular_move_target: int = -1

## The type the last move used counted as, for Conversion 2.
var last_move_used_type: StringName = &""

## Every move used this battle, for Last Resort.
var moves_used: Array[StringName] = []

## Move this battler is locked into for Bide, Rollout, and Outrage.
var forced_move_id: StringName = &""

## Battler index a forced move is aimed at, or `-1` to resolve normally.
var forced_move_target: int = -1

## Consecutive uses of the same move, for Fury Cutter and Rollout.
var consecutive_move_uses: int = 0

## `true` when the last move failed, for Stomping Tantrum.
var last_move_failed: bool = false

## `true` while this battler is switching out.
var switching_out: bool = false

## Turns this battler has spent on the field without switching.
var turns_active: int = 0

## Battlers that participated against this one, for experience sharing.
var participants: Array[int] = []

## Item consumed this battle, for Recycle and Harvest.
var consumed_item: StringName = &""

## `true` when the held item was used up rather than knocked off.
var item_consumed_by_self: bool = false

## Stat stages lowered this round, for Defiant and Competitive.
var stats_lowered_this_turn: bool = false

var stats_raised_this_turn: bool = false

## `true` during the round this battler was sent out, when Stakeout deals extra damage.
var switched_in_this_turn: bool = false

## `true` after this battler's entry Abilities have run.
var switch_in_resolved: bool = false

## `true` when Truant caused this battler to loaf around this round.
var truant_acted_last_round: bool = false

## The party member this Pokemon is disguising itself as through Illusion.
var illusion_pokemon: Pokemon = null

## `true` after Disguise or Ice Face has absorbed a hit this battle.
var form_shield_broken: bool = false

## Id of the [BattleGimmick] currently in force on this Pokemon, or empty.
var gimmick: StringName = &""

## The form before Mega Evolution, or `-1` when the form has not changed.
var pre_gimmick_form: int = -1

## Maximum HP before Dynamax raised it, or `0` when it has not.
var pre_gimmick_total_hp: int = 0

## Rounds of Dynamax left.
var dynamax_turns: int = 0

## The type this Pokemon Terastallized into, or empty.
var tera_type: StringName = &""

## Safari Zone catch-rate modifier from bait and rocks.
var safari_catch_factor: float = 1.0

## Safari Zone flee-rate modifier from bait and rocks.
var safari_flee_factor: float = 1.0

func _init(source: Pokemon, battle_index: int, owning_battle: Battle) -> void:
	pokemon = source
	index = battle_index
	battle = owning_battle
	reset_stat_stages()

# === Identity ===

func display_name() -> String:
	if illusion_pokemon != null:
		return illusion_pokemon.display_name()
	return pokemon.display_name()

## The name as it appears in battle messages, prefixed for the opposing side.
func battle_name() -> String:
	if is_player_side():
		return display_name()
	if battle != null and battle.is_wild_battle():
		return "Wild " + display_name()
	return "Foe " + display_name()

func is_player_side() -> bool:
	return index % 2 == 0

func side_index() -> int:
	return index % 2

func opposing_side_index() -> int:
	return (index + 1) % 2

func species_data() -> SpeciesData:
	if transformed_into != null:
		return transformed_into.species_data()
	return pokemon.species_data()

func level() -> int:
	return pokemon.level()

# === Health ===

func hp() -> int:
	return pokemon.hp

func total_hp() -> int:
	return pokemon.total_hp

func hp_fraction() -> float:
	return float(hp()) / float(maxi(total_hp(), 1))

func is_fainted() -> bool:
	return pokemon.hp <= 0

func is_active() -> bool:
	return not is_fainted() and not switching_out

## Applies damage and returns the amount actually dealt.
func take_damage(amount: int) -> int:
	var before: int = pokemon.hp
	var dealt: int = pokemon.take_damage(amount)
	if dealt > 0:
		damage_taken_this_turn += dealt
		took_damage_this_turn = true
		hp_changed.emit(before, pokemon.hp)
		if pokemon.hp <= 0:
			fainted.emit()
	return dealt

func restore_hp(amount: int) -> int:
	var before: int = pokemon.hp
	var healed: int = pokemon.restore_hp(amount)
	if healed > 0:
		hp_changed.emit(before, pokemon.hp)
	return healed

# === Types ===

func types() -> Array[StringName]:
	if not type_override.is_empty():
		return type_override.duplicate()
	if transformed_into != null:
		return transformed_into.types()
	return pokemon.types()

func has_type(type_id: StringName) -> bool:
	return types().has(type_id)

## `true` when the battler is off the ground and immune to Ground moves, Spikes, and terrain effects.
func is_airborne() -> bool:
	if battle != null and battle.field.has_effect(BattleEffects.GRAVITY):
		return false
	if effects.get(BattleEffects.SMACK_DOWN, 0) > 0:
		return false
	if effects.get(BattleEffects.INGRAIN, 0) > 0:
		return false
	if held_item() == &"IRONBALL":
		return false
	if has_type(&"FLYING") and effects.get(BattleEffects.ROOST, 0) == 0:
		return true
	if ability() == &"LEVITATE":
		return true
	if held_item() == &"AIRBALLOON":
		return true
	if effects.get(BattleEffects.MAGNET_RISE, 0) > 0:
		return true
	if effects.get(BattleEffects.TELEKINESIS, 0) > 0:
		return true
	return false

# === Ability and Item ===

## The Pokemon's ability before field effects such as Neutralizing Gas are applied.
func raw_ability() -> StringName:
	if ability_suppressed:
		return &""
	if not ability_override.is_empty():
		return ability_override
	return pokemon.ability_id()

func ability() -> StringName:
	var own: StringName = raw_ability()
	if own.is_empty() or own == &"NEUTRALIZINGGAS":
		return own
	# Neutralizing Gas suppresses every other Ability except the unsuppressable ones.
	if AbilityEffects.UNSUPPRESSABLE.has(own):
		return own
	if battle != null and battle.neutralizing_gas_active():
		return &""
	return own

func has_ability(ability_id: StringName) -> bool:
	return ability() == ability_id

## `true` when the ability can be ignored by Mold Breaker and friends.
func ability_can_be_ignored() -> bool:
	var record: AbilityData = Database.ability(ability())
	return record == null or not record.has_flag(&"CannotBeIgnored")

## Battle weight in hectograms after Heavy Metal, Light Metal, and Float Stone.
func weight() -> int:
	var record: SpeciesData = species_data()
	var value: int = record.weight if record != null else 1
	match ability():
		&"HEAVYMETAL":
			value *= 2
		&"LIGHTMETAL":
			@warning_ignore("integer_division")
			value /= 2
	if held_item() == &"FLOATSTONE":
		@warning_ignore("integer_division")
		value /= 2
	return maxi(value, 1)

func held_item() -> StringName:
	if battle != null and battle.field.has_effect(BattleEffects.MAGIC_ROOM):
		return &""
	if effects.get(BattleEffects.EMBARGO, 0) > 0:
		return &""
	if has_ability(&"KLUTZ"):
		return &""
	return pokemon.held_item

func has_item(item_id: StringName) -> bool:
	return held_item() == item_id

## Removes the held item, remembering it for Recycle.
func consume_item(by_self: bool = true) -> StringName:
	var item: StringName = pokemon.held_item
	if item.is_empty():
		return &""
	pokemon.held_item = &""
	consumed_item = item
	item_consumed_by_self = by_self
	# Pickup searches the battle's consumed items, so record every item that leaves a battler.
	if by_self and battle != null and battle.tally != null:
		battle.tally.record_item_consumed(item)
	return item

# === Stat Stages ===

func reset_stat_stages() -> void:
	for stat: StringName in STAT_STAGE_IDS:
		stat_stages[stat] = 0

func get_stat_stage(stat: StringName) -> int:
	return int(stat_stages.get(stat, 0))

## `true` when the stat can still be raised, as checked before spending an X item.
func can_raise_stat(stat: StringName) -> bool:
	return get_stat_stage(stat) < GameSettings.data.max_stat_stage

## Changes a stat stage within the configured limits and returns the actual change.
func change_stat_stage(stat: StringName, change: int) -> int:
	# Simple counts every change twice, in either direction.
	if has_ability(&"SIMPLE"):
		change *= 2
	var limit: int = GameSettings.data.max_stat_stage
	var current: int = get_stat_stage(stat)
	var wanted: int = clampi(current + change, -limit, limit)
	var actual: int = wanted - current
	if actual == 0:
		return 0
	stat_stages[stat] = wanted
	if actual < 0:
		stats_lowered_this_turn = true
	else:
		stats_raised_this_turn = true
	stat_stage_changed.emit(stat, actual)
	return actual

## The multiplier a stat stage applies.
func stat_stage_multiplier(stat: StringName) -> float:
	var stage: int = get_stat_stage(stat)
	var table: Array[float] = ACCURACY_STAGE_MULTIPLIERS if stat == &"ACCURACY" or stat == &"EVASION" else STAGE_MULTIPLIERS
	return table[clampi(stage + 6, 0, 12)]

## Total positive stat stages, used by Stored Power and the AI.
func total_positive_stages() -> int:
	var total: int = 0
	for stat: StringName in STAT_STAGE_IDS:
		total += maxi(get_stat_stage(stat), 0)
	return total

## The raw stat value before stages, including split moves, Transform, and Power Trick.
func base_stat(stat: StringName) -> int:
	if effects.get(BattleEffects.POWER_TRICK, 0) > 0:
		if stat == &"ATTACK":
			return _unswapped_stat(&"DEFENSE")
		if stat == &"DEFENSE":
			return _unswapped_stat(&"ATTACK")
	return _unswapped_stat(stat)

## The raw stat before Power Trick swaps Attack and Defense.
func _unswapped_stat(stat: StringName) -> int:
	if stat_overrides.has(stat):
		return maxi(int(stat_overrides[stat]), 1)
	return pokemon.get_stat(stat)

## Replaces a base stat for the rest of the battle.
func set_base_stat(stat: StringName, value: int) -> void:
	stat_overrides[stat] = maxi(value, 1)

## The stat as used in the damage formula, including stage multipliers.
func effective_stat(stat: StringName, ignore_stages: bool = false) -> int:
	var value: float = float(base_stat(stat))
	if not ignore_stages:
		value *= stat_stage_multiplier(stat)
	return maxi(int(value), 1)

## Speed after stages, status, abilities, items, Tailwind and the Pledge swamp.
func effective_speed() -> int:
	var speed: float = float(base_stat(&"SPEED")) * stat_stage_multiplier(&"SPEED")
	speed *= AbilityEffects.speed_multiplier(self)
	speed *= ItemEffects.speed_multiplier(self)
	if battle != null and battle.get_side(side_index()).has_effect(BattleEffects.TAILWIND):
		speed *= 2.0
	if battle != null and battle.get_side(side_index()).has_effect(BattleEffects.SWAMP):
		speed *= 0.25
	if pokemon.status == &"PARALYSIS" and not has_ability(&"QUICKFEET"):
		speed *= 0.5 if GameSettings.data.mechanics_generation >= 7 else 0.25
	return maxi(int(speed), 1)

# === Effects ===

## Returns whether an effect is active, whether it stores a counter or an identifier.
func has_effect(effect: StringName) -> bool:
	if not effects.has(effect):
		return false
	var value: Variant = effects[effect]
	match typeof(value):
		TYPE_INT: return int(value) > 0
		TYPE_BOOL: return bool(value)
		TYPE_STRING, TYPE_STRING_NAME: return not String(value).is_empty()
	return value != null

func get_effect(effect: StringName) -> Variant:
	return effects.get(effect, 0)

## Returns an effect's identifier, or an empty [StringName] for counters and inactive effects.
func get_effect_id(effect: StringName) -> StringName:
	var value: Variant = effects.get(effect)
	if value is StringName or value is String:
		return StringName(value)
	return &""

## Sets a volatile effect unless the battler's Abilities block that mental effect.
func set_effect(effect: StringName, value: Variant) -> void:
	if AbilityEffects.MENTAL_EFFECTS.has(effect) and AbilityEffects.blocks_mental_effect(self, effect):
		return
	effects[effect] = value

## Returns whether Roar, Whirlwind, Dragon Tail, or a similar move can force this battler out.
func can_be_forced_out() -> bool:
	if has_ability(&"SUCTIONCUPS"):
		return false
	if has_effect(BattleEffects.INGRAIN):
		return false
	return true

func clear_effect(effect: StringName) -> void:
	effects.erase(effect)

## Decrements timed effects and removes those that expire.
func tick_effects() -> void:
	for effect: StringName in effects.keys():
		var value: Variant = effects[effect]
		if typeof(value) != TYPE_INT or value <= 0:
			continue
		if BattleEffects.UNTIMED.has(effect):
			continue
		effects[effect] = value - 1
		if effects[effect] <= 0:
			effects.erase(effect)

## Clears everything that does not survive switching out.
func reset_on_switch_out() -> void:
	reset_stat_stages()
	effects.clear()
	type_override.clear()
	ability_override = &""
	ability_suppressed = false
	transformed_into = null
	stat_overrides.clear()
	move_override.clear()
	consecutive_move_uses = 0
	last_move_used = &""
	last_regular_move_used = &""
	last_regular_move_target = -1
	last_move_used_type = &""
	moves_used.clear()
	forced_move_id = &""
	forced_move_target = -1
	turns_active = 0
	participants.clear()
	truant_acted_last_round = false
	illusion_pokemon = null
	form_shield_broken = false
	# Dynamax ends on switch-out; Mega Evolution and Terastallization persist for the battle.
	dynamax_turns = 0

func begin_turn() -> void:
	has_acted = false
	damage_taken_this_turn = 0
	took_damage_this_turn = false
	took_physical_hit = false
	last_damage_category = -1
	stats_lowered_this_turn = false
	stats_raised_this_turn = false
	clear_effect(BattleEffects.MOVE_NEXT)
	clear_effect(BattleEffects.QUASH)

func end_turn() -> void:
	turns_active += 1

# === Moves ===

## The moves this battler can currently select.
func usable_moves() -> Array[PokemonMove]:
	var result: Array[PokemonMove] = []
	for move: PokemonMove in moves():
		if can_use_move(move):
			result.append(move)
	return result

func can_use_move(move: PokemonMove) -> bool:
	if move.is_out_of_pp():
		return false
	# Bide, Rollout, and Outrage lock the battler into one move until they end.
	if not forced_move_id.is_empty() and move.id != forced_move_id:
		return false
	if has_effect(BattleEffects.DISABLE) and get_effect_id(BattleEffects.DISABLE_MOVE) == move.id:
		return false
	if has_effect(BattleEffects.ENCORE) and get_effect_id(BattleEffects.ENCORE_MOVE) != move.id:
		return false
	if has_effect(BattleEffects.TORMENT) and last_move_used == move.id:
		return false
	var record: MoveData = move.data()
	if record == null:
		return false
	if has_effect(BattleEffects.TAUNT) and record.is_status():
		return false
	if has_effect(BattleEffects.HEAL_BLOCK) and record.is_healing_move():
		return false
	if has_effect(BattleEffects.THROAT_CHOP) and record.is_sound_move():
		return false
	if held_item() == &"ASSAULTVEST" and record.is_status():
		return false
	if has_effect(BattleEffects.MOVE_LOCK) and last_move_used != move.id and not last_move_used.is_empty():
		return false
	return true

## The moveset currently in play, including replacements from Transform and Mimic.
func moves() -> Array[PokemonMove]:
	if not move_override.is_empty():
		return move_override
	return pokemon.moves

## The known move with [param move_id], or `null`.
func get_move(move_id: StringName) -> PokemonMove:
	for move: PokemonMove in moves():
		if move.id == move_id:
			return move
	return null

func knows_move(move_id: StringName) -> bool:
	return get_move(move_id) != null

## Copies the moveset so a move can be replaced without changing the party Pokemon.
func detach_moveset() -> void:
	if not move_override.is_empty():
		return
	for move: PokemonMove in pokemon.moves:
		move_override.append(move.duplicate_move())

## Copies the target's battle properties as Transform and Imposter do.
func transform_into(target: Battler) -> void:
	set_effect(BattleEffects.TRANSFORM, true)
	transformed_into = target.transformed_into if target.transformed_into != null else target.pokemon
	type_override = target.types()
	ability_override = target.ability()
	for stat: StringName in [&"ATTACK", &"DEFENSE", &"SPECIAL_ATTACK", &"SPECIAL_DEFENSE", &"SPEED"]:
		set_base_stat(stat, target.base_stat(stat))
	for stat: StringName in STAT_STAGE_IDS:
		stat_stages[stat] = target.get_stat_stage(stat)
	move_override.clear()
	for move: PokemonMove in target.moves():
		var copy: PokemonMove = PokemonMove.create(move.id)
		copy.pp = mini(5, copy.total_pp())
		move_override.append(copy)
	clear_effect(BattleEffects.DISABLE)
	clear_effect(BattleEffects.DISABLE_MOVE)

func is_transformed() -> bool:
	return has_effect(BattleEffects.TRANSFORM)

## Returns `true` when this battler cannot switch out or flee.
func is_trapped() -> bool:
	if is_airborne() or has_type(&"GHOST"):
		return false
	if held_item() == &"SHEDSHELL":
		return false
	if has_effect(BattleEffects.MEAN_LOOK) or has_effect(BattleEffects.TRAPPING):
		return true
	if has_effect(BattleEffects.INGRAIN):
		return true
	if battle != null and battle.field.has_effect(BattleEffects.FAIRY_LOCK):
		return true
	if battle != null:
		for opponent: Battler in battle.opposing_battlers(self):
			if AbilityEffects.traps_opponent(opponent, self):
				return true
	return false

# === Status ===

## Returns `true` when a status condition can currently be inflicted.
func can_take_status(status_id: StringName, inflicter: Battler = null) -> bool:
	if is_fainted():
		return false
	if pokemon.status != &"NONE":
		return false
	if battle != null and battle.get_side(side_index()).has_effect(BattleEffects.SAFEGUARD):
		if inflicter == null or inflicter.side_index() != side_index():
			return false
	if AbilityEffects.blocks_status(self, status_id):
		return false
	if ItemEffects.blocks_status(self, status_id):
		return false
	match status_id:
		&"BURN":
			return not has_type(&"FIRE")
		&"POISON":
			if has_type(&"POISON") or has_type(&"STEEL"):
				return inflicter != null and inflicter.has_ability(&"CORROSION")
			return true
		&"PARALYSIS":
			return not (has_type(&"ELECTRIC") and GameSettings.data.mechanics_generation >= 6)
		&"FROZEN":
			if has_type(&"ICE"):
				return false
			return battle == null or battle.field.weather != &"Sun"
		&"SLEEP":
			if battle != null and battle.field.terrain == &"Electric" and not is_airborne():
				return false
			return true
	return true

## Inflicts a status. 
## Returns `false` when it could not be applied.
func inflict_status(status_id: StringName, turns: int = 0, inflicter: Battler = null) -> bool:
	if not can_take_status(status_id, inflicter):
		return false
	pokemon.status = status_id
	match status_id:
		&"SLEEP":
			pokemon.status_count = turns if turns > 0 else RNG.range_int(2, 4)
		&"POISON":
			pokemon.status_count = turns
			if turns > 0:
				set_effect(BattleEffects.TOXIC_COUNTER, 1)
		_:
			pokemon.status_count = 0
	# Synchronize passes the condition back to whoever caused it.
	if battle != null:
		for message: String in AbilityReactions.on_status_inflicted(self, inflicter, status_id):
			battle.announce(message)
	return true

func cure_status() -> void:
	pokemon.status = &"NONE"
	pokemon.status_count = 0
	clear_effect(BattleEffects.TOXIC_COUNTER)

func is_badly_poisoned() -> bool:
	return pokemon.status == &"POISON" and pokemon.status_count > 0

func is_asleep() -> bool:
	return pokemon.status == &"SLEEP"

# === Substitute ===

func has_substitute() -> bool:
	return int(effects.get(BattleEffects.SUBSTITUTE, 0)) > 0

## Damages the substitute
## Returns `true` when it broke.
func damage_substitute(amount: int) -> bool:
	var remaining: int = int(effects.get(BattleEffects.SUBSTITUTE, 0)) - amount
	if remaining <= 0:
		effects.erase(BattleEffects.SUBSTITUTE)
		return true
	effects[BattleEffects.SUBSTITUTE] = remaining
	return false
