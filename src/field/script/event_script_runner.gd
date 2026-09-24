class_name EventScriptRunner
extends RefCounted
## Runs an event script for a map event.

## Next step after a statement runs.
enum Flow {
	## Continue with the next line.
	NORMAL,
	## Exit the current loop.
	BREAK,
	## Continue the current loop.
	CONTINUE,
	## Stop the whole script.
	EXIT,
	## Return from the current routine.
	RETURN,
	## Carry on from a label.
	GOTO,
}

## Maximum nested routine calls.
const MAX_CALL_DEPTH: int = 16

## Maximum loop passes.
const MAX_LOOP_PASSES: int = 100000

## Loop passes before yielding a frame.
const PASSES_PER_FRAME: int = 200

## Maximum jumps within one block.
const MAX_JUMPS: int = 10000

## Default flash duration.
const DEFAULT_FLASH_SECONDS: float = 0.5

## Default shake duration.
const DEFAULT_SHAKE_SECONDS: float = 1.0

## Local names reserved for command results.
const RESERVED_LOCALS: PackedStringArray = [
	"result", "chosen", "chosen_label", "index",
	"battle_result", "battle_won", "battle_lost", "battle_fled", "battle_caught",
]

## Event running the script.
var event: MapEvent = null

## Map running the script.
var map: MapController = null

## Program being run.
var program: EventScriptProgram = null

## Script locals and command results.
var locals: Dictionary = {}

var _flow: Flow = Flow.NORMAL
var _goto_label: String = ""
var _return_value: Variant = null
var _depth: int = 0

## Problems already reported.
var _reported: Dictionary = {}

## Bridge objects used by the `script` command.
var _script_bridge: EventScriptBridge = null

var _bridge_interpreter: EventInterpreter = null

# === Starting ===
## Runs a script and returns its top-level result.
static func run_script(
	script: EventScript, source_event: MapEvent = null, field: MapController = null
) -> Variant:
	if script == null:
		return null
	return await run_program(script.program(), source_event, field)

static func run_program(
	compiled: EventScriptProgram, source_event: MapEvent = null, field: MapController = null
) -> Variant:
	if compiled == null:
		return null
	var runner: EventScriptRunner = EventScriptRunner.new()
	runner.program = compiled
	runner.event = source_event
	runner.map = field if field != null else _field_for(source_event)
	return await runner.run()

static func _field_for(source_event: MapEvent) -> MapController:
	if source_event != null and source_event.map != null:
		return source_event.map
	return MapController.current

## Starts the program.
func run() -> Variant:
	if program == null:
		return null
	if program.has_errors():
		# The errors were already written out when the script was compiled.
		# Running a script that does not parse would do something arbitrary, so
		# it does nothing instead.
		return null
	_flow = Flow.NORMAL
	_return_value = null
	await _execute_block(program.statements)
	if _flow == Flow.GOTO:
		report("there is no label called %s" % _goto_label, 0)
	_release_bridge()
	return _return_value

# === Statement Loop ===
## Runs statements in order and handles branches and jumps.
func _execute_block(statements: Array) -> void:
	var index: int = 0
	var jumps: int = 0
	## Whether the statement before this one was part of an unfinished chain.
	var chain_open: bool = false
	## Whether something in that chain has already run.
	var chain_taken: bool = false
	while index < statements.size():
		var statement: EventScriptStatement = statements[index]
		var keyword: String = statement.keyword

		if keyword in ["elif", "else"] and not chain_open:
			report("%s does not follow an if" % statement.written_as, statement.line)
			index += 1
			continue

		match keyword:
			"if", "unless":
				chain_taken = _condition_holds(statement)
				if chain_taken:
					await _execute_block(statement.children)
				chain_open = true
			"elif":
				if not chain_taken and _condition_holds(statement):
					chain_taken = true
					await _execute_block(statement.children)
				chain_open = true
			"else":
				if not chain_taken:
					await _execute_block(statement.children)
				chain_open = false
				chain_taken = false
			_:
				await _execute(statement)
				chain_open = false
				chain_taken = false

		if _flow == Flow.GOTO:
			var target: int = _find_label(statements, _goto_label)
			if target < 0:
				# Not in this block; an enclosing one may have it.
				return
			jumps += 1
			if jumps > MAX_JUMPS:
				report("jumped to %s too many times; stopping" % _goto_label, statement.line)
				_flow = Flow.EXIT
				return
			_flow = Flow.NORMAL
			index = target + 1
			chain_open = false
			chain_taken = false
			continue
		if _flow != Flow.NORMAL:
			return
		index += 1

## Checks an `if` or `unless` condition.
func _condition_holds(statement: EventScriptStatement) -> bool:
	var truth: bool = _truth(statement, 0)
	return not truth if statement.keyword == "unless" else truth

static func _find_label(statements: Array, name: String) -> int:
	for index: int in statements.size():
		var statement: EventScriptStatement = statements[index]
		if statement.keyword != "label" or statement.arguments.is_empty():
			continue
		var written: EventScriptExpression = statement.arguments[0]
		if String(written.value) == name:
			return index
	return -1

