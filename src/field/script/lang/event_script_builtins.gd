class_name EventScriptBuiltins
## Reads game state for event script expressions.

## Calls a builtin and reports invalid arguments.
static func call_function(
	runner: EventScriptRunner, name: String, arguments: Array, line: int
) -> Variant:
	var problem: String = EventScriptCommands.function_problem(name, arguments.size())
	if not problem.is_empty():
		runner.report(problem, line)
		return null
	match name:
		# === Session ===
		"switch":
			return GameState.get_switch(int(EventScriptCast.to_number(arguments[0])))
		"variable":
			return GameState.get_variable(int(EventScriptCast.to_number(arguments[0])))
		"self_switch":
			return runner.event != null and Field.get_self_switch(
				runner.event, EventScriptCast.to_text(arguments[0]).to_upper()
			)
		"map_id":
			return runner.map.map_id() if runner.map != null else GameState.map_id

		# === Player ===
		"player_name":
			return runner.player_name()
		"money":
			return GameState.player.money if GameState.player != null else 0
		"coins":
			return GameState.player.coins if GameState.player != null else 0
		"badge_count":
			return GameState.player.badge_count() if GameState.player != null else 0
		"has_badge":
			return GameState.player != null and GameState.player.has_badge(
				int(EventScriptCast.to_number(arguments[0]))
			)
		"player_is_male":
			return GameState.player != null and GameState.player.is_male()
		"player_is_female":
			return GameState.player != null and GameState.player.is_female()
		"has_pokedex":
			return GameState.player != null and GameState.player.has_pokedex
		"has_pokegear":
			return GameState.player != null and GameState.player.has_pokegear
		"has_running_shoes":
			return GameState.player != null and GameState.player.has_running_shoes
		"steps":
			return GameState.player.steps_taken if GameState.player != null else 0

		# === Bag ===
		"has_item":
			var least: int = int(EventScriptCast.to_number(arguments[1])) if arguments.size() > 1 else 1
			return GameState.bag.has_item(EventScriptCast.to_id(arguments[0]), maxi(least, 1))
		"item_count":
			return GameState.bag.quantity_of(EventScriptCast.to_id(arguments[0]))
		"item_name":
			var item: ItemData = Database.item(EventScriptCast.to_id(arguments[0]))
			if item == null:
				return EventScriptCast.to_text(arguments[0])
			return item.get_display_name(
				int(EventScriptCast.to_number(arguments[1])) if arguments.size() > 1 else 1
			)

		# === Party ===
		"party_size":
			return GameState.party.size()
		"party_full":
			return GameState.party.is_full()
		"party_able_count":
			return GameState.party.able_count()
		"has_species":
			return GameState.party.has_species(EventScriptCast.to_id(arguments[0]))
		"highest_level":
			return GameState.party.highest_level()
		"species_name":
			var species: SpeciesData = Database.species(EventScriptCast.to_id(arguments[0]))
			return species.display_name if species != null else EventScriptCast.to_text(arguments[0])

		# === Pokedex ===
		"seen":
			return GameState.player != null and GameState.player.pokedex.is_seen(
				EventScriptCast.to_id(arguments[0])
			)
		"owned":
			return GameState.player != null and GameState.player.pokedex.is_owned(
				EventScriptCast.to_id(arguments[0])
			)
		"seen_count":
			return GameState.player.pokedex.seen_count() if GameState.player != null else 0
		"owned_count":
			return GameState.player.pokedex.owned_count() if GameState.player != null else 0

		# === Map ===
		"player_x":
			var walker_x: GridCharacter = runner.player()
			return walker_x.tile_position.x if walker_x != null else 0
		"player_y":
			var walker_y: GridCharacter = runner.player()
			return walker_y.tile_position.y if walker_y != null else 0
		"event_x":
			var at_x: GridCharacter = _addressed(runner, arguments)
			return at_x.tile_position.x if at_x != null else 0
		"event_y":
			var at_y: GridCharacter = _addressed(runner, arguments)
			return at_y.tile_position.y if at_y != null else 0
		"facing":
			var who: GridCharacter = _addressed(runner, arguments)
			return EventScriptRunner.direction_name(who.facing) if who != null else ""
		"distance_to_player":
			return _distance_to_player(runner, arguments)

		# === Arithmetic and text ===
		"random":
			return RNG.below(maxi(int(EventScriptCast.to_number(arguments[0])), 1))
		"random_range":
			return RNG.range_int(
				int(EventScriptCast.to_number(arguments[0])),
				int(EventScriptCast.to_number(arguments[1]))
			)
		"min":
			return minf(EventScriptCast.to_number(arguments[0]), EventScriptCast.to_number(arguments[1]))
		"max":
			return maxf(EventScriptCast.to_number(arguments[0]), EventScriptCast.to_number(arguments[1]))
		"abs":
			return absf(EventScriptCast.to_number(arguments[0]))
		"floor":
			return int(floorf(EventScriptCast.to_number(arguments[0])))
		"round":
			return int(roundf(EventScriptCast.to_number(arguments[0])))
		"clamp":
			return clampf(
				EventScriptCast.to_number(arguments[0]),
				EventScriptCast.to_number(arguments[1]),
				EventScriptCast.to_number(arguments[2])
			)
		"number":
			return EventScriptCast.to_number(arguments[0])
		"text":
			return EventScriptCast.to_text(arguments[0])
		"length":
			return EventScriptCast.to_text(arguments[0]).length()
		"upper":
			return EventScriptCast.to_text(arguments[0]).to_upper()
		"lower":
			return EventScriptCast.to_text(arguments[0]).to_lower()
	runner.report("there is no function called %s" % name, line)
	return null

## Gets the named character, or the current event by default.
static func _addressed(runner: EventScriptRunner, arguments: Array) -> GridCharacter:
	if arguments.is_empty():
		return runner.event
	return runner.character_from(arguments[0])

## Gets the grid distance to the player.
static func _distance_to_player(runner: EventScriptRunner, arguments: Array) -> int:
	var from: GridCharacter = _addressed(runner, arguments)
	var walker: GridCharacter = runner.player()
	if from == null or walker == null:
		return 0
	var gap: Vector2i = from.tile_position - walker.tile_position
	return absi(gap.x) + absi(gap.y)
