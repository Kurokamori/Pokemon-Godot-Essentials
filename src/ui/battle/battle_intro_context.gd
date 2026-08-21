class_name BattleIntroContext
extends RefCounted
## What the battle intro animation is told about the battle

var location: int = BattleIntro.Location.OUTSIDE

var battle: Battle = null

var foes: Array[TrainerData] = []

func is_trainer_battle() -> bool:
	return not foes.is_empty()
	
func is_double_battle() -> bool:
	return battle != null and battle.battlers_per_side >= 2
	
## If there's specifcally one oposing trainer
func lone_foe() -> TrainerData:
	return foes[0] if foes.size() == 1 else null