# === Execution ===
func _execute(statement: EventScriptStatement) -> void:
	match statement.keyword:
		# === Dialogue ===
		"say":
			await _do_say(statement)
		"ask", "choice":
			await _do_choice(statement)
		"confirm":
			await _do_confirm(statement)

		# === Flow ===
		# `if`, `elif` and `else` are run by _execute_block, which is where the
		# chain they form is kept track of.
		"while":
			await _do_while(statement)
		"repeat":
			await _do_repeat(statement)
		"loop":
			await _do_loop(statement)
		"break":
			_flow = Flow.BREAK
		"continue":
			_flow = Flow.CONTINUE
		"label":
			pass
		"routine":
			# A routine written inside a block is reported while parsing; it is
			# skipped here rather than run where it stands.
			pass
		"goto":
			# A label is a bare name, not a value, so it is read the way it was
			# written rather than looked up as a local.
			_goto_label = _name_of(statement.argument(0))
			_flow = Flow.GOTO
		"call":
			await _do_call(statement)
		"exit":
			_flow = Flow.EXIT
		"return":
			_return_value = _value(statement, 0) if not statement.arguments.is_empty() else null
			locals["result"] = _return_value
			_flow = Flow.RETURN
		"wait":
			await _wait(_number(statement, 0))
		"wait_for_move":
			await _wait_for_movement()

		# === State ===
		"let", "set":
			_do_set(statement)
		"set_switch":
			GameState.set_switch(int(_number(statement, 0)), _flag(statement, 1))
		"set_var":
			GameState.set_variable(int(_number(statement, 0)), _value(statement, 1))
		"add_var":
			GameState.add_variable(int(_number(statement, 0)), int(_number(statement, 1)))
		"set_self_switch":
			_do_self_switch(statement)

		# === Player ===
		"give_item":
			await _do_give_item(statement, true)
		"give_item_silent":
			await _do_give_item(statement, false)
		"take_item":
			locals["result"] = GameState.bag.remove_item(_id(statement, 0), _count(statement, 1))
		"give_money":
			if GameState.player != null:
				GameState.player.add_money(int(_number(statement, 0)))
		"take_money":
			locals["result"] = GameState.player != null and GameState.player.spend_money(
				int(_number(statement, 0))
			)
		"give_pokemon":
			await _do_give_pokemon(statement, true)
		"give_pokemon_silent":
			await _do_give_pokemon(statement, false)
		"add_to_party":
			locals["result"] = _add_to_party(_id(statement, 0), _level(statement, 1))
		"heal_party":
			GameState.party.heal_all()
		"give_badge":
			if GameState.player != null:
				GameState.player.give_badge(int(_number(statement, 0)))
		"open_pc":
			await Field.open_pc()
		"show_town_map":
			await _do_show_town_map(statement)
		"fly":
			locals["result"] = await FieldMoves.offer_fly()
		"trainer_card":
			await Field.show_trainer_card()

		# === Followers ===
		"follower_mode":
			_do_follower_mode(statement)
		"follow_me":
			locals["result"] = Field.set_chosen_follower(_slot(statement, 0))
		"add_follower":
			locals["result"] = _do_add_follower(statement)
		"clear_followers":
			Field.clear_temporary_followers()
		"hide_followers":
			Field.hide_followers()
		"show_followers":
			Field.show_followers()
		"follower_cry":
			Field.follower_cry()

		"pokegear":
			await Field.show_pokegear()
		"phone_book":
			await Field.open_phone()
		"phone_register":
			locals["result"] = await _do_phone_register(statement)
		"phone_registered":
			locals["result"] = _do_phone_registered(statement)
		"phone_call":
			locals["result"] = await _do_phone_call(statement)
		"phone_rematches":
			GameState.phone.rematches_enabled = _truth(statement, 0)
		"phone_rematch_variant":
			GameState.phone.rematch_variant = maxi(int(_number(statement, 0)), 0)

		# === Ceremonies ===
		"hall_of_fame":
			await Field.enter_hall_of_fame()
		"view_hall_of_fame":
			await Field.show_hall_of_fame()
		"show_credits":
			locals["result"] = await Field.show_credits()
		"return_to_title":
			# Whatever was drawn over the map goes with the session, or a
			# half-finished cutscene would still be on the title screen.
			FieldPictures.erase_all()
			_flow = Flow.EXIT
			await SceneRouter.return_to_title()

		# === Movement ===
		"move":
			await _do_move(statement)
		"turn":
			_do_turn(statement)
		"jump":
			await _do_jump(statement)
		"set_speed":
			var walker: GridCharacter = _character(statement, 0)
			if walker != null:
				walker.seconds_per_tile = GridCharacter.speed_to_seconds(
					clampi(int(_number(statement, 1)), 1, 6)
				)
		"set_graphic":
			var dressed: GridCharacter = _character(statement, 0)
			if dressed != null:
				dressed.set_charset(_text_of(statement, 1))
		"set_opacity":
			var faded: GridCharacter = _character(statement, 0)
			if faded != null:
				faded.modulate.a = clampf(_number(statement, 1) / 255.0, 0.0, 1.0)
		"set_through":
			var ghost: GridCharacter = _character(statement, 0)
			if ghost != null:
				ghost.passable = _flag(statement, 1)
		"set_position":
			_do_set_position(statement)
		"show":
			var shown: GridCharacter = _character(statement, 0)
			if shown != null:
				shown.visible = true
		"hide":
			var hidden: GridCharacter = _character(statement, 0)
			if hidden != null:
				hidden.visible = false
		"face_player":
			_do_face_player(statement)
		"warp":
			await _do_warp(statement)
		"warp_scene":
			await _do_warp_scene(statement)
		"teleport":
			if map != null:
				map.move_player_to(
					Vector2i(int(_number(statement, 0)), int(_number(statement, 1))),
					_direction_argument(statement, 2)
				)

		# === Presentation ===
		"play_se":
			AudioManager.play_se(_text_of(statement, 0), _volume(statement, 1), _pitch(statement, 2))
		"play_bgm":
			AudioManager.play_bgm(_text_of(statement, 0), _volume(statement, 1), _pitch(statement, 2))
		"play_bgs":
			AudioManager.play_bgs(_text_of(statement, 0), _volume(statement, 1), _pitch(statement, 2))
		"play_me":
			AudioManager.play_me(_text_of(statement, 0), _volume(statement, 1))
		"play_cry":
			AudioManager.play_cry(_id(statement, 0), 0, _pitch(statement, 1))
		"stop_se":
			AudioManager.stop_all_se()
		"stop_bgm":
			AudioManager.stop_bgm()
		"fade_out_bgm":
			AudioManager.fade_out_bgm(_number(statement, 0) if not statement.arguments.is_empty() else -1.0)
		"stop_bgs":
			AudioManager.stop_bgs()
		"fade_out":
			await SceneRouter.fade_out()
		"fade_in":
			await SceneRouter.fade_in()
		"set_tone":
			await _do_set_tone(statement)
		"clear_tone":
			await Field.clear_tone(_frames(statement, 0))
		"flash_screen":
			Field.flash_screen(_colour(statement, 0), _frames(statement, 1, DEFAULT_FLASH_SECONDS))
		"shake_screen":
			_do_shake_screen(statement)
		"wait_for_shake":
			await Field.wait_for_shake()
		"set_weather":
			Field.set_weather(_id(statement, 0), _power(statement, 1), _seconds(statement, 2))
		"clear_weather":
			Field.clear_weather(_seconds(statement, 0))
		"message_box":
			_do_message_box(statement)
		"play_animation":
			_do_play_animation(statement)
		"remember_music":
			AudioManager.memorize_bgm_bgs()
		"restore_music":
			AudioManager.restore_bgm_bgs()

		# === Pictures ===
		"show_picture":
			_do_show_picture(statement)
		"move_picture":
			_do_move_picture(statement)
		"rotate_picture":
			FieldPictures.rotate(int(_number(statement, 0)), _number(statement, 1))
		"tint_picture":
			_do_tint_picture(statement)
		"erase_picture":
			FieldPictures.erase(int(_number(statement, 0)))
		"erase_pictures":
			FieldPictures.erase_all()

		# === Battles ===
		"wild_battle":
			await _do_wild_battle(statement)
		"double_wild_battle":
			await _do_double_wild_battle(statement)
		"trainer_battle":
			await _do_trainer_battle(statement)

		# === Wild Encounters ===
		"encounters":
			Field.set_encounters_enabled(_flag(statement, 0))
		"single_battle_next":
			Field.force_single_battle()
		"encounter":
			var encounter_type: StringName = &"Land"
			if statement.argument(0) != null:
				encounter_type = _id(statement, 0)
			locals["result"] = await Field.table_encounter(encounter_type)
		"surf":
			locals["result"] = await Field.surf()
		"stop_surfing":
			Field.stop_surfing()
		"dive":
			locals["result"] = await Field.dive()
		"dive_now":
			await Field.dive_now()
		"surface_now":
			await Field.surface_now()
		"fish":
			var rod: StringName = _id(statement, 0) if statement.argument(0) != null else &"OLDROD"
			locals["result"] = await Field.fish(rod)
		"sweet_scent":
			locals["result"] = await Field.sweet_scent()
		"rock_smash_encounter":
			locals["result"] = await Field.rock_smash_encounter()
		"headbutt_encounter":
			var low: bool = statement.argument(0) != null and _truth(statement, 0)
			locals["result"] = await Field.headbutt_encounter(low)

		# === Event ===
		"erase":
			if event != null:
				event.erase()
			_flow = Flow.EXIT

		# === Escape Hatch ===
		"script":
			await _do_script(statement)
		"debug":
			print("[event script] %s: %s" % [statement.where(), _text_of(statement, 0)])

		_:
			report("there is no command called %s" % statement.written_as, statement.line)

