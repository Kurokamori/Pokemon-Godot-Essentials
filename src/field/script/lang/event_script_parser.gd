class_name EventScriptParser
extends RefCounted
## Parses event script text into statements.

## Tab width used for indentation.
const TAB_WIDTH: int = 4

## Maximum block nesting depth.
const MAX_DEPTH: int = 32

## A source line after preprocessing.
class Line extends RefCounted:
	var indent: int = 0
	var content: String = ""
	var number: int = 1

## A token from one source line.
class Token extends RefCounted:
	enum Kind { WORD, NUMBER, STRING, PLAIN_STRING, SYMBOL, OPERATOR, COMMA, EQUALS, OPEN, CLOSE }

	var kind: Kind = Kind.WORD
	var text: String = ""
	var number: float = 0.0
	## Whether the source number had no decimal point.
	var is_whole: bool = true

	func _init(of_kind: Kind = Kind.WORD, of_text: String = "") -> void:
		kind = of_kind
		text = of_text

var _program: EventScriptProgram = null
var _lines: Array[Line] = []
var _index: int = 0
var _tokens: Array = []
var _cursor: int = 0
var _line_number: int = 1

## Parses source text and records its name for warnings.
static func parse(source: String, source_name: String = "") -> EventScriptProgram:
	var parser: EventScriptParser = EventScriptParser.new()
	return parser._parse(source, source_name)

func _parse(source: String, source_name: String) -> EventScriptProgram:
	_program = EventScriptProgram.new()
	_program.source_name = source_name
	_lines = _prepare_lines(source)
	_index = 0
	if _lines.is_empty():
		return _program
	var top: Array[EventScriptStatement] = _build_block(_lines[0].indent, 0, "")
	_program.statements = _extract_routines(top)
	return _program

# === Prepare source lines ===

## Removes comments and joins continued lines.
func _prepare_lines(source: String) -> Array[Line]:
	var prepared: Array[Line] = []
	var raw: PackedStringArray = source.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var pending: Line = null
	for offset: int in raw.size():
		var physical: String = _strip_comment(raw[offset])
		var body: String = physical.strip_edges()
		if body.is_empty():
			continue
		if pending != null:
			pending.content += " " + body
		else:
			pending = Line.new()
			pending.indent = _indent_of(physical)
			pending.content = body
			pending.number = offset + 1
		if _continues(pending.content):
			pending.content = pending.content.trim_suffix("\\").strip_edges()
			continue
		prepared.append(pending)
		pending = null
	if pending != null:
		prepared.append(pending)
	return prepared

## Whether the line continues on the next line.
func _continues(content: String) -> bool:
	if content.ends_with("\\"):
		return true
	var depth: int = 0
	var quote: String = ""
	for index: int in content.length():
		var character: String = content[index]
		if not quote.is_empty():
			if character == "\\":
				continue
			if character == quote:
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
		elif character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
	return depth > 0

## Removes a comment while preserving quoted and escaped hashes.
func _strip_comment(text: String) -> String:
	var quote: String = ""
	var index: int = 0
	var seen_content: bool = false
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
			index += 1
			continue
		if character == "\"" or character == "'":
			quote = character
		elif character == "\\":
			index += 2
			continue
		elif character == "#" and (not seen_content or _stands_apart(text, index)):
			return text.substr(0, index)
		if character != " " and character != "\t":
			seen_content = true
		index += 1
	return text

## Whether a hash is separated from surrounding text.
static func _stands_apart(text: String, index: int) -> bool:
	var before: String = text[index - 1] if index > 0 else " "
	if before != " " and before != "\t":
		return false
	if index + 1 >= text.length():
		return true
	var after: String = text[index + 1]
	return after == " " or after == "\t"

func _indent_of(text: String) -> int:
	var width: int = 0
	for index: int in text.length():
		match text[index]:
			" ":
				width += 1
			"\t":
				width += TAB_WIDTH - (width % TAB_WIDTH)
			_:
				return width
	return width

# === Read blocks ===

