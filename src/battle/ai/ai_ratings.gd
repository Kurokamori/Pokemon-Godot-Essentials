class_name AIRatings
extends RefCounted
## How good an Ability or a held item is to have.


## Base ratings for every Ability that is worth more or less than nothing, keyed by rating.
const ABILITY_RATINGS: Dictionary = {
	10: [&"DELTASTREAM", &"DESOLATELAND", &"HUGEPOWER", &"MOODY", &"PARENTALBOND",
		&"POWERCONSTRUCT", &"PRIMORDIALSEA", &"PUREPOWER", &"SHADOWTAG",
		&"STANCECHANGE", &"WONDERGUARD"],
	9: [&"ARENATRAP", &"DRIZZLE", &"DROUGHT", &"IMPOSTER", &"MAGICBOUNCE", &"MAGICGUARD",
		&"MAGNETPULL", &"SANDSTREAM", &"SPEEDBOOST"],
	8: [&"ADAPTABILITY", &"AERILATE", &"CONTRARY", &"DISGUISE", &"DRAGONSMAW",
		&"ELECTRICSURGE", &"GALVANIZE", &"GRASSYSURGE", &"ILLUSION", &"LIBERO",
		&"MISTYSURGE", &"MULTISCALE", &"MULTITYPE", &"NOGUARD", &"POISONHEAL",
		&"PIXILATE", &"PRANKSTER", &"PROTEAN", &"PSYCHICSURGE", &"REFRIGERATE",
		&"REGENERATOR", &"RKSSYSTEM", &"SERENEGRACE", &"SHADOWSHIELD", &"SHEERFORCE",
		&"SIMPLE", &"SNOWWARNING", &"TECHNICIAN", &"TRANSISTOR", &"WATERBUBBLE"],
	7: [&"BEASTBOOST", &"BULLETPROOF", &"COMPOUNDEYES", &"DOWNLOAD", &"FURCOAT",
		&"HUSTLE", &"ICESCALES", &"INTIMIDATE", &"LEVITATE", &"LIGHTNINGROD",
		&"MEGALAUNCHER", &"MOLDBREAKER", &"MOXIE", &"NATURALCURE", &"SAPSIPPER",
		&"SHEDSKIN", &"SKILLLINK", &"SOULHEART", &"STORMDRAIN", &"TERAVOLT", &"THICKFAT",
		&"TINTEDLENS", &"TOUGHCLAWS", &"TRIAGE", &"TURBOBLAZE", &"UNBURDEN",
		&"VOLTABSORB", &"WATERABSORB"],
	6: [&"BATTLEBOND", &"CHLOROPHYLL", &"COMATOSE", &"DARKAURA", &"DRYSKIN",
		&"FAIRYAURA", &"FILTER", &"FLASHFIRE", &"FORECAST", &"GALEWINGS", &"GUTS",
		&"INFILTRATOR", &"IRONBARBS", &"IRONFIST", &"MIRRORARMOR", &"MOTORDRIVE",
		&"NEUROFORCE", &"PRISMARMOR", &"QUEENLYMAJESTY", &"RECKLESS", &"ROUGHSKIN",
		&"SANDRUSH", &"SCHOOLING", &"SCRAPPY", &"SHIELDSDOWN", &"SOLIDROCK", &"STAKEOUT",
		&"STAMINA", &"STEELWORKER", &"STRONGJAW", &"STURDY", &"SWIFTSWIM", &"TOXICBOOST",
		&"TRACE", &"UNAWARE", &"VICTORYSTAR"],
	5: [&"AFTERMATH", &"AIRLOCK", &"ANALYTIC", &"BERSERK", &"BLAZE", &"CLOUDNINE",
		&"COMPETITIVE", &"CORROSION", &"DANCER", &"DAZZLING", &"DEFIANT", &"FLAREBOOST",
		&"FLUFFY", &"GOOEY", &"HARVEST", &"HEATPROOF", &"INNARDSOUT", &"LIQUIDVOICE",
		&"MARVELSCALE", &"MUMMY", &"NEUTRALIZINGGAS", &"OVERCOAT", &"OVERGROW",
		&"PRESSURE", &"QUICKFEET", &"ROCKHEAD", &"SANDSPIT", &"SHIELDDUST", &"SLUSHRUSH",
		&"SWARM", &"TANGLINGHAIR", &"TORRENT"],
	4: [&"ANGERPOINT", &"BADDREAMS", &"CHEEKPOUCH", &"CLEARBODY", &"CURSEDBODY",
		&"EARLYBIRD", &"EFFECTSPORE", &"FLAMEBODY", &"FLOWERGIFT", &"FULLMETALBODY",
		&"GORILLATACTICS", &"HYDRATION", &"ICEFACE", &"IMMUNITY", &"INSOMNIA",
		&"JUSTIFIED", &"MERCILESS", &"PASTELVEIL", &"POISONPOINT", &"POISONTOUCH",
		&"RIPEN", &"SANDFORCE", &"SOUNDPROOF", &"STATIC", &"SURGESURFER", &"SWEETVEIL",
		&"SYNCHRONIZE", &"VITALSPIRIT", &"WATERCOMPACTION", &"WATERVEIL",
		&"WHITESMOKE", &"WONDERSKIN"],
	3: [&"AROMAVEIL", &"AURABREAK", &"COTTONDOWN", &"DAUNTLESSSHIELD",
		&"EMERGENCYEXIT", &"GLUTTONY", &"GULPMISSILE", &"HYPERCUTTER", &"ICEBODY",
		&"INTREPIDSWORD", &"LIMBER", &"LIQUIDOOZE", &"LONGREACH", &"MAGICIAN",
		&"OWNTEMPO", &"PICKPOCKET", &"RAINDISH", &"RATTLED", &"SANDVEIL",
		&"SCREENCLEANER", &"SNIPER", &"SNOWCLOAK", &"SOLARPOWER", &"STEAMENGINE",
		&"STICKYHOLD", &"SUPERLUCK", &"UNNERVE", &"WIMPOUT"],
	2: [&"BATTLEARMOR", &"COLORCHANGE", &"CUTECHARM", &"DAMP", &"GRASSPELT",
		&"HUNGERSWITCH", &"INNERFOCUS", &"LEAFGUARD", &"LIGHTMETAL", &"MIMICRY",
		&"OBLIVIOUS", &"POWERSPOT", &"PROPELLERTAIL", &"PUNKROCK", &"SHELLARMOR",
		&"STALWART", &"STEADFAST", &"STEELYSPIRIT", &"SUCTIONCUPS", &"TANGLEDFEET",
		&"WANDERINGSPIRIT", &"WEAKARMOR"],
	1: [&"BIGPECKS", &"KEENEYE", &"MAGMAARMOR", &"PICKUP", &"RIVALRY", &"STENCH"],
	-1: [&"DEFEATIST", &"HEAVYMETAL", &"KLUTZ", &"NORMALIZE", &"PERISHBODY", &"STALL",
		&"ZENMODE"],
	-2: [&"SLOWSTART", &"TRUANT"],
}

