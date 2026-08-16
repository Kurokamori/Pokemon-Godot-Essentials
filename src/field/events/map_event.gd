@tool
class_name MapEvent
extends GridCharacter
## Something on a map that reacts to the player

## Drawing order for a page that asks to be drawn over the player.
const TOP_Z_INDEX: int = 100

## Number used by imported "Transfer Player"-style commands
## You want to leave this at 0, at which point it will use the NodeName which is more durable
@export var event_id: int = 0

## Shown in the editor and in debug output. 
## Falls back to the node's name.
@export var event_name: String = ""

@export_group("Appearance")
## Character sheet under `assets/graphics/characters/`, 
## Used when the event ahs no pages
## Empty draws blank
@export var charset: String = "":
	set(value):
		charset = value
		if is_node_ready():
			_refresh_appearance()

@export_group("Script")
## A plain-text event script file, used when the event has no pages.
@export_file("*.evt", "*.txt", "*.tres") var script_file: String = "":
	set(value):
		script_file = value
		_script = null
		if Engine.is_editor_hint() and is_node_ready():
			update_configuration_warnings()
			
## An event script written straight into the event
@export_multiline var script_source: String = "":
	set(value):
		script_source = value
		_script = null
		if Engine.is_editor_hint() and is_node_ready():
			update_configuration_warnings()

@export_group("Behaviour")
## What sets the event off, used when it has no pages.
@export var trigger: EventPage.Trigger = EventPage.Trigger.ACTION_BUTTON

## How the event moves when it has no pages.
@export var move_type: EventPage.MoveType = EventPage.MoveType.FIXED
@export_range(1, 6) var move_speed: int = 3
@export_range(1, 6) var move_frequency: int = 3

## Returns `true` once an Erase Event command has run, until the map is reloaded.
var erased: bool = false

## The map scene this event lives on,
## set by [GameMap] when it takes stock of its events.
## Self-switches are scoped to it.
var map_scene: GameMap = null

var _pages: Array[EventPage] = []
var _page: EventPage = null

## Returns `false` until the first page selection
## This way the openning visuals are resolved before the page if needed
var _page_resolved: bool = false
var _move_timer: float = 0.0

## The compiled script this event carries
var _script: EventScript = null

## An interpreter for a parallel-porcess page to run on its own, so it doesn't block the field's
var _parallel_interpreter: EventInterpreter = null

## Move frequency a move route's Change Frequency command has declared
## this takes precedence over the page's own
## `0` when nothing has been declared
var _move_frequency_override: int = 0

## How far through the active page's custom move route this event progressed.
var _move_route_index: int = 0

## The page the route index counts against
## This allows for swapping pages and starting at the beginning
var _move_route_page: EventPage = null

## Runs the route's commands. Made on first use and kept
var _move_route_runner: MoveRouteRunner = null

## Whether the active page carries [constant ShadowSources.CASTER_MARKUP]
## Read on resolution rather than requerrying
var _casts_dynamic_shadow: bool = false

func _ready() -> void:
	super._ready()
	_collect_pages()
	if Engine.is_editor_hint():
		set_notify_transform(true)
		_snap_to_grid()
		_refresh_appearance()
		update_configuration_warnings()
		return
	GameState.switch_changed.connect(_on_world_changed)
	GameState.variable_changed.connect(_on_world_changed)
	refresh_page()

func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			_snap_to_grid()
		NOTIFICATION_CHILD_ORDER_CHANGED:
			call_deferred("refresh_editor_appearance")

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_advance_movement(delta)
	super._process(delta)

func _advance_movement(delta: float) -> void:
	if erased or is_moving or not is_active():
		return
	var field_interpreter: EventInterpreter = map.interpreter() if map != null else null
	if field_interpreter != null and field_interpreter.is_running():
		return
	match _active_move_type():
		EventPage.MoveType.RANDOM:
			_move_timer -= delta
			if _move_timer <= 0.0:
				_move_timer = float(7 - _active_move_frequency())
				var directions: Array[int] = [Direction.DOWN, Direction.LEFT, Direction.RIGHT, Direction.UP]
				step(directions[RNG.below(4)] as Direction)
		EventPage.MoveType.APPROACH:
			if map == null or map.player == null:
				return
			_move_timer -= delta
			if _move_timer <= 0.0:
				_move_timer = float(7 - _active_move_frequency()) * 0.5
				step(direction_towards(world_cell(), map.player.world_cell()))
		EventPage.MoveType.CUSTOM:
			_move_timer -= delta
			if _move_timer <= 0.0:
				_move_timer = float(7 - _active_move_frequency())
				_advance_move_route()

