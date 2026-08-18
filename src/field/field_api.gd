class_name Field
## The shorthand handlers for writing overworld events
## The field is a container for overworld behaviour and management

## The three states for [method _project_flags_safari_maps]
## It's used enough it's worth extracting, and can't be a bool because `idk` is a unique state
const FLAG_UNKNOWN: int = -1
const FLAG_NO: int = 0
const FLAG_YES: int = 1

static var _safari_maps_flagged: int = FLAG_UNKNOWN

## What field the game is currently on, or `null` if there is no active field
static func controller() -> MapController:
	return MapController.current


## The map scene the player is standing on.
static func map() -> GameMap:
	var field: MapController = controller()
	return field.current_map if field != null else null


static func player() -> PlayerCharacter:
	var field: MapController = controller()
	return field.player if field != null else null


# === Dialogue ===

## Shows the player a message and waits for input
static func say(text: String) -> void:
	var field: MapController = controller()
	if field == null:
		push_warning("Field.say: no field is loaded; skipping '%s'." % text)
		return
	await field.say(text)


## Offers a list of options and returns the index chosen, or `-1` on cancel.
static func ask(
	options: Array,
	prompt: String = "",
	cancel_index: int = MessageBox.CANCELLED,
	default_index: int = 0
) -> int:
	var field: MapController = controller()
	if field == null:
		return -1
	return await field.ask(options, prompt, cancel_index, default_index)


## Asks a yes/no question
## Cancelling counts as `no`
static func confirm(question: String, yes: String = "Yes", no: String = "No") -> bool:
	return await ask([yes, no], question, 2) == 0


## Sets where messages open and whether they are drawn with a frame, persists until changed
static func set_text_options(
	window_position: MessageBox.WindowPosition, frame_visible: bool = true
) -> void:
	var overworld: Overworld = Overworld.current
	if overworld == null or overworld.message_box == null:
		return
	overworld.message_box.set_text_options(window_position, frame_visible)


## Waits [param seconds] of game time
static func wait(seconds: float) -> void:
	var field: MapController = controller()
	if field == null or field.get_tree() == null:
		return
	await field.get_tree().create_timer(seconds).timeout


# === Movement ===

## Sends the player to another map scene, fading through black.
static func warp(scene: PackedScene, spawn: StringName = &"", facing: int = 0, fade: bool = true) -> void:
	var field: MapController = controller()
	if field == null:
		return
	await field.warp_to_scene(scene, spawn, Vector2i(-1, -1), facing, fade)


## Sends the player to a map by its number
static func warp_to_map(map_id: int, cell: Vector2i, facing: int = 0, fade: bool = true) -> void:
	var field: MapController = controller()
	if field == null:
		return
	await field.warp_to_map_id(map_id, cell, facing, fade)


## Moves the player elsewhere on the map they are already on
static func move_player_to(cell: Vector2i, facing: int = 0) -> void:
	var field: MapController = controller()
	if field != null:
		field.move_player_to(cell, facing)


## Walks [param character] through a list of directions, one cell at a time
static func walk(character: GridCharacter, directions: Array) -> void:
	for direction: Variant in directions:
		await character.step(int(direction) as GridCharacter.Direction)


# === Game Session ===

static func get_switch(switch_id: int) -> bool:
	return GameState.get_switch(switch_id)


static func set_switch(switch_id: int, value: bool = true) -> void:
	GameState.set_switch(switch_id, value)


static func get_variable(variable_id: int) -> Variant:
	return GameState.get_variable(variable_id)


static func set_variable(variable_id: int, value: Variant) -> void:
	GameState.set_variable(variable_id, value)


## Reads one of [param event]'s own switches
static func get_self_switch(event: MapEvent, switch: String) -> bool:
	if event == null:
		return false
	return GameState.get_self_switch(_map_id_of(event), event.self_switch_key(), switch)


static func set_self_switch(event: MapEvent, switch: String, value: bool = true) -> void:
	if event == null:
		return
	GameState.set_self_switch(_map_id_of(event), event.self_switch_key(), switch, value)
	var field: MapController = controller()
	if field == null:
		return
	for other: MapEvent in field.all_events():
		other.refresh_page()


