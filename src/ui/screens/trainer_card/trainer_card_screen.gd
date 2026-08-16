class_name TrainerCardScreen extends GameScreen
## The Trainer Card: who the player is, what they've done, and their badges.

## The card is its scene. Almost nothing about how it looks lives here. 
## Each side is a [TrainerCardFace] designed in the editor; the card shows faces as children of Faces in order. 
## This script turns pages and the face fills itself in.


const SCENE_PATH: String = "res://scenes/ui/trainer_card_screen.tscn"

## Sound played when the card comes out.
const OPEN_SOUND: String = "GUI trainer card open"

## Seconds per side flip.
@export_range(0.0, 1.0, 0.01) var flip_seconds: float = 0.18

## Starting face index from zero.
@export var starting_face: int = 0

@onready var _faces_root: Control = %Faces
@onready var _page_label: Label = %PageLabel

## Faces on offer, in turn order.
var _faces: Array[TrainerCardFace] = []
var _face_index: int = 0

## True while turning; prevents held buttons from spinning the card.
var _turning: bool = false


func _ready():
	super._ready()
	_collect_faces()
	if _faces.is_empty():
		push_error("TrainerCardScreen: the card has no faces to show.")
		close(null)
		return
	_face_index = clampi(starting_face, 0, _faces.size() - 1)
	for face in _faces:
		face.visible = false
		face.pivot_offset = face.size * 0.5
	_show_face(_face_index)
	AudioManager.play_se(OPEN_SOUND)

## The card's faces: every available TrainerCardFace under Faces in scene order.
## Helper nodes parked there stay visible.
func _collect_faces():
	_faces.clear()
	for child in _faces_root.get_children():
		var face = child as TrainerCardFace
		if face != null and face.is_available():
			_faces.append(face)
		elif face != null:
			face.visible = false

## Show the face at index, bind it, animate in, and update the page label.
func _show_face(index: int):
	var face = _faces[index]
	face.bind()
	face.visible = true
	face.scale = Vector2.ONE
	face.modulate.a = 1.0
	_page_label.text = _page_text(index)

## Page indicator: the face's title when it has one, and progress count when multiple sides exist.
func _page_text(index: int) -> String:
	var title = _faces[index].title
	if _faces.size() < 2:
		return title
	var counter = "%d/%d" % [index + 1, _faces.size()]
	return "%s  %s" % [title, counter] if not title.is_empty() else counter


# === Turning ===

## Turn the card. Step is direction and pages wrap round.
func _turn(step: int):
	if _turning or _faces.size() < 2:
		return
	_turning = true
	play_select()
	var outgoing = _faces[_face_index]
	_face_index = wrapi(_face_index + step, 0, _faces.size())
	var incoming = _faces[_face_index]

	if flip_seconds <= 0.0:
		outgoing.visible = false
		_show_face(_face_index)
		_turning = false
		return

	var half = flip_seconds * 0.5
	var closing = create_tween()
	closing.tween_property(outgoing, "scale:x", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await closing.finished
	outgoing.visible = false
	outgoing.scale = Vector2.ONE

	incoming.bind()
	incoming.scale = Vector2(0.0, 1.0)
	incoming.visible = true
	_page_label.text = _page_text(_face_index)
	var opening = create_tween()
	opening.tween_property(incoming, "scale:x", 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await opening.finished
	_turning = false


## Input handler for card turning. 
## Returns while turning so input is ignored mid-flip.
func _unhandled_input(event: InputEvent):
	if _turning:
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("storage_next_box"):
		get_viewport().set_input_as_handled()
		_turn(1)
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("storage_previous_box"):
		get_viewport().set_input_as_handled()
		_turn(-1)
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_turn(1)
		return
	super._unhandled_input(event)
