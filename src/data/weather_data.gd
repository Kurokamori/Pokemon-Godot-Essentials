@tool
class_name WeatherData
extends GameDataResource

## The overworld weather -- the particles and their movement

enum Category {
	NONE = 0,
	RAIN = 1,
	SNOW = 2,
	STORM = 3,
	SANDSTORM = 4,
	FOG = 5,
}

@export var category: Category = Category.NONE

## Weather legacy number for porting from RPG Maker
@export var legacy_number: int = 0

@export_group("Particle Motion")
## Pixels moved horizontally per second by each particle
@export var particle_delta_x: int = 0

## Pixels moved vertically per second by each particle
@export var particle_delta_y: int = 0

## Opacity/ Transparency lost per second which allows the particles to fade out
@export var particle_delta_opacity: int = 0

@export_group("Tile Motion")
## Pixels that the full-screen overlay scrolls horizontally per second
@export var tile_delta_x: int = 0

## Pixels that the full-screen overlay scrolls vertically per second
@export var tile_delta_y: int = 0


## File names under `assets/graphics/weather/` used for the particles and overlay
@export var graphics: Array[String] = []

## Screen tint applied at maximum intensity
@export var tint: Color = Color(1.0, 1.0, 1.0, 0.0)
