class_name AIItemUse
extends RefCounted
## Which of a trainer's battle items it reaches for, and who it uses it on.

## How much health each item restores. `0` means "as much as it takes".
const HP_HEAL_AMOUNTS: Dictionary = {
	&"POTION": 20,
	&"SUPERPOTION": 60,
	&"HYPERPOTION": 120,
	&"MAXPOTION": 0,
	&"FULLRESTORE": 0,
	&"BERRYJUICE": 20,
	&"SWEETHEART": 20,
	&"FRESHWATER": 30,
	&"SODAPOP": 50,
	&"LEMONADE": 70,
	&"MOOMOOMILK": 100,
	&"ORANBERRY": 10,
	&"ENERGYPOWDER": 60,
	&"ENERGYROOT": 120,
	&"RAGECANDYBAR": 20,
}

## Items that cure one particular status problem
const ONE_STATUS_CURES: Dictionary = {
	&"AWAKENING": &"SLEEP",
	&"BLUEFLUTE": &"SLEEP",
	&"CHESTOBERRY": &"SLEEP",
	&"ANTIDOTE": &"POISON",
	&"PECHABERRY": &"POISON",
	&"BURNHEAL": &"BURN",
	&"RAWSTBERRY": &"BURN",
	&"PARALYZEHEAL": &"PARALYSIS",
	&"PARLYZHEAL": &"PARALYSIS",
	&"CHERIBERRY": &"PARALYSIS",
	&"ICEHEAL": &"FROZEN",
	&"ASPEARBERRY": &"FROZEN",
}

## Items that cure any status problem at all.
const ALL_STATUS_CURES: Array[StringName] = [
	&"FULLHEAL", &"FULLRESTORE", &"LUMBERRY", &"HEALPOWDER", &"LAVACOOKIE",
	&"OLDGATEAU", &"CASTELIACONE", &"LUMIOSEGALETTE", &"SHALOURSABLE",
	&"BIGMALASADA", &"PEWTERCRUNCHIES",
]

## Items that bring a fainted Pokemon back, and how much of it.
const REVIVE_AMOUNTS: Dictionary = {
	&"REVIVE": 5,
	&"MAXREVIVE": 7,
	&"REVIVALHERB": 7,
	&"MAXHONEY": 7,
}

## Chance of reaching for a heal when the Pokemon is merely hurt rather than in danger.
const CHANCE_TO_TOP_UP: int = 30

## Chance of curing a status problem that is not stopping the Pokemon acting.
const CHANCE_TO_CURE: int = 40

## Chance of reviving when there is still somebody else to send in.
const CHANCE_TO_REVIVE: int = 40

## Share of health below which a Pokemon counts as in danger rather than hurt.
const DANGER_SHARE: float = 0.25

## The action of using an item, or `null` when the trainer would rather fight.
static func choose(battle: Battle, battler: Battler, skill: AISkill) -> BattleAction:
	if battle == null or battler == null or battler.is_player_side():
		return null
	if battle.opponent_items.is_empty() or not skill.is_medium():
		return null
	var side: int = battler.side_index()

	var healing: BattleAction = _choose_heal(battle, battler)
	if healing != null:
		return healing
	var cure: BattleAction = _choose_cure(battle, battler)
	if cure != null:
		return cure
	var boost: BattleAction = _choose_stat_item(battle, battler, skill)
	if boost != null:
		return boost
	return _choose_revive(battle, battler, side)

## The best-fitting healing item, which is the smallest one that still covers most of what is missing.
static func _choose_heal(battle: Battle, battler: Battler) -> BattleAction:
	var missing: int = battler.total_hp() - battler.hp()
	if missing <= 0:
		return null
	var desperate: bool = battler.hp_fraction() <= DANGER_SHARE
	if not desperate:
		if battler.hp_fraction() > 0.5 or not RNG.decide_percent(CHANCE_TO_TOP_UP):
			return null
	var candidates: Array = []
	for item_id: StringName in battle.opponent_items:
		if not HP_HEAL_AMOUNTS.has(item_id):
			continue
		if not _usable_on(item_id, battler.pokemon):
			continue
		var amount: int = int(HP_HEAL_AMOUNTS[item_id])
		if amount <= 0:
			amount = battler.total_hp()
		candidates.append({"item": item_id, "amount": amount})
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return int(first["amount"]) < int(second["amount"])
	)
	var wanted: float = float(missing) * 0.75
	for entry: Dictionary in candidates:
		if float(entry["amount"]) >= wanted:
			return _spend(battle, battler, StringName(entry["item"]))
	return _spend(battle, battler, StringName(candidates.back()["item"]))

