class_name FieldEffects
## Everything an event can do to how the world looks

## The effects layer, or null when we're not in the overworld.
static func screen() -> ScreenEffects:
	var overworld: Overworld = Overworld.current
	return overworld.screen_effects() if overworld != null else null

## The follower line behind the player, or null outside the overworld.
static func followers() -> FollowerTrain:
	var field: MapController = MapController.current
	return field.followers if field != null else null


# === Weather ===

## Brings on weather_id at power (0 off, 9 heaviest), easing in over seconds.
## It sticks until something changes it, even across a map transfer.
static func set_weather(weather_id: StringName, power: int = 5, seconds: float = 0.0) -> void:
	GameState.set_weather_override(weather_id, power)
	var layer: ScreenEffects = screen()
	if layer != null:
		layer.set_weather(weather_id, power, seconds)

## Goes back to the map's own weather.
static func clear_weather(seconds: float = 0.0) -> void:
	GameState.set_weather_override(&"", 0)
	var layer: ScreenEffects = screen()
	if layer != null:
		layer.set_weather(GameState.current_weather(), GameState.current_weather_power(), seconds)

## Redraws the weather the current map calls for.
static func refresh_weather() -> void:
	var layer: ScreenEffects = screen()
	if layer != null:
		layer.set_weather(GameState.current_weather(), GameState.current_weather_power())

## Set Weather by number.
## An unknown number clears the weather.
static func set_weather_number(number: int, power: int = 5, seconds: float = 0.0) -> void:
	var record: WeatherData = Database.weather_by_number(number)
	if record == null:
		push_warning("FieldEffects: there is no weather numbered %d." % number)
		clear_weather(seconds)
		return
	set_weather(record.id, power, seconds)


# === Tone ===

## (Awaited)
## Changes the screen tone over frames, in RPG Maker's numbers:
## red, green and blue from -255 to 255, grey from 0 to 255.
static func change_tone(red: int, green: int, blue: int, grey: int, frames: int) -> void:
	begin_tone_change(red, green, blue, grey, frames)
	if frames > 0:
		await Field.wait(float(frames) / ScreenEffects.FRAMES_PER_SECOND)

## (Instant)
## Changes the screen tone over frames, in RPG Maker's numbers:
## red, green and blue from -255 to 255, grey from 0 to 255.
static func begin_tone_change(red: int, green: int, blue: int, grey: int, frames: int) -> void:
	GameState.screen_tone = Vector4i(red, green, blue, grey)
	var layer: ScreenEffects = screen()
	if layer != null:
		layer.change_tone(red, green, blue, grey, frames)

## Puts the tone back to normal.
static func clear_tone(frames: int = 0) -> void:
	await change_tone(0, 0, 0, 0, frames)

## Redraws the saved tone, e.g. for a map loaded under an already-faded cutscene.
static func refresh_tone() -> void:
	var layer: ScreenEffects = screen()
	if layer == null:
		return
	var tone: Vector4i = GameState.screen_tone
	layer.change_tone(tone.x, tone.y, tone.z, tone.w, 0)

## Fades out, runs action, fades back in — Essentials' pbFadeOutIn.
## Passing nothing just does the transition.
static func fade_out_in(action: Callable = Callable()) -> void:
	await SceneRouter.fade_out()
	if action.is_valid():
		await action.call()
	await SceneRouter.fade_in()


# === Flash and Shake ===

## Washes colour over the screen and fades it out over frames
## Doesn't wait — the flash carries on while the event does.
static func flash(colour: Color, frames: int) -> void:
	var layer: ScreenEffects = screen()
	if layer != null:
		layer.flash(colour, frames)

## Shakes the screen at power and speed (both 0 to 9) for frames.
## A power of zero stops a shake already running.
static func shake(power: int, speed: int, frames: int) -> void:
	var layer: ScreenEffects = screen()
	if layer != null:
		layer.shake(power, speed, frames)

## Waits for a running shake to finish.
static func wait_for_shake() -> void:
	var layer: ScreenEffects = screen()
	if layer == null or not layer.is_shaking():
		return
	await Field.wait(layer.shake_seconds_left())


# === Followers ===

## Adds event to the back of the line and takes it off the map.
static func add_follower(event: MapEvent, name: String, common_event_id: int = 0) -> bool:
	var train: FollowerTrain = followers()
	if train == null:
		return false
	return train.add_event(event, name, common_event_id) != null

## Removes the follower named name from the line.
static func remove_follower(name: String) -> bool:
	var train: FollowerTrain = followers()
	return train != null and train.remove(name)

static func has_followers() -> bool:
	var train: FollowerTrain = followers()
	return train != null and train.has_followers()


## Takes the line off the screen
static func hide_followers() -> void:
	GameState.followers_hidden = true
	var train: FollowerTrain = followers()
	if train != null:
		train.hide_followers()
	refresh_pokemon_followers()

static func show_followers() -> void:
	GameState.followers_hidden = false
	var train: FollowerTrain = followers()
	if train != null:
		train.show_followers()
	refresh_pokemon_followers()

static func put_followers_on_player() -> void:
	var train: FollowerTrain = followers()
	if train != null:
		train.put_on_player()

static func follow_into_door() -> void:
	var train: FollowerTrain = followers()
	if train != null:
		await train.follow_into_door()


# === Pokemon Followers === 


## The Pokemon line behind the player, or null outside the overworld.
static func pokemon_followers() -> PokemonFollowers:
	var field: MapController = MapController.current
	return field.pokemon_followers if field != null else null

