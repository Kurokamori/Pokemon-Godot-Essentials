class_name Battle
extends Node
## Runs battle rules and state; [BattlePresenter] handles visuals.
##
## Example: create a battle, configure it, add it to the scene, and await [method run].

signal battle_started()
signal round_started(round_number: int)
signal battler_sent_out(battler: Battler)
signal battler_fainted(battler: Battler)
signal battle_ended(outcome: BattlePresenter.Outcome)

enum Kind {
	WILD = 0,
	TRAINER = 1,
	SAFARI = 2,
	BUG_CONTEST = 3,
}

## Round limit used as a safety measure before declaring a draw.
const ROUND_LIMIT: int = 1000

## Maximum depth for chained move-calling effects.
const MAX_CALL_DEPTH: int = 4

## The most Pokemon (per side) that can be in a battle at once.
const MAX_BATTLERS_PER_SIDE: int = 3

var kind: Kind = Kind.WILD
var presenter: BattlePresenter = null

## The party for each side; index 0 is the player's party.
var parties: Array[PokemonParty] = []

## Active battlers indexed by battle position.
var battlers: Array[Battler] = []

## Effects which attach to position rather than Pokemon to survive a switch
var position_effects: Array[Dictionary] = []
var sides: Array[BattleSide] = []
var field: BattleField = BattleField.new()

## Set to `true` if Future Sight is going to attack, so it doesn't set itself up again.
var future_sight_active: bool = false

## `true` while Pursuit is intercepting a switch, which makes it do more damage and never miss.
var pursuit_active: bool = false

## The last move any battler used, which is what Copycat copies.
var last_move_used_in_battle: StringName = &""

## How many Pokemon each side sends out at once.
var battlers_per_side: int = 1

@export_group("Trainer Battles")
## Opposing trainer records, empty for wild battles.
var opponent_trainers: Array[TrainerData] = []

## Shadow Pokemon snagged from the opposing trainer and given to the player after battle.
var _caught_by_snagging: Array[Pokemon] = []

## Items the opposing trainer may use, consumed as they are used.
var opponent_items: Array[StringName] = []

@export_group("Audio")
var victory_bgm: String = ""

## Jingle played when a wild Pokemon is caught.
var capture_me: String = ""

@export_group("Rules")
## `true` when the player is able to run away.
var can_run: bool = true

## `true` when the wild Pokemon tries to run after 1 turn (Roaming Pokemon)
var wild_pokemon_flees: bool = false

## `true` when the player may throw Poke Balls.
var can_catch: bool = true

## `true` when losing sends the player to the last Poke Center rather than ending the game.
var can_lose: bool = false

## Money the player loses on defeat, computed at setup.
var money_lost_on_defeat: int = 0

## Rounds after which the battle is decided. `0` is used for normal endurance battles, this is used for special formats.
var round_limit: int = 0

## Scores a battle that hit [member round_limit] with both sides still standing. Left `null`, the battle is a draw instead.
var judge: BattleJudge = null

## Sides whose Pokemon fight on their own rather than being given orders, by side index. Used by the Battle Palace.
var instinct_sides: Array[int] = []

var round_number: int = 0
var outcome: BattlePresenter.Outcome = BattlePresenter.Outcome.UNDECIDED
var _run_attempts: int = 0
var _actions: Array[BattleAction] = []

## Battler indices that have already taken their action this round.
var _acted_this_round: Array[int] = []

## Moves queued by effects such as Metronome or Sleep Talk.
var _called_moves: Array[Dictionary] = []

## Party slots that have consumed a Berry this battle, so Belch stays usable across a switch. Keyed by `"<side>:<party slot>"`.
var _belched_slots: Dictionary = {}

## Battlers waiting to switch out because of Emergency Exit or Wimp Out.
var _pending_ability_switches: Array[int] = []

## A Poke Ball that bounced off, lying on the field for Ball Fetch to pick up.
var dropped_ball: StringName = &""

## Battlers that fainted this round and still need replacing.
var _pending_replacements: Array[int] = []

## Active gimmicks keyed by `"<side>:<party slot>"` so they survive switching.
var gimmick_states: Dictionary = {}

## The Safari Zone trip this battle is part of, when it is one.
var safari: SafariSession = null

## The Bug-Catching Contest entry this battle is part of, when it is one.
var contest: BugContestSession = null

## Recording used to save a battle or replay one deterministically.
var recording: BattleRecording = null

## Records party activity for post-battle checks and evolution handling.
var tally: BattleTally = BattleTally.new()

func _init() -> void:
	sides = [BattleSide.new(0), BattleSide.new(1)]

# === Setup ===

## Configures a wild battle against [param wild_pokemon]. [param per_side] sets how many Pokemon each side sends out; leaving it at `0` takes the count from how many wild Pokemon were passed in.
func setup_wild(player_party: PokemonParty, wild_pokemon: Array[Pokemon], per_side: int = 0) -> void:
	kind = Kind.WILD
	var wild_party: PokemonParty = PokemonParty.new()
	for pkmn: Pokemon in wild_pokemon:
		wild_party.add(pkmn)
	parties = [player_party, wild_party]
	battlers_per_side = clampi(per_side if per_side > 0 else wild_pokemon.size(), 1, MAX_BATTLERS_PER_SIDE)
	can_run = true
	can_catch = true

## Configures a battle against one or more trainers. [param per_side] sets how many Pokemon each side sends out; leaving it at `0` makes it a double battle when there are two trainers and a single one otherwise, so a lone trainer can still be given a double battle by asking for one.
func setup_trainer(player_party: PokemonParty, trainers: Array[TrainerData], per_side: int = 0) -> void:
	kind = Kind.TRAINER
	opponent_trainers = trainers
	var opposing: PokemonParty = PokemonParty.new()
# Multiple opposing trainers share one party for battle purposes.
	opposing.capacity = GameSettings.data.max_party_size * maxi(trainers.size(), 1)
	for trainer: TrainerData in trainers:
		for member: TrainerPokemon in trainer.pokemon:
			var built: Pokemon = TrainerBuilder.build_pokemon(member, trainer)
			if built != null:
				opposing.add(built)
		for item_id: StringName in trainer.items:
			opponent_items.append(item_id)
	parties = [player_party, opposing]
	battlers_per_side = clampi(per_side if per_side > 0 else trainers.size(), 1, MAX_BATTLERS_PER_SIDE)
	can_run = false
	can_catch = false
	money_lost_on_defeat = _calculate_money_loss()

func max_battlers_per_side() -> int:
	return battlers_per_side

func is_wild_battle() -> bool:
	return kind == Kind.WILD

## `true` while a written-down battle is being watched back rather than fought.
func is_replay() -> bool:
	return recording != null and recording.replaying

## `false` during replays, which must not change the player's money, bag, or party.
func changes_the_save() -> bool:
	return not is_replay()

func get_side(side_index: int) -> BattleSide:
	return sides[side_index]

func get_party(side_index: int) -> PokemonParty:
	return parties[side_index]

# === Running the Battle ===

## Runs the whole battle and returns the outcome.
func run() -> BattlePresenter.Outcome:
	if presenter == null:
		presenter = BattlePresenter.new()
	prepare()
	await _announce_opening()

	while outcome == BattlePresenter.Outcome.UNDECIDED and round_number < ROUND_LIMIT:
		round_number += 1
		round_started.emit(round_number)
		await _run_round()
		if outcome == BattlePresenter.Outcome.UNDECIDED:
			_check_for_victory()
		if outcome == BattlePresenter.Outcome.UNDECIDED and round_limit > 0 and round_number >= round_limit:
			await _decide_by_judging()

	if outcome == BattlePresenter.Outcome.UNDECIDED:
		outcome = BattlePresenter.Outcome.DRAW
	await _finish()
	return outcome

## Ends a battle that reaches its round limit with both sides still standing.
func _decide_by_judging() -> void:
	if judge == null:
		outcome = BattlePresenter.Outcome.DRAW
		return
	await presenter.show_message("Time's up! The judges will decide it.")
	for line: String in judge.explain(self):
		await presenter.show_message(line)
	var winner: int = judge.decide(self)
	match winner:
		0:
			outcome = BattlePresenter.Outcome.PLAYER_WON
		1:
			outcome = BattlePresenter.Outcome.PLAYER_LOST
		_:
			outcome = BattlePresenter.Outcome.DRAW

## Sends out the starting battlers without running the battle, so a scripted sequence or a test can drive the phases itself.
func prepare() -> void:
	if presenter == null:
		presenter = BattlePresenter.new()
	# Secret Power and Nature Power read the surroundings, so the battle takes them from wherever the player is standing.
	if GameState != null:
		field.environment = GameState.current_environment()
	# What the party looks like now is what the evolution check afterwards compares against, so it is written down before anybody is sent out.
	tally.begin(get_party(0))
	presenter.on_battle_start(self)
	_send_out_initial()
	# The opening battlers are placed rather than switched in, so this is the one send-out that has to ask for the first draw itself.
	presenter.refresh_all()
	battle_started.emit()

## Clears the per-round state on every battler, which is the first thing a round does.
func begin_round() -> void:
	for battler: Battler in all_active_battlers():
		battler.begin_turn()

## Declares what everyone is about to do this round and works out the order they will do it in. The moves that read another battler's choice — Sucker Punch, Me First, After You, Quash, Round and the Pledges — need this to have happened before they are used.
func set_round_actions(actions: Array[BattleAction]) -> void:
	_actions = actions
	_acted_this_round.clear()
	_sort_actions()

## Runs the declared actions, in whatever order the field effects end up dictating.
func run_round_actions() -> void:
	await _announce_round_start_messages()
	await _run_actions()

## Uses one move immediately, as though [param user] had chosen it this round, including anything the move sets off afterwards.
func use_move_now(user: Battler, move: PokemonMove, target_indices: Array[int] = []) -> void:
	await _use_move(user, BattleAction.use_move(user.index, move, target_indices))
	await _run_instructed_moves(user)

## Runs the end-of-round step on its own.
func run_end_of_round() -> void:
	await _run_end_of_round()

func _finish() -> void:
	# The victory theme goes on before anything is said about the win, which is where Essentials starts it: the last Pokemon has fainted and the battle theme has no business still running under the trainer's speech.
	#
	# A replay must not touch the music, because it is a battle that has already been fought and the map's own track is what is playing behind it.
	if outcome == BattlePresenter.Outcome.PLAYER_WON and not victory_bgm.is_empty() \
			and not is_replay():
		AudioManager.play_bgm(victory_bgm, 1.0, 1.0, true)
	# What was snagged is handed over however the battle ended: the Pokemon is already in a ball with the player's name on it, and losing the fight afterwards does not give it back.
	await _hand_over_snagged()
	if outcome == BattlePresenter.Outcome.PLAYER_WON and kind == Kind.TRAINER:
		await _speak_defeat_lines()
		var winnings: int = _calculate_winnings()
		if winnings > 0 and GameState.player != null and changes_the_save():
			GameState.player.add_money(winnings)
			GameState.stats.battle_money_gained += winnings
			await presenter.show_message(Loc.line("You got ${winnings} for winning!", {"winnings": winnings}))
	if outcome == BattlePresenter.Outcome.PLAYER_LOST:
		if GameState.player != null and money_lost_on_defeat > 0 and changes_the_save():
			GameState.player.spend_money(money_lost_on_defeat)
			GameState.stats.battle_money_lost += money_lost_on_defeat
			await presenter.show_message(Loc.line("You lost ${money_lost_on_defeat}...", {"money_lost_on_defeat": money_lost_on_defeat}))
	_record_outcome()
	# Pokerus passes along the party at the end of every ordinary battle, which is where Essentials does it and the only way it ever spreads. A Frontier run and a replay both leave the party alone.
	if changes_the_save():
		Pokerus.spread_through(get_party(0))
	if recording != null:
		recording.finish(self)
	# A replay must not tell the overworld that the party evolved, because it is a battle that has already been fought.
	if GameState != null and not is_replay():
		GameState.battle_tally = tally
	_revert_gimmicks()
	for battler: Battler in battlers:
		if battler == null:
			continue
		FormHandlers.on_leaving_battle(battler.pokemon, true, true)
		battler.pokemon.status_count = 0 if battler.pokemon.status != &"SLEEP" else battler.pokemon.status_count
	presenter.on_battle_end(outcome)
	battle_ended.emit(outcome)

## Adds this battle to the appropriate win or loss tally.
func _record_outcome() -> void:
	if not changes_the_save() or GameState.stats == null:
		return
	if outcome == BattlePresenter.Outcome.UNDECIDED:
		return
	var won: bool = (
		outcome == BattlePresenter.Outcome.PLAYER_WON
		or outcome == BattlePresenter.Outcome.POKEMON_CAUGHT
	)
	match kind:
		Kind.WILD:
			if won:
				GameState.stats.wild_battles_won += 1
			else:
				GameState.stats.wild_battles_lost += 1
		Kind.TRAINER:
			if won:
				GameState.stats.trainer_battles_won += 1
			else:
				GameState.stats.trainer_battles_lost += 1