## Reads statements at the given indentation level.
func _build_block(indent: int, depth: int, parent_keyword: String) -> Array[EventScriptStatement]:
	var block: Array[EventScriptStatement] = []
	if depth > MAX_DEPTH:
		_error("nested too deeply; check the indenting", _lines[_index].number)
		return block
	while _index < _lines.size():
		var line: Line = _lines[_index]
		if line.indent < indent:
			break
		if line.indent > indent:
			_error(
				"this line is indented further than the one above it, which is not a block", line.number
			)
			_index += 1
			continue
		var block_follows: bool = (
			_index + 1 < _lines.size() and _lines[_index + 1].indent > indent
		)
		var statement: EventScriptStatement = _build_statement(line, block_follows)
		_index += 1
		if statement == null:
			continue
		if _index < _lines.size() and _lines[_index].indent > indent:
			if EventScriptCommands.takes_raw_text(statement.keyword) and statement.arguments.is_empty():
				_absorb_text_block(statement, _lines[_index].indent)
			else:
				statement.children = _build_block(_lines[_index].indent, depth + 1, statement.keyword)
		_check_block(statement)
		_check_placement(statement, block, parent_keyword)
		block.append(statement)
	return block

## Collects indented lines as one message.
func _absorb_text_block(statement: EventScriptStatement, indent: int) -> void:
	while _index < _lines.size() and _lines[_index].indent >= indent:
		# Keep deeper indentation as part of the message.
		var line: Line = _lines[_index]
		statement.arguments.append(_text_expression(line.content, line.number, true))
		_index += 1

## Checks whether a statement has the required block.
func _check_block(statement: EventScriptStatement) -> void:
	var kind: int = EventScriptCommands.block_kind(statement.keyword)
	var has_children: bool = not statement.children.is_empty() or (
		EventScriptCommands.takes_raw_text(statement.keyword) and not statement.arguments.is_empty()
	)
	if kind == EventScriptCommands.BLOCK_NONE and not statement.children.is_empty():
		_error("%s does not take an indented block" % statement.written_as, statement.line)
		return
	if EventScriptCommands.takes_raw_text(statement.keyword) and not statement.children.is_empty():
		# Message text must be on the line or in the block.
		_error(
			"%s has text on its line and a block under it; use one or the other" % statement.written_as,
			statement.line
		)
		return
	if kind in [EventScriptCommands.BLOCK_REQUIRED, EventScriptCommands.BLOCK_BRANCHES] and not has_children:
		_error("%s needs something indented under it" % statement.written_as, statement.line)

## Checks whether a branch is in a valid location.
func _check_placement(
	statement: EventScriptStatement,
	siblings: Array[EventScriptStatement],
	parent_keyword: String
) -> void:
	var allowed: Array = EventScriptCommands.parents_of(statement.keyword)
	if statement.keyword == "routine" and not parent_keyword.is_empty():
		_error("a routine belongs at the left margin, not inside %s" % parent_keyword, statement.line)
		return
	if allowed.is_empty():
		return
	if allowed.has(parent_keyword):
		return
	var previous: String = siblings[siblings.size() - 1].keyword if not siblings.is_empty() else ""
	if statement.keyword in ["elif", "else"] and previous in ["if", "unless", "elif"]:
		return
	_error("%s does not belong here" % statement.written_as, statement.line)

# === Read statements ===

func _build_statement(line: Line, block_follows: bool) -> EventScriptStatement:
	var written: String = _leading_word(line.content)
	if written.is_empty():
		_error("this line does not start with a command", line.number)
		return null
	# Keep a trailing colon when it is message punctuation.
	var keep_colon: bool = EventScriptCommands.takes_raw_text(written) and not block_follows
	var content: String = line.content if keep_colon else _without_block_colon(line.content)

	var keyword: String = EventScriptCommands.canonical(written)
	var statement: EventScriptStatement = EventScriptStatement.new(
		keyword, line.number, _program.source_name, written
	)
	if not EventScriptCommands.exists(written):
		_error("there is no command called %s" % written, line.number)

	var remainder: String = content.substr(written.length()).strip_edges()
	if EventScriptCommands.takes_raw_text(written) and not _starts_quoted(remainder):
		if not remainder.is_empty():
			statement.arguments.append(_text_expression(remainder, line.number, true))
	else:
		statement.arguments = _parse_arguments(remainder, line.number)

	var problem: String = EventScriptCommands.argument_problem(written, statement.arguments.size())
	if not problem.is_empty() and EventScriptCommands.exists(written):
		# A following block can satisfy a command's arguments.
		var block_may_follow: bool = (
			EventScriptCommands.block_kind(written) != EventScriptCommands.BLOCK_NONE
		)
		if not block_may_follow or statement.arguments.size() > 0:
			_error(problem, line.number)
	return statement