## Puts the line right after something changed that it doesn't listen for.
static func refresh_pokemon_followers() -> void:
	var walking: PokemonFollowers = pokemon_followers()
	if walking != null:
		walking.refresh(true)

## The current mode. See [enum FollowerMode.Mode].
static func follower_mode() -> int:
	return PokemonFollowerSettings.effective_mode()

## Forces mode for the rest of the playthrough, over the player's own choice.
static func set_follower_mode(mode: int) -> bool:
	if not FollowerMode.is_valid(mode):
		push_warning("FieldEffects: %d is not a follower mode." % mode)
		return false
	PokemonFollowerSettings.set_session_mode(mode)
	refresh_pokemon_followers()
	return true

## Gives the choice of mode back to the player.
static func clear_follower_mode() -> void:
	PokemonFollowerSettings.clear_session_mode()
	refresh_pokemon_followers()

## Picks party member index to walk under [constant FollowerMode.Mode.CHOSEN].
static func set_chosen_follower(index: int) -> bool:
	if not PokemonFollowerSettings.set_chosen_index(index):
		return false
	refresh_pokemon_followers()
	return true

## The party slot chosen to walk, or
## [constant PokemonFollowerSettings.NOBODY_CHOSEN].
static func chosen_follower() -> int:
	return PokemonFollowerSettings.chosen_index()

## Puts party member index at the head of the line for as long as the script wants, whatever the mode says.
static func add_temporary_follower(index: int, forced: bool = true) -> bool:
	if GameState == null or GameState.party == null:
		return false
	var member: Pokemon = GameState.party.get_member(index)
	if member == null:
		return false
	var entry: FollowerPokemon = FollowerPokemon.from_pokemon(member, index)
	entry.forced = forced
	return _append_temporary(entry)


static func add_temporary_species_follower(
	species_id: StringName, form: int = 0, shiny: bool = false,
	female: bool = false, called: String = "", forced: bool = true
) -> bool:
	if Database.species(species_id) == null:
		push_warning("FieldEffects: there is no species called '%s'." % species_id)
		return false
	var entry: FollowerPokemon = FollowerPokemon.from_species(
		species_id, form, shiny, female, called)
	entry.forced = forced
	return _append_temporary(entry)

static func add_temporary_pokemon_follower(pkmn: Pokemon, forced: bool = true) -> bool:
	if pkmn == null:
		return false
	var entry: FollowerPokemon = FollowerPokemon.from_pokemon(pkmn)
	entry.forced = forced
	return _append_temporary(entry)

## Sends the temporary followers away and puts the party's line back.
static func clear_temporary_followers() -> void:
	if GameState == null:
		return
	GameState.follower_overrides.clear()
	refresh_pokemon_followers()

static func has_temporary_followers() -> bool:
	return GameState != null and not GameState.follower_overrides.is_empty()

## The party members currently walking, for a script that wants to do something to whoever is out.
static func walking_pokemon() -> Array[Pokemon]:
	var walking: PokemonFollowers = pokemon_followers()
	return walking.walking_pokemon() if walking != null else [] as Array[Pokemon]

## Plays the cry of the Pokemon walking closest to the player
static func follower_cry() -> void:
	var walking: PokemonFollowers = pokemon_followers()
	if walking == null:
		return
	var leader: PokemonFollowerCharacter = walking.first()
	if leader != null:
		leader.cry()

static func _append_temporary(entry: FollowerPokemon) -> bool:
	if GameState == null or not entry.is_valid():
		return false
	GameState.follower_overrides.append(entry.to_dict())
	refresh_pokemon_followers()
	return true

# === Reactions ===

## Pops an exclamation mark over [param character] and waits for it.
static func exclaim(character: GridCharacter) -> void:
	if character == null:
		return
	await EmotionBubble.show_over(character)

## A trainer spotting the player: the exclamation mark, the turn, walking over.
static func notice_player(event: MapEvent, always_exclaim: bool = false) -> void:
	var field: MapController = MapController.current
	if event == null or field == null or field.player == null:
		return
	if always_exclaim or not facing_each_other(event, field.player):
		await exclaim(event)
	turn_towards(field.player, event)
	await walk_towards(event, field.player)

## Turns [param character] to look at [param target].
static func turn_towards(character: GridCharacter, target: GridCharacter) -> void:
	if character == null or target == null:
		return
	character.turn(GridCharacter.direction_towards(character.world_cell(), target.world_cell()))

## `true` when the two are face to face.
static func facing_each_other(first: GridCharacter, second: GridCharacter) -> bool:
	if first == null or second == null:
		return false
	var towards: GridCharacter.Direction = GridCharacter.direction_towards(
		first.world_cell(), second.world_cell()
	)
	return first.facing == towards and second.facing == GridCharacter.opposite(towards)

## Walks [param character] up to [param target] and stops one cell short, like
## a trainer who spotted the player.
static func walk_towards(character: GridCharacter, target: GridCharacter) -> void:
	if character == null or target == null:
		return
	var guard: int = 0
	while guard < FollowerTrain.TRAIL_LENGTH:
		var from: Vector2i = character.world_cell()
		var to: Vector2i = target.world_cell()
		var gap: Vector2i = to - from
		if absi(gap.x) + absi(gap.y) <= 1:
			break
		var direction: GridCharacter.Direction = GridCharacter.direction_towards(from, to)
		if not await character.step(direction):
			break
		guard += 1
	turn_towards(character, target)
