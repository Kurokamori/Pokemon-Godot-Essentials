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



func is_running() -> bool:
	return _running

## Runs a command list on behalf of [param source_event]
## Creates a `self` for self switches and the like
func run_commands(commands: Array[MapEventCommand], source_event: MapEvent = null) -> void:
	if _running:
		push_warning("EventInterpreter: asked to run a command list while one is already running.")
		return
	_running = true
	_current_event = source_event
	_commands = commands
	_pointer = 0
	_pending_text = ""
	_choice_renames.clear()
	_choice_hides.clear()
	_choice_group_ends.clear()
	_index_labels()
	event_started.emit(_event_label())

	while _pointer < _commands.size():
		var command: MapEventCommand = _commands[_pointer]
		_pointer += 1
		await _execute(command)
		if not _running:
			break

	await _flush_text()
	_finish_run()

## Runs the named Common Event
func _call_common_event(parameters: Array) -> void:
	if parameters.is_empty():
		return
	var number: int = int(parameters[0])
	var commands: Array[MapEventCommand] = CommonEvents.commands_of(number)
	if commands.is_empty():
		if Database.common_event(number) == null:
			var key: String = "common_event_missing"
			if not _reported_unsupported.has(key):
				_reported_unsupported[key] = true
				push_warning(
					"EventInterpreter: common event %d was called and the project has no such event. Add its record under res://data/common_events/."
					% number)
		return
	await _run_nested(commands)


## Runs [param commands] inside the run that is already going, putting this interpreter's own place back afterwards.
func _run_nested(commands: Array[MapEventCommand]) -> void:
	var outer_commands: Array[MapEventCommand] = _commands
	var outer_pointer: int = _pointer
	var outer_labels: Dictionary = _labels
	var outer_group_ends: Array[int] = _choice_group_ends
	await _flush_text()

	_commands = commands
	_pointer = 0
	_labels = {}
	_choice_group_ends = []
	_index_labels()
	while _pointer < _commands.size():
		var command: MapEventCommand = _commands[_pointer]
		_pointer += 1
		await _execute(command)
		if not _running:
			break
	await _flush_text()

	_commands = outer_commands
	_pointer = outer_pointer
	_labels = outer_labels
	_choice_group_ends = outer_group_ends

func _finish_run() -> void:
	_running = false
	_pending_text = ""
	event_finished.emit(_event_label())
	_current_event = null

## The event whose commands are running, 
## Returns `null` between runs.
func current_event() -> MapEvent:
	return _current_event

## Points the interpreter at [param event] without running a command list on it
func adopt_event(event: MapEvent) -> void:
	_current_event = event

## Shows a message on behalf of the running event and waits for the player
func say(text: String) -> void:
	if map == null:
		push_warning("EventInterpreter: there is no field to show '%s' on." % text)
		return
	await map.say(text)

## Offers a list of options and returns the index chosen, or `-1` on cancel.
func choose(
	options: Array,
	prompt: String = "",
	cancel_index: int = MessageBox.CANCELLED,
	default_index: int = 0
) -> int:
	if map == null:
		return -1
	return await map.ask(options, prompt, cancel_index, default_index)

## Renames the [param number]-th option (one-based) of the next Show Choices on this page
func rename_choice(number: int, replacement: String) -> void:
	_choice_renames[number] = replacement

## Hides or reveals the [param number]-th option (one-based) of the next Show Choices on this page
func hide_choice(number: int, hidden: bool = true) -> void:
	_choice_hides[number] = hidden

func _event_label() -> String:
	return _current_event.display_name() if _current_event != null else ""

func _index_labels() -> void:
	_labels.clear()
	for index: int in range(_commands.size()):
		if _commands[index].code == MapEventCommands.LABEL:
			_labels[str(_commands[index].parameters[0])] = index

