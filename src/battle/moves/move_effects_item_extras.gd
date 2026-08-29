class_name MoveEffectsItemExtras

## Moves built around the user's or the target's held item.

## Held items Fling gives a bespoke effect to, mapped to what they do.
const FLING_EFFECTS: Dictionary = {
	&"POISONBARB": "poison",
	&"TOXICORB": "bad_poison",
	&"FLAMEORB": "burn",
	&"LIGHTBALL": "paralyze",
	&"KINGSROCK": "flinch",
	&"RAZORFANG": "flinch",
}

## The power Fling falls back on for an item with no Fling flag of its own.
const DEFAULT_FLING_POWER: int = 10

static func register_all() -> void:
	MoveEffects.register(&"ThrowUserItemAtTarget", FlingEffect.new())
	MoveEffects.register(&"TypeAndPowerDependOnUserBerry", NaturalGiftEffect.new())
	MoveEffects.register(&"UserConsumeBerryRaiseDefense2", StuffCheeksEffect.new())
	MoveEffects.register(&"AllBattlersConsumeBerry", TeatimeEffect.new())
	MoveEffects.register(&"FailsIfUserNotConsumedBerry", BelchEffect.new())
	MoveEffects.register(&"FailsIfTargetHasNoItem", PoltergeistEffect.new())

## `true` when [param battler] is holding a Berry it could eat right now.

static func holds_usable_berry(battler: Battler) -> bool:
	var record: ItemData = Database.item(battler.held_item())
	return record != null and record.is_berry()

# === Effect Types ==

## Fling, which hurls the held item at the target for damage that depends on the item, then applies whatever the item would have done.
class FlingEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		var record: ItemData = Database.item(user.held_item())
		if record == null:
			return false
		return record.get_fling_power() > 0

	func hit_count(_battle: Battle, _user: Battler, _target: Battler) -> int:
		return 1

	func base_power(_battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> int:
		var record: ItemData = Database.item(user.held_item())
		if record == null:
			return MoveEffectsItemExtras.DEFAULT_FLING_POWER
		return maxi(record.get_fling_power(), MoveEffectsItemExtras.DEFAULT_FLING_POWER)

	func on_start(battle: Battle, user: Battler, _targets: Array[Battler], _move: MoveData) -> void:
		var record: ItemData = Database.item(user.held_item())
		if record != null:
			battle.announce(Loc.line("{pokemon} flung its {name}!", {"pokemon": user.battle_name(), "name": record.get_translated_name()}))

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		if damage <= 0 or target.has_ability(&"SHIELDDUST"):
			return
		var thrown: StringName = user.held_item()
		match MoveEffectsItemExtras.FLING_EFFECTS.get(thrown, ""):
			"poison":
				if target.inflict_status(&"POISON", 0, user):
					battle.announce_status(target, &"POISON")
			"bad_poison":
				if target.inflict_status(&"POISON", 1, user):
					battle.announce_status(target, &"POISON")
			"burn":
				if target.inflict_status(&"BURN", 0, user):
					battle.announce_status(target, &"BURN")
			"paralyze":
				if target.inflict_status(&"PARALYSIS", 0, user):
					battle.announce_status(target, &"PARALYSIS")
			"flinch":
				if not target.has_acted:
					target.set_effect(BattleEffects.FLINCH, 1)
			_:
				for message: String in ItemEffects.force_eat_berry(battle, target, thrown):
					battle.announce(message)

	func on_end(battle: Battle, user: Battler, targets: Array[Battler], move: MoveData) -> void:
		super.on_end(battle, user, targets, move)
		user.consume_item()

## Natural Gift, whose type and power come from the Berry the user is holding.
class NaturalGiftEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		var record: ItemData = Database.item(user.held_item())
		if record == null or not record.is_berry():
			return false
		return record.get_natural_gift_power() > 0

	func effective_type(_battle: Battle, user: Battler, _target: Battler, move: MoveData) -> StringName:
		var record: ItemData = Database.item(user.held_item())
		if record == null:
			return move.type
		var berry_type: StringName = record.get_natural_gift_type()
		return berry_type if Database.type(berry_type) != null else move.type

	func base_power(_battle: Battle, user: Battler, _target: Battler, move: MoveData) -> int:
		var record: ItemData = Database.item(user.held_item())
		if record == null:
			return move.power
		return maxi(record.get_natural_gift_power(), 10)

	func on_end(battle: Battle, user: Battler, targets: Array[Battler], move: MoveData) -> void:
		super.on_end(battle, user, targets, move)
		if user.held_item().is_empty():
			return
		user.consume_item()
		battle.record_berry_eaten(user)

## Stuff Cheeks, which eats the user's own Berry for a sharp Defense rise.
class StuffCheeksEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		return MoveEffectsItemExtras.holds_usable_berry(user)

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		for message: String in ItemEffects.force_eat_berry(battle, user):
			battle.announce(message)
		battle.change_stat_stage(user, &"DEFENSE", 2, user)
		return true

## Scores the Defense boost from the consumed Berry.
	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if not MoveEffectsItemExtras.holds_usable_berry(user):
			return AIScores.USELESS
		if not user.can_raise_stat(&"DEFENSE"):
			return AIScores.USELESS
		return base + 20 - 3 * AIRatings.for_item(user, user.held_item())

## Teatime, which makes everyone on the field eat the Berry they are holding.
class TeatimeEffect extends MoveEffect:

	func override_targets(battle: Battle, _user: Battler, _targets: Array[Battler], _move: MoveData) -> Array[Battler]:
		var chosen: Array[Battler] = []
		for candidate: Battler in battle.all_active_battlers():
			if MoveEffectsItemExtras.holds_usable_berry(candidate):
				chosen.append(candidate)
		return chosen

	func can_be_used(battle: Battle, user: Battler, _move: MoveData) -> bool:
		if not override_targets(battle, user, [] as Array[Battler], null).is_empty():
			return true
		failure_message = "But nothing happened!"
		return false

	func on_start(battle: Battle, _user: Battler, _targets: Array[Battler], _move: MoveData) -> void:
		battle.announce("It's teatime! Everyone dug in to their Berries!")

	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		var ours: int = 0
		var theirs: int = 0
		for battler: Battler in battle.all_active_battlers():
			if not MoveEffectsItemExtras.holds_usable_berry(battler):
				continue
			if battler.side_index() == user.side_index():
				ours += 1
			else:
				theirs += 1
		if ours == 0 and theirs == 0:
			return AIScores.USELESS
		return base + 15 * (ours - theirs)

	func apply_status_move(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		for message: String in ItemEffects.force_eat_berry(battle, target):
			battle.announce(message)
		return true

## Belch, which the user can only manage once it has eaten a Berry.
class BelchEffect extends MoveEffect:

	func can_be_used(battle: Battle, user: Battler, _move: MoveData) -> bool:
		return battle.has_eaten_berry(user)

## Poltergeist, which attacks the target with whatever it is holding.
class PoltergeistEffect extends MoveEffect:

	func succeeds_against(_battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		return not target.held_item().is_empty()

	## Scores the item only when the target is holding one.
	func ai_score(_battle: Battle, _user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.held_item().is_empty():
			return AIScores.USELESS
		return base

	func on_start(battle: Battle, _user: Battler, targets: Array[Battler], _move: MoveData) -> void:
		for target: Battler in targets:
			var record: ItemData = Database.item(target.held_item())
			if record != null:
				battle.announce(Loc.line("{target} is about to be attacked by its {name}!", {"target": target.battle_name(), "name": record.get_translated_name()}))
