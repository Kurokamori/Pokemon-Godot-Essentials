extends Node
## The game session being played, registered as `GameState` autoload
##
## This holds the player and everything carried
## Holds the switches and variables used by events, and the current map context.

## Emitted on session start -- either new game or loaded save game
signal session_started()

## Emitted on the change of any switch -- allows events to react without constant polling.
signal switch_changed(switch_id: int, value: bool)

## Emitted on the change of a game variable -- allows events to react without constant polling.
signal variable_changed(variable_id: int, value: Variant)

## Emitted after the player finishes taking a step.
signal step_taken()

## Emitted when the final step of repel is taken, allowing the game to offer a new one.
## Since this is a question and must stop gameplay, it is unique from [signal step_taken]
signal repel_wore_off()

## Emitted on map change
signal map_changed(new_map_id: int)

## Emitted on the timer's change (start, stop, tick a whole second) to prevent polling
signal timer_changed(seconds_left: float)

## Emitted the moment the timer reaches zero.
signal timer_expired()

enum MovementState {
	WALKING = 0,
	CYCLING = 1,
	SURFING = 2,
	DIVING = 3,
}

var player: Player = null
var party: PokemonParty = null
var bag: PokemonBag = null
var storage: PokemonStorage = null
## Items in the PC's item storage setting.
var item_storage: PokemonBag = null

## The running tally originally kept on `$stats`.
var stats: GameStats = null

## The two Day Care slots and their contents.
var day_care: DayCare = null

## Everybody registered in the Pokegear.
var phone: PhoneBook = null

## The Triple Triad cards the player has collected.
var triads: TriadStorage = null

## Every team that has been inducted into the Hall of Fame, newest last.
var hall_of_fame: HallOfFame = null

## The nine sets of the Purify Chamber and the Pokemon in them.
var purify_chamber: PurifyChamber = null

## Letters kept in the PC.
var mailbox: Mailbox = null

@export_group("Map Context")
var map_id: int = 0
var map_position: Vector2i = Vector2i.ZERO

## Facing direction, following the RPG Maker convention: 
## 2 down, 4 left, 6 right, 8 up.
var map_direction: int = 2

var movement_state: MovementState = MovementState.WALKING

## Encounter table version currently in use for this map.
var encounter_version: int = 0

## `[map_id, x, y, direction]`
## Where an Escape Rope or Dig puts the player down
var escape_point: Array[int] = []

## `[map_id, x, y, direction]`
## The last Pokemon Center the player healed at
## Where teleport and blackout send them, blank until first heal -- defaults to player's house
var healing_spot: Array[int] = []

## Set to `true` when flash is used.
## It survives changing between dark maps and is dropped upon reaching a lit one.
var flash_used: bool = false

## `true` once Strength has been used on this map
## per-map flag, that is reset upon map change.
var strength_used: bool = false

@export_group("Event State")
var switches: Dictionary = {}
var variables: Dictionary = {}

## Self-switches keyed by `"map_id:event_id:switch"`.
var self_switches: Dictionary = {}

## Maps the player has set foot on, as `map_id` to `true`.
var visited_maps: Dictionary = {}

## Temp switches, keyed the same way as [member self_switches].
## Per-map. Cleared upon leaving and returning.
var temp_switches: Dictionary = {}

@export_group("Field Effects")
## Steps remaining on the active Repel, or `0`.
var repel_steps: int = 0

## Steps remaining on a Black Flute, which makes encounters rarer.
var lower_encounter_steps: int = 0

## Steps remaining on a White Flute, which makes encounters more common.
var higher_encounter_steps: int = 0

## Steps remaining on the effect that lowers the level of wild Pokemon.
var lower_level_steps: int = 0

## Steps remaining on the effect that raises the level of wild Pokemon.
var higher_level_steps: int = 0

## Steps since the last wild encounter
## This is for debugging and statistics, not actual grace period encounters.
var steps_since_encounter: int = 0

## The calendar day the Pokerus counters were last lowered on, as `YYYYMMDD`;
## `0` before any day has been noticed.
var pokerus_day: int = 0

## `true` while an event has switched wild encounters off.
var encounters_disabled: bool = false

