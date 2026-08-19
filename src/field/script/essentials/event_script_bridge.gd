class_name EventScriptBridge
extends RefCounted
## Handles the execution of Ruby snippets
##
## This is NOT a full Ruby interpreter, it's a vocabulary list for interpretting specific needed code blocks
##
## This file is an evaluator, actual logic is managed by the proper domains.

## Returns an unsupported snippet with what it is so it can be reported
class Unsupported extends RefCounted:
	var expression: String = ""
	
	func _init(with_expression: String = "") -> void:
		expression = with_expression
		
## Stands in for a singleton while being passed around so that a call made afterwards returns to the same place
## the singletons call from.
class Handle extends RefCounted:
	var reciever: String = ""
	
	func _init(named: String = "") -> void:
		reciever = named
		

const DEFAULT_VARIABLE: int = 1

const BRIDGE_VARIABLE: int = 21

## Variable a Mystery Gift is queued in
const MYSTERY_GIFT_VARIABLE: int = 22

## Variable an event's last run time is stamped into
const EVENT_TIME_VARIABLE: int = 23

const SAVE_SCREEN: String = "res://scenes/ui/screens/save_screen.tscn"

## How a script may call for a scene using `$scene` such as `$scene = Scene_Credits.new`
## [method EventScriptGlobals.change_scene] contains the list of scene an event may switch to
const SCENE_TARGET: String = "$scene"

## Methods that belong to the event, and are called on itself
const SELF_METHODS: Array[String] = [
	"setTempSwitchOn", "setTempSwitchOff", "isTempSwitchOn?", "isTempSwitchOff?",
	"onEvent?", "turn_up", "turn_down", "turn_left", "turn_right",
	"turn_toward_player",
]

## Recievers that stand for one of Essential's singletons
const SINGLETONS: Array[String] = [
	"pbSafariState", "pbBugContestState", "pbBattleChallenge",
	"$game_temp.safari", "$game_temp.bug_contest",
]

## Ruby class names that events use as a `is_a?`
const RUBY_CLASSES: Array[String] = [
	"Symbol", "String", "Integer", "Numeric", "Float", "Array", "Hash",
	"Pokemon", "NilClass",
]

## Methods that take a block and respond with an answer
const QUERY_METHODS: Array[String] = [
	"any?", "all?", "none?", "count", "sum", "find", "detect",
	"map", "collect", "select", "filter", "reject",
]

## The interpreter whose event is running
var interpreter: EventInterpreter = null

## Locals that the running script is using
var locals: Dictionary = {}

## Vocabularies, each populated on first use and then kept
var _globals: EventScriptGlobals = null
var _battles: EventScriptBattles = null
var _receivers: EventScriptReceivers = null
var _facilities: EventScriptFacilities = null



func _init(for_interpreter: EventInterpreter = null) -> void:
	interpreter = for_interpreter

# === Running ===

## Runs [param script] and returns the value of its last statement
func run(script: String) -> Variant:
	var lines: PackedStringArray = RubySyntax.statements(script)
	if lines.is_empty():
		return null
	var block: EventScriptBlock = EventScriptBlock.new(self)
	await block.execute(EventScriptBlock.parse(lines))
	return block.last_value

## Evaluates [param script] for its truth value, the way a conditional branch needs it
func evaluate_condition(script: String) -> bool:
	var result: Variant = await run(script)
	if result is Unsupported:
		return true
	return is_truthy(result)

## Names a snippet the engine has no counterpart for
func report_if_unsupported(value: Variant) -> void:
	if not (value is Unsupported) or interpreter == null:
		return
	interpreter.report_unsupported_script(String(value.expression))

## Gives a frame back, so a loop in a converted event slows the game down rather than completely stalling it
func rest() -> void:
	if interpreter == null or not interpreter.is_inside_tree():
		return
	await interpreter.get_tree().process_frame


# === Vocabularies ===

## The bare-call vocabulary
func globals() -> EventScriptGlobals:
	if _globals == null:
		_globals = EventScriptGlobals.new(self)
	return _globals

## The battle vocabulary and rules for the next fight
func battles() -> EventScriptBattles:
	if _battles == null:
		_battles = EventScriptBattles.new(self)
	return _battles

## The `$player`, `$bag`, `$game_map` and other receivers
func receivers() -> EventScriptReceivers:
	if _receivers == null:
		_receivers = EventScriptReceivers.new(self)
	return _receivers

