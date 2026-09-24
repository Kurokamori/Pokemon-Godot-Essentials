class_name FieldPokemon
## Party actions used by overworld events.

const PARTY_SCREEN: String = "res://scenes/ui/screens/party_screen.tscn"
const NAME_ENTRY_SCREEN: String = "res://scenes/ui/screens/name_entry_screen.tscn"

## Variable value meaning "the player picked nobody".
const NO_CHOICE: int = -1


# === Choosing ===

## Chooses a party member and writes its slot and name to game variables.
static func choose(
	slot_variable: int, name_variable: int = 0, filter: Callable = Callable(),
	prompt: String = "Choose a Pokemon."
) -> int:
	var allowed: Array[int] = _choosable_slots(filter)
	if allowed.is_empty():
		_record_choice(slot_variable, name_variable, NO_CHOICE)
		return NO_CHOICE
	var slot: int = await _ask_for_slot(allowed, prompt)
	_record_choice(slot_variable, name_variable, slot)
	return slot

## Chooses a party member that is not an Egg.
static func choose_non_egg(
	slot_variable: int, name_variable: int = 0, prompt: String = "Choose a Pokemon."
) -> int:
	return await choose(
		slot_variable, name_variable,
		func(pkmn: Pokemon) -> bool: return not pkmn.is_egg(),
		prompt
	)

## Asks for a party member that can still fight.
static func choose_able(
	slot_variable: int, name_variable: int = 0, prompt: String = "Choose a Pokemon."
) -> int:
	return await choose(
		slot_variable, name_variable,
		func(pkmn: Pokemon) -> bool: return pkmn.is_able(),
		prompt
	)

## Chooses a Pokemon that can be traded.
static func choose_tradable(
	slot_variable: int, name_variable: int = 0, filter: Callable = Callable(),
	prompt: String = "Which Pokemon will you trade?"
) -> int:
	return await choose(
		slot_variable, name_variable,
		func(pkmn: Pokemon) -> bool:
			if pkmn.is_egg() or pkmn.cannot_trade:
				return false
			if filter.is_valid() and not bool(filter.call(pkmn)):
				return false
			return GameState.party.able_count() > 1 or not pkmn.is_able(),
		prompt
	)

## Writes the first able Pokemon's slot without asking.
static func first_able(slot_variable: int, name_variable: int = 0) -> int:
	for slot: int in GameState.party.size():
		var pkmn: Pokemon = GameState.party.get_member(slot)
		if pkmn != null and pkmn.is_able():
			_record_choice(slot_variable, name_variable, slot)
			return slot
	_record_choice(slot_variable, name_variable, NO_CHOICE)
	return NO_CHOICE

## The Pokemon whose party slot is held in [param slot_variable], or `null`.
static func from_variable(slot_variable: int) -> Pokemon:
	var slot: int = int(GameState.get_variable(slot_variable))
	if slot < 0:
		return null
	return GameState.party.get_member(slot)

## Party slots [param filter] allows, in party order.
static func _choosable_slots(filter: Callable) -> Array[int]:
	var allowed: Array[int] = []
	for slot: int in GameState.party.size():
		var pkmn: Pokemon = GameState.party.get_member(slot)
		if pkmn == null:
			continue
		if filter.is_valid() and not bool(filter.call(pkmn)):
			continue
		allowed.append(slot)
	return allowed

## Shows the party and returns the slot chosen, or [constant NO_CHOICE].
static func _ask_for_slot(allowed: Array[int], prompt: String) -> int:
	if allowed.size() == GameState.party.size():
		var scene: PackedScene = load(PARTY_SCREEN)
		if scene != null:
			var result: Variant = await SceneRouter.push_screen(
				scene, func(instance: Node) -> void: instance.selection_mode = true
			)
			return int(result) if result != null else NO_CHOICE
	var options: Array = []
	for slot: int in allowed:
		options.append(GameState.party.get_member(slot).display_name())
	options.append("Cancel")
	var chosen: int = await Field.ask(options, prompt, options.size())
	if chosen < 0 or chosen >= allowed.size():
		return NO_CHOICE
	return allowed[chosen]