## Set for one encounter by a script that wants the next wild battle to be a single one whatever the terrain says. 
## Cleared as soon as it is read.
var force_single_battle: bool = false

## A trainer walking with the player, whose presence makes every wild battle a double battle.
## `null` the rest of the time.
var partner_trainer: TrainerData = null

## Berry plants keyed by `"map_id:event_id"`.
var berry_plants: Dictionary = {}

## The Pokemon roaming the region, keyed by [RoamingSpeciesData] id:
##  where each one is, the Pokemon it is met as, and whether it has been caught or beaten.
var roaming_pokemon: Dictionary = {}

## `true` once a roamer has been met on the map the player is standing on, so
## one that got away is not met again on the next step. Cleared on every map change.
var met_roamer_on_this_map: bool = false

## The roamer the encounter about to start belongs to, or empty for an ordinary wild battle. 
var pending_roamer: StringName = &""

## Species defeated in the current Poke Radar chain.
var radar_chain: Dictionary = {}

## Temp variable.
## Where the player has chosen to fly on the town map.
## Held until the menu closes and player flies, never saved.
var fly_destination: TownMapPoint = null

## The Safari Zone trip in progress, or `null`.
var safari: SafariSession = null

## The Bug-Catching Contest entry in progress, or `null`.
var bug_contest: BugContestSession = null

## The Battle Frontier record, kept by facility. 
## The streak in one outlasts a single run, so this survives between visits.
var challenges: Dictionary = {}

@export_group("Shops")
## Buying prices an event has changed with `setPrice`, keyed by item id.
var mart_prices: Dictionary = {}

## Selling prices an event has changed, keyed by item id.
var mart_sell_prices: Dictionary = {}

@export_group("Scripted State")
## Weather an event has asked for, which overrides the map's own.
## Blank leaves the normal weather in place.
var weather_override: StringName = &""

## How heavy the overridden weather is, from 0 to 9.
var weather_power: int = 0

## The screen tone an event has set, in RPG Maker's numbers: red, green and blue
## from `-255` to `255`, and the greying in the fourth from `0` to `255`.
var screen_tone: Vector4i = Vector4i.ZERO

## Which area of a generated dungeon the player is in
## Names the [DungeonParametersData] record [RandomDungeon] builds a floor from.
var dungeon_area: StringName = &""

## Which variant of that area is in play, for dungeons that change shape as the
## story moves on. 
##`0` uses the area's own record.
var dungeon_version: int = 0

## A seed an event has queued up for the next dungeon floor, so a floor can be
## made to order. Used once and cleared; 
## `0` leaves it to chance.
var dungeon_rng_seed: int = 0

## The seed the floor the player is standing in was built from, and the map it belongs to. 
## Saved, so that save load returns to the same location and dungeon design.
var dungeon_active_seed: int = 0
var dungeon_active_map_id: int = 0

## The battle just fought, kept so the player can watch it back. 
## `null` until one has been recorded.
var last_battle_record: BattleRecording = null

## What the party did in the battle just fought, which is what the evolution check afterwards reads.
## Never saved
var battle_tally: BattleTally = null

## Eggs whose counters ran out on the last step and which have yet to hatch.
var hatching_eggs: Array[Pokemon] = []

## Purify Chamber sets whose Shadow Pokemon became ready on the last step.
var purified_sets_ready: Array[int] = []

## Shadow Pokemon whose heart opened a stage on the last step.
var opened_hearts: Array[Pokemon] = []

## Lines an event has queued up for a scripted duel.
var speeches: Array = []

## Mystery Gifts the player has already claimed, by id.
var claimed_mystery_gifts: Array = []

## `true` once the end credits have rolled all the way through to allow future viewings to skip.
var credits_played: bool = false

## Seconds left on RPG Maker's timer, counted down while [member timer_running] is set.
var timer_seconds_left: float = 0.0

## `true` while the timer is counting down.
var timer_running: bool = false

## The battleback an event has asked for with Change Map Settings to override the default map settings.
var battleback_override: String = ""

var _session_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset()


func _process(delta: float) -> void:
	if _session_active and player != null:
		player.play_time_seconds += delta
	_advance_timer(delta)


