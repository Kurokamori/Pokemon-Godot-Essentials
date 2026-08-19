class_name EventScriptFacilities
extends RefCounted
## The static systems such as pokegear, daycare, safari zone, etc.
## These are seperate from [EventScriptRecievers] as they are more than read/write

## The bridge this belongs to, held weakly because it would cause a circular dependency otherwise
var bridge: EventScriptBridge:
	get:
		return _bridge.get_ref() as EventScriptBridge if _bridge != null else null

var _bridge: WeakRef = null

## The Frontier challenge last named, and its state
var _challenge_name: String = "towersingle"
var _challenge_rules: ChallengeRules = null
var _challenge_decision: int = 0
var _challenge_won: bool = false



func _init(for_bridge: EventScriptBridge) -> void:
	_bridge = weakref(for_bridge)


## Runs `<receiver>.<method>(...)` when [param receiver] names one of these systems,
## otherwise [constant EventScriptBridge.Unsupported]
func dispatch(receiver: String, method: String, arguments: Array, raw: String) -> Variant:
	match receiver:
		"Phone", "Phone::Call":
			return await phone(method, arguments, raw)
		"DayCare":
			return await day_care(method, arguments, raw)
		"pbSafariState", "$game_temp.safari":
			return await safari(method, arguments, raw)
		"pbBugContestState", "$game_temp.bug_contest":
			return await bug_contest(method, arguments, raw)
		"pbBattleChallenge":
			return await challenge(method, arguments, raw)
		"pbBattleChallenge.extra":
			return _challenge_extra(method, raw)
	return EventScriptBridge.Unsupported.new(raw)


# === Phone ===

func phone(method: String, arguments: Array, raw: String) -> Variant:
	var book: PhoneBook = GameState.phone
	match method:
		"can_add?":
			return _can_add(book, arguments)
		"add", "add_silent":
			return await _add(book, arguments, method == "add")
		"variant":
			if arguments.size() >= 2:
				return book.variant(_id_of(arguments[0]), String(arguments[1]), _start_version(arguments))
		"increment_version":
			if arguments.size() >= 2:
				var contact: PhoneContact = book.get_trainer(
					_id_of(arguments[0]), String(arguments[1]), _start_version(arguments)
				)
				if contact != null:
					contact.increment_version()
				return contact != null
		"battle":
			return await _phone_battle(book, arguments)
		"reset_after_win":
			if arguments.size() >= 2:
				book.reset_after_win(_id_of(arguments[0]), String(arguments[1]), _start_version(arguments))
				return true
		"get_trainer", "get":
			if arguments.size() >= 2:
				return book.get_trainer(_id_of(arguments[0]), String(arguments[1]), _start_version(arguments))
		"rematches_enabled":
			return book.rematches_enabled
		"rematch_variant":
			return book.rematch_variant
		"contacts":
			return book.visible_contacts()
		"sort_contacts":
			book.sort_contacts()
			return true
		"can_make?":
			return PhoneCall.can_make()
		"can_call_contact?":
			return PhoneCall.refusal_reason(_contact(book, arguments)).is_empty()
		"make_outgoing":
			return await PhoneCall.make_outgoing(_contact(book, arguments))
		"make_incoming":
			return await PhoneCall.make_incoming()
		"generate_trainer_dialogue":
			return PhoneCall.for_contact(_contact(book, arguments))
		"play":
			return await _play_call(arguments)
		"start_message", "end_message":
			return true
	return EventScriptBridge.Unsupported.new(raw)

func _play_call(arguments: Array) -> bool:
	var built: Variant = arguments[0] if not arguments.is_empty() else null
	if built is PhoneCall:
		await Field.take_phone_call(built as PhoneCall)
		return true
	var who: PhoneContact = arguments[1] as PhoneContact if arguments.size() >= 2 else null
	await Field.take_phone_call(PhoneCall.for_contact(who))
	return true

static func _contact(book: PhoneBook, arguments: Array) -> PhoneContact:
	if arguments.is_empty():
		return null
	if arguments[0] is PhoneContact:
		return arguments[0] as PhoneContact
	if arguments.size() >= 2:
		return book.get_trainer(
			_id_of(arguments[0]), String(arguments[1]), _start_version(arguments)
		)
	return book.find(String(arguments[0]))

