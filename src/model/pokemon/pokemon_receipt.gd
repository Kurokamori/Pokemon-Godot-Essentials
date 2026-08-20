class_name PokemonReceipt
extends RefCounted
## The flow of a player actually recieving a pokemon and all the fanfare that happens each time

const NAME_ENTRY_SCENE: String = "res://scenes/ui/name_entry_screen.tscn"

const MAX_NICKNAME_LENGTH: int = 12

enum Destination {
	PARTY = 0,
	STORAGE = 1,
	NOWHERE = 2,
}

## Shows one line of text to the player, as `func(text: String) -> void`
var narrate: Callable = Callable()

## Puts a list of options to the player and returns the index chosen
## Returns `-1` if they back out
var ask: Callable = Callable()

## Whether to offer a nickname at all
var offer_nickname: bool = true

## Whether the receiving player becomes the original trainer
var takes_ownership: bool = true

## Where [method give] put the Pokemon
var destination: Destination = Destination.NOWHERE

## Box the Pokemon was stored in, or `-1` when it went to the party.
var box_index: int = -1



## Creates a Pokemon of [param species_id] at [param level] and gives it to the player
## Returns the Pokemon, or `null` when the species is unknown.
func give_species(species_id: StringName, level: int) -> Pokemon:
	if Database.species(species_id) == null:
		push_error("PokemonReceipt: unknown species '%s'." % species_id)
		destination = Destination.NOWHERE
		return null
	var owner: PokemonOwner = null
	if takes_ownership and GameState.player != null:
		owner = GameState.player.owner_record()
	var pkmn: Pokemon = Pokemon.create(species_id, level, owner)
	await give(pkmn)
	return pkmn

## Runs the full receiving flow for [param pkmn]
## Returns its final destination
func give(pkmn: Pokemon) -> Destination:
	destination = Destination.NOWHERE
	box_index = -1
	if pkmn == null:
		return destination

	if takes_ownership and GameState.player != null:
		pkmn.owner = GameState.player.owner_record()
		if pkmn.obtain_method == Pokemon.ObtainMethod.MET:
			pkmn.obtain_map = GameState.map_id
		pkmn.obtain_level = pkmn.level()

	_register(pkmn)
	_place(pkmn)
	if destination == Destination.NOWHERE:
		await _say(Loc.line("There is no room left for {pokemon}!", {"pokemon": pkmn.display_name()}))
		return destination

	await _say(Loc.line("{player} received {pokemon}!", {"player": _player_name(), "pokemon": pkmn.display_name()}))
	await _offer_nickname(pkmn)
	if destination == Destination.STORAGE:
		await _say(Loc.line("{pokemon} was transferred to Box \"{box_index}\".", {"pokemon": pkmn.display_name(), "box_index": GameState.storage.box_names[box_index]}))
	return destination


# === Internal ===

func _register(pkmn: Pokemon) -> void:
	if GameState.player == null:
		return
	GameState.player.pokedex.register_owned(pkmn)
	GameState.player.record_caught(pkmn.species)

## Puts the Pokemon in the party, or in the first box with room when the party is full
func _place(pkmn: Pokemon) -> void:
	if not GameSettings.data.send_caught_to_boxes:
		if not GameState.party.is_full() and GameState.party.add(pkmn):
			destination = Destination.PARTY
			return
	var box: int = GameState.storage.store(pkmn)
	if box >= 0:
		box_index = box
		destination = Destination.STORAGE
		return
	if not GameState.party.is_full() and GameState.party.add(pkmn):
		destination = Destination.PARTY
		return
	destination = Destination.NOWHERE

## Asks whether the player wants to name the Pokemon
func _offer_nickname(pkmn: Pokemon) -> void:
	if not offer_nickname or not ask.is_valid() or pkmn.is_egg():
		return
	if not GameSettings.data.offer_nicknames:
		return
	var species_name: String = pkmn.display_name()
	await _say(Loc.line("Would you like to give a nickname to {species_name}?", {"species_name": species_name}))
	var answer: int = await ask.call(["Yes", "No"])
	if answer != 0:
		return
	var chosen: String = await ask_nickname(pkmn)
	if chosen.is_empty() or chosen == species_name:
		return
	pkmn.nickname = chosen

## Pushes the naming keyboard for [param pkmn] and returns what was entered
## Returns an empty String when the player backs out
static func ask_nickname(pkmn: Pokemon) -> String:
	var scene: PackedScene = load(NAME_ENTRY_SCENE)
	if scene == null:
		push_error("PokemonReceipt: could not load '%s'." % NAME_ENTRY_SCENE)
		return ""
	var species_name: String = pkmn.display_name()
	var entered: Variant = await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(
			"%s's nickname?" % species_name, species_name, MAX_NICKNAME_LENGTH,
			[] as Array[String], Assets.first_sprite_frame(pkmn.icon())
		)
	)
	return String(entered) if entered is String else ""

func _say(text: String) -> void:
	if not narrate.is_valid():
		return
	await narrate.call(text)

func _player_name() -> String:
	return GameState.player.name if GameState.player != null else "You"
