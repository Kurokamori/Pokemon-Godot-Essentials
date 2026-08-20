class_name EventScriptValues
## Methods and properties available on values returned to imported Ruby events.
## Each method maps one Ruby name to one engine call.

## Returned when a value does not support a requested method.
class NoSuchMethod extends RefCounted:
	pass

## Constants exposed by Essentials to imported events.
const CONSTANTS: Dictionary = {
	"Settings::MAX_MONEY": &"max_money",
	"Settings::MAX_COINS": &"max_coins",
	"Settings::MAX_BATTLE_POINTS": &"max_battle_points",
	"Settings::MAX_SOOT": &"max_soot",
	"Settings::MAX_PLAYER_NAME_SIZE": &"max_player_name_size",
	"Settings::MAXIMUM_LEVEL": &"maximum_level",
	"Settings::EGG_LEVEL": &"egg_level",
	"Settings::MECHANICS_GENERATION": &"mechanics_generation",
	"Settings::SHINY_POKEMON_CHANCE": &"shiny_chance_denominator",
	"Pokemon::MAX_NAME_SIZE": &"max_pokemon_name_size",
	"Pokemon::MAX_MOVES": &"max_moves",
	"Pokemon::EV_LIMIT": &"maximum_total_evs",
	"Pokemon::EV_STAT_LIMIT": &"maximum_stat_evs",
	"Pokemon::IV_STAT_LIMIT": &"maximum_iv",
}

## Data categories available through `GameData::<name>`.
const DATA_CATEGORIES: Dictionary = {
	"Item": &"items",
	"Species": &"species",
	"Move": &"moves",
	"Type": &"types",
	"Stat": &"stats",
	"Ability": &"abilities",
	"Nature": &"natures",
	"Ribbon": &"ribbons",
	"Status": &"statuses",
	"Weather": &"weathers",
	"BerryPlant": &"berry_plants",
	"TrainerType": &"trainer_types",
}

## The value of a `Settings::` or `Pokemon::` constant, or [NoSuchMethod].
static func constant(name: String) -> Variant:
	if not CONSTANTS.has(name):
		return NoSuchMethod.new()
	return GameSettings.data.get(String(CONSTANTS[name]))

## Returns `true` for a `GameData::<something>` receiver.
static func is_data_category(name: String) -> bool:
	return DATA_CATEGORIES.has(_category_name(name))

## Runs `get`, `exists?`, or `try_get` on a GameData category.
static func data_category_call(name: String, method: String, arguments: Array) -> Variant:
	var category: StringName = DATA_CATEGORIES.get(_category_name(name), &"")
	if category == &"" or arguments.is_empty():
		return NoSuchMethod.new()
	var id: StringName = _as_id(arguments[0])
	match method:
		"get", "try_get":
			return Database.get_record(category, id)
		"exists?":
			return Database.has_record(category, id)
	return NoSuchMethod.new()

## Removes the optional `GameData::` prefix from a category name.
static func _category_name(name: String) -> String:
	var trimmed: String = name
	if trimmed.begins_with("GameData::"):
		trimmed = trimmed.substr("GameData::".length())
	return trimmed

# === Dispatch ===

## Calls a method on a value.
static func call_method(value: Variant, method: String, arguments: Array) -> Variant:
	# Supports Ruby's type-test methods.
	if method == "is_a?" or method == "kind_of?" or method == "instance_of?":
		return _is_a(value, String(arguments[0]) if not arguments.is_empty() else "")
	if method == "nil?":
		return value == null
	if value is GridCharacter:
		return _character_method(value, method, arguments)
	if value is Pokemon:
		return _pokemon_method(value, method, arguments)
	if value is GameDataResource:
		return _record_method(value, method, arguments)
	if value is Array:
		return _array_method(value, method, arguments)
	if value is Dictionary:
		return _dictionary_method(value, method, arguments)
	if value is String or value is StringName:
		return _string_method(String(value), method, arguments)
	if value is int or value is float:
		return _number_method(value, method, arguments)
	return NoSuchMethod.new()

## Writes a property on a value.
static func set_property(value: Variant, property: String, assigned: Variant) -> bool:
	if value is Pokemon:
		return _set_pokemon_property(value, property, assigned)
	if value is GridCharacter:
		return _set_character_property(value, property, assigned)
	return false

