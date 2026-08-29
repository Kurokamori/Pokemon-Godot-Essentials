class_name BattleEffects
## Names of the volatile effects tracked on battlers, sides, and the field.
##
## Effects are stored in a dictionary keyed by these names
## The value is an `int` counter unless noted otherwise, `0` means inactive

# === Battler Effects ===

const AQUA_RING: StringName = &"AquaRing"
const ATTRACT: StringName = &"Attract"
const BEAK_BLAST: StringName = &"BeakBlast"
const BIDE: StringName = &"Bide"
const BIDE_DAMAGE: StringName = &"BideDamage"
const BIDE_TARGET: StringName = &"BideTarget"
const CHARGE: StringName = &"Charge"
const CONFUSION: StringName = &"Confusion"
const CURSE: StringName = &"Curse"
const DEFENSE_CURL: StringName = &"DefenseCurl"
const DESTINY_BOND: StringName = &"DestinyBond"
const DISABLE: StringName = &"Disable"
const DISABLE_MOVE: StringName = &"DisableMove"
const ELECTRIFY: StringName = &"Electrify"
const EMBARGO: StringName = &"Embargo"
const ENCORE: StringName = &"Encore"
const ENCORE_MOVE: StringName = &"EncoreMove"
const ENDURE: StringName = &"Endure"

## Function code of the Pledge move an ally set up, waiting to be combined.
const FIRST_PLEDGE: StringName = &"FirstPledge"
const FLINCH: StringName = &"Flinch"
const FOCUS_ENERGY: StringName = &"FocusEnergy"

## `true` while Focus Punch is armed, so being hit cancels it
const FOCUS_PUNCH: StringName = &"FocusPunch"
const FOLLOW_ME: StringName = &"FollowMe"

## Rounds a Safari Zone Pokemon spends eating thrown bait, during which it does not leave.
const SAFARI_EATING: StringName = &"SafariEating"

## Rounds a Safari Zone Pokemon spends angry about a thrown rock
const SAFARI_ANGRY: StringName = &"SafariAngry"

const FORESIGHT: StringName = &"Foresight"
const GRUDGE: StringName = &"Grudge"
const HEAL_BLOCK: StringName = &"HealBlock"
const HELPING_HAND: StringName = &"HelpingHand"
const IMPRISON: StringName = &"Imprison"
const INGRAIN: StringName = &"Ingrain"
const INSTRUCT: StringName = &"Instruct"
const INSTRUCTED: StringName = &"Instructed"
const LASER_FOCUS: StringName = &"LaserFocus"
const LEECH_SEED: StringName = &"LeechSeed"
const LOCK_ON: StringName = &"LockOn"
const LOCK_ON_TARGET: StringName = &"LockOnTarget"
const MAGIC_COAT: StringName = &"MagicCoat"
const MAGNET_RISE: StringName = &"MagnetRise"
const MEAN_LOOK: StringName = &"MeanLook"

## `true` while Me First is copying the target's move, which powers it up.
const ME_FIRST: StringName = &"MeFirst"
const MINIMIZE: StringName = &"Minimize"
const MIRACLE_EYE: StringName = &"MiracleEye"
const MOVE_LOCK: StringName = &"MoveLock"

## `true` when After You or a Shell Trap moves this battler to the front of the acting order.
const MOVE_NEXT: StringName = &"MoveNext"
const MULTI_TURN_ATTACK: StringName = &"MultiTurnAttack"
const NIGHTMARE: StringName = &"Nightmare"
const OUTRAGE: StringName = &"Outrage"
const PERISH_SONG: StringName = &"PerishSong"
const POWDER: StringName = &"Powder"
const POWER_TRICK: StringName = &"PowerTrick"
const PROTECT: StringName = &"Protect"
const PROTECT_RATE: StringName = &"ProtectRate"
const QUASH: StringName = &"Quash"
const RAGE: StringName = &"Rage"
const ROLLOUT: StringName = &"Rollout"
const ROOST: StringName = &"Roost"
const SHELL_TRAP: StringName = &"ShellTrap"
const SMACK_DOWN: StringName = &"SmackDown"
const SNATCH: StringName = &"Snatch"
const SPOTLIGHT: StringName = &"Spotlight"
const STOCKPILE: StringName = &"Stockpile"

