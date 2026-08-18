class_name Overworld
extends Node
## The playable field scene and its map, menus and battles.

const SCENE_PATH: String = "res://scenes/field/overworld.tscn"
const BATTLE_SCENE: String = "res://scenes/battle/battle_scene.tscn"
const PAUSE_MENU_SCENE: String = "res://scenes/ui/pause_menu.tscn"

## The active overworld, used by field helpers that start battles.
static var current: Overworld = null

## A map supplied before entering the tree, used when running one map directly.
var startup_map: GameMap = null

@onready var field: MapController = %Field
@onready var message_box: MessageBox = %MessageBox
@onready var _screen_effects: ScreenEffects = %ScreenEffects
@onready var _picture_layer: PictureLayer = %PictureLayer
@onready var _map_backdrop: MapBackdrop = %MapBackdrop
@onready var _signpost: LocationSignpost = %LocationSignpost

var _battle_running: bool = false

## How the next wild Pokemon was encountered, for the battle intro location.
var _last_encounter_type: StringName = &""

## The last battle recording, if one exists.
var _last_recording: BattleRecording = null

## A field item waiting for the menus to close.
var _pending_field_item: StringName = &""

## `true` while a finished Safari trip or contest is closing.
var _closing_session: bool = false

## `true` while an incoming phone call is being handled.
var _taking_call: bool = false

## Whether the previous map was outdoors, used to mark cave entrances.
var _came_from_outdoors: bool = true

## The last announced place name.
var _last_place_name: String = ""

func _ready() -> void:
	current = self
	GameState.step_taken.connect(_on_step_taken)
	GameState.repel_wore_off.connect(_on_repel_wore_off)
	field.encounter_triggered.connect(_on_encounter_triggered)
	field.message_requested.connect(_on_message_requested)
	field.choices_requested.connect(_on_choices_requested)
	field.map_loaded.connect(_on_map_loaded)
	SceneRouter.screen_changed.connect(_on_screen_changed)
	_enter_starting_position()
	FieldEffects.refresh_weather()
	FieldEffects.refresh_tone()
	_screen_effects.refresh_darkness()
	_screen_effects.refresh_day_night(0.0)

## Advances the Pokegear clock while the player is free to walk.
func _process(delta: float) -> void:
	if _taking_call or not _phone_is_listening():
		return
	if GameState.phone.tick(delta):
		_take_incoming_call()

func _phone_is_listening() -> bool:
	if GameState.player == null or not GameState.player.has_pokegear:
		return false
	if GameState.phone == null or _battle_running or _closing_session:
		return false
	if SceneRouter.has_overlay() or message_box.is_showing():
		return false
	return not field.is_busy()

## Handles an incoming phone call.
func _take_incoming_call() -> void:
	_taking_call = true
	field.player.accepts_input = false
	await PhoneCall.make_incoming()
	field.player.accepts_input = true
	_taking_call = false

## Returns the weather and screen tone layer.
func screen_effects() -> ScreenEffects:
	return _screen_effects

## Returns the picture layer used by map events.
func picture_layer() -> PictureLayer:
	return _picture_layer

## Returns the map panorama and fog layer.
func map_backdrop() -> MapBackdrop:
	return _map_backdrop

## Refreshes field effects and applies the map's tileset backdrop.
func _on_map_loaded(map: GameMap) -> void:
	FieldEffects.refresh_weather()
	FieldEffects.refresh_tone()
	_map_backdrop.apply_tileset(_tileset_of(map))
	FieldItemEffects.settle_bicycle_for_map()
	_screen_effects.refresh_darkness()
	_screen_effects.refresh_day_night(0.0)
	_mark_escape_point_for(map)
	_on_place_reached(map)
	await _end_safari_trip_outside_the_zone()

## Ends a Safari trip after the player leaves the zone.
func _end_safari_trip_outside_the_zone() -> void:
	var session: SafariSession = GameState.safari
	if session == null or not session.active:
		return
	if Field.in_safari_zone():
		return
	session.return_point = null
	session.finish()
	await _close_finished_session()

## Updates systems that run once when the player reaches a new place.
func _on_place_reached(map: GameMap) -> void:
	var here: String = _place_name_of(map)
	if not here.is_empty() and here == _last_place_name:
		return
	_last_place_name = here
	RoamingPokemon.roam_all()
	_announce_place(map, here)

