@tool
class_name FollowerCharacter
extends GridCharacter
## A character following the player directly

## The name the follower is added and removed with
@export var follower_name: String = ""

## The common event that manages talking to this follower
## `0` if there isn't one
@export var common_event_id: int = 0

## Number that the follower came from, so that we can put it back
@export var source_event_id: int = 0


func _ready() -> void:
	super._ready()
	passable = true
	
## Followers also cast shadows, like the player
func casts_dynamic_shadow() -> bool:
	return true
	
## Responds to the action button, and reports whether the follower had something to say
func talk_to(interlocutor: GridCharacter) -> bool:
	if common_event_id <= 0 or map == null:
		return false
	if interlocutor != null:
		turn(GridCharacter.direction_towards(world_cell(), interlocutor.world_cell()))
	await CommonEvents.run_now(map.interpreter(), common_event_id)
	return true
	
## Either takes the step to the cell towards the player, or jumps if it's more than one cell away
func move_towards(cell: Vector2i, seconds: float) -> void:
	if is_moving or cell == tile_position:
		return
	var delta: Vector2i = cell - tile_position
	if absi(delta.x) + absi(delta.y) != 1:
		snap_to(cell)
		return
	seconds_per_tile = seconds
	var direction: GridCharacter.Direction = GridCharacter.direction_towards(tile_position, cell)
	await force_step(direction)
	
## Puts the follower on [param cell] directly
func snap_to(cell: Vector2i) -> void:
	tile_position = cell
	position = MapGrid.cell_to_pixel(cell)
