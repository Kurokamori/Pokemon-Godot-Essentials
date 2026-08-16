class_name MessageCodes
## Converts Pokemon Essentials message codes into a [ParsedMessage].
## The result contains BBCode and playback directives.
## Parsing left to right preserves source order and escaped backslashes.

## Parameterized codes, ordered longest first.
const BRACKETED_CODES: Array[String] = [
	"sign", "wtnp", "ff", "wt", "ts", "me", "se", "ch", "cl", "f", "v", "l", "c", "w", "n",
]

## Parameterless codes, ordered longest first.
const BARE_CODES: Array[String] = [
	"pog", "pn", "pm", "pp", "pg", "pt", "tn", "tp", "te", "tm", "cn", "cl", "op",
	"wu", "wm", "wd", "b", "r", "g", "n",
]

## `\c[n]` colours in Essentials' light-window order.
## Keeps only the main colour from each Essentials pair.
const TEXT_COLOURS: Array[String] = [
	"0070f8", "e82010", "60b048", "48d8d8", "d038b8", "e8d020",
	"a0a0a8", "f0f0f8", "7240e8", "f89818", "505058", "f8f8f8",
]
const DEFAULT_TEXT_COLOUR: String = MessageStyle.DEFAULT_COLOUR

## The colour `\b` switches to.
const MALE_TEXT_COLOUR: String = "3050c8"

## The colour `\r` switches to.
const FEMALE_TEXT_COLOUR: String = "e00808"

## Seconds per character requested by `\ts[n]`.
const TEXT_SPEED_DIVISOR: float = 80.0

## Seconds per unit of `\wt[n]` and `\wtnp[n]`.
const WAIT_UNIT_SECONDS: float = 1.0 / 20.0

## Values available to [method set_context], used by phone dialogue.
const CONTEXT_TRAINER_NAME: StringName = &"trainer_name"
const CONTEXT_TRAINER_POKEMON: StringName = &"trainer_pokemon"
const CONTEXT_WILD_POKEMON: StringName = &"wild_pokemon"
const CONTEXT_TRAINER_MAP: StringName = &"trainer_map"

## Speaker context for `\TN`, `\TP`, `\TE`, and `\TM`.
## Empty during ordinary dialogue.
static var context: Dictionary = {}

## Codes already reported as unknown, so a bad map only warns once.
static var _warned_codes: Dictionary = {}



## Parses [param source] into a [ParsedMessage].
static func parse(source: String) -> ParsedMessage:
	var message: ParsedMessage = ParsedMessage.new()
	var builder: MessageBuilder = MessageBuilder.new(message)
	var index: int = 0
	while index < source.length():
		var character: String = source[index]
		if character == "\\":
			index = _parse_code(source, index, builder)
			continue
		if character == "<":
			var past_tag: int = MessageMarkup.read_tag(source, index, builder)
			if past_tag >= 0:
				index = past_tag
				continue
		elif character == "&":
			var past_entity: int = MessageMarkup.read_entity(source, index, builder)
			if past_entity >= 0:
				index = past_entity
				continue
		builder.append(character)
		index += 1
	builder.finish()
	_resolve_ending(message)
	return message

## Returns visible text with codes and markup removed.
static func plain_text(source: String) -> String:
	return parse(source).plain

## Sets the speaker context for `\TN`, `\TP`, `\TE`, and `\TM`.
## Pass no values to clear the context.
static func set_context(values: Dictionary = {}) -> void:
	context = values

