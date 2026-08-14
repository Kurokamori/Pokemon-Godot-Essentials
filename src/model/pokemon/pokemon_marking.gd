class_name PokemonMarkings
## The six markings that a player can put on a Pokemon, mostly for storage sorting
## Stored as a bitmask, allowing for any combination
## [MarkingIcon] draws the shapes
# TODO replace markings with actual graphics probably

enum Mark {
	CIRCLE = 0,
	TRIANGLE = 1,
	SQUARE = 2,
	HEART = 3,
	STAR = 4,
	DIAMOND = 5,
}

const COUNT: int = 6

const NAMES: Array[String] = [
	"Circle", "Triangle", "Square", "Heart", "Star", "Diamond"
]

## Mask with every marking set
## What 'all' means
## [method matches_any]
const ALL: int = (1 << COUNT) - 1


## Returns `true` when [param mask] contains [param mark]
static func has(mask: int, mark: Mark) -> bool:
	return (mask & bit(mark)) != 0

## The single bit [param mark] occupies.
static func bit(mark: Mark) -> int:
	return 1 << int(mark)

## toggles [param mark]
static func toggled(mask: int, mark: Mark) -> int:
	return mask ^ bit(mark)

## Returns `true` if the mask contains *any* marking
static func any(mask: int) -> bool:
	return (mask & ALL) != 0

## Returns `true` when [param mask] contains at least one of [param wanted]'s markings.
## A `wanted` of zero matches everything
static func matches_any(mask: int, wanted: int) -> bool:
	if (wanted & ALL) == 0:
		return true
	return (mask & wanted & ALL) != 0

## The markings [param mask] contains, in [enum Mark]'s order.
static func list(mask: int) -> Array[Mark]:
	var marks: Array[Mark] = []
	for index: int in range(COUNT):
		var mark: Mark = index as Mark
		if has(mask, mark):
			marks.append(mark)
	return marks

## The name of [param mark] translated to the player's language.
static func name_of(mark: Mark) -> String:
	var index: int = int(mark)
	if index < 0 or index >= NAMES.size():
		return ""
	return Loc.line(NAMES[index])

## Drops anything above the six markings in case something else was previously stored here
static func sanitised(mask: int) -> int:
	return mask & ALL
