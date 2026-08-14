@tool
class_name Pokemon
extends Resource
## A single Pokemon and everything the game hold of one single creature.
## 
## Personal ID derrives gender, nature, ability, shininess, and is caches, so any two pokemon with 
## the same personal ID are identical.
##
## Trainer data, mints, and debug menu all override this directly.

const STAT_IDS: Array[StringName] = [
	&"HP", &"ATTACK", &"DEFENSE", &"SPECIAL_ATTACK", &"SPECIAL_DEFENSE", &"SPEED"
]


## The base friendship/happiness a hatched egg hatches with, instead of its species base hapiness.
const HATCHED_HAPPINESS: int = 120

const MAX_HAPPINESS: int = 255

enum Gender {
	MALE = 0,
	FEMALE = 1,
	GENDERLESS = 2,
}

enum ObtainMethod {
	MET = 0,
	EGG = 1,
	TRADED = 2,
	FATEFUL_ENCOUNTER = 4,
}

## Emitted whenever HP changes, so UI can animate without polling.
signal hp_changed(old_hp: int, new_hp: int)

## Emitted when the non-volatile status changes.
signal status_changed(old_status: StringName, new_status: StringName)

@export_group("Identity")
@export var species: StringName = &"":
	set(value):
		species = value
		_invalidate_derived()
		
## Personal id. 
## Influences gender, nautre, ability slot, shininess, and Wurmple's evolution
@export var personal_id: int = 0

## Form number in use. 
## `-1` requests the form handler to decide.
@export var form: int = 0:
	set(value):
		form = value
		_invalidate_derived()
		
## Form forced by an effect, overriding the form handler.
## `-1` means unforced.
@export var forced_form: int = -1

## Game time in seconds when [member forced_form] was applied
## used for forms that revert after some time.
@export var time_form_set: int = 0

## Type this Pokemon Terastallizes into. 
## Empty means it has not been decided yet,
## in which case [method tera_type] settles on its first type.
@export var tera_type_override: StringName = &""
@export var nickname: String = ""

@export_group("Level and Health")
@export var experience: int = 0
@export var hp: int = 1:
	set(value):
		var clamped: int = clampi(value, 0, maxi(total_hp, 1))
		if clamped == hp:
			return
		var previous: int = hp
		hp = clamped
		hp_changed.emit(previous, hp)
@export var total_hp: int = 1
@export var status: StringName = &"NONE":
	set(value):
		if value == status:
			return
		var previous: StringName = status
		status = value
		if value != &"SLEEP" and value != &"POISON":
			status_count = 0
		status_changed.emit(previous, status)
## Sleep turns remaining, or badly-poisoned counter.
@export var status_count: int = 0

@export_group("Stats")
@export var attack: int = 1
@export var defense: int = 1
@export var special_attack: int = 1
@export var special_defense: int = 1
@export var speed: int = 1

## Individual values in [constant STAT_IDS] order.
@export var ivs: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])

## Stats that Hyper Training has maxed out, in [constant STAT_IDS] order.
@export var ivs_hyper_trained: Array[bool] = [false, false, false, false, false, false]

## Effort values in [constant STAT_IDS] order.
@export var evs: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])

@export_group("Traits")
## Explicit nature id. Empty gets it from [member personal_id].
@export var nature_override: StringName = &""

## Nature used exclusively for stat calculation, as altered by a Mint.
@export var nature_for_stats_override: StringName = &""

## Explicit ability id, set by Skill Swap-likes or trainer data.
@export var ability_override: StringName = &""

## Ability slot: 0 and 1 are normal abilities, 2+ are hidden abilities.
@export_range(0, 5) var ability_index: int = 0

## Explicit gender. `-1` derives it from [member personal_id].
@export_range(-1, 2) var gender_override: int = -1

## `-1` derives shininess from the ids
## `0` forces shinies off, `1` forces shinies on.
@export_range(-1, 1) var shiny_override: int = -1
@export_range(-1, 1) var super_shiny_override: int = -1
@export var held_item: StringName = &""
@export_range(0, 255) var happiness: int = 70

## Pokerus strain and days remaining.
@export var pokerus: int = 0
@export var poke_ball: StringName = &"POKEBALL"

@export_group("Moves")
@export var moves: Array[PokemonMove] = []

## Moves this Pokemon knew when it was first obtained useful for the Move Relearner
@export var first_moves: Array[StringName] = []

@export_group("Eggs")
## Steps left before an egg hatches. `0` means this is not an egg.
@export var steps_to_hatch: int = 0
@export var hatched_map: int = 0

@export_group("Record")
@export var owner: PokemonOwner = null
@export var obtain_method: ObtainMethod = ObtainMethod.MET
@export var obtain_map: int = 0

## Overrides the map name shown on the summary screen.
@export var obtain_text: String = ""
@export var obtain_level: int = 1
@export var time_received: int = 0
@export var time_egg_hatched: int = 0
@export var ribbons: Array[StringName] = []

## The six summary-screen markings.
@export var markings: int = 0

