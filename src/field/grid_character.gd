@tool
class_name GridCharacter
extends Node2D

## A 2D, tile based character with an animated 4-directional sprite. Shared by the player, followers, and events.
##
## The sprite is the child named `CharacterSprite`

enum Direction {
	DOWN = 2,
	LEFT = 4,
	RIGHT = 6,
	UP = 8
}


const DIRECTION_VECTORS: Dictionary = {
	Direction.DOWN: Vector2i(0, 1),
	Direction.LEFT: Vector2i(-1, 0),
	Direction.RIGHT: Vector2i(1, 0),
	Direction.UP: Vector2i(0, -1),
}

## Row in the character sheet for each direction
const DIRECTION_ROWS: Dictionary = {
	Direction.DOWN: 0,
	Direction.LEFT: 1,
	Direction.RIGHT: 2,
	Direction.UP: 3,
}

const FRAMES_PER_DIRECTION: int = 4
const SPRITE_NODE_NAME: String = "CharacterSprite"

## The amount of tiles to cross for a full walk cycle so that each stand + step is one tile, and two tiles alternates left/right
const TILES_PER_WALK_CYCLE: float = 2.0

## Anything faster than this stretches to twice as many tiles, allowing the sprites to look decent at high speeds
const CYCLING_SECONDS_PER_TILE: float = 0.1221

## Material that hides the bottom of a character standing in grass.
const BUSH_MATERIAL_PATH: String = "res://shaders/bush_depth_material.tres"

## Pixels hidden by shallow grass
const SHALLOW_BUSH_DEPTH: int = 12

const REFLECTION_NODE_NAME: String = "CharacterReflection"
const SHADOW_NODE_NAME: String = "CharacterShadow"
const DYNAMIC_SHADOWS_NODE_NAME: String = "DynamicShadows"

## How solid a reflection is drawn, and the colour it takes from the water.
const REFLECTION_ALPHA: float = 0.5
const REFLECTION_TINT: Color = Color(0.78, 0.86, 1.0, REFLECTION_ALPHA)

## How far a rippling reflection wanders sideways
const REFLECTION_RIPPLE_PIXELS: float = 1.0
## How long a water wobble takes
const REFLECTION_RIPPLE_SECONDS: float = 0.9

signal step_started(from: Vector2i, to: Vector2i)
signal step_finished(position: Vector2i)
signal direction_changed(direction: Direction)

## The cell this character occupies. Derived from [member Node2D.position]
var tile_position: Vector2i = Vector2i.ZERO:
	set(value):
		tile_position = value
		if is_inside_tree() and not is_moving:
			position = MapGrid.cell_to_pixel(value)

@export var facing: Direction = Direction.DOWN:
	set(value):
		if value == facing:
			return
		facing = value
		_update_frame()
		direction_changed.emit(facing)

## How many seconds it takes to cross one tile
@export var seconds_per_tile: float = 0.5

## Whether or not to ignore passable and other characters
@export var passable: bool = false

## Whether or not to stay facing a direction regardless of movement
@export var direction_fix: bool = false

## Animates the sprite while stationary
@export var step_animation: bool = false

## Animates the sprite while walking.
## Can be disabled to move the character without animation them (for example for ice)
@export var walk_animation: bool = true

## The frame of the character sheet being displayed.
var pattern: int = 0:
	set(value):
		pattern = wrapi(value, 0, FRAMES_PER_DIRECTION)
		_apply_sprite_frame(facing, pattern)

## The frame a character is on once they stop walking.
var original_pattern: int = 0

## Holds the sprite on whichever frame it is displaying, whatever the character does.
var lock_pattern: bool = false

## Pixels the sprite is lifted off the cell it stands on, without the character having moved.
## Allows for a visual offset without altering walk checks
var sprite_lift: int = 0:
	set(value):
		if value == sprite_lift:
			return
		sprite_lift = value
		_apply_sprite_frame(facing, pattern)

var is_moving: bool = false

## The cell this character started on, mostly for wandering NPCs so they don't wander too far
var origin_cell: Vector2i = Vector2i.ZERO

## Pixels of this character's sprite currently hidden by the grass they are standing in.
var bush_depth: int = 0

## The field this character belongs to, used for collision queries.
var map: MapController = null

