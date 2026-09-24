class_name FieldPoison
## Poison working on the party while the player walks about.

## Steps between one point of poison damage.
const STEPS_PER_POINT: int = 4

## The red wash the screen takes as the poison bites, and how long it lasts in RPG Maker's frames.
const FLASH_COLOUR: Color = Color(1.0, 0.0, 0.0, 0.5)
const FLASH_FRAMES: int = 8

## The ability that keeps a Pokemon from being poisoned at all, and so from being hurt by poison it is already carrying.
const IMMUNITY_ABILITY: StringName = &"IMMUNITY"

## `true` when the step just taken is one poison acts on.
static func is_due() -> bool:
	if not GameSettings.data.poison_damage_in_field:
		return false
	if GameState.player == null:
		return false
	return GameState.player.steps_taken % STEPS_PER_POINT == 0

## Works the poison on every poisoned party member and says what it did.
static func take_step() -> bool:
	if not is_due():
		return false
	var flashed: bool = false
	for pkmn: Pokemon in GameState.party.able_members():
		if not _is_hurt_by_poison(pkmn):
			continue
		if not flashed:
			AudioManager.play_se("Poison step")
			FieldEffects.flash(FLASH_COLOUR, FLASH_FRAMES)
			flashed = true
		await _hurt(pkmn)
	return flashed and GameState.party.able_count() == 0

static func _is_hurt_by_poison(pkmn: Pokemon) -> bool:
	if pkmn == null or pkmn.is_egg() or pkmn.is_fainted():
		return false
	return pkmn.has_status(&"POISON") and pkmn.ability_id() != IMMUNITY_ABILITY

## One point of poison damage, and whatever it came to.
static func _hurt(pkmn: Pokemon) -> void:
	var can_faint: bool = GameSettings.data.poison_faints_in_field
	if pkmn.hp > 1 or can_faint:
		pkmn.hp -= 1
	if pkmn.hp == 1 and not can_faint:
		pkmn.heal_status()
		await Field.say(Loc.line(
			"{pokemon} survived the poisoning.\nThe poison faded away!",
			{"pokemon": pkmn.display_name()}
		))
		return
	if pkmn.hp <= 0:
		pkmn.change_happiness(&"faint")
		pkmn.heal_status()
		await Field.say(Loc.line("{pokemon} fainted...", {"pokemon": pkmn.display_name()}))
