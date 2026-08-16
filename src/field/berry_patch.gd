class_name BerryPatch
extends RefCounted

## A single patch of soil / berries
## 
## Berry plant grow in real time, and update from the system clock
## 
## The berry sprite is the patch's own event

enum Stage {
	EMPTY = 0,
	PLANTED = 1,
	SPROUTED = 2,
	TALLER = 3,
	FLOWERING = 4,
	BERRIES = 5,
}


## How many stages a plant spends growing before it bears fruit.
const GROWING_STAGES: int = 4

## How many stages' worth of time a grown plant keeps its berries for.
const FRUITING_STAGES: int = 4

## How many times a plant regrows on its own before the patch goes back to empty soil
const REPLANT_LIMIT: int = 2

## Charset shown for the default planted berry tree, used for all trees
const PLANTED_CHARSET: String = "berrytreeplanted"

## Prefix of the charset each berry's plant is drawn from
const PLANT_CHARSET_PREFIX: String = "berrytree_"

## What is drawn when a berry has no berry tree has no graphic of its own
const FALLBACK_CHARSET: String = "Object ball"

## The generation from which berries stopped counting waterings and started measuring how wet the soil is.
const MOISTURE_MECHANICS_GENERATION: int = 4

## Soil moisture straight after watering
## And the stages at which they're drawn at
const FULL_MOISTURE: int = 100
const DAMP_MOISTURE: int = 50

## Harvest steps the newer rules divide the maximum yield into (five)
## With one lost for every hour spent dry
const YIELD_STEPS: int = 5

const SECONDS_PER_HOUR: int = 3600

## Watering cans, best first. 
## The first one in the bag is the one offered.
const WATERING_CANS: Array[StringName] = [
	&"SPRAYDUCK", &"SQUIRTBOTTLE", &"SPRINKLOTAD", &"WAILMERPAIL",
]

## The facing each growth stage is drawn as
const STAGE_FACING: Dictionary = {
	Stage.PLANTED: GridCharacter.Direction.DOWN,
	Stage.SPROUTED: GridCharacter.Direction.DOWN,
	Stage.TALLER: GridCharacter.Direction.LEFT,
	Stage.FLOWERING: GridCharacter.Direction.RIGHT,
	Stage.BERRIES: GridCharacter.Direction.UP,
}

## Item id of the berry planted here, or empty
var berry_id: StringName = &""

## Seconds this plant has been alive
var time_alive: int = 0

## Unix time the patch was last updated at
var time_last_updated: int = 0

var growth_stage: Stage = Stage.EMPTY

## How many times the plant has replanted itself
var replant_count: int = 0

## Set to `true` once a plant has been watered in its current stage
var watered_this_stage: bool = false

## How many of the stages the plant was watered in (old rules)
var watering_count: int = 0

## How wet the soil is, from `100` down to `0` (new rules)
var moisture_level: int = FULL_MOISTURE

## The amount of berries the tree has lost (new rules)
var yield_penalty: int = 0


## Empties the patch.
func reset(keep_soil: bool = false) -> void:
	if not keep_soil:
		berry_id = &""
	time_alive = 0
	time_last_updated = 0
	growth_stage = Stage.EMPTY
	replant_count = 0
	watered_this_stage = false
	watering_count = 0
	moisture_level = FULL_MOISTURE
	yield_penalty = 0


## Puts [param planted_berry] in the ground.
func plant(planted_berry: StringName) -> void:
	reset()
	berry_id = planted_berry
	growth_stage = Stage.PLANTED
	time_last_updated = _now()


## Starts the plant over from its sprout
## Used for plants that die and replant themselves
func replant() -> void:
	time_alive = 0
	growth_stage = Stage.SPROUTED
	replant_count += 1
	watered_this_stage = false
	watering_count = 0
	moisture_level = FULL_MOISTURE
	yield_penalty = 0


func is_planted() -> bool:
	return growth_stage > Stage.EMPTY


func is_growing() -> bool:
	return growth_stage > Stage.EMPTY and growth_stage < Stage.BERRIES


func is_grown() -> bool:
	return growth_stage >= Stage.BERRIES


func has_replanted() -> bool:
	return replant_count > 0


## Returns `true` if it uses the more modern berry watering mechanics
static func uses_moisture() -> bool:
	return GameSettings.data.mechanics_generation >= MOISTURE_MECHANICS_GENERATION


## Waters the plant.
func water() -> void:
	moisture_level = FULL_MOISTURE
	if watered_this_stage:
		return
	watered_this_stage = true
	watering_count += 1


## How wet the soil looks: `2` wet, `1` damp, `0` dry. 
## Always `0` under the older systems.
func moisture_stage() -> int:
	if not uses_moisture():
		return 0
	if moisture_level > DAMP_MOISTURE:
		return 2
	return 1 if moisture_level > 0 else 0


