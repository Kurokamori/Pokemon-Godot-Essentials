class_name MoveCallRules

## Which moves the move-calling moves are allowed to produce.

## Moves that call another move.
const CALLERS: Array[StringName] = [
	&"UseLastMoveUsedByTarget", &"UseLastMoveUsed", &"UseMoveTargetIsAboutToUse",
	&"UseMoveDependingOnEnvironment", &"UseRandomUserMoveIfAsleep",
	&"UseRandomMoveFromUserParty", &"UseRandomMove",
]

## Moves that rewrite the user's moveset, which cannot survive being copied.
const MOVESET_CHANGERS: Array[StringName] = [
	&"ReplaceMoveThisBattleWithTargetLastMoveUsed",
	&"ReplaceMoveWithTargetLastMoveUsed",
	&"TransformUserIntoTarget",
]

## Moves that hit back for damage already taken, which have nothing to work with when they are called out of turn.
const COUNTERS: Array[StringName] = [
	&"CounterPhysicalDamage", &"CounterSpecialDamage", &"CounterDamagePlusHalf",
]

## Every protection move, including the side-wide ones.
const PROTECTIONS: Array[StringName] = [
	&"ProtectUser", &"ProtectUserSideFromPriorityMoves",
	&"ProtectUserSideFromMultiTargetDamagingMoves", &"UserEnduresFaintingThisTurn",
	&"ProtectUserSideFromDamagingMovesIfUserFirstTurn", &"ProtectUserSideFromStatusMoves",
	&"ProtectUserFromDamagingMovesKingsShield", &"ProtectUserFromDamagingMovesObstruct",
	&"ProtectUserFromTargetingMovesSpikyShield", &"ProtectUserBanefulBunker",
]

## Moves that redirect or steal another battler's move.
const REDIRECTORS: Array[StringName] = [
	&"BounceBackProblemCausingStatusMoves", &"StealAndUseBeneficialStatusMove",
	&"RedirectAllMovesToUser", &"RedirectAllMovesToTarget",
]

## Moves that set up something which triggers when the user faints.
const FAINT_TRAPS: Array[StringName] = [
	&"SetAttackerMovePPTo0IfUserFaints", &"AttackerFaintsIfUserFaints",
]

## Moves that pass a held item around.
const ITEM_MOVERS: Array[StringName] = [
	&"UserTakesTargetItem", &"UserTargetSwapItems", &"TargetTakesUserItem",
]

## Moves that start concentrating at the start of the round rather than when their turn comes, 
## so calling them mid-turn would skip the setup.
const FOCUSSING: Array[StringName] = [
	&"FailsIfUserDamagedThisTurn", &"UsedAfterUserTakesPhysicalDamage",
	&"BurnAttackerBeforeUserActs",
]

## Every two-turn move, which cannot charge and fire in one call.
const TWO_TURN: Array[StringName] = [
	&"TwoTurnAttack", &"TwoTurnAttackOneTurnInSun", &"TwoTurnAttackParalyzeTarget",
	&"TwoTurnAttackBurnTarget", &"TwoTurnAttackFlinchTarget",
	&"TwoTurnAttackChargeRaiseUserDefense1", &"TwoTurnAttackInvulnerableInSky",
	&"TwoTurnAttackInvulnerableUnderground", &"TwoTurnAttackInvulnerableUnderwater",
	&"TwoTurnAttackInvulnerableInSkyParalyzeTarget",
	&"TwoTurnAttackInvulnerableRemoveProtections",
	&"TwoTurnAttackInvulnerableInSkyTargetCannotAct",
	&"AllBattlersLoseHalfHPUserSkipsNextTurn", &"TwoTurnAttackRaiseUserSpAtkSpDefSpd2",
]

## Moves that drag the target out of battle.
const FORCED_SWITCHES: Array[StringName] = [
	&"SwitchOutTargetStatusMove", &"SwitchOutTargetDamagingMove",
]

## Event moves whose whole point is that they do nothing.
const DO_NOTHING: Array[StringName] = [
	&"DoesNothingFailsIfNoAlly", &"DoesNothingCongratulations",
]

