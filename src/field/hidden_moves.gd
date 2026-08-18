class_name HiddenMoves
extends RefCounted
## Defines the twelve moves usable on the map.
## Carries a party-menu move request back to the map.
class Request extends RefCounted:
	var move: StringName = &""
	var user: Pokemon = null

	func _init(for_move: StringName, by: Pokemon) -> void:
		move = for_move
		user = by

## Every move with a field use, in the order the party menu lists them.
const ALL: Array[StringName] = [
	&"CUT", &"FLY", &"SURF", &"STRENGTH", &"FLASH", &"DIG", &"TELEPORT",
	&"DIVE", &"WATERFALL", &"ROCKSMASH", &"HEADBUTT", &"SWEETSCENT",
]

## Event markers for moves that target something in front of the player.
const CUT_TREE_MARKER: String = "cuttree"
const SMASH_ROCK_MARKER: String = "smashrock"
const HEADBUTT_TREE_MARKER: String = "headbutttree"
const STRENGTH_BOULDER_MARKER: String = "strengthboulder"

## Seconds a felled tree or a broken rock spends shaking before it goes.
const SMASH_SHAKE_SECONDS: float = 0.1
const SMASH_LINGER_SECONDS: float = 0.4

## Seconds a headbutted tree spends shaking before it says what came out of it.
const HEADBUTT_SHAKE_SECONDS: float = 1.0

## Headbutt item odds, in tenths.
const HEADBUTT_BEST_ODDS: int = 8
const HEADBUTT_GOOD_ODDS: int = 5
const HEADBUTT_POOR_ODDS: int = 1

## Seconds the darkness takes to widen when Flash is used.
const FLASH_SECONDS: float = 0.7

## Displays a line of text.
var narrate: Callable = Callable()

## Asks a question and returns whether the player agreed.
var confirm: Callable = Callable()

## A handler that talks through the overworld's own message window.
static func for_field() -> HiddenMoves:
	var handler: HiddenMoves = HiddenMoves.new()
	handler.narrate = func(text: String) -> void:
		await Field.say(text)
	handler.confirm = func(question: String) -> bool:
		return await Field.confirm(question)
	return handler

# === Badges ===

## Returns the badge required by a move, or `0` when none is required.
static func badges_for(move_id: StringName) -> int:
	var settings: GameSettingsData = GameSettings.data
	match move_id:
		&"CUT": return settings.badge_for_cut
		&"FLASH": return settings.badge_for_flash
		&"ROCKSMASH": return settings.badge_for_rock_smash
		&"SURF": return settings.badge_for_surf
		&"FLY": return settings.badge_for_fly
		&"STRENGTH": return settings.badge_for_strength
		&"DIVE": return settings.badge_for_dive
		&"WATERFALL": return settings.badge_for_waterfall
	return 0

## Returns whether the player has the required badge.
static func has_badge_for(move_id: StringName) -> bool:
	var required: int = badges_for(move_id)
	if required <= 0 or GameState.player == null:
		return true
	if GameSettings.data.field_moves_count_badges:
		return GameState.player.badge_count() >= required
	return GameState.player.has_badge(required)

## The Pokemon in the party that could use [param move_id] here, or `null`.
static func user_of(move_id: StringName) -> Pokemon:
	return GameState.party.first_with_move(move_id)

## Returns the hidden moves known by a Pokemon.
static func known_by(pkmn: Pokemon) -> Array[StringName]:
	var known: Array[StringName] = []
	if pkmn == null or pkmn.is_egg():
		return known
	for move_id: StringName in ALL:
		if pkmn.knows_move(move_id):
			known.append(move_id)
	return known

# === Flow ===

## Runs the party-menu flow for a hidden move.
func use_from_party(move_id: StringName, pkmn: Pokemon) -> bool:
	if not await can_use(move_id, pkmn, true):
		return false
	if not await confirm_use(move_id, pkmn):
		return false
	return await use(move_id, pkmn)

