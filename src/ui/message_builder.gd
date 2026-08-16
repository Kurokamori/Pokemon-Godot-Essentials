class_name MessageBuilder
extends RefCounted
## Builds BBCode, plain text, and directives for a [ParsedMessage].
## Styles use a stack so overlapping markup stays balanced.
## Lines are buffered to keep BBCode paragraphs separate from text newlines.
## [member ParsedMessage.plain] matches the label's character count.

## Line alignments, in the order Essentials' `alignstack` uses.
const ALIGN_NONE: int = -1
const ALIGN_LEFT: int = 0
const ALIGN_RIGHT: int = 1
const ALIGN_CENTRE: int = 2

## Placeholder used for an inline image in plain text.
const IMAGE_PLACEHOLDER: String = " "

var message: ParsedMessage = null

## Style stack; the bottom entry is the message's base style.
var _styles: Array[MessageStyle] = []
## Style used by the currently open BBCode span, or `null`.
var _emitted: MessageStyle = null

## BBCode of the line being built, before its alignment wrapper goes on.
var _line: String = ""
## `"\n"` when this line has to be separated from the one above by a character.
var _line_separator: String = ""
## Whether the current line has started and its separator is fixed.
var _line_started: bool = false
## `true` before the first line, which needs no separator.
var _first_line: bool = true

## Alignments opened by `<ac>`, `<ar>` and `<al>` and not yet closed.
var _alignment_stack: Array[int] = []
## Alignment of the line being built.
##
## Captured when the line starts.
## This preserves `<ac>text</ac>` and line-only `<r>` behavior.
var _line_align: int = ALIGN_NONE


func _init(target: ParsedMessage) -> void:
	message = target
	_styles.append(MessageStyle.new())

# === Styles ===

## Returns the style used for new text.
func style() -> MessageStyle:
	return _styles[_styles.size() - 1]

## Opens a style scope and returns a copy to modify.
func push_style() -> MessageStyle:
	var copy: MessageStyle = style().copy()
	_styles.append(copy)
	return copy

## Closes the innermost style scope, ignoring unmatched closers.
func pop_style() -> void:
	if _styles.size() > 1:
		_styles.remove_at(_styles.size() - 1)

## Changes the colour for all following text.
## The colour is written into every open style scope.
func set_colour(hex: String) -> void:
	for entry: MessageStyle in _styles:
		entry.colour = hex

# === Text ===

## Adds one display character, escaping `[` so it is not read as BBCode.
func append(character: String) -> void:
	if character == "\n":
		_begin_line()
		_flush_line()
		return
	_sync_style()
	message.plain += character
	_line += "[lb]" if character == "[" else character

func append_text(text: String) -> void:
	for index: int in range(text.length()):
		append(text[index])

## Adds an inline image, as `<icon=...>` and `<img=...>` ask for.
## [param region] selects part of the source image; an empty one uses all of it.
func append_image(path: String, region: Rect2i = Rect2i()) -> void:
	_sync_style()
	message.plain += IMAGE_PLACEHOLDER
	if region.size.x > 0 and region.size.y > 0:
		_line += "[img region=%d,%d,%d,%d]%s[/img]" % [
			region.position.x, region.position.y, region.size.x, region.size.y, path
		]
	else:
		_line += "[img]%s[/img]" % path

## Records a control code at the point in the text it was read at.
func add(code: StringName, parameter: String = "", seconds: float = 0.0) -> void:
	message.directives.append(
		ParsedMessage.Directive.new(code, message.plain.length(), parameter, seconds)
	)

# === Alignment ===

## Opens a line alignment.
## Mid-line alignment starts a new line.
func push_alignment(value: int) -> void:
	if not _line.is_empty():
		_flush_line()
	_alignment_stack.append(value)
	_line_align = value

## Closes the innermost alignment; the current line keeps its alignment.
func pop_alignment() -> void:
	if not _alignment_stack.is_empty():
		_alignment_stack.remove_at(_alignment_stack.size() - 1)

## Aligns only the rest of the current line, as `<r>` requests.
func set_line_alignment(value: int) -> void:
	if not _line.is_empty():
		_flush_line()
	_line_align = value

func finish() -> void:
	if _line_started or not _line.is_empty():
		_flush_line()


# === Internals ===

func _stack_alignment() -> int:
	if _alignment_stack.is_empty():
		return ALIGN_NONE
	return _alignment_stack[_alignment_stack.size() - 1]

## Decides how this line joins the previous one.
## Alignment breaks before its paragraph.
## Closing alignment does not break the next line.
func _begin_line() -> void:
	if _line_started:
		return
	_line_started = true
	_line_align = _stack_alignment()
	if _first_line:
		_first_line = false
		return
	if _line_align != ALIGN_NONE:
		return
	_line_separator = "\n"
	message.plain += "\n"

func _flush_line() -> void:
	_close_span()
	var alignment: int = _line_align
	var opening: String = ""
	var closing: String = ""
	match alignment:
		ALIGN_LEFT:
			opening = "[left]"
			closing = "[/left]"
		ALIGN_RIGHT:
			opening = "[right]"
			closing = "[/right]"
		ALIGN_CENTRE:
			opening = "[center]"
			closing = "[/center]"
	message.bbcode += _line_separator + opening + _line + closing
	_line = ""
	_line_separator = ""
	_line_started = false
	_line_align = ALIGN_NONE

## Makes the open BBCode span match the style on top of the stack.
func _sync_style() -> void:
	_begin_line()
	var current: MessageStyle = style()
	if _emitted != null and _emitted.matches(current):
		return
	_close_span()
	if current.is_default():
		return
	_line += current.open_tags()
	_emitted = current.copy()

func _close_span() -> void:
	if _emitted == null:
		return
	_line += _emitted.close_tags()
	_emitted = null