# === Dialogue ===
## Shows a translated message.
func _do_say(statement: EventScriptStatement) -> void:
	if statement.arguments.is_empty():
		return
	await _say(_translated_text(statement.arguments, "\n"))

## Translates expressions and fills their placeholders.
func _translated_text(expressions: Array[EventScriptExpression], separator: String) -> String:
	var templates: PackedStringArray = PackedStringArray()
	var params: Dictionary = {}
	for expression: EventScriptExpression in expressions:
		if expression.is_translatable_text():
			expression.collect_translation_params(self, params)
			templates.append(expression.translation_template())
			continue
		var hole: String = expression.to_source()
		params[hole] = EventScriptCast.to_text(expression.evaluate(self))
		templates.append("{%s}" % hole)
	return Loc.line(separator.join(templates), params)

## Returns one translated argument, or an empty string.
func _translated_argument(statement: EventScriptStatement, index: int) -> String:
	var argument: EventScriptExpression = statement.argument(index)
	if argument == null:
		return ""
	return _translated_text([argument] as Array[EventScriptExpression], "")

## Shows a menu and runs the selected branch.
func _do_choice(statement: EventScriptStatement) -> void:
	var first_option: int = 1 if statement.keyword == "ask" else 0
	var prompt: String = _translated_argument(statement, 0) if first_option == 1 else ""
	var options: Array = []
	var labels: Array = []
	for index: int in range(first_option, statement.arguments.size()):
		var argument: EventScriptExpression = statement.arguments[index]
		options.append(_translated_text([argument], ""))
		labels.append(EventScriptCast.to_text(argument.evaluate(self)))
	if options.is_empty():
		report("%s has no options to offer" % statement.written_as, statement.line)
		return

	var cancel_branch: EventScriptStatement = statement.first_child_of(["cancel"])
	var cancel_index: int = MessageBox.CANCELLED if cancel_branch != null else ParsedMessage.CANCEL_DISALLOWED
	var picked: int = await _ask(options, prompt, cancel_index)
	locals["chosen"] = picked
	locals["chosen_label"] = String(labels[picked]) if picked >= 0 and picked < labels.size() else ""

	if picked < 0:
		if cancel_branch != null:
			await _execute_block(cancel_branch.children)
		return
	var branch: EventScriptStatement = _matching_when(statement, picked, String(labels[picked]))
	if branch != null:
		await _execute_block(branch.children)

## Finds the branch for the selected option.
func _matching_when(
	statement: EventScriptStatement, picked: int, label: String
) -> EventScriptStatement:
	var fallback: EventScriptStatement = null
	for child: EventScriptStatement in statement.children:
		if child.keyword == "else":
			fallback = child
			continue
		if child.keyword != "when":
			continue
		for argument: EventScriptExpression in child.arguments:
			var wanted: Variant = argument.evaluate(self)
			if wanted is int or wanted is float:
				if int(wanted) == picked + 1:
					return child
			elif EventScriptCast.to_text(wanted) == label:
				return child
	return fallback

