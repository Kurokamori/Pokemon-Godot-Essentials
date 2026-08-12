@tool
class_name SpeciesEvolution
extends Resource

## One evolution branch of a species.
##
## The meaning of the [member parameter] depends on [member method]
## The expected type is declared by the matching [EvolutionMethodData]
## Storing it as text keeps ever method editable through one inspector field.

## Species that this branch evolves into //
## or comes from in the case that [member is_prevolution] is set.
@export var species: StringName = &""

## ID of an [EvolutionMethodData] record
## Example : &"Level" or &"Item"
@export var method: StringName = &"None"

## Method argument
## A level number, item ID, move ID, species ID, type ID, or freeform location flag
## Depends on method.
@export var parameter: String = ""

## On `true` it records a pre-evolution (a species this species evolved *from*)
## Ignored when checking for evolution.
@export var is_prevolution: bool = false


func parameter_as_int() -> int:
	return int(parameter) if parameter.is_valid_int() else 0
	
func parameter_as_id() -> StringName:
	return StringName(parameter)
