class_name ChallengeOpponents
## Selects and prepares Battle Frontier opponents.

# === Limits ===

const MINIMUM_ROSTER: int = 1

const MAXIMUM_DRAWS_PER_SLOT: int = 16

# === Opponent Selection ===

## Draws an opponent with enough Pokemon for the current round.
static func draw(rules: ChallengeRules, round_number: int, already_faced: Array[StringName]) -> TrainerData:
	var wanted: int = _roster_size_for(rules, round_number)
	var candidates: Array[StringName] = _candidates(wanted, already_faced)
	if candidates.is_empty():
		candidates = _candidates(wanted, [] as Array[StringName])
	while candidates.is_empty() and wanted > MINIMUM_ROSTER:
		wanted -= 1
		candidates = _candidates(wanted, [] as Array[StringName])
	if candidates.is_empty():
		var facility: StringName = rules.facility_id if rules != null else &"the facility"
		push_error("ChallengeOpponents.draw: %s has no trainer to send out at all." % facility)
		return null
	var picked: StringName = candidates[RNG.decide_range_int(0, candidates.size() - 1)]
	var source: TrainerData = Database.get_record(Database.CATEGORY_TRAINERS, picked) as TrainerData
	return rebuild(source, rules) if source != null else null

## Draws wild Pokemon for a facility encounter.
static func draw_wild(rules: ChallengeRules, count: int) -> Array[Pokemon]:
	var wild: Array[Pokemon] = []
	if rules == null or count <= 0:
		return wild
	var pool: Array[StringName] = _wild_species(rules, false)
	if pool.is_empty():
		pool = _wild_species(rules, true)
	if pool.is_empty():
		push_error(
			"ChallengeOpponents.draw_wild: %s has no species to draw from at all." % rules.facility_id
		)
		return wild
	var level: int = rules.level_cap if rules.level_cap > 0 else rules.maximum_level
	var attempts: int = 0
	while wild.size() < count and attempts < count * MAXIMUM_DRAWS_PER_SLOT and not pool.is_empty():
		attempts += 1
		var species: StringName = pool[RNG.decide_range_int(0, pool.size() - 1)]
		if Database.species(species) == null:
			pool.erase(species)
			continue
		wild.append(Pokemon.create(species, level))
	if wild.size() < count:
		push_error("ChallengeOpponents.draw_wild: %s could only find %d of %d wild Pokemon." % [
			rules.facility_id, wild.size(), count,
		])
	return wild

# === Helpers ===

static func _wild_species(rules: ChallengeRules, allow_banned: bool) -> Array[StringName]:
	var pool: Array[StringName] = []
	for id: StringName in Database.get_ids(Database.CATEGORY_SPECIES):
		if String(id).contains("_"):
			continue
		if not allow_banned and rules.banned_species.has(id):
			continue
		pool.append(id)
	return pool

static func _candidates(wanted: int, already_faced: Array[StringName]) -> Array[StringName]:
	var candidates: Array[StringName] = []
	for id: StringName in Database.get_ids(Database.CATEGORY_TRAINERS):
		if already_faced.has(id):
			continue
		var record: TrainerData = Database.get_record(Database.CATEGORY_TRAINERS, id) as TrainerData
		if record == null or record.pokemon.size() < wanted:
			continue
		candidates.append(id)
	return candidates

static func _roster_size_for(rules: ChallengeRules, round_number: int) -> int:
	if rules == null:
		return MINIMUM_ROSTER
	var full: int = maxi(rules.party_size, MINIMUM_ROSTER)
	if rules.rounds <= 1:
		return full
	var through: float = float(clampi(round_number, 1, rules.rounds) - 1) / float(rules.rounds - 1)
	return clampi(int(round(1.0 + through * float(full - 1))), MINIMUM_ROSTER, full)

## Applies challenge bans and level limits to a trainer copy.
static func rebuild(source: TrainerData, rules: ChallengeRules) -> TrainerData:
	if source == null:
		return null
	var built: TrainerData = source.duplicate(true) as TrainerData
	if rules == null:
		return built
	var roster: Array[TrainerPokemon] = []
	for entry: TrainerPokemon in built.pokemon:
		if entry == null or entry.species.is_empty():
			continue
		if rules.banned_species.has(entry.species):
			continue
		if roster.size() >= rules.party_size:
			break
		if rules.level_cap > 0:
			entry.level = rules.level_cap
		roster.append(entry)
	if roster.is_empty():
		for entry: TrainerPokemon in built.pokemon:
			if entry == null or entry.species.is_empty():
				continue
			if rules.level_cap > 0:
				entry.level = rules.level_cap
			roster.append(entry)
			if roster.size() >= rules.party_size:
				break
	built.pokemon = roster
	return built
