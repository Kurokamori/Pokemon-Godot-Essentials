@tool
class_name DuelOutcome
extends Resource
## One row in the Duel's outcome table

const ANY: int = -1

enum Beat {
	STUDY,
	PLAYER_HITS,
	OPPONENT_HITS,
	CLASH,
	PLAYER_EVADES,
	OPPONENT_EVADES,
	PLAYER_PIERCES,
	OPPONENT_PIERCES,
	SPECIAL_CLASH,
}

@export var opponent_action: int = ANY
@export var player_command: int = ANY

@export_multiline var message: String = ""

@export_group("Damage")
@export_range(0, 20) var player_damage: int = 0
@export_range(0, 20) var opponent_damage: int = 0

@export_group("Presentation")
@export var beat: Beat = Beat.STUDY

func matches(action: int, command: int) -> bool:
	if opponent_action != ANY and opponent_action != action:
		return false
	return player_command == ANY or player_command == command