@export_group("Contest Stats")
@export_range(0, 255) var cool: int = 0
@export_range(0, 255) var beauty: int = 0
@export_range(0, 255) var cute: int = 0
@export_range(0, 255) var smart: int = 0
@export_range(0, 255) var tough: int = 0
@export_range(0, 255) var sheen: int = 0

@export_group("Restrictions")
@export var cannot_store: bool = false
@export var cannot_release: bool = false
@export var cannot_trade: bool = false

## Set after a level-up that met an evolution condition.
@export var ready_to_evolve: bool = false

@export_group("Shadow Pokemon")
@export var shadow: bool = false
@export var heart_gauge: int = 0

## Steps walked towards the next time the gauge is worn down by walking. 
## Kept as Per-Pokemon instead of global so that it can be deposited adn withdrawn without loosing count.
@export var heart_gauge_steps: int = 0
@export var hyper_mode: bool = false

## Which moves were replaced by Shadow moves, restored during purification.
@export var shadow_moves: Array[StringName] = []

## Experience won in Shadow battles and held back.
@export var shadow_saved_exp: int = 0

## Effort values earned in Shadow battles and held back.
## In the same order as [constant STAT_IDS]
@export var shadow_saved_evs: PackedInt32Array = PackedInt32Array()

## Mail attached to this Pokemon, or `null`.
@export var mail: PokemonMail = null

## The Pokemon fused into this one by Kyurem-likes, or `null`.
@export var fused: Pokemon = null

var _cached_gender: int = -1
var _cached_nature: StringName = &""
var _cached_ability: StringName = &""
var _cached_shiny: int = -1
var _cached_super_shiny: int = -1


# === Construction ===

## Creates a fully rolled Pokemon of [param species_id] at [param at_level].
static func create(species_id: StringName, at_level: int, new_owner: PokemonOwner = null) -> Pokemon:
	var pkmn: Pokemon = Pokemon.new()
	pkmn.species = species_id
	pkmn.personal_id = RNG.generator.randi() & 0xFFFFFFFF
	pkmn.owner = new_owner if new_owner != null else PokemonOwner.create_unowned()
	var record: SpeciesData = pkmn.species_data()
	if record == null:
		push_error("Pokemon.create: unknown species '%s'." % species_id)
		return pkmn
	pkmn.form = FormHandlers.default_form(pkmn)
	pkmn.experience = pkmn.growth_rate_data().minimum_exp_for_level(at_level)
	pkmn.happiness = record.base_happiness
	pkmn.obtain_level = at_level
	pkmn.steps_to_hatch = 0
	pkmn.time_received = int(Time.get_unix_time_from_system())
	pkmn.randomise_ivs()
	pkmn.reset_moves()
	pkmn.calculate_stats()
	pkmn.heal()
	if RNG.chance(1, maxi(GameSettings.data.pokerus_chance, 1)):
		pkmn.give_pokerus()
	return pkmn

## Creates an egg that will hatch into [param species_id].
static func create_egg(species_id: StringName, new_owner: PokemonOwner = null) -> Pokemon:
	var pkmn: Pokemon = Pokemon.create(species_id, GameSettings.data.egg_level, new_owner)
	var record: SpeciesData = pkmn.species_data()
	pkmn.steps_to_hatch = record.hatch_steps if record != null else 1
	pkmn.obtain_method = ObtainMethod.EGG
	pkmn.happiness = HATCHED_HAPPINESS
	return pkmn

## Hatches a Pokemon.
## The player becomes its trainer, it starts at the hatched friendship, and it gets its inherited moves.
func hatch() -> void:
	if not is_egg():
		return
	steps_to_hatch = 0
	nickname = ""
	if GameState.player != null:
		owner = GameState.player.owner_record()
	happiness = HATCHED_HAPPINESS
	obtain_method = ObtainMethod.EGG
	hatched_map = GameState.map_id
	time_egg_hatched = int(Time.get_unix_time_from_system())
	record_first_moves()
	calculate_stats()
	heal()


# === Data Access ===

func species_data() -> SpeciesData:
	return Database.species_form(species, active_form())

## The form actually in use, acounting for [member forced_form].
func active_form() -> int:
	return forced_form if forced_form >= 0 else form

func growth_rate_data() -> GrowthRateData:
	var record: SpeciesData = species_data()
	if record == null:
		return Database.growth_rate(&"Medium")
	return Database.growth_rate(record.growth_rate)


func types() -> Array[StringName]:
	var record: SpeciesData = species_data()
	if record == null:
		return [&"NORMAL"]
	return record.types.duplicate()


func has_type(type_id: StringName) -> bool:
	return types().has(type_id)


## The type this Pokemon would Terastallize into. 
## Left unset it is the first of its own types.
func tera_type() -> StringName:
	if not tera_type_override.is_empty():
		return tera_type_override
	var own: Array[StringName] = types()
	return own[0] if not own.is_empty() else &""


# === Derived ID === 

func level() -> int:
	return growth_rate_data().level_from_exp(experience)


