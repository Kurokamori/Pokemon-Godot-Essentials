@tool
class_name MetadataData
extends GameDataResource

## Global game settings that are not per-map.
## Exactly one record exists, with the id &"0"

@export var start_money: int = 3000

## Items already in the player's PC at the start of the game.
@export var start_item_storage: Array[StringName] = []

## `[map_id, x, y, direction]` which declares the player's room.
@export var home: Array[int] = []

## Name shown as the creator of the Pokemon storage system.
@export var storage_creator: String = "Bill"

@export_group("Default Audio")
@export var wild_battle_bgm: String = ""
@export var trainer_battle_bgm: String = ""
@export var wild_victory_bgm: String = ""
@export var trainer_victory_bgm: String = ""
@export var wild_capture_me: String = ""
@export var surf_bgm: String = ""
@export var bicycle_bgm: String = ""