## Checks a value against a Ruby class name.
static func _is_a(value: Variant, class_wanted: String) -> bool:
	match class_wanted:
		"Symbol":
			return value is StringName
		"String":
			return value is String
		"Integer", "Numeric", "Fixnum":
			return value is int or value is float
		"Float":
			return value is float
		"Array":
			return value is Array
		"Hash":
			return value is Dictionary
		"Pokemon":
			return value is Pokemon
		"NilClass":
			return value == null
	return false

## Handles methods called on map characters.
static func _character_method(character: GridCharacter, method: String, arguments: Array) -> Variant:
	match method:
		"x":
			return character.tile_position.x
		"y":
			return character.tile_position.y
		"direction":
			return int(character.facing)
		"pattern":
			return character.pattern
		"id":
			return character.event_id if character is MapEvent else 0
		"name":
			return character.display_name() if character is MapEvent else character.name
		"moving?":
			return character.is_moving
		"turn_up":
			character.facing = GridCharacter.Direction.UP
			return true
		"turn_down":
			character.facing = GridCharacter.Direction.DOWN
			return true
		"turn_left":
			character.facing = GridCharacter.Direction.LEFT
			return true
		"turn_right":
			character.facing = GridCharacter.Direction.RIGHT
			return true
		"moveto":
			if arguments.size() >= 2:
				character.tile_position = Vector2i(int(arguments[0]), int(arguments[1]))
				return true
	return NoSuchMethod.new()

static func _set_character_property(character: GridCharacter, property: String, assigned: Variant) -> bool:
	match property:
		"pattern":
			# Keep an explicitly assigned pose after the next step.
			character.pattern = int(assigned)
			character.original_pattern = character.pattern
		"direction":
			character.facing = int(assigned) as GridCharacter.Direction
		"through":
			character.passable = bool(assigned)
		"character_name":
			character.set_charset(String(assigned))
		"direction_fix":
			character.direction_fix = bool(assigned)
		"step_anime":
			character.step_animation = bool(assigned)
		_:
			return false
	return true

## Reads an array or dictionary entry.
static func index_of(value: Variant, index: Variant) -> Variant:
	if value is Array:
		var position: int = int(index)
		if position < 0:
			position += value.size()
		if position < 0 or position >= value.size():
			return null
		return value[position]
	if value is Dictionary:
		return _dictionary_lookup(value, index)
	if value is Pokemon:
		return null
	return null

## Writes an array or dictionary entry.
static func set_index(value: Variant, index: Variant, assigned: Variant) -> bool:
	if value is Array:
		var position: int = int(index)
		if position < 0 or position >= value.size():
			return false
		value[position] = assigned
		return true
	if value is Dictionary:
		value[_hash_key(index)] = assigned
		return true
	return false

## Normalizes string keys to StringName.
static func _hash_key(key: Variant) -> Variant:
	if key is String or key is StringName:
		return StringName(String(key))
	return key

static func _dictionary_lookup(table: Dictionary, key: Variant) -> Variant:
	var normalised: Variant = _hash_key(key)
	if table.has(normalised):
		return table[normalised]
	if table.has(key):
		return table[key]
	return null

# === Pokemon ===