## The phone, Day Care, Safari, Contests and Battle Frontier
func facilities() -> EventScriptFacilities:
	if _facilities == null:
		_facilities = EventScriptFacilities.new(self)
	return _facilities


# === Block Variables ===

## Remembers whatever [param names] are bound to now
## Allowing block's parameters to be returned when it finishes,
## Ruby's blocks shadow rather than replace.
func capture_locals(names: PackedStringArray) -> Dictionary:
	var shadowed: Dictionary = {}
	for name: String in names:
		if locals.has(name):
			shadowed[name] = locals[name]
	return shadowed

## Binds [param names] for one pass of a block.
## A block taking two names is handed a pair — a hash's key and value
## or an item and its position
func bind_locals(names: PackedStringArray, item: Variant) -> void:
	if names.is_empty():
		return
	if names.size() == 1:
		locals[names[0]] = item
		return
	var parts: Array = item if item is Array else [item]
	for index: int in names.size():
		locals[names[index]] = parts[index] if index < parts.size() else null

func restore_locals(shadowed: Dictionary, names: PackedStringArray) -> void:
	for name: String in names:
		if shadowed.has(name):
			locals[name] = shadowed[name]
			continue
		locals.erase(name)


# === Evalutation ===

## Evaluates one expression
func evaluate(expression: String) -> Variant:
	var text: String = expression.strip_edges()
	if text.is_empty():
		return null
	if RubySyntax.is_control_flow(text):
		return Unsupported.new(text)

	var modifier: PackedStringArray = RubySyntax.split_modifier(text)
	if not modifier.is_empty():
		var wanted: bool = modifier[1] == "if"
		var condition: Variant = await evaluate(modifier[2])
		if condition is Unsupported:
			return condition
		if is_truthy(condition) != wanted:
			return null
		return await evaluate(modifier[0])

	var stripped: String = RubySyntax.strip_outer_parentheses(text)
	if stripped != text:
		return await evaluate(stripped)

	var assignment: PackedStringArray = RubySyntax.split_assignment(text)
	if not assignment.is_empty():
		return await _run_assignment(assignment[0], assignment[1], assignment[2])

	var ternary: PackedStringArray = RubySyntax.split_ternary(text)
	if not ternary.is_empty():
		var test: Variant = await evaluate(ternary[0])
		if test is Unsupported:
			return test
		return await evaluate(ternary[1] if is_truthy(test) else ternary[2])

	for operator: String in ["||", "&&"]:
		var split: int = RubySyntax.find_operator(text, operator)
		if split >= 0:
			return await _combine(
				text.substr(0, split), text.substr(split + operator.length()), operator
			)

	for operator: String in ["==", "!=", ">=", "<=", ">", "<"]:
		var split: int = RubySyntax.find_operator(text, operator)
		if split >= 0:
			return await _compare(
				text.substr(0, split), text.substr(split + operator.length()), operator
			)

	for operator: String in ["+", "-", "*", "/", "%"]:
		var split: int = RubySyntax.find_operator(text, operator)
		if split > 0:
			return await _arithmetic(text.substr(0, split), text.substr(split + 1), operator)

	if text.begins_with("!"):
		var inner: Variant = await evaluate(text.substr(1))
		if inner is Unsupported:
			return inner
		return not is_truthy(inner)

	var literal: Array = await _parse_literal(text)
	if not literal.is_empty():
		return literal[0]

	var block: PackedStringArray = RubySyntax.split_inline_block(text)
	if not block.is_empty():
		return await _call_with_block(block[0], block[1], block[2], text)

	var indexed: PackedStringArray = RubySyntax.split_index(text)
	if not indexed.is_empty():
		return await _read_index(indexed[0], indexed[1])

	return await _call(text)

func _combine(left_text: String, right_text: String, operator: String) -> Variant:
	var left: Variant = await evaluate(left_text)
	if left is Unsupported:
		return left
		
	if operator == "||" and is_truthy(left):
		return true
	if operator == "&&" and not is_truthy(left):
		return false
	var right: Variant = await evaluate(right_text)
	if right is Unsupported:
		return right
	return is_truthy(right)

func _compare(left_text: String, right_text: String, operator: String) -> Variant:
	var left: Variant = await evaluate(left_text)
	if left is Unsupported:
		return left
	var right: Variant = await evaluate(right_text)
	if right is Unsupported:
		return right
	match operator:
		"==": return _equal(left, right)
		"!=": return not _equal(left, right)
		">=": return as_number(left) >= as_number(right)
		"<=": return as_number(left) <= as_number(right)
		">": return as_number(left) > as_number(right)
		"<": return as_number(left) < as_number(right)
	return Unsupported.new(operator)

