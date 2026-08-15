@tool
class_name PlayerMetadataData
extends GameDataResource

## One selectable player character.
## The record id is the character number.

@export var player_id: int = 1

## ID of the [TrainerTypeData] this character battles as/
@export var trainer_type: StringName = &""

@export_group("Presentation")
## Name shown when the player picks this character in the intro.
## Falls back to [member GameDataResouce.display_name] when empty.
@export var character_name: String = ""

## Gender this character starts as.
## Declares the `\b` and `\r` message colours and how the other characters address this player.
@export var gender: PokemonOwner.Gender = PokemonOwner.Gender.MALE

## Full body art shown at the intro.
## From `res://assets/graphics/pictures/`
## The trainer sprite is shown when this is empty.
@export var intro_picture: String = ""

## Names offered to the player when naming the player.
@export var suggested_names: Array[String] = []

@export_group("Overworld Charsets")
@export var walk_charset: String = ""
@export var run_charset: String = ""
@export var cycle_charset: String = ""
@export var surf_charset: String = ""
@export var dive_charset: String = ""
@export var fish_charset: String = ""
@export var surf_fish_charset: String = ""

## `[map_id, x, y, direction]`
## overwrites [member MetadataData.home]
@export var home: Array[int] = []

## Name shown for this character, prefers the presentation name.
func chooser_name() -> String:
	if not character_name.is_empty():
		return character_name
	return display_name if not display_name.is_empty() else String(id)

## Art for the character chooser.
## The dedicated intro picture when one is otherwise the character's trainer sprite.
func chooser_texture() -> Texture2D:
	if not intro_picture.is_empty():
		var picture: Texture2D = Assets.texture(AssetIndex.CATEGORY_PICTURES, intro_picture)
		if picture != null:
			return picture
	return Assets.trainer_sprite(trainer_type)
