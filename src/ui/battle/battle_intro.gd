class_name BattleIntro
extends CanvasLayer
## The animation a battle opens on

const SCENE_PATH: String = "res://scenes/ui/battle_intro.tscn"

enum Location {
	OUTSIDE = 0,
	INSIDE = 1,
	CAVE = 2,
	WATER = 3,
}

## Drawn above the map and above the battle, and below [constant BattleTransition.LAYER]
const LAYER: int = 89

## How many times the screen flashes before the wipe
const FLASH_COUNT: int = 2
const HALF_FLASH_SECONDS: float = 0.2

## The pause between the wipe finishing and the battle scene starting
const SETTLE_SECONDS: float = 0.1

## Wipe patterns for a wild battle, by [enum Location].
const WILD_MASKS: Dictionary = {
	Location.OUTSIDE: ["Image1", "Image2", "021-Normal01", "hexatr"],
	Location.INSIDE: ["Image3", "Image4", "computertr", "hexatzr"],
	Location.CAVE: ["022-Normal02", "black_curve", "hexatrc"],
	Location.WATER: ["Image2", "black_half", "021-Normal01"],
}

## Wipe patterns for a trainer battle, by [enum Location]
const TRAINER_MASKS: Dictionary = {
	Location.OUTSIDE: ["black_square", "black_wedge_1", "Battle"],
	Location.INSIDE: ["computertr", "black_square", "battle2"],
	Location.CAVE: ["black_wedge_2", "black_curve", "battle3"],
	Location.WATER: ["black_half", "black_wedge_1", "battle4"],
}

const FALLBACK_MASK: String = "Image1"

@onready var _flash: ColorRect = %IntroFlash

## The instance in the tree -- Made on first use and kept
static var _current: BattleIntro = null


func _ready() -> void:
	layer = LAYER
	_flash.visible = false


# === The Intro ===

## Plays the whole intro for [param context], leaving the screen black
static func play(context: BattleIntroContext) -> void:
	var special: BattleIntroAnimations.Entry = BattleIntroAnimations.best_for(context)
	if special != null and special.play.is_valid():
		await special.play.call(context)
		return
	await flash(context.location)
	await close_over_map(context)

static func close_over_map(context: BattleIntroContext) -> void:
	await BattleTransition.close(mask_for(context))
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.create_timer(SETTLE_SECONDS).timeout

static func flash(location: int, count: int = FLASH_COUNT) -> void:
	if count <= 0:
		return
	var intro: BattleIntro = _ensure()
	if intro == null:
		return
	await intro._play_flashes(flash_colour(location), count)

static func flash_colour(location: int) -> Color:
	var dark: bool = location == Location.CAVE or TimeOfDay.is_night()
	return Color.BLACK if dark else Color.WHITE


# === The Context ===

## Reads the battle and the session and says what the intro is opening
static func context_for(battle: Battle, encounter_type: StringName = &"") -> BattleIntroContext:
	var context: BattleIntroContext = BattleIntroContext.new()
	context.battle = battle
	if battle != null and battle.kind == Battle.Kind.TRAINER:
		context.foes = battle.opponent_trainers.duplicate()
	context.location = location_for(encounter_type)
	return context

static func location_for(encounter_type: StringName = &"") -> int:
	if GameState != null and (GameState.is_surfing() or GameState.is_diving()):
		return Location.WATER
	var encounter: EncounterTypeData = Database.encounter_type(encounter_type)
	if encounter != null and encounter.kind == EncounterTypeData.Kind.FISHING:
		return Location.WATER
	var controller: MapController = Field.controller()
	if controller != null and controller.encounters != null:
		if controller.encounters.has_cave_encounters():
			return Location.CAVE
	var metadata: MapMetadataData = Database.map_metadata(
		GameState.map_id if GameState != null else 0)
	if metadata == null or not metadata.outdoor_map:
		return Location.INSIDE
	return Location.OUTSIDE

## Which pattern the map is wiped away with
static func mask_for(context: BattleIntroContext) -> String:
	var table: Dictionary = TRAINER_MASKS if context.is_trainer_battle() else WILD_MASKS
	var masks: Array = table.get(context.location, [])
	if masks.is_empty():
		return FALLBACK_MASK
	return String(masks[RNG.below(masks.size())])


# === Drawing ===

## Fades a full-screen rectangle in and out [param count] times
func _play_flashes(colour: Color, count: int) -> void:
	_flash.color = Color(colour.r, colour.g, colour.b, 0.0)
	_flash.visible = true
	for _index: int in range(count):
		var tween: Tween = create_tween()
		tween.tween_property(_flash, "color:a", 1.0, HALF_FLASH_SECONDS)
		tween.tween_property(_flash, "color:a", 0.0, HALF_FLASH_SECONDS)
		await tween.finished
	_flash.visible = false

## The node in the tree, made on first use. 
## It is parented to the root so it can survive map changes
static func _ensure() -> BattleIntro:
	if _current != null and is_instance_valid(_current):
		return _current
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		return null
	var made: BattleIntro = scene.instantiate() as BattleIntro
	if made == null:
		return null
	Engine.get_main_loop().root.add_child(made)
	_current = made
	return made
