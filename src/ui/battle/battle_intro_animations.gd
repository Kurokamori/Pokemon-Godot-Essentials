class_name BattleIntroAnimations
## The register of special battle intro animations

## One registered animation.
class Entry extends RefCounted:
	
	## Identifies the registration, so a project can take it off again.
	var name: String = ""
	
	## Highest wins
	var priority: int = 0
	
	## `func(context: BattleIntroContext) -> bool`.
	var condition: Callable = Callable()
	
	## `func(context: BattleIntroContext) -> void`. May await.
	var play: Callable = Callable()

	func matches(context: BattleIntroContext) -> bool:
		if not condition.is_valid():
			return false
		return bool(condition.call(context))


## Priorities the built-in entries sit at
const PRIORITY_VERSUS: int = 50

static var _entries: Array[Entry] = []

static var _defaults_registered: bool = false



## Adds an animation. Registering a name that is already there replaces it
static func register(
	name: String, priority: int, condition: Callable, play: Callable
) -> void:
	remove(name)
	var entry: Entry = Entry.new()
	entry.name = name
	entry.priority = priority
	entry.condition = condition
	entry.play = play
	_entries.append(entry)

## Takes an animation off the list. 
## Returns `true` when there was one.
static func remove(name: String) -> bool:
	for index: int in range(_entries.size()):
		if _entries[index].name == name:
			_entries.remove_at(index)
			return true
	return false

static func has(name: String) -> bool:
	return get_entry(name) != null

static func get_entry(name: String) -> Entry:
	_ensure_defaults()
	for entry: Entry in _entries:
		if entry.name == name:
			return entry
	return null

## Every registered animation, in priority order
static func all() -> Array[Entry]:
	_ensure_defaults()
	var ordered: Array[Entry] = _entries.duplicate()
	ordered.sort_custom(func(left: Entry, right: Entry) -> bool:
		return left.priority > right.priority)
	return ordered

## The animation that should play for [param context]
## `null` when no specific animation should
static func best_for(context: BattleIntroContext) -> Entry:
	for entry: Entry in all():
		if entry.matches(context):
			return entry
	return null

## Puts the built-in animations on the list
static func _ensure_defaults() -> void:
	if _defaults_registered:
		return
	_defaults_registered = true
	register(
		"versus_trainer", PRIORITY_VERSUS,
		func(context: BattleIntroContext) -> bool:
			return not VersusIntroScreen.artwork_for(context.lone_foe()).is_empty(),
		func(context: BattleIntroContext) -> void:
			await VersusIntroScreen.play(context)
	)
