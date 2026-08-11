@tool
class_name EncounterTypeData
extends GameDataResource

## One of the ways to meet a wild Pokemon, for example, walking in grass or using a rod.

enum Kind {
	NONE = 0,
	LAND = 1,
	CAVE = 2,
	WATER = 3,
	FISHING = 4,
	CONTEST = 5,
}

@export var kind: Kind = Kind.LAND

## Base percent chance this encounter type will occur per triggering step.
## `0` means this encounter must be requested (such as fishing)
@export_range(0, 100) var trigger_chance: int = 0
