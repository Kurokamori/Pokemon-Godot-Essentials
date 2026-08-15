@tool
class_name GameSettingsData
extends Resource

## All tuneable settings for a project -- allowing you to edit the .tres file instead of the code directly.

@export_group("Identity")
@export var game_title: String = "Pokemon Godot Essentials"
@export var game_version: String = "0.1"

@export_group("World")
## Size of a single map tile in pixels.
@export var tile_size: int = 32

## Default region before a player reaches a map with a set region
@export var default_region: int = 0

## The time it takes for the player to cross 1 tile
@export var walk_frames_per_tile: float = 0.25
@export var run_frames_per_tile: float = 0.14
@export var cycle_frames_per_tile: float = 0.10

## Time of day tinting for outdoor maps.
@export var time_shading: bool = true

@export_group("Pokemon Rules")
## The generation whose rules the engine follows.
@export_range(2, 9) var mechanics_generation: int = 8
@export_range(1, 255) var maximum_level: int = 100
@export_range(1, 255) var egg_level: int = 1

## Lowers the amount of happiness at which Pokemon requiring happiness evolve at.
@export var happiness_soft_cap: bool = true

## Allows rare candies to be used on level 100 pokemon to trigger an evolution.
@export var rare_candy_usable_at_max_level: bool = true

## Opens the Pokedex after catching a species for the first time or otherwise when acquired for the first time
@export var show_new_species_pokedex_entry: bool = true

## Offers to nickname a pokemon when it first hatches.
@export var offer_nickname_on_hatch: bool = true

## Chance of a wild pokemon being shiny, as a 1 in X value scaled by 65536
@export var shiny_chance_denominator: int = 4096

## Enabling this enables the rarer "square" shiny variant
@export var super_shiny_enabled: bool = true

## 1 in N of each newly generated Pokemon to be carying Pokerus
@export var pokerus_chance: int = 65536

@export_range(1, 12) var max_party_size: int = 6
@export_range(0, 510) var maximum_total_evs: int = 510
@export_range(0, 255) var maximum_stat_evs: int = 252
@export_range(0, 63) var maximum_iv: int = 31
@export var max_moves: int = 4

@export_group("Player")
@export_range(1, 16) var badges_per_region: int = 8
@export var max_money: int = 999999
@export var max_coins: int = 999
@export var max_battle_points: int = 9999
@export var max_soot: int = 9999
@export_range(1, 20) var max_player_name_size: int = 10
@export_range(1, 20) var max_pokemon_name_size: int = 12

@export_group("Bag and Storage")
## The maximum amount each bag slot can store, or -1 for infinite
@export var bag_pocket_capacity: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1]
@export var bag_max_per_slot: int = 999

## Pokets who are automatically alphabetically sorted.
@export var bag_auto_sorted_pockets: Array[int] = [8]

@export_range(1, 999) var storage_box_count: int = 40
@export var storage_box_width: int = 6
@export var storage_box_height: int = 5

## Whether Pokemon which are deposited into the storage are healed.
@export var heal_stored_pokemon: bool = false

@export_group("Battle")
@export var exp_share_gives_full_exp: bool = true

## Setting this to true splits expierence between participants instead of giving each the full amount
@export var split_exp_between_participants: bool = false
@export var scaled_exp_formula: bool = true
@export var affection_effects: bool = true
@export var critical_hit_stages: Array[float] = [0.0417, 0.125, 0.5, 1.0]
@export var critical_hit_multiplier: float = 1.5
@export var same_type_attack_bonus: float = 1.5
@export var damage_roll_minimum: float = 0.85
@export var max_stat_stage: int = 6
@export var can_lose_money_on_defeat: bool = true

## Checks party for pending evolutions after all battles (lose and draw included) or `false` only on wins
@export var check_evolution_after_all_battles: bool = true

## Lets a fainted Pokemon evolve after battle even if it is fainted at the end of battle
@export var check_evolution_for_fainted_pokemon: bool = true

@export var battle_animations: bool = true

## Seconds a battle message remains on screen before the battle advances.
@export_range(0.0, 3.0, 0.05) var battle_message_seconds: float = 0.9

@export_group("Field")
@export var poison_damage_in_field: bool = false
@export var poison_faints_in_field: bool = false
@export var repel_counts_fainted_pokemon: bool = false

## Adds some bonus abilities to the pool that effect wild encounters
## Infiltrator and Super Luck start always counting
## Flash Fire, Harvest, Lightning Rod, and Storm Drain start favouring their own type
@export var more_abilities_affect_wild_encounters: bool = false

## Steps that take for a tick of happinness to count
@export var happiness_steps: int = 128

## Steps between one hatch counter tick to count
@export var egg_steps_per_cycle: int = 1

## Whether the player can use the town map itself to start a fly 
## As opposed to having to use 'Fly' from the party menu
@export var can_fly_from_town_map: bool = true