## Either `(type, name)` for trainer or `(name)`
static func _can_add(book: PhoneBook, arguments: Array) -> bool:
	if arguments.size() >= 2:
		return book.can_add_trainer(_id_of(arguments[0]), String(arguments[1]), _start_version(arguments))
	if arguments.size() == 1:
		return book.can_add_contact(String(arguments[0]))
	return false

## The Phone.add command and its three shapes.
## Phone.add(get_self, :CAMPER, "Jeff", 2) :
## The event, the trainer, how many parties they have, then the version they start on and a common event
##
## Phone.add(31, 4, :CAMPER, "Jeff", 2)   :
## Same as above, written with the map and event numbers explicitly
##
## Phone.add(4, "Professor Oak", 1)  :
## A map, someone who is not a trainer, and the common event their call runs
##
## The number after the name is how many of the trainer there are not which one to register
func _add(book: PhoneBook, arguments: Array, announce: bool) -> Variant:
	var remaining: Array = arguments.duplicate()
	var map_id: int = bridge.map_id()
	var event_id: int = 0
	if not remaining.is_empty() and remaining[0] is MapEvent:
		event_id = (remaining.pop_front() as MapEvent).event_id
	elif remaining.size() >= 2 and _is_number(remaining[0]) and _is_number(remaining[1]):
		map_id = int(_number(remaining.pop_front()))
		event_id = int(_number(remaining.pop_front()))
	elif not remaining.is_empty() and _is_number(remaining[0]):
		# A single leading number is the map a chat contact lives on.
		map_id = int(_number(remaining.pop_front()))

	var contact: PhoneContact = null
	if remaining.size() >= 2 and not _is_number(remaining[1]):
		contact = book.add_trainer(
			_id_of(remaining[0]), String(remaining[1]),
			int(_number(remaining[3])) if remaining.size() >= 4 else 0,
			map_id, event_id,
			int(_number(remaining[2])) if remaining.size() >= 3 else 1,
			int(_number(remaining[4])) if remaining.size() >= 5 else 0,
		)
	elif not remaining.is_empty():
		contact = book.add_contact(
			String(remaining[0]),
			int(_number(remaining[1])) if remaining.size() >= 2 else 0,
			map_id,
		)
	if contact == null:
		return false
	if announce:
		await bridge.say(Loc.line(
			"\\me[Register phone]Registered {contact} in the Pokegear!\\wtnp[60]",
			{"contact": contact.display_name()}
		))
	return true

func _phone_battle(book: PhoneBook, arguments: Array) -> Variant:
	if arguments.size() < 2:
		return false
	var trainer_type: StringName = _id_of(arguments[0])
	var trainer_name: String = String(arguments[1])
	var contact: PhoneContact = book.get_trainer(trainer_type, trainer_name, _start_version(arguments))
	if contact == null:
		return false
	return await bridge.battles().start_trainer_battle(
		trainer_type, trainer_name, contact.next_version()
	)

static func _start_version(arguments: Array) -> int:
	return int(_number(arguments[2])) if arguments.size() >= 3 else 0

static func _is_number(value: Variant) -> bool:
	return value is int or value is float


# === Day Care ===

func day_care(method: String, arguments: Array, raw: String) -> Variant:
	var care: DayCare = GameState.day_care
	match method:
		"count":
			return care.count()
		"egg_generated?":
			return care.egg_generated
		"reset_egg_counters":
			care.reset_egg_counters()
			return true
		"get_details":
			return _day_care_details(care, arguments)
		"get_level_gain":
			return _day_care_level_gain(care, arguments)
		"get_compatibility":
			if not arguments.is_empty():
				var variable: int = int(_number(arguments[0]))
				if variable > 0:
					GameState.set_variable(variable, care.compatibility())
				return care.compatibility()
		"deposit":
			return _day_care_deposit(care, arguments)
		"withdraw":
			return _day_care_withdraw(care, arguments)
		"choose":
			return await _day_care_choose(care, arguments)
		"collect_egg":
			return _day_care_collect_egg(care)
	return EventScriptBridge.Unsupported.new(raw)


