class_name EventScriptGlobals
extends RefCounted
## The vocabulary of bare calls
## Seperated from the [EventScriptBridge] for easy extensibility

const CHALLENGE_FACILITIES: Dictionary = {
	"tower": &"BATTLETOWER",
	"factory": &"BATTLEFACTORY",
	"palace": &"BATTLEPALACE",
	"arena": &"BATTLEARENA",
	"dome": &"BATTLEDOME",
	"pike": &"BATTLEPIKE",
	"pyramid": &"BATTLEPYRAMID",
	"hall": &"BATTLEHALL",
	"pikacup": &"BATTLETOWER",
	"fancycup": &"BATTLETOWER",
	"pokecup": &"BATTLETOWER",
	"littlecup": &"BATTLETOWER",
}

const LOTTERY_DIGITS: int = 5
const LOTTERY_RANGE: int = 65536
const LOTTERY_IN_PARTY: int = 1
const LOTTERY_IN_STORAGE: int = 2

## The scenes `pbEventScreen` can dispatch
const EVENT_SCENES: Dictionary = {
	"ButtonEventScene": ControlsHelpScreen.SCENE_PATH,
}

## The bridge this is dispatching for, weakly held as the rest of the event_scrit files to avoid circular dependencies
var bridge: EventScriptBridge:
	get:
		return _bridge.get_ref() as EventScriptBridge if _bridge != null else null

var _bridge: WeakRef = null



func _init(for_bridge: EventScriptBridge) -> void:
	_bridge = weakref(for_bridge)
	
## Runs bar call [param method]
## [param raw] is the snipped as written, used for error reporting
func call_global(method: String, arguments: Array, raw: String) -> Variant:
	if method == "pbEventScreen":
		return await _event_screen(arguments, raw)
	var result: Variant = await _minigame_calls(method, arguments, raw)
	if not (result is EventScriptBridge.Unsupported):
		return result
	result = await _game_state_calls(method, arguments, raw)
	if not (result is EventScriptBridge.Unsupported):
		return result
	result = await _item_calls(method, arguments, raw)
	if not (result is EventScriptBridge.Unsupported):
		return result
	result = await _pokemon_calls(method, arguments, raw)
	if not (result is EventScriptBridge.Unsupported):
		return result
	result = await _battle_calls(method, arguments, raw)
	if not (result is EventScriptBridge.Unsupported):
		return result
	result = await _presentation_calls(method, arguments, raw)
	if not (result is EventScriptBridge.Unsupported):
		return result
	return await _facility_calls(method, arguments, raw)

# === Internals ===

# === Minigames ===

