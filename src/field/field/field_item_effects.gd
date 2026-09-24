class_name FieldItemEffects
extends RefCounted
## Handles items used in the overworld.

## What using an item from the bag came to.
enum Outcome {
	## Nothing happened.
	NOT_USED = 0,
	## The item did its work there and then.
	USED = 1,
	## The bag has to close first.
	ON_THE_MAP = 2,
}

## Steps each Repel keeps wild Pokemon away for.
const REPEL_STEPS: Dictionary = {
	&"REPEL": 100,
	&"SUPERREPEL": 200,
	&"MAXREPEL": 250,
}

## Steps each flute's effect on wild encounters lasts.
const FLUTE_STEPS: Dictionary = {
	&"BLACKFLUTE": 250,
	&"WHITEFLUTE": 250,
}

## The bicycles.
const BICYCLES: Array[StringName] = [&"BICYCLE", &"MACHBIKE", &"ACROBIKE"]

## The detectors that point at a buried item.
const ITEM_DETECTORS: Array[StringName] = [
	&"ITEMFINDER", &"DOWSINGMCHN", &"DOWSINGMACHINE",
]

## The Poke Radar, which shakes the grass around the player.
const POKE_RADAR: StringName = &"POKERADAR"

## The Exp Share key item in its two states, off first.
const EXP_ALL_OFF: StringName = &"EXPALLOFF"
const EXP_ALL_ON: StringName = &"EXPALL"

## Flag shared by Repel items.
const REPEL_FLAG: StringName = &"Repel"

## Seconds the Itemfinder takes to turn towards what it found, and per quarter turn when it is standing on top of it.
const DETECTOR_TURN_SECONDS: float = 0.3
const DETECTOR_SPIN_SECONDS: float = 0.2

## Shows one line of text to the player, as `func(text: String) -> void`.

var narrate: Callable = Callable()

## Puts a question to the player and returns whether they agreed, as `func(question: String) -> bool`.

var confirm: Callable = Callable()

## Creates a handler that uses the overworld message window.
static func for_field() -> FieldItemEffects:
	var handler: FieldItemEffects = FieldItemEffects.new()
	handler.narrate = func(text: String) -> void:
		await Field.say(text)
	handler.confirm = func(question: String) -> bool:
		return await Field.confirm(question)
	return handler

## Returns whether [param item_id] can be used in the field.
static func handles(item_id: StringName) -> bool:
	if REPEL_STEPS.has(item_id) or FLUTE_STEPS.has(item_id):
		return true
	if BICYCLES.has(item_id) or ITEM_DETECTORS.has(item_id):
		return true
	if FieldMoves.is_rod(item_id):
		return true
	return item_id in [
		&"ESCAPEROPE", &"HONEY", &"SACREDASH", &"COINCASE", EXP_ALL_ON, EXP_ALL_OFF,
		POKE_RADAR, GameSettings.data.town_map_item,
	]

## `true` when using [param item_id] has to wait for the bag to close.
static func needs_the_map(item_id: StringName) -> bool:
	if BICYCLES.has(item_id) or ITEM_DETECTORS.has(item_id):
		return true
	if FieldMoves.is_rod(item_id):
		return true
	return item_id in [&"ESCAPEROPE", &"HONEY", POKE_RADAR, GameSettings.data.town_map_item]


# === From The Bag ===

## Uses [param item_id] with the bag still open.
func use_from_bag(item_id: StringName) -> Outcome:
	var record: ItemData = Database.item(item_id)
	if record == null:
		return Outcome.NOT_USED
	if REPEL_STEPS.has(item_id):
		return Outcome.USED if await _use_repel(record) else Outcome.NOT_USED
	if FLUTE_STEPS.has(item_id):
		await _use_flute(record)
		return Outcome.USED
	if BICYCLES.has(item_id):
		return Outcome.ON_THE_MAP if await _can_use_bicycle() else Outcome.NOT_USED
	if ITEM_DETECTORS.has(item_id):
		return Outcome.ON_THE_MAP
	if item_id == POKE_RADAR:
		# The grass it shakes is the grass the bag is drawn over, so the check is made here and the shaking waits for the map.
		return Outcome.ON_THE_MAP if await PokeRadar.can_use(narrate) else Outcome.NOT_USED
	if FieldMoves.is_rod(item_id):
		return Outcome.ON_THE_MAP if await _can_fish_here() else Outcome.NOT_USED
	if item_id == GameSettings.data.town_map_item:
		return await _open_town_map()
	match item_id:
		&"ESCAPEROPE":
			return Outcome.ON_THE_MAP if await _can_escape() else Outcome.NOT_USED
		&"HONEY":
			return Outcome.ON_THE_MAP
		&"SACREDASH":
			return Outcome.USED if await _use_sacred_ash() else Outcome.NOT_USED
		&"COINCASE":
			await _say(Loc.line("Coins: {coins}", {"coins": _coins()}))
			return Outcome.USED
		EXP_ALL_ON, EXP_ALL_OFF:
			await _toggle_exp_all(item_id)
			return Outcome.USED
	# Unknown field items get the usual "Can't use that here" message.
	await _say("Can't use that here.")
	return Outcome.NOT_USED