## `DayCare.get_details(index, name_var, cost_var)`
## Records the deposited Pokemon's name and what it'll cost to return
static func _day_care_details(care: DayCare, arguments: Array) -> bool:
	var slot: DayCare.Slot = _day_care_slot(care, arguments)
	if slot == null:
		return false
	if arguments.size() >= 2 and int(_number(arguments[1])) > 0:
		GameState.set_variable(int(_number(arguments[1])), slot.pokemon_name())
	if arguments.size() >= 3 and int(_number(arguments[2])) > 0:
		GameState.set_variable(int(_number(arguments[2])), slot.cost())
	return true

static func _day_care_level_gain(care: DayCare, arguments: Array) -> bool:
	var slot: DayCare.Slot = _day_care_slot(care, arguments)
	if slot == null:
		return false
	if arguments.size() >= 2 and int(_number(arguments[1])) > 0:
		GameState.set_variable(int(_number(arguments[1])), slot.pokemon_name())
	if arguments.size() >= 3 and int(_number(arguments[2])) > 0:
		GameState.set_variable(int(_number(arguments[2])), slot.level_gain())
	return true

static func _day_care_slot(care: DayCare, arguments: Array) -> DayCare.Slot:
	var index: int = int(_number(arguments[0])) if not arguments.is_empty() else -1
	if index >= 0:
		var named: DayCare.Slot = care.slot(index)
		return named if named != null and named.is_filled() else null
	for slot: DayCare.Slot in care.slots:
		if slot.is_filled():
			return slot
	return null

static func _day_care_deposit(care: DayCare, arguments: Array) -> bool:
	if arguments.is_empty():
		return false
	var party_slot: int = int(_number(arguments[0]))
	var pkmn: Pokemon = GameState.party.get_member(party_slot)
	if pkmn == null or care.deposit(pkmn) < 0:
		return false
	GameState.party.remove_at(party_slot)
	GameState.stats.day_care_deposits += 1
	return true

static func _day_care_withdraw(care: DayCare, arguments: Array) -> bool:
	if arguments.is_empty() or GameState.party.is_full():
		return false
	var index: int = int(_number(arguments[0]))
	var slot: DayCare.Slot = care.slot(index)
	if slot == null or not slot.is_filled():
		return false
	GameState.stats.day_care_levels_gained += slot.level_gain()
	var pkmn: Pokemon = care.withdraw(index)
	return pkmn != null and GameState.party.add(pkmn)

## `DayCare.choose(message, variable)`
## Queries which one to take, or `-1` to cancel
static func _day_care_choose(care: DayCare, arguments: Array) -> Variant:
	var variable: int = int(_number(arguments[1])) if arguments.size() >= 2 else 0
	var slots: Array[int] = []
	var options: Array = []
	for index: int in care.slots.size():
		if care.slots[index].is_filled():
			slots.append(index)
			options.append(care.slots[index].choice_text())
	if slots.is_empty():
		if variable > 0:
			GameState.set_variable(variable, -1)
		return -1
	var chosen: int = 0
	if slots.size() > 1:
		options.append("Cancel")
		var prompt: String = String(arguments[0]) if not arguments.is_empty() else "Which one?"
		chosen = await Field.ask(options, prompt, options.size())
	var slot: int = slots[chosen] if chosen >= 0 and chosen < slots.size() else -1
	if variable > 0:
		GameState.set_variable(variable, slot)
	return slot

static func _day_care_collect_egg(care: DayCare) -> bool:
	if not care.egg_generated or GameState.party.is_full():
		return false
	var egg: Pokemon = care.generate_egg()
	if egg == null or not GameState.party.add(egg):
		return false
	care.reset_egg_counters()
	return true


# === Safari Zone ===

