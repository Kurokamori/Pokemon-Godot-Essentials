extends Node
## Builds the game's [Theme] and manages its application and updating.
## Registered as the `UITheme` Autoload
##
## The theme is assigned to the root [Window]
## Scenes should carry no colours or styleboxes of their own
## Scenes pick a look with `theme_type_variation` instead such as :
## [constant UIThemeBuilder.HEADING_LABEL]

## Emitted after the theme has been rebuilt and reapplied
signal theme_changed()

## Marks a control which this service put a theme on
## Later rebuilds may replace this while a theme set by the scene itself is left alone
const APPLIED_META: StringName = &"ui_theme_applied"

const SKIN_PATH: String = "res://data/ui_skin.tres"

## Player options config setting section
const OPTIONS_SECTION: String = "display"

## The resource by which the look is described
## Editting `res://data/ui_skin.tres` allows you to change it
## The runtime copy also contians the player's windowskin choices
var skin: UISkinData = null

## The built theme, also assigned to the root window
var theme: Theme = null

var _builder: UIThemeBuilder = UIThemeBuilder.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_skin()
	_load_preferences()
	rebuild()
	# The things parented to canvas layers cannot be reached by `window` so we catch it as it enters the tree
	get_tree().node_added.connect(_on_node_added)
	
## For tool use
## Reloads the skin resource from disk and rebuilds
func reload() -> void:
	WindowSkin.clear_cache()
	theme = _builder.build(skin)
	_apply()
	theme_changed.emit()
	
## Rebuilds the theme from the selected or current skin and then applies it to the game
func rebuild() -> void:
	WindowSkin.clear_cache()
	theme = _builder.build(skin)
	_apply()
	theme_changed.emit()
	
## Puts a theme directly into [param node]
## A screen with its own theme doesn't get overwriten
func apply_to(node: Node) -> void:
	var control: Control = node as Control
	if control == null:
		return
	if control.theme != null and not control.has_meta(APPLIED_META):
		return
	control.theme = theme
	control.set_meta(APPLIED_META, true)
	
## Direct read for speech window skin for dialogue
func speech_window_skin() -> WindowSkin:
	return WindowSkin.load_skin(skin.speech_windowskin) if skin != null else null
	
## Direct read for the window skin
func menu_window_skin() -> WindowSkin:
	return WindowSkin.load_skin(skin.menu_windowskin) if skin != null else null
	
## Direct read for the choice window skin
func choice_window_skin() -> WindowSkin:
	return WindowSkin.load_skin(skin.choice_windowskin) if skin != null else null
	
## Direct read for the sign window skin
func sign_window_skin() -> WindowSkin:
	return WindowSkin.load_skin(skin.sign_windowskin) if skin != null else null
	
# === Windowskin Choices ===

## Switches the menu frame and rebuilds
## Returns `false` when the named skin has no art, and does not alter the windowskin
func set_menu_windowskin(skin_name: String) -> bool:
	if skin == null or skin_name == skin.menu_windowskin:
		return skin != null
	if WindowSkin.load_skin(skin_name) == null:
		return false
	skin.menu_windowskin = skin_name
	skin.choice_windowskin = skin_name
	rebuild()
	save_preferences()
	return true

## Switches the dialogue frame and rebuilds
## Returns `false` when the named skin has no art, and does not alter the windowskin
func set_speech_windowskin(skin_name: String) -> bool:
	if skin == null or skin_name == skin.speech_windowskin:
		return skin != null
	if WindowSkin.load_skin(skin_name) == null:
		return false
	skin.speech_windowskin = skin_name
	rebuild()
	save_preferences()
	return true
	
## Selects the window menu frame at [param index] from the selctable list
## Wraps at both ends for the options menu to be able to cylce.
func set_menu_windowskin_index(index: int) -> void:
	if skin == null:
		return
	set_menu_windowskin(skin.menu_windowskin_at(index))
	
## Selects the speech menu frame at [param index] from the selctable list
## Wraps at both ends for the options menu to be able to cylce.
func set_speech_windowskin_index(index: int) -> void:
	if skin == null:
		return
	set_speech_windowskin(skin.speech_windowskin_at(index))
	
## Gets the index of the selcted menu windowskin
func menu_windowskin_index() -> int:
	return skin.menu_windowskin_index() if skin != null else 0
	
## Gets the index for the selected speech windowskin
func speech_windowskin_index() -> int:
	return skin.speech_windowskin_index() if skin != null else 0
	
# === Persistence ===

func save_preferences() -> void:
	if skin == null:
		return
	var config: ConfigFile = ConfigFile.new()
	config.load(GameSettings.OPTIONS_PATH)
	config.set_value(OPTIONS_SECTION, "menu_windowskin", skin.menu_windowskin)
	config.set_value(OPTIONS_SECTION, "speech_windowskin", skin.speech_windowskin)
	config.save(GameSettings.OPTIONS_PATH)
	
func _load_preferences() -> void:
	if skin == null:
		return
	var config: ConfigFile = ConfigFile.new()
	if config.load(GameSettings.OPTION_PATH) != OK:
		return
	var menu: String = String(config.get_value(OPTIONS_SECTION, "menu_windowskin", skin.menu_windowskin))
	var speech: String = String(config.get_value(OPTIONS_SECTION, "speech_windowskin", skin.speech_windowskin))
	if Assets.exists(AssetIndex.CATEGORY_WINDOWSKINS, menu):
		skin.menu_windowskin = menu
		skin.choice_windowskin = menu
	if Assets.exists(AssetIndex.CATEGORY_WINDOWSKINS, speech):
		skin.speech_windowskin = speech
		
	# === Internals ===
	
## Loads a skin resource
## The runtime copy is a duplicate allowing for the player's frame choices to never write to game
func _load_skin() -> void:
	if ResourceLoader.exists(SKIN_PATH):
		var stored: UISkinData = ResourceLoader.load(SKIN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as UISkinData
		if stored != null:
			skin = stored.duplicate(true) as UISkinData
			return
		skin = UISkinData.new()
		push_warning("UITheme: The UISkin at %s was not found, using the built in defaults" % SKIN_PATH)

## Adds the theme to the window root		
func _apply() -> void:
	var root: Window = get_tree().root
	if root == null:
		return
	root.theme = theme
	_apply_below_canvas_layers(root)
	
## Walks the tree and hands the theme to every control that is under a [CanvasLayer] since they don't naturally inherit from root
func _apply_below_canvas_layers(node: Node) -> void:
	for child: Node in node.get_children():
		if node is CanvasLayer and child is Control:
			apply_to(child)
		_apply_below_canvas_layers(child)
		
func _on_node_added(node: Node) -> void:
	if node is Control and node.get_parent() is CanvasLayer:
		apply_to(node)
