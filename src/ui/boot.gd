extends Control
## First scene in the game.
## Confirms that the data imports correctly before handing over to the title screen.

@onready var _status_label: Label = %StatusLabel
@onready var _detail_label: Label = %DetailLabel

func _ready() -> void:
	var problems: Array[String] = _check_data()
	if problems.is_empty():
		_status_label.text = Loc.line("Loading...")
		_detail_label.text = Loc.line(
			"{CATEGORY_SPECIES} species, {CATEGORY_MOVES} moves, {CATEGORY_ITEMS} items",
			{"CATEGORY_SPECIES": Database.count(Database.CATEGORY_SPECIES),
			"CATEGORY_MOVES": Database.count(Database.CATEGORY_MOVES),
			"CATEGORY_ITEMS": Database.count(Database.CATEGORY_ITEMS) }
		)
		await get_tree().create_timer(0.1).timeout
		SceneRouter.change_root_scene(SceneRouter.TITLE_SCENE)
		return
	_status_label.text = "Game Data is Missing"
	_detail_label.text = "\n".join(problems)

## Returns a human-readable list of data issues.
func _check_data() -> Array[String]:
	var problems: Array[String] = []
	if Database.count(Database.CATEGORY_SPECIES) == 0:
		problems.append("'res://data/species/' contains no species.")
	if Database.count(Database.CATEGORY_MOVES) == 0:
		problems.append("'res://data/moves/' contains no moves.")
	if Database.count(Database.CATEGORY_TYPES) == 0:
		problems.append("'res://data/types/' contains no types.")
	if not problems.is_empty():
		problems.append("Ensure that 'res://data/_manifest.tres lists all categories and their index")
	return problems
