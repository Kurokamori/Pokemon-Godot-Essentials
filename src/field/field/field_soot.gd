class_name FieldSoot
## Volcanic ash gathered off the ground as the player walks through it.

## The terrain the soot lies on.
const SOOT_TERRAIN: StringName = &"SootGrass"

## The item the soot goes into.
const SOOT_SACK: StringName = &"SOOTSACK"

## Gathers whatever the step just taken was worth.
static func take_step(field: MapController) -> int:
	if field == null or GameState.player == null:
		return 0
	if not _standing_on_soot(field):
		return 0
	if GameState.bag == null or not GameState.bag.has_item(SOOT_SACK):
		return 0
	return gather(1)

## Puts [param amount] soot in the sack, as far as it will go, and counts what actually went in.
static func gather(amount: int) -> int:
	var player: Player = GameState.player
	if player == null or amount <= 0:
		return 0
	var before: int = player.soot
	player.soot = clampi(player.soot + amount, 0, GameSettings.data.max_soot)
	var gained: int = player.soot - before
	if gained > 0:
		GameState.stats.soot_collected += gained
	return gained

## `true` when the cell the player is standing on is soot grass.
static func _standing_on_soot(field: MapController) -> bool:
	var terrain: TerrainTagData = field.terrain_at_world(field.player.world_cell())
	return terrain != null and terrain.id == SOOT_TERRAIN
