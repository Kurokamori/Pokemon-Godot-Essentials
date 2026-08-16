class_name TrainerCardFields
## Everything a Trainer Card prints about the player, by name.

## This list feeds the field dropdown on TrainerCardField and what value reads. 

## Values return formatted text since cards show text.

## Fields keyed by scene names, each with its description for tooltips and docs.
const FIELDS: Dictionary[StringName, String] = {
	# === Identity ===
	&"player_name": "The player's name.",
	&"id_number": "Five-digit public trainer ID.",
	&"gender": "\"Boy\" or \"Girl\" from their character choice.",
	&"trainer_type": "Trainer type name, e.g. \"Pokemon Trainer\".",
	&"started_on": "Adventure start date, e.g. \"Aug 10, 2026\".",

	# === Wallet ===
	&"money": "Money with currency symbol and thousands separators.",
	&"money_plain": "Money as digits only.",
	&"coins": "Game Corner coins.",
	&"battle_points": "Frontier Battle Points earned.",
	&"soot": "Volcanic ash collected.",

	# === Progress ===
	&"badge_count": "Badges earned.",
	&"badges_of_total": "Current region badges like \"3/8\".",
	&"pokedex_owned": "Species owned.",
	&"pokedex_seen": "Species seen.",
	&"pokedex_summary": "Owned and seen count like \"120/151\".",
	&"pokedex_completion": "Percent of national Dex owned.",
	&"hall_of_fame_count": "Times inducted into Hall of Fame.",
	&"hall_of_fame_time": "Time until first champion or dash.",

	# === Time ===
	&"play_time": "Play time like \"12h 34m\".",
	&"play_time_hours": "Whole hours played.",
	&"play_sessions": "Times the game has loaded.",
	&"average_session_length": "Average session like \"1h 12m\".",

	# === Location ===
	&"region_name": "Current region name.",
	&"current_location": "Current map name.",

	# === Travel ===
	&"steps_taken": "Every step walked, cycled or surfed.",
	&"distance_walked": "Steps on foot.",
	&"distance_cycled": "Steps by bicycle.",
	&"distance_surfed": "Steps on water.",

	# === Battles ===
	&"battles_won": "Wild and trainer battles won.",
	&"battles_lost": "Wild and trainer battles lost or fled.",
	&"trainer_battles_won": "Trainer battles won.",
	&"wild_battles_won": "Wild battles won.",
	&"blacked_out_count": "Times the player has fainted.",

	# === Pokemon ===
	&"party_count": "Pokemon in the party.",
	&"eggs_hatched": "Eggs hatched.",
	&"evolution_count": "Pokemon evolved.",
	&"trade_count": "Pokemon traded.",
	&"pokemon_caught": "Pokemon caught, including Safari Zone and Eggs.",
	&"boxed_count": "Pokemon in storage.",
}

const MONTH_NAMES: PackedStringArray = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]

## Inspector dropdown list: all field names in order plus an empty entry for unset nodes.
static func hint_string() -> String:
	var names = PackedStringArray([""])
	for name in FIELDS.keys():
		names.append(String(name))
	return ",".join(names)

static func exists(field: StringName) -> bool:
	return FIELDS.has(field)

static func describe(field: StringName) -> String:
	return FIELDS.get(field, "")