func _announce_opening() -> void:
	if kind == Kind.WILD:
		var wild_names: Array[String] = []
		for battler: Battler in active_battlers_on_side(1):
			wild_names.append(battler.display_name())
		if not wild_names.is_empty():
			await presenter.show_message(Loc.line("Wild {pokemon} appeared!", {"pokemon": _join_names(wild_names)}))
	else:
		var names: Array[String] = []
		for trainer: TrainerData in opponent_trainers:
			names.append("%s %s" % [_trainer_type_name(trainer), trainer.display_name])
		await presenter.show_message(Loc.line("{trainer} would like to battle!", {"trainer": _join_names(names)}))
		# The trainer is standing on the field until they throw, so the message comes first and the send-out clears them off it.
		var opposing: Array[String] = []
		for battler: Battler in active_battlers_on_side(1):
			opposing.append(battler.display_name())
		if not opposing.is_empty():
			await presenter.show_message(Loc.line("{trainer} sent out {pokemon}!", {"trainer": _join_names(names), "pokemon": _join_names(opposing)}))
	for battler: Battler in active_battlers_on_side(1):
		await presenter.play_send_out(battler)
	var sent: Array[String] = []
	for battler: Battler in active_battlers_on_side(0):
		sent.append(battler.display_name())
	if not sent.is_empty():
		await presenter.show_message(Loc.line("Go! {pokemon}!", {"pokemon": _join_names(sent)}))
	for battler: Battler in active_battlers_on_side(0):
		await presenter.play_send_out(battler)
	await _run_switch_in_effects()

## Joins names the way the games do: "A", "A and B", "A, B and C".
func _join_names(names: Array[String]) -> String:
	if names.size() <= 1:
		return names[0] if not names.is_empty() else ""
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]

func _send_out_initial() -> void:
	battlers.resize(battlers_per_side * 2)
	position_effects.clear()
	for _position: int in range(battlers.size()):
		position_effects.append({})
	for side: int in range(2):
		var party: PokemonParty = parties[side]
		var sent: int = 0
		for slot: int in range(party.size()):
			if sent >= battlers_per_side:
				break
			var pkmn: Pokemon = party.get_member(slot)
			if pkmn == null or not pkmn.is_able():
				continue
			var position: int = (sent * 2) + side
			_place_battler(position, pkmn, slot)
			sent += 1

func _place_battler(position: int, pkmn: Pokemon, party_slot: int, switching_in: bool = false) -> void:
	var battler: Battler = Battler.new(pkmn, position, self)
	battler.party_index = party_slot
	battlers[position] = battler
	battler.switched_in_this_turn = switching_in
	FormHandlers.on_entering_battle(pkmn, kind == Kind.WILD)
	_apply_shadow_state(battler, switching_in)
	AbilityForms.begin_illusion(self, battler)
	sides[position % 2].seen_party_slots.append(party_slot)
	_restore_gimmick(battler)
	battler_sent_out.emit(battler)

## Applies the Shadow Pokemon effects that occur when one is sent out.
func _apply_shadow_state(battler: Battler, switching_in: bool) -> void:
	if not ShadowPokemon.is_shadow(battler.pokemon):
		return
	# A Pokemon brought onto the field mid-battle arrives calm; the one that started out there keeps whatever temper it walked in with.
	if switching_in:
		ShadowPokemon.leave_hyper_mode(battler.pokemon)
	if Database.has_record(Database.CATEGORY_TYPES, ShadowPokemon.SHADOW_TYPE):
		battler.type_override = [ShadowPokemon.SHADOW_TYPE] as Array[StringName]
	if battler.is_player_side() and changes_the_save():
		ShadowPokemon.wear_heart(battler.pokemon, ShadowPokemon.HeartChange.BATTLE)

func get_battler(position: int) -> Battler:
	if position < 0 or position >= battlers.size():
		return null
	return battlers[position]

## Every battler still on the field.
func all_active_battlers() -> Array[Battler]:
	var result: Array[Battler] = []
	for battler: Battler in battlers:
		if battler != null and not battler.is_fainted():
			result.append(battler)
	return result

## Battlers on the side opposing [param battler].
func opposing_battlers(battler: Battler) -> Array[Battler]:
	var result: Array[Battler] = []
	for other: Battler in battlers:
		if other == null or other.is_fainted():
			continue
		if other.side_index() != battler.side_index():
			result.append(other)
	return result

## Battlers on the same side as [param battler], excluding itself.
func allies_of(battler: Battler) -> Array[Battler]:
	var result: Array[Battler] = []
	for other: Battler in battlers:
		if other == null or other.is_fainted() or other == battler:
			continue
		if other.side_index() == battler.side_index():
			result.append(other)
	return result

## Everyone still standing on [param side_index], in position order.
func active_battlers_on_side(side_index: int) -> Array[Battler]:
	var result: Array[Battler] = []
	for battler: Battler in battlers:
		if battler != null and not battler.is_fainted() and battler.side_index() == side_index:
			result.append(battler)
	return result

## `true` when the player picks this battler's actions rather than the AI.
func is_player_controlled(battler: Battler) -> bool:
	return battler != null and battler.side_index() == 0

## Party slots on [param side_index] that are already out, which the switch menu must not offer.
func active_party_slots(side_index: int) -> Array[int]:
	var result: Array[int] = []
	for battler: Battler in battlers:
		if battler != null and battler.side_index() == side_index:
			result.append(battler.party_index)
	return result

## `true` when two positions are adjacent for a non-long-range move.
func is_adjacent(first: int, second: int) -> bool:
	if first == second or first < 0 or second < 0:
		return false
	@warning_ignore("integer_division")
	var first_slot: int = first / 2
	@warning_ignore("integer_division")
	var second_slot: int = second / 2
	if first % 2 == second % 2:
		return absi(first_slot - second_slot) <= 1
	return absi(first_slot - (battlers_per_side - 1 - second_slot)) <= 1

## The position directly opposite [param position] on the other side, which is the one a triple battle's Shift command looks at.
func facing_position(position: int) -> int:
	@warning_ignore("integer_division")
	var slot: int = battlers_per_side - 1 - (position / 2)
	return (slot * 2) + (1 - (position % 2))

## Every battler [param move] could reach from [param user], before the player narrows it down to one. Follows the three reach flags on the target record, then drops anyone too far away for a move that is not long range.
func candidate_targets(user: Battler, target_data: TargetData) -> Array[Battler]:
	var candidates: Array[Battler] = []
	if target_data == null:
		return candidates
	if target_data.targets_foe:
		candidates.append_array(opposing_battlers(user))
	if target_data.targets_ally:
		candidates.append_array(allies_of(user))
	if target_data.includes_user and not user.is_fainted():
		candidates.append(user)
	if target_data.long_range:
		return candidates
	var reachable: Array[Battler] = []
	for candidate: Battler in candidates:
		if candidate == user or is_adjacent(user.index, candidate.index):
			reachable.append(candidate)
	return reachable

## The battlers [param user] could aim [param move] at, for the player to pick between. Empty when there is nothing to choose: the move hits everything it can reach, aims at the user, or there is only one legal target anyway.
func choosable_targets(user: Battler, move: MoveData) -> Array[Battler]:
	var none: Array[Battler] = []
	if move == null:
		return none
	var data: TargetData = Database.target(move.target)
	if data == null or data.targets_user() or not data.can_choose_target():
		return none
	var candidates: Array[Battler] = candidate_targets(user, data)
	return candidates if candidates.size() > 1 else none

## `true` when a Poke Ball can be thrown at the current opponent.
func can_throw_poke_ball(ball_id: StringName = &"") -> bool:
	if is_safari_battle():
		return safari != null and safari.balls_left > 0
	if is_bug_contest_battle():
		return contest != null and contest.balls_left > 0
	if kind == Kind.TRAINER and can_snag(ball_id):
		return active_battlers_on_side(1).size() == 1
	if not can_catch:
		return false
	if kind != Kind.WILD:
		return false
	return active_battlers_on_side(1).size() == 1

## `true` when [param ball_id] would snag the Pokemon standing opposite: it has to be a Snag Ball, and what it is thrown at has to be a Shadow Pokemon.
##
## A Snag Ball requires a Snag Machine and a Shadow Pokemon owned by another trainer.
func can_snag(ball_id: StringName) -> bool:
	if ball_id.is_empty():
		return false
	var record: ItemData = Database.item(ball_id)
	if record == null or not record.is_snag_ball():
		return false
	for candidate: Battler in active_battlers_on_side(1):
		if ShadowPokemon.is_shadow(candidate.pokemon):
			return true
	return false

## `true` when [param battler] is a Shadow Pokemon of the player's that has lost its temper, which is the only time calling out to one does anything.
func can_call_to(battler: Battler) -> bool:
	if battler == null or not battler.is_player_side():
		return false
	return ShadowPokemon.hyper_mode(battler.pokemon)

# === Rounds ===

func _run_round() -> void:
	begin_round()

	var chosen: Array[BattleAction] = await _choose_round_actions()
	if outcome != BattlePresenter.Outcome.UNDECIDED:
		return

	set_round_actions(chosen)
	await run_round_actions()

	await _run_end_of_round()
	for battler: Battler in all_active_battlers():
		battler.end_turn()

## Collects everyone's action for the round: the player's side first, so the Pokemon it controls can be stepped back through, then the opposing side.
func _choose_round_actions() -> Array[BattleAction]:
	if recording != null and recording.replaying:
		var replayed: Array[BattleAction] = recording.take_round(self)
		if replayed.is_empty():
			# The recording has run out before the battle finished, which means it was cut short. Ending it here is better than carrying on with actions nobody chose.
			outcome = BattlePresenter.Outcome.DRAW
		return replayed
	var chosen: Dictionary = {}
	await _choose_side_actions(chosen, 0)
	if outcome != BattlePresenter.Outcome.UNDECIDED:
		return []
	await _choose_side_actions(chosen, 1)

	var ordered: Array[BattleAction] = []
	for battler: Battler in all_active_battlers():
		if chosen.has(battler.index):
			ordered.append(chosen[battler.index])
	if recording != null:
		recording.record_round(ordered)
	return ordered

## Walks one side's battlers in position order, filling [param chosen]. The player may back out of a battler's menu to redo the one before it, and an action that uses the whole round stops the rest of the side being asked.
func _choose_side_actions(chosen: Dictionary, side_index: int) -> void:
	# Nothing attacks in the Safari Zone. The Pokemon opposite is deciding whether to stay, which the end of the round settles.
	if side_index == 1 and is_safari_battle():
		return
	var order: Array[Battler] = active_battlers_on_side(side_index)
	var position: int = 0
	while position < order.size():
		if outcome != BattlePresenter.Outcome.UNDECIDED:
			return
		var battler: Battler = order[position]
		var forced: BattleAction = forced_action(battler)
		if forced != null:
			chosen[battler.index] = forced
			position += 1
			continue
		var action: BattleAction = await _request_action(battler, position == 0)
		if action == null:
			action = BattleAI.choose_action(self, battler)
		if action.kind == BattleAction.Kind.CANCEL:
			if position == 0:
				continue
			position -= 1
			chosen.erase(order[position].index)
			continue
		chosen[battler.index] = action
		if action.uses_whole_round():
			for skipped: Battler in order.slice(position + 1):
				chosen.erase(skipped.index)
			return
		position += 1

## Asks whoever is in charge of [param battler] what it should do.
func _request_action(battler: Battler, is_first_choice: bool) -> BattleAction:
	# A side fighting on instinct is never asked: its Pokemon pick for themselves, which is the whole point of the Battle Palace.
	if instinct_sides.has(battler.side_index()):
		return BattleInstinct.choose_action(self, battler)
	if is_player_controlled(battler) and presenter != null:
		var chosen: BattleAction = await presenter.choose_action(battler, is_first_choice)
		if chosen != null:
			return chosen
	return BattleAI.choose_action(self, battler)

## Returns a forced action for a battler, or `null` when it may choose freely.
func forced_action(battler: Battler) -> BattleAction:
	var locked: StringName = battler.forced_move_id
	if locked.is_empty():
		locked = battler.get_effect_id(BattleEffects.TWO_TURN_ATTACK)
	if locked.is_empty() and battler.has_effect(BattleEffects.MULTI_TURN_ATTACK):
		# Recharging still costs the turn, so the move is "used" and refused.
		locked = battler.last_move_used
		if locked.is_empty() and not battler.moves().is_empty():
			locked = battler.moves()[0].id
	if locked.is_empty():
		return null
	var move: PokemonMove = battler.get_move(locked)
	if move == null:
		move = PokemonMove.create(locked)
	var targets: Array[int] = []
	if battler.forced_move_target >= 0:
		targets.append(battler.forced_move_target)
	return BattleAction.use_move(battler.index, move, targets)

## Runs every action, letting After You, Quash and a sprung Shell Trap reorder the queue between one action and the next.
func _run_actions() -> void:
	while outcome == BattlePresenter.Outcome.UNDECIDED:
		var action: BattleAction = _next_action()
		if action == null:
			return
		_acted_this_round.append(action.battler_index)
		var battler: Battler = get_battler(action.battler_index)
		if battler == null or battler.is_fainted():
			continue
		await _perform_action(action)
		await _resolve_faints()
		await _run_pending_ability_switches()
		await _run_instructed_moves(battler)

