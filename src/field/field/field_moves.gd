class_name FieldMoves
## Field behaviours such as surfing, fishing, breaking a rock

const SURF_MOVE: StringName = &"SURF"
const DIVE_MOVE: StringName = &"DIVE"
const FLY_MOVE: StringName = &"FLY"
const ROCK_SMASH_MOVE: StringName = &"ROCKSMASH"
const HEADBUTT_MOVE: StringName = &"HEADBUTT"
const SWEET_SCENT_MOVE: StringName = &"SWEETSCENT"

## How long after casting before it's possible for a bite
const FISHING_SECONDS: float = 1.2

## If adding a rod here, also remember to update [method encounter_type_for_rod] or else it'll have Old Rod encounters
const ROD_ITEMS: Array[StringName] = [&"OLDROD", &"GOODROD", &"SUPERROD"]

# === Surf === 

## Returns `true` when the player meets all the conditions to surf
static func can_start_surf() -> bool:
	var field: MapController = Field.controller()
	if field == null or GameState.is_surfing():
		return false
	if GameState.party.first_with_move(SURF_MOVE) == null:
		return false
	var terrain: TerrainTagData = field.terrain_at(field.player.tile_ahead())
	return terrain != null and terrain.can_surf_freely()

## Asks if the player wishes to surf and puts them on the water if they do.
## Returns `true` if they set off.
static func offer_surf() -> bool:
	if not can_start_surf():
		return false
	var user: Pokemon = GameState.party.first_with_move(SURF_MOVE)
	_hold_player(true)
	var accepted: bool = await Field.confirm("The water is a deep blue...\nWould you like to surf on it?")
	if not accepted:
		_hold_player(false)
		return false
	await _announce(SURF_MOVE, user)
	await start_surf()
	_hold_player(false)
	return true

## Puts the player on the water in front of them
static func start_surf() -> void:
	var field: MapController = Field.controller()
	if field == null or GameState.is_surfing():
		return
	GameState.movement_state = GameState.MovementState.SURFING
	GameState.stats.surf_count += 1
	field.player.refresh_charset()
	_begin_surf_music()
	await field.player.force_step(field.player.facing)


## Takes the player off the water
static func end_surf() -> void:
	var field: MapController = Field.controller()
	if not GameState.is_surfing():
		return
	GameState.movement_state = GameState.MovementState.WALKING
	if field != null:
		field.player.refresh_charset()
	_end_surf_music()

## Pauses the map's music and starts the surfing theme
static func _begin_surf_music() -> void:
	AudioManager.push_bgm_position()
	var track: String = _surf_bgm()
	if not track.is_empty():
		AudioManager.play_bgm(track, 1.0, 1.0, true)

static func _end_surf_music() -> void:
	AudioManager.pop_bgm_position()

static func _surf_bgm() -> String:
	var metadata: MetadataData = Database.metadata()
	return metadata.surf_bgm if metadata != null and not metadata.surf_bgm.is_empty() else ""


# === Dive ===

## The dive map bellow the player's current position
## Returns `0` if there isn't one
static func dive_map_below() -> int:
	var metadata: MapMetadataData = GameState.current_map_metadata()
	return metadata.dive_map_id if metadata != null else 0

## The surface map above the player
## Returns `0` if there isn't one
static func surface_map_above() -> int:
	return Database.surface_map_for(GameState.map_id)

## Returns `true` if the conditions to dive are satisfied
static func is_over_dive_spot() -> bool:
	var field: MapController = Field.controller()
	if field == null or GameState.is_diving() or not GameState.is_surfing():
		return false
	if dive_map_below() <= 0:
		return false
	var terrain: TerrainTagData = field.terrain_at(field.player.tile_position)
	return terrain != null and terrain.can_dive

## Returns `true` if the player could surface from a dive
static func is_under_surfacing_spot() -> bool:
	var field: MapController = Field.controller()
	if field == null or not GameState.is_diving():
		return false
	var above: int = surface_map_above()
	if above <= 0:
		return false
	return _surface_terrain_at(above, field.player.tile_position) != null

## A copy of the map above for reference, not to be added to the tree
static var _surface_probe: GameMap = null
static var _surface_probe_map: int = 0

## The terrain of [param surface_map] at [param cell] if it can be dived through
## Returns `null` for anything else
## Dive and Surface maps that correlate share a coordinate system
static func _surface_terrain_at(surface_map: int, cell: Vector2i) -> TerrainTagData:
	var probe: GameMap = _probe_for(surface_map)
	if probe == null:
		return null
	var terrain: TerrainTagData = probe.terrain_at(cell)
	return terrain if terrain != null and terrain.can_dive else null