func _snap_to_grid() -> void:
	var snapped_position: Vector2 = MapGrid.snap(position)
	if not position.is_equal_approx(snapped_position):
		position = snapped_position
	tile_position = MapGrid.pixel_to_cell(position)

func _collect_pages() -> void:
	_pages.clear()
	for child: Node in get_children():
		var page: EventPage = child as EventPage
		if page != null:
			_pages.append(page)

# === Identity === 

## The key this event's self-switches are stored under
func self_switch_key() -> String:
	return str(event_id) if event_id > 0 else String(name)


func display_name() -> String:
	return event_name if not event_name.is_empty() else String(name)


# === Pages ===

## Reworks which page is active and applies its appearance.
func refresh_page() -> void:
	if Engine.is_editor_hint():
		return
	var page: EventPage = _find_active_page()
	if _page_resolved and page == _page and not _pages.is_empty():
		return
	_page = page
	_page_resolved = true
	_move_frequency_override = 0
	_refresh_appearance()
	_casts_dynamic_shadow = ShadowSources.casts(self)
	if map != null:
		map.invalidate_shadow_sources()

func _find_active_page() -> EventPage:
	if _pages.is_empty():
		return null
	var map_id: int = map_scene.map_id if map_scene != null else 0
	for index: int in range(_pages.size() - 1, -1, -1):
		if _pages[index].conditions_met(map_id, self_switch_key()):
			return _pages[index]
	return null

func current_page() -> EventPage:
	return null if erased else _page

## Returns `true` if the event exists right now: 
## it has not been erased and, if it has pages whether one of them is valid.
func is_active() -> bool:
	if erased:
		return false
	return _pages.is_empty() or _page != null

func casts_dynamic_shadow() -> bool:
	return _casts_dynamic_shadow and is_active()

func _refresh_appearance() -> void:
	if Engine.is_editor_hint():
		refresh_editor_appearance()
		return
	if not is_active():
		visible = false
		return
	visible = true
	if _page == null:
		set_charset(charset)
		seconds_per_tile = speed_to_seconds(move_speed)
		return
	set_charset(_page.charset)
	facing = _page.direction
	direction_fix = _page.direction_fix
	step_animation = _page.step_animation
	passable = _page.passable
	seconds_per_tile = speed_to_seconds(_page.move_speed)
	z_index = TOP_Z_INDEX if _page.always_on_top else 0
	modulate.a = float(_page.opacity) / 255.0

## The page the editor draws. A map is edited as the player will first find it or its first page if none of them
## are on by default for editting in 2D viewport
func preview_page() -> EventPage:
	if _pages.is_empty():
		return null
	for index: int in range(_pages.size() - 1, -1, -1):
		if _pages[index].is_initially_active():
			return _pages[index]
	return _pages[0]

## Draws the event the way the player will first see it, and leaves it that way in the saved scene
func refresh_editor_appearance() -> void:
	_collect_pages()
	var page: EventPage = preview_page()
	visible = true
	draw_charset_frame(preview_charset(), page.direction if page != null else facing)
	modulate.a = float(page.opacity if page != null else 255) / 255.0
	z_index = TOP_Z_INDEX if (page != null and page.always_on_top) else 0

## The character sheet the editor preview draws -- blank if empty
func preview_charset() -> String:
	var page: EventPage = preview_page()
	return page.charset if page != null else charset

func _on_world_changed(_id: int, _value: Variant) -> void:
	refresh_page()


# === Triggers === 

## What sets this event off right now.
func active_trigger() -> EventPage.Trigger:
	return _page.trigger if _page != null else trigger

func _active_move_type() -> EventPage.MoveType:
	return _page.move_type if _page != null else move_type

func _active_move_frequency() -> int:
	if _move_frequency_override > 0:
		return _move_frequency_override
	return _page.move_frequency if _page != null else move_frequency

func set_move_frequency_override(frequency: int) -> void:
	_move_frequency_override = clampi(frequency, 0, 6)


# === Custom Movement ===