static func _map_id_of(event: MapEvent) -> int:
	if event.map_scene != null:
		return event.map_scene.map_id
	var field: MapController = controller()
	return field.map_id() if field != null else 0


# === The Player ===

static func give_item(item_id: StringName, count: int = 1) -> bool:
	return GameState.bag.add_item(item_id, count)


static func take_item(item_id: StringName, count: int = 1) -> bool:
	return GameState.bag.remove_item(item_id, count)


static func has_item(item_id: StringName) -> bool:
	return GameState.bag.has_item(item_id)


static func give_money(amount: int) -> void:
	if GameState.player != null:
		GameState.player.add_money(amount)


static func take_money(amount: int) -> bool:
	if GameState.player == null:
		return false
	return GameState.player.spend_money(amount)


static func heal_party() -> void:
	GameState.party.heal_all()


# === Presentation ===

static func play_se(sound_name: String) -> void:
	AudioManager.play_se(sound_name)


static func play_me(sound_name: String) -> void:
	AudioManager.play_me(sound_name)


static func play_bgm(track_name: String) -> void:
	AudioManager.play_bgm(track_name)


static func fade_out() -> void:
	await SceneRouter.fade_out()


static func fade_in() -> void:
	await SceneRouter.fade_in()


# === Battles ===

## Starts a wild battle against one Pokemon and returns how it ended
static func wild_battle(species_id: StringName, level: int) -> BattlePresenter.Outcome:
	var overworld: Overworld = Overworld.current
	if overworld == null:
		push_warning("Field.wild_battle: there is no overworld to fight in.")
		return BattlePresenter.Outcome.UNDECIDED
	var wild: Pokemon = Pokemon.create(species_id, level)
	return await overworld.start_wild_battle(wild)


## Starts a wild battle as a double battle
static func double_wild_battle(
	first_species: StringName, first_level: int, second_species: StringName, second_level: int
) -> BattlePresenter.Outcome:
	var overworld: Overworld = Overworld.current
	if overworld == null:
		push_warning("Field.double_wild_battle: there is no overworld to fight in.")
		return BattlePresenter.Outcome.UNDECIDED
	var wild: Array[Pokemon] = [
		EncounterSystem.generate_species(first_species, first_level),
		EncounterSystem.generate_species(second_species, second_level),
	]
	return await overworld.start_wild_battle_against(wild)


## Rolls a wild battle from the current map's own encounter table for [param encounter_type]
## Returns `false` if there's no table or no encounter
static func table_encounter(encounter_type: StringName = &"Land") -> bool:
	var field: MapController = controller()
	if field == null:
		return false
	var terrain: TerrainTagData = field.terrain_at(field.player.tile_position)
	var wild: Array[Pokemon] = field.encounters.build_encounter(
		encounter_type, terrain, GameState.is_repel_active())
	if wild.is_empty():
		return false
	var overworld: Overworld = Overworld.current
	if overworld == null:
		return false
	await overworld.start_wild_battle_against(wild)
	return true


## Switches wild encounters off or back on
static func set_encounters_enabled(enabled: bool) -> void:
	GameState.encounters_disabled = not enabled


## Makes the next wild battle a single one whatever the grass says
## Cleared once the encounter is rolled
static func force_single_battle() -> void:
	GameState.force_single_battle = true


## Puts a trainer at the player's side
## While with a partner, all battles are double battles
## Pass no arguments to send them off
static func set_partner(trainer_type: StringName = &"", trainer_name: String = "", version: int = 0) -> bool:
	if trainer_type.is_empty():
		GameState.partner_trainer = null
		return true
	var trainer: TrainerData = Database.trainer(trainer_type, trainer_name, version)
	if trainer == null:
		push_error("Field.set_partner: no trainer record for %s '%s'." % [trainer_type, trainer_name])
		return false
	GameState.partner_trainer = trainer
	return true


# === Field Moves ===

## Asks if the player wants to surf,
## Returns true if they said yes and set off surfing
static func surf() -> bool:
	return await FieldMoves.offer_surf()


## Takes the player off the water wherever they are.
static func stop_surfing() -> void:
	FieldMoves.end_surf()


static func is_surfing() -> bool:
	return GameState.is_surfing()


