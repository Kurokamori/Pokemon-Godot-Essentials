class_name MessageBox
extends Control
## Displays typed dialogue, control codes, pages, and choices.
## [MessageCodes] converts source text into BBCode and directives.
## [method _process] reveals text and runs directives in order.
## Long messages pause at the last visible line, then scroll by one line.
## [signal message_finished] fires once after the window closes.
## `\w[name]` and `\sign[name]` can change the window skin mid-message.

signal message_finished()
signal choice_made(index: int)

enum State {
	## Nothing is being shown.
	HIDDEN,
	## Characters are being typed out.
	REVEALING,
	## Stopped mid-message, waiting for a button press.
	PAUSED,
	## Sliding the text up by a line after the player asked for the next one.
	SCROLLING,
	## Fully revealed, waiting for the player to dismiss it.
	FINISHED,
}

enum WindowPosition { TOP, MIDDLE, BOTTOM }

const CHOICE_ITEM_SCENE: String = "res://scenes/ui/choice_item.tscn"

## Essentials uses this value when cancelling is not allowed.
const CANCEL_DISALLOWED: int = ParsedMessage.CANCEL_DISALLOWED

## Returned when the caller wants cancellation reported separately.
const CANCELLED: int = -1

## Briefly ignores input after opening a message.
## Prevents one press from dismissing two messages.
const INPUT_GUARD_SECONDS: float = 0.15

## Gap between the window and the edge of the screen.
const PANEL_MARGIN: float = 8.0
## Height used when the font cannot be measured.
const FALLBACK_LINE_HEIGHT: float = 20.0

## Frames to wait for line layout before disabling paging.
const PAGE_MEASURE_ATTEMPTS: int = 10

## Where the player's text speed is kept, in characters per second.
const OPTIONS_PATH: String = "user://options.cfg"
const OPTIONS_SECTION: String = "display"
const OPTIONS_TEXT_SPEED: String = "text_speed"

## Default reveal speed in characters per second.
@export var characters_per_second: float = 45.0

## Lines the window is tall enough for when the message does not ask for more.
@export var lines_per_page: int = 2

## Seconds the window takes to slide in or out for `\op`, `\cl` and `\sign`.
@export var slide_duration: float = 0.4

## Seconds the text takes to scroll up by one line.
@export var line_scroll_duration: float = 0.1

## Frames per second of the arrow shown while the window waits for a button.
@export var arrow_frames_per_second: float = 5.0

## Maximum visible choices before scrolling.
## The layout may reduce this value to fit the screen.
@export var max_visible_choices: int = 6

@onready var _panel: PanelContainer = %MessagePanel
@onready var _label: RichTextLabel = %MessageLabel
@onready var _continue_arrow: TextureRect = %ContinueArrow
@onready var _choice_panel: PanelContainer = %ChoicePanel
@onready var _choice_viewport: Control = %ChoiceViewport
@onready var _choice_list: VBoxContainer = %ChoiceList
@onready var _choice_up_arrow: TextureRect = %ChoiceUpArrow
@onready var _choice_down_arrow: TextureRect = %ChoiceDownArrow
@onready var _face_panel: PanelContainer = %FacePanel
@onready var _face_image: TextureRect = %FaceImage
@onready var _info_windows: VBoxContainer = %InfoWindows
@onready var _gold_panel: PanelContainer = %GoldPanel
@onready var _gold_label: Label = %GoldLabel
@onready var _coins_panel: PanelContainer = %CoinsPanel
@onready var _coins_label: Label = %CoinsLabel
@onready var _battle_points_panel: PanelContainer = %BattlePointsPanel
@onready var _battle_points_label: Label = %BattlePointsLabel

var _choice_scene: PackedScene = null
var _message: ParsedMessage = null
var _state: State = State.HIDDEN
var _position: WindowPosition = WindowPosition.BOTTOM

## Starting position until a message control code changes it.
## Persists until text options are changed.
var _default_position: WindowPosition = WindowPosition.BOTTOM

## Whether Change Text Options hides the frame.
var _frame_hidden: bool = false
var _line_count: int = 2

## Characters currently on screen.
var _revealed: int = 0
var _total_characters: int = 0

## Index of the next directive to fire.
var _next_directive: int = 0
var _reveal_accumulator: float = 0.0

## `0` reveals the whole message at once, as `\ts[]` asks for.
var _seconds_per_character: float = 0.0
var _wait_seconds: float = 0.0

## Pixels the window is pushed off screen by while it slides.
var _slide_offset: float = 0.0
var _slide_tween: Tween = null

## First line of the message currently at the top of the window.
var _top_line: int = 0