## Picks the next action to run: anything pulled to the front by After You goes first, then the normal order, then whatever Quash pushed back, least-quashed first.
func _next_action() -> BattleAction:
	var pending: Array[BattleAction] = []
	for action: BattleAction in _actions:
		if _acted_this_round.has(action.battler_index):
			continue
		var battler: Battler = get_battler(action.battler_index)
		if battler == null or battler.is_fainted():
			_acted_this_round.append(action.battler_index)
			continue
		pending.append(action)
	if pending.is_empty():
		return null

	for action: BattleAction in pending:
		if get_battler(action.battler_index).has_effect(BattleEffects.MOVE_NEXT):
			return action
	var lowest_quash: int = -1
	var chosen: BattleAction = null
	for action: BattleAction in pending:
		var quash: int = int(get_battler(action.battler_index).get_effect(BattleEffects.QUASH))
		if quash == 0:
			return action
		if lowest_quash < 0 or quash < lowest_quash:
			lowest_quash = quash
			chosen = action
	return chosen

## The action [param battler_index] chose this round, or `null` when it is not acting. Sucker Punch, Me First, After You and Round all need to know what someone else is about to do.
func action_for(battler_index: int) -> BattleAction:
	for action: BattleAction in _actions:
		if action.battler_index == battler_index:
			return action
	return null

## `true` when [param battler_index] has already taken its action this round.
func has_acted_this_round(battler_index: int) -> bool:
	return _acted_this_round.has(battler_index)

## Shows the lines that Focus Punch, Shell Trap and Beak Blast print before anyone moves, which is also when they arm themselves.
func _announce_round_start_messages() -> void:
	for action: BattleAction in _actions:
		if action.kind != BattleAction.Kind.USE_MOVE or action.move == null:
			continue
		var battler: Battler = get_battler(action.battler_index)
		if battler == null or battler.is_fainted():
			continue
		var record: MoveData = action.move.data()
		if record == null:
			continue
		var effect: MoveEffect = MoveEffects.get_effect(record.function_code)
		var message: String = effect.round_start_message(self, battler, record)
		if not message.is_empty():
			await presenter.show_message(message)

## Orders actions by priority bracket, then speed, with a stable tiebreak.
func _sort_actions() -> void:
	for action: BattleAction in _actions:
		var battler: Battler = get_battler(action.battler_index)
		action.resolved_priority = action.base_priority()
		if action.kind == BattleAction.Kind.USE_MOVE and battler != null:
			action.resolved_priority += _priority_bonus(battler, action)
		action.resolved_speed = battler.effective_speed() if battler != null else 0
		action.speed_tiebreak = RNG.below(1000)
		# Stall goes to the back of its own bracket rather than out of it, which is a rung below speed and above the random tiebreak.
		action.moves_last_in_bracket = battler != null and battler.has_ability(&"STALL")
	var reverse_speed: bool = field.has_effect(BattleEffects.TRICK_ROOM)
	_actions.sort_custom(func(a: BattleAction, b: BattleAction) -> bool:
		if a.resolved_priority != b.resolved_priority:
			return a.resolved_priority > b.resolved_priority
		if a.moves_last_in_bracket != b.moves_last_in_bracket:
			return b.moves_last_in_bracket
		if a.resolved_speed != b.resolved_speed:
			return a.resolved_speed < b.resolved_speed if reverse_speed else a.resolved_speed > b.resolved_speed
		return a.speed_tiebreak > b.speed_tiebreak
	)

func _priority_bonus(battler: Battler, action: BattleAction) -> int:
	var bonus: int = 0
	var move: MoveData = action.move.data() if action.move != null else null
	if move == null:
		return 0
	if battler.has_ability(&"PRANKSTER") and move.is_status():
		bonus += 1
	if battler.has_ability(&"GALEWINGS") and move.type == &"FLYING":
		if battler.hp() == battler.total_hp() or GameSettings.data.mechanics_generation < 7:
			bonus += 1
	if battler.has_ability(&"TRIAGE") and move.is_healing_move():
		bonus += 3
	bonus += AbilityReactions.priority_bonus(battler, move)
	bonus += MoveEffects.get_effect(move.function_code).priority_bonus(self, battler, move)
	return bonus

## The priority the round's sort settled on for [param battler], which the priority-blocking Abilities need in order to know whether to step in. A battler that is not acting this round — a called move, a delayed attack — has no action, and counts as ordinary priority.
func _resolved_priority_of(battler: Battler) -> int:
	var action: BattleAction = action_for(battler.index)
	return action.resolved_priority if action != null else 0

func _perform_action(action: BattleAction) -> void:
	var battler: Battler = get_battler(action.battler_index)
	match action.kind:
		BattleAction.Kind.USE_MOVE:
			await _apply_gimmick(battler, action)
			await _use_move(battler, action)
		BattleAction.Kind.SWITCH:
			await _run_pursuit(battler)
			if battler.is_fainted():
				battler.has_acted = true
				return
			await _switch_battler(battler, action.switch_to)
		BattleAction.Kind.USE_ITEM:
			await _use_item(battler, action)
		BattleAction.Kind.RUN:
			await _attempt_run(battler)
		BattleAction.Kind.SHIFT:
			await _shift_to_centre(battler)
		BattleAction.Kind.THROW_BAIT:
			await _throw_bait(get_battler(1))
		BattleAction.Kind.THROW_ROCK:
			await _throw_rock(get_battler(1))
		BattleAction.Kind.CALL:
			await _call_to(battler)
	battler.has_acted = true

## Calls out to a Shadow Pokemon and reduces its Hyper Mode state.
func _call_to(battler: Battler) -> void:
	if battler == null:
		return
	await presenter.show_message(Loc.line("{trainer} called {pokemon}!", {
		"trainer": _side_name(battler), "pokemon": battler.battle_name(),
	}))
	if not ShadowPokemon.is_shadow(battler.pokemon):
		await presenter.show_message("But nothing happened!")
		return
	if not ShadowPokemon.hyper_mode(battler.pokemon):
		await presenter.show_message("But nothing happened!")
		return
	ShadowPokemon.leave_hyper_mode(battler.pokemon)
	if changes_the_save():
		ShadowPokemon.wear_heart(battler.pokemon, ShadowPokemon.HeartChange.CALL)
	await presenter.show_message(Loc.line(
		"{pokemon} came to its senses from the Trainer's call!",
		{"pokemon": battler.battle_name()}))
	presenter.refresh_battler(battler)

## Lets a waiting Pursuit strike [param switcher] before it leaves the field.
func _run_pursuit(switcher: Battler) -> void:
	for action: BattleAction in _actions:
		if _acted_this_round.has(action.battler_index):
			continue
		if action.kind != BattleAction.Kind.USE_MOVE or action.move == null:
			continue
		var record: MoveData = action.move.data()
		if record == null or record.function_code != &"PursueSwitchingFoe":
			continue
		var pursuer: Battler = get_battler(action.battler_index)
		if pursuer == null or pursuer.is_fainted():
			continue
		if pursuer.side_index() == switcher.side_index():
			continue
		if not pursuer.can_use_move(action.move):
			continue
		_acted_this_round.append(pursuer.index)
		action.targets = [switcher.index]
		pursuit_active = true
		await _use_move(pursuer, action)
		pursuit_active = false
		pursuer.has_acted = true
		await _resolve_faints()
		if switcher.is_fainted() or outcome != BattlePresenter.Outcome.UNDECIDED:
			return

# === Moves ===

func _use_move(user: Battler, action: BattleAction) -> void:
	await _execute_move(user, action, false)
	await _run_called_moves()

## Queues [param move_id] to be used by [param user] as soon as the move that asked for it has finished. Metronome, Sleep Talk, Copycat, Mirror Move, Nature Power, Assist and Me First all go through here.
func call_move(user: Battler, move_id: StringName, target_index: int = -1) -> void:
	_called_moves.append({"user": user, "move": move_id, "target": target_index})

## Runs everything [method call_move] queued, one at a time. A called move may queue another, so the chain is cut off at [constant MAX_CALL_DEPTH] as a backstop against a pair of moves that call each other.
func _run_called_moves() -> void:
	var run_so_far: int = 0
	while not _called_moves.is_empty():
		if run_so_far >= MAX_CALL_DEPTH:
			_called_moves.clear()
			return
		run_so_far += 1
		var entry: Dictionary = _called_moves.pop_front()
		var user: Battler = entry["user"]
		if user == null or user.is_fainted() or outcome != BattlePresenter.Outcome.UNDECIDED:
			continue
		var move: PokemonMove = PokemonMove.create(StringName(entry["move"]))
		var targets: Array[int] = []
		if int(entry["target"]) >= 0:
			targets.append(int(entry["target"]))
		await _execute_move(user, BattleAction.use_move(user.index, move, targets), true)
		# Me First only powers up the one move it stole.
		user.clear_effect(BattleEffects.ME_FIRST)
		await _resolve_faints()

## The whole of using one move. [param called] is `true` when another move asked for this one, which skips the PP cost, the can-act checks and the bookkeeping that only regular uses do.
func _execute_move(user: Battler, action: BattleAction, called: bool) -> void:
	var move: PokemonMove = action.move
	if move == null:
		return
	var record: MoveData = move.data()
	if record == null:
		return

	if not called and not await _obeys_through_hyper_mode(user, record):
		return
	if not called and not await _can_act(user, record):
		return

	var effect: MoveEffect = MoveEffects.get_effect(record.function_code)

	# Two-turn moves charge on the first turn and strike on the second.
	if effect.is_two_turn and not user.has_effect(BattleEffects.TWO_TURN_ATTACK):
		user.set_effect(BattleEffects.TWO_TURN_ATTACK, move.id)
		if not effect.invulnerable_state.is_empty():
			user.set_effect(BattleEffects.INVULNERABLE, effect.invulnerable_state)
		if not called:
			move.use_pp()
		await presenter.show_message(effect.charge_message % user.battle_name() if effect.charge_message.contains("%s") else effect.charge_message)
		return
	user.clear_effect(BattleEffects.TWO_TURN_ATTACK)
	user.clear_effect(BattleEffects.INVULNERABLE)

	if not called:
		move.use_pp()
		_update_consecutive_uses(user, move.id)
		if not user.moves_used.has(move.id):
			user.moves_used.append(move.id)

	var announcement: String = effect.use_message(self, user, record)
	if not announcement.is_empty():
		await presenter.show_message(announcement)

	# Aegislash draws its blade and Protean repaints its user before anything is worked out, so the change counts towards this very move.
	var used_type: StringName = DamageCalculator.move_type_for(self, user, user, record, effect)
	for message: String in AbilityReactions.before_move_used(self, user, record, used_type):
		await presenter.show_message(message)

	if await _powder_explodes(user, record, effect):
		user.last_move_failed = true
		_note_for_judge(user, record, false, called)
		return

	if AbilityReactions.explosion_is_damped(self, user, effect):
		await presenter.show_message(Loc.line("{pokemon} cannot use {move}!", {
			"pokemon": user.battle_name(), "move": record.get_translated_name(),
		}))
		user.last_move_failed = true
		_note_for_judge(user, record, false, called)
		return
	if not effect.can_be_used(self, user, record):
		await presenter.show_message(_take_failure_message(effect))
		user.last_move_failed = true
		_note_for_judge(user, record, false, called)
		return

	var targets: Array[Battler] = effect.override_targets(self, user, _resolve_targets(user, action, record), record)
	var target_data: TargetData = Database.target(record.target)
	if targets.is_empty() and target_data != null and target_data.num_targets > 0:
		await presenter.show_message("But there was no target...")
		user.last_move_failed = true
		_note_for_judge(user, record, false, called)
		return

	effect.on_start(self, user, targets, record)
	var damaging_this_use: bool = record.is_damaging() and effect.is_damaging_this_use(self, user, record)
	await presenter.play_move_animation(user, targets, record)

	var any_hit: bool = false
	for target: Battler in targets:
		if target.is_fainted():
			continue
		if await _hit_target(user, target, move, record, effect, damaging_this_use):
			any_hit = true

	if targets.is_empty() and not damaging_this_use:
		if effect.apply_status_move(self, user, user, record):
			any_hit = true
		else:
			await presenter.show_message(_take_failure_message(effect))

	effect.on_end(self, user, targets, record)
	_note_for_judge(user, record, any_hit, called)
	user.last_move_used = move.id
	last_move_used_in_battle = move.id
	user.last_move_used_type = DamageCalculator.move_type_for(self, user, targets[0] if not targets.is_empty() else user, record, effect)
	if not called:
		user.last_regular_move_used = move.id
		user.last_regular_move_target = targets[0].index if not targets.is_empty() else -1
	user.last_move_failed = not any_hit and damaging_this_use

	for message: String in AbilityReactions.after_move_used(self, user, record, any_hit):
		await presenter.show_message(message)
	# A move that changed the weather changes what Castform and Cherrim are, and it has to happen now rather than at the end of the round.
	for battler: Battler in all_active_battlers():
		for message: String in AbilityForms.refresh_weather_forms(self, battler):
			await presenter.show_message(message)

	if effect.recharges_after and any_hit:
		user.set_effect(BattleEffects.MULTI_TURN_ATTACK, 1)
	if effect.switches_out_user and any_hit:
		await _switch_after_move(user)
	# Roar, Whirlwind and Dragon Tail drag whoever they hit off the field. Suction Cups and a rooted Pokemon both stay put; a wild Pokemon that is blown away ends the battle rather than being replaced.
	if effect.switches_out_target and any_hit:
		for target: Battler in targets:
			await _force_out(target)
	if not called:
		await _run_dancers(user, record)
	if user.held_item() == &"LIFEORB" and any_hit and damaging_this_use:
		if not user.has_ability(&"MAGICGUARD"):
			@warning_ignore("integer_division")
			user.take_damage(maxi(user.total_hp() / 10, 1))
			await presenter.show_message(Loc.line("{pokemon} lost some HP!", {"pokemon": user.battle_name()}))
	# A held Leppa Berry watches PP rather than HP, so it is asked here — the one moment a move can have just run out.
	for message: String in ItemEffects.on_end_of_using_move(self, user):
		await presenter.show_message(message)

