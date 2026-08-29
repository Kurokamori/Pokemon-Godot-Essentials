class_name MoveEffectsCalling

## The moves whose whole effect is to make another move happen.

## Moves Nature Power turns into under each terrain.
const TERRAIN_MOVES: Dictionary = {
	&"Electric": &"THUNDERBOLT",
	&"Grassy": &"ENERGYBALL",
	&"Misty": &"MOONBLAST",
	&"Psychic": &"PSYCHIC",
}

## Moves Nature Power turns into in each environment when no terrain is up.
const ENVIRONMENT_MOVES: Dictionary = {
	&"Grass": &"ENERGYBALL",
	&"TallGrass": &"ENERGYBALL",
	&"Forest": &"ENERGYBALL",
	&"ForestGrass": &"ENERGYBALL",
	&"MovingWater": &"HYDROPUMP",
	&"StillWater": &"HYDROPUMP",
	&"Underwater": &"HYDROPUMP",
	&"Puddle": &"MUDBOMB",
	&"Cave": &"POWERGEM",
	&"Rock": &"EARTHPOWER",
	&"Sand": &"EARTHPOWER",
	&"Snow": &"ICEBEAM",
	&"Ice": &"ICEBEAM",
	&"Volcano": &"LAVAPLUME",
	&"Graveyard": &"SHADOWBALL",
	&"Sky": &"AIRSLASH",
	&"Space": &"DRACOMETEOR",
	&"UltraSpace": &"PSYSHOCK",
}

## The move Nature Power falls back on when nothing else fits.
const NATURE_POWER_DEFAULT: StringName = &"TRIATTACK"

## How many times Metronome rolls before giving up.
const METRONOME_ATTEMPTS: int = 1000

static func register_all() -> void:
	MoveEffects.register(&"UseRandomMove", MetronomeEffect.new())
	MoveEffects.register(&"UseRandomUserMoveIfAsleep", SleepTalkEffect.new())
	MoveEffects.register(&"UseRandomMoveFromUserParty", AssistEffect.new())
	MoveEffects.register(&"UseLastMoveUsed", CopycatEffect.new())
	MoveEffects.register(&"UseLastMoveUsedByTarget", MirrorMoveEffect.new())
	MoveEffects.register(&"UseMoveTargetIsAboutToUse", MeFirstEffect.new())
	MoveEffects.register(&"UseMoveDependingOnEnvironment", NaturePowerEffect.new())
	MoveEffects.register(&"TargetUsesItsLastUsedMoveAgain", InstructEffect.new())

## Returns `true` when [param move_id] names a move that exists and is not in [param blacklist].
static func is_callable(move_id: StringName, blacklist: Dictionary) -> bool:
	if move_id.is_empty():
		return false
	if not Database.has_record(Database.CATEGORY_MOVES, move_id):
		return false
	var record: MoveData = Database.move(move_id)
	if record == null or record.type == &"SHADOW":
		return false
	return not blacklist.has(record.function_code)

# === Effect Types ==

## Metronome, which rolls a move out of the whole move list.
class MetronomeEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		var blacklist: Dictionary = MoveCallRules.metronome()
		var ids: Array[StringName] = Database.get_ids(Database.CATEGORY_MOVES)
		if ids.is_empty():
			return false
		for _attempt: int in range(MoveEffectsCalling.METRONOME_ATTEMPTS):
			var candidate: StringName = ids[RNG.below(ids.size())]
			var record: MoveData = Database.move(candidate)
			if record == null or record.has_flag(&"CannotMetronome"):
				continue
			if not MoveEffectsCalling.is_callable(candidate, blacklist):
				continue
			battle.announce(Loc.line("Waggling a finger let it use {name}!", {"name": record.get_translated_name()}))
			battle.call_move(user, candidate)
			return true
		return false

