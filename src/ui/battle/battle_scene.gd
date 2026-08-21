extends GameScreen
## The visual battle: the field, the command menu and the message log

const BAG_SCREEN: String = "res://scenes/ui/bag_screen.tscn"
const PARTY_SCREEN: String = "res://scenes/ui/party_screen.tscn"
const LIST_BUTTON_SCENE: PackedScene = preload("res://scenes/battle/battle_list_button.tscn")
## Stands in for a move in a slot the Pokemon has not filled.
const EMPTY_MOVE_TEXT: String = "-"

## Set by whoever opens the scene, before it enters the tree.
var battle: Battle = null

@onready var _field_host: Control = %FieldHost
@onready var _message_panel: PanelContainer = %MessagePanel
@onready var _message_label: RichTextLabel = %BattleMessageLabel
@onready var _command_panel: PanelContainer = %CommandPanel
@onready var _command_grid: GridContainer = %CommandGrid
@onready var _fight_button: Button = %FightButton
@onready var _bag_button: Button = %BagButton
@onready var _pokemon_button: Button = %PokemonButton
@onready var _run_button: Button = %RunButton
@onready var _shift_button: Button = %ShiftButton
@onready var _ball_button: Button = %BallButton
@onready var _bait_button: Button = %BaitButton
@onready var _rock_button: Button = %RockButton
@onready var _call_button: Button = %CallButton
@onready var _ball_count_panel: PanelContainer = %BallCountPanel
@onready var _ball_count_label: Label = %BallCountLabel
@onready var _move_panel: PanelContainer = %MovePanel
@onready var _move_grid: GridContainer = %MoveGrid
@onready var _move_info: Label = %MoveInfoLabel
@onready var _gimmick_button: Button = %GimmickButton
@onready var _target_panel: PanelContainer = %TargetPanel
@onready var _target_list: VBoxContainer = %TargetList
@onready var _target_prompt: Label = %TargetPromptLabel
@onready var _prompt_panel: PanelContainer = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel
@onready var _prompt_list: VBoxContainer = %PromptList

var _field: BattleFieldView = null
var _presenter: ScenePresenter = null

## The battler the command menu is currently asking about.
var _acting_battler: Battler = null

## Set `true` when the first pokemon is choosing, which is the only time running and catching are allowed
var _is_first_choice: bool = true

## The player's chosen action
var _chosen_action: BattleAction = null

var _chosen_prompt_index: int = -2

## The gimmick armed on the move menu
var _armed_gimmick: StringName = &""

## The gimmicks the acting battler could use, refreshed when its menu opens.
var _offered_gimmicks: Array[BattleGimmick] = []

var _watching: bool = false


## Forwards [BattlePresenter] calls to the scene
class ScenePresenter extends BattlePresenter:
	var scene: Node = null

	func _init(owner: Node) -> void:
		scene = owner

	func show_message(text: String) -> void:
		await scene.display_message(text)

	func show_message_brief(text: String) -> void:
		scene.display_message_brief(text)

	func choose_action(battler: Battler, is_first_choice: bool) -> BattleAction:
		return await scene.request_action(battler, is_first_choice)

	func choose_replacement(battler_index: int) -> int:
		return await scene.request_replacement(battler_index)

	func choose_move_to_forget(pkmn: Pokemon, move_id: StringName) -> int:
		return await scene.request_move_to_forget(pkmn, move_id)

	func choose_option(prompt: String, options: Array) -> int:
		return await scene.request_choice(prompt, options)

	func refresh_battler(_battler: Battler) -> void:
		scene.refresh_all_battlers()

	func refresh_all() -> void:
		scene.refresh_all_battlers()

	func on_battle_start(started: Battle) -> void:
		super.on_battle_start(started)
		scene.build_field()

	func play_send_out(sent: Battler) -> void:
		await scene.play_send_out_animation(sent)

	func play_faint(battler: Battler) -> void:
		await scene.play_faint_animation(battler)

	func play_move_animation(user: Battler, targets: Array[Battler], move: MoveData) -> void:
		await scene.play_move(user, targets, move)

	func play_effect_animation(target: Battler, animation: StringName) -> void:
		await scene.play_effect(target, animation)

	func play_capture(target: Battler, ball: StringName, shakes: int, caught: bool) -> void:
		await scene.play_capture_animation(target, ball, shakes, caught)

