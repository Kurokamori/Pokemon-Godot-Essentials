class_name EggHatching
## Manages all egg hatching

const SCENE_PATH: String = "res://scenes/ui/screens/egg_hatch_screen.tscn"

## Hatches all the eggs ready in [param eggs] -- one after the other
static func hatch_all(eggs: Array[Pokemon]) -> void:
	for egg: Pokemon in eggs:
		await hatch(egg)
		
## Hatches an Egg
static func hatch(egg: Pokemon) -> void:
	if egg == null or not egg.is_egg():
		return
	GameState.stats.eggs_hatched += 1
	await Field.say("Huh?")
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		push_error("EggHatching: The egg hatching scene at %s is missing" % SCENE_PATH)
		hatch_without_scene(egg)
		return
	await SceneRouter.fade_out()
	await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(egg)
	)
	await SceneRouter.fade_in()
	
static func hatch_without_scene(egg: Pokemon) -> void:
	if egg == null or not egg.is_egg():
		return
	egg.hatch()
	if GameState.player != null:
		GameState.player.pokedex.register_owned(egg)
		GameState.player.record_caught(egg.species)
