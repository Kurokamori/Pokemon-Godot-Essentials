class_name FieldItems
## Handing items to the player, and the two events that do it most: the ball lying on the ground and the berry patch.

## Fanfares an item arrives with.
const ITEM_JINGLE: String = "Item get"
const KEY_ITEM_JINGLE: String = "Key item get"
const MACHINE_JINGLE: String = "Machine get"
const BERRY_JINGLE: String = "Berry get"

## How long the "you found it" line stays up before closing itself, in the units `\wtnp` counts.
const FOUND_WAIT: int = 40
const MACHINE_WAIT: int = 70
const BERRY_WAIT: int = 30

## Picks up an item found lying on the ground, and reports whether it was taken.
static func found(item: Variant, quantity: int = 1) -> bool:
	var record: ItemData = _record(item)
	if record == null or quantity < 1:
		return false
	var label: String = _item_label(record, quantity)
	if not GameState.bag.add_item(record.id, quantity):
		await Field.say(_found_message(record, label, quantity))
		await Field.say("But your Bag is full...")
		return false
	await Field.say("\\me[%s]%s\\wtnp[%d]" % [
		_jingle_for(record), _found_message(record, label, quantity), _wait_for(record),
	])
	await Field.say(_pocket_message(record, label))
	return true

## Picks up an item and switches [param event] off, which is the whole of what an item ball does.
static func take_from_event(event: MapEvent, item: Variant, quantity: int = 1) -> bool:
	if not await found(item, quantity):
		return false
	Field.set_self_switch(event, ItemEvent.TAKEN_SWITCH, true)
	return true

## Gifts play the fanfare before checking whether the bag has room.
static func received(item: Variant, quantity: int = 1) -> bool:
	var record: ItemData = _record(item)
	if record == null or quantity < 1:
		return false
	var label: String = _item_label(record, quantity)
	await Field.say("\\me[%s]%s\\wtnp[%d]" % [
		_jingle_for(record), _obtained_message(record, label, quantity), _wait_for(record),
	])
	if not GameState.bag.add_item(record.id, quantity):
		return false
	await Field.say(_pocket_message(record, label))
	return true

## Hands over a Game Corner prize, which is quieter than an ordinary gift: the player already knows what they asked for.
static func bought_prize(item: Variant, quantity: int = 1) -> bool:
	var record: ItemData = _record(item)
	if record == null or quantity < 1:
		return false
	if not GameState.bag.add_item(record.id, quantity):
		return false
	await Field.say(_pocket_message(record, _item_label(record, quantity)))
	return true


# === Berries ===

## Picks the berries off a grown plant and clears the patch.
static func pick_berry(event: MapEvent, berry: Variant, quantity: int = 1) -> bool:
	var record: ItemData = _record(berry)
	if record == null:
		return false
	var count: int = maxi(quantity, 1)
	var label: String = _item_label(record, count)
	var question: String = (
		Loc.line("There are {count} \\c[1]{berry}\\c[0]!\nWant to pick them?", {
			"count": count, "berry": label,
		}) if count > 1
		else Loc.line("There is 1 \\c[1]{berry}\\c[0]!\nWant to pick it?", {"berry": label})
	)
	if not await Field.confirm(question):
		return false
	if not GameState.bag.can_add(record.id, count):
		await Field.say("Too bad...\nThe Bag is full...")
		return false
	GameState.bag.add_item(record.id, count)
	GameState.stats.berry_plants_picked += 1
	var plant: BerryPlantData = Database.berry_plant(record.id)
	if plant != null and count >= plant.max_yield:
		GameState.stats.max_yield_berry_plants += 1
	var picked: String = (
		Loc.line("You picked the {count} \\c[1]{berry}\\c[0].", {
			"count": count, "berry": label,
		}) if count > 1
		else Loc.line("You picked the \\c[1]{berry}\\c[0].", {"berry": label})
	)
	await Field.say("\\me[%s]%s\\wtnp[%d]" % [BERRY_JINGLE, picked, BERRY_WAIT])
	await Field.say(_pocket_message(record, label))
	await Field.say("The soil returned to its soft and loamy state.")
	Field.set_self_switch(event, ItemEvent.TAKEN_SWITCH, true)
	return true

## Harvests, waters or plants berries depending on the patch's stage.
static func berry_plant(event: MapEvent) -> void:
	if event == null:
		return
	var patch: BerryPatch = GameState.berry_patch(_map_id_of(event), event.event_id)
	patch.update()
	_dress_event(event, patch)

	if patch.is_grown():
		if await pick_berry(event, patch.berry_id, patch.berry_yield()):
			patch.reset()
			_dress_event(event, patch)
		return
	if patch.is_growing():
		await _tend_growing_plant(patch)
		_dress_event(event, patch)
		return
	await _offer_bare_soil(event, patch)
	_dress_event(event, patch)

