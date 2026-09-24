class_name EventScriptProgram
extends RefCounted
## A parsed event script and its routines.

## Statements to run when the script starts.
var statements: Array[EventScriptStatement] = []

## Named routine blocks.
var routines: Dictionary = {}

## Parse errors, with their source line numbers.
var errors: PackedStringArray = PackedStringArray()

## Name shown in warnings.
var source_name: String = ""

func has_errors() -> bool:
	return not errors.is_empty()

## Whether there are statements to run.
func is_empty() -> bool:
	return statements.is_empty()

func routine(name: String) -> Array:
	return routines.get(name, [])

func has_routine(name: String) -> bool:
	return routines.has(name)

## Writes parse errors to the output panel.
func report_errors() -> void:
	if errors.is_empty():
		return
	var where: String = source_name if not source_name.is_empty() else "event script"
	push_error("%s: %s" % [where, "\n  ".join(errors)])