func _arithmetic(left_text: String, right_text: String, operator: String) -> Variant:
	var left: Variant = await evaluate(left_text)
	if left is Unsupported:
		return left
	var right: Variant = await evaluate(right_text)
	if right is Unsupported:
		return right
	if operator == "+":
		if left is String or right is String:
			return String(left) + String(right)
		if left is Array and right is Array:
			return (left as Array) + (right as Array)
		return _numeric(as_number(left) + as_number(right), left, right)
	if operator == "-":
		return _numeric(as_number(left) - as_number(right), left, right)
	if operator == "*":
		return _numeric(as_number(left) * as_number(right), left, right)
	if operator == "%":
		var divisor: float = as_number(right)
		return 0 if is_zero_approx(divisor) else int(as_number(left)) % int(divisor)
	var denominator: float = as_number(right)
	if is_zero_approx(denominator):
		return 0
	# Ruby's `/` on two integers throws the remainder away
	if _is_integer(left) and _is_integer(right):
		return int(as_number(left)) / int(denominator)
	return as_number(left) / denominator

## Keeps whole numbers whole. 
## Ruby only produces a float when one was involved
static func _numeric(value: float, left: Variant, right: Variant) -> Variant:
	if _is_integer(left) and _is_integer(right):
		return int(value)
	return value

static func _is_integer(value: Variant) -> bool:
	return value is int or value is bool or value == null


# === Blocks ===

## Returns `true` when [param method] is one a block may be handed to. 
## The iterating half of the list is [EventScriptBlock]'s, 
## so a method added for `do |x|` blocks is understood in `{ |x| ... }` ones too.
static func takes_block(method: String) -> bool:
	return EventScriptBlock.ITERATORS.has(method) or QUERY_METHODS.has(method)

## Runs a call that was given a block
func _call_with_block(
	head: String, parameters: String, body: String, raw: String
) -> Variant:
	var names: PackedStringArray = RubySyntax.block_parameters(parameters)
	if head == "proc" or head == "lambda" or head == "Proc.new":
		return block_callable(names, body)
	var split: int = RubySyntax.find_method_separator(head)
	if split < 0:
		return Unsupported.new(raw)
	var collection: Variant = await evaluate(head.substr(0, split))
	if collection is Unsupported:
		return collection
	return await run_block_method(
		collection, head.substr(split + 1).strip_edges(), names, body, raw
	)

## Wraps a block up as a [Callable], which is what a `proc` argument becomes.
## Returns value immediately and cannot await/be awaited
func block_callable(names: PackedStringArray, body: String) -> Callable:
	return func(value: Variant = null) -> Variant:
		var shadowed: Dictionary = capture_locals(names)
		bind_locals(names, value)
		var result: Variant = await evaluate(body)
		restore_locals(shadowed, names)
		return result

## Runs [param method] over [param collection], evaluating [param body] once per item with [param names] bound to it.
func run_block_method(
	collection: Variant, method: String, names: PackedStringArray,
	body: String, raw: String
) -> Variant:
	if not takes_block(method):
		return Unsupported.new(raw)
	var items: Array = EventScriptBlock.items_of(collection, method)
	var shadowed: Dictionary = capture_locals(names)
	var gathered: Array = []
	var matched: int = 0
	var total: float = 0.0
	var found: Variant = null
	for item: Variant in items:
		bind_locals(names, item)
		var result: Variant = await evaluate(body)
		if result is Unsupported:
			restore_locals(shadowed, names)
			return result
		var truthy: bool = is_truthy(result)
		if truthy:
			matched += 1
			if found == null:
				found = item
		total += as_number(result)
		gathered.append(result)
		# `any?` and `find` stop as soon as they have their answer
		if truthy and (method == "any?" or method == "find" or method == "detect"):
			break
		if not truthy and (method == "all?" or method == "none?"):
			break
	restore_locals(shadowed, names)

	match method:
		"any?":
			return matched > 0
		"all?":
			return matched == items.size()
		"none?":
			return matched == 0
		"count":
			return matched
		"sum":
			return total
		"find", "detect":
			return found
		"map", "collect":
			return gathered
		"select", "filter", "reject":
			var kept: Array = []
			for index: int in items.size():
				var wanted: bool = is_truthy(gathered[index])
				if wanted == (method != "reject"):
					kept.append(items[index])
			return kept
	return collection