## Item that opens the town map / region map from the pause menu
## If this remains empty no item is capable of showing the town map, and only events can
@export var town_map_item: StringName = &"TOWNMAP"

@export_group("Player Options")
## Whether the player moves at running speed without having to hold down the run button
## Thus turning the run button into a walk button.
## Doesn't do anything until the player has running shoes.
@export var run_by_default: bool = false

## Sends a caught pokemon directly to the storage box even when the party has room
@export var send_caught_to_boxes: bool = false

## Whether the game ever asks the "Would you like to give a nickname" question
@export var offer_nicknames: bool = false

@export_group("Followers")
## The default follower mode
## If you want the player to be able to change this, list valid modes in [member follower_allowed_modes]
## List only the mode you have set here, and the player will not have the option to change it
@export var follower_mode: FollowerMode.Mode = FollowerMode.Mode.LEAD

## The modes offered by the options screen
## Listed as the [enum FollowerMode.Mode] numbers.
## Blank = All are available
## Only One Option = A set option, player may not change.
@export var follower_allowed_modes: Array[int] = [0, 1, 2, 3, 4]

## The specific species that walks with the player if [constant FollowerMode.Mode.FIXED_SPECIES]
## For example, if you were remaking Yellow you would set this to Pikachu
@export var follower_species: StringName = &""

## If there's a specific species set, this sets its form
@export_range(0, 255) var follower_species_form: int = 0

## If there's a specific set species, whether or not it needs to be in the party before it appears
@export var follower_species_needs_party: bool = true

## The maximum amount of Pokemon allowed out under setting [constant FollowerMode.Mode.WHOLE_PARTY]
## TODO: Consider splitting this into two settings? 'Whole Party' and 'Set Amount' or something
@export var follower_maximum: int = 6

## Whether eggs follow the player,
## This does not ship with an overworld spritesheet for eggs, but here if you want it.
@export var follower_includes_eggs: bool = false

## Whether or not fainted Pokemon still appear in the overworld as followers
@export var follower_includes_fainted: bool = false

## Whether the followers follow the player if surfing or diving
@export var follower_hidden_while_surfing: bool = false

## Whether the followers follow the player when cycling
@export var follower_hidden_while_cycling: bool = false

## Distance between the player and the first follower
@export_range(1, 8) var follower_spacing: int = 1

@export_group("Hidden Moves")
## How the numbers bellow are read.
## Set, a move needs the player to HAVE that many badge
## Unset, it needs that one specific badge.
## Counted from zero, so 1 is the second badge.
@export var field_moves_count_badges: bool = true

## Badge that the Hidden Move needs before the player may use it outside of battle
## `0` asks for none - what a project that either has no gyms or gates differently wants
@export_range(0, 16) var badge_for_cut: int = 1
@export_range(0, 16) var badge_for_flash: int = 2
@export_range(0, 16) var badge_for_rock_smash: int = 3
@export_range(0, 16) var badge_for_surf: int = 4
@export_range(0, 16) var badge_for_fly: int = 5
@export_range(0, 16) var badge_for_strength: int = 6
@export_range(0, 16) var badge_for_dive: int = 7
@export_range(0, 16) var badge_for_waterfall: int = 8

@export_group("Pokegear")
## Whether or not trainers start incrememnting towards rematches right away
## If false, an event has to set `Phone.rematches_enabled` before any trainer wants a rematch
@export var phone_rematches_from_the_start: bool = true

## Shortest time, in minutes, before a trainer tries for a rematch or to call the player.
## Both clocks roll a fresh wait in this range each time.
@export var phone_call_minutes_minimum: int = 20

## Longest time, in minutes, before a trainer tries for a rematch or to call the player.
@export var phone_call_minutes_maximum: int = 60

## How far up their rematch ladder any contact may climb at the beginning
## `0` means that every battle is a rematch of their original team
## `Phone.rematch_varaint` raises to raise the maximum value
## This gates it from letting a first map trainer to use their end game team
@export var phone_starting_rematch_variant: int = 0

## Whether or not to colour the phone call text by the caller's gender
@export var colour_phone_calls_by_name: bool = true

@export_group("Audio")
@export var default_bgm_volume: float = 1.0
@export var default_se_volume: float = 1.0
@export var bgm_fade_seconds: float = 0.8

@export_group("Development")
## Allows the debug menu to open with `game_debug` action.
## Disable this before releasing.
@export var debug_mode: bool = false


## Maximum amount of exp a Pokemon can hold.
func maximum_exp() -> int:
	return 9999999
	
## `true` when a shiny is rolled.
## [param denominator] overrides [member shiny_chance_denominator] for the one roll
## This is how chaining overrides the base value
func roll_shiny(rng: RandomNumberGenerator, rolls: int = 1, denominator: int = 0) -> bool:
	var odds: int = maxi(denominator if denominator > 0 else shiny_chance_denominator, 1)
	for i: int in range(maxi(rolls, 1)):
		if rng.randi_range(1, odds) == 1:
			return true
	return false
