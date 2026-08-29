class_name ChallengeRunner
extends RefCounted
## Runs a Battle Frontier challenge.

# === Callbacks ===

## The session being run.
var session: ChallengeSession = null

## Starts a trainer battle.
var fight: Callable = Callable()

## Starts a wild battle.
var fight_wild: Callable = Callable()

## Displays challenge dialogue.
var narrate: Callable = Callable()

## Displays choices and returns the selected index.
var ask: Callable = Callable()

## Heals the player's party.
var heal: Callable = Callable()

## Keeps battle recordings for the session.
var keep_recordings: bool = false

## The party used for the challenge.
var party: PokemonParty = null

## The trainer used in the latest trainer battle.
var last_opponent: TrainerData = null

## Temporary data shared by challenge formats.
var scratch: Dictionary = {}

## The recording from the latest battle.
var last_recording: BattleRecording = null

func _init(for_session: ChallengeSession = null, with_party: PokemonParty = null) -> void:
	session = for_session
	party = with_party

## Returns the format used by the current session.
func format() -> ChallengeFormat:
	return session.rules.shape() if session != null and session.rules != null else null

# === Entry ===

## Starts a challenge and lets its format choose the entry flow.
func enter(challenge_rules: ChallengeRules) -> bool:
	if session == null or challenge_rules == null or session.active:
		return false
	session.rules = challenge_rules
	var shape: ChallengeFormat = challenge_rules.shape()
	if not shape.entry_message.is_empty():
		await say(shape.entry_message)
	scratch.clear()
	return await shape.begin_run(self, party)

## Asks the player to choose the required team slots.
func choose_team() -> Array[int]:
	var rules: ChallengeRules = session.rules
	var chosen: Array[int] = []
	while chosen.size() < rules.party_size:
		var options: Array = []
		var slots: Array[int] = []
		for slot: int in range(party.size()):
			if chosen.has(slot):
				continue
			var member: Pokemon = party.get_member(slot)
			if member == null:
				continue
			options.append(member.display_name())
			slots.append(slot)
		if options.is_empty():
			return [] as Array[int]
		var picked: int = await ask_options(options, Loc.line("Choose Pokemon {chosen} of {party_size}.", {"chosen": chosen.size() + 1, "party_size": rules.party_size}))
		if picked < 0 or picked >= slots.size():
			return [] as Array[int]
		chosen.append(slots[picked])
	var complaints: Array[String] = rules.selection_complaints(party, chosen)
	if complaints.is_empty():
		return chosen
	await say(complaints[0])
	return await choose_team()

# === Run ===

## Runs rounds until the challenge is won or lost.
func run() -> bool:
	if session == null or session.rules == null or not session.active:
		return false
	if not fight.is_valid():
		push_error("ChallengeRunner: nothing was given to fight with.")
		return false
	var shape: ChallengeFormat = format()
	while not session.is_complete():
		var round_number: int = session.next_round()
		if round_number <= 0:
			break
		last_opponent = null
		var outcome: BattlePresenter.Outcome = await shape.run_round(self, round_number)
		_keep_recording()
		if outcome == BattlePresenter.Outcome.UNDECIDED:
			await say("There is nobody left to battle.")
			session.finish(false)
			shape.on_finished(self, false)
			return false
		if outcome != BattlePresenter.Outcome.PLAYER_WON:
			session.lose_round()
			await say(Loc.line("Your challenge ends here. You won {wins} in a row.", {"wins": session.wins}))
			shape.on_finished(self, false)
			return false
		session.win_round()
		@warning_ignore("redundant_await")
		await shape.on_round_won(self, round_number)
		if not session.is_complete():
			await _heal_party()
			if session.rules.heals_between_rounds:
				await say(Loc.line("Your Pokemon have been restored. {round_number} to go!", {"round_number": (
					session.rules.rounds - round_number)}))
	session.finish(true)
	await say(Loc.line("You beat all {rounds}! Your streak stands at {streak}.", {"rounds": session.rules.rounds, "streak": session.streak}))
	shape.on_finished(self, true)
	return true

# === Battles ===

## Starts a trainer battle for a challenge round.
func fight_trainer(trainer: TrainerData, round_number: int) -> BattlePresenter.Outcome:
	if not fight.is_valid():
		return BattlePresenter.Outcome.UNDECIDED
	return await fight.call(trainer, round_number, battle_setup(round_number))

## Starts a wild battle for a challenge round.
func fight_wild_pokemon(wild: Array[Pokemon], round_number: int) -> BattlePresenter.Outcome:
	if not fight_wild.is_valid():
		push_warning("ChallengeRunner: this facility fights wild Pokemon and nothing was given to fight them with.")
		return BattlePresenter.Outcome.PLAYER_WON
	return await fight_wild.call(wild, round_number, battle_setup(round_number))

## Returns the battle setup callback for a challenge round.
func battle_setup(round_number: int) -> Callable:
	return prepare_battle.bind(round_number)

func prepare_battle(battle: Battle, round_number: int) -> void:
	last_recording = null
	if battle == null:
		return
	var shape: ChallengeFormat = format()
	if shape != null:
		shape.configure_battle(battle, self, round_number)
	if not keep_recordings:
		return
	last_recording = BattleRecording.start(battle, "%s, battle %d" % [
		session.rules.display_name, round_number,
	])
	battle.recording = last_recording

func _keep_recording() -> void:
	if last_recording == null:
		return
	session.record_battle(last_recording)
	last_recording = null

func _heal_party() -> void:
	if session.rules != null and not session.rules.heals_between_rounds:
		return
	if heal.is_valid():
		await heal.call()
		return
	if party != null:
		party.heal_all()

# === Dialogue ===

## Shows a line of challenge dialogue.
func say(text: String) -> void:
	if narrate.is_valid():
		await narrate.call(text)

## Shows a list of choices and returns the selected index.
func ask_options(options: Array, prompt: String = "") -> int:
	if not ask.is_valid() or options.is_empty():
		return -1
	return await ask.call(options, prompt)

## Asks a yes or no question.
func confirm(question: String) -> bool:
	return await ask_options(["Yes", "No"], question) == 0
