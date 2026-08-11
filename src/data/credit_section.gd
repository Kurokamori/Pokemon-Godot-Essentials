@tool
class_name CreditsSection
extends Resource

## One block of credits roll, a heading and the names under it.
##
## A section can have no heading, which just runs plain lines.

## How names under a heading are laid out.
enum Layout {
	AUTO,
	ONE_PER_LINE,
	TWO_PER_LINE,
}

## Number of entries at which the layout starts pairing them.
const AUTO_PAIR_THRESHOLD: int = 5

## Shown above the entries or blank
@export var heading: String = ""

## The names, one per entry.
## An empty entry is a blank line -- for spacing.
@export var entries: Array[String] = []

## The layout style of the credits section.
@export var layout: Layout = Layout.AUTO

## Blank lines left after this section, before the next heading.
@export_range(0, 8) var blank_lines_after: int = 1

## Whether this section's entries should be drawn two abreast.
func is_paired() -> bool:
	match layout:
		Layout.ONE_PER_LINE:
			return false
		Layout.TWO_PER_LINE:
			return true
		_:
			return entries.size() >= AUTO_PAIR_THRESHOLD
			
## The entries grouped into the rows they are drawn as.
func rows() -> Array[PackedStringArray]:
	var built: Array[PackedStringArray] = []
	if not is_paired():
		for entry: String in entries:
			built.append(PackedStringArray([entry]))
		return built
	var index: int = 0
	while index < entries.size():
		var row: PackedStringArray = PackedStringArray([entries[index]])
		if index + 1 < entries.size():
			row.append(entries[index + 1])
		built.append(row)
		index += 2
	return built
