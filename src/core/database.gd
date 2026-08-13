extends Node
## A central read-only access point for all the static game-data records.
##
## Registered as `Database` autoload.
## Records live as `.tres` files under `res://data/[category]/` and are resolved through [DataIndex]
## Lookups are lazy by default so tghat starting the game doesn't hold up reading all ~2,000 .tres files
## Call [method preload_category] if a category is about to be heavily accessed
##
## Example:
## var bulbasaur: SpeciesData = Database.species(&"BULBASAUR")
## var tackle: MoveData = Database.move(&"TACKLE")

const MANIFEST_PATH: String = "res://data/_manifest.tres"

const CATEGORY_SPECIES: StringName = &"species"
const CATEGORY_MOVES: StringName = &"moves"
const CATEGORY_ITEMS: StringName = &"items"
const CATEGORY_ABILITIES: StringName = &"abilities"
const CATEGORY_TYPES: StringName = &"types"
const CATEGORY_NATURES: StringName = &"natures"
const CATEGORY_GROWTH_RATES: StringName = &"growth_rates"
const CATEGORY_GENDER_RATIOS: StringName = &"gender_ratios"
const CATEGORY_EGG_GROUPS: StringName = &"egg_groups"
const CATEGORY_BODY_SHAPES: StringName = &"body_shapes"
const CATEGORY_BODY_COLORS: StringName = &"body_colors"
const CATEGORY_HABITATS: StringName = &"habitats"
const CATEGORY_STATS: StringName = &"stats"
const CATEGORY_STATUSES: StringName = &"statuses"
const CATEGORY_TARGETS: StringName = &"targets"
const CATEGORY_TERRAIN_TAGS: StringName = &"terrain_tags"
const CATEGORY_WEATHERS: StringName = &"weathers"
const CATEGORY_ENVIRONMENTS: StringName = &"environments"
const CATEGORY_ENCOUNTER_TYPES: StringName = &"encounter_types"
const CATEGORY_BATTLE_WEATHERS: StringName = &"battle_weathers"
const CATEGORY_BATTLE_TERRAINS: StringName = &"battle_terrains"
const CATEGORY_EVOLUTION_METHODS: StringName = &"evolution_methods"
const CATEGORY_BERRY_PLANTS: StringName = &"berry_plants"
const CATEGORY_RIBBONS: StringName = &"ribbons"
const CATEGORY_ENCOUNTERS: StringName = &"encounters"
const CATEGORY_TRAINERS: StringName = &"trainers"
const CATEGORY_TRAINER_TYPES: StringName = &"trainer_types"
const CATEGORY_MAP_METADATA: StringName = &"map_metadata"
const CATEGORY_METADATA: StringName = &"metadata"
const CATEGORY_PLAYER_METADATA: StringName = &"player_metadata"
const CATEGORY_TOWN_MAPS: StringName = &"town_maps"
const CATEGORY_REGIONAL_DEXES: StringName = &"regional_dexes"
const CATEGORY_PHONE_MESSAGES: StringName = &"phone_messages"
const CATEGORY_DUNGEON_PARAMETERS: StringName = &"dungeon_parameters"
const CATEGORY_ROAMING_SPECIES: StringName = &"roaming_species"
const CATEGORY_DUNGEON_TILESETS: StringName = &"dungeon_tilesets"
const CATEGORY_TILESETS: StringName = &"tilesets"
const CATEGORY_BATTLE_ANIMATIONS: StringName = &"battle_animations"
const CATEGORY_COMMON_EVENTS: StringName = &"common_events"
const CATEGORY_MYSTERY_GIFTS: StringName = &"mystery_gifts"

## [method reload] emits this once the index is rebuilt, open UI can refresh
signal data_reloaded()

var _manifest: DataManifest = null
var _indexes: Dictionary = {}
var _cache: Dictionary = {}
var _missing_reported: Dictionary = {}

## The associated surface map to underwater map
## built the first time [method surface_map_for] is used
var _surface_maps: Dictionary = {}

## Cached species ids in national dex order, built on first use.
var _national_dex_order: Array[StringName] = []


func _ready() -> void:
	reload()

