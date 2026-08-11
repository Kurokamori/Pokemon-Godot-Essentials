@tool
class_name MapEventCommand
extends Resource

## An instruction in an event page's script.
##
## Command numbers follow the RPG Maker XP event command set to fully port between Essentials and here.

## Command number, e.g. `101` for "Show Text"
@export var code: int = 0

## Nesting level, used for conditional branches and loops.
@export var indent: int = 0

## Command args, the shape depends on [member code]
@export var parameters: Array = []



func to_debug_string() -> String:
	# return "%s(%s)" % [MapEventCommands.name_for(code), parameters]
	# TODO: Enable once MapEventCommands actually exist
	return "You haven't made this possible yet."