static func _pokemon_method(pkmn: Pokemon, method: String, arguments: Array) -> Variant:
	match method:
		"name", "display_name":
			return pkmn.display_name()
		"speciesName", "species_name":
			var record: SpeciesData = pkmn.species_data()
			return record.display_name if record != null else String(pkmn.species)
		"species":
			return pkmn.species
		"species_data":
			return pkmn.species_data()
		"level":
			return pkmn.level()
		"form":
			return pkmn.form
		"item", "item_id":
			return pkmn.held_item
		"happiness":
			return pkmn.happiness
		"beauty":
			return pkmn.beauty
		"nature":
			return pkmn.nature()
		"ability_index":
			return pkmn.ability_index
		"ability":
			return pkmn.ability_id()
		"poke_ball":
			return pkmn.poke_ball
		"owner":
			return pkmn.owner
		"iv", "calcIV":
			return _stat_table(pkmn, true)
		"ev":
			return _stat_table(pkmn, false)
		"totalhp", "total_hp":
			return pkmn.total_hp
		"hp":
			return pkmn.hp
		"numMoves", "move_count":
			return pkmn.move_count()
		"moves":
			return _move_ids(pkmn)
		"getMoveList", "get_move_list":
			return _level_up_move_list(pkmn)
		"first_moves":
			return pkmn.first_moves.duplicate()
		"egg?", "is_egg?":
			return pkmn.is_egg()
		"shadowPokemon?", "shadow?":
			return pkmn.shadow
		"male?":
			return pkmn.is_male()
		"female?":
			return pkmn.is_female()
		"genderless?":
			return pkmn.is_genderless()
		"shiny?":
			return pkmn.is_shiny()
		"able?":
			return pkmn.is_able()
		"fainted?":
			return pkmn.is_fainted()
		"hasHiddenAbility?":
			return pkmn.has_hidden_ability()
		"cannot_store":
			return pkmn.cannot_store
		"isSpecies?":
			return not arguments.is_empty() and pkmn.species == _as_id(arguments[0])
		"hasMove?":
			return not arguments.is_empty() and pkmn.knows_move(_as_id(arguments[0]))
		"hasItem?":
			return not arguments.is_empty() and pkmn.held_item == _as_id(arguments[0])
		"hasRibbon?":
			return not arguments.is_empty() and pkmn.has_ribbon(_as_id(arguments[0]))
		"foreign?":
			return _is_foreign(pkmn, arguments)
		"compatible_with_move?":
			return not arguments.is_empty() and pkmn.can_learn_machine_move(_as_id(arguments[0]))
		"can_relearn_move?":
			return not pkmn.relearnable_moves().is_empty()
		"learn_move":
			return not arguments.is_empty() and pkmn.learn_move(_as_id(arguments[0]))
		"forget_move":
			return not arguments.is_empty() and pkmn.forget_move(_as_id(arguments[0]))
		"forget_move_at_index":
			return not arguments.is_empty() and pkmn.forget_move_at(int(arguments[0]))
		"giveRibbon", "give_ribbon":
			return not arguments.is_empty() and pkmn.give_ribbon(_as_id(arguments[0]))
		"takeRibbon", "take_ribbon":
			return not arguments.is_empty() and pkmn.take_ribbon(_as_id(arguments[0]))
		"upgradeRibbon", "upgrade_ribbon":
			return _upgrade_ribbon(pkmn, arguments)
		"changeHappiness", "change_happiness":
			if arguments.is_empty():
				return false
			pkmn.change_happiness(_as_id(arguments[0]))
			return true
		"calc_stats", "calcStats":
			pkmn.calculate_stats()
			return true
		"makeMale", "make_male":
			pkmn.gender_override = Pokemon.Gender.MALE
			return true
		"makeFemale", "make_female":
			pkmn.gender_override = Pokemon.Gender.FEMALE
			return true
		"heal":
			pkmn.heal()
			return true
		"play_cry":
			pkmn.play_cry()
			return true
		"hiddenPower", "hidden_power":
			return _hidden_power(pkmn)
	return NoSuchMethod.new()

static func _set_pokemon_property(pkmn: Pokemon, property: String, assigned: Variant) -> bool:
	match property:
		"name", "nickname":
			# Ruby uses nil to clear a nickname.
			pkmn.nickname = "" if assigned == null else String(assigned)
		"form":
			pkmn.form = int(assigned)
		"item", "item_id":
			pkmn.held_item = _as_id(assigned)
		"happiness":
			pkmn.happiness = clampi(int(assigned), 0, 255)
		"beauty":
			pkmn.beauty = clampi(int(assigned), 0, 255)
		"cool":
			pkmn.cool = clampi(int(assigned), 0, 255)
		"cute":
			pkmn.cute = clampi(int(assigned), 0, 255)
		"smart":
			pkmn.smart = clampi(int(assigned), 0, 255)
		"tough":
			pkmn.tough = clampi(int(assigned), 0, 255)
		"sheen":
			pkmn.sheen = clampi(int(assigned), 0, 255)
		"nature":
			pkmn.nature_override = _as_id(assigned)
		"ability_index":
			pkmn.ability_index = int(assigned)
		"poke_ball":
			pkmn.poke_ball = _as_id(assigned)
		"shiny":
			pkmn.set_shiny(bool(assigned))
		"level":
			pkmn.set_level(int(assigned))
		"hp":
			pkmn.hp = int(assigned)
		"cannot_store":
			pkmn.cannot_store = bool(assigned)
		"cannot_release":
			pkmn.cannot_release = bool(assigned)
		"cannot_trade":
			pkmn.cannot_trade = bool(assigned)
		"obtain_text":
			pkmn.obtain_text = String(assigned)
		_:
			return false
	return true