## Characters may be revealed up to here before the window has to scroll.
var _page_limit: int = 0

## Whether the page still needs measuring.
var _page_unmeasured: bool = true

## Frames spent waiting for line layout.
## A failed layout eventually shows the whole message.
var _page_measure_attempts: int = 0

## Measured line height, or zero before layout.
var _text_height: float = 0.0

## Whether the current pause ends with a scroll.
var _paused_to_scroll: bool = false
var _scroll_tween: Tween = null

var _choice_buttons: Array[Button] = []

## Essentials' cancel numbering for the choice on screen.
var _choice_cancel: int = CANCEL_DISALLOWED
var _choice_index: int = 0

## First option visible in the choice window.
var _choice_top: int = 0
var _choice_rows_visible: int = 0
var _choice_row_height: float = 0.0

## Whether a choice is opening or active.
## Blocks message input before the options appear.
var _choice_active: bool = false

## Whether the choice window is ready for input.
## Prevents emitting an answer before the caller is listening.
var _choice_ready: bool = false

## Choice result returned by [method show_message_with_choices].
var _last_choice: int = CANCELLED

## Windowskins already reported as missing, so each only warns once.
var _reported_windowskins: Dictionary = {}

## Seconds left before the window accepts a button press again.
var _input_guard: float = 0.0

## Frames of the "press a button" arrow, from the windowskin or drawn.
var _arrow_textures: Array[Texture2D] = []
var _arrow_frame: int = 0
var _arrow_time: float = 0.0


func _ready() -> void:
	_choice_scene = load(CHOICE_ITEM_SCENE)
	if _choice_scene == null:
		push_error("MessageBox: %s could not be loaded." % CHOICE_ITEM_SCENE)
	_panel.visible = false
	_choice_panel.visible = false
	_continue_arrow.visible = false
	_hide_extra_windows()
	_line_count = lines_per_page
	_apply_windowskin("")
	_refresh_scroll_arrows()
	UITheme.theme_changed.connect(_on_theme_changed)
	set_process_input(true)
	set_process(false)


# === Messages ===

## Shows [param text] until the player dismisses it.
##
## Translates the source before [MessageCodes] parses it.
## Translated text may move or remove control codes.
## Build messages with values through [method Loc.line].
func show_message(text: String) -> void:
	if _state != State.HIDDEN:
		_finish()
	_begin(MessageCodes.parse(Loc.line(text)))
	await message_finished


## Shows [param text], then opens its choices without dismissing the message.
func show_message_with_choices(
	text: String,
	options: Array,
	cancel_index: int = CANCEL_DISALLOWED,
	default_index: int = 0) -> int:
	if _state != State.HIDDEN:
		_finish()
	var message: ParsedMessage = MessageCodes.parse(Loc.line(text))
	message.has_choices = true
	message.choices = PackedStringArray()
	for option: Variant in options:
		message.choices.append(Loc.line(str(option)))
	message.choice_cancel = cancel_index
	message.choice_default = default_index
	message.choice_variable = 0
	_last_choice = CANCELLED
	_begin(message)
	# Return the answer after the message window closes.
	await message_finished
	return _last_choice

## Shows [param options] and returns the selected index.
##
## [param cancel_index] uses Essentials' numbering.
## [constant CANCEL_DISALLOWED] disables cancellation.
## Positive values select a one-based option.
## Negative values return unchanged.
## [param default_index] is selected initially.
func show_choices(options: Array, cancel_index: int = CANCEL_DISALLOWED, default_index: int = 0) -> int:
	if options.is_empty():
		push_warning("MessageBox: asked for a choice with no options.")
		return CANCELLED
	await _open_choices(Loc.lines(options), cancel_index, default_index)
	var chosen: int = await choice_made
	_close_choices()
	return chosen

## Sets the default message position and frame visibility.
##
## Both settings persist until changed.
## A message's `\wu`, `\wm`, or `\wd` code overrides the position.
func set_text_options(window_position: WindowPosition, frame_visible: bool) -> void:
	_default_position = window_position
	_frame_hidden = not frame_visible
	if _state == State.HIDDEN and not _choice_active:
		return
	# Apply changes immediately to an open window.
	_position = window_position
	_apply_windowskin(_message.windowskin if _message != null else "")
	_reposition()

## Restores the default position and visible frame.
func reset_text_options() -> void:
	set_text_options(WindowPosition.BOTTOM, true)

## Where a message opens when nothing has said otherwise.
func default_position() -> WindowPosition:
	return _default_position

## Returns `true` while messages are being drawn without a frame.
func is_frame_hidden() -> bool:
	return _frame_hidden

