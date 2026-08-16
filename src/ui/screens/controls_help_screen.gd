class_name ControlsHelpScreen
extends GameScreen
## The explination of controls that Oak offers at the beginning of the game

const SCENE_PATH: String = "res://scenes/ui/screens/controls_help_screen.tscn"

## One row of a page
const CONTROLS_HELP_ROW: PackedScene = preload("res://scenes/ui/controls_help_row.tscn")

## The pages, in order. 
## Each is a title and a list of `[action, description]` rows
## An empty action is a row with no key
const PAGES: Array = [
	[
		"Moving around",
		[
			[
				&"",
				"Use the Arrow keys to move around.\n\nThey also move the cursor "
				+ "through menus and lists.",
			],
		],
	],
	[
		"Talking and choosing",
		[
			[
				&"ui_accept",
				"Confirms a choice, talks to people, looks at things, and moves "
				+ "through what they say.",
			],
			[
				&"ui_cancel",
				"Leaves a menu and takes a choice back. Held down while walking, "
				+ "it runs.",
			],
		],
	],
	[
		"Menus",
		[
			[&"game_menu", "Opens the pause menu."],
			[
				&"game_special",
				"Opens the Ready Menu, where a registered item or a field move "
				+ "one of your Pokemon knows can be used without going through "
				+ "the bag.",
			],
		],
	],
	[
		"Changing the keys",
		[
			[&"game_run", "Runs, held down while you walk."],
			[
				&"",
				"Any of these keys can be changed: open the pause menu and "
				+ "choose Controls.",
			],
		],
	],
]

@onready var _title_label: Label = %HelpTitle
@onready var _row_list: VBoxContainer = %HelpRowList
@onready var _progress_label: Label = %HelpProgress
@onready var _prompt_label: Label = %HelpPrompt

## Which page is showing, zero indexed
var _page: int = 0


func _ready() -> void:
	super._ready()
	_show_page(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()
		return
	super._unhandled_input(event)


## Moves to the next page
## Closes the screen post the last once
func _advance() -> void:
	play_confirm()
	if _page + 1 >= PAGES.size():
		close(null, true)
		return
	_show_page(_page + 1)


func _show_page(number: int) -> void:
	_page = clampi(number, 0, PAGES.size() - 1)
	var page: Array = PAGES[_page]
	_title_label.text = String(page[0])
	for child: Node in _row_list.get_children():
		child.queue_free()
	var keyed: bool = false
	for row: Array in page[1]:
		keyed = keyed or not StringName(row[0]).is_empty()
	for row: Array in page[1]:
		_add_row(StringName(row[0]), String(row[1]), keyed)
	_progress_label.text = "%d/%d" % [_page + 1, PAGES.size()]
	_prompt_label.text = (
		"Press %s to finish." % KeyBindings.key_name_for(&"ui_accept")
		if _page + 1 >= PAGES.size()
		else "Press %s to go on." % KeyBindings.key_name_for(&"ui_accept")
	)


## One row of the page
func _add_row(action: StringName, description: String, keep_key_column: bool) -> void:
	var row: ControlsHelpRow = CONTROLS_HELP_ROW.instantiate()
	_row_list.add_child(row)
	row.bind(action, description, keep_key_column)
