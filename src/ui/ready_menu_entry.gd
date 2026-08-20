class_name ReadyMenuEntry
extends Button
## An icon and title for a single Ready Menu entry

@onready var _icon: TextureRect = %ReadyEntryIcon
@onready var _label: Label = %ReadyEntryLabel

func bind(label: String, picture: Texture2D) -> void:
	_label.text = label
	_icon.texture = picture
	_icon.visible = picture != null
