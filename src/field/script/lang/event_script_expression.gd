class_name EventScriptExpression
extends RefCounted
## One value in an event script.

enum Kind {
	## A literal value.
	LITERAL,
	## A bare name, local, or builtin.
	IDENTIFIER,
	## A builtin call.
	CALL,
	## A unary operation.
	UNARY,
	## A binary operation.
	BINARY,
	## Text with interpolated expressions.
	TEXT,
}

var kind: Kind = Kind.LITERAL

## Literal value, name, or operator.
var value: Variant = null

## Arguments or operands.
var operands: Array[EventScriptExpression] = []

## Text chunks and expressions.
var parts: Array = []

## Source line number.
var line: int = 0

static func literal(of_value: Variant, at_line: int = 0) -> EventScriptExpression:
	var made: EventScriptExpression = EventScriptExpression.new()
	made.kind = Kind.LITERAL
	made.value = of_value
	made.line = at_line
	return made

static func identifier(name: String, at_line: int = 0) -> EventScriptExpression:
	var made: EventScriptExpression = EventScriptExpression.new()
	made.kind = Kind.IDENTIFIER
	made.value = name
	made.line = at_line
	return made

static func call_function(
	name: String, arguments: Array[EventScriptExpression], at_line: int = 0
) -> EventScriptExpression:
	var made: EventScriptExpression = EventScriptExpression.new()
	made.kind = Kind.CALL
	made.value = name
	made.operands = arguments
	made.line = at_line
	return made

static func unary(operator: String, operand: EventScriptExpression, at_line: int = 0) -> EventScriptExpression:
	var made: EventScriptExpression = EventScriptExpression.new()
	made.kind = Kind.UNARY
	made.value = operator
	made.operands = [operand] as Array[EventScriptExpression]
	made.line = at_line
	return made

static func binary(
	operator: String,
	left: EventScriptExpression,
	right: EventScriptExpression,
	at_line: int = 0
) -> EventScriptExpression:
	var made: EventScriptExpression = EventScriptExpression.new()
	made.kind = Kind.BINARY
	made.value = operator
	made.operands = [left, right] as Array[EventScriptExpression]
	made.line = at_line
	return made

static func text(of_parts: Array, at_line: int = 0) -> EventScriptExpression:
	var made: EventScriptExpression = EventScriptExpression.new()
	made.kind = Kind.TEXT
	made.parts = of_parts
	made.line = at_line
	return made

## Evaluates this expression.
func evaluate(runner: EventScriptRunner) -> Variant:
	match kind:
		Kind.LITERAL:
			return value
		Kind.TEXT:
			var built: String = ""
			for part: Variant in parts:
				if part is EventScriptExpression:
					built += EventScriptCast.to_text((part as EventScriptExpression).evaluate(runner))
				else:
					built += String(part)
			return built
		Kind.IDENTIFIER:
			return _evaluate_identifier(runner)
		Kind.CALL:
			var arguments: Array = []
			for operand: EventScriptExpression in operands:
				arguments.append(operand.evaluate(runner))
			return runner.call_builtin(String(value), arguments, line)
		Kind.UNARY:
			var single: Variant = operands[0].evaluate(runner)
			match String(value):
				"not":
					return not EventScriptCast.to_bool(single)
				"-":
					return -EventScriptCast.to_number(single)
				"+":
					return EventScriptCast.to_number(single)
		Kind.BINARY:
			return _evaluate_binary(runner)
	return null

## Resolves a name as a local, builtin, or id.
func _evaluate_identifier(runner: EventScriptRunner) -> Variant:
	var name: String = String(value)
	if runner.has_local(name):
		return runner.get_local(name)
	if EventScriptCommands.is_function(name):
		return runner.call_builtin(name, [], line)
	return StringName(name)