func exp_to_next_level() -> int:
	return growth_rate_data().exp_to_next_level(experience)


func level_progress() -> float:
	return growth_rate_data().level_progress(experience)


func is_max_level() -> bool:
	return level() >= GameSettings.data.maximum_level


func gender() -> int:
	if gender_override >= 0:
		return gender_override
	if _cached_gender >= 0:
		return _cached_gender
	var record: SpeciesData = species_data()
	if record == null:
		_cached_gender = Gender.GENDERLESS
		return _cached_gender
	var ratio: GenderRatioData = Database.gender_ratio(record.gender_ratio)
	if ratio == null:
		_cached_gender = Gender.GENDERLESS
	elif ratio.always_male:
		_cached_gender = Gender.MALE
	elif ratio.always_female:
		_cached_gender = Gender.FEMALE
	elif ratio.genderless:
		_cached_gender = Gender.GENDERLESS
	else:
		_cached_gender = Gender.FEMALE if (personal_id & 0xFF) < ratio.female_chance else Gender.MALE
	return _cached_gender


func is_male() -> bool:
	return gender() == Gender.MALE


func is_female() -> bool:
	return gender() == Gender.FEMALE


func is_genderless() -> bool:
	return gender() == Gender.GENDERLESS


func nature() -> StringName:
	if not nature_override.is_empty():
		return nature_override
	if not _cached_nature.is_empty():
		return _cached_nature
	var ids: Array[StringName] = Database.get_ids(Database.CATEGORY_NATURES)
	if ids.is_empty():
		return &"HARDY"
	_cached_nature = ids[personal_id % ids.size()]
	return _cached_nature


## The nature used when calculating stats.
## which a Mint can change without affecting the nature displayed for the summary screen.
func nature_for_stats() -> StringName:
	if not nature_for_stats_override.is_empty():
		return nature_for_stats_override
	return nature()


func ability_id() -> StringName:
	if not ability_override.is_empty():
		return ability_override
	if not _cached_ability.is_empty():
		return _cached_ability
	var record: SpeciesData = species_data()
	if record == null:
		return &""
	var slot: int = ability_index
	if slot >= 2:
		var hidden_index: int = slot - 2
		if hidden_index < record.hidden_abilities.size():
			_cached_ability = record.hidden_abilities[hidden_index]
			return _cached_ability
		slot = personal_id & 1
	if slot < record.abilities.size():
		_cached_ability = record.abilities[slot]
	elif not record.abilities.is_empty():
		_cached_ability = record.abilities[0]
	return _cached_ability


func has_hidden_ability() -> bool:
	return ability_index >= 2


func is_shiny() -> bool:
	if shiny_override >= 0:
		return shiny_override == 1
	if _cached_shiny >= 0:
		return _cached_shiny == 1
	_cached_shiny = 1 if _shiny_value() < _shiny_threshold() else 0
	return _cached_shiny == 1


## The rarer "square" shiny sparkle, when enabled.
func is_super_shiny() -> bool:
	if not GameSettings.data.super_shiny_enabled:
		return false
	if super_shiny_override >= 0:
		return super_shiny_override == 1
	if _cached_super_shiny >= 0:
		return _cached_super_shiny == 1
	_cached_super_shiny = 1 if _shiny_value() == 0 else 0
	return _cached_super_shiny == 1


func _shiny_value() -> int:
	var owner_id: int = owner.id if owner != null else 0
	var combined: int = personal_id ^ owner_id
	return (combined & 0xFFFF) ^ ((combined >> 16) & 0xFFFF)


func _shiny_threshold() -> int:
	var denominator: int = maxi(GameSettings.data.shiny_chance_denominator, 1)
	return maxi(65536 / denominator, 1)


func set_shiny(value: bool) -> void:
	shiny_override = 1 if value else 0
	_cached_shiny = -1


func display_name() -> String:
	if not nickname.is_empty():
		return nickname
	if is_egg():
		return "Egg"
	var record: SpeciesData = species_data()
	return record.display_name if record != null else String(species)


func is_egg() -> bool:
	return steps_to_hatch > 0


func is_fainted() -> bool:
	return hp <= 0 and not is_egg()


func is_able() -> bool:
	return not is_egg() and hp > 0


func has_status(status_id: StringName = &"") -> bool:
	if status_id.is_empty():
		return status != &"NONE"
	return status == status_id


func is_owned_by(other: PokemonOwner) -> bool:
	return owner != null and owner.matches(other)


func is_foreign(other: PokemonOwner) -> bool:
	return not is_owned_by(other)


# === Stats ===

## Individual value for [param stat] (accounting for Hyper Training).
func get_iv(stat: StringName) -> int:
	var index: int = STAT_IDS.find(stat)
	if index < 0:
		return 0
	if ivs_hyper_trained[index]:
		return GameSettings.data.maximum_iv
	return ivs[index]


