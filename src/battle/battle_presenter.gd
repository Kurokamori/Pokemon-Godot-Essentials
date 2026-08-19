class_name BattlePresenter
extends RefCounted
## The interface which a battle uses to communicate with the outside world

## Battle outcomes reported to [method on_battle_end]
enum Outcome {
	UNDECIDED = 0,
	PLAYER_WON = 1,
	PLAYER_LOST = 2,
	PLAYER_FLED = 3,
	POKEMON_CAUGHT = 4,
	DRAW = 5,
}

var battle: Battle = null



func on_battle_start(_battle: Battle) -> void:
	battle = _battle


func on_battle_end(_outcome: Outcome) -> void:
	pass

## Shows a line of dialogue which awaits the player's confirmation
func show_message(_text: String) -> void:
	await _completed()


## Shows a line that clears on its own
func show_message_brief(_text: String) -> void:
	await _completed()
	
	
# === Actions ===
	
## Asks the [param battler] for an action
## [param is_first_choice] is `true` when this is the first battler on the side being offered a choice
## For controlling when running and pokeballs are offered
##
## Returns `null` to allow AI to choose for the player, mostly used for headless testing OR
## for [method BattleAction.cancel] to go back to the previous battler
func choose_action(_battler: Battler, _is_first_choice: bool) -> BattleAction:
	await _completed()
	return null
	
## Asks for the index of the party slot to send into [battler index]
## Returns `-1` to let the AI pick (agian generally for headless testing)
## [method Battle.active_party_slots] are the slots in the field and cannot be chosen
func choose_replacement(_battler_index: int) -> int:
	await _completed()
	return -1
	
## Chooses whehter to learn [param move_id]
## Returns the overwriten move's slot or  `-1` to skip
func choose_move_to_forget(_pkmn: Pokemon, _move_id: StringName) -> int:
	await _completed()
	return -1
	
func choose_option(_prompt: String, _options: Array) -> int:
	await _completed()
	return -1

## Asks whether the player wants to switch after defeating an opponent
func confirm_switch_after_faint() -> bool:
	await _completed()
	return false

func play_move_animation(_user: Battler, _targets: Array[Battler], _move: MoveData) -> void:
	await _completed()

func play_effect_animation(_target: Battler, _animation: StringName) -> void:
	await _completed()

## Refreshes on-screen HP bars and status icons
func refresh_battler(_battler: Battler) -> void:
	pass

func refresh_all() -> void:
	pass

## Plays the send-out sequence for [param battler]
func play_send_out(_battler: Battler) -> void:
	await _completed()

func play_faint(_battler: Battler) -> void:
	await _completed()

## Plays the Poke Ball throw and shake sequence
## Returns the number of shakes, so the proper message can be displayed
func play_capture(_target: Battler, _ball: StringName, _shakes: int, _caught: bool) -> void:
	await _completed()
	
# === Internals ===

## Awaited by the default implementations of the hook a battle awaits
## This makes a hook a coroutine even when they do nothing
##
## The battle has to await these methods because the visuals suspend inside them
func _completed() -> void:
	@warning_ignore("redundant_await")
	await true
	
