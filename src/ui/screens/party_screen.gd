extends GameScreen
## The party screen. Doubles as a selection screen.

const SUMMARY_SCREEN: String = "res://scenes/ui/summary_screen.tscn"
const BAG_SCREEN: String = "res://scenes/ui/bag_screen.tscn"
const PARTY_SLOT_SCENE: PackedScene = preload("res://scenes/ui/party_slot.tscn")

## When set, choosing a Pokemon closes the screen with its index instead of opening the action menu.
## The row an entry on this screen is drawn as.
@export var entry_scene: PackedScene = preload("res://scenes/ui/menu_entry_button.tscn")

@export var selection_mode: bool = false

## When set, only Pokemon this item can be used on are selectable.
@export var filter_item: StringName = &""

@export var unavailable_slots: Array[int] = []

@onready var _slot_list: GridContainer = %SlotList
@onready var _prompt_label: Label = %PromptLabel
@onready var _action_panel: PanelContainer = %ActionPanel
@onready var _action_list: VBoxContainer = %ActionList
@onready var _message_box: MessageBox = %MessageBox

var _slots: Array[PartySlot] = []
var _selected_index: int = -1

## Index held while the player picks a second Pokemon to swap with.
var _swap_index: int = -1

## Set `true` while a message or a nested screen owns the input
var _busy: bool = false


func _ready() -> void:
	super._ready()
	_action_panel.visible = false
	_prompt_label.text = "Choose a Pokemon." if selection_mode else "Your Pokemon."
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	super._unhandled_input(event)

func refresh() -> void:
	for slot: PartySlot in _slots:
		slot.queue_free()
	_slots.clear()
	var maximum: int = GameSettings.data.max_party_size
	var first_available: PartySlot = null
	for index: int in range(maximum):
		var slot: PartySlot = PARTY_SLOT_SCENE.instantiate()
		_slot_list.add_child(slot)
		slot.bind(GameState.party.get_member(index))
		if unavailable_slots.has(index):
			slot.mark_unavailable("OUT")
		slot.pressed.connect(_on_slot_pressed.bind(index))
		_slots.append(slot)
		if first_available == null and not slot.disabled:
			first_available = slot
	if first_available != null:
		first_available.grab_focus()
	elif not _slots.is_empty():
		_slots[0].grab_focus()

func _on_slot_pressed(index: int) -> void:
	var pkmn: Pokemon = GameState.party.get_member(index)
	if pkmn == null:
		return
	play_confirm()
	if _swap_index >= 0:
		GameState.party.swap(_swap_index, index)
		_swap_index = -1
		refresh()
		return
	if selection_mode:
		if not filter_item.is_empty():
			var item: ItemData = Database.item(filter_item)
			if item != null and not ItemUsage.can_use_on(item, pkmn):
				_prompt_label.text = "It would have no effect."
				return
		close(index)
		return
	_selected_index = index
	_show_actions(pkmn)

func _show_actions(pkmn: Pokemon) -> void:
	for child: Node in _action_list.get_children():
		child.queue_free()
	var actions: Array = [
		["Summary", _on_summary],
	]
	for move_id: StringName in HiddenMoves.known_by(pkmn):
		actions.push_back([HiddenMoves.move_name(move_id), _on_field_move.bind(move_id)])
	actions.append(["Switch", _on_switch])
	if _may_choose_as_follower(pkmn):
		var walking: bool = PokemonFollowerSettings.chosen_index() == _selected_index
		actions.append([("Stop Walking" if walking else "Walk With"), _on_walk_with])
	if _has_anything_usable_on(pkmn):
		actions.append(["Use Item", _on_use_item])
	if not GameState.bag.is_empty() and pkmn.mail == null and not pkmn.is_egg():
		actions.append(["Give Item", _on_give_item])
	if pkmn.mail != null:
		actions.append(["Mail", _on_mail])
	elif not pkmn.held_item.is_empty():
		actions.append(["Take Item", _on_take_item])
	actions.append(["Cancel", _hide_actions])

	var first: Button = null
	for action: Array in actions:
		var button: Button = entry_scene.instantiate() as Button
		button.text = action[0]
		button.pressed.connect(action[1])
		button.focus_entered.connect(play_select)
		_action_list.add_child(button)
		if first == null:
			first = button
	_action_panel.visible = true
	if first != null:
		first.grab_focus()

func _hide_actions() -> void:
	_action_panel.visible = false
	if _selected_index >= 0 and _selected_index < _slots.size():
		_slots[_selected_index].grab_focus()

func _on_summary() -> void:
	var scene: PackedScene = load(SUMMARY_SCREEN)
	if scene == null:
		return
	_action_panel.visible = false
	await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.party_index = _selected_index
	)
	refresh()

## A hidden move chosen out of the menu
func _on_field_move(move_id: StringName) -> void:
	var pkmn: Pokemon = GameState.party.get_member(_selected_index)
	if pkmn == null:
		return
	_action_panel.visible = false
	var moves: HiddenMoves = _hidden_moves()
	_busy = true
	var allowed: bool = await moves.can_use(move_id, pkmn, true)
	var agreed: bool = allowed and await moves.confirm_use(move_id, pkmn)
	_busy = false
	if not agreed:
		_restore_focus()
		return
	close(HiddenMoves.Request.new(move_id, pkmn))

