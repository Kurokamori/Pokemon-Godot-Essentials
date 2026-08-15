@tool
class_name TrainerPokemon
extends Resource

## A given Pokemon on a trainer's team
## Unset fields are randomly rolled or set from the species

@export var species: StringName = &""
@export_range(1, 100) var level: int = 5
@export_range(0, 255) var form: int = 0

## Overrides the species name in battle for having a trainer with a nicknamed pokemon
@export var nickname: String = ""

## The Pokemon's moves, up to four.
## Empty means that it will use the last up to 4 it would know by level up
@export var moves: Array[StringName] = []

@export_group("Traits")
## Explicit ability id
## Overrides [member ability_index]
@export var ability: StringName = &""

## Index into the species' ability list, with `-1` to pick automatically
@export_range(-1, 5) var ability_index: int = -1

## Held item
@export var item: StringName = &""

## Pokemon gender, -1 rolls it based on the species probability
@export_range(-1, 1) var gender: int = -1

## The Pokemon's nature, empty rolls random
@export var nature: StringName = &""

## The Pokemon's happiness or `-1` for the species default
@export_range(-1, 255) var happiness: int = -1

## The pokeball the Pokemon is in
@export var poke_ball: StringName = &""

@export_group("Stats")
## The six individual values in their canonical order (HP/ATK/DEF/SPA/SPD/SPE)
## An empty array rolls randomly
## A single value applies that value to all the stats
@export var ivs: Array[int] = []

## The six effort values in their canonical order (HP/ATK/DEF/SPA/SPD/SPE)
## An empty array rolls randomly
## A single value applies that value to all the stats
@export var evs: Array[int] = []

@export_group("Flags")
@export var shiny: bool = false
@export var super_shiny: bool = false
@export var shadow: bool = false
