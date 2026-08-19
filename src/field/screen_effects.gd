class_name ScreenEffects
extends CanvasLayer
## Screen tone, weather, screen flash, screen shake

const TONE_RANGE: float = 255.0

const PACKED_TONE_SPAN: float = 510.0

const FRAMES_PER_SECOND: float = 60.0

const MAX_PARTICLES: int = 120

const PARTICLE_MARGIN: float = 96.0

## The distance the player can see in dark caves without and with flash
const DARKNESS_RADIUS_MIN: float = 64.0
const DARKNESS_RADIUS_MAX: float = 176.0

const DAY_NIGHT_INTERVAL: float = 2.0

## Frequency at which day/night tones shift
const DAY_NIGHT_FADE_SECONDS: float = 0.4

## Shader Uniforms on the Darkness Overlay
const DARKNESS_RADIUS: StringName = &"radius"
const DARKNESS_CENTRE: StringName = &"centre"
const DARKNESS_RECT_SIZE: StringName = &"rect_size"

@onready var _particle_root: Node2D = %WeatherParticles
@onready var _weather_tile: TextureRect = %WeatherTile
@onready var _weather_tint: ColorRect = %WeatherTint
@onready var _day_night_tint: ColorRect = %DayNightTint
@onready var _darkness_overlay: ColorRect = %DarknessOverlay
@onready var _tone_overlay: ColorRect = %ToneOverlay
@onready var _flash_overlay: ColorRect = %FlashOverlay

var _weather: StringName = &"None"
var _weather_record: WeatherData = null
var _power: int = 0

var _particles: Array[Sprite2D] = []

var _tile_offset: Vector2 = Vector2.ZERO

var _tone: Color = Color(0.0, 0.0, 0.0, 0.0)
var _tone_tween: Tween = null
var _flash_tween: Tween = null
var _shake: ScreenShake = ScreenShake.new()
var _shaking_field: bool = false
var _darkness_tween: Tween = null
var _day_night_age: float = DAY_NIGHT_INTERVAL

func _ready() -> void:
	_apply_tone()
	set_process(true)
	
func _process(delta: float) -> void:
	_advance_shake(delta)
	_follow_player_with_darkness()
	_advance_day_night(delta)
	if _weather_record == null: 
		return
	_advance_particles(delta)
	_advance_tile(delta)
	
# === Weather ===

## Starts [param new_weather] at [param power]
## A power of `0` or `none` ends the weather instead
func set_weather(new_weather: StringName, power: int = 5, seconds: float = 0.0) -> void:
	_weather = new_weather
	_power = clampi(power, 0, 9)
	_weather_record = Database.weather(new_weather)
	if _weather_record == null or _power <= 0 or _weather_record.category == WeatherData.Category.NONE:
		_clear_weather()
		return
	_build_particles()
	_build_tile()
	var target: Color = _weather_record.tint
	if seconds <= 0.0:
		_weather_tint.color = target
		return
	var tween: Tween = create_tween()
	tween.tween_property(_weather_tint, "color", target, seconds)
	
func weather_id() -> StringName:
	return _weather
	
func _clear_weather() -> void:
	_weather = &"None"
	_power = 0
	_weather_record = null
	for particle: Sprite2D in _particles:
		particle.queue_free()
	_particles.clear()
	_weather_tile.visible = false
	_weather_tint.color = Color (1.0, 1.0, 1.0, 0.0)
	
func _build_particles() -> void:
	var wanted: int = 0
	if _weather_record.particle_delta_x != 0 or _weather_record.particle_delta_y != 0:
		wanted = int(float(MAX_PARTICLES) * float(_power) / 9.0)
	while _particles.size() > wanted:
		_particles.pop_back().queue_free()
	if wanted == 0 or _weather_record.graphics.is_empty():
		return
	while _particles.size() < wanted:
		var particle: Sprite2D = Sprite2D.new()
		particle.centered = false
		_particle_root.add_child(particle)
		_particles.append(particle)
	for index: int in _particles.size():
		var graphic_name: String = _weather_record.graphics[index % _weather_record.graphics.size()]
		_particles[index].texture = Assets.texture(AssetIndex.CATEGORY_WEATHER, graphic_name)
		_particles[index].position = _random_start()
		_particles[index].modulate.a = 1.0
		
