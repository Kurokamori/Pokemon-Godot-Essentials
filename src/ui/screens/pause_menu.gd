extends GameScreen
## The menu opened with the menu button in the overworld.

const PARTY_SCREEN: String = "res://scenes/ui/party_screen.tscn"
const BAG_SCREEN: String = "res://scenes/ui/bag_screen.tscn"
const POKEDEX_SCREEN: String = "res://scenes/ui/pokedex_screen.tscn"
const STORAGE_SCREEN: String = "res://scenes/ui/storage_screen.tscn"
const SAVE_SCREEN: String = "res://scenes/ui/save_screen.tscn"
const OPTIONS_SCREEN: String = "res://scenes/ui/options_screen.tscn"
const REPLAY_SCREEN: String = ReplayScreen.SCENE_PATH

@onready var _entry_list: VBoxContainer = %EntryList
@onready var _player_name: Label = %PlayerNameLabel
@onready var _play_time: Label = %PlayTimeLabel


func _ready() -> void:
	super._ready()
	if GameState.player != null:
		_player_name.text = GameState.player.name
		_play_time.text = GameState.player.formatted_play_time()
	_build_entries()

## Rebuilds entries so unavailable items stay hidden.
func _build_entries() -> void:
	for child: Node in _entry_list.get_children():
		child.queue_free()
	var entries: Array = []
	if GameState.player != null and GameState.player.has_pokedex:
		entries.append(["Pokedex", _open_pokedex])
		
	if not GameState.party.is_empty():
		entries.append(["Pokemon", _open_party])
		
	if not GameState.bag.is_empty():
		entries.append(["Bag", _open_bag])
		
	if _has_pokegear():
		entries.append(["Pokégear", _open_pokegear])
		
	elif _has_town_map():
		entries.append(["Town Map", _open_town_map])
	if not BattleRecording.list_saved().is_empty():
		entries.append(["Replays", _open_replays])
		
	if GameState.player != null:
		entries.append([GameState.player.name, _open_trainer_card])
	entries.append(["Save", _open_save])
	entries.append(["Options", _open_options])
	entries.append(["Controls", _open_controls])
	entries.append(["Close", func() -> void: close(null)])

	var first: Button = null
	for entry: Array in entries:
		var button: Button = Button.new()
		button.text = entry[0]
		button.theme_type_variation = UIThemeBuilder.MENU_ENTRY
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(entry[1])
		button.focus_entered.connect(play_select)
		_entry_list.add_child(button)
		if first == null:
			first = button
	if first != null:
		first.grab_focus()

func _open_screen(path: String) -> Variant:
	var scene: PackedScene = load(path)
	if scene == null:
		push_warning("PauseMenu: %s is missing." % path)
		return null
	play_confirm()
	return await SceneRouter.push_screen(scene)

## Closes the menu after a field move so it is used on the overworld.
func _open_party() -> void:
	var chosen: Variant = await _open_screen(PARTY_SCREEN)
	if chosen is HiddenMoves.Request:
		var request: HiddenMoves.Request = chosen as HiddenMoves.Request
		close(null)
		await HiddenMoves.for_field().use(request.move, request.user)
		return
	_build_entries()

func _open_bag() -> void:
	await _open_screen(BAG_SCREEN)
	_build_entries()

func _open_pokedex() -> void:
	await _open_screen(POKEDEX_SCREEN)
	_build_entries()

func _has_town_map() -> bool:
	var item_id: StringName = GameSettings.data.town_map_item
	return not item_id.is_empty() and GameState.bag.has_item(item_id)

func _has_pokegear() -> bool:
	return GameState.player != null and GameState.player.has_pokegear

## Closes the menu when Pokegear starts a flight to another map.
func _open_pokegear() -> void:
	play_confirm()
	var scene: PackedScene = load(PokegearScreen.SCENE_PATH)
	if scene == null:
		push_warning("PauseMenu: %s is missing." % PokegearScreen.SCENE_PATH)
		return
	var destination: Variant = await SceneRouter.push_screen(scene)
	if destination is TownMapPoint:
		close(null)
		await FieldMoves.fly_to(destination as TownMapPoint)
		return
	_build_entries()

## Opens the player's map and closes the menu if Fly changes the overworld.
func _open_town_map() -> void:
	play_confirm()
	var scene: PackedScene = load(TownMapScreen.SCENE_PATH)
	if scene == null:
		push_warning("PauseMenu: %s is missing." % TownMapScreen.SCENE_PATH)
		return
	var destination: Variant = await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(TownMapScreen.Mode.PLAYER)
	)
	if destination is TownMapPoint:
		close(null)
		await FieldMoves.fly_to(destination as TownMapPoint)
		return
	_build_entries()

func _open_trainer_card() -> void:
	await _open_screen(TrainerCardScreen.SCENE_PATH)
	_build_entries()

func _open_replays() -> void:
	await _open_screen(REPLAY_SCREEN)
	_build_entries()

func _open_save() -> void:
	await _open_screen(SAVE_SCREEN)
	_build_entries()

func _open_options() -> void:
	await _open_screen(OPTIONS_SCREEN)
	_build_entries()

## Opens the separate controls screen used for key rebinding.
func _open_controls() -> void:
	await _open_screen(ControlsScreen.SCENE_PATH)
	_build_entries()