## Displays [param text] without typing or waiting for input.
## Close it with [method hide_message] or replace it with another message.
func display_text(text: String) -> void:
	if _state != State.HIDDEN:
		_finish()
	var message: ParsedMessage = MessageCodes.parse(Loc.line(text))
	_begin(message)
	_reveal(_total_characters)
	_state = State.HIDDEN
	set_process(false)
	_continue_arrow.visible = false

## Closes the window immediately and releases any awaiting message.
func hide_message() -> void:
	if _choice_active:
		_close_choices()
	if _state != State.HIDDEN:
		_finish()
		return
	_panel.visible = false
	_continue_arrow.visible = false
	_hide_extra_windows()

func is_showing() -> bool:
	return _state != State.HIDDEN or _choice_active

func _begin(message: ParsedMessage) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_message = message
	_line_count = message.line_count if message.line_count > 0 else lines_per_page
	_position = _default_position
	_apply_windowskin(message.windowskin)

	_label.text = message.bbcode
	_total_characters = message.character_count()
	_revealed = 0
	_label.visible_characters = 0
	_next_directive = 0
	_reveal_accumulator = 0.0
	_wait_seconds = 0.0
	_seconds_per_character = 1.0 / maxf(_preferred_characters_per_second(), 1.0)

	_top_line = 0
	_text_height = 0.0
	_set_text_scroll(0.0)
	_page_limit = _total_characters
	_page_unmeasured = true
	_page_measure_attempts = 0
	_paused_to_scroll = false

	_continue_arrow.visible = false
	_input_guard = INPUT_GUARD_SECONDS
	_slide_offset = 0.0
	_panel.visible = true
	_reposition()
	if message.opens_with_animation:
		_start_slide(true)
		_wait_seconds = slide_duration

	_state = State.REVEALING
	set_process(true)

func _process(delta: float) -> void:
	_animate_arrow(delta)
	_input_guard = maxf(_input_guard - delta, 0.0)
	if _state != State.REVEALING:
		return
	if _wait_seconds > 0.0:
		_wait_seconds = maxf(_wait_seconds - delta, 0.0)
		return
	_measure_page()
	if _page_unmeasured:
		return
	if not _fire_due_directives():
		return
	if _revealed >= _total_characters:
		_on_reveal_complete()
		return
	if _revealed >= _page_limit:
		_pause_for_scroll()
		return
	if _seconds_per_character <= 0.0:
		_reveal(_page_limit)
		return
	_reveal_accumulator += delta
	var steps: int = int(_reveal_accumulator / _seconds_per_character)
	if steps <= 0:
		return
	_reveal_accumulator -= float(steps) * _seconds_per_character
	_reveal(mini(_revealed + steps, _page_limit))

## Fires due directives
## Returns `false` when one pauses the message
func _fire_due_directives() -> bool:
	while _next_directive < _message.directives.size():
		var directive: ParsedMessage.Directive = _message.directives[_next_directive]
		if directive.position > _revealed:
			return true
		_next_directive += 1
		if not _apply_directive(directive):
			return false
	return true


## Runs one directive. 
## Returns `false` when the message must stop here.
func _apply_directive(directive: ParsedMessage.Directive) -> bool:
	match directive.code:
		ParsedMessage.WAIT:
			_wait_seconds = directive.seconds
			return false
		ParsedMessage.WAIT_NO_PAUSE:
			_wait_seconds = directive.seconds
			return directive.seconds <= 0.0
		ParsedMessage.PAUSE:
			_state = State.PAUSED
			_paused_to_scroll = false
			_continue_arrow.visible = true
			return false
		ParsedMessage.TEXT_SPEED:
			_set_text_speed(directive.parameter)
		ParsedMessage.SOUND_EFFECT:
			AudioManager.play_se(directive.parameter)
		ParsedMessage.MUSIC_EFFECT:
			AudioManager.play_me(directive.parameter)
		ParsedMessage.FACE:
			_show_face(directive.parameter)
		ParsedMessage.FACE_CELL:
			_show_face_cell(directive.parameter)
		ParsedMessage.GOLD_WINDOW:
			_show_gold_window()
		ParsedMessage.COINS_WINDOW:
			_show_coins_window()
		ParsedMessage.BATTLE_POINTS_WINDOW:
			_show_battle_points_window()
		ParsedMessage.WINDOW_TOP:
			_position = WindowPosition.TOP
			_reposition()
		ParsedMessage.WINDOW_MIDDLE:
			_position = WindowPosition.MIDDLE
			_reposition()
		ParsedMessage.WINDOW_BOTTOM:
			_position = WindowPosition.BOTTOM
			_reposition()
	return true

