@tool
class_name MysteryGiftItem
extends Resource

## A single mystery gift item

@export var item: StringName = &""
@export_range(1, 999) var quantity: int = 1
