class_name MysteryGift
## Currently a bookkeeping port as there is no networking implemented yet
## But this allows for the adding and claiming of MysteryGift Pokemon and allows me to
## scaffold the rest of the functionality.

## A gift waiting to be claimed or `null`
static func pending() -> MysteryGiftData:
	var queued: Variant = GameState.get_variable(EventScriptBridge.MYSTERY_GIFT_VARIABLE)
	var number: int = int(queued) if queued != null else 0
	if number <= 0 or GameState.claimed_mystery_gift.has(number):
		return null
	return Database.mystery_gift(number)
	
## Returns `true` when there is a gift which can be claimed
static func has_pending() -> bool:
	return pending() != null
	
## Gives the player [param gift] and marks it claimed.
##
## [param narate] and [param receipt] are what it says and how a Pokemon is recieved
## Returns `false` when there's nothing to claim.
static func claim(gift: MysteryGiftData, narrate: Callable, receipt: PokemonReceipt) -> bool:
	if gift == null:
		return false
	if GameState.claimed_mystery_gifts.has(gift.gift_id):
		return false
	GameState.claimed_mystery_gifts.append(gift.gift_id)
	
	if narrate.is_valid():
		await narrate.call(Loc.line("A gift arrived: {gift}!", {
			"gift": gift.get_translated_name(),
		}))
		var described: String = gift.get_translated_description()
		if not described.is_empty():
			await narrate.call(described)

	for entry: MysteryGiftItem in gift.items:
		if entry == null or entry.item.is_empty():
			continue
		var record: ItemData = Database.item(entry.item)
		if record == null:
			continue
		if not GameState.bag.add_item(entry.item, entry.quantity):
			if narrate.is_valid():
				await narrate.call(Loc.line("There was no room for the {item}.", {
					"item": record.get_translated_name(),
				}))
			continue
		if narrate.is_valid():
			await narrate.call(Loc.line("Received {quantity} {item}!", {
				"quantity": entry.quantity, "item": record.get_translated_name(),
			}))

	var pkmn: Pokemon = gift.build_pokemon(
		GameState.player.owner_record() if GameState.player != null else null)
	if pkmn != null and receipt != null:
		await receipt.give(pkmn)
	return true