func _set_text_speed(parameter: String) -> void:
	if parameter.is_empty():
		_seconds_per_character = 0.0
	else:
		_seconds_per_character = float(parameter.to_int()) / MessageCodes.TEXT_SPEED_DIVISOR
	_reveal_accumulator = 0.0

## Returns the player's current text speed
## Falls back to [member characters_per_second].
func _preferred_characters_per_second() -> float:
	var config: ConfigFile = ConfigFile.new()
	if config.load(OPTIONS_PATH) != OK:
		return characters_per_second
	return maxf(float(config.get_value(OPTIONS_SECTION, OPTIONS_TEXT_SPEED, characters_per_second)), 1.0)

func _reveal(count: int) -> void:
	_revealed = clampi(count, 0, _total_characters)
	_label.visible_characters = _revealed

## Handles the state after all characters are visible.
func _on_reveal_complete() -> void:
	if _message.has_choices:
		_state = State.FINISHED
		_continue_arrow.visible = false
		set_process(false)
		_run_inline_choices()
		return
	if not _message.waits_for_input:
		_finish()
		return
	_state = State.FINISHED
	_continue_arrow.visible = true

## Handles a message that ends in a choice. `\ch[...]` also writes the result to a game variable;
## [method show_message_with_choices] asks for variable zero, which is not one, and reads the answer off [signal choice_made].
func _run_inline_choices() -> void:
	var options: Array = Array(_message.choices)
	var cancel: int = _message.choice_cancel
	var variable: int = _message.choice_variable
	var chosen: int = await show_choices(options, cancel, _message.choice_default)
	if variable > 0:
		GameState.set_variable(variable, maxi(chosen + 1, 0))
	_last_choice = chosen
	_finish()


## Closes the window and releases whoever is awaiting the message.
func _finish() -> void:
	if _state == State.HIDDEN:
		return
	var animate: bool = _message != null and _message.closes_with_animation
	var close_sound: String = _message.close_sound if _message != null else ""
	_state = State.HIDDEN
	set_process(false)
	_continue_arrow.visible = false
	_hide_extra_windows()
	_message = null

	if animate:
		if not close_sound.is_empty():
			AudioManager.play_se(close_sound)
		_start_slide(false)
		_slide_tween.finished.connect(_on_close_slide_finished, CONNECT_ONE_SHOT)
	else:
		_panel.visible = false
	message_finished.emit()

func _on_close_slide_finished() -> void:
	if _state == State.HIDDEN:
		_panel.visible = false

# === Paging ===

## Finds how far text can reveal before scrolling.
## Retries until the label has been laid out.
func _measure_page() -> void:
	if not _page_unmeasured:
		return
	if _total_characters <= 0:
		_page_unmeasured = false
		_page_limit = 0
		return
	_page_measure_attempts += 1
	var lines: int = _label.get_line_count() if _label.size.x > 0.0 else 0
	if lines <= 0:
		if _page_measure_attempts < PAGE_MEASURE_ATTEMPTS:
			return
		_page_unmeasured = false
		_page_limit = _total_characters
		return
	_page_unmeasured = false
	_measure_text_height(lines)
	var below: int = _top_line + _line_count
	if below >= lines:
		_page_limit = _total_characters
		return
	_page_limit = _first_character_on_line(below)

## Finds the first character on [param line] with a binary search.
func _first_character_on_line(line: int) -> int:
	var low: int = 0
	var high: int = _total_characters
	while low < high:
		var middle: int = (low + high) / 2
		if _label.get_character_line(middle) >= line:
			high = middle
		else:
			low = middle + 1
	return low

func _pause_for_scroll() -> void:
	_state = State.PAUSED
	_paused_to_scroll = true
	_continue_arrow.visible = true

## Scrolls the text up by one line and resumes typing.
func _scroll_one_line() -> void:
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_top_line += 1
	_state = State.SCROLLING
	_continue_arrow.visible = false
	_paused_to_scroll = false
	var target: float = -_label.get_line_offset(_top_line)
	_scroll_tween = create_tween()
	_scroll_tween.tween_method(_set_text_scroll, float(_label.offset_top), target, line_scroll_duration)
	_scroll_tween.finished.connect(_on_scroll_finished, CONNECT_ONE_SHOT)

func _on_scroll_finished() -> void:
	if _state != State.SCROLLING:
		return
	_page_unmeasured = true
	_page_measure_attempts = 0
	_state = State.REVEALING

## Shifts the label inside the clipped message body.
func _set_text_scroll(value: float) -> void:
	_label.offset_top = value
	_label.offset_bottom = value

