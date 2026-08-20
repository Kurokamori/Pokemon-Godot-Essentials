class_name PurifyChamberRules
## The actual shape of the purification -- extracted as its own class to avoid circular references.

## Sets the chamber holds.
const SET_COUNT: int = 9

## Ordinary Pokemon that fit in one set's ring
const SET_SIZE: int = 4


## The best tempo a set can reach, which is what a demanding species is measured against
static func maximum_tempo() -> int:
	var width: int = SET_SIZE + 1
	return (((width * width) + width) / 2) - 1
