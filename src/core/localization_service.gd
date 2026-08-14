extends Node
## Handles localization and displaying the game in the player's chosen language
## 
## Registered as the `Localization` Autoload
## It reads [LocaleManifest] - loads the catalog for one locale in to [TranslationDomain]s, and
## tells [TranslationServer] which language is being played.
## Text itself goes through the helper, [Loc]

## The player's language choice, kept in the options config
const OPTIONS_SECTION: String = "display"
const OPTIONS_KEY: String = "language"

## What is emitted when the catalogs for a new langauge are loaded
## Anything that shows text listens to this and rebuilds on reception
signal locale_changed(locale: StringName)

var _manifest: LocaleManifest = null

## Translations which are currently registerd (as `domain -> Array[Translation]`) so switching
## locale can take back exactly what put it in.
var _loaded: Dictionary = {}

func _ready() -> void:
	_load_manifest()
	var wanted: StringName = _stored_locale()
	if not _manifest.has_locale(wanted):
		wanted = _manifest.source_locale
	_apply_locale(wanted)
	
# === Manifest ===

func _load_manifest() -> void:
	if ResourceLoader.exists(LocaleManifest.MANIFEST_PATH):
		_manifest = ResourceLoader.load(LocaleManifest.MANIFEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as LocaleManifest
	if _manifest == null:
		_manifest = LocaleManifest.new()
		
	## Rereads the manifest and reloads the current catalog
	## Used by the extractor after it has rewritten them so the editor has the new text without a restart
func reload() -> void:
	var current: StringName = current_locale()
	_load_manifest()
	_apply_locale(current if _manifest.has_locale(current) else _manifest.source_locale)
		
	# === Locales ===
	
	## Return the language being played in
func current_locale() -> StringName:
	return StringName(TranslationServer.get_locale())
		
	## The source langauge (the language the game is written in)
func source_locale() -> StringName:
	return _manifest.source_locale
		
## Every available locale the game can be played with, source langauge first
func available_locales() -> Array[StringName]:
	var result: Array[StringName] = []
	for locale: String in _manifest.locales:
		result.append(StringName(locale))
	return result
	
## What a given [param locale] calls itself, for displaying in the language picker
func display_name_for(locale: StringName) -> String:
	return _manifest.display_name_for(locale)
	
## Changes the lanuges and remembers the choice.
## Does nothing if [param locale] has no catalog
func set_locale(locale: StringName) -> void:
	if locale == current_locale():
		return
	if not _manifest.has_locale(locale):
		push_warning("Localization: no catalogs for locale '%s'." % locale)
		return
	_apply_locale(locale)
	_store_locale(locale)

func _apply_locale(locale: StringName) -> void:
	_unload_catalogs()
	TranslationServer.set_locale(String(locale))
	if locale != _manifest.source_locale:
		_load_catalogs(locale)
	locale_changed.emit(locale)
	
# === Catalogs ===

## Loads whatever has been translated into [param locale]
##
## A catalog without compiled translations is quietly skipped
## How many were skipped is reported once
func _load_catalogs(locale: StringName) -> void:
	var untranslated: int = 0
	for catalog: LocaleCatalog in _manifest.catalogs:
		if catalog == null:
			continue
		var path: String = catalog.translation_path_for(locale)
		if path.is_empty() or not ResourceLoader.exists(path):
			untranslated += 1
			continue
		var translation: Translation = ResourceLoader.load(path, "Translation")
		if translation == null:
			push_warning("Localization: %s could not be read as a translation." % path)
			continue
		_add_translation(catalog.domain, translation)
	if untranslated > 0:
		print_verbose("Localization: %d of %d catalogs have nothing in %s yet." % [
			untranslated, _manifest.catalogs.size(), locale,
		])

func _unload_catalogs() -> void:
	for domain: StringName in _loaded:
		for translation: Translation in _loaded[domain]:
			_remove_translation(domain, translation)
	_loaded.clear()
	
## For the main domain, it is reached through [TranslationServer] itself, instead of [TranslationDomain] as this is
## what Godot reads and uses `auto_translate` 
func _add_translation(domain: StringName, translation: Translation) -> void:
	if domain.is_empty():
		TranslationServer.add_translation(translation)
	else: 
		TranslationServer.get_or_add_domain(domain).add_translation(translation)
	if not _loaded.has(domain):
		_loaded[domain] = [] as Array[Translation]
	var registered: Array[Translation] = _loaded[domain]
	registered.append(translation)
	
func _remove_translation(domain: StringName, translation: Translation) -> void:
	if domain.is_empty():
		TranslationServer.remove_translation(translation)
	else:
		TranslationServer.get_or_add_domain(domain).remove_translation(translation)
		
# === Persistance ===

func _stored_locale() -> StringName:
	var config: ConfigFile = ConfigFile.new()
	if config.load(GameSettings.OPTIONS_PATH) != OK:
		return _default_locale()
	var stored: String = String(config.get_value(OPTIONS_SECTION, OPTIONS_KEY, ""))
	return StringName(stored) if not stored.is_empty() else _default_locale()

## The default language the game opens in before the player chooses one
## attepmts their own if the game has a translation for it, otherwise source langauge.
func _default_locale() -> StringName:
	var system: String = OS.get_locale()
	if _manifest.has_locale(StringName(system)):
		return StringName(system)
	var language: String = OS.get_locale_language()
	if _manifest.has_locale(StringName(language)):
		return StringName(language)
	return _manifest.source_locale

## Writes back only this service's key, so the rest of the options file survives.
func _store_locale(locale: StringName) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(GameSettings.OPTIONS_PATH)
	config.set_value(OPTIONS_SECTION, OPTIONS_KEY, String(locale))
	config.save(GameSettings.OPTIONS_PATH)