## Resets the session to an empty state.
func reset() -> void:
	player = null
	party = PokemonParty.new()
	bag = PokemonBag.new()
	storage = PokemonStorage.new()
	item_storage = PokemonBag.new()
	stats = GameStats.new()
	day_care = DayCare.new()
	phone = PhoneBook.new()
	triads = TriadStorage.new()
	hall_of_fame = HallOfFame.new()
	purify_chamber = PurifyChamber.new()
	mailbox = Mailbox.new()
	purified_sets_ready.clear()
	opened_hearts.clear()
	map_id = 0
	map_position = Vector2i.ZERO
	map_direction = 2
	movement_state = MovementState.WALKING
	encounter_version = 0
	escape_point.clear()
	healing_spot.clear()
	flash_used = false
	strength_used = false
	switches.clear()
	variables.clear()
	self_switches.clear()
	temp_switches.clear()
	visited_maps.clear()
	repel_steps = 0
	lower_encounter_steps = 0
	higher_encounter_steps = 0
	lower_level_steps = 0
	higher_level_steps = 0
	steps_since_encounter = 0
	pokerus_day = 0
	encounters_disabled = false
	force_single_battle = false
	partner_trainer = null
	berry_plants.clear()
	roaming_pokemon.clear()
	met_roamer_on_this_map = false
	pending_roamer = &""
	radar_chain.clear()
	fly_destination = null
	safari = null
	bug_contest = null
	challenges.clear()
	mart_prices.clear()
	mart_sell_prices.clear()
	weather_override = &""
	weather_power = 0
	screen_tone = Vector4i.ZERO
	dungeon_area = &""
	dungeon_version = 0
	dungeon_rng_seed = 0
	dungeon_active_seed = 0
	dungeon_active_map_id = 0
	last_battle_record = null
	battle_tally = null
	hatching_eggs.clear()
	speeches.clear()
	claimed_mystery_gifts.clear()
	credits_played = false
	timer_seconds_left = 0.0
	timer_running = false
	battleback_override = ""
	_session_active = false


## Starts a fresh game for [param player_name].
func start_new_game(player_name: String, gender: PokemonOwner.Gender, character_id: int = 1) -> void:
	reset()
	player = Player.create(player_name, gender, character_id)
	var metadata: MetadataData = Database.metadata()
	if metadata != null:
		for item_id: StringName in metadata.start_item_storage:
			item_storage.add_item(item_id, 1)
		if metadata.home.size() >= 3:
			map_id = metadata.home[0]
			map_position = Vector2i(metadata.home[1], metadata.home[2])
			if metadata.home.size() >= 4:
				map_direction = metadata.home[3]
	mark_map_visited(map_id)
	pokerus_day = _calendar_day()
	stats.begin_session()
	_session_active = true
	session_started.emit()


func has_session() -> bool:
	return player != null


# === Switches and Variables ===

func get_switch(switch_id: int) -> bool:
	return bool(switches.get(switch_id, false))


func set_switch(switch_id: int, value: bool) -> void:
	if bool(switches.get(switch_id, false)) == value:
		return
	switches[switch_id] = value
	switch_changed.emit(switch_id, value)


func get_variable(variable_id: int) -> Variant:
	return variables.get(variable_id, 0)


func set_variable(variable_id: int, value: Variant) -> void:
	variables[variable_id] = value
	variable_changed.emit(variable_id, value)


func add_variable(variable_id: int, amount: int) -> void:
	set_variable(variable_id, int(get_variable(variable_id)) + amount)


## Self-switches are scoped to one event on one map. 
## [param event_key] is the event's number for imported events and its node name for events made by hand
func get_self_switch(for_map: int, event_key: String, switch: String) -> bool:
	return bool(self_switches.get("%d:%s:%s" % [for_map, event_key, switch], false))


func set_self_switch(for_map: int, event_key: String, switch: String, value: bool) -> void:
	self_switches["%d:%s:%s" % [for_map, event_key, switch]] = value


## Temporary self-switches, cleared on leaving the map.
## [param event_key] is the event's number for imported events and its node name for events made by hand
func get_temp_switch(for_map: int, event_key: String, switch: String) -> bool:
	return bool(temp_switches.get("%d:%s:%s" % [for_map, event_key, switch], false))


