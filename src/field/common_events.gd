class_name CommonEvents
## The running command lists any map can call, as well as the ones that run themselves.

const CATEGORY: StringName = &"common_events"

## [param number]'s commands
## empty when there is no such event or it has none
static func commands_of(number: int) -> Array[MapEventCommand]:
	var record: CommonEventData = Database.common_event(number)
	return record.commands if record != null else ([] as Array[MapEventCommand])

## Returns `true` so long as common event [param number] has anything to run
static func exists(number: int) -> bool:
	return not commands_of(number).is_empty()
	
## Runs the provided common event [param number] and awaits it.
static func run_now( interpreter: EventInterpreter, number: int, source_event: MapEvent = null) -> bool:
	var commands: Array[MapEventCommand] = commands_of(number)
	if interpreter == null or commands.is_empty():
		return false
	await interpreter.run_commands(commands, source_event)
	return true
	
## The common event pending to run right now, or null
## Highest priority first, which means lowest number
static func pending_autorun() -> CommonEventData:
	return _first_waiting(CommonEventData.Trigger.AUTORUN)
	
## Every common event that should be running alongside the player currently
static func pending_parallel() -> Array[CommonEventData]:
	var found: Array[CommonEventData] = []
	for record: CommonEventData in all():
		if record.trigger == CommonEventData.Trigger.PARALLEL and record.is_waiting_to_run():
			found.append(record)
	return found

## Every common event the project has, in numerical order.
static func all() -> Array[CommonEventData]:
	var found: Array[CommonEventData] = []
	for record: GameDataResource in Database.get_all(CATEGORY):
		var common: CommonEventData = record as CommonEventData
		if common != null:
			found.append(common)
	found.sort_custom(func(a: CommonEventData, b: CommonEventData) -> bool:
		return a.event_id < b.event_id
	)
	return found

static func _first_waiting(trigger: CommonEventData.Trigger) -> CommonEventData:
	for record: CommonEventData in all():
		if record.trigger == trigger and record.is_waiting_to_run():
			return record
	return null
