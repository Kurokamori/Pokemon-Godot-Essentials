class_name TimeOfDay
## Real-world clock which is used by evolutions, encounters and map tinting.

enum Phase {
	MORNING = 0,
	DAY = 1,
	AFTERNOON = 2,
	EVENING = 3,
	NIGHT = 4,
}

## A time override to report instead of the system time, `-1` reports actual time
static var forced_hour: int = -1

## Screen tint applied at the start of each hour on outdoor maps. 
## Lerped between adjacent times so the transition is smooth.
const HOURLY_TONES: Array[Color] = [
	Color(-0.30, -0.28, -0.10, 0.28), Color(-0.30, -0.28, -0.10, 0.28),
	Color(-0.30, -0.28, -0.10, 0.28), Color(-0.30, -0.28, -0.10, 0.28),
	Color(-0.26, -0.24, -0.08, 0.24), Color(-0.16, -0.14, -0.04, 0.14),
	Color(-0.06, -0.06, 0.00, 0.06), Color(0.00, 0.00, 0.00, 0.00),
	Color(0.00, 0.00, 0.00, 0.00), Color(0.00, 0.00, 0.00, 0.00),
	Color(0.00, 0.00, 0.00, 0.00), Color(0.00, 0.00, 0.00, 0.00),
	Color(0.00, 0.00, 0.00, 0.00), Color(0.00, 0.00, 0.00, 0.00),
	Color(0.00, 0.00, 0.00, 0.00), Color(0.04, 0.00, -0.04, 0.00),
	Color(0.08, -0.02, -0.08, 0.04), Color(0.12, -0.06, -0.12, 0.08),
	Color(0.08, -0.10, -0.10, 0.14), Color(0.00, -0.16, -0.06, 0.20),
	Color(-0.14, -0.22, -0.04, 0.24), Color(-0.24, -0.26, -0.08, 0.28),
	Color(-0.30, -0.28, -0.10, 0.28), Color(-0.30, -0.28, -0.10, 0.28),
]


static func now() -> Dictionary:
	return Time.get_datetime_dict_from_system()


static func hour() -> int:
	if forced_hour >= 0:
		return forced_hour % 24
	return int(now()["hour"])


static func minute() -> int:
	if forced_hour >= 0:
		return 0
	return int(now()["minute"])


static func is_day() -> bool:
	var h: int = hour()
	return h >= 5 and h < 20


static func is_night() -> bool:
	return not is_day()


static func is_morning() -> bool:
	var h: int = hour()
	return h >= 5 and h < 10


static func is_afternoon() -> bool:
	var h: int = hour()
	return h >= 14 and h < 17


static func is_evening() -> bool:
	var h: int = hour()
	return h >= 17 and h < 20


static func phase() -> Phase:
	if is_night():
		return Phase.NIGHT
	if is_morning():
		return Phase.MORNING
	if is_evening():
		return Phase.EVENING
	if is_afternoon():
		return Phase.AFTERNOON
	return Phase.DAY


## Day of the week, 0 is Sunday.
static func weekday() -> int:
	return int(now()["weekday"])


## The screen tint for the current time which interpolates between hours.
static func current_tone() -> Color:
	var h: int = hour()
	var m: int = minute()
	var current: Color = HOURLY_TONES[h]
	var upcoming: Color = HOURLY_TONES[(h + 1) % 24]
	var blend: float = float(m) / 60.0
	return current.lerp(upcoming, blend)
