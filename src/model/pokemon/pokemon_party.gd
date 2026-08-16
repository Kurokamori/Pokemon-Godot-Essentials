class_name PokemonParty
extends RefCounted
## The Pokemon that a trainer own
##
## Signal based rather than UI maintained

const MINIMUM_MEMBERS: int = 1

## The ability flag that indicates an ability that halves the walking needed to hatch an egg
const FASTER_HATCHING_FLAG: StringName = &"FasterEggHatching"

var members: Array[Pokemon] = []

## overrides the default maximum for contexts like double battles where the player may only have 3 memebers
var capacity: int = 0

signal member_added(pokemon: Pokemon, index: int)
signal member_removed(pokemon: Pokemon, index: int)
signal members_reordered()
signal party_changed()


func size() -> int:
	return members.size()
	
func is_empty() -> bool:
	return members.is_empty()
	
func is_full() -> bool:
	return members.size() >= (capacity if capacity > 0 else GameSettings.data.max_party_size)
	
func get_member(index: int) -> Pokemon:
	if index < 0 or index >= members.size():
		return null
	return members[index]
	
## Attempts to add a Pokemon
## Returns `false` when the party is already full
func add(pokemon: Pokemon) -> bool:
	if pokemon == null or is_full():
		return false
	members.append(pokemon)
	member_added.emit(pokemon, members.size() - 1)
	party_changed.emit()
	return true
	
func remove_at(index: int) -> Pokemon:
	if index < 0 or index >= members.size():
		return null
	var pkmn: Pokemon = members[index]
	members.remove_at(index)
	member_removed.emit(pkmn, index)
	party_changed.emit()
	return pkmn
	
## Places [param replacement] into the slot [param index]
## Returns `null` if the party would be illegal due to the swap
## Returns back the Pokemon that was there before
func replace_at(index: int, replacement: Pokemon) -> Pokemon:
	if replacement == null or index < 0 or index >= members.size():
		return null
	if not can_replace_at(index, replacement):
		return null
	var prev: Pokemon = members[index]
	members[index] = replacement
	member_removed.emit(prev, index)
	member_added.emit(replacement, index)
	party_changed.emit()
	return prev
	
func remove(pokemon: Pokemon) -> bool:
	var index: int = members.find(pokemon)
	if index < 0:
		return false
	remove_at(index)
	return true
	
func swap(first: int, second: int) -> void:
	if first == second:
		return
	if first < 0 or second < 0 or first > members.size() or second > members.size():
		return
	var held: Pokemon = members[first]
	members[first] = members[second]
	members[second] = held
	members_reordered.emit()
	party_changed.emit()
	
func clear() -> void:
	members.clear()
	party_changed.emit()
	
# === Queries ===

## Which party Pokemon are still able to battle
func able_members() -> Array[Pokemon]:
	var result: Array[Pokemon] = []
	for pkmn: Pokemon in members:
		if pkmn.is_able():
			result.append(pkmn)
	return result
	
func able_count() -> int:
	return able_members().size()
	
## Returns `true` when every memeber is fainted
func all_fainted() -> bool:
	return able_count() == 0
	
func first_able() -> Pokemon:
	for pkmn: Pokemon in members:
		if pkmn.is_able():
			return pkmn
	return null
	
## The Pokemon at the front of the party, fainted or not
## Ignores eggs
## Used for abilities and items
func first_non_egg() -> Pokemon:
	for pkmn: Pokemon in members:
		if not pkmn.is_egg():
			return pkmn
	return null
	
## Members that are currently eligeble for battle, one of THESE must remain in the party at all time
func battle_ready_members() -> Array[Pokemon]:
	return _battle_ready_of(members)
	
func battle_ready_count() -> int:
	return _battle_ready_of(members).size()
	
