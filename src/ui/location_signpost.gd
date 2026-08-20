class_name LocationSignpost
extends Control
## The panel that slides from the top to announce a new locaiton

## Seconds the panel takes to slide in, and to slide back out again.
const SLIDE_SECONDS: float = 0.4

## Seconds it stays fully in view between the two slides.
const LINGER_SECONDS: float = 1.6


@onready var _panel: PanelContainer = %SignpostPanel
@onready var _label: Label = %SignpostLabel

## The slide currently running
var _slide: Tween = null

func _ready() -> void:
	_panel.visible = false

func show_place(place_name: String) -> void:
	if place_name.is_empty():
		return
	_label.text = place_name
	_panel.visible = true
	await get_tree().process_frame
	var height: float = _panel.size.y
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_panel.position.y = -height
	_slide = create_tween()
	_slide.tween_property(_panel, "position:y", 0.0, SLIDE_SECONDS)
	_slide.tween_interval(LINGER_SECONDS)
	_slide.tween_property(_panel, "position:y", -height, SLIDE_SECONDS)
	await _slide.finished
	_panel.visible = false

## Takes the signpost away at once
func dismiss() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_panel.visible = false

func is_showing() -> bool:
	return _panel != null and _panel.visible