## Sleep Talk, which picks one of the user's own moves while it sleeps.
class SleepTalkEffect extends MoveEffect:

	func usable_while_asleep() -> bool:
		return true

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		if not user.is_asleep():
			return false
		var blacklist: Dictionary = MoveCallRules.sleep_talk()
		var candidates: Array[StringName] = []
		for known: PokemonMove in user.moves():
			if known.is_out_of_pp():
				continue
			if MoveEffectsCalling.is_callable(known.id, blacklist):
				candidates.append(known.id)
		if candidates.is_empty():
			return false
		var foes: Array[Battler] = battle.opposing_battlers(user)
		var target_index: int = foes[RNG.below(foes.size())].index if not foes.is_empty() else -1
		battle.call_move(user, candidates[RNG.below(candidates.size())], target_index)
		return true

	## Sleep Talk is useful only while the user is asleep.
	func ai_score(_battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if not user.is_asleep():
			return AIScores.USELESS
		return base + 30

## Assist, which borrows a move from the rest of the user's party.
class AssistEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		var blacklist: Dictionary = MoveCallRules.assist()
		var candidates: Array[StringName] = []
		var party: PokemonParty = battle.get_party(user.side_index())
		for slot: int in range(party.size()):
			if slot == user.party_index:
				continue
			var member: Pokemon = party.get_member(slot)
			if member == null or member.is_egg():
				continue
			for known: PokemonMove in member.moves:
				if MoveEffectsCalling.is_callable(known.id, blacklist):
					candidates.append(known.id)
		if candidates.is_empty():
			return false
		battle.call_move(user, candidates[RNG.below(candidates.size())])
		return true

## A move drawn at random from the rest of the party, so it is worth having only when there is a party
	func ai_score(battle: Battle, user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		var party: PokemonParty = battle.get_party(user.side_index())
		var borrowable: int = 0
		for slot: int in range(party.size()):
			if slot == user.party_index:
				continue
			var member: Pokemon = party.get_member(slot)
			if member != null and not member.is_egg() and not member.moves.is_empty():
				borrowable += 1
		return base if borrowable > 0 else AIScores.USELESS

## Copycat, which repeats whatever move was used last by anyone.
class CopycatEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, _target: Battler, _move: MoveData) -> bool:
		if not MoveEffectsCalling.is_callable(battle.last_move_used_in_battle, MoveCallRules.copycat()):
			return false
		battle.call_move(user, battle.last_move_used_in_battle)
		return true

## Nothing to copy on the first round of a battle, and nothing to copy when the last move used cannot be called.
	func ai_score(battle: Battle, _user: Battler, _target: Battler, _move: MoveData, base: int) -> int:
		if not MoveEffectsCalling.is_callable(battle.last_move_used_in_battle, MoveCallRules.copycat()):
			return AIScores.USELESS
		var copied: MoveData = battle.resolve_move(battle.last_move_used_in_battle)
		if copied == null:
			return AIScores.USELESS
		return base + (20 if copied.is_damaging() else 0)

## Mirror Move, which throws the target's own last move back at it.
class MirrorMoveEffect extends MoveEffect:

	func succeeds_against(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		var record: MoveData = battle.resolve_move(target.last_regular_move_used)
		if record == null or not record.can_be_mirrored():
			failure_message = "The mirror move failed!"
			return false
		return true

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		battle.call_move(user, target.last_regular_move_used, target.index)
		return true

## Me First, which steals the move the target has not used yet and hits harder with it.
class MeFirstEffect extends MoveEffect:

	func succeeds_against(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		if battle.has_acted_this_round(target.index):
			return false
		var action: BattleAction = battle.action_for(target.index)
		if action == null or action.kind != BattleAction.Kind.USE_MOVE or action.move == null:
			return false
		var record: MoveData = action.move.data()
		if record == null or record.is_status():
			return false
		return not MoveCallRules.me_first().has(record.function_code)

	## This depends on the target's unresolved action.
	func failure_is_known_when_choosing() -> bool:
		return false

## Only works on a target that has not acted, so it is worth taking when the user is faster and worth nothing when it is not.
	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or target.side_index() == user.side_index():
			return AIScores.USELESS
		if not AIBattlerView.faster_than(battle, user, target):
			return AIScores.USELESS
		if not AIBattlerView.has_damaging_move(target):
			return AIScores.USELESS
		return base + 20

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		var action: BattleAction = battle.action_for(target.index)
		if action == null or action.move == null:
			return false
		user.set_effect(BattleEffects.ME_FIRST, true)
		battle.call_move(user, action.move.id, target.index)
		return true

## Nature Power, which becomes a move that suits the terrain or the surroundings.
class NaturePowerEffect extends MoveEffect:

	func apply_status_move(battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
		var chosen: StringName = _chosen_move(battle, user)
		var record: MoveData = Database.move(chosen)
		if record == null:
			return false
		battle.announce(Loc.line("Nature Power turned into {name}!", {"name": record.get_translated_name()}))
		battle.call_move(user, chosen, target.index)
		return true

	func _chosen_move(battle: Battle, user: Battler) -> StringName:
		if battle.field.terrain != &"None" and not user.is_airborne():
			var terrain_move: StringName = MoveEffectsCalling.TERRAIN_MOVES.get(battle.field.terrain, &"")
			if Database.move(terrain_move) != null:
				return terrain_move
		var environment_move: StringName = MoveEffectsCalling.ENVIRONMENT_MOVES.get(battle.field.environment, &"")
		if Database.move(environment_move) != null:
			return environment_move
		return MoveEffectsCalling.NATURE_POWER_DEFAULT

## Instruct, which makes the target immediately repeat its last move.
class InstructEffect extends MoveEffect:

	func succeeds_against(battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		var repeated: StringName = target.last_regular_move_used
		if repeated.is_empty() or not target.knows_move(repeated):
			return false
		if target.has_effect(BattleEffects.TWO_TURN_ATTACK) or not target.forced_move_id.is_empty():
			return false
		var known: PokemonMove = target.get_move(repeated)
		if known == null or known.is_out_of_pp():
			return false
		var pending: BattleAction = battle.action_for(target.index)
		if pending != null and pending.move != null:
			var pending_record: MoveData = pending.move.data()
			if pending_record != null and MoveCallRules.FOCUSSING.has(pending_record.function_code):
				return false
		return MoveEffectsCalling.is_callable(repeated, MoveCallRules.instruct())

## A free extra move for an ally, and a free extra move for a foe if it is pointed the wrong way.
	func ai_score(battle: Battle, user: Battler, target: Battler, _move: MoveData, base: int) -> int:
		if target == null or battle.max_battlers_per_side() < 2:
			return AIScores.USELESS
		if target.side_index() != user.side_index() or target == user:
			return AIScores.USELESS
		var repeated: MoveData = battle.resolve_move(target.last_regular_move_used)
		if repeated == null:
			return AIScores.USELESS
		return base + (25 if repeated.is_damaging() else 0)

	func apply_status_move(_battle: Battle, _user: Battler, target: Battler, _move: MoveData) -> bool:
		target.set_effect(BattleEffects.INSTRUCT, true)
		return true