## Base ratings for every held item that is worth more or less than nothing.
const ITEM_RATINGS: Dictionary = {
	10: [&"EVIOLITE", &"FOCUSSASH", &"LIFEORB", &"THICKCLUB"],
	9: [&"ASSAULTVEST", &"BLACKSLUDGE", &"CHOICEBAND", &"CHOICESCARF", &"CHOICESPECS",
		&"DEEPSEATOOTH", &"LEFTOVERS"],
	8: [&"LEEK", &"STICK", &"THROATSPRAY", &"WEAKNESSPOLICY"],
	7: [&"EXPERTBELT", &"LIGHTBALL", &"LUMBERRY", &"POWERHERB", &"ROCKYHELMET",
		&"SITRUSBERRY"],
	6: [&"KINGSROCK", &"LIECHIBERRY", &"LIGHTCLAY", &"PETAYABERRY", &"RAZORFANG",
		&"REDCARD", &"SALACBERRY", &"SHELLBELL", &"WHITEHERB",
		&"BABIRIBERRY", &"CHARTIBERRY", &"CHILANBERRY", &"CHOPLEBERRY", &"COBABERRY",
		&"COLBURBERRY", &"HABANBERRY", &"KASIBBERRY", &"KEBIABERRY", &"OCCABERRY",
		&"PASSHOBERRY", &"PAYAPABERRY", &"RINDOBERRY", &"ROSELIBERRY", &"SHUCABERRY",
		&"TANGABERRY", &"WACANBERRY", &"YACHEBERRY",
		&"BUGGEM", &"DARKGEM", &"DRAGONGEM", &"ELECTRICGEM", &"FAIRYGEM", &"FIGHTINGGEM",
		&"FIREGEM", &"FLYINGGEM", &"GHOSTGEM", &"GRASSGEM", &"GROUNDGEM", &"ICEGEM",
		&"NORMALGEM", &"POISONGEM", &"PSYCHICGEM", &"ROCKGEM", &"STEELGEM", &"WATERGEM",
		&"ADAMANTORB", &"GRISEOUSORB", &"LUSTROUSORB", &"SOULDEW",
		&"AGUAVBERRY", &"FIGYBERRY", &"IAPAPABERRY", &"MAGOBERRY", &"WIKIBERRY"],
	5: [&"CUSTAPBERRY", &"DEEPSEASCALE", &"EJECTBUTTON", &"FOCUSBAND", &"JABOCABERRY",
		&"KEEBERRY", &"LANSATBERRY", &"MARANGABERRY", &"MENTALHERB", &"METRONOME",
		&"MUSCLEBAND", &"QUICKCLAW", &"RAZORCLAW", &"ROWAPBERRY", &"SCOPELENS",
		&"WISEGLASSES",
		&"BLACKBELT", &"BLACKGLASSES", &"CHARCOAL", &"DRAGONFANG", &"HARDSTONE",
		&"MAGNET", &"METALCOAT", &"MIRACLESEED", &"MYSTICWATER", &"NEVERMELTICE",
		&"POISONBARB", &"SHARPBEAK", &"SILKSCARF", &"SILVERPOWDER", &"SOFTSAND",
		&"SPELLTAG", &"TWISTEDSPOON",
		&"ODDINCENSE", &"ROCKINCENSE", &"ROSEINCENSE", &"SEAINCENSE", &"WAVEINCENSE",
		&"DRACOPLATE", &"DREADPLATE", &"EARTHPLATE", &"FISTPLATE", &"FLAMEPLATE",
		&"ICICLEPLATE", &"INSECTPLATE", &"IRONPLATE", &"MEADOWPLATE", &"MINDPLATE",
		&"PIXIEPLATE", &"SKYPLATE", &"SPLASHPLATE", &"SPOOKYPLATE", &"STONEPLATE",
		&"TOXICPLATE", &"ZAPPLATE",
		&"DAMPROCK", &"HEATROCK", &"ICYROCK", &"SMOOTHROCK", &"TERRAINEXTENDER"],
	4: [&"ADRENALINEORB", &"APICOTBERRY", &"BLUNDERPOLICY", &"CHESTOBERRY",
		&"EJECTPACK", &"ENIGMABERRY", &"GANLONBERRY", &"HEAVYDUTYBOOTS",
		&"ROOMSERVICE", &"SAFETYGOGGLES", &"SHEDSHELL", &"STARFBERRY"],
	3: [&"BIGROOT", &"BRIGHTPOWDER", &"LAXINCENSE", &"LEPPABERRY", &"PERSIMBERRY",
		&"PROTECTIVEPADS", &"UTILITYUMBRELLA",
		&"ASPEARBERRY", &"CHERIBERRY", &"PECHABERRY", &"RAWSTBERRY"],
	2: [&"ABSORBBULB", &"BERRYJUICE", &"CELLBATTERY", &"GRIPCLAW", &"LUMINOUSMOSS",
		&"MICLEBERRY", &"ORANBERRY", &"SNOWBALL", &"WIDELENS", &"ZOOMLENS",
		&"ELECTRICSEED", &"GRASSYSEED", &"MISTYSEED", &"PSYCHICSEED"],
	1: [&"AIRBALLOON", &"BINDINGBAND", &"DESTINYKNOT", &"FLOATSTONE", &"LUCKYPUNCH",
		&"METALPOWDER", &"QUICKPOWDER",
		&"BURNDRIVE", &"CHILLDRIVE", &"DOUSEDRIVE", &"SHOCKDRIVE",
		&"BUGMEMORY", &"DARKMEMORY", &"DRAGONMEMORY", &"ELECTRICMEMORY",
		&"FAIRYMEMORY", &"FIGHTINGMEMORY", &"FIREMEMORY", &"FLYINGMEMORY",
		&"GHOSTMEMORY", &"GRASSMEMORY", &"GROUNDMEMORY", &"ICEMEMORY", &"POISONMEMORY",
		&"PSYCHICMEMORY", &"ROCKMEMORY", &"STEELMEMORY", &"WATERMEMORY"],
	-5: [&"FULLINCENSE", &"LAGGINGTAIL", &"RINGTARGET"],
	-6: [&"MACHOBRACE", &"POWERANKLET", &"POWERBAND", &"POWERBELT", &"POWERBRACER",
		&"POWERLENS", &"POWERWEIGHT"],
	-7: [&"FLAMEORB", &"IRONBALL", &"TOXICORB"],
	-9: [&"STICKYBARB"],
}

