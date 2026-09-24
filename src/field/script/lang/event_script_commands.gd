class_name EventScriptCommands
## Command names, arguments, and block rules for event scripts.

## No block is allowed.
const BLOCK_NONE: int = 0

## A block is optional.
const BLOCK_OPTIONAL: int = 1

## A block is required.
const BLOCK_REQUIRED: int = 2

## A block contains branch keywords.
const BLOCK_BRANCHES: int = 3

## No argument limit.
const ANY: int = -1

## Command definitions, keyed by canonical name.
const COMMANDS: Dictionary = {
	# === Dialogue ===
	"say": {
		"args": [0, ANY], "block": BLOCK_OPTIONAL, "raw": true, "group": "Dialogue",
		"usage": "say <text>",
		"summary": "Shows one message box and waits for the player. Quotes are optional; an indented block makes a message of several lines.",
	},
	"ask": {
		"args": [2, ANY], "block": BLOCK_BRANCHES, "group": "Dialogue",
		"usage": "ask <prompt> <option> <option> ...:",
		"summary": "Asks a question with the options listed, and runs the matching `when` branch. The prompt stays on screen while the player decides.",
	},
	"choice": {
		"args": [1, ANY], "block": BLOCK_BRANCHES, "group": "Dialogue",
		"usage": "choice <option> <option> ...:",
		"summary": "Offers a menu with no question above it and runs the matching `when` branch.",
	},
	"when": {
		"args": [0, ANY], "block": BLOCK_REQUIRED, "group": "Dialogue",
		"parent": ["ask", "choice"],
		"usage": "when <option or number>:",
		"summary": "The branch taken when the player picks this option, named either by its text or by its position, counting from one.",
	},
	"cancel": {
		"args": [0, 0], "block": BLOCK_REQUIRED, "group": "Dialogue",
		"parent": ["ask", "choice"],
		"usage": "cancel:",
		"summary": "The branch taken when the player backs out. Adding one is what allows the menu to be cancelled at all.",
	},
	"confirm": {
		"args": [1, 1], "block": BLOCK_BRANCHES, "group": "Dialogue",
		"usage": "confirm <question>:",
		"summary": "Asks a yes/no question and runs the `yes` or `no` branch. Backing out counts as no.",
	},
	"yes": {
		"args": [0, 0], "block": BLOCK_REQUIRED, "group": "Dialogue",
		"parent": ["confirm"], "usage": "yes:", "summary": "The branch taken when the player agrees.",
	},
	"no": {
		"args": [0, 0], "block": BLOCK_REQUIRED, "group": "Dialogue",
		"parent": ["confirm"], "usage": "no:", "summary": "The branch taken when the player refuses.",
	},

	# === Flow ===
	"if": {
		"args": [1, 1], "block": BLOCK_REQUIRED, "group": "Flow",
		"usage": "if <condition>:",
		"summary": "Runs the block when the condition holds.",
	},
	"elif": {
		"args": [1, 1], "block": BLOCK_REQUIRED, "group": "Flow",
		"parent": ["if", "unless"],
		"usage": "elif <condition>:",
		"summary": "Another condition to try when the ones above it did not hold.",
	},
	"else": {
		"args": [0, 0], "block": BLOCK_REQUIRED, "group": "Flow",
		"parent": ["if", "unless", "ask", "choice", "confirm"],
		"usage": "else:",
		"summary": "The block run when nothing above it was taken. Under a menu it stands for any option without a `when`.",
	},
	"unless": {
		"args": [1, 1], "block": BLOCK_REQUIRED, "group": "Flow",
		"usage": "unless <condition>:",
		"summary": "Runs the block when the condition does not hold.",
	},
	"while": {
		"args": [1, 1], "block": BLOCK_REQUIRED, "group": "Flow",
		"usage": "while <condition>:",
		"summary": "Repeats the block for as long as the condition holds.",
	},
	"repeat": {
		"args": [1, 1], "block": BLOCK_REQUIRED, "group": "Flow",
		"usage": "repeat <count>:",
		"summary": "Runs the block that many times. `index` counts the passes from zero.",
	},
	"loop": {
		"args": [0, 0], "block": BLOCK_REQUIRED, "group": "Flow",
		"usage": "loop:",
		"summary": "Repeats the block until something in it breaks, exits or warps.",
	},
	"break": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Flow",
		"usage": "break", "summary": "Leaves the loop being run.",
	},
	"continue": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Flow",
		"usage": "continue", "summary": "Skips to the next pass of the loop being run.",
	},
	"label": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Flow",
		"usage": "label <name>", "summary": "Marks a place `goto` can jump back or forward to.",
	},
	"goto": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Flow",
		"usage": "goto <name>", "summary": "Carries on from the named label.",
	},
	"routine": {
		"args": [1, 1], "block": BLOCK_REQUIRED, "group": "Flow",
		"usage": "routine <name>:",
		"summary": "Names a block that `call` can run. Routines are skipped where they are written.",
	},
	"call": {
		"args": [1, ANY], "block": BLOCK_NONE, "group": "Flow",
		"usage": "call <routine or script path>",
		"summary": "Runs a routine from this file, or another script file, and comes back. Extra arguments arrive as `arg1`, `arg2` and so on.",
	},
	"exit": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Flow",
		"usage": "exit", "summary": "Stops the script here.",
	},
	"return": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Flow",
		"usage": "return [value]",
		"summary": "Leaves the routine being called, optionally with a value the caller reads as `result`.",
	},
	"wait": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Flow",
		"usage": "wait <seconds>", "summary": "Pauses for that many seconds.",
	},
	"wait_for_move": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Flow",
		"usage": "wait_for_move", "summary": "Waits until nobody on the map is still walking.",
	},

	# === State ===
	"let": {
		"args": [2, ANY], "block": BLOCK_NONE, "group": "State",
		"usage": "let <name> = <value>",
		"summary": "Makes a value the rest of the script can read back by name. Locals last as long as the run does.",
	},
	"set": {
		"args": [2, ANY], "block": BLOCK_NONE, "group": "State",
		"usage": "set <name> = <value>", "summary": "Changes a local made by `let`, or makes one.",
	},
	"set_switch": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "State",
		"usage": "set_switch <id> [on|off]", "summary": "Turns a game switch on, or off with a second argument of `off`.",
	},
	"set_var": {
		"args": [2, 2], "block": BLOCK_NONE, "group": "State",
		"usage": "set_var <id> = <value>", "summary": "Writes a game variable.",
	},
	"add_var": {
		"args": [2, 2], "block": BLOCK_NONE, "group": "State",
		"usage": "add_var <id> <amount>", "summary": "Adds to a game variable.",
	},
	"set_self_switch": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "State",
		"usage": "set_self_switch <A|B|C|D> [on|off]",
		"summary": "Flips one of this event pages own switches, which is how an event remembers it has been used.",
	},

	# === Player ===
	"give_item": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Player",
		"usage": "give_item <ITEM> [count]",
		"summary": "Puts an item in the bag and says so, handling a full bag the way a found item does.",
	},
	"give_item_silent": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Player",
		"usage": "give_item_silent <ITEM> [count]", "summary": "Puts an item in the bag without a message.",
	},
	"take_item": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Player",
		"usage": "take_item <ITEM> [count]", "summary": "Removes an item from the bag.",
	},
	"give_money": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Player",
		"usage": "give_money <amount>", "summary": "Adds to the players money.",
	},
	"take_money": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Player",
		"usage": "take_money <amount>", "summary": "Takes money, as far as there is any. `result` says whether it was all there.",
	},
	"give_pokemon": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Player",
		"usage": "give_pokemon <SPECIES> [level]",
		"summary": "Gives a Pokemon through the usual receiving flow: it is named, and it goes to a box when the party is full.",
	},
	"give_pokemon_silent": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Player",
		"usage": "give_pokemon_silent <SPECIES> [level]", "summary": "Gives a Pokemon with no message and no nickname prompt.",
	},
	"add_to_party": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Player",
		"usage": "add_to_party <SPECIES> [level]",
		"summary": "Adds straight to the party, doing nothing when it is full. `result` says whether there was room.",
	},
	"heal_party": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Player",
		"usage": "heal_party", "summary": "Restores the whole party.",
	},
	"give_badge": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Player",
		"usage": "give_badge <number>", "summary": "Awards a badge, counting from one.",
	},
	"open_pc": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Player",
		"usage": "open_pc", "summary": "Runs the storage PC menu until the player logs off.",
	},
	"show_town_map": {
		"args": [0, 2], "block": BLOCK_NONE, "group": "Player",
		"usage": "show_town_map [own] [region]",
		"summary": "Opens the region map. `own` is the player's own map, which shows where they are and offers Fly; left out it is a map on a wall. `region` shows somewhere other than where the player is.",
	},
	"fly": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Player",
		"usage": "fly",
		"summary": "Opens the region map to choose a destination and flies there. `result` says whether the player went.",
	},
	"trainer_card": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Player",
		"usage": "trainer_card",
		"summary": "Shows the player their Trainer Card.",
	},

	# === Followers ===
	"follower_mode": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Followers",
		"usage": "follower_mode <none|lead|chosen|species|party|default>",
		"summary": "Decides which Pokemon walk behind the player for the rest of the playthrough, over whatever the player chose in the options. `default` hands the choice back to them.",
	},
	"follow_me": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Followers",
		"usage": "follow_me <party slot>",
		"summary": "Picks the party member in that slot as the one that walks, counting from one. Picking the one already picked clears it. Only means anything in the `chosen` mode.",
	},
	"add_follower": {
		"args": [1, 5], "block": BLOCK_NONE, "group": "Followers",
		"usage": "add_follower <party slot | SPECIES> [form] [shiny] [female] [name]",
		"summary": "Puts a Pokemon at the head of the line for a scene, whatever the mode says. A number is a party slot counting from one; a species is a Pokemon that need not be in the party at all. `result` says whether it worked.",
	},
	"clear_followers": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Followers",
		"usage": "clear_followers",
		"summary": "Sends the scene's followers away and puts the party's own line back.",
	},
	"hide_followers": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Followers",
		"usage": "hide_followers",
		"summary": "Takes the followers off the screen for a cutscene.",
	},
	"show_followers": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Followers",
		"usage": "show_followers",
		"summary": "Puts them back, the Pokemon on the player's heels rather than wherever they were standing.",
	},
	"follower_cry": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Followers",
		"usage": "follower_cry",
		"summary": "Plays the cry of whichever Pokemon is walking closest to the player.",
	},

	# === Pokegear ===
	"pokegear": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Pokegear",
		"usage": "pokegear",
		"summary": "Opens the Pokegear, from which the player can reach the region map and their phone book. Does nothing until they have been given one.",
	},
	"phone_book": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Pokegear",
		"usage": "phone_book",
		"summary": "Opens the phone book on its own, skipping the Pokegear's app menu.",
	},
	"phone_register": {
		"args": [1, 4], "block": BLOCK_NONE, "group": "Pokegear",
		"usage": "phone_register <type> <name> [parties] [version]",
		"summary": "Swaps numbers with a trainer and announces it. A name on its own registers somebody who only ever chats. `parties` is how many of that trainer there are to work up through; `version` is the one to start on. `result` says whether the number was new.",
	},
	"phone_registered": {
		"args": [1, 3], "block": BLOCK_NONE, "group": "Pokegear",
		"usage": "phone_registered <type> <name> [version]",
		"summary": "`result` says whether that contact is already in the phone book.",
	},
	"phone_call": {
		"args": [1, 3], "block": BLOCK_NONE, "group": "Pokegear",
		"usage": "phone_call <type> <name> [version]",
		"summary": "Rings a contact who is already in the phone book. A name on its own rings somebody who only chats. `result` says whether the call went through.",
	},
	"phone_rematches": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Pokegear",
		"usage": "phone_rematches <on|off>",
		"summary": "Turns rematches on or off for the whole phone book, which is how a game holds them back until a plot point.",
	},
	"phone_rematch_variant": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Pokegear",
		"usage": "phone_rematch_variant <number>",
		"summary": "Raises the ceiling on how strong anybody's rematch may get, counted from the party they were registered with. Games step it up as the story goes on.",
	},

	# === Ceremonies ===
	"hall_of_fame": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Ceremonies",
		"usage": "hall_of_fame",
		"summary": "Records the party in the Hall of Fame and plays the ceremony.",
	},
	"view_hall_of_fame": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Ceremonies",
		"usage": "view_hall_of_fame",
		"summary": "Opens the record of teams already inducted.",
	},
	"show_credits": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Ceremonies",
		"usage": "show_credits",
		"summary": "Rolls the end credits. `result` says whether the player watched to the end.",
	},
	"return_to_title": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Ceremonies",
		"usage": "return_to_title",
		"summary": "Abandons the session and goes back to the title screen, which is how a cancelled Battle Frontier run ends. Nothing after it runs.",
	},

	# === Movement ===
	"move": {
		"args": [2, ANY], "block": BLOCK_NONE, "group": "Movement",
		"usage": "move <who> <step> <step> ...",
		"summary": "Walks somebody one cell per step: up, down, left, right, up_left, up_right, down_left, down_right, forward, back, random, toward, away. Put a `wait` on a line of its own to pause between steps.",
	},
	"turn": {
		"args": [2, 2], "block": BLOCK_NONE, "group": "Movement",
		"usage": "turn <who> <up|down|left|right|player|away|around|random>",
		"summary": "Turns somebody on the spot without moving them.",
	},
	"jump": {
		"args": [3, 3], "block": BLOCK_NONE, "group": "Movement",
		"usage": "jump <who> <across> <down>", "summary": "Hops that many cells, which may be negative or zero.",
	},
	"set_speed": {
		"args": [2, 2], "block": BLOCK_NONE, "group": "Movement",
		"usage": "set_speed <who> <1-6>", "summary": "How fast they walk from now on.",
	},
	"set_graphic": {
		"args": [2, 2], "block": BLOCK_NONE, "group": "Movement",
		"usage": "set_graphic <who> <charset>", "summary": "Swaps the character sheet they are drawn with.",
	},
	"set_opacity": {
		"args": [2, 2], "block": BLOCK_NONE, "group": "Movement",
		"usage": "set_opacity <who> <0-255>", "summary": "How solid they look.",
	},
	"set_through": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Movement",
		"usage": "set_through <who> [on|off]", "summary": "Lets them walk through walls and through other characters.",
	},
	"set_position": {
		"args": [3, 4], "block": BLOCK_NONE, "group": "Movement",
		"usage": "set_position <who> <x> <y> [facing]", "summary": "Puts them on a cell at once, without walking there.",
	},
	"show": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Movement",
		"usage": "show [who]", "summary": "Makes somebody visible again.",
	},
	"hide": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Movement",
		"usage": "hide [who]", "summary": "Makes somebody invisible without erasing them.",
	},
	"face_player": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Movement",
		"usage": "face_player [who]", "summary": "Turns towards the player.",
	},
	"warp": {
		"args": [3, 4], "block": BLOCK_NONE, "group": "Movement",
		"usage": "warp <map id> <x> <y> [facing]", "summary": "Sends the player to another map, fading through black.",
	},
	"warp_scene": {
		"args": [1, 3], "block": BLOCK_NONE, "group": "Movement",
		"usage": "warp_scene <scene path> [spawn name] [facing]",
		"summary": "Sends the player to a map scene by path, landing on a named spawn point.",
	},
	"teleport": {
		"args": [2, 3], "block": BLOCK_NONE, "group": "Movement",
		"usage": "teleport <x> <y> [facing]", "summary": "Moves the player elsewhere on the map they are already on.",
	},

	# === Presentation ===
	"play_se": {
		"args": [1, 3], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "play_se <name> [volume] [pitch]", "summary": "Plays a sound effect.",
	},
	"play_bgm": {
		"args": [1, 3], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "play_bgm <name> [volume] [pitch]", "summary": "Starts background music.",
	},
	"play_bgs": {
		"args": [1, 3], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "play_bgs <name> [volume] [pitch]", "summary": "Starts a background sound.",
	},
	"play_me": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "play_me <name> [volume]", "summary": "Plays a jingle over the music.",
	},
	"play_cry": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "play_cry <SPECIES> [pitch]", "summary": "Plays a Pokemon cry.",
	},
	"stop_se": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "stop_se", "summary": "Silences the sound effects playing.",
	},
	"stop_bgm": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "stop_bgm", "summary": "Stops the music at once.",
	},
	"fade_out_bgm": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "fade_out_bgm [seconds]", "summary": "Fades the music out.",
	},
	"stop_bgs": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "stop_bgs", "summary": "Stops the background sound.",
	},
	"fade_out": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "fade_out", "summary": "Fades the screen to black.",
	},
	"fade_in": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "fade_in", "summary": "Fades the screen back in.",
	},
	"set_tone": {
		"args": [3, 5], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "set_tone <red> <green> <blue> [grey] [seconds]",
		"summary": "Tints the screen, in RPG Maker's numbers: -255 to 255 a channel, and 0 to 255 of grey. Waits for the change.",
	},
	"clear_tone": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "clear_tone [seconds]",
		"summary": "Puts the screen tone back to normal, and waits for it.",
	},
	"flash_screen": {
		"args": [0, 2], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "flash_screen [colour] [seconds]",
		"summary": "Washes a colour over the screen and fades it away. White for half a second unless told otherwise. Does not wait.",
	},
	"shake_screen": {
		"args": [0, 3], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "shake_screen [power] [speed] [seconds]",
		"summary": "Shakes the screen, both numbers from 0 to 9. Does not wait; a power of zero stops one already running.",
	},
	"wait_for_shake": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "wait_for_shake", "summary": "Waits until the screen has stopped shaking.",
	},
	"set_weather": {
		"args": [1, 3], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "set_weather <WEATHER> [power] [seconds]",
		"summary": "Brings on a weather over the map's own, at a power from 0 to 9. Does not wait; it stays until something changes it.",
	},
	"clear_weather": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "clear_weather [seconds]",
		"summary": "Hands the map its own weather back.",
	},
	"message_box": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "message_box <top|middle|bottom> [frame]",
		"summary": "Where the message window opens from now on, and whether it is drawn with a frame. Both stick until something changes them again.",
	},
	"play_animation": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "play_animation <number> [who]",
		"summary": "Plays one of the overworld animations over somebody. Defaults to this event.",
	},
	"remember_music": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "remember_music",
		"summary": "Writes down the music and ambience playing now, for `restore_music` to put back after a detour.",
	},
	"restore_music": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Presentation",
		"usage": "restore_music",
		"summary": "Starts the music and ambience `remember_music` wrote down again.",
	},

	# === Pictures ===
	"show_picture": {
		"args": [2, 6], "block": BLOCK_NONE, "group": "Pictures",
		"usage": "show_picture <number> <image> [x] [y] [opacity] [zoom]",
		"summary": "Draws an image from `assets/graphics/pictures/` over the map. The number is what the other picture commands address it by; higher numbers draw in front.",
	},
	"move_picture": {
		"args": [3, 6], "block": BLOCK_NONE, "group": "Pictures",
		"usage": "move_picture <number> <x> <y> [seconds] [opacity] [zoom]",
		"summary": "Slides a picture somewhere else, fading its opacity and zoom on the way. Does not wait.",
	},
	"rotate_picture": {
		"args": [2, 2], "block": BLOCK_NONE, "group": "Pictures",
		"usage": "rotate_picture <number> <speed>",
		"summary": "Spins a picture at that speed, or stops one with a speed of zero.",
	},
	"tint_picture": {
		"args": [4, 5], "block": BLOCK_NONE, "group": "Pictures",
		"usage": "tint_picture <number> <red> <green> <blue> [seconds]",
		"summary": "Tints a picture, in RPG Maker's numbers: -255 to 255 a channel. A picture's tone is a tint rather than a wash, so each channel says how much of that colour survives.",
	},
	"erase_picture": {
		"args": [1, 1], "block": BLOCK_NONE, "group": "Pictures",
		"usage": "erase_picture <number>", "summary": "Takes one picture off the screen.",
	},
	"erase_pictures": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Pictures",
		"usage": "erase_pictures", "summary": "Takes every picture off the screen.",
	},

	# === Battles ===
	"wild_battle": {
		"args": [1, 2], "block": BLOCK_NONE, "group": "Battle",
		"usage": "wild_battle <SPECIES> [level]",
		"summary": "Fights one wild Pokemon. Afterwards `battle_won`, `battle_lost`, `battle_fled` and `battle_caught` say how it went.",
	},
	"double_wild_battle": {
		"args": [2, 4], "block": BLOCK_NONE, "group": "Battle",
		"usage": "double_wild_battle <SPECIES> <SPECIES> [level] [level]",
		"summary": "Fights two wild Pokemon at once. Levels default to 5 each, and the second level defaults to the first.",
	},
	"trainer_battle": {
		"args": [2, 3], "block": BLOCK_NONE, "group": "Battle",
		"usage": "trainer_battle <TYPE> <name> [version]",
		"summary": "Fights a trainer from the trainer list. Afterwards `battle_won` says whether the player took it.",
	},

	# === Wild encounters ===
	"encounters": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "encounters [on|off]",
		"summary": "Switches wild encounters on or off for the rest of the game, until switched back.",
	},
	"single_battle_next": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "single_battle_next",
		"summary": "Makes the next wild battle a single one even in grass that would double it.",
	},
	"encounter": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "encounter [type]",
		"summary": "Rolls a wild battle from this map's own table, as though the player had walked into one. `result` says whether anything turned up.",
	},
	"surf": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "surf",
		"summary": "Offers to put the player on the water they are facing. `result` says whether they set off.",
	},
	"stop_surfing": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "stop_surfing", "summary": "Takes the player off the water.",
	},
	"dive": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "dive",
		"summary": "Offers to take the player underwater, or to bring them back up, whichever fits where they are. `result` says whether they went.",
	},
	"dive_now": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "dive_now",
		"summary": "Takes the player straight down to the map below, without asking.",
	},
	"surface_now": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "surface_now",
		"summary": "Brings the player straight back up to the map above, without asking.",
	},
	"fish": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "fish [ROD]",
		"summary": "Casts a rod at the water in front of the player. Defaults to the Old Rod. `result` says whether anything bit.",
	},
	"sweet_scent": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "sweet_scent",
		"summary": "Draws out whatever lives where the player is standing — two of them in grass that allows double battles.",
	},
	"rock_smash_encounter": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "rock_smash_encounter",
		"summary": "The wild Pokemon a smashed rock sometimes hides. `result` says whether one was fought.",
	},
	"headbutt_encounter": {
		"args": [0, 1], "block": BLOCK_NONE, "group": "Encounters",
		"usage": "headbutt_encounter [low]",
		"summary": "The wild Pokemon a headbutted tree sometimes drops. `low` picks the poorer of the two tables.",
	},

	# === Event ===
	"erase": {
		"args": [0, 0], "block": BLOCK_NONE, "group": "Event",
		"usage": "erase", "summary": "Takes this event off the map until it is loaded again.",
	},

	# === Escape hatch ===
	"script": {
		"args": [1, ANY], "block": BLOCK_NONE, "raw": true, "group": "Escape hatch",
		"usage": "script <essentials snippet>",
		"summary": "Runs one of the Essentials calls [EventScriptBridge] understands, for anything without a command of its own. `result` is what it returned.",
	},
	"debug": {
		"args": [0, ANY], "block": BLOCK_NONE, "raw": true, "group": "Escape hatch",
		"usage": "debug <text>", "summary": "Prints to the output panel. Shows nothing to the player.",
	},
}

