class_name UIThemeBuilder
extends RefCounted
## Turns the [UISkinData] into an actual [Theme] that the game can use.
##
## The theme is built instead of being a static .tres file to allow for hotswapping windowskins
## that need to be composited before they're nine-patched.
##
## Alongside standard styles, there are `theme_type_variations` which allow for more control over the visuals.
##
## The Variations are:
## HeadingLabel   MutedLabel    TitleLabel      ValueLabel
## WindowLabel    WindowValue   WindowRichText
## SpeechPanel    ChoicePanel   SignPanel       HeaderPanel
## MenuEntry      ChoiceButton  TabButton       ValueEntry
## HPBar          EXPBar
##
## The `Window` variations are the ones used for text that sits on a window skin instead of a speech skin


## Variation names
const HEADING_LABEL: StringName = &"HeadingLabel"
const MUTED_LABEL: StringName = &"MutedLabel"
const TITLE_LABEL: StringName = &"TitleLabel"
const VALUE_LABEL: StringName = &"ValueLabel"
const WINDOW_LABEL: StringName = &"WindowLabel"
const WINDOW_VALUE: StringName = &"WindowValue"
const WINDOW_RICH_TEXT: StringName = &"WindowRichText"
const SPEECH_PANEL: StringName = &"SpeechPanel"
const CHOICE_PANEL: StringName = &"ChoicePanel"
const SIGN_PANEL: StringName = &"SignPanel"
const HEADER_PANEL: StringName = &"HeaderPanel"
const MENU_ENTRY: StringName = &"MenuEntry"
const CHOICE_BUTTON: StringName = &"ChoiceButton"
const TAB_BUTTON: StringName = &"TabButton"
const VALUE_ENTRY: StringName = &"ValueEntry"
const HP_BAR: StringName = &"HPBar"
const EXP_BAR: StringName = &"EXPBar"

## Padding added inside of a window along with the frame's own margins.
const WINDOW_PADDING: Vector2i = Vector2i(6, 2)

## Padding inside of a menu entry.
const ENTRY_PADDING: Vector2i = Vector2i(8, 3)

## How thick a scroll bar is drawn.
const SCROLL_BAR_THICKNESS: int = 6

var _skin: UISkinData = null
var _theme: Theme = null

## Font and size pairs whose descent has already been corrected this build
## This allows for measuring it to be done once.
var _corrected_fonts: Dictionary = {}



## Builds the theme described by [param skin]. 
## Returns an empty theme if it cannot.
func build(skin: UISkinData) -> Theme:
	_theme = Theme.new()
	_corrected_fonts.clear()
	if skin == null:
		push_warning("UIThemeBuilder: there is no skin resource -- using engine defaults.")
		return _theme
	_skin = skin
	_apply_defaults()
	_build_labels()
	_build_panels()
	_build_buttons()
	_build_rich_text()
	_build_item_list()
	_build_bars()
	_build_inputs()
	_build_separators()
	_build_containers()
	return _theme


# === Defaults ===

func _apply_defaults() -> void:
	if _skin.main_font != null:
		_theme.default_font = _font(_skin.main_font, _skin.font_size)
	_theme.default_font_size = _skin.font_size

## [param font], with room for its descenders at [param size].
func _font(font: Font, size: int) -> Font:
	if font == null:
		return null
	var key: Array = [font.get_instance_id(), size]
	if not _corrected_fonts.has(key):
		_corrected_fonts[key] = true
		FontMetrics.repair_descent(font, size)
	return font


# === Labels ===

func _build_labels() -> void:
	_label_style(&"Label", _skin.main_font, _skin.font_size, _skin.light_text, _skin.light_text_shadow)
	_label_style(HEADING_LABEL, _skin.bold_font, _skin.heading_font_size, _skin.light_text, _skin.light_text_shadow)
	_label_style(TITLE_LABEL, _skin.bold_font, _skin.title_font_size, _skin.light_text, _skin.light_text_shadow)
	_label_style(MUTED_LABEL, _skin.small_font, _skin.small_font_size, _skin.muted_text, Color.TRANSPARENT)
	_label_style(VALUE_LABEL, _skin.narrow_font, _skin.font_size, _skin.light_text, _skin.light_text_shadow)
	_label_style(WINDOW_LABEL, _skin.main_font, _skin.font_size, _skin.dark_text, _skin.dark_text_shadow)
	_label_style(WINDOW_VALUE, _skin.narrow_font, _skin.small_font_size, _skin.dark_text, _skin.dark_text_shadow)
	for variation: StringName in [HEADING_LABEL, TITLE_LABEL, MUTED_LABEL, VALUE_LABEL,
			WINDOW_LABEL, WINDOW_VALUE]:
		_theme.set_type_variation(variation, &"Label")

