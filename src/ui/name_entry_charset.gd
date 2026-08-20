class_name NameEntryCharsets
## Finds the [NameEntryCharsetData] for a language

const DIRECTORY: String = "res://data/name_entry"

## Keyboards already loaded, keyed by locale
static var _cache: Dictionary = {}



## The keyboard for the language being played
static func for_current_locale() -> NameEntryCharsetData:
	return for_locale(StringName(TranslationServer.get_locale()))

## The keyboard for [param locale]
## Or `null` if one couldn't be located
static func for_locale(locale: StringName) -> NameEntryCharsetData:
	if _cache.has(locale):
		return _cache[locale]
	var found: NameEntryCharsetData = null
	for candidate: StringName in _candidates(locale):
		found = _load(candidate)
		if found != null and found.is_usable():
			break
		found = null
	_cache[locale] = found
	return found

## Drops the cache
static func reload() -> void:
	_cache.clear()

## The locales to try, most specific first
static func _candidates(locale: StringName) -> Array[StringName]:
	var wanted: Array[StringName] = [locale]
	var language: String = String(locale).split("_")[0]
	if language != String(locale):
		wanted.append(StringName(language))
	var source: StringName = Localization.source_locale()
	if not wanted.has(source):
		wanted.append(source)
	return wanted

static func _load(locale: StringName) -> NameEntryCharsetData:
	var path: String = "%s/%s.tres" % [DIRECTORY, locale]
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "") as NameEntryCharsetData
