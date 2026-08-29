class_name MoveEffectsMultiTurn

## Moves that span more than one turn, or that set themselves up before the round starts.

## Pledge combinations, keyed by function code.
const PLEDGE_COMBOS: Dictionary = {
	&"WaterPledge": {
		&"GrassPledge": {"effect": BattleEffects.SWAMP, "type": &"GRASS"},
		&"FirePledge": {"effect": BattleEffects.RAINBOW, "type": &""},
	},
	&"FirePledge": {
		&"WaterPledge": {"effect": BattleEffects.RAINBOW, "type": &"WATER"},
		&"GrassPledge": {"effect": BattleEffects.SEA_OF_FIRE, "type": &""},
	},
	&"GrassPledge": {
		&"FirePledge": {"effect": BattleEffects.SEA_OF_FIRE, "type": &"FIRE"},
		&"WaterPledge": {"effect": BattleEffects.SWAMP, "type": &""},
	},
}

## How many rounds a Pledge combination's side effect lasts.
const PLEDGE_EFFECT_TURNS: int = 4

## Which side each combination lands on.
const PLEDGE_EFFECT_ON_FOES: Dictionary = {
	BattleEffects.SEA_OF_FIRE: true,
	BattleEffects.RAINBOW: false,
	BattleEffects.SWAMP: true,
}

## Lines announcing each Pledge combination.
const PLEDGE_MESSAGES: Dictionary = {
	BattleEffects.SEA_OF_FIRE: "A sea of fire enveloped the opposing team!",
	BattleEffects.RAINBOW: "A rainbow appeared in the sky!",
	BattleEffects.SWAMP: "A swamp enveloped the opposing team!",
}

static func register_all() -> void:
	MoveEffects.register(&"MultiTurnAttackBideThenReturnDoubleDamage", BideEffect.new())
	MoveEffects.register(&"MultiTurnAttackPowersUpEachTurn", RolloutEffect.new())
	MoveEffects.register(&"MultiTurnAttackConfuseUserAtEnd", ThrashEffect.new())
	MoveEffects.register(&"AttackTwoTurnsLater", DelayedAttackEffect.new())
	MoveEffects.register(&"FailsIfUserDamagedThisTurn", FocusPunchEffect.new())
	MoveEffects.register(&"UsedAfterUserTakesPhysicalDamage", ShellTrapEffect.new())
	MoveEffects.register(&"BurnAttackerBeforeUserActs", BeakBlastEffect.new())
	MoveEffects.register(&"UsedAfterAllyRoundWithDoublePower", RoundEffect.new())
	for pledge_code: StringName in PLEDGE_COMBOS:
		MoveEffects.register(pledge_code, PledgeEffect.new(pledge_code))

# === Effect Types ==

## Bide, which soaks up damage for two rounds and then hands back double.
class BideEffect extends MoveEffect:

	func use_message(_battle: Battle, user: Battler, move: MoveData) -> String:
		var stage: int = int(user.get_effect(BattleEffects.BIDE))
		if stage == 0:
			return "%s used %s!" % [user.battle_name(), move.display_name]
		if stage > 1:
			return Loc.line("{pokemon} is storing energy!", {"pokemon": user.battle_name()})
		return Loc.line("{pokemon} unleashed energy!", {"pokemon": user.battle_name()})

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		if int(user.get_effect(BattleEffects.BIDE)) != 1:
			return true
		if int(user.get_effect(BattleEffects.BIDE_DAMAGE)) > 0:
			return true
		_release(user)
		return false

	## Do not check this while the AI is choosing; it releases stored energy.

	func failure_is_known_when_choosing() -> bool:
		return false

