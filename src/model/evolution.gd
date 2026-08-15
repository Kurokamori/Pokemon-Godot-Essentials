class_name Evolutions
## Manages when to query if an evolution is going to happen, and then plays the evolution

# TODO: Make the actual evolution scene
const SCENE_PATH: String = ""

## Plays the evolution of the [param pokemon] into [param new_species] and applies it
## Returns `true` when it succeeded, and `false` if the player cancels.
static func play(pokemon: Pokemon, new_species: StringName, can_cancel: bool = true) -> bool:
	if pokemon == null or new_species.is_empty():
		return false
	if Database.species(new_species) == null:
		push_error("Evolution: Evolution.play couldn't find species '%s'" % new_species)
		return false
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		push_error("Evolution: Evolution.play the evolution screen is missing.")
		return apply_without_scene(pokemon, new_species)
	await SceneRouter.fade_out()
	var result: Variant = await SceneRouter.push_screen(
		scene, func(screen: Node) -> void:
		screen.setup(pokemon, new_species, can_cancel)
	)
	await SceneRouter.fade_in()
	return bool(result)
	
## Applies an evolution without the scene or presentation.
static func apply_without_scene(pokemon: Pokemon, new_species: StringName) -> bool:
	if pokemon == null or new_species.is_empty():
		return false
	pokemon.evolve_into(new_species)
	GameState.stats.evolution_count += 1
	if GameState.player != null:
		GameState.player.pokedex.register_owned(pokemon)
	for move_id: StringName in pokemon.moves_learned_on_evolution():
		pokemon.learn_move(move_id)
	return true
	
# === Triggers ===

## Checks [param pokemon] for if it has a level up evolution, and if so, plays it
## Both Rare Candies and field level ups call this
static func on_level_up(pokemon: Pokemon) -> bool:
	var evolve_into: StringName = EvolutionMethods.check_evolution(
		pokemon, EvolutionMethods.TRIGGER_LEVEL_UP
	)
	if evolve_into.is_empty():
		return false
	return await play(pokemon, evolve_into)
	
## Checks the [param pokemon] against the [param item_id]
## Evolutions started with stones/items cannot be cancelled
static func on_use_item(pokemon: Pokemon, item_id: StringName) -> bool:
	var evolves_into: StringName = EvolutionMethods.check_evolution(
		pokemon, EvolutionMethods.TRIGGER_USE_ITEM, item_id
	)
	if evolves_into.is_empty():
		return false
	return await play(pokemon, evolves_into, false)
	
## Checks if [param pokemon] has a trade evolution with [param partner]
# TODO: Do I cover normal trades?
static func on_trade(pokemon: Pokemon, partner: Pokemon) -> bool:
	var evolves_into: StringName = EvolutionMethods.check_evolution(
		pokemon, EvolutionMethods.TRIGGER_TRADE, partner
	)
	if evolves_into.is_empty():
		return false
	return await play(pokemon, evolves_into)
	
## Checks the entire party after a battle to see if there are any pending evolutions.
## A member that earned a level in battle is checked for a level up evolution
## Failing that, they're all checked for any evolutions the battle may have otherwise caused,
## This reads [param battle_tally]
static func after_battle(battle_tally: BattleTally) -> void:
	if GameState.party == null:
		return
	var battled: Array[Pokemon] = GameState.party.duplicate()
	for pokemon: Pokemon in battled:
		if pokemon == null or pokemon.is_egg():
			continue
		if pokemon.is_fainted() and not GameSettings.data.check_evolution_for_fainted_pokemon:
			continue
		var evolves_into: StringName = &""
		if battle_tally != null and battle_tally.gained_a_level(pokemon):
			evolves_into = EvolutionMethods.check_evolution(pokemon, EvolutionMethods.TRIGGER_LEVEL_UP)
		if evolves_into.is_empty():
			evolves_into = EvolutionMethods.check_evolution(
				pokemon, EvolutionMethods.TRIGGER_AFTER_BATTLE, battle_tally
			)
		if evolves_into.is_empty():
			continue
		await play(pokemon, evolves_into)
		
## Initiates an evolution that awaits an event number [param event_number]
##
## Every event that can cause an evoluiotn has an unique number,
## This number is stored as the species' evolution parameter 
## (such as `1` for Kubfu's tower and `2` for Galarian Yamask slab)
static func by_event(event_number: int) -> bool:
	if GameState.party == null:
		return false
	var evolved: bool = false
	for pokemon: Pokemon in GameState.party.members.duplicate():
		if pokemon == null or not pokemon.is_able():
			continue
		var into: StringName = EvolutionMethods.check_evolution(
			pokemon, EvolutionMethods.TRIGGER_EVENT, event_number
		)
		if into.is_empty():
			continue
		if await play(pokemon, into):
			evolved = true
	return evolved
