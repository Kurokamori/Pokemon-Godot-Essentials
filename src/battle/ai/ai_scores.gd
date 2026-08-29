class_name AIScores
extends RefCounted
## These are the scores that the AI uses to determine the viability of a move, it starts at the base and adds/subtracts as it goes.
## [constant FAIL] means the move would not work at all.
## [constant USELESS] is a move that would change nothing of value.
## It's own class so that it can be accessed by [MoveEffect] without depending on [BattleAI]

const FAIL: int = 20

const USELESS: int = 60

const BASE: int = 100
