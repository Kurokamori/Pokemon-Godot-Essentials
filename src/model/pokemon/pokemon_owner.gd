@tool
class_name PokemonOwner
extends Resource

## The original trainer record on a given pokemon.
##
## The ID (32-bit - [member id] ) is split into the visible public id and a hidden id.
## Both halves fee the shininess check and obedience check for traded Pokemon. 

enum Gender {
	MALE = 0,
	FEMALE = 1,
	UNKNOWN = 2,
}

@export var id: int = 0
@export var name: String = ""
@export var gender : Gender = Gender.MALE

## Language code -- marks foreign Pokemon
@export var language: int = 0


static func create(owner_id: int, owner_name: String, owner_gender: Gender, owner_language: int = 0) -> PokemonOwner:
	var owner: PokemonOwner = PokemonOwner.new()
	owner.id = owner_id
	owner.name = owner_name
	owner.gender = owner_gender
	owner.language = owner_language
	return owner
	
## An owner record that means there is no original trainer.
## used for eggs and Pokemon generated outside of the trainer context.
static func create_unowned() -> PokemonOwner:
	return PokemonOwner.new()
	

func public_id() -> int:
	return id & 0xFFFF
	
func secret_id() -> int:
	return (id >> 16) & 0xFFFF
	
func is_unowned() -> bool:
	return name.is_empty()
	

## Decides whether the player counts as traded.
## Returns `true` when [param other] is the same trainer.
func matches(other: PokemonOwner) -> bool:
	if other == null:
		return false
	return id == other.id and name == other.name
	
func duplicate_owner() -> PokemonOwner:
	return PokemonOwner.create(id, name, gender, language)
	
func to_dict() -> Dictionary:
	return {"id": id, "name": name, "gender": int(gender), "language": language}  

static func from_dict(source: Dictionary) -> PokemonOwner:
	var owner: PokemonOwner = PokemonOwner.new()
	owner.id = int(source.get("id", 0))
	owner.name = String(source.get("name", ""))
	owner.gender = int(source.get("gender", 0)) as Gender
	owner.language = int(source.get("language", 0))
	return owner
