class_name ChallengeRentalFormat
extends ChallengeFormat
## Battle Factory rental teams and trades.

# === Rentals ===

## The number of Pokemon offered when choosing a rental team.
@export var pool_size: int = 6

## Allows a trade after each won round.
@export var swaps_after_win: bool = true

func _init() -> void:
	entry_message = "Pick your team from the rentals. Win, and you may trade for what you beat."

func rents_team() -> bool:
	return true

# === Selection ===

func begin_run(runner: ChallengeRunner, party: PokemonParty) -> bool:
	var rules: ChallengeRules = runner.session.rules
	var pool: Array[Pokemon] = ChallengeRentals.draw_pool(rules, maxi(pool_size, rules.party_size))
	if pool.size() < rules.party_size:
		await runner.say("There aren't enough Pokemon to rent out today.")
		return false
	var team: Array[Pokemon] = await _choose_rentals(runner, pool, rules.party_size)
	if team.is_empty():
		return false
	if runner.session.begin_with_rentals(rules, party, team):
		return true
	await runner.say("That team can't enter.")
	return false

func _choose_rentals(runner: ChallengeRunner, pool: Array[Pokemon], wanted: int) -> Array[Pokemon]:
	var chosen: Array[Pokemon] = []
	var remaining: Array[Pokemon] = pool.duplicate()
	while chosen.size() < wanted:
		var options: Array = []
		for candidate: Pokemon in remaining:
			options.append(_describe(candidate))
		var picked: int = await runner.ask_options(options, Loc.line("Rent which Pokemon? ({chosen} of {wanted})", {"chosen": chosen.size() + 1, "wanted": wanted}))
		if picked < 0 or picked >= remaining.size():
			return [] as Array[Pokemon]
		chosen.append(remaining[picked])
		remaining.remove_at(picked)
	return chosen

# === Trades ===

func on_round_won(runner: ChallengeRunner, _round_number: int) -> void:
	if not swaps_after_win or runner.last_opponent == null:
		return
	var offered: Array[Pokemon] = ChallengeRentals.from_trainer(
		runner.last_opponent, runner.session.rules)
	if offered.is_empty():
		return
	if not await runner.confirm("Would you like to trade for one of their Pokemon?"):
		return
	var take_options: Array = []
	for candidate: Pokemon in offered:
		take_options.append(_describe(candidate))
	var taking: int = await runner.ask_options(take_options, "Take which one?")
	if taking < 0 or taking >= offered.size():
		return
	var party: PokemonParty = runner.party
	var give_options: Array = []
	for slot: int in range(party.size()):
		give_options.append(_describe(party.get_member(slot)))
	var giving: int = await runner.ask_options(give_options, "And give up which one?")
	if giving < 0 or giving >= party.size():
		return
	var handed_over: Pokemon = party.replace_at(giving, offered[taking])
	if handed_over == null:
		await runner.say("You can't give that one up.")
		return
	await runner.say(Loc.line("You traded {handed_over} for {taking}!", {"handed_over": handed_over.display_name(), "taking": offered[taking].display_name()}))

# === Helpers ===

func _describe(pkmn: Pokemon) -> String:
	if pkmn == null:
		return "(nothing)"
	var moves: Array[String] = []
	for move: PokemonMove in pkmn.moves:
		var record: MoveData = move.data()
		if record != null:
			moves.append(record.display_name)
	if moves.is_empty():
		return "%s Lv%d" % [pkmn.display_name(), pkmn.level()]
	return "%s Lv%d â€” %s" % [pkmn.display_name(), pkmn.level(), ", ".join(moves)]