## Plays the next command of the active page's move route
func _advance_move_route() -> void:
	var route: Array[MapEventCommand] = _active_move_route()
	if route.is_empty():
		return
	if _move_route_index >= route.size():
		if not _move_route_repeats():
			return
		_move_route_index = 0
	var entry: MapEventCommand = route[_move_route_index]
	_move_route_index += 1
	if entry == null or entry.code == 0:
		return
	_move_route().run_entry(entry)

## The route the active page walks, empty when it has none or is not set to Custom
func _active_move_route() -> Array[MapEventCommand]:
	var page: EventPage = current_page()
	if page == null or page.move_type != EventPage.MoveType.CUSTOM:
		return [] as Array[MapEventCommand]
	if page != _move_route_page:
		_move_route_page = page
		_move_route_index = 0
	return page.move_route

func _move_route_repeats() -> bool:
	return _move_route_page == null or _move_route_page.move_route_repeats

func _move_route() -> MoveRouteRunner:
	if _move_route_runner == null:
		_move_route_runner = MoveRouteRunner.new(self, map, interpreter())
	_move_route_runner.map = map
	_move_route_runner.interpreter = interpreter()
	return _move_route_runner

## The event script this event runs when it has no pages, or `null`.
func event_script() -> EventScript:
	_script = EventScript.resolve(script_file, script_source, display_name(), _script)
	return _script

## Returns `true` when this event carries a script of its own
func has_script() -> bool:
	var script: EventScript = event_script()
	return script != null and not script.is_blank()

## Returns `true` when running the event would actually do something
func has_action() -> bool:
	if not is_active():
		return false
	return _page.has_action() if _page != null else has_script()

## Returns `true` when other characters may walk through this event right now.
func is_passable_now() -> bool:
	if not is_active() or not visible:
		return true
	return _page.passable if _page != null else passable

## Sets the point of contact to `player on top of event` rather than player bumping into the event
func is_over_trigger() -> bool:
	if not is_active():
		return false
	if not charset_of_active_page().is_empty() and not is_passable_now():
		return false
	if map == null:
		return true
	return map.is_standable_at(world_cell())

func charset_of_active_page() -> String:
	return _page.charset if _page != null else charset

func erase() -> void:
	erased = true
	visible = false

func turn_towards(other: GridCharacter) -> void:
	if direction_fix:
		return
	facing = direction_towards(world_cell(), other.world_cell())


# === Execution ===

## Runs the event
func run() -> void:
	var page: EventPage = current_page()
	if page != null:
		await page.run(self)
		return
	if erased or not has_script():
		return
	await EventScriptRunner.run_script(event_script(), self)

## The interpreter this event's commands should run on
## The field's unless it's a parallel runner -- in which case it gets its own so as to not stop field's
func interpreter() -> EventInterpreter:
	if _parallel_interpreter != null and is_instance_valid(_parallel_interpreter):
		return _parallel_interpreter
	return map.interpreter() if map != null else null

## Hands the event the interpreter its parallel page runs on
## `null` when the run is over
func set_parallel_interpreter(side: EventInterpreter) -> void:
	_parallel_interpreter = side

func is_parallel_running() -> bool:
	return _parallel_interpreter != null and is_instance_valid(_parallel_interpreter)


# === Editor ===

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	var pages: int = 0
	for child: Node in get_children():
		if child is EventPage:
			pages += 1
	if pages > 0 and not charset.is_empty():
		warnings.append("This event has pages, so its own Charset is ignored. Set the charset on each page instead.")
	if pages > 0 and (not script_file.is_empty() or not script_source.strip_edges().is_empty()):
		warnings.append("This event has pages, so its own script is ignored. Put the script on a page instead.")
	if not script_file.is_empty() and not script_source.strip_edges().is_empty():
		warnings.append("This event has both a Script File and a Script Source. The file is used; clear the other one.")
	if not script_file.is_empty() and not FileAccess.file_exists(script_file):
		warnings.append("There is no script file at %s." % script_file)
	var script: EventScript = event_script()
	if script != null and script.program().has_errors():
		warnings.append("This events script does not read: %s" % "; ".join(script.program().errors))
	if get_parent() != null and get_parent().name != GameMap.EVENTS_NODE_NAME:
		warnings.append("Events belong under the map's '%s' node so they y-sort against the player." % GameMap.EVENTS_NODE_NAME)
	return warnings
