@tool
class_name CharacterShadow
extends Node2D
## The shadow patch beneat a character's feet
##
## These rules declare behaviour
## on water -- no -- a surfing player casts a reflection
## in deep grass -- no -- we can't see their feet to begin with
## indoors -- yes, but fainter -- for a softer lit look

## Fraction of the character's width the shadow is
const WIDTH_FRACTION: float = 0.42

## The shadow's height as a fraction of its OWN width
const FLATNESS: float = 0.38

## Darkness of the shadow outdoors
const OUTDOOR_ALPHA: float = 0.28
## Darkness of the shadow indoors
const INDOOR_ALPHA: float = 0.16

## How far the shadow is offset from the bottom bounds of the sprite
const FOOT_OFFSET: float = 2.0

## Setgments the ellipse is drawn out of
## It's small enough that it really never needs more than this
const SEGMENTS: int = 16

## Colour before any alpha is applied
const SHADOW_COLOUR: Color = Color(0.05, 0.05, 0.1)


func _ready() -> void:
	# uses z-index so it remains on the same y-sort slot as the player
	z_index = -1
	if not Engine.is_editor_hint():
		set_process(false)
		
func _draw() -> void:
	var owner_character: GridCharacter = get_parent() as GridCharacter
	if owner_character == null:
		return
	var alpha: float = _alpha_for(owner_character)
	if alpha <= 0.0:
		return
	var frame: Vector2i = owner_character.frame_size()
	var width: float = float(frame.x) * WIDTH_FRACTION
	var height: float = width * FLATNESS
	var centre: Vector2 = Vector2(
		float(MapGrid.TILE_SIZE) * 0.5, float(MapGrid.TILE_SIZE) - FOOT_OFFSET)
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(SEGMENTS):
		var angle: float = TAU * float(index) / float(SEGMENTS)
		points.append(centre + Vector2(cos(angle) * width * 0.5, sin(angle) * height * 0.5))
	draw_colored_polygon(points, Color(SHADOW_COLOUR, alpha))
	
func _alpha_for(character: GridCharacter) -> float:
	if character.map == null or not character.visible:
		return 0.0
	var terrain: TerrainTagData = character.map.terrain_at_world(character.world_cell())
	if terrain != null and (terrain.shows_reflections or terrain.can_surf):
		return 0.0
	if character.bush_depth >= MapGrid.TILE_SIZE:
		return 0.0
	return OUTDOOR_ALPHA if _is_outdoors(character) else INDOOR_ALPHA
	
func _is_outdoors(character: GridCharacter) -> bool:
	if character.home_map == null:
		return true
	var meta: MapMetadataData = Database.map_metadata(character.home_map.map_id)
	return meta == null or meta.outdoor_map
	
func refresh() -> void:
	queue_redraw()
