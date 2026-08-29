class_name MoveEffectsGimmicks

## Move effects the battle gimmicks bring with them.

static func register_all() -> void:
	MoveEffects.register(&"MaxMove", MaxMoveEffect.new())

## The secondary each Max Move type brings.
const MAX_MOVE_EFFECTS: Dictionary = {
	&"FIRE": {"weather": &"Sun"},
	&"WATER": {"weather": &"Rain"},
	&"ROCK": {"weather": &"Sandstorm"},
	&"ICE": {"weather": &"Hail"},
	&"ELECTRIC": {"terrain": &"Electric"},
	&"GRASS": {"terrain": &"Grassy"},
	&"FAIRY": {"terrain": &"Misty"},
	&"PSYCHIC": {"terrain": &"Psychic"},
	&"FIGHTING": {"raise": &"ATTACK"},
	&"STEEL": {"raise": &"DEFENSE"},
	&"GHOST": {"raise": &"SPECIAL_ATTACK"},
	&"DARK": {"raise": &"SPECIAL_DEFENSE"},
	&"FLYING": {"raise": &"SPEED"},
	&"GROUND": {"lower": &"SPECIAL_DEFENSE"},
	&"POISON": {"lower": &"DEFENSE"},
	&"BUG": {"lower": &"SPECIAL_ATTACK"},
	&"DRAGON": {"lower": &"ATTACK"},
	&"NORMAL": {"lower": &"SPEED"},
}

## A Max Move: ordinary spread damage, plus the field or stat effect its type carries.
class MaxMoveEffect extends MoveEffect:

## Set once the secondary has fired this use, so a spread Max Move does not set the weather once per target.
	var _fired: bool = false

## Asked once per use, before the targets are worked out, which is where the once-a-use flag is cleared.
	func can_be_used(battle: Battle, user: Battler, move: MoveData) -> bool:
		_fired = false
		return super.can_be_used(battle, user, move)

	## Do not check this while the AI is choosing; it resets this use's flag.
	func failure_is_known_when_choosing() -> bool:
		return false

	func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
		super.on_hit(battle, user, target, move, damage)
		if _fired:
			return
		_fired = true
		var entry: Dictionary = MoveEffectsGimmicks.MAX_MOVE_EFFECTS.get(move.type, {})
		if entry.has("weather"):
			battle.field.set_weather(entry["weather"])
			battle.announce_weather(entry["weather"])
			return
		if entry.has("terrain"):
			battle.field.set_terrain(entry["terrain"])
			battle.announce_terrain(entry["terrain"])
			return
		if entry.has("raise"):
			for ally: Battler in battle.active_battlers_on_side(user.side_index()):
				battle.change_stat_stage(ally, entry["raise"], 1, user)
			return
		if entry.has("lower"):
			for foe: Battler in battle.active_battlers_on_side(user.opposing_side_index()):
				battle.change_stat_stage(foe, entry["lower"], -1, user)