func _hidden_moves() -> HiddenMoves:
	var moves: HiddenMoves = HiddenMoves.new()
	moves.narrate = func(text: String) -> void:
		await _message_box.show_message(text)
	moves.confirm = func(question: String) -> bool:
		return await _message_box.show_message_with_choices(question, ["Yes", "No"], 2) == 0
	return moves

func _on_switch() -> void:
	_swap_index = _selected_index
	_action_panel.visible = false
	_prompt_label.text = "Move to where?"

func _may_choose_as_follower(pkmn: Pokemon) -> bool:
	if PokemonFollowerSettings.effective_mode() != FollowerMode.Mode.CHOSEN:
		return false
	if PokemonFollowerSettings.chosen_index() == _selected_index:
		return true
	return PokemonFollowerSettings.may_walk(pkmn)

func _on_walk_with() -> void:
	play_confirm()
	FieldEffects.set_chosen_follower(_selected_index)
	_hide_actions()

func _has_anything_usable_on(pkmn: Pokemon) -> bool:
	for item_id: StringName in GameState.bag.all_item_ids():
		var record: ItemData = Database.item(item_id)
		if record != null and ItemUsage.can_use_on(record, pkmn):
			return true
	return false

## Uses a bag item on the Pokemon whose menu is open
func _on_use_item() -> void:
	var pkmn: Pokemon = GameState.party.get_member(_selected_index)
	if pkmn == null:
		return
	_action_panel.visible = false
	var item_id: StringName = await _choose_item(true, pkmn)
	if item_id.is_empty():
		_restore_focus()
		return
	var record: ItemData = Database.item(item_id)
	if record == null:
		_restore_focus()
		return
	_busy = true
	var worked: bool = await ItemUsage.use_on_pokemon(record, pkmn, -1, _lesson())
	if worked:
		if record.consumable:
			GameState.bag.remove_item(item_id, 1)
	else:
		await _message_box.show_message("It won't have any effect.")
	_busy = false
	refresh()
	_restore_focus()

func _on_give_item() -> void:
	var pkmn: Pokemon = GameState.party.get_member(_selected_index)
	if pkmn == null:
		return
	_action_panel.visible = false
	var item_id: StringName = await _choose_item(false, pkmn)
	if item_id.is_empty():
		_restore_focus()
		return
	_busy = true
	await _held_items().give(pkmn, item_id)
	_busy = false
	refresh()
	_restore_focus()

## Opens the bag as a selector and returns what the player picked
func _choose_item(usable_only: bool, pkmn: Pokemon) -> StringName:
	var scene: PackedScene = load(BAG_SCREEN)
	if scene == null:
		push_warning("PartyScreen: %s is missing." % BAG_SCREEN)
		return &""
	_busy = true
	var chosen: Variant = await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.selection_mode = true
		if usable_only:
			instance.usable_on = pkmn
	)
	_busy = false
	return StringName(String(chosen)) if chosen != null else &""

## A [MoveLearning] that talks through this screen's own message window
func _lesson() -> MoveLearning:
	var teaching: MoveLearning = MoveLearning.new()
	teaching.narrate = func(text: String) -> void:
		await _message_box.show_message(text)
	teaching.ask = func(options: Array, prompt: String) -> int:
		return await _message_box.show_message_with_choices(prompt, options, options.size())
	return teaching

func _on_take_item() -> void:
	var pkmn: Pokemon = GameState.party.get_member(_selected_index)
	if pkmn == null or pkmn.held_item.is_empty():
		return
	_action_panel.visible = false
	_busy = true
	await _held_items().take(pkmn)
	_busy = false
	refresh()
	_restore_focus()

func _on_mail() -> void:
	var pkmn: Pokemon = GameState.party.get_member(_selected_index)
	if pkmn == null or pkmn.mail == null:
		return
	_action_panel.visible = false
	_busy = true
	var chosen: int = await _message_box.show_message_with_choices(
		"Do what with the mail?", ["Read", "Take", "Cancel"], 3
	)
	_busy = false
	match chosen:
		0:
			_busy = true
			await FieldMail.read(pkmn.mail)
			_busy = false
			_restore_focus()
		1:
			await _on_take_item()
		_:
			_restore_focus()

## A [HeldItemHandling] that talks through this screen's own message window
func _held_items() -> HeldItemHandling:
	var handling: HeldItemHandling = HeldItemHandling.new()
	handling.narrate = func(text: String) -> void:
		await _message_box.show_message(text)
	handling.ask = func(options: Array, prompt: String) -> int:
		return await _message_box.show_message_with_choices(prompt, options, options.size())
	handling.compose = func(item_id: StringName) -> String:
		return await FieldMail.compose(item_id)
	return handling

func _restore_focus() -> void:
	if not is_inside_tree():
		return
	if _selected_index >= 0 and _selected_index < _slots.size():
		_slots[_selected_index].grab_focus.call_deferred()
