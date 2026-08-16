class_name ControlsScreen
extends GameScreen
## Essentials' `UI_Controls`: rebinding the keys.

const SCENE_PATH: String = "res://scenes/ui/screens/controls_screen.tscn"

@onready var _row_list: VBoxContainer = %ControlsRowList
@onready var _status_label: Label = %ControlsStatus

## The action waiting for a key, or nothing if no key is being bound
var _listening: StringName = &""
var _rows: Dictionary = {}


func _ready() -> void:
	super._ready()
	_build()


## While a row is listening, all inputs are its own
func _input(event: InputEvent) -> void:
	if _listening.is_empty():
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.physical_keycode == KEY_ESCAPE:
		_stop_listening(Loc.line("Left as it was."))
		return
	_apply(key.physical_keycode)


func _unhandled_input(event: InputEvent) -> void:
	if not _listening.is_empty():
		return
	super._unhandled_input(event)


func _build() -> void:
	for child: Node in _row_list.get_children():
		child.queue_free()
	_rows.clear()
	var first: Button = null
	for entry: Array in KeyBindings.rebindable():
		var action: StringName = StringName(entry[0])
		var button: Button = Button.new()
		button.theme_type_variation = UIThemeBuilder.MENU_ENTRY
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_start_listening.bind(action))
		button.focus_entered.connect(play_select)
		_row_list.add_child(button)
		_rows[action] = button
		if first == null:
			first = button
	var reset: Button = Button.new()
	reset.text = Loc.line("Reset to defaults")
	reset.theme_type_variation = UIThemeBuilder.MENU_ENTRY
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.pressed.connect(_on_reset)
	reset.focus_entered.connect(play_select)
	_row_list.add_child(reset)
	_refresh()
	if first != null:
		first.grab_focus.call_deferred()


func _refresh() -> void:
	for entry: Array in KeyBindings.rebindable():
		var action: StringName = StringName(entry[0])
		var button: Button = _rows.get(action) as Button
		if button == null:
			continue
		button.text = "%s%s%s" % [
			Loc.line(String(entry[1])), "   ", KeyBindings.key_name_for(action),
		]


func _start_listening(action: StringName) -> void:
	play_confirm()
	_listening = action
	_status_label.text = Loc.line("Press a key. Escape leaves it as it was.")


func _apply(key: Key) -> void:
	var action: StringName = _listening
	var clash: StringName = KeyBindings.action_using(key)
	if not clash.is_empty() and clash != action:
		_stop_listening(Loc.line("{key} is already {action}.", {
			"key": OS.get_keycode_string(key), "action": _label_for(clash),
		}))
		return
	if not KeyBindings.rebind(action, key):
		_stop_listening(Loc.line("That key cannot be used."))
		return
	GameSettings.save_key_bindings()
	_stop_listening(Loc.line("{action} is now {key}.", {
		"action": _label_for(action), "key": OS.get_keycode_string(key),
	}))


func _on_reset() -> void:
	play_confirm()
	KeyBindings.restore_defaults()
	GameSettings.save_key_bindings()
	_refresh()
	_status_label.text = Loc.line("The keys are back to what the game shipped with.")


## Stops waiting for a key and says what happened.
func _stop_listening(message: String) -> void:
	var was_listening: StringName = _listening
	_listening = &""
	_status_label.text = message
	_refresh()
	var button: Button = _rows.get(was_listening) as Button
	if button != null:
		button.grab_focus.call_deferred()


func _label_for(action: StringName) -> String:
	for entry: Array in KeyBindings.rebindable():
		if StringName(entry[0]) == action:
			return Loc.line(String(entry[1]))
	return String(action)
