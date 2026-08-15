class_name GameStats
extends RefCounted

## The game's running tally of things
## Everything's a plain coutner, and not to be derived so everything agrees

## How many Gym Leaders the counters are sized for.
const BADGE_COUNT: int = 16

## Every counter that can be named
## And whether it holds a number or a list
## This allows misspellings to report rather than silently write and die
const COUNTERS: Dictionary = {
	&"distance_walked": TYPE_INT, &"distance_cycled": TYPE_INT,
	&"distance_surfed": TYPE_INT, &"distance_slid_on_ice": TYPE_INT,
	&"bump_count": TYPE_INT, &"cycle_count": TYPE_INT, &"surf_count": TYPE_INT,
	&"dive_count": TYPE_INT, &"fly_count": TYPE_INT, &"cut_count": TYPE_INT,
	&"flash_count": TYPE_INT, &"rock_smash_count": TYPE_INT,
	&"rock_smash_battles": TYPE_INT, &"headbutt_count": TYPE_INT,
	&"headbutt_battles": TYPE_INT, &"strength_push_count": TYPE_INT,
	&"waterfall_count": TYPE_INT, &"waterfalls_descended": TYPE_INT,
	&"repel_count": TYPE_INT, &"itemfinder_count": TYPE_INT,
	&"fishing_count": TYPE_INT, &"fishing_battles": TYPE_INT,
	&"poke_radar_count": TYPE_INT, &"poke_radar_longest_chain": TYPE_INT,
	&"berry_plants_picked": TYPE_INT, &"max_yield_berry_plants": TYPE_INT,
	&"berries_planted": TYPE_INT, &"poke_center_count": TYPE_INT,
	&"revived_fossil_count": TYPE_INT, &"lottery_prize_count": TYPE_INT,
	&"eggs_hatched": TYPE_INT, &"evolution_count": TYPE_INT,
	&"evolutions_cancelled": TYPE_INT, &"trade_count": TYPE_INT,
	&"moves_taught_by_item": TYPE_INT, &"moves_taught_by_tutor": TYPE_INT,
	&"moves_taught_by_reminder": TYPE_INT, &"day_care_deposits": TYPE_INT,
	&"day_care_levels_gained": TYPE_INT, &"pokerus_infections": TYPE_INT,
	&"shadow_pokemon_purified": TYPE_INT, &"wild_battles_won": TYPE_INT,
	&"wild_battles_lost": TYPE_INT, &"trainer_battles_won": TYPE_INT,
	&"trainer_battles_lost": TYPE_INT, &"total_exp_gained": TYPE_INT,
	&"battle_money_gained": TYPE_INT, &"battle_money_lost": TYPE_INT,
	&"blacked_out_count": TYPE_INT, &"mega_evolution_count": TYPE_INT,
	&"failed_poke_ball_count": TYPE_INT, &"money_spent_at_marts": TYPE_INT,
	&"money_earned_at_marts": TYPE_INT, &"mart_items_bought": TYPE_INT,
	&"premier_balls_earned": TYPE_INT, &"drinks_bought": TYPE_INT,
	&"drinks_won": TYPE_INT, &"coins_won": TYPE_INT, &"coins_lost": TYPE_INT,
	&"battle_points_won": TYPE_INT, &"battle_points_spent": TYPE_INT,
	&"soot_collected": TYPE_INT, &"elite_four_attempts": TYPE_INT,
	&"hall_of_fame_entry_count": TYPE_INT,
	&"time_to_enter_hall_of_fame": TYPE_INT, &"safari_pokemon_caught": TYPE_INT,
	&"most_captures_per_safari_game": TYPE_INT, &"bug_contest_count": TYPE_INT,
	&"bug_contest_wins": TYPE_INT, &"play_sessions": TYPE_INT,
	&"time_last_saved": TYPE_INT,
	&"gym_leader_attempts": TYPE_ARRAY, &"times_to_get_badges": TYPE_ARRAY,
}

# === Distance ===
var distance_walked: int = 0
var distance_cycled: int = 0
var distance_surfed: int = 0
var distance_slid_on_ice: int = 0
var bump_count: int = 0
var cycle_count: int = 0
var surf_count: int = 0
var dive_count: int = 0

# === Field Moves ===
var fly_count: int = 0
var cut_count: int = 0
var flash_count: int = 0
var rock_smash_count: int = 0
var rock_smash_battles: int = 0
var headbutt_count: int = 0
var headbutt_battles: int = 0
var strength_push_count: int = 0
var waterfall_count: int = 0
var waterfalls_descended: int = 0

