@tool
class_name PokemonFollowerCharacter
extends FollowerCharacter
## A Pokemon walking behind the player

const WORRIED_HP_FRACTION: float = 0.25

## Happiness at or above which a follower has something fond to say
const FOND_HAPPINESS: int = 200

## Happiness at or below which it does not say something fond
const UNHAPPY_HAPPINESS: int = 50

## What this follower is. 
## Never `null` once [method bind] has been called.
var entry: FollowerPokemon = null


func _ready() -> void:
	super._ready()
	passable = true

## Dresses this follower as [param wanted] and takes its name from it
func bind(wanted: FollowerPokemon) -> void:
	entry = wanted
	if entry == null:
		return
	follower_name = entry.display_name()
	var sheet: String = entry.charset_name()
	if sheet != charset_name():
		set_charset(sheet)

## The party member this follower is 
## `null` for one that is not in the party
func pokemon() -> Pokemon:
	return entry.pokemon if entry != null else null

func casts_dynamic_shadow() -> bool:
	return true

# === Talking ===

## Answers the action button: the cry, then a line about how it is feeling
## Always returns true
func talk_to(interlocutor: GridCharacter) -> bool:
	if interlocutor != null:
		turn(GridCharacter.direction_towards(world_cell(), interlocutor.world_cell()))
	cry()
	await Field.say(reaction_line())
	return true

## Plays this follower's cry
func cry() -> void:
	if entry == null or entry.egg or entry.species.is_empty():
		return
	AudioManager.play_cry(entry.species, entry.form)

## What this follower says when it is spoken to.
func reaction_line() -> String:
	var called: String = entry.display_name() if entry != null else ""
	var pkmn: Pokemon = pokemon()
	if pkmn == null:
		return Loc.line("{pokemon} is looking around happily.", {"pokemon": called})
	if pkmn.is_egg():
		return Loc.line("{pokemon} is warm to the touch.", {"pokemon": called})
	var status: String = _status_line(pkmn, called)
	if not status.is_empty():
		return status
	if pkmn.hp_fraction() <= WORRIED_HP_FRACTION:
		return Loc.line("{pokemon} is worn out and wants to rest.", {"pokemon": called})
	if pkmn.happiness >= FOND_HAPPINESS:
		return Loc.line("{pokemon} looks delighted to be walking with you!", {"pokemon": called})
	if pkmn.happiness <= UNHAPPY_HAPPINESS:
		return Loc.line("{pokemon} does not seem to be enjoying itself.", {"pokemon": called})
	if pkmn.has_pokerus() and not pkmn.is_pokerus_cured():
		return Loc.line("{pokemon} has little spots all over it.", {"pokemon": called})
	if not pkmn.held_item.is_empty():
		var item: ItemData = Database.item(pkmn.held_item)
		if item != null:
			return Loc.line(
				"{pokemon} is holding on tightly to the {item}.",
				{"pokemon": called, "item": item.display_name})
	return Loc.line("{pokemon} is looking around happily.", {"pokemon": called})

## Status messages or an empty string if the Pokemon has no status/unknown status
func _status_line(pkmn: Pokemon, called: String) -> String:
	match pkmn.status:
		&"SLEEP":
			return Loc.line("{pokemon} is fast asleep.", {"pokemon": called})
		&"POISON":
			return Loc.line("{pokemon} looks unwell from the poison.", {"pokemon": called})
		&"BURN":
			return Loc.line("{pokemon} is nursing its burn.", {"pokemon": called})
		&"PARALYSIS":
			return Loc.line("{pokemon} keeps stiffening up.", {"pokemon": called})
		&"FROZEN":
			return Loc.line("{pokemon} is shivering with cold.", {"pokemon": called})
	return ""
