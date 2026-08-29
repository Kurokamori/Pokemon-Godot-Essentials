class_name MoveEffectsLingering

## The moves whose whole point happens later, rather than when they are used.

static func register_all() -> void:
	MoveEffects.register(&"CurseTargetOrLowerUserSpd1RaiseUserAtkDef1", CurseEffect.new())
	MoveEffects.register(&"StartRaiseUserAtk1WhenDamaged", RageEffect.new())
	MoveEffects.register(&"SleepTargetNextTurn", YawnEffect.new())
	MoveEffects.register(&"AttackerFaintsIfUserFaints", DyingWishEffect.new(BattleEffects.DESTINY_BOND))
	MoveEffects.register(&"SetAttackerMovePPTo0IfUserFaints", DyingWishEffect.new(BattleEffects.GRUDGE))
	MoveEffects.register(&"RaiseUserSpDef1PowerUpElectricMove", ChargeEffect.new())

## Curse, which is two different moves depending on who uses it.
class CurseEffect extends MoveEffect:

	## Share of the user's maximum health the Ghost-type version costs.
	const GHOST_COST: float = 0.5

	func _init() -> void:
		user_stat_changes = {&"SPEED": -1, &"ATTACK": 1, &"DEFENSE": 1}
		stat_change_is_main_effect = true

## A Ghost aims at a foe; anybody else is aiming at itself, and the record's own target says `User`.
	func override_targets(
		battle: Battle, user: Battler, targets: Array[Battler], _move: MoveData
	) -> Array[Battler]:
		if not _is_ghost(user) or battle == null:
			return targets
		var foes: Array[Battler] = battle.opposing_battlers(user)
		if foes.is_empty():
			return targets
		var chosen: Array[Battler] = []
		chosen.append(foes[0])
		return chosen

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		if not _is_ghost(user):
			return true
		if user.hp() <= 1:
			failure_message = Loc.line("{pokemon} has too little health left!", {
				"pokemon": user.battle_name(),
			})
			return false
		return true

	func apply_status_move(battle: Battle, user: Battler, target: Battler, move: MoveData) -> bool:
		if not _is_ghost(user):
			return super.apply_status_move(battle, user, target, move)
		if target == null or target == user or target.has_effect(BattleEffects.CURSE):
			return false
		user.take_damage(maxi(int(float(user.total_hp()) * GHOST_COST), 1))
		target.set_effect(BattleEffects.CURSE, 999)
		battle.announce(Loc.line("{user} cut its own HP and laid a curse on {target}!", {
			"user": user.battle_name(), "target": target.battle_name(),
		}))
		return true

	## Two moves in one, so two scores.
	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if not _is_ghost(user):
			return base
		if target == null or target.has_effect(BattleEffects.CURSE):
			return AIScores.USELESS
		if user.hp_fraction() <= GHOST_COST:
			return AIScores.USELESS
		var worth: int = base + int(50.0 * target.hp_fraction())
		if target.is_trapped():
			worth += 20
		return worth

	func _is_ghost(user: Battler) -> bool:
		return user != null and user.has_type(&"GHOST")

## Rage, which keeps its user angry until it does something else.
class RageEffect extends MoveEffect:

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		user.set_effect(BattleEffects.RAGE, 999)

## Worth having only while there is something left to be angry at
	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if user.has_effect(BattleEffects.RAGE):
			return base
		if not user.can_raise_stat(&"ATTACK"):
			return base
		return base + 10

## Yawn, which makes the target drowsy now and asleep at the end of the next round.
class YawnEffect extends MoveEffect:

## Rounds the drowsiness lasts.
	const DROWSY_ROUNDS: int = 2

	func succeeds_against(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		if target == null or target.has_effect(BattleEffects.YAWN):
			return false
		return target.can_take_status(&"SLEEP", user)

	func apply_status_move(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		target.set_effect(BattleEffects.YAWN, DROWSY_ROUNDS)
		battle.announce(Loc.line("{target} became drowsy!", {"target": target.battle_name()}))
		return true

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.has_effect(BattleEffects.YAWN):
			return AIScores.USELESS
		if not target.can_take_status(&"SLEEP", user):
			return AIScores.USELESS
		if AIBattlerView.wants_status(battle, target, &"SLEEP"):
			return AIScores.USELESS
		return base + 15

## Destiny Bond and Grudge, which are the same move with two different prices
class DyingWishEffect extends MoveEffect:
	var _effect: StringName = &""

	func _init(which: StringName = &"") -> void:
		_effect = which

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		if user.has_effect(_effect):
			failure_message = "But it failed!"
			return false
		return true

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		user.set_effect(_effect, 999)
		battle.announce(Loc.line(
			"{pokemon} is trying to take its foe down with it!"
			if _effect == BattleEffects.DESTINY_BOND
			else "{pokemon} wants its foe to bear a grudge!",
			{"pokemon": user.battle_name()}))
		return true

## Worth arming only when the user is likely to be knocked out this round
	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if user.has_effect(_effect):
			return AIScores.FAIL
		var worth: int = base
		if user.hp_fraction() < 0.25:
			worth += 30
		elif user.hp_fraction() > 0.5:
			worth -= 30
		if AIEndOfRound.damage_for(battle, user) >= user.hp():
			worth += 20
		return worth

## Charge, which raises the user's Special Defense now and doubles the power of the Electric move it uses next.
class ChargeEffect extends MoveEffect:

## Rounds the charge is held for.
	const HELD_FOR: int = 2

	func _init() -> void:
		user_stat_changes = {&"SPECIAL_DEFENSE": 1}

	func apply_status_move(battle: Battle, user: Battler, target: Battler, move: MoveData) -> bool:
		user.set_effect(BattleEffects.CHARGE, HELD_FOR)
		battle.announce(Loc.line("{pokemon} began charging power!", {"pokemon": user.battle_name()}))
		super.apply_status_move(battle, user, target, move)
		return true

	## Worth using only when there is an Electric move to spend it on.
	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if user.has_effect(BattleEffects.CHARGE):
			return AIScores.USELESS
		if not AIBattlerView.has_damaging_move_of(battle, user, &"ELECTRIC"):
			return AIScores.USELESS
		return base + 20
