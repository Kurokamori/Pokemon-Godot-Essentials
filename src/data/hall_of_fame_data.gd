@tool
class_name HallOfFameData
extends Resource

## The Hall of Fame ceremony, as data.
##
## The [HallOfFameScreen] will play this.
## It brings the team in one at a time, names each of them, and welcomes the player, finishing on their trainer card.
## What is said, how long each beat lasts, where teh team stands, and what plays behind it, are all fields here.
## A project changes its ceremony by editting the hall_of_fame.tres rather than the screen.

## Where the team stands during the ceremony.
enum Layout {
	## Two rows of three, the way Gen 3 did it.
	TWO_ROWS,
	## A single line across the screen, stepping up towards the back.
	ONE_ROW,
}

@export_group("Staging")
## Layout type, either two rows (Gen 3) or a single cascading row.
@export var layout: Layout = Layout.TWO_ROWS

## Background behind the ceremony, from `assets/graphics/ui/`.
@export var background_graphic: String = "Hall of Fame/bg"

## Bars laid over the background, from `assets/graphics/ui/`.
## Leave empty for a plain background.
@export var bars_graphic: String = "Hall of Fame/bars"

## How faded a Pokemon is when the spotlight is no longer on it. From 0 to 1.
@export_range(0.0, 1.0, 0.05) var dimmed_opacity: float = 0.25

## Whether or not hide the bars for the trainer reveal
@export var hides_bars_for_trainer: bool = true


@export_group("Timing")
## Seconds a pokemon takes to slide in from off screen.
@export_range(0.0, 10.0, 0.1) var appear_seconds: float = 3.0

## Seconds each Pokemon is held in the spotlight and its details are up.
@export_range(0.0, 10.0, 0.1) var entry_seconds: float = 3.0

## Seconds the welcome line is held up for.
@export_range(0.0, 10.0, 0.1) var welcome_seconds: float = 4.0

## Seconds the closing fade takes.
@export_range(0.0, 5.0, 0.1) var final_fade_seconds: float = 1.0

## Whether the team slides on.
## Off, they are simply there.
@export var animates_entrance: bool = true


@export_group("Words")
## Shown once the whole team is on screen.
@export var welcome_line: String = "Welcome to the Hall of Fame!"

## Shown over the trainer card when shown at the end, left empty there is no message.
@export_multiline var closing_line: String = "League champion!\nCongratulations!"

## Heading over the induction number on the viewer.
@export var entry_number_label: String = "Hall of Fame No."


@export_group("Records")
## How many teams a save keeps.
## `0` holds the ceremony but doesn't record anything.
## `-1` keep all of them.
## A large number is kinder to the save file than no limit at all.
@export var entry_limit: int = 50

## Whether an egg in the party is shown and recorded with the rest of the team.
@export var records_eggs: bool = true


@export_group("Audio")
## Track which is played over the ceremony.
## From `assets/audio/bgm/`
## Left empty, whatever was playing continues to play.
@export var music: String = "Hall of Fame"

## Whether the track that was playing before comes back afterwards.
@export var restores_previous_music: bool = true