func set_temp_switch(for_map: int, event_key: String, switch: String, value: bool) -> void:
	temp_switches["%d:%s:%s" % [for_map, event_key, switch]] = value


# === Map Context ===

func current_map_metadata() -> MapMetadataData:
	return Database.map_metadata(map_id)


func map_has_flag(flag: StringName) -> bool:
	var metadata: MapMetadataData = current_map_metadata()
	return metadata != null and metadata.has_flag(flag)


func current_region() -> int:
	var metadata: MapMetadataData = current_map_metadata()
	if metadata != null and metadata.town_map_position.size() >= 1:
		return metadata.town_map_position[0]
	return GameSettings.data.default_region


func is_outdoors() -> bool:
	var metadata: MapMetadataData = current_map_metadata()
	return metadata != null and metadata.outdoor_map


func is_on_dark_map() -> bool:
	var metadata: MapMetadataData = current_map_metadata()
	return metadata != null and metadata.dark_map


func is_surfing() -> bool:
	return movement_state == MovementState.SURFING


func is_diving() -> bool:
	return movement_state == MovementState.DIVING


func is_cycling() -> bool:
	return movement_state == MovementState.CYCLING


## Id of the overworld [WeatherData] currently in effect.
##
## Weather an event has asked for wins over the map's own.
func current_weather() -> StringName:
	if weather_override != &"":
		return weather_override
	var metadata: MapMetadataData = current_map_metadata()
	if metadata != null and metadata.weather.size() >= 1:
		return StringName(metadata.weather[0])
	return &"None"


## How heavy the weather is, from 0 to 9 for overwriten weather.
func current_weather_power() -> int:
	if weather_override != &"":
		return weather_power
	var metadata: MapMetadataData = current_map_metadata()
	if metadata != null and metadata.weather.size() >= 2:
		return int(metadata.weather[1])
	return 0


## Asks for [param weather_id] whatever the map says. 
## An empty id, or a power of zero, returns the map its own weather back.
func set_weather_override(weather_id: StringName, power: int = 5) -> void:
	weather_override = weather_id if power > 0 else &""
	weather_power = clampi(power, 0, 9)


# === Timer ===

## Starts RPG Maker's timer at [param seconds], which is Control Timer. 
## Starting one that is already running replaces the time left instead of adding to it.
func start_timer(seconds: float) -> void:
	timer_seconds_left = maxf(seconds, 0.0)
	timer_running = timer_seconds_left > 0.0
	timer_changed.emit(timer_seconds_left)


## Stops the timer and takes it off screen, which is Control Timer's other half.
func stop_timer() -> void:
	timer_running = false
	timer_seconds_left = 0.0
	timer_changed.emit(0.0)


## Whole seconds left on the timer, which is what a display shows and what is read by scripts.
func timer_seconds() -> int:
	return ceili(timer_seconds_left) if timer_running else 0


func _advance_timer(delta: float) -> void:
	if not timer_running:
		return
	var before: int = timer_seconds()
	timer_seconds_left = maxf(timer_seconds_left - delta, 0.0)
	if timer_seconds_left <= 0.0:
		timer_running = false
		timer_changed.emit(0.0)
		timer_expired.emit()
		return
	if timer_seconds() != before:
		timer_changed.emit(timer_seconds_left)


## The berry patch belonging to event [param event_id] on [param for_map], made the first time it is requested.
func berry_patch(for_map: int, event_id: int) -> BerryPatch:
	var key: String = "%d:%d" % [for_map, event_id]
	var stored: Variant = berry_plants.get(key)
	if stored is BerryPatch:
		return stored
	var patch: BerryPatch = BerryPatch.from_dict(stored) if stored is Dictionary else BerryPatch.new()
	berry_plants[key] = patch
	return patch


## Id of the [EnvironmentData] a battle started here would use. Tiles win over map metadata.
func current_environment() -> StringName:
	var terrain: TerrainTagData = current_terrain()
	if terrain != null and not terrain.battle_environment.is_empty():
		return terrain.battle_environment
	var metadata: MapMetadataData = current_map_metadata()
	if metadata != null and not metadata.battle_environment.is_empty():
		return metadata.battle_environment
	return &"None"