## Removes the optional block colon.
func _without_block_colon(content: String) -> String:
	if not content.ends_with(":"):
		return content
	var quote: String = ""
	for index: int in content.length():
		var character: String = content[index]
		if not quote.is_empty():
			if character == "\\":
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
	if not quote.is_empty():
		return content
	return content.substr(0, content.length() - 1).strip_edges()

static func _leading_word(content: String) -> String:
	if content.is_empty() or not _starts_word(content[0]):
		return ""
	var length: int = 1
	while length < content.length() and _continues_word(content[length]):
		length += 1
	return content.substr(0, length)

static func _starts_quoted(text: String) -> bool:
	return text.begins_with("\"") or text.begins_with("'")

# === Parse expressions ===

func _parse_arguments(text: String, line_number: int) -> Array[EventScriptExpression]:
	var arguments: Array[EventScriptExpression] = []
	if text.strip_edges().is_empty():
		return arguments
	_load(text, line_number)
	while not _at_end():
		if _peek_kind() == Token.Kind.COMMA or _peek_kind() == Token.Kind.EQUALS:
			_cursor += 1
			continue
		var before: int = _cursor
		var expression: EventScriptExpression = _expression()
		if expression == null:
			break
		arguments.append(expression)
		if _cursor == before:
			# Skip invalid tokens to keep parsing.
			_error("cannot make sense of %s" % _peek().text, line_number)
			_cursor += 1
	return arguments

func _load(text: String, line_number: int) -> void:
	_line_number = line_number
	_tokens = _tokenize(text, line_number)
	_cursor = 0

func _expression() -> EventScriptExpression:
	return _or_expression()

func _or_expression() -> EventScriptExpression:
	var left: EventScriptExpression = _and_expression()
	while _match_word("or"):
		var right: EventScriptExpression = _and_expression()
		left = EventScriptExpression.binary("or", left, right, _line_number)
	return left

func _and_expression() -> EventScriptExpression:
	var left: EventScriptExpression = _not_expression()
	while _match_word("and"):
		var right: EventScriptExpression = _not_expression()
		left = EventScriptExpression.binary("and", left, right, _line_number)
	return left

func _not_expression() -> EventScriptExpression:
	if _match_word("not"):
		return EventScriptExpression.unary("not", _not_expression(), _line_number)
	return _comparison()

func _comparison() -> EventScriptExpression:
	var left: EventScriptExpression = _additive()
	while _peek_operator(["==", "!=", "<", "<=", ">", ">="]):
		var operator: String = _peek().text
		_cursor += 1
		var right: EventScriptExpression = _additive()
		left = EventScriptExpression.binary(operator, left, right, _line_number)
	return left

func _additive() -> EventScriptExpression:
	var left: EventScriptExpression = _multiplicative()
	while _peek_operator(["+", "-"]):
		var operator: String = _peek().text
		_cursor += 1
		var right: EventScriptExpression = _multiplicative()
		left = EventScriptExpression.binary(operator, left, right, _line_number)
	return left

func _multiplicative() -> EventScriptExpression:
	var left: EventScriptExpression = _unary()
	while _peek_operator(["*", "/", "%"]):
		var operator: String = _peek().text
		_cursor += 1
		var right: EventScriptExpression = _unary()
		left = EventScriptExpression.binary(operator, left, right, _line_number)
	return left

func _unary() -> EventScriptExpression:
	if _peek_operator(["-", "+"]):
		var operator: String = _peek().text
		_cursor += 1
		return EventScriptExpression.unary(operator, _unary(), _line_number)
	return _primary()

func _primary() -> EventScriptExpression:
	if _at_end():
		return null
	var token: Token = _peek()
	match token.kind:
		Token.Kind.NUMBER:
			_cursor += 1
			var number: Variant = token.number
			if token.is_whole:
				number = int(token.number)
			return EventScriptExpression.literal(number, _line_number)
		Token.Kind.STRING:
			_cursor += 1
			return _text_expression(token.text, _line_number, true)
		Token.Kind.PLAIN_STRING:
			_cursor += 1
			return _text_expression(token.text, _line_number, false)
		Token.Kind.SYMBOL:
			_cursor += 1
			return EventScriptExpression.literal(StringName(token.text), _line_number)
		Token.Kind.OPEN:
			_cursor += 1
			var inner: EventScriptExpression = _expression()
			if _peek_kind() == Token.Kind.CLOSE:
				_cursor += 1
			else:
				_error("a ( was never closed", _line_number)
			return inner
		Token.Kind.WORD:
			return _word()
	return null

