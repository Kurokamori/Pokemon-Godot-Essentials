class_name ZPowerBonuses

## What a status move gains from being used with a Z-crystal.

## What a bonus does.
enum Kind {

	## Raise the stats named in the bonus.
	STATS = 0,

	## Put back every stage that has been knocked off the user.
	RESET_LOWERED = 1,

	## Restore the user to full health.
	HEAL = 2,
}

## Every stat a "raise everything" bonus raises.
const MAIN_STATS: Array[StringName] = [
	&"ATTACK", &"DEFENSE", &"SPECIAL_ATTACK", &"SPECIAL_DEFENSE", &"SPEED",
]

## Moves whose Z-Power bonus is not derivable from what the move does, by move id.
const TABLE: Dictionary = {
	&"SPLASH": {"stats": {&"ATTACK": 3}},
	&"CELEBRATE": {"stats": {}, "all": 1},
	&"HAPPYHOUR": {"stats": {}, "all": 1},
	&"HOLDHANDS": {"stats": {}, "all": 1},
	&"CONVERSION": {"stats": {}, "all": 1},
}

## Applies [param record]'s Z-Power bonus to [param battler].
static func apply(battle: Battle, battler: Battler, record: MoveData) -> bool:
	if battle == null or battler == null or record == null:
		return false
	var bonus: Dictionary = bonus_for(battler, record)
	match int(bonus.get("kind", Kind.STATS)):
		Kind.RESET_LOWERED:
			return _reset_lowered(battler)
		Kind.HEAL:
			return _heal(battle, battler)
	var changed: bool = false
	var stats: Dictionary = bonus.get("stats", {}) as Dictionary
	for stat: StringName in stats:
		if battle.change_stat_stage(battler, stat, int(stats[stat]), battler):
			changed = true
	return changed

## The bonus [param record] carries for [param battler], as `{kind, stats}`.
static func bonus_for(battler: Battler, record: MoveData) -> Dictionary:
	if TABLE.has(record.id):
		return _from_table(TABLE[record.id] as Dictionary)
	var effect: MoveEffect = MoveEffects.get_effect(record.function_code)
	if effect != null:
		var raised: Dictionary = _raised_stats(effect)
		if not raised.is_empty():
			return {"kind": Kind.STATS, "stats": raised}
		if effect.heal_fraction > 0.0:
			return {"kind": Kind.RESET_LOWERED, "stats": {}}
	return {"kind": Kind.STATS, "stats": {leaning_stat(battler): 1}}

## One more stage of everything the move already raises on its user.
static func _raised_stats(effect: MoveEffect) -> Dictionary:
	var raised: Dictionary = {}
	for stat: StringName in effect.user_stat_changes:
		if int(effect.user_stat_changes[stat]) > 0:
			raised[stat] = 1
	return raised

## Unpacks a table entry, expanding its `all` shorthand.
static func _from_table(entry: Dictionary) -> Dictionary:
	var stats: Dictionary = (entry.get("stats", {}) as Dictionary).duplicate()
	var everything: int = int(entry.get("all", 0))
	if everything != 0:
		for stat: StringName in MAIN_STATS:
			stats[stat] = everything
	return {"kind": int(entry.get("kind", Kind.STATS)), "stats": stats}

## Whichever attacking stat [param battler] is built around.
static func leaning_stat(battler: Battler) -> StringName:
	if battler.base_stat(&"ATTACK") >= battler.base_stat(&"SPECIAL_ATTACK"):
		return &"ATTACK"
	return &"SPECIAL_ATTACK"

## Puts back every stage that has been knocked off.
static func _reset_lowered(battler: Battler) -> bool:
	var changed: bool = false
	for stat: StringName in Battler.STAT_STAGE_IDS:
		var stage: int = battler.get_stat_stage(stat)
		if stage >= 0:
			continue
		battler.change_stat_stage(stat, -stage)
		changed = true
	return changed

static func _heal(battle: Battle, battler: Battler) -> bool:
	var missing: int = battler.total_hp() - battler.hp()
	if missing <= 0:
		return false
	battler.restore_hp(missing)
	battle.presenter.refresh_battler(battler)
	return true