## Offers either let the player dive or surface (depending on where they are already)
## Returns `true` if they did so
static func dive() -> bool:
	return await FieldMoves.offer_dive()


## Forcibly takes the player under to the map this one names as its `dive_map_id`
static func dive_now() -> void:
	await FieldMoves.dive()


## Brings the player back up to the map above, without asking.
static func surface_now() -> void:
	await FieldMoves.surface()


static func is_diving() -> bool:
	return GameState.is_diving()


## Returns `true` when the map the player is on is the underwater half of a pair.
static func is_underwater_map() -> bool:
	return FieldMoves.surface_map_above() > 0


## Casts a rod at the water in front of the player.
static func fish(rod: StringName = &"OLDROD") -> bool:
	return await FieldMoves.fish(rod)


## The wild Pokemon a smashed rock sometimes has
## Called when a rock is broken, returns true if a battle was fought
static func rock_smash_encounter() -> bool:
	return await FieldMoves.rock_smash_encounter()


## The wild Pokemon a headbutted tree sometimes drops
static func headbutt_encounter(low: bool = false) -> bool:
	return await FieldMoves.headbutt_encounter(low)


## Uses Sweet Scent where the player is standing
static func sweet_scent() -> bool:
	return await FieldMoves.sweet_scent()


# === Field Items ===

## Uses [param item_id] on the world
## Returns `true` if it was spent and removes it from the bag
static func use_item(item_id: StringName) -> bool:
	var record: ItemData = Database.item(item_id)
	if record == null:
		return false
	var used: bool = await FieldItemEffects.for_field().use_in_field(item_id)
	if used and record.consumable:
		GameState.bag.remove_item(item_id, 1)
	return used


## Puts the player on or off their bicycle
## Returns `true` when they changed
static func toggle_bicycle() -> bool:
	return await FieldItemEffects.for_field().toggle_bicycle()


## Remembers where the player is standing as the place an Escape Rope or Dig sends them to
static func set_escape_point() -> void:
	GameState.set_escape_point()


static func clear_escape_point() -> void:
	GameState.clear_escape_point()


## Remembers where the player is standing as the spot Teleport returns to and a blackout/whiteout sends them to
static func set_healing_spot() -> void:
	GameState.set_healing_spot()


## Starts a trainer battle against the named trainer and reports how it ended.
static func trainer_battle(trainer_type: StringName, trainer_name: String, version: int = 0) -> BattlePresenter.Outcome:
	var overworld: Overworld = Overworld.current
	if overworld == null:
		push_warning("Field.trainer_battle: there is no overworld to fight in.")
		return BattlePresenter.Outcome.UNDECIDED
	var trainer: TrainerData = Database.trainer(trainer_type, trainer_name, version)
	if trainer == null:
		push_error("Field.trainer_battle: no trainer record for %s '%s'." % [trainer_type, trainer_name])
		return BattlePresenter.Outcome.UNDECIDED
	return await overworld.start_trainer_battle(trainer)


# === Safari Zone and Bug Contest ===

## Starts a Safari Zone trip
static func start_safari_zone(balls: int = 30, steps: int = 500, return_to_gate: bool = true) -> void:
	var session: SafariSession = SafariSession.new()
	session.begin(balls, steps, SessionReturnPoint.here() if return_to_gate else null)
	GameState.safari = session
	await say(Loc.line("Here are {balls_left} Safari Balls. We'll call you when you're out of them.", {"balls_left": session.balls_left}))


## `true` while a safari trip is running
static func in_safari_zone() -> bool:
	if GameState == null or GameState.safari == null or not GameState.safari.active:
		return false
	if not _project_flags_safari_maps():
		return true
	return safari_zone_owns_map(GameState.map_id)


## `true` when [param map_id] is part of the Safari Zone the current trip is in
static func safari_zone_owns_map(map_id: int) -> bool:
	var metadata: MapMetadataData = Database.map_metadata(map_id)
	if metadata != null and metadata.safari_map:
		return true
	var session: SafariSession = GameState.safari if GameState != null else null
	if session == null or session.return_point == null:
		return false
	return session.return_point.map_id == map_id


