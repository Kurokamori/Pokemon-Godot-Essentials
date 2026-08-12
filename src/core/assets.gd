class_name Assets
## Static Helpers for turning game-data assets into named loaded resources.
##
## All lookups go through [AssetIndex]
## Every loaded texture is cached.

const INDEX_PATH: String = "res://assets/_asset_index.tres"

static var _index: AssetIndex = null
static var _texture_cache: Dictionary = {}
static var _audio_cache: Dictionary = {}
static var _frame_cache: Dictionary = {}
static var _warned: Dictionary = {}


static func index() -> AssetIndex:
	if _index == null:
		if ResourceLoader.exists(INDEX_PATH):
			_index = ResourceLoader.load(INDEX_PATH, "", ResourceLoader.CACHE_MODE_REUSE) as AssetIndex
		if _index == null:
			_index = AssetIndex.new()
			push_warning("Assets : %s missing, run asset indexer." % INDEX_PATH)
	return _index
	
static func reload_index() -> void:
	_index = null	
	_texture_cache.clear()
	_audio_cache.clear()
	_frame_cache.clear()
	_warned.clear()
	
static func path(category: StringName, asset_name: String) -> String:
	return index().resolve(category, asset_name)
	
static func exists(category: StringName, asset_name: String) -> bool:
	return index().has_asset(category, asset_name)
	
