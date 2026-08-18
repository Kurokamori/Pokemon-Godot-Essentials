class_name ShadowSources
extends Node

## Every light that casts shadows

# TODO: rework how lamps actually write their lamp data -- it doesn't need to be comments

## The comment that marks an event as a lamp.
const SOURCE_MARKUP: String = "Shadow Source"

## The markup that marks an event as a shadow caster
const CASTER_MARKUP: String = "Shadow"

const COMMENT_CODE: int = 108
const COMMENT_CONTINUATION_CODE: int = 408

## How many parameters either markup takes.
const MAX_PARAMETERS: int = 4


## Every lamp among [param events].
static func collect(events: Array[MapEvent]) -> Array[ShadowSource]:
	var found: Array[ShadowSource] = []
	for event: MapEvent in events:
		var parameters: Array = []
		if _read_markup(event, SOURCE_MARKUP, parameters):
			found.append(ShadowSource.new(event, parameters))
	return found


## Returns `true` when [param event] is marked as something the lamps cast a shadow from
static func casts(event: MapEvent) -> bool:
	var parameters: Array = []
	return _read_markup(event, CASTER_MARKUP, parameters)


## Looks for `begin <markup>` among [param event]'s active page and fills [param out_parameters] with
## the `key value` comments under it.
static func _read_markup(event: MapEvent, markup: String, out_parameters: Array) -> bool:
	if not is_instance_valid(event):
		return false
	var page: EventPage = event.current_page()
	if page == null:
		return false
	var opening: String = ("begin " + markup).to_lower()
	var commands: Array[MapEventCommand] = page.commands
	for index: int in range(commands.size()):
		if not _is_comment(commands[index]) or _comment_text(commands[index]).to_lower() != opening:
			continue
		_read_parameters(commands, index, out_parameters)
		return true
	return false


## Fills [param out_parameters] from the comments following [param opening_index]
static func _read_parameters(
		commands: Array[MapEventCommand], opening_index: int, out_parameters: Array) -> void:
	for index: int in range(opening_index + 1, commands.size()):
		if not _is_comment(commands[index]):
			return
		var parts: PackedStringArray = _comment_text(commands[index]).split(" ", false)
		if parts.size() < 2 or parts[0].to_lower() == "begin":
			return
		out_parameters.append(_as_value(parts[1]))
		if out_parameters.size() >= MAX_PARAMETERS:
			return


static func _is_comment(command: MapEventCommand) -> bool:
	if command == null:
		return false
	if command.code != COMMENT_CODE and command.code != COMMENT_CONTINUATION_CODE:
		return false
	return command.parameters.size() > 0 and command.parameters[0] is String


static func _comment_text(command: MapEventCommand) -> String:
	return String(command.parameters[0]).strip_edges()


## Checks if the word is a numeric value, so that it's read properly
static func _as_value(word: String) -> Variant:
	if word.is_valid_int():
		return word.to_int()
	if word.is_valid_float():
		return word.to_float()
	return word
