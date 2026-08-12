@tool
class_name RegionalDexData
extends GameDataResource

## The list of species and their order for one regional Pokedex.

## Region number this dex refers to.
@export var region: int = 0

## Dex order for the species.
## Index 0 is dex number 1.
@export var species_order: Array[StringName] = []


## 1-based dex number of the provided [param species_id] or `0` when absent.
func get_dex_number(species_id: StringName) -> int:
	var index: int = species_order.find(species_id)
	return index + 1
	
## Finds the species at the provided dex number (dex is 1 based)
func get_species_at(dex_number: int) -> StringName:
	var index: int = dex_number - 1
	if index < 0 or index >= species_order.size():
		return &""
	return species_order[index]
	
func size() -> int:
	return species_order.size()