func _do_confirm(statement: EventScriptStatement) -> void:
	var agreed: bool = await _confirm(_translated_argument(statement, 0))
	locals["result"] = agreed
	locals["chosen"] = 0 if agreed else 1
	var branch: EventScriptStatement = statement.first_child_of(["yes"] if agreed else ["no"])
	if branch != null:
		await _execute_block(branch.children)

# === Flow ===
func _do_while(statement: EventScriptStatement) -> void:
	var passes: int = 0
	while _truth(statement, 0):
		passes += 1
		if not await _loop_guard(passes, statement):
			return
		await _execute_block(statement.children)
		if not _continue_loop():
			return

func _do_repeat(statement: EventScriptStatement) -> void:
	var total: int = int(_number(statement, 0))
	var outer: Variant = locals.get("index")
	for pass_number: int in maxi(total, 0):
		locals["index"] = pass_number
		if not await _loop_guard(pass_number + 1, statement):
			break
		await _execute_block(statement.children)
		if not _continue_loop():
			break
	# A nested repeat puts the outer count back, so the lines after it still read
	# the pass they belong to.
	if outer == null:
		locals.erase("index")
	else:
		locals["index"] = outer

func _do_loop(statement: EventScriptStatement) -> void:
	var passes: int = 0
	while true:
		passes += 1
		if not await _loop_guard(passes, statement):
			return
		await _execute_block(statement.children)
		if not _continue_loop():
			return

## Handles loop control and reports whether the loop continues.
func _continue_loop() -> bool:
	match _flow:
		Flow.CONTINUE:
			_flow = Flow.NORMAL
			return true
		Flow.BREAK:
			_flow = Flow.NORMAL
			return false
		Flow.NORMAL:
			return true
	return false

## Yields during long loops and stops runaway loops.
func _loop_guard(passes: int, statement: EventScriptStatement) -> bool:
	if passes > MAX_LOOP_PASSES:
		report("this loop never ends; stopping it", statement.line)
		_flow = Flow.EXIT
		return false
	if passes % PASSES_PER_FRAME == 0:
		await _next_frame()
	return true

func _do_call(statement: EventScriptStatement) -> void:
	var name: String = _call_target(statement)
	if _depth >= MAX_CALL_DEPTH:
		report("call went %d deep at %s; stopping" % [MAX_CALL_DEPTH, name], statement.line)
		_flow = Flow.EXIT
		return

	var arguments: Array = []
	for index: int in range(1, statement.arguments.size()):
		arguments.append(statement.arguments[index].evaluate(self))

	if program != null and program.has_routine(name):
		await _call_routine(name, arguments, statement)
		return
	await _call_file(name, arguments, statement)

## Runs a routine with the current locals.
func _call_routine(name: String, arguments: Array, statement: EventScriptStatement) -> void:
	var saved_flow: Flow = _flow
	var saved_return: Variant = _return_value
	var saved_arguments: Dictionary = _bind_arguments(arguments)
	_depth += 1
	_flow = Flow.NORMAL
	_return_value = null
	await _execute_block(program.routine(name))
	if _flow == Flow.GOTO:
		report("routine %s has no label called %s" % [name, _goto_label], statement.line)
	var returned: Variant = _return_value
	_depth -= 1
	_restore_arguments(saved_arguments)
	# A routine that exits the script takes the caller with it; one that simply
	# returns hands control back.
	if _flow != Flow.EXIT:
		_flow = saved_flow
	_return_value = saved_return
	locals["result"] = returned

## Runs another script with its own locals.
func _call_file(name: String, arguments: Array, statement: EventScriptStatement) -> void:
	var script: EventScript = EventScript.load_script(name)
	if script == null:
		report("there is no routine or script file called %s" % name, statement.line)
		return
	var runner: EventScriptRunner = EventScriptRunner.new()
	runner.program = script.program()
	runner.event = event
	runner.map = map
	runner._depth = _depth + 1
	runner._bind_arguments(arguments)
	locals["result"] = await runner.run()
	if runner._flow == Flow.EXIT:
		_flow = Flow.EXIT

## Sets call arguments as locals and returns their previous values.
func _bind_arguments(arguments: Array) -> Dictionary:
	var saved: Dictionary = {"arg_count": locals.get("arg_count")}
	locals["arg_count"] = arguments.size()
	for index: int in arguments.size():
		var name: String = "arg%d" % (index + 1)
		saved[name] = locals.get(name)
		locals[name] = arguments[index]
	return saved

func _restore_arguments(saved: Dictionary) -> void:
	for name: String in saved:
		if saved[name] == null:
			locals.erase(name)
		else:
			locals[name] = saved[name]

## Resolves a call to a local routine or script file.
func _call_target(statement: EventScriptStatement) -> String:
	if statement.arguments.is_empty():
		return ""
	return EventScriptCast.to_text(statement.arguments[0].evaluate(self))

# === State ===
func _do_set(statement: EventScriptStatement) -> void:
	var name: String = _name_of(statement.argument(0))
	if name.is_empty() or statement.arguments.size() < 2:
		report("%s needs a name to set" % statement.written_as, statement.line)
		return
	if RESERVED_LOCALS.has(name):
		report("%s is set by the engine and cannot be assigned" % name, statement.line)
		return
	# Everything after the name is one value; the extra arguments only turn up
	# when a comma split them, so they are joined back as a list.
	if statement.arguments.size() == 2:
		locals[name] = statement.arguments[1].evaluate(self)
		return
	var gathered: Array = []
	for index: int in range(1, statement.arguments.size()):
		gathered.append(statement.arguments[index].evaluate(self))
	locals[name] = gathered