func _execute(command: MapEventCommand) -> void:
	match command.code:
		0, MapEventCommands.END_BRANCH:
			pass
		MapEventCommands.END_CHOICES:
			if not _choice_group_ends.is_empty():
				_pointer = int(_choice_group_ends.pop_back())
		MapEventCommands.SHOW_TEXT:
			await _flush_text()
			_pending_text = String(command.parameters[0])
		MapEventCommands.CONTINUE_TEXT:
			_pending_text += "\n" + String(command.parameters[0])
		MapEventCommands.CHANGE_TEXT_OPTIONS:
			await _flush_text()
			_change_text_options(command.parameters)
		MapEventCommands.SHOW_CHOICES:
			await _show_choices(command)
		MapEventCommands.CHOICE_BRANCH:
			_handle_choice_branch(command)
		MapEventCommands.CHOICE_CANCEL:
			if _choice_result != -1:
				_skip_branch(command.indent)
		MapEventCommands.WAIT:
			await _flush_text()
			var frames: int = int(command.parameters[0])
			await get_tree().create_timer(float(frames) / 60.0).timeout
		MapEventCommands.COMMENT, MapEventCommands.COMMENT_MORE:
			pass
		MapEventCommands.CONDITIONAL_BRANCH:
			await _flush_text()
			if not await _evaluate_condition(command.parameters):
				_skip_to_else_or_end(command.indent)
		MapEventCommands.ELSE_BRANCH:
			_skip_branch(command.indent)
		MapEventCommands.LOOP:
			pass
		MapEventCommands.REPEAT_ABOVE:
			_jump_to_loop_start(command.indent)
		MapEventCommands.BREAK_LOOP:
			_skip_past_loop(command.indent)
		MapEventCommands.EXIT_EVENT:
			_running = false
		MapEventCommands.ERASE_EVENT:
			if _current_event != null:
				_current_event.erase()
			_running = false
		MapEventCommands.CALL_COMMON_EVENT:
			await _call_common_event(command.parameters)
		MapEventCommands.LABEL:
			pass
		MapEventCommands.JUMP_TO_LABEL:
			var label: String = String(command.parameters[0])
			if _labels.has(label):
				_pointer = int(_labels[label])
				_choice_group_ends.clear()
		MapEventCommands.CONTROL_SWITCHES:
			_control_switches(command.parameters)
		MapEventCommands.CONTROL_VARIABLES:
			_control_variables(command.parameters)
		MapEventCommands.CONTROL_SELF_SWITCH:
			_control_self_switch(command.parameters)
		MapEventCommands.CONTROL_TIMER:
			_control_timer(command.parameters)
		MapEventCommands.CHANGE_MONEY:
			_change_money(command.parameters)
		MapEventCommands.CHANGE_ITEMS:
			_change_items(command.parameters)
		MapEventCommands.CHANGE_PARTY:
			# This is a guard against the RPG Maker built in change party command for actors, which we do not use
			pass
		MapEventCommands.TRANSFER_PLAYER:
			await _transfer_player(command.parameters)
		MapEventCommands.SET_EVENT_LOCATION:
			_set_event_location(command.parameters)
		MapEventCommands.SCROLL_MAP:
			_scroll_map(command.parameters)
		MapEventCommands.CHANGE_MAP_SETTINGS:
			_change_map_settings(command.parameters)
		MapEventCommands.CHANGE_FOG_TONE:
			_change_fog_tone(command.parameters)
		MapEventCommands.CHANGE_FOG_OPACITY:
			_change_fog_opacity(command.parameters)
		MapEventCommands.SHOW_ANIMATION:
			_show_animation(command.parameters)
		MapEventCommands.CHANGE_TRANSPARENCY:
			if map != null and map.player != null:
				map.player.visible = int(command.parameters[0]) == 1
		MapEventCommands.SET_MOVE_ROUTE:
			await _run_move_route(command.parameters)
		MapEventCommands.MOVE_ROUTE_STEP:
			pass
		MapEventCommands.WAIT_FOR_MOVE:
			await _wait_for_movement()
		MapEventCommands.PREPARE_TRANSITION:
			await _flush_text()
			await SceneRouter.fade_out()
		MapEventCommands.EXECUTE_TRANSITION:
			await SceneRouter.fade_in()
		MapEventCommands.CHANGE_SCREEN_TONE:
			_change_screen_tone(command.parameters)
		MapEventCommands.SCREEN_FLASH:
			_screen_flash(command.parameters)
		MapEventCommands.SCREEN_SHAKE:
			_screen_shake(command.parameters)
		MapEventCommands.SHOW_PICTURE:
			_show_picture(command.parameters)
		MapEventCommands.MOVE_PICTURE:
			_move_picture(command.parameters)
		MapEventCommands.ROTATE_PICTURE:
			if command.parameters.size() >= 2:
				FieldPictures.rotate(int(command.parameters[0]), float(command.parameters[1]))
		MapEventCommands.PICTURE_TONE:
			_tone_picture(command.parameters)
		MapEventCommands.ERASE_PICTURE:
			if not command.parameters.is_empty():
				FieldPictures.erase(int(command.parameters[0]))
		MapEventCommands.SET_WEATHER:
			_set_weather(command.parameters)
		MapEventCommands.PLAY_BGM:
			AudioManager.play_bgm(_audio_name(command.parameters[0]))
		MapEventCommands.FADE_OUT_BGM:
			AudioManager.fade_out_bgm(float(command.parameters[0]))
		MapEventCommands.PLAY_BGS:
			AudioManager.play_bgs(_audio_name(command.parameters[0]))
		MapEventCommands.FADE_OUT_BGS:
			AudioManager.stop_bgs()
		MapEventCommands.MEMORIZE_BGM_BGS:
			AudioManager.memorize_bgm_bgs()
		MapEventCommands.RESTORE_BGM_BGS:
			AudioManager.restore_bgm_bgs()
		MapEventCommands.PLAY_ME:
			AudioManager.play_me(_audio_name(command.parameters[0]))
		MapEventCommands.PLAY_SE:
			AudioManager.play_se(_audio_name(command.parameters[0]))
		MapEventCommands.STOP_SE:
			AudioManager.stop_all_se()
		MapEventCommands.RECOVER_ALL:
			GameState.party.heal_all()
		MapEventCommands.RETURN_TO_TITLE:
			await _return_to_title()
		MapEventCommands.SCRIPT:
			await _flush_text()
			await _run_script(command)
		MapEventCommands.SCRIPT_MORE:
			# Continuation lines are swallowed by the Script command above them.
			pass
		MapEventCommands.BUTTON_INPUT, MapEventCommands.INPUT_NUMBER:
			await _flush_text()
		_:
			_report_unsupported(command, "")

