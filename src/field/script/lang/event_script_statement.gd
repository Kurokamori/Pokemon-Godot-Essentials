class_name EventScriptStatement
extends RefCounted
## One command in an event script and its child statements.

## Canonical command name.
var keyword: String = ""

## Original command spelling for errors.
var written_as: String = ""

var arguments: Array[EventScriptExpression] = []
var children: Array[EventScriptStatement] = []

## Source line number.
var line: int = 0

## Source file or resource.
var source_name: String = ""

func _init(
	of_keyword: String = "",
	at_line: int = 0,
	from_source: String = "",
	as_written: String = ""
) -> void:
	keyword = of_keyword
	line = at_line
	source_name = from_source
	written_as = as_written if not as_written.is_empty() else of_keyword

## Source location for warnings.
func where() -> String:
	if source_name.is_empty():
		return "line %d" % line
	return "%s:%d" % [source_name, line]

## First child with one of the given keywords.
func first_child_of(keywords: Array) -> EventScriptStatement:
	for child: EventScriptStatement in children:
		if keywords.has(child.keyword):
			return child
	return null

func argument(index: int) -> EventScriptExpression:
	return arguments[index] if index < arguments.size() else null

## Statement written as one line.
func to_source() -> String:
	var written: PackedStringArray = PackedStringArray()
	for expression: EventScriptExpression in arguments:
		written.append(expression.to_source())
	var head: String = written_as
	if not written.is_empty():
		head += " " + " ".join(written)
	return head + ":" if not children.is_empty() else head
