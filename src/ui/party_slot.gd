class_name PartySlot
extends Button
## One Pokemon's row on the party screen.

@onready var _icon: PokemonIcon = %SlotIcon
@onready var _name_label: Label = %SlotNameLabel
@onready var _level_label: Label = %SlotLevelLabel
@onready var _hp_label: Label = %SlotHPLabel
@onready var _hp_bar: ProgressBar = %SlotHPBar
@onready var _status_label: Label = %SlotStatusLabel
@onready var _item_label: Label = %SlotItemLabel
@onready var _markings: MarkingsStrip = %SlotMarkings

var pokemon: Pokemon = null


func _ready() -> void:
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))

func _on_focus_changed(focused: bool) -> void:
	_icon.set_animating(focused and pokemon != null)
	var skin: UISkinData = UITheme.skin
	if skin == null:
		return
	var colour: Color = skin.selected_text if focused else skin.dark_text
	var shadow: Color = skin.light_text_shadow if focused else skin.dark_text_shadow
	for label: Label in [_name_label, _level_label, _hp_label, _status_label, _item_label]:
		label.add_theme_color_override(&"font_color", colour)
		label.add_theme_color_override(&"font_shadow_color", shadow)
	_markings.colour = colour

## Fills the row from [param source]. 
## Passing `null` shows an empty slot.
func bind(source: Pokemon) -> void:
	pokemon = source
	_markings.show_pokemon(source)
	if source == null:
		_name_label.text = ""
		_level_label.text = ""
		_hp_label.text = ""
		_status_label.text = ""
		_item_label.text = ""
		_icon.clear_icon()
		_hp_bar.visible = false
		disabled = true
		return
	disabled = false
	_icon.set_pokemon(source)
	_icon.set_animating(has_focus())
	_name_label.text = source.display_name()
	_hp_bar.visible = not source.is_egg()
	if source.is_egg():
		_level_label.text = ""
		_hp_label.text = ""
		_status_label.text = "EGG"
		_item_label.text = ""
		return
	_level_label.text = "Lv%d" % source.level()
	_hp_label.text = "%d/%d" % [source.hp, source.total_hp]
	_hp_bar.max_value = source.total_hp
	_hp_bar.value = source.hp
	_apply_hp_colour(source.hp_fraction())
	_status_label.text = "" if source.status == &"NONE" else String(source.status).substr(0, 3)
	var item: ItemData = Database.item(source.held_item)
	_item_label.text = item.display_name if item != null else ""

func mark_unavailable(reason: String) -> void:
	disabled = true
	_status_label.text = reason

## Recolours the bar's fill for how hurt the Pokemon is
func _apply_hp_colour(fraction: float) -> void:
	var skin: UISkinData = UITheme.skin
	if skin == null:
		return
	var fill: StyleBoxFlat = _hp_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill == null:
		return
	var recoloured: StyleBoxFlat = fill.duplicate() as StyleBoxFlat
	recoloured.bg_color = skin.hp_bar_colour(fraction)
	_hp_bar.add_theme_stylebox_override(&"fill", recoloured)