## Sends any accumulated Show Text lines to the UI and waits for the player.
func _flush_text() -> void:
	if _pending_text.is_empty():
		return
	var text: String = _pending_text
	_pending_text = ""
	await say(text)

## Runs a Show Choices command. The show text just before it is used as the prompt, if present.
func _show_choices(command: MapEventCommand) -> void:
	var prompt: String = _pending_text
	_pending_text = ""
	var blocks: Array = _collect_choice_blocks(_pointer - 1, command.indent)
	var group_end: int = int(blocks[-1]["end"]) + 1

	var labels: Array = []
	var sources: Array = []
	var number: int = 0
	for block: int in blocks.size():
		var options: Array = blocks[block]["options"]
		for local: int in options.size():
			number += 1
			if bool(_choice_hides.get(number, false)):
				continue
			labels.append(String(_choice_renames.get(number, options[local])))
			sources.append(Vector2i(block, local))
	_choice_renames.clear()
	_choice_hides.clear()

	var cancel: Dictionary = _merged_cancel(blocks, sources)
	var picked: int = await choose(labels, prompt, int(cancel["ui"]))

	var target_block: int
	if picked >= 0 and picked < sources.size():
		target_block = sources[picked].x
		_choice_result = sources[picked].y
	else:
		target_block = int(cancel["block"])
		_choice_result = -1

	_pointer = int(blocks[target_block]["ptr"]) + 1
	_choice_group_ends.push_back(group_end)

## Collects the run of Show Choices starting at [param start] that share [param indent], each as `{ptr, options, cancel, end}`
##  `end` being the index of its end choices
func _collect_choice_blocks(start: int, indent: int) -> Array:
	var blocks: Array = []
	var index: int = start
	while (
		index < _commands.size()
		and _commands[index].code == MapEventCommands.SHOW_CHOICES
		and _commands[index].indent == indent
	):
		var command: MapEventCommand = _commands[index]
		var end: int = _find_choice_block_end(index + 1, indent)
		blocks.append({
			ptr = index,
			options = command.parameters[0] if command.parameters.size() > 0 else [],
			cancel = int(command.parameters[1]) if command.parameters.size() > 1 else 0,
			end = end,
		})
		index = end + 1
	return blocks

## The index of the End Choices that closes the block opened at [param from] - 1.
func _find_choice_block_end(from: int, indent: int) -> int:
	var index: int = from
	while index < _commands.size():
		var command: MapEventCommand = _commands[index]
		if command.indent == indent and command.code == MapEventCommands.END_CHOICES:
			return index
		index += 1
	return _commands.size() - 1