## Returns whether a move can be used at the current location.
func can_use(move_id: StringName, pkmn: Pokemon, show_message: bool = true) -> bool:
	if pkmn == null or not pkmn.knows_move(move_id):
		return false
	if not has_badge_for(move_id):
		if show_message:
			await _say("Sorry, a new Badge is required.")
		return false
	var allowed: bool = _place_allows(move_id)
	if not allowed and show_message:
		await _say(_refusal_for(move_id))
	return allowed

## Confirms moves that relocate the player.
func confirm_use(move_id: StringName, _pkmn: Pokemon) -> bool:
	match move_id:
		&"DIG":
			return await _ask(Loc.line(
				"Want to escape from here and return to {place}?",
				{"place": _escape_point_name()}
			))
		&"TELEPORT":
			return await _ask(Loc.line(
				"Want to return to the healing spot used last in {place}?",
				{"place": _healing_spot_name()}
			))
	return true

const SELF_ANNOUNCING: Array[StringName] = [&"FLY", &"SWEETSCENT"]

## Runs the animation, announcement, and effect for a move.
func use(move_id: StringName, pkmn: Pokemon) -> bool:
	if not SELF_ANNOUNCING.has(move_id):
		await announce(move_id, pkmn)
	match move_id:
		&"CUT": return await use_cut()
		&"ROCKSMASH": return await use_rock_smash()
		&"HEADBUTT": return await use_headbutt()
		&"STRENGTH": return await use_strength()
		&"FLASH": return await use_flash()
		&"DIG": return await use_dig()
		&"TELEPORT": return await use_teleport()
		&"WATERFALL": return use_waterfall()
		&"SURF":
			await FieldMoves.start_surf()
			return true
		&"DIVE": return await _use_dive()
		&"FLY": return await FieldMoves.offer_fly()
		&"SWEETSCENT": return await FieldMoves.sweet_scent()
	return false

## Shows the banner or narrates the fallback message.
func announce(move_id: StringName, pkmn: Pokemon) -> void:
	await HiddenMoveBanner.announce(move_id, pkmn, narrate)

static func move_name(move_id: StringName) -> String:
	var record: MoveData = Database.move(move_id)
	return record.get_translated_name() if record != null else String(move_id).capitalize()

# === Context ===

## Returns whether the current location allows a move.
func _place_allows(move_id: StringName) -> bool:
	match move_id:
		&"CUT": return _event_in_front(CUT_TREE_MARKER) != null
		&"ROCKSMASH": return _event_in_front(SMASH_ROCK_MARKER) != null
		&"HEADBUTT": return _event_in_front(HEADBUTT_TREE_MARKER) != null
		&"STRENGTH": return not GameState.strength_used
		&"FLASH": return GameState.is_on_dark_map() and not GameState.flash_used
		&"DIG": return GameState.has_escape_point()
		&"TELEPORT":
			return GameState.is_outdoors() and GameState.respawn_destination().size() >= 3
		&"WATERFALL": return _facing_waterfall()
		&"SURF": return FieldMoves.can_start_surf()
		&"DIVE": return FieldMoves.is_over_dive_spot() or FieldMoves.is_under_surfacing_spot()
		&"FLY": return FieldMoves.can_fly()
		&"SWEETSCENT": return true
	return false

## Returns the message for a refused move.
func _refusal_for(move_id: StringName) -> String:
	match move_id:
		&"STRENGTH": return "Strength is already being used."
		&"FLASH":
			if GameState.flash_used:
				return "Flash is already being used."
		&"SURF":
			if GameState.is_surfing():
				return "You're already surfing."
	return "You can't use that here."

## Returns the active event matching a marker in front of the player.
func _event_in_front(marker: String) -> MapEvent:
	var field: MapController = Field.controller()
	if field == null:
		return null
	for event: MapEvent in field.events_at(field.player.tile_ahead()):
		if event.erased or not event.is_active():
			continue
		if event.display_name().to_lower().replace(" ", "").contains(marker):
			return event
	return null

func _facing_waterfall() -> bool:
	var field: MapController = Field.controller()
	if field == null or not GameState.is_surfing():
		return false
	var terrain: TerrainTagData = field.terrain_at(field.player.tile_ahead())
	return terrain != null and terrain.waterfall

# === Cut ===

