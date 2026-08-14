class_name KeyBindings
## Keybinding and Rebinding handeling

# TODO: Add joypad support?

## Where the player's keys are written within the options config
const SECTION: String = "controls"

# TODO: Add left/right/up/down probably
# TODO: Generally expand rebindability and ensure UI uses it properly.

## The actions offered to rebind, in the order they're listed on the screen with their display names
const REBINDABLE: Array = [
	["ui_accept", "Confirm"],
	["ui_cancel", "Cancel"],
	["game_menu", "Menu"],
	["game_run", "Run"],
	["game_special", "Ready Menu"],
	["storage_previous_box", "Previous Box"],
	["storage_next_box", "Next Box"],
]

## The project's default keys, taken once before anything is rebound so that restore default knows what to restore.
static var _defaults: Dictionary = {}

## Getter for the rebindable actions as `[action, label]` pairs
static func rebindable() -> Array:
	return REBINDABLE
	
## The current keyboard key bound to [param action]
## Returns `KEY_NONE` when none
static func key_for(action: StringName) -> Key:
	if not InputMap.has_action(action):
		return KEY_NONE
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.physical_keycode
	return KEY_NONE
	
## What the key bound to the [param action] is actually called, for UI to display
static func key_name_for(action: StringName) -> String:
	var key: Key = key_for(action)
	return OS.get_keycode_string(key) if key != KEY_NONE else "-"
	
## Binds the [param action] to the [param key] -- which replacing any existing keybinding
## Returns false if the key is already bound to an action, so as to not break the game
static func rebind(action: StringName, key: Key) -> bool:
	if not InputMap.has_action(action) or key == KEY_NONE:
		return false
	_remember_defaults()
	var clash: StringName = action_using(key)
	if not clash.is_empty() and clash != action:
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var replacement: InputEventKey = InputEventKey.new()
	replacement.physical_keycode = key
	InputMap.action_add_event(action, replacement)
	return true
	
## The rebindable action already using the [param key] or empty StringName
static func action_using(key: Key) -> StringName:
	for entry: Array in REBINDABLE:
		var action: StringName = StringName(entry[0])
		if key_for(action) == key:
			return action
	return &""
	
## Restores the default keybindings the project is built with
static func restore_defaults() -> void:
	_remember_defaults()
	for entry: Array in REBINDABLE:
		var action: StringName = StringName(entry[0])
		if not _defaults.has(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		for key: Variant in _defaults[action]:
			var restored: InputEventKey = InputEventKey.new()
			restored.physical_keycode = int(key) as Key
			InputMap.action_add_event(action, restored)
			
## Writes the player's chosen keybinds + whatever defaults remain into [param config]
static func save_into(config: ConfigFile) -> void:
	for entry: Array in REBINDABLE:
		var action: StringName = StringName(entry[0])
		config.set_value(SECTION, String(action), int(key_for(action)))
		
## Loads the [param config] saved keybindings.
## Clashing keys are skipped, incase version missmatch causes doubling up
static func load_from(config: ConfigFile) -> void:
	if not config.has_section(SECTION):
		return
	_remember_defaults()
	for entry: Array in REBINDABLE:
		var action: StringName = StringName(entry[0])
		var saved: int = int(config.get_value(SECTION, String(action), int(KEY_NONE)))
		if saved == int(KEY_NONE):
			continue
		rebind(action, saved as Key)
		
## Collects a copy of the project's own key settings.
static func _remember_defaults() -> void:
	if not _defaults.is_empty():
		return
	for entry: Array in REBINDABLE:
		var action: StringName = StringName(entry[0])
		if not InputMap.has_action(action):
			continue
		var keys: Array[int] = []
		for event: InputEvent in InputMap.action_get_events(action):
			var key: InputEventKey = event as InputEventKey
			if key != null:
				keys.append(int(key.physical_keycode))
		_defaults[action] = keys