## Works out the cancel behaviour of a merged menu
func _merged_cancel(blocks: Array, sources: Array) -> Dictionary:
	var effective: int = -1
	for block: int in blocks.size():
		if int(blocks[block]["cancel"]) != 0:
			effective = block
	if effective < 0:
		return {ui = MessageBox.CANCEL_DISALLOWED, block = blocks.size() - 1}
	var cancel_type: int = int(blocks[effective]["cancel"])
	if cancel_type != 5:
		var wanted: Vector2i = Vector2i(effective, cancel_type - 1)
		var visible_position: int = sources.find(wanted)
		if visible_position >= 0:
			return {ui = visible_position + 1, block = effective}
	return {ui = MessageBox.CANCELLED, block = effective}

func _handle_choice_branch(command: MapEventCommand) -> void:
	var branch_index: int = int(command.parameters[0])
	if branch_index != _choice_result:
		_skip_branch(command.indent)

## Skips forward past the block that starts at the current indent level.
func _skip_branch(indent: int) -> void:
	while _pointer < _commands.size():
		var command: MapEventCommand = _commands[_pointer]
		if command.indent <= indent:
			var terminator: bool = command.code in [
				MapEventCommands.END_BRANCH, MapEventCommands.END_CHOICES,
				MapEventCommands.CHOICE_BRANCH, MapEventCommands.CHOICE_CANCEL,
				MapEventCommands.ELSE_BRANCH,
			]
			if terminator or command.indent < indent:
				return
		_pointer += 1

## Jumps to the matching Else
## Jumps past the branch if there is no else
func _skip_to_else_or_end(indent: int) -> void:
	while _pointer < _commands.size():
		var command: MapEventCommand = _commands[_pointer]
		if command.indent == indent:
			if command.code == MapEventCommands.ELSE_BRANCH:
				_pointer += 1
				return
			if command.code == MapEventCommands.END_BRANCH:
				_pointer += 1
				return
		if command.indent < indent:
			return
		_pointer += 1

func _jump_to_loop_start(indent: int) -> void:
	for index: int in range(_pointer - 1, -1, -1):
		var command: MapEventCommand = _commands[index]
		if command.code == MapEventCommands.LOOP and command.indent == indent:
			_pointer = index + 1
			return

func _skip_past_loop(indent: int) -> void:
	while _pointer < _commands.size():
		var command: MapEventCommand = _commands[_pointer]
		_pointer += 1
		if command.code == MapEventCommands.REPEAT_ABOVE and command.indent == indent:
			return


# === Commands ===

func _control_switches(parameters: Array) -> void:
	var first: int = int(parameters[0])
	var last: int = int(parameters[1])
	var value: bool = int(parameters[2]) == 0
	for id: int in range(first, last + 1):
		GameState.set_switch(id, value)

func _control_variables(parameters: Array) -> void:
	var first: int = int(parameters[0])
	var last: int = int(parameters[1])
	var operation: int = int(parameters[2])
	var operand_kind: int = int(parameters[3])
	var value: int = 0
	match operand_kind:
		0: value = int(parameters[4])
		1: value = int(GameState.get_variable(int(parameters[4])))
		2: value = RNG.range_int(int(parameters[4]), int(parameters[5]))
		_: value = 0
	for id: int in range(first, last + 1):
		var current: int = int(GameState.get_variable(id))
		match operation:
			0: current = value
			1: current += value
			2: current -= value
			3: current *= value
			4: current = current / value if value != 0 else current
			5: current = current % value if value != 0 else current
		GameState.set_variable(id, current)

func _control_self_switch(parameters: Array) -> void:
	if _current_event == null or map == null:
		return
	var switch: String = String(parameters[0])
	var value: bool = int(parameters[1]) == 0
	GameState.set_self_switch(map.map_id(), _current_event.self_switch_key(), switch, value)
	for event: MapEvent in map.all_events():
		event.refresh_page()

## Change Text Options
## where and how message boxes are drawn
## Both stick until an event changes them again
func _change_text_options(parameters: Array) -> void:
	var position_number: int = int(parameters[0]) if not parameters.is_empty() else 2
	var frame_hidden: bool = parameters.size() > 1 and int(parameters[1]) == 1
	var window_position: MessageBox.WindowPosition = MessageBox.WindowPosition.BOTTOM
	match position_number:
		0: window_position = MessageBox.WindowPosition.TOP
		1: window_position = MessageBox.WindowPosition.MIDDLE
	Field.set_text_options(window_position, not frame_hidden)