## Returns a snapshot of a Pokemon's IVs or EVs.
static func _stat_table(pkmn: Pokemon, individual: bool) -> Dictionary:
	var table: Dictionary = {}
	for stat: StringName in Pokemon.STAT_IDS:
		table[stat] = pkmn.get_raw_iv(stat) if individual else pkmn.get_ev(stat)
	return table

## Writes one IV or EV value.
static func write_stat(pkmn: Pokemon, table: String, stat: Variant, value: int) -> bool:
	var stat_id: StringName = _as_id(stat)
	if not Pokemon.STAT_IDS.has(stat_id):
		return false
	if table == "iv":
		pkmn.set_iv(stat_id, value)
		return true
	if table == "ev":
		pkmn.set_ev(stat_id, value)
		return true
	return false

static func _move_ids(pkmn: Pokemon) -> Array:
	var ids: Array = []
	for move: PokemonMove in pkmn.moves:
		ids.append(move.id)
	return ids

## Returns the species' learnset as level and move pairs.
static func _level_up_move_list(pkmn: Pokemon) -> Array:
	var moves: Array = []
	var record: SpeciesData = pkmn.species_data()
	if record == null:
		return moves
	for entry: LevelUpMove in record.level_up_moves:
		moves.append([entry.level, entry.move])
	return moves

static func _is_foreign(pkmn: Pokemon, arguments: Array) -> bool:
	if not arguments.is_empty() and arguments[0] is PokemonOwner:
		return pkmn.is_foreign(arguments[0])
	var owner: PokemonOwner = GameState.player.owner_record() if GameState.player != null else null
	return pkmn.is_foreign(owner)

## Replaces a ribbon with the next ribbon in its chain.
static func _upgrade_ribbon(pkmn: Pokemon, chain: Array) -> Variant:
	for index: int in chain.size():
		var ribbon: StringName = _as_id(chain[index])
		if not pkmn.has_ribbon(ribbon):
			continue
		if index + 1 >= chain.size():
			return null
		var better: StringName = _as_id(chain[index + 1])
		pkmn.take_ribbon(ribbon)
		pkmn.give_ribbon(better)
		return better
	if chain.is_empty():
		return null
	var first: StringName = _as_id(chain[0])
	pkmn.give_ribbon(first)
	return first

## Returns Hidden Power's type and power.
static func _hidden_power(pkmn: Pokemon) -> Array:
	var result: Dictionary = pkmn.hidden_power()
	return [result.get("type", &"NORMAL"), result.get("power", 60)]

# === Data Records ===

static func _record_method(record: GameDataResource, method: String, arguments: Array) -> Variant:
	match method:
		"name", "real_name":
			return record.display_name
		"id":
			return record.id
		"has_flag?":
			return not arguments.is_empty() and record.has_flag(_as_id(arguments[0]))
	if record is ItemData:
		return _item_method(record, method)
	if record is SpeciesData:
		return _species_method(record, method)
	if record is MoveData:
		return _move_method(record, method)
	return NoSuchMethod.new()

static func _item_method(record: ItemData, method: String) -> Variant:
	match method:
		"name_plural":
			return record.name_plural
		"move":
			return record.move
		"price":
			return MartStock.price_of(record)
		"sell_price":
			return MartStock.sell_price_of(record)
		"pocket":
			return record.pocket
		"portion_name":
			return record.portion_name
		"portion_name_plural":
			return record.portion_name_plural
		"is_berry?":
			return record.is_berry()
		"is_machine?":
			return record.is_machine()
		"is_key_item?":
			return record.is_key_item()
		"is_poke_ball?":
			return record.is_poke_ball()
		"is_mail?":
			return record.is_mail()
		"is_important?":
			return record.is_important()
	return NoSuchMethod.new()

static func _species_method(record: SpeciesData, method: String) -> Variant:
	match method:
		"types":
			return record.types.duplicate()
		"egg_groups":
			return record.egg_groups.duplicate()
		"egg_moves":
			return record.egg_moves.duplicate()
		"base_exp":
			return record.base_exp
		"growth_rate":
			return record.growth_rate
		"gender_ratio":
			return record.gender_ratio
		"hatch_steps":
			return record.hatch_steps
		"offspring":
			return record.offspring.duplicate()
		"get_baby_species":
			return record.get_prevolution()
	return NoSuchMethod.new()