## Registers one label style. 
## A transparent [param shadow] disables shadow.
func _label_style(type: StringName, font: Font, size: int, colour: Color, shadow: Color) -> void:
	if font != null:
		_theme.set_font(&"font", type, _font(font, size))
	_theme.set_font_size(&"font_size", type, size)
	_theme.set_color(&"font_color", type, colour)
	_theme.set_color(&"font_shadow_color", type, shadow)
	if shadow.a > 0.0:
		_theme.set_constant(&"shadow_offset_x", type, _skin.text_shadow_offset.x)
		_theme.set_constant(&"shadow_offset_y", type, _skin.text_shadow_offset.y)
	_theme.set_constant(&"line_spacing", type, _skin.line_spacing)
	_theme.set_constant(&"outline_size", type, 0)


# === Panels ===

func _build_panels() -> void:
	var menu: StyleBox = _window_style(_skin.menu_windowskin)
	_theme.set_stylebox(&"panel", &"PanelContainer", menu)
	_theme.set_stylebox(&"panel", &"Panel", menu)
	_theme.set_stylebox(&"panel", &"PopupPanel", menu)

	_panel_variation(SPEECH_PANEL, _window_style(_skin.speech_windowskin))
	_panel_variation(CHOICE_PANEL, _window_style(_skin.choice_windowskin))
	_panel_variation(SIGN_PANEL, _window_style(_skin.sign_windowskin))
	_panel_variation(HEADER_PANEL, _header_style())

func _panel_variation(name: StringName, style: StyleBox) -> void:
	_theme.set_type_variation(name, &"PanelContainer")
	_theme.set_stylebox(&"panel", name, style)

## Loads [param skin_name] as a window and returns its stylebox
## Falls back to a flat panel in the skin's color
func _window_style(skin_name: String) -> StyleBox:
	var skin: WindowSkin = WindowSkin.load_skin(skin_name)
	if skin == null:
		push_warning("UIThemeBuilder: windowskin '%s' not found." % skin_name)
		return _fallback_window_style()
	return skin.panel_stylebox_with_padding(WINDOW_PADDING)

func _fallback_window_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("f8f8f8")
	style.border_color = _skin.accent_dark
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _header_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = _skin.accent
	style.border_color = _skin.accent_dark
	style.border_width_bottom = 3
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


# === Buttons ===

func _build_buttons() -> void:
	_button_styles(&"Button", _skin.menu_windowskin, true)
	_theme.set_type_variation(MENU_ENTRY, &"Button")
	_button_styles(MENU_ENTRY, _skin.menu_windowskin, false)
	_theme.set_type_variation(CHOICE_BUTTON, &"Button")
	_button_styles(CHOICE_BUTTON, _skin.choice_windowskin, false)
	_theme.set_type_variation(TAB_BUTTON, &"Button")
	_build_tab_button()
	_theme.set_type_variation(VALUE_ENTRY, &"Button")
	_build_value_entry()


## Styles a button type.
## if [param framed] it draws the window skin as the button's background (for standalone buttons)
## Menu entries however remain transparent and only show selection cursor
func _button_styles(type: StringName, skin_name: String, framed: bool) -> void:
	var skin: WindowSkin = WindowSkin.load_skin(skin_name)
	var normal: StyleBox = null
	if framed:
		if skin != null:
			normal = skin.panel_stylebox_with_padding(Vector2i.ZERO)
		else:
			normal = _fallback_window_style()
	else:
		normal = _entry_style(Color.TRANSPARENT)
	var selected: StyleBox = _selection_style(skin)
	_theme.set_stylebox(&"normal", type, normal)
	_theme.set_stylebox(&"focus", type, selected)
	_theme.set_stylebox(&"hover", type, _entry_style(_skin.hover_fill))
	_theme.set_stylebox(&"pressed", type, _entry_style(_skin.pressed_fill))
	_theme.set_stylebox(&"disabled", type, normal)

	var text_colour: Color = _skin.dark_text if framed or skin != null else _skin.light_text
	var uses_cursor: bool = skin != null and skin.has_cursor()
	var selected_colour: Color = text_colour if uses_cursor else _skin.selected_text
	_theme.set_color(&"font_color", type, text_colour)
	_theme.set_color(&"font_hover_color", type, text_colour)
	_theme.set_color(&"font_focus_color", type, selected_colour)
	_theme.set_color(&"font_pressed_color", type, selected_colour)
	_theme.set_color(&"font_hover_pressed_color", type, selected_colour)
	_theme.set_color(&"font_disabled_color", type, _skin.disabled_text)
	_theme.set_color(&"font_shadow_color", type, _skin.dark_text_shadow)
	_theme.set_constant(&"shadow_offset_x", type, _skin.text_shadow_offset.x)
	_theme.set_constant(&"shadow_offset_y", type, _skin.text_shadow_offset.y)
	_theme.set_constant(&"outline_size", type, 0)
	_theme.set_constant(&"align_to_largest_stylebox", type, 0)
	if _skin.main_font != null:
		_theme.set_font(&"font", type, _font(_skin.main_font, _skin.font_size))
	_theme.set_font_size(&"font_size", type, _skin.font_size)