func _do_self_switch(statement: EventScriptStatement) -> void:
	if event == null:
		report("there is no event here to set a self-switch on", statement.line)
		return
	var switch: String = _text_of(statement, 0).to_upper()
	if not ["A", "B", "C", "D"].has(switch):
		report("a self-switch is called A, B, C or D, not %s" % switch, statement.line)
		return
	Field.set_self_switch(event, switch, _flag(statement, 1))

# === Player ===
func _do_give_item(statement: EventScriptStatement, announce: bool) -> void:
	var item_id: StringName = _id(statement, 0)
	var quantity: int = _count(statement, 1)
	var record: ItemData = Database.item(item_id)
	if record == null:
		report("there is no item called %s" % item_id, statement.line)
		locals["result"] = false
		return
	if not GameState.bag.add_item(item_id, quantity):
		if announce:
			await _say("There is no room left in the Bag.")
		locals["result"] = false
		return
	locals["result"] = true
	if not announce:
		return
	var received: String = record.get_display_name(quantity)
	if quantity > 1:
		received = "%s (x%d)" % [received, quantity]
	await _say(Loc.line("{player} obtained {received}!", {"player": player_name(), "received": received}))

func _do_give_pokemon(statement: EventScriptStatement, announce: bool) -> void:
	var species_id: StringName = _id(statement, 0)
	if Database.species(species_id) == null:
		report("there is no species called %s" % species_id, statement.line)
		locals["result"] = false
		return
	var receipt: PokemonReceipt = _make_receipt(announce)
	var given: Pokemon = await receipt.give_species(species_id, _level(statement, 1))
	locals["result"] = given != null and receipt.destination != PokemonReceipt.Destination.NOWHERE

## Builds a receipt for the current message box.
func _make_receipt(announce: bool) -> PokemonReceipt:
	var receipt: PokemonReceipt = PokemonReceipt.new()
	if not announce:
		receipt.offer_nickname = false
		return receipt
	receipt.narrate = func(text: String) -> void:
		await _say(text)
	receipt.ask = func(options: Array) -> int:
		# Backing out of a yes/no question means no, which is the second option.
		return await _ask(options, "", 2)
	return receipt

func _add_to_party(species_id: StringName, level: int) -> bool:
	if Database.species(species_id) == null or GameState.party.is_full():
		return false
	var owner: PokemonOwner = GameState.player.owner_record() if GameState.player != null else null
	var pkmn: Pokemon = Pokemon.create(species_id, level, owner)
	if not GameState.party.add(pkmn):
		return false
	if GameState.player != null:
		GameState.player.pokedex.register_owned(pkmn)
	return true

## Shows the player's map or a wall map.
func _do_show_town_map(statement: EventScriptStatement) -> void:
	var wall_map: bool = true
	if statement.argument(0) != null:
		wall_map = _text_of(statement, 0).strip_edges().to_lower() != "own"
	var region: int = -1
	if statement.argument(1) != null:
		region = int(_number(statement, 1))
	await Field.show_town_map(wall_map, region)

# === Followers ===
## Sets the follower mode.
func _do_follower_mode(statement: EventScriptStatement) -> void:
	var written: String = _text_of(statement, 0).strip_edges().to_lower()
	if written.is_empty() or written == "default" or written == "player":
		Field.clear_follower_mode()
		return
	var mode: int = FollowerMode.from_name(written)
	if mode < 0:
		report("'%s' is not a follower mode." % written, statement.line)
		return
	Field.set_follower_mode(mode)

## Adds a party member or species as a follower.
func _do_add_follower(statement: EventScriptStatement) -> bool:
	var first: Variant = _value(statement, 0)
	if first is int or first is float:
		return Field.add_temporary_follower(_slot(statement, 0))
	var form: int = int(_number(statement, 1)) if statement.argument(1) != null else 0
	var shiny: bool = _truth(statement, 2) if statement.argument(2) != null else false
	var female: bool = _truth(statement, 3) if statement.argument(3) != null else false
	var called: String = _text_of(statement, 4) if statement.argument(4) != null else ""
	return Field.add_temporary_species_follower(EventScriptCast.to_id(first), form, shiny, female, called)

# === Pokegear ===
## Registers the current event as a phone contact.
func _do_phone_register(statement: EventScriptStatement) -> bool:
	var book: PhoneBook = GameState.phone
	if statement.argument(1) == null:
		return await _announce_registration(book.add_contact(
			_text_of(statement, 0), 0, GameState.map_id
		))
	var parties: int = int(_number(statement, 2)) if statement.argument(2) != null else 1
	var version: int = int(_number(statement, 3)) if statement.argument(3) != null else 0
	return await _announce_registration(book.add_trainer(
		_id(statement, 0), _text_of(statement, 1), version,
		GameState.map_id, event.event_id if event != null else 0, parties
	))

## Checks whether a phone contact is registered.
func _do_phone_registered(statement: EventScriptStatement) -> bool:
	var book: PhoneBook = GameState.phone
	if statement.argument(1) == null:
		return book.get_contact(_text_of(statement, 0)) != null
	var version: int = int(_number(statement, 2)) if statement.argument(2) != null else 0
	return book.get_trainer(_id(statement, 0), _text_of(statement, 1), version) != null

func _do_phone_call(statement: EventScriptStatement) -> bool:
	if statement.argument(1) == null:
		return await Field.phone_call(StringName(_text_of(statement, 0)))
	var version: int = int(_number(statement, 2)) if statement.argument(2) != null else 0
	return await Field.phone_call(_id(statement, 0), _text_of(statement, 1), version)

func _announce_registration(contact: PhoneContact) -> bool:
	if contact == null:
		return false
	await Field.say(Loc.line(
		"\\me[Register phone]Registered {contact} in the Pokegear!\\wtnp[60]",
		{"contact": contact.display_name()}
	))
	return true

# === Presentation ===
## Changes the screen tone and waits for it to finish.
func _do_set_tone(statement: EventScriptStatement) -> void:
	var grey: int = int(_number(statement, 3)) if statement.argument(3) != null else 0
	await Field.change_tone(
		int(_number(statement, 0)), int(_number(statement, 1)), int(_number(statement, 2)),
		grey, _frames(statement, 4)
	)

