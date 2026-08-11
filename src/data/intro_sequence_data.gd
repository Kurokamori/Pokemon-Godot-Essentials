class_name IntroSequenceData
extends Resource

## The openning professor scene as data.
##
## The [IntroScreen] will run this.
## Shows the pictures named here, speaks the lines in order, and stops at the marked points to ask the player who they are.
## Everything that one might wish to easily author, can be editted here.
##
## Each line is one message, shown and dismissed on its own, so there is no need to end one with a pause code.
## Lines may use the same control codes as any other message, plus three placeholders filled into the scene:
##
## {PROFESSOR} -- the professor name set bellow
## {PLAYER} -- the name of the player 
## {RIVAL} -- the name of the rival
##
## Lines left empty are skipped.

@export_group("Cast")
## The name of the Professor.
@export var professor_name: String = "Oak"

## The professor's image.
## Located at `res://assets/graphics/pictures/`
@export var professor_picture: String = "introOak"

## Pokemon image the professor shows off in the intro.
## Located at `res://assets/graphics/pictures/`
@export var demo_pokemon_picture: String = "introMarill"

## Cry played when the demo pokemon appears. (Leave blank for no cry)
@export var demo_pokemon_species: StringName = &"MARILL"

## Rival's picture, shown when the player names them.
## Professor's picture is kept on screen when blank.
## Located at `res://assets/graphics/pictures/`
@export var rival_picture: String = ""


@export_group("Scenery")
## Background image.
## Located at `res://assets/graphics/pictures/`
@export var background_picture: String = "introbg"

## Platform the professor/characters stand on.
## Leave empty to show nothing.
## Located at `res://assets/graphics/pictures/`
@export var base_picture: String = "introbase"

## Music played over the intro.
## Left empty whatever was already playing will continue to play.
@export var music: String = ""


@export_group("Script")
## The text shown at the beginning, while only the professor is on screen.
@export_multiline var greeting_lines: Array[String] = [
	"Hello there!\\nGlad to meet you!",
	"Welcome to the world of POKEMON!",
]

## Spoken while the demo Pokemon is on the screen.
@export_multiline var world_lines: Array[String] = [
	"This world is widely inhavited by creatures known as POKEMON!",
	"We humans live alongside POKEMON as friends.",
	"At times we play together, and at other times we work together.",
]

## What's said right before the player chooses their graphic.
@export_multiline var ask_character_lines: Array[String] = [
	"Now then...\\nFirst, tell me a little about yourself.",
]

## Spoken just before teh character name is asked, `{PLAYER}` isn't known yet, so do not use it.
@export_multiline var ask_name_lines: Array[String] = [
	"So tell me...\\nWhat is your name?",
]

## What's said when the player has been named.
@export_multiline var confirm_name_lines: Array[String] = [
	"Right! So your name is {PLAYER}!",
]

## What's said before the rival is named.
@export_multiline var ask_rival_lines: Array[String] = [
	"This is my grandson,",
	"He's been your rival since you were babies.",
	"...Erm, what was his name again?",
]

## Said when the rival has a name.
@export_multiline var confirm_rival_lines: Array[String] = [
	"That's right! I remember now! His name is {Rival}!",
]

## Said last, over the player's own picture.
@export_multiline var farewell_lines: Array[String] = [
	"{PLAYER}!",
	"Your very own POKEMON legend is about to unfold!",
	"A world of dreams and adventures with POKEMON awaits!\\nLet's go!",
]


@export_group("Character Choice")
## Ids of the [PlayerMetadataData] records the player may pick from.
## Empty means every record in the category in index order.
@export var selectable_characters: Array[StringName] = []

## Prompt shown above the character chooser.
@export var character_prompter: String = "Who are you?"


@export_group("Naming")
## Prompt shown on the name entry screen for the player.
@export var player_name_prompt: String = "Your name?"

## Prompt shown when naming the rival.
@export var rival_name_prompt: String = "Rival's name?"

## Offered names when the player is asked to name their rival.
@export var rival_name_suggestions: Array[String] = ["Blue", "Gary", "Silver", "May", "Brendan"]

## The name used when the rival's name is left blank.
@export var default_rival_name: String = "Blue"

## Used when the player leaves their own name blank and there's no fallback.
@export var default_player_name: String = "Red"

## Game variable the rival's name is written to
## This allows events to print it as `\v[id]`.
## Saves already will carry this variable so nothing else is needed to persist it.
@export var rival_name_variable: int = 1



@export_group("Starting Kit")
## Species offered at the beginning when the intro is finished.
## This allows for debugging and playable framework before gameplay acquisition is possible.
## Leave blanks to start with nothing.
@export var starter_species: StringName = &"CYNDAQUIL"

## The level of the given starter.
@export var starter_level: int = 5

## Items placed into the bag at start as item id and quantity, leaving empty gives the player nothing.
@export var starting_items: Dictionary[StringName, int] = {
	&"POTION": 5,
	&"POKEBALL": 10,
}

## Whether the player is able to run by the end of the intro or of they must wait until they recieve running shoes.
@export var give_running_shoes: bool = false


## Function to fill the placeholders in [param line].
## Unknown values are left as is so unfinished sequences still read logically.
func fill(line: String, player_name: String, rival_name: String) -> String:
	var text: String = line.replace("{PROFESSOR}", professor_name)
	text = text.replace("{PLAYER}", player_name)
	text = text.replace("RIVAL", rival_name)
	return text
