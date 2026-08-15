class_name FollowerMode
## The options that a project can pick from for default Pokemon Follower behaviour
##
## This is just the vocabulary, [PokemonFollowerSettings] works out the settings and [PokemonFollowers] actually renders them
## This is part of core so it has no dependencies (other than [Loc]) so GameSettings can access it safely.

enum Mode {
	NONE = 0,
	
	## The lead party member follows the player
	LEAD = 1,
	
	## The player (or a script) chooses the follower, falls back to first when unable to resolve
	CHOSEN = 2,
	
	## A specific species is always with the player, such as Pikachu in Yellow
	## [member GameSettingsData.follow_species] and its two sibling settings allow you to adjust this
	FIXED_SPECIES = 3,
	
	## Every single party member -- Pokemon Rangers style
	WHOLE_PARTY = 4,
}

const OPTIONS_KEY: String = "follower_mode"

## Everymode, in the order the Options Screen would offer them if it's the player's choice
const ALL: Array[int] = [
	Mode.NONE, Mode.LEAD, Mode.CHOSEN, Mode.FIXED_SPECIES, Mode.WHOLE_PARTY
]

## The string version, for saving and scripts, to survive re-ordering
const NAMES: Dictionary = {
	Mode.NONE: "none",
	Mode.LEAD: "lead",
	Mode.CHOSEN: "chosen",
	Mode.FIXED_SPECIES: "species",
	Mode.WHOLE_PARTY: "party",
}

static func is_valid(mode: int) -> bool:
	return ALL.has(mode)
	
## Sanitises the mode, in case something was misspelled or wrongly written
static func sanitised(mode: int) -> bool:
	return mode if is_valid(mode) else Mode.NONE
	
## The name of the mode, for user facing display
static func label(mode: int) -> String:
	match mode:
		Mode.NONE:
			return Loc.line("Off")
		Mode.LEAD:
			return Loc.line("First Party Member")
		Mode.CHOSEN:
			return Loc.line("Selected Party Member")
		Mode.FIXED_SPECIES:
			return Loc.line("Set Species")
		Mode.WHOLE_PARTY:
			return Loc.line("Entire Party")
	return Loc.line("Off")
	
## The sentance description of the mode
static func description(mode: int) -> String:
	match mode:
		Mode.NONE:
			return Loc.line("No Pokemon walk behind you.")
		Mode.LEAD:
			return Loc.line("The first party member walks with you.")
		Mode.CHOSEN:
			return Loc.line("You may choose which party member walks with you.")
		Mode.FIXED_SPECIES:
			return Loc.line("A set Pokemon walks with you.")
		Mode.WHOLE_PARTY:
			return Loc.line("Your whole party walks behind you.")
	return Loc.line("No Pokemon walk with you")
	
## Gets the word for the [param mode]
static func to_name(mode: int) -> String:
	return String(NAMES.get(sanitised(mode), NAMES[Mode.LEAD]))
	
## The mode which corresponds to [param mode_name], or `-1` when it corresponds to none.
## Both the term and the number are accepted, so it can be called either way.
static func from_name(mode_name: String) -> int:
	var clean: String = mode_name.strip_edges().to_lower().replace(" ", "_")
	if clean.is_empty():
		return -1
	if clean.is_valid_int():
		var num: int = clean.to_int()
		return num if is_valid(num) else -1
	for mode: int in ALL:
		if String(NAMES[mode]) == clean:
			return mode
	return -1