static func _record_choice(slot_variable: int, name_variable: int, slot: int) -> void:
	if slot_variable > 0:
		GameState.set_variable(slot_variable, slot)
	if name_variable <= 0:
		return
	var pkmn: Pokemon = GameState.party.get_member(slot) if slot >= 0 else null
	GameState.set_variable(name_variable, pkmn.display_name() if pkmn != null else "")


# === Moves ===

## Offers to teach [param move_id] to a party member, which is what a Move Tutor does.
static func tutor_move(move_id: StringName) -> bool:
	var record: MoveData = Database.move(move_id)
	if record == null:
		return false
	var slot: int = await choose(
		0, 0,
		func(option: Pokemon) -> bool:
			return not option.is_egg() and (
				option.can_learn_machine_move(move_id) or option.relearnable_moves().has(move_id)
			),
		Loc.line("Teach {name} to which Pokemon?", {"name": record.get_translated_name()})
	)
	var candidate: Pokemon = GameState.party.get_member(slot) if slot >= 0 else null
	if candidate == null:
		return false
	if candidate.knows_move(move_id):
		await Field.say(Loc.line("{pokemon} already knows {name}.", {"pokemon": candidate.display_name(), "name": record.get_translated_name()}))
		return false
	if not await teach_move(candidate, move_id):
		return false
	GameState.stats.moves_taught_by_tutor += 1
	return true

## Teaches [param move_id] to [param pkmn], asking which move to give up when there is no room.
static func teach_move(pkmn: Pokemon, move_id: StringName) -> bool:
	return await lesson().teach(pkmn, move_id)

## Asks which of [param pkmn]'s moves to act on, and returns its index or `-1`.
static func choose_move(pkmn: Pokemon, prompt: String = "Which move?") -> int:
	return await lesson().choose_move(pkmn, prompt)

## Creates a move lesson that uses the overworld message window.
static func lesson() -> MoveLearning:
	var teaching: MoveLearning = MoveLearning.new()
	teaching.narrate = func(text: String) -> void:
		await Field.say(text)
	teaching.ask = func(options: Array, prompt: String) -> int:
		return await Field.ask(options, prompt, options.size())
	return teaching

## Runs the Move Relearner on [param pkmn]: lists the moves it could remember and teaches whichever the player picks.
static func relearn_move(pkmn: Pokemon) -> bool:
	if pkmn == null:
		return false
	var choices: Array[StringName] = pkmn.relearnable_moves()
	if choices.is_empty():
		await Field.say(Loc.line("{pokemon} has no moves it can remember.", {"pokemon": pkmn.display_name()}))
		return false
	var chosen: StringName = await _ask_which_move(pkmn)
	if chosen.is_empty():
		return false
	if not await teach_move(pkmn, chosen):
		return false
	GameState.stats.moves_taught_by_reminder += 1
	return true

## Asks which move to remember, using the screen when available.
static func _ask_which_move(pkmn: Pokemon) -> StringName:
	var choices: Array[StringName] = pkmn.relearnable_moves()
	var scene: PackedScene = load(MoveRelearnerScreen.SCENE_PATH)
	if scene != null:
		var picked: Variant = await SceneRouter.push_screen(scene, func(instance: Node) -> void:
			instance.setup(pkmn)
		)
		return StringName(String(picked)) if picked != null else &""
	var options: Array = []
	for move_id: StringName in choices:
		var record: MoveData = Database.move(move_id)
		options.append(record.display_name if record != null else String(move_id))
	options.append("Cancel")
	var chosen: int = await Field.ask(options, "Which move should it remember?", options.size())
	if chosen < 0 or chosen >= choices.size():
		return &""
	return choices[chosen]


# === Evolution ===

## Sets off the evolutions that wait on evolution event [param number], which is Essentials' `pbEvolutionEvent`.
static func evolution_event(number: int) -> bool:
	return await Evolutions.by_event(number)