# === On The Map ===

## Uses [param item_id] with the map in front of the player.
func use_in_field(item_id: StringName) -> bool:
	var record: ItemData = Database.item(item_id)
	if record == null:
		return false
	if BICYCLES.has(item_id):
		return await toggle_bicycle()
	if ITEM_DETECTORS.has(item_id):
		return await _search_for_hidden_items(record)
	if item_id == POKE_RADAR:
		return await PokeRadar.use(narrate)
	if FieldMoves.is_rod(item_id):
		if not await _can_fish_here():
			return false
		await FieldMoves.fish(item_id)
		return true
	if item_id == GameSettings.data.town_map_item:
		return await _fly_to_chosen_destination()
	match item_id:
		&"ESCAPEROPE":
			return await _use_escape_rope(record)
		&"HONEY":
			await _used_message(record)
			await FieldMoves.sweet_scent()
			return true
	# Handle items that do not need the map the same way as the bag.
	return await use_from_bag(item_id) == Outcome.USED


# === Repels ===

## Starts a Repel.
func _use_repel(record: ItemData) -> bool:
	if GameState.repel_steps > 0:
		await _say("But a repellent's effect still lingers from earlier.")
		return false
	AudioManager.play_se("Repel")
	GameState.stats.repel_count += 1
	await _used_message(record)
	# Repel checks the party leader each step, so there is no leader to save here.
	GameState.repel_steps = int(REPEL_STEPS[record.id])
	return true

## Offers another Repel now that the last one has worn off, which is the prompt the games put up on the step it runs out.
func offer_another_repel() -> StringName:
	var carried: StringName = _best_repel_carried()
	if carried == &"":
		await _say("The repellent's effect wore off!")
		return &""
	var record: ItemData = Database.item(carried)
	if record == null or not confirm.is_valid():
		await _say("The repellent's effect wore off!")
		return &""
	var agreed: bool = await confirm.call(Loc.line(
		"The repellent's effect wore off!\nWould you like to use another {item}?",
		{"item": record.get_translated_portion_name()}
	))
	if not agreed:
		return &""
	if not await _use_repel(record):
		return &""
	if record.consumable:
		GameState.bag.remove_item(carried, 1)
	return carried

## The strongest Repel in the bag, or nothing when there is none.
func _best_repel_carried() -> StringName:
	var best: StringName = &""
	var best_steps: int = 0
	for item_id: StringName in GameState.bag.all_item_ids():
		var record: ItemData = Database.item(item_id)
		if record == null or not record.has_flag(REPEL_FLAG):
			continue
		var steps: int = int(REPEL_STEPS.get(item_id, 0))
		if steps > best_steps:
			best = item_id
			best_steps = steps
	return best


# === Flutes ===

## Sets encounter rates and levels for the Black or White Flute.
func _use_flute(record: ItemData) -> void:
	var steps: int = int(FLUTE_STEPS[record.id])
	await _used_message(record)
	match record.id:
		&"BLACKFLUTE":
			GameState.lower_encounter_steps = steps
			GameState.higher_encounter_steps = 0
			GameState.higher_level_steps = steps
			GameState.lower_level_steps = 0
			await _say("The likelihood of encountering Pokemon decreased!")
		&"WHITEFLUTE":
			GameState.higher_encounter_steps = steps
			GameState.lower_encounter_steps = 0
			GameState.lower_level_steps = steps
			GameState.higher_level_steps = 0
			await _say("The likelihood of encountering Pokemon increased!")


# === Bicycle ===

