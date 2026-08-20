@tool
class_name SignEvent
extends MapEvent
## A signpost, notice board, bookshelf, anything where the interaction is essentially reading

## Each entry is its own message box,
## `\n` starts a new line within the same box
@export_multiline var lines: Array[String] = []

func active_trigger() -> EventPage.Trigger:
	return EventPage.Trigger.ACTION_BUTTON
	
func has_action() -> bool:
	return is_active() and not lines.is_empty()
	
func run() -> void:
	for line: String in lines:
		await Field.say(line)
		
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super._get_configuration_warnings()
	if lines.is_empty():
		warnings.append("This sign has nothing written on it.")
	return warnings
