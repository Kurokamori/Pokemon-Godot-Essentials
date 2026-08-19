class_name RubySyntax
## Text in text out evalutation to splice up Ruby scripts into useable bits

## Operators on which a line may end, each needs to be followed by something
const CONTINUATIONS: Array[String] = [
	"||", "&&", "==", "!=", ">=", "<=", "+", "-", "*", "/", "%", ",", "=", ".",
	">", "<",
]

## Control flow blocks that cannot contain single values
const CONTROL_FLOW_KEYWORDS: Array[String] = [
	"if ", "unless ", "for ", "while ", "case ", "when ", "begin", "end", "else",
	"elsif", "return ", "next", "break", "loop",
]

# === Statements ===

## Splices [param script] into logical lines, one per statement, with continuations respected
static func statements(script: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var pending: String = ""
	for raw_line: String in script.split("\n"):
		var line: String = _without_comment(raw_line).strip_edges()
		if line.is_empty():
			continue
		pending = line if pending.is_empty() else "%s %s" % [pending, line]
		if is_balanced(pending) and not _wants_more(pending):
			result.append(pending)
			pending = ""
	if not pending.is_empty():
		result.append(pending)
	return result
	
# === Blocks ===

## Splits blocks into their call, block's parameters, and body, or returns nuthing when the text is not one
## A `{` with nothing in front of it is a hash literal not a block
static func split_inline_block(text: String) -> PackedStringArray:
	if not text.ends_with("}"):
		return PackedStringArray()
	var opening: int = _matching_open_brace(text)
	if opening <= 0:
		return PackedStringArray()
	var head: String = text.substr(0, opening).strip_edges()
	if head.is_empty():
		return PackedStringArray()
	var inner: String = text.substr(opening + 1, text.length() - opening - 2).strip_edges()
	var parameters: String = ""
	if inner.begins_with("|"):
		var closing_bar: int = inner.find("|", 1)
		if closing_bar < 0:
			return PackedStringArray()
		parameters = inner.substr(1, closing_bar - 1)
		inner = inner.substr(closing_bar + 1).strip_edges()
	return PackedStringArray([head, parameters, inner])
	
## The names between a blocks `|` bars
static func block_parameters(text: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for part: String in text.split(","):
		var name: String = part.strip_edges()
		if not name.is_empty():
			names.append(name)
	return names

	
# === Statements ===

## Splits a statement if condtion into its three parts
## Returns nothing when the text is not one
## Only trailing modifiers count, if it starts with an `if` it's a block
static func split_modifier(text: String) -> PackedStringArray:
	for keyword: String in [" if ", " unless "]:
		var index: int = find_operator(text, keyword)
		if index <= 0:
			continue
		return PackedStringArray([
			text.substr(0, index).strip_edges(), keyword.strip_edges(),
			text.substr(index + keyword.length()).strip_edges(),
		])
	return PackedStringArray()
	
## Splits terniaries `condition ? yes : no` or returns nothing
static func split_ternary(text: String) -> PackedStringArray:
	var question: int = find_operator(text, " ? ")
	if question < 0:
		return PackedStringArray()
	var colon: int = find_operator(text.substr(question + 3), " : ")
	if colon < 0:
		return PackedStringArray()
	colon += question + 3
	return PackedStringArray([
		text.substr(0, question).strip_edges(),
		text.substr(question + 3, colon - question - 3).strip_edges(),
		text.substr(colon + 3).strip_edges(),
	])
	
## Splits an assignment into `[target, operator, value]`
## Returns an empty array when the text is not one
static func split_assignment(text: String) -> PackedStringArray:
	for operator: String in ["+=", "-=", "="]:
		var index: int = find_operator(text, operator)
		if index < 0:
			continue
		if operator == "=":
			var following: String = text[index + 1] if index + 1 < text.length() else ""
			var previous: String = text[index - 1] if index > 0 else ""
			if following == "=" or "=!<>+-*/%".contains(previous):
				continue
		return PackedStringArray([
			text.substr(0, index).strip_edges(), operator,
			text.substr(index + operator.length()).strip_edges(),
		])
	return PackedStringArray()


## Splits `base[index]` into its two parts, or returns nothing.
static func split_index(text: String) -> PackedStringArray:
	if not text.ends_with("]"):
		return PackedStringArray()
	var depth: int = 0
	var quote: String = ""
	var index: int = text.length() - 1
	while index >= 0:
		var character: String = text[index]
		if not quote.is_empty():
			if character == quote and (index == 0 or text[index - 1] != "\\"):
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "]" or character == ")" or character == "}":
			depth += 1
		elif character == "[" or character == "(" or character == "{":
			depth -= 1
			if depth == 0 and character == "[":
				# An opening bracket at the very start is a list, not an index.
				if index == 0:
					return PackedStringArray()
				return PackedStringArray([
					text.substr(0, index).strip_edges(),
					text.substr(index + 1, text.length() - index - 2).strip_edges(),
				])
		index -= 1
	return PackedStringArray()
	
# === Operators ===

## Finds the `.` that sperates a final method from its reciever
## Ignores `.` inside brackets, strings, and numbers
static func find_method_separator(text: String) -> int:
	var depth: int = 0
	var quote: String = ""
	var separator: int = -1
	var index: int = 0
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
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == "." and depth == 0:
			# A dot between digits is a decimal point, not a method call.
			var previous: String = text[index - 1] if index > 0 else ""
			var following: String = text[index + 1] if index + 1 < text.length() else ""
			if not (previous.is_valid_int() and following.is_valid_int()):
				separator = index
		index += 1
	return separator
	
## Position of [param operator] at bracket depth zero, or `-1`.
static func find_operator(text: String, operator: String) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = 0
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
			index += 1
			continue
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif depth == 0 and text.substr(index, operator.length()) == operator:
			if not _is_part_of_longer_operator(text, index, operator):
				return index
		index += 1
	return -1
	
# === Grouping ===

## Splits the [param text] on [param seperator]
## ignoring seperators inside of brackets and strings
static func split_top_level(text: String, separator: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var quote: String = ""
	var start: int = 0
	var index: int = 0
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
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == separator and depth == 0:
			result.append(text.substr(start, index - start))
			start = index + 1
		index += 1
	result.append(text.substr(start))
	return result


## Removes the brackets around `(a + b)`, leaving `(a) + (b)` alone.
static func strip_outer_parentheses(text: String) -> String:
	if not text.begins_with("(") or not text.ends_with(")"):
		return text
	if not is_balanced(text.substr(1, text.length() - 2)):
		return text
	return text.substr(1, text.length() - 2).strip_edges()

	
# === Internals ===

## True when it ends in an operator, and so the following line is part of the same statement
static func _wants_more(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return false
	# A block's `|item|` closes a line; a trailing `||` carries on to the next.
	if trimmed.ends_with("|") and not trimmed.ends_with("||"):
		return false
	for operator: String in CONTINUATIONS:
		if trimmed.ends_with(operator):
			return true
	return false

## Drops a trailing `# comment`
static func _without_comment(line: String) -> String:
	var quote: String = ""
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "#":
			return line.substr(0, index)
		index += 1
	return line

## Returns `true` when every bracket [param text] opens is closed again and no quote is left hanging.
static func is_balanced(text: String) -> bool:
	var depth: int = 0
	var quote: String = ""
	var index: int = 0
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
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		index += 1
	return depth <= 0 and quote.is_empty()

## Returns `true` when [param text] is a control structure rather than an expression.
static func is_control_flow(text: String) -> bool:
	for keyword: String in CONTROL_FLOW_KEYWORDS:
		if text == keyword.strip_edges() or text.begins_with(keyword):
			return true
	return text.contains(" do |") or text.ends_with(" do") or text.begins_with("@")
	
## Position of the `{` that closes with the `}` at the end of [param text]
static func _matching_open_brace(text: String) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = text.length() - 1
	while index >= 0:
		var character: String = text[index]
		if not quote.is_empty():
			if character == quote and (index == 0 or text[index - 1] != "\\"):
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "}":
			depth += 1
		elif character == "{":
			depth -= 1
			if depth == 0:
				return index
		index -= 1
	return -1
	
## Guards against reading individual symbols in combined operators such as `>=` as `>`
static func _is_part_of_longer_operator(text: String, index: int, operator: String) -> bool:
	var following: String = text[index + operator.length()] if index + operator.length() < text.length() else ""
	var previous: String = text[index - 1] if index > 0 else ""
	if operator == ">" or operator == "<":
		return following == "="
	if operator == "==" or operator == "!=":
		return following == "="
	if operator == "*" or operator == "/" or operator == "%":
		return index == 0
	if operator == "+" or operator == "-":
		return index == 0 or previous.strip_edges().is_empty() == false and "+-*/=<>!&|(,".contains(previous)
	return false
