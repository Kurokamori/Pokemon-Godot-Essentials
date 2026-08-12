@tool
class_name TargetData
extends GameDataResource

## Describes which targets a move can be targeted at.
##
## These flags say which battlers are in reach:
## [member targets_foe], [member targets_ally], and [member includes_user]
##
## [member long_range] says whether the ones that are out of reach across a tripple battle field still count.
##
## A move that hits everything sets [member targets_all]
## One that the player aims sets [member num_targets] to `1`

## Number of battlers that are hit.
## `0` means the user or the field itself.
@export var num_targets: int = 1

## `true` if the move is aimed at the opposing side.
@export var targets_foe: bool = false

## `true` if the move can reach the user's allies.
## Most single target damaging moves can -- allowing hitting the patner.
@export var targets_ally: bool = false

## `true` if a user is one of the battlers hit
## Examples : Explosion or Howl
@export var includes_user:bool = false

## `true` when a move hits every legal target instead of one chosen battler.
@export var targets_all: bool = false

## `true` if the move affects the opposing side as a whole
## used for entry hazards.
@export var affects_foe_side: bool = false

## `true` on the case that the move can reach battlers that are not adjacent to the user.
## Only a tripple battle has any battlers that are not adjacent
## This changes nothing in a single or double battle.
@export var long_range: bool = false


## returns `true` when the player picks a specific battler for this move.
func can_choose_target() -> bool:
	return num_targets == 1 and not targets_all
	
## returns `true` when the move only affects the user.
func targets_user() -> bool:
	return num_targets == 0 and not affects_foe_side
	
## returns `true` when the move reaches anyone other than the user
## declares whether checking adjacency is worthwhile.
func reaches_others() -> bool:
	return targets_foe or targets_ally
