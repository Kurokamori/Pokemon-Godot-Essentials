class_name FieldMail
## Opening a letter, writing one, and the Mailbox in the player's PC.

## Opens [param letter] and returns when the player closes it.
static func read(letter: PokemonMail) -> void:
	if letter == null:
		return
	var scene: PackedScene = load(MailScreen.SCENE_PATH)
	if scene == null:
		push_error("FieldMail.read: the mail screen is missing from %s." % MailScreen.SCENE_PATH)
		return
	await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(letter)
	)

## Asks the player to write a letter on [param item_id] and returns what they wrote, or an empty string when they gave up.
static func compose(item_id: StringName) -> String:
	var scene: PackedScene = load(MailWriteScreen.SCENE_PATH)
	if scene == null:
		push_error("FieldMail.compose: the mail writer is missing from %s." % MailWriteScreen.SCENE_PATH)
		return ""
	var written: Variant = await SceneRouter.push_screen(scene, func(screen: Node) -> void:
		screen.setup(item_id)
	)
	return String(written) if written != null else ""

## A [HeldItemHandling] that talks through the overworld's message window and opens the writer for a Mail item.
static func through_field() -> HeldItemHandling:
	var handling: HeldItemHandling = HeldItemHandling.new()
	handling.narrate = func(text: String) -> void:
		await Field.say(text)
	handling.ask = func(options: Array, prompt: String) -> int:
		return await Field.ask(options, prompt)
	handling.compose = func(item_id: StringName) -> String:
		return await compose(item_id)
	return handling


# === The Pc ===

## The Mailbox in the player's PC: Essentials' `pbPCMailbox`.
static func open_mailbox() -> void:
	var mailbox: Mailbox = GameState.mailbox
	if mailbox == null or mailbox.is_empty():
		await Field.say("There's no Mail here.")
		return
	while not mailbox.is_empty():
		var labels: Array[String] = []
		for letter: PokemonMail in mailbox.letters:
			labels.append(_letter_label(letter))
		labels.append(Loc.line("Cancel"))
		var chosen: int = await Field.ask(labels, "Which Mail do you want to look at?")
		if chosen < 0 or chosen >= mailbox.size():
			return
		await _letter_menu(chosen)

## What one letter is called on the list.
static func _letter_label(letter: PokemonMail) -> String:
	if not letter.sender.is_empty():
		return Loc.line("{sender}'s Mail", {"sender": letter.sender})
	var record: ItemData = Database.item(letter.item)
	return record.get_translated_name() if record != null else Loc.line("Mail")

## What can be done with one letter, in Essentials' order.
static func _letter_menu(index: int) -> void:
	var mailbox: Mailbox = GameState.mailbox
	var letter: PokemonMail = mailbox.get_letter(index)
	if letter == null:
		return
	var chosen: int = await Field.ask(
		["Read", "Move to Bag", "Give", "Cancel"],
		Loc.line("What do you want to do with {label}?", {"label": _letter_label(letter)})
	)
	match chosen:
		0:
			await read(letter)
		1:
			await _move_to_bag(index)
		2:
			await _give_to_pokemon(index)

## Empties a letter into the bag.
static func _move_to_bag(index: int) -> void:
	var mailbox: Mailbox = GameState.mailbox
	var letter: PokemonMail = mailbox.get_letter(index)
	if letter == null:
		return
	if not await Field.confirm("The message will be lost. Is that OK?"):
		return
	if not GameState.bag.can_add(letter.item, 1):
		await Field.say("The Bag is full.")
		return
	mailbox.take(index)
	GameState.bag.add_item(letter.item, 1)
	await Field.say("The Mail was returned to the Bag with its message erased.")

## Hands a letter back to a Pokemon, which is how a letter leaves the PC intact.
static func _give_to_pokemon(index: int) -> void:
	var slot: int = await FieldPokemon.choose(
		0, 0, Callable(), "Give to which Pokemon?"
	)
	if slot < 0:
		return
	var pkmn: Pokemon = GameState.party.get_member(slot)
	if pkmn == null:
		return
	if pkmn.is_egg():
		await Field.say("Eggs can't hold mail.")
		return
	if not Mailbox.can_hold_mail(pkmn):
		await Field.say("This Pokemon is holding an item. It can't hold mail.")
		return
	if GameState.mailbox.give_to(index, pkmn):
		await Field.say("Mail was transferred from the Mailbox.")
