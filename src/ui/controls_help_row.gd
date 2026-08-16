class_name ControlsHelpRow
extends HBoxContainer
## One line of [ControlsHelpScreen]: the key on the left, what it does on the right.
## Read from [KeyBindings] which allows rebound keys to read collectly

@onready var _key_badge: PanelContainer = %RowKeyBadge
@onready var _key_label: Label = %RowKey
@onready var _description_label: Label = %RowDescription

var _action: StringName = &""
var _description: String = ""

## Set `true` when the badge column is kept even for a row with no key
## Formatting convience
var _keep_key_column: bool = false


func _ready() -> void:
	_refresh()

## Shows the key bound to [param action] beside [param description]. 
## Safe to call before the row is in the tree.
func bind(action: StringName, description: String, keep_key_column: bool = false) -> void:
	_action = action
	_description = description
	_keep_key_column = keep_key_column
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	_description_label.text = _description
	var has_key: bool = not _action.is_empty()
	_key_badge.visible = has_key or _keep_key_column
	_key_badge.self_modulate.a = 1.0 if has_key else 0.0
	_key_label.text = KeyBindings.key_name_for(_action) if has_key else ""