## Two rounds of standing still for double whatever lands in between.

	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if int(user.get_effect(BattleEffects.BIDE)) > 0:
			# Already storing: the move is forced anyway, so there is nothing to
			# weigh.
			return base
		if user.hp_fraction() < 0.5:
			return AIScores.USELESS
		var incoming: float = 0.0
		for foe: Battler in battle.opposing_battlers(user):
			for move: PokemonMove in foe.moves():
				var record: MoveData = move.data() if move != null else null
				if record == null or not record.is_damaging():
					continue
				var effect: MoveEffect = MoveEffects.get_effect(record.function_code)
				incoming = maxf(incoming, float(
					AIMoveView.rough_damage(battle, foe, user, record, effect)))
		# Two rounds of it has to be survivable, or there is nothing to hand back.
		if incoming * 2.0 >= float(user.hp()):
			return AIScores.USELESS
		return base + int(30.0 * incoming / float(maxi(user.total_hp(), 1)))

	func is_damaging_this_use(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		return int(user.get_effect(BattleEffects.BIDE)) == 1

	func override_targets(battle: Battle, user: Battler, targets: Array[Battler], _move: MoveData) -> Array[Battler]:
		if int(user.get_effect(BattleEffects.BIDE)) != 1:
			return targets
		var remembered: Battler = battle.get_battler(int(user.get_effect(BattleEffects.BIDE_TARGET)))
		if remembered != null and not remembered.is_fainted():
			return [remembered]
		var foes: Array[Battler] = battle.opposing_battlers(user)
		return [foes[RNG.below(foes.size())]] if not foes.is_empty() else targets

	func fixed_damage(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> int:
		return maxi(int(user.get_effect(BattleEffects.BIDE_DAMAGE)) * 2, 1)

	func apply_status_move(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> bool:
		# Storing energy is a success in itself, so nothing is printed.
		return true

	func on_end(battle: Battle, user: Battler, targets: Array[Battler], move: MoveData) -> void:
		super.on_end(battle, user, targets, move)
		var stage: int = int(user.get_effect(BattleEffects.BIDE))
		if stage == 0:
			user.set_effect(BattleEffects.BIDE_DAMAGE, 0)
			user.set_effect(BattleEffects.BIDE_TARGET, -1)
			user.forced_move_id = move.id
			stage = 3
		stage -= 1
		user.set_effect(BattleEffects.BIDE, stage)
		if stage <= 0:
			_release(user)

	func _release(user: Battler) -> void:
		user.clear_effect(BattleEffects.BIDE)
		user.clear_effect(BattleEffects.BIDE_DAMAGE)
		user.clear_effect(BattleEffects.BIDE_TARGET)
		user.forced_move_id = &""
		user.forced_move_target = -1

## Rollout and Ice Ball, which double in power every round for five rounds and start one doubling higher after Defense Curl.
class RolloutEffect extends MoveEffect:

	func base_power(_battle: Battle, user: Battler, _target: Battler, move: MoveData) -> int:
		var remaining: int = int(user.get_effect(BattleEffects.ROLLOUT))
		var doublings: int = 0 if remaining == 0 else 5 - remaining
		if user.has_effect(BattleEffects.DEFENSE_CURL):
			doublings += 1
		return move.power * (1 << clampi(doublings, 0, 5))

	func on_after_all_hits(_battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		if int(user.get_effect(BattleEffects.ROLLOUT)) == 0:
			if damage <= 0:
				return
			user.set_effect(BattleEffects.ROLLOUT, 5)
			user.forced_move_id = move.id
			user.forced_move_target = target.index
		var remaining: int = int(user.get_effect(BattleEffects.ROLLOUT)) - 1
		user.set_effect(BattleEffects.ROLLOUT, remaining)
		if remaining <= 0:
			_release(user)

	func on_miss(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> void:
		_release(user)

	func _release(user: Battler) -> void:
		user.clear_effect(BattleEffects.ROLLOUT)
		user.forced_move_id = &""
		user.forced_move_target = -1

## Thrash, Outrage and Petal Dance, which rampage for two or three rounds and leave the user confused from the effort.
class ThrashEffect extends MoveEffect:

	func on_after_all_hits(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		if int(user.get_effect(BattleEffects.OUTRAGE)) == 0:
			if damage <= 0:
				return
			user.set_effect(BattleEffects.OUTRAGE, RNG.range_int(2, 3))
			user.forced_move_id = move.id
			user.forced_move_target = target.index
		var remaining: int = int(user.get_effect(BattleEffects.OUTRAGE)) - 1
		user.set_effect(BattleEffects.OUTRAGE, remaining)
		if remaining > 0:
			return
		_release(user)
		if user.has_effect(BattleEffects.CONFUSION):
			return
		if battle.field.terrain == &"Misty" and not user.is_airborne():
			return
		user.set_effect(BattleEffects.CONFUSION, RNG.range_int(2, 5))
		battle.announce(Loc.line("{pokemon} became confused due to fatigue!", {"pokemon": user.battle_name()}))

	func on_miss(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> void:
		_release(user)

	func _release(user: Battler) -> void:
		user.clear_effect(BattleEffects.OUTRAGE)
		user.forced_move_id = &""
		user.forced_move_target = -1

## Future Sight and Doom Desire, which land two rounds after they are used.
class DelayedAttackEffect extends MoveEffect:

	func is_damaging_this_use(battle: Battle, _user: Battler, _move: MoveData) -> bool:
		return battle.future_sight_active

	func use_message(battle: Battle, user: Battler, move: MoveData) -> String:
		# The strike is announced by the battle, which names the target.
		if battle.future_sight_active:
			return ""
		return "%s used %s!" % [user.battle_name(), move.display_name]

	func accuracy(battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> int:
		return move.accuracy if battle.future_sight_active else 0

	func succeeds_against(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		if battle.future_sight_active:
			return true
		var slot: Dictionary = battle.effects_at_position(target.index)
		return int(slot.get(BattleEffects.FUTURE_SIGHT_COUNTER, 0)) <= 0

## A blow that lands two rounds from now, on whoever is standing there then.

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return base
		var slot: Dictionary = battle.effects_at_position(target.index)
		if int(slot.get(BattleEffects.FUTURE_SIGHT_COUNTER, 0)) > 0:
			return AIScores.USELESS
		# Nothing left on the other side to still be standing there.
		var party: PokemonParty = battle.get_party(target.side_index())
		if party.able_count() <= 1 and target.hp_fraction() < 0.4:
			return AIScores.USELESS
		return base + (15 if user.turns_active < 2 else 0)

	func apply_status_move(battle: Battle, user: Battler, target: Battler, move: MoveData) -> bool:
		var slot: Dictionary = battle.effects_at_position(target.index)
		slot[BattleEffects.FUTURE_SIGHT_COUNTER] = 3
		slot[BattleEffects.FUTURE_SIGHT_MOVE] = move.id
		slot[BattleEffects.FUTURE_SIGHT_USER_INDEX] = user.index
		slot[BattleEffects.FUTURE_SIGHT_USER_PARTY_INDEX] = user.party_index
		if move.id == &"DOOMDESIRE":
			battle.announce(Loc.line("{pokemon} chose Doom Desire as its destiny!", {"pokemon": user.battle_name()}))
		else:
			battle.announce(Loc.line("{pokemon} foresaw an attack!", {"pokemon": user.battle_name()}))
		return true

## Focus Punch, which starts concentrating before the round and loses its focus if anything damages the user first.
class FocusPunchEffect extends MoveEffect:

	func round_start_message(_battle: Battle, user: Battler, _move: MoveData) -> String:
		user.set_effect(BattleEffects.FOCUS_PUNCH, true)
		return Loc.line("{pokemon} is tightening its focus!", {"pokemon": user.battle_name()})

	func use_message(_battle: Battle, user: Battler, move: MoveData) -> String:
		if _lost_focus(user):
			return ""
		return "%s used %s!" % [user.battle_name(), move.display_name]

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		if not _lost_focus(user):
			return true
		failure_message = Loc.line("{pokemon} lost its focus and couldn't move!", {"pokemon": user.battle_name()})
		return false

	func _lost_focus(user: Battler) -> bool:
		return user.has_effect(BattleEffects.FOCUS_PUNCH) and user.took_damage_this_turn

## Whether the focus survives is settled by what happens during the round, so the answer does not exist yet when the action is being chosen.

	func failure_is_known_when_choosing() -> bool:
		return false

## Enormous power for a round the user has to get through untouched.

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if user.has_substitute():
			return base + 20
		var threatened: bool = false
		for foe: Battler in battle.opposing_battlers(user):
			if AIBattlerView.can_attack(foe) and AIBattlerView.has_damaging_move(foe):
				threatened = true
				break
		if not threatened:
			return base + 20
		if target != null and AIBattlerView.faster_than(battle, user, target):
			return base - 10
		return base - 30

## Shell Trap, which only goes off after a physical hit.
class ShellTrapEffect extends MoveEffect:

	func round_start_message(_battle: Battle, user: Battler, _move: MoveData) -> String:
		user.set_effect(BattleEffects.SHELL_TRAP, true)
		return Loc.line("{pokemon} set a shell trap!", {"pokemon": user.battle_name()})

	func use_message(_battle: Battle, user: Battler, move: MoveData) -> String:
		if not user.took_physical_hit:
			return ""
		return "%s used %s!" % [user.battle_name(), move.display_name]

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		if not user.has_effect(BattleEffects.SHELL_TRAP):
			return false
		if user.took_physical_hit:
			return true
		failure_message = Loc.line("{pokemon}'s shell trap didn't work!", {"pokemon": user.battle_name()})
		return false

	func failure_is_known_when_choosing() -> bool:
		return false

## It only goes off after a physical hit, so it is worth setting against something that attacks physically and a wasted round against anything else.

	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		var physical_foe: bool = false
		for foe: Battler in battle.opposing_battlers(user):
			if AIBattlerView.has_physical_move(foe) and AIBattlerView.can_attack(foe):
				physical_foe = true
				break
		return base + 20 if physical_foe else AIScores.USELESS

## Beak Blast, which heats up before the round and burns anything that touches the user before it fires.
class BeakBlastEffect extends MoveEffect:

	func round_start_message(_battle: Battle, user: Battler, _move: MoveData) -> String:
		user.set_effect(BattleEffects.BEAK_BLAST, true)
		return Loc.line("{pokemon} started heating up its beak!", {"pokemon": user.battle_name()})

	func on_start(_battle: Battle, user: Battler, _targets: Array[Battler], _move: MoveData) -> void:
		user.clear_effect(BattleEffects.BEAK_BLAST)

## The burn is the point, and it only lands on something that touches the user first.

	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		for foe: Battler in battle.opposing_battlers(user):
			if foe.pokemon.status != &"NONE" or foe.has_type(&"FIRE"):
				continue
			var touches: bool = AIBattlerView.check_moves(foe, func(move: PokemonMove) -> bool:
				var record: MoveData = move.data()
				return record != null and record.makes_contact()
			)
			if touches:
				return base + 15
		return base

## Round, which doubles in power once an ally has used it this round and pulls the next ally planning to use it forward in the acting order.
class RoundEffect extends MoveEffect:

	func base_power(battle: Battle, user: Battler, _target: Battler, move: MoveData) -> int:
		if battle.get_side(user.side_index()).has_effect(BattleEffects.ROUND):
			return move.power * 2
		return move.power

	func on_end(battle: Battle, user: Battler, targets: Array[Battler], move: MoveData) -> void:
		super.on_end(battle, user, targets, move)
		battle.get_side(user.side_index()).set_effect(BattleEffects.ROUND, 1)
		for ally: Battler in battle.allies_of(user):
			if battle.has_acted_this_round(ally.index):
				continue
			var action: BattleAction = battle.action_for(ally.index)
			if action == null or action.kind != BattleAction.Kind.USE_MOVE or action.move == null:
				continue
			var record: MoveData = action.move.data()
			if record == null or record.function_code != move.function_code:
				continue
			ally.set_effect(BattleEffects.MOVE_NEXT, true)
			ally.clear_effect(BattleEffects.QUASH)
			break

## Fire Pledge, Water Pledge and Grass Pledge.
class PledgeEffect extends MoveEffect:

	## `true` on the turn this move waits for its partner instead of attacking.
	var _waiting: bool = false

	## The combination this use completes, or empty when it is on its own.
	var _combo: Dictionary = {}

	func _init(function_code: StringName) -> void:
		code = function_code

	func _combos() -> Dictionary:
		return MoveEffectsMultiTurn.PLEDGE_COMBOS.get(code, {})

	func effective_type(_battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> StringName:
		var override: StringName = StringName(_combo.get("type", &""))
		return override if not override.is_empty() else move.type

	func base_power(_battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> int:
		return move.power * 2 if not _combo.is_empty() else move.power

	func is_damaging_this_use(_battle: Battle, _user: Battler, _move: MoveData) -> bool:
		return not _waiting

	func on_start(battle: Battle, user: Battler, _targets: Array[Battler], move: MoveData) -> void:
		_waiting = false
		_combo = {}
		var partner: StringName = user.get_effect_id(BattleEffects.FIRST_PLEDGE)
		user.clear_effect(BattleEffects.FIRST_PLEDGE)
		if _combos().has(partner):
			_combo = _combos()[partner]
			battle.announce("The two moves have become one! It's a combined move!")
			return
		# Nobody has set up yet, so look for an ally that is about to.
		for ally: Battler in battle.allies_of(user):
			if battle.has_acted_this_round(ally.index):
				continue
			var action: BattleAction = battle.action_for(ally.index)
			if action == null or action.kind != BattleAction.Kind.USE_MOVE or action.move == null:
				continue
			var record: MoveData = action.move.data()
			if record == null or not _combos().has(record.function_code):
				continue
			_waiting = true
			ally.set_effect(BattleEffects.FIRST_PLEDGE, move.function_code)
			ally.set_effect(BattleEffects.MOVE_NEXT, true)
			ally.clear_effect(BattleEffects.QUASH)
			battle.announce(Loc.line("{pokemon} is waiting for {ally}'s move...", {"pokemon": user.battle_name(), "ally": ally.battle_name()}))
			break

	func apply_status_move(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		# Setting up deliberately does nothing else, and counts as a failure for
		# the moves that care about the last one failing.
		user.last_move_failed = true
		return true

	func on_after_all_hits(battle: Battle, user: Battler, _target: Battler, _move: MoveData, _damage: int) -> void:
		if _combo.is_empty():
			return
		var effect_name: StringName = StringName(_combo.get("effect", &""))
		if effect_name.is_empty():
			return
		var on_foes: bool = bool(MoveEffectsMultiTurn.PLEDGE_EFFECT_ON_FOES.get(effect_name, false))
		var side_index: int = user.opposing_side_index() if on_foes else user.side_index()
		var side: BattleSide = battle.get_side(side_index)
		if side.has_effect(effect_name):
			return
		side.set_effect(effect_name, MoveEffectsMultiTurn.PLEDGE_EFFECT_TURNS)
		battle.announce(String(MoveEffectsMultiTurn.PLEDGE_MESSAGES.get(effect_name, "The field changed!")))