## The map scene [member tile_position] is counted on.
## Useful because we can often see more than one map at a time so this allows querries to stay native to their map.
var home_map: GameMap = null

var _sprite: Sprite2D = null

## Seconds since the walking sprite last changed frame
## Persists among cells so that a walking character maintains stride
var _animation_time: float = 0.0

## Set to `true` while the walk cycle is going
var _walking: bool = false

## Seconds the jump takes, or `0.0` when the character is not jumping.
var _jump_seconds: float = 0.0
var _sheet_columns: int = FRAMES_PER_DIRECTION
var _sheet_rows: int = 4
var _charset_name: String = ""

## The character drawn upside down in the water they are standing on, made on first call, and then cached.
## Is `null` for a character that has never been reflected.
var _reflection: Sprite2D = null

## How far through one wobble of the reflection this character is.
var _ripple_time: float = 0.0

## The cell the reflection was last worked out for
## So a stationary character doesn't cause rechecking
var _reflection_cell: Vector2i = Vector2i(-9999, -9999)

## The patch drawn under this character's feet
var _shadow: CharacterShadow = null

## The shadows this character throws from the lamps around it, made only for a character which casts shadows.
var _dynamic_shadows: DynamicShadows = null


func _ready() -> void:
	_ensure_sprite()
	if not Engine.is_editor_hint():
		adopt_placed_position()
		_ensure_shadow()
	_update_frame()

## Takes the starting cell from wherever the node was placed, and snaps to it.
## This allows for authoring nodes in scene, and them maintaining their plce.
## Code-spawned nodes are postioned once they're in the tree.
func adopt_placed_position() -> void:
	tile_position = MapGrid.pixel_to_cell(position)
	position = MapGrid.cell_to_pixel(tile_position)
	origin_cell = tile_position
	refresh_bush_depth()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	advance_pattern(delta)
	_advance_reflection(delta)
	_advance_dynamic_shadows()

## Moves the walk cycle on by [param delta] seconds.
##
## Called per character, per frame.
##
## Three things can happen. 
## Stopping puts the sprite back on [member original_pattern].
## Setting off from a standstill takes the first stride at once.
## Walking on runs the  timer, and because the timer and [member pattern] both survive from step to step
func advance_pattern(delta: float) -> void:
	var animating: bool = _is_animating()
	if lock_pattern:
		_walking = animating
		return
	if not animating:
		if _walking:
			_walking = false
			_animation_time = 0.0
			pattern = original_pattern
		return
	if not _walking:
		_walking = true
		_animation_time = 0.0
		pattern = pattern + 1
		return
	var pattern_time: float = pattern_cycle_seconds() / float(FRAMES_PER_DIRECTION)
	if pattern_time <= 0.0:
		return
	_animation_time += delta
	while _animation_time >= pattern_time:
		_animation_time -= pattern_time
		pattern = pattern + 1

## How long in seconds, one full four frame cycle of a walking sprite takes
func pattern_cycle_seconds() -> float:
	if _jump_seconds > 0.0:
		return _jump_seconds * TILES_PER_WALK_CYCLE
	var cycle: float = seconds_per_tile * TILES_PER_WALK_CYCLE
	if seconds_per_tile <= CYCLING_SECONDS_PER_TILE:
		cycle *= 2.0
	return cycle

## The sprite the scene provides
## Returns `null` when it has none
func _find_sprite() -> Sprite2D:
	if _sprite != null and is_instance_valid(_sprite):
		return _sprite
	_sprite = get_node_or_null(NodePath(SPRITE_NODE_NAME)) as Sprite2D
	return _sprite

## Finds the sprite the scene provides or creates one if needed.
func _ensure_sprite() -> void:
	if _find_sprite() != null:
		return
	_sprite = Sprite2D.new()
	_sprite.name = SPRITE_NODE_NAME
	_sprite.centered = false
	add_child(_sprite)

## Loads a character sheet by name.
func set_charset(sheet_name: String) -> void:
	_charset_name = sheet_name
	_apply_charset(sheet_name)
	_update_frame()

## Draws the first frame of [param sheet_name] facing [param direction]
func draw_charset_frame(sheet_name: String, direction: Direction) -> void:
	_apply_charset(sheet_name)
	_apply_sprite_frame(direction, 0)

