class_name MapEventCommands
## Names and support status of the event command numbers

const SHOW_TEXT: int = 101
const SHOW_CHOICES: int = 102
const CHOICE_BRANCH: int = 402
const CHOICE_CANCEL: int = 403
const INPUT_NUMBER: int = 103
const CHANGE_TEXT_OPTIONS: int = 104
const BUTTON_INPUT: int = 105
const WAIT: int = 106
const COMMENT: int = 108
const COMMENT_MORE: int = 408
const CONDITIONAL_BRANCH: int = 111
const ELSE_BRANCH: int = 411
const LOOP: int = 112
const BREAK_LOOP: int = 113
const EXIT_EVENT: int = 115
const ERASE_EVENT: int = 116
const CALL_COMMON_EVENT: int = 117
const LABEL: int = 118
const JUMP_TO_LABEL: int = 119
const CONTROL_SWITCHES: int = 121
const CONTROL_VARIABLES: int = 122
const CONTROL_SELF_SWITCH: int = 123
const CONTROL_TIMER: int = 124
const CHANGE_MONEY: int = 125
const CHANGE_ITEMS: int = 126
const CHANGE_PARTY: int = 129
const TRANSFER_PLAYER: int = 201
const SET_EVENT_LOCATION: int = 202
const SCROLL_MAP: int = 203
const CHANGE_MAP_SETTINGS: int = 204
const CHANGE_FOG_TONE: int = 205
const CHANGE_FOG_OPACITY: int = 206
const SHOW_ANIMATION: int = 207
const CHANGE_TRANSPARENCY: int = 208
const SET_MOVE_ROUTE: int = 209
const WAIT_FOR_MOVE: int = 210
const PREPARE_TRANSITION: int = 221
const EXECUTE_TRANSITION: int = 222
const CHANGE_SCREEN_TONE: int = 223
const SCREEN_FLASH: int = 224
const SCREEN_SHAKE: int = 225
const SHOW_PICTURE: int = 231
const MOVE_PICTURE: int = 232
const ROTATE_PICTURE: int = 233
const PICTURE_TONE: int = 234
const ERASE_PICTURE: int = 235
const SET_WEATHER: int = 236
const PLAY_BGM: int = 241
const FADE_OUT_BGM: int = 242
const PLAY_BGS: int = 245
const FADE_OUT_BGS: int = 246
const MEMORIZE_BGM_BGS: int = 247
const RESTORE_BGM_BGS: int = 248
const PLAY_ME: int = 249
const PLAY_SE: int = 250
const STOP_SE: int = 251
const RECOVER_ALL: int = 314
const RETURN_TO_TITLE: int = 354
const SCRIPT: int = 355
const SCRIPT_MORE: int = 655
const CONTINUE_TEXT: int = 401

## Structural markers they carry no behaviour of their own
const END_CHOICES: int = 404
const END_BRANCH: int = 412
const REPEAT_ABOVE: int = 413
const MOVE_ROUTE_STEP: int = 509

## Commands [EventInterpreter] executes.
const SUPPORTED: Array[int] = [
	SHOW_TEXT, CONTINUE_TEXT, SHOW_CHOICES, CHOICE_BRANCH, CHOICE_CANCEL,
	CHANGE_TEXT_OPTIONS, WAIT, COMMENT, COMMENT_MORE, CONDITIONAL_BRANCH,
	ELSE_BRANCH, LOOP, BREAK_LOOP, EXIT_EVENT, ERASE_EVENT, CALL_COMMON_EVENT,
	LABEL, JUMP_TO_LABEL, CONTROL_SWITCHES, CONTROL_VARIABLES,
	CONTROL_SELF_SWITCH, CONTROL_TIMER, CHANGE_MONEY, CHANGE_ITEMS, CHANGE_PARTY,
	TRANSFER_PLAYER, SET_EVENT_LOCATION, SCROLL_MAP, CHANGE_MAP_SETTINGS,
	CHANGE_FOG_TONE, CHANGE_FOG_OPACITY, SHOW_ANIMATION,
	CHANGE_TRANSPARENCY, SET_MOVE_ROUTE, WAIT_FOR_MOVE, PREPARE_TRANSITION,
	EXECUTE_TRANSITION, CHANGE_SCREEN_TONE, SCREEN_FLASH, SCREEN_SHAKE,
	SHOW_PICTURE, MOVE_PICTURE, ROTATE_PICTURE, PICTURE_TONE, ERASE_PICTURE,
	SET_WEATHER, PLAY_BGM, FADE_OUT_BGM, PLAY_BGS, FADE_OUT_BGS,
	MEMORIZE_BGM_BGS, RESTORE_BGM_BGS, PLAY_ME,
	PLAY_SE, STOP_SE, RECOVER_ALL, RETURN_TO_TITLE, SCRIPT, SCRIPT_MORE,
	BUTTON_INPUT, INPUT_NUMBER,
	END_CHOICES, END_BRANCH, REPEAT_ABOVE, MOVE_ROUTE_STEP,
]

