class_name MessageMarkup
## The angle-bracket formatting tags Essentials draws message text with.
##
## Reads Essentials' angle-bracket formatting tags after [MessageCodes].
## Style tags map through [MessageStyle]; alignment, breaks, and images are handled directly.

## Tags that change text appearance, ordered longest first.
const STYLE_TAGS: PackedStringArray = [
	"c3", "c2", "outln2", "outln", "c", "o", "fn", "fs", "i", "b", "u", "s",
]

## Tags that align the line they are on, and the alignment each asks for.
const ALIGNMENT_TAGS: Dictionary = {
	"al": MessageBuilder.ALIGN_LEFT,
	"ar": MessageBuilder.ALIGN_RIGHT,
	"ac": MessageBuilder.ALIGN_CENTRE,
}

## Recognized tags that produce no additional output.
const IGNORED_TAGS: PackedStringArray = ["pg", "pog"]

## Where an `<img=Graphics/Folder/name>` path looks up
const IMAGE_FOLDERS: Dictionary = {
	"icons": AssetIndex.CATEGORY_ICONS,
	"pictures": AssetIndex.CATEGORY_PICTURES,
	"items": AssetIndex.CATEGORY_ITEMS,
	"characters": AssetIndex.CATEGORY_CHARACTERS,
	"trainers": AssetIndex.CATEGORY_TRAINERS,
	"battlebacks": AssetIndex.CATEGORY_BATTLEBACKS,
	"panoramas": AssetIndex.CATEGORY_PANORAMAS,
	"fogs": AssetIndex.CATEGORY_FOGS,
	"titles": AssetIndex.CATEGORY_TITLES,
	"windowskins": AssetIndex.CATEGORY_WINDOWSKINS,
	"system": AssetIndex.CATEGORY_UI,
	"ui": AssetIndex.CATEGORY_UI,
}

## Folders an `<img=name>` with no folder of its own is looked for in.
const IMAGE_FALLBACK_CATEGORIES: Array[StringName] = [
	AssetIndex.CATEGORY_PICTURES, AssetIndex.CATEGORY_ICONS, AssetIndex.CATEGORY_UI,
]

## Where `<fn=name>` looks for a font, and the extensions it tries.
const FONT_FOLDER: String = "res://assets/fonts/"
const FONT_EXTENSIONS: PackedStringArray = [".ttf", ".otf", ".fnt", ".woff2", ".woff"]

## The named characters Essentials' `fmtReplaceEscapes` understands.
const ENTITIES: Dictionary = {
	"lt": "<", "gt": ">", "apos": "'", "quot": "\"", "amp": "&", "m": "♂", "f": "♀",
}

static var _tag_pattern: RegEx = null

## Tags and fonts already reported, so a bad map only warns once.
static var _warned: Dictionary = {}

## Font paths already resolved, since a tag may repeat on every line.
static var _font_paths: Dictionary = {}



## Reads a tag at [param index] and returns the next index, or `-1` when invalid.
static func read_tag(source: String, index: int, builder: MessageBuilder) -> int:
	var found: RegExMatch = _pattern().search(source, index)
	if found == null or found.get_start() != index:
		return -1
	var closing: bool = found.get_string(1) == "/"
	var name: String = found.get_string(2).to_lower()
	var parameter: String = found.get_string(3)
	_apply(name, parameter, closing, builder)
	return found.get_end()

## Reads an `&name;` escape at [param index], returning the next index or `-1`.
static func read_entity(source: String, index: int, builder: MessageBuilder) -> int:
	var close: int = source.find(";", index + 1)
	if close < 0 or close - index > 6:
		return -1
	var name: String = source.substr(index + 1, close - index - 1).to_lower()
	if not ENTITIES.has(name):
		return -1
	builder.append_text(String(ENTITIES[name]))
	return close + 1

## Returns `true` when [param text] still contains an unrecognized formatting tag.
static func contains_tag(text: String) -> bool:
	return _pattern().search(text) != null

static func _apply(name: String, parameter: String, closing: bool, builder: MessageBuilder) -> void:
	if ALIGNMENT_TAGS.has(name):
		if closing:
			builder.pop_alignment()
		else:
			builder.push_alignment(int(ALIGNMENT_TAGS[name]))
		return
	if name in IGNORED_TAGS:
		return
	match name:
		"br":
			if not closing:
				builder.append("\n")
			return
		"r":
			if not closing:
				builder.set_line_alignment(MessageBuilder.ALIGN_RIGHT)
			return
		"icon":
			if not closing:
				_append_image(parameter, AssetIndex.CATEGORY_ICONS, builder)
			return
		"img":
			if not closing:
				_append_path_image(parameter, builder)
			return
	if closing:
		builder.pop_style()
		return
	_open_style(name, parameter, builder)


