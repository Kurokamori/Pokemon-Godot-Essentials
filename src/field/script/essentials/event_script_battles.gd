class_name EventScriptBattles
extends RefCounted
## Battle event vocabulary for the event script bridge

## Battle rules which can be set by an event
const KNOWN_RULES: Array[String] = [
	"single", "double", "triple", "canlose", "cannotlose", "nomoney", "noexp",
	"nopartner", "backdrop", "environment", "terrain", "weather", "outcomevar",
	"battlerule",
]

const OUTCOME_WON: int = 1
const OUTCOME_LOST: int = 2
const OUTCOME_FLED: int = 3


## The bridge this vocabulary belongs to
## EventScriptGlobals.bridge also holds this, so we can't have a proper reference because it would be circular
var bridge: EventScriptBridge:
	get:
		return _bridge.get_ref() as EventScriptBridge if _bridge != null else null

var _bridge: WeakRef = null

## Rules set for the next battle, cleared once it has been fought.
var rules: Dictionary = {}

## The trainer type the last `pbTrainerIntro` named
## This lets `pbTrainerEnd` know what music to stop
var intro_trainer: StringName = &""

## How the last battle ended
var last_outcome: BattlePresenter.Outcome = BattlePresenter.Outcome.UNDECIDED



func _init(for_bridge: EventScriptBridge) -> void:
	_bridge = weakref(for_bridge)
	
# === Trainers ===

## Starts trainer music intro and any other setup can go here
func trainer_intro(trainer_type: StringName) -> bool:
	intro_trainer = trainer_type
	var trainer: TrainerTypeData = Database.trainer_type(trainer_type)
	var track: String = trainer.intro_bgm if trainer != null else ""
	if track.is_empty():
		return true
	AudioManager.play_bgm(track)
	return true
	
## Returns the player to the map, and resets the music, any cleanup can go here
func trainer_end() -> bool:
	intro_trainer = &""
	rules.clear()
	var field: MapController = MapController.current
	if field != null and field.current_map != null and not field.current_map.bgm.is_empty():
		AudioManager.play_bgm(field.current_map.bgm)
	return true
	
## Starts the trainer battle with [param trainer_type]/[param trainer_name]
## Returns `true` if the player won
func start_trainer_battle(
	trainer_type: StringName, trainer_name: String, version: int = 0
) -> bool:
	var overworld: Overworld = Overworld.current
	var trainer: TrainerData = Database.trainer(trainer_type, trainer_name, version)
	if overworld == null or trainer == null:
		push_error("EventScriptBattles: no trainer record for %s '%s' (%d)." % [
			trainer_type, trainer_name, version,
		])
		return false
	var trainers: Array[TrainerData] = [trainer]
	var partner: TrainerData = GameState.partner_trainer
	if partner != null and not _rule_is_set("nopartner"):
		trainers.append(partner)
	var outcome: BattlePresenter.Outcome = await overworld.start_trainer_battle_against(
		trainers, _battlers_per_side(trainers.size()), _configure()
	)
	_finish(outcome)
	return outcome == BattlePresenter.Outcome.PLAYER_WON
	
## Fights a single wild Pokemon
## Returns `true` if the player won (counting catching it)
func start_wild_battle(species_id: StringName, level: int) -> bool:
	var overworld: Overworld = Overworld.current
	if overworld == null or Database.species(species_id) == null:
		return false
	var wild: Pokemon = Pokemon.create(species_id, maxi(level, 1))
	var outcome: BattlePresenter.Outcome = await overworld.start_wild_battle_against(
		[wild] as Array[Pokemon], _battlers_per_side(1), _configure()
	)
	_finish(outcome)
	return outcome == BattlePresenter.Outcome.PLAYER_WON or outcome == BattlePresenter.Outcome.POKEMON_CAUGHT
	
## Checks if the trainer exists, returning the result
func trainer_exists(arguments: Array) -> bool:
	if arguments.size() < 2:
		return false
	var version: int = int(arguments[2]) if arguments.size() >= 3 else 0
	return Database.trainer(
		StringName(String(arguments[0])), String(arguments[1]), version
	) != null
	
	
# === Rules ===


func set_rule(arguments: Array) -> bool:
	if arguments.is_empty():
		return false
	var name: String = String(arguments[0]).to_lower()
	rules[name] = arguments[1] if arguments.size() >= 2 else true
	if not KNOWN_RULES.has(name):
		push_warning("EventScriptBattles: battle rule '%s' has no effect here." % name)
	return true

func _rule_is_set(name: String) -> bool:
	return rules.has(name) and EventScriptBridge.is_truthy(rules[name])

