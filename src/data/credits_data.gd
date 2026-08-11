@tool
class_name CreditsData
extends GameDataResource

## The end credits, as data.
##
## [CreditScreen] will roll this.
## Lays out the sections in order, scrolls them past a slideshow of backgrounds, and finishes when the last one scrolls by.
## Everything the author wishes to control is in this data structure.
##
## Adding a name is adding a string to a [CreditsSection].
## Adding a section is adding another resource to [member sections].

@export_group("Roll")
## The blocks of the roll, in the order they scroll by.
@export var sections: Array[CreditsSection] = []

## Pixels a second the roll travels at.
@export_range(4.0, 240.0, 1.0) var scroll_speed: float = 40.0

## Height of one line, which also the height of a blank one.
## Headings and names are drawn by the theme so this only declares the spacing.
@export_range(8, 64) var line_height: int = 24

## Blank lines left at the top and bottom of the roll, so it starts and ends off screen.
@export_range(0, 32) var padding_lines: int = 4

@export_group("Scenery")
## Backdrops shown behind the roll, from `assets/graphics/titles/` changing one after another and restarting.
## Leave blank for no backdrop.
@export var backgrounds: Array[String] = []

## Seconds each background is up before the enxt fades in.
@export_range(1.0, 60.0, 0.5) var seconds_per_background: float = 11.0

## Seconds one backdrop takes to fade into the next.
@export_range(0.0, 5.0, 0.1) var background_fade_seconds: float = 1.0

## How much the backdrops are darkened.
@export_range(0.0, 1.0, 0.05) var backdrop_dim: float = 0.35

@export_group("Audio")
## Track played during credits scene -- from `assets/audio/bgm/`
## Left empty whatever was already playing plays on.
@export var music: String = "Credits"

## Whether the track that was playing before comes back afterwards.
@export var restore_previous_music: bool = true

@export_group("Skipping")
## Whether the roll can be cut short the first time it's watched.
## The main games require it, here we offer the option to not.
@export var skippable_on_first_play: bool = false

## Every row of the roll in order -- which builds the labels in the scene.
const ROW_HEADING: StringName = &"heading"
const ROW_LINE: StringName = &"line"
const ROW_PAIR: StringName = &"pair"
const ROW_BLANK: StringName = &"blank"

func build_rows() -> Array[Array]:
	var rows: Array[Array] = []
	for section: CreditsSection in sections:
		if section in sections:
			if section == null:
				continue
			if not section.heading.is_empty():
				rows.append([ROW_HEADING, section.heading, ""])
		for row: PackedStringArray in section.rows():
			if row.size() >= 2:
				rows.append([ROW_PAIR, row[0], row[1]])
			elif row[0].strip_edges().is_empty():
				rows.append([ROW_BLANK, "", ""])
			else:
				rows.append([ROW_LINE, row[0], ""])
		for _blank: int in range(section.blank_lines_after):
			rows.append([ROW_BLANK, "", ""])
	return rows