## Reads the code at [param index] and returns the next source index.
## [param index] must point at a backslash.
static func _parse_code(source: String, index: int, builder: MessageBuilder) -> int:
	var rest: String = source.substr(index + 1)
	if rest.is_empty():
		builder.append("\\")
		return index + 1

	var first: String = rest[0]
	match first:
		"\\":
			builder.append("\\")
			return index + 2
		"1", "!":
			builder.add(ParsedMessage.PAUSE)
			return index + 2
		".":
			builder.add(ParsedMessage.WAIT, "", 0.25)
			return index + 2
		"|":
			builder.add(ParsedMessage.WAIT, "", 1.0)
			return index + 2
		"^":
			builder.add(ParsedMessage.WAIT_NO_PAUSE)
			return index + 2
		"[":
			return _parse_literal_colour(rest, index, builder)

	var lower: String = rest.to_lower()
	for code: String in BRACKETED_CODES:
		if not lower.begins_with(code + "["):
			continue
		var close: int = rest.find("]", code.length() + 1)
		if close < 0:
			continue
		var parameter: String = rest.substr(code.length() + 1, close - code.length() - 1)
		_apply_bracketed(code, parameter, builder)
		return index + close + 2

	for code: String in BARE_CODES:
		if not lower.begins_with(code):
			continue
		_apply_bare(code, builder)
		return index + code.length() + 1

	_warn_unknown(first)
	builder.append("\\")
	return index + 1

## Parses a literal colour from `\[........]`.
## Accepts Essentials' packed colour and plain hex formats.
static func _parse_literal_colour(rest: String, index: int, builder: MessageBuilder) -> int:
	var close: int = rest.find("]")
	if close >= 0:
		var value: String = rest.substr(1, close - 1)
		if value.length() == 8 and value.is_valid_hex_number(false):
			builder.set_colour(MessageMarkup.packed_colour(value))
			return index + close + 2
		if value.length() >= 6 and value.is_valid_hex_number(false):
			builder.set_colour(MessageMarkup.rgb_colour(value))
			return index + close + 2
	_warn_unknown("[")
	builder.append("\\")
	return index + 1

static func _apply_bracketed(code: String, parameter: String, builder: MessageBuilder) -> void:
	match code:
		"sign":
			# Match Essentials' animated named-window expansion.
			builder.message.opens_with_animation = true
			builder.message.closes_with_animation = true
			builder.add(ParsedMessage.TEXT_SPEED, "")
			builder.message.windowskin = parameter
		"wtnp":
			var no_pause_wait: float = float(parameter.strip_edges().to_int()) * WAIT_UNIT_SECONDS
			builder.add(ParsedMessage.WAIT_NO_PAUSE, parameter, no_pause_wait)
		"wt":
			var wait: float = float(parameter.strip_edges().to_int()) * WAIT_UNIT_SECONDS
			builder.add(ParsedMessage.WAIT, parameter, wait)
		"ts":
			builder.add(ParsedMessage.TEXT_SPEED, parameter.strip_edges())
		"me":
			builder.add(ParsedMessage.MUSIC_EFFECT, parameter)
		"se":
			builder.add(ParsedMessage.SOUND_EFFECT, parameter)
		"f":
			builder.add(ParsedMessage.FACE, parameter)
		"ff":
			builder.add(ParsedMessage.FACE_CELL, parameter)
		"cl":
			builder.message.closes_with_animation = true
			builder.message.close_sound = parameter
		"ch":
			_apply_choices(parameter, builder.message)
		"v":
			builder.append_text(str(GameState.get_variable(parameter.to_int())))
		"l":
			builder.message.line_count = maxi(parameter.to_int(), 1)
		"c":
			builder.set_colour(colour_for(parameter.to_int()))
		"w":
			builder.message.windowskin = parameter
		"n":
			# Actor-name codes are not used by this project.
			pass