static func _probe_for(surface_map: int) -> GameMap:
	if _surface_probe_map == surface_map and is_instance_valid(_surface_probe):
		return _surface_probe
	release_surface_probe()
	var scene: PackedScene = MapIndex.get_index().load_map(surface_map)
	if scene == null:
		return null
	_surface_probe = scene.instantiate() as GameMap
	_surface_probe_map = surface_map if _surface_probe != null else 0
	return _surface_probe

## Frees the copy of the surface map (not the version in the tree but the version kept in memory)
static func release_surface_probe() -> void:
	if is_instance_valid(_surface_probe):
		_surface_probe.free()
	_surface_probe = null
	_surface_probe_map = 0

## Offers to dive, or to come back up
## Returns true if accepted
static func offer_dive() -> bool:
	if is_over_dive_spot():
		return await _offer_dive_down()
	if is_under_surfacing_spot():
		return await _offer_surfacing()
	return false

static func _offer_dive_down() -> bool:
	var user: Pokemon = GameState.party.first_with_move(DIVE_MOVE)
	_hold_player(true)
	if user == null:
		await Field.say("The sea is deep here. A Pokemon may be able to go underwater.")
		_hold_player(false)
		return false
	if not await Field.confirm("The sea is deep here.\nWould you like to use Dive?"):
		_hold_player(false)
		return false
	await _announce(DIVE_MOVE, user)
	await dive()
	_hold_player(false)
	return true

static func _offer_surfacing() -> bool:
	var user: Pokemon = GameState.party.first_with_move(DIVE_MOVE)
	_hold_player(true)
	if user == null:
		await Field.say("Light is filtering down from above. A Pokemon may be able to surface here.")
		_hold_player(false)
		return false
	if not await Field.confirm("Light is filtering down from above.\nWould you like to use Dive?"):
		_hold_player(false)
		return false
	await _announce(DIVE_MOVE, user)
	await surface()
	_hold_player(false)
	return true

## Takes the player down to the map below onto the same cell, facing the same way
static func dive() -> void:
	var field: MapController = Field.controller()
	var below: int = dive_map_below()
	if field == null or below <= 0 or GameState.is_diving():
		return
	if GameState.is_surfing():
		_end_surf_music()
	GameState.movement_state = GameState.MovementState.DIVING
	GameState.stats.dive_count += 1
	await _move_between_dive_maps(field, below)

## Brings the player back up to the map above to the place from whence they came
static func surface() -> void:
	var field: MapController = Field.controller()
	var above: int = surface_map_above()
	if field == null or above <= 0 or not GameState.is_diving():
		return
	GameState.movement_state = GameState.MovementState.SURFING
	await _move_between_dive_maps(field, above)
	release_surface_probe()
	_begin_surf_music()

## Warps specifically between dive maps, setting movement state before warp so that the charset is consistent
static func _move_between_dive_maps(field: MapController, target_map: int) -> void:
	var cell: Vector2i = field.player.tile_position
	await field.warp_to_map_id(
		target_map, cell, int(field.player.facing), true, MapController.NO_WALK)

# === Fly ===

## Returns `true` when somebody in the party knows Fly.
static func knows_fly() -> bool:
	return GameState.party.first_with_move(FLY_MOVE) != null

## Returns `true` if all the conditions to fly are presently met
static func can_fly() -> bool:
	if not knows_fly():
		return false
	if Field.in_safari_zone() or Field.in_bug_contest():
		return false
	if GameState.is_diving() or GameState.is_surfing():
		return false
	return GameState.is_outdoors()

## Opens the town map for the player to choose a destination and flies them there.
## Returns `true` when they went somewhere.
static func offer_fly() -> bool:
	if not can_fly():
		return false
	var destination: TownMapPoint = await Field.choose_fly_destination()
	if destination == null:
		return false
	await fly_to(destination)
	return true

## Flies the player to [param destination] without asking
static func fly_to(destination: TownMapPoint) -> void:
	if destination == null or not destination.is_fly_destination():
		return
	var user: Pokemon = GameState.party.first_with_move(FLY_MOVE)
	if user != null:
		await _announce(FLY_MOVE, user)
	GameState.stats.fly_count += 1
	await Field.warp_to_map(destination.fly_map_id, destination.fly_position)

# === Fishing === 

