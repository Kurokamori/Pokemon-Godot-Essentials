class_name MoveEffectsOrderExtras

## Moves that change who acts when, who a move lands on, or which depend on what someone else has already chosen to do.

static func register_all() -> void:
	MoveEffects.register(&"HigherPriorityInGrassyTerrain", GrassyGlideEffect.new())
	MoveEffects.register(&"TargetActsNext", AfterYouEffect.new())
	MoveEffects.register(&"TargetActsLast", QuashEffect.new())
	MoveEffects.register(&"PursueSwitchingFoe", PursuitEffect.new())
	MoveEffects.register(&"FailsIfTargetActed", SuckerPunchEffect.new())
	MoveEffects.register(&"FailsIfNotUserFirstTurn", FirstImpressionEffect.new())
	MoveEffects.register(&"RedirectAllMovesToTarget", SpotlightEffect.new())
	MoveEffects.register(&"PowerUpAllyMove", HelpingHandEffect.new())
	MoveEffects.register(&"UserSwapsPositionsWithAlly", AllySwitchEffect.new())
	MoveEffects.register(&"HitsAllFoesAndPowersUpInPsychicTerrain", ExpandingForceEffect.new())
	MoveEffects.register(&"HealAllyOrDamageFoe", PollenPuffEffect.new())
	MoveEffects.register(&"DamageTargetAlly", FlameBurstEffect.new())

## The highest Quash anyone on the field is carrying.
static func highest_quash(battle: Battle) -> int:
	var highest: int = 0
	for battler: Battler in battle.all_active_battlers():
		highest = maxi(highest, int(battler.get_effect(BattleEffects.QUASH)))
	return highest

## Returns `true` when [param target] still has a move waiting to be used this round.
static func has_move_pending(battle: Battle, target: Battler) -> bool:
	if battle.has_acted_this_round(target.index):
		return false
	var action: BattleAction = battle.action_for(target.index)
	return action != null and action.kind == BattleAction.Kind.USE_MOVE and action.move != null

# === Effect Types ==

## Grassy Glide, which cuts ahead of the queue while Grassy Terrain is up.
class GrassyGlideEffect extends MoveEffect:

	func priority_bonus(battle: Battle, user: Battler, _move: MoveData) -> int:
		if battle.field.terrain == &"Grassy" and not user.is_airborne():
			return 1
		return 0

