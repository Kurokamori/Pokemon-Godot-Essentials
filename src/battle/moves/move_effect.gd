class_name MoveEffect
extends RefCounted

## Behaviour for a move function code.

## Function code this effect was registered under.
var code: StringName = &"None"

## Message shown instead of "But it failed!" for the next failed move.
var failure_message: String = ""

@export_group("Stat Changes")

## Stat changes applied to the user, as `{stat: stages}`.
@export var user_stat_changes: Dictionary = {}

## Stat changes applied to each target, as `{stat: stages}`.
@export var target_stat_changes: Dictionary = {}

## Stat changes applied to the user's allies.
@export var ally_stat_changes: Dictionary = {}

## Set `true` when the move fails if none of its stat changes can apply.
@export var stat_change_is_main_effect: bool = false

@export_group("Status")

## Non-volatile status inflicted on the target.
@export var status_to_inflict: StringName = &""

## `true` for the badly-poisoned variant.
@export var status_is_severe: bool = false
@export var causes_flinch: bool = false
@export var causes_confusion: bool = false
@export var causes_attraction: bool = false

@export_group("Multi-hit")
@export var minimum_hits: int = 1
@export var maximum_hits: int = 1

@export_group("Damage Sharing")

## Fraction of damage dealt taken as recoil, e.g.
@export var recoil_fraction: float = 0.0

## Fraction of damage dealt restored to the user.
@export var drain_fraction: float = 0.0

## Fraction of the user's maximum HP restored.
@export var heal_fraction: float = 0.0

## Set `true` when using this move puts HP back on the user or on an ally.
@export var restores_hp: bool = false

## Fraction of the user's maximum HP lost as a cost.
@export var hp_cost_fraction: float = 0.0

## `true` when using the move makes the user faint.
@export var user_faints: bool = false

@export_group("Field")

## Weather this move starts.
@export var weather_to_start: StringName = &""

## Terrain this move starts.
@export var terrain_to_start: StringName = &""

## Entry hazard added to the opposing side.
@export var hazard_to_add: StringName = &""

## Maximum layers the hazard can stack to.
@export var hazard_max_layers: int = 1

## Side effect started on the user's side, e.g.
@export var side_effect_to_start: StringName = &""
@export var side_effect_turns: int = 5

@export_group("Structure")
## `true` for moves that charge for a turn before striking.
@export var is_two_turn: bool = false

## Message shown on the charging turn.
@export var charge_message: String = ""

## Semi-invulnerable state entered while charging, e.g.
@export var invulnerable_state: StringName = &""

## Set `true` for moves that make the user rest the following turn.
@export var recharges_after: bool = false

## Set `true` for protection moves.
@export var is_protect_move: bool = false

## Set `true` when the user switches out after a successful hit.
@export var switches_out_user: bool = false

## Set `true` when the target is forced out.
@export var switches_out_target: bool = false

## Set `true` for one-hit knockout moves.
@export var is_ohko: bool = false

## Set `true` when the move always lands a critical hit.
@export var always_crits_flag: bool = false

## Set `true` when the move can never miss.
@export var never_misses_flag: bool = false

## Set `true` when the move ignores the target's defensive stat stages.
@export var ignores_defensive_stages_flag: bool = false

@export_group("Fixed Damage")

## Fixed damage dealt, or `-1` when the normal formula applies.
@export var fixed_damage_amount: int = -1

## Set `true` when the move deals damage equal to the user's level.
@export var fixed_damage_is_user_level: bool = false

## Set `true` when the move halves the target's current HP.
@export var fixed_damage_is_half_target_hp: bool = false

# === Damage Hooks ==