func _ready() -> void:
	super._ready()
	closes_on_cancel = false
	_hide_menus()
	_fight_button.pressed.connect(_on_fight_pressed)
	_bag_button.pressed.connect(_on_bag_pressed)
	_pokemon_button.pressed.connect(_on_pokemon_pressed)
	_run_button.pressed.connect(_on_run_pressed)
	_shift_button.pressed.connect(_on_shift_pressed)
	_gimmick_button.pressed.connect(_on_gimmick_pressed)
	_ball_button.pressed.connect(_on_ball_pressed)
	_bait_button.pressed.connect(_on_bait_pressed)
	_rock_button.pressed.connect(_on_rock_pressed)
	_call_button.pressed.connect(_on_call_pressed)
	if battle == null:
		push_error("BattleScene: no battle was supplied.")
		return
	_watching = battle.is_replay()
	_presenter = ScenePresenter.new(self)
	battle.presenter = _presenter
	add_child(battle)
	var outcome: BattlePresenter.Outcome = await battle.run()
	await SceneRouter.fade_out()
	close(outcome)

## Builds the field once the battle has decided how big it is
func build_field() -> void:
	if _field != null:
		return
	_field = load(BattleFieldView.SCENE_PATH).instantiate() as BattleFieldView
	if _field == null:
		push_error("BattleScene: %s is missing." % BattleFieldView.SCENE_PATH)
		return
	_field_host.add_child(_field)
	_field.build(battle)
	_field.show_trainer(1)
	if not battle.is_wild_battle():
		_field.show_trainer(0)
	if battle.safari != null:
		battle.safari.balls_changed.connect(_on_balls_changed)
	elif battle.contest != null:
		battle.contest.balls_changed.connect(_on_balls_changed)
	_refresh_ball_count()
	_reveal.call_deferred()

## Fades the screen back in now that there is a battlefield to look at
func _reveal() -> void:
	await SceneRouter.fade_in()

func _on_balls_changed(_remaining: int) -> void:
	_refresh_ball_count()

func _hide_menus() -> void:
	_command_panel.visible = false
	_move_panel.visible = false
	_target_panel.visible = false
	_prompt_panel.visible = false
	_set_full_width_menu(false)

func _set_full_width_menu(shown: bool, covers_panels: bool = true) -> void:
	_message_panel.visible = not shown
	if _field != null:
		_field.set_panels_visible(not (shown and covers_panels))

# === Presentation ===

func display_message(text: String) -> void:
	_message_label.text = text
	var seconds: float = GameSettings.data.battle_message_seconds
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout

func display_message_brief(text: String) -> void:
	_message_label.text = text

func refresh_all_battlers() -> void:
	if _field != null:
		_field.refresh()

func play_send_out_animation(battler: Battler) -> void:
	if _field == null:
		return
	if battle.is_safari_battle() and battler.is_player_side():
		return
	var animated: bool = GameSettings.data.battle_animations
	if animated:
		if battler.is_player_side():
			await _field.play_player_throw()
		else:
			await _field.hide_trainer(1)
	_field.refresh()
	await _field.play_send_out(battler, animated)

func play_faint_animation(battler: Battler) -> void:
	if _field == null:
		return
	var sprite: BattlerSprite = _field.sprite_for(battler)
	if sprite != null and GameSettings.data.battle_animations:
		await sprite.play_faint()
	_field.refresh()

func play_move(user: Battler, targets: Array[Battler], move: MoveData) -> void:
	if _field != null and GameSettings.data.battle_animations:
		await _field.play_move_animation(user, targets, move)