## Codes that no caller ever produces.
const NEVER_CALLED: Array[StringName] = [&"Struggle", &"FailsIfUserNotConsumedBerry"]

## Combines the named groups into one lookup set.
static func build(groups: Array, extra: Array[StringName] = []) -> Dictionary:
	var blacklist: Dictionary = {}
	for group: Array in groups:
		for code: StringName in group:
			blacklist[code] = true
	for code: StringName in extra:
		blacklist[code] = true
	return blacklist

## Metronome's blacklist.
static func metronome() -> Dictionary:
	return build([NEVER_CALLED, CALLERS, MOVESET_CHANGERS, COUNTERS, PROTECTIONS,
			REDIRECTORS, FAINT_TRAPS, ITEM_MOVERS, FOCUSSING, DO_NOTHING],
			[&"FlinchTargetFailsIfUserNotAsleep", &"TargetActsNext", &"TargetActsLast",
			&"TargetUsesItsLastUsedMoveAgain", &"PowerUpAllyMove", &"RemoveProtections"])

## Copycat's blacklist, which also refuses the forced-switch moves from Generation 6 onwards.
static func copycat() -> Dictionary:
	var blacklist: Dictionary = build([NEVER_CALLED, CALLERS, MOVESET_CHANGERS, COUNTERS,
			PROTECTIONS, REDIRECTORS, FAINT_TRAPS, ITEM_MOVERS, FOCUSSING, DO_NOTHING],
			[&"PowerUpAllyMove", &"RemoveProtections"])
	if GameSettings.data.mechanics_generation >= 6:
		for code: StringName in FORCED_SWITCHES:
			blacklist[code] = true
	return blacklist

## Assist's blacklist, which from Generation 6 also refuses the two-turn moves.
static func assist() -> Dictionary:
	var blacklist: Dictionary = build([NEVER_CALLED, MOVESET_CHANGERS, COUNTERS, PROTECTIONS,
			REDIRECTORS, FAINT_TRAPS, ITEM_MOVERS, FOCUSSING, DO_NOTHING],
			[&"PowerUpAllyMove", &"RemoveProtections", &"SwitchOutTargetDamagingMove"])
	for code: StringName in CALLERS:
		blacklist[code] = true
	if GameSettings.data.mechanics_generation < 6:
		# Nature Power is allowed before Generation 6.
		blacklist.erase(&"UseMoveDependingOnEnvironment")
	else:
		for code: StringName in TWO_TURN:
			blacklist[code] = true
		blacklist[&"SwitchOutTargetStatusMove"] = true
	return blacklist

## Sleep Talk's blacklist.
static func sleep_talk() -> Dictionary:
	return build([NEVER_CALLED, CALLERS, TWO_TURN, FOCUSSING],
			[&"MultiTurnAttackPreventSleeping", &"MultiTurnAttackBideThenReturnDoubleDamage",
			&"ReplaceMoveThisBattleWithTargetLastMoveUsed",
			&"ReplaceMoveWithTargetLastMoveUsed"])

## Instruct's blacklist.
static func instruct() -> Dictionary:
	return build([NEVER_CALLED, CALLERS, MOVESET_CHANGERS, TWO_TURN, FOCUSSING],
			[&"MultiTurnAttackBideThenReturnDoubleDamage",
			&"ProtectUserFromDamagingMovesKingsShield",
			&"TargetUsesItsLastUsedMoveAgain", &"AttackAndSkipNextTurn"])

## Sketch's and Mimic's blacklists, which differ only in what Mimic adds.
static func sketch() -> Dictionary:
	return build([], [&"Struggle", &"ReplaceMoveWithTargetLastMoveUsed"])

static func mimic() -> Dictionary:
	return build([MOVESET_CHANGERS], [&"Struggle", &"UseRandomMove"])

## Me First's blacklist.
static func me_first() -> Dictionary:
	return build([COUNTERS, FOCUSSING], [&"UserTakesTargetItem", &"Struggle",
			&"FailsIfUserNotConsumedBerry"])