## Cuts the tree in front of the player.
func use_cut() -> bool:
	var tree: MapEvent = _event_in_front(CUT_TREE_MARKER)
	if tree == null:
		return false
	GameState.stats.cut_count += 1
	await smash_event(tree, "Cut")
	return true

## Smashes the rock in front of the player.
func use_rock_smash() -> bool:
	var rock: MapEvent = _event_in_front(SMASH_ROCK_MARKER)
	if rock == null:
		return false
	GameState.stats.rock_smash_count += 1
	await smash_event(rock, "Rock Smash")
	if await FieldMoves.rock_smash_encounter():
		GameState.stats.rock_smash_battles += 1
	return true

## Shakes and removes a cut or smashed event.
static func smash_event(event: MapEvent, sound: String) -> void:
	if event == null:
		return
	AudioManager.play_se(sound)
	var shake: Array[GridCharacter.Direction] = [
		GridCharacter.Direction.LEFT, GridCharacter.Direction.RIGHT,
		GridCharacter.Direction.UP,
	]
	for direction: GridCharacter.Direction in shake:
		await Field.wait(SMASH_SHAKE_SECONDS)
		event.facing = direction
	await Field.wait(SMASH_LINGER_SECONDS)
	event.erased = true
	event.visible = false
	Field.set_self_switch(event, ItemEvent.TAKEN_SWITCH, true)

## Headbutts the tree in front of the player.
func use_headbutt() -> bool:
	var tree: MapEvent = _event_in_front(HEADBUTT_TREE_MARKER)
	if tree == null:
		return false
	GameState.stats.headbutt_count += 1
	AudioManager.play_se("Headbutt")
	await Field.wait(HEADBUTT_SHAKE_SECONDS)
	var odds: int = _headbutt_odds(tree)
	if RNG.generator.randi_range(0, 9) >= odds:
		await _say("Nope. Nothing...")
		return true
	# A tree that barely ever holds anything draws from the poor table when it
	# does, and a good tree from the rich one. The odds and the table are the
	# same number in Essentials, which is why they are worked out together.
	if await FieldMoves.headbutt_encounter(odds == HEADBUTT_POOR_ODDS):
		GameState.stats.headbutt_battles += 1
	else:
		await _say("Nope. Nothing...")
	return true

## Returns the headbutt odds for a tree, in tenths.
func _headbutt_odds(tree: MapEvent) -> int:
	var cell: Vector2i = tree.tile_position
	var from_tree: int = (cell.x + (cell.x / 24) + 1) * (cell.y + (cell.y / 24) + 1)
	from_tree = (from_tree * 2 / 5) % 10
	var from_player: int = (GameState.player.public_id() % 10) if GameState.player != null else 0
	var apart: int = absi(from_tree - from_player)
	if from_tree == from_player:
		return HEADBUTT_BEST_ODDS
	if from_tree > from_player and apart < 5:
		return HEADBUTT_GOOD_ODDS
	if from_tree < from_player and apart > 5:
		return HEADBUTT_GOOD_ODDS
	return HEADBUTT_POOR_ODDS

# === Strenght ===

## Enables Strength for the current map.
func use_strength() -> bool:
	GameState.strength_used = true
	await _say("Strength made it possible to move boulders around!")
	return true

## Offers Strength when the player hits a boulder.
func offer_strength() -> bool:
	if GameState.strength_used:
		await _say("Strength made it possible to move boulders around.")
		return false
	var user: Pokemon = user_of(&"STRENGTH")
	if user == null or not has_badge_for(&"STRENGTH"):
		await _say("It's a big boulder, but a Pokemon may be able to push it aside.")
		return false
	await _say("It's a big boulder, but you may be able to push it aside with a hidden move.")
	if not await _ask("Would you like to use Strength?"):
		return false
	await announce(&"STRENGTH", user)
	return await use_strength()

# === Flash ===

## Enables Flash and widens the darkness effect.
func use_flash() -> bool:
	GameState.flash_used = true
	GameState.stats.flash_count += 1
	var overworld: Overworld = Overworld.current
	if overworld != null:
		await overworld.screen_effects().widen_darkness(FLASH_SECONDS)
	return true

# === Dig and Fly ===

