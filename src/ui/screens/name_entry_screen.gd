extends GameScreen
## The universal naming keyboard

## Characters offered per page, populated by [NameEntryCharsetData], a string per page
@export var pages: Array[String] = [
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"abcdefghijklmnopqrstuvwxyz",
	"0123456789 !?.,-'\"/()&:;",
]

## Label for each page's switch button, in the same order as [member pages]
@export var page_names: Array[String] = ["ABC", "abc", "123"]

## The characters per row in the grid
@export_range(4, 16) var columns: int = 9

## Lowest character code that represents something typeable
const FIRST_PRINTABLE: int = 32

## Delete, which is above control codes but also not typeable
const DELETE_CHARACTER: int = 127

@export var tab_scene: PackedScene = preload("res://scenes/ui/pocket_tab_button.tscn")
@export var key_scene: PackedScene = preload("res://scenes/ui/menu_entry_button.tscn")

@onready var _prompt_label: Label = %PromptLabel
@onready var _name_label: Label = %NameLabel
@onready var _portrait: TextureRect = %Portrait
@onready var _grid: GridContainer = %CharacterGrid
@onready var _page_row: HBoxContainer = %PageRow
@onready var _suggestion_row: HBoxContainer = %SuggestionRow
@onready var _backspace_button: Button = %BackspaceButton
@onready var _accept_button: Button = %AcceptButton

## Name being typed.
var _entered: String = ""

## Max length something can be beyond the caller's limit adn the language's limit considerations
var _max_length: int = 10

## What the caller asked for
var _requested_max_length: int = 10

## What the language allows, or `0` when it does not say
var _charset_max_length: int = 0

## Used when the player accepts an empty name.
var _fallback: String = ""

var _page: int = 0
var _page_buttons: Array[Button] = []
var _character_buttons: Array[Button] = []


func _ready() -> void:
	super._ready()
	closes_on_cancel = false
	_backspace_button.pressed.connect(_on_backspace_pressed)
	_accept_button.pressed.connect(_on_accept_pressed)
	_adopt_charset(NameEntryCharsets.for_current_locale())
	_build_page_buttons()
	_show_page(0)
	_refresh_name()

## Takes the keys for the language being played
func _adopt_charset(charset: NameEntryCharsetData) -> void:
	if charset == null:
		return
	pages = charset.pages.duplicate()
	page_names = charset.page_names.duplicate()
	columns = charset.columns
	_charset_max_length = charset.max_length
	_update_max_length()

## Configures the screen before it is shown
func setup(prompt: String, fallback: String, max_length: int, suggestions: Array[String] = [], portrait: Texture2D = null) -> void:
	_fallback = fallback
	_requested_max_length = maxi(max_length, 1)
	_update_max_length()
	if is_node_ready():
		_apply_setup(prompt, suggestions, portrait)
		return
	ready.connect(_apply_setup.bind(prompt, suggestions, portrait), CONNECT_ONE_SHOT)

func _apply_setup(prompt: String, suggestions: Array[String], portrait: Texture2D) -> void:
	_prompt_label.text = prompt
	_portrait.texture = portrait
	_portrait.visible = portrait != null
	_build_suggestions(suggestions)
	_refresh_name()

## Applies whichever limit is tighter, the caller's or the language's
func _update_max_length() -> void:
	if _charset_max_length > 0:
		_max_length = mini(_requested_max_length, _charset_max_length)
	else:
		_max_length = _requested_max_length

## The name as it stands
func entered_name() -> String:
	return _entered if not _entered.is_empty() else _fallback


# === Pages ===

func _build_page_buttons() -> void:
	for index: int in range(pages.size()):
		var button: Button = tab_scene.instantiate() as Button
		button.name = "Page%d" % index
		button.text = page_names[index] if index < page_names.size() else str(index + 1)
		button.pressed.connect(_on_page_pressed.bind(index))
		_page_row.add_child(button)
		_page_buttons.append(button)

func _on_page_pressed(index: int) -> void:
	play_select()
	_show_page(index)

## Rebuilds the character grid for [param index]
func _show_page(index: int) -> void:
	if pages.is_empty():
		return
	_page = clampi(index, 0, pages.size() - 1)
	for button: Button in _page_buttons:
		button.button_pressed = button == _page_buttons[_page]
	for button: Button in _character_buttons:
		button.queue_free()
	_character_buttons.clear()
	_grid.columns = columns
	for character: String in pages[_page]:
		var button: Button = key_scene.instantiate() as Button
		button.text = character
		button.custom_minimum_size = Vector2(28, 26)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_character_pressed.bind(character))
		_grid.add_child(button)
		_character_buttons.append(button)
	if not _character_buttons.is_empty():
		_character_buttons[0].grab_focus()

func _build_suggestions(suggestions: Array[String]) -> void:
	for child: Node in _suggestion_row.get_children():
		child.queue_free()
	_suggestion_row.visible = not suggestions.is_empty()
	for suggestion: String in suggestions:
		var button: Button = key_scene.instantiate() as Button
		button.text = suggestion
		button.pressed.connect(_on_suggestion_pressed.bind(suggestion))
		_suggestion_row.add_child(button)


# === Typing ===

func _on_character_pressed(character: String) -> void:
	if _entered.length() >= _max_length:
		return
	play_select()
	_entered += character
	_refresh_name()

func _on_suggestion_pressed(suggestion: String) -> void:
	play_confirm()
	_entered = suggestion.substr(0, _max_length)
	_refresh_name()

func _on_backspace_pressed() -> void:
	if _entered.is_empty():
		return
	play_select()
	_entered = _entered.substr(0, _entered.length() - 1)
	_refresh_name()

func _on_accept_pressed() -> void:
	play_confirm()
	close(entered_name())

## Typing on a real keyboard fills the same buffer
func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	for action: StringName in [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down",
			&"ui_left", &"ui_right"]:
		if event.is_action_pressed(action):
			return
	if key.keycode == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		_on_backspace_pressed()
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_on_accept_pressed()
		return
	if key.unicode < FIRST_PRINTABLE or key.unicode == DELETE_CHARACTER:
		return
	get_viewport().set_input_as_handled()
	_on_character_pressed(char(key.unicode))

## Cancel deletes the last character rather than closing the screen
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _entered.is_empty():
		close("")
		return
	_on_backspace_pressed()

## Draws the name as filled and empty slots
func _refresh_name() -> void:
	var slots: PackedStringArray = PackedStringArray()
	for index: int in range(_max_length):
		slots.append(_entered.substr(index, 1) if index < _entered.length() else "_")
	_name_label.text = " ".join(slots)
	_backspace_button.disabled = _entered.is_empty()

## Backing out of naming returns nothing rather than a half-typed name
func close(result: Variant = null, silent: bool = false) -> void:
	super.close(result if result is String else "", silent)