## The terrain under the player, or `null` outside the overworld.
func current_terrain() -> TerrainTagData:
	var field: MapController = MapController.current
	if field == null or field.player == null:
		return null
	return field.terrain_at(field.player.tile_position)


func set_map(new_map_id: int, position: Vector2i, direction: int = -1) -> void:
	var changed: bool = new_map_id != map_id
	map_id = new_map_id
	map_position = position
	if direction > 0:
		map_direction = direction
	mark_map_visited(map_id)
	if changed:
		temp_switches.clear()
		strength_used = false
		if not is_on_dark_map():
			flash_used = false
		met_roamer_on_this_map = false
		PokeRadar.cancel()
		map_changed.emit(map_id)


## Records that the player has been to [param for_map_id]
## which is what makes its town map point a Fly destination.
func mark_map_visited(for_map_id: int) -> void:
	if for_map_id > 0:
		visited_maps[for_map_id] = true


func has_visited_map(for_map_id: int) -> bool:
	return bool(visited_maps.get(for_map_id, false))


# === Escape Point and Healing Spot ===

## Remembers the cell behind the player as the place an Escape Rope or Dig returns at.
func set_escape_point() -> void:
	var field: MapController = MapController.current
	if field == null or field.player == null:
		return
	var facing: GridCharacter.Direction = field.player.facing
	var behind: Vector2i = field.player.tile_position - Vector2i(
		GridCharacter.DIRECTION_VECTORS[facing])
	escape_point = [map_id, behind.x, behind.y, int(GridCharacter.opposite(facing))]


## Sets the escape point by hand, for an event that names the spot itself.
func set_escape_point_at(for_map_id: int, cell: Vector2i, facing: int) -> void:
	escape_point = [for_map_id, cell.x, cell.y, facing]


func clear_escape_point() -> void:
	escape_point.clear()


func has_escape_point() -> bool:
	return escape_point.size() >= 3


## Remembers where the player is standing as the spot Teleport returns to and a blackout sends them
func set_healing_spot() -> void:
	var field: MapController = MapController.current
	if field == null or field.player == null:
		healing_spot = [map_id, map_position.x, map_position.y, map_direction]
		return
	healing_spot = [
		map_id, field.player.tile_position.x, field.player.tile_position.y,
		int(field.player.facing),
	]


## Where a blackout or Teleport puts the player down
##
## A copy, not the list itself. The caller is about to warp the player, and a warp clears the escape point.
func respawn_destination() -> Array[int]:
	if healing_spot.size() >= 3:
		return healing_spot.duplicate()
	var metadata: MapMetadataData = current_map_metadata()
	if metadata != null and metadata.teleport_destination.size() >= 3:
		return metadata.teleport_destination.duplicate()
	var global_metadata: MetadataData = Database.metadata()
	if global_metadata != null and global_metadata.home.size() >= 3:
		return global_metadata.home.duplicate()
	return []


# === Stepping ===

## Advances everything that happens once per tile walked.
func take_step() -> void:
	if player == null:
		return
	player.steps_taken += 1
	steps_since_encounter += 1
	# A step across ice is not one the player chose to take, so it does not spend a Repel.
	var terrain: TerrainTagData = current_terrain()
	var slid: bool = terrain != null and terrain.ice
	if repel_steps > 0 and not slid:
		repel_steps -= 1
		if repel_steps == 0:
			repel_wore_off.emit()
	lower_encounter_steps = maxi(lower_encounter_steps - 1, 0)
	higher_encounter_steps = maxi(higher_encounter_steps - 1, 0)
	lower_level_steps = maxi(lower_level_steps - 1, 0)
	higher_level_steps = maxi(higher_level_steps - 1, 0)
	# A Safari trip and a contest are both measured in steps rather than in time, so walking is what runs them down.
	if safari != null and safari.active:
		safari.take_step()
	if bug_contest != null and bug_contest.active:
		bug_contest.take_step()
	if player.steps_taken % GameSettings.data.happiness_steps == 0:
		for pkmn: Pokemon in party.members:
			if not pkmn.is_egg():
				pkmn.change_happiness(&"walking")
	# The Poke Radar's battery recharges as the player walks, and a chain broken by walking out of the grass
	PokeRadar.take_step()
	# Pokemon left at the Day Care gain Exp from the player's walking, and the pair's chances of an Egg are rolled as the steps go by.
	day_care.take_step()
	# An Egg in the party gets closer to hatching per-step. Ready eggs wait here for their turn.
	for ready_egg: Pokemon in party.take_step():
		if not hatching_eggs.has(ready_egg):
			hatching_eggs.append(ready_egg)
	# The Purify Chamber works on the Shadow Pokemon in it for every step walked.
	# A heart that opens all the way is announced, which is a message the walk has to stop for, so it queues here the way a hatching Egg does.
	for ready_set: int in purify_chamber.take_step():
		if not purified_sets_ready.has(ready_set):
			purified_sets_ready.append(ready_set)
	# A Shadow Pokemon walking with the player has its heart worn down too.
	for opened: Pokemon in ShadowPokemon.walk_party(party):
		if not opened_hearts.has(opened):
			opened_hearts.append(opened)
	_record_distance_walked(slid)
	advance_pokerus_days()
	step_taken.emit()