## Casts [param rod] where the player is facing
## Returns `true` if something bit and was battled
static func fish(rod: StringName) -> bool:
	var field: MapController = Field.controller()
	if field == null:
		return false
	var terrain: TerrainTagData = field.terrain_at(field.player.tile_ahead())
	if GameState.is_surfing():
		terrain = field.terrain_at(field.player.tile_position)
	if terrain == null or not terrain.can_fish:
		return false

	_hold_player(true)
	GameState.stats.fishing_count += 1
	field.player.set_pose(PlayerCharacter.Pose.FISHING)
	var encounter_type: StringName = encounter_type_for_rod(rod)
	AudioManager.play_se("Battle recall")
	await Field.wait(FISHING_SECONDS)
	GameState.force_single_battle = true
	var wild: Array[Pokemon] = field.encounters.build_encounter(
		encounter_type, terrain, GameState.is_repel_active())
	if wild.is_empty():
		await Field.say("Not even a nibble...")
		_stop_fishing(field)
		return false
	await Field.say("Oh! A bite!")
	GameState.stats.fishing_battles += 1
	_stop_fishing(field)
	await _fight(wild)
	return true

## Returns the rod away, and lets the player move again
static func _stop_fishing(field: MapController) -> void:
	if field != null and field.player != null:
		field.player.set_pose(PlayerCharacter.Pose.NORMAL)
	_hold_player(false)

static func encounter_type_for_rod(rod: StringName) -> StringName:
	match rod:
		&"GOODROD":
			return &"GoodRod"
		&"SUPERROD":
			return &"SuperRod"
	return &"OldRod"

## Return `true` when [param item_id] is one of the three rods
static func is_rod(item_id: StringName) -> bool:
	return item_id in ROD_ITEMS


# === Rock Smash, Headbutt, Sweet Scent ===

## Manages Rock Smash encoutners
## Returns `true` when one was fought
static func rock_smash_encounter() -> bool:
	var field: MapController = Field.controller()
	if field == null:
		return false
	var terrain: TerrainTagData = field.terrain_at(field.player.tile_position)
	if not field.encounters.encounter_triggered(&"RockSmash", false, false):
		return false
	return await _encounter_now(&"RockSmash", terrain)

## The encounter a headbutted tree sometimes drops.
## [param low] picks which Headbutt encounter table to use -- low rarely holds anything
static func headbutt_encounter(low: bool = false) -> bool:
	var field: MapController = Field.controller()
	if field == null:
		return false
	var terrain: TerrainTagData = field.terrain_at(field.player.tile_position)
	return await _encounter_now(&"HeadbuttLow" if low else &"HeadbuttHigh", terrain)

## Sweet Scent -- may cause a double battle in normal grass
static func sweet_scent() -> bool:
	var field: MapController = Field.controller()
	if field == null:
		return false
	var user: Pokemon = GameState.party.first_with_move(SWEET_SCENT_MOVE)
	if user == null:
		return false
	var terrain: TerrainTagData = field.terrain_at(field.player.tile_position)
	_hold_player(true)
	await _announce(SWEET_SCENT_MOVE, user)
	var encounter_type: StringName = &""
	if field.encounters.can_encounter_here(terrain):
		encounter_type = field.encounters.current_encounter_type(terrain)
	var fought: bool = false
	if not encounter_type.is_empty():
		fought = await _encounter_now(encounter_type, terrain, false)
	if not fought:
		await Field.say("But nothing appeared...")
	_hold_player(false)
	return fought

# === Internal ===

static func _hold_player(held: bool) -> void:
	var field: MapController = Field.controller()
	if field != null and field.player != null:
		field.player.accepts_input = not held

## Rolls and fights an encounter of [param encounter_type] straight away
static func _encounter_now(
	encounter_type: StringName, terrain: TerrainTagData, only_single: bool = true
) -> bool:
	var field: MapController = Field.controller()
	if field == null or not field.encounters.has_encounter_type(encounter_type):
		return false
	if only_single:
		GameState.force_single_battle = true
	var wild: Array[Pokemon] = field.encounters.build_encounter(
		encounter_type, terrain, GameState.is_repel_active())
	if wild.is_empty():
		return false
	await _fight(wild)
	return true

static func _fight(wild: Array[Pokemon]) -> void:
	var overworld: Overworld = Overworld.current
	if overworld == null:
		push_warning("FieldMoves: there is no overworld to fight in.")
		return
	if Field.in_safari_zone():
		await overworld.start_safari_battle(wild[0])
		return
	if Field.in_bug_contest():
		await overworld.start_bug_contest_battle(wild[0])
		return
	await overworld.start_wild_battle_against(wild)

## Introduces a move with the banner the hidden moves all use
static func _announce(move_id: StringName, user: Pokemon) -> void:
	await HiddenMoveBanner.announce(move_id, user, func(text: String) -> void:
		await Field.say(text)
	)
