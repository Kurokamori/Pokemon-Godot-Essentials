extends Node
## Loads the game setting resource and exposes it as the GameSettings autoload
##
## A default is created when the file is missing

const SETTINGS_PATH: String = "res://data/game_settings.tres"

## Where the options for a player are actually written
const OPTIONS_PATH: String = "user://options.cfg"

const OPTIONS_SECTION: String = "player"
const AUDIO_SECTION: String = "audio"

## What is emitted when [method reload] swaps to a different settings resource
signal settings_changed()

var data: GameSettingsData = null

func _ready() -> void:
	reload()
	
func reload() -> void:
	if ResourceLoader.exists(SETTINGS_PATH):
		data = ResourceLoader.load(SETTINGS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameSettingsData
	if data == null:
		data = GameSettingsData.new()
		push_warning("GameSettings: The game settings file at: %s was not found, using built-in defaults" % SETTINGS_PATH)
	_apply_player_options()
	_apply_window_title()
	settings_changed.emit()

## Names the game window whatever the GameSettingsData declares as the game name.
## Skipped by the editor -- empty leaves the project.godot setting.
func _apply_window_title() -> void:
	if Engine.is_editor_hint() or data.game_title.strip_edges().is_empty():
		return
	DisplayServer.window_set_title(data.game_title)
	
## Applies the player's chosen settings over the project defaults.
## This has to happen at boot so that it takes effect immediately.
## The rest of the settings are applied on call when whoever needs them is initialized,
## such as [MessageBox] taking text speed or [UIThemeService] for the frames
func _apply_player_options() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(OPTIONS_PATH) != OK:
		return
	data.run_by_default = bool(
		config.get_value(OPTIONS_SECTION, "run_by_default", data.run_by_default)
	)
	data.send_caught_to_boxes = bool(
		config.get_value(OPTIONS_SECTION, "send_to_boxes", data.send_caught_to_boxes)
	)
	data.offer_nickname = bool(
		config.get_value(OPTIONS_SECTION, "give_nicknames", data.offer_nickname)
	)
	data.default_bgm_volume = clampf(float(
		config.get_value(AUDIO_SECTION, "bgm_volume", data.default_bgm_volume * 100.0)) / 100.00, 0.0, 1.0
	)
	data.default_se_volume = clampf(float(
	config.get_value(AUDIO_SECTION, "se_volume", data.default_se_volume * 100.00)) / 100.00, 0.0, 1.0	
	)	
	_apply_follower_mode(config)
	KeyBindings.load_from(config)

## Gets the player follower mode from [param config]
## It is saved by name rather than number, and rejects now illegal options
func _apply_follower_mode(config: ConfigFile) -> void:
	var written: String = String(
		config.get_value(OPTIONS_SECTION, FollowerMode.OPTIONS_KEY, "")
	)
	if written.is_empty():
		return
	var chosen: int = FollowerMode.from_name(written)
	if chosen < 0:
		return
	if not data.follower_allowed_modes.is_empty() and not data.follower_allowed_modes.has(chosen):
		return
	data.follower_mode = chosen as FollowerMode.Mode
	
## Writes back the player's keybindings, and writes on change
func save_key_bindings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(OPTIONS_PATH)
	KeyBindings.save_into(config)
	config.save(OPTIONS_PATH)