## How many berries this plant will give.
func berry_yield() -> int:
	var record: BerryPlantData = Database.berry_plant(berry_id)
	if record == null:
		return 1
	if uses_moisture():
		var kept: int = record.max_yield * maxi(YIELD_STEPS - yield_penalty, 0) / YIELD_STEPS
		return maxi(kept, record.min_yield)
	if watering_count <= 0:
		return record.min_yield
	var range_size: int = maxi(record.max_yield - record.min_yield, 0)
	var earned: int = range_size * (watering_count - 1)
	earned += RNG.below(range_size + 1)
	return (earned / GROWING_STAGES) + record.min_yield


## Brings the berry patch up to date with the system clock
func update() -> void:
	if not is_planted():
		return
	var record: BerryPlantData = Database.berry_plant(berry_id)
	if record == null:
		return
	var now: int = _now()
	var elapsed: int = now - time_last_updated
	if elapsed <= 0:
		return

	var seconds_per_stage: int = maxi(record.hours_per_stage * SECONDS_PER_HOUR, 1)
	var new_time_alive: int = time_alive + elapsed
	var replanted: bool = false
	
	while true:
		var stages_this_life: int = GROWING_STAGES + FRUITING_STAGES
		if has_replanted():
			stages_this_life -= 1
		if new_time_alive < stages_this_life * seconds_per_stage:
			break
		if replant_count >= REPLANT_LIMIT:
			reset()
			return
		new_time_alive -= stages_this_life * seconds_per_stage
		replant()
		replanted = true

	var previous_stage: Stage = Stage.EMPTY if replanted else growth_stage
	time_alive = new_time_alive
	growth_stage = (Stage.PLANTED + (time_alive / seconds_per_stage)) as Stage
	if has_replanted():
		growth_stage = (growth_stage + 1) as Stage
	growth_stage = clampi(growth_stage, Stage.PLANTED, Stage.BERRIES) as Stage
	time_last_updated = now

	if uses_moisture():
		_dry_out(record, elapsed, replanted)
	elif growth_stage > previous_stage:
		watered_this_stage = false
	if _is_raining():
		water()

func _dry_out(record: BerryPlantData, elapsed: int, replanted: bool) -> void:
	var previous_hour: int = 0 if replanted else (time_alive - elapsed) / SECONDS_PER_HOUR
	var current_hour: int = time_alive / SECONDS_PER_HOUR
	for hour: int in range(maxi(current_hour - previous_hour, 0)):
		if moisture_level > 0:
			moisture_level = maxi(moisture_level - record.drying_per_hour, 0)
		else:
			yield_penalty += 1

func appearance() -> Dictionary:
	if not is_planted():
		return {"charset": "", "facing": GridCharacter.Direction.DOWN}
	if growth_stage == Stage.PLANTED:
		return {"charset": PLANTED_CHARSET, "facing": GridCharacter.Direction.DOWN}
	var charset: String = PLANT_CHARSET_PREFIX + String(berry_id)
	if GridCharacter.charset_texture(charset) == null:
		charset = FALLBACK_CHARSET
	return {
		"charset": charset,
		"facing": STAGE_FACING.get(growth_stage, GridCharacter.Direction.DOWN),
	}

static func _now() -> int:
	return int(Time.get_unix_time_from_system())

static func _is_raining() -> bool:
	var record: WeatherData = Database.weather(GameState.current_weather())
	if record == null:
		return false
	return record.category == WeatherData.Category.RAIN or record.category == WeatherData.Category.STORM

func to_dict() -> Dictionary:
	return {
		"berry_id": String(berry_id),
		"time_alive": time_alive,
		"time_last_updated": time_last_updated,
		"growth_stage": int(growth_stage),
		"replant_count": replant_count,
		"watered_this_stage": watered_this_stage,
		"watering_count": watering_count,
		"moisture_level": moisture_level,
		"yield_penalty": yield_penalty,
	}

static func from_dict(source: Dictionary) -> BerryPatch:
	var patch: BerryPatch = BerryPatch.new()
	patch.berry_id = StringName(source.get("berry_id", ""))
	patch.time_alive = int(source.get("time_alive", 0))
	patch.time_last_updated = int(source.get("time_last_updated", 0))
	patch.growth_stage = int(source.get("growth_stage", 0)) as Stage
	patch.replant_count = int(source.get("replant_count", 0))
	patch.watered_this_stage = bool(source.get("watered_this_stage", false))
	patch.watering_count = int(source.get("watering_count", 0))
	patch.moisture_level = int(source.get("moisture_level", FULL_MOISTURE))
	patch.yield_penalty = int(source.get("yield_penalty", 0))
	return patch
