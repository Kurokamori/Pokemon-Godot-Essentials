@tool
class_name EvolutionMethodData
extends GameDataResource

## Declares a way that a pokemon species/line can evolve.
##
## The conditions are actually implemented later at [EvolutionMethods] and looked up by [member GameDataResource.id].
## This record only says what kind of parameter the method takes and what triggers fire it, so tools can validate data without knowing the rules.

enum ParameterType {
	NONE = 0,
	INTEGER = 1,
	ITEM = 2,
	MOVE = 3,
	SPECIES = 4,
	TYPE = 5,
	TEXT = 6,
}

@export var parameter_type: ParameterType = ParameterType.NONE

@export_group("Triggers")
## Checked after gaining a level, regardless of the parameter.
@export var any_level_up: bool = false

## Checked after gaining a level.
@export var on_level_up: bool = false

## Checked when an item is used on the Pokemon.
@export var on_use_item: bool = false

## Checked when the Pokemon is traded.
@export var on_trade: bool = false

## Checked after a battle ends.
@export var after_battle: bool = false

## Checked when an event explicitly asks the Pokemon to evolve.
@export var on_event: bool = false


## `true` when this method needs no parameter value.
func takes_no_parameter() -> bool:
	return parameter_type == ParameterType.NONE
	
## `true` when [param trigger]
## one of [EvolutionMethods] `TRIGGER_` names is the one this method answers to.
## [EvolutionMethods] builds its per-trigger lists from this, so a new method declares when it fires here and nowhere else.
func fires_on(trigger: StringName) -> bool:
	match trigger:
		EvolutionMethods.TRIGGER_LEVEL_UP: return on_level_up
		EvolutionMethods.TRIGGER_USE_ITEM: return on_use_item
		EvolutionMethods.TRIGGER_TRADE: return on_trade
		EvolutionMethods.TRIGGER_AFTER_BATTLE: return after_battle
		EvolutionMethods.TRIGGER_EVENT: return on_event
	return false