## After You, which lets the target move next whatever its speed is.
class AfterYouEffect extends MoveEffect:

	func succeeds_against(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		if target.has_effect(BattleEffects.MOVE_NEXT):
			return false
		return MoveEffectsOrderExtras.has_move_pending(battle, target)

	func failure_is_known_when_choosing() -> bool:
		return false

	## Scores After You for an ally that has not acted.
	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.side_index() != user.side_index() or target == user:
			return AIScores.USELESS
		if target.has_effect(BattleEffects.MOVE_NEXT):
			return AIScores.USELESS
		for foe: Battler in battle.opposing_battlers(user):
			if AIBattlerView.faster_than(battle, foe, target):
				return base + 20
		return base

	func apply_status_move(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		target.set_effect(BattleEffects.MOVE_NEXT, true)
		target.clear_effect(BattleEffects.QUASH)
		battle.announce(Loc.line("{target} took the kind offer!", {"target": target.battle_name()}))
		return true

## Quash, which pushes the target to the back of the acting order.
class QuashEffect extends MoveEffect:

	func succeeds_against(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		if not MoveEffectsOrderExtras.has_move_pending(battle, target):
			return false
		var highest: int = MoveEffectsOrderExtras.highest_quash(battle)
		if highest > 0 and int(target.get_effect(BattleEffects.QUASH)) == highest:
			return false
		return true

	func failure_is_known_when_choosing() -> bool:
		return false

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.side_index() == user.side_index():
			return AIScores.USELESS
		return base + (20 if AIBattlerView.faster_than(battle, target, user) else -10)

	func apply_status_move(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		target.set_effect(BattleEffects.QUASH, MoveEffectsOrderExtras.highest_quash(battle) + 1)
		target.clear_effect(BattleEffects.MOVE_NEXT)
		battle.announce(Loc.line("{target}'s move was postponed!", {"target": target.battle_name()}))
		return true

class PursuitEffect extends MoveEffect:

	func base_power(battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> int:
		return move.power * 2 if battle.pursuit_active else move.power

	func never_misses(battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> bool:
		return battle.pursuit_active

	func ai_score(battle: Battle, _user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return base
		var party: PokemonParty = battle.get_party(target.side_index())
		var reserves: int = party.able_count() - battle.active_battlers_on_side(
			target.side_index()).size()
		return base + (15 if reserves > 0 else 0)

## Sucker Punch, which only lands on a target that is about to attack.
class SuckerPunchEffect extends MoveEffect:

	func succeeds_against(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		if not MoveEffectsOrderExtras.has_move_pending(battle, target):
			return false
		var record: MoveData = battle.action_for(target.index).move.data()
		if record == null:
			return false
		# Me First counts, because the move it steals will be a damaging one.
		if record.function_code == &"UseMoveTargetIsAboutToUse":
			return true
		return record.is_damaging()

	func failure_is_known_when_choosing() -> bool:
		return false


	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return base
		if not AIBattlerView.has_damaging_move(target):
			return AIScores.USELESS
		if not AIBattlerView.faster_than(battle, target, user):
			return base
		return base - 10 * mini(user.consecutive_move_uses, 3)

## First Impression, which only works on the user's first round out.
class FirstImpressionEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		return user.turns_active < 1

## Spotlight, which drags every single-target move onto the target.
class SpotlightEffect extends MoveEffect:

	func apply_status_move(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		var strength: int = 1
		for ally: Battler in battle.allies_of(target):
			strength = maxi(strength, int(ally.get_effect(BattleEffects.SPOTLIGHT)) + 1)
		target.set_effect(BattleEffects.SPOTLIGHT, strength)
		battle.announce(Loc.line("{target} became the center of attention!", {"target": target.battle_name()}))
		return true

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or battle.max_battlers_per_side() < 2:
			return AIScores.USELESS
		if target.side_index() != user.side_index():
			return AIScores.USELESS
		return base + int(20.0 * target.hp_fraction())

class HelpingHandEffect extends MoveEffect:

	func succeeds_against(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		if target.has_effect(BattleEffects.HELPING_HAND):
			return false
		return MoveEffectsOrderExtras.has_move_pending(battle, target)

	func failure_is_known_when_choosing() -> bool:
		return false

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or battle.max_battlers_per_side() < 2:
			return AIScores.USELESS
		if target.side_index() != user.side_index() or target == user:
			return AIScores.USELESS
		if target.has_effect(BattleEffects.HELPING_HAND):
			return AIScores.USELESS
		return base + (20 if AIBattlerView.has_damaging_move(target) else -20)

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		target.set_effect(BattleEffects.HELPING_HAND, 1)
		battle.announce(Loc.line("{pokemon} is ready to help {target}!", {"pokemon": user.battle_name(), "target": target.battle_name()}))
		return true

## Ally Switch, which trades places with the user's partner.
class AllySwitchEffect extends MoveEffect:

	func can_be_used(battle: Battle, user: Battler, _move: MoveData) -> bool:
		return battle.allies_of(user).size() == 1

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		var allies: Array[Battler] = battle.allies_of(user)
		if allies.size() != 1:
			return false
		var partner: Battler = allies[0]
		var partner_name: String = partner.battle_name()
		if not battle.swap_battlers(user.index, partner.index):
			return false
		battle.announce(Loc.line("{pokemon} and {partner_name} switched places!", {"pokemon": user.battle_name(), "partner_name": partner_name}))
		return true

## Expanding Force, which spreads across the opposing side and hits harder while Psychic Terrain is up.
class ExpandingForceEffect extends MoveEffect:

	func override_targets(battle: Battle, user: Battler, targets: Array[Battler], _move: MoveData) -> Array[Battler]:
		if _boosted(battle, user):
			var foes: Array[Battler] = battle.opposing_battlers(user)
			if not foes.is_empty():
				return foes
		return targets

	func base_power(battle: Battle, user: Battler, _target: Battler, move: MoveData) -> int:
		return move.power * 3 / 2 if _boosted(battle, user) else move.power

	func _boosted(battle: Battle, user: Battler) -> bool:
		return battle.field.terrain == &"Psychic" and not user.is_airborne()

## Pollen Puff, which damages a foe but heals an ally instead.
class PollenPuffEffect extends MoveEffect:

	var _aimed_at_ally: bool = false

	func on_start(_battle: Battle, user: Battler, targets: Array[Battler], _move: MoveData) -> void:
		_aimed_at_ally = not targets.is_empty() and targets[0].side_index() == user.side_index()

	func is_damaging_this_use(_battle: Battle, _user: Battler, _move: MoveData) -> bool:
		return not _aimed_at_ally

	func override_targets(battle: Battle, user: Battler, targets: Array[Battler], _move: MoveData) -> Array[Battler]:
		if user.has_effect(BattleEffects.HEAL_BLOCK) and not targets.is_empty():
			if targets[0].side_index() == user.side_index():
				var foes: Array[Battler] = battle.opposing_battlers(user)
				if not foes.is_empty():
					return foes.slice(0, 1)
		return targets

	func succeeds_against(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		if target.side_index() != user.side_index():
			return true
		return target.hp() < target.total_hp() and not target.has_effect(BattleEffects.HEAL_BLOCK)

	## Scores Pollen Puff as healing against allies and damage against foes.
	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.side_index() != user.side_index():
			return base
		if not AIBattlerView.can_heal(target):
			return AIScores.USELESS
		return base + int(60.0 * (1.0 - target.hp_fraction()))

	func apply_status_move(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		if target.restore_hp(maxi(target.total_hp() / 2, 1)) <= 0:
			return false
		battle.announce(Loc.line("{target}'s HP was restored.", {"target": target.battle_name()}))
		return true

## Flame Burst, which splashes onto whoever is standing next to the target.
class FlameBurstEffect extends MoveEffect:

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		if damage <= 0:
			return
		for splashed: Battler in battle.allies_of(target):
			if splashed.has_ability(&"MAGICGUARD") or splashed == user:
				continue
			splashed.take_damage(maxi(splashed.total_hp() / 16, 1))
			battle.announce(Loc.line("The bursting flame hit {splashed}!", {"splashed": splashed.battle_name()}))
