class_name MoveEffectsMiscExtras

## The remaining moves with rules of their own: the ones that read the surroundings, 
## rewrite a moveset, work on PP, or depend on something that happened earlier in the battle.

## Secret Power's effect in each terrain, and the move whose animation it borrows.
const SECRET_POWER_TERRAIN: Dictionary = {
	&"Electric": "paralyze",
	&"Grassy": "sleep",
	&"Misty": "lower_special_attack",
	&"Psychic": "lower_speed",
}

## Secret Power's effect in each environment when no terrain is up.
const SECRET_POWER_ENVIRONMENT: Dictionary = {
	&"Grass": "sleep",
	&"TallGrass": "sleep",
	&"Forest": "sleep",
	&"ForestGrass": "sleep",
	&"MovingWater": "lower_attack",
	&"StillWater": "lower_attack",
	&"Underwater": "lower_attack",
	&"Puddle": "lower_speed",
	&"Cave": "flinch",
	&"Rock": "lower_accuracy",
	&"Sand": "lower_accuracy",
	&"Snow": "freeze",
	&"Ice": "freeze",
	&"Volcano": "burn",
	&"Graveyard": "flinch",
	&"Sky": "lower_speed",
	&"Space": "flinch",
	&"UltraSpace": "lower_defense",
}

## What Secret Power does anywhere else.
const SECRET_POWER_DEFAULT: String = "paralyze"

## Magnitude's base power for magnitudes four to ten.
const MAGNITUDE_POWERS: Array[int] = [10, 30, 50, 70, 90, 110, 150]

## The magnitude rolled, weighted towards seven, as twenty equally likely draws.
const MAGNITUDE_ROLLS: Array[int] = [
	4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 10,
]

## How many rounds in a row Echoed Voice keeps building for.
const MAX_ECHOED_VOICE: int = 5

static func register_all() -> void:
	MoveEffects.register(&"FailsIfUserHasUnusedMove", LastResortEffect.new())
	MoveEffects.register(&"FailsUnlessTargetSharesTypeWithUser", SynchronoiseEffect.new())
	MoveEffects.register(&"CrashDamageIfFailsUnusableInGravity", CrashDamageEffect.new())
	MoveEffects.register(&"HitOncePerUserTeamMember", BeatUpEffect.new())
	MoveEffects.register(&"RandomPowerDoublePowerIfTargetUnderground", MagnitudeEffect.new())
	MoveEffects.register(&"PowerHigherWithConsecutiveUseOnUserSide", EchoedVoiceEffect.new())
	MoveEffects.register(&"DoublePowerAfterFusionBolt",
		FusionEffect.new(BattleEffects.FUSION_BOLT, BattleEffects.FUSION_FLARE))
	MoveEffects.register(&"DoublePowerAfterFusionFlare",
		FusionEffect.new(BattleEffects.FUSION_FLARE, BattleEffects.FUSION_BOLT))
	MoveEffects.register(&"EffectDependsOnEnvironment", SecretPowerEffect.new())
	MoveEffects.register(&"SwapSideEffects", CourtChangeEffect.new())
	MoveEffects.register(&"LowerPPOfTargetLastMoveBy3", ReducePPEffect.new(3, false))
	MoveEffects.register(&"LowerPPOfTargetLastMoveBy4", ReducePPEffect.new(4, true))
	MoveEffects.register(&"TargetMovesBecomeElectric", ElectrifyEffect.new())
	MoveEffects.register(&"TargetNextFireMoveDamagesTarget", PowderEffect.new())
	MoveEffects.register(&"SetUserTypesToResistLastAttack", Conversion2Effect.new())
	MoveEffects.register(&"TransformUserIntoTarget", TransformEffect.new())
	MoveEffects.register(&"ReplaceMoveWithTargetLastMoveUsed", SketchEffect.new())
	MoveEffects.register(&"ReplaceMoveThisBattleWithTargetLastMoveUsed", MimicEffect.new())

# === Effect Types ==

## Last Resort, which only works once every other move has been used.
class LastResortEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, move: MoveData) -> bool:
		var others: int = 0
		for known: PokemonMove in user.moves():
			if known.id == move.id:
				continue
			others += 1
			if not user.moves_used.has(known.id):
				return false
		return others > 0

