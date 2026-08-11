@tool
class_name LevelUpMove
extends Resource

## One entry of a species' level-up learnset.

## The level at which the move is learned.
## `0` is a birth move / known from birth.
@export_range(0, 100) var level: int = 1

## Move Name
@export var move: StringName = &""
