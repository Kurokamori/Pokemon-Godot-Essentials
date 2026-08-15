class_name EvolutionMethods
## Implements every Pokemon evolution condition
## 
## To add a method:
## Register an [EvolutionMethodData] resource
## then add a `match` arm in [method _condition_met] for the condition itself.
## Possibly add them to a corresponding constant if items/duplication

const TRIGGER_LEVEL_UP: StringName = &"level_up"
const TRIGGER_USE_ITEM: StringName = &"use_item"
const TRIGGER_TRADE: StringName = &"trade"
const TRIGGER_AFTER_BATTLE: StringName = &"after_battle"
const TRIGGER_EVENT: StringName = &"event"

## Happinness Threshold for a Pokemon to evolve from happiness/friendship
## With and without the soft cap for affection-honoring generations
const HAPPINESS_THRESHOLD: int = 220
const HAPPINESS_THRESHOLD_SOFT_CAP: int = 160

## The amount of damage needed for `EventAfterDamageTaken` (which is used by Galarian Yamask)
const DAMAGE_TAKEN_THRESHOLD: int = 49

## Battle Bond ability constant as evolution stands in for form change
const BATTLE_BOND: StringName = &"BATTLEBOND"

## Everstone item pointer
const EVERSTONE: StringName = &"EVERSTONE"

## Ball used for bonus Pokemon recieved on evolution (Ninjask/Shedinja)
const DUPLICATE_BALL: StringName = &"POKEBALL"

## The weather types accepted by each type of weather evolution
const CLEAR_WEATHER: Array[StringName] = [&"None"]
const SUNNY_WEATHER: Array[StringName] = [&"Sun"]
const RAINY_WEATHER: Array[StringName] = [&"Rain", &"Storm", &"HeavyRain", &"Fog"]
const SNOWY_WEATHER: Array[StringName] = [&"Snow", &"Blizzard"]
const SANDY_WEATHER: Array[StringName] = [&"Sandstorm"]

## What methods a given trigger fires, figured from [EvolutionMethodData] the first time a trigger is querried.
static var _methods_by_trigger: Dictionary = {}

## Methods which consume a held item on evolution
const ITEM_CONSUMED_METHODS: Array[StringName] = [
	&"HappinessHoldItem", &"HoldItem", &"HoldItemMale", &"HoldItemFemale",
	&"DayHoldItem", &"NightHoldItem", &"HoldItemHappiness", &"TradeItem",
]

## Methods which duplicate a pokemon on evolution
const DUPLICATING_METHODS: Array[StringName] = [&"Shedinja"]


## Returns the species name of the Pokemon [param pkmn] evolves to using [param trigger]
## Returns an empty `StringName` if none.
## [param parameter] contains the trigger specific context such as the item_id of `use_item`
static func check_evolution(pkmn: Pokemon, trigger: StringName, parameter: Variant = null) -> StringName:
	if not can_evolve(pkmn):
		return &""
	var record: SpeciesData = pkmn.species_data()
	if record == null:
		return &""
	var allowed: Array[StringName] = methods_for_trigger(trigger)
	for evo: SpeciesEvolution in record.get_evolutions():
		if not allowed.has(evo.method):
			continue
		if _condition_met(pkmn, evo, trigger, parameter):
			return evo.species
	return &""
	
## Returns `true` if [param pkmn] could at all evolve
## (Not an egg, not a Shadow Pokemon, not holding an Everstone, doesn't have an ability that prevents it)
static func can_evolve(pkmn: Pokemon) -> bool:
	if pkmn == null or pkmn.is_egg() or pkmn.shadow:
		return false
	if pkmn.held_item == EVERSTONE:
		return false
	return pkmn.ability_id() != BATTLE_BOND
	
## Which methods [param trigger] may call, as stated by their records
## Built and kept, for easier future lookup
static func methods_for_trigger(trigger: StringName) -> Array[StringName]:
	if _methods_by_trigger.has(trigger):
		return _methods_by_trigger[trigger]
	var methods: Array[StringName] = []
	for method_id: StringName in Database.get_ids(Database.CATEGORY_EVOLUTION_METHODS):
		var record: EvolutionMethodData = Database.evolution_method(method_id)
		if record != null and record.fires_on(trigger):
			methods.append(method_id)
	_methods_by_trigger[trigger] = methods
	return methods
	
