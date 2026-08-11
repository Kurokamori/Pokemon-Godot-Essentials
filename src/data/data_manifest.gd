@tool
class_name DataManifest
extends Resource

## Lists every data category and the [DataIndex] that describes it.

## Maps a category name such as &"species" to the `res://` path of its [DataIndex]
@export var indexes: Dictionary = {}

func categories() -> Array:
	return indexes.keys()
	
func get_index_path(category: StringName) -> String:
	return indexes.get(category, "")