## Control Timer: `0` starts it at a number of seconds, `1` stops it.
func _control_timer(parameters: Array) -> void:
	if parameters.is_empty():
		return
	if int(parameters[0]) == 0:
		GameState.start_timer(float(parameters[1]) if parameters.size() > 1 else 0.0)
		return
	GameState.stop_timer()

## Scroll Map: which way, how many cells, and how fast.
func _scroll_map(parameters: Array) -> void:
	if map == null or parameters.size() < 3:
		return
	var direction: int = int(parameters[0])
	var distance: int = int(parameters[1])
	var speed: int = int(parameters[2])
	var offset: Vector2 = Vector2.ZERO
	match direction:
		GridCharacter.Direction.DOWN: offset = Vector2(0.0, float(distance))
		GridCharacter.Direction.LEFT: offset = Vector2(-float(distance), 0.0)
		GridCharacter.Direction.RIGHT: offset = Vector2(float(distance), 0.0)
		GridCharacter.Direction.UP: offset = Vector2(0.0, -float(distance))
	map.scroll_map(offset, float(distance) * GridCharacter.speed_to_seconds(speed))

## Change Map Settings
func _change_map_settings(parameters: Array) -> void:
	if parameters.is_empty():
		return
	var backdrop: MapBackdrop = _backdrop()
	match int(parameters[0]):
		0:
			if backdrop != null:
				backdrop.set_panorama(
					String(parameters[1]) if parameters.size() > 1 else "",
					int(parameters[2]) if parameters.size() > 2 else 0
				)
		1:
			if backdrop != null:
				backdrop.set_fog(
					String(parameters[1]) if parameters.size() > 1 else "",
					int(parameters[2]) if parameters.size() > 2 else 0,
					int(parameters[3]) if parameters.size() > 3 else 64,
					int(parameters[4]) if parameters.size() > 4 else 0,
					float(parameters[5]) if parameters.size() > 5 else 100.0,
					Vector2(
						float(parameters[6]) if parameters.size() > 6 else 0.0,
						float(parameters[7]) if parameters.size() > 7 else 0.0
					)
				)
		2:
			GameState.battleback_override = String(parameters[1]) if parameters.size() > 1 else ""

func _change_fog_tone(parameters: Array) -> void:
	var backdrop: MapBackdrop = _backdrop()
	if backdrop == null or parameters.is_empty() or typeof(parameters[0]) != TYPE_COLOR:
		return
	var tone: Vector4i = ScreenEffects.unpack_tone(parameters[0])
	var tint: Color = Color(
		clampf(1.0 + float(tone.x) / ScreenEffects.TONE_RANGE, 0.0, 2.0),
		clampf(1.0 + float(tone.y) / ScreenEffects.TONE_RANGE, 0.0, 2.0),
		clampf(1.0 + float(tone.z) / ScreenEffects.TONE_RANGE, 0.0, 2.0)
	)
	backdrop.set_fog_tone(tint, int(parameters[1]) if parameters.size() > 1 else 0)

func _change_fog_opacity(parameters: Array) -> void:
	var backdrop: MapBackdrop = _backdrop()
	if backdrop == null or parameters.is_empty():
		return
	backdrop.set_fog_opacity(
		int(parameters[0]), int(parameters[1]) if parameters.size() > 1 else 0
	)

func _backdrop() -> MapBackdrop:
	var overworld: Overworld = Overworld.current
	return overworld.map_backdrop() if overworld != null else null

func _show_animation(parameters: Array) -> void:
	if map == null or parameters.size() < 2:
		return
	var character: GridCharacter = _addressed_character(int(parameters[0]))
	if character == null:
		return
	OverworldEffects.play_animation_number(map, int(parameters[1]), character)

## Show Picture: the number to draw it as, the graphic, where its origin sits,
## whether the position is a pair of numbers or a pair of variables, and then the
## position, zoom, opacity and blend mode
func _show_picture(parameters: Array) -> void:
	if parameters.size() < 10:
		return
	FieldPictures.show(
		int(parameters[0]),
		String(parameters[1]),
		int(parameters[2]),
		_picture_position(parameters),
		Vector2(float(parameters[6]), float(parameters[7])),
		int(parameters[8]),
		int(parameters[9])
	)

