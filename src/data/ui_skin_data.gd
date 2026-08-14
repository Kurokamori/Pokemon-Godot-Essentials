@tool
class_name UISkinData
extends Resource
## The game's look all as one edittable resource.
##
## Names under `Windowskins` are asset names from `res://assets/graphics/windowskins/`

@export_group("Windowskins")
## Menu frame for panels, menus, pause menu, etc.
@export var menu_windowskin: String = "choice 1"

## Dialogue window frame for speach windows
@export var speech_windowskin: String = "speech hgss 1"

## Frame used by choice lists shown next to a message
@export var choice_windowskin: String = "choice 1"

## Frame for location sign shown when entering a new area
@export var sign_windowskin: String = "sign hgss loc"

## Menu frames which the player can cycle through in the options screen
@export var menu_windowskin_choices: Array[String] = [
	"choice 1", "choice 2", "choice 3", "choice 4", "choice 5", "choice 6",
	"choice 7", "choice 8", "choice 9", "choice 10", "choice 11", "choice 12",
	"choice 13", "choice 14", "choice 15", "choice 16", "choice 17",
	"choice 18", "choice 19", "choice 20", "choice 21", "choice 22",
	"choice 23", "choice 24", "choice 25", "choice 26", "choice 27",
	"choice 28",
]
## Speech frames the player can cycle through in the options screen.
@export var speech_windowskin_choices: Array[String] = [
	"speech hgss 1", "speech hgss 2", "speech hgss 3", "speech hgss 4",
	"speech hgss 5", "speech hgss 6", "speech hgss 7", "speech hgss 8",
	"speech hgss 9", "speech hgss 10", "speech hgss 11", "speech hgss 12",
	"speech hgss 13", "speech hgss 14", "speech hgss 15", "speech hgss 16",
	"speech hgss 17", "speech hgss 18", "speech hgss 19", "speech hgss 20",
	"speech pl 18",
]

@export_group("Text Colours")
## Text on light window background
@export var dark_text: Color = Color("505058")
## Text shadow on light window background
@export var dark_text_shadow: Color = Color("a0a0a8")

## Text on a dark window background or picture
@export var light_text: Color = Color("f8f8f8")
## Text shadow on a dark window background or picture
@export var light_text_shadow: Color = Color("485058")

## Colour of the `\b` message, used for 'male' characters
@export var male_text: Color = Color("3050c8")
## Color of the `\r` messages, used for 'female' characters
@export var female_text: Color = Color("e00808")

## Colour of secondary text such as hints and captions
@export var muted_text: Color = Color("7c8494")
## Colour of selected entry's label highlight
@export var selected_text: Color = Color("f8f8f8")

## Offset of the 1-pixel shadow
@export var text_shadow_offset: Vector2i = Vector2i(1, 1)

@export_group("Screen Colours")
## Fill for the background of menus that do not draw their own background windowskins
@export var screen_background: Color = Color("263a5e")

## The gradient stop of the background gradient that do not draw their own background windowskins
@export var screen_background_edge: Color = Color("16223a")

## Overlay drawn between partial menus
@export var screen_dim: Color = Color(0.0, 0.0, 0.0, 0.4)

## Accent used for headers, focus rings, and selected tabs
@export var accent: Color = Color("e8474b")

## Secondary accent, used for the trim under headers
@export var accent_dark: Color = Color("a82c31")

@export_group("Bars")
@export var hp_bar_high: Color = Color("40c848")
@export var hp_bar_medium: Color = Color("f8b830")
@export var hp_bar_low: Color = Color("f04848")

@export var exp_bar: Color = Color("38a8f0")

@export var bar_background: Color = Color("404850")

@export_range(0, 8) var bar_corner_radius: int = 2

@export_group("Selection")
## The tint of the selection highlight when a windowskin has no cursor art for itself
@export var selection_fill: Color = Color(0.910, 0.278, 0.294, 0.900)

## Fill drawn under an entry that the player is hovering over
@export var hover_fill: Color = Color(1.0, 1.0, 1.0, 0.12)

## Fill drawn under an entry being pressed by the player
@export var pressed_fill: Color = Color(0.0, 0.0, 0.0, 0.12)

## Colour of the disabled text
@export var disabled_text: Color = Color("8890a0")

@export_group("Audio")
@export var select_sound: String = "GUI sel cursor"
@export var confirm_sound: String = "GUI sel decision"
@export var cancel_cound: String = "GUI menu close"


## Resolves [param index] within [member menu_windowskin_choices]
## A wrapping so that the options screen can cycle bidirectionally
func menu_windowskin_at(index: int) -> String:
	if menu_windowskin_choices.is_empty():
		return menu_windowskin
	return menu_windowskin_choices[posmod(index, menu_windowskin_choices.size())]

## Resolves [param index] within [member speech_windowskin_choices]
## A wrapping so that the options screen can cycle bidirectionally
func speech_windowskin_at(index: int) -> String:
	if speech_windowskin_choices.is_empty():
		return speech_windowskin
	return speech_windowskin_choices[posmod(index, speech_windowskin_choices.size())]
	
## Index of the current menu frame within the selectable list
## Returns `0` if it's not one of them
func menu_windowskin_index() -> int:
	return maxi(menu_windowskin_choices.find(menu_windowskin), 0)

## Index of the current speech frame within the selectable list
## Returns `0` if it's not one of them
func speech_windowskin_index() -> int:
	return maxi(speech_windowskin_choices.find(speech_windowskin), 0)


## Colour an HP bar should be at [param fraction] of full health
func hp_bar_colour(fraction: float) -> Color:
	if fraction <= 0.25:
		return hp_bar_low
	if fraction <= 0.5:
		return hp_bar_medium
	return hp_bar_high