# === Input ===

func _input(event: InputEvent) -> void:
	if _choice_active:
		_choice_input(event)
		return
	if _state == State.HIDDEN or _state == State.SCROLLING:
		return
	if not event.is_action_pressed("ui_accept") and not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _input_guard > 0.0:
		return
	match _state:
		State.REVEALING:
			_skip_reveal()
		State.PAUSED:
			if _paused_to_scroll:
				_scroll_one_line()
			else:
				_state = State.REVEALING
				_continue_arrow.visible = false
		State.FINISHED:
			_finish()

## Jumps to the end of what is on screen, or to the next explicit pause in it.
func _skip_reveal() -> void:
	if _page_unmeasured:
		return
	_wait_seconds = 0.0
	_reveal_accumulator = 0.0
	_reveal(_next_stop_position())

func _next_stop_position() -> int:
	var stop: int = _page_limit
	for index: int in range(_next_directive, _message.directives.size()):
		var directive: ParsedMessage.Directive = _message.directives[index]
		if directive.code == ParsedMessage.PAUSE and directive.position > _revealed:
			stop = mini(stop, directive.position)
			break
	return stop

# === Choices ===

## Builds the choice window, sizes it to its options and puts it on screen.
func _open_choices(options: Array, cancel_index: int, default_index: int) -> void:
	_clear_choices()
	_choice_cancel = cancel_index
	_choice_active = true
	_choice_ready = false
	for index: int in range(options.size()):
		var button: Button = _make_choice_button(str(options[index]), index)
		_choice_list.add_child(button)
		_choice_buttons.append(button)
	# Show the panel transparently for layout.
	_choice_panel.modulate.a = 0.0
	_choice_panel.visible = true
	_choice_top = 0
	_choice_index = clampi(default_index, 0, _choice_buttons.size() - 1)
	await get_tree().process_frame
	_layout_choices()
	_select_choice(_choice_index, false)
	_choice_panel.modulate.a = 1.0
	_choice_ready = true

func _close_choices() -> void:
	_choice_active = false
	_choice_ready = false
	_choice_panel.visible = false
	_clear_choices()

func _make_choice_button(text: String, index: int) -> Button:
	var button: Button = null
	if _choice_scene != null:
		button = _choice_scene.instantiate() as Button
	if button == null:
		button = Button.new()
		button.focus_mode = Control.FOCUS_ALL
	var parsed: ParsedMessage = MessageCodes.parse(text)
	var item: ChoiceItem = button as ChoiceItem
	if item != null:
		item.set_markup(parsed.bbcode)
	else:
		button.text = parsed.plain
	button.pressed.connect(_confirm_choice.bind(index))
	button.focus_entered.connect(_on_choice_focused.bind(index))
	return button

## Sizes rows, then the choice window, and places it above the message.
func _layout_choices() -> void:
	if _choice_buttons.is_empty():
		return
	var widest: float = 0.0
	var tallest: float = 0.0
	for button: Button in _choice_buttons:
		var item: ChoiceItem = button as ChoiceItem
		if item == null:
			continue
		item.custom_minimum_size = item.content_size()
		widest = maxf(widest, item.custom_minimum_size.x)
		tallest = maxf(tallest, item.custom_minimum_size.y)
	if tallest <= 0.0:
		tallest = FALLBACK_LINE_HEIGHT
	var separation: float = float(_choice_list.get_theme_constant(&"separation"))
	_choice_row_height = tallest + separation
	var frame: Vector2 = _panel_padding(_choice_panel)
	var arrows: float = _choice_up_arrow.custom_minimum_size.y + _choice_down_arrow.custom_minimum_size.y
	var room: float = size.y - _panel_height() - (PANEL_MARGIN * 3.0) - frame.y - arrows
	var fits: int = int(floorf(maxf(room, _choice_row_height) / _choice_row_height))
	_choice_rows_visible = clampi(mini(max_visible_choices, fits), 1, _choice_buttons.size())

	_choice_viewport.custom_minimum_size = Vector2(
		widest, (_choice_row_height * float(_choice_rows_visible)) - separation)
	_refresh_scroll_arrows()
	_position_choice_panel(_choice_panel.get_combined_minimum_size())

## Puts the choice window above the message window and against its right edge,
## dropping it below when there is no room above.
func _position_choice_panel(window: Vector2) -> void:
	var anchor: Rect2 = _message_rect()
	var left: float = anchor.position.x + anchor.size.x - window.x
	var top: float = anchor.position.y - window.y - PANEL_MARGIN
	if top < PANEL_MARGIN:
		var below: float = anchor.position.y + anchor.size.y + PANEL_MARGIN
		top = below if below + window.y <= size.y - PANEL_MARGIN else PANEL_MARGIN
	_place(_choice_panel, Rect2(Vector2(maxf(left, PANEL_MARGIN), top), window))