## Takes the Eggs that are ready to hatch off the queue, leaving it empty.
func take_hatching_eggs() -> Array[Pokemon]:
	var ready_eggs: Array[Pokemon] = hatching_eggs.duplicate()
	hatching_eggs.clear()
	return ready_eggs


## Takes the Purify Chamber sets that just became ready off the queue, leaving it empty.
func take_ready_purify_sets() -> Array[int]:
	var ready_sets: Array[int] = purified_sets_ready.duplicate()
	purified_sets_ready.clear()
	return ready_sets


## Takes the Shadow Pokemon whose hearts opened a stage off the queue, leaving it empty.
func take_opened_hearts() -> Array[Pokemon]:
	var opened: Array[Pokemon] = opened_hearts.duplicate()
	opened_hearts.clear()
	return opened


## Takes a day off every infected Pokemon's Pokerus counter if the calendar day has changed since the last time this was asked.
## 
## Called on every step and whenever a session starts, so the day can change without the player having to walk.
##
## One day comes off per *noticed* change rather than per elapsed day, meaning that 
## a notable absense of time still only costs one day of Pokerus.
func advance_pokerus_days() -> void:
	var today: int = _calendar_day()
	if pokerus_day == today:
		return
	if pokerus_day != 0:
		Pokerus.lower_counts(party)
	pokerus_day = today


## Today as `YYYYMMDD`, which compares as a number and is stable across a save.
func _calendar_day() -> int:
	var now: Dictionary = TimeOfDay.now()
	return int(now["year"]) * 10000 + int(now["month"]) * 100 + int(now["day"])


## Adds this step to whichever distance counter the player is covering it by.
func _record_distance_walked(slid: bool) -> void:
	if slid:
		stats.distance_slid_on_ice += 1
		return
	match movement_state:
		MovementState.CYCLING: stats.distance_cycled += 1
		MovementState.SURFING, MovementState.DIVING: stats.distance_surfed += 1
		_: stats.distance_walked += 1


func is_repel_active() -> bool:
	return repel_steps > 0


# === Serialisation === 