## Checks if a condition is met
static func _condition_met(pkmn: Pokemon, evo: SpeciesEvolution, trigger: StringName, parameter: Variant) -> bool:
	var level: int = pkmn.level()
	var value: int = evo.parameter_as_int()
	var id_value: StringName = evo.parameter_as_id()
	var friendly: int = happiness_threshold()
	
	# === CONDITION MATCH ARM ===
	match evo.method:
		# === Plain Level Thresholds ===
		&"Level":
			return level >= value
		&"LevelMale":
			return level >= value and pkmn.is_male()
		&"LevelFemale":
			return level >= value and pkmn.is_female()
		&"LevelDay":
			return level >= value and TimeOfDay.is_day()
		&"LevelNight":
			return level >= value and TimeOfDay.is_night()
		&"LevelMorning":
			return level >= value and TimeOfDay.is_morning()
		&"LevelAfternoon":
			return level >= value and TimeOfDay.is_afternoon()
		&"LevelEvening":
			return level >= value and TimeOfDay.is_evening()
		&"LevelNoWeather":
			return level >= value and _weather_is_any(CLEAR_WEATHER)
		&"LevelSun":
			return level >= value and _weather_is_any(SUNNY_WEATHER)
		&"LevelRain":
			return level >= value and _weather_is_any(RAINY_WEATHER)
		&"LevelSnow":
			return level >= value and _weather_is_any(SNOWY_WEATHER)
		&"LevelSandstorm":
			return level >= value and _weather_is_any(SANDY_WEATHER)
		&"LevelCycling":
			return level >= value and GameState.is_cycling()
		&"LevelSurfing":
			return level >= value and GameState.is_surfing()
		&"LevelDiving":
			return level >= value and GameState.is_diving()
		&"LevelDarkness":
			return level >= value and GameState.is_on_dark_map()
		&"LevelDarkInParty":
			return level >= value and _party_has_type(&"DARK", pkmn)

		# === Stats === 
		&"AttackGreater":
			return level >= value and pkmn.attack > pkmn.defense
		&"AtkDefEqual":
			return level >= value and pkmn.attack == pkmn.defense
		&"DefenseGreater":
			return level >= value and pkmn.defense > pkmn.attack

		# === Special Bugs (Wurmple and Nincada === 
		&"Silcoon":
			return level >= value and ((pkmn.personal_id >> 16) & 0xFFFF) % 10 < 5
		&"Cascoon":
			return level >= value and ((pkmn.personal_id >> 16) & 0xFFFF) % 10 >= 5
		&"Ninjask":
			return level >= value

		# === Happiness === 
		&"Happiness":
			return pkmn.happiness >= friendly
		&"HappinessMale":
			return pkmn.happiness >= friendly and pkmn.is_male()
		&"HappinessFemale":
			return pkmn.happiness >= friendly and pkmn.is_female()
		&"HappinessDay":
			return pkmn.happiness >= friendly and TimeOfDay.is_day()
		&"HappinessNight":
			return pkmn.happiness >= friendly and TimeOfDay.is_night()
		&"HappinessMove":
			return pkmn.happiness >= friendly and pkmn.knows_move(id_value)
		&"HappinessMoveType":
			return pkmn.happiness >= friendly and _knows_move_of_type(pkmn, id_value)
		&"HappinessHoldItem":
			return pkmn.happiness >= friendly and pkmn.held_item == id_value
		&"MaxHappiness":
			return pkmn.happiness == 255
		&"Beauty":
			return pkmn.beauty >= value

		# === Held Items ===
		&"HoldItem":
			return pkmn.held_item == id_value
		&"HoldItemMale":
			return pkmn.held_item == id_value and pkmn.is_male()
		&"HoldItemFemale":
			return pkmn.held_item == id_value and pkmn.is_female()
		&"DayHoldItem":
			return pkmn.held_item == id_value and TimeOfDay.is_day()
		&"NightHoldItem":
			return pkmn.held_item == id_value and TimeOfDay.is_night()
		&"HoldItemHappiness":
			return pkmn.held_item == id_value and pkmn.happiness >= friendly

		# === Moves and Pary ===
		&"HasMove":
			return pkmn.knows_move(id_value)
		&"HasMoveType":
			return _knows_move_of_type(pkmn, id_value)
		&"HasInParty":
			return _party_has_species(id_value)

		# === Location ===
		&"Location":
			return GameState.map_id == value
		&"LocationFlag":
			return GameState.map_has_flag(StringName(evo.parameter))
		&"Region":
			return GameState.current_region() == value

		# === Evolution Stones === 
		&"Item":
			return _used_item_is(parameter, id_value)
		&"ItemMale":
			return _used_item_is(parameter, id_value) and pkmn.is_male()
		&"ItemFemale":
			return _used_item_is(parameter, id_value) and pkmn.is_female()
		&"ItemDay":
			return _used_item_is(parameter, id_value) and TimeOfDay.is_day()
		&"ItemNight":
			return _used_item_is(parameter, id_value) and TimeOfDay.is_night()
		&"ItemHappiness":
			return _used_item_is(parameter, id_value) and pkmn.happiness >= friendly

		# === Trading === 
		&"Trade":
			return true
		&"TradeMale":
			return pkmn.is_male()
		&"TradeFemale":
			return pkmn.is_female()
		&"TradeDay":
			return TimeOfDay.is_day()
		&"TradeNight":
			return TimeOfDay.is_night()
		&"TradeItem":
			return pkmn.held_item == id_value
		&"TradeSpecies":
			var partner: Pokemon = parameter as Pokemon
			if partner == null or partner.species != id_value:
				return false
			return partner.held_item != EVERSTONE

		# === Battle and Events ===
		&"BattleDealCriticalHit":
			var tally: BattleTally = parameter as BattleTally
			return tally != null and tally.criticals_dealt(pkmn) >= value
		&"Event":
			return int(parameter if parameter != null else -1) == value
		&"EventAfterDamageTaken":
			if trigger == TRIGGER_AFTER_BATTLE:
				var damage_tally: BattleTally = parameter as BattleTally
				if damage_tally != null and damage_tally.damage_taken(pkmn) >= DAMAGE_TAKEN_THRESHOLD:
					pkmn.ready_to_evolve = true
				return false
			return int(parameter if parameter != null else -1) == value and pkmn.ready_to_evolve
		
	return false
	
