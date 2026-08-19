class_name EventScriptReceivers
extends RefCounted
## The recievers an event names that are part of the engine rather than for a value,
## such as `$player`, `$bag`, `game_map`, etc.

## Self-switch which event moved by a script is remembered under.
const MOVED_SWITCH: String = "_moved"

## The bridge this is dispatching for
var bridge: EventScriptBridge:
	get:
		return _bridge.get_ref() as EventScriptBridge if _bridge != null else null

var _bridge: WeakRef = null


func _init(for_bridge: EventScriptBridge) -> void:
	_bridge = weakref(for_bridge)



## Runs `<receiver>.<method>(...)` when [param receiver] names something in the engine.
## [param raw] is the snippet as written, used when reporting one that has no counterpart.
func dispatch(receiver: String, method: String, arguments: Array, raw: String) -> Variant:
	match receiver:
		"$player":
			return _player(method, arguments, raw)
		"$player.pokedex":
			return _pokedex(method, arguments, raw)
		"$bag":
			return _bag(method, arguments, raw)
		"$stats":
			return _stats(method, arguments, raw)
		"$game_player":
			return _game_player(method, raw)
		"$game_map":
			return _game_map(method, raw)
		"$game_screen":
			return _game_screen(method, arguments, raw)
		"$PokemonGlobal":
			return _pokemon_global(method, raw)
		"$PokemonMap":
			return _pokemon_map(method, arguments, raw)
		"Pokemon":
			return _pokemon_class(method, arguments, raw)
		"Tone", "Color":
			return tone(arguments)
		"Followers":
			return await _followers(method, arguments, raw)
		"PokemonFollowers", "FollowingPokemon", "$PokemonGlobal.followers":
			return _pokemon_followers(method, arguments, raw)
		"$game_temp.last_battle_record":
			return _recording(method, raw)
		"$speeches":
			return _speeches(method, arguments, raw)
	return EventScriptBridge.Unsupported.new(raw)


# === $player ===

func _player(method: String, arguments: Array, raw: String) -> Variant:
	var player: Player = GameState.player
	if player == null:
		return EventScriptBridge.Unsupported.new(raw)
	match method:
		"has_species?":
			if not arguments.is_empty():
				return GameState.party.has_species(StringName(String(arguments[0])))
		"party_full?":
			return GameState.party.is_full()
		"pokemon_count":
			return GameState.party.size()
		"party", "pokemon_party":
			return GameState.party.members
		"first_pokemon":
			return GameState.party.get_member(0)
		"last_party":
			return GameState.party.get_member(GameState.party.size() - 1)
		"has_other_able_pokemon?":
			if not arguments.is_empty():
				return _has_other_able_pokemon(StringName(String(arguments[0])))
		"badge_count":
			return player.badge_count()
		"badges":
			return badge_list(player)
		"male?":
			return player.is_male()
		"female?":
			return player.is_female()
		"has_pokedex":
			return player.has_pokedex
		"has_pokegear":
			return player.has_pokegear
		"has_running_shoes":
			return player.has_running_shoes
		"has_snag_machine":
			return player.has_snag_machine
		"seen_storage_creator":
			return player.seen_storage_creator
		"seen_purify_chamber":
			return player.seen_purify_chamber
		"mystery_gift_unlocked":
			return player.mystery_gift_unlocked
		"coins":
			return player.coins
		"battle_points":
			return player.battle_points
		"soot":
			return player.soot
		"money":
			return player.money
		"name":
			return player.name
		"id", "public_id":
			return player.public_id()
	return EventScriptBridge.Unsupported.new(raw)

## The badge list an event indexes into. It is a snapshot; 
## Writing to it goes through [method EventScriptBridge._assign_index] instead.
static func badge_list(player: Player) -> Array:
	var earned: Array = []
	for index: int in GameStats.BADGE_COUNT:
		earned.append(player.has_badge(index))
	return earned

static func _has_other_able_pokemon(species_id: StringName) -> bool:
	for pkmn: Pokemon in GameState.party.members:
		if pkmn.species != species_id and pkmn.is_able():
			return true
	return false

func _pokedex(method: String, arguments: Array, raw: String) -> Variant:
	var player: Player = GameState.player
	if player == null:
		return EventScriptBridge.Unsupported.new(raw)
	match method:
		"seen_count":
			return player.pokedex.seen_count()
		"owned_count":
			return player.pokedex.owned_count()
		"seen?":
			return not arguments.is_empty() and player.pokedex.is_seen(StringName(String(arguments[0])))
		"owned?":
			return not arguments.is_empty() and player.pokedex.is_owned(StringName(String(arguments[0])))
		"owned_shadow_pokemon?":
			# TODO: Add shadow pokemon catching, owning, etc.
			return false
		"unlock":
			if not arguments.is_empty():
				player.pokedex.unlock_dex(int(_number(arguments[0])))
				return true
		"lock":
			if not arguments.is_empty():
				player.pokedex.lock_dex(int(_number(arguments[0])))
				return true
	return EventScriptBridge.Unsupported.new(raw)


