@tool
class_name TrainerCardFace extends Control
## One side of the Trainer Card. A face is an ordinary scene: put what you want in it, drop
## [TrainerCardField], [TrainerCardBadges], [TrainerCardPortrait] and [TrainerCardArt] where they belong.
## When the card opens it walks its children and fills in every one, so nothing needs wiring up or fixed positions.

## Shown as the page's name. 
## Empty means name it by position.
@export var title: String = ""

## Switch that must be ON before this face appears. 
## 0 always offers it.
@export var required_switch: int = 0


func is_available() -> bool:
	if required_switch <= 0:
		return true
	return GameState != null and GameState.get_switch(required_switch)

func bind():
	_bind_below(self)

## Walk under node, filling in anything that knows itself. 
## Found by method not type so custom nodes can join with bind_trainer_card declared.
static func _bind_below(node: Node):
	for child: Node in node.get_children():
		if child.has_method("bind_trainer_card"):
			child.call("bind_trainer_card")
		_bind_below(child)
