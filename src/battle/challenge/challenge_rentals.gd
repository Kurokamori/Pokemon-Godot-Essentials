class_name ChallengeRentals
## Builds rental Pokemon for the Battle Factory.

# === Limits ===

const MAXIMUM_DRAWS: int = 400

# === Rentals ===

## Draws a pool of rental Pokemon with unique species where possible.
static func draw_pool(rules: ChallengeRules, count: int) -> Array[Pokemon]:
	var pool: Array[Pokemon] = []
	if rules == null or count <= 0:
		return pool
	var candidates: Array[Dictionary] = _candidate_entries(rules, false)
	if candidates.is_empty():
		candidates = _candidate_entries(rules, true)
	if candidates.is_empty():
		push_error(
			"ChallengeRentals.draw_pool: %s has no trainer Pokemon to rack up." % rules.facility_id
		)
		return pool
	var taken_species: Array[StringName] = []
	var passed_over: Array[Dictionary] = []
	var draws: int = 0
	while pool.size() < count and draws < MAXIMUM_DRAWS and not candidates.is_empty():
		draws += 1
		var index: int = RNG.decide_range_int(0, candidates.size() - 1)
		var entry: Dictionary = candidates[index]
		candidates.remove_at(index)
		var species: StringName = StringName(entry["species"])
		if taken_species.has(species):
			passed_over.append(entry)
			continue
		var built: Pokemon = build(entry["pokemon"] as TrainerPokemon, entry["trainer"] as TrainerData, rules)
		if built == null:
			continue
		taken_species.append(species)
		pool.append(built)
	while pool.size() < count and not passed_over.is_empty():
		var entry: Dictionary = passed_over.pop_back()
		var built: Pokemon = build(entry["pokemon"] as TrainerPokemon, entry["trainer"] as TrainerData, rules)
		if built != null:
			pool.append(built)
	if pool.size() < count:
		push_error("ChallengeRentals.draw_pool: %s could only rack up %d of %d Pokemon." % [
			rules.facility_id, pool.size(), count,
		])
	return pool

## Builds rental Pokemon from every usable member of a trainer's team.
static func from_trainer(trainer: TrainerData, rules: ChallengeRules) -> Array[Pokemon]:
	var offered: Array[Pokemon] = []
	if trainer == null:
		return offered
	for entry: TrainerPokemon in trainer.pokemon:
		var built: Pokemon = build(entry, trainer, rules)
		if built != null:
			offered.append(built)
	return offered

## Builds one unowned and fully healed rental Pokemon.
static func build(entry: TrainerPokemon, trainer: TrainerData, rules: ChallengeRules) -> Pokemon:
	if entry == null or entry.species.is_empty():
		return null
	if Database.species(entry.species) == null:
		return null
	var built: Pokemon = TrainerBuilder.build_pokemon(entry, trainer)
	if built == null:
		return null
	built.owner = PokemonOwner.create_unowned()
	if rules != null:
		rules.apply_level_cap(built)
	built.heal()
	return built

# === Helpers ===

static func _candidate_entries(rules: ChallengeRules, allow_banned: bool) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id: StringName in Database.get_ids(Database.CATEGORY_TRAINERS):
		var record: TrainerData = Database.get_record(Database.CATEGORY_TRAINERS, id) as TrainerData
		if record == null:
			continue
		for member: TrainerPokemon in record.pokemon:
			if member == null or member.species.is_empty():
				continue
			if not allow_banned and rules.banned_species.has(member.species):
				continue
			entries.append({
				"species": member.species,
				"pokemon": member,
				"trainer": record,
			})
	return entries
