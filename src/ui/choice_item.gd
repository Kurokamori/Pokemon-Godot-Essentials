class_name ChoiceItem
extends Button
## One option in the message window's choice list.

@onready var _label: RichTextLabel = %ChoiceLabel


func _ready() -> void:
	_inset_label()

## Draws [param bbcode], already expanded by [MessageCodes]
func set_markup(bbcode: String) -> void:
	if _label == null:
		_label = get_node_or_null("%ChoiceLabel") as RichTextLabel
	if _label == null:
		return
	_label.text = bbcode

## The size this option requires, frame included
func content_size() -> Vector2:
	if _label == null:
		return custom_minimum_size
	var frame: Vector2 = _frame_padding()
	return Vector2(_label.get_content_width(), _label.get_content_height()) + frame

## Insets the label of its frame
func _inset_label() -> void:
	if _label == null:
		return
	var style: StyleBox = get_theme_stylebox(&"normal")
	if style == null:
		return
	_label.offset_left = style.get_margin(SIDE_LEFT)
	_label.offset_top = style.get_margin(SIDE_TOP)
	_label.offset_right = -style.get_margin(SIDE_RIGHT)
	_label.offset_bottom = -style.get_margin(SIDE_BOTTOM)

func _frame_padding() -> Vector2:
	var style: StyleBox = get_theme_stylebox(&"normal")
	if style == null:
		return Vector2(16.0, 8.0)
	return Vector2(
		style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT),
		style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	)
