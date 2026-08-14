class_name PokemonBag
extends RefCounted

## The player's bag, grouped by pocket.
## Each pocket is an ordered list of `[item_id, quantity]`
##
## Insertion order is preserved so that player's arrangement survives
## With the exception of pockets listed in [member GameSettingsData.bag_auto_sorted_pockets]

signal item_added(item_id: StringName, quantity: int)
signal item_removed(item_id: StringName, quantity: int)
signal bag_changed()

## Maps a pocket number to it's `Array` pair of `[StringName, int]`
var pockets: Dictionary = {}

## Items which are registered by the player for the 'ready' menu
## Running out of an item will not remove it from this list / unregister it
## [method registered_in_bag] will filter it down to what can actually be used.
var registered_items: Array[StringName] = []

## Remembers the pocket the player last had open, so it can be restored when the bag is re-opened
var last_viewed_pocket: int = BagPockets.ITEMS
## Retains the scroll index of each pocket
var last_viewed_index: Dictionary = {}


func _init() -> void:
	for pocket: int in BagPockets.all():
		pockets[pocket] = []
		last_viewed_index[pocket] = 0

func pocket_for(item_id: StringName) -> int:
	var record: ItemData = Database.item(item_id)
	return record.pocket if record != null else BagPockets.ITEMS


## Slots in [param pocket], as `[item_id, quantity]` pairs.
func get_pocket(pocket: int) -> Array:
	return pockets.get(pocket, [])


func quantity_of(item_id: StringName) -> int:
	var pocket: int = pocket_for(item_id)
	for slot: Array in get_pocket(pocket):
		if slot[0] == item_id:
			return slot[1]
	return 0


func has_item(item_id: StringName, at_least: int = 1) -> bool:
	return quantity_of(item_id) >= at_least

## Every item stored in the bag, in pocket order.
## This is used by methods that are looking for an item by what it is rather than ID.
func all_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for pocket: int in pockets:
		for slot: Array in pockets[pocket]:
			result.append(slot[0])
	return result
	
## Returns `true` when a TM/HM teaching [param move_id] is present in the bag
func has_machine_for(move_id: StringName) -> bool:
	for slot: Array in get_pocket(BagPockets.TMS):
		var item: ItemData = Database.item(slot[0])
		if item != null and item.move == move_id:
			return true
	return false
	

## Adds items. 
## Returns `false` when the pocket is full and nothing was added.
func add_item(item_id: StringName, quantity: int = 1) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false
	var record: ItemData = Database.item(item_id)
	if record == null:
		push_warning("PokemonBag: unknown item '%s'." % item_id)
		return false
	var pocket: int = record.pocket
	var slots: Array = pockets[pocket]
	var max_per_slot: int = GameSettings.data.bag_max_per_slot
	var remaining: int = quantity

	for slot: Array in slots:
		if slot[0] != item_id:
			continue
		var room: int = max_per_slot - slot[1]
		if room <= 0:
			break
		var moved: int = mini(room, remaining)
		slot[1] += moved
		remaining -= moved
		if remaining <= 0:
			_after_change(pocket)
			item_added.emit(item_id, quantity)
			return true

	var capacity: int = _pocket_capacity(pocket)
	while remaining > 0:
		if capacity >= 0 and slots.size() >= capacity:
			break
		var moved: int = mini(max_per_slot, remaining)
		slots.append([item_id, moved])
		remaining -= moved

	if remaining == quantity:
		return false
	_after_change(pocket)
	item_added.emit(item_id, quantity - remaining)
	return remaining == 0


## Removes items. 
## Returns `false` when the bag does not hold enough.
func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if quantity_of(item_id) < quantity:
		return false
	var pocket: int = pocket_for(item_id)
	var slots: Array = pockets[pocket]
	var remaining: int = quantity
	for index: int in range(slots.size() - 1, -1, -1):
		var slot: Array = slots[index]
		if slot[0] != item_id:
			continue
		var taken: int = mini(slot[1], remaining)
		slot[1] -= taken
		remaining -= taken
		if slot[1] <= 0:
			slots.remove_at(index)
		if remaining <= 0:
			break
	_after_change(pocket)
	item_removed.emit(item_id, quantity)
	return true


## Removes every copy of an item.
func remove_all(item_id: StringName) -> void:
	var held: int = quantity_of(item_id)
	if held > 0:
		remove_item(item_id, held)
		