## Move Picture, the parameters are Show Picture's with the graphic's name replaced by how many frames the move is
func _move_picture(parameters: Array) -> void:
	if parameters.size() < 10:
		return
	FieldPictures.move(
		int(parameters[0]),
		int(parameters[1]),
		int(parameters[2]),
		_picture_position(parameters),
		Vector2(float(parameters[6]), float(parameters[7])),
		int(parameters[8]),
		int(parameters[9])
	)

func _tone_picture(parameters: Array) -> void:
	if parameters.size() < 2 or typeof(parameters[1]) != TYPE_COLOR:
		return
	var tone: Vector4i = ScreenEffects.unpack_tone(parameters[1])
	var tint: Color = Color(
		clampf(1.0 + float(tone.x) / ScreenEffects.TONE_RANGE, 0.0, 2.0),
		clampf(1.0 + float(tone.y) / ScreenEffects.TONE_RANGE, 0.0, 2.0),
		clampf(1.0 + float(tone.z) / ScreenEffects.TONE_RANGE, 0.0, 2.0)
	)
	FieldPictures.tone(
		int(parameters[0]), tint, int(parameters[2]) if parameters.size() > 2 else 0
	)

## Where a picture command wants its picture
func _picture_position(parameters: Array) -> Vector2:
	if int(parameters[3]) == 0:
		return Vector2(float(parameters[4]), float(parameters[5]))
	return Vector2(
		float(GameState.get_variable(int(parameters[4]))),
		float(GameState.get_variable(int(parameters[5])))
	)

func _return_to_title() -> void:
	_running = false
	FieldPictures.erase_all()
	await SceneRouter.return_to_title()

func _change_money(parameters: Array) -> void:
	if GameState.player == null:
		return
	var amount: int = int(parameters[1])
	if int(parameters[0]) == 0:
		GameState.player.add_money(amount)
	else:
		GameState.player.spend_money(amount)

func _change_items(parameters: Array) -> void:
	var item_id: StringName = StringName(str(parameters[0]))
	var operation: int = int(parameters[1])
	var amount: int = int(parameters[3]) if parameters.size() > 3 else 1
	if operation == 0:
		GameState.bag.add_item(item_id, amount)
	else:
		GameState.bag.remove_item(item_id, amount)

## Change Screen Tone
func _change_screen_tone(parameters: Array) -> void:
	if parameters.is_empty() or typeof(parameters[0]) != TYPE_COLOR:
		return
	var tone: Vector4i = ScreenEffects.unpack_tone(parameters[0])
	var frames: int = int(parameters[1]) if parameters.size() > 1 else 0
	FieldEffects.begin_tone_change(tone.x, tone.y, tone.z, tone.w, frames)

func _screen_flash(parameters: Array) -> void:
	if parameters.is_empty() or typeof(parameters[0]) != TYPE_COLOR:
		return
	var frames: int = int(parameters[1]) if parameters.size() > 1 else 0
	FieldEffects.flash(ScreenEffects.unpack_flash(parameters[0]), frames)

## Screen Shake: how far, how fast, and for how many frames.
func _screen_shake(parameters: Array) -> void:
	if parameters.size() < 3:
		return
	FieldEffects.shake(int(parameters[0]), int(parameters[1]), int(parameters[2]))

## Set Weather: the weather by the number the map data stores it as, how heavy, and how long it takes
func _set_weather(parameters: Array) -> void:
	if parameters.is_empty():
		return
	var number: int = int(parameters[0])
	var power: int = int(parameters[1]) if parameters.size() > 1 else 5
	var frames: int = int(parameters[2]) if parameters.size() > 2 else 0
	var seconds: float = float(frames) / ScreenEffects.FRAMES_PER_SECOND
	if number <= 0 or power <= 0:
		FieldEffects.clear_weather(seconds)
		return
	FieldEffects.set_weather_number(number, power, seconds)

func _transfer_player(parameters: Array) -> void:
	await _flush_text()
	if map == null:
		return
	var target_map: int = int(parameters[1])
	var target_cell: Vector2i = Vector2i(int(parameters[2]), int(parameters[3]))
	var direction: int = int(parameters[4]) if parameters.size() > 4 else 0
	if target_map == map.map_id():
		map.move_player_to(target_cell, direction)
		return
	await map.warp_to_map_id(target_map, target_cell, direction)