# === Items ===
var repel_count: int = 0
var itemfinder_count: int = 0
var fishing_count: int = 0
var fishing_battles: int = 0
var poke_radar_count: int = 0
var poke_radar_longest_chain: int = 0
var berry_plants_picked: int = 0
var max_yield_berry_plants: int = 0
var berries_planted: int = 0

# === Locations ===
var poke_center_count: int = 0
var revived_fossil_count: int = 0
var lottery_prize_count: int = 0

# === Pokemon ===
var eggs_hatched: int = 0
var evolution_count: int = 0
var evolutions_cancelled: int = 0
var trade_count: int = 0
var moves_taught_by_item: int = 0
var moves_taught_by_tutor: int = 0
var moves_taught_by_reminder: int = 0
var day_care_deposits: int = 0
var day_care_levels_gained: int = 0
var pokerus_infections: int = 0
var shadow_pokemon_purified: int = 0

# === Battles ===
# Losses include battles fled from.
var wild_battles_won: int = 0
var wild_battles_lost: int = 0
var trainer_battles_won: int = 0
var trainer_battles_lost: int = 0
var total_exp_gained: int = 0
var battle_money_gained: int = 0
var battle_money_lost: int = 0
var blacked_out_count: int = 0
var mega_evolution_count: int = 0
var failed_poke_ball_count: int = 0

# === Money ===
var money_spent_at_marts: int = 0
var money_earned_at_marts: int = 0
var mart_items_bought: int = 0
var premier_balls_earned: int = 0
var drinks_bought: int = 0
var drinks_won: int = 0
var coins_won: int = 0
var coins_lost: int = 0
var battle_points_won: int = 0
var battle_points_spent: int = 0
var soot_collected: int = 0

# === Milestones ===
## Entry per Gym Leader -- How many Attempts.
var gym_leader_attempts: Array[int] = []
## Entry per Badge -- play time in seconds when it was earned, or `-1`.
var times_to_get_badges: Array[int] = []
var elite_four_attempts: int = 0
var hall_of_fame_entry_count: int = 0
var time_to_enter_hall_of_fame: int = -1
var safari_pokemon_caught: int = 0
var most_captures_per_safari_game: int = 0
var bug_contest_count: int = 0
var bug_contest_wins: int = 0

# === Sessions ===
var play_sessions: int = 0
var time_last_saved: int = -1


func _init() -> void:
	gym_leader_attempts.resize(BADGE_COUNT)
	times_to_get_badges.resize(BADGE_COUNT)
	times_to_get_badges.fill(-1)
	
func distance_moved() -> int:
	return distance_walked + distance_cycled + distance_surfed + distance_slid_on_ice
	
func caught_pokemon_count() -> int:
	return safari_pokemon_caught + eggs_hatched
	# TODO: is this...? right? why does this work?
	
func set_time_to_badge(which: int) -> void:
	if which < 0 or which >= times_to_get_badges.size():
		return
	times_to_get_badges[which] = _play_time()

func set_time_to_hall_of_fame() -> void:
	if time_to_enter_hall_of_fame < 0:
		time_to_enter_hall_of_fame = _play_time()
		
func begin_session() -> void:
	play_sessions += 1
	
func average_session_length() -> int:
	if play_sessions <= 0:
		return 0
	return _play_time() / play_sessions
	
func set_time_last_saved() -> void:
	time_last_saved = _play_time()
	
func time_since_last_saved() -> int:
	if time_last_saved < 0:
		return 0
	return maxi(_play_time() - time_last_saved, 0)
	
func add_to(counter: StringName, amount: int) -> bool:
	var curr: Variant = get_counter(counter)
	if curr == null:
		return false
	return set_counter(counter, int(curr) + amount)
	
func get_counter(counter: StringName) -> Variant:
	if not COUNTERS.has(counter):
		return null
	return get(String(counter))
	
func set_counter(counter: StringName, value: Variant) -> bool:
	if not COUNTERS.has(counter):
		return false
	set(String(counter), value)
	return true
	
# === Internals and Serialisation ===
func _play_time() -> int:
	return int(GameState.player.play_time_seconds) if GameState.player != null else 0


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for counter: StringName in COUNTERS:
		var value: Variant = get(String(counter))
		result[String(counter)] = value.duplicate() if value is Array else value
	return result


func from_dict(source: Dictionary) -> void:
	for counter: StringName in COUNTERS:
		var key: String = String(counter)
		if not source.has(key):
			continue
		if int(COUNTERS[counter]) == TYPE_ARRAY:
			var values: Array[int] = []
			values.assign(source[key])
			values.resize(BADGE_COUNT)
			set(key, values)
			continue
		set(key, int(source[key]))
