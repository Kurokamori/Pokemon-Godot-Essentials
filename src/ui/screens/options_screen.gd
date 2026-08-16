extends GameScreen
## Player-facing options.
##
## Every setting is an [OptionRow].
## Up and down move between rows; left and right change the selected value.
## Settings are persisted to `user://options.cfg`.

const OPTIONS_PATH: String = "user://options.cfg"

## Follower modes in the order shown by the row.
var _follower_modes: Array[int] = []

## Characters per second for each text-speed choice.
const TEXT_SPEEDS: Array[float] = [20.0, 45.0, 90.0, 999.0]
const DEFAULT_TEXT_SPEED_INDEX: int = 1

## Percentage points between one volume choice and the next.
const VOLUME_STEP: int = 10
const WINDOW_SCALES: Array[int] = [1, 2, 3]
const DEFAULT_WINDOW_SCALE: int = 2
const BASE_WINDOW_SIZE: Vector2i = Vector2i(512, 384)

@onready var _rows_box: VBoxContainer = %Rows
@onready var _text_speed: OptionRow = %TextSpeedRow
@onready var _bgm_volume: OptionRow = %BGMRow
@onready var _se_volume: OptionRow = %SERow
@onready var _default_movement: OptionRow = %DefaultMovementRow
@onready var _send_to_boxes: OptionRow = %SendToBoxesRow
@onready var _give_nicknames: OptionRow = %GiveNicknamesRow
@onready var _followers: OptionRow = %FollowerRow
@onready var _battle_style: OptionRow = %BattleStyleRow
@onready var _battle_effects: OptionRow = %BattleEffectsRow
@onready var _window_scale: OptionRow = %WindowScaleRow
@onready var _language: OptionRow = %LanguageRow
@onready var _menu_frame: OptionRow = %MenuFrameRow
@onready var _speech_frame: OptionRow = %SpeechFrameRow


func _ready() -> void:
	super._ready()
	_build_choices()
	_build_languages()
	_build_followers()
	_build_frames()
	load_options()
	Localization.locale_changed.connect(_on_locale_changed)
	_text_speed.choice_changed.connect(_on_text_speed_changed)
	_bgm_volume.choice_changed.connect(_on_volume_changed)
	_se_volume.choice_changed.connect(_on_volume_changed)
	_default_movement.choice_changed.connect(_on_default_movement_changed)
	_send_to_boxes.choice_changed.connect(_on_send_to_boxes_changed)
	_give_nicknames.choice_changed.connect(_on_give_nicknames_changed)
	_followers.choice_changed.connect(_on_followers_changed)
	_battle_style.choice_changed.connect(_on_battle_style_changed)
	_battle_effects.choice_changed.connect(_on_battle_effects_changed)
	_window_scale.choice_changed.connect(_on_window_scale_changed)
	_language.choice_changed.connect(_on_language_changed)
	_menu_frame.choice_changed.connect(_on_menu_frame_changed)
	_speech_frame.choice_changed.connect(_on_speech_frame_changed)
	_refresh_focus_chain()
	_text_speed.grab_row_focus()
# === Choices ===

## Fills the fixed pickers.
## Kept apart from [method _ready] so language changes can rebuild their labels.
func _build_choices() -> void:
	_text_speed.set_choices(PackedStringArray(Loc.lines(["Slow", "Normal", "Fast", "Instant"])))
	_default_movement.set_choices(PackedStringArray(Loc.lines(["Walking", "Running"])))
	_send_to_boxes.set_choices(PackedStringArray(Loc.lines(["Party", "Boxes"])))
	_give_nicknames.set_choices(PackedStringArray(Loc.lines(["Give", "Don't give"])))
	_battle_style.set_choices(PackedStringArray(Loc.lines(["Switch", "Set"])))
	_battle_effects.set_choices(PackedStringArray(Loc.lines(["On", "Off"])))
	var volumes: PackedStringArray = PackedStringArray()
	for percent: int in range(0, 101, VOLUME_STEP):
		volumes.append("%d%%" % percent)
	_bgm_volume.set_choices(volumes)
	_se_volume.set_choices(volumes)
	var scales: PackedStringArray = PackedStringArray()
	for window_scale: int in WINDOW_SCALES:
		scales.append("%dx" % window_scale)
	_window_scale.set_choices(scales)

