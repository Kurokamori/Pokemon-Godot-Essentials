@tool
class_name TownMapPoint
extends Resource

## One labelled square on a region map

## The category the region map records live int
## Named here instead of being stamped by [Database] because a point is a sub-resource of [TownMapData]
## and is never loaded on its on
const DATA_CATEGORY: StringName = &"town_maps"

@export var position: Vector2i = Vector2i.ZERO
@export var location_name: String = ""

## Secondary label such as a landmark in a town
@export var point_of_interest: String = ""

@export_group("Fly Destination")
## Map the player flies to at this point.
## `0` means it is not a fly destination.
@export var fly_map_id: int = 0

## Position on the fly map that the player lands.
@export var fly_position: Vector2i = Vector2i.ZERO

## Switch that is required to be ON before this point is accessbile
## `0` means it's always accessible.
##
## A wall map (display map) hides all points regardless
@export var visibility_switch: int = 0


## Whether this point should be labelled.
##
## [param wall_map] is a map the player is viewing rather than their owned Town Map
func is_visible(wall_map: bool) -> bool:
	if visibility_switch <= 0:
		return true
	if wall_map:
		return false
	return GameState.get_switch(visibility_switch)
	
## Whether or not this place CAN be flown to, regardless of whether the player can fly here.
func is_fly_destination() -> bool:
	return fly_map_id > 0
	
## The place name in the player's language
func get_translated_location_name() -> String:
	return Loc.data(DATA_CATEGORY, location_name)
	
## The landmark label in the player's game langauge
func get_translated_point_of_interest() -> String:
	return Loc.data(DATA_CATEGORY, point_of_interest)