## Tells the judges what a move came to, when there are judges watching. A move another move set off is not one its user chose, so it is not scored.
func _note_for_judge(user: Battler, record: MoveData, landed: bool, called: bool) -> void:
	if judge == null or called:
		return
	judge.note_move(user, record, landed)

## Takes the effect's own failure line, falling back to the generic one.
func _take_failure_message(effect: MoveEffect) -> String:
	if effect.failure_message.is_empty():
		return "But it failed!"
	var message: String = effect.failure_message
	effect.failure_message = ""
	return message

## Powder blows up in the user's face when it tries to use a Fire move.
func _powder_explodes(user: Battler, record: MoveData, effect: MoveEffect) -> bool:
	if not user.has_effect(BattleEffects.POWDER):
		return false
	if DamageCalculator.move_type_for(self, user, user, record, effect) != &"FIRE":
		return false
	await presenter.show_message("When the flame touched the powder on the Pokemon, it exploded!")
	var weather: StringName = field.effective_weather(self)
	if weather != &"Rain" and weather != &"HeavyRain" and not user.has_ability(&"MAGICGUARD"):
		user.take_damage(maxi(int(round(float(user.total_hp()) / 4.0)), 1))
		await presenter.show_message(Loc.line("{pokemon} is hurt by Powder!", {"pokemon": user.battle_name()}))
		presenter.refresh_battler(user)
	return true

## Makes every battler that Instruct pointed at repeat its last move.
func _run_instructed_moves(instructor: Battler) -> void:
	for battler: Battler in all_active_battlers():
		if not battler.has_effect(BattleEffects.INSTRUCT):
			continue
		battler.clear_effect(BattleEffects.INSTRUCT)
		var repeated: StringName = battler.last_regular_move_used
		if repeated.is_empty():
			continue
		var known: PokemonMove = battler.get_move(repeated)
		if known == null or not battler.can_use_move(known):
			continue
		await presenter.show_message(Loc.line("{pokemon} used the move instructed by {instructor}!", {"pokemon": battler.battle_name(), "instructor": instructor.battle_name()}))
		battler.set_effect(BattleEffects.INSTRUCTED, true)
		var targets: Array[int] = []
		if battler.last_regular_move_target >= 0:
			targets.append(battler.last_regular_move_target)
		await _execute_move(battler, BattleAction.use_move(battler.index, known, targets), true)
		battler.clear_effect(BattleEffects.INSTRUCTED)
		await _run_called_moves()
		await _resolve_faints()

## Checks whether a battler can act, including Shadow Pokemon Hyper Mode.
##
## `Pokemon.hyper_mode` was saved and read by nothing: a Shadow Pokemon fought exactly like an ordinary one.
func _obeys_through_hyper_mode(user: Battler, record: MoveData) -> bool:
	if not user.is_player_side() or not ShadowPokemon.is_shadow(user.pokemon):
		return true
	if ShadowPokemon.try_enter_hyper_mode(user.pokemon):
		await presenter.show_message(Loc.line(
			"{pokemon}'s emotions rose to a fever pitch!\nIt entered Hyper Mode!",
			{"pokemon": user.battle_name()}
		))
	if ShadowPokemon.obeys(user.pokemon, record):
		return true
	await presenter.show_message(Loc.line(
		"{pokemon} is in Hyper Mode and would not listen!", {"pokemon": user.battle_name()}
	))
	return false

func _can_act(user: Battler, record: MoveData) -> bool:
	# Truant loafs on every second round, whatever the Pokemon was told to do. It always acts on the first, so the flag starts out saying it did not.
	if user.has_ability(&"TRUANT"):
		user.truant_acted_last_round = not user.truant_acted_last_round
		if not user.truant_acted_last_round:
			await presenter.show_message(Loc.line("{pokemon} is loafing around!", {"pokemon": user.battle_name()}))
			return false
	if user.has_effect(BattleEffects.FLINCH):
		user.clear_effect(BattleEffects.FLINCH)
		await presenter.show_message(Loc.line("{pokemon} flinched and couldn't move!", {"pokemon": user.battle_name()}))
		for message: String in AbilityReactions.on_flinch(self, user):
			await presenter.show_message(message)
		return false
	if user.has_effect(BattleEffects.MULTI_TURN_ATTACK):
		user.clear_effect(BattleEffects.MULTI_TURN_ATTACK)
		await presenter.show_message(Loc.line("{pokemon} must recharge!", {"pokemon": user.battle_name()}))
		return false
	match user.pokemon.status:
		&"SLEEP":
			# Early Bird burns through a sleep twice as fast as anything else.
			user.pokemon.status_count -= 2 if user.has_ability(&"EARLYBIRD") else 1
			if user.pokemon.status_count <= 0:
				user.cure_status()
				await presenter.show_message(Loc.line("{pokemon} woke up!", {"pokemon": user.battle_name()}))
			else:
				await presenter.show_message(Loc.line("{pokemon} is fast asleep.", {"pokemon": user.battle_name()}))
				if record.has_flag(&"UsableWhileAsleep"):
					return true
				return MoveEffects.get_effect(record.function_code).usable_while_asleep()
		&"FROZEN":
			if record.thaws_user() or RNG.chance(1, 5):
				user.cure_status()
				await presenter.show_message(Loc.line("{pokemon} thawed out!", {"pokemon": user.battle_name()}))
			else:
				await presenter.show_message(Loc.line("{pokemon} is frozen solid!", {"pokemon": user.battle_name()}))
				return false
		&"PARALYSIS":
			if RNG.chance(1, 4):
				await presenter.show_message(Loc.line("{pokemon} is paralyzed! It can't move!", {"pokemon": user.battle_name()}))
				return false
	if user.has_effect(BattleEffects.CONFUSION):
		user.set_effect(BattleEffects.CONFUSION, int(user.get_effect(BattleEffects.CONFUSION)) - 1)
		if int(user.get_effect(BattleEffects.CONFUSION)) <= 0:
			user.clear_effect(BattleEffects.CONFUSION)
			await presenter.show_message(Loc.line("{pokemon} snapped out of its confusion!", {"pokemon": user.battle_name()}))
		else:
			await presenter.show_message(Loc.line("{pokemon} is confused!", {"pokemon": user.battle_name()}))
			if RNG.chance(1, 3):
				var self_damage: int = _confusion_damage(user)
				user.take_damage(self_damage)
				await presenter.show_message("It hurt itself in its confusion!")
				presenter.refresh_battler(user)
				return false
	if user.has_effect(BattleEffects.ATTRACT):
		if RNG.chance(1, 2):
			await presenter.show_message(Loc.line("{pokemon} is immobilised by love!", {"pokemon": user.battle_name()}))
			return false
	return true

func _confusion_damage(user: Battler) -> int:
	var attack: int = user.effective_stat(&"ATTACK")
	var defense: int = user.effective_stat(&"DEFENSE")
	var level: int = user.level()
	var base: float = ((2.0 * level / 5.0 + 2.0) * 40.0 * attack / defense) / 50.0 + 2.0
	return maxi(int(base * DamageCalculator.random_roll()), 1)

func _hit_target(user: Battler, target: Battler, _move: PokemonMove, record: MoveData, effect: MoveEffect, damaging: bool) -> bool:
	if not effect.succeeds_against(self, user, target, record):
		var reason: String = effect.failure_message
		effect.failure_message = ""
		await presenter.show_message(reason if not reason.is_empty() else Loc.line("It doesn't affect {target}...", {"target": target.battle_name()}))
		effect.on_miss(self, user, target, record)
		return false
	var blocked: Array[String] = []
	if AbilityReactions.blocks_move(self, user, target, record, _resolved_priority_of(user), blocked):
		await presenter.show_message(blocked[0])
		effect.on_miss(self, user, target, record)
		return false
	if AbilityReactions.bounces_move(user, target, record):
		await presenter.show_message(Loc.line("{target} bounced the move back!", {"target": target.battle_name()}))
		effect.apply_status_move(self, target, user, record)
		presenter.refresh_battler(user)
		return false
	if target.has_effect(BattleEffects.PROTECT) and record.can_be_protected_against():
		if not AbilityReactions.ignores_protection(user, record):
			await presenter.show_message(Loc.line("{target} protected itself!", {"target": target.battle_name()}))
			effect.on_miss(self, user, target, record)
			return false
	if not DamageCalculator.rolls_hit(self, user, target, record, effect):
		await presenter.show_message(Loc.line("{target} avoided the attack!", {"target": target.battle_name()}))
		effect.on_miss(self, user, target, record)
		return false

	if not damaging:
		if not effect.apply_status_move(self, user, target, record):
			await presenter.show_message(_take_failure_message(effect))
			return false
		effect.on_after_all_hits(self, user, target, record, 0)
		presenter.refresh_battler(target)
		presenter.refresh_battler(user)
		return true

	# Disguise and Ice Face soak the first hit up entirely, decoy and all.
	var shielded: Array[String] = []
	if AbilityForms.absorbs_hit(self, target, record, shielded):
		for message: String in shielded:
			await presenter.show_message(message)
		presenter.refresh_battler(target)
		return false

	var extra_hits: int = AbilityReactions.extra_hits(user, record, effect)
	var hits: int = effect.hit_count(self, user, target) + extra_hits
	var total_damage: int = 0
	var any_critical: bool = false
	var last_result: DamageCalculator.DamageResult = null
	for hit: int in range(hits):
		if target.is_fainted():
			break
		var result: DamageCalculator.DamageResult = DamageCalculator.calculate(self, user, target, record, effect)
		# Parental Bond's second strike lands at a fraction of the first.
		if extra_hits > 0 and hit >= hits - extra_hits:
			result.damage = maxi(int(float(result.damage) * AbilityReactions.extra_hit_multiplier(user)), 1)
		last_result = result
		if result.immune:
			await presenter.show_message(Loc.line("It doesn't affect {target}...", {"target": target.battle_name()}))
			effect.on_miss(self, user, target, record)
			return false
		if effect.is_ohko:
			if user.level() < target.level():
				await presenter.show_message("But it failed!")
				effect.on_miss(self, user, target, record)
				return false
			result.damage = target.hp()
		var damage: int = _apply_damage(user, target, result.damage, record)
		total_damage += damage
		presenter.refresh_battler(target)
		# Two evolution methods are settled by what happens here: how many critical hits a party member lands, and how much it is hit for.
		if target.is_player_side():
			tally.record_damage(target.pokemon, damage)
		if result.critical:
			any_critical = true
			if user.is_player_side():
				tally.record_critical(user.pokemon)
			await presenter.show_message("A critical hit!")
	if last_result != null:
		await _announce_effectiveness(last_result, target)
	if hits > 1:
		await presenter.show_message(Loc.line("Hit {hits} time(s)!", {"hits": hits}))

	if total_damage > 0:
		target.last_damage_category = record.category
		if record.is_physical():
			target.took_physical_hit = true
		_store_bide_damage(user, target, total_damage)
		var broken: Array[String] = []
		if AbilityForms.break_illusion(target, broken):
			for message: String in broken:
				await presenter.show_message(message)
			presenter.refresh_battler(target)
		if AbilityEffects.makes_contact(user, record):
			for message: String in AbilityEffects.on_contact(self, user, target):
				await presenter.show_message(message)
		for message: String in ItemEffects.on_damage_taken(self, target, total_damage):
			await presenter.show_message(message)
		for message: String in ItemEffects.check_berries(self, target):
			await presenter.show_message(message)
		for message: String in AbilityReactions.on_item_consumed(self, target):
			await presenter.show_message(message)
		var move_type: StringName = DamageCalculator.move_type_for(self, user, target, record, effect)
		for message: String in AbilityReactions.on_hit_taken(self, user, target, record, move_type, total_damage, any_critical):
			await presenter.show_message(message)
		for message: String in AbilityReactions.on_damage_dealt(self, user, target, total_damage):
			await presenter.show_message(message)
		for message: String in AbilityForms.refresh_hp_forms(self, target):
			await presenter.show_message(message)
		await _run_hit_reactions(user, target, record, total_damage)
	effect.on_hit(self, user, target, record, total_damage)
	effect.on_after_all_hits(self, user, target, record, total_damage)
	presenter.refresh_battler(target)
	presenter.refresh_battler(user)
	return total_damage > 0

## Bide remembers everything that hurt it and who did it last.
func _store_bide_damage(user: Battler, target: Battler, damage: int) -> void:
	if not target.has_effect(BattleEffects.BIDE):
		return
	target.set_effect(BattleEffects.BIDE_DAMAGE, int(target.get_effect(BattleEffects.BIDE_DAMAGE)) + damage)
	target.set_effect(BattleEffects.BIDE_TARGET, user.index)

