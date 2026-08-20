class_name MapTimer
extends Control
## An onscreen timer

@onready var _panel: PanelContainer = %TimerPanel
@onready var _label: Label = %TimerLabel


func _ready() -> void:
	GameState.timer_changed.connect(_on_timer_changed)
	_refresh()

func _on_timer_changed(_seconds_left: float) -> void:
	_refresh()

func _refresh() -> void:
	_panel.visible = GameState.timer_running
	if not GameState.timer_running:
		return
	_label.text = format_seconds(GameState.timer_seconds())

static func format_seconds(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%d:%02d" % [seconds / 60, seconds % 60]
