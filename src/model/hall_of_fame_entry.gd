class_name HallOfFameEntry
extends RefCounted
## One actual record in the hall of fame -- the team and trainer

## Copies of the party
var team: Array[Pokemon] = []

## The player name when the record was taken
var player_name: String = ""
var public_id: int = 0

## Seconds at the moment the entry was made
var play_time_seconds: int = 0

var pokedex_owned: int = 0
var pokedex_seen: int = 0

var entry_number: int = 0

## Unix time the entry record was made
var recorded_at: int = 0


## Creates a party recording, 
## [param include_eggs] decides whether or not eggs are included -- passed by [member HallOfFameData.records_eggs]
static func create(number: int, include_eggs: bool = true) -> HallOfFameEntry:
	var entry: HallOfFameEntry = HallOfFameEntry.new()
	entry.entry_number = number
	entry.recorded_at = int(Time.get_unix_time_from_system())
	for pokemon: Pokemon in GameState.party.members:
		if pokemon.is_egg() and not include_eggs:
			continue
		entry.team.append(Pokemon.from_dict(pokemon.to_dict()))
	var player: Player = GameState.player
	if player != null:
		entry.player_name = player.name
		entry.public_id = player.public_id()
		entry.play_time_seconds = int(player.play_time_seconds)
		entry.pokedex_owned = player.pokedex.owned_count()
		entry.pokedex_seen = player.pokedex.seen_count()
	return entry
	
## The play time formatted as `Xh Xm' or just 'Xm'
func formatted_play_time() -> String:
	var hours: int = play_time_seconds / 3600
	var minutes: int = (play_time_seconds / 60) % 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes


func formatted_id() -> String:
	return "%05d" % public_id


func size() -> int:
	return team.size()


func to_dict() -> Dictionary:
	var members: Array = []
	for pkmn: Pokemon in team:
		members.append(pkmn.to_dict())
	return {
		"team": members,
		"player_name": player_name,
		"public_id": public_id,
		"play_time_seconds": play_time_seconds,
		"pokedex_owned": pokedex_owned,
		"pokedex_seen": pokedex_seen,
		"entry_number": entry_number,
		"recorded_at": recorded_at,
	}


static func from_dict(source: Dictionary) -> HallOfFameEntry:
	var entry: HallOfFameEntry = HallOfFameEntry.new()
	for member: Variant in source.get("team", []):
		var pkmn: Pokemon = Pokemon.from_dict(member as Dictionary)
		if pkmn != null:
			entry.team.append(pkmn)
	entry.player_name = String(source.get("player_name", ""))
	entry.public_id = int(source.get("public_id", 0))
	entry.play_time_seconds = int(source.get("play_time_seconds", 0))
	entry.pokedex_owned = int(source.get("pokedex_owned", 0))
	entry.pokedex_seen = int(source.get("pokedex_seen", 0))
	entry.entry_number = int(source.get("entry_number", 0))
	entry.recorded_at = int(source.get("recorded_at", 0))
	return entry