# === Assignment ===

func _run_assignment(target: String, operator: String, value_text: String) -> Variant:
	if operator == "=" and target.strip_edges() == SCENE_TARGET:
		return await globals().change_scene(value_text.strip_edges())
	var value: Variant = await evaluate(value_text)
	if value is Unsupported:
		return Unsupported.new("%s %s %s" % [target, operator, value_text])
	var final: Variant = value
	if operator != "=":
		var current: Variant = await evaluate(target)
		if current is Unsupported:
			return Unsupported.new("%s %s %s" % [target, operator, value_text])
		var stepped: float = (
			as_number(current) + as_number(value) if operator == "+="
			else as_number(current) - as_number(value)
		)
		final = _numeric(stepped, current, value)
	return await _assign(target.strip_edges(), final)

## Writes [param value] wherever [param target] names
func _assign(target: String, value: Variant) -> Variant:
	var indexed: PackedStringArray = RubySyntax.split_index(target)
	if not indexed.is_empty():
		return await _assign_index(indexed[0], indexed[1], value)

	var split: int = RubySyntax.find_method_separator(target)
	if split < 0:
		locals[target] = value
		return value

	var receiver: String = target.substr(0, split).strip_edges()
	var property: String = target.substr(split + 1).strip_edges()
	var written: Variant = _assign_engine_property(receiver, property, value)
	if not (written is Unsupported):
		return written

	var holder: Variant = await evaluate(receiver)
	if holder is Unsupported:
		return holder
	if EventScriptValues.set_property(holder, property, value):
		return value
	return Unsupported.new(target)

## Writes one of the engine properties an event is allowed to set directly
func _assign_engine_property(receiver: String, property: String, value: Variant) -> Variant:
	var player: Player = GameState.player
	match receiver:
		"$player":
			if player == null:
				return Unsupported.new(receiver)
			return _assign_player_property(player, property, value)
		"$stats":
			return value if GameState.stats.set_counter(StringName(property), value) else Unsupported.new(receiver)
		"Phone":
			return _assign_phone_property(property, value)
		"$PokemonGlobal":
			return _assign_global_property(property, value)
		"$game_screen":
			if property == "weather":
				FieldEffects.set_weather(StringName(String(value)))
				return value
	return Unsupported.new(receiver)

func _assign_player_property(player: Player, property: String, value: Variant) -> Variant:
	match property:
		"has_pokedex": player.has_pokedex = is_truthy(value)
		"has_pokegear": player.has_pokegear = is_truthy(value)
		"has_running_shoes": player.has_running_shoes = is_truthy(value)
		"has_snag_machine": player.has_snag_machine = is_truthy(value)
		"seen_storage_creator": player.seen_storage_creator = is_truthy(value)
		"seen_purify_chamber": player.seen_purify_chamber = is_truthy(value)
		"mystery_gift_unlocked": player.mystery_gift_unlocked = is_truthy(value)
		"coins": player.coins = clampi(int(as_number(value)), 0, GameSettings.data.max_coins)
		"battle_points": player.battle_points = clampi(
			int(as_number(value)), 0, GameSettings.data.max_battle_points
		)
		"soot": player.soot = clampi(int(as_number(value)), 0, GameSettings.data.max_soot)
		"money": player.money = int(as_number(value))
		"name": player.name = String(value)
		_: return Unsupported.new(property)
	return value

## The two Pokegear settings an event turns on:
## whether anybody wants a rematch, and how strong a rematch may get.
func _assign_phone_property(property: String, value: Variant) -> Variant:
	var book: PhoneBook = GameState.phone
	match property:
		"rematches_enabled":
			book.rematches_enabled = is_truthy(value)
		"rematch_variant":
			book.rematch_variant = maxi(int(as_number(value)), 0)
		_:
			return Unsupported.new(property)
	return value

func _assign_global_property(property: String, value: Variant) -> Variant:
	match property:
		"encounter_version":
			GameState.encounter_version = int(as_number(value))
		"dungeon_area":
			GameState.dungeon_area = StringName(String(value))
		"dungeon_version":
			GameState.dungeon_version = int(as_number(value))
		"dungeon_rng_seed":
			GameState.dungeon_rng_seed = int(as_number(value))
		"lastbattle":
			GameState.last_battle_record = value if value is BattleRecording else null
		_:
			return Unsupported.new(property)
	return value