## Returns the player to the escape point.
func use_dig() -> bool:
	return await FieldItemEffects.escape_to_entrance()

## Returns the player to the last healing spot.
func use_teleport() -> bool:
	var overworld: Overworld = Overworld.current
	if overworld == null or GameState.respawn_destination().size() < 3:
		return false
	GameState.clear_escape_point()
	FieldItemEffects.dismount_bicycle(true)
	await overworld.warp_to_respawn()
	return true

func _use_dive() -> bool:
	if FieldMoves.is_over_dive_spot():
		await FieldMoves.dive()
		return true
	if FieldMoves.is_under_surfacing_spot():
		await FieldMoves.surface()
		return true
	return false

# === Waterfall ===

## Starts climbing the waterfall.
func use_waterfall() -> bool:
	var field: MapController = Field.controller()
	if field == null or field.player.facing != GridCharacter.Direction.UP:
		return false
	GameState.stats.waterfall_count += 1
	field.begin_waterfall(GridCharacter.Direction.UP)
	return true

## Offers Waterfall when the player faces one.
func offer_waterfall() -> bool:
	var field: MapController = Field.controller()
	if field == null:
		return false
	var terrain: TerrainTagData = field.terrain_at(field.player.tile_ahead())
	if terrain == null:
		return false
	if terrain.waterfall_crest and not terrain.waterfall:
		await _say("A wall of water is crashing down with a mighty roar.")
		return false
	if not terrain.waterfall:
		return false
	var user: Pokemon = user_of(&"WATERFALL")
	if user == null or not has_badge_for(&"WATERFALL"):
		await _say("A wall of water is crashing down with a mighty roar.")
		return false
	if not await _ask("It's a large waterfall.\nWould you like to use Waterfall?"):
		return false
	await announce(&"WATERFALL", user)
	return use_waterfall()

# === Event Managed Offers ===

## Offers Cut without removing the tree event.
func ask_to_cut() -> bool:
	var user: Pokemon = user_of(&"CUT")
	if user == null or not has_badge_for(&"CUT"):
		await _say("This tree looks like it can be cut down.")
		return false
	if not await _ask("This tree looks like it can be cut down!\nWould you like to cut it?"):
		return false
	GameState.stats.cut_count += 1
	await announce(&"CUT", user)
	return true

## Offers Rock Smash without removing the rock event.
func ask_to_rock_smash() -> bool:
	var user: Pokemon = user_of(&"ROCKSMASH")
	if user == null or not has_badge_for(&"ROCKSMASH"):
		await _say("It's a rugged rock, but a Pokemon may be able to smash it.")
		return false
	if not await _ask("This rock seems breakable with a hidden move.\nWould you like to use Rock Smash?"):
		return false
	GameState.stats.rock_smash_count += 1
	await announce(&"ROCKSMASH", user)
	return true

## Offers Headbutt and runs the full interaction here.
func offer_headbutt() -> bool:
	var user: Pokemon = user_of(&"HEADBUTT")
	if user == null:
		await _say("A Pokemon could be in this tree. Maybe a Pokemon could shake it.")
		return false
	if not await _ask("A Pokemon could be in this tree.\nWould you like to use Headbutt?"):
		return false
	await announce(&"HEADBUTT", user)
	return await use_headbutt()

# === Internals ===

## Returns the map name used by the Dig prompt.
func _escape_point_name() -> String:
	if not GameState.has_escape_point():
		return ""
	return _map_name(GameState.escape_point[0])

func _healing_spot_name() -> String:
	var destination: Array[int] = GameState.respawn_destination()
	return _map_name(destination[0]) if destination.size() >= 3 else ""

static func _map_name(for_map_id: int) -> String:
	var metadata: MapMetadataData = Database.map_metadata(for_map_id)
	if metadata != null and not metadata.get_translated_name().is_empty():
		return metadata.get_translated_name()
	return Loc.line("that place")

func _player_name() -> String:
	return GameState.player.name if GameState.player != null else "You"

func _say(text: String) -> void:
	if narrate.is_valid():
		await narrate.call(text)

func _ask(question: String) -> bool:
	if not confirm.is_valid():
		return false
	return await confirm.call(question)