## The Safari Zone gate's commands
func safari(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"pbStart", "begin", "pbStartSafari":
			var balls: int = int(_number(arguments[0])) if arguments.size() >= 1 else 30
			var steps: int = int(_number(arguments[1])) if arguments.size() >= 2 else 500
			await Field.start_safari_zone(balls, steps)
			return true
		"pbEnd", "finish", "pbEndSafari":
			await Field.end_safari_zone()
			return true
		"inProgress?", "active?":
			return Field.in_safari_zone()
		"ballsLeft", "balls":
			return GameState.safari.balls_left if GameState.safari != null else 0
		"stepsLeft", "steps":
			return GameState.safari.steps_left if GameState.safari != null else 0
		"pbCaught", "caught":
			return GameState.safari.caught.size() if GameState.safari != null else 0
		"decision":
			if GameState.safari != null and GameState.safari.active:
				return 0
			return 1
	return EventScriptBridge.Unsupported.new(raw)

# === Bug-Catching Contest ===

## The contest gate's commands
func bug_contest(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"pbStart", "begin", "pbStartContest":
			var balls: int = int(_number(arguments[0])) if arguments.size() >= 1 else 20
			var steps: int = int(_number(arguments[1])) if arguments.size() >= 2 else 0
			var slot: int = int(_number(arguments[2])) if arguments.size() >= 3 else -1
			return await Field.start_bug_contest(slot, balls, steps)
		"pbStartJudging", "pbEnd", "finish":
			return await Field.end_bug_contest()
		"inProgress?", "active?":
			return Field.in_bug_contest()
		"pbContestHeld?":
			return GameState.stats.bug_contest_count > 0
		"ballsLeft", "balls":
			return GameState.bug_contest.balls_left if GameState.bug_contest != null else 0
		"place", "placing", "pbClearIfEnded":
			return GameState.bug_contest.placing() if GameState.bug_contest != null else 0
		"pbGetPlaceInfo":
			return _contest_place_info(arguments)
		"pbSetJudgingPoint", "pbSetReception", "pbSetContestMap", "pbSetPokemon":
			return true
	return EventScriptBridge.Unsupported.new(raw)


## `pbBugContestState.pbGetPlaceInfo(n)`
## The name, Pokemon, and score of the entrant who came at `n + 1`th written into three consecutive game vars
static func _contest_place_info(arguments: Array) -> bool:
	var session: BugContestSession = GameState.bug_contest
	if session == null or arguments.is_empty():
		return false
	var entrant: Dictionary = session.entrant_at(int(_number(arguments[0])) + 1)
	GameState.set_variable(1, entrant.get("name", ""))
	GameState.set_variable(2, entrant.get("pokemon", ""))
	GameState.set_variable(3, entrant.get("score", 0))
	return true


# === Battle Frontier ===

## `pbBattleChallenge` — the Battle Frontier attendant's script
func challenge(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"set":
			if not arguments.is_empty():
				_challenge_name = String(arguments[0])
				if arguments.size() >= 3 and arguments[2] is ChallengeRules:
					_challenge_rules = arguments[2]
				return true
		"start":
			_challenge_won = await Field.run_challenge(challenge_facility(), _challenge_rules)
			_challenge_decision = 1 if _challenge_won else 2
			return _challenge_won
		"decision":
			return _challenge_decision
		"setDecision":
			if not arguments.is_empty():
				_challenge_decision = int(_number(arguments[0]))
				return true
		"wins", "battleNumber":
			return Field.challenge_streak(challenge_facility())
		"getPreviousWins":
			return Field.challenge_streak(_facility_named(arguments))
		"getMaxWins":
			return Field.challenge_best_streak(_facility_named(arguments))
		"pbGoOn", "pbGoToStart", "pbAddWin", "pbRest", "pbCancel", "pbEnd":
			return true
		"pbResting?":
			return false
		"pbMatchOver?":
			return true
		"extra":
			return EventScriptBridge.Handle.new("pbBattleChallenge.extra")
	return EventScriptBridge.Unsupported.new(raw)


## The Battle Factory's swaps and the rental teams
static func _challenge_extra(method: String, raw: String) -> Variant:
	match method:
		"pbPrepareRentals", "pbChooseRentals", "pbPrepareSwaps", "pbChooseSwaps":
			return true
	return EventScriptBridge.Unsupported.new(raw)


func _facility_named(arguments: Array) -> StringName:
	if arguments.is_empty():
		return challenge_facility()
	return EventScriptGlobals.facility_of(String(arguments[0]))


## The Frontier building the attendant's script is about
func challenge_facility() -> StringName:
	return EventScriptGlobals.facility_of(_challenge_name)


# === Internals ===

static func _id_of(value: Variant) -> StringName:
	if value is GameDataResource:
		return value.id
	return StringName(String(value))


static func _number(value: Variant) -> float:
	return EventScriptBridge.as_number(value)
