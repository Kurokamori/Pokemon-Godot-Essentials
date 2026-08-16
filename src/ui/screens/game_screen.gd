class_name GameScreen
extends Control
## Base class for every full-screen menu.

## [SceneRouter.push_screen] awaits [signal closed], so a screen returns a value simply by closing with it


## Emitted when the screen is done. The payload is the screen's result.
signal closed(result: Variant)

## Set to `true` when pressing cancel should close the screen.
@export var closes_on_cancel: bool = true

var _closing: bool = false

func _ready() -> void:
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if _closing or not closes_on_cancel:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close(null)

## Closes the screen, handing [param result] back to whoever opened it.

## [param silent] leaves the closing sound out
func close(result: Variant = null, silent: bool = false) -> void:
	if _closing:
		return
	_closing = true
	if not silent:
		AudioManager.play_se("GUI menu close")
	closed.emit(result)

func play_select() -> void:
	AudioManager.play_se("GUI sel cursor")

func play_confirm() -> void:
	AudioManager.play_se("GUI sel decision")
