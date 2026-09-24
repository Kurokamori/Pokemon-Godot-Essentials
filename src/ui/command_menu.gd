class_name CommandMenu
extends PanelContainer
## A command list opened beside its anchor.

## A selectable command.
class Command extends RefCounted:
	## Id sent with [signal command_chosen].
	var id: StringName = &""
	## Label shown in the menu.
	var text: String = ""
	## Disabled entries cannot be chosen.
	var enabled: bool = true

	func _init(command_id: StringName, label: String, is_enabled: bool = true) -> void:
		id = command_id
		text = label
		enabled = is_enabled

## Emitted when a command is chosen, including [member cancel_command].
signal command_chosen(id: StringName)

## Separate scene keeps menu entries independent of dialogue styling.
const ENTRY_SCENE: PackedScene = preload("res://scenes/ui/command_menu_entry.tscn")

## Space between the menu and its anchor.
const ANCHOR_GAP: float = 4.0
## Minimum space from the screen edge.
const SCREEN_MARGIN: float = 6.0

## Id emitted when the player cancels.
@export var cancel_command: StringName = &"cancel"

@onready var _list: VBoxContainer = %CommandList

var _entries: Array[Button] = []
## Control to refocus when the menu closes.
var _return_focus: Control = null
var _open: bool = false

func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)

func is_open() -> bool:
	return _open

## Opens beside [param anchor], or centred without one. Focus returns there on close.
func open(commands: Array[Command], anchor: Control = null) -> void:
	_clear_entries()
	for command: Command in commands:
		_add_entry(command)
	_link_entries()
	if _entries.is_empty():
		push_warning("CommandMenu: opened with no commands.")
		return
	_return_focus = anchor
	_open = true
	set_process_unhandled_input(true)
	await get_tree().process_frame
	if not _open:
		return
	reset_size()
	_place_beside(anchor)
	visible = true
	_focus_first()

## Hides the menu and restores focus to its anchor.
func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	set_process_unhandled_input(false)
	_clear_entries()
	if _return_focus != null and is_instance_valid(_return_focus) and _return_focus.is_inside_tree():
		_return_focus.grab_focus()
	_return_focus = null

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_choose(cancel_command)

# === Entries ===

func _add_entry(command: Command) -> void:
	var button: Button = ENTRY_SCENE.instantiate() as Button
	if button == null:
		push_error("CommandMenu: %s is not a Button." % ENTRY_SCENE.resource_path)
		return
	button.text = command.text
	button.disabled = not command.enabled
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_choose.bind(command.id))
	button.focus_entered.connect(_on_entry_focused)
	_list.add_child(button)
	_entries.append(button)

## Wraps focus from either end of the list.
func _link_entries() -> void:
	var count: int = _entries.size()
	for index: int in range(count):
		var entry: Button = _entries[index]
		var previous: Button = _entries[posmod(index - 1, count)]
		var next: Button = _entries[posmod(index + 1, count)]
		entry.focus_neighbor_top = previous.get_path()
		entry.focus_neighbor_bottom = next.get_path()
		entry.focus_previous = previous.get_path()
		entry.focus_next = next.get_path()
		entry.focus_neighbor_left = entry.get_path()
		entry.focus_neighbor_right = entry.get_path()

func _clear_entries() -> void:
	for entry: Button in _entries:
		entry.queue_free()
	_entries.clear()

func _focus_first() -> void:
	for entry: Button in _entries:
		if not entry.disabled:
			entry.grab_focus()
			return
	if not _entries.is_empty():
		_entries[0].grab_focus()

func _on_entry_focused() -> void:
	AudioManager.play_se("GUI sel cursor")

func _choose(id: StringName) -> void:
	if not _open:
		return
	AudioManager.play_se("GUI sel decision" if id != cancel_command else "GUI menu close")
	close()
	command_chosen.emit(id)

# === Placement ===

## Places the menu beside its anchor and keeps it on screen.
func _place_beside(anchor: Control) -> void:
	var screen: Vector2 = get_viewport_rect().size
	var menu_size: Vector2 = size
	var target: Vector2 = (screen - menu_size) * 0.5
	if anchor != null and is_instance_valid(anchor) and anchor.is_inside_tree():
		var rect: Rect2 = anchor.get_global_rect()
		target = Vector2(rect.end.x + ANCHOR_GAP, rect.position.y)
		if target.x + menu_size.x > screen.x - SCREEN_MARGIN:
			target.x = rect.position.x - menu_size.x - ANCHOR_GAP
	var lowest: Vector2 = Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	var highest: Vector2 = screen - menu_size - lowest
	global_position = target.clamp(lowest, highest.max(lowest))