## Writes into `a[0]`, `h[:KEY]`, `pkmn.iv[:HP]` or `$player.badges[3]`.
func _assign_index(base_text: String, index_text: String, value: Variant) -> Variant:
	var index: Variant = await evaluate(index_text)
	if index is Unsupported:
		return index

	if base_text == "$player.badges":
		if GameState.player == null:
			return Unsupported.new(base_text)
		GameState.player.set_badge(int(as_number(index)), is_truthy(value))
		return value
	var stat_split: int = RubySyntax.find_method_separator(base_text)
	if stat_split >= 0:
		var table: String = base_text.substr(stat_split + 1).strip_edges()
		if table == "iv" or table == "ev":
			var owner: Variant = await evaluate(base_text.substr(0, stat_split))
			if owner is Pokemon and EventScriptValues.write_stat(owner, table, index, int(as_number(value))):
				return value

	var base: Variant = await evaluate(base_text)
	if base is Unsupported:
		return base
	if EventScriptValues.set_index(base, index, value):
		return value
	return Unsupported.new("%s[%s]" % [base_text, index_text])

func _read_index(base_text: String, index_text: String) -> Variant:
	var base: Variant = await evaluate(base_text)
	if base is Unsupported:
		return base
	var index: Variant = await evaluate(index_text)
	if index is Unsupported:
		return index
	if base_text == "$player.badges" and GameState.player != null:
		return GameState.player.has_badge(int(as_number(index)))
	return EventScriptValues.index_of(base, index)


# === Calls ===

## Splits a call chain such as `$player.pokedex.unlock(1)` into its receiver and its method, 
## then hands it to [method _dispatch]. 
func _call(text: String) -> Variant:
	var split: int = RubySyntax.find_method_separator(text)
	var receiver: String = text.substr(0, split).strip_edges() if split >= 0 else ""
	var tail: String = text.substr(split + 1).strip_edges() if split >= 0 else text

	var method: String = tail
	var arguments: Array = []
	var open: int = tail.find("(")
	if open >= 0 and tail.ends_with(")"):
		method = tail.substr(0, open).strip_edges()
		arguments = await _parse_arguments(tail.substr(open + 1, tail.length() - open - 2))
		for argument: Variant in arguments:
			if argument is Unsupported:
				return Unsupported.new(text)
	elif receiver.is_empty():
		if locals.has(method):
			return locals[method]
		var named: Variant = _named_value(method)
		if not (named is Unsupported):
			return named

	return await _dispatch(receiver, method, arguments, text)

func _parse_arguments(text: String) -> Array:
	var result: Array = []
	for part: String in RubySyntax.split_top_level(text, ","):
		var trimmed: String = part.strip_edges()
		if trimmed.is_empty():
			continue
		result.append(await evaluate(trimmed))
	return result

## Maps one parsed call onto the engine
func _dispatch(receiver: String, method: String, arguments: Array, raw: String) -> Variant:
	if receiver.is_empty():
		if method == "get_event" or method == "get_character":
			return event_by_id(int(as_number(arguments[0]))) if not arguments.is_empty() else null
		if method == "get_self":
			return current_event()
		if SELF_METHODS.has(method):
			return await _dispatch_event("get_self", method, arguments, raw)
		return await globals().call_global(method, arguments, raw)

	var handled: Variant = await _dispatch_named_receiver(receiver, method, arguments, raw)
	if not (handled is Unsupported):
		return handled

	var holder: Variant = await evaluate(receiver)
	if holder is Unsupported:
		return holder
	if holder is Handle:
		return await _dispatch_named_receiver(holder.receiver, method, arguments, raw)
	var result: Variant = EventScriptValues.call_method(holder, method, arguments)
	if result is EventScriptValues.NoSuchMethod:
		return Unsupported.new(raw)
	return result

## The receivers that name something in the engine rather than a value, tried in the order: 
## the engine's own state, the standing systems, a battle, a data table, and finally an event on the map.
func _dispatch_named_receiver(
	receiver: String, method: String, arguments: Array, raw: String
) -> Variant:
	var handled: Variant = await receivers().dispatch(receiver, method, arguments, raw)
	if not (handled is Unsupported):
		return handled

	handled = await facilities().dispatch(receiver, method, arguments, raw)
	if not (handled is Unsupported):
		return handled

	match receiver:
		"TrainerBattle":
			return await _start_trainer_battle(method, arguments, raw)
		"WildBattle":
			return await _start_wild_battle(method, arguments, raw)

	if EventScriptValues.is_data_category(receiver):
		return EventScriptValues.data_category_call(receiver, method, arguments)
	if receiver == "get_self" or receiver.begins_with("get_event(") or receiver.begins_with("get_character("):
		return await _dispatch_event(receiver, method, arguments, raw)
	return Unsupported.new(raw)