## The highlight behind the focused entry
## Either the windowskins cursor art or the color
func _selection_style(skin: WindowSkin) -> StyleBox:
	if skin != null and skin.has_cursor():
		var cursor: StyleBoxTexture = skin.cursor_stylebox().duplicate() as StyleBoxTexture
		cursor.content_margin_left = float(ENTRY_PADDING.x)
		cursor.content_margin_right = float(ENTRY_PADDING.x)
		cursor.content_margin_top = float(ENTRY_PADDING.y)
		cursor.content_margin_bottom = float(ENTRY_PADDING.y)
		return cursor
	return _entry_style(_skin.selection_fill, 4)


func _entry_style(fill: Color, corner_radius: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = float(ENTRY_PADDING.x)
	style.content_margin_right = float(ENTRY_PADDING.x)
	style.content_margin_top = float(ENTRY_PADDING.y)
	style.content_margin_bottom = float(ENTRY_PADDING.y)
	return style


## A menu entry that carries a value instead of a command.
func _build_value_entry() -> void:
	_button_styles(VALUE_ENTRY, _skin.menu_windowskin, false)
	if _skin.narrow_font != null:
		_theme.set_font(&"font", VALUE_ENTRY, _font(_skin.narrow_font, _skin.small_font_size))
	_theme.set_font_size(&"font_size", VALUE_ENTRY, _skin.small_font_size)


## Tabs in summary and bag screens
func _build_tab_button() -> void:
	var inactive: StyleBoxFlat = _entry_style(Color(0.0, 0.0, 0.0, 0.25), 4)
	var active: StyleBoxFlat = _entry_style(_skin.accent, 4)
	_theme.set_stylebox(&"normal", TAB_BUTTON, inactive)
	_theme.set_stylebox(&"hover", TAB_BUTTON, _entry_style(_skin.accent_dark, 4))
	_theme.set_stylebox(&"pressed", TAB_BUTTON, active)
	_theme.set_stylebox(&"focus", TAB_BUTTON, active)
	_theme.set_stylebox(&"disabled", TAB_BUTTON, inactive)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_focus_color", &"font_hover_pressed_color"]:
		_theme.set_color(state, TAB_BUTTON, _skin.light_text)
	_theme.set_color(&"font_shadow_color", TAB_BUTTON, _skin.light_text_shadow)
	_theme.set_constant(&"shadow_offset_x", TAB_BUTTON, _skin.text_shadow_offset.x)
	_theme.set_constant(&"shadow_offset_y", TAB_BUTTON, _skin.text_shadow_offset.y)
	if _skin.bold_font != null:
		_theme.set_font(&"font", TAB_BUTTON, _font(_skin.bold_font, _skin.small_font_size))
	_theme.set_font_size(&"font_size", TAB_BUTTON, _skin.small_font_size)


# === Rich Text ===

func _build_rich_text() -> void:
	if _skin.main_font != null:
		_theme.set_font(&"normal_font", &"RichTextLabel", _font(_skin.main_font, _skin.font_size))
	if _skin.bold_font != null:
		_theme.set_font(&"bold_font", &"RichTextLabel", _font(_skin.bold_font, _skin.font_size))
	if _skin.narrow_font != null:
		_theme.set_font(&"mono_font", &"RichTextLabel", _font(_skin.narrow_font, _skin.font_size))
	_theme.set_font_size(&"normal_font_size", &"RichTextLabel", _skin.font_size)
	_theme.set_font_size(&"bold_font_size", &"RichTextLabel", _skin.font_size)
	_theme.set_font_size(&"mono_font_size", &"RichTextLabel", _skin.font_size)
	_theme.set_color(&"default_color", &"RichTextLabel", _skin.light_text)
	_theme.set_color(&"font_shadow_color", &"RichTextLabel", _skin.light_text_shadow)
	_theme.set_constant(&"shadow_offset_x", &"RichTextLabel", _skin.text_shadow_offset.x)
	_theme.set_constant(&"shadow_offset_y", &"RichTextLabel", _skin.text_shadow_offset.y)
	_theme.set_constant(&"shadow_outline_size", &"RichTextLabel", 0)
	_theme.set_constant(&"line_separation", &"RichTextLabel", _skin.line_spacing)
	_theme.set_stylebox(&"normal", &"RichTextLabel", StyleBoxEmpty.new())
	_theme.set_stylebox(&"focus", &"RichTextLabel", StyleBoxEmpty.new())

	_theme.set_type_variation(WINDOW_RICH_TEXT, &"RichTextLabel")
	_theme.set_color(&"default_color", WINDOW_RICH_TEXT, _skin.dark_text)
	_theme.set_color(&"font_shadow_color", WINDOW_RICH_TEXT, _skin.dark_text_shadow)
	_theme.set_constant(&"shadow_offset_x", WINDOW_RICH_TEXT, _skin.text_shadow_offset.x)
	_theme.set_constant(&"shadow_offset_y", WINDOW_RICH_TEXT, _skin.text_shadow_offset.y)
	_theme.set_constant(&"line_separation", WINDOW_RICH_TEXT, _skin.line_spacing)

# === Item List ===

func _build_item_list() -> void:
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.25)
	background.set_corner_radius_all(4)
	background.set_content_margin_all(6.0)
	_theme.set_stylebox(&"panel", &"ItemList", background)
	_theme.set_stylebox(&"focus", &"ItemList", StyleBoxEmpty.new())
	_theme.set_stylebox(&"selected", &"ItemList", _entry_style(_skin.selection_fill.darkened(0.45), 4))
	_theme.set_stylebox(&"selected_focus", &"ItemList", _entry_style(_skin.selection_fill, 4))
	_theme.set_stylebox(&"hovered", &"ItemList", _entry_style(_skin.hover_fill, 4))
	_theme.set_stylebox(&"cursor", &"ItemList", StyleBoxEmpty.new())
	_theme.set_stylebox(&"cursor_unfocused", &"ItemList", StyleBoxEmpty.new())
	_theme.set_color(&"font_color", &"ItemList", _skin.light_text)
	_theme.set_color(&"font_selected_color", &"ItemList", _skin.selected_text)
	_theme.set_color(&"font_hovered_color", &"ItemList", _skin.light_text)
	_theme.set_constant(&"v_separation", &"ItemList", 2)
	_theme.set_constant(&"h_separation", &"ItemList", 4)
	if _skin.main_font != null:
		_theme.set_font(&"font", &"ItemList", _font(_skin.main_font, _skin.small_font_size))
	_theme.set_font_size(&"font_size", &"ItemList", _skin.small_font_size)


