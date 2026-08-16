class_name ParsedMessage
extends RefCounted
## Message after it's been expanded and parsed
## [member bbc_code] is the version with formatting
## [member plain] is the version with only the text (for the typewriter)
## Everything that was in the source and wasn't simple text becomes a [Directive]

## Waits [member.Directive.seconds]
const WAIT: StringName = &"wait"

## Waits [member.Directive.seconds] and then closes without awaiting the palyer
const WAIT_NO_PAUSE: StringName = &"wait_no_pause"

## Stops and waits for the player's input
const PAUSE: StringName = &"pause"

## Manages the 'typing' speed
## Empty reveals the text instantly
const TEXT_SPEED: StringName = &"text_speed"
const SOUND_EFFECT: StringName = &"sound_effect"
const MUSIC_EFFECT: StringName = &"music_effect"

## Shows the whole graphic named by [member Directive.parameter]
## `\f[name]` requests this
const FACE: StringName = &"face"

## Shows one 96x96 frame of a face sheet
## `\ff[name,index]` requests this
## The index defaults to 0 (first position)
const FACE_CELL: StringName = &"face_cell"
const GOLD_WINDOW: StringName = &"gold_window"
const COINS_WINDOW: StringName = &"coin_window"
const BATTLE_POINTS_WINDOW: StringName = &"battle_points_window"

const WINDOW_TOP: StringName = &"window_top"
const WINDOW_MIDDLE: StringName = &"window_middle"
const WINDOW_BOTTOM: StringName = &"window_bottom"

const CANCEL_DISALLOWED: int = 0

## Width and height of one cell of a face sheet
const FACE_CELL_SIZE: int = 96
## How many cells of face sheets sit side by side
const FACE_CELL_COLUMNS: int = 4

## A single control code
## TODO : Should this be its own file? I feel like yes?
class Directive extends RefCounted:
	var code: StringName = &""
	var param: String = ""
	
	## The character position at which this directive is revealed
	var postion: int = 0
	
	## Duration for related codes
	var seconds: float = 0.0
	
	func _init(directive_code: StringName, at: int, value: String = "", duration: float = 0.0) -> void:
		code = directive_code
		param = value
		postion = at
		seconds = duration
		
var bbccode: String = ""
var plain: String = ""
var directives: Array[Directive] = []

## Lines the window needs to be tall enough for, if nothing is passed it remains its configured height
var line_count: int = 0

## Requested Windowskin if there's an override
var windowsking: String = ""

var has_choices: bool = false
var choices: PackedStringArray = PackedStringArray()
var choice_variable: int = 0
## What cancelling the choice does
var choice_cancel: int = CANCEL_DISALLOWED
## Option selected when the choice first opens
var choice_default: int = 0

## Set `false` when the message closes itself
var waits_for_input: bool = true

## Set `true` when the window should slide in instead of just appearing
var opens_with_animation: bool = false

## Set `true` when the window should slide out instead of just disapearing
var closes_with_animation: bool = false

## Sound effect played by `\cl[name]` when the window slides out
var close_sound: String = ""


func character_count() -> int:
	return plain.length()
