extends GameScreen
## Save slot picker, used both for saving and (with [member load_mode]) loading.

const OVERWORLD_SCENE: String = "res://scenes/field/overworld.tscn"

## When set, choosing a slot loads it instead of saving to it.
@export var load_mode: bool = false

@onready var _slot_list: VBoxContainer = %SlotList
@onready var _prompt_label: Label = %SavePromptLabel

func _ready() -> void:
	super._ready()
	_prompt_label.text = "Load which game?" if load_mode else "Save to which slot?"
	refresh()

func refresh() -> void:
	for child: Node in _slot_list.get_children():
		child.queue_free()
	var first: Button = null
	for slot: int in range(SaveManager.SLOT_COUNT):
		var button: Button = Button.new()
		button.theme_type_variation = UIThemeBuilder.MENU_ENTRY
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_entered.connect(play_select)
		var summary: Dictionary = SaveManager.slot_summary(slot)
		if summary.is_empty():
			button.text = Loc.line("Slot {slot}   (empty)", {"slot": (slot + 1)})
			button.disabled = load_mode
		else:
			button.text = Loc.line("Slot {slot}   {name}   Badges {badges}   Dex {pokedex_owned}   {play_time}", {"slot": slot + 1, "name": summary["name"], "badges": summary["badges"], "pokedex_owned": summary["pokedex_owned"], "play_time": summary["play_time"]})
		button.pressed.connect(_on_slot_pressed.bind(slot))
		_slot_list.add_child(button)
		if first == null and not button.disabled:
			first = button
	if first != null:
		first.grab_focus()

func _on_slot_pressed(slot: int) -> void:
	play_confirm()
	if load_mode:
		if SaveManager.load_game(slot):
			SceneRouter.change_root_scene(OVERWORLD_SCENE)
			close(slot)
		return
	if SaveManager.save_game(slot):
		_prompt_label.text = Loc.line("Saved to slot {slot}.", {"slot": (slot + 1)})
		AudioManager.play_se("GUI save choice")
		refresh()
	else:
		_prompt_label.text = "Could not save."
