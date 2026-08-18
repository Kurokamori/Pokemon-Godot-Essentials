class_name FollowerTrain
extends RefCounted
## Manages the line of characters walking behind the player.
## Default spacing between consecutive followers.
const CELLS_PER_FOLLOWER: int = 1

## Maximum recorded trail length.
const TRAIL_LENGTH: int = 64

## The field the line is walking on.
var field: MapController = null

## Configured spacing between consecutive followers.
var cells_per_follower: int = CELLS_PER_FOLLOWER

var followers: Array[FollowerCharacter] = []

## Cells the player has stood on, most recent first, in world cells.
var _trail: Array[Vector2i] = []

func _init(for_field: MapController = null) -> void:
	field = for_field
	if GameSettings != null and GameSettings.data != null:
		cells_per_follower = maxi(GameSettings.data.follower_spacing, 1)

# === Membership ===

## Adds an event as a follower.
func add_event(event: MapEvent, name: String = "", common_event_id: int = 0) -> FollowerCharacter:
	if event == null or field == null:
		return null
	var follower: FollowerCharacter = _spawn(
		name if not name.is_empty() else event.display_name(),
		event.charset_name(), common_event_id, event.event_id
	)
	if follower == null:
		return null
	follower.snap_to(event.tile_position)
	follower.facing = event.facing
	event.erased = true
	event.visible = false
	return follower

## Adds a script-created partner follower.
func add_charset(name: String, charset: String, common_event_id: int = 0) -> FollowerCharacter:
	var follower: FollowerCharacter = _spawn(name, charset, common_event_id, 0)
	if follower == null:
		return null
	put_on_player()
	return follower

## Adds an existing follower to the line.
func adopt(follower: FollowerCharacter, charset: String = "") -> FollowerCharacter:
	if follower == null or field == null or field.current_map == null:
		return null
	field.current_map.characters_root().add_child(follower)
	follower.map = field
	follower.home_map = field.current_map
	if not charset.is_empty():
		follower.set_charset(charset)
	followers.append(follower)
	return follower

## Returns the follower at a world cell.
func at_cell(world_cell: Vector2i) -> FollowerCharacter:
	for follower: FollowerCharacter in followers:
		if is_instance_valid(follower) and follower.world_cell() == world_cell:
			return follower
	return null

## Returns a named partner, or the first partner.
func get_follower(name: String = "") -> FollowerCharacter:
	for follower: FollowerCharacter in followers:
		if follower is PokemonFollowerCharacter:
			continue
		if name.is_empty() or follower.follower_name == name:
			return follower
	return null

## Returns partner NPCs in walking order.
func partners() -> Array[FollowerCharacter]:
	var found: Array[FollowerCharacter] = []
	for follower: FollowerCharacter in followers:
		if not (follower is PokemonFollowerCharacter):
			found.append(follower)
	return found

## Removes a named partner from the line.
func remove(name: String) -> bool:
	var follower: FollowerCharacter = get_follower(name)
	if follower == null:
		return false
	return remove_follower(follower)

func remove_follower(follower: FollowerCharacter) -> bool:
	if follower == null or not followers.has(follower):
		return false
	followers.erase(follower)
	follower.queue_free()
	return true

## Removes every follower from the line.
func clear() -> void:
	for follower: FollowerCharacter in followers:
		follower.queue_free()
	followers.clear()

## Removes partner NPCs while keeping Pokemon followers.
func clear_partners() -> void:
	for follower: FollowerCharacter in partners():
		remove_follower(follower)

func has_followers() -> bool:
	return not followers.is_empty()

func count() -> int:
	return followers.size()

# === Movement ===

## Records a step and moves the follower line.
func on_player_stepped() -> void:
	if field == null or field.player == null:
		return
	_trail.push_front(field.player.world_cell())
	if _trail.size() > TRAIL_LENGTH:
		_trail.resize(TRAIL_LENGTH)
	if followers.is_empty():
		return
	var seconds: float = field.player.seconds_per_tile
	for index: int in followers.size():
		var target: Variant = _trail_cell(index)
		if target == null:
			continue
		_walk_follower(followers[index], target, seconds)

## Places the whole line on the player.
func put_on_player() -> void:
	if field == null or field.player == null or field.current_map == null:
		return
	_trail.clear()
	for follower: FollowerCharacter in followers:
		_reparent_to_player_map(follower)
		follower.snap_to(field.player.tile_position)
		follower.facing = field.player.facing

## Detaches the line before a map transfer.
func detach_from_map(host: Node) -> void:
	_trail.clear()
	for follower: FollowerCharacter in followers:
		if not is_instance_valid(follower):
			continue
		if follower.get_parent() != host:
			follower.reparent(host)
		follower.home_map = null

## Walks the line through a doorway.
func follow_into_door() -> void:
	if field == null or field.player == null:
		return
	var seconds: float = field.player.seconds_per_tile
	for follower: FollowerCharacter in followers:
		_reparent_to_player_map(follower)
		var steps: int = 0
		# Stop after a limited number of steps if scenery blocks the follower.
		while follower.tile_position != field.player.tile_position and steps < TRAIL_LENGTH:
			await follower.move_towards(_step_towards(follower.tile_position, field.player.tile_position), seconds)
			steps += 1
		follower.visible = false
	_trail.clear()

## Hides every follower.
func hide_followers() -> void:
	for follower: FollowerCharacter in followers:
		follower.visible = false

## Shows the line and places it behind the player.
func show_followers() -> void:
	put_on_player()
	reveal()

## Reveals the line without moving it.
func reveal() -> void:
	for follower: FollowerCharacter in followers:
		follower.visible = true

# === Internals ===

func _spawn(
	name: String, charset: String, common_event_id: int, source_event_id: int
) -> FollowerCharacter:
	if field == null or field.current_map == null:
		return null
	if not name.is_empty() and get_follower(name) != null:
		return null
	var follower: FollowerCharacter = FollowerCharacter.new()
	follower.name = "Follower%d" % (followers.size() + 1)
	follower.follower_name = name
	follower.common_event_id = common_event_id
	follower.source_event_id = source_event_id
	return adopt(follower, charset)

## Returns the trail cell for a follower.
func _trail_cell(index: int) -> Variant:
	var position: int = (index + 1) * maxi(cells_per_follower, 1)
	if position < 0 or position >= _trail.size():
		return null
	return _trail[position]

## Moves a follower to a world cell.
func _walk_follower(follower: FollowerCharacter, world_cell: Vector2i, seconds: float) -> void:
	_reparent_to_player_map(follower)
	follower.move_towards(follower.local_cell(world_cell), seconds)

## Moves a follower onto the player map.
func _reparent_to_player_map(follower: FollowerCharacter) -> void:
	if field == null or field.player == null:
		return
	var home: GameMap = field.player.home_map
	if home == null or follower.home_map == home:
		return
	var world: Vector2i = follower.world_cell()
	if follower.get_parent() != home.characters_root():
		follower.reparent(home.characters_root())
	follower.home_map = home
	follower.snap_to(field.to_map_cell(home, world))

## Returns the next cell toward a target.
static func _step_towards(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta: Vector2i = to - from
	if delta == Vector2i.ZERO:
		return from
	if absi(delta.x) >= absi(delta.y):
		return from + Vector2i(signi(delta.x), 0)
	return from + Vector2i(0, signi(delta.y))
