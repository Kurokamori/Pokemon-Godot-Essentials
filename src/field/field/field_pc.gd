class_name FieldPC
## The PC: the machine in every Poke Center and in the player's own bedroom.

const STORAGE_CREATOR_FALLBACK: String = "Bill"

## The machines the Poke Center PC can offer, as ids.
const ENTRY_POKEMON_STORAGE: StringName = &"pokemon_storage"
const ENTRY_PLAYER_PC: StringName = &"player_pc"
const ENTRY_PURIFY_CHAMBER: StringName = &"purify_chamber"
const ENTRY_HALL_OF_FAME: StringName = &"hall_of_fame"
const ENTRY_MYSTERY_GIFT: StringName = &"mystery_gift"
const ENTRY_LOG_OFF: StringName = &"log_off"

## The Poke Center machine.
static func open_poke_center_pc() -> void:
	AudioManager.play_se("PC open")
	await Field.say(Loc.line("{player} booted up the PC.", {"player": _player_name()}))
	while true:
		var entries: Array[StringName] = _poke_center_entries()
		var labels: Array[String] = []
		for entry: StringName in entries:
			labels.append(_entry_label(entry))
		var chosen: int = await Field.ask(labels, "Which PC should be accessed?")
		if chosen < 0 or chosen >= entries.size():
			break
		var picked: StringName = entries[chosen]
		if picked == ENTRY_LOG_OFF:
			break
		await _open_entry(picked)
	AudioManager.play_se("PC close")

## "PLAYER's PC", which is what the machine in the player's bedroom is.
static func open_trainer_pc() -> void:
	AudioManager.play_se("PC open")
	await Field.say(Loc.line("{player} booted up the PC.", {"player": _player_name()}))
	await _trainer_pc_menu()
	AudioManager.play_se("PC close")

## The machines on offer, in Essentials' order.
static func _poke_center_entries() -> Array[StringName]:
	var entries: Array[StringName] = [ENTRY_POKEMON_STORAGE, ENTRY_PLAYER_PC]
	if GameState.player != null and GameState.player.seen_purify_chamber:
		entries.append(ENTRY_PURIFY_CHAMBER)
	if not GameState.hall_of_fame.is_empty():
		entries.append(ENTRY_HALL_OF_FAME)
	# Show the gift machine only when a gift is waiting.
	if MysteryGift.has_pending():
		entries.append(ENTRY_MYSTERY_GIFT)
	entries.append(ENTRY_LOG_OFF)
	return entries

## What an entry is called on the menu.
static func _entry_label(entry: StringName) -> String:
	match entry:
		ENTRY_POKEMON_STORAGE:
			if GameState.player != null and GameState.player.seen_storage_creator:
				return Loc.line("{name}'s PC", {"name": _storage_creator()})
			return Loc.line("Someone's PC")
		ENTRY_PLAYER_PC:
			return Loc.line("{player}'s PC", {"player": _player_name()})
		ENTRY_PURIFY_CHAMBER:
			return Loc.line("Purify Chamber")
		ENTRY_HALL_OF_FAME:
			return Loc.line("Hall of Fame")
		ENTRY_MYSTERY_GIFT:
			return Loc.line("Mystery Gift")
	return Loc.line("Log off")

static func _open_entry(entry: StringName) -> void:
	match entry:
		ENTRY_POKEMON_STORAGE:
			await _open_pokemon_storage()
		ENTRY_PLAYER_PC:
			await _trainer_pc_menu()
		ENTRY_PURIFY_CHAMBER:
			await Field.show_purify_chamber()
		ENTRY_HALL_OF_FAME:
			await Field.show_hall_of_fame()
		ENTRY_MYSTERY_GIFT:
			await _claim_mystery_gift()

## Hands over the gift an event has queued.
static func _claim_mystery_gift() -> void:
	var gift: MysteryGiftData = MysteryGift.pending()
	if gift == null:
		await Field.say("There is no gift waiting.")
		return
	await MysteryGift.claim(gift, _narrator(), _gift_receipt())

## A [PokemonReceipt] that talks through the field's own window, for a gift that hands over a Pokemon.
static func _gift_receipt() -> PokemonReceipt:
	var receipt: PokemonReceipt = PokemonReceipt.new()
	receipt.narrate = _narrator()
	receipt.ask = func(options: Array) -> int:
		return await Field.ask(options, "", options.size())
	return receipt

static func _narrator() -> Callable:
	return func(text: String) -> void:
		await Field.say(text)


# === The Machines ===

## The boxes.
static func _open_pokemon_storage() -> void:
	AudioManager.play_se("PC access")
	await Field.say("The Pokemon Storage System was opened.")
	var scene: PackedScene = load(StorageScreen.SCENE_PATH)
	if scene == null:
		push_error("FieldPC: the storage screen is missing from %s." % StorageScreen.SCENE_PATH)
		return
	await SceneRouter.push_screen(scene)

## The player's own machine: item storage and the Mailbox, as Essentials' `pbTrainerPCMenu` has them.
static func _trainer_pc_menu() -> void:
	AudioManager.play_se("PC access")
	await Field.say(Loc.line("Accessed {player}'s PC.", {"player": _player_name()}))
	while true:
		var entries: Array[String] = ["Item Storage", "Mailbox", "Turn Off"]
		var chosen: int = await Field.ask(entries, "What do you want to do?")
		match chosen:
			0:
				await _item_storage_menu()
			1:
				await FieldMail.open_mailbox()
			_:
				return


# === Item Storage ===

## Opens the PC item storage menu.
static func _item_storage_menu() -> void:
	while true:
		var entries: Array[String] = ["Withdraw Item", "Deposit Item", "Toss Item", "Exit"]
		var chosen: int = await Field.ask(entries, "What do you want to do?")
		match chosen:
			0:
				await _open_item_storage(ItemStorageScreen.Mode.WITHDRAW)
			1:
				await _open_item_storage(ItemStorageScreen.Mode.DEPOSIT)
			2:
				await _open_item_storage(ItemStorageScreen.Mode.TOSS)
			_:
				return

## Opens item storage, or explains why the selected side is empty.
static func _open_item_storage(mode: ItemStorageScreen.Mode) -> void:
	if mode == ItemStorageScreen.Mode.DEPOSIT:
		if GameState.bag.is_empty():
			await Field.say("There are no items in the Bag.")
			return
	elif GameState.item_storage.is_empty():
		await Field.say("There are no items.")
		return
	var scene: PackedScene = load(ItemStorageScreen.SCENE_PATH)
	if scene == null:
		push_error("FieldPC: the item storage screen is missing from %s." % ItemStorageScreen.SCENE_PATH)
		return
	await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(mode)
	)


# === Readings ===

static func _player_name() -> String:
	return GameState.player.name if GameState.player != null else "Player"

static func _storage_creator() -> String:
	var metadata: MetadataData = Database.metadata()
	if metadata == null or metadata.storage_creator.is_empty():
		return STORAGE_CREATOR_FALLBACK
	return metadata.storage_creator