## The effects a battler can have waiting on being hit: Beak Blast's burn and Shell Trap springing.
func _run_hit_reactions(user: Battler, target: Battler, record: MoveData, damage: int) -> void:
	if target.side_index() == user.side_index():
		return
	if target.has_effect(BattleEffects.BEAK_BLAST) and AbilityEffects.makes_contact(user, record):
		if user.inflict_status(&"BURN", 0, target):
			await presenter.show_message(Loc.line("{pokemon} was burned!", {"pokemon": user.battle_name()}))
			presenter.refresh_battler(user)
	if target.has_effect(BattleEffects.SHELL_TRAP) and record.is_physical() and damage > 0:
		if not _acted_this_round.has(target.index) and action_for(target.index) != null:
			target.set_effect(BattleEffects.MOVE_NEXT, true)
			target.clear_effect(BattleEffects.QUASH)

## Applies damage through the substitute and the survive-on-1-HP effects.
func _apply_damage(user: Battler, target: Battler, amount: int, record: MoveData) -> int:
	if amount <= 0:
		return 0
	if target.has_substitute() and not record.ignores_substitute():
		if target.damage_substitute(amount):
			presenter.show_message(Loc.line("{target}'s substitute faded!", {"target": target.battle_name()}))
		return 0
	var lethal: bool = amount >= target.hp()
	if lethal and target.hp() == target.total_hp() and target.has_ability(&"STURDY"):
		amount = target.hp() - 1
	elif lethal and ItemEffects.survives_lethal_hit(target):
		amount = target.hp() - 1
		target.consume_item()
	elif lethal and target.has_effect(BattleEffects.ENDURE):
		amount = target.hp() - 1
	var dealt: int = target.take_damage(amount)
	if dealt > 0:
		target.last_attacker_index = user.index
		target.last_move_taken = record.id
	if judge != null and user.side_index() != target.side_index():
		judge.note_damage(user, dealt)
	# Everyone who landed a hit shares the experience, which matters most in a double battle where two Pokemon can wear the same target down.
	if not target.participants.has(user.index):
		target.participants.append(user.index)
	return dealt

func _announce_effectiveness(result: DamageCalculator.DamageResult, _target: Battler) -> void:
	if result.effectiveness > 1.0:
		await presenter.show_message("It's super effective!")
	elif result.effectiveness < 1.0 and result.effectiveness > 0.0:
		await presenter.show_message("It's not very effective...")

func _resolve_targets(user: Battler, action: BattleAction, record: MoveData) -> Array[Battler]:
	var target_data: TargetData = Database.target(record.target)
	if target_data == null:
		return opposing_battlers(user).slice(0, 1)
	if target_data.targets_user():
		return [user]
	var single_foe: bool = target_data.targets_foe and not target_data.targets_all and target_data.num_targets == 1
	if single_foe:
		var pulled: Battler = _redirected_target(user, record)
		if pulled != null:
			return [pulled]
	if not action.targets.is_empty():
		var chosen: Array[Battler] = []
		for index: int in action.targets:
			var target: Battler = get_battler(index)
			if target != null and not target.is_fainted():
				chosen.append(target)
		if not chosen.is_empty():
			return chosen
	var candidates: Array[Battler] = candidate_targets(user, target_data)
	if candidates.is_empty():
		return []
	if target_data.num_targets >= 2 or target_data.targets_all:
		return candidates
	# Nothing picked a target, so the engine does. A move that could have been aimed at an ally is not aimed at one by accident: Tackle can hit your own partner, but only because somebody chose that.
	var foes: Array[Battler] = []
	for candidate: Battler in candidates:
		if candidate.side_index() != user.side_index():
			foes.append(candidate)
	if not foes.is_empty():
		candidates = foes
	return [candidates[RNG.below(candidates.size())]]

## The battler that Follow Me, Rage Powder or Spotlight is pulling a single-target move towards, or `null` when nothing is redirecting it.
func _redirected_target(user: Battler, record: MoveData) -> Battler:
	if record.has_flag(&"CannotBeRedirected") or record.function_code == &"CannotBeRedirected":
		return null
	if AbilityReactions.ignores_redirection(user):
		return null
	var long_range: bool = true
	var target_data: TargetData = Database.target(record.target)
	if target_data != null:
		long_range = target_data.long_range
	var best: Battler = null
	var best_strength: int = 0
	for candidate: Battler in opposing_battlers(user):
		# Follow Me cannot pull a move towards someone the user could not have aimed it at in the first place.
		if not long_range and not is_adjacent(user.index, candidate.index):
			continue
		var strength: int = 0
		if candidate.has_effect(BattleEffects.FOLLOW_ME):
			strength = 1
		var spotlight: int = int(candidate.get_effect(BattleEffects.SPOTLIGHT))
		if spotlight > 0:
			strength = maxi(strength, spotlight + 1)
		if strength > best_strength:
			best_strength = strength
			best = candidate
	return best

## Effects held by battle position [param position], which outlive a switch.
func effects_at_position(position: int) -> Dictionary:
	while position_effects.size() <= position:
		position_effects.append({})
	return position_effects[position]

## Exchanges the battlers standing in two positions, as Ally Switch does. The round's chosen actions move with them; anything held by the position itself, such as a Future Sight already on its way, stays where it is.
func swap_battlers(first: int, second: int) -> bool:
	if first == second:
		return false
	var one: Battler = get_battler(first)
	var two: Battler = get_battler(second)
	if one == null or two == null or one.side_index() != two.side_index():
		return false
	battlers[first] = two
	battlers[second] = one
	one.index = second
	two.index = first
	for action: BattleAction in _actions:
		if action.battler_index == first:
			action.battler_index = second
		elif action.battler_index == second:
			action.battler_index = first
	for slot: int in range(_acted_this_round.size()):
		if _acted_this_round[slot] == first:
			_acted_this_round[slot] = second
		elif _acted_this_round[slot] == second:
			_acted_this_round[slot] = first
	return true

## `true` when [param battler] may use a triple battle's Shift command: it has to be standing on an end, the centre of its own side has to be occupied by an ally it can trade with, and the position directly opposite has to be empty — which is the game's way of saying there is nobody left for it to fight.
func can_shift(battler: Battler) -> bool:
	if battler == null or battlers_per_side < 3 or battler.is_fainted():
		return false
	@warning_ignore("integer_division")
	var slot: int = battler.index / 2
	@warning_ignore("integer_division")
	if slot == battlers_per_side / 2:
		return false
	var centre: Battler = get_battler(centre_position(battler.side_index()))
	if centre == null or centre.is_fainted():
		return false
	if battler.is_trapped() or centre.is_trapped():
		return false
	var opposite: Battler = get_battler(facing_position(battler.index))
	return opposite == null or opposite.is_fainted()

## The centre position of [param side_index], which is where a Shift lands.
func centre_position(side_index: int) -> int:
	@warning_ignore("integer_division")
	return ((battlers_per_side / 2) * 2) + side_index

## Trades [param battler] with the ally in the centre of its side.
func _shift_to_centre(battler: Battler) -> void:
	var centre: int = centre_position(battler.side_index())
	var partner: Battler = get_battler(centre)
	if partner == null or not swap_battlers(battler.index, centre):
		return
	await presenter.show_message(Loc.line("{pokemon} and {partner} shifted places!", {"pokemon": battler.display_name(), "partner": partner.display_name()}))
	presenter.refresh_all()

## Records that a party member has eaten a Berry, which is what Belch needs.
func record_berry_eaten(battler: Battler) -> void:
	_belched_slots["%d:%d" % [battler.side_index(), battler.party_index]] = true

## `true` when this battler has eaten a Berry at some point this battle.
func has_eaten_berry(battler: Battler) -> bool:
	return _belched_slots.has("%d:%d" % [battler.side_index(), battler.party_index])

func _update_consecutive_uses(user: Battler, move_id: StringName) -> void:
	if user.last_move_used == move_id:
		user.consecutive_move_uses += 1
	else:
		user.consecutive_move_uses = 0

# === Switching ===

func _switch_battler(battler: Battler, party_slot: int) -> void:
	var party: PokemonParty = parties[battler.side_index()]
	var incoming: Pokemon = party.get_member(party_slot)
	if incoming == null or not incoming.is_able():
		return
	# Whoever is already on the field cannot be sent out a second time.
	for other: Battler in battlers:
		if other != null and other != battler and other.side_index() == battler.side_index():
			if other.party_index == party_slot:
				return
	await presenter.show_message(Loc.line("{pokemon}, come back!", {"pokemon": battler.display_name()}))
	for message: String in AbilityReactions.on_switch_out(self, battler):
		await presenter.show_message(message)
	FormHandlers.on_leaving_battle(battler.pokemon, true, false)
	_end_gimmick_on_leaving_field(battler)
	battler.reset_on_switch_out()
	var position: int = battler.index
	_place_battler(position, incoming, party_slot, true)
	await presenter.show_message(Loc.line("Go! {pokemon}!", {"pokemon": battlers[position].display_name()}))
	await presenter.play_send_out(battlers[position])
	await _apply_entry_hazards(battlers[position])
	await _run_switch_in_effects()

## Drags [param target] off the field against its will, as Roar and Whirlwind do. Returns without doing anything when the target refuses or there is nobody behind it; against a lone wild Pokemon it ends the battle instead.
func _force_out(target: Battler) -> void:
	if target == null or target.is_fainted() or not target.can_be_forced_out():
		return
	if is_wild_battle() and not target.is_player_side():
		if max_battlers_per_side() > 1:
			return
		await presenter.show_message(Loc.line("{pokemon} was blown away!", {"pokemon": target.battle_name()}))
		outcome = BattlePresenter.Outcome.PLAYER_FLED
		return
	var party: PokemonParty = parties[target.side_index()]
	var already_out: Array[int] = active_party_slots(target.side_index())
	var choices: Array[int] = []
	for slot: int in range(party.size()):
		if already_out.has(slot):
			continue
		var candidate: Pokemon = party.get_member(slot)
		if candidate != null and candidate.is_able():
			choices.append(slot)
	if choices.is_empty():
		return
	await presenter.show_message(Loc.line("{pokemon} was dragged out!", {"pokemon": target.battle_name()}))
	await _switch_battler(target, choices[RNG.below(choices.size())])

## Takes a Pokemon off the field because its own Ability said so, which is Emergency Exit and Wimp Out. Returns `true` when there was somebody to send out in its place; the switch itself is queued so it happens once the move that caused it has finished.
func request_ability_switch(battler: Battler) -> bool:
	if battler == null or battler.is_fainted() or battler.switching_out:
		return false
	var already_out: Array[int] = active_party_slots(battler.side_index())
	var party: PokemonParty = parties[battler.side_index()]
	for slot: int in range(party.size()):
		if already_out.has(slot):
			continue
		var candidate: Pokemon = party.get_member(slot)
		if candidate != null and candidate.is_able():
			_pending_ability_switches.append(battler.index)
			return true
	return false

## Carries out the switches that Emergency Exit and Wimp Out asked for. Run between actions, so the Pokemon leaves once the move that scared it off is done rather than in the middle of it.
func _run_pending_ability_switches() -> void:
	if _pending_ability_switches.is_empty():
		return
	var queued: Array[int] = _pending_ability_switches.duplicate()
	_pending_ability_switches.clear()
	for index: int in queued:
		var battler: Battler = get_battler(index)
		if battler == null or battler.is_fainted():
			continue
		await _switch_after_move(battler)

## Makes every Dancer on the field copy the dance [param user] just performed.
func _run_dancers(user: Battler, record: MoveData) -> void:
	for dancer: Battler in AbilityReactions.dancers_for(self, user, record):
		var known: PokemonMove = dancer.get_move(record.id)
		var copy: PokemonMove = known if known != null else PokemonMove.create(record.id)
		await presenter.show_message(Loc.line("{pokemon} kept the dance going!", {"pokemon": dancer.battle_name()}))
		var action: BattleAction = BattleAction.use_move(dancer.index, copy)
		await _execute_move(dancer, action, true)

## `true` while a Pokemon with Neutralizing Gas is standing on the field, which is what switches every other Ability off. Reads the written-down Ability rather than the effective one, because asking for the effective one is what this answers.
func neutralizing_gas_active() -> bool:
	for battler: Battler in battlers:
		if battler == null or battler.is_fainted():
			continue
		if battler.raw_ability() == &"NEUTRALIZINGGAS":
			return true
	return false

## The battler that last dealt damage to [param victim], or `null`.
func _last_attacker_of(victim: Battler) -> Battler:
	if victim.last_attacker_index < 0:
		return null
	return get_battler(victim.last_attacker_index)

## The move that last dealt damage to [param victim], or `null`.
func _last_move_against(victim: Battler) -> MoveData:
	if victim.last_move_taken.is_empty():
		return null
	return Database.move(victim.last_move_taken)

## Puts a Poke Ball that bounced off down on the field, where Ball Fetch can go and get it. Only the first one is kept, as Essentials does.
func drop_ball(ball_id: StringName) -> void:
	if dropped_ball.is_empty():
		dropped_ball = ball_id

## Hands the dropped ball over and clears it.
func take_dropped_ball() -> StringName:
	var ball: StringName = dropped_ball
	dropped_ball = &""
	return ball

func _switch_after_move(user: Battler) -> void:
	var party: PokemonParty = parties[user.side_index()]
	var already_out: Array[int] = active_party_slots(user.side_index())
	for slot: int in range(party.size()):
		if already_out.has(slot):
			continue
		var candidate: Pokemon = party.get_member(slot)
		if candidate != null and candidate.is_able():
			await _switch_battler(user, slot)
			return

