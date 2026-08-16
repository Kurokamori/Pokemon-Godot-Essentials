class_name Player
extends RefCounted
## The actual player character (not party, bag, storage which all live on GameState)

signal money_changed(old_amount: int, new_amount: int)
signal badge_earned(badge: int)

var name: String = ""

## 32-bit trainer id
## The low 16 bits are the visible player id
var id: int = 0
var gender: PokemonOwner.Gender = PokemonOwner.Gender.MALE
## Which [PlayerMetadata] supplies the graphics for this player
var character_id: int = 1

var money: int = 0:
	set(value):
		var clamped: int = clampi(value, 0, GameSettings.data.max_money)
		if clamped == money:
			return
		var prev: int = money
		money = clamped
		money_changed.emit(prev, money)
		
var coins: int = 0
var battle_points: int = 0
var soot: int = 0
		
var badges: int = 0

var pokedex: Pokedex = Pokedex.new()

var play_time_seconds: float = 0.0
var steps_taken: int = 0

## Unix time at which the adventure began

var started_at: int = 0

## Whether the Pokedex has been gotten
var has_pokedex: bool = false
var has_pokegear: bool = false
var has_running_shoes: bool = false
var has_snag_machine: bool = false

## Amount of Pokemon of each species the player has defeated
var species_defeated: Dictionary = {}
var species_caught: Dictionary = {}

## Claimed mystery gifts
var mystery_gifts: Array = []

## Every track the player has heard, recorded the first time they hear it.
var heard_tracks: Array[String] = []

## Unique flags for one off conversations

## Set to `true` once the player knows who made the storage system
var seen_storage_creator: bool = false

## Set to `true` once the player has unlocked the purifying chamber
var seen_purify_chamber: bool = false

## Set to `true` once the player can access mystery gifts
var mystery_gift_unlocked: bool = false


static func create(player_name: String, player_gender: PokemonOwner.Gender, metadata_id: int = 1) -> Player:
	var player: Player = Player.new()
	player.name = player_name
	player.gender = player_gender
	player.character_id = metadata_id
	player.id = RNG.generator.randi() & 0xFFFFFFFF
	player.started_at = int(Time.get_unix_time_from_system())
	var metadata: MetadataData = Database.metadata()
	player.money = metadata.start_money if metadata != null else 3000
	return player


func public_id() -> int:
	return id & 0xFFFF


func secret_id() -> int:
	return (id >> 16) & 0xFFFF


## The owner record on Pokemon the player catches.
func owner_record() -> PokemonOwner:
	return PokemonOwner.create(id, name, gender)


func trainer_type() -> StringName:
	var metadata: PlayerMetadataData = Database.player_metadata(character_id)
	return metadata.trainer_type if metadata != null else &""


func is_male() -> bool:
	return gender == PokemonOwner.Gender.MALE


func is_female() -> bool:
	return gender == PokemonOwner.Gender.FEMALE


# === Money ===

func add_money(amount: int) -> void:
	money += amount