## `true` when the player could get on or off a bike where they are standing, and says why not when they could not.
func _can_use_bicycle() -> bool:
	if GameState.is_surfing() or GameState.is_diving():
		await _say("Can't use that here.")
		return false
	var metadata: MapMetadataData = GameState.current_map_metadata()
	if GameState.is_cycling():
		if metadata != null and metadata.always_bicycle:
			await _say("You can't dismount your Bike here.")
			return false
		return true
	var terrain: TerrainTagData = GameState.current_terrain()
	if terrain != null and (terrain.must_walk or terrain.must_walk_or_run):
		await _say("Can't use that here.")
		return false
	if metadata == null or (not metadata.can_bicycle and not metadata.outdoor_map):
		await _say("Can't use that here.")
		return false
	return true

## Gets the player on or off the bike, whichever they are not currently doing.
func toggle_bicycle() -> bool:
	if not await _can_use_bicycle():
		return false
	if GameState.is_cycling():
		dismount_bicycle()
		return true
	mount_bicycle()
	return true

## Starts cycling and plays the bike theme over the map music.
static func mount_bicycle() -> void:
	if GameState.is_cycling():
		return
	GameState.movement_state = GameState.MovementState.CYCLING
	GameState.stats.cycle_count += 1
	_refresh_player_sprite()
	AudioManager.play_se("Bicycle")
	AudioManager.push_bgm_position()
	var metadata: MetadataData = Database.metadata()
	if metadata != null and not metadata.bicycle_bgm.is_empty():
		AudioManager.play_bgm(metadata.bicycle_bgm, 1.0, 1.0, true)

## Takes the player off the bike and hands the map its music back.
static func dismount_bicycle(keep_music: bool = false) -> void:
	if not GameState.is_cycling():
		return
	GameState.movement_state = GameState.MovementState.WALKING
	_refresh_player_sprite()
	if keep_music:
		AudioManager.drop_bgm_position()
		return
	AudioManager.pop_bgm_position()

## Matches the bike state to the new map.
static func settle_bicycle_for_map() -> void:
	var metadata: MapMetadataData = GameState.current_map_metadata()
	if metadata != null and metadata.always_bicycle:
		mount_bicycle()
		return
	if not GameState.is_cycling():
		return
	if metadata == null or not (metadata.can_bicycle or metadata.outdoor_map):
		dismount_bicycle(true)


# === Escape Rope ===

## `true` when there is somewhere to escape to, and says so when there is not.
func _can_escape() -> bool:
	if GameState.has_escape_point():
		return true
	await _say("Can't use that here.")
	return false

## Returns the player to the cave entrance and clears the escape point.
func _use_escape_rope(record: ItemData) -> bool:
	if not await _can_escape():
		return false
	await _used_message(record)
	return await escape_to_entrance()

## The warp itself, without the item wrapped round it.
static func escape_to_entrance() -> bool:
	var field: MapController = Field.controller()
	if field == null or not GameState.has_escape_point():
		return false
	# Copy the point before clearing it; both references use the same array.
	var point: Array[int] = GameState.escape_point.duplicate()
	var facing: int = point[3] if point.size() >= 4 else GridCharacter.Direction.DOWN
	GameState.clear_escape_point()
	# A bike does not survive a warp out of a cave, because the map the player lands on may be one no bike belongs on.
	dismount_bicycle(true)
	await field.warp_to_map_id(
		point[0], Vector2i(point[1], point[2]), facing, true, MapController.NO_WALK)
	return true


# === Sacred Ash ===

## Revives and fully heals every fainted Pokemon in the party.
func _use_sacred_ash() -> bool:
	if GameState.party.is_empty():
		await _say("There is no Pokemon.")
		return false
	var revived: int = 0
	for pkmn: Pokemon in GameState.party.members:
		if not pkmn.is_fainted():
			continue
		pkmn.heal()
		revived += 1
		await _say(Loc.line("{pokemon}'s HP was restored.", {"pokemon": pkmn.display_name()}))
	if revived == 0:
		await _say("It won't have any effect.")
		return false
	return true


# === Exp All ===