static func _move_method(record: MoveData, method: String) -> Variant:
	match method:
		"type":
			return record.type
		"power", "base_damage":
			return record.power
		"accuracy":
			return record.accuracy
		"total_pp":
			return record.total_pp
	return NoSuchMethod.new()

# === Arrays, Hashes, and Text ===

static func _array_method(list: Array, method: String, arguments: Array) -> Variant:
	match method:
		"length", "size", "count":
			return list.size()
		"empty?":
			return list.is_empty()
		"first":
			return list[0] if not list.is_empty() else null
		"last":
			return list[-1] if not list.is_empty() else null
		"sample":
			return list[RNG.below(list.size())] if not list.is_empty() else null
		"shuffle":
			return RNG.shuffled(list)
		"min":
			return _extreme(list, true)
		"max":
			return _extreme(list, false)
		"sum":
			return _sum(list)
		"include?":
			return not arguments.is_empty() and _contains(list, arguments[0])
		"index":
			return list.find(arguments[0]) if not arguments.is_empty() else -1
		"push", "append":
			for argument: Variant in arguments:
				list.append(argument)
			return list
		"pop":
			return list.pop_back()
		"delete":
			if not arguments.is_empty():
				list.erase(arguments[0])
			return list
		"compact", "compact!":
			# Ruby's compact! removes nil entries in place.
			var kept: Array = []
			for entry: Variant in list:
				if entry != null:
					kept.append(entry)
			list.assign(kept)
			return list
		"reverse":
			var reversed: Array = list.duplicate()
			reversed.reverse()
			return reversed
		"join":
			var separator: String = String(arguments[0]) if not arguments.is_empty() else ""
			var parts: PackedStringArray = PackedStringArray()
			for entry: Variant in list:
				parts.append(str(entry))
			return separator.join(parts)
	return NoSuchMethod.new()

static func _dictionary_method(table: Dictionary, method: String, arguments: Array) -> Variant:
	match method:
		"length", "size", "count":
			return table.size()
		"empty?":
			return table.is_empty()
		"keys":
			return table.keys()
		"values":
			return table.values()
		"has_key?", "key?", "include?":
			return not arguments.is_empty() and table.has(_hash_key(arguments[0]))
		"merge", "merge!":
			for argument: Variant in arguments:
				if argument is Dictionary:
					table.merge(argument, true)
			return table
		"fetch":
			if arguments.is_empty():
				return null
			var found: Variant = _dictionary_lookup(table, arguments[0])
			return found if found != null or arguments.size() < 2 else arguments[1]
	return NoSuchMethod.new()

static func _string_method(text: String, method: String, arguments: Array) -> Variant:
	match method:
		"length", "size":
			return text.length()
		"empty?":
			return text.is_empty()
		"upcase":
			return text.to_upper()
		"downcase":
			return text.to_lower()
		"capitalize":
			return text.capitalize()
		"to_i":
			return int(text)
		"to_s", "to_sym":
			return text
		"include?":
			return not arguments.is_empty() and text.contains(String(arguments[0]))
		"starts_with_vowel?":
			return not text.is_empty() and "AEIOUaeiou".contains(text[0])
	return NoSuchMethod.new()

static func _number_method(value: Variant, method: String, _arguments: Array) -> Variant:
	match method:
		"to_i":
			return int(value)
		"to_f":
			return float(value)
		"to_s":
			return str(value)
		"abs":
			if value is float:
				return absf(float(value))
			return absi(int(value))
	return NoSuchMethod.new()

static func _extreme(list: Array, smallest: bool) -> Variant:
	if list.is_empty():
		return null
	var best: Variant = list[0]
	for entry: Variant in list:
		var better: bool = float(entry) < float(best) if smallest else float(entry) > float(best)
		if better:
			best = entry
	return best

static func _sum(list: Array) -> float:
	var total: float = 0.0
	for entry: Variant in list:
		total += float(entry)
	return total

## Compares strings and symbols by their text.
static func _contains(list: Array, wanted: Variant) -> bool:
	for entry: Variant in list:
		if entry == wanted:
			return true
		if (entry is String or entry is StringName) and (wanted is String or wanted is StringName):
			if String(entry) == String(wanted):
				return true
	return false

static func _as_id(value: Variant) -> StringName:
	if value is GameDataResource:
		return value.id
	return StringName(String(value))
