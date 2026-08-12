@tool
class_name PhoneMessageData
extends GameDataResource

## Phone call dailogue for a given trainer type or the shared `default` set.
##
## Message text supports the same escape codes as ordinary dialogue plus :
## `\TN` (trianer name)
## `\PN` (player name)
## `\TP` (a party pokemon of the caller)
## `\TE` (a wild Pokemon the caller mentions)
## `\TM` (the map which the caller resides on)
##
## A line may be several messages in one, seperated by `\m`
## [PhoneCall] will split on `\m`, so each page is its own call.

## ID of a [TrainerTypeData] record, or `default` / `defaultBattleRequest`
@export var trainer_type: StringName = &""

## Distinguishes the different callers sharing a single trainer type.
@export var version: int = 0

# TODO: Add better docstrings to this file.
@export_group("Greeting")
@export var intro: Array[String] = []
@export var intro_morning: Array[String] = []
@export var intro_afternoon: Array[String] = []
@export var intro_evening: Array[String] = []

@export_group("Conversation")
@export var body: Array[String] = []
@export var body1: Array[String] = []
@export var body2: Array[String] = []
@export var battle_request: Array[String] = []

## the 'nagging' said after the first battle request, said instead of repeating the request.
## falls back to [member battle_request]
@export var battle_remind: Array[String] = []

@export var greeting: Array[String] = []
@export var greeting_time: Array[String] = []
@export var bumb: Array[String] = []
@export var end: Array[String] = []


## Picks one random line from [param lines], or an empty string.
static func pick(lines: Array[String], rng: RandomNumberGenerator) -> String:
	if lines.is_empty():
		return ""
	return lines[rng.randi_range(0, lines.size() - 1)]
	
## Picks one random line from [param lines] and translates it.
##
## The instance method rather than [method pick] is what should be used
func pick_translated(lines: Array[String], rng: RandomNumberGenerator) -> String:
	return translate_field(pick(lines, rng))
