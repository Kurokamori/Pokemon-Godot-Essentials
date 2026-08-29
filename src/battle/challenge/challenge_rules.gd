class_name ChallengeRules
extends Resource
## Rules shared by Battle Frontier facilities.

# === Defaults ===

const RESTRICTED_SPECIES: Array[StringName] = [
	&"MEWTWO", &"MEW", &"LUGIA", &"HOOH", &"CELEBI",
	&"KYOGRE", &"GROUDON", &"RAYQUAZA", &"JIRACHI", &"DEOXYS",
	&"DIALGA", &"PALKIA", &"GIRATINA", &"PHIONE", &"MANAPHY",
	&"DARKRAI", &"SHAYMIN", &"ARCEUS",
	&"RESHIRAM", &"ZEKROM", &"KYUREM", &"VICTINI", &"KELDEO",
	&"MELOETTA", &"GENESECT",
	&"XERNEAS", &"YVELTAL", &"ZYGARDE", &"DIANCIE", &"HOOPA", &"VOLCANION",
	&"COSMOG", &"COSMOEM", &"SOLGALEO", &"LUNALA", &"NECROZMA",
	&"MAGEARNA", &"MARSHADOW", &"ZERAORA",
	&"ZACIAN", &"ZAMAZENTA", &"ETERNATUS", &"ZARUDE", &"CALYREX",
]

# === Facility Rules ===

@export_group("Facility")
## The name shown to the player.
@export var display_name: String = "Battle Tower"

## The identifier used to find this facility.
@export var facility_id: StringName = &"BATTLETOWER"

## The facility's battle format.
@export var format: ChallengeFormat = null

@export_group("Party")
## The number of Pokemon required for the challenge.
@export var party_size: int = 3

## The level applied to entered Pokemon when positive.
@export var level_cap: int = 50

## The maximum level allowed when no level cap is used.
@export var maximum_level: int = 100

## Prevents duplicate species in the entered team.
@export var species_clause: bool = true

## Prevents duplicate held items in the entered team.
@export var item_clause: bool = true

## Allows Eggs in the entered team.
@export var allow_eggs: bool = false

## Species that cannot enter the challenge.
@export var banned_species: Array[StringName] = []

## Items that cannot be brought into the challenge.
@export var banned_items: Array[StringName] = []

@export_group("Challenge")
## The number of rounds in one challenge.
@export var rounds: int = 7

## The number of Pokemon fighting on each side.
@export var battlers_per_side: int = 1

## Heals the player's party between rounds.
@export var heals_between_rounds: bool = true

@export_group("Prizes")
## The prize points awarded for the first completed run.
@export var prize_points: int = 3

## Additional prize points awarded for later runs in a streak.
@export var prize_points_per_run: int = 1

## The maximum prize points awarded for one streak.
@export var maximum_prize_points: int = 20

static var _default_format: ChallengeFormat = null

# === Constructors ===

## Creates standard Battle Tower rules.
static func tower() -> ChallengeRules:
	var rules: ChallengeRules = ChallengeRules.new()
	rules.display_name = "Battle Tower"
	rules.facility_id = &"BATTLETOWER"
	rules.banned_species = RESTRICTED_SPECIES.duplicate()
	return rules

## Creates doubles Battle Tower rules.
static func double_tower() -> ChallengeRules:
	var rules: ChallengeRules = tower()
	rules.display_name = "Battle Tower (Doubles)"
	rules.facility_id = &"BATTLETOWERDOUBLES"
	rules.party_size = 4
	rules.battlers_per_side = 2
	return rules

## Returns this facility's format, creating the default format when needed.
func shape() -> ChallengeFormat:
	if format != null:
		return format
	if _default_format == null:
		_default_format = ChallengeFormat.new()
	return _default_format

## Returns the prize points earned at a given streak length.
func prize_for(streak: int) -> int:
	if prize_points <= 0:
		return 0
	var runs_held: int = maxi(streak / maxi(rounds, 1), 1)
	var paid: int = prize_points + ((runs_held - 1) * prize_points_per_run)
	return clampi(paid, 0, maxi(maximum_prize_points, prize_points))