## Points the sprite at a character sheet, or clears it when there is none.
func _apply_charset(sheet_name: String) -> void:
	var texture: Texture2D = charset_texture(sheet_name)
	if texture == null and _find_sprite() == null:
		return
	_ensure_sprite()
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.region_enabled = texture != null

## The character sheet named [param sheet_name]
## Returns `null` if empty or if nothing was found
static func charset_texture(sheet_name: String) -> Texture2D:
	if sheet_name.is_empty():
		return null
	return Assets.texture(AssetIndex.CATEGORY_CHARACTERS, sheet_name)

func charset_name() -> String:
	return _charset_name

func frame_size() -> Vector2i:
	if _sprite == null or _sprite.texture == null:
		return Vector2i(MapGrid.TILE_SIZE, MapGrid.TILE_SIZE)
	var size: Vector2i = _sprite.texture.get_size()
	return Vector2i(size.x / _sheet_columns, size.y / _sheet_rows)

## Returns `true` while the sprite should be animating
func _is_animating() -> bool:
	return (is_moving and walk_animation) or step_animation

func _update_frame() -> void:
	_apply_sprite_frame(facing, pattern)

## Shows cell [param column] of row [param direction] of the character sheet.
func _apply_sprite_frame(direction: Direction, column: int) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var size: Vector2i = frame_size()
	var row: int = int(DIRECTION_ROWS.get(direction, 0))
	_sprite.region_rect = Rect2(Vector2(column * size.x, row * size.y), size)
	_sprite.offset = Vector2(
		float(MapGrid.TILE_SIZE - size.x) / 2.0,
		float(MapGrid.TILE_SIZE - size.y - sprite_lift))
	_apply_bush_depth()
	_refresh_reflection()


# === Reflections ===

## Draws the character's reflection or removes it when it is not needed
func _refresh_reflection() -> void:
	if Engine.is_editor_hint():
		return
	var wanted: bool = _stands_on_reflective_water()
	if not wanted:
		if _reflection != null and is_instance_valid(_reflection):
			_reflection.visible = false
		return
	_ensure_reflection()
	if _reflection == null:
		return
	var size: Vector2i = frame_size()
	_reflection.visible = visible
	_reflection.texture = _sprite.texture
	_reflection.region_enabled = _sprite.region_enabled
	_reflection.region_rect = _sprite.region_rect
	_reflection.offset = Vector2(
		float(MapGrid.TILE_SIZE - size.x) / 2.0, float(MapGrid.TILE_SIZE))

func _stands_on_reflective_water() -> bool:
	if map == null or _sprite == null or _sprite.texture == null:
		return false
	var terrain: TerrainTagData = map.terrain_at_world(world_cell())
	return terrain != null and terrain.shows_reflections

## Makes the shadow, under the character.
func _ensure_shadow() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		return
	_shadow = CharacterShadow.new()
	_shadow.name = SHADOW_NODE_NAME
	add_child(_shadow)
	move_child(_shadow, 0)

## The shadow under this character's feet
## Returns null if there is no shadow
func shadow() -> CharacterShadow:
	return _shadow if _shadow != null and is_instance_valid(_shadow) else null


# === Dynamic Shadows ===

## Whether the lights on the map cast a shadow from this character.
func casts_dynamic_shadow() -> bool:
	return false

## Redraws the shadows this character casts, and makes them the first time it stands anywhere with a lamp in it.
func _advance_dynamic_shadows() -> void:
	if not casts_dynamic_shadow() or map == null:
		return
	var sources: Array[ShadowSources.Source] = map.shadow_sources()
	if sources.is_empty():
		if _dynamic_shadows != null and is_instance_valid(_dynamic_shadows):
			_dynamic_shadows.refresh(sources)
		return
	_ensure_dynamic_shadows()
	_dynamic_shadows.refresh(sources)

## Makes the node that shadows live under, once.
func _ensure_dynamic_shadows() -> void:
	if _dynamic_shadows != null and is_instance_valid(_dynamic_shadows):
		return
	_dynamic_shadows = DynamicShadows.new()
	_dynamic_shadows.name = DYNAMIC_SHADOWS_NODE_NAME
	add_child(_dynamic_shadows)
	move_child(_dynamic_shadows, 0)

