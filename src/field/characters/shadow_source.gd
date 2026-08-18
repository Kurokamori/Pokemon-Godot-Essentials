class_name ShadowSource
extends RefCounted

const DEFAULT_ANGLE_MIN: float = 0.0
const DEFAULT_ANGLE_MAX: float = 0.0
const DEFAULT_DISTANCE_MAX: float = 350.0
const DEFAULT_OPACITY: float = 100.0

var event: MapEvent = null

var angle_min: float = DEFAULT_ANGLE_MIN
var angle_max: float = DEFAULT_ANGLE_MAX

var distance_max: float = DEFAULT_DISTANCE_MAX

var opacity: float = DEFAULT_OPACITY

func _init(from_event: MapEvent, parameters: Array) -> void:
	event = from_event
	if parameters.size() > 0:
		angle_min = float(parameters[0])
	if parameters.size() > 1:
		angle_max = float(parameters[1])
	if parameters.size() > 2:
		distance_max = float(parameters[2])
	if parameters.size() > 3:
		opacity = float(parameters[3])

func light_position() -> Vector2:
	return event.global_position + Vector2(
		float(MapGrid.TILE_SIZE) * 0.5, float(MapGrid.TILE_SIZE))

func is_lit() -> bool:
	return is_instance_valid(event) and not event.erased and event.visible