## Drops the cache of records, and re-reads the manifest
func reload() -> void:
	_indexes.clear()
	_cache.clear()
	_missing_reported.clear()
	_surface_maps.clear()
	_national_dex_order.clear()
	if not ResourceLoader.exists(MANIFEST_PATH):
		push_error("Database: no manifest at %s. Run Project > Tools > Import PBS Data." % MANIFEST_PATH)
		return
	_manifest = ResourceLoader.load(MANIFEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as DataManifest
	if _manifest == null:
		push_error("Database: manifest at %s could not be read." % MANIFEST_PATH)
		return
	for category: StringName in _manifest.indexes:
		var index_path: String = _manifest.indexes[category]
		if not ResourceLoader.exists(index_path):
			push_error("Database: index for '%s' missing at %s." % [category, index_path])
			continue
		var index: DataIndex = ResourceLoader.load(index_path, "", ResourceLoader.CACHE_MODE_IGNORE) as DataIndex
		if index != null:
			_indexes[category] = index
			_cache[category] = {}
	data_reloaded.emit()


# === Generic API === 

## Returns [param id] from [param category]
## Returns `null` if it does not exist
## Missing ids are reported only once, keeping logs readable.
func get_record(category: StringName, id: StringName) -> GameDataResource:
	if id.is_empty():
		return null
	var index: DataIndex = _indexes.get(category)
	if index == null:
		_report_missing("category:" + category, "Database: unknown data category '%s'." % category)
		return null
	var category_cache: Dictionary = _cache[category]
	var cached: Variant = category_cache.get(id)
	if cached != null:
		return cached
	var path: String = index.get_record_path(id)
	if path.is_empty():
		_report_missing(category + ":" + id, "Database: no '%s' record with id '%s'." % [category, id])
		return null
	var record: GameDataResource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if record == null:
		push_error("Database: failed to load %s." % path)
		return null
	record.data_category = category
	category_cache[id] = record
	return record

func has_record(category: StringName, id: StringName) -> bool:
	var index: DataIndex = _indexes.get(category)
	return index != null and index.has_id(id)

## Every id in [param category], in canonical order.
func get_ids(category: StringName) -> Array[StringName]:
	var index: DataIndex = _indexes.get(category)
	if index == null:
		return []
	return index.ordered_ids

## Loads and returns every record in [param category].
func get_all(category: StringName) -> Array[GameDataResource]:
	var result: Array[GameDataResource] = []
	for id: StringName in get_ids(category):
		var record: GameDataResource = get_record(category, id)
		if record != null:
			result.append(record)
	return result

## Prelaods the whole [param category] into the cache
## Useful for contexts like opening the Pokedex or starting a battle.
func preload_category(category: StringName) -> void:
	for id: StringName in get_ids(category):
		get_record(category, id)

func count(category: StringName) -> int:
	var index: DataIndex = _indexes.get(category)
	return index.size() if index != null else 0

# === Typed Accessors ===

func species(id: StringName) -> SpeciesData:
	return get_record(CATEGORY_SPECIES, id) as SpeciesData

## Finds a species by its name and form if present (form falls back to form `0` when the form doesn't exist)
func species_form(species_id: StringName, form: int) -> SpeciesData:
	if form > 0:
		var form_id: StringName = StringName("%s_%d" % [species_id, form])
		var form_record: SpeciesData = species(form_id)
		if form_record != null:
			return form_record
	return species(species_id)

func move(id: StringName) -> MoveData:
	return get_record(CATEGORY_MOVES, id) as MoveData

func item(id: StringName) -> ItemData:
	return get_record(CATEGORY_ITEMS, id) as ItemData

func ability(id: StringName) -> AbilityData:
	return get_record(CATEGORY_ABILITIES, id) as AbilityData

func type(id: StringName) -> TypeData:
	return get_record(CATEGORY_TYPES, id) as TypeData

func nature(id: StringName) -> NatureData:
	return get_record(CATEGORY_NATURES, id) as NatureData

func growth_rate(id: StringName) -> GrowthRateData:
	return get_record(CATEGORY_GROWTH_RATES, id) as GrowthRateData

func gender_ratio(id: StringName) -> GenderRatioData:
	return get_record(CATEGORY_GENDER_RATIOS, id) as GenderRatioData

func stat(id: StringName) -> StatData:
	return get_record(CATEGORY_STATS, id) as StatData

func status(id: StringName) -> StatusData:
	return get_record(CATEGORY_STATUSES, id) as StatusData

func target(id: StringName) -> TargetData:
	return get_record(CATEGORY_TARGETS, id) as TargetData

func terrain_tag(id: StringName) -> TerrainTagData:
	return get_record(CATEGORY_TERRAIN_TAGS, id) as TerrainTagData

## Looks a terrain tag up by the number stored in tileset data.
func terrain_tag_by_number(number: int) -> TerrainTagData:
	for id: StringName in get_ids(CATEGORY_TERRAIN_TAGS):
		var tag: TerrainTagData = terrain_tag(id)
		if tag != null and tag.tag_number == number:
			return tag
	return null

func weather(id: StringName) -> WeatherData:
	return get_record(CATEGORY_WEATHERS, id) as WeatherData

## Looks a weather up by the number RPG Maker's Set Weather command to allow for compatibility
## with old RPG Maker maps / scripts.
func weather_by_number(number: int) -> WeatherData:
	if number <= 0:
		return weather(&"None")
	for id: StringName in get_ids(CATEGORY_WEATHERS):
		var record: WeatherData = weather(id)
		if record != null and record.legacy_number == number:
			return record
	return null

func environment(id: StringName) -> EnvironmentData:
	return get_record(CATEGORY_ENVIRONMENTS, id) as EnvironmentData

func encounter_type(id: StringName) -> EncounterTypeData:
	return get_record(CATEGORY_ENCOUNTER_TYPES, id) as EncounterTypeData

func battle_weather(id: StringName) -> BattleWeatherData:
	return get_record(CATEGORY_BATTLE_WEATHERS, id) as BattleWeatherData

func battle_terrain(id: StringName) -> BattleTerrainData:
	return get_record(CATEGORY_BATTLE_TERRAINS, id) as BattleTerrainData

## The common event numbered [param number]
## Returns `null` when the project has none.
func common_event(number: int) -> CommonEventData:
	return get_record(CATEGORY_COMMON_EVENTS, CommonEventData.make_id(number)) as CommonEventData

## The Mystery Gift numbered [param number]
## `null` when the project has no such gift.
func mystery_gift(number: int) -> MysteryGiftData:
	return get_record(
		CATEGORY_MYSTERY_GIFTS, MysteryGiftData.make_id(number)) as MysteryGiftData

func battle_animation(id: StringName) -> BattleAnimationData:
	return get_record(CATEGORY_BATTLE_ANIMATIONS, id) as BattleAnimationData

func evolution_method(id: StringName) -> EvolutionMethodData:
	return get_record(CATEGORY_EVOLUTION_METHODS, id) as EvolutionMethodData

func berry_plant(id: StringName) -> BerryPlantData:
	return get_record(CATEGORY_BERRY_PLANTS, id) as BerryPlantData

func ribbon(id: StringName) -> RibbonData:
	return get_record(CATEGORY_RIBBONS, id) as RibbonData

func trainer_type(id: StringName) -> TrainerTypeData:
	return get_record(CATEGORY_TRAINER_TYPES, id) as TrainerTypeData

func trainer(type_id: StringName, trainer_name: String, version: int = 0) -> TrainerData:
	return get_record(CATEGORY_TRAINERS, TrainerData.make_id(type_id, trainer_name, version)) as TrainerData

func encounters(map_id: int, version: int = 0) -> EncounterData:
	return get_record(CATEGORY_ENCOUNTERS, EncounterData.make_id(map_id, version)) as EncounterData

func map_metadata(map_id: int) -> MapMetadataData:
	return get_record(CATEGORY_MAP_METADATA, StringName(str(map_id))) as MapMetadataData

## The map that [param dive_map_id] is the underwater version of, or `0`.
func surface_map_for(dive_map_id: int) -> int:
	if dive_map_id <= 0:
		return 0
	if _surface_maps.is_empty():
		_build_dive_pairs()
	return int(_surface_maps.get(dive_map_id, 0))

func _build_dive_pairs() -> void:
	_surface_maps[0] = 0
	for id: StringName in get_ids(CATEGORY_MAP_METADATA):
		var metadata_record: MapMetadataData = get_record(CATEGORY_MAP_METADATA, id) as MapMetadataData
		if metadata_record == null or metadata_record.dive_map_id <= 0:
			continue
		var surface_id: int = int(String(id))
		if _surface_maps.has(metadata_record.dive_map_id):
			push_warning("Database: maps %d and %d both dive to map %d." % [
				int(_surface_maps[metadata_record.dive_map_id]), surface_id, metadata_record.dive_map_id,
			])
			continue
		_surface_maps[metadata_record.dive_map_id] = surface_id

func metadata() -> MetadataData:
	return get_record(CATEGORY_METADATA, &"0") as MetadataData

func player_metadata(player_id: int) -> PlayerMetadataData:
	return get_record(CATEGORY_PLAYER_METADATA, StringName(str(player_id))) as PlayerMetadataData

func town_map(region: int) -> TownMapData:
	return get_record(CATEGORY_TOWN_MAPS, StringName(str(region))) as TownMapData

func regional_dex(region: int) -> RegionalDexData:
	return get_record(CATEGORY_REGIONAL_DEXES, StringName(str(region))) as RegionalDexData

func phone_messages(id: StringName) -> PhoneMessageData:
	return get_record(CATEGORY_PHONE_MESSAGES, id) as PhoneMessageData

func dungeon_parameters(id: StringName) -> DungeonParametersData:
	return get_record(CATEGORY_DUNGEON_PARAMETERS, id) as DungeonParametersData

func roaming_species(id: StringName) -> RoamingSpeciesData:
	return get_record(CATEGORY_ROAMING_SPECIES, id) as RoamingSpeciesData

func dungeon_tileset(tileset_id: int) -> DungeonTilesetData:
	return get_record(CATEGORY_DUNGEON_TILESETS, StringName(str(tileset_id))) as DungeonTilesetData

func tileset(tileset_id: int) -> TilesetData:
	return get_record(CATEGORY_TILESETS, StringName(str(tileset_id))) as TilesetData

func egg_group(id: StringName) -> GameDataResource:
	return get_record(CATEGORY_EGG_GROUPS, id)

func body_shape(id: StringName) -> BodyShapeData:
	return get_record(CATEGORY_BODY_SHAPES, id) as BodyShapeData

func body_color(id: StringName) -> GameDataResource:
	return get_record(CATEGORY_BODY_COLORS, id)

func habitat(id: StringName) -> GameDataResource:
	return get_record(CATEGORY_HABITATS, id)

## === Shortcuts ===

## Species ids of form 0 only
## This is the national dex ordering.
func national_dex_order() -> Array[StringName]:
	if not _national_dex_order.is_empty():
		return _national_dex_order
	for id: StringName in get_ids(CATEGORY_SPECIES):
		if not String(id).contains("_"):
			_national_dex_order.append(id)
	return _national_dex_order

## 1-based national dex number of [param species_id], or `0` when unknown.
func national_dex_number(species_id: StringName) -> int:
	return national_dex_order().find(species_id) + 1

## Damage multiplier of [param attacking_type] against a defender that has
## [param defending_types].
func type_effectiveness(attacking_type: StringName, defending_types: Array[StringName]) -> float:
	if attacking_type.is_empty():
		return 1.0
	var multiplier: float = 1.0
	for defending_type: StringName in defending_types:
		var record: TypeData = type(defending_type)
		if record != null:
			multiplier *= record.effectiveness_against_self(attacking_type)
	return multiplier

## All stat ids that hold a value on a Pokemon, in canonical order.
func persistent_stat_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in get_ids(CATEGORY_STATS):
		var record: StatData = stat(id)
		if record != null and record.is_persistent():
			result.append(id)
	return result

## All stat ids that have battle stat stages, in canonical order.
func battle_stat_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in get_ids(CATEGORY_STATS):
		var record: StatData = stat(id)
		if record != null and record.has_stat_stages():
			result.append(id)
	return result

func _report_missing(key: String, message: String) -> void:
	if _missing_reported.has(key):
		return
	_missing_reported[key] = true
	push_warning(message)