## Loads a texture by its category and name
## Returns `null` when absent.
static func texture(category: StringName, asset_name: StringName) -> Texture2D:
	var key: String = String(category) + "/" + asset_name.to_lower()
	if _texture_cache.has(key):
		return _texture_cache[key]
	var resource_path: String = path(category, asset_name)
	if resource_path.is_empty():
		_warn_once(key, "Assets: no texture '%s' found in category '%s'" % [asset_name, category])
		return null
	var loaded: Texture2D = ResourceLoader.load(resource_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	_texture_cache[key] = loaded
	return loaded
	
## Loads an audio by its category and name
## Returns `null` when absent.
static func audio(category: StringName, asset_name: StringName) -> AudioStream:
	var key: String = String(category) + "/" + asset_name.to_lower()
	if _audio_cache.has(key):
		return _audio_cache[key]
	var resource_path : String = path(category, asset_name)
	if resource_path.is_empty():
		_warn_once(key, "Assets: no audio file '%s' found in category '%s'" % [asset_name, category])
		return null
	var loaded: AudioStream = ResourceLoader.load(resource_path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
	_audio_cache[key] = loaded
	return loaded
	
# === Pokemon Sprites ==

## Battle sprite for a species + form.
## setting [param back] will select the player-side sprite.
static func pokemon_sprite(species_id: StringName, form: int, shiny: bool, back: bool, female: bool = false, egg: bool = false) -> Texture2D:
	if egg:
		return _first_texture(AssetIndex.CATEGORY_POKEMON_EGGS, [String(species_id), "000"])
	var category: StringName
	if back:
		category = AssetIndex.CATEGORY_POKEMON_BACK_SHINY if shiny else AssetIndex.CATEGORY_POKEMON_BACK
	else: 
		category = AssetIndex.CATEGORY_POKEMON_FRONT_SHINY if shiny else AssetIndex.CATEGORY_POKEMON_FRONT
	return _first_texture(category, _sprite_name_candidates(species_id, form, female))
	
## Egg animation sheep of the cracking egg.
## Five frames from left to right.
## Any species without an egg of its own, falls back to the generic egg.
static func egg_cracks(species_id: StringName) -> Texture2D:
	return _first_texture(
		AssetIndex.CATEGORY_POKEMON_EGGS, [String(species_id) + "_cracks", "000_cracks"]
	)
	
## Party and Storage icons for the species/form
static func pokemon_icon(species_id: StringName, form: int, shiny: bool, female: bool = false, egg: bool = false) -> Texture2D:
	if egg:
		return _first_texture(AssetIndex.CATEGORY_POKEMON_EGGS, [String(species_id) + "_icon", "000_icon", "egg_icon"])
	var category: StringName = AssetIndex.CATEGORY_POKEMON_ICONS_SHINY if shiny else AssetIndex.CATEGORY_POKEMON_ICONS
	var icon: Texture2D = _first_texture(category, _sprite_name_candidates(species_id, form, female))
	if icon == null and shiny:
		icon = _first_texture(AssetIndex.CATEGORY_POKEMON_ICONS, _sprite_name_candidates(species_id, form, female))
	return icon
	
## Spritesheets are square frames laid out from left to right so 128x64 sheet is 2 64x64 frames
##
## Frames are cached alongside the textures they slice.
## Otherwise, every party view / storage view would re-slice the same sheet 
## An [AtlasTexture] is safe to share once built.
##
## A sheet that is not a whole number of square frames wide will be treated as one whole (long) frame
## instead of treating it as wrongly sliced.
static func sprite_sheet_frames(sheet: Texture2D) -> Array[AtlasTexture]:
	if sheet == null:
		return [] as Array[AtlasTexture]
	var key: String = sheet.resource_path
	if key.is_empty():
		key = str(sheet.get_instance_id())
	if _frame_cache.has(key):
		return _frame_cache[key]
	var width: int = sheet.get_width()
	var height: int = sheet.get_height()
	var count: int = 1
	if height > 0 and width >= height and width % height == 0:
		count = width / height
	var frame_width: int = width / count
	var frames: Array[AtlasTexture] = []
	for frame_index: int in range(count):
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(
			Vector2(float(frame_index * frame_width), 0.0),
			Vector2(float(frame_width), float(height)),
		)
		frame.filter_clip = true
		frames.append(frame)
	_frame_cache[key] = frames
	return frames

## [param sheet] resting frame - for places that show a still icon
static func first_sprite_frame(sheet: Texture2D) -> Texture2D:
	var frames: Array[AtlasTexture] = sprite_sheet_frames(sheet)
	return frames[0] if not frames.is_empty() else null
	
## The pokeball icon, extracted from [param ball_id]'s throwing sheet
## used to draw the pokeball as a single icon.
##
## These frames are half as wide as they are tall rather than square
## The ball rests in the middle of the first frame so that's what we return.
static func poke_ball_icon(ball_id:StringName) -> Texture2D:
	var sheet: Texture2D = texture(AssetIndex.CATEGORY_BATTLE_ANIMATIONS, "ball_%s" % ball_id)
	if sheet == null:
		return null
	var height: float = float(sheet.get_height())
	if height <= 0.0 or float(sheet.get_width()) < height:
		return sheet
	var side: float = height * 0.5
	var frame: AtlasTexture = AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(Vector2(0.0, (height - side) * 0.5), Vector2(side, side))
	frame.filter_clip = true
	return frame

static func pokemon_footprint(species_id: StringName, form: int) -> Texture2D:
	return _first_texture(AssetIndex.CATEGORY_POKEMON_FOOTPRINTS, _sprite_name_candidates(species_id, form, false))
	
# === Other Sprites ===
	
static func item_icon(item_id: StringName) -> Texture2D:
	return _first_texture(AssetIndex.CATEGORY_ITEMS, [String(item_id), "000"])
	
static func trainer_sprite(trainer_type_id: StringName) -> Texture2D:
	return _first_texture(AssetIndex.CATEGORY_TRAINERS, [String(trainer_type_id)])
	
## The picture used for the bag category icon
## [param pocket] is the [BagPocket] number
static func bag_pocket_icon(pocket: int) -> Texture2D:
	return _first_texture(AssetIndex.CATEGORY_ICONS, ["bagPocket%d" % pocket])

# === Utilities ===
static func _sprite_name_candidates(species_id: StringName, form: int, female: bool) -> Array:
	var base: String = String(species_id)
	var candidates: Array = []
	if form > 0:
		if female:
			candidates.append("%s_%d_female" % [base, form])
	if female:
		candidates.append(base + "_female")
	candidates.append(base)
	return candidates

static func _first_texture(category: StringName, candidates: Array) -> Texture2D:
	for candidate: String in candidates:
		if exists(category, candidate):
			return texture(category, candidate)
	return null
	
static func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)