func to_dict() -> Dictionary:
	var safari_data: Variant = null
	if safari != null:
		safari_data = safari.to_dict()
	var bug_contest_data: Variant = null
	if bug_contest != null:
		bug_contest_data = bug_contest.to_dict()
	var last_battle_data: Variant = null
	if last_battle_record != null:
		last_battle_data = last_battle_record.to_dict()
	return {
		"player": player.to_dict() if player != null else {},
		"party": party.to_array(),
		"bag": bag.to_dict(),
		"storage": storage.to_dict(),
		"item_storage": item_storage.to_dict(),
		"mailbox": mailbox.to_dict(),
		"map_id": map_id,
		"map_position": [map_position.x, map_position.y],
		"map_direction": map_direction,
		"movement_state": int(movement_state),
		"encounter_version": encounter_version,
		"escape_point": escape_point.duplicate(),
		"healing_spot": healing_spot.duplicate(),
		"flash_used": flash_used,
		"strength_used": strength_used,
		"switches": _int_keys(switches),
		"variables": _int_keys(variables),
		"self_switches": self_switches.duplicate(true),
		"visited_maps": _int_keys(visited_maps),
		"repel_steps": repel_steps,
		"lower_encounter_steps": lower_encounter_steps,
		"higher_encounter_steps": higher_encounter_steps,
		"lower_level_steps": lower_level_steps,
		"higher_level_steps": higher_level_steps,
		"steps_since_encounter": steps_since_encounter,
		"pokerus_day": pokerus_day,
		"encounters_disabled": encounters_disabled,
		"partner_trainer": String(partner_trainer.id) if partner_trainer != null else "",
		"berry_plants": _berry_plants_to_dict(),
		"roaming_pokemon": RoamingPokemon.to_dict(),
		"radar_chain": radar_chain.duplicate(true),
		"safari": safari_data,
		"bug_contest": bug_contest_data,
		"challenges": _challenges_to_dict(),
		"stats": stats.to_dict(),
		"day_care": day_care.to_dict(),
		"phone": phone.to_dict(),
		"triads": triads.to_array(),
		"hall_of_fame": hall_of_fame.to_dict(),
		"purify_chamber": purify_chamber.to_dict(),
		"marts": MartStock.to_dict(),
		"weather_override": String(weather_override),
		"weather_power": weather_power,
		"screen_tone": [screen_tone.x, screen_tone.y, screen_tone.z, screen_tone.w],
		"dungeon_area": String(dungeon_area),
		"dungeon_version": dungeon_version,
		"dungeon_rng_seed": dungeon_rng_seed,
		"dungeon_active_seed": dungeon_active_seed,
		"dungeon_active_map_id": dungeon_active_map_id,
		"last_battle_record": last_battle_data,
		"claimed_mystery_gifts": claimed_mystery_gifts.duplicate(),
		"credits_played": credits_played,
		"timer_seconds_left": timer_seconds_left,
		"timer_running": timer_running,
		"battleback_override": battleback_override,
		"rng_seed": RNG.get_seed(),
	}


