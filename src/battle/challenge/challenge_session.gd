class_name ChallengeSession
extends RefCounted
## Stores the state of a Battle Frontier run.

## Emitted when a new round starts.
signal round_started(round_number: int)

## Emitted after a round is won.
signal round_won(round_number: int)

## Emitted when the run ends.
signal finished(completed: bool)

# === State ===

## The rules for the current challenge.
var rules: ChallengeRules = null

## The current streak across completed runs.
var streak: int = 0

## The highest recorded streak.
var best_streak: int = 0

## The number of rounds won in the current run.
var wins: int = 0

## The number of rounds lost in the current run.
var losses: int = 0

## The round currently being played.
var current_round: int = 0

## Whether a challenge run is active.
var active: bool = false

## Tracks borrowed Pokemon during the run.
var loan: PartyLoan = PartyLoan.new()

## Copies of the player's original Pokemon.
var entered_originals: Array[Pokemon] = []

## Trainer identifiers already used in the run.
var faced: Array[StringName] = []

## Battle recordings made during the run.
var recordings: Array[BattleRecording] = []

## Whether the current team consists of rentals.
var rented: bool = false

# === Run Lifecycle ===

## Begins a challenge with selected party slots.
func begin(challenge_rules: ChallengeRules, party: PokemonParty, slots: Array[int]) -> bool:
	if challenge_rules == null or active:
		return false
	if not challenge_rules.is_legal_selection(party, slots):
		return false
	if not loan.take(party, slots):
		return false
	rules = challenge_rules
	entered_originals.clear()
	var fighters: Array[Pokemon] = []
	for member: Pokemon in party.members:
		entered_originals.append(member)
		var copy: Pokemon = Pokemon.from_dict(member.to_dict())
		rules.apply_level_cap(copy)
		fighters.append(copy)
	party.clear()
	for fighter: Pokemon in fighters:
		party.add(fighter)
	rented = false
	_start_run()
	return true

## Begins a challenge with a supplied rental team.
func begin_with_rentals(challenge_rules: ChallengeRules, party: PokemonParty, team: Array[Pokemon]) -> bool:
	if challenge_rules == null or active or party == null:
		return false
	if team.size() != challenge_rules.party_size:
		return false
	if not loan.take_all(party):
		return false
	rules = challenge_rules
	entered_originals.clear()
	for member: Pokemon in team:
		rules.apply_level_cap(member)
		party.add(member)
	rented = true
	_start_run()
	return true

func _start_run() -> void:
	faced.clear()
	recordings.clear()
	current_round = 0
	active = true

## Advances to the next round and emits [signal round_started].
func next_round() -> int:
	if not active or is_complete():
		return 0
	current_round += 1
	round_started.emit(current_round)
	return current_round

## Records a won round and updates the streak.
func win_round() -> void:
	if not active:
		return
	wins += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	round_won.emit(current_round)

## Records a lost round and ends the run.
func lose_round() -> void:
	if not active:
		return
	losses += 1
	streak = 0
	finish(false)

## Returns whether all configured rounds have been completed.
func is_complete() -> bool:
	return rules != null and current_round >= rules.rounds

## Ends the current run.
func finish(completed: bool) -> void:
	if not active:
		return
	active = false
	current_round = 0
	finished.emit(completed)

## Restores the party and returns any loaned Pokemon.
func leave(party: PokemonParty) -> void:
	if not entered_originals.is_empty():
		party.clear()
		for member: Pokemon in entered_originals:
			party.add(member)
		entered_originals.clear()
	loan.give_back(party, not rented)
	rented = false

## Stores a battle recording in the session.
func record_battle(recording: BattleRecording) -> void:
	if recording != null:
		recordings.append(recording)

# === Persistence ===

## Converts the session state to a saveable dictionary.
func to_dict() -> Dictionary:
	var replays: Array = []
	for recording: BattleRecording in recordings:
		replays.append(recording.to_dict())
	return {
		"streak": streak,
		"best_streak": best_streak,
		"wins": wins,
		"losses": losses,
		"current_round": current_round,
		"active": active,
		"rented": rented,
		"loan": loan.to_dict(),
		"entered_originals": _originals_to_array(),
		"faced": Array(faced),
		"recordings": replays,
	}

func _originals_to_array() -> Array:
	var members: Array = []
	for pkmn: Pokemon in entered_originals:
		members.append(pkmn.to_dict())
	return members

## Loads the session state from a dictionary.
func from_dict(source: Dictionary) -> void:
	streak = int(source.get("streak", 0))
	best_streak = int(source.get("best_streak", 0))
	wins = int(source.get("wins", 0))
	losses = int(source.get("losses", 0))
	current_round = int(source.get("current_round", 0))
	active = bool(source.get("active", false))
	rented = bool(source.get("rented", false))
	loan.from_dict(source.get("loan", {}) as Dictionary)
	entered_originals.clear()
	for entry: Variant in source.get("entered_originals", []):
		var pkmn: Pokemon = Pokemon.from_dict(entry as Dictionary)
		if pkmn != null:
			entered_originals.append(pkmn)
	faced.clear()
	for entry: Variant in source.get("faced", []):
		faced.append(StringName(entry))
	recordings.clear()
	for entry: Variant in source.get("recordings", []):
		var recording: BattleRecording = BattleRecording.from_dict(entry as Dictionary)
		if recording != null:
			recordings.append(recording)
