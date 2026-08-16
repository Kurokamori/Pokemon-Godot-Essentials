extends Control
## Title screen splash and main menu.

const OVERWORLD_SCENE: String = "res://scenes/field/overworld.tscn"
const INTRO_SCENE: String = "res://scenes/ui/screens/intro_screen.tscn"
const OPTIONS_SCENE: String = "res://scenes/ui/screens/options_screen.tscn"

## Track played over the title screen.
@export var TITLE_BGM: String = "Title"

## Seconds between blinks of the "press enter" prompt.
@export var PROMPT_BLINK_SECONDS: float = 0.6

## Seconds the menu takes to slide in.
@export var MENU_SLIDE_SECONDS: float = 0.25

## Distance the menu slides up from.
@export var MENU_SLIDE_DISTANCE: float = 24.0

@onready var _press_start: TextureRect = %PressStart
@onready var _menu_panel: PanelContainer = %MenuPanel
@onready var _save_panel: PanelContainer = %SavePanel
@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _save_name: Label = %SaveNameLabel
@onready var _save_badges: Label = %SaveBadgesLabel
@onready var _save_dex: Label = %SaveDexLabel
@onready var _save_time: Label = %SaveTimeLabel

var _menu_open: bool = false
var _blink_time: float = 0.0

func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	for button: Button in [_continue_button, _new_game_button, _options_button, _quit_button]:
		button.focus_entered.connect(_on_entry_focused)
	_menu_panel.visible = false
	_save_panel.visible = false
	AudioManager.play_bgm(TITLE_BGM)
	set_process_unhandled_input(true)

func _process(delta: float) -> void:
	_blink_time += delta
	_press_start.visible = fmod(_blink_time, PROMPT_BLINK_SECONDS * 2.0) < PROMPT_BLINK_SECONDS

func _unhandled_input(event: InputEvent) -> void:
	if _menu_open:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		return
	if not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	_open_menu()

## Reveals the menu and the save summary, and stops the prompt blinking.
func _open_menu() -> void:
	_menu_open = true
	set_process(false)
	_press_start.visible = false
	AudioManager.play_se(UITheme.skin.confirm_sound)
	_refresh_save_summary()
	_menu_panel.visible = true
	_slide_in(_menu_panel)
	_focus_first_entry()

## Slides [param panel] up into place.
func _slide_in(panel: Control) -> void:
	var target: float = panel.position.y
	panel.position.y = target + MENU_SLIDE_DISTANCE
	panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "position:y", target, MENU_SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, MENU_SLIDE_SECONDS)

## Fills the save summary or disables Continue when no save exists.
func _refresh_save_summary() -> void:
	var slot: int = SaveManager.most_recent_slot()
	if slot < 0:
		_continue_button.disabled = true
		_save_panel.visible = false
		return
	var summary: Dictionary = SaveManager.slot_summary(slot)
	_save_name.text = String(summary.get("name", "Player"))
	_save_badges.text = "Badges   %d" % int(summary.get("badges", 0))
	_save_dex.text = "Pokedex  %d" % int(summary.get("pokedex_owned", 0))
	_save_time.text = "Time     %s" % String(summary.get("play_time", "0:00"))
	_save_panel.visible = true
	_slide_in(_save_panel)

func _focus_first_entry() -> void:
	if _continue_button.disabled:
		_new_game_button.grab_focus()
		return
	_continue_button.grab_focus()

func _on_entry_focused() -> void:
	AudioManager.play_se(UITheme.skin.select_sound)

# === Entries ===

func _on_continue_pressed() -> void:
	var slot: int = SaveManager.most_recent_slot()
	if slot < 0:
		return
	AudioManager.play_se(UITheme.skin.confirm_sound)
	if SaveManager.load_game(slot):
		AudioManager.fade_out_bgm()
		SceneRouter.change_root_scene(OVERWORLD_SCENE)

func _on_new_game_pressed() -> void:
	AudioManager.play_se(UITheme.skin.confirm_sound)
	var scene: PackedScene = load(INTRO_SCENE)
	if scene == null:
		push_error("TitleScreen: %s could not be loaded." % INTRO_SCENE)
		return
	var completed: Variant = await SceneRouter.push_screen(scene)
	if not bool(completed):
		_focus_first_entry()
		return
	AudioManager.fade_out_bgm()
	SceneRouter.change_root_scene(OVERWORLD_SCENE)

func _on_options_pressed() -> void:
	AudioManager.play_se(UITheme.skin.confirm_sound)
	var scene: PackedScene = load(OPTIONS_SCENE)
	if scene != null:
		await SceneRouter.push_screen(scene)
	_options_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
