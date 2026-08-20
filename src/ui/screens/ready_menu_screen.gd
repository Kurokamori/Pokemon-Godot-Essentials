class_name ReadyMenuScreen
extends GameScreen
## Register menu -- hidden moves and registered items

const SCENE_PATH: String = "res://scenes/ui/screens/ready_menu_screen.tscn"
const ENTRY_SCENE: PackedScene = preload("res://scenes/ui/ready_menu_entry.tscn")

const EMPTY_MESSAGE: String = "An item in the Bag can be registered to this key for instant use."

@onready var _entry_list: VBoxContainer = %ReadyEntryList
@onready var _empty_label: Label = %ReadyEmptyLabel
@onready var _caption: Label = %ReadyCaption
@onready var _message_box: MessageBox = %MessageBox

## Set `true` while a question owns the input
var _busy: bool = false



func _ready() -> void:
	super._ready()
	await _build()

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	super._unhandled_input(event)

static func has_anything() -> bool:
	if not GameState.bag.registered_in_bag().is_empty():
		return true
	return not (await usable_moves()).is_empty()

## Every hidden move the party could use here, as `[move_id, Pokemon]` pairs.
static func usable_moves() -> Array:
	var found: Array = []
	if GameState == null or GameState.party == null:
		return found
	var handler: HiddenMoves = HiddenMoves.new()
	for pkmn: Pokemon in GameState.party.members:
		if pkmn.is_egg():
			continue
		for move_id: StringName in HiddenMoves.known_by(pkmn):
			if _already_offered(found, move_id):
				continue
			if not await handler.can_use(move_id, pkmn, false):
				continue
			found.append([move_id, pkmn])
	return found

# === Internals ===

## Returns `true` when [param move_id] is already on the list. 
static func _already_offered(found: Array, move_id: StringName) -> bool:
	for entry: Array in found:
		if entry[0] == move_id:
			return true
	return false

func _build() -> void:
	for child: Node in _entry_list.get_children():
		child.queue_free()
	var moves: Array = await usable_moves()
	var items: Array[StringName] = GameState.bag.registered_in_bag()
	_empty_label.visible = moves.is_empty() and items.is_empty()
	_empty_label.text = Loc.line(EMPTY_MESSAGE)
	_caption.text = ""

	var first: Button = null
	for entry: Array in moves:
		var button: Button = _add_entry(
			HiddenMoves.move_name(entry[0]), _pokemon_icon(entry[1]))
		button.pressed.connect(_on_move_chosen.bind(entry[0], entry[1]))
		button.focus_entered.connect(_on_focused.bind(
			Loc.line("{pokemon} can use this.", {"pokemon": entry[1].display_name()})))
		if first == null:
			first = button
	for item_id: StringName in items:
		var record: ItemData = Database.item(item_id)
		if record == null:
			continue
		var button: Button = _add_entry(record.get_translated_name(), Assets.item_icon(item_id))
		button.pressed.connect(_on_item_chosen.bind(item_id))
		button.focus_entered.connect(_on_focused.bind(record.get_translated_description()))
		if first == null:
			first = button
	if first != null:
		first.grab_focus.call_deferred()

func _add_entry(label: String, icon: Texture2D) -> Button:
	var entry: Button = ENTRY_SCENE.instantiate()
	_entry_list.add_child(entry)
	entry.bind(label, icon)
	return entry

func _on_focused(caption: String) -> void:
	play_select()
	_caption.text = caption

## A move needs the player to agree before the menus come down
func _on_move_chosen(move_id: StringName, user: Pokemon) -> void:
	play_confirm()
	_busy = true
	var agreed: bool = await _talker().confirm_use(move_id, user)
	_busy = false
	if not agreed:
		await _build()
		return
	close(HiddenMoves.Request.new(move_id, user))

func _on_item_chosen(item_id: StringName) -> void:
	play_confirm()
	close(item_id)

## A [HiddenMoves] that talks through this screen's own window
func _talker() -> HiddenMoves:
	var handler: HiddenMoves = HiddenMoves.new()
	handler.narrate = func(text: String) -> void:
		await _message_box.show_message(text)
	handler.confirm = func(question: String) -> bool:
		return await _message_box.show_message_with_choices(question, ["Yes", "No"], 2) == 0
	return handler

## The party icon of the Pokemon that would use a move.
func _pokemon_icon(pkmn: Pokemon) -> Texture2D:
	if pkmn == null:
		return null
	var sheet: Texture2D = pkmn.icon()
	if sheet == null:
		return null
	var frames: Array[AtlasTexture] = Assets.sprite_sheet_frames(sheet)
	return frames[0] if not frames.is_empty() else sheet