## A bare word that names something rather than calling it
func _named_value(name: String) -> Variant:
	if SINGLETONS.has(name):
		return Handle.new(name)
	if name == "$speeches":
		return GameState.speeches
	if name == "get_self":
		return current_event()
	if name.contains("::"):
		return EventScriptValues.constant(name)
	if name == "$DEBUG":
		return OS.is_debug_build()
	if RUBY_CLASSES.has(name):
		return name
	return Unsupported.new(name)


# === Battles ===

func _start_trainer_battle(method: String, arguments: Array, raw: String) -> Variant:
	if method != "start" or arguments.size() < 2:
		return Unsupported.new(raw)
	var version: int = int(as_number(arguments[2])) if arguments.size() >= 3 else 0
	return await battles().start_trainer_battle(
		_id_of(arguments[0]), String(arguments[1]), version
	)

func _start_wild_battle(method: String, arguments: Array, raw: String) -> Variant:
	if method != "start" or arguments.is_empty():
		return Unsupported.new(raw)
	var level: int = int(as_number(arguments[1])) if arguments.size() >= 2 else 5
	return await battles().start_wild_battle(_id_of(arguments[0]), level)


# === Events ===

## Calls made on an event: `get_self`, `get_event(12)` and `get_character(2)`.
func _dispatch_event(receiver: String, method: String, arguments: Array, raw: String) -> Variant:
	var event_id: int = _event_id_from_receiver(receiver)
	if event_id < 0:
		return Unsupported.new(raw)
	var event: MapEvent = event_by_id(event_id)
	match method:
		"setTempSwitchOn":
			if not arguments.is_empty():
				GameState.set_temp_switch(map_id(), _self_switch_key(event_id), String(arguments[0]), true)
				return true
		"setTempSwitchOff":
			if not arguments.is_empty():
				GameState.set_temp_switch(map_id(), _self_switch_key(event_id), String(arguments[0]), false)
				return true
		"isTempSwitchOn?":
			if not arguments.is_empty():
				return GameState.get_temp_switch(map_id(), _self_switch_key(event_id), String(arguments[0]))
		"isTempSwitchOff?":
			if not arguments.is_empty():
				return not GameState.get_temp_switch(map_id(), _self_switch_key(event_id), String(arguments[0]))
		"isOn?":
			if not arguments.is_empty():
				return GameState.get_self_switch(map_id(), _self_switch_key(event_id), String(arguments[0]))
		"isOff?":
			if not arguments.is_empty():
				return not GameState.get_self_switch(map_id(), _self_switch_key(event_id), String(arguments[0]))
		"onEvent?":
			return _player_is_on_event(event_id)
		"id":
			return event_id
		"x":
			return event.tile_position.x if event != null else 0
		"y":
			return event.tile_position.y if event != null else 0
		"turn_up", "turn_down", "turn_left", "turn_right":
			return _turn_event(event, method)
		"turn_toward_player":
			if event != null:
				FieldEffects.turn_towards(event, MapController.current.player)
			return event != null
	return Unsupported.new(raw)

static func _turn_event(event: MapEvent, method: String) -> bool:
	if event == null:
		return false
	match method:
		"turn_up": event.facing = GridCharacter.Direction.UP
		"turn_down": event.facing = GridCharacter.Direction.DOWN
		"turn_left": event.facing = GridCharacter.Direction.LEFT
		"turn_right": event.facing = GridCharacter.Direction.RIGHT
	return true

## Breaks the running event: it shakes, is taken off the map and remembers being removed.
## Derives the name from the event type so this can use cut and rocksmash
func smash_current_event() -> bool:
	var event: MapEvent = current_event()
	if event == null:
		return false
	var name_of_it: String = event.display_name().to_lower().replace(" ", "")
	var sound: String = (
		"Cut" if name_of_it.contains(HiddenMoves.CUT_TREE_MARKER) else "Rock Smash"
	)
	await HiddenMoves.smash_event(event, sound)
	return true

