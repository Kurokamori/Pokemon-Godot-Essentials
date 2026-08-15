class_name PokemonIcon
extends SpriteSheetIcon
## A Pokemon party/storage icon, drawn by SpriteSheetIcon's methods, and animates when hovered/focused

## Shows the [param source]'s icon, remaining on the first frame.
## Passing through `null` clears the icon
func set_pokemon(source: Pokemon) -> void:
	set_sheet(source.icon() if source != null else null)
