class_name FollowerPokemon
extends RefCounted
## Describes one Pokemon walking behind the player.
## Party slot this follower was taken from, or [constant NOT_IN_PARTY].
const NOT_IN_PARTY: int = -1

var species: StringName = &""
var form: int = 0
var shiny: bool = false
var female: bool = false
var egg: bool = false

## Display name, using the nickname when present.
var nickname: String = ""

## Party slot represented by this follower.
var party_index: int = NOT_IN_PARTY

## Live party member, when applicable.
var pokemon: Pokemon = null

## Forces this follower to appear when followers are disabled.
var forced: bool = false

# === Building ===

## Creates a follower from a party Pokemon.
static func from_pokemon(pkmn: Pokemon, index: int = NOT_IN_PARTY) -> FollowerPokemon:
	if pkmn == null:
		return null
	var entry: FollowerPokemon = FollowerPokemon.new()
	entry.species = pkmn.species
	entry.form = pkmn.active_form()
	entry.shiny = pkmn.is_shiny()
	entry.female = pkmn.is_female()
	entry.egg = pkmn.is_egg()
	entry.nickname = pkmn.display_name()
	entry.party_index = index
	entry.pokemon = pkmn
	return entry

## Creates a temporary follower from a species.
static func from_species(
	species_id: StringName, at_form: int = 0, is_shiny: bool = false,
	is_female: bool = false, called: String = ""
) -> FollowerPokemon:
	var entry: FollowerPokemon = FollowerPokemon.new()
	entry.species = species_id
	entry.form = maxi(at_form, 0)
	entry.shiny = is_shiny
	entry.female = is_female
	entry.nickname = called
	return entry

# === Reading ===

## Returns whether this entry has a species.
func is_valid() -> bool:
	return not species.is_empty()

## Returns the species record for this follower.
func species_data() -> SpeciesData:
	if species.is_empty():
		return null
	return Database.species_form(species, form)

## Returns the follower character sheet name.
func charset_name() -> String:
	return Assets.pokemon_follower_charset(species, form, shiny, female, egg)

## Returns this follower's display name.
func display_name() -> String:
	if not nickname.is_empty():
		return nickname
	if egg:
		return Loc.line("Egg")
	var record: SpeciesData = species_data()
	return record.display_name if record != null else String(species)

## Returns whether this follower represents a party member.
func is_party_member() -> bool:
	return party_index != NOT_IN_PARTY and pokemon != null

## Returns the values used to compare follower state.
func signature() -> String:
	return "%s/%d/%d/%d/%d/%d/%s" % [
		species, form, int(shiny), int(female), int(egg), party_index, nickname
	]

# === Persistence ===

## Serializes this follower for saving.
func to_dict() -> Dictionary:
	return {
		"species": String(species),
		"form": form,
		"shiny": shiny,
		"female": female,
		"egg": egg,
		"nickname": nickname,
		"party_index": party_index,
		"forced": forced,
	}

static func from_dict(source: Dictionary) -> FollowerPokemon:
	var entry: FollowerPokemon = FollowerPokemon.new()
	entry.species = StringName(source.get("species", ""))
	entry.form = int(source.get("form", 0))
	entry.shiny = bool(source.get("shiny", false))
	entry.female = bool(source.get("female", false))
	entry.egg = bool(source.get("egg", false))
	entry.nickname = String(source.get("nickname", ""))
	entry.party_index = int(source.get("party_index", NOT_IN_PARTY))
	entry.forced = bool(source.get("forced", false))
	return entry