const NAMES: Dictionary = {
	SHOW_TEXT: "ShowText", CONTINUE_TEXT: "ContinueText", SHOW_CHOICES: "ShowChoices",
	CHOICE_BRANCH: "ChoiceBranch", CHOICE_CANCEL: "ChoiceCancel",
	INPUT_NUMBER: "InputNumber", CHANGE_TEXT_OPTIONS: "ChangeTextOptions",
	BUTTON_INPUT: "ButtonInput", WAIT: "Wait", COMMENT: "Comment",
	COMMENT_MORE: "CommentMore", CONDITIONAL_BRANCH: "ConditionalBranch",
	ELSE_BRANCH: "Else", LOOP: "Loop", BREAK_LOOP: "BreakLoop",
	EXIT_EVENT: "ExitEvent", ERASE_EVENT: "EraseEvent",
	CALL_COMMON_EVENT: "CallCommonEvent", LABEL: "Label",
	JUMP_TO_LABEL: "JumpToLabel", CONTROL_SWITCHES: "ControlSwitches",
	CONTROL_VARIABLES: "ControlVariables", CONTROL_SELF_SWITCH: "ControlSelfSwitch",
	CONTROL_TIMER: "ControlTimer", CHANGE_MONEY: "ChangeMoney",
	CHANGE_ITEMS: "ChangeItems", CHANGE_PARTY: "ChangeParty",
	TRANSFER_PLAYER: "TransferPlayer", SET_EVENT_LOCATION: "SetEventLocation",
	SCROLL_MAP: "ScrollMap", CHANGE_MAP_SETTINGS: "ChangeMapSettings",
	CHANGE_FOG_TONE: "ChangeFogTone",
	CHANGE_FOG_OPACITY: "ChangeFogOpacity", SHOW_ANIMATION: "ShowAnimation",
	CHANGE_TRANSPARENCY: "ChangeTransparency", SET_MOVE_ROUTE: "SetMoveRoute",
	WAIT_FOR_MOVE: "WaitForMove", PREPARE_TRANSITION: "PrepareTransition",
	EXECUTE_TRANSITION: "ExecuteTransition", CHANGE_SCREEN_TONE: "ChangeScreenTone",
	SCREEN_FLASH: "ScreenFlash", SCREEN_SHAKE: "ScreenShake",
	SHOW_PICTURE: "ShowPicture", MOVE_PICTURE: "MovePicture",
	ROTATE_PICTURE: "RotatePicture", PICTURE_TONE: "PictureTone",
	ERASE_PICTURE: "ErasePicture", SET_WEATHER: "SetWeather",
	PLAY_BGM: "PlayBGM", FADE_OUT_BGM: "FadeOutBGM", PLAY_BGS: "PlayBGS",
	FADE_OUT_BGS: "FadeOutBGS", MEMORIZE_BGM_BGS: "MemorizeBGMBGS",
	RESTORE_BGM_BGS: "RestoreBGMBGS", PLAY_ME: "PlayME", PLAY_SE: "PlaySE",
	STOP_SE: "StopSE", RECOVER_ALL: "RecoverAll", RETURN_TO_TITLE: "ReturnToTitle",
	SCRIPT: "Script", SCRIPT_MORE: "ScriptMore",
	END_CHOICES: "EndChoices", END_BRANCH: "EndBranch",
	REPEAT_ABOVE: "RepeatAbove", MOVE_ROUTE_STEP: "MoveRouteStep",
}

## Move route command numbers used inside [constant SET_MOVE_ROUTE].
const MOVE_DOWN: int = 1
const MOVE_LEFT: int = 2
const MOVE_RIGHT: int = 3
const MOVE_UP: int = 4
const MOVE_LOWER_LEFT: int = 5
const MOVE_LOWER_RIGHT: int = 6
const MOVE_UPPER_LEFT: int = 7
const MOVE_UPPER_RIGHT: int = 8
const MOVE_RANDOM: int = 9
const MOVE_TOWARD_PLAYER: int = 10
const MOVE_AWAY_FROM_PLAYER: int = 11
const MOVE_FORWARD: int = 12
const MOVE_BACKWARD: int = 13
const JUMP: int = 14
const WAIT_FRAMES: int = 15
const TURN_DOWN: int = 16
const TURN_LEFT: int = 17
const TURN_RIGHT: int = 18
const TURN_UP: int = 19
const TURN_RIGHT_90: int = 20
const TURN_LEFT_90: int = 21
const TURN_180: int = 22
const TURN_RANDOM: int = 24
const TURN_TOWARD_PLAYER: int = 25
const TURN_AWAY_FROM_PLAYER: int = 26
const CHANGE_SPEED: int = 29
const CHANGE_FREQUENCY: int = 30
const WALK_ANIME_ON: int = 31
const WALK_ANIME_OFF: int = 32
const STEP_ANIME_ON: int = 33
const STEP_ANIME_OFF: int = 34
const DIRECTION_FIX_ON: int = 35
const DIRECTION_FIX_OFF: int = 36
const THROUGH_ON: int = 37
const THROUGH_OFF: int = 38
const ALWAYS_ON_TOP_ON: int = 39
const ALWAYS_ON_TOP_OFF: int = 40
const CHANGE_GRAPHIC: int = 41
const CHANGE_OPACITY: int = 42
const CHANGE_BLENDING: int = 43
## Play SE from inside a move route
const MOVE_ROUTE_PLAY_SE: int = 44
const MOVE_ROUTE_SCRIPT: int = 45

