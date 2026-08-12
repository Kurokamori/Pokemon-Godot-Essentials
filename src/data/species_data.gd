@tool
class_name SpeciesData
extends GameDataResource

## A Pokemon Species or an alternate form of the species.
##
## Every form is a seperate record.
## The record id of a form 0 is the bare species id (`&"TYPHLOSION"`)
## Other forms append the form number (`&"TYPHLOSION_1"`)
##
## [member mega_message] is for species that Mega Evolve without a stone
## such as Rayquaza, which does it by knowing Dragon Ascent, and so has no item to announce this reaction from.
const MEGA_MESSAGE_WISH: int = 1

## How far [method minimum_level] walks down a family before the data has a cycle in it.
## No real family is anywehre near this long
const MAXIMUM_FAMILY_DEPTH: int = 16

## Base species this record belongs to.
@export var species: StringName = &""

## Form number.
## `0` is the default form.
@export_range(0, 255) var form: int = 0

## Form name shown after the species name.
## (Example : "Mega Charizard X" )
@export var form_name: String = ""

## Pokedex category
## Omit 'Pokemon' so "Seed" = "Seed Pokemon"
@export var category: String = ""

@export_multiline var pokedex_entry: String = ""

## Form whose Pokedex page this form shares.
## Generally equal to [member form].
@export var pokedex_form: int = 0

## One or Two type ids.
@export var types: Array[StringName] = [&"NORMAL"]

@export_group("Base Stats")
@export_range(1, 255) var base_hp: int = 1
@export_range(1, 255) var base_attack: int = 1
@export_range(1, 255) var base_defense: int = 1
@export_range(1, 255) var base_special_attack: int = 1
@export_range(1, 255) var base_special_defense: int = 1
@export_range(1, 255) var base_speed: int = 1

@export_group("Effort Value (EV) Yield")
@export_range(0, 3) var ev_hp: int = 0
@export_range(0, 3) var ev_attack: int = 0
@export_range(0, 3) var ev_defense: int = 0
@export_range(0, 3) var ev_special_attack: int = 0
@export_range(0, 3) var ev_special_defense: int = 0
@export_range(0, 3) var ev_speed: int = 0

@export_group("Growth")
@export var base_exp: int = 100
## ID of a [GrowthRateData] record
@export var growth_rate: StringName = &"Medium"
## Id of a [GenderRatioData] record
@export var gender_ratio: StringName = &"Female50Percent"
@export_range(0, 255) var catch_rate: int = 255
@export_range(0, 255) var base_happiness: int = 70

@export_group("Moves")
@export var level_up_moves: Array[LevelUpMove] = []
## Moves that can be learned 'artificially' such a move tutor, TM, HM, TR
@export var tutor_moves: Array[StringName] = []
@export var egg_moves: Array[StringName] = []

@export_group("Abilities")
@export var abilities: Array[StringName] = []
@export var hidden_abilities: Array[StringName] = []

@export_group("Wild Held Items")
@export var wild_item_common: Array[StringName] = []
@export var wild_item_uncommon: Array[StringName] = []
@export var wild_item_rare: Array[StringName] = []

@export_group("Breeding")
@export var egg_groups: Array[StringName] = [&"Undiscovered"]
@export var hatch_steps: int = 1
## Item the mother must hold to produce [member offspring] instead of the default baby form.
@export var incense: StringName = &""
## Species that may hatch from this species' eggs.
## Empty means the lowest evolution stage of the line.
@export var offspring: Array[StringName] = []

@export_group("Evolution")
@export var evolutions: Array[SpeciesEvolution] = []

@export_group("Pokedex")
## Height in DECIMETERS (a value of `7` means 0.7m)
@export var height: int = 1

## Weight in HECTOGRAMS (a value of `1105` means 110.5kg)
@export var weight: int = 1

## ID of a [BodyColorData] record
@export var color: StringName = &"Red"

## ID of the [BodyShapeData] record
@export var shape: StringName = &"Head"

## ID of a [HabitatData] record
@export var habitat: StringName = &"None"
@export var generation: int = 0

@export_group("Mega Evolution")
@export var mega_stone: StringName = &""
@export var mega_move: StringName = &""

## What form is returned to when the Mega Evolution ends.
## `0` returns the Pokemon to the form it was in when it Mega Evolved
@export var unmega_form: int = 0

