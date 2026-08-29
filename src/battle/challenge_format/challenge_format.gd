class_name ChallengeFormat
extends Resource
## Defines facility-specific battle behavior.

# === Hooks ===

## Message shown when the player enters the facility.
@export_multiline var entry_message: String = ""

# === Default Behavior ===

## Starts a standard challenge run by choosing a team.
func begin_run(runner: ChallengeRunner, party: PokemonParty) -> bool:
	var slots: Array[int] = await runner.choose_team()
	if slots.is_empty():
		return false
	if runner.session.begin(runner.session.rules, party, slots):
		return true
	await runner.say("That team can't enter.")
	return false

## Runs a standard trainer battle round.
func run_round(runner: ChallengeRunner, round_number: int) -> BattlePresenter.Outcome:
	var trainer: TrainerData = ChallengeOpponents.draw(
		runner.session.rules, round_number, runner.session.faced)
	if trainer == null:
		return BattlePresenter.Outcome.UNDECIDED
	runner.session.faced.append(trainer.id)
	runner.last_opponent = trainer
	await runner.say(Loc.line("Battle {round_number} of {rounds}: {trainer}!", {"round_number": round_number, "rounds": runner.session.rules.rounds, "trainer": trainer.get_translated_name()}))
	return await runner.fight_trainer(trainer, round_number)

## Configures a battle before it starts.
func configure_battle(_battle: Battle, _runner: ChallengeRunner, _round_number: int) -> void:
	pass

## Runs after a round is won.
func on_round_won(_runner: ChallengeRunner, _round_number: int) -> void:
	pass

## Runs when the challenge ends.
func on_finished(_runner: ChallengeRunner, _completed: bool) -> void:
	pass

## Returns whether this format supplies rental Pokemon.
func rents_team() -> bool:
	return false