func _build_tile() -> void:
	var uses_tile: bool = (_weather_record.tile_delta_x != 0 or _weather_record.tile_delta_y != 0)
	if not uses_tile or _weather_record.graphics.is_empty():
		_weather_tile.visible = false
		return
	_weather_tile.texture = Assets.texture(AssetIndex.CATEGORY_WEATHER, _weather_record.graphics[0])
	_weather_tile.visible = _weather_tile.texture != null
	_weather_tile.modulate.a = clampf(float(_power) / 9.0, 0.0, 1.0)
	
func _advance_particles(delta: float) -> void:
	if _particles.is_empty():
		return
	var motion: Vector2 = Vector2(float(_weather_record.particle_delta_x), float(_weather_record.particle_delta_y)) * delta
	var fade: float = float(_weather_record.particle_delta_opacity) * delta / 255.0
	var bounds: Vector2 = _screen_size()
	for particle: Sprite2D in _particles:
		particle.position += motion
		if fade > 0.0:
			particle.modulate.a -= fade
			if _is_off_screen(particle.postion, bounds) or particle.modulate.a <= 0.0:
				particle.position = _random_start()
				particle.modulate.a = 1.0
	
func _advance_tile(delta: float) -> void:
	if not _weather_tile.visible:
		return
	_tile_offset += Vector2(float(_weather_record.tile_delta_x), float(_weather_record.tile_delta_y)) * delta
	var size: Vector2 = _weather_tile.texture.get_size() if _weather_tile.texture != null else Vector2.ONE
	_tile_offset.x = fposmod(_tile_offset.x, maxf(size.x, 1.0))
	_tile_offset.y = fposmod(_tile_offset.y, maxf(size.y, 1.0))
	_weather_tile.position = _tile_offset - size
	
func _random_start() -> Vector2:
	var bounds: Vector2 = _screen_size()
	var start: Vector2 = Vector2(
		randf_range(-PARTICLE_MARGIN, bounds.x + PARTICLE_MARGIN),
		randf_range(-PARTICLE_MARGIN, bounds.y + PARTICLE_MARGIN)
	)
	if _weather_record.particle_delta_y > 0:
		start.y = randf_range(-PARTICLE_MARGIN, 0.0)
	elif _weather_record.particle_delta_y < 0:
		start.y = randf_range(bounds.y, bounds.y + PARTICLE_MARGIN)
	return start

static func _is_off_screen(position: Vector2, bounds: Vector2) -> bool:
	return (
		position.x < -PARTICLE_MARGIN or position.x > bounds.x + PARTICLE_MARGIN
		or position.y < -PARTICLE_MARGIN or position.y > bounds.y + PARTICLE_MARGIN
	)

func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size
	
# === Darkness ===

## Updates, draws, or clears the darkness circle on map change
func refresh_darkness() -> void:
	var dark: bool = GameState.is_on_dark_map()
	_darkness_overlay.visible = dark
	if not dark:
		return
	_set_darkness_radius(
		DARKNESS_RADIUS_MAX if GameState.flash_used else DARKNESS_RADIUS_MIN)

func widen_darkness(seconds: float) -> void:
	if not _darkness_overlay.visible:
		return
	if _darkness_tween != null and _darkness_tween.is_valid():
		_darkness_tween.kill()
	if seconds <= 0.0:
		_set_darkness_radius(DARKNESS_RADIUS_MAX)
		return
	_darkness_tween = create_tween()
	_darkness_tween.tween_method(
		_set_darkness_radius, darkness_radius(), DARKNESS_RADIUS_MAX, seconds)
	await _darkness_tween.finished