func _choice_input(event: InputEvent) -> void:
	if not _choice_ready:
		return
	if event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_move_choice(-1)
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_move_choice(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_confirm_choice(_choice_index)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel_choice()

## Moves the selection, wrapping at either end.
func _move_choice(step: int) -> void:
	if _choice_buttons.size() < 2:
		return
	var count: int = _choice_buttons.size()
	_select_choice(posmod(_choice_index + step, count), true)

func _select_choice(index: int, audible: bool) -> void:
	if _choice_buttons.is_empty():
		return
	_choice_index = clampi(index, 0, _choice_buttons.size() - 1)
	if audible:
		AudioManager.play_se("GUI sel cursor")
	_scroll_choices_into_view()
	_choice_buttons[_choice_index].grab_focus()

## Keeps the selected option within the visible rows.
func _scroll_choices_into_view() -> void:
	if _choice_rows_visible <= 0:
		return
	var top: int = _choice_top
	if _choice_index < top:
		top = _choice_index
	elif _choice_index >= top + _choice_rows_visible:
		top = _choice_index - _choice_rows_visible + 1
	_choice_top = clampi(top, 0, maxi(_choice_buttons.size() - _choice_rows_visible, 0))
	var offset: float = -float(_choice_top) * _choice_row_height
	_choice_list.offset_top = offset
	_choice_list.offset_bottom = offset
	_refresh_scroll_arrows()

func _on_choice_focused(index: int) -> void:
	_choice_index = index

func _confirm_choice(index: int) -> void:
	if not _choice_active or not _choice_ready:
		return
	AudioManager.play_se("GUI sel decision")
	_choice_active = false
	choice_made.emit(index)

## Applies cancel numbering and reports the resulting choice.
func _cancel_choice() -> void:
	if not _choice_ready or _choice_cancel == CANCEL_DISALLOWED:
		return
	AudioManager.play_se("GUI menu close")
	_choice_active = false
	choice_made.emit(_choice_cancel - 1 if _choice_cancel > 0 else _choice_cancel)

func _clear_choices() -> void:
	for button: Button in _choice_buttons:
		button.queue_free()
	_choice_buttons.clear()
	_choice_index = 0
	_choice_top = 0
	_choice_list.offset_top = 0.0
	_choice_list.offset_bottom = 0.0

## Fades scroll arrows without changing the window size.
func _refresh_scroll_arrows() -> void:
	var count: int = _choice_buttons.size()
	var scrollable: bool = _choice_rows_visible > 0 and count > _choice_rows_visible
	_choice_up_arrow.modulate.a = 1.0 if scrollable and _choice_top > 0 else 0.0
	_choice_down_arrow.modulate.a = (
		1.0 if scrollable and _choice_top + _choice_rows_visible < count else 0.0
	)
	var colour: Color = _choice_panel.get_theme_color(&"font_color", UIThemeBuilder.WINDOW_LABEL)
	if _choice_up_arrow.texture == null:
		_choice_up_arrow.texture = ArrowTexture.triangle(ArrowTexture.Direction.UP, colour)
	if _choice_down_arrow.texture == null:
		_choice_down_arrow.texture = ArrowTexture.triangle(ArrowTexture.Direction.DOWN, colour)


# === Layout ===

## Places the window for `\wu`, `\wm`, or `\wd`.
## Includes its current slide offset.
func _reposition() -> void:
	var height: float = _panel_height()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.offset_left = PANEL_MARGIN
	_panel.offset_right = -PANEL_MARGIN
	var top: float = 0.0
	match _position:
		WindowPosition.TOP:
			_panel.anchor_top = 0.0
			_panel.anchor_bottom = 0.0
			top = PANEL_MARGIN
		WindowPosition.MIDDLE:
			_panel.anchor_top = 0.5
			_panel.anchor_bottom = 0.5
			top = -height * 0.5
		WindowPosition.BOTTOM:
			_panel.anchor_top = 1.0
			_panel.anchor_bottom = 1.0
			top = -(PANEL_MARGIN + height)
	_panel.offset_top = top + _slide_offset
	_panel.offset_bottom = top + height + _slide_offset
	_reposition_extra_windows()

func _panel_height() -> float:
	var padding: float = 16.0
	var style: StyleBox = _panel.get_theme_stylebox(&"panel")
	if style != null:
		padding = style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	return maxf(_text_height, _font_text_height()) + padding

## Height of [member _line_count] lines in the default font.
func _font_text_height() -> float:
	var line_height: float = FALLBACK_LINE_HEIGHT
	var font: Font = _label.get_theme_font(&"normal_font")
	if font != null:
		var font_size: int = _label.get_theme_font_size(&"normal_font_size")
		# Match the label's ascent-plus-descent line sizing.
		line_height = font.get_ascent(font_size) + font.get_descent(font_size)
	line_height += float(_label.get_theme_constant(&"line_separation"))
	return line_height * float(_line_count)

## Measures actual line height, including tags such as `<fs=32>`.
## Default-font text matches the estimate.
func _measure_text_height(lines: int) -> void:
	var top: float = _label.get_line_offset(_top_line)
	var below: int = _top_line + _line_count
	var bottom: float = (
		_label.get_line_offset(below) if below < lines else float(_label.get_content_height())
	)
	var measured: float = maxf(bottom - top, 0.0)
	if is_equal_approx(measured, _text_height):
		return
	_text_height = measured
	_reposition()

## Returns the message window's current or expected position.
func _message_rect() -> Rect2:
	if _panel.visible:
		return Rect2(_panel.position, _panel.size)
	var height: float = _panel_height()
	return Rect2(
		Vector2(PANEL_MARGIN, size.y - PANEL_MARGIN - height),
		Vector2(size.x - (PANEL_MARGIN * 2.0), height)
	)

## Anchors [param control] to the top left and puts it exactly at [param area].
func _place(control: Control, area: Rect2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = area.position.x
	control.offset_top = area.position.y
	control.offset_right = area.position.x + area.size.x
	control.offset_bottom = area.position.y + area.size.y

func _panel_padding(panel: PanelContainer) -> Vector2:
	var style: StyleBox = panel.get_theme_stylebox(&"panel")
	if style == null:
		return Vector2(16.0, 16.0)
	return Vector2(
		style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT),
		style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	)

## Distance the window travels when it slides out of view.
func _slide_away_offset() -> float:
	var travel: float = _panel_height() + PANEL_MARGIN * 2.0
	return -travel if _position == WindowPosition.TOP else travel

func _start_slide(opening: bool) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	var away: float = _slide_away_offset()
	_slide_tween = create_tween()
	if opening:
		_set_slide_offset(away)
		_slide_tween.tween_method(_set_slide_offset, away, 0.0, slide_duration)
	else:
		_slide_tween.tween_method(_set_slide_offset, _slide_offset, away, slide_duration)

func _set_slide_offset(value: float) -> void:
	_slide_offset = value
	_reposition()


# === Extra Windows ===

## Shows the whole of a picture beside the message, as `\f[name]` asks for.
func _show_face(picture_name: String) -> void:
	var texture: Texture2D = Assets.texture(AssetIndex.CATEGORY_PICTURES, picture_name.strip_edges())
	if texture == null:
		push_warning("MessageBox: no picture '%s' for a message face." % picture_name)
		return
	_apply_face(texture)

## Shows one cell of a face sheet, as `\ff[name]` and `\ff[name,index]` ask for.
## The cells are [constant ParsedMessage.FACE_CELL_SIZE] square and run [constant ParsedMessage.FACE_CELL_COLUMNS] to a row,
## so `\ff[name]` on its own is the top left corner of the picture.
func _show_face_cell(parameter: String) -> void:
	var fields: PackedStringArray = MessageCodes.split_fields(parameter)
	var picture_name: String = fields[0].strip_edges()
	var cell: int = maxi(fields[1].strip_edges().to_int(), 0) if fields.size() > 1 else 0
	var texture: Texture2D = Assets.texture(AssetIndex.CATEGORY_PICTURES, picture_name)
	if texture == null:
		push_warning("MessageBox: no picture '%s' for a message face." % picture_name)
		return
	var side: int = ParsedMessage.FACE_CELL_SIZE
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		float((cell % ParsedMessage.FACE_CELL_COLUMNS) * side),
		float((cell / ParsedMessage.FACE_CELL_COLUMNS) * side),
		float(side),
		float(side)
	)
	_apply_face(atlas)

