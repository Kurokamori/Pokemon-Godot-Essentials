@tool
class_name EventPage
extends Node
## One page of a map event
## Pages are children of [MapEvent], in priority order.
## The last page conditions are met is the active one.
##
## A page can get behaviour one of 4 ways:
## Plain-text script either directly in the editor or as an attached .evt file (when those are added)
## A list of [MapEventCommand]s
## Or a page can have its own GDScript which overwrites [mehtod run]
## -- this allows you to define custom behaviour as you would in straight GDScript
## -- should extend EventPage

enum Trigger {
	ACTION_BUTTON = 0,
	PLAYER_TOUCH = 1,
	EVENT_TOUCH = 2,
	AUTORUN = 3,
	PARALLEL = 4
}

enum MoveType {
	FIXED = 0,
	RANDOM = 1,
	APPROACH = 2,
	CUSTOM = 3,
}


@export_group("Conditions")
## Game switch that must be `ON` for this page to run
## `0` for no condition
@export var required_switch_a: int = 0:
	set(value):
		required_switch_a = value
		_preview_changed()
		
## Secondary game switch that must be `ON` for this page to run
## `0` for no condition
@export var required_switch_b: int = 0:
	set(value):
		required_switch_b = value
		_preview_changed()
		
## Game variable that must have reached [member required_variable_value]
## `0` for no condition
@export var required_variable: int = 0:
	set(value):
		required_variable = value
		_preview_changed()
		
@export var required_variable_value: int = 0

## Self Switch that must be ON
## Empty for no condition
@export_custom(PROPERTY_HINT_ENUM, "A,B,C,D") var required_self_switch: String = "":
	set(value):
		required_self_switch = value
		_preview_changed()
		
@export_group("Appearance")
## Character sheet under `assets/graphics/characters/`
## Empty draws nothing
@export var charset: String = "":
	set(value):
		charset = value
		_preview_changed()
		
@export var direction: GridCharacter.Direction = GridCharacter.Direction.DOWN:
	set(value):
		direction = value
		_preview_changed()
		
@export_range(0, 255) var opacity: int = 255:
	set(value):
		opacity = value
		_preview_changed()
		
## Draws over the player whatever the two are standing on.
@export var always_on_top: bool = false:
	set(value):
		always_on_top = value
		_preview_changed()
		
## Other characters may walk through the event.
@export var passable: bool = false

@export_group("Movement")
@export var move_type: MoveType = MoveType.FIXED

@export_range(1, 6) var move_speed: int = 3

@export_range(1, 6) var move_frequency: int = 3

## Keeps facing one way, even when spoken to or moved.
@export var direction_fix: bool = false

## Animates on the spot while standing still.
@export var step_animation: bool = false

## The route walked when [member move_type] is [constant MoveType.CUSTOM].
@export var move_route: Array[MapEventCommand] = []

@export var move_route_repeats: bool = true

@export_group("Script")
@export var trigger: Trigger = Trigger.ACTION_BUTTON

## A plain-text event script file
@export_file("*.evt", "*.txt", "*.tres") var script_file: String = "":
	set(value):
		script_file = value
		_script = null
		_script_changed()
		
## An event script written straight into the page
## Ignored when [member script_file] is set.
@export_multiline var script_source: String = "":
	set(value):
		script_source = value
		_script = null
		_script_changed()
		
@export var commands: Array[MapEventCommand] = []

## The compiled script
var _script: EventScript = null

## Returns `true` when this page's conditions are currently satisfied.
func conditions_met(map_id: int, event_key: String) -> bool:
	if Engine.is_editor_hint():
		return true
	if required_switch_a > 0 and not GameState.get_switch(required_switch_a):
		return false
	if required_switch_b > 0 and not GameState.get_switch(required_switch_b):
		return false
	if required_variable > 0 and int(GameState.get_variable(required_variable)) < required_variable_value:
		return false
	if not required_self_switch.is_empty():
		if not GameState.get_self_switch(map_id, event_key, required_self_switch):
			return false
	return true


## Returns `true` if this is the defaultly active page
func is_initially_active() -> bool:
	if required_switch_a > 0 or required_switch_b > 0:
		return false
	if required_variable > 0:
		return false
	return required_self_switch.is_empty()


## Returns `true` when the page draws nothing
func is_invisible() -> bool:
	return charset.is_empty()


## Returns the event script this page runs
## Returns `null` when there isn't one
func event_script() -> EventScript:
	_script = EventScript.resolve(script_file, script_source, String(name), _script)
	return _script


## Returns `true` if the event has any kind of actions (event list/ script/ GDScript)
func has_action() -> bool:
	if not commands.is_empty() or get_script() != EventPage:
		return true
	var script: EventScript = event_script()
	return script != null and not script.is_blank()


## Runs the page.
func run(event: MapEvent) -> void:
	var script: EventScript = event_script()
	if script != null and not script.is_blank():
		await EventScriptRunner.run_script(script, event)
		return
	if commands.is_empty():
		return
	var interpreter: EventInterpreter = event.interpreter() if event != null else null
	if interpreter == null:
		push_warning("EventPage: '%s' has no interpreter to run its commands on." % name)
		return
	await interpreter.run_commands(commands, event)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if not script_file.is_empty() and not script_source.strip_edges().is_empty():
		warnings.append(
			"This page has both a Script File and a Script Source. The file is used; clear the other one."
		)
	if not script_file.is_empty() and not FileAccess.file_exists(script_file):
		warnings.append("There is no script file at %s." % script_file)
	var script: EventScript = event_script()
	if script != null and script.program().has_errors():
		warnings.append(
			"This pages script does not read: %s" % "; ".join(script.program().errors)
		)
	if not commands.is_empty() and script != null and not script.is_blank():
		warnings.append(
			"This page has both a script and an imported command list. The script is used."
		)
	return warnings


# === Internals ===

## Rechecks a script on update, to parse check it before runtime
func _script_changed() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()

## Redraws the owning event to update with page changes
func _preview_changed() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var event: MapEvent = get_parent() as MapEvent
	if event != null:
		event.refresh_editor_appearance()