## Says how the plant is coming along, then offers to water it.
static func _tend_growing_plant(patch: BerryPatch) -> void:
	var record: ItemData = Database.item(patch.berry_id)
	var berry_name: String = record.get_translated_name() if record != null else Loc.line("berry")
	match patch.growth_stage:
		BerryPatch.Stage.PLANTED:
			await Field.say(Loc.line("{article} {berry} was planted here.", {"article": _article_for(berry_name).capitalize(), "berry": berry_name}))
		BerryPatch.Stage.SPROUTED:
			await Field.say(Loc.line("The {berry_name} has sprouted.", {"berry_name": berry_name}))
		BerryPatch.Stage.TALLER:
			await Field.say(Loc.line("The {berry_name} plant is growing bigger.", {"berry_name": berry_name}))
		_:
			await Field.say(_bloom_message(berry_name, patch.watering_count))
	# Dry soil changes the message and whether watering is offered.
	if BerryPatch.uses_moisture():
		await Field.say(_soil_message(patch.moisture_stage()))
		if patch.moisture_stage() >= 2:
			return
	var can: StringName = _watering_can()
	if can == &"":
		return
	var can_record: ItemData = Database.item(can)
	var can_name: String = (
		can_record.get_translated_name() if can_record != null else Loc.line("watering can")
	)
	if not await Field.confirm(Loc.line("Want to sprinkle some water with the {can_name}?", {"can_name": can_name})):
		return
	patch.water()
	# The codes wrap the sentence rather than being part of it, so only the sentence itself is offered for translation.
	await Field.say("\\se[Water berry plant]%s\\wtnp[%d]" % [
		Loc.line("{player} watered the plant.", {"player": _player_name()}), FOUND_WAIT,
	])
	await Field.say("The plant seemed to be delighted.")

## Offers to plant something in an empty patch.
static func _offer_bare_soil(event: MapEvent, patch: BerryPatch) -> void:
	if not await Field.confirm("It's soft, loamy soil. Want to plant a berry?"):
		return
	var berry: StringName = await _choose_berry()
	if berry == &"":
		return
	patch.plant(berry)
	GameState.bag.remove_item(berry, 1)
	GameState.stats.berries_planted += 1
	var record: ItemData = Database.item(berry)
	var berry_name: String = record.get_translated_name() if record != null else Loc.line("berry")
	await Field.say(Loc.line("{player} planted {article} {berry} in the soft loamy soil.", {"player": _player_name(), "article": _article_for(berry_name), "berry": berry_name}))
	_dress_event(event, patch)

## Asks which berry to plant, listing only berries the player is carrying.
static func _choose_berry() -> StringName:
	var berries: Array[StringName] = []
	var options: Array = []
	for item_id: StringName in GameState.bag.all_item_ids():
		var record: ItemData = Database.item(item_id)
		if record == null or not record.is_berry():
			continue
		berries.append(item_id)
		options.append("%s  x%d" % [record.get_translated_name(), GameState.bag.quantity_of(item_id)])
	if berries.is_empty():
		await Field.say("You have no berries to plant.")
		return &""
	options.append("Cancel")
	var chosen: int = await Field.ask(options, "Which berry will you plant?", options.size())
	if chosen < 0 or chosen >= berries.size():
		return &""
	return berries[chosen]

## Puts the right plant graphic on the patch's event.
static func _dress_event(event: MapEvent, patch: BerryPatch) -> void:
	if event == null:
		return
	var look: Dictionary = patch.appearance()
	event.set_charset(String(look["charset"]))
	# The growth stage is which way the sprite faces, so the event must not turn to look at the player while it is a plant.
	event.direction_fix = patch.is_planted()
	event.facing = int(look["facing"]) as GridCharacter.Direction

## The best watering can in the bag, or nothing when the player has none.
static func _watering_can() -> StringName:
	for can: StringName in BerryPatch.WATERING_CANS:
		if GameState.bag.has_item(can):
			return can
	return &""

## What the soil under a growing plant looks like, from [method BerryPatch.moisture_stage].
static func _soil_message(moisture: int) -> String:
	match moisture:
		2: return Loc.line("The soil is soft and moist.")
		1: return Loc.line("The soil is starting to dry out.")
	return Loc.line("The soil is dry and cracked.")