## The type the move counts as this time it is used.
func effective_type(_battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> StringName:
	return move.type

## The base power for this use, letting variable-power moves compute it.
func base_power(_battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> int:
	return move.power

## Base power [BattleAI] should use to score this move.
func expected_base_power(battle: Battle, user: Battler, target: Battler, move: MoveData) -> int:
	return base_power(battle, user, target, move)

## How many times [BattleAI] should reckon the move hits.
func expected_hit_count(user: Battler) -> int:
	if maximum_hits <= minimum_hits:
		return minimum_hits
	if user != null and user.has_ability(&"SKILLLINK"):
		return maximum_hits
	if minimum_hits == 2 and maximum_hits == 5:
		return 3
	return minimum_hits

## Fixed damage, or `-1` to use the normal formula.
func fixed_damage(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> int:
	if fixed_damage_is_user_level:
		return user.level()
	if fixed_damage_is_half_target_hp:
		return maxi(target.hp() / 2, 1)
	return fixed_damage_amount

## Accuracy for this use.
func accuracy(_battle: Battle, _user: Battler, _target: Battler, move: MoveData) -> int:
	return move.accuracy

func never_misses(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> bool:
	if never_misses_flag:
		return true
	return false

func always_critical() -> bool:
	return always_crits_flag

func ignores_defensive_stages() -> bool:
	return ignores_defensive_stages_flag

## Swaps which stat is used to attack, e.g.
func attacking_stat(_move: MoveData, default_stat: StringName) -> StringName:
	return default_stat

## Swaps which stat defends, e.g.
func defending_stat(_move: MoveData, default_stat: StringName) -> StringName:
	return default_stat

## Which battler's stats are used to attack.
func stat_source(user: Battler, _target: Battler) -> Battler:
	return user

## A final multiplier applied after every other damage modifier.
func final_damage_multiplier(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> float:
	return 1.0

## How many times the move hits this use.
func hit_count(_battle: Battle, user: Battler, _target: Battler) -> int:
	if maximum_hits <= minimum_hits:
		return minimum_hits
	if user.has_ability(&"SKILLLINK"):
		return maximum_hits
	# Two to five hits are weighted towards two and three.
	if minimum_hits == 2 and maximum_hits == 5:
		var roll: int = RNG.below(100)
		if roll < 35:
			return 2
		if roll < 70:
			return 3
		if roll < 85:
			return 4
		return 5
	return RNG.range_int(minimum_hits, maximum_hits)

# === Control Hooks ==

## Runs before targets are chosen.
func can_be_used(_battle: Battle, _user: Battler, _move: MoveData) -> bool:
	return true

## Runs per target before the hit.
func succeeds_against(_battle: Battle, user: Battler, target: Battler, _move: MoveData) -> bool:
	if not stat_change_is_main_effect or target == null:
		return true
	if not user_stat_changes.is_empty() and _any_change_possible(user, user_stat_changes, user):
		return true
	if not target_stat_changes.is_empty() and _any_change_possible(target, target_stat_changes, user):
		return true
	if not ally_stat_changes.is_empty():
		return true
	return user_stat_changes.is_empty() and target_stat_changes.is_empty()

## Whether any of [param changes] would actually move a stage on [param subject].
func _any_change_possible(subject: Battler, changes: Dictionary, source: Battler) -> bool:
	for stat: StringName in changes:
		var stages: int = int(changes[stat])
		if stages > 0 and subject.can_raise_stat(stat):
			return true
		if stages < 0 and subject.can_lower_stat(stat, source):
			return true
	return false

## Returns `false` when failure cannot be checked safely while choosing an action.
func failure_is_known_when_choosing() -> bool:
	return true

## Runs once when the move starts, before any damage.
func on_start(_battle: Battle, _user: Battler, _targets: Array[Battler], _move: MoveData) -> void:
	pass

## Runs after damage against each target that was hit.
func on_hit(battle: Battle, user: Battler, target: Battler, move: MoveData, damage: int) -> void:
	_apply_status(battle, user, target, move)
	_apply_stat_changes(battle, user, target)
	_apply_drain(battle, user, damage, target)
	_apply_recoil(battle, user, damage)

## Runs once per target after all hits resolve, even if none connect.
func on_after_all_hits(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData, _damage: int) -> void:
	pass

## A second type the move is worked out against, on top of its own.
func extra_effectiveness_type() -> StringName:
	return &""

## Runs when the move misses, is avoided or does nothing to [param target].
func on_miss(_battle: Battle, _user: Battler, _target: Battler, _move: MoveData) -> void:
	pass

## Runs once after every target has been dealt with, even when the move missed.
func on_end(battle: Battle, user: Battler, _targets: Array[Battler], _move: MoveData) -> void:
	_apply_field_effects(battle, user)
	_apply_healing(battle, user)

# === Round Hooks ==

## A line shown at the start of the round, before anyone acts.
func round_start_message(_battle: Battle, _user: Battler, _move: MoveData) -> String:
	return ""

## Priority added on top of the move's own, for Grassy Glide.
func priority_bonus(_battle: Battle, _user: Battler, _move: MoveData) -> int:
	return 0

## The line announcing the move, already formatted.
func use_message(_battle: Battle, user: Battler, move: MoveData) -> String:
	return "%s used %s!" % [user.battle_name(), move.display_name]

## Replaces the targets the battle resolved.
func override_targets(_battle: Battle, _user: Battler, targets: Array[Battler], _move: MoveData) -> Array[Battler]:
	return targets

## Returns `true` for the moves a sleeping battler can still use
func usable_while_asleep() -> bool:
	return false

# === AI ==

## Returns this move's [BattleAI] score for the round.
func ai_score(
	_battle: Battle, _user: Battler, _target: Battler, _move: MoveData, base: int
) -> int:
	return base

## Returns `false` when this particular use deals no damage even though the move is a damaging one.
func is_damaging_this_use(_battle: Battle, _user: Battler, _move: MoveData) -> bool:
	return true

## For status moves, the whole effect.
func apply_status_move(battle: Battle, user: Battler, target: Battler, move: MoveData) -> bool:
	var did_something: bool = false
	if _apply_status(battle, user, target, move):
		did_something = true
	if _apply_stat_changes(battle, user, target):
		did_something = true
	if _apply_field_effects(battle, user):
		did_something = true
	if _apply_healing(battle, user):
		did_something = true
	return did_something

# === Shared Helpers ==

func _apply_status(battle: Battle, user: Battler, target: Battler, move: MoveData) -> bool:
	var applied: bool = false
	var chance: int = move.effect_chance
	var rolls_effect: bool = chance <= 0 or RNG.range_int(1, 100) <= _boosted_chance(user, chance)
	if not rolls_effect:
		return false
	if not status_to_inflict.is_empty():
		var turns: int = 1 if status_is_severe else 0
		if target.inflict_status(status_to_inflict, turns, user):
			battle.announce_status(target, status_to_inflict)
			applied = true
	if causes_flinch and not target.has_acted:
		target.set_effect(BattleEffects.FLINCH, 1)
		applied = true
	if causes_confusion and not target.has_effect(BattleEffects.CONFUSION):
		if not (battle.field.terrain == &"Misty" and not target.is_airborne()):
			target.set_effect(BattleEffects.CONFUSION, RNG.range_int(2, 5))
			battle.announce(Loc.line("{target} became confused!", {"target": target.battle_name()}))
			applied = true
	if causes_attraction and not target.has_effect(BattleEffects.ATTRACT):
		if _can_attract(user, target):
			target.set_effect(BattleEffects.ATTRACT, user.index + 1)
			battle.announce(Loc.line("{target} fell in love!", {"target": target.battle_name()}))
			applied = true
	return applied

## Serene Grace and the Pledge rainbow both double the chance of a secondary effect
func _boosted_chance(user: Battler, chance: int) -> int:
	if user.has_ability(&"SERENEGRACE"):
		return chance * 2
	if user.battle != null and user.battle.get_side(user.side_index()).has_effect(BattleEffects.RAINBOW):
		return chance * 2
	return chance

func _can_attract(user: Battler, target: Battler) -> bool:
	if user.pokemon.is_genderless() or target.pokemon.is_genderless():
		return false
	return user.pokemon.gender() != target.pokemon.gender()

func _apply_stat_changes(battle: Battle, user: Battler, target: Battler) -> bool:
	var applied: bool = false
	for stat: StringName in user_stat_changes:
		if battle.change_stat_stage(user, stat, int(user_stat_changes[stat]), user):
			applied = true
	for stat: StringName in target_stat_changes:
		if battle.change_stat_stage(target, stat, int(target_stat_changes[stat]), user):
			applied = true
	if not ally_stat_changes.is_empty():
		for ally: Battler in battle.allies_of(user):
			for stat: StringName in ally_stat_changes:
				if battle.change_stat_stage(ally, stat, int(ally_stat_changes[stat]), user):
					applied = true
	return applied

func _apply_drain(battle: Battle, user: Battler, damage: int, target: Battler = null) -> void:
	if drain_fraction <= 0.0 or damage <= 0:
		return
	if target != null and target.has_ability(&"LIQUIDOOZE") and not AbilityEffects.ignores_abilities(user):
		var backfire: int = maxi(int(float(damage) * drain_fraction), 1)
		user.take_damage(backfire)
		battle.announce(Loc.line("{pokemon} sucked up the liquid ooze!", {"pokemon": user.battle_name()}))
		return
	if user.has_effect(BattleEffects.HEAL_BLOCK):
		return
	var amount: int = maxi(int(float(damage) * drain_fraction), 1)
	if user.has_item(&"BIGROOT"):
		amount = int(float(amount) * 1.3)
	user.restore_hp(amount)
	battle.announce(Loc.line("{pokemon} had its energy drained!", {"pokemon": user.battle_name()}))

func _apply_recoil(battle: Battle, user: Battler, damage: int) -> void:
	if recoil_fraction <= 0.0 or damage <= 0:
		return
	if user.has_ability(&"ROCKHEAD") or user.has_ability(&"MAGICGUARD"):
		return
	var amount: int = maxi(int(float(damage) * recoil_fraction), 1)
	user.take_damage(amount)
	battle.announce(Loc.line("{pokemon} was hurt by recoil!", {"pokemon": user.battle_name()}))

func _apply_healing(battle: Battle, user: Battler) -> bool:
	var did_something: bool = false
	if heal_fraction > 0.0:
		if user.has_effect(BattleEffects.HEAL_BLOCK):
			return false
		if user.hp() >= user.total_hp():
			return false
		var amount: int = maxi(int(float(user.total_hp()) * heal_fraction), 1)
		user.restore_hp(amount)
		battle.announce(Loc.line("{pokemon} regained health!", {"pokemon": user.battle_name()}))
		did_something = true
	if hp_cost_fraction > 0.0:
		user.take_damage(maxi(int(float(user.total_hp()) * hp_cost_fraction), 1))
		did_something = true
	if user_faints:
		user.take_damage(user.hp())
		did_something = true
	return did_something

func _apply_field_effects(battle: Battle, user: Battler) -> bool:
	var did_something: bool = false
	if not weather_to_start.is_empty() and battle.field.weather != weather_to_start:
		var turns: int = 8 if ItemEffects.extends_weather(user, weather_to_start) else 5
		battle.field.set_weather(weather_to_start, turns)
		battle.announce_weather(weather_to_start)
		did_something = true
	if not terrain_to_start.is_empty() and battle.field.terrain != terrain_to_start:
		var turns: int = 8 if user.has_item(&"TERRAINEXTENDER") else 5
		battle.field.set_terrain(terrain_to_start, turns)
		battle.announce_terrain(terrain_to_start)
		did_something = true
	if not hazard_to_add.is_empty():
		var side: BattleSide = battle.get_side(user.opposing_side_index())
		if side.add_hazard_layer(hazard_to_add, hazard_max_layers):
			battle.announce(Loc.line("{hazard_to_add} were scattered on the opposing side!", {"hazard_to_add": hazard_to_add}))
			did_something = true
	if not side_effect_to_start.is_empty():
		var side: BattleSide = battle.get_side(user.side_index())
		if not side.has_effect(side_effect_to_start):
			var turns: int = side_effect_turns
			if user.has_item(&"LIGHTCLAY") and side_effect_to_start in [
					BattleEffects.REFLECT, BattleEffects.LIGHT_SCREEN, BattleEffects.AURORA_VEIL]:
				turns = 8
			side.set_effect(side_effect_to_start, turns)
			did_something = true
	return did_something