## Returns `true` when any map in the project is flagged as part of a Safari Zone.
static func _project_flags_safari_maps() -> bool:
	if _safari_maps_flagged == FLAG_UNKNOWN:
		_safari_maps_flagged = FLAG_NO
		for record: GameDataResource in Database.get_all(Database.CATEGORY_MAP_METADATA):
			var metadata: MapMetadataData = record as MapMetadataData
			if metadata != null and metadata.safari_map:
				_safari_maps_flagged = FLAG_YES
				break
	return _safari_maps_flagged == FLAG_YES


## Ends the trip and hands over everything caught on it
static func end_safari_zone() -> void:
	var session: SafariSession = GameState.safari if GameState != null else null
	if session == null:
		return
	session.finish()
	GameState.safari = null
	var total: int = session.caught.size()
	GameState.stats.safari_pokemon_caught += total
	GameState.stats.most_captures_per_safari_game = maxi(
		GameState.stats.most_captures_per_safari_game, total)
	if total == 0:
		await say("Didn't catch a thing? Better luck next time!")
		return
	await say(Loc.line("You caught {total} Pokemon! Let's have a look at them.", {"total": total}))
	for pkmn: Pokemon in session.caught:
		await _hand_over(pkmn)


## Enters the Bug-Catching Contest -- the player keeps one pokemon, and the rest are temporarily held
## Returns `false` when the player backed out or had nothing that could compete.
static func start_bug_contest(
	party_slot: int = -1, balls: int = 20, steps: int = 0, return_to_gate: bool = true
) -> bool:
	if GameState == null or GameState.party.able_count() == 0:
		return false
	var slot: int = party_slot
	if slot < 0:
		slot = await _choose_contest_entrant()
	if slot < 0:
		return false
	var session: BugContestSession = BugContestSession.new()
	session.begin(balls, steps, SessionReturnPoint.here() if return_to_gate else null)
	if not session.enter(GameState.party, slot):
		return false
	GameState.bug_contest = session
	GameState.stats.bug_contest_count += 1
	await say(Loc.line("We'll look after the rest of your Pokemon. Here are {balls_left} {balls_left2}!", {"balls_left": session.balls_left, "balls_left2": _ball_name(BugContestSession.BALL, session.balls_left)}))
	return true


static func in_bug_contest() -> bool:
	return GameState != null and GameState.bug_contest != null and GameState.bug_contest.active


## Ends the bug catching contest
static func end_bug_contest() -> int:
	var session: BugContestSession = GameState.bug_contest if GameState != null else null
	if session == null:
		return 0
	session.finish()
	session.leave(GameState.party)
	GameState.bug_contest = null
	if session.caught == null:
		await say("You didn't catch anything! Come back and try again.")
		return session.rival_scores.size() + 1
	var place: int = session.placing()
	await say("Now, the results of the Bug-Catching Contest!")
	for rank: int in range(1, mini(4, session.rival_scores.size() + 2)):
		var entrant: Dictionary = session.entrant_at(rank)
		if String(entrant["name"]).is_empty():
			continue
		await say(Loc.line("In {rank} place, {name}, with {score} points!", {"rank": _ordinal(rank), "name": entrant["name"], "score": int(entrant["score"])}))
	if place == 1:
		GameState.stats.bug_contest_wins += 1
		await say(Loc.line("Congratulations! Your {caught} took first place!", {"caught": session.caught.display_name()}))
	else:
		await say(Loc.line("You came {place} with your {caught}. Thanks for entering!", {"place": _ordinal(place), "caught": session.caught.display_name()}))
	await _hand_over(session.caught)
	return place


## Asks which Pokemon the player wants to take into the bug catching contest.
static func _choose_contest_entrant() -> int:
	var party: PokemonParty = GameState.party
	var options: Array = []
	var slots: Array[int] = []
	for slot: int in range(party.size()):
		var member: Pokemon = party.get_member(slot)
		if member == null or not member.is_able():
			continue
		options.append(member.display_name())
		slots.append(slot)
	if options.is_empty():
		return -1
	var chosen: int = await ask(options, "Which Pokemon will you enter?")
	return slots[chosen] if chosen >= 0 and chosen < slots.size() else -1


