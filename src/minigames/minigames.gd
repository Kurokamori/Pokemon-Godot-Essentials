class_name Minigames
## The short way to start a minigame

## The list of games in the game, where the ID is looked up
const LIBRARY_PATH: String = "res://data/minigames/minigame_library.tres"

## The location for duel rules, which isn't its own screen
const DUEL_RULES_PATH: String = "res://data/minigames/duel_rules.tres"

## The Triple Triad rules a duel falls back to
const TRIAD_RULES_PATH: String = "res://data/minigames/triad_rules.tres"

const COIN_CASE: StringName = &"COINCASE"

const VOLTORB_FLIP: StringName = &"VOLTORBFLIP"
const SLOT_MACHINE: StringName = &"SLOTMACHINE"
const MINING: StringName = &"MINING"
const TILE_PUZZLE: StringName = &"TILEPUZZLE"
const TRIAD_DUEL: StringName = &"TRIADDUEL"
const TRIAD_SHOP: StringName = &"TRIADSHOP"

static var _library: MinigameLibrary = null
static var _duel_rules: DuelRules = null



## The project's list of games, loaded on first use.
static func library() -> MinigameLibrary:
	if _library != null:
		return _library
	if ResourceLoader.exists(LIBRARY_PATH):
		_library = ResourceLoader.load(LIBRARY_PATH, "") as MinigameLibrary
	if _library == null:
		_library = MinigameLibrary.new()
		push_warning("Minigames: %s is missing; no game can be opened." % LIBRARY_PATH)
	return _library

## Forgets the loaded library, for a tool that has just edited it.
static func reload() -> void:
	_library = null
	_duel_rules = null
	_triad_rules = null

static func has(id: StringName) -> bool:
	var entry: MinigameEntry = library().entry(id)
	return entry != null and entry.is_playable()

## Plays the game called [param id] and returns whatever it closed with
static func open(id: StringName, setup: Callable = Callable()) -> Variant:
	var entry: MinigameEntry = library().entry(id)
	if entry == null:
		push_error("Minigames: there is no game called '%s'." % id)
		return null
	if not entry.is_playable():
		await Field.say(entry.excuse())
		return null
	await SceneRouter.fade_out()
	var result: Variant = await SceneRouter.push_screen(entry.scene, setup)
	await SceneRouter.fade_in()
	return result


# === The Game Corner ===

## Plays Voltorb Flip and returns the coins won.
static func voltorb_flip() -> int:
	if not _has_coin_case():
		await Field.say("You can't play unless you have a Coin Case.")
		return 0
	if _coins() >= GameSettings.data.max_coins:
		await Field.say("Your Coin Case is full!")
		return 0
	var won: Variant = await open(VOLTORB_FLIP)
	return int(won) if won != null else 0

## Plays a slot machine and returns how many coins the player is up or down by.
static func slot_machine(difficulty: int = 1) -> int:
	if not _has_coin_case():
		await Field.say("It's a Slot Machine.")
		return 0
	if _coins() <= 0:
		await Field.say("You don't have any Coins to play!")
		return 0
	if _coins() >= GameSettings.data.max_coins:
		await Field.say("Your Coin Case is full!")
		return 0
	var change: Variant = await open(SLOT_MACHINE, func(screen: Node) -> void:
		screen.difficulty = clampi(difficulty, 0, 2)
	)
	return int(change) if change != null else 0

static func _has_coin_case() -> bool:
	return GameState.bag.has_item(COIN_CASE)

static func _coins() -> int:
	return GameState.player.coins if GameState.player != null else 0

# === Mining ===

## Starts a wall mining, and returns the item ids of any retrieved items
static func mining() -> Array:
	var won: Variant = await open(MINING)
	return won if won is Array else []


# === Puzzles ===

## Runs one of the seven tile puzzles and reports whether it was solved
static func tile_puzzle(
	mode: int, board: StringName, puzzle_width: int = 0, puzzle_height: int = 0
) -> bool:
	var solved: Variant = await open(TILE_PUZZLE, func(screen: Node) -> void:
		screen.mode = clampi(mode, 1, 7) as TilePuzzleBoard.Mode
		screen.board_id = board
		screen.board_width = puzzle_width
		screen.board_height = puzzle_height
	)
	return solved is bool and solved


# === Triple Triad ===

## Returns `true` when the player owns enough cards for them to play Triple Triad
static func can_play_triad(minimum: int = -1) -> bool:
	var wanted: int = minimum if minimum >= 0 else triad_rules().minimum_cards
	return GameState.triads.total_cards() >= wanted

## Duels [param opponent] at Triple Triad and returns a [enum TriadDuelScreen.Result]
static func triad_duel(
	opponent: String, min_level: int = 0, max_level: int = 5,
	rule_names: Array = [], opponent_deck: Array = [], prize: StringName = &""
) -> int:
	var result: Variant = await open(TRIAD_DUEL, func(screen: Node) -> void:
		screen.opponent_name = opponent
		screen.min_level = min_level
		screen.max_level = max_level
		screen.rule_names = rule_names
		screen.opponent_deck = opponent_deck
		screen.prize_species = prize
	)
	return int(result) if result != null else int(TriadDuelScreen.Result.NOT_PLAYED)

static func buy_triad_cards() -> void:
	await _open_triad_shop(TriadShopScreen.Mode.BUY)

static func sell_triad_cards() -> void:
	await _open_triad_shop(TriadShopScreen.Mode.SELL)

## Opens the player's collection to be looked through, with nothing for sale
static func show_triad_cards() -> void:
	await _open_triad_shop(TriadShopScreen.Mode.BROWSE)


static func _open_triad_shop(mode: TriadShopScreen.Mode) -> void:
	await open(TRIAD_SHOP, func(screen: Node) -> void:
		screen.mode = mode
	)

## Hands the player a card
## Returns `false` if the player already has a maximum amount of that card
static func give_triad_card(species: StringName, count: int = 1) -> bool:
	if Database.species(species) == null:
		push_error("Minigames: '%s' is not a species and cannot be a card." % species)
		return false
	return GameState.triads.add(species, count)

## The rules a duel falls back to when the event names none of its own.
static func triad_rules() -> TriadRules:
	if _triad_rules != null:
		return _triad_rules
	if ResourceLoader.exists(TRIAD_RULES_PATH):
		_triad_rules = ResourceLoader.load(TRIAD_RULES_PATH, "") as TriadRules
	if _triad_rules == null:
		_triad_rules = TriadRules.new()
	return _triad_rules


static var _triad_rules: TriadRules = null


# === The Duel ===

## Fights [param event] and reports whether the player won
static func duel(
	trainer_type: StringName, trainer_name: String, event: MapEvent, speeches: Array
) -> bool:
	var rules: DuelRules = duel_rules()
	if rules == null:
		await Field.say("There is nobody to duel.")
		return false
	var session: DuelSession = DuelSession.new()
	return await session.run(rules, trainer_type, trainer_name, event, speeches)

static func duel_rules() -> DuelRules:
	if _duel_rules != null:
		return _duel_rules
	if ResourceLoader.exists(DUEL_RULES_PATH):
		_duel_rules = ResourceLoader.load(DUEL_RULES_PATH, "") as DuelRules
	if _duel_rules == null:
		push_warning("Minigames: %s is missing." % DUEL_RULES_PATH)
	return _duel_rules
