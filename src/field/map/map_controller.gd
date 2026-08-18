class_name MapController
extends Node2D

## Manages what map is loaded, the player standing on it, and anything that needs to survive a map change

## Emitted once a map scene is in place and its events are loaded
signal map_loaded(map: GameMap)

## Emitted when a map threshold with no warp or fade is crossed
signal map_crossed(map: GameMap)

## Emitted each time a player finishes a step
signal player_moved(cell: Vector2i)

## Emitted when a wild battle is about to begin.
signal encounter_triggered(wild: Array[Pokemon], encounter_type: StringName)


## Emitted for each line of dialogue
## Answered by message box's [method acknowledge_message]
signal message_requested(text: String)

## Emitted when a choice is offered
signal choices_requested(prompt: String, options: Array, cancel_index: int, default_index: int)

signal message_acknowledged()
signal choice_submitted()


## The field on which the game currently is
## For the [Field] helpers that scripted events use
static var current: MapController = null

@onready var _map_root: MapNeighbourhood = %MapRoot
@onready var _interpreter: EventInterpreter = %Interpreter
@onready var player: PlayerCharacter = %Player

var current_map: GameMap = null