## Sets message box position and frame style.
func _do_message_box(statement: EventScriptStatement) -> void:
	var position: MessageBox.WindowPosition = MessageBox.WindowPosition.BOTTOM
	match _text_of(statement, 0).to_lower():
		"top":
			position = MessageBox.WindowPosition.TOP
		"middle", "centre", "center":
			position = MessageBox.WindowPosition.MIDDLE
		"bottom":
			position = MessageBox.WindowPosition.BOTTOM
		_:
			report("a message box opens at the top, the middle or the bottom", statement.line)
			return
	Field.set_text_options(position, _flag(statement, 1))

## Plays an overworld animation on a character.
func _do_play_animation(statement: EventScriptStatement) -> void:
	if map == null:
		return
	var over: GridCharacter = event if statement.argument(1) == null else _character(statement, 1)
	if over == null:
		report("there is nobody called %s to animate" % _text_of(statement, 1), statement.line)
		return
	OverworldEffects.play_animation_number(map, int(_number(statement, 0)), over)

# === Pictures ===
## Shows a picture at the given position and size.
func _do_show_picture(statement: EventScriptStatement) -> void:
	FieldPictures.show(
		int(_number(statement, 0)),
		_text_of(statement, 1),
		FieldPicture.ORIGIN_TOP_LEFT,
		_picture_position(statement, 2),
		_picture_zoom(statement, 5),
		_opacity(statement, 4),
		FieldPicture.BLEND_NORMAL
	)

## Moves a picture without waiting for the animation.
func _do_move_picture(statement: EventScriptStatement) -> void:
	FieldPictures.move(
		int(_number(statement, 0)),
		_frames(statement, 3),
		FieldPicture.ORIGIN_TOP_LEFT,
		_picture_position(statement, 1),
		_picture_zoom(statement, 5),
		_opacity(statement, 4),
		FieldPicture.BLEND_NORMAL
	)

## Tints a picture.
func _do_tint_picture(statement: EventScriptStatement) -> void:
	var tint: Color = Color(
		clampf(1.0 + _number(statement, 1) / ScreenEffects.TONE_RANGE, 0.0, 2.0),
		clampf(1.0 + _number(statement, 2) / ScreenEffects.TONE_RANGE, 0.0, 2.0),
		clampf(1.0 + _number(statement, 3) / ScreenEffects.TONE_RANGE, 0.0, 2.0)
	)
	FieldPictures.tone(int(_number(statement, 0)), tint, _frames(statement, 4))

func _picture_position(statement: EventScriptStatement, index: int) -> Vector2:
	return Vector2(_number(statement, index), _number(statement, index + 1))

## Reads optional picture zoom.
func _picture_zoom(statement: EventScriptStatement, index: int) -> Vector2:
	if statement.argument(index) == null:
		return Vector2(100.0, 100.0)
	var percent: float = _number(statement, index)
	return Vector2(percent, percent)

## Reads optional picture opacity.
func _opacity(statement: EventScriptStatement, index: int) -> int:
	if statement.argument(index) == null:
		return 255
	return clampi(int(_number(statement, index)), 0, 255)

## Starts a screen shake without waiting.
func _do_shake_screen(statement: EventScriptStatement) -> void:
	Field.shake_screen(
		_power(statement, 0), _power(statement, 1),
		_frames(statement, 2, DEFAULT_SHAKE_SECONDS)
	)

# === Movement ===
func _do_move(statement: EventScriptStatement) -> void:
	var walker: GridCharacter = _character(statement, 0)
	if walker == null:
		report("there is nobody called %s to move" % EventScriptCast.to_text(_value(statement, 0)), statement.line)
		return
	for index: int in range(1, statement.arguments.size()):
		var step: String = EventScriptCast.to_text(statement.arguments[index].evaluate(self)).to_lower()
		await _one_step(walker, step, statement)

func _one_step(walker: GridCharacter, step: String, statement: EventScriptStatement) -> void:
	match step:
		"up", "down", "left", "right":
			await walker.step(_direction_named(step))
		"forward", "ahead":
			await walker.step(walker.facing)
		"back", "backward":
			await walker.force_step(GridCharacter.opposite(walker.facing))
		"up_left", "up_right", "down_left", "down_right":
			# A diagonal takes whichever way around the corner is open, which is
			# what a staircase and a step around a table both need.
			var parts: PackedStringArray = step.split("_")
			await walker.step_diagonal(_direction_named(parts[1]), _direction_named(parts[0]))
		"random":
			var options: Array[int] = [
				GridCharacter.Direction.DOWN, GridCharacter.Direction.LEFT,
				GridCharacter.Direction.RIGHT, GridCharacter.Direction.UP,
			]
			await walker.step(options[RNG.below(4)] as GridCharacter.Direction)
		"toward", "toward_player":
			var towards: GridCharacter = player()
			if towards != null:
				await walker.step(
					GridCharacter.direction_towards(walker.tile_position, towards.tile_position)
				)
		"away", "away_from_player":
			var from: GridCharacter = player()
			if from != null:
				await walker.step(GridCharacter.opposite(
					GridCharacter.direction_towards(walker.tile_position, from.tile_position)
				))
		_:
			report("%s is not a direction to move in" % step, statement.line)

