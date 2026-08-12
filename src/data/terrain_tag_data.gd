@tool
class_name TerrainTagData
extends GameDataResource

## Behaviour attacked to a tile's terrain tag number.
##
## Effect a tag falls back to when it says it rustles but does not say what with.
## Named here rather than in [OverworldEffects] because data records are read in the editor,
## field runtime is not.

const DEFAULT_STEP_EFFECT: StringName = &"GrassRustle"

## Terrain tag number which is stored in the tileset.
@export var tag_number: int = 0

@export_group("Water")
@export var can_surf: bool = false
@export var waterfall: bool = false
@export var waterfall_crest: bool = false
@export var can_fish: bool = false
@export var can_dive: bool = false

@export_group("Encounters")
@export var land_wild_encounters: bool = false

## A wild battle which is started on this tile is sometimes a double battle
@export var double_wild_encounters: bool = false

## A wild battle started here is ALWAYS a double battle (if the player has 2 healthy Pokemon)
@export var always_double_wild_encounters: bool = false

## The player's feet are hidden by the growth of this tile, rather than only their ankles.
@export var deep_bush: bool = false

## Walking through this, rustles it.
@export var shows_grass_rustle: bool = false

@export_group("Movement")
@export var ledge: bool = false
@export var ice: bool = false
@export var bridge: bool = false

## The player slides across this tile without stopping
@export var must_walk: bool = false

## The player cannot cylce over this tile
@export var must_walk_or_run: bool = false

## Passability data on this tile is ignored
@export var ignore_passabilitiy: bool = false

@export_group("Presentation")
@export var shows_reflections: bool = false

## ID of an [EnvironmentData] record used for battles started here.
@export var battle_environment: StringName = &""

## ID of the [OverworldEffectData] played when a character steps on this tile
## Such as the grass rustle, the puff of sand, or splash
## Empty means nothing is drawn.
## Except that a tile with [member show_grass_rustle] set falls back to
## [constant DEFAULT_STEP_EFFECT]
##
## To add new grass:
## Give the tag its own terrain tag number
## point [member step_effect] at a new record in the overworld effect library
## The animation will follow the new settings.
@export var step_effect: StringName = &""

## Sound that is played when a character steps onto this tiel.
## Accessed by name from the `se` category of assets/audio
## Empty for silence.
@export var step_sound: String = ""


## returns `true` when the tile is water the player can surf or fish from.
func is_water() -> bool:
	return can_surf or waterfall or waterfall_crest or can_fish
	
## returns true when the player can surf across this tile freely,
## rather than being carried across it.
func can_surf_freely() -> bool:
	return can_surf and not waterfall and not waterfall_crest
	
## returns `true` when standing on this tile can trigger a wild LAND encounter.
func triggers_land_encounters() -> bool:
	return land_wild_encounters

## returns `true when a wild battle here is ever able to be a double battle.
func allows_double_wild_encounters() -> bool:
	return double_wild_encounters or always_double_wild_encounters
	
## The overworld effect a step on this tile plays
## Resolves through `shows_grass_rustle` fallsback
## Empty when nothing should be drawn
func resolved_step_effect() -> StringName:
	if not step_effect.is_empty():
		return step_effect
	return DEFAULT_STEP_EFFECT if shows_grass_rustle else &""