func _evaluate_binary(runner: EventScriptRunner) -> Variant:
	var operator: String = String(value)
	# Keep `and` and `or` short-circuiting.
	if operator == "and":
		if not EventScriptCast.to_bool(operands[0].evaluate(runner)):
			return false
		return EventScriptCast.to_bool(operands[1].evaluate(runner))
	if operator == "or":
		if EventScriptCast.to_bool(operands[0].evaluate(runner)):
			return true
		return EventScriptCast.to_bool(operands[1].evaluate(runner))

	var left: Variant = operands[0].evaluate(runner)
	var right: Variant = operands[1].evaluate(runner)
	match operator:
		"==":
			return EventScriptCast.equal(left, right)
		"!=":
			return not EventScriptCast.equal(left, right)
		"<":
			return EventScriptCast.to_number(left) < EventScriptCast.to_number(right)
		"<=":
			return EventScriptCast.to_number(left) <= EventScriptCast.to_number(right)
		">":
			return EventScriptCast.to_number(left) > EventScriptCast.to_number(right)
		">=":
			return EventScriptCast.to_number(left) >= EventScriptCast.to_number(right)
		"+":
			# Join values when either side is text.
			if left is String or right is String:
				return EventScriptCast.to_text(left) + EventScriptCast.to_text(right)
			return _number_result(
				EventScriptCast.to_number(left) + EventScriptCast.to_number(right), left, right
			)
		"-":
			return _number_result(
				EventScriptCast.to_number(left) - EventScriptCast.to_number(right), left, right
			)
		"*":
			return _number_result(
				EventScriptCast.to_number(left) * EventScriptCast.to_number(right), left, right
			)
		"/":
			var divisor: float = EventScriptCast.to_number(right)
			if is_zero_approx(divisor):
				runner.report("divided by zero", line)
				return 0
			return _number_result(EventScriptCast.to_number(left) / divisor, left, right)
		"%":
			var modulus: int = int(EventScriptCast.to_number(right))
			if modulus == 0:
				runner.report("divided by zero", line)
				return 0
			return int(EventScriptCast.to_number(left)) % modulus
	return null

## Keeps whole-number results as integers.
static func _number_result(result: float, left: Variant, right: Variant) -> Variant:
	if typeof(left) == TYPE_FLOAT or typeof(right) == TYPE_FLOAT:
		return result
	return int(result)

## Whether this expression can be translated.
func is_translatable_text() -> bool:
	return kind == Kind.TEXT or (kind == Kind.LITERAL and value is String)

## Returns the text with placeholders for expressions.
func translation_template() -> String:
	if kind == Kind.LITERAL:
		return String(value) if value is String else ""
	if kind != Kind.TEXT:
		return ""
	var built: String = ""
	for part: Variant in parts:
		if part is EventScriptExpression:
			built += "{%s}" % (part as EventScriptExpression).to_source()
		else:
			built += String(part)
	return built

## Adds evaluated placeholders to the translation parameters.
func collect_translation_params(runner: EventScriptRunner, into: Dictionary) -> void:
	if kind != Kind.TEXT:
		return
	for part: Variant in parts:
		if part is EventScriptExpression:
			var hole: EventScriptExpression = part as EventScriptExpression
			into[hole.to_source()] = EventScriptCast.to_text(hole.evaluate(runner))

## Returns the expression as source text.
func to_source() -> String:
	match kind:
		Kind.LITERAL:
			if value is String:
				return "\"%s\"" % value
			return EventScriptCast.to_text(value)
		Kind.TEXT:
			var built: String = ""
			for part: Variant in parts:
				if part is EventScriptExpression:
					built += "{%s}" % (part as EventScriptExpression).to_source()
				else:
					built += String(part)
			return "\"%s\"" % built
		Kind.IDENTIFIER:
			return String(value)
		Kind.CALL:
			var arguments: PackedStringArray = PackedStringArray()
			for operand: EventScriptExpression in operands:
				arguments.append(operand.to_source())
			return "%s(%s)" % [value, ", ".join(arguments)]
		Kind.UNARY:
			return "%s %s" % [value, operands[0].to_source()]
		Kind.BINARY:
			return "%s %s %s" % [operands[0].to_source(), value, operands[1].to_source()]
	return ""
