class_name EventScriptBlock
extends RefCounted
## The control structure for Ruby scripts, handling `if`/`else`, `for`, `while` etc.

enum Kind {
	STATEMENT,
	BRANCH,
	LOOP,
	COUNT,
	ITERATE,
	SKIP,
	STOP,
}

enum Flow {
	NORMAL,
	NEXT,
	BREAK,
}

const MAX_LOOP_DEPTH: int = 100000

const ITERATORS: Array[String] = [
	"each", "each_value", "each_key", "each_pair", "each_with_index",
	"reverse_each", "times",
]

class ScriptNode extends RefCounted:
	var kind: Kind = Kind.STATEMENT
	var text: String = ""
	var source: String = ""
	var body: Array[ScriptNode] = []
	
	## The `else/elsif` branches
	var alternate: Array[ScriptNode] = []
	
	var parameters: PackedStringArray = PackedStringArray()
	var iterator: String = "each"
	
## The [EventScriptBridge] every expression is evaluated against
var bridge: RefCounted  = null

var last_value: Variant = null

func _init(for_bridge: RefCounted) -> void:
	bridge = for_bridge
	
# === Parsing ===

## Reads [param lines] into a tree
static func parse(lines: PackedStringArray) -> Array[ScriptNode]:
	var cursor: Array[int] = [0]
	return _parse_until(lines, cursor, PackedStringArray())
	
## Reads nodes until a terminator is reached
static func _parse_until(
	lines: PackedStringArray, cursor: Array[int], terminators: PackedStringArray
) -> Array[ScriptNode]:
	var nodes: Array[ScriptNode] = []
	while cursor[0] < lines.size():
		var line: String = lines[cursor[0]].strip_edges()
		if _is_terminator(line, terminators):
			return nodes
		cursor[0] += 1
		var node: ScriptNode = _parse_line(line, lines, cursor)
		if node != null:
			nodes.append(node)
	return nodes

static func _is_terminator(line: String, terminators: PackedStringArray) -> bool:
	for terminator: String in terminators:
		if line == terminator or _starts_with_word(line, terminator):
			return true
	return false

## Reads one line and, if it starts a block, reads everything up to its `end`
static func _parse_line(line: String, lines: PackedStringArray, cursor: Array[int]) -> ScriptNode:
	if line.is_empty():
		return null

	var node: ScriptNode = ScriptNode.new()
	node.source = line

	if _starts_with_word(line, "if") or _starts_with_word(line, "unless"):
		return _parse_branch(line, lines, cursor, node)
	if _starts_with_word(line, "while") or _starts_with_word(line, "until") or line == "loop do":
		return _parse_loop(line, lines, cursor, node)
	if _starts_with_word(line, "for"):
		return _parse_count(line, lines, cursor, node)

	var iteration: PackedStringArray = _split_iterator(line)
	if not iteration.is_empty():
		return _parse_iterate(iteration, lines, cursor, node)

	if _starts_with_word(line, "next"):
		node.kind = Kind.SKIP
		node.text = _condition_after(line, "next")
		return node
	if _starts_with_word(line, "break"):
		node.kind = Kind.STOP
		node.text = _condition_after(line, "break")
		return node

	node.kind = Kind.STATEMENT
	node.text = line
	return node

static func _parse_branch(
	line: String, lines: PackedStringArray, cursor: Array[int], node: ScriptNode
) -> ScriptNode:
	var negated: bool = _starts_with_word(line, "unless")
	var condition: String = _after_word(line, "unless" if negated else "if")
	return _fill_branch(node, condition, negated, lines, cursor)

## Reads a branches body and whatever follows it
static func _fill_branch(
	node: ScriptNode, condition: String, negated: bool,
	lines: PackedStringArray, cursor: Array[int]
) -> ScriptNode:
	node.kind = Kind.BRANCH
	# `unless x` is `if !(x)`, which keeps one branch shape rather than two.
	node.text = "!(%s)" % condition if negated else condition
	node.body = _parse_until(lines, cursor, PackedStringArray(["end", "else", "elsif"]))
	if cursor[0] >= lines.size():
		return node
	var closer: String = lines[cursor[0]].strip_edges()
	cursor[0] += 1
	if _starts_with_word(closer, "elsif"):
		var chained: ScriptNode = ScriptNode.new()
		chained.source = closer
		var chain: Array[ScriptNode] = []
		chain.append(_fill_branch(chained, _after_word(closer, "elsif"), false, lines, cursor))
		node.alternative = chain
		return node
	if closer == "else":
		node.alternative = _parse_until(lines, cursor, PackedStringArray(["end"]))
		cursor[0] += 1
	return node

