class_name PokemonFollowers
extends RefCounted
## The pokemon walking behind the player

var field: MapController = null

var train: FollowerTrain = null

var followers: Array[PokemonFollowerCharacter] = []

## Cached value for the state of the followers
## Allows comparison to be a single string comparison instead of checking the whole party
var _signature: String = ""

var _synced: bool = false

var _watched_party: PokemonParty = null

var _watched_members: Array[Pokemon] = []


func _init(for_field: MapController = null, for_train: FollowerTrain = null) -> void:
	field = for_field
	train = for_train
	
# === Listening ===

func attach() -> void:
	if GameState == null:
		return
	if not GameState.session_started.is_connected(_on_session_started):
		GameState.session_started.connect(_on_session_started)
	if not GameState.movement_state_changed.is_connected(_on_movement_state_changed):
		GameState.movement_state_changed.connect(_on_movement_state_changed)
	_watch_party()


func detach() -> void:
	if GameState != null:
		if GameState.session_started.is_connected(_on_session_started):
			GameState.session_started.disconnect(_on_session_started)
		if GameState.movement_state_changed.is_connected(_on_movement_state_changed):
			GameState.movement_state_changed.disconnect(_on_movement_state_changed)
	_unwatch_party()
	
# === The Line ==

func refresh(force: bool = false) -> void:
	if field == null or train == null:
		return
	_prune()
	var wanted: Array[FollowerPokemon] = PokemonFollowerSettings.wanted()
	var signature: String = _signature_of(wanted)
	if _synced and not force and signature == _signature:
		return
	_signature = signature
	_synced = true
	if field.current_map == null or field.player == null:
		_clear_characters()
		return
	_reconcile(wanted)
	_resync_train()
	
func on_player_stepped() -> void:
	refresh()
	
func clear() -> void:
	_clear_characters()
	_signature = ""
	_synced = false

func count() -> int:
	return followers.size()
	
func first() -> PokemonFollowerCharacter:
	return followers[0] if not followers.is_empty() else null
	
func at_cell(world_cell: Vector2i) -> PokemonFollowerCharacter:
	for follower: PokemonFollowerCharacter in followers:
		if follower.world_cell() == world_cell:
			return follower
	return null
	
## Returns the Pokemon currently walking
func walking_pokemon() -> Array[Pokemon]:
	var walking: Array[Pokemon] = []
	for character: PokemonFollowerCharacter in followers:
		var pkmn: Pokemon = character.pokemon()
		if pkmn != null:
			walking.append(pkmn)
	return walking
	
# === Internal ===

## Listens to the party the session holds
func _watch_party() -> void:
	if GameState != null and GameState.party != _watched_party:
		_unwatch_party()
		_watched_party = GameState.party
		if _watched_party != null:
			_watched_party.party_changed.connect(_on_party_changed)
	_watch_members()
	
## Monitors the health of each party member
func _watch_members() -> void:
	_unwatch_members()
	if _watched_party == null:
		return
	for index: int in _watched_party.size():
		var member: Pokemon = _watched_party.get_member(index)
		if member != null and not member.hp_changed.is_connected(_on_member_health_changed):
			member.hp_changed.connect(_on_member_health_changed)
			_watched_members.append(member)


func _unwatch_party() -> void:
	if _watched_party != null and _watched_party.party_changed.is_connected(_on_party_changed):
		_watched_party.party_changed.disconnect(_on_party_changed)
	_watched_party = null
	_unwatch_members()


func _unwatch_members() -> void:
	for member: Pokemon in _watched_members:
		if is_instance_valid(member) and member.hp_changed.is_connected(_on_member_health_changed):
			member.hp_changed.disconnect(_on_member_health_changed)
	_watched_members.clear()


func _on_session_started() -> void:
	_watch_party()
	refresh(true)


func _on_party_changed() -> void:
	_watch_members()
	refresh()
	
func _on_member_health_changed(_old_hp: int, _new_hp: int) -> void:
	refresh()


func _on_movement_state_changed(_state: int) -> void:
	refresh()
	
## Does as little as possible to realign the followers with [param wanted]
func _reconcile(wanted: Array[FollowerPokemon]) -> void:
	for index: int in range(followers.size() - 1, wanted.size() - 1, -1):
		train.remove_follower(followers[index])
		followers.remove_at(index)
	for index: int in wanted.size():
		if index < followers.size():
			followers[index].bind(wanted[index])
			continue
		var arrival: PokemonFollowerCharacter = _spawn(wanted[index])
		if arrival == null:
			return
		followers.append(arrival)
		
## Places a new Pokemon on the map
func _spawn(wanted: FollowerPokemon) -> PokemonFollowerCharacter:
	if not wanted.is_valid():
		return null
	var sheet: String = wanted.charset_name()
	if sheet.is_empty():
		push_warning(
			"PokemonFollowers: no follower sheet for %s, and no fallback either." % wanted.species)
		return null
	if field.current_map == null:
		return null
	var follower: PokemonFollowerCharacter = PokemonFollowerCharacter.new()
	follower.name = "PokemonFollower%d" % (followers.size() + 1)
	train.adopt(follower, "")
	follower.bind(wanted)
	follower.snap_to(field.player.tile_position)
	follower.facing = field.player.facing
	return follower
	
func _resync_train() -> void:
	var partners: Array[FollowerCharacter] = []
	for follower: FollowerCharacter in train.followers:
		if not (follower is PokemonFollowerCharacter):
			partners.append(follower)
	train.followers.clear()
	for follower: PokemonFollowerCharacter in followers:
		train.followers.append(follower)
	for partner: FollowerCharacter in partners:
		train.followers.append(partner)

func _clear_characters() -> void:
	for follower: PokemonFollowerCharacter in followers:
		train.remove_follower(follower)
	followers.clear()

## Drops any character that was freed
func _prune() -> void:
	var surviving: Array[PokemonFollowerCharacter] = []
	for follower: PokemonFollowerCharacter in followers:
		if is_instance_valid(follower) and train.followers.has(follower):
			surviving.append(follower)
	if surviving.size() != followers.size():
		_synced = false
	followers = surviving
	
static func _signature_of(wanted: Array[FollowerPokemon]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: FollowerPokemon in wanted:
		parts.append(entry.signature())
	return "|".join(parts)