## How wide the circle is now, in pixels. 
## Returns `0` when no darkness is drawn.
func darkness_radius() -> float:
	if not _darkness_overlay.visible:
		return 0.0
	return float(_shader_material().get_shader_parameter(DARKNESS_RADIUS))

func _set_darkness_radius(pixels: float) -> void:
	_shader_material().set_shader_parameter(DARKNESS_RADIUS, pixels)

func _follow_player_with_darkness() -> void:
	if not _darkness_overlay.visible:
		return
	var field: MapController = MapController.current
	if field == null or field.player == null or not is_instance_valid(field.player):
		return
	var view: Vector2 = _screen_size()
	var material: ShaderMaterial = _shader_material()
	material.set_shader_parameter(DARKNESS_RECT_SIZE, view)
	var on_screen: Vector2 = field.player.get_global_transform_with_canvas().origin
	material.set_shader_parameter(DARKNESS_CENTRE, Vector2(
		on_screen.x / maxf(view.x, 1.0), on_screen.y / maxf(view.y, 1.0)
	))

func _shader_material() -> ShaderMaterial:
	return _darkness_overlay.material as ShaderMaterial


# === Tone ===

## Changes the screen tone over [param frames]
## [param red], [param blue], [param green] all run from `-255` to `255`
## [param gray] reuns from `0` to `255`
func change_tone(red: int, green: int, blue: int, grey: int, frames: int) -> void:
	var target: Color = _tone_colour(red, green, blue, grey)
	if _tone_tween != null and _tone_tween.is_valid():
		_tone_tween.kill()
	_tone = target
	if frames <= 0:
		_apply_tone()
		return
	_tone_tween = create_tween()
	_tone_tween.tween_property(
		_tone_overlay, "color", target, float(frames) / FRAMES_PER_SECOND
	)

## The current screen tone
func tone() -> Color:
	return _tone

static func _tone_colour(red: int, green: int, blue: int, grey: int) -> Color:
	var channels: Vector3 = Vector3(float(red), float(green), float(blue)) / TONE_RANGE
	var average: float = (channels.x + channels.y + channels.z) / 3.0
	var strength: float = clampf(absf(average), 0.0, 1.0)
	var greyness: float = clampf(float(grey) / TONE_RANGE, 0.0, 1.0)
	if strength <= 0.0 and greyness <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var wash: Color = Color(1.0, 1.0, 1.0) if average > 0.0 else Color(0.0, 0.0, 0.0)
	if strength <= 0.0:
		return Color(0.5, 0.5, 0.5, greyness * 0.5)
	var mixed: Color = wash.lerp(Color(0.5, 0.5, 0.5), greyness)
	mixed.a = maxf(strength, greyness * 0.5)
	return mixed

func _apply_tone() -> void:
	_tone_overlay.color = _tone


# === Day / Night ===

## Shades an outdoor map by the time of day
func _advance_day_night(delta: float) -> void:
	_day_night_age += delta
	if _day_night_age < DAY_NIGHT_INTERVAL:
		return
	_day_night_age = 0.0
	refresh_day_night()

## Works the tint out now and slides to it
func refresh_day_night(seconds: float = DAY_NIGHT_FADE_SECONDS) -> void:
	if _day_night_tint == null:
		return
	_day_night_age = 0.0
	var wanted: Color = _day_night_colour()
	if is_equal_approx(seconds, 0.0):
		_day_night_tint.color = wanted
		return
	if _day_night_tint.color.is_equal_approx(wanted):
		return
	create_tween().tween_property(_day_night_tint, "color", wanted, seconds)

func _day_night_colour() -> Color:
	if not GameSettings.data.time_shading or not _is_outdoors():
		return Color(0.0, 0.0, 0.0, 0.0)
	return _day_night_overlay(TimeOfDay.current_tone())