static func _parse_loop(
	line: String, lines: PackedStringArray, cursor: Array[int], node: ScriptNode
) -> ScriptNode:
	node.kind = Kind.LOOP
	if line == "loop do":
		node.text = "true"
	elif _starts_with_word(line, "until"):
		node.text = "!(%s)" % _strip_trailing_do(_after_word(line, "until"))
	else:
		node.text = _strip_trailing_do(_after_word(line, "while"))
	node.body = _parse_until(lines, cursor, PackedStringArray(["end"]))
	cursor[0] += 1
	return node
	
## `for i in 0...16` — the variable, and the range it walks.
static func _parse_count(
	line: String, lines: PackedStringArray, cursor: Array[int], node: ScriptNode
) -> ScriptNode:
	node.kind = Kind.COUNT
	var rest: String = _strip_trailing_do(_after_word(line, "for"))
	var split: int = rest.find(" in ")
	if split < 0:
		node.kind = Kind.STATEMENT
		node.text = line
		return node
	node.parameters = PackedStringArray([rest.substr(0, split).strip_edges()])
	node.text = rest.substr(split + 4).strip_edges()
	node.body = _parse_until(lines, cursor, PackedStringArray(["end"]))
	cursor[0] += 1
	return node

static func _parse_iterate(
	iteration: PackedStringArray, lines: PackedStringArray, cursor: Array[int], node: ScriptNode
) -> ScriptNode:
	node.kind = Kind.ITERATE
	node.text = iteration[0]
	node.iterator = iteration[1]
	node.parameters = _split_parameters(iteration[2])
	node.body = _parse_until(lines, cursor, PackedStringArray(["end"]))
	cursor[0] += 1
	return node

## Splits `list.each do |item|` into the collection, the method and the block's parameters
## Returns nothing when the line is not one.
static func _split_iterator(line: String) -> PackedStringArray:
	if not line.ends_with("|"):
		return PackedStringArray()
	var closing_bar: int = line.length() - 1
	var opening_bar: int = line.rfind("|", closing_bar - 1)
	if opening_bar < 0:
		return PackedStringArray()
	var parameters: String = line.substr(opening_bar + 1, closing_bar - opening_bar - 1)
	var head: String = line.substr(0, opening_bar).strip_edges()
	if not head.ends_with("do"):
		return PackedStringArray()
	head = head.substr(0, head.length() - 2).strip_edges()

	for method: String in ITERATORS:
		var suffix: String = "." + method
		if head.ends_with(suffix):
			return PackedStringArray([
				head.substr(0, head.length() - suffix.length()), method, parameters,
			])
	return PackedStringArray()