## Announces the translated place name when the map requests it.
func _announce_place(map: GameMap, place_name: String) -> void:
	if place_name.is_empty() or map == null:
		return
	var metadata: MapMetadataData = Database.map_metadata(map.map_id)
	if metadata == null or not metadata.announce_location:
		return
	_signpost.show_place(metadata.get_translated_name())

## Returns the source-language place name used to compare arrivals.
func _place_name_of(map: GameMap) -> String:
	var metadata: MapMetadataData = Database.map_metadata(map.map_id) if map != null else null
	if metadata != null and not metadata.display_name.is_empty():
		return metadata.display_name
	return ""

## Records an escape point on entry and clears it outdoors.
func _mark_escape_point_for(map: GameMap) -> void:
	var outdoors: bool = GameState.is_outdoors()
	if outdoors:
		GameState.clear_escape_point()
	elif _came_from_outdoors and map != null:
		GameState.set_escape_point_at(
			map.map_id, field.player.tile_position, int(field.player.facing))
	_came_from_outdoors = outdoors

## Returns the tileset used by [param map], or `null` if it has none.
func _tileset_of(map: GameMap) -> TilesetData:
	if map == null:
		return null
	var tileset_id: int = map.source_tileset_id()
	return Database.tileset(tileset_id) if tileset_id > 0 else null

func _exit_tree() -> void:
	if current == self:
		current = null

func _unhandled_input(event: InputEvent) -> void:
	if _battle_running or message_box.is_showing():
		return
	if field.is_busy():
		return
	if event.is_action_pressed("game_menu"):
		get_viewport().set_input_as_handled()
		_open_pause_menu()
		return
	if event.is_action_pressed("game_special"):
		get_viewport().set_input_as_handled()
		_open_ready_menu()
		return
	if event.is_action_pressed("game_debug") and GameSettings.data.debug_mode:
		get_viewport().set_input_as_handled()
		_open_debug_menu()

## Places the player at the session position or the configured home.
func _enter_starting_position() -> void:
	if startup_map != null:
		var spawn: SpawnPoint = startup_map.default_spawn()
		var cell: Vector2i = spawn.cell() if spawn != null else Vector2i.ZERO
		var facing: int = int(spawn.facing) if spawn != null else GridCharacter.Direction.DOWN
		field.adopt_map(startup_map, cell, facing)
		startup_map = null
		return

	var map_id: int = GameState.map_id
	var position: Vector2i = GameState.map_position
	if map_id <= 0:
		var metadata: MetadataData = Database.metadata()
		if metadata != null and metadata.home.size() >= 3:
			map_id = metadata.home[0]
			position = Vector2i(metadata.home[1], metadata.home[2])
	if map_id <= 0:
		push_warning("Overworld: no starting map is configured.")
		return
	field.load_map_id(map_id, position, GameState.map_direction)

func _on_message_requested(text: String) -> void:
	# Hide the location sign while showing dialogue.
	_signpost.dismiss()
	await message_box.show_message(text)
	field.acknowledge_message()

func _on_choices_requested(
	prompt: String, options: Array, cancel_index: int, default_index: int
) -> void:
	var chosen: int = 0
	if prompt.is_empty():
		chosen = await message_box.show_choices(options, cancel_index, default_index)
	else:
		chosen = await message_box.show_message_with_choices(
			prompt, options, cancel_index, default_index
		)
	field.submit_choice(chosen)

func _on_encounter_triggered(wild: Array[Pokemon], encounter_type: StringName) -> void:
	if _battle_running or field.current_map == null or wild.is_empty():
		return
	_last_encounter_type = encounter_type
	if GameState.safari != null and GameState.safari.active:
		await start_safari_battle(wild[0])
		return
	if GameState.bug_contest != null and GameState.bug_contest.active:
		await start_bug_contest_battle(wild[0])
		return
	await start_wild_battle_against(wild)

## Queues [param item_id] until the menus close.
func request_field_item(item_id: StringName) -> void:
	_pending_field_item = item_id

func _on_screen_changed(screen: Node) -> void:
	if screen != null or _pending_field_item.is_empty():
		return
	var item_id: StringName = _pending_field_item
	_pending_field_item = &""
	await _use_field_item(item_id)