## Which lead-in line from [BattleGimmicks.MegaEvolution] announces the change with.
## See [constant MEGA_MESSAGE_WISH]
@export var mega_message: int = 0

@export_group("Sprite Metrics")
## Pixel offset applied to the backsprite in battle
@export var back_sprite_offset: Vector2i = Vector2i.ZERO

## Pixel offset applied to the front sprite in the battle
@export var front_sprite_offset: Vector2i = Vector2i.ZERO

## Height in pixels that the front sprite floats above its base for fliers/floaters
@export var front_sprite_altitude: int = 0

@export var shadow_x: int = 0
@export var shadow_size: int = 2


func get_base_stat(stat: StringName) -> int:
	match stat:
		&"HP": return base_hp
		&"ATTACK": return base_attack
		&"DEFENSE": return base_defense
		&"SPECIAL_ATTACK": return base_special_attack
		&"SPECIAL_DEFENSE": return base_special_defense
		&"SPEED": return base_speed
	return 0
	
func get_ev_yield(stat: StringName) -> int:
	match stat:
		&"HP": return ev_hp
		&"ATTACK": return ev_attack
		&"DEFENSE": return ev_defense
		&"SPECIAL_ATTACK": return ev_special_attack
		&"SPECIAL_DEFENSE": return ev_special_defense
		&"SPEED": return ev_speed
	return 0
	
func get_base_stat_total() -> int:
	return base_hp + base_attack + base_defense + base_special_attack + base_special_defense + base_speed
	
func has_type(type_id: StringName) -> bool:
	return types.has(type_id)
	
func is_single_typed() -> bool:
	return types.size() <= 1
	
## In SOURCE LANGUAGE returns the full display name, including form names where they exist.
func get_full_name() -> String:
	if form_name.is_empty():
		return display_name
	return form_name
	
## The full, TRANSLATED, name including form name where one exists.
func get_translated_full_name() -> String:
	if form_name.is_empty():
		return get_translated_name()
	return translate_field(form_name)
	
## Translates the Pokedex Category, such as 'Seed' for 'Seed Pokemon'
func get_translated_category() -> String:
	return translate_field(category)
	
## The Pokedex entry translated in the player's language.
func get_translated_pokedex_entry() -> String:
	return translate_field(pokedex_entry)
	
## Evolution branches this species can actually take.
## Excludes pre-evolution bookkeeping entries.
func get_evolutions() -> Array[SpeciesEvolution]:
	var result: Array[SpeciesEvolution] = []
	for evo: SpeciesEvolution in evolutions:
		if not evo.is_prevolution:
			result.append(evo)
	return result
	
## The lowest level this Pokemon species can exist at.
##
## A base form can be level 1.
## Any further form must be at least one level above the lowest its pre-evolution can be.
## And a species reached by standard level evolution cannot be a level lower than its evolution level.
## A pre-evolution that only hatches from an Egg held with an incense breaks the chain at 1 --
## because the incense is what makes it exsit rather than level.
##
## This exists for checks that fire on any level up and do not say anything about level
## [param depth] is a recursion guard and answers 1 in case of cycle.
func minimum_level(depth: int = 0) -> int:
	if depth >= MAXIMUM_FAMILY_DEPTH:
		return 1
	var prevolution: SpeciesEvolution = _prevolution_entry()
	if prevolution == null:
		return 1
	var before: SpeciesData = Database.species(prevolution.species)
	if before == null:
		return 1
	if not before.incense.is_empty():
		return 1
	var lowest: int = before.minimum_level(depth + 1)
	var method: EvolutionMethodData = Database.evolution_method(prevolution.method)
	if method == null or not method.on_level_up:
		return lowest
	return lowest + 1 if method.any_level_up else maxi(prevolution.prameter_as_int(), lowest)
	
## The entry which names the species this one came from, otherwise `null`
func _prevolution_entry() -> SpeciesEvolution:
	for evo: SpeciesEvolution in evolutions:
		if evo.is_prevolution:
			return evo
	return null
	
## The species from which this one evolved from.
## Returns an empty [StringName] when it is a base form.
func get_prevolution() -> StringName:
	for evo: SpeciesEvolution in evolutions:
		if evo.is_prevolution:
			return evo.species
	return &""
	
func is_legendary() -> bool:
	return has_flag(&"Legendary") or has_flag(&"Mythical") or has_flag(&"UltraBeast")
	
func get_sprite_key() -> String:
	if form == 0:
		return String(species)
	return "%s_%d" % [species, form]