## Gives [param pkmn] to the player through the ordinary receiving flow
static func _hand_over(pkmn: Pokemon) -> void:
	var receipt: PokemonReceipt = PokemonReceipt.new()
	receipt.narrate = func(text: String) -> void:
		await say(text)
	receipt.ask = func(options: Array) -> int:
		return await ask(options)
	await receipt.give(pkmn)


static func _ball_name(ball_id: StringName, quantity: int) -> String:
	var record: ItemData = Database.item(ball_id)
	if record == null:
		return "Balls"
	return record.name_plural if quantity != 1 else record.display_name


# === Battle Frontier ===

## Runs one attempt at a Battle Frontier facility and returns `true` when the player got all the way through.
static func run_challenge(facility: StringName = &"BATTLETOWER", rules: ChallengeRules = null) -> bool:
	var overworld: Overworld = Overworld.current
	if overworld == null:
		push_warning("Field.run_challenge: there is no overworld to fight in.")
		return false
	var applied: ChallengeRules = rules if rules != null else ChallengeFacilities.rules_for(facility)
	if applied == null:
		push_error("Field.run_challenge: %s is not a facility." % facility)
		return false
	var record: ChallengeSession = GameState.challenge_record(facility)
	if record.active:
		push_warning("Field.run_challenge: a run at %s is already going." % facility)
		return false

	if not applied.shape().rents_team():
		var complaints: Array[String] = applied.validate(GameState.party)
		if not complaints.is_empty():
			await say(complaints[0])
			return false

	var runner: ChallengeRunner = _challenge_runner(overworld, record, applied)
	if not await runner.enter(applied):
		return false
	var completed: bool = await runner.run()
	_store_challenge_recordings(applied, record)
	record.leave(GameState.party)
	GameState.party.heal_all()
	if completed:
		await _pay_challenge_prize(applied, record)
	return completed


## Builds the runner a facility is fought through
static func _challenge_runner(
	overworld: Overworld, record: ChallengeSession, rules: ChallengeRules
) -> ChallengeRunner:
	var runner: ChallengeRunner = ChallengeRunner.new(record, GameState.party)
	runner.keep_recordings = true
	runner.narrate = func(text: String) -> void:
		await say(text)
	runner.ask = func(options: Array, prompt: String) -> int:
		return await ask(options, prompt)
	runner.fight = func(
		trainer: TrainerData, _round_number: int, setup: Callable
	) -> BattlePresenter.Outcome:
		return await overworld.start_trainer_battle_against(
			[trainer] as Array[TrainerData], rules.battlers_per_side, setup)
	runner.fight_wild = func(
		wild: Array[Pokemon], _round_number: int, setup: Callable
	) -> BattlePresenter.Outcome:
		return await overworld.start_wild_battle_against(wild, rules.battlers_per_side, setup)
	return runner


## Writes the run's battles out where the replay screen can find them. 
static func _store_challenge_recordings(rules: ChallengeRules, record: ChallengeSession) -> void:
	for index: int in range(record.recordings.size()):
		var recording: BattleRecording = record.recordings[index]
		if recording == null:
			continue
		recording.save_to(BattleRecording.path_for("%s-%02d" % [
			String(rules.facility_id).to_lower(), index + 1,
		]))


## Hands over the Battle Points a completed run is worth
static func _pay_challenge_prize(rules: ChallengeRules, record: ChallengeSession) -> void:
	var points: int = rules.prize_for(record.streak)
	if points <= 0:
		return
	give_battle_points(points)
	await say(Loc.line("Here are {points} Battle Points. You now have {battle_points}.", {"points": points, "battle_points": battle_points()}))


## The streak at [param facility]
static func challenge_streak(facility: StringName = &"BATTLETOWER") -> int:
	return GameState.challenge_record(facility).streak


## The best streak ever managed at [param facility]
static func challenge_best_streak(facility: StringName = &"BATTLETOWER") -> int:
	return GameState.challenge_record(facility).best_streak


## One line of a facility's record board
static func challenge_record_line(facility: StringName) -> String:
	var rules: ChallengeRules = ChallengeFacilities.rules_for(facility)
	var record: ChallengeSession = GameState.challenge_record(facility)
	var title: String = rules.display_name if rules != null else String(facility)
	return Loc.line("{title} — now {streak}, best {best_streak}", {"title": title, "streak": record.streak, "best_streak": record.best_streak})