func _apply_face(texture: Texture2D) -> void:
	_face_image.texture = texture
	_face_image.custom_minimum_size = texture.get_size()
	_face_panel.visible = true
	_reposition_extra_windows()

func _show_gold_window() -> void:
	var money: int = GameState.player.money if GameState.player != null else 0
	_gold_label.text = MessageCodes.format_money(money)
	_gold_panel.visible = true
	_reposition_extra_windows()

func _show_coins_window() -> void:
	var coins: int = GameState.player.coins if GameState.player != null else 0
	_coins_label.text = "%d Coins" % coins
	_coins_panel.visible = true
	_reposition_extra_windows()

func _show_battle_points_window() -> void:
	var points: int = GameState.player.battle_points if GameState.player != null else 0
	_battle_points_label.text = "%d BP" % points
	_battle_points_panel.visible = true
	_reposition_extra_windows()

## Places the face and info windows away from the message text.
func _reposition_extra_windows() -> void:
	if not is_node_ready():
		return
	var anchor: Rect2 = _message_rect()
	if _face_panel.visible:
		var face: Vector2 = _face_panel.get_combined_minimum_size()
		var top: float = anchor.position.y - face.y - PANEL_MARGIN
		if top < PANEL_MARGIN:
			top = PANEL_MARGIN
		_place(_face_panel, Rect2(Vector2(anchor.position.x, top), face))
	var info: Vector2 = _info_windows.get_combined_minimum_size()
	var high: bool = anchor.position.y > size.y * 0.5
	var info_top: float = PANEL_MARGIN if high else size.y - PANEL_MARGIN - info.y
	_place(
		_info_windows,
		Rect2(Vector2(size.x - PANEL_MARGIN - maxf(info.x, 160.0), info_top),
			Vector2(maxf(info.x, 160.0), info.y))
	)