func play_effect(target: Battler, animation: StringName) -> void:
	if _field != null and GameSettings.data.battle_animations:
		await _field.play_common_animation(animation, target)

func play_capture_animation(target: Battler, _ball: StringName, shakes: int, caught: bool) -> void:
	if _field == null or not GameSettings.data.battle_animations:
		return
	var sprite: BattlerSprite = _field.sprite_for(target)
	if sprite == null:
		return
	for _shake: int in range(maxi(shakes, 1)):
		await sprite.play_wobble()
	if caught:
		await sprite.play_absorb()

# === Decisions ===

## Runs the command menu for one battler and returns what the player picked
func request_action(battler: Battler, is_first_choice: bool) -> BattleAction:
	_acting_battler = battler
	_is_first_choice = is_first_choice
	_chosen_action = null
	_armed_gimmick = &""
	_offered_gimmicks = BattleGimmicks.available_for(battle, battler)
	_message_label.text = "What will you do?" if battle.is_safari_battle() 		else Loc.line("What will {pokemon} do?", {"pokemon": battler.display_name()})
	_show_command_menu()
	while _chosen_action == null:
		await get_tree().process_frame
	_hide_menus()
	_acting_battler = null
	var action: BattleAction = _chosen_action
	_chosen_action = null
	return action

func _show_command_menu() -> void:
	_hide_menus()
	_command_panel.visible = true
	var safari: bool = battle.is_safari_battle()
	var contest: bool = battle.is_bug_contest_battle()
	_fight_button.visible = not safari
	_bag_button.visible = not safari and not contest
	_pokemon_button.visible = not safari
	_ball_button.visible = safari or contest
	_bait_button.visible = safari
	_rock_button.visible = safari
	_ball_button.disabled = not battle.can_throw_poke_ball()
	_run_button.disabled = not battle.can_run or not _is_first_choice
	_shift_button.visible = battle.can_shift(_acting_battler)
	_call_button.visible = battle.can_call_to(_acting_battler)
	var first: Button = _first_command_button()
	if first != null:
		first.grab_focus()

## The button focus starts on
func _first_command_button() -> Button:
	var fallback: Button = null
	for child: Node in _command_grid.get_children():
		var button: Button = child as Button
		if button == null or not button.visible:
			continue
		if not button.disabled:
			return button
		if fallback == null:
			fallback = button
	return fallback

## Keeps the balls-left readout up to date
func _refresh_ball_count() -> void:
	var supplied: StringName = battle.supplied_ball()
	_ball_count_panel.visible = not supplied.is_empty()
	if not _ball_count_panel.visible:
		return
	var record: ItemData = Database.item(supplied)
	var plural: String = record.name_plural if record != null and not record.name_plural.is_empty() else "Balls"
	_ball_count_label.text = "%s: %d" % [plural, _balls_left()]

func _balls_left() -> int:
	if battle.safari != null:
		return battle.safari.balls_left
	if battle.contest != null:
		return battle.contest.balls_left
	return 0

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_pressed("game_debug") and GameSettings.data.debug_mode:
		if _acting_battler != null and not _watching:
			get_viewport().set_input_as_handled()
			_open_debug_menu()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _watching:
		get_viewport().set_input_as_handled()
		play_select()
		battle.outcome = BattlePresenter.Outcome.DRAW
		return
	if _acting_battler == null:
		return
	get_viewport().set_input_as_handled()
	if _target_panel.visible:
		play_select()
		_show_moves(_acting_battler)
		return
	if _move_panel.visible:
		play_select()
		_show_command_menu()
		return
	if not _is_first_choice:
		play_select()
		_chosen_action = BattleAction.cancel(_acting_battler.index)

func _open_debug_menu() -> void:
	var scene: PackedScene = load(BattleDebugScreen.SCENE_PATH)
	if scene == null:
		return
	await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.setup(battle)
	)
	if battle.outcome != BattlePresenter.Outcome.UNDECIDED:
		return
	refresh_all_battlers()
	_show_command_menu()

