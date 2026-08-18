@tool
class_name HiddenItemEvent
extends MapEvent
## A Hidden Item, no sprite or collision
## Player finds it by pressing the action button on the exact cell
## Self-Switch keeps it hidden once collected

const TAKEN_SWITCH: String = "A"

## The marker that essentials used to denote hidden items, 
## used to allow importing maps and backwards compatibility
const IMPORTED_NAME_MARKER: String = "hiddenitem"

## The distance the Item Finder reaches in tiles
## Screen rather than Circle
const SEARCH_WIDTH: int = 8
const SEARCH_HEIGHT: int = 6

@export var item: StringName = &""
@export var quantity: int = 1

func active_trigger() -> EventPage.Trigger:
	return EventPage.Trigger.ACTION_BUTTON
	
func is_active() -> bool:
	if not super.is_active():
		return false
	if Engine.is_editor_hint():
		return true
	return not is_taken()
	
func is_taken() -> bool:
	return GameState.get_self_switch(_map_number(), self_switch_key(), TAKEN_SWITCH)
	
func has_action() -> bool:
	return is_active() and not String(item).is_empty()
	
func is_over_trigger() -> bool:
	return is_active()

func run() -> void:
	if String(item).is_empty():
		return
	await FieldItems.take_from_event(self, item, quantity)
	
## Item finder nearest item that hasn't been taken or `null` if there's nothing
## [param from] is a world cell, as [method GridCharacter.world_cell] gives it
static func closest_to(field: MapController, from: Vector2i) -> MapEvent:
	var closest: MapEvent = null
	var closest_distance: int = 0
	for event: MapEvent in field.every_event():
		if not is_hidden_item(event):
			continue
		var offset: Vector2i = event.world_cell() - from
		if absi(offset.x) >= SEARCH_WIDTH or absi(offset.y) >= SEARCH_HEIGHT:
			continue
		var distance: int = absi(offset.x) + absi(offset.y)
		if closest != null and closest_distance <= distance:
			continue
		closest = event
		closest_distance = distance
	return closest
	
## Return `true` if [param event] is a hidden item that has yet to be found
static func is_hidden_item(event: MapEvent) -> bool:
	if event == null or event.erased:
		return false
	if event is HiddenItemEvent:
		return not (event as HiddenItemEvent).is_taken()
	if not _name_marks_a_hidden_item(event.display_name()):
		return false	
	var map_number: int = event.map_scene.map_id if event.map_scene != null else GameState.map_id
	return not GameState.get_self_switch(map_number, event.self_switch_key(), TAKEN_SWITCH)
	
static func _name_marks_a_hidden_item(label: String) -> bool:
	return label.to_lower().replace(" ", "").contains(IMPORTED_NAME_MARKER)
	
func _map_number() -> int:
	return map_scene.map_id if map_scene != null else GameState.map_id
	
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super._get_configuration_warnings()
	if String(item).is_empty():
		warnings.append("This hidden item does not contain an item")
	return warnings