## Spends money. 
## Returns `false` if the player cannot afford
func spend_money(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	return true


func can_afford(amount: int) -> bool:
	return money >= amount


# === Badges ===

func has_badge(badge: int) -> bool:
	return (badges & (1 << badge)) != 0


func give_badge(badge: int) -> void:
	if has_badge(badge):
		return
	badges |= 1 << badge
	badge_earned.emit(badge)


## Gives or takes away a badge.
func set_badge(badge: int, earned: bool) -> void:
	if earned:
		give_badge(badge)
		return
	badges &= ~(1 << badge)


func badge_count() -> int:
	var total: int = 0
	for index: int in range(32):
		if has_badge(index):
			total += 1
	return total


## The level above which traded Pokemon may not listen to the trainer
func obedience_level() -> int:
	var earned: int = badge_count()
	if earned >= 8:
		return GameSettings.data.maximum_level
	return mini(10 + (10 * earned), GameSettings.data.maximum_level)


# === Counters ===

func record_defeated(species_id: StringName) -> void:
	species_defeated[species_id] = int(species_defeated.get(species_id, 0)) + 1


func record_caught(species_id: StringName) -> void:
	species_caught[species_id] = int(species_caught.get(species_id, 0)) + 1


func times_defeated(species_id: StringName) -> int:
	return int(species_defeated.get(species_id, 0))


## The shiny roll bonus earned by battling multiple of the same species.
func shiny_roll_bonus(species_id: StringName) -> int:
	if GameSettings.data.mechanics_generation < 8:
		return 0
	var battled: int = times_defeated(species_id)
	if battled >= 500:
		return 5
	if battled >= 300:
		return 4
	if battled >= 200:
		return 3
	if battled >= 100:
		return 2
	if battled >= 50:
		return 1
	return 0


func formatted_play_time() -> String:
	var total: int = int(play_time_seconds)
	return "%d:%02d" % [total / 3600, (total % 3600) / 60]


## Remembers that [param track_name] has been heard. 
## Returns `true` if this is the first time that track has been heard.
func note_heard_track(track_name: String) -> bool:
	if track_name.is_empty() or heard_tracks.has(track_name):
		return false
	heard_tracks.append(track_name)
	return true


## All heard tracks, as a list, for saves.
func _heard_track_list() -> Array:
	var stored: Array = []
	for track_name: String in heard_tracks:
		stored.append(track_name)
	return stored


func to_dict() -> Dictionary:
	return {
		"name": name,
		"id": id,
		"gender": int(gender),
		"character_id": character_id,
		"money": money,
		"coins": coins,
		"battle_points": battle_points,
		"soot": soot,
		"badges": badges,
		"pokedex": pokedex.to_dict(),
		"play_time_seconds": play_time_seconds,
		"steps_taken": steps_taken,
		"started_at": started_at,
		"has_pokedex": has_pokedex,
		"has_pokegear": has_pokegear,
		"has_running_shoes": has_running_shoes,
		"has_snag_machine": has_snag_machine,
		"species_defeated": _string_keys(species_defeated),
		"species_caught": _string_keys(species_caught),
		"mystery_gifts": mystery_gifts.duplicate(true),
		"heard_tracks": _heard_track_list(),
		"seen_storage_creator": seen_storage_creator,
		"seen_purify_chamber": seen_purify_chamber,
		"mystery_gift_unlocked": mystery_gift_unlocked,
	}


func from_dict(source: Dictionary) -> void:
	name = String(source.get("name", ""))
	id = int(source.get("id", 0))
	gender = int(source.get("gender", 0)) as PokemonOwner.Gender
	character_id = int(source.get("character_id", 1))
	money = int(source.get("money", 0))
	coins = int(source.get("coins", 0))
	battle_points = int(source.get("battle_points", 0))
	soot = int(source.get("soot", 0))
	badges = int(source.get("badges", 0))
	pokedex.from_dict(source.get("pokedex", {}))
	play_time_seconds = float(source.get("play_time_seconds", 0.0))
	steps_taken = int(source.get("steps_taken", 0))
	started_at = int(source.get("started_at", 0))
	has_pokedex = bool(source.get("has_pokedex", false))
	has_pokegear = bool(source.get("has_pokegear", false))
	has_running_shoes = bool(source.get("has_running_shoes", false))
	has_snag_machine = bool(source.get("has_snag_machine", false))
	species_defeated = _stringname_keys(source.get("species_defeated", {}))
	species_caught = _stringname_keys(source.get("species_caught", {}))
	mystery_gifts = source.get("mystery_gifts", []).duplicate(true)
	heard_tracks.clear()
	for entry: Variant in source.get("heard_tracks", []):
		heard_tracks.append(String(entry))
	seen_storage_creator = bool(source.get("seen_storage_creator", false))
	seen_purify_chamber = bool(source.get("seen_purify_chamber", false))
	mystery_gift_unlocked = bool(source.get("mystery_gift_unlocked", false))


func _string_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		result[String(key)] = source[key]
	return result


func _stringname_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		result[StringName(key)] = source[key]
	return result
