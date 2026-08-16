@tool
class_name OptionRow
extends HBoxContainer
## One settings-list row with a title and a value changed by left and right.
## Buttons keep keyboard changes in place without opening a popup.
## Only the value takes focus; the arrows remain mouse targets.

## Emitted when the player picks a different choice.
## [method select] does not emit it, allowing screens to initialize rows safely.
signal choice_changed(index: int)

## Text shown on the left. Exported so a row is written in the scene rather than
## built in code.
@export var title: String = "Option":
	set = set_title
	
## Appends the selected position when enabled.
@export var shows_position: bool = false:
	set = set_shows_position
	
## Steps past either end continue from the other, rather than stopping there.
@export var wraps: bool = true

var _choices: PackedStringArray = PackedStringArray()
var _selected: int = 0

@onready var _title_label: Label = %TitleLabel
@onready var _value_button: Button = %ValueButton
@onready var _previous_button: Button = %PreviousButton
@onready var _next_button: Button = %NextButton


func _ready() -> void:
	_title_label.text = title
	_refresh_value()
	if Engine.is_editor_hint():
		return
	_previous_button.pressed.connect(_on_stepped.bind(-1))
	_next_button.pressed.connect(_on_stepped.bind(1))
	_value_button.pressed.connect(_on_stepped.bind(1))
	_value_button.gui_input.connect(_on_value_gui_input)

# === Properties ===

func set_title(value: String) -> void:
	title = value
	if is_node_ready():
		_title_label.text = value

func set_shows_position(value: bool) -> void:
	shows_position = value
	if is_node_ready():
		_refresh_value()

# === Choices ===

## Replaces the list of choices, keeping the player on the same entry number.
## That is what a row wants after a language change, which rebuilds the labels without changing what is selected.
func set_choices(labels: PackedStringArray) -> void:
	_choices = labels
	_selected = clampi(_selected, 0, maxi(_choices.size() - 1, 0))
	if is_node_ready():
		_refresh_value()

func choice_count() -> int:
	return _choices.size()

## Shows the choice at [param index], without emitting [signal choice_changed].
func select(index: int) -> void:
	_selected = _resolve(index)
	if is_node_ready():
		_refresh_value()

func selected() -> int:
	return _selected

## The current choice's label, or an empty string when the row has no choices.
func selected_text() -> String:
	if _selected < 0 or _selected >= _choices.size():
		return ""
	return _choices[_selected]

## Moves [param amount] choices and emits the change when the value changes.
func step(amount: int) -> void:
	var index: int = _resolve(_selected + amount)
	if index == _selected:
		return
	_selected = index
	_refresh_value()
	choice_changed.emit(_selected)


# === Focus ===

## Returns the control that takes focus for this row.
func focus_target() -> Control:
	return _value_button

func grab_row_focus() -> void:
	_value_button.grab_focus()

func has_row_focus() -> bool:
	return _value_button.has_focus()

# === Internals ===

func _resolve(index: int) -> int:
	if _choices.is_empty():
		return 0
	if wraps:
		return posmod(index, _choices.size())
	return clampi(index, 0, _choices.size() - 1)

func _refresh_value() -> void:
	var value: String = selected_text()
	if shows_position and not _choices.is_empty():
		value = "%s  (%d/%d)" % [value, _selected + 1, _choices.size()]
	_value_button.text = value
	var steppable: bool = _choices.size() > 1
	_previous_button.disabled = not steppable or (not wraps and _selected == 0)
	_next_button.disabled = not steppable or (not wraps and _selected == _choices.size() - 1)

## Handles pointer and accept input, focusing the row before changing its value.
func _on_stepped(amount: int) -> void:
	_value_button.grab_focus()
	step(amount)

## Handles left and right before focus navigation can move out of the row.
func _on_value_gui_input(event: InputEvent) -> void:
	var amount: int = 0
	if event.is_action_pressed(&"ui_left", true):
		amount = -1
	elif event.is_action_pressed(&"ui_right", true):
		amount = 1
	if amount == 0:
		return
	_value_button.accept_event()
	step(amount)
