@tool
class_name ItemEvent
extends MapEvent
## An item which is lying on the ground.

const TAKEN_SWITCH: String = "A"

@export var item: StringName = &""
@export var quantity: int = 1

@export_group("Presentation")
## Fanfare jingle played on pickup
@export var jingle: String = "Item get"

## The name of the pokeball whose graphic should be displayed
@export var ball_graphic: StringName = &"" 
# TODO hook this up to be automatic


func active_trigger() -> EventPage.Trigger:
	return EventPage.Trigger.ACTION_BUTTON
	
func is_active() -> bool:
	if not super.is_active():
		return false
	if Engine.is_editor_hint():
		return true
	return not GameState.get_self_switch(_map_number(), self_switch_key(), TAKEN_SWITCH)
	
func has_action() -> bool:
	return is_active() and not String(item).is_empty()
	
func run() -> void:
	var record: ItemData = Database.item(item)
	if record == null:
		push_error("ItemEvent '%s' names an item that does not exist: '%s'." % [display_name(), item])
		return
	var label: String = _item_label(record)
	if not GameState.bag.add_item(item, quantity):
		await Field.say(bag_full_message.replace("{item}", label))
		return
	if not jingle.is_empty():
		AudioManager.play_me(jingle)
	await Field.say(Loc.line("{player} found {label}!", {"player": _player_name(), "label": label}))
	Field.set_self_switch(self, TAKEN_SWITCH, true)

func _item_label(record: ItemData) -> String:
	if quantity > 1:
		return "%d %s" % [quantity, record.get_display_name(quantity)]
	return record.get_display_name(1)

func _player_name() -> String:
	return GameState.player.name if GameState.player != null else "You"

func _map_number() -> int:
	return map_scene.map_id if map_scene != null else 0

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super._get_configuration_warnings()
	if String(item).is_empty():
		warnings.append("This item event does not say which item it gives.")
	return warnings
