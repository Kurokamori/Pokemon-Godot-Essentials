class_name PokemonFollowerSettings
## Decides what the rules are about pokemon followers
##
## Decided with authority in this order:
## The Project - [GameSettingsData]
## The Player Settings (if the player is allowed to choose)
## The Session - If anything has actively overwritten it

const OPTIONS_SECTION: String = "player"

const NOBODY_CHOSEN: int = -1

const NO_OVERRIDE: int = -1

# === Mode ===

static func effective_mode() -> int:
	if GameState != null and GameState.follower_mode_override != NO_OVERRIDE:
		return FollowerMode.sanitised(GameState.follower_mode_override)
	return player_mode()
	
static func player_mode() -> int:
	if GameSettings == null or GameSettings.data == null:
		return FollowerMode.Mode.LEAD
	return FollowerMode.sanitised(GameSettings.data.follower_mode)
	
## Sets player to [param mode] and writes it to options
static func set_player_mode(mode: int) -> bool:
	if GameSettings == null or GameSettings.data == null:
		return false
	if not allowed_modes().has(mode):
		return false
	GameSettings.data.follower_mode = mode as FollowerMode.Mode
	var config: ConfigFile = ConfigFile.new()
	config.load(GameSettings.OPTIONS_PATH)
	config.set_value(OPTIONS_SECTION, FollowerMode.OPTIONS_KEY, FollowerMode.to_name(mode))
	config.save(GameSettings.OPTIONS_PATH)
	return true
	
## Lists the modes from game settings
## Empty or completely unrecognized is all of them
static func allowed_modes() -> Array[int]:
	var offered: Array[int] = []
	if GameSettings != null and GameSettings.data != null:
		for mode: int in FollowerMode.ALL:
			if GameSettings.data.follower_allowed_modes.has(mode):
				offered.append(mode)
	if offered.is_empty():
		return FollowerMode.ALL.duplicate()
	return offered
	
## Enforces a set mode, passing [constant NO_OVERRIDE] or call [method clear_session_mode] to 
## return to the game default / player choice
static func set_session_mode(mode: int) -> void:
	if GameState == null:
		return
	GameState.follower_mode_override = mode if FollowerMode.is_valid(mode) else NO_OVERRIDE
	
static func clear_session_mode() -> void:
	set_session_mode(NO_OVERRIDE)
	
# === The Selected Follower ===

## What party slot the player has chosen, or [constant NOBODY_CHOSEN]
static func chosen_index() -> int:
	if GameState == null:
		return NOBODY_CHOSEN
	return GameState.follower_chosen_index
	
## Sets [param index] to walk with the player, passing the selected index or [constant NOBODY_CHOSEN] clears it.
static func set_chosen_index(index: int) -> bool:
	if GameState == null:
		return false
	var slot: int = index
	if slot == GameState.follower_chosen_index:
		slot = NOBODY_CHOSEN
	if slot != NOBODY_CHOSEN and GameState.party.get_member(slot) == null:
		return false
	GameState.follower_chosen_index = slot
	return true
	
# === Eligibility ===

static func may_walk(pkmn: Pokemon) -> bool:
	if pkmn == null:
		return false
	if GameSettings == null or GameSettings.data == null:
		return not pkmn.is_egg() and not pkmn.is_fainted()
	if pkmn.is_egg() and not GameSettings.data.follower_includes_eggs:
		return false
	if pkmn.is_fainted() and not GameSettings.data.follower_includes_fainted:
		return false
	return true
	
## Returns `true` if the followers are unavailable or disabled
static func is_suppressed() -> bool:
	if GameState == null or not GameState.has_session():
		return true
	if GameState.followers_hidden:
		return true
	if GameSettings == null or GameSettings.data == null:
		return false
	if GameSettings.data.follower_hidden_while_surfing and (
		GameState.is_surfing() or GameState.is_diving()
	):
		return true
	if GameSettings.data.follower_hidden_while_cycling and GameState.is_cycling():
		return true
	return false
	
# === The Line ===

## Returns the pokemon that should be walking behind the player, nearest to the player first
static func wanted() -> Array[FollowerPokemon]:
	var line: Array[FollowerPokemon] = []
	if is_suppressed():
		return line
	var temporary: Array[FollowerPokemon] = temporary_followers()
	if not temporary.is_empty():
		return temporary
	match effective_mode():
		FollowerMode.Mode.LEAD:
			_append_first_eligible(line)
		FollowerMode.Mode.CHOSEN:
			_append_chosen(line)
		FollowerMode.Mode.FIXED_SPECIES:
			_append_fixed_species(line)
		FollowerMode.Mode.WHOLE_PARTY:
			_append_whole_party(line)
	return line
	
## Set temporary followers placed here by script
static func temporary_followers() -> Array[FollowerPokemon]:
	var entries: Array[FollowerPokemon] = []
	if GameState == null:
		return entries
	var followers_are_off: bool = effective_mode() == FollowerMode.Mode.NONE
	for saved: Variant in GameState.follower_overrides:
		if not (saved is Dictionary):
			continue
		var entry: FollowerPokemon = FollowerPokemon.from_dict(saved as Dictionary)
		if entry.party_index != FollowerPokemon.NOT_IN_PARTY:
			var member: Pokemon = GameState.party.get_member(entry.party_index)
			if member == null:
				continue
			var forced: bool = entry.forced
			entry = FollowerPokemon.from_pokemon(member, entry.party_index)
			entry.forced = forced
		if followers_are_off and not entry.forced:
			continue
		if entry.is_valid():
			entries.append(entry)
	return entries
	
static func maximum() -> int:
	if GameSettings == null or GameSettings.data == null:
		return 6
	return maxi(GameSettings.data.follower_maximum, 0)
	
# === Modes ===

static func _append_first_eligible(line: Array[FollowerPokemon]) -> void:
	for index: int in GameState.party.size():
		var member: Pokemon = GameState.party.get_member(index)
		if may_walk(member):
			line.append(FollowerPokemon.from_pokemon(member, index))
			return
			
static func _append_chosen(line: Array[FollowerPokemon]) -> void:
	var index: int = chosen_index()
	if index != NOBODY_CHOSEN:
		var member: Pokemon = GameState.party.get_member(index)
		if may_walk(member):
			line.append(FollowerPokemon.from_pokemon(member, index))
			return
	_append_first_eligible(line)
	
static func _append_fixed_species(line: Array[FollowerPokemon]) -> void:
	if GameSettings == null or GameSettings.data == null:
		return
	var species: StringName = GameSettings.data.follower_species
	if species.is_empty():
		return
	for index: int in GameState.party.size():
		var member: Pokemon = GameState.party.get_member(index)
		if member != null and member.species == species and may_walk(member):
			line.append(FollowerPokemon.from_pokemon(member, index))
			return
	if GameSettings.data.follower_species_needs_party:
		return
	if Database.species(species) == null:
		push_warning(
			"PokemonFollowerSettings: follower_species is set to '%s', which is not a species."
			% species)
		return
	line.append(FollowerPokemon.from_species(species, GameSettings.data.follower_species_form))
	
static func _append_whole_party(line: Array[FollowerPokemon]) -> void:
	var room: int = maximum()
	for index: int in GameState.party.size():
		if line.size() >= room:
			return
		var member: Pokemon = GameState.party.get_member(index)
		if may_walk(member):
			line.append(FollowerPokemon.from_pokemon(member, index))
