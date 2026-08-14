extends Node
## Reads and writes save files
## Registered as the `SaveManager` autoload.
##
## Saves are JSON 
## Every fiule carries a [constant SAVE_VERSION]; [method _migrate] upgrades older files

const SAVE_DIRECTORY: String = "user://saves"
const SAVE_VERSION: int = 1
const SLOT_COUNT: int = 3

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_failed(slot: int, reason: String)

var last_used_slot: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)


func slot_path(slot: int) -> String:
	return "%s/save_%d.json" % [SAVE_DIRECTORY, slot]


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Writes the current session to [param slot]. 
## Writes to a temp first so that interupting a save doesn't corrupt the existing one.
func save_game(slot: int = 0) -> bool:
	if not GameState.has_session():
		save_failed.emit(slot, "No active game to save.")
		return false
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_version": GameSettings.data.game_version,
		"state": GameState.to_dict(),
	}
	var text: String = JSON.stringify(payload, "\t")
	var temporary: String = slot_path(slot) + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		save_failed.emit(slot, "Could not open %s for writing." % temporary)
		return false
	file.store_string(text)
	file.close()
	if slot_exists(slot):
		DirAccess.remove_absolute(slot_path(slot))
	var error: int = DirAccess.rename_absolute(temporary, slot_path(slot))
	if error != OK:
		save_failed.emit(slot, "Could not replace save file (error %d)." % error)
		return false
	last_used_slot = slot
	GameState.stats.set_time_last_saved()
	game_saved.emit(slot)
	return true


## Loads [param slot] into [GameState]. 
## Returns `false` in the case where the file is missing or unreadable.
func load_game(slot: int = 0) -> bool:
	var payload: Dictionary = read_slot(slot)
	if payload.is_empty():
		return false
	GameState.from_dict(payload.get("state", {}))
	GameState.stats.begin_session()
	last_used_slot = slot
	game_loaded.emit(slot)
	return true


## Reads and migrates a slot without applying it
## This is used to display the save slots
func read_slot(slot: int) -> Dictionary:
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: could not open %s." % path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: %s is not valid save data." % path)
		return {}
	return _migrate(parsed)


## A short summary of a slot for the load screen or an empty dictionary.
func slot_summary(slot: int) -> Dictionary:
	var payload: Dictionary = read_slot(slot)
	if payload.is_empty():
		return {}
	var state: Dictionary = payload.get("state", {})
	var player_data: Dictionary = state.get("player", {})
	var party_data: Array = state.get("party", [])
	var pokedex_data: Dictionary = player_data.get("pokedex", {})
	var owned: Dictionary = pokedex_data.get("owned", {})
	var total_seconds: int = int(player_data.get("play_time_seconds", 0.0))
	return {
		"slot": slot,
		"name": player_data.get("name", ""),
		"badges": _count_bits(int(player_data.get("badges", 0))),
		"pokedex_owned": owned.size(),
		"party_size": party_data.size(),
		"play_time": "%d:%02d" % [total_seconds / 3600, (total_seconds % 3600) / 60],
		"map_id": int(state.get("map_id", 0)),
		"saved_at": int(payload.get("saved_at", 0)),
	}


func delete_slot(slot: int) -> bool:
	if not slot_exists(slot):
		return false
	return DirAccess.remove_absolute(slot_path(slot)) == OK


## The most recently written slot
## Returns `-1` when there are no saves.
func most_recent_slot() -> int:
	var newest_slot: int = -1
	var newest_time: int = -1
	for slot: int in range(SLOT_COUNT):
		var summary: Dictionary = slot_summary(slot)
		if summary.is_empty():
			continue
		var saved_at: int = int(summary.get("saved_at", 0))
		if saved_at > newest_time:
			newest_time = saved_at
			newest_slot = slot
	return newest_slot


## Upgrades a save payload written by an older version of the game.
func _migrate(payload: Dictionary) -> Dictionary:
	var version: int = int(payload.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager: save is from a newer version (%d)." % version)
		return payload
	payload["version"] = SAVE_VERSION
	return payload


func _count_bits(value: int) -> int:
	var total: int = 0
	var remaining: int = value
	while remaining > 0:
		total += remaining & 1
		remaining >>= 1
	return total
