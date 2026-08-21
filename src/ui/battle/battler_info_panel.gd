class_name BattlerInfoPanel
extends PanelContainer
## The name, level, status and HP for a battling pokemon

## Set `true` to show exact HP numbers
## In the games this is only true for the player's pokemon
@export var show_hp_numbers: bool = false

@onready var _name_label: Label = %PokemonName
@onready var _level_label: Label = %PokemonLevel
@onready var _status_label: Label = %StatusLabel
@onready var _hp_bar: ProgressBar = %HPBar
@onready var _hp_label: Label = %HPLabel

## The battler currently shown
## `null` if the position is empty
var battler: Battler = null


func _ready() -> void:
	_hp_label.visible = show_hp_numbers

## Populates the panel from [param source]
## Passing `null` or a fainted battler hides it instead
func bind(source: Battler) -> void:
	battler = source
	var present: bool = source != null and not source.is_fainted()
	visible = present
	if not present:
		return
	_name_label.text = source.display_name()
	_level_label.text = "Lv%d" % source.level()
	_status_label.text = _status_text(source)
	_hp_bar.max_value = source.total_hp()
	_hp_bar.value = source.hp()
	_apply_hp_colour(source.hp_fraction())
	if show_hp_numbers:
		_hp_label.text = "%d/%d" % [source.hp(), source.total_hp()]

func _status_text(source: Battler) -> String:
	if source.pokemon.status == &"NONE":
		return ""
	var record: StatusData = Database.status(source.pokemon.status)
	var name_text: String = record.display_name if record != null else String(source.pokemon.status)
	return name_text.substr(0, 3).to_upper()

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
