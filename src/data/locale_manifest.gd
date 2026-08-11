@tool
class_name LocaleManifest
extends Resource

## Everything a localization service would need to bring up the game in a langauge.
##
## Written by the extractor and read once at startup.
## It exists for the same reason as data manifest, to avoid listing `res://` at build.

# TODO: check if this works at build -- .tres/.res handling
const MANIFEST_PATH: String = "res://locale/_locale_manifest.tres"

## Locale the source text is written in.
## Never needs a catalog of its own, it's what the game falls back to when there's no translation.
@export var source_locale: StringName = &"en"

## Every local the game can be played in, [member source_locale] first.
@export var locales: PackedStringArray = ["en"]

## What each locale calls itself, keyed by local code (such as `{"ru": "Русский"}`
## This is what displays in the language selection screen so that it displays in its own language.
@export var locale_names: Dictionary = {"en": "English"}

## One entry per translatable CSV, see [LocaleCatalog].
@export var catalogs: Array[LocaleCatalog] = []


## The name shown for [param locale] in a language picker
## Set Value -> Godot's Known Value -> Raw Code
func display_name_for(locale: StringName) -> String:
	var key: String = String(locale)
	if locale_names.has(key):
		return String(locale_names[key])
	var known: String = TranslationServer.get_locale_name(key)
	return known if not known.is_empty() else key
	
func has_locale(locale: StringName) -> bool:
	return Array(locales).has(String(locale))
	
## Every catalog which belongs to the [param domain]
func catalogs_for_domain(domain: StringName) -> Array[LocaleCatalog]:
	var result: Array[LocaleCatalog] = []
	for catalog: LocaleCatalog in catalogs:
		if catalog != null and catalog.domain == domain:
			result.append(catalog)
	return result