## Abilities that are worth nothing at all to a battler with no damaging move of the type they power up, keyed by that type.
const TYPE_BOOST_ABILITIES: Dictionary = {
	&"BLAZE": &"FIRE",
	&"TORRENT": &"WATER",
	&"OVERGROW": &"GRASS",
	&"SWARM": &"BUG",
	&"STEELWORKER": &"STEEL",
	&"TRANSISTOR": &"ELECTRIC",
	&"DRAGONSMAW": &"DRAGON",
	&"WATERBUBBLE": &"WATER",
}

## Moves that throw the user's held item at somebody, which makes a heavy item worth holding.
const FLING_CODES: Array[StringName] = [&"ThrowUserItemAtTarget"]

## Moves that hit harder while their user is holding nothing.
const ACROBATICS_CODES: Array[StringName] = [&"DoublePowerIfUserHasNoItem"]

## What having [param ability] would be worth to [param battler]
static func for_ability(battle: Battle, battler: Battler, ability: StringName) -> int:
	if ability.is_empty() or ability == &"NONE":
		return 0
	var rating: int = _base(ABILITY_RATINGS, ability)
	if TYPE_BOOST_ABILITIES.has(ability):
		var wanted: StringName = TYPE_BOOST_ABILITIES[ability]
		if not AIBattlerView.has_damaging_move_of(battle, battler, wanted):
			return 0
	match ability:
		&"SKILLLINK":
			if not AIBattlerView.check_moves(battler, func(move: PokemonMove) -> bool:
				var record: MoveData = move.data()
				if record == null:
					return false
				return MoveEffects.get_effect(record.function_code).maximum_hits > 1
			):
				return 0
		&"IRONFIST", &"STRONGJAW", &"MEGALAUNCHER", &"PUNKROCK":
			if not _has_move_of_kind(battler, ability):
				return 0
		&"HUGEPOWER", &"PUREPOWER", &"HUSTLE", &"GORILLATACTICS":
			if not AIBattlerView.has_physical_move(battler):
				return 0
		&"SOLARPOWER", &"COMPOUNDEYES":
			if not AIBattlerView.has_damaging_move(battler):
				return 0
	return rating