## Move route commands number themselves from one and share those numbers with the commands above,
## Therefore they need to be named and counted seperately.
const MOVE_ROUTE_NAMES: Dictionary = {
	MOVE_DOWN: "MoveDown", MOVE_LEFT: "MoveLeft", MOVE_RIGHT: "MoveRight",
	MOVE_UP: "MoveUp", MOVE_LOWER_LEFT: "MoveLowerLeft",
	MOVE_LOWER_RIGHT: "MoveLowerRight", MOVE_UPPER_LEFT: "MoveUpperLeft",
	MOVE_UPPER_RIGHT: "MoveUpperRight", MOVE_RANDOM: "MoveRandom",
	MOVE_TOWARD_PLAYER: "MoveTowardPlayer",
	MOVE_AWAY_FROM_PLAYER: "MoveAwayFromPlayer", MOVE_FORWARD: "MoveForward",
	MOVE_BACKWARD: "MoveBackward", JUMP: "Jump", WAIT_FRAMES: "WaitFrames",
	TURN_DOWN: "TurnDown", TURN_LEFT: "TurnLeft", TURN_RIGHT: "TurnRight",
	TURN_UP: "TurnUp", TURN_RIGHT_90: "TurnRight90", TURN_LEFT_90: "TurnLeft90",
	TURN_180: "Turn180", TURN_RANDOM: "TurnRandom",
	TURN_TOWARD_PLAYER: "TurnTowardPlayer",
	TURN_AWAY_FROM_PLAYER: "TurnAwayFromPlayer", CHANGE_SPEED: "ChangeSpeed",
	CHANGE_FREQUENCY: "ChangeFrequency", WALK_ANIME_ON: "WalkAnimeOn",
	WALK_ANIME_OFF: "WalkAnimeOff", STEP_ANIME_ON: "StepAnimeOn",
	STEP_ANIME_OFF: "StepAnimeOff", DIRECTION_FIX_ON: "DirectionFixOn",
	DIRECTION_FIX_OFF: "DirectionFixOff", THROUGH_ON: "ThroughOn",
	THROUGH_OFF: "ThroughOff", ALWAYS_ON_TOP_ON: "AlwaysOnTopOn",
	ALWAYS_ON_TOP_OFF: "AlwaysOnTopOff", CHANGE_GRAPHIC: "ChangeGraphic",
	CHANGE_OPACITY: "ChangeOpacity", CHANGE_BLENDING: "ChangeBlending",
	MOVE_ROUTE_PLAY_SE: "MoveRoutePlaySE", MOVE_ROUTE_SCRIPT: "MoveRouteScript",
}

## Move route commands [EventInterpreter] executes.
const MOVE_ROUTE_SUPPORTED: Array[int] = [
	MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_LOWER_LEFT,
	MOVE_LOWER_RIGHT, MOVE_UPPER_LEFT, MOVE_UPPER_RIGHT, MOVE_RANDOM,
	MOVE_TOWARD_PLAYER, MOVE_AWAY_FROM_PLAYER, MOVE_FORWARD, MOVE_BACKWARD,
	JUMP, WAIT_FRAMES, TURN_DOWN, TURN_LEFT, TURN_RIGHT, TURN_UP,
	TURN_RIGHT_90, TURN_LEFT_90, TURN_180, TURN_RANDOM, TURN_TOWARD_PLAYER,
	TURN_AWAY_FROM_PLAYER, CHANGE_SPEED, CHANGE_FREQUENCY, WALK_ANIME_ON,
	WALK_ANIME_OFF, STEP_ANIME_ON, STEP_ANIME_OFF, DIRECTION_FIX_ON,
	DIRECTION_FIX_OFF, THROUGH_ON, THROUGH_OFF, ALWAYS_ON_TOP_ON,
	ALWAYS_ON_TOP_OFF, CHANGE_GRAPHIC, CHANGE_OPACITY, CHANGE_BLENDING,
	MOVE_ROUTE_PLAY_SE, MOVE_ROUTE_SCRIPT,
]


static func name_for(code: int) -> String:
	return NAMES.get(code, "Command%d" % code)

static func is_supported(code: int) -> bool:
	return SUPPORTED.has(code)

static func move_route_name_for(code: int) -> String:
	return MOVE_ROUTE_NAMES.get(code, "MoveRouteCommand%d" % code)

static func is_move_route_supported(code: int) -> bool:
	return MOVE_ROUTE_SUPPORTED.has(code)