# === Bars ===

func _build_bars() -> void:
	_progress_bar(&"ProgressBar", _skin.hp_bar_high)
	_theme.set_type_variation(HP_BAR, &"ProgressBar")
	_progress_bar(HP_BAR, _skin.hp_bar_high)
	_theme.set_type_variation(EXP_BAR, &"ProgressBar")
	_progress_bar(EXP_BAR, _skin.exp_bar)

func _progress_bar(type: StringName, fill: Color) -> void:
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = _skin.bar_background
	background.set_corner_radius_all(_skin.bar_corner_radius)
	var foreground: StyleBoxFlat = StyleBoxFlat.new()
	foreground.bg_color = fill
	foreground.set_corner_radius_all(_skin.bar_corner_radius)
	_theme.set_stylebox(&"background", type, background)
	_theme.set_stylebox(&"fill", type, foreground)
	_theme.set_color(&"font_color", type, _skin.light_text)
	_theme.set_font_size(&"font_size", type, _skin.small_font_size)

# === Inputs ===

func _build_inputs() -> void:
	_build_line_edit()
	_build_slider()
	_build_option_button()
	_build_scroll_container()

func _build_line_edit() -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	normal.border_color = _skin.muted_text
	normal.border_width_bottom = 2
	normal.set_content_margin_all(6.0)
	normal.set_corner_radius_all(3)
	var focused: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focused.border_color = _skin.accent
	_theme.set_stylebox(&"normal", &"LineEdit", normal)
	_theme.set_stylebox(&"focus", &"LineEdit", focused)
	_theme.set_stylebox(&"read_only", &"LineEdit", normal)
	_theme.set_color(&"font_color", &"LineEdit", _skin.light_text)
	_theme.set_color(&"font_placeholder_color", &"LineEdit", _skin.muted_text)
	_theme.set_color(&"caret_color", &"LineEdit", _skin.accent)
	_theme.set_color(&"selection_color", &"LineEdit", _skin.selection_fill)
	if _skin.main_font != null:
		_theme.set_font(&"font", &"LineEdit", _font(_skin.main_font, _skin.font_size))
	_theme.set_font_size(&"font_size", &"LineEdit", _skin.font_size)
	var text_normal: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	text_normal.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	var text_focused: StyleBoxFlat = text_normal.duplicate() as StyleBoxFlat
	text_focused.border_color = _skin.accent
	_theme.set_stylebox(&"normal", &"TextEdit", text_normal)
	_theme.set_stylebox(&"focus", &"TextEdit", text_focused)
	_theme.set_stylebox(&"read_only", &"TextEdit", text_normal)
	_theme.set_color(&"font_color", &"TextEdit", _skin.light_text)
	_theme.set_color(&"font_placeholder_color", &"TextEdit", _skin.muted_text)
	_theme.set_color(&"caret_color", &"TextEdit", _skin.accent)
	_theme.set_color(&"selection_color", &"TextEdit", _skin.selection_fill)
	if _skin.main_font != null:
		_theme.set_font(&"font", &"TextEdit", _font(_skin.main_font, _skin.font_size))
	_theme.set_font_size(&"font_size", &"TextEdit", _skin.font_size)