## Checks the validate of a replacement, passing `null` for [param replacement] removes them outright
## The party must stay legal, however in the case where it's not, the player is exempt so they can organize out of it.
func can_replace_at(index: int, replacement: Pokemon) -> bool:
	if index < 0 or index >= members.size():
		return true
	var remaining: Array[Pokemon] = members.duplicate()
	if replacement == null:
		remaining.remove_at(index)
	else:
		remaining[index] = replacement
	if remaining.size() < MINIMUM_MEMBERS:
		return false
	if battle_ready_count() == 0:
		return true
	return not _battle_ready_of(remaining).is_empty
	
## Returns `true` if the selected Pokemon leaving the party wouldn't leave the party in a bad state
func can_remove_at(index: int) -> bool:
	if get_member(index) == null:
		return false
	return can_replace_at(index, null)
	
## The party, in party order, omitting eggs
func non_egg_members() -> Array[Pokemon]:
	var result: Array[Pokemon] = []
	for pkmn: Pokemon in members:
		if not pkmn.is_egg():
			result.append(pkmn)
	return result
	
func has_species(species_id: StringName) -> bool:
	for pkmn: Pokemon in members:
		if pkmn.species == species_id:
			return true
	return false
	
func has_move(move_id: StringName) -> bool:
	for pkmn: Pokemon in members:
		if not pkmn.is_egg() and pkmn.knows_move(move_id):
			return true
	return false
	
## The first Pokemon in the party that knows the [param move_id]
func first_with_move(move_id: StringName) -> Pokemon:
	for pkmn: Pokemon in members:
		if not pkmn.is_egg() and pkmn.knows_move(move_id):
			return pkmn
	return null
	
func has_ability(ability_id: StringName) -> bool:
	for pkmn: Pokemon in members:
		if not pkmn.is_egg() and pkmn.ability_id() == ability_id:
			return true
	return false
	
func lead_ability() -> StringName:
	for pkmn: Pokemon in members:
		if not pkmn.is_egg():
			return pkmn.ability_id()
	return &""
	
func highest_level() -> int:
	var highest: int = 0
	for pkmn: Pokemon in members:
		if not pkmn.is_egg():
			highest = pkmn.level() if pkmn.level() > highest else highest
	return highest
	
func lowest_level() -> int:
	var lowest: int = 0
	for pkmn: Pokemon in members:
		if not pkmn.is_egg():
			lowest = mini(pkmn.level(), lowest)
	return lowest
	
# === Actions ===

func heal_all() -> void:
	for pkmn: Pokemon in members:
		pkmn.heal()
	party_changed.emit()
	
## Ticks down egg hatch timing, returns any eggs that are ready to hatch
func take_step() -> Array[Pokemon]:
	var ready_hatch: Array[Pokemon] = []
	var per_step: int = maxi(GameSettings.data.egg_steps_per_cycle, 1)
	if _has_faster_hatching_ability():
		per_step += 1
	for pkmn: Pokemon in members:
		if not pkmn.is_egg():
			continue
		if pkmn.steps_to_hatch - per_step <= 0:
			ready_hatch.append(pkmn)
			continue
		pkmn.steps_to_hatch -= per_step
	return ready_hatch
	
# === Serialisation ===

func to_array() -> Array:
	var result: Array = []
	for pkmn: Pokemon in members:
		result.append(pkmn.to_dict())
	return result
	
func from_array(source: Array) -> void:
	members.clear()
	for entry: Variant in source:
		members.append(Pokemon.from_dict(entry))
	party_changed.emit()
	
	
# === Internals ===

func _battle_ready_of(candidates: Array[Pokemon]) -> Array[Pokemon]:
	var result: Array[Pokemon] = []
	for pkmn: Pokemon in candidates:
		if pkmn != null and not pkmn.is_egg() and pkmn.is_able():
			result.append(pkmn)
	return result
	
func _has_faster_hatching_ability() -> bool:
	for pkmn: Pokemon in members:
		if pkmn.is_egg():
			continue
		var ability: AbilityData = Database.ability(pkmn.ability_id())
		if ability != null and ability.has_flag(FASTER_HATCHING_FLAG):
			return true
	return false
	
