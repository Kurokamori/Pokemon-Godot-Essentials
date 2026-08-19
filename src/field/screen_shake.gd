class_name ScreenShake
extends RefCounted
## Camera shake effect, side to side

const FRAMES_PER_SECOND: float = 60.0

## How far the offset may swing either side of centre, as a multiple of power.
const SWING: float = 2.0

## How much of `power * speed` is traversed in one frame
const STEP_DIVISOR: float = 10.0

var _power: float = 0.0
var _speed: float = 0.0
var _frames_left: float = 0.0
var _offset: float = 0.0
var _direction: float = 1.0

## Part of a frame carried over between `advance` calls
var _leftover: float = 0.0

## Starts shaking at [param power] (0-9), moving at [param speed] (0-9), for [param frames]
## A power of zero stops the shake instead.
func start(power: int, speed: int, frames: int) -> void:
	_power = float(clampi(power, 0, 9))
	_speed = float(clampi(speed, 0, 9))
	_frames_left = float(maxi(frames, 0))
	_direction = 1.0
	_leftover = 0.0
	if _power <= 0.0:
		stop()

func stop() -> void:
	_power = 0.0
	_speed = 0.0
	_frames_left = 0.0
	_offset = 0.0
	_direction = 1.0
	_leftover = 0.0

## `true` while the screen is still moving
func is_active() -> bool:
	return _frames_left > 0.0 or not is_zero_approx(_offset)

## How long the shake has left, in seconds
func seconds_left() -> float:
	return _frames_left / FRAMES_PER_SECOND

## Advances by [param delta] seconds and returns where the screen should sit
func advance(delta: float) -> float:
	if not is_active():
		return 0.0
	_leftover += delta * FRAMES_PER_SECOND
	while _leftover >= 1.0 and is_active():
		_leftover -= 1.0
		_advance_one_frame()
	return _offset

func _advance_one_frame() -> void:
	var step: float = _power * _speed * _direction / STEP_DIVISOR
	if _frames_left <= 1.0 and _offset * (_offset + step) < 0.0:
		_offset = 0.0
	else:
		_offset += step
	if _offset > _power * SWING:
		_direction = -1.0
	elif _offset < -_power * SWING:
		_direction = 1.0
	if _frames_left > 0.0:
		_frames_left -= 1.0
