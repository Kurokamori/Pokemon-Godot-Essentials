class_name Door
## Generic properties of a doorway, the graphics and the walk through behaviour

const CHARSET_PREFIX: String = "doors"

const OPEN_SOUND: String = "Door enter"

## Seconds each stage of the animation is held for
const STAGE_SECONDS: float = 2.0 / 60.0

## The facing rows in the order they are drawn as the door opens
## shut, ajar, half open, open
## Closing plays them backwards.
const STAGES: Array[int] = [
	GridCharacter.Direction.DOWN,
	GridCharacter.Direction.LEFT,
	GridCharacter.Direction.RIGHT,
	GridCharacter.Direction.UP,
]

## The way a door is left behind
const EXIT_DIRECTION: GridCharacter.Direction = GridCharacter.Direction.DOWN



## The door standing on [param cell]
## Returns `null` when there is none.
static func at(field: MapController, cell: Vector2i) -> MapEvent:
	if field == null:
		return null
	for event: MapEvent in field.events_at(cell):
		if is_door(event):
			return event
	return null

## Returns `true` when [param event] is drawn as a door right now
static func is_door(event: MapEvent) -> bool:
	if event == null or not event.is_active():
		return false
	return event.charset_of_active_page().begins_with(CHARSET_PREFIX)

## Swings [param door] open, playing the sound as it goes
## Checks so it's safe to call on `null`
static func open(door: MapEvent, sound: String = OPEN_SOUND) -> void:
	if door == null or not is_instance_valid(door):
		return
	if not sound.is_empty():
		AudioManager.play_se(sound)
	await _play(door, STAGES)

## Swings [param door] shut again, without a sound
static func close(door: MapEvent) -> void:
	if door == null or not is_instance_valid(door):
		return
	var backwards: Array[int] = STAGES.duplicate()
	backwards.reverse()
	await _play(door, backwards)

static func _play(door: MapEvent, stages: Array[int]) -> void:
	var tree: SceneTree = door.get_tree()
	for stage: int in stages:
		door.facing = stage as GridCharacter.Direction
		if tree == null:
			continue
		await tree.create_timer(STAGE_SECONDS).timeout