## Makes the reflection sprite, once.
func _ensure_reflection() -> void:
	if _reflection != null and is_instance_valid(_reflection):
		return
	_reflection = Sprite2D.new()
	_reflection.name = REFLECTION_NODE_NAME
	_reflection.centered = false
	_reflection.flip_v = true
	_reflection.modulate = REFLECTION_TINT
	_reflection.z_index = -1
	_reflection.show_behind_parent = false
	add_child(_reflection)
	move_child(_reflection, 0)

## Animates the reflection, and keeps it true to the character.
func _advance_reflection(delta: float) -> void:
	var here: Vector2i = world_cell()
	if here != _reflection_cell:
		_reflection_cell = here
		_refresh_reflection()
		if _shadow != null and is_instance_valid(_shadow):
			_shadow.refresh()
	if _reflection == null or not is_instance_valid(_reflection) or not _reflection.visible:
		return
	if _still_reflections():
		_reflection.position.x = 0.0
		return
	_ripple_time = fmod(_ripple_time + delta, REFLECTION_RIPPLE_SECONDS)
	var phase: float = TAU * _ripple_time / REFLECTION_RIPPLE_SECONDS
	_reflection.position.x = sin(phase) * REFLECTION_RIPPLE_PIXELS

func _still_reflections() -> bool:
	var metadata: MapMetadataData = null
	if home_map != null:
		metadata = Database.map_metadata(home_map.map_id)
	return metadata != null and metadata.still_reflections


# === Bush Depth ===

## Figures out how much of the character to hide with grass/bushes
func refresh_bush_depth() -> void:
	var depth: int = _calculate_bush_depth()
	if depth == bush_depth:
		return
	bush_depth = depth
	_apply_bush_depth()

func _calculate_bush_depth() -> int:
	if map == null or passable:
		return 0
	var here: Vector2i = world_cell()
	if map.is_deep_bush_at(here):
		if not is_moving:
			return MapGrid.TILE_SIZE
		var behind: Vector2i = here - Vector2i(DIRECTION_VECTORS[facing])
		return MapGrid.TILE_SIZE if map.is_deep_bush_at(behind) else 0
	if not is_moving and map.is_bush_at(here):
		return SHALLOW_BUSH_DEPTH
	return 0

func _apply_bush_depth() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.refresh()
	if _sprite == null:
		return
	if bush_depth <= 0 and _sprite.material == null:
		return
	_ensure_bush_material()
	var bush_material: ShaderMaterial = _sprite.material as ShaderMaterial
	if bush_material == null:
		return
	var sheet_height: float = 0.0
	if _sprite.texture != null:
		sheet_height = float(_sprite.texture.get_size().y)
	bush_material.set_shader_parameter("bush_depth", float(bush_depth))
	bush_material.set_shader_parameter("frame_top", _sprite.region_rect.position.y)
	bush_material.set_shader_parameter("frame_height", float(frame_size().y))
	bush_material.set_shader_parameter("sheet_height", sheet_height)

## Gives this sprite the bush material, if it already has a material, it is not given one.
func _ensure_bush_material() -> void:
	if _sprite.material != null:
		return
	var shared: ShaderMaterial = load(BUSH_MATERIAL_PATH) as ShaderMaterial
	if shared == null:
		push_error("GridCharacter: the bush material is missing from %s." % BUSH_MATERIAL_PATH)
		return
	_sprite.material = shared.duplicate()

static func tile_to_pixel(tile: Vector2i) -> Vector2:
	return MapGrid.cell_to_pixel(tile)

## Which way somebody at [param from] would turn to look at [param to].
## The larger axis wins. 
static func direction_towards(from: Vector2i, to: Vector2i) -> Direction:
	var delta: Vector2i = to - from
	if absi(delta.x) > absi(delta.y):
		return Direction.RIGHT if delta.x > 0 else Direction.LEFT
	return Direction.DOWN if delta.y > 0 else Direction.UP

static func opposite(direction: Direction) -> Direction:
	match direction:
		Direction.DOWN: return Direction.UP
		Direction.UP: return Direction.DOWN
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
	return Direction.DOWN

## Seconds per cell for an movement speed
static func speed_to_seconds(speed: int) -> float:
	return clampf(0.8 / pow(1.6, float(speed - 1)), 0.05, 2.0)

