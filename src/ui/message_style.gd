class_name MessageStyle
extends RefCounted
## How a run of message text is drawn, as one comparable value.

## Fallback colour for text when the theme cannot be read.
const DEFAULT_COLOUR: String = "505058"

## Outline colour used when the theme cannot be read.
const OUTLINE_COLOUR: String = "a0a0a8"

## Pixels of outline `<outln>` and `<outln2>` ask for.
const OUTLINE_THIN: int = 2
const OUTLINE_THICK: int = 4

## Six hex digits, or empty to use the theme's text colour.
var colour: String = ""

## `0`-`255`, as `<o=n>` writes it.
var opacity: int = 255
var bold: bool = false
var italic: bool = false
var underline: bool = false
var strikethrough: bool = false

## A `res://` path, or empty for the theme's font.
var font_path: String = ""

## `0` for the theme's size.
var font_size: int = 0

## Outline width in pixels, `0` for none.
var outline: int = 0


## Returns the skin's colour for unstyled text.
static func default_colour() -> String:
	if UITheme != null and UITheme.skin != null:
		return UITheme.skin.dark_text.to_html(false)
	return DEFAULT_COLOUR

## Returns the skin's text shadow colour used by outline tags.
static func outline_colour() -> String:
	if UITheme != null and UITheme.skin != null:
		return UITheme.skin.dark_text_shadow.to_html(false)
	return OUTLINE_COLOUR

func copy() -> MessageStyle:
	var other: MessageStyle = MessageStyle.new()
	other.colour = colour
	other.opacity = opacity
	other.bold = bold
	other.italic = italic
	other.underline = underline
	other.strikethrough = strikethrough
	other.font_path = font_path
	other.font_size = font_size
	other.outline = outline
	return other

func matches(other: MessageStyle) -> bool:
	if other == null:
		return false
	return (
		colour == other.colour
		and opacity == other.opacity
		and bold == other.bold
		and italic == other.italic
		and underline == other.underline
		and strikethrough == other.strikethrough
		and font_path == other.font_path
		and font_size == other.font_size
		and outline == other.outline
	)

## Returns `true` when this style needs no markup at all, so plain text stays plain.
func is_default() -> bool:
	return matches(MessageStyle.new())

## Returns BBCode that opens this style in the order [method close_tags] unwinds.
func open_tags() -> String:
	var tags: String = ""
	if not font_path.is_empty():
		tags += "[font=%s]" % font_path
	if font_size > 0:
		tags += "[font_size=%d]" % font_size
	if outline > 0:
		tags += "[outline_size=%d][outline_color=#%s]" % [outline, outline_colour()]
	if not colour.is_empty() or opacity < 255:
		tags += "[color=#%s]" % _effective_colour()
	if bold:
		tags += "[b]"
	if italic:
		tags += "[i]"
	if underline:
		tags += "[u]"
	if strikethrough:
		tags += "[s]"
	return tags

func close_tags() -> String:
	var tags: String = ""
	if strikethrough:
		tags += "[/s]"
	if underline:
		tags += "[/u]"
	if italic:
		tags += "[/i]"
	if bold:
		tags += "[/b]"
	if not colour.is_empty() or opacity < 255:
		tags += "[/color]"
	if outline > 0:
		tags += "[/outline_color][/outline_size]"
	if font_size > 0:
		tags += "[/font_size]"
	if not font_path.is_empty():
		tags += "[/font]"
	return tags

## Returns the colour with `<o=n>` folded into its alpha.
##
## Opacity is encoded in the colour because [RichTextLabel] has no opacity tag.
func _effective_colour() -> String:
	var base: String = colour if not colour.is_empty() else default_colour()
	if opacity >= 255:
		return base
	return "%s%02x" % [base, maxi(opacity, 0)]