## Runs the entry Abilities of everyone who has just arrived. Battlers that were already standing there are skipped: without the flag, every switch re-ran Intimidate, Trace and Drizzle for the whole field.
func _run_switch_in_effects() -> void:
	for battler: Battler in all_active_battlers():
		if battler.switch_in_resolved:
			continue
		battler.switch_in_resolved = true
		for message: String in AbilityEffects.on_switch_in(self, battler):
			await presenter.show_message(message)

func _apply_entry_hazards(battler: Battler) -> void:
	var side: BattleSide = sides[battler.side_index()]
	if battler.has_ability(&"MAGICGUARD"):
		return
	if side.has_effect(BattleEffects.STEALTH_ROCK):
		var effectiveness: float = Database.type_effectiveness(&"ROCK", battler.types())
		var damage: int = int(float(battler.total_hp()) * effectiveness / 8.0)
		if damage > 0:
			battler.take_damage(damage)
			await presenter.show_message(Loc.line("Pointed stones dug into {pokemon}!", {"pokemon": battler.battle_name()}))
	if not battler.is_airborne():
		var spike_layers: int = int(side.get_effect(BattleEffects.SPIKES))
		if spike_layers > 0:
			var divisor: int = [0, 8, 6, 4][mini(spike_layers, 3)]
			@warning_ignore("integer_division")
			battler.take_damage(battler.total_hp() / divisor)
			await presenter.show_message(Loc.line("{pokemon} was hurt by spikes!", {"pokemon": battler.battle_name()}))
		var toxic_layers: int = int(side.get_effect(BattleEffects.TOXIC_SPIKES))
		if toxic_layers > 0:
			if battler.has_type(&"POISON"):
				side.clear_effect(BattleEffects.TOXIC_SPIKES)
				await presenter.show_message(Loc.line("{pokemon} absorbed the poison spikes!", {"pokemon": battler.battle_name()}))
			elif battler.inflict_status(&"POISON", 1 if toxic_layers >= 2 else 0):
				await presenter.show_message(Loc.line("{pokemon} was poisoned!", {"pokemon": battler.battle_name()}))
		if side.has_effect(BattleEffects.STICKY_WEB):
			change_stat_stage(battler, &"SPEED", -1, null)
			await presenter.show_message(Loc.line("{pokemon} was caught in a sticky web!", {"pokemon": battler.battle_name()}))
	presenter.refresh_battler(battler)

# === Items ===

func _use_item(battler: Battler, action: BattleAction) -> void:
	var record: ItemData = Database.item(action.item)
	if record == null:
		return
	if record.is_poke_ball():
		if not can_throw_poke_ball(action.item):
			await presenter.show_message("It's impossible to aim with two Pokemon in the way!")
			return
		await _throw_poke_ball(battler, action.item)
		return
	var target_pokemon: Pokemon = parties[battler.side_index()].get_member(action.item_target)
	if target_pokemon == null:
		target_pokemon = battler.pokemon
	await presenter.show_message(Loc.line("{trainer} used the {name}!", {"trainer": _side_name(battler), "name": record.get_translated_name()}))

	# An X item, a Dire Hit or a flute acts on the Pokemon as it stands on the field; a Guard Spec. or a Poke Doll acts on the battle itself. Neither can be expressed as a change to the [Pokemon] record, so both are answered before the record-level items below.
	match record.battle_use:
		ItemData.BattleUse.ON_BATTLER, ItemData.BattleUse.DIRECT:
			await _use_battle_item(battler, record)
			return

	# Confusion is a battle effect rather than a status, so an item that clears it has to be answered here, where the target's [Battler] is in reach.
	var target_battler: Battler = _battler_holding(target_pokemon)
	var cured_confusion: bool = (
		ItemUsage.CONFUSION_CURE_ITEMS.has(record.id)
		and target_battler != null
		and target_battler.has_effect(BattleEffects.CONFUSION)
	)
	if cured_confusion:
		target_battler.clear_effect(BattleEffects.CONFUSION)
	if ItemUsage.apply_in_battle(record, target_pokemon, action.item_move_index) or cured_confusion:
		if battler.is_player_side() and changes_the_save():
			GameState.bag.remove_item(action.item, 1)
		presenter.refresh_all()
	else:
		await presenter.show_message("But it had no effect!")

## Uses an item that acts on the battler or on the battle rather than on a Pokemon record — the X items, Dire Hit, Max Mushrooms, the flutes, Guard Spec. and the escape items. Spends it only when it did something.
func _use_battle_item(battler: Battler, record: ItemData) -> void:
	var messages: Array[String] = []
	if record.battle_use == ItemData.BattleUse.ON_BATTLER:
		messages = ItemEffects.use_on_battler(self, battler, record.id)
	else:
		messages = ItemEffects.use_in_battle(self, battler, record.id)
	if messages.is_empty():
		await presenter.show_message("But it had no effect!")
		return
	for message: String in messages:
		await presenter.show_message(message)
	if battler.is_player_side() and changes_the_save():
		GameState.bag.remove_item(record.id, 1)
	presenter.refresh_all()

## The active battler [param pkmn] is out as, or `null` when it is sitting in the party. An item used on a benched Pokemon has no battler to affect.
func _battler_holding(pkmn: Pokemon) -> Battler:
	for candidate: Battler in all_active_battlers():
		if candidate.pokemon == pkmn:
			return candidate
	return null

func _throw_poke_ball(battler: Battler, ball_id: StringName) -> void:
	var snagging: bool = kind == Kind.TRAINER and can_snag(ball_id)
	var target: Battler = _ball_target(battler, snagging)
	if target == null:
		return
	var record: ItemData = Database.item(ball_id)
	await presenter.show_message(Loc.line("{trainer} threw a {name}!", {"trainer": _side_name(battler), "name": record.get_translated_name()}))
	# The Safari Zone and the Bug Contest lend their own balls, so those come off the session's count rather than out of the bag.
	if safari != null:
		safari.use_ball()
	elif contest != null:
		contest.use_ball()
	elif changes_the_save():
		GameState.bag.remove_item(ball_id, 1)
	var shakes: int = CaptureCalculator.roll_shakes(self, target, ball_id)
	var caught: bool = shakes >= 4
	await presenter.play_capture(target, ball_id, shakes, caught)
	if not caught:
		if changes_the_save() and GameState.stats != null:
			GameState.stats.failed_poke_ball_count += 1
		drop_ball(ball_id)
		var messages: Array[String] = [
			"Oh no! The Pokemon broke free!",
			"Aww! It appeared to be caught!",
			"Aargh! Almost had it!",
			"Shoot! It was so close, too!",
		]
		await presenter.show_message(messages[clampi(shakes, 0, 3)])
		return
	# The jingle goes with the "Gotcha!" and silences the battle theme under it, which is what a ME is for. A replay leaves the music alone.
	if not capture_me.is_empty() and not is_replay():
		AudioManager.play_me(capture_me)
	await presenter.show_message(Loc.line("Gotcha! {pokemon} was caught!", {"pokemon": target.display_name()}))
	target.pokemon.poke_ball = ball_id
	if snagging:
		await _snag(target)
		return
	if await _keep_caught_pokemon(target):
		return
	if not changes_the_save():
		# Watching a capture back must not hand the Pokemon over a second time.
		outcome = BattlePresenter.Outcome.POKEMON_CAUGHT
		return
	# A caught Pokemon goes through the same receiving flow as one handed over by an event, so it is named and boxed the same way.
	var receipt: PokemonReceipt = PokemonReceipt.new()
	receipt.narrate = func(text: String) -> void:
		await presenter.show_message(text)
	receipt.ask = func(options: Array) -> int:
		return await ask(options)
	await receipt.give(target.pokemon)
	outcome = BattlePresenter.Outcome.POKEMON_CAUGHT

## Which Pokemon the ball is aimed at.
##
## An ordinary throw takes whoever is standing opposite, because it is only allowed when one Pokemon is. A snag picks out the Shadow Pokemon: Essentials lets a Snag Ball be thrown in a double battle for exactly this reason, and throwing it at the trainer's ordinary Pokemon would only be blocked.
func _ball_target(thrower: Battler, snagging: bool) -> Battler:
	var first: Battler = null
	for candidate: Battler in opposing_battlers(thrower):
		if first == null:
			first = candidate
		if snagging and ShadowPokemon.is_shadow(candidate.pokemon):
			return candidate
	return first

## Takes a snagged Pokemon off the trainer it belonged to and gives it to the player, leaving the battle to carry on around the hole it left.
##
## Essentials snags by removing the Pokemon from the opposing party and setting its owner, which is the difference between a snag and a capture: a capture ends the battle, and a snag is one Pokemon out of a team the player still has to beat. The trainer sends out their next one through the ordinary replacement path, so this only has to make the hole.
func _snag(target: Battler) -> void:
	var opposing: PokemonParty = parties[1]
	var snagged: Pokemon = target.pokemon
	if GameState.player != null:
		snagged.owner = GameState.player.owner_record()
	ShadowPokemon.update_shadow_moves(snagged)
	snagged.record_first_moves()
	var vacated: int = target.party_index
	opposing.remove_at(vacated)
	_close_party_gap(1, vacated)
	FormHandlers.on_leaving_battle(snagged, true, true)
	if not changes_the_save():
		# A replay must not hand the Pokemon over a second time.
		_check_for_victory()
		return
	_caught_by_snagging.append(snagged)
	# The battler leaves the field the way a fainted one does, so the trainer sends out their next Pokemon, but without the faint message: it did not faint, it left in a ball.
	_check_for_victory()
	if outcome == BattlePresenter.Outcome.UNDECIDED:
		await _replace_battler(target.index)
	presenter.refresh_all()

## Renumbers everything that remembers a party slot on [param side] after the Pokemon in [param vacated] has been taken out of the party.
##
## Essentials blanks the slot instead and leaves the numbering alone, which this port's [PokemonParty] has no room for — a party here is a list of Pokemon and not a list of six places. Closing the gap is the same answer, as long as everything holding a slot number is told: a battler still on the field, and the seen-slots list the party bar draws from.
func _close_party_gap(side: int, vacated: int) -> void:
	for battler: Battler in battlers:
		if battler == null or battler.side_index() != side:
			continue
		if battler.party_index > vacated:
			battler.party_index -= 1
	var seen: Array[int] = sides[side].seen_party_slots
	for index: int in range(seen.size() - 1, -1, -1):
		if seen[index] == vacated:
			seen.remove_at(index)
		elif seen[index] > vacated:
			seen[index] -= 1

## Hands over everything snagged this battle. Held until the battle is over for the same reason a Safari trip holds what it catches: the receiving flow asks questions, and the middle of a round is no place to ask them.
func _hand_over_snagged() -> void:
	if _caught_by_snagging.is_empty():
		return
	var snagged: Array[Pokemon] = _caught_by_snagging.duplicate()
	_caught_by_snagging.clear()
	for pkmn: Pokemon in snagged:
		var receipt: PokemonReceipt = PokemonReceipt.new()
		receipt.narrate = func(text: String) -> void:
			await presenter.show_message(text)
		receipt.ask = func(options: Array) -> int:
			return await ask(options)
		await receipt.give(pkmn)

## Deals with a Pokemon caught in one of the two special battles, where it does not simply join the party. Returns `true` when it was dealt with, so the usual receiving flow is skipped.
func _keep_caught_pokemon(target: Battler) -> bool:
	if safari != null:
		safari.record_catch(target.pokemon)
		outcome = BattlePresenter.Outcome.POKEMON_CAUGHT
		return true
	if contest == null:
		return false
	if contest.caught == null:
		contest.keep(target.pokemon)
		await presenter.show_message(Loc.line("{pokemon} is your entry!", {"pokemon": target.display_name()}))
		outcome = BattlePresenter.Outcome.POKEMON_CAUGHT
		return true
	# Only one Pokemon may be entered, so catching a second is a choice between them, and the score is what makes the choice worth thinking about.
	var held: Pokemon = contest.caught
	var answer: int = await ask([
		Loc.line("Keep {pokemon} ({score})", {
			"pokemon": target.display_name(),
			"score": BugContestSession.score_for(target.pokemon),
		}),
		Loc.line("Keep {pokemon} ({score})", {
			"pokemon": held.display_name(),
			"score": BugContestSession.score_for(held),
		}),
	], "You can only enter one. Which will it be?")
	if answer == 0:
		contest.keep(target.pokemon)
		await presenter.show_message(Loc.line("{pokemon} is your entry!", {"pokemon": target.display_name()}))
	else:
		await presenter.show_message(Loc.line("{pokemon} stays your entry.", {"pokemon": held.display_name()}))
	outcome = BattlePresenter.Outcome.POKEMON_CAUGHT
	return true

# === Fleeing ===