## Command aliases.
const ALIASES: Dictionary = {
	"text": "say", "message": "say", "msg": "say", "print": "debug", "log": "debug",
	"menu": "choice", "choices": "choice", "question": "ask",
	"otherwise": "else", "default": "else", "else_if": "elif", "elseif": "elif",
	"jump_to": "goto", "def": "routine", "stop": "exit", "end_event": "exit",
	"local": "let", "variable": "set_var", "set_variable": "set_var",
	"add_variable": "add_var", "switch": "set_switch", "self_switch": "set_self_switch",
	"speed": "set_speed", "graphic": "set_graphic", "opacity": "set_opacity",
	"through": "set_through", "place": "set_position", "face": "turn",
	"se": "play_se", "bgm": "play_bgm", "bgs": "play_bgs", "me": "play_me",
	"cry": "play_cry", "essentials": "script", "ruby": "script",
	"erase_event": "erase", "wait_for_moves": "wait_for_move",
	"pause": "wait",
	"tone": "set_tone", "tint": "set_tone", "flash": "flash_screen",
	"shake": "shake_screen", "weather": "set_weather",
}

## Builtins and their argument counts.
const FUNCTIONS: Dictionary = {
	# session
	"switch": {"args": [1, 1], "summary": "Whether game switch <id> is on."},
	"variable": {"args": [1, 1], "summary": "The value of game variable <id>."},
	"self_switch": {"args": [1, 1], "summary": "Whether this events own switch A, B, C or D is on."},
	"map_id": {"args": [0, 0], "summary": "The number of the map being played."},
	# the player
	"player_name": {"args": [0, 0], "summary": "The name the player chose."},
	"money": {"args": [0, 0], "summary": "How much money the player has."},
	"coins": {"args": [0, 0], "summary": "How many Game Corner coins the player has."},
	"badge_count": {"args": [0, 0], "summary": "How many badges the player has earned."},
	"has_badge": {"args": [1, 1], "summary": "Whether badge <number> has been earned."},
	"player_is_male": {"args": [0, 0], "summary": "Whether the player is male."},
	"player_is_female": {"args": [0, 0], "summary": "Whether the player is female."},
	"has_pokedex": {"args": [0, 0], "summary": "Whether the player owns a Pokedex."},
	"has_pokegear": {"args": [0, 0], "summary": "Whether the player owns a Pokegear."},
	"has_running_shoes": {"args": [0, 0], "summary": "Whether the player owns running shoes."},
	"steps": {"args": [0, 0], "summary": "How many steps the player has taken."},
	# the bag
	"has_item": {"args": [1, 2], "summary": "Whether the bag holds <ITEM>, optionally at least <count> of it."},
	"item_count": {"args": [1, 1], "summary": "How many of <ITEM> are in the bag."},
	"item_name": {"args": [1, 2], "summary": "The readable name of <ITEM>, plural when <count> is more than one."},
	# the party
	"party_size": {"args": [0, 0], "summary": "How many Pokemon are in the party."},
	"party_full": {"args": [0, 0], "summary": "Whether the party has no room left."},
	"party_able_count": {"args": [0, 0], "summary": "How many party Pokemon can still battle."},
	"has_species": {"args": [1, 1], "summary": "Whether the party holds a <SPECIES>."},
	"highest_level": {"args": [0, 0], "summary": "The level of the highest party member."},
	"species_name": {"args": [1, 1], "summary": "The readable name of <SPECIES>."},
	# the Pokedex
	"seen": {"args": [1, 1], "summary": "Whether <SPECIES> has been seen."},
	"owned": {"args": [1, 1], "summary": "Whether <SPECIES> has been caught."},
	"seen_count": {"args": [0, 0], "summary": "How many species have been seen."},
	"owned_count": {"args": [0, 0], "summary": "How many species have been caught."},
	# the map
	"player_x": {"args": [0, 0], "summary": "The players column."},
	"player_y": {"args": [0, 0], "summary": "The players row."},
	"event_x": {"args": [0, 1], "summary": "The column somebody stands on; this event when nobody is named."},
	"event_y": {"args": [0, 1], "summary": "The row somebody stands on; this event when nobody is named."},
	"facing": {"args": [0, 1], "summary": "Which way somebody is facing, as up, down, left or right."},
	"distance_to_player": {"args": [0, 1], "summary": "How many cells away from the player somebody is, counted around corners."},
	# arithmetic and text
	"random": {"args": [1, 1], "summary": "A whole number from zero up to but not including <count>."},
	"random_range": {"args": [2, 2], "summary": "A whole number between the two given, either end included."},
	"min": {"args": [2, 2], "summary": "The smaller of two numbers."},
	"max": {"args": [2, 2], "summary": "The larger of two numbers."},
	"abs": {"args": [1, 1], "summary": "A number without its sign."},
	"floor": {"args": [1, 1], "summary": "A number rounded down."},
	"round": {"args": [1, 1], "summary": "A number rounded to the nearest whole one."},
	"clamp": {"args": [3, 3], "summary": "A number held between a smallest and a largest."},
	"number": {"args": [1, 1], "summary": "A value read as a number."},
	"text": {"args": [1, 1], "summary": "A value read as text."},
	"length": {"args": [1, 1], "summary": "How many characters are in some text."},
	"upper": {"args": [1, 1], "summary": "Text in capitals."},
	"lower": {"args": [1, 1], "summary": "Text in lower case."},
}