## The raw individual value, ignoring Hyper Training.
## Breeding and Hidden Power use this over the actual IVs.
func get_raw_iv(stat: StringName) -> int:
	var index: int = STAT_IDS.find(stat)
	return ivs[index] if index >= 0 else 0


func set_iv(stat: StringName, value: int) -> void:
	var index: int = STAT_IDS.find(stat)
	if index >= 0:
		ivs[index] = clampi(value, 0, GameSettings.data.maximum_iv)


func get_ev(stat: StringName) -> int:
	var index: int = STAT_IDS.find(stat)
	return evs[index] if index >= 0 else 0


func set_ev(stat: StringName, value: int) -> void:
	var index: int = STAT_IDS.find(stat)
	if index >= 0:
		evs[index] = clampi(value, 0, GameSettings.data.maximum_stat_evs)


func total_evs() -> int:
	var total: int = 0
	for value: int in evs:
		total += value
	return total


## Adds effort values while respecting both the per-stat and total caps. 
## Returns the amount actually gained.
func gain_ev(stat: StringName, amount: int) -> int:
	var index: int = STAT_IDS.find(stat)
	if index < 0 or amount == 0:
		return 0
	var settings: GameSettingsData = GameSettings.data
	var room_in_stat: int = settings.maximum_stat_evs - evs[index]
	var room_in_total: int = settings.maximum_total_evs - total_evs()
	var gained: int = mini(amount, mini(room_in_stat, room_in_total))
	gained = maxi(gained, -evs[index])
	evs[index] += gained
	return gained


func randomise_ivs() -> void:
	var maximum: int = GameSettings.data.maximum_iv
	for i: int in range(STAT_IDS.size()):
		ivs[i] = RNG.range_int(0, maximum)


## Recomputes the six stats from base stats, level, IVs, EVs and nature. 
## Keeps current HP proportional by shifting it with the change in maximum HP.
func calculate_stats() -> void:
	var record: SpeciesData = species_data()
	if record == null:
		return
	var current_level: int = level()
	var nature_record: NatureData = Database.nature(nature_for_stats())

	var new_total_hp: int = _calculate_hp(
		record.base_hp, current_level, get_iv(&"HP"), get_ev(&"HP")
	)
	var hp_difference: int = new_total_hp - total_hp
	total_hp = new_total_hp
	if hp > 0 or hp_difference > 0:
		hp = maxi(hp + hp_difference, 1)

	attack = _calculate_stat(record.base_attack, current_level, &"ATTACK", nature_record)
	defense = _calculate_stat(record.base_defense, current_level, &"DEFENSE", nature_record)
	special_attack = _calculate_stat(record.base_special_attack, current_level, &"SPECIAL_ATTACK", nature_record)
	special_defense = _calculate_stat(record.base_special_defense, current_level, &"SPECIAL_DEFENSE", nature_record)
	speed = _calculate_stat(record.base_speed, current_level, &"SPEED", nature_record)


func _calculate_hp(base: int, at_level: int, iv: int, ev: int) -> int:
	if base == 1:
		return 1
	return floori(float((base * 2) + iv + (ev / 4)) * at_level / 100.0) + at_level + 10


func _calculate_stat(base: int, at_level: int, stat: StringName, nature_record: NatureData) -> int:
	var iv: int = get_iv(stat)
	var ev: int = get_ev(stat)
	var raw: int = floori(float((base * 2) + iv + (ev / 4)) * at_level / 100.0) + 5
	var multiplier: float = nature_record.get_stat_multiplier(stat) if nature_record != null else 1.0
	return floori(float(raw) * multiplier)


func get_stat(stat: StringName) -> int:
	match stat:
		&"HP": return total_hp
		&"ATTACK": return attack
		&"DEFENSE": return defense
		&"SPECIAL_ATTACK": return special_attack
		&"SPECIAL_DEFENSE": return special_defense
		&"SPEED": return speed
	return 0


func hp_fraction() -> float:
	return float(hp) / float(maxi(total_hp, 1))


# === Healing ===

## Restores HP, PP and status.
func heal() -> void:
	if is_egg():
		return
	calculate_stats()
	hp = total_hp
	status = &"NONE"
	status_count = 0
	heal_all_pp()
	ready_to_evolve = false


func heal_hp() -> void:
	if is_egg():
		return
	hp = total_hp


func heal_status() -> void:
	status = &"NONE"
	status_count = 0


func heal_all_pp() -> void:
	for move: PokemonMove in moves:
		move.restore_pp()


## Applies damage and returns the amount actually dealt.
func take_damage(amount: int) -> int:
	var before: int = hp
	hp = maxi(0, hp - maxi(amount, 0))
	# TODO apply the game setting for blocking / unblocking evolution on faint.
	if hp <= 0:
		ready_to_evolve = false
	return before - hp


## Restores HP and returns the amount actually restored.
func restore_hp(amount: int) -> int:
	var before: int = hp
	hp = mini(total_hp, hp + maxi(amount, 0))
	return hp - before


# === Moves ===

func move_count() -> int:
	return moves.size()