static func _open_style(name: String, parameter: String, builder: MessageBuilder) -> void:
	var style: MessageStyle = builder.push_style()
	match name:
		"b":
			style.bold = true
		"i":
			style.italic = true
		"u":
			style.underline = true
		"s":
			style.strikethrough = true
		"outln":
			style.outline = MessageStyle.OUTLINE_THIN
		"outln2":
			style.outline = MessageStyle.OUTLINE_THICK
		"o":
			style.opacity = clampi(parameter.strip_edges().to_int(), 0, 255)
		"fs":
			style.font_size = maxi(parameter.strip_edges().to_int(), 1)
		"fn":
			style.font_path = _font_path(parameter.strip_edges())
		"c":
			style.colour = rgb_colour(parameter.strip_edges())
		"c2":
			style.colour = packed_colour(parameter.strip_edges())
		"c3":
			# `<c3=main,shadow>`; only the main colour survives the port.
			style.colour = rgb_colour(parameter.split(",")[0].strip_edges())


# === Images ===

static func _append_image(name: String, category: StringName, builder: MessageBuilder) -> void:
	var trimmed: String = name.strip_edges()
	var path: String = Assets.path(category, trimmed)
	if path.is_empty():
		_warn("no image '%s' for an inline graphic" % trimmed)
		return
	builder.append_image(path)

## Reads `<img=path|x|y|width|height>` and resolves its RPG Maker folder.
static func _append_path_image(parameter: String, builder: MessageBuilder) -> void:
	var fields: PackedStringArray = parameter.split("|")
	var path: String = _resolve_image_path(fields[0].strip_edges())
	if path.is_empty():
		_warn("no image '%s' for an inline graphic" % fields[0].strip_edges())
		return
	var region: Rect2i = Rect2i()
	if fields.size() >= 5:
		region = Rect2i(
			fields[1].strip_edges().to_int(), fields[2].strip_edges().to_int(),
			fields[3].strip_edges().to_int(), fields[4].strip_edges().to_int()
		)
	builder.append_image(path, region)

static func _resolve_image_path(raw: String) -> String:
	if raw.begins_with("res://"):
		return raw if ResourceLoader.exists(raw) else ""
	var parts: PackedStringArray = raw.replace("\\", "/").split("/", false)
	if parts.size() >= 2:
		var folder: String = parts[parts.size() - 2].to_lower()
		if IMAGE_FOLDERS.has(folder):
			return Assets.path(IMAGE_FOLDERS[folder], parts[parts.size() - 1])
	var name: String = parts[parts.size() - 1] if parts.size() > 0 else raw
	for category: StringName in IMAGE_FALLBACK_CATEGORIES:
		var path: String = Assets.path(category, name)
		if not path.is_empty():
			return path
	return ""


# === Colour ===

## Six hex digits used by `<c=...>` and each half of `<c3=...>`.
static func rgb_colour(value: String) -> String:
	if value.length() >= 6 and value.substr(0, 6).is_valid_hex_number(false):
		return value.substr(0, 6).to_lower()
	if not value.is_empty():
		_warn("'%s' is not a six-digit colour" % value)
	return ""

## Eight hex digits containing packed main and shadow colours.
## Only the main colour survives, expanded from RPG Maker's five-bit channels.
static func packed_colour(value: String) -> String:
	if value.length() < 4 or not value.substr(0, 4).is_valid_hex_number(false):
		_warn("'%s' is not a packed colour pair" % value)
		return ""
	var packed: int = value.substr(0, 4).hex_to_int()
	var red: int = ((packed >> 10) & 0x1F) * 255 / 31
	var green: int = ((packed >> 5) & 0x1F) * 255 / 31
	var blue: int = (packed & 0x1F) * 255 / 31
	return "%02x%02x%02x" % [red, green, blue]


# === Font ===

## The file `<fn=name>` means.
## Named by file name, so "Power Clear Bold" is `power clear bold.ttf`.
static func _font_path(name: String) -> String:
	if name.is_empty():
		return ""
	var key: String = name.to_lower()
	if _font_paths.has(key):
		return String(_font_paths[key])
	var resolved: String = ""
	for extension: String in FONT_EXTENSIONS:
		var candidate: String = FONT_FOLDER + key + extension
		if ResourceLoader.exists(candidate):
			resolved = candidate
			break
	if resolved.is_empty():
		_warn("no font file for '%s'; keeping the window's own font" % name)
	_font_paths[key] = resolved
	return resolved

# === Internals ===

static func _pattern() -> RegEx:
	if _tag_pattern == null:
		var names: PackedStringArray = PackedStringArray()
		names.append_array(STYLE_TAGS)
		names.append_array(["icon", "img", "ac", "ar", "al", "br", "pog", "pg", "r"])
		_tag_pattern = RegEx.create_from_string(
			"(?i)<(/?)(%s)(?:\\s*=\\s*([^>]*))?>" % "|".join(names)
		)
	return _tag_pattern

static func _warn(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	push_warning("MessageMarkup: %s." % message)