## Fills the two frame pickers from the skin's selectable lists.
## Puts each row on the frame currently in use.
func _build_frames() -> void:
	var skin: UISkinData = UITheme.skin
	if skin == null:
		return
	_menu_frame.set_choices(PackedStringArray(skin.menu_windowskin_choices))
	_speech_frame.set_choices(PackedStringArray(skin.speech_windowskin_choices))
	_menu_frame.select(UITheme.menu_windowskin_index())
	_speech_frame.select(UITheme.speech_windowskin_index())
	
# === Language ===

## Fills the language picker with the available translations.
## Each language uses its own name, and the row is hidden when there is only one.
func _build_languages() -> void:
	var locales: Array[StringName] = Localization.available_locales()
	_language.visible = locales.size() > 1
	var names: PackedStringArray = PackedStringArray()
	var current: StringName = Localization.current_locale()
	var current_index: int = 0
	for index: int in range(locales.size()):
		names.append(Localization.display_name_for(locales[index]))
		if locales[index] == current:
			current_index = index
	_language.set_choices(names)
	_language.select(current_index)
	
# === Followers ===

## Fills the follower picker with the available modes.
## The row is hidden when there is only one mode.
func _build_followers() -> void:
	_follower_modes = PokemonFollowerSettings.allowed_modes()
	_followers.visible = _follower_modes.size() > 1
	var labels: PackedStringArray = PackedStringArray()
	for mode: int in _follower_modes:
		labels.append(FollowerMode.label(mode))
	_followers.set_choices(labels)
	_followers.select(maxi(_follower_modes.find(PokemonFollowerSettings.player_mode()), 0))

## Applies the follower mode immediately to the map behind the screen.
func _on_followers_changed(index: int) -> void:
	if index < 0 or index >= _follower_modes.size():
		return
	play_select()
	PokemonFollowerSettings.set_player_mode(_follower_modes[index])
	FieldEffects.refresh_pokemon_followers()

func _on_language_changed(index: int) -> void:
	var locales: Array[StringName] = Localization.available_locales()
	if index < 0 or index >= locales.size():
		return
	play_select()
	Localization.set_locale(locales[index])

## Puts every label this screen writes itself back in the new language. 
## The ones that come from the scene are handled by Godot, which re-translates a [Control] when the locale changes.
func _on_locale_changed(_locale: StringName) -> void:
	_build_choices()
	_build_languages()
	_build_followers()
	_refresh_focus_chain()


# === Settings ===

func _on_text_speed_changed(_index: int) -> void:
	play_select()
	save_options()

## Both volume rows come through here, because the master volumes are read as a pair and the change has to reach whatever is already playing.
func _on_volume_changed(_index: int) -> void:
	GameSettings.data.default_bgm_volume = float(_bgm_volume.selected() * VOLUME_STEP) / 100.0
	GameSettings.data.default_se_volume = float(_se_volume.selected() * VOLUME_STEP) / 100.0
	AudioManager.refresh_volumes()
	play_select()
	save_options()

## Whether the run button walks or runs. 
func _on_default_movement_changed(index: int) -> void:
	GameSettings.data.run_by_default = index == 1
	play_select()
	save_options()

## Whether a caught Pokemon goes to the party or straight to a box.
func _on_send_to_boxes_changed(index: int) -> void:
	GameSettings.data.send_caught_to_boxes = index == 1
	play_select()
	save_options()

func _on_give_nicknames_changed(index: int) -> void:
	GameSettings.data.offer_nicknames = index == 0
	play_select()
	save_options()

func _on_battle_style_changed(_index: int) -> void:
	play_select()
	save_options()

## Turning battle effects off skips move animations
func _on_battle_effects_changed(index: int) -> void:
	GameSettings.data.battle_animations = index == 0
	play_select()
	save_options()

func _on_window_scale_changed(index: int) -> void:
	play_select()
	DisplayServer.window_set_size(BASE_WINDOW_SIZE * WINDOW_SCALES[index])
	save_options()



# === Frames ===

## [UITheme] saves frame choices and rebuilds the theme immediately.
## Re-selects the active frame in case loading fell back to another skin.
func _on_menu_frame_changed(index: int) -> void:
	play_select()
	UITheme.set_menu_windowskin_index(index)
	_menu_frame.select(UITheme.menu_windowskin_index())

func _on_speech_frame_changed(index: int) -> void:
	play_select()
	UITheme.set_speech_windowskin_index(index)
	_speech_frame.select(UITheme.speech_windowskin_index())