func _word() -> EventScriptExpression:
	var token: Token = _peek()
	_cursor += 1
	var word: String = token.text
	if EventScriptCommands.LITERAL_WORDS.has(word.to_lower()):
		return EventScriptExpression.literal(
			EventScriptCommands.LITERAL_WORDS[word.to_lower()], _line_number
		)
	if _peek_kind() != Token.Kind.OPEN:
		return EventScriptExpression.identifier(word, _line_number)

	_cursor += 1
	var arguments: Array[EventScriptExpression] = []
	while not _at_end() and _peek_kind() != Token.Kind.CLOSE:
		if _peek_kind() == Token.Kind.COMMA:
			_cursor += 1
			continue
		var before: int = _cursor
		var argument: EventScriptExpression = _expression()
		if argument == null or _cursor == before:
			_error("cannot make sense of the arguments to %s" % word, _line_number)
			break
		arguments.append(argument)
	if _peek_kind() == Token.Kind.CLOSE:
		_cursor += 1
	else:
		_error("the arguments to %s were never closed" % word, _line_number)

	if not EventScriptCommands.is_function(word):
		_error("there is no function called %s" % word, _line_number)
	else:
		var problem: String = EventScriptCommands.function_problem(word, arguments.size())
		if not problem.is_empty():
			_error(problem, _line_number)
	return EventScriptExpression.call_function(word.to_lower(), arguments, _line_number)

func _at_end() -> bool:
	return _cursor >= _tokens.size()

func _peek() -> Token:
	return _tokens[_cursor] if _cursor < _tokens.size() else Token.new(Token.Kind.WORD, "")

func _peek_kind() -> int:
	return _peek().kind if not _at_end() else -1

func _peek_operator(operators: Array) -> bool:
	return not _at_end() and _peek().kind == Token.Kind.OPERATOR and operators.has(_peek().text)

func _match_word(word: String) -> bool:
	if _at_end():
		return false
	var token: Token = _peek()
	if token.kind == Token.Kind.WORD and token.text.to_lower() == word:
		_cursor += 1
		return true
	return false

# === Tokenize expressions ===

func _tokenize(text: String, line_number: int) -> Array:
	var tokens: Array = []
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == " " or character == "\t":
			index += 1
			continue
		if character == "\"" or character == "'":
			var closing: int = _find_closing_quote(text, index)
			if closing < 0:
				_error("a quote was never closed", line_number)
				closing = text.length()
			var kind: Token.Kind = Token.Kind.STRING if character == "\"" else Token.Kind.PLAIN_STRING
			tokens.append(Token.new(kind, text.substr(index + 1, closing - index - 1)))
			index = closing + 1
			continue
		if character.is_valid_int() or (character == "." and _digit_follows(text, index)):
			var end: int = index
			var seen_point: bool = false
			while end < text.length():
				if text[end].is_valid_int():
					end += 1
					continue
				if text[end] == "." and not seen_point and _digit_follows(text, end):
					seen_point = true
					end += 1
					continue
				break
			var number_token: Token = Token.new(Token.Kind.NUMBER, text.substr(index, end - index))
			number_token.number = number_token.text.to_float()
			number_token.is_whole = not seen_point
			tokens.append(number_token)
			index = end
			continue
		if _starts_word(character):
			var end_word: int = index
			while end_word < text.length() and _continues_word(text[end_word]):
				end_word += 1
			tokens.append(Token.new(Token.Kind.WORD, text.substr(index, end_word - index)))
			index = end_word
			continue
		if character == ":" and index + 1 < text.length() and _starts_word(text[index + 1]):
			var end_symbol: int = index + 1
			while end_symbol < text.length() and _continues_word(text[end_symbol]):
				end_symbol += 1
			tokens.append(Token.new(Token.Kind.SYMBOL, text.substr(index + 1, end_symbol - index - 1)))
			index = end_symbol
			continue
		var two: String = text.substr(index, 2)
		if ["==", "!=", "<=", ">="].has(two):
			tokens.append(Token.new(Token.Kind.OPERATOR, two))
			index += 2
			continue
		if two == "&&":
			tokens.append(Token.new(Token.Kind.WORD, "and"))
			index += 2
			continue
		if two == "||":
			tokens.append(Token.new(Token.Kind.WORD, "or"))
			index += 2
			continue
		match character:
			",":
				tokens.append(Token.new(Token.Kind.COMMA, ","))
			"=":
				tokens.append(Token.new(Token.Kind.EQUALS, "="))
			"(":
				tokens.append(Token.new(Token.Kind.OPEN, "("))
			")":
				tokens.append(Token.new(Token.Kind.CLOSE, ")"))
			"!":
				tokens.append(Token.new(Token.Kind.WORD, "not"))
			"<", ">", "+", "-", "*", "/", "%":
				tokens.append(Token.new(Token.Kind.OPERATOR, character))
			_:
				_error("%s means nothing here" % character, line_number)
		index += 1
	return tokens