func _on_fight_pressed() -> void:
	if _acting_battler == null:
		return
	play_confirm()
	_show_moves(_acting_battler)

func _show_moves(battler: Battler) -> void:
	_hide_menus()
	for child: Node in _move_grid.get_children():
		child.queue_free()
	var moves: Array[PokemonMove] = battler.moves()
	var slots: int = maxi(GameSettings.data.max_moves, moves.size())
	var first: Button = null
	for slot: int in range(slots):
		var move: PokemonMove = moves[slot] if slot < moves.size() else null
		var record: MoveData = move.data() if move != null else null
		var button: BattleListButton = LIST_BUTTON_SCENE.instantiate()
		_move_grid.add_child(button)
		if record == null:
			button.set_entry(EMPTY_MOVE_TEXT)
			button.disabled = true
			continue
		button.set_entry(record.display_name, "%d/%d" % [move.pp, move.total_pp()])
		button.disabled = not battler.can_use_move(move)
		button.pressed.connect(_on_move_chosen.bind(move))
		button.focus_entered.connect(_on_move_focused.bind(record))
		if first == null and not button.disabled:
			first = button
	_move_panel.visible = true
	_set_full_width_menu(true, false)
	_refresh_gimmick_button()
	if first == null:
		_on_move_chosen(PokemonMove.create(&"STRUGGLE"))
		return
	_move_info.text = ""
	first.grab_focus()

## Shows the button that arms Mega Evolution, a Z-Move, Dynamax or a Tera type
func _refresh_gimmick_button() -> void:
	_gimmick_button.visible = not _offered_gimmicks.is_empty()
	if _offered_gimmicks.is_empty():
		return
	var armed: BattleGimmick = _armed_gimmick_record()
	if armed != null:
		_gimmick_button.text = "%s ✓" % armed.menu_text
		return
	_gimmick_button.text = _offered_gimmicks[0].menu_text

func _armed_gimmick_record() -> BattleGimmick:
	for gimmick: BattleGimmick in _offered_gimmicks:
		if gimmick.id == _armed_gimmick:
			return gimmick
	return null

## Arms the next gimmick in the list, or disarms when the end is reached
func _on_gimmick_pressed() -> void:
	play_confirm()
	if _offered_gimmicks.is_empty():
		return
	var armed: BattleGimmick = _armed_gimmick_record()
	var next: int = 0 if armed == null else _offered_gimmicks.find(armed) + 1
	_armed_gimmick = _offered_gimmicks[next].id if next < _offered_gimmicks.size() else &""
	_refresh_gimmick_button()

## Writes out the move the player is looking at, on the one line under the grid
func _on_move_focused(record: MoveData) -> void:
	_move_info.text = Loc.line("{type}   Power {value}   Acc {value2}", {"type": record.type, "value": "-" if record.power <= 1 else str(record.power), "value2": "-" if record.accuracy == 0 else str(record.accuracy)})

func _on_move_chosen(move: PokemonMove) -> void:
	play_confirm()
	if _acting_battler == null:
		return
	var choices: Array[Battler] = battle.choosable_targets(_acting_battler, move.data())
	if choices.is_empty():
		_chosen_action = BattleAction.use_move(_acting_battler.index, move, [], _armed_gimmick)
		return
	_show_targets(move, choices)

func _show_targets(move: PokemonMove, choices: Array[Battler]) -> void:
	_hide_menus()
	for child: Node in _target_list.get_children():
		child.queue_free()
	var record: MoveData = move.data()
	_target_prompt.text = Loc.line("Use {record} on whom?", {"record": (record.get_translated_name() if record != null else "the move")})
	var first: Button = null
	for target: Battler in choices:
		var button: BattleListButton = LIST_BUTTON_SCENE.instantiate()
		_target_list.add_child(button)
		var side_text: String = "ally" if target.side_index() == _acting_battler.side_index() else "foe"
		button.set_entry("%s (%s)" % [target.battle_name(), side_text],
			"%d/%d" % [target.hp(), target.total_hp()])
		button.pressed.connect(_on_target_chosen.bind(move, target))
		if first == null:
			first = button
	_target_panel.visible = true
	_set_full_width_menu(true)
	if first != null:
		first.grab_focus()

