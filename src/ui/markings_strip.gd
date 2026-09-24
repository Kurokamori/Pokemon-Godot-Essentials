class_name MarkingsStrip
extends HBoxContainer
## The markings a Pokemon carries -- displayed in a row that is not the markings editor

## Side of each marking, in pixels.
@export var icon_size: int = 10:
	set(value):
		icon_size = value
		_resize_icons()

## Colour to draw the markings in
## Transparent takes the dark colour of the skin
@export var colour: Color = Color.TRANSPARENT:
	set(value):
		colour = value
		for icon: MarkingIcon in _icons:
			icon.colour = value

const MARKING_ICON_SCENE: PackedScene = preload("res://scenes/ui/marking_icon.tscn")

var _icons: Array[MarkingIcon] = []
var _mask: int = 0


func _ready() -> void:
	_build()
	show_mask(_mask)

## Shows the markings in [param mask].
func show_mask(mask: int) -> void:
	_mask = PokemonMarkings.sanitised(mask)
	if _icons.is_empty():
		return
	for index: int in range(_icons.size()):
		_icons[index].visible = PokemonMarkings.has(_mask, index as PokemonMarkings.Mark)
	visible = PokemonMarkings.any(_mask)

## Shows [param pkmn]'s markings if there is a pokemon
func show_pokemon(pkmn: Pokemon) -> void:
	show_mask(pkmn.markings if pkmn != null else 0)

## The six icons are built once and shown or hidden afterwards
func _build() -> void:
	for index: int in range(PokemonMarkings.COUNT):
		var icon: MarkingIcon = MARKING_ICON_SCENE.instantiate()
		icon.mark = index as PokemonMarkings.Mark
		icon.filled = true
		icon.colour = colour
		add_child(icon)
		_icons.append(icon)
	_resize_icons()

func _resize_icons() -> void:
	for icon: MarkingIcon in _icons:
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