# === Validation ===

## Returns complaints for a party that is entering the challenge.
func validate(party: PokemonParty) -> Array[String]:
	var complaints: Array[String] = []
	if party == null:
		return ["There is no party to enter."] as Array[String]
	var eligible: Array[Pokemon] = []
	for slot: int in range(party.size()):
		var member: Pokemon = party.get_member(slot)
		if member != null:
			eligible.append(member)
	if eligible.size() < party_size:
		complaints.append(Loc.line("You need {party_size} Pokemon to enter, and you have {eligible}.", {"party_size": party_size, "eligible": eligible.size()}))
	_check_members(eligible, complaints)
	_check_clauses(eligible, complaints)
	return complaints

## Returns whether the party can enter the challenge.
func is_legal(party: PokemonParty) -> bool:
	return validate(party).is_empty()

## Returns whether the selected party slots can enter the challenge.
func is_legal_selection(party: PokemonParty, slots: Array[int]) -> bool:
	return selection_complaints(party, slots).is_empty()

## Returns complaints for a selected set of party slots.
func selection_complaints(party: PokemonParty, slots: Array[int]) -> Array[String]:
	var complaints: Array[String] = []
	if party == null:
		return ["There is no party to enter."] as Array[String]
	if slots.size() != party_size:
		complaints.append(Loc.line("You must choose exactly {party_size} Pokemon.", {"party_size": party_size}))
	var chosen: Array[Pokemon] = []
	for slot: int in slots:
		var member: Pokemon = party.get_member(slot)
		if member == null:
			complaints.append("One of the Pokemon you chose is not there.")
			continue
		if chosen.has(member):
			complaints.append("You chose the same Pokemon twice.")
			continue
		chosen.append(member)
	_check_members(chosen, complaints)
	_check_clauses(chosen, complaints)
	return complaints

# === Helpers ===

func _check_members(members: Array[Pokemon], complaints: Array[String]) -> void:
	for member: Pokemon in members:
		var name_text: String = member.display_name()
		if member.is_egg() and not allow_eggs:
			complaints.append(Loc.line("{name_text} is still an Egg.", {"name_text": name_text}))
			continue
		if not member.is_able():
			complaints.append(Loc.line("{name_text} is in no shape to battle.", {"name_text": name_text}))
		if banned_species.has(member.species):
			complaints.append(Loc.line("{name_text} is not allowed here.", {"name_text": name_text}))
		if level_cap <= 0 and member.level() > maximum_level:
			complaints.append(Loc.line("{name_text} is above Lv{maximum_level}.", {"name_text": name_text, "maximum_level": maximum_level}))
		if not member.held_item.is_empty() and banned_items.has(member.held_item):
			complaints.append(Loc.line("{name_text} is holding something that is not allowed.", {"name_text": name_text}))

func _check_clauses(members: Array[Pokemon], complaints: Array[String]) -> void:
	if species_clause:
		var seen: Array[StringName] = []
		for member: Pokemon in members:
			if seen.has(member.species):
				complaints.append(Loc.line("You may only bring one {member}.", {"member": _species_name(member)}))
				continue
			seen.append(member.species)
	if not item_clause:
		return
	var held: Array[StringName] = []
	for member: Pokemon in members:
		if member.held_item.is_empty():
			continue
		if held.has(member.held_item):
			var record: ItemData = Database.item(member.held_item)
			complaints.append(Loc.line("Two of your Pokemon are holding a {record}.", {"record": (
				record.get_translated_name() if record != null else String(member.held_item))}))
			continue
		held.append(member.held_item)

func _species_name(pkmn: Pokemon) -> String:
	var record: SpeciesData = pkmn.species_data()
	return record.display_name if record != null else String(pkmn.species)

## Applies the level cap and refreshes the Pokemon's stats and health.
func apply_level_cap(pkmn: Pokemon) -> void:
	if level_cap <= 0 or pkmn == null or pkmn.level() == level_cap:
		return
	pkmn.set_level(level_cap)
	pkmn.calculate_stats()
	pkmn.heal()