## A status cure, preferring the one that resolves only this problem.
static func _choose_cure(battle: Battle, battler: Battler) -> BattleAction:
	var status: StringName = battler.pokemon.status
	if status == &"NONE":
		return null
	if AIBattlerView.wants_status(battle, battler, status):
		return null
	# Sleep that is about to end on its own is not worth an item.
	if status == &"SLEEP" and battler.pokemon.status_count <= 2:
		return null
	var stopping: bool = status == &"SLEEP" or status == &"FROZEN"
	if not stopping and not RNG.decide_percent(CHANCE_TO_CURE):
		return null
	for item_id: StringName in battle.opponent_items:
		if ONE_STATUS_CURES.get(item_id, &"") == status and _usable_on(item_id, battler.pokemon):
			return _spend(battle, battler, item_id)
	for item_id: StringName in battle.opponent_items:
		if ALL_STATUS_CURES.has(item_id) and _usable_on(item_id, battler.pokemon):
			return _spend(battle, battler, item_id)
	return null

## An X item, which is only worth using when the stat it raises is valuable to the Pokemon
static func _choose_stat_item(battle: Battle, battler: Battler, skill: AISkill) -> BattleAction:
	if not RNG.decide_percent(CHANCE_TO_TOP_UP):
		return null
	var context: AIContext = AIContext.make(battle, battler, battler, null, MoveEffect.new(), skill)
	for item_id: StringName in battle.opponent_items:
		var record: ItemData = Database.item(item_id)
		if record == null or record.battle_use != ItemData.BattleUse.ON_BATTLER:
			continue
		var stat: StringName = _stat_raised_by(item_id)
		if stat.is_empty():
			continue
		if not AIStatScores.raise_worthwhile(context, battler, stat):
			continue
		return _spend(battle, battler, item_id)
	return null

## A Revive, worth more when there are no other Pokemon to send out
static func _choose_revive(battle: Battle, battler: Battler, side: int) -> BattleAction:
	var party: PokemonParty = battle.get_party(side)
	var able_reserves: int = 0
	for slot: int in range(party.size()):
		var member: Pokemon = party.get_member(slot)
		if member != null and member.is_able() and not battle.active_party_slots(side).has(slot):
			able_reserves += 1
	if able_reserves > 0 and not RNG.decide_percent(CHANCE_TO_REVIVE):
		return null
	var best_item: StringName = &""
	var best_slot: int = -1
	var best_worth: int = -1
	for slot: int in range(party.size()):
		var member: Pokemon = party.get_member(slot)
		if member == null or member.is_able():
			continue
		for item_id: StringName in battle.opponent_items:
			if not REVIVE_AMOUNTS.has(item_id):
				continue
			var worth: int = int(REVIVE_AMOUNTS[item_id])
			if worth > best_worth:
				best_worth = worth
				best_item = item_id
				best_slot = slot
	if best_slot < 0:
		return null
	battle.opponent_items.erase(best_item)
	return BattleAction.use_item(battler.index, best_item, best_slot)

## Whether the item would actually do anything to this Pokemon.
static func _usable_on(item_id: StringName, pkmn: Pokemon) -> bool:
	var record: ItemData = Database.item(item_id)
	if record == null or pkmn == null:
		return false
	if pkmn.is_egg() or not pkmn.is_able():
		return false
	return record.battle_use == ItemData.BattleUse.ON_POKEMON \
		or record.battle_use == ItemData.BattleUse.ON_BATTLER

## The stat an X item raises, or empty when the item is not one.
static func _stat_raised_by(item_id: StringName) -> StringName:
	var text: String = String(item_id)
	if not text.begins_with("X"):
		return &""
	for stem: StringName in ItemEffects.STAT_BOOST_ITEMS:
		if text.begins_with(String(stem)):
			return StringName(ItemEffects.STAT_BOOST_ITEMS[stem])
	return &""

## Takes the item out of the trainer's bag and builds the action that uses it.
static func _spend(battle: Battle, battler: Battler, item_id: StringName) -> BattleAction:
	battle.opponent_items.erase(item_id)
	return BattleAction.use_item(battler.index, item_id, battler.party_index)
