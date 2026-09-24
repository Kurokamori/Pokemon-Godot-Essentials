extends GameScreen
## Shows pockets, their items, and actions for the selected item.
## Cancel backs out one level at a time.

const PARTY_SCREEN: String = "res://scenes/ui/party_screen.tscn"

## Item menu command ids.
const COMMAND_USE: StringName = &"use"
const COMMAND_GIVE: StringName = &"give"
const COMMAND_TOSS: StringName = &"toss"
const COMMAND_REGISTER: StringName = &"register"
const COMMAND_CANCEL: StringName = &"cancel"

const HINT_POCKETS: String = "Up/Down: pocket    C: open    X: close"
const HINT_ITEMS: String = "Up/Down: choose    C: select    X: back"

## Return the chosen item id instead of showing its actions.
@export var selection_mode: bool = false

## Show only items usable in battle.
@export var battle_mode: bool = false

## Show only items that can affect this Pokemon.
var usable_on: Pokemon = null

## Scene used to draw pocket tabs.
@export var tab_scene: PackedScene = preload("res://scenes/ui/pocket_tab_button.tscn")

@onready var _pocket_label: Label = %PocketLabel
@onready var _pocket_list: VBoxContainer = %PocketList
@onready var _item_list: ItemList = %ItemList
@onready var _description: RichTextLabel = %ItemDescription
@onready var _icon: TextureRect = %ItemIcon
@onready var _hint: Label = %HintLabel
@onready var _command_menu: CommandMenu = %CommandMenu
@onready var _message_box: MessageBox = %MessageBox

var _pocket: int = BagPockets.ITEMS
var _pocket_buttons: Array[Button] = []
var _cursor: ItemListCursor = null

## Item owned by the open command menu.
var _menu_item: StringName = &""

## True while a nested screen handles input.
var _busy: bool = false

func _ready() -> void:
	super._ready()
	_pocket = GameState.bag.last_viewed_pocket
	_build_pockets()
	_cursor = ItemListCursor.new(_item_list)
	_cursor.moved.connect(_on_item_selected)
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.item_activated.connect(_on_item_activated)
	_command_menu.command_chosen.connect(_on_command_chosen)
	refresh(true)
	_focus_pocket()

func _build_pockets() -> void:
	for button: Button in _pocket_buttons:
		button.queue_free()
	_pocket_buttons.clear()
	for pocket: int in BagPockets.all():
		var button: Button = tab_scene.instantiate() as Button
		button.text = BagPockets.name_of(pocket)
		button.icon = Assets.bag_pocket_icon(pocket)
		button.button_pressed = pocket == _pocket
		button.focus_entered.connect(_on_pocket_focused.bind(pocket))
		button.pressed.connect(_on_pocket_pressed.bind(pocket))
		_pocket_list.add_child(button)
		_pocket_buttons.append(button)
	_link_pockets()

## Wraps focus between pockets; right enters the item list.
func _link_pockets() -> void:
	var count: int = _pocket_buttons.size()
	for index: int in range(count):
		var button: Button = _pocket_buttons[index]
		var previous: Button = _pocket_buttons[posmod(index - 1, count)]
		var next: Button = _pocket_buttons[posmod(index + 1, count)]
		button.focus_neighbor_top = previous.get_path()
		button.focus_neighbor_bottom = next.get_path()
		button.focus_previous = previous.get_path()
		button.focus_next = next.get_path()
		button.focus_neighbor_left = button.get_path()
		button.focus_neighbor_right = _item_list.get_path()
	_sync_pocket_tabs()

## Updates the selected tab and the list's left focus target.
func _sync_pocket_tabs() -> void:
	var pockets: Array[int] = BagPockets.all()
	for index: int in range(_pocket_buttons.size()):
		_pocket_buttons[index].button_pressed = pockets[index] == _pocket
	var current: int = pockets.find(_pocket)
	if current >= 0 and current < _pocket_buttons.size():
		_item_list.focus_neighbor_left = _pocket_buttons[current].get_path()
		_item_list.focus_previous = _pocket_buttons[current].get_path()

# === Input ===

## Handle list movement before the focus system moves off the list.
func _input(event: InputEvent) -> void:
	if _busy or _command_menu.is_open() or not _item_list.has_focus():
		return
	if _cursor.handle_input(event):
		get_viewport().set_input_as_handled()

## Cancel returns from the items to the pockets before closing the bag.
func _unhandled_input(event: InputEvent) -> void:
	if _busy or _command_menu.is_open():
		return
	if _item_list.has_focus() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play_se("GUI menu close")
		_focus_pocket()
		return
	super._unhandled_input(event)