## `true` when at least one more of [param item_id] would fit.
func can_add(item_id: StringName, quantity: int = 1) -> bool:
	var record: ItemData = Database.item(item_id)
	if record == null:
		return false
	var capacity: int = _pocket_capacity(record.pocket)
	if capacity < 0:
		return true
	var slots: Array = pockets[record.pocket]
	var max_per_slot: int = GameSettings.data.bag_max_per_slot
	var room: int = 0
	for slot: Array in slots:
		if slot[0] == item_id:
			room += max_per_slot - slot[1]
	room += (capacity - slots.size()) * max_per_slot
	return room >= quantity


func slot_count(pocket: int) -> int:
	return get_pocket(pocket).size()
	
# === Registered Items ===

func is_registered(item_id: StringName) -> bool:
	return registered_items.has(item_id)
	
## Adds [param item_id] to the Ready Menu
## Returns `false` when it either was already there or cannot be registered
func register_item(item_id: StringName) -> bool:
	if registered_items.has(item_id):
		return false
	var item: ItemData = Database.item(item_id)
	if item == null or not item.can_register():
		return false
	registered_items.append(item_id)
	bag_changed.emit()
	return true
	
## Removes [param item_id] from the Ready Menu
## Returns `false` if it wasn't on it in the first place
func deregister_item(item_id: StringName) -> bool:
	var index: int = registered_items.find(item_id)
	if index < 0:
		return false
	registered_items.remove_at(index)
	bag_changed.emit()
	return true
	
## The items the player is actually carying in register order.
func registered_in_bag() -> Array[StringName]:
	var usable: Array[StringName] = []
	for item_id: StringName in registered_items:
		if has_item(item_id):
			usable.append(item_id)
	return usable
	
func is_empty() -> bool: 
	for pocket: int in pockets:
		if not pockets[pocket].is_empty():
			return false
	return true
	
func clear() -> void:
	for pocket: int in pockets:
		pockets[pocket].clear()
	registered_items.clear()
	bag_changed.emit()
	
# === Utility and Order ===

## Organizes a pocket
func move_slot(pocket: int, from_index: int, to_index: int) -> void:
	var slots: Array = pockets.get(pocket, [])
	if from_index < 0 or from_index >= slots.size():
		return
	if to_index < 0 or to_index >= slots.size():
		return
	var slot: Array = slots[from_index]
	slots.remove_at(from_index)
	slots.insert(to_index, slot)
	bag_changed.emit()
	
## Sorts the bag to the canonical order items appear in the database
func sort_pocket(pocket: int) -> void:
	var order: Array[StringName] = Database.get_ids(Database.CATEGORY_ITEMS)
	var slots: Array = pockets.get(pocket, [])
	slots.sort_custom(func(a: Array, b: Array) -> bool:
		return order.find(a[0]) < order.find(b[0])
		)
	bag_changed.emit()
	
# === Internal ===

func _pocket_capacity(pocket: int) -> int:
	var capacities: Array[int] = GameSettings.data.bag_pocket_capacity
	var index: int = pocket - 1
	if index < 0 or index >= capacities.size():
		return -1
	return capacities[index]
	
func _after_change(pocket: int) -> void:
	if GameSettings.data.bag_auto_sorted_pokets.has(pocket):
		sort_pocket(pocket)
	bag_changed.emit()
	
func to_dict() -> Dictionary:
	var stored: Dictionary = {}
	for pocket: int in pockets:
		var slots: Array = []
		for slot: Array in pockets[pocket]:
			slots.append([String(slot[0]), slot[1]])
		stored[str(pocket)] = slots
	var registered: Array = []
	for item_id: StringName in registered_items:
		registered.append(String(item_id))
	return {
		"pockets": stored,
		"registered_items": registered,
		"last_viewed_pocket": last_viewed_pocket,
		"last_viewed_index": last_viewed_index.duplicate(),
	}


func from_dict(source: Dictionary) -> void:
	for pocket: int in pockets:
		pockets[pocket].clear()
	var stored: Dictionary = source.get("pockets", {})
	for key: Variant in stored:
		var pocket: int = int(key)
		if not pockets.has(pocket):
			pockets[pocket] = []
		for slot: Variant in stored[key]:
			pockets[pocket].append([StringName(slot[0]), int(slot[1])])
	registered_items.clear()
	for entry: Variant in source.get("registered_items", []):
		registered_items.append(StringName(entry))
	last_viewed_pocket = int(source.get("last_viewed_pocket", BagPockets.ITEMS))
	last_viewed_index = source.get("last_viewed_index", {}).duplicate()
	bag_changed.emit()