func knows_move(move_id: StringName) -> bool:
	for move: PokemonMove in moves:
		if move.id == move_id:
			return true
	return false


func get_move(move_id: StringName) -> PokemonMove:
	for move: PokemonMove in moves:
		if move.id == move_id:
			return move
	return null


## Teaches a move. 
## Returns `false` when the move is already known or the move list is full
func learn_move(move_id: StringName) -> bool:
	if move_id.is_empty() or knows_move(move_id):
		return false
	if moves.size() >= GameSettings.data.max_moves:
		return false
	moves.append(PokemonMove.create(move_id))
	return true


## Teaches a move, pushing out the oldest one when the list is full.
func learn_move_forced(move_id: StringName) -> void:
	if knows_move(move_id):
		return
	if moves.size() >= GameSettings.data.max_moves:
		moves.pop_front()
	moves.append(PokemonMove.create(move_id))


func forget_move(move_id: StringName) -> bool:
	for i: int in range(moves.size()):
		if moves[i].id == move_id:
			moves.remove_at(i)
			return true
	return false


func forget_move_at(index: int) -> bool:
	if index < 0 or index >= moves.size():
		return false
	moves.remove_at(index)
	return true


## Exchanges the moves at [param first] and [param second].
func swap_moves(first: int, second: int) -> bool:
	if first == second:
		return false
	if first < 0 or first >= moves.size() or second < 0 or second >= moves.size():
		return false
	var held: PokemonMove = moves[first]
	moves[first] = moves[second]
	moves[second] = held
	return true


## Replaces the move at [param index], keeping the list order stable.
func replace_move_at(index: int, move_id: StringName) -> void:
	if index < 0 or index >= moves.size():
		learn_move_forced(move_id)
		return
	moves[index] = PokemonMove.create(move_id)


## Fills the move list with the last four moves this Pokemon would know at its current level.
func reset_moves() -> void:
	var record: SpeciesData = species_data()
	if record == null:
		return
	var current_level: int = level()
	var learnable: Array[StringName] = []
	for entry: LevelUpMove in record.level_up_moves:
		if entry.level <= current_level and not learnable.has(entry.move):
			learnable.append(entry.move)
	var limit: int = GameSettings.data.max_moves
	if learnable.size() > limit:
		learnable = learnable.slice(learnable.size() - limit)
	moves.clear()
	for move_id: StringName in learnable:
		moves.append(PokemonMove.create(move_id))
	first_moves = learnable.duplicate()


## Records the moves this Pokemon knows now as the ones it was born knowing
func record_first_moves() -> void:
	first_moves.clear()
	for move: PokemonMove in moves:
		if not first_moves.has(move.id):
			first_moves.append(move.id)


