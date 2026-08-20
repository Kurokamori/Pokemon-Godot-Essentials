@tool
class_name MinigameEntry
extends Resource
## One playable game in [MinigameLibrary]

## What the code is that events ask for this minigame by
@export var id: StringName = &""

## Shown wherever the game names itself
@export var display_name: String = ""

## The screen the game is played on
## It must be a [MinigameScreen] or atleast have closed signal
@export var scene: PackedScene = null

## Said to the player when [member scene] is missing
@export var unavailable_message: String = ""


func is_playable() -> bool:
	return scene != null

func title() -> String:
	return display_name if not display_name.is_empty() else String(id)

func excuse() -> String:
	if not unavailable_message.is_empty():
		return unavailable_message
	return Loc.line("{title} is out of order.", {"title": title()})