## What this field shows now, formatted.
## Unknown fields or ones without a session return empty so nodes fall back sensibly.
static func value(field: StringName) -> String:
	if field.is_empty() or GameState == null:
		return ""
	var player = GameState.player
	if player == null:
		return ""
	var stats = GameState.stats

	match field:
		# === Identity ===
		&"player_name":
			return player.name
		&"id_number":
			return "%05d" % player.public_id()
		&"gender":
			return _character_name(player)
		&"trainer_type":
			return _trainer_type_name(player)
		&"started_on":
			return _format_date(player.started_at)

		# === Wallet ===
		&"money":
			return "$%s" % _with_separators(player.money)
		&"money_plain":
			return str(player.money)
		&"coins":
			return _with_separators(player.coins)
		&"battle_points":
			return str(player.battle_points)
		&"soot":
			return _with_separators(player.soot)

		# === Progress ===
		&"badge_count":
			return str(player.badge_count())
		&"badges_of_total":
			return "%d/%d" % [_badges_in_region(player), GameSettings.data.badges_per_region]
		&"pokedex_owned":
			return str(player.pokedex.owned_count())
		&"pokedex_seen":
			return str(player.pokedex.seen_count())
		&"pokedex_summary":
			return "%d/%d" % [player.pokedex.owned_count(), player.pokedex.seen_count()]
		&"pokedex_completion":
			return _completion(player)
		&"hall_of_fame_count":
			return str(stats.hall_of_fame_entry_count)
		&"hall_of_fame_time":
			return _format_duration(stats.time_to_enter_hall_of_fame)

		# === Time ===
		&"play_time":
			return _format_duration(int(player.play_time_seconds))
		&"play_time_hours":
			return str(int(player.play_time_seconds) / 3600)
		&"play_sessions":
			return str(stats.play_sessions)
		&"average_session_length":
			return _format_duration(stats.average_session_length())

		# === Location ===
		&"region_name":
			return _region_name()
		&"current_location":
			return _location_name()

		# === Travel ===
		&"steps_taken":
			return _with_separators(player.steps_taken)
		&"distance_walked":
			return _with_separators(stats.distance_walked)
		&"distance_cycled":
			return _with_separators(stats.distance_cycled)
		&"distance_surfed":
			return _with_separators(stats.distance_surfed)

		# === Battles ===
		&"battles_won":
			return _with_separators(stats.wild_battles_won + stats.trainer_battles_won)
		&"battles_lost":
			return _with_separators(stats.wild_battles_lost + stats.trainer_battles_lost)
		&"trainer_battles_won":
			return _with_separators(stats.trainer_battles_won)
		&"wild_battles_won":
			return _with_separators(stats.wild_battles_won)
		&"blacked_out_count":
			return str(stats.blacked_out_count)

		# === Pokemon ===
		&"party_count":
			return str(GameState.party.size())
		&"eggs_hatched":
			return str(stats.eggs_hatched)
		&"evolution_count":
			return str(stats.evolution_count)
		&"trade_count":
			return str(stats.trade_count)
		&"pokemon_caught":
			return _with_separators(player.species_caught.size())
		&"boxed_count":
			return str(GameState.storage.total_stored())
	return ""

# === Internals ===

# === Formatting ===

## Whole hours and minutes like the games print play time.
## Negative means not yet, what unreached milestones show.
static func _format_duration(seconds: int) -> String:
	if seconds < 0:
		return "--"
	var hours = seconds / 3600
	var minutes = (seconds / 60) % 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes

## Date as "Aug 10, 2026".
static func _format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "--"
	var parts = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%s %d, %d" % [MONTH_NAMES[int(parts["month"]) - 1], int(parts["day"]), int(parts["year"])]

## Thousands separated like games do for money and steps.
static func _with_separators(amount: int) -> String:
	var digits = str(absi(amount))
	var grouped = ""
	var counted = 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		counted += 1
		if counted % 3 == 0 and index > 0:
			grouped = "," + grouped
	return ("-" + grouped) if amount < 0 else grouped


# === Lookups ===

## Character display name from metadata, or "Boy"/"Girl" if none.
static func _character_name(player: Player) -> String:
	var metadata = Database.player_metadata(player.character_id)
	if metadata != null and not metadata.character_name.is_empty():
		return metadata.character_name
	return "Girl" if player.is_female() else "Boy"

## Trainer type display name, or raw type name if none.
static func _trainer_type_name(player: Player) -> String:
	var record = Database.trainer_type(player.trainer_type())
	if record != null and not record.display_name.is_empty():
		return record.display_name
	return String(player.trainer_type())

## Current region display name.
static func _region_name() -> String:
	var region = Database.town_map(GameState.current_region())
	return region.display_name if region != null else ""

## Current map display name.
static func _location_name() -> String:
	var metadata = Database.map_metadata(GameState.map_id)
	if metadata != null and not metadata.display_name.is_empty():
		return metadata.display_name
	var map = Field.map()
	return map.display_name if map != null else ""

## Badges earned in current region.
## Regions split the bit-run into blocks like the region map's badge strip rows.
static func _badges_in_region(player: Player) -> int:
	var per_region = maxi(GameSettings.data.badges_per_region, 1)
	var first = GameState.current_region() * per_region
	var earned = 0
	for offset in range(per_region):
		if player.has_badge(first + offset):
			earned += 1
	return earned

## Pokédex completion as percentage string, or "0%" if no data.
static func _completion(player: Player) -> String:
	var total = Database.national_dex_order().size()
	if total <= 0:
		return "0%"
	return "%d%%" % (player.pokedex.owned_count() * 100 / total)
