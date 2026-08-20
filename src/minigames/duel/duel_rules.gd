@tool
class_name DuelRules
extends Resource
## The rules of a scripted duel, their commands and what they do

## The commands, in the order they're displayed
@export var command_names: Array[String] = [
	"DEFEND", "PRECISE ATTACK", "FIERCE ATTACK", "SPECIAL ATTACK"
]

@export_range(1, 99) var starting_health = 10

## The command that may only be used once per combat
## `-1` for a duel where all the commands can be used as many times
@export var once_only_command: int = 3

## How likely the opponent is pick a command in the same order as [member command_names]
## A weight of `0` means it'll never be picked
@export var opponent_weights: PackedInt32Array = PackedInt32Array([3 , 4, 4, 2])

## What each pairing of commands does
## Checked in order
## The first row that matches is the one that occurs
@export var outcomes: Array[DuelOutcome] = []

@export_group("Presentation")
## The health bars and portraits
## Left empty there will be no health bars
@export var overlay_scene: PackedScene = null

## What is asked before every round
@export var prompt: String = "Choose a command."

## Seconds for a lunge or retreat
@export_range(0.05, 2.0) var move_seconds: float = 0.25

## Seconds for a screen shake for a delivered blow
@export_range(0.0, 2.0) var shake_seconds: float = 0.3

## The distance the screen shakes, in pixels
@export_range(0.0, 32.0) var shake_strength: float = 6.0

## Seconds a hit flash plays for
@export_range(0.0, 2.0) var flash_seconds: float = 0.25

## Seconds between rounds
@export_range(0.0, 4.0) var beat_seconds: float = 0.35


@export_group("Duel Sounds")
@export var hit_sound: String = "Battle damage normal"
@export var strong_hit_sound: String = "Battle damage super"
@export var miss_sound: String = "Battle flee"
@export var win_jingle: String = "Slots win"


func command_count() -> int:
	return command_names.size()
	
## The commands the player can choose from
## [param used_special] drops the once only command once it has been used
func commands_for(used_special: bool) -> Array[String]:
	var offered: Array[String] = []
	for index: int in range(command_names.size()):
		if used_special and index == once_only_command:
			continue
		offered.append(command_names[index])
	return offered
	
## Turns the index of a choice into the command it stands for
func command_of_choice(choice: int, used_special: bool) -> int:
	if not used_special or once_only_command < 0:
		return choice
	return choice if choice < once_only_command else choice + 1
	
## Rolls the opponent's command
func draw_opponent_command(used_special: bool) -> int:
	var total: int = 0
	for index: int in range(opponent_weights.size()):
		if used_special and index == once_only_command:
			continue
		total += maxi(opponent_weights[index], 0)
	if total <= 0:
		return 0
	var roll: int = RNG.below(total)
	for index: int in range(opponent_weights.size()):
		if used_special and index == once_only_command:
			continue
		roll -= maxi(opponent_weights[index], 0)
		if roll < 0:
			return index
	return 0
	
## The outcome for opponents [param action] and player's [param command]
func outcome_for(action: int, command: int) -> DuelOutcome:
	for row: DuelOutcome in outcomes:
		if row != null and row.matches(action, command):
			return row
	var nothing: DuelOutcome = DuelOutcome.new()
	nothing.message = "You circle eachother."
	return nothing