## Where this character is standing in the field, so it can be compared to a character on another map.
func world_cell() -> Vector2i:
	if map == null or home_map == null:
		return tile_position
	return map.to_world_cell(home_map, tile_position)

## [param world_cell] said in this character's own cells.
func local_cell(world: Vector2i) -> Vector2i:
	if map == null or home_map == null:
		return world
	return map.to_map_cell(home_map, world)

func facing_vector() -> Vector2i:
	return DIRECTION_VECTORS[facing]

## The cell directly in front of this character.
func tile_ahead(distance: int = 1) -> Vector2i:
	return tile_position + (facing_vector() * distance)

## Turns to face [param direction] without moving.
func turn(direction: Direction) -> void:
	if direction_fix:
		return
	facing = direction

## Attempts to step one cell in [param direction]. 
## Returns `false` if there's collision or the character is already in motion
func step(direction: Direction) -> bool:
	if is_moving:
		return false
	turn(direction)
	var target: Vector2i = tile_position + Vector2i(DIRECTION_VECTORS[direction])
	if not can_enter(target, direction):
		return false
	await _move_to(target)
	return true

func step_diagonal(horizontal: Direction, vertical: Direction) -> bool:
	if is_moving:
		return false
	if not direction_fix:
		if facing == opposite(horizontal):
			facing = horizontal
		elif facing == opposite(vertical):
			facing = vertical
	if not can_enter_diagonally(horizontal, vertical):
		return false
	var offset: Vector2i = Vector2i(DIRECTION_VECTORS[horizontal]) + Vector2i(DIRECTION_VECTORS[vertical])
	await _move_to(tile_position + offset)
	return true


## Return `true` if a diagonal step is permitted
func can_enter_diagonally(horizontal: Direction, vertical: Direction) -> bool:
	if passable:
		return true
	if map == null:
		return true
	var sideways: Vector2i = tile_position + Vector2i(DIRECTION_VECTORS[horizontal])
	var upright: Vector2i = tile_position + Vector2i(DIRECTION_VECTORS[vertical])
	var target: Vector2i = sideways + Vector2i(DIRECTION_VECTORS[vertical])
	var around_the_side: bool = (
		map.is_passable(self, tile_position, sideways, horizontal)
		and map.is_passable(self, sideways, target, vertical)
	)
	if around_the_side:
		return true
	return (
		map.is_passable(self, tile_position, upright, vertical)
		and map.is_passable(self, upright, target, horizontal)
	)


## Moves to an adjacent cell without a passability check
func force_step(direction: Direction) -> void:
	if is_moving:
		return
	turn(direction)
	await _move_to(tile_position + Vector2i(DIRECTION_VECTORS[direction]))


func _move_to(target: Vector2i) -> void:
	var origin: Vector2i = tile_position
	is_moving = true
	step_started.emit(origin, target)
	tile_position = target
	refresh_bush_depth()
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", MapGrid.cell_to_pixel(target), seconds_per_tile)
	await tween.finished
	is_moving = false
	refresh_bush_depth()
	step_finished.emit(target)


## Returns `true` when this character may enter [param target] moving in [param direction].
func can_enter(target: Vector2i, direction: Direction) -> bool:
	if passable:
		return true
	if map == null:
		return true
	return map.is_passable(self, tile_position, target, direction)


## Jumps a number of cells, used for ledges.
func jump(offset: Vector2i, duration: float = 0.35) -> void:
	if is_moving:
		return
	var target: Vector2i = tile_position + offset
	is_moving = true
	_jump_seconds = duration
	step_started.emit(tile_position, target)
	tile_position = target
	bush_depth = 0
	_apply_bush_depth()
	var destination: Vector2 = MapGrid.cell_to_pixel(target)
	var start: Vector2 = position
	var tween: Tween = create_tween()
	tween.tween_method(func(progress: float) -> void:
		var flat: Vector2 = start.lerp(destination, progress)
		flat.y -= sin(progress * PI) * float(MapGrid.TILE_SIZE) * 0.5
		position = flat
	, 0.0, 1.0, duration)
	await tween.finished
	position = destination
	is_moving = false
	_jump_seconds = 0.0
	refresh_bush_depth()
	step_finished.emit(target)
