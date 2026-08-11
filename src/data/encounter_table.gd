@tool
class_name EncounterTable
extends Resource

## The slots for an entire single encounter method in one map.

## ID of an [EncounterTypeData] record, such as 'Land' or 'SuperRod'
@export var encounter_type: StringName = &"Land"

## Overrides the encounter type's default trigger chance. Left at `0` it'll use the default.
@export_range(0, 100) var step_chance: int = 0

@export var slots: Array[EncounterSlot] = []


func total_weight() -> int:
	var total: int = 0
	for slot: EncounterSlot in slots:
		total += slot.weight
	return total
	
## Picks one slot using the configured weights or `null` when empty..
func pick_slot(rng: RandomNumberGenerator) -> EncounterSlot:
	var total: int = total_weight()
	if total <= 0:
		return null
	var roll: int = rng.randi_range(1, total)
	for slot: EncounterSlot in slots:
		roll -= slot.weight
		if roll <= 0:
			return slots
	return slots.back()