func _set_event_location(parameters: Array) -> void:
	if map == null:
		return
	var event_id: int = int(parameters[0])
	var node: GridCharacter = null
	if event_id == -1:
		node = map.player
	else:
		node = map.event_by_id(event_id)
	if node == null:
		return
	node.tile_position = Vector2i(int(parameters[2]), int(parameters[3]))
	node.position = MapGrid.cell_to_pixel(node.tile_position)
	var direction: int = int(parameters[4]) if parameters.size() > 4 else 0
	if direction > 0:
		node.facing = direction as GridCharacter.Direction

func _run_move_route(parameters: Array) -> void:
	if map == null:
		return
	var character: GridCharacter = _addressed_character(int(parameters[0]))
	if character == null:
		return
	var route: Variant = parameters[1] if parameters.size() > 1 else null
	if route == null or not route.has("list"):
		return
	await MoveRouteRunner.new(character, map, self).run(route["list"])

## The character a command addresses by number.
## `-1` is the player, and `0` is the event running this command
func _addressed_character(target_id: int) -> GridCharacter:
	if map == null:
		return null
	if target_id < 0:
		return map.player
	if target_id == 0:
		return _current_event
	return map.event_by_id(target_id)

func _wait_for_movement() -> void:
	if map == null:
		return
	while true:
		var still_moving: bool = map.player != null and map.player.is_moving
		for event: MapEvent in map.all_events():
			still_moving = still_moving or event.is_moving
		if not still_moving:
			return
		await get_tree().process_frame

func _run_script(command: MapEventCommand) -> void:
	var lines: Array[String] = [_script_line(command)]
	while _pointer < _commands.size() and _commands[_pointer].code == MapEventCommands.SCRIPT_MORE:
		lines.append(_script_line(_commands[_pointer]))
		_pointer += 1
	var result: Variant = await script_bridge().run("\n".join(lines))
	if result is EventScriptBridge.Unsupported:
		report_unsupported_script(String(result.expression))

static func _script_line(command: MapEventCommand) -> String:
	return String(command.parameters[0]) if not command.parameters.is_empty() else ""

func script_bridge() -> EventScriptBridge:
	if _script_bridge == null:
		_script_bridge = EventScriptBridge.new(self)
	return _script_bridge

func reported_unsupported() -> Dictionary:
	return _reported_unsupported

func report_unsupported_script(expression: String) -> void:
	if expression.is_empty() or _reported_unsupported.has(expression):
		return
	_reported_unsupported[expression] = true
	var where: String = ""
	if _current_event != null:
		where = " (event '%s')" % _current_event.display_name()
	push_warning("EventInterpreter: script '%s' has no counterpart in this engine%s." % [expression, where])

## Evaluates a Conditional Branch. 
## Returns `true` when the branch is taken.
func _evaluate_condition(parameters: Array) -> bool:
	if parameters.is_empty():
		return true
	match int(parameters[0]):
		0:
			return GameState.get_switch(int(parameters[1])) == (int(parameters[2]) == 0)
		1:
			var left: int = int(GameState.get_variable(int(parameters[1])))
			var right: int = int(parameters[3]) if int(parameters[2]) == 0 else int(GameState.get_variable(int(parameters[3])))
			match int(parameters[4]):
				0: return left == right
				1: return left >= right
				2: return left <= right
				3: return left > right
				4: return left < right
				5: return left != right
		2:
			if _current_event == null or map == null:
				return false
			var switch: String = String(parameters[1])
			var expected: bool = int(parameters[2]) == 0
			return GameState.get_self_switch(map.map_id(), _current_event.self_switch_key(), switch) == expected
		4:
			return GameState.bag.has_item(StringName(str(parameters[1])))
		7:
			return GameState.player != null and GameState.player.money >= int(parameters[1])
		12:
			# A Ruby snippet, run through the same evaluator as a Script command.
			if parameters.size() < 2:
				return true
			return await script_bridge().evaluate_condition(String(parameters[1]))
	return true

func _audio_name(parameter: Variant) -> String:
	if typeof(parameter) == TYPE_DICTIONARY:
		return String(parameter.get("name", ""))
	return String(parameter)

func _report_unsupported(command: MapEventCommand, note: String) -> void:
	var key: String = str(command.code)
	if _reported_unsupported.has(key):
		return
	_reported_unsupported[key] = true
	var where: String = ""
	if _current_event != null:
		where = " (event '%s')" % _current_event.display_name()
	push_warning("EventInterpreter: %s (%d) is not implemented%s. %s" % [
		MapEventCommands.name_for(command.code), command.code, where, note,
	])
