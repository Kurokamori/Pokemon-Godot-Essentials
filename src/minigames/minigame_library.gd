@tool
class_name MinigameLibrary
extends Resource
## The list of minigames which this game has, keyed by ID

## Every minigame, IDs must be unique
@export var entries: Array[MinigameEntry] = []

var _by_id: Dictionary = {}
var _indexed: bool = false

## the entry called [param id]
## Returns `null` if the library has no such game
func entry(id: StringName) -> MinigameEntry:
	_build_index()
	return _by_id.get(id)
	
func has(id: StringName) -> bool:
	return entry(id) != null
	
func scene_for(id: StringName) -> PackedScene:
	var found: MinigameEntry = entry(id)
	return found.scene if found != null else null
	
func ids() -> Array[StringName]:
	_build_index()
	var listed: Array[StringName] = []
	for key: Variant in _by_id:
		listed.append(key)
	return listed
	
## Adds [param new_entry] at runtime, replacing the game's minigame already using the id
func register(new_entry: MinigameEntry) -> void:
	if new_entry == null or new_entry.id.is_empty():
		push_error("MinigameLibrary: Attempting to register an entry wihtout an id")
		return
	_build_index()
	for index: int in range(entries.size()):
		if entries[index] != null and entries[index].id == new_entry.id:
			entries[index] = new_entry
			_by_id[new_entry.id] = new_entry
			return
	entries.append(new_entry)
	_by_id[new_entry.id] = new_entry
	
## Clears the cache
func refresh() -> void:
	_indexed = false
	_by_id.clear()
	
func _build_index() -> void:
	if _indexed:
		return
	_indexed = true
	_by_id.clear()
	for listed: MinigameEntry in entries:
		if listed == null or listed.id.is_empty():
			continue
		if _by_id.has(listed.id):
			push_warning("MinigameLibrary: '%s' is listed more than once" % listed.id)
			continue
		_by_id[listed.id] = listed