## Turns one row of [constant TimeOfDay.HOURLY_TONES] into the overlay that stands in for it.
static func _day_night_overlay(hourly: Color) -> Color:
	var deltas: Vector3 = Vector3(hourly.r, hourly.g, hourly.b)
	var strength: float = maxf(maxf(absf(deltas.x), absf(deltas.y)), absf(deltas.z))
	var greyness: float = clampf(hourly.a, 0.0, 1.0)
	if strength <= 0.0 and greyness <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	if strength <= 0.0:
		return Color(0.5, 0.5, 0.5, greyness * 0.5)
	var swing: float = strength * 2.0
	var wash: Color = Color(
		clampf(0.5 + deltas.x / swing, 0.0, 1.0),
		clampf(0.5 + deltas.y / swing, 0.0, 1.0),
		clampf(0.5 + deltas.z / swing, 0.0, 1.0))
	var mixed: Color = wash.lerp(Color(0.5, 0.5, 0.5), greyness)
	mixed.a = maxf(strength, greyness * 0.5)
	return mixed

func _is_outdoors() -> bool:
	var metadata: MapMetadataData = Database.map_metadata(GameState.map_id)
	return metadata != null and metadata.outdoor_map

## Turns the colour an imported map stores back into RPG Maker's numbers
static func unpack_tone(packed: Color) -> Vector4i:
	return Vector4i(
		roundi(packed.r * PACKED_TONE_SPAN - TONE_RANGE),
		roundi(packed.g * PACKED_TONE_SPAN - TONE_RANGE),
		roundi(packed.b * PACKED_TONE_SPAN - TONE_RANGE),
		roundi(packed.a * TONE_RANGE)
	)

## Turns the colour an imported Screen Flash stores into something Godot useable
static func unpack_flash(packed: Color) -> Color:
	var channels: Vector4i = unpack_tone(packed)
	return Color(
		clampf(float(channels.x) / TONE_RANGE, 0.0, 1.0),
		clampf(float(channels.y) / TONE_RANGE, 0.0, 1.0),
		clampf(float(channels.z) / TONE_RANGE, 0.0, 1.0),
		clampf(float(channels.w) / TONE_RANGE, 0.0, 1.0)
	)


# === Flash ===

## Paints [param colour] over the screen and fades it away over [param frames]
func flash(colour: Color, frames: int) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_overlay.color = colour
	if frames <= 0 or colour.a <= 0.0:
		_flash_overlay.color.a = 0.0
		return
	_flash_tween = create_tween()
	_flash_tween.tween_property(
		_flash_overlay, "color:a", 0.0, float(frames) / FRAMES_PER_SECOND
	)

## The flash colour on screen now, 
## transparent when there is none.
func flash_colour() -> Color:
	return _flash_overlay.color


# === Shake ===

## Shakes the screen at [param power] (0-9) and [param speed] (0-9) for [param frames]
func shake(power: int, speed: int, frames: int) -> void:
	_shake.start(power, speed, frames)
	if not _shake.is_active():
		_release_shake()

## Returns `true` while the screen is still moving.
func is_shaking() -> bool:
	return _shake.is_active()

## How long the shake has left, in seconds.
func shake_seconds_left() -> float:
	return _shake.seconds_left()

## Hands the field how far the shake wants the camera moved this frame
## This is combined with scroll, so that there's only one writer
func _advance_shake(delta: float) -> void:
	if not _shake.is_active():
		if _shaking_field:
			_release_shake()
		return
	var field: MapController = MapController.current
	if field == null:
		return
	_shaking_field = true
	field.set_shake_offset(_shake.advance(delta))

## Takes the shake back out of the camera's offset
func _release_shake() -> void:
	_shaking_field = false
	var field: MapController = MapController.current
	if field != null:
		field.set_shake_offset(0.0)
