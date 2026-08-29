class_name ChallengeWildFormat
extends ChallengeFormat
## Battle Pyramid wild encounters.

# === Encounters ===

## The number of wild Pokemon encountered on each floor.
@export var wild_per_floor: int = 1

func _init() -> void:
	entry_message = "Nothing in here is anybody's. Nothing in here will heal you either."

# === Encounters ===

func run_round(runner: ChallengeRunner, round_number: int) -> BattlePresenter.Outcome:
	var wild: Array[Pokemon] = ChallengeOpponents.draw_wild(
		runner.session.rules, maxi(wild_per_floor, 1))
	if wild.is_empty():
		return BattlePresenter.Outcome.UNDECIDED
	runner.last_opponent = null
	var names: Array[String] = []
	for pkmn: Pokemon in wild:
		names.append(pkmn.display_name())
	await runner.say(Loc.line("Floor {round_number} of {rounds}: a wild {names}!", {"round_number": round_number, "rounds": runner.session.rules.rounds, "names": " and ".join(names)}))
	return await runner.fight_wild_pokemon(wild, round_number)
