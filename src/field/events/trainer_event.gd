@tool
class_name TrainerEvent
extends MapEvent
## A trainer who challenges the player, either on sight or when spoken to

## The self-switch this event remembers having been beaten in
const DEFEATED_SWITCH: String = "A"

## Id of the [TrainerTypeData] record, e.g. `&"YOUNGSTER"`
@export var trainer_type: StringName = &""
@export var trainer_name: String = ""
@export var version: int = 0

@export_group("Dialogue")
## Said when the battle starts
@export_multiline var challenge_lines: Array[String] = []

## Said once the player has won
@export_multiline var defeat_lines: Array[String] = []

## Said when the player talks to them afterwards
@export_multiline var after_lines: Array[String] = []

@export_group("Sight")
## How many cells ahead the trainer notices the player
@export_range(0, 12) var sight_range: int = 0

## Sound played the moment the player is spotted
@export var notice_sound: String = "Exclaim"

var _spotting: bool = false


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint() or sight_range <= 0 or _spotting:
		return
	if map == null or map.is_busy() or not is_active() or is_defeated():
		return
	if _player_in_sight():
		_start_sighting()

func active_trigger() -> EventPage.Trigger:
	return EventPage.Trigger.ACTION_BUTTON

func has_action() -> bool:
	return is_active()

func is_defeated() -> bool:
	if Engine.is_editor_hint():
		return false
	return GameState.get_self_switch(_map_number(), self_switch_key(), DEFEATED_SWITCH)

func run() -> void:
	if is_defeated():
		for line: String in after_lines:
			await Field.say(line)
		return
	await _battle()

## Walks up to the player and fights
func _start_sighting() -> void:
	_spotting = true
	map.run_event(self)

func _battle() -> void:
	if not notice_sound.is_empty() and _spotting:
		AudioManager.play_se(notice_sound)
	if _spotting:
		await _approach_player()
	for line: String in challenge_lines:
		await Field.say(line)
	var outcome: BattlePresenter.Outcome = await Field.trainer_battle(trainer_type, trainer_name, version)
	_spotting = false
	if outcome != BattlePresenter.Outcome.PLAYER_WON:
		return
	Field.set_self_switch(self, DEFEATED_SWITCH, true)
	for line: String in defeat_lines:
		await Field.say(line)

func _approach_player() -> void:
	if map == null or map.player == null:
		return
	var guard: int = sight_range + 1
	while guard > 0:
		var gap: Vector2i = map.player.tile_position - tile_position
		if absi(gap.x) + absi(gap.y) <= 1:
			return
		if not await step(facing):
			return
		guard -= 1

func _player_in_sight() -> bool:
	if map.player == null:
		return false
	var step_vector: Vector2i = facing_vector()
	var cell: Vector2i = tile_position
	for distance: int in range(1, sight_range + 1):
		cell += step_vector
		if map.player.tile_position == cell:
			return true
		if not map.is_standable(cell):
			return false
	return false

func _map_number() -> int:
	return map_scene.map_id if map_scene != null else 0

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super._get_configuration_warnings()
	if String(trainer_type).is_empty() or trainer_name.is_empty():
		warnings.append("This trainer has no trainer type or name, so no party can be found for them.")
	return warnings
