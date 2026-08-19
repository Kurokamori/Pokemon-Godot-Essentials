class_name EventInterpreter
extends Node
## Executes an event page's command list

signal event_started(event_name: String)
signal event_finished(event_name: String)

## The field which this event interpreter belongs to
var map: MapController = null

var _running: bool = false
var _commands: Array[MapEventCommand] = []
var _pointer: int = 0
var _current_event: MapEvent = null
var _labels: Dictionary = {}
var _choice_result: int = -1
var _choice_renames: Dictionary = {}
var _choice_hides: Dictionary = {}
var _choice_group_ends: Array[int] = []
var _reported_unsupported: Dictionary = {}
var _pending_text: String = ""
var _script_bridge: EventScriptBridge = null
