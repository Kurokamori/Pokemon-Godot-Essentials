extends CanvasLayer
## Registered as the `SceneRouter` Autoload
## Manages scene changes and screen transitions
##
## Screens are pushed onto a stack rather than swapping the whole tree
## this way the overworld stays alive underneath menus and battles and can be returned to exactly as it was.
## [method push_screen] awaits the screen's `closed` signal, this lets calling code read a result straight from the call site:


## Emitted after a screen is pushed or popped, with the new top of the stack.
signal screen_changed(screen: Node)

const FADE_DURATION: float = 0.25

## The screen the game starts on.
const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

## Canvas layer the bottom-most screen is drawn on. 
## Screens are layered here and must remain bellow the router's own layer.
const SCREEN_LAYER_BASE: int = 10

## This router's layer, above every screen.
const ROUTER_LAYER: int = 100

var _stack: Array[Node] = []
## One [CanvasLayer] per entry in [member _stack], in the same order. 
## Screens live on a canvas layer because the overworld's camera moves the root viewport canvas
var _layers: Array[CanvasLayer] = []

## The control that had keyboard focus when each screen was pushed
## Allows focus to be returned when the menu is closed.
var _focus_returns: Array[Control] = []
var _fade: ColorRect = null
var _busy: bool = false


func _ready() -> void:
	layer = ROUTER_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.name = "FadeOverlay"
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.visible = false
	add_child(_fade)

## Replaces the whole scene tree, used for boot, title and starting a new game.
func change_root_scene(scene_path: String) -> void:
	_suspend_scene_below(true)
	await fade_out()
	clear_screens()
	_suspend_scene_below(true)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_in()

## Abandons the game in progress and goes back to the title screen
func return_to_title() -> void:
	AudioManager.stop_all()
	GameState.reset()
	await change_root_scene(TITLE_SCENE)

## Closes every open screen.
func clear_screens() -> void:
	for index: int in range(_stack.size()):
		if is_instance_valid(_stack[index]):
			_stack[index].queue_free()
		if is_instance_valid(_layers[index]):
			_layers[index].queue_free()
	_stack.clear()
	_layers.clear()
	_focus_returns.clear()
	_suspend_scene_below(false)
	screen_changed.emit(null)

## Instances [param scene] on top of the current screen and waits for it to close.
## Returns the scene passed to it's closed signal.
func push_screen(scene: PackedScene, setup: Callable = Callable()) -> Variant:
	if scene == null:
		push_error("SceneRouter: cannot push a null scene.")
		return null
	var instance: Node = scene.instantiate()
	if setup.is_valid():
		setup.call(instance)
	var host: CanvasLayer = _make_screen_layer(instance.name)
	_stack.append(instance)
	_layers.append(host)
	_focus_returns.append(get_viewport().gui_get_focus_owner())
	get_viewport().gui_release_focus()
	_pause_below()
	host.add_child(instance)
	get_tree().root.add_child(host)
	screen_changed.emit(instance)
	var result: Variant = null
	if instance.has_signal("closed"):
		result = await instance.closed
	else:
		push_warning("SceneRouter: %s has no 'closed' signal." % instance.name)
	pop_screen()
	return result

## Removes the top screen.
func pop_screen() -> void:
	if _stack.is_empty():
		return
	var instance: Node = _stack.pop_back()
	var host: CanvasLayer = _layers.pop_back()
	var focus_return: Control = _focus_returns.pop_back() if not _focus_returns.is_empty() else null
	if is_instance_valid(instance):
		instance.queue_free()
	if is_instance_valid(host):
		host.queue_free()
	_pause_below()
	_restore_focus(focus_return)
	screen_changed.emit(current_screen())

## Builds the canvas layer a screen is drawn on.
func _make_screen_layer(screen_name: String) -> CanvasLayer:
	var host: CanvasLayer = CanvasLayer.new()
	host.name = "%sLayer" % screen_name
	host.layer = mini(SCREEN_LAYER_BASE + _stack.size(), ROUTER_LAYER - 1)
	host.follow_viewport_enabled = false
	return host

func current_screen() -> Node:
	return _stack.back() if not _stack.is_empty() else null

func stack_depth() -> int:
	return _stack.size()

## Returns `true` while any screen is open over the overworld.
func has_overlay() -> bool:
	return not _stack.is_empty()


# === Fading ===

func fade_out(duration: float = FADE_DURATION, colour: Color = Color.BLACK) -> void:
	if _busy:
		return
	_busy = true
	_fade.color = Color(colour.r, colour.g, colour.b, 0.0)
	_fade.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duration)
	await tween.finished
	_busy = false

func fade_in(duration: float = FADE_DURATION) -> void:
	if _busy:
		return
	_busy = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duration)
	await tween.finished
	_fade.visible = false
	_busy = false

## Fades out, runs [param action], then fades back in. Used for map transfers.
func transition(action: Callable, duration: float = FADE_DURATION) -> void:
	await fade_out(duration)
	if action.is_valid():
		var result: Variant = action.call()
		if result is Signal:
			await result
	await get_tree().process_frame
	await fade_in(duration)

## Only the topmost screen processes input; everything below is suspended.
func _pause_below() -> void:
	for index: int in range(_stack.size()):
		var instance: Node = _stack[index]
		if not is_instance_valid(instance):
			continue
		var is_top: bool = index == _stack.size() - 1
		instance.process_mode = Node.PROCESS_MODE_INHERIT if is_top else Node.PROCESS_MODE_DISABLED
	_suspend_scene_below(not _stack.is_empty())

## Stops or restarts the running scene underneath the screen stack.
func _suspend_scene_below(suspended: bool) -> void:
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		return
	scene.process_mode = Node.PROCESS_MODE_DISABLED if suspended else Node.PROCESS_MODE_INHERIT

## Returns focus to the [param control] once whatever screen was covering it is gone.
## It is deferred as the node is only able to process again at the end of the frame.
func _restore_focus(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	control.grab_focus.call_deferred()
