@tool
class_name GameDataResource
extends Resource

## This is a base class for all static game-data records
##
## Records are identified by [StringName] ids which are unique to each category.

## Unique identifier for the record.
@export var id: StringName = &""

## Display name in source language, which translations are keyed on.
## Call [method get_translated_name] to show it to the player.
@export var display_name: String = ""

## Free-form tags.
## Systems query these with [method has_flag] instead of hardcoding against specifc ids.
@export var flags: Array[StringName] = []

## Category this record was loaded from, such as 'species'.
## Stamped by [method Database.get_record] rather than saved.
var data_category: StringName = &""

## Get the display name in the player's language.
##
## Names are translated with cateogries = domain so that word overlaps (i.e. "Psychic" and "Psychic"(trainer))
## Falls back to [member display_name] and then to [member id] just incase.
func get_translated_name() -> String:
	if display_name.is_empty():
		return String(id)
	return Loc.data(data_category, display_name)
	
## Translates [param text] as another piece of the record's own text (i.e. a description, pokedex entry)
func translate_field(text: String) -> String:
	return Loc.data(data_category, text)
	
## Returns `true` when this record carries [param flag] (not case-sensitive)
func has_flag(flag: StringName) -> bool:
	for existing: StringName in flags:
		if existing.nocasecmp_to(flag) == 0:
			return true
	return false
	
## Returns the value of a `Name-value` style flag OR [param fallback] when flag is absent.
func get_flag_value(prefix: StringName, fallback: String = "") -> String:
	var needle: String = String(prefix) + "_"
	for existing: StringName in flags:
		var text: String = String(existing)
		if text.begins_with(needle):
			return text.substr(needle.length())
	return fallback
	
func _to_string() -> String:
	return "%s(%s)" % [get_script().get_global_name(), id]