## The whole record board, one line per facility
static func challenge_record_board() -> Array[String]:
	var lines: Array[String] = []
	for facility: StringName in ChallengeFacilities.ALL:
		lines.append(challenge_record_line(facility))
	return lines

static func show_challenge_record_board() -> void:
	for line: String in challenge_record_board():
		await say(line)


## Opens the list of recorded battles and plays back whichever one the player chooses
## Returns when they close it
static func watch_replays() -> void:
	var scene: PackedScene = load(ReplayScreen.SCENE_PATH)
	if scene == null:
		push_error("Field.watch_replays: the replay screen is missing.")
		return
	await SceneRouter.push_screen(scene)


# === Town Map ===

## Opens the region map. Returns when the player closes it
static func show_town_map(wall_map: bool = true, for_region: int = -1) -> void:
	var mode: TownMapScreen.Mode = TownMapScreen.Mode.WALL if wall_map else TownMapScreen.Mode.PLAYER
	var destination: TownMapPoint = await _open_town_map(mode, for_region)
	if destination != null:
		await FieldMoves.fly_to(destination)


## Opens the region map with the fly destinations already marked and returns the one the player picked
static func choose_fly_destination(for_region: int = -1) -> TownMapPoint:
	return await _open_town_map(TownMapScreen.Mode.FLY, for_region)


static func _open_town_map(mode: TownMapScreen.Mode, for_region: int) -> TownMapPoint:
	var scene: PackedScene = load(TownMapScreen.SCENE_PATH)
	if scene == null:
		push_error("Field.show_town_map: the town map screen is missing.")
		return null
	var result: Variant = await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(mode, for_region)
	)
	return result as TownMapPoint


# === Pokegear ===

## Opens the Pokegear and returns when the player puts it away
static func show_pokegear() -> void:
	if GameState.player == null or not GameState.player.has_pokegear:
		return
	var scene: PackedScene = load(PokegearScreen.SCENE_PATH)
	if scene == null:
		push_error("Field.show_pokegear: the Pokegear screen is missing.")
		return
	var destination: Variant = await SceneRouter.push_screen(scene)
	if destination is TownMapPoint:
		await FieldMoves.fly_to(destination as TownMapPoint)


## Opens the Pokegear's phone book on its own, skipping the app menu
static func open_phone() -> void:
	var book: PhoneBook = GameState.phone
	if book == null or not book.has_visible_contacts():
		await say(Loc.line("There are no phone numbers stored."))
		return
	var scene: PackedScene = load(PhoneScreen.SCENE_PATH)
	if scene == null:
		push_error("Field.open_phone: the phone screen is missing.")
		return
	await SceneRouter.push_screen(scene)


## Shows [param conversation] as a call over whatever is on screen
static func take_phone_call(conversation: PhoneCall) -> void:
	await PhoneCallScreen.play(conversation)


## Rings [param trainer_type] [param trainer_name]
## Returns `true` when the call was placed
static func phone_call(
	trainer_type: StringName, trainer_name: String = "", version: int = 0
) -> bool:
	var book: PhoneBook = GameState.phone
	if book == null:
		return false
	var contact: PhoneContact = null
	if trainer_name.is_empty():
		contact = book.find(String(trainer_type))
	else:
		contact = book.get_trainer(trainer_type, trainer_name, version)
	if contact == null:
		push_warning(
			"Field.phone_call: %s %s is not in the phone book."
			% [trainer_type, trainer_name]
		)
		return false
	return await PhoneCall.make_outgoing(contact)


## Shows the player their Trainer Card and returns when they put it away
static func show_trainer_card() -> void:
	var scene: PackedScene = load(TrainerCardScreen.SCENE_PATH)
	if scene == null:
		push_error("Field.show_trainer_card: the Trainer Card screen is missing.")
		return
	await SceneRouter.push_screen(scene)