## Uses a queued field item and consumes it when successful.
func _use_field_item(item_id: StringName) -> void:
	var record: ItemData = Database.item(item_id)
	if record == null:
		return
	field.player.accepts_input = false
	var used: bool = await FieldItemEffects.for_field().use_in_field(item_id)
	field.player.accepts_input = true
	if used and record.consumable:
		GameState.bag.remove_item(item_id, 1)

## Runs a wild battle against a single Pokemon and returns how it ended.
func start_wild_battle(wild: Pokemon) -> BattlePresenter.Outcome:
	return await start_wild_battle_against([wild] as Array[Pokemon])

## Runs a wild battle and returns the player to the map.
## [param configure] can modify the battle before it starts.
func start_wild_battle_against(
	wild_pokemon: Array[Pokemon], per_side: int = 0, configure: Callable = Callable()
) -> BattlePresenter.Outcome:
	if wild_pokemon.is_empty():
		return BattlePresenter.Outcome.UNDECIDED
	_battle_running = true
	field.player.accepts_input = false
	AudioManager.push_bgm_position()
	var roamer: RoamingSpeciesData = _pending_roamer()
	var track: String = ""
	if roamer != null and not roamer.battle_bgm.is_empty():
		track = roamer.battle_bgm
	else:
		track = BattleAudio.wild_battle_bgm(GameState.map_id)
	if not track.is_empty():
		AudioManager.play_bgm(track, 1.0, 1.0, true)

	var battle: Battle = Battle.new()
	battle.setup_wild(GameState.party, wild_pokemon, 1 if roamer != null else per_side)
	battle.wild_pokemon_flees = roamer != null
	battle.victory_bgm = BattleAudio.wild_victory_bgm(GameState.map_id)
	battle.capture_me = BattleAudio.capture_me(GameState.map_id)
	if configure.is_valid():
		configure.call(battle)
	var met: Pokemon = wild_pokemon[0]
	var outcome: BattlePresenter.Outcome = await _run_battle(battle)
	if roamer != null:
		RoamingPokemon.on_battle_ended(roamer, outcome)
	await _after_battle(outcome)
	await PokeRadar.on_battle_ended(met.species, met.level(), outcome, _narrate())
	return outcome

## Returns a narrator for systems that speak through the field message box.
func _narrate() -> Callable:
	return func(text: String) -> void:
		await field.say(text)

## Takes the pending roamer from the session.
func _pending_roamer() -> RoamingSpeciesData:
	var id: StringName = GameState.pending_roamer
	GameState.pending_roamer = &""
	return Database.roaming_species(id) if not id.is_empty() else null

## Runs a Safari Zone encounter.
func start_safari_battle(wild: Pokemon) -> BattlePresenter.Outcome:
	if wild == null or GameState.safari == null or not GameState.safari.active:
		return BattlePresenter.Outcome.UNDECIDED
	_battle_running = true
	field.player.accepts_input = false
	AudioManager.push_bgm_position()
	var battle: Battle = Battle.new()
	battle.setup_safari(GameState.party, [wild] as Array[Pokemon], GameState.safari)
	var outcome: BattlePresenter.Outcome = await _run_battle(battle)
	await _after_battle(outcome)
	return outcome

## Runs a Bug-Catching Contest encounter.
func start_bug_contest_battle(wild: Pokemon) -> BattlePresenter.Outcome:
	if wild == null or GameState.bug_contest == null or not GameState.bug_contest.active:
		return BattlePresenter.Outcome.UNDECIDED
	_battle_running = true
	field.player.accepts_input = false
	AudioManager.push_bgm_position()
	var battle: Battle = Battle.new()
	battle.setup_bug_contest(GameState.party, [wild] as Array[Pokemon], GameState.bug_contest)
	var outcome: BattlePresenter.Outcome = await _run_battle(battle)
	await _after_battle(outcome)
	return outcome

## Runs a trainer battle against one trainer.
func start_trainer_battle(trainer: TrainerData) -> BattlePresenter.Outcome:
	return await start_trainer_battle_against([trainer] as Array[TrainerData])

