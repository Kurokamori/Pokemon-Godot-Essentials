extends Resource

## [Database] will load an index per category so that it can resolve an id to a file
## without scanning the filesystem, which also allows it to work the same on exported builds.

## Category name, such as &"species"
@export var category: StringName = &""

## Script path of the [GameDataResource] subclass stored in this category.
@export var record_script: String = ""

## Maps [StringName] ids to `res://` paths.
@export var paths: Dictionary = {}

## Ids in their canonical order, which the UI uses when listing records.
@export var ordered_ids: Array[StringName] = []

func has_id(id: StringName) -> bool:
	return paths.has(id)
	
func get_record_path(id: StringName) -> String:
	return paths.get(id, "")
	
func size() -> int:
	return ordered_ids.size()