func _hide_extra_windows() -> void:
	_face_panel.visible = false
	_gold_panel.visible = false
	_coins_panel.visible = false
	_battle_points_panel.visible = false

## Applies [param skin_name] from `\w[name]` or `\sign[name]`.
## An empty name restores the player's chosen frame.
func _apply_windowskin(skin_name: String) -> void:
	if skin_name.is_empty():
		_use_default_windowskin()
		return
	var skin: WindowSkin = WindowSkin.load_skin(skin_name)
	if skin == null:
		if not _reported_windowskins.has(skin_name):
			_reported_windowskins[skin_name] = true
			push_warning("MessageBox: no windowskin named '%s'." % skin_name)
		_use_default_windowskin()
		return
	if _frame_hidden:
		_hide_frame()
	else:
		_panel.add_theme_stylebox_override(
			&"panel", skin.panel_stylebox_with_padding(UIThemeBuilder.WINDOW_PADDING)
		)
	_refresh_arrow_frames(skin)

func _use_default_windowskin() -> void:
	if _frame_hidden:
		_hide_frame()
	else:
		_panel.remove_theme_stylebox_override(&"panel")
	_refresh_arrow_frames(UITheme.speech_window_skin())

## Draws the window without a frame.
## Keeps the normal padding.
func _hide_frame() -> void:
	var blank: StyleBoxEmpty = StyleBoxEmpty.new()
	blank.content_margin_left = float(UIThemeBuilder.WINDOW_PADDING.x)
	blank.content_margin_right = float(UIThemeBuilder.WINDOW_PADDING.x)
	blank.content_margin_top = float(UIThemeBuilder.WINDOW_PADDING.y)
	blank.content_margin_bottom = float(UIThemeBuilder.WINDOW_PADDING.y)
	_panel.add_theme_stylebox_override(&"panel", blank)


# === Wait Arrow ===

## Points the arrow at the frames of [param skin].
func _refresh_arrow_frames(skin: WindowSkin) -> void:
	_arrow_textures.clear()
	if skin != null:
		for frame: AtlasTexture in skin.pause_frames():
			_arrow_textures.append(frame)
	if _arrow_textures.is_empty():
		_arrow_textures = ArrowTexture.bobbing_frames(_label.get_theme_color(&"default_color"))
	_arrow_frame = 0
	_arrow_time = 0.0
	_continue_arrow.texture = _arrow_textures[0] if not _arrow_textures.is_empty() else null

## Advances the wait arrow animation while the window is visible.
func _animate_arrow(delta: float) -> void:
	if not _continue_arrow.visible or _arrow_textures.size() < 2:
		return
	_arrow_time += delta
	var frame: int = int(_arrow_time * arrow_frames_per_second) % _arrow_textures.size()
	if frame == _arrow_frame:
		return
	_arrow_frame = frame
	_continue_arrow.texture = _arrow_textures[frame]

## Rebuilds the window art after the player changes their frame in the options.
func _on_theme_changed() -> void:
	if _message != null and not _message.windowskin.is_empty():
		_apply_windowskin(_message.windowskin)
	else:
		_apply_windowskin("")
	_choice_up_arrow.texture = null
	_choice_down_arrow.texture = null
	_refresh_scroll_arrows()
	_reposition()
