class_name ChallengeFacilities
## Battle Frontier facility definitions.

# === Facilities ===

const FOLDER: String = "res://data/challenges"

## The standard Battle Tower facility.
const TOWER: StringName = &"BATTLETOWER"

## The doubles Battle Tower facility.
const TOWER_DOUBLES: StringName = &"BATTLETOWERDOUBLES"

## The Battle Factory facility.
const FACTORY: StringName = &"BATTLEFACTORY"

## The Battle Arena facility.
const ARENA: StringName = &"BATTLEARENA"

## The Battle Palace facility.
const PALACE: StringName = &"BATTLEPALACE"

## The Battle Dome facility.
const DOME: StringName = &"BATTLEDOME"

## The Battle Pike facility.
const PIKE: StringName = &"BATTLEPIKE"

## The Battle Pyramid facility.
const PYRAMID: StringName = &"BATTLEPYRAMID"

## All supported facility identifiers.
const ALL: Array[StringName] = [
	TOWER, TOWER_DOUBLES, FACTORY, ARENA, PALACE, DOME, PIKE, PYRAMID,
]

# === Lookup ===

## Loads stored rules or builds the facility defaults.
static func rules_for(facility: StringName) -> ChallengeRules:
	var path: String = "%s/%s.tres" % [FOLDER, String(facility).to_lower()]
	if ResourceLoader.exists(path):
		var stored: ChallengeRules = load(path) as ChallengeRules
		if stored != null:
			return stored
	return build(facility)

## Builds the default rules for a facility.
static func build(facility: StringName) -> ChallengeRules:
	match facility:
		TOWER:
			return ChallengeRules.tower()
		TOWER_DOUBLES:
			return ChallengeRules.double_tower()
		FACTORY:
			return _factory()
		ARENA:
			return _arena()
		PALACE:
			return _palace()
		DOME:
			return _dome()
		PIKE:
			return _pike()
		PYRAMID:
			return _pyramid()
	return null

# === Defaults ===

static func _factory() -> ChallengeRules:
	var rules: ChallengeRules = ChallengeRules.tower()
	rules.display_name = "Battle Factory"
	rules.facility_id = FACTORY
	var shape: ChallengeRentalFormat = ChallengeRentalFormat.new()
	shape.pool_size = 6
	rules.format = shape
	rules.prize_points = 4
	return rules

static func _arena() -> ChallengeRules:
	var rules: ChallengeRules = ChallengeRules.tower()
	rules.display_name = "Battle Arena"
	rules.facility_id = ARENA
	var shape: ChallengeJudgedFormat = ChallengeJudgedFormat.new()
	shape.rounds_before_judging = 3
	rules.format = shape
	rules.prize_points = 4
	return rules

static func _palace() -> ChallengeRules:
	var rules: ChallengeRules = ChallengeRules.tower()
	rules.display_name = "Battle Palace"
	rules.facility_id = PALACE
	rules.format = ChallengeInstinctFormat.new()
	rules.prize_points = 4
	return rules

static func _dome() -> ChallengeRules:
	var rules: ChallengeRules = ChallengeRules.tower()
	rules.display_name = "Battle Dome"
	rules.facility_id = DOME
	rules.rounds = 4
	rules.format = ChallengeTournamentFormat.new()
	rules.prize_points = 3
	return rules

static func _pike() -> ChallengeRules:
	var rules: ChallengeRules = ChallengeRules.tower()
	rules.display_name = "Battle Pike"
	rules.facility_id = PIKE
	rules.rounds = 14
	rules.heals_between_rounds = false
	rules.format = ChallengeGauntletFormat.new()
	rules.prize_points = 5
	return rules

static func _pyramid() -> ChallengeRules:
	var rules: ChallengeRules = ChallengeRules.tower()
	rules.display_name = "Battle Pyramid"
	rules.facility_id = PYRAMID
	rules.heals_between_rounds = false
	rules.format = ChallengeWildFormat.new()
	rules.prize_points = 5
	return rules