## Defence stages gained through Stockpile, given back by Spit Up and Swallow.
const STOCKPILE_DEFENSE: StringName = &"StockpileDefense"
const STOCKPILE_SPECIAL_DEFENSE: StringName = &"StockpileSpecialDefense"
const SUBSTITUTE: StringName = &"Substitute"
const TAUNT: StringName = &"Taunt"
const TELEKINESIS: StringName = &"Telekinesis"
const THROAT_CHOP: StringName = &"ThroatChop"
const TORMENT: StringName = &"Torment"
const TOXIC_COUNTER: StringName = &"ToxicCounter"
const TRANSFORM: StringName = &"Transform"
const TRAPPING: StringName = &"Trapping"
const TRAPPING_USER: StringName = &"TrappingUser"
const TWO_TURN_ATTACK: StringName = &"TwoTurnAttack"
const UPROAR: StringName = &"Uproar"
const YAWN: StringName = &"Yawn"

## Semi-invulnerable state such as Fly or Dig, stored as the move's id
const INVULNERABLE: StringName = &"Invulnerable"

# === Side Effects ===
const AURORA_VEIL: StringName = &"AuroraVeil"
const LIGHT_SCREEN: StringName = &"LightScreen"
const REFLECT: StringName = &"Reflect"
const LUCKY_CHANT: StringName = &"LuckyChant"
const MIST: StringName = &"Mist"
const SAFEGUARD: StringName = &"Safeguard"
const SPIKES: StringName = &"Spikes"
const STEALTH_ROCK: StringName = &"StealthRock"
const STICKY_WEB: StringName = &"StickyWeb"
const TAILWIND: StringName = &"Tailwind"
const TOXIC_SPIKES: StringName = &"ToxicSpikes"
const WIDE_GUARD: StringName = &"WideGuard"
const QUICK_GUARD: StringName = &"QuickGuard"
const CRAFTY_SHIELD: StringName = &"CraftyShield"
const MAT_BLOCK: StringName = &"MatBlock"
const RAINBOW: StringName = &"Rainbow"
const SEA_OF_FIRE: StringName = &"SeaOfFire"
const SWAMP: StringName = &"Swamp"

## How many consecutive rounds Echoed Voice has been used on this side, 1 to 5.
const ECHOED_VOICE_COUNTER: StringName = &"EchoedVoiceCounter"

## `true` when Echoed Voice was used on this side this round.
const ECHOED_VOICE_USED: StringName = &"EchoedVoiceUsed"

## `true` once Round has been used on this side this round, doubling the power of the next Round.
const ROUND: StringName = &"Round"

# === Field Effects ===
const GRAVITY: StringName = &"Gravity"
const MAGIC_ROOM: StringName = &"MagicRoom"
const TRICK_ROOM: StringName = &"TrickRoom"
const WONDER_ROOM: StringName = &"WonderRoom"
const FAIRY_LOCK: StringName = &"FairyLock"
const ION_DELUGE: StringName = &"IonDeluge"
const MUD_SPORT: StringName = &"MudSport"
const WATER_SPORT: StringName = &"WaterSport"

## Set `true` for the rest of the round after Fusion Bolt hits
const FUSION_BOLT: StringName = &"FusionBolt"

## Set `true` for the rest of the round after Fusion Bolt hits
const FUSION_FLARE: StringName = &"FusionFlare"

# === Position Effects ===

## Effects held by a battle position rather than by the battler in it

const WISH_COUNTER: StringName = &"WishCounter"
const WISH_AMOUNT: StringName = &"WishAmount"
const WISH_MAKER: StringName = &"WishMaker"

const FUTURE_SIGHT_COUNTER: StringName = &"FutureSightCounter"
const FUTURE_SIGHT_MOVE: StringName = &"FutureSightMove"
const FUTURE_SIGHT_USER_INDEX: StringName = &"FutureSightUserIndex"
const FUTURE_SIGHT_USER_PARTY_INDEX: StringName = &"FutureSightUserPartyIndex"

# === Bookkeeping ===

## Battler effects whose integer value is not a turn counter
const UNTIMED: Array[StringName] = [
	ATTRACT, BIDE, BIDE_DAMAGE, BIDE_TARGET, CONFUSION,
	LEECH_SEED, LOCK_ON_TARGET, OUTRAGE, PERISH_SONG, POWER_TRICK,
	PROTECT_RATE, QUASH, ROLLOUT, SPOTLIGHT, STOCKPILE, STOCKPILE_DEFENSE,
	STOCKPILE_SPECIAL_DEFENSE, SUBSTITUTE, TOXIC_COUNTER, TRAPPING_USER,
]
