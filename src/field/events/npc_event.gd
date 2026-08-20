@tool
class_name NpcEvent
extends MapEvent
## A simple NPC script, handles appearance and talking
## More involved NPCs need event pages or scripts

## Each entry is one message box
## `\n` starts a new line within the box
@export_multiline var lines: Array[String] = []

@export_group("After Talking")
## Self-switch turned on once the player has spoken to them.
## Left empty they'll say the same thing every time, set it and 
## create a second page conditioned on that switch for them to say something new.
@export_enum("A", "B", "C", "D") var self_switch_after: String = ""

## Turns back to the way they were facing once the conversation ends.
@export var restore_facing: bool = true


func active_trigger() -> EventPage.Trigger:
	return EventPage.Trigger.ACTION_BUTTON


func has_action() -> bool:
	return is_active() and (not lines.is_empty() or has_script())


func run() -> void:
	var original: Direction = facing
	for line: String in lines:
		await Field.say(line)
	if has_script():
		await EventScriptRunner.run_script(event_script(), self)
	if not self_switch_after.is_empty():
		Field.set_self_switch(self, self_switch_after, true)
	if restore_facing and not direction_fix:
		facing = original