## Shoves the running event one cell away from the player, such as a strenght boulder
func push_current_event() -> bool:
	var event: MapEvent = current_event()
	var field: MapController = MapController.current
	if event == null or field == null or field.player == null:
		return false
	if not GameState.strength_used:
		return false
	var direction: GridCharacter.Direction = field.player.facing
	var target: Vector2i = event.tile_position + Vector2i(
		GridCharacter.DIRECTION_VECTORS[direction])
	if not event.can_enter(target, direction):
		return false
	AudioManager.play_se("Strength push")
	GameState.stats.strength_push_count += 1
	await event.force_step(direction)
	return true

## Sets one of an event's own switches and lets every event on the map notice
func set_self_switch(event_id: int, switch: String, value: bool) -> bool:
	GameState.set_self_switch(map_id(), _self_switch_key(event_id), switch, value)
	if interpreter != null and interpreter.map != null:
		for event: MapEvent in interpreter.map.all_events():
			event.refresh_page()
	return true

## Stamps the running event with the time it last ran
func set_event_time() -> void:
	var event: MapEvent = current_event()
	if event == null:
		return
	GameState.set_variable(
		EVENT_TIME_VARIABLE, int(Time.get_unix_time_from_system())
	)


# === Pokemon Gifts ===

## Gives the player a Pokemon through the shared receiving flow
func give_pokemon(arguments: Array, announce: bool) -> Variant:
	if arguments.is_empty():
		return Unsupported.new("pbAddPokemon")
	var receipt: PokemonReceipt = _make_receipt(announce)
	if arguments[0] is Pokemon:
		await receipt.give(arguments[0])
		return receipt.destination != PokemonReceipt.Destination.NOWHERE
	var level: int = int(as_number(arguments[1])) if arguments.size() >= 2 else 5
	var given: Pokemon = await receipt.give_species(_id_of(arguments[0]), maxi(level, 1))
	return given != null and receipt.destination != PokemonReceipt.Destination.NOWHERE

func give_foreign_pokemon(arguments: Array) -> Variant:
	var species_id: StringName = _id_of(arguments[0])
	if Database.species(species_id) == null:
		return false
	var level: int = int(as_number(arguments[1]))
	var owner_name: String = String(arguments[2])
	var owner: PokemonOwner = PokemonOwner.create(
		RNG.generator.randi() & 0xFFFFFFFF, owner_name, PokemonOwner.Gender.MALE
	)
	var pkmn: Pokemon = Pokemon.create(species_id, maxi(level, 1), owner)
	if arguments.size() >= 4 and arguments[3] != null:
		pkmn.nickname = String(arguments[3])
	pkmn.obtain_method = Pokemon.ObtainMethod.TRADED
	var receipt: PokemonReceipt = _make_receipt(true)
	# A traded Pokemon keeps its trainer and its name, so neither is offered.
	receipt.takes_ownership = false
	receipt.offer_nickname = false
	await receipt.give(pkmn)
	return receipt.destination != PokemonReceipt.Destination.NOWHERE

## Adds straight to the party without the receiving flow
## Returns whether there was room
func add_to_party(species: Variant, level: int) -> bool:
	var species_id: StringName = _id_of(species)
	if Database.species(species_id) == null or GameState.party.is_full():
		return false
	var pkmn: Pokemon = Pokemon.create(species_id, maxi(level, 1), _player_owner())
	if not GameState.party.add(pkmn):
		return false
	if GameState.player != null:
		GameState.player.pokedex.register_owned(pkmn)
	return true

## Builds a receipt wired to the interpreter's message window, so they reuse the existing message box.
func _make_receipt(announce: bool) -> PokemonReceipt:
	var receipt: PokemonReceipt = PokemonReceipt.new()
	if not announce or interpreter == null:
		receipt.offer_nickname = announce
		return receipt
	receipt.narrate = func(text: String) -> void:
		await interpreter.say(text)
	receipt.ask = func(options: Array) -> int:
		# Cancelling a yes/no question means no, which is the second option.
		return await interpreter.choose(options, "", 2)
	return receipt

static func _player_owner() -> PokemonOwner:
	return GameState.player.owner_record() if GameState.player != null else null


# === Map ===

## The event whose script is running
## Returns `null` when none are
func current_event() -> MapEvent:
	return interpreter.current_event() if interpreter != null else null

## The event numbered [param event_id] on the map the script is running on
func event_by_id(event_id: int) -> MapEvent:
	if interpreter == null or interpreter.map == null:
		return null
	return interpreter.map.event_by_id(event_id)

## The map the script is running on, by the number self-switches are keyed under.
func map_id() -> int:
	if interpreter != null and interpreter.map != null:
		return interpreter.map.map_id()
	return GameState.map_id