func _do_turn(statement: EventScriptStatement) -> void:
	var turner: GridCharacter = _character(statement, 0)
	if turner == null:
		report("there is nobody called %s to turn" % EventScriptCast.to_text(_value(statement, 0)), statement.line)
		return
	var which: String = _text_of(statement, 1).to_lower()
	match which:
		"up", "down", "left", "right":
			turner.turn(_direction_named(which))
		"around", "back":
			turner.turn(GridCharacter.opposite(turner.facing))
		"player", "toward", "toward_player":
			var towards: GridCharacter = player()
			if towards != null:
				turner.turn(GridCharacter.direction_towards(turner.tile_position, towards.tile_position))
		"away", "away_from_player":
			var from: GridCharacter = player()
			if from != null:
				turner.turn(GridCharacter.opposite(
					GridCharacter.direction_towards(turner.tile_position, from.tile_position)
				))
		"random":
			var options: Array[int] = [
				GridCharacter.Direction.DOWN, GridCharacter.Direction.LEFT,
				GridCharacter.Direction.RIGHT, GridCharacter.Direction.UP,
			]
			turner.turn(options[RNG.below(4)] as GridCharacter.Direction)
		_:
			report("%s is not a direction to turn to" % which, statement.line)

func _do_jump(statement: EventScriptStatement) -> void:
	var jumper: GridCharacter = _character(statement, 0)
	if jumper == null:
		return
	await jumper.jump(Vector2i(int(_number(statement, 1)), int(_number(statement, 2))))

func _do_face_player(statement: EventScriptStatement) -> void:
	var turner: GridCharacter = _character(statement, 0) if not statement.arguments.is_empty() else event
	var towards: GridCharacter = player()
	if turner == null or towards == null:
		return
	turner.turn(GridCharacter.direction_towards(turner.tile_position, towards.tile_position))

func _do_set_position(statement: EventScriptStatement) -> void:
	var placed: GridCharacter = _character(statement, 0)
	if placed == null:
		return
	placed.tile_position = Vector2i(int(_number(statement, 1)), int(_number(statement, 2)))
	placed.position = MapGrid.cell_to_pixel(placed.tile_position)
	var facing: int = _direction_argument(statement, 3)
	if facing > 0:
		placed.facing = facing as GridCharacter.Direction

func _do_warp(statement: EventScriptStatement) -> void:
	await Field.warp_to_map(
		int(_number(statement, 0)),
		Vector2i(int(_number(statement, 1)), int(_number(statement, 2))),
		_direction_argument(statement, 3)
	)

func _do_warp_scene(statement: EventScriptStatement) -> void:
	var path: String = _text_of(statement, 0)
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		report("there is no map scene at %s" % path, statement.line)
		return
	var spawn: StringName = StringName(_text_of(statement, 1)) if statement.arguments.size() > 1 else &""
	await Field.warp(scene, spawn, _direction_argument(statement, 2))

func _wait_for_movement() -> void:
	if map == null:
		return
	while true:
		var moving: bool = map.player != null and map.player.is_moving
		for other: MapEvent in map.all_events():
			moving = moving or other.is_moving
		if not moving:
			return
		await _next_frame()

# === Battles ===
func _do_wild_battle(statement: EventScriptStatement) -> void:
	var species_id: StringName = _id(statement, 0)
	if Database.species(species_id) == null:
		report("there is no species called %s" % species_id, statement.line)
		return
	_record_outcome(await Field.wild_battle(species_id, _level(statement, 1)))

func _do_double_wild_battle(statement: EventScriptStatement) -> void:
	var first: StringName = _id(statement, 0)
	var second: StringName = _id(statement, 1)
	for species_id: StringName in [first, second]:
		if Database.species(species_id) == null:
			report("there is no species called %s" % species_id, statement.line)
			return
	var first_level: int = _level(statement, 2)
	# One level given is taken to mean both, which is what an event asking for a
	# pair of the same strength wants to write.
	var second_level: int = first_level if statement.argument(3) == null else _level(statement, 3)
	_record_outcome(await Field.double_wild_battle(first, first_level, second, second_level))

func _do_trainer_battle(statement: EventScriptStatement) -> void:
	var version: int = int(_number(statement, 2)) if statement.arguments.size() > 2 else 0
	_record_outcome(await Field.trainer_battle(_id(statement, 0), _text_of(statement, 1), version))

## Stores the battle result in locals.
func _record_outcome(outcome: BattlePresenter.Outcome) -> void:
	locals["battle_result"] = int(outcome)
	locals["battle_won"] = outcome == BattlePresenter.Outcome.PLAYER_WON
	locals["battle_lost"] = outcome == BattlePresenter.Outcome.PLAYER_LOST
	locals["battle_fled"] = outcome == BattlePresenter.Outcome.PLAYER_FLED
	locals["battle_caught"] = outcome == BattlePresenter.Outcome.POKEMON_CAUGHT
	locals["result"] = locals["battle_won"]

# === Escape Hatch ===
func _do_script(statement: EventScriptStatement) -> void:
	var snippet: String = _text_of(statement, 0)
	var outcome: Variant = await _essentials().run(snippet)
	if outcome is EventScriptBridge.Unsupported:
		report("%s has no counterpart in this engine" % snippet, statement.line)
		locals["result"] = null
		return
	locals["result"] = outcome

## Creates the Essentials bridge when first needed.
func _essentials() -> EventScriptBridge:
	if _script_bridge != null:
		return _script_bridge
	if map != null:
		_bridge_interpreter = EventInterpreter.new()
		_bridge_interpreter.name = "ScriptBridgeInterpreter"
		_bridge_interpreter.map = map
		map.add_child(_bridge_interpreter)
		_bridge_interpreter.adopt_event(event)
	_script_bridge = EventScriptBridge.new(_bridge_interpreter)
	return _script_bridge

func _release_bridge() -> void:
	if _bridge_interpreter != null and is_instance_valid(_bridge_interpreter):
		_bridge_interpreter.queue_free()
	_bridge_interpreter = null
	_script_bridge = null

# === Builtins ===
## Calls an expression builtin.
func call_builtin(name: String, arguments: Array, line: int) -> Variant:
	return EventScriptBuiltins.call_function(self, name, arguments, line)

# === Talking ===
func _say(text: String) -> void:
	if map == null:
		push_warning("EventScriptRunner: there is no field to say %s on." % text)
		return
	await map.say(text)

