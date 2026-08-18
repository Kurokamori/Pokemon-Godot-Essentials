class_name HiddenMoveBanner
extends CanvasLayer
## Shows a Pokemon using a move outside battle.
## The sprite is clipped to the bar while crossing.

const SCENE_PATH: String = "res://scenes/field/hidden_move_banner.tscn"

## How tall the bar opens, in pixels.
const BAR_HEIGHT: float = 96.0

## Seconds each phase takes, in Essentials' own timings.
const OPEN_SECONDS: float = 0.25
const CROSS_SECONDS: float = 0.4
const HOLD_SECONDS: float = 0.75

## Light streak settings. Streaks alternate behind and in front of the Pokemon.
const STREAK_COUNT: int = 15
const STREAK_SIZE: Vector2 = Vector2(52.0, 4.0)
const STREAK_SECONDS: float = 0.8

## Keeps streaks away from the panel border.
const STREAK_MARGIN: float = 12.0

@onready var _bar: Panel = %Bar
@onready var _streaks_behind: Control = %StreaksBehind
@onready var _streaks_front: Control = %StreaksFront
@onready var _sprite: TextureRect = %PokemonSprite

## The Pokemon crossing the bar, set before the scene enters the tree.
var pokemon: Pokemon = null

## Bar openness from `0` to `1`.
var openness: float = 0.0:
	set(value):
		openness = clampf(value, 0.0, 1.0)
		if _bar != null:
			var half: float = BAR_HEIGHT * openness * 0.5
			_bar.offset_top = -half
			_bar.offset_bottom = half

## Streak positions and start times.
var _streak_starts: PackedFloat32Array = PackedFloat32Array()
var _streak_times: PackedFloat32Array = PackedFloat32Array()
var _streak_bars: Array[ColorRect] = []
var _elapsed: float = 0.0

## Shows the banner or narrates the fallback message.
static func announce(move_id: StringName, pkmn: Pokemon, narrate: Callable) -> void:
	if await play(pkmn):
		return
	if not narrate.is_valid():
		return
	var record: MoveData = Database.move(move_id)
	await narrate.call(Loc.line("{user} used {move}!", {
		"user": pkmn.display_name() if pkmn != null else _player_name(),
		"move": record.get_translated_name() if record != null else String(move_id).capitalize(),
	}))

static func _player_name() -> String:
	return GameState.player.name if GameState.player != null else "You"

static func play(pkmn: Pokemon) -> bool:
	if pkmn == null:
		return false
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		push_warning("HiddenMoveBanner: %s is missing." % SCENE_PATH)
		return false
	var banner: HiddenMoveBanner = scene.instantiate() as HiddenMoveBanner
	if banner == null:
		return false
	banner.pokemon = pkmn
	Engine.get_main_loop().get_root().add_child(banner)
	await banner.run()
	banner.queue_free()
	return true

func _ready() -> void:
	openness = 0.0
	_sprite.visible = false
	_sprite.texture = _sprite_for(pokemon)
	_build_streaks()

func _process(delta: float) -> void:
	_elapsed += delta
	_advance_streaks()

## Runs the animation phases.
func run() -> void:
	await _tween_openness(1.0)
	_sprite.visible = true
	await _cross(_offscreen_right(), _centre())
	if pokemon != null:
		AudioManager.play_cry(pokemon.species, pokemon.form)
	await _wait(HOLD_SECONDS)
	await _cross(_centre(), _offscreen_left())
	_sprite.visible = false
	await _tween_openness(0.0)

# === Internal ===

func _tween_openness(to: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "openness", to, OPEN_SECONDS)
	await tween.finished

## Slides the sprite between two x positions.
func _cross(from: float, to: float) -> void:
	_sprite.position = Vector2(from, (BAR_HEIGHT - _sprite.size.y) * 0.5)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "position:x", to, CROSS_SECONDS)
	await tween.finished

## Waits while allowing processing during a paused map.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _centre() -> float:
	return (_bar.size.x - _sprite.size.x) * 0.5

func _offscreen_right() -> float:
	return _bar.size.x

func _offscreen_left() -> float:
	return -_sprite.size.x

# === Streaks ===

## Creates and positions the streaks.
func _build_streaks() -> void:
	_streak_starts.resize(STREAK_COUNT)
	_streak_times.resize(STREAK_COUNT)
	var colour: Color = _streak_colour()
	for index: int in range(STREAK_COUNT):
		var streak: ColorRect = ColorRect.new()
		streak.size = STREAK_SIZE
		streak.color = colour
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var host: Control = _streaks_front if index % 2 == 0 else _streaks_behind
		host.add_child(streak)
		_streak_bars.append(streak)
		_place_streak(index, true)

## Positions one streak, scattering it during initial setup.
func _place_streak(index: int, scattered: bool) -> void:
	var streak: ColorRect = _streak_bars[index]
	var span: float = maxf(BAR_HEIGHT - (STREAK_MARGIN * 2.0) - STREAK_SIZE.y, 1.0)
	var width: float = _bar.size.x
	var start: float = (
		RNG.generator.randf() * width if scattered
		else -STREAK_SIZE.x - (RNG.generator.randf() * width * 0.25)
	)
	streak.position = Vector2(start, STREAK_MARGIN + (RNG.generator.randf() * span))
	_streak_starts[index] = start
	_streak_times[index] = _elapsed

func _advance_streaks() -> void:
	var travel: float = _bar.size.x * 2.0
	for index: int in range(_streak_bars.size()):
		var age: float = _elapsed - _streak_times[index]
		var streak: ColorRect = _streak_bars[index]
		streak.position.x = _streak_starts[index] + (
			travel * clampf(age / STREAK_SECONDS, 0.0, 1.0))
		if streak.position.x >= _bar.size.x:
			_place_streak(index, false)

## Returns the faded accent color used by streaks.
func _streak_colour() -> Color:
	var skin: UISkinData = UITheme.skin
	var base: Color = skin.accent if skin != null else Color.WHITE
	return Color(base.r, base.g, base.b, 0.5)

func _sprite_for(pkmn: Pokemon) -> Texture2D:
	if pkmn == null:
		return null
	return Assets.pokemon_sprite(
		pkmn.species, pkmn.form, pkmn.is_shiny(), false, pkmn.is_female(), pkmn.is_egg()
	)
