@tool
class_name CommonEventData
extends GameDataResource
## A common event like the ones that exist in RPG Maker
## A command list that either can be called or run itself

## When a common event runs on its own if it ever does.
enum Trigger {
	## Only when something explicitly calls it
	NONE = 0,
	## While [member switch_id] is switched on
	AUTORUN = 1,
	## While [member switch_id] is switched on alongside the player
	PARALLEL = 2,
}

## The event number
@export var event_id: int = 0

@export var trigger: Trigger = Trigger.NONE

## The switch the event trigger waits on, ignored when Trigger.NONE
@export var switch_id: int = 0

@export var commands: Array[MapEventCommand] = []


## Builds the GameData record id for [param number]
static func make_id(number: int) -> StringName:
	return StringName(str(number))
	
## Returns `true` when this event runs itself once the switch is set on
func runs_on_its_own() -> bool:
	return trigger != Trigger.NONE

## Returns `true` when the common event should currently be running
func is_waiting_to_run() -> bool:
	if not runs_on_its_own() or commands.is_empty():
		return false
	if switch_id <= 0:
		return false
	return GameState.get_switch(switch_id)