func _attempt_run(battler: Battler) -> void:
	if not can_run:
		await presenter.show_message("No! There's no running from a Trainer battle!")
		return
	_run_attempts += 1
	if battler.is_trapped():
		await presenter.show_message(Loc.line("{pokemon} can't escape!", {"pokemon": battler.battle_name()}))
		return
	if battler.has_ability(&"RUNAWAY") or battler.has_item(&"SMOKEBALL"):
		await presenter.show_message("Got away safely!")
		outcome = BattlePresenter.Outcome.PLAYER_FLED
		return
	var fastest_foe: int = 1
	for foe: Battler in opposing_battlers(battler):
		fastest_foe = maxi(fastest_foe, foe.effective_speed())
	if battler.effective_speed() >= fastest_foe:
		await presenter.show_message("Got away safely!")
		outcome = BattlePresenter.Outcome.PLAYER_FLED
		return
	@warning_ignore("integer_division")
	var odds: int = ((battler.effective_speed() * 128) / fastest_foe) + (30 * _run_attempts)
	if RNG.below(256) < odds:
		await presenter.show_message("Got away safely!")
		outcome = BattlePresenter.Outcome.PLAYER_FLED
	else:
		await presenter.show_message("Can't escape!")

# === End of Round ===

func _run_end_of_round() -> void:
	if is_safari_battle():
		for battler: Battler in all_active_battlers():
			battler.tick_effects()
		await _safari_flee_check()
		return
	await _resolve_delayed_attacks()
	field.tick()
	field.clear_effect(BattleEffects.FUSION_BOLT)
	field.clear_effect(BattleEffects.FUSION_FLARE)
	await _run_sea_of_fire()
	for side: BattleSide in sides:
		side.tick_effects()

	for battler: Battler in _speed_ordered_battlers():
		if battler.is_fainted():
			continue
		await _end_of_round_for(battler)
	await _resolve_faints()

	for battler: Battler in all_active_battlers():
		battler.tick_effects()
		_clear_round_flags(battler)
	await _roamer_flee_check()

## Takes a roaming Pokemon away at the end of the round it was met in.
##
## It goes last, after the faints have been resolved, so a roamer knocked out in that one round is defeated rather than escaping from a battle it lost.
func _roamer_flee_check() -> void:
	if not wild_pokemon_flees or outcome != BattlePresenter.Outcome.UNDECIDED:
		return
	var target: Battler = get_battler(1)
	if target == null or target.is_fainted():
		return
	await presenter.show_message(Loc.line("{pokemon} fled!", {"pokemon": target.display_name()}))
	outcome = BattlePresenter.Outcome.PLAYER_FLED

## Clears the volatile flags that only ever last one round.
func _clear_round_flags(battler: Battler) -> void:
	for effect: StringName in [BattleEffects.BEAK_BLAST, BattleEffects.SHELL_TRAP,
			BattleEffects.FOCUS_PUNCH, BattleEffects.ELECTRIFY, BattleEffects.HELPING_HAND,
			BattleEffects.POWDER, BattleEffects.SPOTLIGHT, BattleEffects.MOVE_NEXT,
			BattleEffects.QUASH, BattleEffects.FIRST_PLEDGE]:
		battler.clear_effect(effect)
	battler.switched_in_this_turn = false

## Fires the attacks that Future Sight and Doom Desire left waiting, which are held by the battle position so switching does not cancel them.
func _resolve_delayed_attacks() -> void:
	for position: int in range(battlers.size()):
		var slot: Dictionary = effects_at_position(position)
		var counter: int = int(slot.get(BattleEffects.FUTURE_SIGHT_COUNTER, 0))
		if counter <= 0:
			continue
		counter -= 1
		slot[BattleEffects.FUTURE_SIGHT_COUNTER] = counter
		if counter > 0:
			continue
		var move_id: StringName = StringName(slot.get(BattleEffects.FUTURE_SIGHT_MOVE, &""))
		var user_index: int = int(slot.get(BattleEffects.FUTURE_SIGHT_USER_INDEX, -1))
		var user_slot: int = int(slot.get(BattleEffects.FUTURE_SIGHT_USER_PARTY_INDEX, -1))
		slot.erase(BattleEffects.FUTURE_SIGHT_COUNTER)
		slot.erase(BattleEffects.FUTURE_SIGHT_MOVE)
		slot.erase(BattleEffects.FUTURE_SIGHT_USER_INDEX)
		slot.erase(BattleEffects.FUTURE_SIGHT_USER_PARTY_INDEX)
		var target: Battler = get_battler(position)
		if target == null or target.is_fainted() or move_id.is_empty():
			continue
		var attacker: Battler = _delayed_attack_user(user_index, user_slot)
		if attacker == null or attacker.index == position:
			continue
		var record: MoveData = Database.move(move_id)
		if record == null:
			continue
		await presenter.show_message(Loc.line("{target} took the {name} attack!", {"target": target.battle_name(), "name": record.get_translated_name()}))
		var remembered_failure: bool = attacker.last_move_failed
		future_sight_active = true
		var move: PokemonMove = PokemonMove.create(move_id)
		await _execute_move(attacker, BattleAction.use_move(attacker.index, move, [position]), true)
		future_sight_active = false
		attacker.last_move_failed = remembered_failure
		await _resolve_faints()
		if outcome != BattlePresenter.Outcome.UNDECIDED:
			return

## Finds the battler a delayed attack belongs to, standing one up from the party when it is no longer on the field.
func _delayed_attack_user(user_index: int, party_slot: int) -> Battler:
	if user_index < 0 or party_slot < 0:
		return null
	var side: int = user_index % 2
	for battler: Battler in all_active_battlers():
		if battler.side_index() == side and battler.party_index == party_slot:
			return battler
	var pkmn: Pokemon = parties[side].get_member(party_slot)
	if pkmn == null or not pkmn.is_able():
		return null
	var stand_in: Battler = Battler.new(pkmn, user_index, self)
	stand_in.party_index = party_slot
	return stand_in

## The Fire Pledge and Grass Pledge combination burns everyone on one side.
func _run_sea_of_fire() -> void:
	for side_index: int in range(sides.size()):
		if not sides[side_index].has_effect(BattleEffects.SEA_OF_FIRE):
			continue
		for battler: Battler in _speed_ordered_battlers():
			if battler.side_index() != side_index or battler.is_fainted():
				continue
			if battler.has_type(&"FIRE") or battler.has_ability(&"MAGICGUARD"):
				continue
			@warning_ignore("integer_division")
			battler.take_damage(maxi(battler.total_hp() / 8, 1))
			await presenter.show_message(Loc.line("{pokemon} is hurt by the sea of fire!", {"pokemon": battler.battle_name()}))
			presenter.refresh_battler(battler)

func _end_of_round_for(battler: Battler) -> void:
	if not battler.gimmick.is_empty():
		var gimmick: BattleGimmick = BattleGimmicks.get_gimmick(battler.gimmick)
		if gimmick != null:
			gimmick.on_round_end(self, battler)
	var weather: StringName = field.effective_weather(self)
	match weather:
		&"Sandstorm":
			if not (battler.has_type(&"ROCK") or battler.has_type(&"GROUND") or battler.has_type(&"STEEL")):
				if not battler.has_ability(&"SANDVEIL") and not battler.has_ability(&"MAGICGUARD"):
					@warning_ignore("integer_division")
					battler.take_damage(maxi(battler.total_hp() / 16, 1))
					await presenter.show_message(Loc.line("{pokemon} is buffeted by the sandstorm!", {"pokemon": battler.battle_name()}))
		&"Hail":
			if not battler.has_type(&"ICE") and not battler.has_ability(&"MAGICGUARD"):
				@warning_ignore("integer_division")
				battler.take_damage(maxi(battler.total_hp() / 16, 1))
				await presenter.show_message(Loc.line("{pokemon} is buffeted by the hail!", {"pokemon": battler.battle_name()}))

	match battler.pokemon.status:
		&"POISON":
			var divisor: int = 8
			if battler.is_badly_poisoned():
				var counter: int = int(battler.get_effect(BattleEffects.TOXIC_COUNTER))
				battler.set_effect(BattleEffects.TOXIC_COUNTER, counter + 1)
				@warning_ignore("integer_division")
				battler.take_damage(maxi(battler.total_hp() * counter / 16, 1))
			elif not battler.has_ability(&"POISONHEAL"):
				@warning_ignore("integer_division")
				battler.take_damage(maxi(battler.total_hp() / divisor, 1))
			if not battler.has_ability(&"POISONHEAL"):
				await presenter.show_message(Loc.line("{pokemon} was hurt by poison!", {"pokemon": battler.battle_name()}))
		&"BURN":
			var divisor: int = 16 if GameSettings.data.mechanics_generation >= 7 else 8
			@warning_ignore("integer_division")
			battler.take_damage(maxi(battler.total_hp() / divisor, 1))
			await presenter.show_message(Loc.line("{pokemon} was hurt by its burn!", {"pokemon": battler.battle_name()}))

	if battler.has_effect(BattleEffects.LEECH_SEED):
		var drainer: Battler = get_battler(int(battler.get_effect(BattleEffects.LEECH_SEED)) - 1)
		if drainer != null and not drainer.is_fainted():
			@warning_ignore("integer_division")
			var drained: int = maxi(battler.total_hp() / 8, 1)
			battler.take_damage(drained)
			drainer.restore_hp(drained)
			await presenter.show_message(Loc.line("{pokemon}'s health was sapped by Leech Seed!", {"pokemon": battler.battle_name()}))

	if field.terrain == &"Grassy" and not battler.is_airborne():
		@warning_ignore("integer_division")
		battler.restore_hp(maxi(battler.total_hp() / 16, 1))

	for message: String in AbilityEffects.on_end_of_round(self, battler):
		await presenter.show_message(message)
	for message: String in ItemEffects.on_end_of_round(self, battler):
		await presenter.show_message(message)
	for message: String in AbilityReactions.on_item_consumed(self, battler):
		await presenter.show_message(message)

	if battler.has_effect(BattleEffects.PERISH_SONG):
		var count: int = int(battler.get_effect(BattleEffects.PERISH_SONG)) - 1
		battler.set_effect(BattleEffects.PERISH_SONG, count)
		await presenter.show_message(Loc.line("{pokemon}'s perish count fell to {count}!", {"pokemon": battler.battle_name(), "count": count}))
		if count <= 0:
			battler.take_damage(battler.hp())
	presenter.refresh_battler(battler)

func _speed_ordered_battlers() -> Array[Battler]:
	var ordered: Array[Battler] = all_active_battlers()
	ordered.sort_custom(func(a: Battler, b: Battler) -> bool:
		return a.effective_speed() > b.effective_speed()
	)
	return ordered

# === Fainting ===

func _resolve_faints() -> void:
	for battler: Battler in battlers:
		if battler == null or not battler.is_fainted():
			continue
		if _pending_replacements.has(battler.index):
			continue
		_pending_replacements.append(battler.index)
		# The Illusion drops as the Pokemon goes down, so the faint message names what actually fainted.
		var revealed: Array[String] = []
		if AbilityForms.break_illusion(battler, revealed):
			for message: String in revealed:
				await presenter.show_message(message)
		await presenter.show_message(Loc.line("{pokemon} fainted!", {"pokemon": battler.battle_name()}))
		for message: String in AbilityReactions.on_faint(self, battler, _last_attacker_of(battler), _last_move_against(battler)):
			await presenter.show_message(message)
		presenter.play_faint(battler)
		battler_fainted.emit(battler)
		if not battler.is_player_side():
			await BattleExperience.award(self, battler)

	_check_for_victory()
	if outcome != BattlePresenter.Outcome.UNDECIDED:
		return

	for position: int in _pending_replacements.duplicate():
		await _replace_battler(position)
	_pending_replacements.clear()

func _replace_battler(position: int) -> void:
	var side: int = position % 2
	var party: PokemonParty = parties[side]
	# The fainted battler is still standing in the position, so it has to come out of the list before working out who is left on the field. Anything it is under that would not survive the walk back goes first, while the battler holding the numbers to put back is still to hand.
	_end_gimmick_on_leaving_field(battlers[position])
	battlers[position] = null
	var slot: int = -1
	if recording != null and recording.replaying:
		slot = recording.take_replacement()
	elif side == 0 and presenter != null:
		slot = await presenter.choose_replacement(position)
	if slot < 0 or active_party_slots(side).has(slot):
		slot = BattleAI.choose_replacement(self, side)
	if slot < 0:
		return
	if recording != null and not recording.replaying:
		recording.record_replacement(slot)
	var incoming: Pokemon = party.get_member(slot)
	if incoming == null:
		return
	_place_battler(position, incoming, slot, true)
	await presenter.show_message(Loc.line("Go! {pokemon}!", {"pokemon": battlers[position].display_name()}))
	await presenter.play_send_out(battlers[position])
	await _apply_entry_hazards(battlers[position])
	await _run_switch_in_effects()

func _check_for_victory() -> void:
	if outcome != BattlePresenter.Outcome.UNDECIDED:
		return
	var player_can_fight: bool = parties[0].able_count() > 0
	var foe_can_fight: bool = parties[1].able_count() > 0
	if not player_can_fight and not foe_can_fight:
		outcome = BattlePresenter.Outcome.DRAW
	elif not player_can_fight:
		outcome = BattlePresenter.Outcome.PLAYER_LOST
	elif not foe_can_fight:
		outcome = BattlePresenter.Outcome.PLAYER_WON

# === Gimmicks ===

## Runs the gimmick [param action] asked for, then lets it rewrite the move. Mega Evolution changes the Pokemon and leaves the move alone; a Z-Crystal and Dynamax leave the Pokemon alone and change the move.
func _apply_gimmick(user: Battler, action: BattleAction) -> void:
	var gimmick: BattleGimmick = _gimmick_for(user, action)
	if gimmick == null:
		return
	if not action.gimmick.is_empty():
		await gimmick.activate(self, user)
		_remember_gimmick(user)
	var replacement: PokemonMove = gimmick.transform_move(self, user, action.move)
	if replacement != null:
		action.move = replacement

