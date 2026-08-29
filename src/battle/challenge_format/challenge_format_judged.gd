class_name ChallengeJudgedFormat
extends ChallengeFormat
## Battle Arena judged battles.

# === Battle Setup ===

## The number of battle rounds before the judge decides.
@export var rounds_before_judging: int = 3

func _init() -> void:
	entry_message = "Three rounds, then the judges decide. Attack, and make it count."

# === Battle Setup ===

func configure_battle(battle: Battle, _runner: ChallengeRunner, _round_number: int) -> void:
	battle.round_limit = maxi(rounds_before_judging, 1)
	battle.judge = BattleJudge.new()
