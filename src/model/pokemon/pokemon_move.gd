@tool
class_name PokemonMove
extends Resource
## A move known by a Pokemon

const MAX_PP_UPS: int = 3

@export var id: StringName = &"":
	set(value):
		id = value
		if _pp_initialised:
			pp = mini(pp, total_pp())

## Number of PP Ups applied
## which raises the maximum PP by 20% of the base each.
@export_range(0, 3) var pp_ups: int = 0

## Remaining PP.
@export var pp: int = 0

## A record used instead of looking [member id] up in the database.
## Z-Moves and Max Moves are built out of the moves they replace and are not stored as a file.
var data_override: MoveData = null

var _pp_initialised: bool = false


static func create(move_id: StringName, applied_pp_ups: int = 0) -> PokemonMove:
	var move: PokemonMove = PokemonMove.new()
	move.id = move_id
	move.pp_ups = applied_pp_ups
	move.pp = move.total_pp()
	move._pp_initialised = true
	return move


## A move that carries its own data instead of in the database.
static func create_from_data(record: MoveData, remaining_pp: int = 1) -> PokemonMove:
	var move: PokemonMove = PokemonMove.new()
	move.data_override = record
	move.id = record.id
	move.pp = remaining_pp
	move._pp_initialised = true
	return move


func data() -> MoveData:
	return data_override if data_override != null else Database.move(id)


## Maximum PP including PP Ups.
func total_pp() -> int:
	var record: MoveData = data()
	if record == null:
		return 0
	var base: int = record.total_pp
	if base == 0:
		return 0
	return base + ((base * pp_ups) / 5)


func restore_pp() -> void:
	pp = total_pp()


## Spends [param amount] PP and never drops below zero.
func use_pp(amount: int = 1) -> void:
	pp = maxi(0, pp - amount)


## Returns `true` if using a pp up would do anything (it's not at its max)
func can_apply_pp_up() -> bool:
	if pp_ups >= MAX_PP_UPS:
		return false
	var record: MoveData = data()
	return record != null and record.total_pp > 0


## Applies a PP Up
## Returns `false` if it can't because a move is maxxed or has no PP to begin with
func apply_pp_up() -> bool:
	if not can_apply_pp_up():
		return false
	var before: int = total_pp()
	pp_ups += 1
	pp += total_pp() - before
	return true


## Sets PP Ups directly to maximum
func apply_pp_max() -> bool:
	if pp_ups >= MAX_PP_UPS:
		return false
	var before: int = total_pp()
	pp_ups = MAX_PP_UPS
	pp += total_pp() - before
	return true


func is_out_of_pp() -> bool:
	return total_pp() > 0 and pp <= 0


func duplicate_move() -> PokemonMove:
	var copy: PokemonMove = PokemonMove.new()
	copy.id = id
	copy.pp_ups = pp_ups
	copy.pp = pp
	copy._pp_initialised = true
	return copy


func to_dict() -> Dictionary:
	return {"id": String(id), "pp": pp, "pp_ups": pp_ups}


static func from_dict(source: Dictionary) -> PokemonMove:
	var move: PokemonMove = PokemonMove.new()
	move.id = StringName(source.get("id", ""))
	move.pp_ups = int(source.get("pp_ups", 0))
	move.pp = int(source.get("pp", 0))
	move._pp_initialised = true
	return move