## Move ids this Pokemon learns at [param at_level].
func moves_learned_at_level(at_level: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var record: SpeciesData = species_data()
	if record == null:
		return result
	for entry: LevelUpMove in record.level_up_moves:
		if entry.level == at_level and not knows_move(entry.move):
			result.append(entry.move)
	return result


## `true` when this species can learn [param move_id] by TM, HM, TR or tutor.
func can_learn_machine_move(move_id: StringName) -> bool:
	var record: SpeciesData = species_data()
	return record != null and record.tutor_moves.has(move_id)


## Moves the relearner can teach: level-up moves at or below the current level
## as well as the moves it was born knowing.
func relearnable_moves() -> Array[StringName]:
	var result: Array[StringName] = []
	var record: SpeciesData = species_data()
	if record == null:
		return result
	var current_level: int = level()
	for entry: LevelUpMove in record.level_up_moves:
		if entry.level <= current_level and not knows_move(entry.move) and not result.has(entry.move):
			result.append(entry.move)
	for move_id: StringName in first_moves:
		if not knows_move(move_id) and not result.has(move_id):
			result.append(move_id)
	return result


# === Experience ===

## Grants experience and returns the levels gained. 
## Does not itself handle level-up move learning or evolution; 
## [BattleExperience] and the field level-up drive those so they can display messages.
func gain_exp(amount: int) -> int:
	if is_egg() or amount <= 0:
		return 0
	var before: int = level()
	var maximum: int = GameSettings.data.maximum_level
	var cap: int = growth_rate_data().minimum_exp_for_level(maximum)
	experience = mini(experience + amount, cap)
	var after: int = level()
	if after != before:
		calculate_stats()
	return after - before


## Sets the level directly, adjusting experience to the level's needed value.
func set_level(new_level: int) -> void:
	var clamped: int = clampi(new_level, 1, GameSettings.data.maximum_level)
	experience = growth_rate_data().minimum_exp_for_level(clamped)
	calculate_stats()


# === Happiness ===

## Adjusts happiness with the games' diminishing-returns bands.
func change_happiness(reason: StringName) -> void:
	if ShadowPokemon.ignores_happiness(self):
		return
	var current: int = happiness
	var gain: int = 0
	match reason:
		&"walking": gain = 1 if current < 200 else 0
		&"levelup": gain = 3 if current < 100 else (2 if current < 200 else 1)
		&"groom": gain = 10 if current < 200 else 4
		&"evberry": gain = 10 if current < 100 else (5 if current < 200 else 2)
		&"vitamin": gain = 5 if current < 100 else (3 if current < 200 else 2)
		&"wing": gain = 3 if current < 100 else (2 if current < 200 else 1)
		&"machine", &"battle", &"battleitem": gain = 1
		&"luxuryball", &"lucky_egg": gain = 1
		&"faint": gain = -1
		&"faintbad": gain = -5 if current < 200 else -10
		&"powder": gain = -10 if current < 200 else -15
		&"energyroot": gain = -10 if current < 200 else -15
		&"revivalherb": gain = -15 if current < 200 else -20
		_:
			push_warning("Pokemon.change_happiness: unknown reason '%s'." % reason)
			return
	if gain > 0:
		if poke_ball == &"LUXURYBALL":
			gain += 1
		if held_item == &"SOOTHEBELL":
			gain = int(gain * 1.5)
		if obtain_map == GameState.map_id and obtain_map != 0:
			gain += 1
	happiness = clampi(current + gain, 0, 255)


# === Pokerus ===

## Infects this Pokemon with [param strain], or with a random one.
##
## A cured Pokemon is immune and is left alone; 
## An infected Pokemon has its counter reset.
func give_pokerus(strain: int = 0) -> void:
	if is_pokerus_cured():
		return
	var chosen: int = strain if strain >= 1 and strain <= 15 else RNG.range_int(1, 16)
	var days: int = (chosen % 4) + 1
	pokerus = (chosen << 4) | days
	if GameState != null and GameState.stats != null:
		GameState.stats.pokerus_infections += 1


func pokerus_strain() -> int:
	return pokerus >> 4


func pokerus_days_left() -> int:
	return pokerus & 0x0F


func has_pokerus() -> bool:
	return pokerus_days_left() > 0


func is_pokerus_cured() -> bool:
	return pokerus > 0 and pokerus_days_left() == 0


## Takes one day off the counter, curing this Pokemon of PokeRus when it depleats fully.
func tick_pokerus() -> void:
	if has_pokerus():
		pokerus -= 1


# === Ribbons ===

func has_ribbon(ribbon_id: StringName) -> bool:
	return ribbons.has(ribbon_id)


func give_ribbon(ribbon_id: StringName) -> bool:
	if ribbons.has(ribbon_id):
		return false
	ribbons.append(ribbon_id)
	return true


func take_ribbon(ribbon_id: StringName) -> bool:
	var index: int = ribbons.find(ribbon_id)
	if index < 0:
		return false
	ribbons.remove_at(index)
	return true


# === Hidden Power ===

## Hidden Power's type and power, from the raw individual values.
func hidden_power() -> Dictionary:
	var type_bits: int = 0
	var power_bits: int = 0
	var order: Array[StringName] = [
		&"HP", &"ATTACK", &"DEFENSE", &"SPEED", &"SPECIAL_ATTACK", &"SPECIAL_DEFENSE"
	]
	for i: int in range(order.size()):
		var iv: int = get_raw_iv(order[i])
		type_bits |= (iv & 1) << i
		power_bits |= ((iv >> 1) & 1) << i
	var candidates: Array[StringName] = []
	for type_id: StringName in Database.get_ids(Database.CATEGORY_TYPES):
		var record: TypeData = Database.type(type_id)
		if record != null and not record.pseudo_type and type_id != &"NORMAL":
			candidates.append(type_id)
	var chosen: StringName = &"NORMAL"
	if not candidates.is_empty():
		chosen = candidates[(type_bits * (candidates.size() - 1)) / 63]
	return {
		"type": chosen,
		"power": 30 + ((power_bits * 40) / 63),
	}


# === Evolution ===

## The species this Pokemon would evolve into for [param trigger]
## Or an empty `StringName` when none are found / apply
func check_evolution(trigger: StringName, parameter: Variant = null) -> StringName:
	return EvolutionMethods.check_evolution(self, trigger, parameter)


## Applies an evolution in place, keeping HP proportional and refreshing stats.
## Returns Shedinja at evolution, otherwise returns `null` (Returns a pokemon left behind by the evolution)
func evolve_into(new_species: StringName) -> Pokemon:
	var hp_before: int = hp
	var max_before: int = total_hp
	var was_fainted: bool = is_fainted()
	var extra: Pokemon = EvolutionMethods.run_after_evolution(self, new_species)
	species = new_species
	form = FormHandlers.default_form(self)
	ready_to_evolve = false
	calculate_stats()
	if was_fainted:
		hp = 0
	elif max_before > 0:
		hp = clampi(roundi(float(hp_before) * float(total_hp) / float(max_before)), 1, total_hp)
	return extra


## Move ids this Pokemon learns the moment it becomes its current species
func moves_learned_on_evolution() -> Array[StringName]:
	var result: Array[StringName] = []
	var record: SpeciesData = species_data()
	if record == null:
		return result
	var current_level: int = level()
	for entry: LevelUpMove in record.level_up_moves:
		if entry.level != 0 and entry.level != current_level:
			continue
		if knows_move(entry.move) or result.has(entry.move):
			continue
		result.append(entry.move)
	return result


# === Sprites ===

func front_sprite() -> Texture2D:
	return Assets.pokemon_sprite(species, active_form(), is_shiny(), false, is_female(), is_egg())


func back_sprite() -> Texture2D:
	return Assets.pokemon_sprite(species, active_form(), is_shiny(), true, is_female(), is_egg())


func icon() -> Texture2D:
	return Assets.pokemon_icon(species, active_form(), is_shiny(), is_female(), is_egg())


func play_cry(pitch: float = 1.0, volume: float = 1.0) -> void:
	if is_egg():
		return
	AudioManager.play_cry(species, active_form(), pitch, volume)


# === Duplication ===

## A deep copy, safe to hand to a battle or to storage without aliasing.
func clone() -> Pokemon:
	var copy: Pokemon = Pokemon.new()
	copy.copy_from_dict(to_dict())
	return copy


func _invalidate_derived() -> void:
	_cached_gender = -1
	_cached_nature = &""
	_cached_ability = &""
	_cached_shiny = -1
	_cached_super_shiny = -1


# === Serialisation ===

## Converts to a plain dictionary for the save file. 
## Explicit serialisation keeps saves readable and lets [SaveManager] migrate old fields.
func to_dict() -> Dictionary:
	var move_list: Array = []
	for move: PokemonMove in moves:
		move_list.append(move.to_dict())
	var first_move_list: Array = []
	for move_id: StringName in first_moves:
		first_move_list.append(String(move_id))
	var ribbon_list: Array = []
	for ribbon_id: StringName in ribbons:
		ribbon_list.append(String(ribbon_id))
	var shadow_move_list: Array = []
	for move_id: StringName in shadow_moves:
		shadow_move_list.append(String(move_id))
	return {
		"species": String(species),
		"personal_id": personal_id,
		"form": form,
		"forced_form": forced_form,
		"time_form_set": time_form_set,
		"tera_type": String(tera_type_override),
		"nickname": nickname,
		"exp": experience,
		"hp": hp,
		"total_hp": total_hp,
		"status": String(status),
		"status_count": status_count,
		"attack": attack,
		"defense": defense,
		"special_attack": special_attack,
		"special_defense": special_defense,
		"speed": speed,
		"ivs": Array(ivs),
		"ivs_hyper_trained": ivs_hyper_trained.duplicate(),
		"evs": Array(evs),
		"nature_override": String(nature_override),
		"nature_for_stats_override": String(nature_for_stats_override),
		"ability_override": String(ability_override),
		"ability_index": ability_index,
		"gender_override": gender_override,
		"shiny_override": shiny_override,
		"super_shiny_override": super_shiny_override,
		"held_item": String(held_item),
		"happiness": happiness,
		"pokerus": pokerus,
		"poke_ball": String(poke_ball),
		"moves": move_list,
		"first_moves": first_move_list,
		"steps_to_hatch": steps_to_hatch,
		"hatched_map": hatched_map,
		"owner": owner.to_dict() if owner != null else {},
		"obtain_method": int(obtain_method),
		"obtain_map": obtain_map,
		"obtain_text": obtain_text,
		"obtain_level": obtain_level,
		"time_received": time_received,
		"time_egg_hatched": time_egg_hatched,
		"ribbons": ribbon_list,
		"markings": markings,
		"contest": [cool, beauty, cute, smart, tough, sheen],
		"cannot_store": cannot_store,
		"cannot_release": cannot_release,
		"cannot_trade": cannot_trade,
		"ready_to_evolve": ready_to_evolve,
		"shadow": shadow,
		"heart_gauge": heart_gauge,
		"heart_gauge_steps": heart_gauge_steps,
		"hyper_mode": hyper_mode,
		"shadow_moves": shadow_move_list,
		"shadow_saved_exp": shadow_saved_exp,
		"shadow_saved_evs": Array(shadow_saved_evs),
		"mail": mail.to_dict() if mail != null else {},
		"fused": fused.to_dict() if fused != null else {},
	}


static func from_dict(source: Dictionary) -> Pokemon:
	var pkmn: Pokemon = Pokemon.new()
	pkmn.copy_from_dict(source)
	return pkmn


func copy_from_dict(source: Dictionary) -> void:
	species = DictRead.read_string_name(source, "species")
	personal_id = DictRead.read_int(source, "personal_id", 0)
	form = DictRead.read_int(source, "form", 0)
	forced_form = DictRead.read_int(source, "forced_form", -1)
	time_form_set = DictRead.read_int(source, "time_form_set", 0)
	tera_type_override = DictRead.read_string_name(source, "tera_type")
	nickname = DictRead.read_string(source, "nickname")
	experience = DictRead.read_int(source, "exp", 0)
	total_hp = DictRead.read_int(source, "total_hp", 1)
	hp = DictRead.read_int(source, "hp", 1)
	status = DictRead.read_string_name(source, "status", &"NONE")
	status_count = DictRead.read_int(source, "status_count", 0)
	attack = DictRead.read_int(source, "attack", 1)
	defense = DictRead.read_int(source, "defense", 1)
	special_attack = DictRead.read_int(source, "special_attack", 1)
	special_defense = DictRead.read_int(source, "special_defense", 1)
	speed = DictRead.read_int(source, "speed", 1)
	ivs = DictRead.read_int_array(source, "ivs", PackedInt32Array([0, 0, 0, 0, 0, 0]))
	evs = DictRead.read_int_array(source, "evs", PackedInt32Array([0, 0, 0, 0, 0, 0]))
	ivs_hyper_trained.clear()
	var hyper_trained: Array = DictRead.read_array(
		source, "ivs_hyper_trained", [false, false, false, false, false, false]
	)
	for value: Variant in hyper_trained:
		ivs_hyper_trained.append(DictRead.as_bool(value))
	nature_override = DictRead.read_string_name(source, "nature_override")
	nature_for_stats_override = DictRead.read_string_name(source, "nature_for_stats_override")
	ability_override = DictRead.read_string_name(source, "ability_override")
	ability_index = DictRead.read_int(source, "ability_index", 0)
	gender_override = DictRead.read_int(source, "gender_override", -1)
	shiny_override = DictRead.read_int(source, "shiny_override", -1)
	super_shiny_override = DictRead.read_int(source, "super_shiny_override", -1)
	held_item = DictRead.read_string_name(source, "held_item")
	happiness = DictRead.read_int(source, "happiness", 70)
	pokerus = DictRead.read_int(source, "pokerus", 0)
	poke_ball = DictRead.read_string_name(source, "poke_ball", &"POKEBALL")
	moves.clear()
	for entry: Variant in DictRead.read_array(source, "moves"):
		moves.append(PokemonMove.from_dict(DictRead.as_dict(entry)))
	first_moves.clear()
	for entry: Variant in DictRead.read_array(source, "first_moves"):
		first_moves.append(DictRead.as_string_name(entry))
	steps_to_hatch = DictRead.read_int(source, "steps_to_hatch", 0)
	hatched_map = DictRead.read_int(source, "hatched_map", 0)
	var owner_dict: Dictionary = DictRead.read_dict(source, "owner")
	owner = PokemonOwner.from_dict(owner_dict) if not owner_dict.is_empty() else PokemonOwner.create_unowned()
	obtain_method = DictRead.read_int(source, "obtain_method", 0) as ObtainMethod
	obtain_map = DictRead.read_int(source, "obtain_map", 0)
	obtain_text = DictRead.read_string(source, "obtain_text")
	obtain_level = DictRead.read_int(source, "obtain_level", 1)
	time_received = DictRead.read_int(source, "time_received", 0)
	time_egg_hatched = DictRead.read_int(source, "time_egg_hatched", 0)
	ribbons.clear()
	for entry: Variant in DictRead.read_array(source, "ribbons"):
		ribbons.append(DictRead.as_string_name(entry))
	markings = DictRead.read_int(source, "markings", 0)
	var contest: Array = DictRead.read_array(source, "contest", [0, 0, 0, 0, 0, 0])
	contest.resize(6)
	cool = DictRead.as_int(contest[0])
	beauty = DictRead.as_int(contest[1])
	cute = DictRead.as_int(contest[2])
	smart = DictRead.as_int(contest[3])
	tough = DictRead.as_int(contest[4])
	sheen = DictRead.as_int(contest[5])
	cannot_store = DictRead.read_bool(source, "cannot_store", false)
	cannot_release = DictRead.read_bool(source, "cannot_release", false)
	cannot_trade = DictRead.read_bool(source, "cannot_trade", false)
	ready_to_evolve = DictRead.read_bool(source, "ready_to_evolve", false)
	shadow = DictRead.read_bool(source, "shadow", false)
	heart_gauge = DictRead.read_int(source, "heart_gauge", 0)
	heart_gauge_steps = DictRead.read_int(source, "heart_gauge_steps", 0)
	hyper_mode = DictRead.read_bool(source, "hyper_mode", false)
	shadow_moves.clear()
	for entry: Variant in DictRead.read_array(source, "shadow_moves"):
		shadow_moves.append(DictRead.as_string_name(entry))
	shadow_saved_exp = DictRead.read_int(source, "shadow_saved_exp", 0)
	shadow_saved_evs = DictRead.read_int_array(source, "shadow_saved_evs", PackedInt32Array())
	var mail_dict: Dictionary = DictRead.read_dict(source, "mail")
	mail = PokemonMail.from_dict(mail_dict) if not mail_dict.is_empty() else null
	var fused_dict: Dictionary = DictRead.read_dict(source, "fused")
	fused = Pokemon.from_dict(fused_dict) if not fused_dict.is_empty() else null
	_invalidate_derived()