## Swaps the Exp Share key item for its opposite state, which is how the games show a toggle in a bag that has no toggles.
func _toggle_exp_all(item_id: StringName) -> void:
	var turning_on: bool = item_id == EXP_ALL_OFF
	var replacement: StringName = EXP_ALL_ON if turning_on else EXP_ALL_OFF
	if Database.item(replacement) == null:
		return
	GameState.bag.remove_item(item_id, 1)
	GameState.bag.add_item(replacement, 1)
	await _say(
		"The Exp Share was turned on." if turning_on else "The Exp Share was turned off."
	)


# === Town Map ===

## Opens the region map and saves the chosen Fly destination.
func _open_town_map() -> Outcome:
	var scene: PackedScene = load(TownMapScreen.SCENE_PATH)
	if scene == null:
		push_warning("FieldItemEffects: %s is missing." % TownMapScreen.SCENE_PATH)
		return Outcome.NOT_USED
	var chosen: Variant = await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(TownMapScreen.Mode.PLAYER)
	)
	if not (chosen is TownMapPoint):
		return Outcome.NOT_USED
	GameState.fly_destination = chosen as TownMapPoint
	return Outcome.ON_THE_MAP

## Takes the flight the town map was closed on.
func _fly_to_chosen_destination() -> bool:
	var destination: TownMapPoint = GameState.fly_destination
	GameState.fly_destination = null
	if destination == null:
		return false
	await FieldMoves.fly_to(destination)
	return true


# === Itemfinder ===

## Points the Itemfinder at the nearest hidden item, or says there is nothing about.
func _search_for_hidden_items(record: ItemData) -> bool:
	var field: MapController = Field.controller()
	if field == null:
		return false
	GameState.stats.itemfinder_count += 1
	AudioManager.play_se("Itemfinder")
	var here: Vector2i = field.player.world_cell()
	var found: MapEvent = HiddenItemEvent.closest_to(field, here)
	if found == null:
		await _say("... \\wt[10]... \\wt[10]... \\wt[10]... \\wt[10]Nope! There's no response.")
		return true
	var there: Vector2i = found.world_cell()
	if there == here:
		await _spin_on_the_spot(field.player)
		await _say(Loc.line(
			"The {item}'s indicating something right underfoot!",
			{"item": record.get_translated_portion_name()}
		))
		return true
	field.player.turn(GridCharacter.direction_towards(here, there))
	await Field.wait(DETECTOR_TURN_SECONDS)
	await _say(Loc.line(
		"Huh? The {item}'s responding!", {"item": record.get_translated_portion_name()}
	))
	await _say("There's an item buried around here!")
	return true

## Turns the player all the way round, which is what the detector does when the item is under their feet.
func _spin_on_the_spot(character: GridCharacter) -> void:
	const TURNS: Array[GridCharacter.Direction] = [
		GridCharacter.Direction.LEFT, GridCharacter.Direction.UP,
		GridCharacter.Direction.RIGHT, GridCharacter.Direction.DOWN,
	]
	for direction: GridCharacter.Direction in TURNS:
		await Field.wait(DETECTOR_SPIN_SECONDS)
		character.turn(direction)
	await Field.wait(DETECTOR_TURN_SECONDS)


# === Fishing ===

## `true` when there is water in front of the player to cast into, and says so when there is not.
func _can_fish_here() -> bool:
	var field: MapController = Field.controller()
	if field == null:
		return false
	var ahead: Vector2i = field.player.tile_ahead()
	var terrain: TerrainTagData = field.terrain_at(
		field.player.tile_position if GameState.is_surfing() else ahead)
	if terrain == null or not terrain.can_fish:
		await _say("Can't use that here.")
		return false
	if not GameState.is_surfing() and not field.player.can_enter(ahead, field.player.facing):
		await _say("Can't use that here.")
		return false
	return true


# === Internals ===

static func _refresh_player_sprite() -> void:
	var field: MapController = Field.controller()
	if field != null and field.player != null:
		field.player.refresh_charset()

## "You used a Repel." — the line every consumable field item announces itself with.
func _used_message(record: ItemData) -> void:
	var item_name: String = record.get_translated_portion_name()
	await _say(Loc.line(
		"You used {article} {item}.",
		{"article": "an" if _starts_with_vowel(item_name) else "a", "item": item_name}
	))

static func _starts_with_vowel(text: String) -> bool:
	if text.is_empty():
		return false
	return "AEIOUaeiou".contains(text[0])

func _coins() -> int:
	return GameState.player.coins if GameState.player != null else 0

func _say(text: String) -> void:
	if narrate.is_valid():
		await narrate.call(text)
