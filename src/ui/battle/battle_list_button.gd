class_name BattleListButton
extends Button
## A single button in battle, either for moves or target list

@onready var _label: Label = %EntryLabel
@onready var _detail: Label = %EntryDetail


func _ready() -> void:
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))

## Populates the row. 
## [param detail] is the right-hand column
func set_entry(label: String, detail: String = "") -> void:
	_label.text = label
	_detail.text = detail
	_detail.visible = not detail.is_empty()

## Manually restyling because it doesn't inherit
func _on_focus_changed(focused: bool) -> void:
	var skin: UISkinData = UITheme.skin
	if skin == null:
		return
	var colour: Color = skin.selected_text if focused else skin.dark_text
	var shadow: Color = skin.light_text_shadow if focused else skin.dark_text_shadow
	for label: Label in [_label, _detail]:
		label.add_theme_color_override(&"font_color", colour)
		label.add_theme_color_override(&"font_shadow_color", shadow)