## Puts a short question to the player and returns the index they picked
## Returns `-1` if they back out
func request_choice(prompt: String, options: Array) -> int:
	_hide_menus()
	for child: Node in _prompt_list.get_children():
		child.queue_free()
	_prompt_label.text = prompt
	_chosen_prompt_index = -2
	var first: BattleListButton = null
	for index: int in range(options.size()):
		var button: BattleListButton = LIST_BUTTON_SCENE.instantiate()
		_prompt_list.add_child(button)
		button.set_entry(String(options[index]), "")
		button.pressed.connect(_on_prompt_chosen.bind(index))
		if first == null:
			first = button
	_prompt_panel.visible = true
	_set_full_width_menu(true)
	if first != null:
		first.grab_focus()
	while _chosen_prompt_index == -2:
		await get_tree().process_frame
	_prompt_panel.visible = false
	return _chosen_prompt_index

func _on_prompt_chosen(index: int) -> void:
	play_confirm()
	_chosen_prompt_index = index

func _on_target_chosen(move: PokemonMove, target: Battler) -> void:
	play_confirm()
	if _acting_battler == null:
		return
	_chosen_action = BattleAction.use_move(_acting_battler.index, move, [target.index], _armed_gimmick)

func _on_bag_pressed() -> void:
	if _acting_battler == null:
		return
	var scene: PackedScene = load(BAG_SCREEN)
	if scene == null:
		return
	var result: Variant = await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.selection_mode = true
		instance.battle_mode = true
	)
	if result == null:
		_show_command_menu()
		return
	var item_id: StringName = StringName(result)
	var record: ItemData = Database.item(item_id)
	if record != null and record.is_poke_ball():
		if not _is_first_choice:
			display_message_brief("It's impossible to aim without being focused!")
			_show_command_menu()
			return
		if not battle.can_throw_poke_ball(item_id):
			display_message_brief(
				"The Trainer blocked your Poke Ball! Don't be a thief!"
				if battle.kind == Battle.Kind.TRAINER
				else "It's impossible to aim with two Pokemon in the way!")
			_show_command_menu()
			return
	if record != null and not _acts_on_a_pokemon(record):
		if not ItemEffects.can_use_in_battle(battle, _acting_battler, item_id):
			display_message_brief("It won't have any effect.")
			_show_command_menu()
			return
	var target_slot: int = _acting_battler.party_index
	if record != null and _acts_on_a_pokemon(record):
		target_slot = await _choose_party_member_for_item(record)
		if target_slot < 0:
			_show_command_menu()
			return
	var move_index: int = -1
	if record != null and record.battle_use == ItemData.BattleUse.ON_MOVE:
		move_index = await _choose_move_for_item(record, GameState.party.get_member(target_slot))
		if move_index < 0:
			_show_command_menu()
			return
	_chosen_action = BattleAction.use_item(
		_acting_battler.index, item_id, target_slot, move_index
	)

## Returns `true` when the item is used on a Pokemon in the party
func _acts_on_a_pokemon(record: ItemData) -> bool:
	return (
		record.battle_use == ItemData.BattleUse.ON_POKEMON
		or record.battle_use == ItemData.BattleUse.ON_MOVE
	)

## Opens the party screen as a chooser for an item
## Returns a party slot or `-1` when the player backed out
func _choose_party_member_for_item(record: ItemData) -> int:
	var scene: PackedScene = load(PARTY_SCREEN)
	if scene == null:
		return -1
	var result: Variant = await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.selection_mode = true
		instance.filter_item = record.id
	)
	if result == null:
		return -1
	var slot: int = int(result)
	var pkmn: Pokemon = GameState.party.get_member(slot)
	return slot if pkmn != null and ItemUsage.can_use_on(record, pkmn) else -1