# === $bag ===

func _bag(method: String, arguments: Array, raw: String) -> Variant:
	if arguments.is_empty():
		return EventScriptBridge.Unsupported.new(raw)
	var item_id: StringName = _id_of(arguments[0])
	var quantity: int = _quantity(arguments, 1)
	match method:
		"add":
			return GameState.bag.add_item(item_id, quantity)
		"remove":
			return GameState.bag.remove_item(item_id, quantity)
		"has?":
			return GameState.bag.has_item(item_id, quantity)
		"can_add?":
			return GameState.bag.can_add(item_id, quantity)
		"quantity":
			return GameState.bag.quantity_of(item_id)
	return EventScriptBridge.Unsupported.new(raw)


# === $stats ===

func _stats(method: String, arguments: Array, raw: String) -> Variant:
	var value: Variant = GameState.stats.get_counter(StringName(method))
	if value == null:
		return _stats_call(method, arguments, raw)
	return value

func _stats_call(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"set_time_to_badge":
			if not arguments.is_empty():
				GameState.stats.set_time_to_badge(int(_number(arguments[0])))
				return true
		"set_time_to_hall_of_fame":
			GameState.stats.set_time_to_hall_of_fame()
			return true
		"set_time_last_saved":
			GameState.stats.set_time_last_saved()
			return true
		"distance_moved":
			return GameState.stats.distance_moved()
	return EventScriptBridge.Unsupported.new(raw)


# === The Map ===

func _game_player(method: String, raw: String) -> Variant:
	var field: MapController = MapController.current
	var walker: PlayerCharacter = field.player if field != null else null
	if walker == null:
		return EventScriptBridge.Unsupported.new(raw)
	match method:
		"x": return walker.tile_position.x
		"y": return walker.tile_position.y
		"direction": return int(walker.facing)
		"has_follower?": return FieldEffects.has_followers()
		"moving?": return walker.is_moving
	return EventScriptBridge.Unsupported.new(raw)

func _game_map(method: String, raw: String) -> Variant:
	match method:
		"map_id": return GameState.map_id
		"name", "display_name":
			var metadata: MapMetadataData = GameState.current_map_metadata()
			return metadata.display_name if metadata != null else ""
	return EventScriptBridge.Unsupported.new(raw)

func _game_screen(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"weather":
			if arguments.is_empty():
				return GameState.current_weather()
			var power: int = int(_number(arguments[1])) if arguments.size() >= 2 else 5
			var frames: int = int(_number(arguments[2])) if arguments.size() >= 3 else 0
			FieldEffects.set_weather(
				StringName(String(arguments[0])), power, float(frames) / ScreenEffects.FRAMES_PER_SECOND
			)
			return true
		"weather_type":
			return GameState.current_weather()
		"weather_max":
			return GameState.current_weather_power()
	return EventScriptBridge.Unsupported.new(raw)

func _pokemon_global(method: String, raw: String) -> Variant:
	match method:
		"encounter_version": return GameState.encounter_version
		"dungeon_area": return GameState.dungeon_area
		"dungeon_version": return GameState.dungeon_version
		"dungeon_rng_seed": return GameState.dungeon_rng_seed
		"lastbattle": return GameState.last_battle_record
		"partner": return GameState.partner_trainer
	return EventScriptBridge.Unsupported.new(raw)

func _pokemon_map(method: String, arguments: Array, raw: String) -> Variant:
	if method != "addMovedEvent":
		return EventScriptBridge.Unsupported.new(raw)
	var event: MapEvent = (
		arguments[0] if not arguments.is_empty() and arguments[0] is MapEvent
		else bridge.current_event()
	)
	if event == null:
		return EventScriptBridge.Unsupported.new(raw)
	GameState.set_self_switch(bridge.map_id(), event.self_switch_key(), MOVED_SWITCH, true)
	return true


# === Pokemon ===

func _pokemon_class(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"play_cry":
			if not arguments.is_empty():
				var record: SpeciesData = Database.species(_id_of(arguments[0]))
				if record != null:
					AudioManager.play_se(record.get_sprite_key())
				return true
		"new":
			if not arguments.is_empty():
				var level: int = int(_number(arguments[1])) if arguments.size() >= 2 else 5
				return Pokemon.create(_id_of(arguments[0]), maxi(level, 1), _player_owner())
	return EventScriptBridge.Unsupported.new(raw)

static func _player_owner() -> PokemonOwner:
	return GameState.player.owner_record() if GameState.player != null else null


# === Followers ===

func _followers(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"add":
			if arguments.size() >= 2:
				var event: MapEvent = bridge.event_by_id(int(_number(arguments[0])))
				var common_event: int = int(_number(arguments[2])) if arguments.size() >= 3 else 0
				return FieldEffects.add_follower(event, String(arguments[1]), common_event)
		"add_event":
			if not arguments.is_empty() and arguments[0] is MapEvent:
				return FieldEffects.add_follower(arguments[0], arguments[0].display_name())
		"remove":
			if not arguments.is_empty():
				return FieldEffects.remove_follower(String(arguments[0]))
		"remove_event":
			if not arguments.is_empty() and arguments[0] is MapEvent:
				return FieldEffects.remove_follower(arguments[0].display_name())
		"clear":
			var train: FollowerTrain = FieldEffects.followers()
			if train != null:
				train.clear_partners()
			GameState.partner_trainer = null
			return true
		"get":
			var train: FollowerTrain = FieldEffects.followers()
			var name: String = String(arguments[0]) if not arguments.is_empty() else ""
			return train.get_follower(name) if train != null else null
		"hide_followers":
			FieldEffects.hide_followers()
			return true
		"show_followers":
			FieldEffects.show_followers()
			return true
		"put_followers_on_player":
			FieldEffects.put_followers_on_player()
			return true
		"follow_into_door":
			await FieldEffects.follow_into_door()
			return true
	return EventScriptBridge.Unsupported.new(raw)

func _pokemon_followers(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"mode", "get_mode":
			return FieldEffects.follower_mode()
		"set_mode":
			if not arguments.is_empty():
				return FieldEffects.set_follower_mode(_follower_mode_argument(arguments[0]))
		"clear_mode":
			FieldEffects.clear_follower_mode()
			return true
		"choose", "set_chosen":
			if not arguments.is_empty():
				return FieldEffects.set_chosen_follower(int(_number(arguments[0])))
		"chosen":
			return FieldEffects.chosen_follower()
		"add", "add_from_party":
			if not arguments.is_empty():
				return FieldEffects.add_temporary_follower(int(_number(arguments[0])))
		"add_species":
			if not arguments.is_empty():
				var form: int = int(_number(arguments[1])) if arguments.size() >= 2 else 0
				var shiny: bool = bool(arguments[2]) if arguments.size() >= 3 else false
				return FieldEffects.add_temporary_species_follower(
					_id_of(arguments[0]), form, shiny)
		"add_pokemon":
			if not arguments.is_empty() and arguments[0] is Pokemon:
				return FieldEffects.add_temporary_pokemon_follower(arguments[0])
		"clear", "clear_temporary":
			FieldEffects.clear_temporary_followers()
			return true
		"refresh":
			FieldEffects.refresh_pokemon_followers()
			return true
		"hide":
			FieldEffects.hide_followers()
			return true
		"show":
			FieldEffects.show_followers()
			return true
		"cry":
			FieldEffects.follower_cry()
			return true
		"count":
			var walking: PokemonFollowers = FieldEffects.pokemon_followers()
			return walking.count() if walking != null else 0
		"walking", "pokemon":
			return FieldEffects.walking_pokemon()
	return EventScriptBridge.Unsupported.new(raw)

## A follower mode written either as its name or as its number.
static func _follower_mode_argument(argument: Variant) -> int:
	if argument is String or argument is StringName:
		return FollowerMode.from_name(String(argument))
	return int(_number(argument))


# === Bits and Bobs ===

func _speeches(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"push", "append":
			for argument: Variant in arguments:
				GameState.speeches.append(argument)
			return GameState.speeches
		"clear":
			GameState.speeches.clear()
			return GameState.speeches
	var result: Variant = EventScriptValues.call_method(GameState.speeches, method, arguments)
	return EventScriptBridge.Unsupported.new(raw) if result is EventScriptValues.NoSuchMethod else result

func _recording(method: String, raw: String) -> Variant:
	var recording: BattleRecording = GameState.last_battle_record
	match method:
		"nil?":
			return recording == null
		"outcome":
			return recording.outcome if recording != null else 0
		"round_count":
			return recording.round_count if recording != null else 0
	return EventScriptBridge.Unsupported.new(raw)

## `Tone.new(r, g, b, grey)` has no object of its own here; 
static func tone(arguments: Array) -> Array:
	var channels: Array = [0, 0, 0, 0]
	for index: int in mini(arguments.size(), 4):
		channels[index] = int(_number(arguments[index]))
	return channels


# === Utilities ===

static func _id_of(value: Variant) -> StringName:
	if value is GameDataResource:
		return value.id
	return StringName(String(value))

static func _quantity(arguments: Array, index: int) -> int:
	if arguments.size() <= index:
		return 1
	return maxi(int(_number(arguments[index])), 1)

static func _number(value: Variant) -> float:
	return EventScriptBridge.as_number(value)