# === Focus ===

## Wires visible rows into a wrapped up-and-down focus chain.
func _refresh_focus_chain() -> void:
	var targets: Array[Control] = []
	for child: Node in _rows_box.get_children():
		var row: OptionRow = child as OptionRow
		if row != null and row.visible:
			targets.append(row.focus_target())
	if targets.is_empty():
		return
	for index: int in range(targets.size()):
		var target: Control = targets[index]
		var previous: Control = targets[posmod(index - 1, targets.size())]
		var next: Control = targets[posmod(index + 1, targets.size())]
		target.focus_neighbor_top = target.get_path_to(previous)
		target.focus_neighbor_bottom = target.get_path_to(next)
		target.focus_previous = target.get_path_to(previous)
		target.focus_next = target.get_path_to(next)



# === Persistence ===


func load_options() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(OPTIONS_PATH)
	var default_speed: float = TEXT_SPEEDS[DEFAULT_TEXT_SPEED_INDEX]
	_text_speed.select(_nearest_text_speed(float(config.get_value("display", "text_speed", default_speed))))
	var default_bgm: float = GameSettings.data.default_bgm_volume * 100.0
	var default_se: float = GameSettings.data.default_se_volume * 100.0
	_bgm_volume.select(_volume_index(float(config.get_value("audio", "bgm_volume", default_bgm))))
	_se_volume.select(_volume_index(float(config.get_value("audio", "se_volume", default_se))))
	GameSettings.data.default_bgm_volume = float(_bgm_volume.selected() * VOLUME_STEP) / 100.0
	GameSettings.data.default_se_volume = float(_se_volume.selected() * VOLUME_STEP) / 100.0
	AudioManager.refresh_volumes()
	_battle_style.select(int(config.get_value("battle", "style", 0)))
	_battle_effects.select(int(config.get_value("battle", "effects", 0)))
	GameSettings.data.battle_animations = _battle_effects.selected() == 0
	_window_scale.select(_window_scale_index(int(config.get_value("display", "window_scale", DEFAULT_WINDOW_SCALE))))
	# Preserve project defaults when these options are absent from the file.
	_default_movement.select(
		1 if bool(config.get_value("player", "run_by_default", GameSettings.data.run_by_default)) else 0)
	_send_to_boxes.select(
		1 if bool(config.get_value("player", "send_to_boxes", GameSettings.data.send_caught_to_boxes)) else 0)
	_give_nicknames.select(
		0 if bool(config.get_value("player", "give_nicknames", GameSettings.data.offer_nicknames)) else 1)
	GameSettings.data.run_by_default = _default_movement.selected() == 1
	GameSettings.data.send_caught_to_boxes = _send_to_boxes.selected() == 1
	GameSettings.data.offer_nicknames = _give_nicknames.selected() == 0

## Writes back only the keys this screen owns
func save_options() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(OPTIONS_PATH)
	config.set_value("display", "text_speed", TEXT_SPEEDS[_text_speed.selected()])
	config.set_value("display", "window_scale", WINDOW_SCALES[_window_scale.selected()])
	config.set_value("audio", "bgm_volume", _bgm_volume.selected() * VOLUME_STEP)
	config.set_value("audio", "se_volume", _se_volume.selected() * VOLUME_STEP)
	config.set_value("battle", "style", _battle_style.selected())
	config.set_value("battle", "effects", _battle_effects.selected())
	config.set_value("player", "run_by_default", _default_movement.selected() == 1)
	config.set_value("player", "send_to_boxes", _send_to_boxes.selected() == 1)
	config.set_value("player", "give_nicknames", _give_nicknames.selected() == 0)
	config.save(OPTIONS_PATH)

## The text-speed choice closest to [param speed]
func _nearest_text_speed(speed: float) -> int:
	var best: int = DEFAULT_TEXT_SPEED_INDEX
	var best_distance: float = INF
	for index: int in range(TEXT_SPEEDS.size()):
		var distance: float = absf(TEXT_SPEEDS[index] - speed)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best

func _volume_index(percent: float) -> int:
	return clampi(roundi(percent / float(VOLUME_STEP)), 0, 100 / VOLUME_STEP)

func _window_scale_index(window_scale: int) -> int:
	var index: int = WINDOW_SCALES.find(window_scale)
	return index if index >= 0 else WINDOW_SCALES.find(DEFAULT_WINDOW_SCALE)
