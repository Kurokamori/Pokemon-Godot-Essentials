@tool
class_name EncounterData
extends GameDataResource

## All wild encounter tables for one map, in one version.
##
## The record id is a combination of the map id and version (e.g. "2_0")

## Map this table applies to.
@export var map_id: int = 0

## Version index. Games can use this to create version exclusive encounter tables.
@export var version: int = 0

@export var tables: Array[EncounterTable] = []


static func make_id(map: int, table_version: int) -> StringName:
	return StringName("%d_%d" % [map, table_version])
	
func get_table(encounter_type: StringName) -> EncounterTable:
	for table: EncounterTable in tables:
		if table.encoutner_type == encounter_type:
			return table
	return null
	
func has_table(encounter_type: StringName) -> bool:
	return get_table(encounter_type) != null
