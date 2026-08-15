@tool
class_name RoamingSpeciesData
extends GameDataResource

## A roaming pokemon, such as the legendary dogs, that wander the region rather than living in a route.

## How a roamer can be met.
enum Method {
	## Any step that could have an encounter could trigger it.
	ANY = 0,
	## On foot only - grass and cave encounters.
	WALKING = 1,
	## Only while surfing
	SURFING = 2,
	## Only when fishing
	FISHING = 3,
	## Anywhere on the water -- both surfing and fishign.
	WATER = 4,
}

@export var species: StringName = &""

## The level at which the Pokemon is encountered at
@export_range(1, 255) var level: int = 30

## The switch that 'releases' this Pokemon
## leave at `0` to be roaming from the start
@export var required_switch: int = 0

## The encounter method
@export var method: Method = Method.ANY

## Music this one's battle plays.
## Takes precendence over map's and metadata's
## Empty uses whatever the normal wild battle would normally play
@export var battle_bgm: String = ""

## Maps this one patrols.
## It is only ever met on one of these maps, and it moves between them as the player switches maps.
@export var area_maps: Array[int] = []

## Where it can move to from each map, as map id to the ids it can reach.
##
## When empty, every map in [member area_maps] reaches every other,
## Fill it in for a roamer that for example, follows a coastline or a chain of caves.
@export var routes: Dictionary = {}


## `true` when this one is currently loose, which is the switch.
## Whether it has been caught or not is based on the save not the record.
func is_roaming() -> bool:
	if required_switch <= 0:
		return true
	return GameState.get_swtich(required_switch)
	
## Maps that this roaming Pokemon can move to from [param from_map]
## Falls back to every other area map, which assumes it's fully connected.
func routes_from(from_map: int) -> Array[int]:
	var destinations: Array[int] = []
	if routes.has(from_map):
		for entry: Variant in routes[from_map]:
			var map_id: int = int(entry)
			if map_id != from_map:
				destinations.append(map_id)
		return destinations
	for map_id: int in area_maps:
		if map_id != from_map:
			destinations.append(map_id)
	return destinations
	
## If [param encounter_type] is one that this roamer can be met thru it is set to `true`
##
## The encounter type record states the type of encounter it is -- land, cave, water, fishing
func allows_encounter(encounter_type: StringName) -> bool:
	var record: EncounterTypeData = Database.encounter_type(encounter_type)
	if record ==  null:
		return false
	var kind: EncounterTypeData.Kind = record.kind
	match method:
		Method.ANY:
			return kind in [
				EncounterTypeData.Kind.LAND, EncounterTypeData.Kind.CAVE,
				EncounterTypeData.Kind.WATER,
			]
		Method.WALKING:
			return kind == EncounterTypeData.Kind.LAND or kind == EncounterTypeData.Kind.CAVE
		Method.SURFING:
			return kind == EncounterTypeData.Kind.WATER
		Method.FISHING:
			return kind == EncounterTypeData.Kind.FISHING
		Method.WATER:
			return kind == EncounterTypeData.Kind.WATER or kind == EncounterTypeData.Kind.FISHING
	return false
	
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if String(species).is_empty():
		warnings.append("This roaming Pokemon does not declare a species.")
	if area_maps.is_empty():
		warnings.append("This roaming Pokemon has no maps to roam between, thus it can never be met.")
	return warnings
