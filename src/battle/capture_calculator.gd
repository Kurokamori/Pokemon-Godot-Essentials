class_name CaptureCalculator

## The Math for Poke Ball captures.
##
## Follows the Gen IV onwards mechanic of a catch rate being turned into a shake probability
# TODO: Add older mechanic types

const SIMPLE_BALL_RATES: Dictionary = {
	&"POKEBALL": 1.0,
	&"GREATBALL": 1.5,
	&"ULTRABALL": 2.0,
	&"MASTERBALL": 255.0,
	&"SAFARIBALL": 1.5,
	&"SPORTBALL": 1.5,
	&"PREMIERBALL": 1.0,
	&"CHERISHBALL": 1.0,
	&"LUXURYBALL": 1.0,
	&"HEALBALL": 1.0,
	&"FRIENDBALL": 1.0,
	&"PARKBALL": 2.5,
	&"BEASTBALL": 0.1,
} 

## Gets the Pokeball's catch multiplier based on the current situation
static func ball_multiplier(battle: Battle, target: Battler, ball_id: StringName) -> float:
	if SIMPLE_BALL_RATES.has(ball_id):
		return SIMPLE_BALL_RATES[ball_id]
	match ball_id:
		&"NETBALL":
			return 3.5 if target.has_type(&"WATER") or target.has_type(&"BUG") else 1.0
		&"DIVEBALL": 
			return 3.5 if GameState.is_surfing() or GameState.is_diving() else 1.0
		&"NESTBALL":
			return maxf((41.0 - float(target.level())) / 10.0, 1)
		&"REPEATBALL":
			return 3.5 if GameState.player != null and GameState.player.pokedex.is_owned(target.pokemon.species) else 1.0
		&"TIMERBALL":
			return minf(1.0 + (float(battle.round_number) * 1229.0 / 4096.0), 4.0)
		&"QUICKBALL":
			return 5.0 if battle.round_number <= 1 else 1.0
		&"DUSKBALL":
			var dark: bool = TimeOfDay.is_night() or GameState.is_on_dark_map()
			return 3.0 if dark else 1.0
		&"FASTBALL":
			var species: SpeciesData = target.species_data()
			return 4.0 if species != null and species.base_speed >= 100 else 1.0
		&"LEVELBALL":
			var player_level: int = GameState.party.highest_level()
			if player_level >= target.level() * 4:
				return 8.0
			if player_level >= target.level() * 2:
				return 4.0
			if player_level > target.level():
				return 2.0
			return 1.0
		&"LUREBALL":
			return 4.0 if GameState.is_surfing() else 1.0
		&"HEAVYBALL":
			var species: SpeciesData = target.species_data()
			var weight: int = species.weight if species != null else 0
			if weight >= 3000:
				return 3.0
			if weight >= 2000:
				return 2.0
			if weight <= 1000:
				return 0.5
			return 1.0
		&"LOVEBALL":
			var leading: Pokemon = GameState.party.first_able()
			if leading == null or leading.species != target.pokemon.species:
				return 1.0
			return 8.0 if leading.gender() != target.pokemon.gender() else 1.0
		&"MOONBALL":
			var species: SpeciesData = target.species_data()
			if species == null:
				return 1.0
			for evo: SpeciesEvolution in species.get_evolutions():
				if evo.method == &"Item" and evo.parameter_as_id() == &"MOONSTONE":
					return 4.0
			return 1.0
		&"DREAMBALL":
			return 4.0 if target.pokemon.status == &"SLEEP" else 1.0
	return 1.0
	
## The modifier applied to the catch rate from Statuses
static func status_multiplier(target: Battler) -> float:
	match target.pokemon.status:
		&"SLEEP", &"FROZEN":
			return 2.5
		&"POISON", &"BURN", &"PARALYSIS":
			return 1.5
	return 1.0
	
## Returns the final modified catch rate
static func catch_rate(battle: Battle, target: Battler, ball_id: StringName) -> float:
	var species: SpeciesData = target.species_data()
	if species == null:
		return 0.0
	var base: float = float(species.catch_rate)
	var due_hp: float = (3.0 * float(target.total_hp()) - 2.0 * float(target.hp())) / (3.0 * float(target.total_hp()))
	var rate: float = base * due_hp
	rate *= ball_multiplier(battle, target, ball_id)
	rate *= status_multiplier(target)
	rate *= target.safari_catch_factor
	return clampf(rate, 0.0, 255.0)
	
## Rolls how many shakes the player actually gets
## Returns 0-4 -- four shakes means caught.
static func roll_shakes(battle: Battle, target: Battler, ball_id: StringName) -> int:
	if ball_id == &"MASTERBALL":
		return 4
	var rate: float = catch_rate(battle, target, ball_id)
	if rate <= 0.0:
		return 0
	if rate >= 255.0:
		return 4
	var shake_probability: int = int(65536.0 / pow(255.0 / rate, 0.1875))
	for shake: int in range(4):
		if RNG.below(65536) >= shake_probability:
			return shake
	return 4
	
## Returns `true` if the throw succeeds, without shake details
static func rolls_capture(battle: Battle, target: Battler, ball_id: StringName) -> bool:
	return roll_shakes(battle, target, ball_id) >= 4