## Shows a message through the interpreter's own window and waits for the player.
func say(text: String) -> void:
	if interpreter == null:
		return
	await interpreter.say(text)

## The key an event's self-switches are stored under.
func _self_switch_key(event_id: int) -> String:
	var event: MapEvent = event_by_id(event_id)
	return event.self_switch_key() if event != null else str(event_id)

func _player_is_on_event(event_id: int) -> bool:
	if interpreter == null or interpreter.map == null or interpreter.map.player == null:
		return false
	var event: MapEvent = event_by_id(event_id)
	if event == null:
		return false
	return interpreter.map.player.tile_position == event.tile_position

## `get_self` is the running event; 
## `get_event(4)` and `get_character(4)` name one by id
func _event_id_from_receiver(receiver: String) -> int:
	if receiver == "get_self":
		if interpreter != null and interpreter.current_event() != null:
			return interpreter.current_event().event_id
		return -1
	var open: int = receiver.find("(")
	if open < 0 or not receiver.ends_with(")"):
		return -1
	var inner: String = receiver.substr(open + 1, receiver.length() - open - 2).strip_edges()
	return int(inner) if inner.is_valid_int() else -1

# === Literals ===

## Reads a Ruby literal. 
## Returns `[value]` on success and an empty array when the text is not a literal
## Returning empty allows null to be it's own value
func _parse_literal(text: String) -> Array:
	if text == "nil":
		return [null]
	if text == "true":
		return [true]
	if text == "false":
		return [false]
	if text.begins_with(":") and not text.contains(" "):
		return [StringName(text.substr(1))]
	if (text.begins_with("\"") and text.ends_with("\"")) or (text.begins_with("'") and text.ends_with("'")):
		return [text.substr(1, text.length() - 2).c_unescape()]
	if text.is_valid_int():
		return [int(text)]
	if text.is_valid_float():
		return [float(text)]
	if text.begins_with("[") and text.ends_with("]"):
		return [await _parse_list(text.substr(1, text.length() - 2))]
	if text.begins_with("{") and text.ends_with("}"):
		return [await _parse_hash(text.substr(1, text.length() - 2))]
	return []

func _parse_list(inner: String) -> Array:
	var values: Array = []
	for part: String in RubySyntax.split_top_level(inner, ","):
		var trimmed: String = part.strip_edges()
		if trimmed.is_empty():
			continue
		values.append(await evaluate(trimmed))
	return values

## Reads `{:REDAPRICORN => :LEVELBALL, ...}`
func _parse_hash(inner: String) -> Dictionary:
	var table: Dictionary = {}
	for part: String in RubySyntax.split_top_level(inner, ","):
		var trimmed: String = part.strip_edges()
		if trimmed.is_empty():
			continue
		var arrow: int = RubySyntax.find_operator(trimmed, "=>")
		if arrow < 0:
			continue
		var key: Variant = await evaluate(trimmed.substr(0, arrow))
		var value: Variant = await evaluate(trimmed.substr(arrow + 2))
		if key is String or key is StringName:
			key = StringName(String(key))
		table[key] = value
	return table

# === Conversions ===

static func is_truthy(value: Variant) -> bool:
	# Ruby counts everything except `nil` and `false` as true.
	if value == null:
		return false
	if value is bool:
		return value
	return true

static func as_number(value: Variant) -> float:
	if value is bool:
		return 1.0 if value else 0.0
	if value is int or value is float:
		return float(value)
	if value is String or value is StringName:
		var text: String = String(value)
		return float(text) if text.is_valid_float() else 0.0
	return 0.0

static func _equal(left: Variant, right: Variant) -> bool:
	# `nil` is only ever equal to `nil`
	if left == null or right == null:
		return left == null and right == null
	if left is GameDataResource or right is GameDataResource:
		return identifier(left) == identifier(right)
	if left is StringName or right is StringName:
		return identifier(left) == identifier(right)
	if (left is int or left is float) and (right is int or right is float):
		return is_equal_approx(as_number(left), as_number(right))
	# Ruby answers `false` for anything else compared across types
	if typeof(left) != typeof(right):
		return false
	return left == right

## Comparing a data record with a symbol compares their ids
static func identifier(value: Variant) -> String:
	if value is GameDataResource:
		return String(value.id)
	if value is String or value is StringName:
		return String(value)
	return str(value)

static func _id_of(value: Variant) -> StringName:
	if value is GameDataResource:
		return value.id
	return StringName(String(value))