static func _starts_word(character: String) -> bool:
	return character == "_" or character.is_valid_identifier()

static func _continues_word(character: String) -> bool:
	return character == "_" or character.is_valid_identifier() or character.is_valid_int()

static func _digit_follows(text: String, index: int) -> bool:
	return index + 1 < text.length() and text[index + 1].is_valid_int()

## Finds the closing quote.
static func _find_closing_quote(text: String, start: int) -> int:
	var quote: String = text[start]
	var index: int = start + 1
	while index < text.length():
		if text[index] == "\\":
			index += 2
			continue
		if text[index] == quote:
			return index
		index += 1
	return -1

# === Parse message text ===

## Parses message text and interpolation.
func _text_expression(raw: String, line_number: int, interpolate: bool) -> EventScriptExpression:
	var parts: Array = []
	var buffer: String = ""
	var index: int = 0
	while index < raw.length():
		var character: String = raw[index]
		if character == "\\" and index + 1 < raw.length():
			var escaped: String = raw[index + 1]
			match escaped:
				"n":
					buffer += "\n"
				"t":
					buffer += "\t"
				"\"", "'", "{", "}", "#", "\\":
					buffer += escaped
				_:
				# Keep unknown escapes unchanged.
					buffer += character
					index += 1
					continue
			index += 2
			continue
		if interpolate and character == "{":
			var closing: int = _find_closing_brace(raw, index)
			if closing < 0:
				_error("a { in text was never closed", line_number)
				buffer += character
				index += 1
				continue
			if not buffer.is_empty():
				parts.append(buffer)
				buffer = ""
			parts.append(_sub_expression(raw.substr(index + 1, closing - index - 1), line_number))
			index = closing + 1
			continue
		buffer += character
		index += 1
	if not buffer.is_empty():
		parts.append(buffer)

	if parts.is_empty():
		return EventScriptExpression.literal("", line_number)
	if parts.size() == 1 and parts[0] is String:
		return EventScriptExpression.literal(String(parts[0]), line_number)
	return EventScriptExpression.text(parts, line_number)

## Parses one interpolated expression.
func _sub_expression(inner: String, line_number: int) -> EventScriptExpression:
	var saved_tokens: Array = _tokens
	var saved_cursor: int = _cursor
	var saved_line: int = _line_number
	_load(inner, line_number)
	var parsed: EventScriptExpression = _expression()
	_tokens = saved_tokens
	_cursor = saved_cursor
	_line_number = saved_line
	if parsed == null:
		_error("there is nothing to fill in between { and }", line_number)
		return EventScriptExpression.literal("", line_number)
	return parsed

static func _find_closing_brace(text: String, start: int) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = start
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "{":
			depth += 1
		elif character == "}":
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1

# === Report errors ===

func _error(message: String, line_number: int) -> void:
	_program.errors.append("line %d: %s" % [line_number, message])

# === Extract routines ===

## Removes routine definitions from the main statement list.
func _extract_routines(block: Array[EventScriptStatement]) -> Array[EventScriptStatement]:
	var remaining: Array[EventScriptStatement] = []
	for statement: EventScriptStatement in block:
		if statement.keyword != "routine":
			remaining.append(statement)
			continue
		if statement.arguments.is_empty():
			continue
		var name: String = _routine_name(statement.arguments[0])
		if name.is_empty():
			_error("a routine needs a name", statement.line)
			continue
		if _program.routines.has(name):
			_error("there is already a routine called %s" % name, statement.line)
		_program.routines[name] = statement.children
	return remaining

## Reads a routine name from its expression.
static func _routine_name(expression: EventScriptExpression) -> String:
	if expression.kind == EventScriptExpression.Kind.IDENTIFIER:
		return String(expression.value)
	if expression.kind == EventScriptExpression.Kind.LITERAL:
		return String(expression.value)
	return ""
