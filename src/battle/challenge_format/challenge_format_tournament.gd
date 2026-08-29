class_name ChallengeTournamentFormat
extends ChallengeFormat
## Battle Dome tournament brackets.

# === Tournament ===

const BRACKET_KEY: String = "tournament_bracket"

## Shows the opposing team's species before each battle.
@export var shows_opponent_team: bool = true

func _init() -> void:
	entry_message = "The whole bracket is posted before the first match. Study it."

# === Bracket ===

func begin_run(runner: ChallengeRunner, party: PokemonParty) -> bool:
	if not await super.begin_run(runner, party):
		return false
	var bracket: Array[TrainerData] = _draw_bracket(runner)
	runner.scratch[BRACKET_KEY] = bracket
	if bracket.is_empty():
		return true
	var names: Array[String] = []
	for trainer: TrainerData in bracket:
		names.append(trainer.display_name)
	await runner.say(Loc.line("The field: {names}.", {"names": ", ".join(names)}))
	return true

func run_round(runner: ChallengeRunner, round_number: int) -> BattlePresenter.Outcome:
	var bracket: Array[TrainerData] = runner.scratch.get(BRACKET_KEY, [] as Array[TrainerData])
	if round_number > bracket.size():
		return await super.run_round(runner, round_number)
	var trainer: TrainerData = bracket[round_number - 1]
	runner.session.faced.append(trainer.id)
	runner.last_opponent = trainer
	await runner.say(Loc.line("Round {round_number} of {rounds}: {trainer}!", {"round_number": round_number, "rounds": runner.session.rules.rounds, "trainer": trainer.get_translated_name()}))
	if shows_opponent_team:
		await runner.say(Loc.line("{trainer} brings {trainer2}.", {"trainer": trainer.get_translated_name(), "trainer2": _team_text(trainer)}))
	return await runner.fight_trainer(trainer, round_number)

func _draw_bracket(runner: ChallengeRunner) -> Array[TrainerData]:
	var rules: ChallengeRules = runner.session.rules
	var bracket: Array[TrainerData] = []
	var faced: Array[StringName] = []
	for round_number: int in range(1, rules.rounds + 1):
		var trainer: TrainerData = ChallengeOpponents.draw(rules, round_number, faced)
		if trainer == null:
			break
		faced.append(trainer.id)
		bracket.append(trainer)
	return bracket

# === Helpers ===

func _team_text(trainer: TrainerData) -> String:
	var names: Array[String] = []
	for entry: TrainerPokemon in trainer.pokemon:
		var record: SpeciesData = Database.species(entry.species)
		names.append(record.display_name if record != null else String(entry.species))
	return ", ".join(names) if not names.is_empty() else "nobody at all"