# === Pockets ===

## Focus the open pocket's tab.
func _focus_pocket() -> void:
	var index: int = BagPockets.all().find(_pocket)
	if index < 0 or index >= _pocket_buttons.size():
		index = 0
	if _pocket_buttons.is_empty():
		return
	_pocket_buttons[index].grab_focus()
	_update_hint()

## Show the pocket under the cursor.
func _on_pocket_focused(pocket: int) -> void:
	_update_hint()
	if pocket == _pocket:
		return
	_show_pocket(pocket)

## Enter the chosen pocket's item list.
func _on_pocket_pressed(pocket: int) -> void:
	if pocket != _pocket:
		_show_pocket(pocket)
	# Restore tab state before entering the list.
	_sync_pocket_tabs()
	_enter_items()

func _show_pocket(pocket: int) -> void:
	_pocket = pocket
	GameState.bag.last_viewed_pocket = pocket
	play_select()
	_sync_pocket_tabs()
	refresh(true)

## Focus the item list, or stay on the tabs if it is empty.
func _enter_items() -> void:
	if _item_list.item_count == 0:
		AudioManager.play_se("GUI sel buzzer")
		return
	play_confirm()
	_item_list.grab_focus()
	_update_hint()

func _update_hint() -> void:
	_hint.text = HINT_ITEMS if _item_list.has_focus() else HINT_POCKETS

# === Items ===

## Fill the list and preserve its cursor unless [param reset_cursor] is set.
func refresh(reset_cursor: bool = false) -> void:
	var previous: int = -1 if reset_cursor else _cursor.current()
	_pocket_label.text = BagPockets.name_of(_pocket)
	_item_list.clear()
	for slot: Array in GameState.bag.get_pocket(_pocket):
		var record: ItemData = Database.item(slot[0])
		if record == null:
			continue
		if battle_mode and record.battle_use == ItemData.BattleUse.NONE:
			continue
		if usable_on != null and not ItemUsage.can_use_on(record, usable_on):
			continue
		var label: String = record.display_name
		if record.show_quantity:
			label += "  x%d" % slot[1]
		_item_list.add_item(label, Assets.item_icon(record.id))
		_item_list.set_item_metadata(_item_list.item_count - 1, record.id)
	if _item_list.item_count > 0:
		var target: int = clampi(previous, 0, _item_list.item_count - 1)
		_cursor.select(target)
		_show_item(target)
		return
	_description.text = "There is nothing here."
	_icon.texture = null

func _show_item(index: int) -> void:
	var item_id: StringName = _item_list.get_item_metadata(index)
	var record: ItemData = Database.item(item_id)
	if record == null:
		return
	_description.text = record.description
	_icon.texture = Assets.item_icon(record.id)

func _on_item_selected(index: int) -> void:
	play_select()
	_show_item(index)

func _on_item_activated(index: int) -> void:
	if _busy or _command_menu.is_open():
		return
	var item_id: StringName = _item_list.get_item_metadata(index)
	play_confirm()
	if selection_mode:
		close(item_id)
		return
	_show_actions(item_id)

# === Item commands ===

func _show_actions(item_id: StringName) -> void:
	var record: ItemData = Database.item(item_id)
	if record == null:
		return
	_menu_item = item_id
	var commands: Array[CommandMenu.Command] = []
	if record.field_use != ItemData.FieldUse.NONE:
		commands.append(CommandMenu.Command.new(COMMAND_USE, _use_label(record)))
	# Show the action the toggle would take.
	if record.can_register():
		commands.append(CommandMenu.Command.new(COMMAND_REGISTER,
			"Deregister" if GameState.bag.is_registered(item_id) else "Register"))
	if not record.is_important():
		commands.append(CommandMenu.Command.new(COMMAND_GIVE, "Give"))
		commands.append(CommandMenu.Command.new(COMMAND_TOSS, "Toss"))
	commands.append(CommandMenu.Command.new(COMMAND_CANCEL, "Cancel"))
	_command_menu.open(commands, _item_list)

## Return the Use label for [param record], including toggle state.
func _use_label(record: ItemData) -> String:
	if FieldItemEffects.BICYCLES.has(record.id):
		return "Walk" if GameState.is_cycling() else "Use"
	match record.id:
		FieldItemEffects.EXP_ALL_ON: return "Turn off"
		FieldItemEffects.EXP_ALL_OFF: return "Turn on"
	return "Use"

