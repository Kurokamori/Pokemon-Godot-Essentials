@tool
class_name BerryPlantData
extends GameDataResource

## Growth behaviour of one planted berry.
## The record id is the berry item id.

## Real-time hours spent in each of the four growth stages.
@export_range(1, 48) var hours_per_stage: int = 3

## Soil Moisture lost per hour, as a percentage.
@export_range(0, 100) var drying_per_hour: int = 15

## Minimum number of berries harvested at zero watering.
@export_range(1,99) var min_yield: int = 2

## Maximum number of berries harvested when watered every stage.
@export_range(1, 99) var max_yield: int = 5


## Total real-time hours from planting to a fully grown plant.
func hours_to_full_growth() -> int:
	return hours_per_stage * 4