## The gimmick that should act on [param user] this round: the one the action asked for, or the one already in force when a Dynamaxed Pokemon attacks again on a later round.
func _gimmick_for(user: Battler, action: BattleAction) -> BattleGimmick:
	if not action.gimmick.is_empty():
		return BattleGimmicks.get_gimmick(action.gimmick)
	if user.gimmick.is_empty():
		return null
	return BattleGimmicks.get_gimmick(user.gimmick)

## Records that a party slot is under a gimmick, so switching out and back does not undo a Mega Evolution or a Tera type.
func _remember_gimmick(battler: Battler) -> void:
	if battler.gimmick.is_empty():
		return
	# Only the ones that outlast leaving the field are worth remembering; Dynamax is undone on the way out, so there is nothing to put back.
	var gimmick: BattleGimmick = BattleGimmicks.get_gimmick(battler.gimmick)
	if gimmick != null and not gimmick.survives_switch:
		return
	gimmick_states["%d:%d" % [battler.side_index(), battler.party_index]] = {
		"gimmick": battler.gimmick,
		"tera_type": battler.tera_type,
		"form": battler.pre_gimmick_form,
	}

## Puts a returning Pokemon back under whatever gimmick it was already using.
func _restore_gimmick(battler: Battler) -> void:
	var key: String = "%d:%d" % [battler.side_index(), battler.party_index]
	if not gimmick_states.has(key):
		return
	var saved: Dictionary = gimmick_states[key]
	battler.gimmick = saved["gimmick"]
	battler.pre_gimmick_form = int(saved["form"])
	battler.tera_type = saved["tera_type"]
	if not battler.tera_type.is_empty():
		battler.type_override = [battler.tera_type] as Array[StringName]

## Undoes whatever [param battler] is under that does not outlast leaving the field, which is Dynamax and only Dynamax. Without this the Pokemon walks off with its inflated maximum HP: the battler object holding the real total is thrown away with the position, and the end-of-battle sweep only sees whoever is standing on the field by then.
func _end_gimmick_on_leaving_field(battler: Battler) -> void:
	if battler == null or battler.gimmick.is_empty():
		return
	var gimmick: BattleGimmick = BattleGimmicks.get_gimmick(battler.gimmick)
	if gimmick == null or gimmick.survives_switch:
		return
	gimmick.revert(self, battler)
	battler.gimmick = &""
	battler.pre_gimmick_total_hp = 0

## Undoes every gimmick still in force, which is the last thing a battle does before handing the party back.
func _revert_gimmicks() -> void:
	for battler: Battler in battlers:
		if battler == null or battler.gimmick.is_empty():
			continue
		var gimmick: BattleGimmick = BattleGimmicks.get_gimmick(battler.gimmick)
		if gimmick != null:
			gimmick.revert(self, battler)
		battler.gimmick = &""
	# A Pokemon that Mega Evolved and was then switched out is not standing in any position, so its form is put back from what was recorded.
	for key: Variant in gimmick_states:
		var saved: Dictionary = gimmick_states[key]
		if int(saved["form"]) < 0:
			continue
		var parts: PackedStringArray = String(key).split(":")
		var pkmn: Pokemon = parties[int(parts[0])].get_member(int(parts[1]))
		if pkmn != null and pkmn.form != int(saved["form"]):
			pkmn.form = int(saved["form"])
			pkmn.calculate_stats()
	gimmick_states.clear()

# === Safari Zone ===

## Sets this battle up as a Safari Zone encounter with [param wild_pokemon]. Nothing on the opposing side attacks; the player throws balls, bait and rocks, and the Pokemon decides each round whether to stay.
func setup_safari(player_party: PokemonParty, wild_pokemon: Array[Pokemon], session: SafariSession) -> void:
	setup_wild(player_party, wild_pokemon, 1)
	kind = Kind.SAFARI
	safari = session
	can_run = true
	can_catch = true

## Sets this battle up as a Bug-Catching Contest encounter. The player's one Pokemon fights as usual; only the ball is different, and what happens to what it catches.
func setup_bug_contest(player_party: PokemonParty, wild_pokemon: Array[Pokemon], session: BugContestSession) -> void:
	setup_wild(player_party, wild_pokemon, 1)
	kind = Kind.BUG_CONTEST
	contest = session
	can_run = true
	can_catch = true

## `true` in a Safari battle, where the player has no Pokemon out and the command menu is Ball, Bait, Rock and Run.
func is_safari_battle() -> bool:
	return kind == Kind.SAFARI

func is_bug_contest_battle() -> bool:
	return kind == Kind.BUG_CONTEST

## The ball a battle of this kind throws, which the two special kinds supply themselves rather than taking from the bag.
func supplied_ball() -> StringName:
	match kind:
		Kind.SAFARI:
			return SafariSession.BALL
		Kind.BUG_CONTEST:
			return BugContestSession.BALL
	return &""

## Throws bait: the Pokemon settles down to eat, which makes it much less likely to run off and, because it stops paying attention to the ball, harder to catch.
func _throw_bait(target: Battler) -> void:
	if target == null:
		return
	await presenter.show_message(Loc.line("{player} threw some bait!", {"player": _player_name()}))
	await presenter.play_effect_animation(target, &"SafariBait")
	target.safari_catch_factor = maxf(target.safari_catch_factor * 0.5, 0.1)
	target.safari_flee_factor = maxf(target.safari_flee_factor * 0.5, 0.05)
	target.set_effect(BattleEffects.SAFARI_EATING, RNG.range_int(1, 5))
	await presenter.show_message(Loc.line("{pokemon} is eating!", {"pokemon": target.display_name()}))

## Throws a rock: the Pokemon is angry, which makes it easier to catch while it is distracted and much more likely to bolt.
func _throw_rock(target: Battler) -> void:
	if target == null:
		return
	await presenter.show_message(Loc.line("{player} threw a rock!", {"player": _player_name()}))
	await presenter.play_effect_animation(target, &"SafariRock")
	target.safari_catch_factor = minf(target.safari_catch_factor * 2.0, 4.0)
	target.safari_flee_factor = minf(target.safari_flee_factor * 2.0, 4.0)
	target.set_effect(BattleEffects.SAFARI_ANGRY, RNG.range_int(1, 5))
	await presenter.play_effect_animation(target, &"SafariAnger")
	await presenter.show_message(Loc.line("{pokemon} is angry!", {"pokemon": target.display_name()}))

## Decides whether the Safari Pokemon has had enough and leaves. A Pokemon that is eating stays put; an angry one is far more likely to go.
func _safari_flee_check() -> void:
	var target: Battler = get_battler(1)
	if target == null or target.is_fainted():
		return
	if target.has_effect(BattleEffects.SAFARI_EATING):
		return
	var record: SpeciesData = target.species_data()
	# A Pokemon that is easy to catch is also one that does not much mind being looked at, so the base chance to leave comes from its catch rate.
	var base: float = 1.0 - (float(record.catch_rate if record != null else 128) / 255.0)
	var chance: float = clampf(base * 0.5 * target.safari_flee_factor, 0.0, 0.9)
	if RNG.generator.randf() >= chance:
		return
	await presenter.show_message(Loc.line("{pokemon} fled!", {"pokemon": target.display_name()}))
	outcome = BattlePresenter.Outcome.PLAYER_FLED

func _player_name() -> String:
	return GameState.player.name if GameState != null and GameState.player != null else "You"

# === Helpers ===

## Changes a stat stage with the messages and ability reactions that go with it. Returns `true` when the stage actually moved.
func change_stat_stage(target: Battler, stat: StringName, change: int, source: Battler) -> bool:
	# Contrary reads every change the other way round, and it does so before any of the guards below, so a Contrary Pokemon welcomes what would have been a drop rather than refusing it.
	if target.has_ability(&"CONTRARY") and (source == null or not AbilityEffects.ignores_abilities(source)):
		change = -change
	var hostile: bool = source != null and source.side_index() != target.side_index()
	if change < 0 and hostile:
		if sides[target.side_index()].has_effect(BattleEffects.MIST):
			return false
		if target.has_ability(&"CLEARBODY") or target.has_ability(&"WHITESMOKE") or target.has_ability(&"FULLMETALBODY"):
			return false
		if stat == &"ATTACK" and target.has_ability(&"HYPERCUTTER"):
			return false
		if stat == &"DEFENSE" and target.has_ability(&"BIGPECKS"):
			return false
		if stat == &"ACCURACY" and target.has_ability(&"KEENEYE"):
			return false
		# Mirror Armor does not refuse the drop, it hands it straight back.
		if target.has_ability(&"MIRRORARMOR"):
			change_stat_stage(source, stat, change, target)
			return false
	var applied: int = target.change_stat_stage(stat, change)
	if applied == 0:
		return false
	play_common_animation(&"StatUp" if applied > 0 else &"StatDown", target)
	if applied < 0 and source != null and source.side_index() != target.side_index():
		if target.has_ability(&"DEFIANT"):
			target.change_stat_stage(&"ATTACK", 2)
		elif target.has_ability(&"COMPETITIVE"):
			target.change_stat_stage(&"SPECIAL_ATTACK", 2)
	return true

## Puts a question to whoever is in charge, and remembers the answer. A battle being recorded writes it down; one being replayed gives back the answer that was given the first time, rather than asking again.
func ask(options: Array, prompt: String = "") -> int:
	if recording != null and recording.replaying:
		return recording.take_prompt()
	var answer: int = -1
	if presenter != null:
		answer = await presenter.choose_option(prompt, options)
	if recording != null:
		recording.record_prompt(answer)
	return answer

func announce(text: String) -> void:
	if presenter != null:
		presenter.show_message_brief(text)

func announce_status(target: Battler, status_id: StringName) -> void:
	var verbs: Dictionary = {
		&"POISON": "was poisoned", &"BURN": "was burned", &"PARALYSIS": "is paralyzed",
		&"SLEEP": "fell asleep", &"FROZEN": "was frozen solid",
	}
	play_common_animation(status_id, target)
	announce("%s %s!" % [target.battle_name(), verbs.get(status_id, "was affected")])

func announce_weather(weather: StringName) -> void:
	var lines: Dictionary = {
		&"Rain": "It started to rain!", &"Sun": "The sunlight turned harsh!",
		&"Sandstorm": "A sandstorm kicked up!", &"Hail": "It started to hail!",
	}
	play_common_animation(weather, null)
	announce(lines.get(weather, "The weather changed!"))

func announce_terrain(terrain: StringName) -> void:
	announce(Loc.line("{terrain} Terrain covered the battlefield!", {"terrain": terrain}))

## Asks the presenter for one of the shared animations — a stat arrow, a status flash, the weather starting. Named rather than numbered so a battle can ask for one without knowing whether the screen has it.
func play_common_animation(animation: StringName, target: Battler) -> void:
	if presenter != null:
		presenter.play_effect_animation(target, animation)

func _side_name(battler: Battler) -> String:
	if battler.is_player_side():
		return GameState.player.name if GameState.player != null else "You"
	return "The opposing trainer"

## The side [param battler] fights for, named the way a message about the whole side names it. Essentials' `pbTeam`.
func team_name(battler: Battler) -> String:
	return "Your team" if battler.is_player_side() else "The opposing team"

func _trainer_type_name(trainer: TrainerData) -> String:
	var record: TrainerTypeData = Database.trainer_type(trainer.trainer_type)
	return record.display_name if record != null else String(trainer.trainer_type)

## What each beaten trainer says, before the money is handed over — Essentials' `@endSpeeches`, which every trainer record carries as `lose_text` and which nothing in this port had ever read.
##
## A trainer with nothing to say is passed over rather than given a blank window, and each one is announced as beaten first, so a double battle does not run two unattributed speeches together.
func _speak_defeat_lines() -> void:
	if opponent_trainers.size() > 1:
		var names: Array[String] = []
		for trainer: TrainerData in opponent_trainers:
			names.append("%s %s" % [_trainer_type_name(trainer), trainer.display_name])
		await presenter.show_message(
			Loc.line("{trainer} was defeated!", {"trainer": _join_names(names)}))
	else:
		for trainer: TrainerData in opponent_trainers:
			await presenter.show_message(Loc.line("{trainer} was defeated!", {
				"trainer": "%s %s" % [_trainer_type_name(trainer), trainer.display_name],
			}))
	for trainer: TrainerData in opponent_trainers:
		var speech: String = trainer.get_translated_lose_text()
		if speech.strip_edges().is_empty():
			continue
		await presenter.show_message(speech)

func _calculate_winnings() -> int:
	var total: int = 0
	for trainer: TrainerData in opponent_trainers:
		var record: TrainerTypeData = Database.trainer_type(trainer.trainer_type)
		var base_money: int = record.base_money if record != null else 30
		var highest_level: int = 1
		for member: TrainerPokemon in trainer.pokemon:
			highest_level = maxi(highest_level, member.level)
		total += base_money * highest_level
	return total

func _calculate_money_loss() -> int:
	if GameState.player == null or not GameSettings.data.can_lose_money_on_defeat:
		return 0
	var badge_factor: int = maxi(GameState.player.badge_count(), 1)
	var level: int = parties[0].highest_level()
	return mini(GameState.player.money, badge_factor * level * 4)