static func _bloom_message(berry_name: String, watering_count: int) -> String:
	var params: Dictionary = {"berry": berry_name}
	match watering_count:
		4: return Loc.line("This {berry} plant is in fabulous bloom!", params)
		3: return Loc.line("This {berry} plant is blooming very beautifully!", params)
		2: return Loc.line("This {berry} plant is blooming prettily!", params)
		1: return Loc.line("This {berry} plant is blooming cutely!", params)
	return Loc.line("This {berry} plant is in bloom!", params)


# === Shops ===

## Opens a Poke Mart stocking [param items].
static func open_mart(items: Array, shop_name: String = "Poke Mart") -> void:
	await _open_shop(items, MartScreen.Currency.MONEY, true, shop_name)

## Opens a counter that trades in Battle Points, which never buys anything back.
static func open_battle_point_shop(items: Array, shop_name: String = "Exchange Service Corner") -> void:
	await _open_shop(items, MartScreen.Currency.BATTLE_POINTS, false, shop_name)

## Opens a Game Corner prize counter, which trades in coins.
static func open_prize_counter(items: Array, shop_name: String = "Prize Corner") -> void:
	await _open_shop(items, MartScreen.Currency.COINS, false, shop_name)

static func _open_shop(
	items: Array, currency: MartScreen.Currency, sells_back: bool, shop_name: String
) -> void:
	var scene: PackedScene = load(MartScreen.SCENE_PATH)
	if scene == null:
		push_error("FieldItems: the shop screen is missing.")
		return
	var stock: Array[StringName] = []
	for entry: Variant in items:
		var id: StringName = StringName(String(entry))
		if Database.item(id) != null:
			stock.append(id)
	await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.stock = stock
		instance.currency = currency
		instance.sells_back = sells_back
		instance.shop_name = shop_name
	)


# === Wording ===

static func _record(item: Variant) -> ItemData:
	if item is ItemData:
		return item
	return Database.item(StringName(String(item)))

## Uses the item's portion name when building a sentence.
static func _item_label(record: ItemData, quantity: int) -> String:
	return record.get_translated_portion_name(quantity)

static func _jingle_for(record: ItemData) -> String:
	if record.is_machine():
		return MACHINE_JINGLE
	return KEY_ITEM_JINGLE if record.is_key_item() else ITEM_JINGLE

static func _wait_for(record: ItemData) -> int:
	return MACHINE_WAIT if record.is_machine() else FOUND_WAIT

static func _found_message(record: ItemData, label: String, quantity: int) -> String:
	return _discovery_message(record, label, quantity, true)

static func _obtained_message(record: ItemData, label: String, quantity: int) -> String:
	return _discovery_message(record, label, quantity, false)

## Builds the item found and item received messages.
static func _discovery_message(
	record: ItemData, label: String, quantity: int, was_found: bool
) -> String:
	var params: Dictionary = {"item": label, "quantity": quantity}
	if record.is_machine():
		var move: MoveData = Database.move(record.move)
		params["move"] = move.get_translated_name() if move != null else ""
		if quantity > 1:
			return Loc.line(
				"You found {quantity} \\c[1]{item} {move}\\c[0]!" if was_found
				else "You obtained {quantity} \\c[1]{item} {move}\\c[0]!",
				params
			)
		return Loc.line(
			"You found \\c[1]{item} {move}\\c[0]!" if was_found
			else "You obtained \\c[1]{item} {move}\\c[0]!",
			params
		)
	if quantity > 1:
		return Loc.line(
			"You found {quantity} \\c[1]{item}\\c[0]!" if was_found
			else "You obtained {quantity} \\c[1]{item}\\c[0]!",
			params
		)
	params["article"] = _article_for(label)
	return Loc.line(
		"You found {article} \\c[1]{item}\\c[0]!" if was_found
		else "You obtained {article} \\c[1]{item}\\c[0]!",
		params
	)

static func _pocket_message(record: ItemData, label: String) -> String:
	return Loc.line("You put the {item} in\\nyour Bag's \\c[1]{pocket}\\c[0] pocket.", {
		"item": label,
		"pocket": BagPockets.translated_name_of(record.pocket),
	})

## The indefinite article [param name] takes.
static func _article_for(name: String) -> String:
	return "an" if _starts_with_vowel(name) else "a"

static func _starts_with_vowel(text: String) -> bool:
	if text.is_empty():
		return false
	return "AEIOUaeiou".contains(text[0])

static func _player_name() -> String:
	return GameState.player.name if GameState.player != null else "You"

static func _map_id_of(event: MapEvent) -> int:
	if event.map_scene != null:
		return event.map_scene.map_id
	return GameState.map_id