## The minigame the event opens, each is a named scene in [MinigameLibrary]
func _minigame_calls(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"pbVoltorbFlip":
			return await Minigames.voltorb_flip()
		"pbSlotMachine":
			var difficulty: int = int(_number(arguments[0])) if not arguments.is_empty() else 1
			return await Minigames.slot_machine(difficulty)
		"pbMiningGame":
			return await Minigames.mining()
		"pbTilePuzzle":
			return await _tile_puzzle(arguments)
		"pbTriadDuel":
			return await _triad_duel(arguments)
		"pbCanTriadDuel?":
			return Minigames.can_play_triad()
		"pbBuyTriads":
			await Minigames.buy_triad_cards()
			return true
		"pbSellTriads":
			await Minigames.sell_triad_cards()
			return true
		"pbTriadList":
			await Minigames.show_triad_cards()
			return true
		"pbGiveTriadCard":
			if not arguments.is_empty():
				return Minigames.give_triad_card(_id(arguments[0]), _quantity(arguments, 1))
		"pbDuel":
			return await _duel(arguments)
		"pbMinigame":
			if not arguments.is_empty():
				return await Minigames.open(_id(arguments[0]))
	return EventScriptBridge.Unsupported.new(raw)
	
## `pbTilePuzzle(game, board, width, height)`
func _tile_puzzle(arguments: Array) -> Variant:
	if arguments.size() < 2:
		return EventScriptBridge.Unsupported.new("pbTilePuzzle")
	return await Minigames.tile_puzzle(
		int(_number(arguments[0])), _id(arguments[1]),
		int(_number(arguments[2])) if arguments.size() >= 3 else 0,
		int(_number(arguments[3])) if arguments.size() >= 4 else 0
	)
	
## `pbTriadDuel(name, min_level, max_level, rules, opponent_deck, prize)` 
## Last three options are optional and can be written as `nil` to access later options
func _triad_duel(arguments: Array) -> Variant:
	if arguments.is_empty():
		return EventScriptBridge.Unsupported.new("pbTriadDuel")
	return await Minigames.triad_duel(
		String(arguments[0]),
		int(_number(arguments[1])) if arguments.size() >= 2 else 0,
		int(_number(arguments[2])) if arguments.size() >= 3 else 5,
		_as_list_or_empty(arguments, 3),
		_as_list_or_empty(arguments, 4),
		_id(arguments[5]) if arguments.size() >= 6 and arguments[5] != null else &""
	)

## `pbDuel(trainer_type, name, event, speeches)`
func _duel(arguments: Array) -> Variant:
	if arguments.size() < 2:
		return EventScriptBridge.Unsupported.new("pbDuel")
	var event: MapEvent = bridge.current_event()
	if arguments.size() >= 3 and arguments[2] is MapEvent:
		event = arguments[2]
	var speeches: Array = GameState.speeches
	if arguments.size() >= 4 and arguments[3] is Array:
		speeches = arguments[3]
	return await Minigames.duel(_id(arguments[0]), String(arguments[1]), event, speeches)
	
# === Switches or Variables ===

func _game_state_calls(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"pbSet":
			if arguments.size() >= 2:
				GameState.set_variable(int(_number(arguments[0])), arguments[1])
				return arguments[1]
		"pbGet":
			if arguments.size() >= 1:
				return GameState.get_variable(int(_number(arguments[0])))
		"setVariable":
			if arguments.size() >= 1:
				GameState.set_variable(EventScriptBridge.DEFAULT_VARIABLE, arguments[0])
				return arguments[0]
		"getVariable":
			return GameState.get_variable(EventScriptBridge.DEFAULT_VARIABLE)
		"pbSetSelfSwitch":
			if arguments.size() >= 3:
				return bridge.set_self_switch(
					int(_number(arguments[0])), String(arguments[1]), _truthy(arguments[2])
				)
		"rand":
			if arguments.size() >= 1:
				return RNG.below(maxi(int(_number(arguments[0])), 1))
			return RNG.generator.randf()
		"rename_choice":
			if arguments.size() >= 2 and bridge.interpreter != null:
				bridge.interpreter.rename_choice(int(_number(arguments[0])), String(arguments[1]))
				return true
		"hide_choice":
			if not arguments.is_empty() and bridge.interpreter != null:
				var hidden: bool = arguments.size() < 2 or _truthy(arguments[1])
				bridge.interpreter.hide_choice(int(_number(arguments[0])), hidden)
				return true
		"_I", "_INTL", "_ISPRINTF":
			return _format(arguments)
		"pbMessage":
			if not arguments.is_empty():
				await bridge.say(String(arguments[0]))
				return true
		"pbConfirmMessage":
			if not arguments.is_empty():
				return await Field.confirm(String(arguments[0]))
		"pbSetEventTime":
			bridge.set_event_time()
			return true
		"pbSetPokemonCenter":
			GameState.set_healing_spot()
			return true
		"pbCommonEvent":
			if arguments.is_empty():
				return false
			return await CommonEvents.run_now(
				bridge.interpreter, int(_number(arguments[0])), bridge.current_event())
		"pbSetEscapePoint":
			GameState.set_escape_point()
			return true
		"pbEraseEscapePoint":
			GameState.clear_escape_point()
			return true
		"pbIsWeekday":
			return _is_weekday(arguments)
		"pbIsWeekend?":
			return _is_weekday([0, 6])
		"pbSaveScreen":
			return await _open_screen(EventScriptBridge.SAVE_SCREEN)
		"pbShowMap":
			var map_region: int = int(_number(arguments[0])) if not arguments.is_empty() else -1
			var wall_map: bool = _truthy(arguments[1]) if arguments.size() >= 2 else true
			await Field.show_town_map(wall_map, map_region)
			return true
		"pbTrainerCard":
			await Field.show_trainer_card()
			return true
		"pbPurifyChamber":
			await Field.show_purify_chamber()
			return true
		"pbRelicStone":
			await RelicStone.use()
			return true
		"pbPokeCenterPC":
			await Field.open_pc()
			return true
		"pbTrainerPC":
			await Field.open_trainer_pc()
			return true
		"pbGetStorageCreator":
			var metadata: MetadataData = Database.metadata()
			return metadata.storage_creator if metadata != null else "Bill"
		"pbPokerus?":
			for pkmn: Pokemon in GameState.party.members:
				if pkmn.has_pokerus():
					return true
			return false
		"pbHallOfFameEntry":
			return await _hall_of_fame()
	return EventScriptBridge.Unsupported.new(raw)

# === Items ===

func _item_calls(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"pbItemBall":
			if not arguments.is_empty():
				return await FieldItems.take_from_event(
					bridge.current_event(), arguments[0], _quantity(arguments, 1)
				)
		"pbReceiveItem":
			if not arguments.is_empty():
				return await FieldItems.received(arguments[0], _quantity(arguments, 1))
		"pbBuyPrize":
			if not arguments.is_empty():
				return await FieldItems.bought_prize(arguments[0], _quantity(arguments, 1))
		"pbPickBerry":
			if not arguments.is_empty():
				return await FieldItems.pick_berry(
					bridge.current_event(), arguments[0], _quantity(arguments, 1)
				)
		"pbBerryPlant":
			await FieldItems.berry_plant(bridge.current_event())
			return true
		"pbPokemonMart":
			if not arguments.is_empty():
				await FieldItems.open_mart(_as_list(arguments[0]))
				return true
		"pbBattlePointShop":
			if not arguments.is_empty():
				await FieldItems.open_battle_point_shop(_as_list(arguments[0]))
				return true
		"setPrice":
			if arguments.size() >= 2:
				MartStock.set_price(_id(arguments[0]), int(_number(arguments[1])))
				return true
		"setSellPrice":
			if arguments.size() >= 2:
				MartStock.set_sell_price(_id(arguments[0]), int(_number(arguments[1])))
				return true
		"pbChooseApricorn":
			return await _choose_item_of_kind(arguments, "APRICORN", "Which Apricorn?")
		"pbChooseFossil":
			return await _choose_item_of_kind(arguments, "FOSSIL", "Which fossil?")
		"pbChooseItem":
			return await _choose_item_of_kind(arguments, "", "Which item?")
		"pbReceiveMysteryGift":
			if not arguments.is_empty():
				return await _receive_mystery_gift(int(_number(arguments[0])))
		"pbNextMysteryGiftID":
			return _next_mystery_gift_id()
		"pbSetLotteryNumber":
			return _set_lottery_number(arguments)
		"pbLottery":
			return _run_lottery(arguments)
	return EventScriptBridge.Unsupported.new(raw)
	
## Asks the player to choose an item of a sort -- and writes it into the supplied variable
func _choose_item_of_kind(arguments: Array, needle: String, prompt: String) -> Variant:
	var variable: int = int(_number(arguments[0])) if not arguments.is_empty() else 0
	var found: Array[StringName] = []
	var options: Array = []
	for item_id: StringName in GameState.bag.all_item_ids():
		var record: ItemData = Database.item(item_id)
		if record == null:
			continue
		if not needle.is_empty() and not String(item_id).contains(needle):
			continue
		found.append(item_id)
		options.append("%s  x%d" % [record.display_name, GameState.bag.quantity_of(item_id)])
	if found.is_empty():
		if variable > 0:
			GameState.set_variable(variable, &"NONE")
		return &"NONE"
	options.append("Cancel")
	var chosen: int = await Field.ask(options, prompt, options.size())
	var picked: StringName = found[chosen] if chosen >= 0 and chosen < found.size() else &"NONE"
	if variable > 0:
		GameState.set_variable(variable, picked)
	return picked	

# === Pokemon ===

func _pokemon_calls(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"pbAddPokemon":
			return await bridge.give_pokemon(arguments, true)
		"pbAddPokemonSilent":
			return await bridge.give_pokemon(arguments, false)
		"pbAddToParty":
			if arguments.size() >= 1:
				return bridge.add_to_party(arguments[0], int(_number(arguments[1])) if arguments.size() >= 2 else 5)
		"pbAddForeignPokemon":
			if arguments.size() >= 3:
				return await bridge.give_foreign_pokemon(arguments)
		"pbBoxesFull?":
			return GameState.storage.first_box_with_room() < 0
		"pbGetPokemon":
			if not arguments.is_empty():
				return FieldPokemon.from_variable(int(_number(arguments[0])))
		"pbChoosePokemon":
			return await FieldPokemon.choose(
				_variable(arguments, 0), _variable(arguments, 1), _filter(arguments, 2)
			)
		"pbChooseNonEggPokemon":
			return await FieldPokemon.choose_non_egg(_variable(arguments, 0), _variable(arguments, 1))
		"pbChooseAblePokemon":
			return await FieldPokemon.choose_able(_variable(arguments, 0), _variable(arguments, 1))
		"pbChooseTradablePokemon":
			return await FieldPokemon.choose_tradable(
				_variable(arguments, 0), _variable(arguments, 1), _filter(arguments, 2)
			)
		"pbChoosePokemonForTrade":
			return await _choose_for_trade(arguments)
		"pbFirstAblePokemon":
			return FieldPokemon.first_able(_variable(arguments, 0), _variable(arguments, 1))
		"pbChooseMove":
			if not arguments.is_empty():
				return await _choose_move(arguments)
		"pbMoveTutorChoose":
			if not arguments.is_empty():
				return await FieldPokemon.tutor_move(_id(arguments[0]))
		"pbRelearnMoveScreen":
			if not arguments.is_empty() and arguments[0] is Pokemon:
				return await FieldPokemon.relearn_move(arguments[0])
		"pbHiddenPower":
			if not arguments.is_empty() and arguments[0] is Pokemon:
				var result: Dictionary = arguments[0].hidden_power()
				return [result.get("type", &"NORMAL"), result.get("power", 60)]
		"pbEvolutionEvent":
			# The argument is the evolution event's own number, not a game variable
			return await FieldPokemon.evolution_event(int(_number(arguments[0])) if not arguments.is_empty() else 0)
		"pbStartTrade":
			if arguments.size() >= 2:
				return await FieldPokemon.trade(
					int(_number(arguments[0])), arguments[1],
					String(arguments[2]) if arguments.size() >= 3 else "",
					String(arguments[3]) if arguments.size() >= 4 else "",
					int(_number(arguments[4])) if arguments.size() >= 5 else 0
				)
		"pbGenerateEgg":
			if not arguments.is_empty():
				return await FieldPokemon.generate_egg(
					_id(arguments[0]), String(arguments[1]) if arguments.size() >= 2 else ""
				)
		"pbTextEntry":
			return await _text_entry(arguments)
		"pbEnterNPCName":
			return await _npc_name(arguments)
		"pbTrainerName":
			return await _player_name(arguments)
	return EventScriptBridge.Unsupported.new(raw)

func _choose_move(arguments: Array) -> Variant:
	var pkmn: Pokemon = arguments[0] if arguments[0] is Pokemon else null
	if pkmn == null:
		return -1
	var index: int = await FieldPokemon.choose_move(pkmn)
	var variable: int = _variable(arguments, 1)
	if variable > 0:
		GameState.set_variable(variable, index)
	if arguments.size() >= 3:
		var name_variable: int = int(_number(arguments[2]))
		var record: MoveData = Database.move(pkmn.moves[index].id) if index >= 0 else null
		if name_variable > 0:
			GameState.set_variable(name_variable, record.display_name if record != null else "")
	return index

## `pbChoosePokemonForTrade(slot_var, name_var, wanted_species)` 
## Only accepts the asked for species
func _choose_for_trade(arguments: Array) -> Variant:
	var wanted: StringName = _id(arguments[2]) if arguments.size() >= 3 else &""
	return await FieldPokemon.choose_tradable(
		_variable(arguments, 0), _variable(arguments, 1),
		func(pkmn: Pokemon) -> bool: return wanted == &"" or pkmn.species == wanted
	)

func _text_entry(arguments: Array) -> Variant:
	var prompt: String = String(arguments[0]) if not arguments.is_empty() else "Enter a name."
	var max_length: int = int(_number(arguments[2])) if arguments.size() >= 3 else 10
	var variable: int = int(_number(arguments[3])) if arguments.size() >= 4 else 0
	return await FieldPokemon.enter_text(prompt, "", max_length, variable)

func _npc_name(arguments: Array) -> Variant:
	var prompt: String = String(arguments[0]) if not arguments.is_empty() else "Enter a name."
	var max_length: int = int(_number(arguments[2])) if arguments.size() >= 3 else 10
	var fallback: String = String(arguments[3]) if arguments.size() >= 4 else ""
	return await FieldPokemon.enter_text(prompt, fallback, max_length)

## `pbTrainerName` asks the player to name Someone/Something 
## With no arguments, the player is asked to name themselves
func _player_name(arguments: Array) -> Variant:
	if GameState.player == null:
		return ""
	if not arguments.is_empty():
		GameState.player.name = String(arguments[0])
		return GameState.player.name
	GameState.player.name = await FieldPokemon.enter_text(
		"What is your name?", GameState.player.name, GameSettings.data.max_player_name_size
	)
	return GameState.player.name

# === Battle ===

func _battle_calls(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"pbTrainerIntro":
			return bridge.battles().trainer_intro(_id(arguments[0]) if not arguments.is_empty() else &"")
		"pbTrainerEnd":
			return bridge.battles().trainer_end()
		"pbTrainerCheck":
			return bridge.battles().trainer_exists(arguments)
		"setBattleRule":
			return bridge.battles().set_rule(arguments)
		"pbCanDoubleBattle?", "pbDoubleBattleAllowed?":
			return GameState.party.able_count() >= 2
		"pbRecordLastBattle":
			return bridge.battles().record_last_battle()
		"pbPlayLastBattle":
			return await bridge.battles().play_last_battle()
		"pbRegisterPartner":
			return bridge.battles().register_partner(arguments)
		"pbDeregisterPartner":
			GameState.partner_trainer = null
			return true
		"pbChangePlayer":
			if not arguments.is_empty():
				return bridge.battles().change_player(int(_number(arguments[0])))
		"pbHasEligible?":
			return bridge.battles().has_eligible_party(arguments)
		"pbEntryScreen":
			return await bridge.battles().entry_screen(arguments)
		"pbBattleChallengeGraphic":
			return true
		"pbBattleChallengeBattle":
			return await bridge.battles().challenge_battle()
		"pbBattleChallengeBeginSpeech":
			return bridge.battles().challenge_begin_speech()
		"pbSmashThisEvent":
			return await bridge.smash_current_event()
		"pbPushThisBoulder":
			return await bridge.push_current_event()
		"pbRockSmashRandomEncounter":
			return await FieldMoves.rock_smash_encounter()
		"pbRockSmash":
			return await HiddenMoves.for_field().ask_to_rock_smash()
		"pbCut":
			return await HiddenMoves.for_field().ask_to_cut()
		"pbHeadbutt":
			return await HiddenMoves.for_field().offer_headbutt()
		"pbStrength":
			return await HiddenMoves.for_field().offer_strength()
		"pbWaterfall":
			return await HiddenMoves.for_field().offer_waterfall()
		"pbSweetScent":
			return await FieldMoves.sweet_scent()
	return EventScriptBridge.Unsupported.new(raw)

# === Presentation ===

func _presentation_calls(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"pbNoticePlayer":
			var event: MapEvent = arguments[0] if not arguments.is_empty() and arguments[0] is MapEvent else bridge.current_event()
			await FieldEffects.notice_player(event, arguments.size() >= 2 and _truthy(arguments[1]))
			return true
		"pbExclaim":
			var who: Variant = arguments[0] if not arguments.is_empty() else bridge.current_event()
			await _exclaim(who)
			return true
		"pbToneChangeAll":
			return await _tone_change(arguments)
		"pbFadeOutIn":
			await FieldEffects.fade_out_in()
			return true
		"pbBridgeOn":
			GameState.set_variable(EventScriptBridge.BRIDGE_VARIABLE, _height(arguments))
			return true
		"pbBridgeOff":
			GameState.set_variable(EventScriptBridge.BRIDGE_VARIABLE, 0)
			return true
		"pbCaveEntrance", "pbCaveExit":
			await FieldEffects.fade_out_in()
			return true
		"follower_animation", "follower_move_route":
			return true
	return EventScriptBridge.Unsupported.new(raw)

func _exclaim(who: Variant) -> void:
	if who is Array:
		for entry: Variant in who:
			if entry is GridCharacter:
				await FieldEffects.exclaim(entry)
		return
	if who is GridCharacter:
		await FieldEffects.exclaim(who)

func _tone_change(arguments: Array) -> Variant:
	if arguments.is_empty():
		return false
	var tone: Variant = arguments[0]
	if not (tone is Array) or tone.size() < 3:
		return false
	var frames: int = int(_number(arguments[1])) if arguments.size() >= 2 else 0
	await FieldEffects.change_tone(
		int(_number(tone[0])), int(_number(tone[1])), int(_number(tone[2])),
		int(_number(tone[3])) if tone.size() >= 4 else 0, frames
	)
	return true

static func _height(arguments: Array) -> int:
	return int(_number(arguments[0])) if not arguments.is_empty() else 1

# === Safari Contest Frontier ===

func _facility_calls(method: String, arguments: Array, raw: String) -> Variant:
	match method:
		"pbSafariZone", "pbStartSafari":
			return await bridge.facilities().safari("pbStart", arguments, raw)
		"pbBugContest", "pbStartBugContest":
			return await bridge.facilities().bug_contest("pbStart", arguments, raw)
		"pbBattleChallenge", "pbBattleTower":
			var facility: StringName = _id(arguments[0]) if not arguments.is_empty() else &"BATTLETOWER"
			return await Field.run_challenge(facility)
		"pbBattleChallengeStreak":
			return Field.challenge_streak(_facility_or_default(arguments))
		"pbBattleChallengeBest":
			return Field.challenge_best_streak(_facility_or_default(arguments))
		"pbBattleTowerRules", "pbBattlePalaceRules", "pbBattleArenaRules", \
		"pbBattleFactoryRules", "pbPikaCupRules", "pbFancyCupRules", \
		"pbPokeCupRules", "pbLittleCupRules":
			return _rules_for(method, arguments)
	return EventScriptBridge.Unsupported.new(raw)

static func _facility_or_default(arguments: Array) -> StringName:
	if arguments.is_empty():
		return &"BATTLETOWER"
	return facility_of(String(arguments[0]))

## The facility a Frontier challenge name belongs to
static func facility_of(challenge_name: String) -> StringName:
	var lowered: String = challenge_name.to_lower()
	for prefix: String in CHALLENGE_FACILITIES:
		if lowered.begins_with(prefix):
			return CHALLENGE_FACILITIES[prefix]
	return &"BATTLETOWER"

## Builds the rules for the Facility
static func _rules_for(method: String, arguments: Array) -> ChallengeRules:
	var facility: StringName = facility_of(method.substr(2))
	var rules: ChallengeRules = ChallengeFacilities.rules_for(facility)
	if rules == null:
		return null
	var applied: ChallengeRules = rules.duplicate(true)
	if not arguments.is_empty():
		applied.battlers_per_side = 2 if _truthy(arguments[0]) else 1
	if arguments.size() >= 2 and _truthy(arguments[1]):
		# "Open level" means the party comes as it is rather than being set to level 50
		applied.level_cap = 0
	return applied
	
# === One Offs ===

func _open_screen(path: String) -> bool:
	var scene: PackedScene = load(path)
	if scene == null:
		return false
	await SceneRouter.push_screen(scene)
	return true

func _hall_of_fame() -> bool:
	await Field.enter_hall_of_fame()
	return true

## Runs `$scene = Something.new`
func change_scene(expression: String) -> Variant:
	var scene_name: String = expression.trim_suffix(".new").strip_edges()
	match scene_name:
		"Scene_Credits":
			await Field.show_credits()
			return true
		"Scene_Map":
			# Going back to the map is where an event already is.
			return true
	return EventScriptBridge.Unsupported.new("%s = %s" % [EventScriptBridge.SCENE_TARGET, expression])

## Hands over the gift numbered [param gift_id]
func _receive_mystery_gift(gift_id: int) -> bool:
	if GameState.claimed_mystery_gifts.has(gift_id):
		await bridge.say("You have already received that gift.")
		return false
	var gift: MysteryGiftData = Database.mystery_gift(gift_id)
	if gift == null:
		GameState.claimed_mystery_gifts.append(gift_id)
		push_warning(
			"Mystery Gift %d was claimed and the project has no such gift record."
			% gift_id)
		await bridge.say("The gift was received!")
		return true
	var narrate: Callable = func(text: String) -> void:
		await bridge.say(text)
	var receipt: PokemonReceipt = PokemonReceipt.new()
	receipt.narrate = narrate
	receipt.ask = func(options: Array) -> int:
		return await Field.ask(options, "", options.size())
	return await MysteryGift.claim(gift, narrate, receipt)

## The next Mystery Gift waiting to be claimed, or `0` when there is none
func _next_mystery_gift_id() -> int:
	var queued: Variant = GameState.get_variable(EventScriptBridge.MYSTERY_GIFT_VARIABLE)
	var gift_id: int = int(queued) if queued != null else 0
	return gift_id if gift_id > 0 and not GameState.claimed_mystery_gifts.has(gift_id) else 0

## `pbEventScreen(ButtonEventScene)` — plays the scene the event names, out of [constant EVENT_SCENES].
## Returns `true` when one was played
func _event_screen(arguments: Array, raw: String) -> bool:
	var scene_name: String = ""
	if not arguments.is_empty():
		scene_name = EventScriptBridge.identifier(arguments[0]).strip_edges()
	if not EVENT_SCENES.has(scene_name):
		scene_name = _event_scene_name_in(raw)
	if not EVENT_SCENES.has(scene_name):
		push_warning("pbEventScreen: no scene called '%s'." % scene_name)
		await bridge.say("Nothing happens.")
		return false
	var scene: PackedScene = load(String(EVENT_SCENES[scene_name])) as PackedScene
	if scene == null:
		push_warning("pbEventScreen: '%s' names a scene that will not load." % scene_name)
		return false
	await SceneRouter.push_screen(scene)
	return true

## The first name in [param raw] that [constant EVENT_SCENES] knows
static func _event_scene_name_in(raw: String) -> String:
	for scene_name: String in EVENT_SCENES:
		if raw.contains(scene_name):
			return scene_name
	return ""

## Draws today's lottery number and writes it into the variable named
func _set_lottery_number(arguments: Array) -> String:
	var drawn: String = _lottery_number_today()
	var variable: int = _variable(arguments, 0)
	if variable > 0:
		GameState.set_variable(variable, drawn)
	return drawn

## Today's draw, zero-padded to [constant LOTTERY_DIGITS] digits
static func _lottery_number_today() -> String:
	var today: Dictionary = Time.get_datetime_dict_from_system()
	var day_seed: int = (
		int(today.get("day", 1)) + (int(today.get("month", 1)) << 5) + (int(today.get("year", 0)) << 9)
	)
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = day_seed
	return "%0*d" % [LOTTERY_DIGITS, generator.randi() % LOTTERY_RANGE]

## Checks the party and the boxes against the drawn number and reports the best match,
## which is how many digits agree counting from the right.
func _run_lottery(arguments: Array) -> int:
	var drawn: int = (
		int(_number(arguments[0])) if not arguments.is_empty() else int(_lottery_number_today())
	)
	var best_name: String = ""
	var best_position: int = 0
	var best_matches: int = 0
	var searches: Array[Array] = [
		[LOTTERY_IN_PARTY, GameState.party.members],
		[LOTTERY_IN_STORAGE, GameState.storage.all_stored()],
	]
	for search: Array in searches:
		var position: int = int(search[0])
		for pkmn: Pokemon in search[1]:
			if pkmn == null or pkmn.owner == null:
				continue
			var matches: int = _matching_digits(drawn, pkmn.owner.public_id())
			if matches <= best_matches:
				continue
			best_name = pkmn.display_name()
			best_position = position
			best_matches = matches
	if arguments.size() >= 2:
		GameState.set_variable(int(_number(arguments[1])), best_name)
	if arguments.size() >= 3:
		GameState.set_variable(int(_number(arguments[2])), best_position)
	if arguments.size() >= 4:
		GameState.set_variable(int(_number(arguments[3])), best_matches)
	return best_matches

## How many digits [param drawn] and [param id] agree on, counting from the right and stopping at [constant LOTTERY_DIGITS]
static func _matching_digits(drawn: int, id: int) -> int:
	var matches: int = 0
	for digit: int in LOTTERY_DIGITS:
		var power: int = int(pow(10.0, float(digit)))
		if (drawn / power) % 10 != (id / power) % 10:
			break
		matches += 1
	return matches

## `pbIsWeekday(1, 2, 4, 6)` is true on any of the days listed, counting Sunday as zero.
static func _is_weekday(arguments: Array) -> bool:
	var today: int = Time.get_datetime_dict_from_system()["weekday"]
	for argument: Variant in arguments:
		if int(_number(argument)) == today:
			return true
	return false


# === Utility ===

## The list arguments at [param index]
## Returns empty if it's absent or `nil`
static func _as_list_or_empty(arguments: Array, index: int) -> Array:
	if arguments.size() <= index or arguments[index] == null:
		return []
	return _as_list(arguments[index])
	
## Essentials' `_INTL`: the first argument is a template whose `{1}`, `{2}`, … placeholders are filled from the arguments after it.
static func _format(arguments: Array) -> String:
	if arguments.is_empty():
		return ""
	var text: String = String(arguments[0])
	for index: int in range(1, arguments.size()):
		text = text.replace("{%d}" % index, str(arguments[index]))
	return text

## A list argument, which an event writes either as:
##  a Ruby array or as a single item when there is only one.
static func _as_list(value: Variant) -> Array:
	if value is Array:
		return value
	return [value]

static func _variable(arguments: Array, index: int) -> int:
	if arguments.size() <= index:
		return 0
	return int(_number(arguments[index]))

## A `proc { |pkmn| ... }` argument, which the parser cannot read
static func _filter(arguments: Array, index: int) -> Callable:
	if arguments.size() > index and arguments[index] is Callable:
		return arguments[index]
	return Callable()

static func _quantity(arguments: Array, index: int) -> int:
	if arguments.size() <= index:
		return 1
	return maxi(int(_number(arguments[index])), 1)

static func _id(value: Variant) -> StringName:
	if value is GameDataResource:
		return value.id
	return StringName(String(value))

static func _number(value: Variant) -> float:
	return EventScriptBridge.as_number(value)

static func _truthy(value: Variant) -> bool:
	return EventScriptBridge.is_truthy(value)

func say(text: String) -> void:
	await bridge.say(text)
