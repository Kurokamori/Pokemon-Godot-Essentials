@tool
class_name TrainerCardBadges extends Control
## The row of badges on a Trainer Card.

## Badges from one region come from a single sheet, one column per badge and one row per region.

## The editor shows all badges as earned so a face can be laid out against a full row.

## Sheet under `assets/graphics/ui/`, 
## cut into [member badge_size] cells.
@export var sheet_graphic: String = "Trainer Card/icon_badges":
	set(value):
		sheet_graphic = value
		_rebuild()

## Size of each badge on the sheet and drawn at.
@export var badge_size: Vector2i = Vector2i(32, 32):
	set(value):
		badge_size = value
		_rebuild()

@export_group("Layout")

## Columns in the grid before wrapping to a new row.
@export_range(1, 16) var columns: int = 8:
	set(value):
		columns = value
		_rebuild()

## Gap between badges across and down.
@export var spacing: Vector2i = Vector2i(16, 8):
	set(value):
		spacing = value
		_rebuild()

## Number of badges to show.
## Zero means use the region's count from GameSettingsData.badges_per_region.
@export_range(0, 16) var count: int = 0:
	set(value):
		count = value
		_rebuild()

@export_group("Which Badges")

## Region these badges belong to and which sheet row they're on.
## Negative one means current region.
@export_range(-1, 8) var region: int = -1:
	set(value):
		region = value
		_rebuild()

@export_group("Unearned")

## Show unearned badges as visible marks.
@export var show_unearned: bool = true:
	set(value):
		show_unearned = value
		_rebuild()

## Opacity of unearned badges.
## Zero leaves them invisible like the games do, small values ghost them in.
@export_range(0.0, 1.0, 0.05) var unearned_opacity: float = 0.0:
	set(value):
		unearned_opacity = value
		_rebuild()

var _slots: Array[TextureRect] = []


func _ready():
	_rebuild()

func _get_configuration_warnings() -> PackedStringArray:
	if Assets.texture(AssetIndex.CATEGORY_UI, sheet_graphic) == null:
		return ["No badge sheet found named '%s'." % sheet_graphic]
	return []

func bind_trainer_card():
	_rebuild()

## Size the grid needs so containers layout it properly.
func _get_minimum_size() -> Vector2:
	var shown = _badge_count()
	var across = mini(shown, columns)
	var down = ceili(float(shown) / float(maxi(columns, 1)))
	if across <= 0 or down <= 0:
		return Vector2.ZERO
	return Vector2(
		across * badge_size.x + maxi(across - 1, 0) * spacing.x,
		down * badge_size.y + maxi(down - 1, 0) * spacing.y
	)


# === Drawing ===

func _rebuild():
	if not is_inside_tree():
		return
	var shown = _badge_count()
	_fit_slots(shown)
	var sheet = Assets.texture(AssetIndex.CATEGORY_UI, sheet_graphic)
	var row = maxi(_region(), 0)
	for index in range(shown):
		var slot = _slots[index]
		slot.texture = _badge_texture(sheet, index, row)
		slot.size = Vector2(badge_size)
		slot.position = Vector2(
			(index % columns) * (badge_size.x + spacing.x),
			(index / columns) * (badge_size.y + spacing.y)
		)
		var earned = _has_badge(index)
		slot.visible = earned or show_unearned
		slot.modulate.a = 1.0 if earned else unearned_opacity
	update_minimum_size()
	if Engine.is_editor_hint():
		update_configuration_warnings()

## Keep exactly wanted slots, reusing built ones so refresh doesn't churn through nodes.
func _fit_slots(wanted: int):
	while _slots.size() > wanted:
		var extra = _slots.pop_back()
		extra.queue_free()
	while _slots.size() < wanted:
		var slot = TextureRect.new()
		slot.name = "Badge%d" % _slots.size()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(slot)
		_slots.append(slot)

## One cell of the sheet at index across, row down.
func _badge_texture(sheet: Texture2D, index: int, row: int) -> Texture2D:
	if sheet == null or badge_size.x <= 0 or badge_size.y <= 0:
		return null
	var cell = AtlasTexture.new()
	cell.atlas = sheet
	cell.region = Rect2(
		Vector2(float(index * badge_size.x), float(row * badge_size.y)), Vector2(badge_size)
	)
	cell.filter_clip = true
	return cell


# === Lookups ===

## How many badges to draw.
## The editor gets this from the grid since autoloads aren't there during layout.
func _badge_count() -> int:
	if count > 0:
		return count
	if Engine.is_editor_hint() or GameSettings == null or GameSettings.data == null:
		return columns
	return GameSettings.data.badges_per_region

## Which row of the sheet these badges are on.
func _region() -> int:
	if region >= 0:
		return region
	if Engine.is_editor_hint() or GameState == null:
		return 0
	return GameState.current_region()

## Whether this region's badge at index has been earned.
## Regions split the bit-run into blocks.
func _has_badge(index: int) -> bool:
	if Engine.is_editor_hint():
		return true
	if GameState == null or GameState.player == null:
		return false
	var per_region = maxi(_badge_count(), 1)
	return GameState.player.has_badge((maxi(_region(), 0) * per_region) + index)