## Synchronoise, which only reaches targets that share a type with the user.
class SynchronoiseEffect extends MoveEffect:

	func succeeds_against(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		for own_type: StringName in user.types():
			if target.has_type(own_type):
				return true
		failure_message = Loc.line("{target} is unaffected!", {"target": target.battle_name()})
		return false

## Jump Kick and High Jump Kick, which hurt the user badly when they miss.
class CrashDamageEffect extends MoveEffect:

	func can_be_used(battle: Battle, _user: Battler, _move: MoveData) -> bool:
		return not battle.field.has_effect(BattleEffects.GRAVITY)

	func on_miss(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> void:
		if user.has_ability(&"MAGICGUARD"):
			return
		user.take_damage(maxi(user.total_hp() / 2, 1))
		battle.announce(Loc.line("{pokemon} kept going and crashed!", {"pokemon": user.battle_name()}))

## Beat Up, which hits once for every healthy member of the user's party 
class BeatUpEffect extends MoveEffect:

## Party slots still to strike with this use, 
## filled in by [method hit_count] and consumed one at a time by [method base_power].
	var _remaining: Array[int] = []

	func can_be_used(battle: Battle, user: Battler, _move: MoveData) -> bool:
		return not _able_slots(battle, user).is_empty()

	func hit_count(battle: Battle, user: Battler, _target: Battler) -> int:
		_remaining = _able_slots(battle, user)
		return maxi(_remaining.size(), 1)

	func base_power(battle: Battle, user: Battler, _target: Battler, move: MoveData) -> int:
		if _remaining.is_empty():
			return move.power
		var slot: int = _remaining.pop_front()
		var member: Pokemon = battle.get_party(user.side_index()).get_member(slot)
		if member == null:
			return move.power
		var species: SpeciesData = member.species_data()
		if species == null:
			return move.power
		return 5 + (species.base_attack / 10)

## [method base_power] consumes a party member, so the AI must not call it.
	func expected_base_power(battle: Battle, user: Battler, _target: Battler, move: MoveData) -> int:
		var slots: Array[int] = _able_slots(battle, user)
		if slots.is_empty():
			return move.power
		var total: int = 0
		for slot: int in slots:
			var member: Pokemon = battle.get_party(user.side_index()).get_member(slot)
			var species: SpeciesData = member.species_data() if member != null else null
			@warning_ignore("integer_division")
			total += 5 + (species.base_attack / 10) if species != null else move.power
		@warning_ignore("integer_division")
		return maxi(total / slots.size(), 1)

## One strike per able party member
	func expected_hit_count(user: Battler) -> int:
		if user == null or user.battle == null:
			return 1
		return maxi(_able_slots(user.battle, user).size(), 1)

	func _able_slots(battle: Battle, user: Battler) -> Array[int]:
		var slots: Array[int] = []
		var party: PokemonParty = battle.get_party(user.side_index())
		for slot: int in range(party.size()):
			var member: Pokemon = party.get_member(slot)
			if member == null or member.is_egg() or not member.is_able():
				continue
			if member.status != &"NONE":
				continue
			slots.append(slot)
		return slots


class MagnitudeEffect extends MoveEffect:

## The power rolled for this use, kept so every target in a spread takes the same magnitude.
	var _power: int = 0

	func on_start(battle: Battle, _user: Battler, _targets: Array[Battler], _move: MoveData) -> void:
		var rolls: Array[int] = MoveEffectsMiscExtras.MAGNITUDE_ROLLS
		var magnitude: int = rolls[RNG.below(rolls.size())]
		_power = MoveEffectsMiscExtras.MAGNITUDE_POWERS[magnitude - 4]
		battle.announce("Magnitude %d!" % magnitude)

	func base_power(_battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> int:
		return _power if _power > 0 else move.power

	func expected_base_power(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> int:
		var total: int = 0
		for magnitude: int in MoveEffectsMiscExtras.MAGNITUDE_ROLLS:
			total += MoveEffectsMiscExtras.MAGNITUDE_POWERS[magnitude - 4]
		@warning_ignore("integer_division")
		return maxi(total / MoveEffectsMiscExtras.MAGNITUDE_ROLLS.size(), 1)

	func final_damage_multiplier(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> float:
		var multiplier: float = 1.0
		if target.get_effect_id(BattleEffects.INVULNERABLE) == &"Underground":
			multiplier *= 2.0
		if battle.field.terrain == &"Grassy":
			multiplier *= 0.5
		return multiplier

## Echoed Voice, which grows louder every round its side keeps using it.
class EchoedVoiceEffect extends MoveEffect:

	func base_power(battle: Battle, user: Battler, _target: Battler, move: MoveData) -> int:
		return move.power * clampi(_counter(battle, user), 1, MoveEffectsMiscExtras.MAX_ECHOED_VOICE)

	func on_start(battle: Battle, user: Battler, _targets: Array[Battler], _move: MoveData) -> void:
		var side: BattleSide = battle.get_side(user.side_index())
		if not side.has_effect(BattleEffects.ECHOED_VOICE_USED):
			side.set_effect(BattleEffects.ECHOED_VOICE_COUNTER,
				mini(_counter(battle, user) + 1, MoveEffectsMiscExtras.MAX_ECHOED_VOICE))
		side.set_effect(BattleEffects.ECHOED_VOICE_USED, 1)

	func _counter(battle: Battle, user: Battler) -> int:
		return int(battle.get_side(user.side_index()).get_effect(BattleEffects.ECHOED_VOICE_COUNTER))

## Fusion Flare and Fusion Bolt, each of which hits twice as hard when the other has already been used this round.
class FusionEffect extends MoveEffect:
	var _partner_flag: StringName
	var _own_flag: StringName

	func _init(partner_flag: StringName, own_flag: StringName) -> void:
		_partner_flag = partner_flag
		_own_flag = own_flag

	func final_damage_multiplier(battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> float:
		return 2.0 if battle.field.has_effect(_partner_flag) else 1.0

	func on_end(battle: Battle, user: Battler, targets: Array[Battler], move: MoveData) -> void:
		super.on_end(battle, user, targets, move)
		battle.field.set_effect(_own_flag, 1)

## Secret Power, whose secondary effect follows the terrain or the surroundings.
class SecretPowerEffect extends MoveEffect:

	func on_after_all_hits(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		if damage <= 0 or target.is_fainted() or user.has_ability(&"SHEERFORCE"):
			return
		if target.has_ability(&"SHIELDDUST"):
			return
		var chance: int = move.effect_chance if move.effect_chance > 0 else 30
		if RNG.range_int(1, 100) > _boosted_chance(user, chance):
			return
		match _effect_here(battle):
			"paralyze":
				if target.inflict_status(&"PARALYSIS", 0, user):
					battle.announce_status(target, &"PARALYSIS")
			"sleep":
				if target.inflict_status(&"SLEEP", 0, user):
					battle.announce_status(target, &"SLEEP")
			"burn":
				if target.inflict_status(&"BURN", 0, user):
					battle.announce_status(target, &"BURN")
			"freeze":
				if target.inflict_status(&"FROZEN", 0, user):
					battle.announce_status(target, &"FROZEN")
			"flinch":
				if not target.has_acted:
					target.set_effect(BattleEffects.FLINCH, 1)
			"lower_attack":
				battle.change_stat_stage(target, &"ATTACK", -1, user)
			"lower_defense":
				battle.change_stat_stage(target, &"DEFENSE", -1, user)
			"lower_special_attack":
				battle.change_stat_stage(target, &"SPECIAL_ATTACK", -1, user)
			"lower_speed":
				battle.change_stat_stage(target, &"SPEED", -1, user)
			"lower_accuracy":
				battle.change_stat_stage(target, &"ACCURACY", -1, user)

	func _effect_here(battle: Battle) -> String:
		if MoveEffectsMiscExtras.SECRET_POWER_TERRAIN.has(battle.field.terrain):
			return MoveEffectsMiscExtras.SECRET_POWER_TERRAIN[battle.field.terrain]
		return MoveEffectsMiscExtras.SECRET_POWER_ENVIRONMENT.get(
			battle.field.environment, MoveEffectsMiscExtras.SECRET_POWER_DEFAULT)

## Court Change, which trades every side effect between the two sides.
class CourtChangeEffect extends MoveEffect:

	func can_be_used(battle: Battle, _user: Battler, _move: MoveData) -> bool:
		return battle.get_side(0).has_swappable_effect() or battle.get_side(1).has_swappable_effect()

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		battle.get_side(0).swap_effects_with(battle.get_side(1))
		battle.announce("%s swapped the battle effects affecting each side of the field!"
			% user.battle_name())
		return true

## Worth exactly the difference between what each side has standing.
	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		var ours: int = _weight(battle.get_side(user.side_index()))
		var theirs: int = _weight(battle.get_side(user.opposing_side_index()))
		if ours == 0 and theirs == 0:
			return AIScores.USELESS
		return base + 8 * (theirs - ours)

## What one side's swappable effects are worth to whoever owns them.
	func _weight(side: BattleSide) -> int:
		var total: int = 0
		for effect: StringName in BattleSide.SWAPPED_BY_COURT_CHANGE:
			if not side.has_effect(effect):
				continue
			match effect:
				BattleEffects.SPIKES, BattleEffects.TOXIC_SPIKES, BattleEffects.STEALTH_ROCK, \
						BattleEffects.STICKY_WEB, BattleEffects.SEA_OF_FIRE, BattleEffects.SWAMP:
					total -= 1
				_:
					total += 1
		return total

## Spite and Eerie Spell, which drain PP from the move the target used last.
class ReducePPEffect extends MoveEffect:
	var _amount: int

	## `true` when running out of PP to take is a failure (Spite)
	var _is_main_effect: bool

	func _init(amount: int, is_main_effect: bool) -> void:
		_amount = amount
		_is_main_effect = is_main_effect

	func succeeds_against(_battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		if not _is_main_effect:
			return true
		return _drainable(target) != null

	func apply_status_move(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		return _drain(battle, target)

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		if damage > 0:
			_drain(battle, target)

	func _drain(battle: Battle, target: Battler) -> bool:
		var drained: PokemonMove = _drainable(target)
		if drained == null:
			return false
		var taken: int = mini(_amount, drained.pp)
		drained.pp -= taken
		var record: MoveData = drained.data()
		battle.announce(Loc.line("It reduced the PP of {target}'s {record} by {taken}!", {"target": target.battle_name(), "record": record.get_translated_name() if record != null else String(drained.id), "taken": taken}))
		return true

	func _drainable(target: Battler) -> PokemonMove:
		var last: PokemonMove = target.get_move(target.last_regular_move_used)
		if last == null or last.pp <= 0 or last.total_pp() <= 0:
			return null
		return last

	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.side_index() == user.side_index():
			return AIScores.USELESS
		var drained: PokemonMove = _drainable(target)
		if drained == null:
			return AIScores.USELESS if _is_main_effect else base
		# Emptying a move outright is worth far more than shaving it.
		return base + (25 if drained.pp <= _amount else 10)

## Electrify, which turns the target's move Electric for the rest of the round.
class ElectrifyEffect extends MoveEffect:

	func succeeds_against(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		if target.has_effect(BattleEffects.ELECTRIFY):
			return false
		return MoveEffectsOrderExtras.has_move_pending(battle, target)

	func failure_is_known_when_choosing() -> bool:
		return false

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.side_index() == user.side_index():
			return AIScores.USELESS
		if target.has_effect(BattleEffects.ELECTRIFY):
			return AIScores.USELESS
		var absorbs: bool = AIBattlerView.effectiveness_of_type_against(
			battle, &"ELECTRIC", user, target) == 0.0
		match user.ability():
			&"VOLTABSORB", &"LIGHTNINGROD", &"MOTORDRIVE":
				absorbs = true
		return base + (40 if absorbs else -20)

	func apply_status_move(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		target.set_effect(BattleEffects.ELECTRIFY, 1)
		battle.announce(Loc.line("{target}'s moves have been electrified!", {"target": target.battle_name()}))
		return true

## Powder, which blows up in the target's face if it tries a Fire move.
class PowderEffect extends MoveEffect:

	func succeeds_against(_battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		return not target.has_effect(BattleEffects.POWDER)

## Only ever does anything to something that was going to use a Fire move
	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.has_effect(BattleEffects.POWDER):
			return AIScores.USELESS
		if target.side_index() == user.side_index():
			return AIScores.USELESS
		if not AIBattlerView.has_damaging_move_of(battle, target, &"FIRE"):
			return AIScores.USELESS
		return base + 30

	func apply_status_move(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		target.set_effect(BattleEffects.POWDER, 1)
		battle.announce(Loc.line("{target} is covered in powder!", {"target": target.battle_name()}))
		return true

## Conversion 2, which turns the user into a type that resists whatever the target last attacked with.
class Conversion2Effect extends MoveEffect:

	func succeeds_against(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		return not _resisting_types(user, target).is_empty()

## Only worth using once the target has shown what it attacks with, which is what the resisting types are worked out from.
	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or _resisting_types(user, target).is_empty():
			return AIScores.USELESS
		return base + 15

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		var options: Array[StringName] = _resisting_types(user, target)
		if options.is_empty():
			return false
		var chosen: StringName = options[RNG.below(options.size())]
		user.type_override = [chosen] as Array[StringName]
		var record: TypeData = Database.type(chosen)
		battle.announce(Loc.line("{pokemon}'s type changed to {record}!", {"pokemon": user.battle_name(), "record": record.get_translated_name() if record != null else String(chosen)}))
		return true

	func _resisting_types(user: Battler, target: Battler) -> Array[StringName]:
		var options: Array[StringName] = []
		var attacked_with: StringName = target.last_move_used_type
		if attacked_with.is_empty() or target.last_move_used.is_empty():
			return options
		for type_id: StringName in Database.get_ids(Database.CATEGORY_TYPES):
			var record: TypeData = Database.type(type_id)
			if record == null or record.pseudo_type or user.has_type(type_id):
				continue
			if record.effectiveness_against_self(attacked_with) < 1.0:
				options.append(type_id)
		return options

## Transform, which turns the user into a copy of the target.
class TransformEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, _move: MoveData) -> bool:
		return not user.is_transformed()

	func succeeds_against(_battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		return not target.is_transformed()

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		user.transform_into(target)
		battle.announce(Loc.line("{pokemon} transformed into {pokemon2}!", {"pokemon": user.battle_name(), "pokemon2": target.display_name()}))
		battle.presenter.refresh_all()
		return true

	func ai_score(_battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or user.is_transformed() or target.is_transformed():
			return AIScores.USELESS
		var gained: int = 0
		for stat: StringName in [&"ATTACK", &"DEFENSE", &"SPECIAL_ATTACK", &"SPECIAL_DEFENSE", &"SPEED"]:
			gained += target.base_stat(stat) - user.base_stat(stat)
		var stages: int = AIBattlerView.positive_stat_stages(target) 			- AIBattlerView.positive_stat_stages(user)
		if user.hp_fraction() < 0.3:
			return AIScores.USELESS
		return base + clampi(gained / 10, -30, 30) + 8 * stages

## Sketch, which replaces itself with the target's last move for good.
class SketchEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, move: MoveData) -> bool:
		return not user.is_transformed() and user.knows_move(move.id)

	func succeeds_against(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		return MoveEffectsMiscExtras.can_be_copied(user, target, MoveCallRules.sketch())

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return AIScores.USELESS
		var copied: MoveData = battle.resolve_move(target.last_regular_move_used)
		if copied == null:
			return AIScores.USELESS
		if not copied.is_damaging():
			return base
		if not user.has_type(copied.type) and copied.power < 60:
			return base
		return base + mini(copied.power / 4, 30)

	func apply_status_move(battle: Battle, user: Battler, target: Battler, move: MoveData) -> bool:
		var learned: StringName = target.last_regular_move_used
		if not MoveEffectsMiscExtras.replace_move(user, move.id, learned, true):
			return false
		var record: MoveData = Database.move(learned)
		battle.announce("%s learned %s!" % [
			user.battle_name(), record.display_name if record != null else String(learned)])
		return true

## Mimic, which borrows the target's last move for the rest of the battle.
class MimicEffect extends MoveEffect:

	func can_be_used(_battle: Battle, user: Battler, move: MoveData) -> bool:
		return not user.is_transformed() and user.knows_move(move.id)

	func succeeds_against(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		return MoveEffectsMiscExtras.can_be_copied(user, target, MoveCallRules.mimic())

	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null:
			return AIScores.USELESS
		var copied: MoveData = battle.resolve_move(target.last_regular_move_used)
		if copied == null:
			return AIScores.USELESS
		if not copied.is_damaging():
			return base
		if not user.has_type(copied.type) and copied.power < 60:
			return base
		return base + mini(copied.power / 4, 30)

	func apply_status_move(battle: Battle, user: Battler, target: Battler, move: MoveData) -> bool:
		var learned: StringName = target.last_regular_move_used
		if not MoveEffectsMiscExtras.replace_move(user, move.id, learned, false):
			return false
		var record: MoveData = Database.move(learned)
		battle.announce("%s learned %s!" % [
			user.battle_name(), record.display_name if record != null else String(learned)])
		return true

## Returns `true` when the target's last move is one Sketch or Mimic may take.
static func can_be_copied(user: Battler, target: Battler, blacklist: Dictionary) -> bool:
	var copied: StringName = target.last_regular_move_used
	if copied.is_empty() or user.knows_move(copied):
		return false
	return MoveEffectsCalling.is_callable(copied, blacklist)

## Puts [param learned] into the slot currently holding [param replaced].
static func replace_move(user: Battler, replaced: StringName, learned: StringName, permanent: bool) -> bool:
	if permanent:
		user.move_override.clear()
		for slot: int in range(user.pokemon.moves.size()):
			if user.pokemon.moves[slot].id != replaced:
				continue
			user.pokemon.moves[slot] = PokemonMove.create(learned)
			return true
		return false
	user.detach_moveset()
	for slot: int in range(user.move_override.size()):
		if user.move_override[slot].id != replaced:
			continue
		user.move_override[slot] = PokemonMove.create(learned)
		return true
	return false
