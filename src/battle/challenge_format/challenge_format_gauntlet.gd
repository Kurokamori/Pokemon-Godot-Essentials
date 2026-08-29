class_name ChallengeGauntletFormat
extends ChallengeFormat
## Battle Pike room selection and encounters.

# === Rooms ===

enum Room {
	TRAINER = 0,
	WILD = 1,
	REST = 2,
	EMPTY = 3,
}

## Relative chances for trainer, wild, rest, and empty rooms.
@export var room_weights: Array[int] = [50, 25, 15, 10]

func _init() -> void:
	entry_message = "Pick a door. We heal nobody in here."

# === Encounters ===

func run_round(runner: ChallengeRunner, round_number: int) -> BattlePresenter.Outcome:
	match _draw_room():
		Room.WILD:
			return await _wild_room(runner, round_number)
		Room.REST:
			return await _rest_room(runner)
		Room.EMPTY:
			return await _empty_room(runner)
	return await super.run_round(runner, round_number)

func _wild_room(runner: ChallengeRunner, round_number: int) -> BattlePresenter.Outcome:
	var wild: Array[Pokemon] = ChallengeOpponents.draw_wild(
		runner.session.rules, runner.session.rules.battlers_per_side)
	if wild.is_empty():
		return await super.run_round(runner, round_number)
	runner.last_opponent = null
	await runner.say("Something was waiting in here!")
	return await runner.fight_wild_pokemon(wild, round_number)

func _rest_room(runner: ChallengeRunner) -> BattlePresenter.Outcome:
	await runner.say("There's a nurse in here. Your Pokemon are restored to full health!")
	if runner.party != null:
		runner.party.heal_all()
	return BattlePresenter.Outcome.PLAYER_WON

func _empty_room(runner: ChallengeRunner) -> BattlePresenter.Outcome:
	await runner.say("Nothing in here. On to the next door.")
	return BattlePresenter.Outcome.PLAYER_WON

# === Helpers ===

func _draw_room() -> Room:
	var total: int = 0
	for weight: int in room_weights:
		total += maxi(weight, 0)
	if total <= 0:
		return Room.TRAINER
	var roll: int = RNG.decide_range_int(1, total)
	var running: int = 0
	for index: int in range(room_weights.size()):
		running += maxi(room_weights[index], 0)
		if roll <= running:
			return index as Room
	return Room.TRAINER