## How many Pokemon each side sends out
func _battlers_per_side(trainer_count: int) -> int:
	if _rule_is_set("triple"):
		return 3
	if _rule_is_set("double"):
		return 2
	if _rule_is_set("single"):
		return 1
	return maxi(trainer_count, 1)

## Applies the rules of a battle once it's set up
func _configure() -> Callable:
	var applied: Dictionary = rules.duplicate()
	return func(battle: Battle) -> void:
		if applied.has("canlose"):
			battle.can_lose = EventScriptBridge.is_truthy(applied["canlose"])
		if applied.has("cannotlose"):
			battle.can_lose = not EventScriptBridge.is_truthy(applied["cannotlose"])
		if applied.has("environment"):
			battle.field.environment = StringName(String(applied["environment"]))
		if applied.has("weather"):
			battle.field.weather = StringName(String(applied["weather"]))
		if applied.has("terrain"):
			battle.field.terrain = StringName(String(applied["terrain"]))

## Records how a battle resolved and clears its rules
func _finish(outcome: BattlePresenter.Outcome) -> void:
	last_outcome = outcome
	var variable: int = int(rules.get("outcomevar", 0))
	if variable > 0:
		GameState.set_variable(variable, _outcome_code(outcome))
	rules.clear()
	var overworld: Overworld = Overworld.current
	if overworld != null and overworld.last_recording() != null:
		GameState.last_battle_record = overworld.last_recording()

static func _outcome_code(outcome: BattlePresenter.Outcome) -> int:
	match outcome:
		BattlePresenter.Outcome.PLAYER_WON, BattlePresenter.Outcome.POKEMON_CAUGHT: return OUTCOME_WON
		BattlePresenter.Outcome.PLAYER_LOST: return OUTCOME_LOST
	return OUTCOME_FLED
	

# === Battle Records ===

## Keeps the battle just fought so the player can watch it back
func record_last_battle() -> bool:
	var overworld: Overworld = Overworld.current
	var recording: BattleRecording = overworld.last_recording() if overworld != null else null
	if recording == null:
		recording = GameState.last_battle_record
	if recording == null:
		return false
	GameState.last_battle_record = recording
	return recording.save_to(BattleRecording.path_for("last-battle"))

func play_last_battle() -> bool:
	if GameState.last_battle_record == null:
		await bridge.say("There is no battle recorded.")
		return false
	var overworld: Overworld = Overworld.current
	if overworld == null:
		return false
	await overworld.watch_recording(GameState.last_battle_record)
	return true
	

# === Party Members ===

## Registers a trainer to fight alongside the player
func register_partner(arguments: Array) -> bool:
	if arguments.size() < 2:
		return false
	var version: int = int(arguments[2]) if arguments.size() >= 3 else 0
	var partner: TrainerData = Database.trainer(
		StringName(String(arguments[0])), String(arguments[1]), version
	)
	if partner == null:
		return false
	GameState.partner_trainer = partner
	return true

## Swaps the player, used for when someone else is playing (such as the catching tutorial)
func change_player(metadata_id: int) -> bool:
	if GameState.player == null:
		return false
	GameState.player.character_id = metadata_id
	var field: MapController = MapController.current
	if field != null and field.player != null:
		field.player.refresh_charset()
	return true


# === Battle Frontier ===

## Whether or not the player can enter a challenge needing [param count] with Pokemon at or under [param level]
func has_eligible_party(arguments: Array) -> bool:
	var wanted: int = int(arguments[0]) if not arguments.is_empty() else 3
	var cap: int = int(arguments[1]) if arguments.size() >= 2 else 100
	var eligible: int = 0
	for pkmn: Pokemon in GameState.party.members:
		if pkmn.is_egg() or not pkmn.is_able() or pkmn.level() > cap:
			continue
		eligible += 1
	return eligible >= wanted

## The Frontier screen for choosing a team
## Returns `true` when the player went through with it
func entry_screen(arguments: Array) -> bool:
	if not has_eligible_party(arguments):
		await bridge.say("You do not have enough Pokemon that can enter.")
		return false
	var wanted: int = int(arguments[0]) if not arguments.is_empty() else 3
	return await Field.confirm(Loc.line("Will you enter with {wanted} Pokemon?", {"wanted": wanted}))

## Runs one battle of the challenge the player is on
## Actual challenges are run by [ChallengeRunner]
func challenge_battle() -> bool:
	var facility: StringName = bridge.facilities().challenge_facility()
	return await Field.run_challenge(facility)

## The line a Frontier attendant says at the start of a run
func challenge_begin_speech() -> String:
	var facility_rules: ChallengeRules = ChallengeFacilities.rules_for(bridge.facilities().challenge_facility())
	var title: String = facility_rules.display_name if facility_rules != null else "the challenge"
	return Loc.line("Welcome to {title}! Do your best!", {"title": title})
