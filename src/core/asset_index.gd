@tool
class_name AssetIndex
extends Resource

## Maps the plain asset names used by game data onto "res://" paths.
##
## A lot of data refers to assets by bare names so instead of guessing at an extension and hoping the file is there
## the importer scans `res://assets/` once and writes this index which als oworks unchanged in contexts where directory listing is unreliable.

const CATEGORY_BGM: StringName = &"bgm"
const CATEGORY_BGS: StringName = &"bgs"
const CATEGORY_ME: StringName = &"me"
const CATEGORY_SE: StringName = &"se"
const CATEGORY_CHARACTERS: StringName = &"characters"
const CATEGORY_POKEMON_FRONT: StringName = &"pokemon_front"
const CATEGORY_POKEMON_FRONT_SHINY: StringName = &"pokemon_front_shiny"
const CATEGORY_POKEMON_BACK: StringName = &"pokemon_back"
const CATEGORY_POKEMON_BACK_SHINY: StringName = &"pokemon_back_shiny"
const CATEGORY_POKEMON_ICONS: StringName = &"pokemon_icons"
const CATEGORY_POKEMON_ICONS_SHINY: StringName = &"pokemon_icons_shiny"
const CATEGORY_POKEMON_EGGS: StringName = &"pokemon_eggs"
const CATEGORY_POKEMON_FOOTPRINTS: StringName = &"pokemon_footprints"
const CATEGORY_POKEMON_SHADOW: StringName = &"pokemon_shadow"
const CATEGORY_ITEMS: StringName = &"items"
const CATEGORY_BATTLEBACKS: StringName = &"battlebacks"
const CATEGORY_BATTLE_ANIMATIONS: StringName = &"battle_animations"
const CATEGORY_AUTOTILES: StringName = &"autotiles"
const CATEGORY_TILESETS: StringName = &"tilesets"
const CATEGORY_PICTURES: StringName = &"pictures"
const CATEGORY_ICONS: StringName = &"icons"
const CATEGORY_FOGS: StringName = &"fogs"
const CATEGORY_PANORAMAS: StringName = &"panoramas"
const CATEGORY_UI: StringName = &"ui"
const CATEGORY_TRAINERS: StringName = &"trainers"
const CATEGORY_WINDOWSKINS: StringName = &"windowskins"
const CATEGORY_TITLES: StringName = &"titles"
const CATEGORY_ANIMATIONS: StringName = &"animations"
const CATEGORY_TRANSITIONS: StringName = &"transitions"
const CATEGORY_WEATHER: StringName = &"weather"

## Maps a category to its corresponding `Dictionary` of lower-cased asset name to `res://` path
@export var categories: Dictionary = {}

## Resolves [param asset_name] within [param category]
## Returns an empty string when not present.
func resolve(category: StringName, asset_name: String) -> String:
	if asset_name.is_empty():
		return ""
	var bucket: Dictionary = categories.get(category, {})
	return bucket.get(asset_name.to_lower(), "")
	
func has_asset(category: StringName, asset_name: String) -> bool:
	return not resolve(category, asset_name).is_empty()
	
## All the assets in [param category], sorted.
func names_in(category: StringName) -> Array:
	var bucket: Dictionary = categories.get(category, {})
	var names: Array = bucket.keys()
	names.sort()
	return names
	
func count(category: StringName) -> int:
	var bucket: Dictionary = categories.get(category, {})
	return bucket.size()