## Runs a trainer battle. [param configure] can modify it before it starts.
func start_trainer_battle_against(
	trainers: Array[TrainerData], per_side: int = 0, configure: Callable = Callable()
) -> BattlePresenter.Outcome:
	if trainers.is_empty():
		return BattlePresenter.Outcome.UNDECIDED
	_battle_running = true
	field.player.accepts_input = false
	AudioManager.push_bgm_position()
	var track: String = BattleAudio.trainer_battle_bgm(trainers[0], GameState.map_id)
	if not track.is_empty():
		AudioManager.play_bgm(track, 1.0, 1.0, true)

	var battle: Battle = Battle.new()
	battle.setup_trainer(GameState.party, trainers, per_side)
	battle.victory_bgm = BattleAudio.trainer_victory_bgm(trainers[0], GameState.map_id)
	if configure.is_valid():
		configure.call(battle)
	var outcome: BattlePresenter.Outcome = await _run_battle(battle)
	await _after_battle(outcome)
	return outcome

## Returns the last battle recording, or `null` if none exists.
func last_recording() -> BattleRecording:
	return _last_recording

## Replays [param recording] without changing the game's RNG state.
func watch_recording(recording: BattleRecording) -> void:
	var scene: PackedScene = load(BATTLE_SCENE)
	if recording == null or scene == null:
		return
	var seed_before: int = RNG.get_seed()
	var state_before: int = RNG.get_state()
	var replay: Battle = recording.rebuild()
	await SceneRouter.fade_out()
	await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.battle = replay
	)
	RNG.set_seed(seed_before)
	RNG.set_state(state_before)
	recording.replaying = false
	await SceneRouter.fade_in()

func _run_battle(battle: Battle) -> BattlePresenter.Outcome:
	var scene: PackedScene = load(BATTLE_SCENE)
	var outcome: BattlePresenter.Outcome = BattlePresenter.Outcome.UNDECIDED
	# Record normal battles for replay.
	if battle.recording == null:
		battle.recording = BattleRecording.start(battle)
		_last_recording = battle.recording
	if scene == null:
		# Resolve the battle without a visual scene.
		add_child(battle)
		outcome = await battle.run()
		battle.queue_free()
		return outcome
	# Play the encounter transition and open the battle scene.
	await BattleIntro.play(BattleIntro.context_for(battle, _last_encounter_type))
	_last_encounter_type = &""
	var result: Variant = await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.battle = battle
	)
	outcome = int(result) as BattlePresenter.Outcome if result != null else BattlePresenter.Outcome.DRAW
	return outcome

func _after_battle(outcome: BattlePresenter.Outcome) -> void:
	AudioManager.pop_bgm_position()
	_battle_running = false
	field.player.accepts_input = true
	field.encounters.reset_step_count()
	GameState.steps_since_encounter = 0
	FieldEffects.refresh_pokemon_followers()
	await BattleTransition.open()
	await _run_after_battle_abilities()
	await _check_evolutions(outcome)
	if outcome == BattlePresenter.Outcome.PLAYER_LOST:
		await _handle_blackout()
		return
	await _close_finished_session()

## Runs abilities that trigger after battle.
func _run_after_battle_abilities() -> void:
	var tally: BattleTally = GameState.battle_tally
	var consumed: Array[StringName] = tally.items_consumed if tally != null else [] as Array[StringName]
	for message: String in AbilityAfterBattle.run(GameState.party, consumed):
		await field.say(message)

## Checks for evolutions after the battle.
func _check_evolutions(outcome: BattlePresenter.Outcome) -> void:
	var went_badly: bool = (
		outcome == BattlePresenter.Outcome.PLAYER_LOST
		or outcome == BattlePresenter.Outcome.DRAW
	)
	var tally: BattleTally = GameState.battle_tally
	GameState.battle_tally = null
	if went_badly and not GameSettings.data.check_evolution_after_all_battles:
		return
	await Evolutions.after_battle(tally)

func _on_step_taken() -> void:
	FieldSoot.take_step(field)
	await _apply_field_poison()
	await _hatch_ready_eggs()
	await _announce_ready_purify_sets()
	await _announce_opened_hearts()
	await _close_finished_session()

## Applies field poison while the player walks.
func _apply_field_poison() -> void:
	if _battle_running:
		return
	field.player.accepts_input = false
	var wiped_out: bool = await FieldPoison.take_step()
	field.player.accepts_input = true
	if wiped_out:
		await _handle_blackout()

## Announces a depleted Repel and offers another.
func _on_repel_wore_off() -> void:
	if _battle_running:
		return
	field.player.accepts_input = false
	await FieldItemEffects.for_field().offer_another_repel()
	field.player.accepts_input = true