func _build_slider() -> void:
	for type: StringName in [&"HSlider", &"VSlider"]:
		var track: StyleBoxFlat = StyleBoxFlat.new()
		track.bg_color = _skin.bar_background
		track.set_corner_radius_all(3)
		track.content_margin_top = 3.0
		track.content_margin_bottom = 3.0
		var filled: StyleBoxFlat = track.duplicate() as StyleBoxFlat
		filled.bg_color = _skin.accent
		_theme.set_stylebox(&"slider", type, track)
		_theme.set_stylebox(&"grabber_area", type, filled)
		_theme.set_stylebox(&"grabber_area_highlight", type, filled)
		_theme.set_constant(&"center_grabber", type, 1)

func _build_option_button() -> void:
	_button_styles(&"OptionButton", _skin.menu_windowskin, true)
	_theme.set_stylebox(&"normal", &"MenuButton", _entry_style(Color.TRANSPARENT))
	_theme.set_stylebox(&"panel", &"PopupMenu", _window_style(_skin.menu_windowskin))
	_theme.set_stylebox(&"hover", &"PopupMenu", _entry_style(_skin.selection_fill, 4))
	_theme.set_color(&"font_color", &"PopupMenu", _skin.dark_text)
	_theme.set_color(&"font_hover_color", &"PopupMenu", _skin.dark_text)
	if _skin.main_font != null:
		_theme.set_font(&"font", &"PopupMenu", _font(_skin.main_font, _skin.font_size))
	_theme.set_font_size(&"font_size", &"PopupMenu", _skin.font_size)

func _build_scroll_container() -> void:
	_theme.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = _skin.accent
	grabber.set_corner_radius_all(3)
	grabber.set_content_margin_all(float(SCROLL_BAR_THICKNESS) / 2.0)
	var scroll_track: StyleBoxFlat = StyleBoxFlat.new()
	scroll_track.bg_color = Color(0.0, 0.0, 0.0, 0.25)
	scroll_track.set_corner_radius_all(3)
	scroll_track.set_content_margin_all(float(SCROLL_BAR_THICKNESS) / 2.0)
	for type: StringName in [&"HScrollBar", &"VScrollBar"]:
		_theme.set_stylebox(&"scroll", type, scroll_track)
		_theme.set_stylebox(&"grabber", type, grabber)
		_theme.set_stylebox(&"grabber_highlight", type, grabber)
		_theme.set_stylebox(&"grabber_pressed", type, grabber)


# === Seperators ===

func _build_separators() -> void:
	var line: StyleBoxFlat = StyleBoxFlat.new()
	line.bg_color = Color(_skin.muted_text, 0.5)
	line.content_margin_top = 1.0
	line.content_margin_bottom = 1.0
	_theme.set_stylebox(&"separator", &"HSeparator", line)
	_theme.set_stylebox(&"separator", &"VSeparator", line)
	_theme.set_constant(&"separation", &"HSeparator", 4)
	_theme.set_constant(&"separation", &"VSeparator", 4)

func _build_containers() -> void:
	_theme.set_constant(&"separation", &"VBoxContainer", 4)
	_theme.set_constant(&"separation", &"HBoxContainer", 6)
	_theme.set_constant(&"h_separation", &"GridContainer", 4)
	_theme.set_constant(&"v_separation", &"GridContainer", 4)