## Evolves [param pkmn] if a level-up condition is met.
static func evolve_now(pkmn: Pokemon) -> bool:
	return await Evolutions.on_level_up(pkmn)


# === Trades ===

## Trades the party member in [param slot_variable] for [param offered], which is what an in-game trade NPC does.
static func trade(
	slot_variable: int, offered: Variant, their_name: String = "", trader: String = "",
	level: int = 0
) -> bool:
	var given: Pokemon = from_variable(slot_variable)
	if given == null:
		return false
	var received: Pokemon = _as_pokemon(offered, given.level() if level <= 0 else level)
	if received == null:
		return false
	var slot: int = int(GameState.get_variable(slot_variable))
	if not their_name.is_empty():
		received.nickname = their_name
	received.owner = PokemonOwner.create(
		RNG.generator.randi() & 0xFFFFFFFF,
		trader if not trader.is_empty() else "Trainer",
		PokemonOwner.Gender.MALE
	)
	received.obtain_method = Pokemon.ObtainMethod.TRADED
	received.calculate_stats()
	# Show the trade before swapping; the screen handles both messages.
	var watched: bool = await _show_trade(given, received, trader)
	if not watched:
		await Field.say(Loc.line("{given} was traded for {received}!", {"given": given.display_name(), "received": received.display_name()}))
	GameState.party.replace_at(slot, received)
	GameState.stats.trade_count += 1
	if GameState.player != null:
		GameState.player.pokedex.register_owned(received)
	if not watched:
		await Field.say(Loc.line("Take good care of {received}!", {"received": received.display_name()}))
	# Check whether the traded Pokemon evolves on arrival.
	await Evolutions.on_trade(received, given)
	return true

## Plays the trading ceremony.
static func _show_trade(leaving: Pokemon, arriving: Pokemon, with_whom: String) -> bool:
	var scene: PackedScene = load(TradeScreen.SCENE_PATH)
	if scene == null:
		return false
	await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.setup(leaving, arriving, with_whom)
	)
	return true

## Puts an Egg of [param species_id] in the party.
static func generate_egg(species_id: StringName, from_whom: String = "") -> bool:
	if Database.species(species_id) == null or GameState.party.is_full():
		return false
	var owner: PokemonOwner = GameState.player.owner_record() if GameState.player != null else null
	var egg: Pokemon = Pokemon.create_egg(species_id, owner)
	if not from_whom.is_empty():
		egg.obtain_text = from_whom
	if not GameState.party.add(egg):
		return false
	await Field.say(Loc.line("{player} received the Egg!", {"player": _player_name()}))
	return true

static func _as_pokemon(source: Variant, level: int) -> Pokemon:
	if source is Pokemon:
		return source
	var species_id: StringName = StringName(String(source))
	if Database.species(species_id) == null:
		return null
	return Pokemon.create(species_id, maxi(level, 1))


# === Text Entry ===

## Opens the name-entry screen and writes what was typed into [param result_variable].
static func enter_text(
	prompt: String, fallback: String = "", max_length: int = 10, result_variable: int = 0
) -> String:
	var scene: PackedScene = load(NAME_ENTRY_SCREEN)
	if scene == null:
		return fallback
	var result: Variant = await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.setup(prompt, fallback, max_length)
	)
	var entered: String = String(result) if result != null else fallback
	if result_variable > 0:
		GameState.set_variable(result_variable, entered)
	return entered

## Names a Pokemon, keeping its old name when nothing was typed.
static func nickname(pkmn: Pokemon) -> String:
	if pkmn == null:
		return ""
	var species: SpeciesData = pkmn.species_data()
	var species_name: String = species.display_name if species != null else "Pokemon"
	var entered: String = await enter_text(
		"%s's nickname?" % species_name, pkmn.display_name(),
		GameSettings.data.max_pokemon_name_size
	)
	pkmn.nickname = "" if entered == species_name else entered
	return pkmn.display_name()

static func _player_name() -> String:
	return GameState.player.name if GameState.player != null else "You"