static func _apply_bare(code: String, builder: MessageBuilder) -> void:
	match code:
		"pn":
			builder.append_text(GameState.player.name if GameState.player != null else "")
		"pm":
			builder.append_text(format_money(GameState.player.money if GameState.player != null else 0))
		"pp":
			var lead: Pokemon = GameState.party.first_able() if GameState.party != null else null
			builder.append_text(lead.display_name() if lead != null else "")
		"pg":
			builder.set_colour(MALE_TEXT_COLOUR if _player_is_male() else FEMALE_TEXT_COLOUR)
		"pog":
			builder.set_colour(FEMALE_TEXT_COLOUR if _player_is_male() else MALE_TEXT_COLOUR)
		"tn":
			builder.append_text(_from_context(CONTEXT_TRAINER_NAME))
		"tp":
			builder.append_text(_from_context(CONTEXT_TRAINER_POKEMON))
		"te":
			builder.append_text(_from_context(CONTEXT_WILD_POKEMON))
		"tm":
			builder.append_text(_from_context(CONTEXT_TRAINER_MAP))
		"b":
			builder.set_colour(MALE_TEXT_COLOUR)
		"r":
			builder.set_colour(FEMALE_TEXT_COLOUR)
		"n":
			builder.append("\n")
		"g":
			builder.add(ParsedMessage.GOLD_WINDOW)
		"cn":
			builder.add(ParsedMessage.COINS_WINDOW)
		"pt":
			builder.add(ParsedMessage.BATTLE_POINTS_WINDOW)
		"cl":
			builder.message.closes_with_animation = true
		"op":
			builder.message.opens_with_animation = true
		"wu":
			builder.add(ParsedMessage.WINDOW_TOP)
		"wm":
			builder.add(ParsedMessage.WINDOW_MIDDLE)
		"wd":
			builder.add(ParsedMessage.WINDOW_BOTTOM)

## Parses `\ch[variable,cancel,option,option,...]`.
static func _apply_choices(parameter: String, message: ParsedMessage) -> void:
	var fields: PackedStringArray = split_fields(parameter)
	if fields.size() < 3:
		push_warning("MessageCodes: \\ch needs a variable, a cancel index and at least one option.")
		return
	message.has_choices = true
	message.choice_variable = fields[0].strip_edges().to_int()
	message.choice_cancel = fields[1].strip_edges().to_int()
	for index: int in range(2, fields.size()):
		message.choices.append(fields[index])

## A message ending in `\wtnp` or `\^` closes on its own.
static func _resolve_ending(message: ParsedMessage) -> void:
	for directive: ParsedMessage.Directive in message.directives:
		if directive.code != ParsedMessage.WAIT_NO_PAUSE:
			continue
		if directive.position >= message.character_count():
			message.waits_for_input = false

## Returns the BBCode colour for `\c[n]`.
## Out-of-range values use the default colour.
static func colour_for(index: int) -> String:
	if index < 1 or index > TEXT_COLOURS.size():
		return DEFAULT_TEXT_COLOUR
	return TEXT_COLOURS[index - 1]

## Splits a comma-separated parameter.
## Double quotes allow commas inside an option.
static func split_fields(parameter: String) -> PackedStringArray:
	var fields: PackedStringArray = PackedStringArray()
	var current: String = ""
	var quoted: bool = false
	var index: int = 0
	while index < parameter.length():
		var character: String = parameter[index]
		if character == "\"":
			if quoted and index + 1 < parameter.length() and parameter[index + 1] == "\"":
				current += "\""
				index += 2
				continue
			quoted = not quoted
			index += 1
			continue
		if character == "," and not quoted:
			fields.append(current)
			current = ""
			index += 1
			continue
		current += character
		index += 1
	fields.append(current)
	return fields

## Money as a currency mark and thousands separators.
static func format_money(amount: int) -> String:
	var digits: String = str(absi(amount))
	var grouped: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			grouped += ","
		grouped += digits[index]
	return ("-$" if amount < 0 else "$") + grouped

static func _from_context(key: StringName) -> String:
	return str(context.get(key, ""))

static func _player_is_male() -> bool:
	return GameState.player == null or GameState.player.is_male()

static func _warn_unknown(code: String) -> void:
	if _warned_codes.has(code):
		return
	_warned_codes[code] = true
	push_warning("MessageCodes: unknown control code '\\%s'; showing it as text." % code)