## Opens the Purify Chamber and returns when the player closes it
static func show_purify_chamber() -> void:
	var scene: PackedScene = load(PurifyChamberScreen.SCENE_PATH)
	if scene == null:
		push_error("Field.show_purify_chamber: the Purify Chamber screen is missing.")
		return
	await SceneRouter.push_screen(scene)


## Opens the PC in a Poke Center and returns once the player has logged off
static func open_pc() -> void:
	await FieldPC.open_poke_center_pc()


## Opens "PLAYER's PC" -- the machine in the player's own bedroom
static func open_trainer_pc() -> void:
	await FieldPC.open_trainer_pc()


# === Ceremonies ===

## Rolls the end credits and returns when they are over
## `true` if the player watched it all the way through
## `false` when the player skipped it
static func show_credits() -> bool:
	var scene: PackedScene = load(CreditsScreen.SCENE_PATH)
	if scene == null:
		push_error("Field.show_credits: the credits screen is missing.")
		return false
	return bool(await SceneRouter.push_screen(scene))


## Records the party in the Hall of Fame and plays the ceremony
static func enter_hall_of_fame() -> void:
	await _open_hall_of_fame(HallOfFameScreen.Mode.CEREMONY)
	await SceneRouter.fade_in()


## Opens the record of teams already inducted
static func show_hall_of_fame() -> void:
	await _open_hall_of_fame(HallOfFameScreen.Mode.VIEWER)


static func _open_hall_of_fame(mode: HallOfFameScreen.Mode) -> void:
	var scene: PackedScene = load(HallOfFameScreen.SCENE_PATH)
	if scene == null:
		push_error("Field.enter_hall_of_fame: the Hall of Fame screen is missing.")
		return
	await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(mode)
	)


# === Battle Points ===

## Battle Points the player is carrying.
static func battle_points() -> int:
	return GameState.player.battle_points if GameState != null and GameState.player != null else 0


static func give_battle_points(amount: int) -> void:
	if GameState == null or GameState.player == null or amount <= 0:
		return
	GameState.player.battle_points += amount
	# The other half of the ledger `MartScreen` keeps when they are spent.
	GameState.stats.battle_points_won += amount


## Spends Battle Points
## Returns `false` if the player can't afford it
static func spend_battle_points(amount: int) -> bool:
	if GameState == null or GameState.player == null or amount <= 0:
		return false
	if GameState.player.battle_points < amount:
		return false
	GameState.player.battle_points -= amount
	return true


# === Vocabulary ===

## Hands over an item the way a ball on the ground does
static func found_item(item_id: StringName, quantity: int = 1) -> bool:
	return await FieldItems.found(item_id, quantity)


## Hands over an item as a gift saying "obtained"
static func receive_item(item_id: StringName, quantity: int = 1) -> bool:
	return await FieldItems.received(item_id, quantity)


## Opens a Poke Mart stocking [param items]
static func open_mart(items: Array, shop_name: String = "Poke Mart") -> void:
	await FieldItems.open_mart(items, shop_name)


## Asks the player to pick a party member and returns the slot, or `-1`
static func choose_pokemon(prompt: String = "Choose a Pokemon.") -> int:
	return await FieldPokemon.choose(0, 0, Callable(), prompt)


## Teaches [param move_id] to [param pkmn]
static func teach_move(pkmn: Pokemon, move_id: StringName) -> bool:
	return await FieldPokemon.teach_move(pkmn, move_id)


## Brings on [param weather_id] at [param power], from 0 (off) to 9 (heaviest).
static func set_weather(weather_id: StringName, power: int = 5, seconds: float = 0.0) -> void:
	FieldEffects.set_weather(weather_id, power, seconds)


## Hands the map its own weather back over [param seconds]
static func clear_weather(seconds: float = 0.0) -> void:
	FieldEffects.clear_weather(seconds)


## Changes the screen tone over [param frames] and waits for it
static func change_tone(red: int, green: int, blue: int, grey: int, frames: int) -> void:
	await FieldEffects.change_tone(red, green, blue, grey, frames)


## Puts the screen tone back to normal over [param frames], and waits for it
static func clear_tone(frames: int = 0) -> void:
	await FieldEffects.clear_tone(frames)