func _ask(options: Array, prompt: String, cancel_index: int) -> int:
	if map == null:
		return -1
	return await map.ask(options, prompt, cancel_index)

func _confirm(question: String) -> bool:
	# Backing out of a yes/no question counts as no, which is the second option.
	return await _ask(["Yes", "No"], question, 2) == 0

## Returns the player's name.
func player_name() -> String:
	return GameState.player.name if GameState.player != null else "You"

# === Arguments ===
func _value(statement: EventScriptStatement, index: int) -> Variant:
	var argument: EventScriptExpression = statement.argument(index)
	return argument.evaluate(self) if argument != null else null

func _text_of(statement: EventScriptStatement, index: int) -> String:
	return EventScriptCast.to_text(_value(statement, index))

func _number(statement: EventScriptStatement, index: int) -> float:
	return EventScriptCast.to_number(_value(statement, index))

func _truth(statement: EventScriptStatement, index: int) -> bool:
	return EventScriptCast.to_bool(_value(statement, index))

func _id(statement: EventScriptStatement, index: int) -> StringName:
	return EventScriptCast.to_id(_value(statement, index))

## Reads an optional on/off argument.
func _flag(statement: EventScriptStatement, index: int) -> bool:
	if statement.argument(index) == null:
		return true
	return EventScriptCast.to_bool(_value(statement, index))

## Reads a one-based party slot.
func _slot(statement: EventScriptStatement, index: int) -> int:
	return maxi(int(_number(statement, index)), 1) - 1

## Reads an optional positive count.
func _count(statement: EventScriptStatement, index: int) -> int:
	if statement.argument(index) == null:
		return 1
	return maxi(int(_number(statement, index)), 1)

## Reads an optional level.
func _level(statement: EventScriptStatement, index: int) -> int:
	if statement.argument(index) == null:
		return 5
	return maxi(int(_number(statement, index)), 1)

## Reads a duration in seconds.
func _seconds(statement: EventScriptStatement, index: int, fallback: float = 0.0) -> float:
	if statement.argument(index) == null:
		return fallback
	return maxf(_number(statement, index), 0.0)

## Reads a duration in frames.
func _frames(statement: EventScriptStatement, index: int, fallback: float = 0.0) -> int:
	return roundi(_seconds(statement, index, fallback) * ScreenEffects.FRAMES_PER_SECOND)

## Reads an optional colour.
func _colour(statement: EventScriptStatement, index: int) -> Color:
	if statement.argument(index) == null:
		return Color.WHITE
	return Color.from_string(_text_of(statement, index), Color.WHITE)

## Reads an optional weather or shake power.
func _power(statement: EventScriptStatement, index: int, fallback: int = 5) -> int:
	if statement.argument(index) == null:
		return fallback
	return clampi(int(_number(statement, index)), 0, 9)

func _volume(statement: EventScriptStatement, index: int) -> float:
	if statement.argument(index) == null:
		return 1.0
	return _number(statement, index)

func _pitch(statement: EventScriptStatement, index: int) -> float:
	if statement.argument(index) == null:
		return 1.0
	return _number(statement, index)

## Reads an optional facing.
func _direction_argument(statement: EventScriptStatement, index: int) -> int:
	if statement.argument(index) == null:
		return 0
	var written: Variant = _value(statement, index)
	if written is int or written is float:
		return int(written)
	return int(_direction_named(EventScriptCast.to_text(written)))

static func _direction_named(name: String) -> GridCharacter.Direction:
	match name.to_lower():
		"up", "north":
			return GridCharacter.Direction.UP
		"left", "west":
			return GridCharacter.Direction.LEFT
		"right", "east":
			return GridCharacter.Direction.RIGHT
	return GridCharacter.Direction.DOWN

## Reads a facing value.
static func direction_name(direction: int) -> String:
	match direction:
		GridCharacter.Direction.UP:
			return "up"
		GridCharacter.Direction.LEFT:
			return "left"
		GridCharacter.Direction.RIGHT:
			return "right"
	return "down"

## Reads a local name.
static func _name_of(expression: EventScriptExpression) -> String:
	if expression == null:
		return ""
	if expression.kind == EventScriptExpression.Kind.IDENTIFIER:
		return String(expression.value)
	if expression.kind == EventScriptExpression.Kind.LITERAL:
		return String(expression.value)
	return ""

# === Characters ===
func _character(statement: EventScriptStatement, index: int) -> GridCharacter:
	return character_from(_value(statement, index))

## Resolves a character name or id.
func character_from(who: Variant) -> GridCharacter:
	if who is int or who is float:
		return map.event_by_id(int(who)) if map != null else null
	var name: String = EventScriptCast.to_text(who)
	match name.to_lower():
		"self", "this", "me", "":
			return event
		"player", "hero":
			return player()
	if map == null:
		return null
	for other: MapEvent in map.all_events():
		if String(other.name) == name or other.display_name() == name:
			return other
	return null

## Returns the player character.
func player() -> GridCharacter:
	if map != null:
		return map.player
	return Field.player()

# === Locals ===
func has_local(name: String) -> bool:
	return locals.has(name)

func get_local(name: String) -> Variant:
	return locals.get(name)

# === Timing ===
func _wait(seconds: float) -> void:
	var tree: SceneTree = _tree()
	if tree == null or seconds <= 0.0:
		return
	await tree.create_timer(seconds).timeout

func _next_frame() -> void:
	var tree: SceneTree = _tree()
	if tree == null:
		return
	await tree.process_frame

func _tree() -> SceneTree:
	if map != null and map.is_inside_tree():
		return map.get_tree()
	return Engine.get_main_loop() as SceneTree

# === Reports ===
## Reports a problem once, naming the script and the line it is on.
func report(message: String, line: int) -> void:
	var key: String = "%d:%s" % [line, message]
	if _reported.has(key):
		return
	_reported[key] = true
	var where: String = program.source_name if program != null else ""
	if where.is_empty():
		where = "event script"
	push_warning("%s:%d: %s" % [where, line, message])
