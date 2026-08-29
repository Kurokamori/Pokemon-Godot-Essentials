class_name ChallengeInstinctFormat
extends ChallengeFormat
## Battle Palace instinct battles.

# === Battle Setup ===

func _init() -> void:
	entry_message = "Here your Pokemon fight on instinct. Choose them well; you cannot order them."

func configure_battle(battle: Battle, _runner: ChallengeRunner, _round_number: int) -> void:
	if not battle.instinct_sides.has(0):
		battle.instinct_sides.append(0)