## Asks which of [param pkmn]'s moves an item used on a move is for
## Displays the move's remaining PP beside it
## Returns `-1` on cancel
func _choose_move_for_item(record: ItemData, pkmn: Pokemon) -> int:
	if pkmn == null:
		return -1
	var options: Array = []
	for move: PokemonMove in pkmn.moves:
		var known: MoveData = move.data()
		options.append("%s  %d/%d" % [
			known.display_name if known != null else String(move.id), move.pp, move.total_pp()
		])
	if options.is_empty():
		return -1
	var prompt: String = String(
		ItemUsage.MOVE_TARGET_ITEMS.get(record.id, "Use it on which move?")
	)
	var chosen: int = await request_choice(prompt, options)
	return -1 if chosen < 0 or chosen >= pkmn.moves.size() else chosen

func _on_pokemon_pressed() -> void:
	if _acting_battler == null:
		return
	var index: int = await request_replacement(_acting_battler.index)
	if index < 0:
		_show_command_menu()
		return
	_chosen_action = BattleAction.switch_out(_acting_battler.index, index)

func _on_call_pressed() -> void:
	if _acting_battler == null:
		return
	play_confirm()
	_chosen_action = BattleAction.call_to(_acting_battler.index)

func _on_run_pressed() -> void:
	if _acting_battler == null:
		return
	play_confirm()
	_chosen_action = BattleAction.run(_acting_battler.index)

func _on_shift_pressed() -> void:
	if _acting_battler == null:
		return
	play_confirm()
	_chosen_action = BattleAction.shift(_acting_battler.index)

## Throws the ball the battle supplies rather than one out of the bag
func _on_ball_pressed() -> void:
	if _acting_battler == null:
		return
	var ball: StringName = battle.supplied_ball()
	if ball.is_empty():
		return
	play_confirm()
	_chosen_action = BattleAction.use_item(_acting_battler.index, ball, _acting_battler.party_index)

func _on_bait_pressed() -> void:
	if _acting_battler == null:
		return
	play_confirm()
	_chosen_action = BattleAction.throw_bait(_acting_battler.index)

func _on_rock_pressed() -> void:
	if _acting_battler == null:
		return
	play_confirm()
	_chosen_action = BattleAction.throw_rock(_acting_battler.index)

## Opens the party screen to pick who comes in at [param _battler_index]
func request_replacement(_battler_index: int) -> int:
	var scene: PackedScene = load(PARTY_SCREEN)
	if scene == null:
		return -1
	var unavailable: Array[int] = battle.active_party_slots(0)
	var result: Variant = await SceneRouter.push_screen(scene, func(instance: Node) -> void:
		instance.selection_mode = true
		instance.unavailable_slots = unavailable
	)
	if result == null:
		return -1
	var index: int = int(result)
	if unavailable.has(index):
		return -1
	var pkmn: Pokemon = GameState.party.get_member(index)
	if pkmn == null or not pkmn.is_able():
		return -1
	return index

func request_move_to_forget(pkmn: Pokemon, move_id: StringName) -> int:
	if _watching:
		return -1
	var record: MoveData = Database.move(move_id)
	await display_message(Loc.line("{pokemon} wants to learn {record}, but already knows four moves.", {"pokemon": pkmn.display_name(), "record": record.get_translated_name() if record != null else String(move_id)}))
	var options: Array = []
	for move: PokemonMove in pkmn.moves:
		var known: MoveData = move.data()
		options.append(known.display_name if known != null else String(move.id))
	options.append("Don't learn %s" % (record.display_name if record != null else String(move_id)))
	var chosen: int = await request_choice("Forget which move?", options)
	return -1 if chosen < 0 or chosen >= pkmn.moves.size() else chosen
