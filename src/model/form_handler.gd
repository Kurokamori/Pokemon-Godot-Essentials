class_name FormHandler
extends RefCounted

## The hooks for deciding what form a species is
##
## Each hook is optional.
## A hook returns a new form number, `-1` leaves the form alone.

## Choose a form on the Pokemon's creation
## Signature: `func(pokemon: Pokemon) -> int`
var on_creation: Callable = Callable()

## Re-evaluated whenever the form is read
## For state forms such as those controlled by a held_item.
## Signature: `func(pokemon: Pokemon) -> int`
var get_form: Callable = Callable()

## Applied on the beginning of battle / when the Pokemon enters battle
## Signature: `func(pokemon: Pokemon, wild: bool) -> int`
var on_entering_battle: Callable = Callable()

## Applied on the ending of a battle / leaving battle
## Signature: `func(pokemon: Pokemon, used_in_battle: bool, battle_ended: bool) -> int`
var on_leaving_battle: Callable = Callable()

## Runs after the form changes, for things like swapping a signature move
## Signature: `func(pokemon: Pokemon, new_form: int, old_form: int) -> void`
var on_set_form: Callable = Callable()

## Form to take on Primal Reversion
## Signature: `func(pokemon: Pokemon) -> int`
var get_primal_form: Callable = Callable()

## Form to take on Mega Evolution
## Signature: `func(pokemon: Pokemon) -> int`
var get_mega_form: Callable = Callable()
