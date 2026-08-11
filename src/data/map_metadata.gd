@tool
class_name MapMetadataData
extends GameDataResource

## Per-Map configurations.
## Every field is optional.
## Unset fields fall back to global defaults.
##
## The record id is the map number as a string such as &"5"

@export var map_id: int = 0

@export_group("Environment")
## `true` for maps that are outdoor, meaning they are effected by day cycle tinting and weather.
@export var outdoor_map: bool = false

## Whether or not to show the location banner upon entry.
@export var announce_location: bool = false

## Requires a light source (traditionally, flash) to see.
@export var dark_map: bool = false

## Prevents the camera from scrolling past the map edges.
@export var snap_edges: bool = false

## Reflections on this map do not ripple.
@export var still_reflections: bool = false

## Whether this map is / is part of / the Safari Zone.
@export var safari_map: bool = false


## Whether the layout of this map is generated on arrival, and discards what's painted on it.
##
## Set it to the id of a [DungeonsParameterData] record to always build that kind of floor,
## or set it to `true` which allows whichever floor [memeber GameState.dungeon_area] asks for,
## this allowsd for one map to serve for every floor of a dungeon. 
## Leave empty for ordinary maps.
@export var random_dungeon: StringName = &""

@export_group("Movement")
@export var can_bicycle: bool = false
@export var always_bicycle: bool = false

## Map entered when diving herer.
## `0` means that diving is not possible here.
@export var dive_map_id: int = 0

## `[map_id, x, y]`
## location that a player is sent to when using Teleport or a PokeCenter respawn.
## Empty when this map has no destination.
@export var teleport_destination: Array[int] = []


@export_group("Presentation")
## Id of a [WeatherData] record plus its intensity.
## For example : [&"Rain", 50]`
@export var weather: Array = []

## [region, x, y]
## postion on the town map.
## Empty to hide.
@export var town_map_postion: Array[int] = []

## `[width, height]`
## in town-map squares for maps that span several.
@export var town_map_size: Array[int] = []

## The battle background used for battles in this area.
@export var battle_background: String = ""

## Id of an [EnvironmentData] record which overrides the terrain-derrived value.
@export var battle_environment: StringName = &""


@export_group("Audio")
@export var wild_battle_bgm: String = ""
@export var trainer_battle_bgm: String = ""
@export var wild_victory_bgm: String = ""
@export var trainer_victory_bgm: String = ""
@export var wild_capture_me: String = ""