## What holding [param item] would be worth to [param battler]
static func for_item(battler: Battler, item: StringName) -> int:
	if item.is_empty() or item == &"NONE":
		var empty_handed: int = 0
		if AIBattlerView.has_move_with_function(battler, ACROBATICS_CODES):
			empty_handed += 1
		return empty_handed
	var rating: int = _base(ITEM_RATINGS, item)
	if AIBattlerView.has_move_with_function(battler, FLING_CODES):
		var record: ItemData = Database.item(item)
		if record != null:
			var power: int = int(record.get_flag_value(&"Fling", "0"))
			if power >= 80:
				rating += 1
			if power >= 100:
				rating += 1
	if AIBattlerView.has_move_with_function(battler, ACROBATICS_CODES):
		rating -= 1
	return rating

## Whether the battler has a move of the kind [param ability] powers up
static func _has_move_of_kind(battler: Battler, ability: StringName) -> bool:
	return AIBattlerView.check_moves(battler, func(move: PokemonMove) -> bool:
		var record: MoveData = move.data()
		if record == null:
			return false
		match ability:
			&"IRONFIST":
				return record.is_punching_move()
			&"STRONGJAW":
				return record.is_biting_move()
			&"MEGALAUNCHER":
				return record.is_pulse_move()
			&"PUNKROCK":
				return record.is_sound_move()
		return false
	)

static func _base(table: Dictionary, id: StringName) -> int:
	for rating: int in table:
		if (table[rating] as Array).has(id):
			return rating
	return 0
