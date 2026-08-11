@tool
class_name LocaleCatalog
extends Resource

## A CSV of translatable text and the Godot compiled translation built from it.
##
## A catalog is what the translator uses.
## A single spreadsheet whose first column is the English (or source) an remaining columns are one locale each.

## Translation domain that these strings belong to.
## Empty for the main domain, which is where sentances live;
## Data records use `data/[category]`. ( see [Loc])
@export var domain: StringName = &""

## The spreadsheet which a translator would edit (such as `res://locale/data/species.csv`)
@export_file("*.csv") var source_path: String = ""

## The compiled translations, one per locale column of the CSV.
## Godot writes these itself on import.
## The paths are recorded here to avoid scanning `res://`
@export var translation_paths: PackedStringArray = []

## Locales the catalog covers, in the same order as [member translation_paths]
@export var locales: PackedStringArray = []

## How many source strings the CSV holds.
## Used for tooling / reporting.
@export var entry_count: int = 0


## The compiled translation for [param locale] (or any empty string that is not covered)
func translation_path_for(locale: StringName) -> String:
	var index: int = Array(locales).find(String(locale))
	if index < 0 or index >= translation_paths.size():
		return ""
	return translation_paths[index]
	
func _to_string() -> String:
	return "LocaleCatalog(%s, %d entries, %d locales)" % [
		domain if not domain.is_empty() else &"main", entry_count, locales.size(),
	]
