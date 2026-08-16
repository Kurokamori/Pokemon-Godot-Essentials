class_name IntroScreen
extends GameScreen
## The opening scene of each game where the player talks to the professor and sets up their game.

## Emitted by a chooser entry, or with `-1` when the player backs out of it.
signal character_chosen(index: int)

const SEQUENCE_PATH: String = "res://data/intro.tres"
const NAME_ENTRY_SCENE: String = "res://scenes/ui/name_entry_screen.tscn"

## Seconds a character takes to fade in or out.
const ACTOR_FADE_SECONDS: float = 0.35
## Seconds held between beats of the scene.
const BEAT_SECONDS: float = 0.25

## The opening to play. Left unset, the screen loads [constant SEQUENCE_PATH].
@export var sequence: IntroSequenceData = null

@onready var _background: TextureRect = %Background
@onready var _base: TextureRect = %Base
@onready var _actor: TextureRect = %Actor
@onready var _message_box: MessageBox = %MessageBox
@onready var _chooser: Control = %CharacterChooser
@onready var _chooser_prompt: Label = %ChooserPrompt
@onready var _chooser_name: Label = %ChooserName
@onready var _chooser_list: HBoxContainer = %ChooserList

## Answers gathered as the scene runs.
var _character: PlayerMetadataData = null
var _player_name: String = ""
var _rival_name: String = ""
## Buttons in the character chooser, one per selectable record.
var _chooser_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	closes_on_cancel = false
	_chooser.visible = false
	if sequence == null:
		sequence = _load_sequence()
	_apply_scenery()
	_play()

## Loads the configured opening, falling back to built-in defaults
func _load_sequence() -> IntroSequenceData:
	if ResourceLoader.exists(SEQUENCE_PATH):
		var loaded: IntroSequenceData = ResourceLoader.load(
			SEQUENCE_PATH, "", ResourceLoader.CACHE_MODE_REUSE
		) as IntroSequenceData
		if loaded != null:
			return loaded
	push_warning("IntroScreen: %s not found, using built-in defaults." % SEQUENCE_PATH)
	return IntroSequenceData.new()

func _apply_scenery() -> void:
	_background.texture = _picture(sequence.background_picture)
	_base.texture = _picture(sequence.base_picture)
	_base.visible = _base.texture != null
	_actor.modulate.a = 0.0
	if not sequence.music.is_empty():
		AudioManager.play_bgm(sequence.music)

## The whole opening, in the order it happens.
func _play() -> void:
	await _show_actor(sequence.professor_picture)
	await _speak(sequence.greeting_lines)

	if not sequence.demo_pokemon_picture.is_empty():
		await _show_actor(sequence.demo_pokemon_picture)
		if not sequence.demo_pokemon_species.is_empty():
			AudioManager.play_cry(sequence.demo_pokemon_species)
	await _speak(sequence.world_lines)
	await _show_actor(sequence.professor_picture)

	await _speak(sequence.ask_character_lines)
	_character = await _choose_character()
	if _character == null:
		close(false)
		return

	await _show_actor(_character.intro_picture, _character.chooser_texture())
	await _speak(sequence.ask_name_lines)
	_player_name = await _ask_name(
		sequence.player_name_prompt,
		_default_player_name(),
		GameSettings.data.max_player_name_size,
		_character.suggested_names,
		_actor.texture,
	)
	await _speak(sequence.confirm_name_lines)

	if not sequence.rival_picture.is_empty():
		await _show_actor(sequence.rival_picture)
	else:
		await _show_actor(sequence.professor_picture)
	await _speak(sequence.ask_rival_lines)
	_rival_name = await _ask_name(
		sequence.rival_name_prompt,
		sequence.default_rival_name,
		GameSettings.data.max_player_name_size,
		sequence.rival_name_suggestions,
		_picture(sequence.rival_picture),
	)
	await _speak(sequence.confirm_rival_lines)

	await _show_actor(_character.intro_picture, _character.chooser_texture())
	await _speak(sequence.farewell_lines)

	await _begin_session()
	close(true)

## Speaks [param lines] one after another, skipping empty ones
func _speak(lines: Array[String]) -> void:
	for line: String in lines:
		if line.strip_edges().is_empty():
			continue
		await _message_box.show_message(sequence.fill(line, _player_name, _rival_name))

## Cross-fades the character on stage to [param picture_name], or to [param override] when the caller already has the texture in hand.
func _show_actor(picture_name: String, override: Texture2D = null) -> void:
	var texture: Texture2D = override if override != null else _picture(picture_name)
	if texture == _actor.texture and _actor.modulate.a > 0.0:
		return
	if _actor.modulate.a > 0.0:
		await _fade_actor(0.0)
	_actor.texture = texture
	if texture == null:
		return
	_stand_actor(texture.get_size())
	await _fade_actor(1.0)
	await get_tree().create_timer(BEAT_SECONDS).timeout