func from_dict(source: Dictionary) -> void:
	reset()
	player = Player.new()
	player.from_dict(source.get("player", {}))
	party.from_array(source.get("party", []))
	bag.from_dict(source.get("bag", {}))
	storage.from_dict(source.get("storage", {}))
	item_storage.from_dict(source.get("item_storage", {}))
	mailbox.from_dict(source.get("mailbox", {}))
	map_id = int(source.get("map_id", 0))
	var stored_position: Array = source.get("map_position", [0, 0])
	map_position = Vector2i(int(stored_position[0]), int(stored_position[1]))
	map_direction = int(source.get("map_direction", 2))
	movement_state = int(source.get("movement_state", 0)) as MovementState
	encounter_version = int(source.get("encounter_version", 0))
	escape_point = _int_list(source.get("escape_point", []))
	healing_spot = _int_list(source.get("healing_spot", []))
	flash_used = bool(source.get("flash_used", false))
	strength_used = bool(source.get("strength_used", false))
	switches = _restore_int_keys(source.get("switches", {}))
	variables = _restore_int_keys(source.get("variables", {}))
	self_switches = source.get("self_switches", {}).duplicate(true)
	visited_maps = _restore_int_keys(source.get("visited_maps", {}))
	mark_map_visited(map_id)
	repel_steps = int(source.get("repel_steps", 0))
	lower_encounter_steps = int(source.get("lower_encounter_steps", 0))
	higher_encounter_steps = int(source.get("higher_encounter_steps", 0))
	lower_level_steps = int(source.get("lower_level_steps", 0))
	higher_level_steps = int(source.get("higher_level_steps", 0))
	steps_since_encounter = int(source.get("steps_since_encounter", 0))
	pokerus_day = int(source.get("pokerus_day", 0))
	encounters_disabled = bool(source.get("encounters_disabled", false))
	var saved_partner: String = str(source.get("partner_trainer", ""))
	if not saved_partner.is_empty():
		partner_trainer = Database.get_record(
			Database.CATEGORY_TRAINERS, StringName(saved_partner)) as TrainerData
	_berry_plants_from_dict(source.get("berry_plants", {}))
	RoamingPokemon.from_dict(source.get("roaming_pokemon", {}))
	radar_chain = source.get("radar_chain", {}).duplicate(true)
	stats.from_dict(source.get("stats", {}))
	day_care.from_dict(source.get("day_care", {}))
	phone.from_dict(source.get("phone", {}))
	triads.from_array(source.get("triads", []))
	hall_of_fame.from_dict(source.get("hall_of_fame", {}))
	purify_chamber.from_dict(source.get("purify_chamber", {}))
	MartStock.from_dict(source.get("marts", {}))
	weather_override = StringName(source.get("weather_override", ""))
	weather_power = int(source.get("weather_power", 0))
	var stored_tone: Array = source.get("screen_tone", [])
	if stored_tone.size() >= 4:
		screen_tone = Vector4i(
			int(stored_tone[0]), int(stored_tone[1]), int(stored_tone[2]), int(stored_tone[3])
		)
	dungeon_area = StringName(source.get("dungeon_area", ""))
	dungeon_version = int(source.get("dungeon_version", 0))
	dungeon_rng_seed = int(source.get("dungeon_rng_seed", 0))
	dungeon_active_seed = int(source.get("dungeon_active_seed", 0))
	dungeon_active_map_id = int(source.get("dungeon_active_map_id", 0))
	var saved_battle: Variant = source.get("last_battle_record")
	if saved_battle is Dictionary:
		last_battle_record = BattleRecording.from_dict(saved_battle)
	claimed_mystery_gifts = source.get("claimed_mystery_gifts", []).duplicate()
	credits_played = bool(source.get("credits_played", false))
	timer_seconds_left = float(source.get("timer_seconds_left", 0.0))
	timer_running = bool(source.get("timer_running", false))
	battleback_override = String(source.get("battleback_override", ""))
	var saved_safari: Variant = source.get("safari")
	if typeof(saved_safari) == TYPE_DICTIONARY:
		safari = SafariSession.new()
		safari.from_dict(saved_safari as Dictionary)
	var saved_contest: Variant = source.get("bug_contest")
	if typeof(saved_contest) == TYPE_DICTIONARY:
		bug_contest = BugContestSession.new()
		bug_contest.from_dict(saved_contest as Dictionary)
	for facility: Variant in source.get("challenges", {}):
		var session: ChallengeSession = ChallengeSession.new()
		session.from_dict(source["challenges"][facility] as Dictionary)
		challenges[StringName(facility)] = session
	RNG.set_seed(int(source.get("rng_seed", 0)))
	_session_active = true
	# A save put down yesterday has a day to catch up on before the player takes
	# a step, so the day is noticed on the way in rather than on the way past.
	advance_pokerus_days()
	session_started.emit()


## Berry patches written out for the save file. They are held as [BerryPatch]  objects while the game is running
## This allows growth to be worked out on them while the game runs, and as plain dictionaries on disk.
func _berry_plants_to_dict() -> Dictionary:
	var saved: Dictionary = {}
	for key: Variant in berry_plants:
		var patch: Variant = berry_plants[key]
		saved[str(key)] = patch.to_dict() if patch is BerryPatch else patch
	return saved


func _berry_plants_from_dict(source: Dictionary) -> void:
	berry_plants.clear()
	for key: Variant in source:
		if source[key] is Dictionary:
			berry_plants[str(key)] = BerryPatch.from_dict(source[key])


func _challenges_to_dict() -> Dictionary:
	var saved: Dictionary = {}
	for facility: Variant in challenges:
		var session: ChallengeSession = challenges[facility]
		if session != null:
			saved[String(facility)] = session.to_dict()
	return saved


## The record at [param facility], made on the first visit. 
func challenge_record(facility: StringName) -> ChallengeSession:
	if not challenges.has(facility):
		challenges[facility] = ChallengeSession.new()
	return challenges[facility]


## A saved list of numbers read back as one. 
## JSON hands every number back as a float, so the coordinates a save carries have to be narrowed before they can be indexed with.
func _int_list(source: Variant) -> Array[int]:
	var result: Array[int] = []
	if not (source is Array):
		return result
	for entry: Variant in source:
		result.append(int(entry))
	return result


func _int_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		result[str(key)] = source[key]
	return result


func _restore_int_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		result[int(key)] = source[key]
	return result
