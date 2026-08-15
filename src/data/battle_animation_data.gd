@tool
class_name BattleAnimationData
extends GameDataResource

## One battle animation.
##
## An animation is a list of frames; a frame is a list of cells.
## A cel is one picture drawn somewhere on the screen with zoom, angle, and opacity.
## A cel with a negative pattern is not a picture at all but one of the Pokemon in the battle
## This is how we animate them without animating them seperately
##
## An animation also contains timing, things that ahppen on a given frame rather than being drawn into it.
## A sound may play, the screen or battler flash, or the field shakes.
##
## Cells are stored flat: each frame is a [PackedFloat32Array] holding [constant CEL_FIELDS] number per cell,
## in the order of the `CEL_` constants (instead of storing them as thousands of sub-resources)

## Animation frames a second
const FRAMES_PER_SECOND: float = 20.0

## Fields per cel, also the stride into the frame's array
const CEL_FIELDS: int = 13

const CEL_X: int = 0
const CEL_Y: int = 1
const CEL_ZOOM_X: int = 2
const CEL_ZOOM_Y: int = 3

## Rotation in degrees (ANTI-clockwise)
const CEL_ANGLE: int = 4

## `1` when mirrored
const CEL_MIRROR: int = 5

## Declares which frame of the animation's sheet to draw.
## `PATTERN_USER` and `PATTERN_TARGET` mean the battler sprites instead of the picture
const CEL_PATTERN: int = 6
const CEL_OPACITY: int = 7
const CEL_TONE_RED: int = 8
const CEL_TONE_GREEN: int = 9
const CEL_TONE_BLUE: int = 10

## `0` draws behind the battlers
## All other values in front of them
const CEL_PRIORITY: int = 11

## Which battler the cel's coordinates are measured from;
## See `FOCUS_` constants
const CEL_FOCUS: int = 12

## Pattern value which means 'this cel is the Pokemon using the move'
const PATTERN_USER: int = -1

## Pattern value meaning that `this cel is the Pokemon that is being hit'
const PATTERN_TARGET: int = -2

## Flash scopes
const FLASH_NONE: int = 0
const FLASH_TARGET: int = 1
const FLASH_SCREEN: int = 2
const FLASH_HIDE_TARGET: int = 3
const FLASH_USER: int = 4

const FOCUS_TARGET: int = 1
const FOCUS_USER: int = 2
## Positioned relative to both battlers allowing the cell to stretch between them
const FOCUS_USER_AND_TARGET: int = 3
## Screen coordinates are used instead of battler's postion
const FOCUS_SCREEN: int = 4

## Side size of one square cell on an animation sheet
const CEL_SIZE: int = 192

## Cels per row on a sheet - compatible with RPG Maker
##
## RPG Maker reads a pattern number as `pattern % 5` across and ` pattern / 5` down
const RMXP_SHEET_COLUMNS: int = 5

## Where the animation was authored
## The user stands here in ever cel's coordinates
## [BattleAnimationPlayer] will move it to where the battler really is
const AUTHORED_USER_POSITION: Vector2 = Vector2(128.0, 224.0)
## Similar to AUTHORED_USER_POSTION this is where the target was authored in cel's coordinates
## The target stands here in ever cel
## [BattleAnimationPlayer] will move it to where the target really is
const AUTHORED_TARGET_POSITION: Vector2 = Vector2(384.0, 96.0)

## Name of the sheet in the `battle_animations` asset category
## Omit extension
## Empty when ever cel is a battler rather than a picture
@export var graphic: String = ""

## How many wide in cels this sheet is
## `0` means decide from the sheet
## A sheet laid out to no rule of either kind says so here
@export var sheet_columns: int = 0

## Side size of one cel on this animation's sheet
## `0` means [constant CEL_SIZE]
@export var cel_side: int = 0

## A [PackedFloat32Array] per frame
## Each holds `CEL_FIELDS` number per cel
@export var frames: Array[PackedFloat32Array] = []

@export_group("Sound")
## Frame each sound effect plays on
@export var timing_frames: PackedInt32Array = PackedInt32Array()

## Name of the sound effect played on on the corresponding frame
@export var timing_sounds: PackedStringArray = PackedStringArray()

## Volume (0-100) for the matching sound
@export var timing_volumes: PackedInt32Array = PackedInt32Array()

## Pitch (as a percentage) for matching sound
@export var timing_pitches: PackedInt32Array = PackedInt32Array()

@export_group("Flash")
## Frame each flash begins on
@export var flash_frames: PackedInt32Array = PackedInt32Array()

## What each flash covers (See the `FLASH_` constants)
@export var flash_scopes: PackedInt32Array = PackedInt32Array()

## Colour of each flash.
## The alpha value is how strong the flash is at its peak
## And then it fades to nothing over the flash's duration
@export var flash_colors: PackedColorArray = PackedColorArray()

## How many frames each flash takes to fade away
@export var flash_durations: PackedInt32Array = PackedInt32Array()

@export_group("Shake")
## The frame each shake begins on for this animation
@export var shake_frames: PackedInt32Array = PackedInt32Array()

## How far the field shakes sideways at the crest of each shake (in pixels)
@export var shake_powers: PackedFloat32Array = PackedFloat32Array()

## How fast each shake actually shakes back and forth in swings a second
@export var shake_speeds: PackedFloat32Array = PackedFloat32Array()

## How many frames each shake takes to settle
@export var shake_durations: PackedInt32Array = PackedInt32Array()


## Resolves the side of one cel on this animation's sheet
func cel_side_or_default() -> int:
	return cel_side if cel_side > 0 else CEL_SIZE
	
## How many cels across [param sheet_width] pixels hold (resolved)
func sheet_columns_or_default(sheet_width: int) -> int:
	if sheet_columns > 0:
		return sheet_columns
	if cel_side <= 0:
		return RMXP_SHEET_COLUMNS
	return maxi(sheet_width / cel_side, 1)

## === Counts ===
func sound_count() -> int:
	return timing_frames.size()
	
func flash_count() -> int:
	return flash_frames.size()
	
func shake_count() -> int:
	return shake_frames.size()
	
func frame_count() -> int:
	return frames.size()
	
## Returns `true` when the animation flashes or shakes at all
func has_effects() -> bool:
	return not flash_frames.is_empty() or not shake_frames.is_empty()
	
## The amount of cels [param index] holds
func cel_count(index: int) -> int:
	if index < 0 or index >= frames.size():
		return 0
	return frames[index].size() / CEL_FIELDS
	
## Reads a single field of a single cel
func cel_field(frame_index: int, cel_index: int, field: int) -> float:
	if frame_index < 0 or frame_index >= frames.size():
		return 0.0
	var offset: int = cel_index * CEL_FIELDS + field
	var frame: PackedFloat32Array = frames[frame_index]
	return frame[offset] if offset >= 0 and offset < frame.size() else 0.0
	
## The id for a move that the animation would have,
## [param opposing] picks the variant for opposing side, if the move has it (few do)
static func id_for_move(move_id: StringName, opposing: bool = false) -> StringName:
	return StringName("%s_%s" % ["OPPMOVE" if opposing else "MOVE", move_id])
	
## An id for a shared animation, suhc as &"COMMON_STATUP"
static func id_for_common(name: StringName) -> StringName:
	return String("COMMON_%s" % String(name).to_upper())