## Bare words that are literal values.
const LITERAL_WORDS: Dictionary = {
	"true": true, "false": false, "on": true, "off": false,
	"yes": true, "no": false, "none": null, "null": null,
}

## Branch keywords.
const BRANCH_KEYWORDS: PackedStringArray = ["when", "cancel", "else", "elif", "yes", "no"]

## Resolves a command alias, keeping unknown names unchanged.
static func canonical(written: String) -> String:
	var name: String = written.to_lower()
	return String(ALIASES.get(name, name))

static func exists(written: String) -> bool:
	return COMMANDS.has(canonical(written))

static func spec(written: String) -> Dictionary:
	return COMMANDS.get(canonical(written), {})

## Whether a command takes raw text.
static func takes_raw_text(written: String) -> bool:
	return bool(spec(written).get("raw", false))

static func block_kind(written: String) -> int:
	return int(spec(written).get("block", BLOCK_NONE))

## Valid parent commands for a branch.
static func parents_of(written: String) -> Array:
	return spec(written).get("parent", [])

static func is_function(name: String) -> bool:
	return FUNCTIONS.has(name.to_lower())

## Returns an argument error, if any.
static func argument_problem(written: String, count: int) -> String:
	var limits: Array = spec(written).get("args", [0, ANY])
	var least: int = int(limits[0])
	var most: int = int(limits[1])
	if count < least:
		return "%s needs at least %d argument%s" % [written, least, "" if least == 1 else "s"]
	if most != ANY and count > most:
		return "%s takes at most %d argument%s" % [written, most, "" if most == 1 else "s"]
	return ""

static func function_problem(name: String, count: int) -> String:
	if not is_function(name):
		return ""
	var limits: Array = FUNCTIONS[name.to_lower()].get("args", [0, ANY])
	var least: int = int(limits[0])
	var most: int = int(limits[1])
	if count < least or (most != ANY and count > most):
		if least == most:
			return "%s() takes %d argument%s" % [name, least, "" if least == 1 else "s"]
		return "%s() takes between %d and %d arguments" % [name, least, most]
	return ""

## Returns all command names, sorted.
static func all_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for name: String in COMMANDS:
		names.append(name)
	for name: String in ALIASES:
		names.append(name)
	names.sort()
	return names

## Returns command names in a group.
static func names_in_group(group: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for name: String in COMMANDS:
		if String(COMMANDS[name].get("group", "")) == group:
			names.append(name)
	return names

## Returns all command groups.
static func groups() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for name: String in COMMANDS:
		var group: String = String(COMMANDS[name].get("group", ""))
		if not group.is_empty() and not found.has(group):
			found.append(group)
	return found