## Hatches eggs that became ready on the last step.
func _hatch_ready_eggs() -> void:
	if _battle_running or GameState.hatching_eggs.is_empty():
		return
	var ready_eggs: Array[Pokemon] = GameState.take_hatching_eggs()
	field.player.accepts_input = false
	await EggHatching.hatch_all(ready_eggs)
	field.player.accepts_input = true

## Announces Shadow Pokemon ready for purification.
func _announce_ready_purify_sets() -> void:
	if _battle_running or GameState.purified_sets_ready.is_empty():
		return
	var ready_sets: Array[int] = GameState.take_ready_purify_sets()
	field.player.accepts_input = false
	for set_index: int in ready_sets:
		var shadow: Pokemon = GameState.purify_chamber.get_shadow(set_index)
		if shadow == null:
			continue
		await field.say(Loc.line(
			"Your {pokemon} in the Purify Chamber is ready for purification!",
			{"pokemon": shadow.display_name()}
		))
	field.player.accepts_input = true

## Announces heart stages opened by walking.
func _announce_opened_hearts() -> void:
	if _battle_running or GameState.opened_hearts.is_empty():
		return
	var opened: Array[Pokemon] = GameState.take_opened_hearts()
	field.player.accepts_input = false
	for pkmn: Pokemon in opened:
		if ShadowPokemon.is_ready_to_purify(pkmn):
			await field.say(Loc.line("{pokemon} is ready to open the door to its heart!",
				{"pokemon": pkmn.display_name()}))
		else:
			await field.say(Loc.line("The door to {pokemon}'s heart opened a little.",
				{"pokemon": pkmn.display_name()}))
	field.player.accepts_input = true

## Closes a Safari trip or contest that has run out of time or resources.
func _close_finished_session() -> void:
	if _battle_running or _closing_session:
		return
	var safari_over: bool = GameState.safari != null and not GameState.safari.active
	var contest_over: bool = GameState.bug_contest != null and not GameState.bug_contest.active
	if not safari_over and not contest_over:
		return
	_closing_session = true
	field.player.accepts_input = false
	var gate: SessionReturnPoint = null
	if safari_over:
		gate = GameState.safari.return_point
		await Field.end_safari_zone()
	else:
		gate = GameState.bug_contest.return_point
		await Field.end_bug_contest()
	if gate != null and gate.is_set():
		await gate.go_back()
	field.player.accepts_input = true
	_closing_session = false

## Sends the player back to their last healing spot after a blackout.
func _handle_blackout() -> void:
	GameState.stats.blacked_out_count += 1
	await message_box.show_message("You have no more Pokemon that can fight!\nYou scurried to a Pokemon Center...")
	GameState.party.heal_all()
	GameState.clear_escape_point()
	await warp_to_respawn()

## Warps the player to the last healing spot, if one is configured.
func warp_to_respawn() -> void:
	var destination: Array[int] = GameState.respawn_destination()
	if destination.size() < 3:
		return
	var facing: int = destination[3] if destination.size() >= 4 else GridCharacter.Direction.DOWN
	await field.warp_to_map_id(destination[0], Vector2i(destination[1], destination[2]), facing)

func _open_pause_menu() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE)
	if scene == null:
		return
	field.player.accepts_input = false
	await SceneRouter.push_screen(scene)
	field.player.accepts_input = true

## Opens the debug menu when debug mode is enabled.
func _open_debug_menu() -> void:
	var scene: PackedScene = load(DebugMenuScreen.SCENE_PATH)
	if scene == null:
		return
	field.player.accepts_input = false
	await SceneRouter.push_screen(scene)
	field.player.accepts_input = true

## Opens the Ready Menu and uses the selected field action.
func _open_ready_menu() -> void:
	var scene: PackedScene = load(ReadyMenuScreen.SCENE_PATH)
	if scene == null:
		return
	if not await ReadyMenuScreen.has_anything():
		await field.say(ReadyMenuScreen.EMPTY_MESSAGE)
		return
	field.player.accepts_input = false
	var chosen: Variant = await SceneRouter.push_screen(scene)
	field.player.accepts_input = true
	if chosen is HiddenMoves.Request:
		var request: HiddenMoves.Request = chosen as HiddenMoves.Request
		await HiddenMoves.for_field().use(request.move, request.user)
		return
	if chosen != null:
		await _use_field_item(StringName(String(chosen)))