func _on_command_chosen(id: StringName) -> void:
	var item_id: StringName = _menu_item
	_menu_item = &""
	if item_id.is_empty():
		return
	match id:
		COMMAND_USE:
			_on_use(item_id)
		COMMAND_GIVE:
			_on_give(item_id)
		COMMAND_TOSS:
			_on_toss(item_id)
		COMMAND_REGISTER:
			_on_register(item_id)

## Toggle the item's Ready Menu registration.
func _on_register(item_id: StringName) -> void:
	if GameState.bag.is_registered(item_id):
		GameState.bag.deregister_item(item_id)
	else:
		GameState.bag.register_item(item_id)
	refresh()

## Use the item on a Pokemon or pass it to [FieldItemEffects].
func _on_use(item_id: StringName) -> void:
	var record: ItemData = Database.item(item_id)
	if record == null:
		return
	if record.field_use == ItemData.FieldUse.ON_POKEMON or record.is_machine() or record.is_evolution_stone():
		await _use_on_party_member(record)
		_return_focus()
		return
	_busy = true
	var outcome: FieldItemEffects.Outcome = await _field_items().use_from_bag(item_id)
	_busy = false
	match outcome:
		FieldItemEffects.Outcome.USED:
			if record.consumable:
				GameState.bag.remove_item(item_id, 1)
			refresh()
		FieldItemEffects.Outcome.ON_THE_MAP:
			# The overworld uses the item after the bag closes.
			# Without an overworld, report that the item cannot be used.
			if Overworld.current == null:
				await _message_box.show_message("Can't use that here.")
				_return_focus()
				return
			Overworld.current.request_field_item(item_id)
			close()
			return
	_return_focus()

## Choose a Pokemon and use the item on it.
func _use_on_party_member(record: ItemData) -> void:
	var index: int = await _choose_party_member(record.id)
	if index < 0:
		return
	var pkmn: Pokemon = GameState.party.get_member(index)
	_busy = true
	var worked: bool = await ItemUsage.use_on_pokemon(record, pkmn, -1, _lesson())
	_busy = false
	if not worked:
		await _message_box.show_message("It won't have any effect.")
		return
	if record.consumable:
		GameState.bag.remove_item(record.id, 1)
	refresh()

## Route field item messages through the bag's message window.
func _field_items() -> FieldItemEffects:
	var handler: FieldItemEffects = FieldItemEffects.new()
	handler.narrate = func(text: String) -> void:
		await _message_box.show_message(text)
	handler.confirm = func(question: String) -> bool:
		return await _message_box.show_message_with_choices(question, ["Yes", "No"], 2) == 0
	return handler

## Route move learning messages through the bag's message window.
func _lesson() -> MoveLearning:
	var teaching: MoveLearning = MoveLearning.new()
	teaching.narrate = func(text: String) -> void:
		await _message_box.show_message(text)
	teaching.ask = func(options: Array, prompt: String) -> int:
		return await _message_box.show_message_with_choices(prompt, options, options.size())
	return teaching

func _choose_party_member(item_id: StringName) -> int:
	var scene: PackedScene = load(PARTY_SCREEN)
	if scene == null:
		return -1
	_busy = true
	var result: Variant = await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.selection_mode = true
		instance.filter_item = item_id
	)
	_busy = false
	return int(result) if result != null else -1

## Give an item to a party member through [HeldItemHandling].
func _on_give(item_id: StringName) -> void:
	var index: int = await _choose_party_member(&"")
	if index < 0:
		_return_focus()
		return
	var pkmn: Pokemon = GameState.party.get_member(index)
	if pkmn == null:
		_return_focus()
		return
	_busy = true
	await _held_items().give(pkmn, item_id)
	_busy = false
	refresh()
	_return_focus()

## Route held item messages through the bag's message window.
func _held_items() -> HeldItemHandling:
	var handling: HeldItemHandling = HeldItemHandling.new()
	handling.narrate = func(text: String) -> void:
		await _message_box.show_message(text)
	handling.ask = func(options: Array, prompt: String) -> int:
		return await _message_box.show_message_with_choices(prompt, options, options.size())
	handling.compose = func(mail_id: StringName) -> String:
		return await FieldMail.compose(mail_id)
	return handling

func _on_toss(item_id: StringName) -> void:
	GameState.bag.remove_item(item_id, GameState.bag.quantity_of(item_id))
	refresh()
	_return_focus()

## Restore focus after an action, returning to tabs if the list is empty.
func _return_focus() -> void:
	if not is_inside_tree():
		return
	if _item_list.item_count == 0:
		_focus_pocket.call_deferred()
		return
	_item_list.grab_focus.call_deferred()
	_update_hint.call_deferred()
