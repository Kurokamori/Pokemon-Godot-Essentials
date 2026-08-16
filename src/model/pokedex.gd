class_name Pokedex
extends RefCounted

## Tracks the Pokedex

signal species_seen(species_id: StringName)
signal species_owned(species_id: StringName)

const NATIONAL_DEX: int = -1

var seen: Dictionary = {}
var owned: Dictionary = {}

## Maps a species id to the set of form numbers seen
## allows the Pokedex to show which forms are or aren't missing
var seen_forms: Dictionary = {}

## Maps a species id to the set of form numbers owned
## allows the Pokedex to show which forms are or aren't missing
var owned_forms: Dictionary = {}

## Species whose pages have been opened at least one time
var entries_read: Dictionary = {}

## The regional dexes which are unlocked and visible
var unlocked_dexes: Array[bool] = [true]


func mark_seen(species_id: StringName, form_id: int = 0, gender: int = 0) -> void:
	if species_id.is_empty():
		return
	var new: bool = not seen.has(species_id)
	seen[species_id] = true
	_add_form(seen_forms, species_id, form_id, gender)
	if new:
		species_seen.emit(species_id)

func mark_owned(species_id: StringName, form_id: int = 0, gender: int = 0) -> void:
	if species_id.is_empty():
		return
	var new: bool = not owned.has(species_id)
	owned[species_id] = true
	_add_form(owned_forms, species_id, form_id, gender)
	if new:
		species_owned.emit(species_id)

func register_seen(pokemon: Pokemon) -> void:
	mark_seen(pokemon.species, pokemon.active_form(), pokemon.gender())
	
func register_owned(pokemon: Pokemon) -> void:
	mark_owned(pokemon.species, pokemon.active_form(), pokemon.gender())
	
func is_seen(species_id: StringName) -> bool:
	return seen.has(species_id)
	
func is_owned(species_id: StringName) -> bool:
	return owned.has(species_id)
	
func has_seen_form(species_id: StringName, form: int, gender: int = 0) -> bool:
	var forms: Dictionary = seen_forms.get(species_id, {})
	return forms.has(_form_key(form, gender))

func has_owned_form(species_id: StringName, form: int, gender: int = 0) -> bool:
	var forms: Dictionary = owned_forms.get(species_id, {})
	return forms.has(_form_key(form, gender))

func mark_entry_read(species_id: StringName) -> void:
	entries_read[species_id] = true

func has_read_entry(species_id: StringName) -> bool:
	return entries_read.has(species_id)

## Number of species seen, optionally limited to one regional dex.
func seen_count(region: int = -1) -> int:
	return _count(seen, region)

## Number of species caught, optionally limited to one regional dex.
func owned_count(region: int = -1) -> int:
	return _count(owned, region)

func _count(source: Dictionary, region: int) -> int:
	if region < 0:
		return source.size()
	var dex: RegionalDexData = Database.regional_dex(region)
	if dex == null:
		return source.size()
	var total: int = 0
	for species_id: StringName in dex.species_order:
		if source.has(species_id):
			total += 1
	return total

## Marks a whole regional dex as available in the Pokedex UI.
func unlock_dex(region: int) -> void:
	while unlocked_dexes.size() <= region:
		unlocked_dexes.append(false)
	unlocked_dexes[region] = true

## Hides a regional dex again, which the events that gate the Pokedex use to
## take it back.
func lock_dex(region: int) -> void:
	if region < 0 or region >= unlocked_dexes.size():
		return
	unlocked_dexes[region] = false


func is_dex_unlocked(region: int) -> bool:
	if region < 0 or region >= unlocked_dexes.size():
		return false
	return unlocked_dexes[region]

func _add_form(store: Dictionary, species_id: StringName, form: int, gender: int) -> void:
	if not store.has(species_id):
		store[species_id] = {}
	store[species_id][_form_key(form, gender)] = true

func _form_key(form: int, gender: int) -> String:
	return "%d:%d" % [form, gender]

func to_dict() -> Dictionary:
	return {
		"seen": _string_keys(seen),
		"owned": _string_keys(owned),
		"seen_forms": _string_keys(seen_forms),
		"owned_forms": _string_keys(owned_forms),
		"entries_read": _string_keys(entries_read),
		"unlocked_dexes": unlocked_dexes.duplicate(),
	}

func from_dict(source: Dictionary) -> void:
	seen = _stringname_keys(source.get("seen", {}))
	owned = _stringname_keys(source.get("owned", {}))
	seen_forms = _stringname_keys(source.get("seen_forms", {}))
	owned_forms = _stringname_keys(source.get("owned_forms", {}))
	entries_read = _stringname_keys(source.get("entries_read", {}))
	unlocked_dexes.clear()
	for entry: Variant in source.get("unlocked_dexes", [true]):
		unlocked_dexes.append(bool(entry))

func _string_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		result[String(key)] = source[key]
	return result

func _stringname_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		result[StringName(key)] = source[key]
	return result