## Washes [param colour] over the screen and fades it out over [param frames]
## The flash is not awaited
static func flash_screen(colour: Color, frames: int) -> void:
	FieldEffects.flash(colour, frames)


## Shakes the screen at [param power] and [param speed], both from 0 to 9, for [param frames]
static func shake_screen(power: int, speed: int, frames: int) -> void:
	FieldEffects.shake(power, speed, frames)


## Waits for a shake already running to finish settling.
static func wait_for_shake() -> void:
	await FieldEffects.wait_for_shake()


## The moment a trainer spots the player
static func notice_player(event: MapEvent) -> void:
	await FieldEffects.notice_player(event)


# === Pokemon Followers ===


## Forces a follower mode for the rest of the playthrough
static func set_follower_mode(mode: int) -> bool:
	return FieldEffects.set_follower_mode(mode)


## Hands the choice of mode back to the player
static func clear_follower_mode() -> void:
	FieldEffects.clear_follower_mode()


## The mode the game is running under
static func follower_mode() -> int:
	return FieldEffects.follower_mode()


## Picks the party member in [param index] as the one that walks under [constant FollowerMode.Mode.CHOSEN]
## Picking the one already picked clears it.
static func set_chosen_follower(index: int) -> bool:
	return FieldEffects.set_chosen_follower(index)


## Puts the party member in [param index] at the head of the line for a scene,
## whatever the mode says and whatever else is in the party.
static func add_temporary_follower(index: int) -> bool:
	return FieldEffects.add_temporary_follower(index)


## Puts a pokemon at the head of the follower line.
static func add_temporary_species_follower(
	species_id: StringName, form: int = 0, shiny: bool = false,
	female: bool = false, called: String = ""
) -> bool:
	return FieldEffects.add_temporary_species_follower(
		species_id, form, shiny, female, called)


## Sends the temporary followers away and puts the party's own line back.
static func clear_temporary_followers() -> void:
	FieldEffects.clear_temporary_followers()


## Takes the followers off the screen for a cutscene
static func hide_followers() -> void:
	FieldEffects.hide_followers()


static func show_followers() -> void:
	FieldEffects.show_followers()


## The party members currently walking behind the player
static func walking_pokemon() -> Array[Pokemon]:
	return FieldEffects.walking_pokemon()


## Walks the whole line onto the player's cell one after another
static func followers_into_door() -> void:
	await FieldEffects.follow_into_door()


## Plays the cry of whichever Pokemon is walking closest to the player
static func follower_cry() -> void:
	FieldEffects.follower_cry()


# === Minigames ===


## Plays Voltorb Flip and returns the coins won
static func voltorb_flip() -> int:
	return await Minigames.voltorb_flip()


## Plays a slot machine and returns how many coins the player ended up up or down by
## [param difficulty] runs from `0` (generous) to `2` (evil)
static func slot_machine(difficulty: int = 1) -> int:
	return await Minigames.slot_machine(difficulty)


## Digs at the mining wall and returns the items that came out of it
static func mining_game() -> Array:
	return await Minigames.mining()


## Runs one of the seven tile puzzles and reports whether it was solved.
## [param mode] is a [enum TilePuzzleBoard.Mode].
static func tile_puzzle(
	mode: int, board: StringName, puzzle_width: int = 0, puzzle_height: int = 0
) -> bool:
	return await Minigames.tile_puzzle(mode, board, puzzle_width, puzzle_height)


## Duels somebody at Triple Triad and returns a [enum TriadDuelScreen.Result].
static func triad_duel(
	opponent: String, min_level: int = 0, max_level: int = 5,
	rules: Array = [], opponent_deck: Array = [], prize: StringName = &""
) -> int:
	return await Minigames.triad_duel(opponent, min_level, max_level, rules, opponent_deck, prize)


## Fights [param event] hand to hand and reports whether the player won.
## [param speeches] is twelve lines, three for each command the opponent can choose.
static func duel(
	trainer_type: StringName, trainer_name: String, event: MapEvent, speeches: Array
) -> bool:
	return await Minigames.duel(trainer_type, trainer_name, event, speeches)


static func _ordinal(number: int) -> String:
	match number:
		1:
			return "first"
		2:
			return "second"
		3:
			return "third"
	return "%dth" % number