static func _split_parameters(text: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for part: String in text.split(","):
		var name: String = part.strip_edges()
		if not name.is_empty():
			names.append(name)
	return names

## The condition of a `next if x` or a `break unless x`, as an expression that is true when the statement should happen.
## An empty string means it always acts.
static func _condition_after(line: String, keyword: String) -> String:
	var rest: String = _after_word(line, keyword)
	if rest.is_empty():
		return ""
	if _starts_with_word(rest, "if"):
		return _after_word(rest, "if")
	if _starts_with_word(rest, "unless"):
		return "!(%s)" % _after_word(rest, "unless")
	return ""

static func _starts_with_word(line: String, word: String) -> bool:
	if not line.begins_with(word):
		return false
	if line.length() == word.length():
		return true
	return not _is_name_character(line[word.length()])

static func _is_name_character(character: String) -> bool:
	if character == "_":
		return true
	var code: int = character.unicode_at(0)
	return (
		(code >= 48 and code <= 57)
		or (code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
	)

static func _after_word(line: String, word: String) -> String:
	return line.substr(word.length()).strip_edges()

static func _strip_trailing_do(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.ends_with(" do"):
		return trimmed.substr(0, trimmed.length() - 3).strip_edges()
	return trimmed

# === Execution ===

## Runs [param nodes] and returns how the block resolved.
func execute(nodes: Array[ScriptNode]) -> Flow:
	for node: ScriptNode in nodes:
		var flow: Flow = await _run(node)
		if flow != Flow.NORMAL:
			return flow
	return Flow.NORMAL

func _run(node: ScriptNode) -> Flow:
	match node.kind:
		Kind.STATEMENT:
			last_value = await bridge.evaluate(node.text)
			bridge.report_if_unsupported(last_value)
			return Flow.NORMAL
		Kind.BRANCH:
			return await _run_branch(node)
		Kind.LOOP:
			return await _run_loop(node)
		Kind.COUNT:
			return await _run_count(node)
		Kind.ITERATE:
			return await _run_iterate(node)
		Kind.SKIP:
			return Flow.NEXT if await _holds(node.text) else Flow.NORMAL
		Kind.STOP:
			return Flow.BREAK if await _holds(node.text) else Flow.NORMAL
	return Flow.NORMAL

## Whether a `next if`/`break if` should act. 
## An empty condition always acts.
func _holds(condition: String) -> bool:
	if condition.is_empty():
		return true
	return await bridge.evaluate_condition(condition)

func _run_branch(node: ScriptNode) -> Flow:
	if await bridge.evaluate_condition(node.text):
		return await execute(node.body)
	return await execute(node.alternative)

func _run_loop(node: ScriptNode) -> Flow:
	var passes: int = 0
	while await bridge.evaluate_condition(node.text):
		passes += 1
		if passes > MAX_LOOP_DEPTH:
			push_error("EventScriptBlock: '%s' never finished." % node.source)
			break
		var flow: Flow = await execute(node.body)
		if flow == Flow.BREAK:
			break
		await bridge.rest()
	return Flow.NORMAL

func _run_count(node: ScriptNode) -> Flow:
	var name: String = node.parameters[0] if not node.parameters.is_empty() else "i"
	var values: Array = await _range_of(node.text)
	return await _walk(values, PackedStringArray([name]), node.body)

## Reads `0...16` and `0..15`, and falls back to evaluating the text for a list.
func _range_of(text: String) -> Array:
	for separator: String in ["...", ".."]:
		var split: int = text.find(separator)
		if split < 0:
			continue
		var from: Variant = await bridge.evaluate(text.substr(0, split))
		var to: Variant = await bridge.evaluate(text.substr(split + separator.length()))
		var first: int = _whole_number(from)
		var last: int = _whole_number(to)
		if separator == "..":
			last += 1
		var values: Array = []
		for value: int in range(first, last):
			values.append(value)
		return values
	var evaluated: Variant = await bridge.evaluate(text)
	return evaluated if evaluated is Array else []

static func _whole_number(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	if value is String or value is StringName:
		return int(String(value))
	return 0

func _run_iterate(node: ScriptNode) -> Flow:
	var collection: Variant = await bridge.evaluate(node.text)
	bridge.report_if_unsupported(collection)
	return await _walk(items_of(collection, node.iterator), node.parameters, node.body)

## What one pass of [param iterator] is handed, in order.
static func items_of(collection: Variant, iterator: String) -> Array:
	if collection is int or collection is float:
		# `3.times do |i|` counts rather than walking anything.
		var counted: Array = []
		for index: int in maxi(int(collection), 0):
			counted.append(index)
		return counted
	if collection is Dictionary:
		match iterator:
			"each_key":
				return collection.keys()
			"each_pair", "each", "each_with_index":
				var pairs: Array = []
				for key: Variant in collection:
					pairs.append([key, collection[key]])
				return pairs
			_:
				return collection.values()
	if not (collection is Array):
		return []
	var items: Array = (collection as Array).duplicate()
	if iterator == "reverse_each":
		items.reverse()
	if iterator == "each_with_index":
		var numbered: Array = []
		for index: int in items.size():
			numbered.append([items[index], index])
		return numbered
	return items

## Runs [param body] once per item, binding [param parameters] for the pass and returning anything shadowed
## back to its orignal state
func _walk(items: Array, parameters: PackedStringArray, body: Array[ScriptNode]) -> Flow:
	var shadowed: Dictionary = bridge.capture_locals(parameters)
	for item: Variant in items:
		bridge.bind_locals(parameters, item)
		var flow: Flow = await execute(body)
		if flow == Flow.BREAK:
			break
		await bridge.rest()
	bridge.restore_locals(shadowed, parameters)
	return Flow.NORMAL
