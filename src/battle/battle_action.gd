class_name BattleAction
extends RefCounted
## A battler's choice for a round

enum Kind {
	NONE = 0,
	USE_MOVE = 1,
	SWITCH = 2,
	USE_ITEM = 3,
	RUN = 4,
	CALL = 5,
	MEGA_EVOLVE = 6,
	## Not an action at all: a request to go back and choose again for the previuous battler
	CANCEL = 7,
	## A triple battle's Shift: trade places with the ally in the centre
	SHIFT = 8,
	## Safari Zone only: throw bait, so the Pokemon settles down.
	THROW_BAIT = 9,
	## Safari Zone only: throw a rock, so the Pokemon is rattled.
	THROW_ROCK = 10,
}


var kind: Kind = Kind.NONE

## Index of the battler
var battler_index: int = 0

@export_group("Move")
var move: PokemonMove = null

## Battler indices this move is aimed at
## Empty for automatic resolution
var targets: Array[int] = []

@export_group("Switch")
## Party slot to switch to
var switch_to: int = -1

@export_group("Item")
var item: StringName = &""

## Party slot or battler index the item is used on
var item_target: int = -1

## Move index for items such as Ether
var item_move_index: int = -1

## Id of the [BattleGimmick] the battler will use before acting, or empty
## This bundles with the move since all gimics work with an attak on the same turn
var gimmick: StringName = &""

## Priority resolved at the start of the round, so speed ties stay stable.
var resolved_priority: int = 0
var resolved_speed: int = 0

## Sets `true` when the acting battler goes at the back of its priority bracket
var moves_last_in_bracket: bool = false

## Random tiebreaker so equal speed is decided once per round
var speed_tiebreak: int = 0



static func use_move(index: int, chosen_move: PokemonMove, chosen_targets: Array[int] = [], with_gimmick: StringName = &"") -> BattleAction:
	var action: BattleAction = BattleAction.new()
	action.kind = Kind.USE_MOVE
	action.battler_index = index
	action.move = chosen_move
	action.targets = chosen_targets
	action.gimmick = with_gimmick
	return action

static func switch_out(index: int, party_slot: int) -> BattleAction:
	var action: BattleAction = BattleAction.new()
	action.kind = Kind.SWITCH
	action.battler_index = index
	action.switch_to = party_slot
	return action

static func use_item(index: int, item_id: StringName, target: int = -1, move_index: int = -1) -> BattleAction:
	var action: BattleAction = BattleAction.new()
	action.kind = Kind.USE_ITEM
	action.battler_index = index
	action.item = item_id
	action.item_target = target
	action.item_move_index = move_index
	return action

## Trades places with the ally standing in the centre (for triple battles)
static func shift(index: int) -> BattleAction:
	var action: BattleAction = BattleAction.new()
	action.kind = Kind.SHIFT
	action.battler_index = index
	return action

static func throw_bait(index: int) -> BattleAction:
	var action: BattleAction = BattleAction.new()
	action.kind = Kind.THROW_BAIT
	action.battler_index = index
	return action

static func throw_rock(index: int) -> BattleAction:
	var action: BattleAction = BattleAction.new()
	action.kind = Kind.THROW_ROCK
	action.battler_index = index
	return action

## Calls out to a Shadow Pokemon that has lost its temper
static func call_to(index: int) -> BattleAction:
	var action: BattleAction = BattleAction.new()
	action.kind = Kind.CALL
	action.battler_index = index
	return action

static func run(index: int) -> BattleAction:
	var action: BattleAction = BattleAction.new()
	action.kind = Kind.RUN
	action.battler_index = index
	return action

## A request to step back to the previous battler's choice
## Used for double and triple battles 
static func cancel(index: int) -> BattleAction:
	var action: BattleAction = BattleAction.new()
	action.kind = Kind.CANCEL
	action.battler_index = index
	return action

## Returns `true` when taking this action is a whole round action regardless of how many battlers you have
## Running or throwing a pokeball use this
func uses_whole_round() -> bool:
	if kind == Kind.RUN or kind == Kind.THROW_BAIT or kind == Kind.THROW_ROCK:
		return true
	if kind != Kind.USE_ITEM:
		return false
	var record: ItemData = Database.item(item)
	return record != null and record.is_poke_ball()

## Base priority bracket
func base_priority() -> int:
	match kind:
		Kind.SWITCH, Kind.USE_ITEM, Kind.CALL, Kind.RUN, Kind.SHIFT:
			return 6
		Kind.THROW_BAIT, Kind.THROW_ROCK:
			return 6
		Kind.USE_MOVE:
			var record: MoveData = move.data() if move != null else null
			return record.priority if record != null else 0
	return 0
