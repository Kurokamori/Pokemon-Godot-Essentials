class_name HallOfFame
extends RefCounted
## Each team that the player has registered to the Hall of Fame
##
## The list is capped so that there's an upper limit to what we store here

var entries: Array[HallOfFameEntry] = []

var last_number: int = 0


func is_empty() -> bool:
	return entries.is_empty()
	

## The most recent record, or `null` before there is one.
func latest() -> HallOfFameEntry:
	return entries.back() if not entries.is_empty() else null


## Records the party and returns the new entry.
func record(limit: int = 50, include_eggs: bool = true) -> HallOfFameEntry:
	last_number += 1
	var entry: HallOfFameEntry = HallOfFameEntry.create(last_number, include_eggs)
	if limit == 0:
		return entry
	entries.append(entry)
	if limit > 0:
		while entries.size() > limit:
			entries.pop_front()
	return entry


func clear() -> void:
	entries.clear()
	last_number = 0


func to_dict() -> Dictionary:
	var records: Array = []
	for entry: HallOfFameEntry in entries:
		records.append(entry.to_dict())
	return {"entries": records, "last_number": last_number}


func from_dict(source: Dictionary) -> void:
	clear()
	for record_source: Variant in source.get("entries", []):
		entries.append(HallOfFameEntry.from_dict(record_source as Dictionary))
	last_number = int(source.get("last_number", entries.size()))