## Figure out the happiness asked for depending on whether or not softcap is enabled
static func happiness_threshold() -> int:
	if GameSettings.data.happiness_soft_cap:
		return HAPPINESS_THRESHOLD_SOFT_CAP
	return HAPPINESS_THRESHOLD
	
## Runs whatever the needed bookkeeping is for a given evolution method
static func run_after_evolution(pkmn: Pokemon, new_species: StringName) -> Pokemon:
	if pkmn == null:
		return null
	var record: SpeciesData = pkmn.species_data()
	if record == null:
		return null
	for evo: SpeciesEvolution in record.get_evolutions():
		if evo.species != new_species and not DUPLICATING_METHODS.has(evo.method):
			continue
		if ITEM_CONSUMED_METHODS.has(evo.method):
			if pkmn.held_item != evo.parameter_as_id():
				continue
			pkmn.held_item = &""
			return null
		if DUPLICATING_METHODS.has(evo.method):
			var duplicated: Pokemon = _duplicate_for(pkmn, evo.species)
			if duplicated != null:
				return duplicated
	return null
	
# === Internals ===
	
## Creates the 'duplicate' pokemon for an evolution (for vanilla : Shedinja)
## Returns `null` if the party is full or there is no ball
static func _duplicate_for(pkmn: Pokemon, species_id: StringName) -> Pokemon:
	if GameState.party == null or GameState.party.is_full():
		return null
	if not GameState.bag.has_item(DUPLICATE_BALL):
		return null
	var duplicated: Pokemon = pkmn.clone()
	duplicated.species_id = species_id
	duplicated.nickname = ""
	duplicated.poke_ball = DUPLICATE_BALL
	duplicated.markings = 0
	duplicated.held_item = &""
	duplicated.ribbons.clear()
	duplicated.form = FormHandlers.default_form(duplicated)
	duplicated.calculate_stats()
	duplicated.heal()
	if not GameState.party.add(duplicated):
		return null
	GameState.bag.remove_item(DUPLICATE_BALL, 1)
	if GameState.player != null:
		GameState.player.pokedex.register_owned(duplicated)
	return duplicated
	
static func _weather_is_any(weather_ids: Array[StringName]) -> bool: 
	var current_weather: StringName = GameState.current_weather()
	return weather_ids.has(current_weather if not current_weather.is_empty() else CLEAR_WEATHER[0])

static func _party_has_species(species_id: StringName) -> bool:
	for member: Pokemon in GameState.party.members:
		if member.species == species_id:
			return true
	return false

static func _party_has_type(type_id: StringName, exclude: Pokemon) -> bool:
	for member: Pokemon in GameState.party.members:
		if member == exclude:
			continue
		if member.has_type(type_id):
			return true
	return false
	
static func _knows_move_of_type(pkmn: Pokemon, type_id: StringName) -> bool:
	for move: PokemonMove in pkmn.moves:
		var ref: MoveData = move.data()
		if ref != null and ref.type == type_id:
			return true
	return false
	
static func _used_item_is(param: Variant, expected: StringName) -> bool:
	return param != null and StringName(param) == expected