## Sizes the actor to its art and plants it on the standing line, so pictures of different heights all have their feet in the same place.
func _stand_actor(art_size: Vector2) -> void:
	_actor.offset_left = -art_size.x * 0.5
	_actor.offset_right = art_size.x * 0.5
	_actor.offset_top = -art_size.y
	_actor.offset_bottom = 0.0

func _fade_actor(target: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_actor, "modulate:a", target, ACTOR_FADE_SECONDS)
	await tween.finished

func _picture(picture_name: String) -> Texture2D:
	if picture_name.is_empty():
		return null
	return Assets.texture(AssetIndex.CATEGORY_PICTURES, picture_name)

## Character records the chooser offers, in the order the sequence lists them. 
## An empty list in the sequence means every character the project defines.
func _selectable_records() -> Array[PlayerMetadataData]:
	var records: Array[PlayerMetadataData] = []
	var ids: Array[StringName] = sequence.selectable_characters
	if ids.is_empty():
		ids = Database.get_ids(Database.CATEGORY_PLAYER_METADATA)
	for character_id: StringName in ids:
		var record: PlayerMetadataData = Database.get_record(
			Database.CATEGORY_PLAYER_METADATA, character_id
		) as PlayerMetadataData
		if record != null:
			records.append(record)
	return records

## Shows the selectable characters and waits for one to be picked. 
## Returns `null` when the player backs out.
func _choose_character() -> PlayerMetadataData:
	var records: Array[PlayerMetadataData] = _selectable_records()
	if records.is_empty():
		push_error("IntroScreen: no player characters to choose from.")
		return null
	if records.size() == 1:
		return records[0]

	_chooser_prompt.text = sequence.character_prompt
	_build_chooser(records)
	_chooser.visible = true
	_chooser_buttons[0].grab_focus()
	var chosen: int = await character_chosen
	_chooser.visible = false
	_clear_chooser()
	if chosen < 0 or chosen >= records.size():
		return null
	return records[chosen]

## Fills the chooser with one entry per character. 
## The entries are built here because how many there are depends on the project's data
func _build_chooser(records: Array[PlayerMetadataData]) -> void:
	_clear_chooser()
	for index: int in range(records.size()):
		var record: PlayerMetadataData = records[index]
		var button: Button = Button.new()
		button.name = "Character%d" % index
		button.theme_type_variation = UIThemeBuilder.MENU_ENTRY
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(96, 150)
		button.icon = record.chooser_texture()
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_character_chosen.bind(index))
		button.focus_entered.connect(_on_character_focused.bind(record))
		_chooser_list.add_child(button)
		_chooser_buttons.append(button)
	_chooser_name.text = records[0].chooser_name()

func _clear_chooser() -> void:
	for button: Button in _chooser_buttons:
		button.queue_free()
	_chooser_buttons.clear()

func _on_character_focused(record: PlayerMetadataData) -> void:
	_chooser_name.text = record.chooser_name()
	play_select()

func _on_character_chosen(index: int) -> void:
	play_confirm()
	character_chosen.emit(index)

## Pushes the naming keyboard and returns what the player entered
## falling back to [param fallback] when they leave it blank or back out.
func _ask_name(prompt: String, fallback: String, max_length: int, suggestions: Array[String], portrait: Texture2D) -> String:
	var scene: PackedScene = load(NAME_ENTRY_SCENE)
	if scene == null:
		push_error("IntroScreen: %s could not be loaded." % NAME_ENTRY_SCENE)
		return fallback
	var entered: Variant = await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(prompt, fallback, max_length, suggestions, portrait)
	)
	var chosen: String = String(entered) if entered != null else ""
	return chosen if not chosen.strip_edges().is_empty() else fallback

## First suggestion the chosen character offers, or the sequence's default.
func _default_player_name() -> String:
	if _character != null and not _character.suggested_names.is_empty():
		return _character.suggested_names[0]
	return sequence.default_player_name

## Creates the session the answers describe, and hands over the starting kit.
func _begin_session() -> void:
	GameState.start_new_game(_player_name, _character.gender, _character.player_id)
	GameState.set_variable(sequence.rival_name_variable, _rival_name)
	await _give_starting_kit()

## The starter is handed over through [PokemonReceipt]
func _give_starting_kit() -> void:
	if not sequence.starter_species.is_empty() and Database.species(sequence.starter_species) != null:
		var receipt: PokemonReceipt = PokemonReceipt.new()
		receipt.narrate = func(text: String) -> void:
			await _message_box.show_message(text)
		receipt.ask = func(options: Array) -> int:
# Cancelling a yes/no question means no, which is the second option.
			return await _message_box.show_choices(options, 2)
		await receipt.give_species(sequence.starter_species, sequence.starter_level)
	for item_id: StringName in sequence.starting_items:
		GameState.bag.add_item(item_id, sequence.starting_items[item_id])
	GameState.player.has_running_shoes = sequence.gives_running_shoes

## Cancelling is only offered while the chooser is up
func _unhandled_input(event: InputEvent) -> void:
	if not _chooser.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		character_chosen.emit(-1)
