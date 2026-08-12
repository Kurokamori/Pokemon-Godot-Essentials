@tool
class_name StatusData
extends GameDataResource

## A non-volatile status condition.
## Such as : Sleep or Poison.

## Battle animation that plays when this status is inflicted.
@export var animation: StringName = &""

## Index into the status icon strip
@export var icon_position: int = 0
