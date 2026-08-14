extends Node
## Manages a central RNG stream, registered as the `RNG` Autoload
## 
## By keeping all rng behind a seeded generator a save file can record its seed and debug sessions can 
## reproduce a battle exactly.
## Systems that need independent streams such as map generation call [method make_stream] instead of using 
## [RandomNumberGenerator] directly.

var generator: RandomNumberGenerator = RandomNumberGenerator.new()

## This stream is for deciding rathre than for resolving
## used for things like AI move and Pokemon selection
## This allows battles to be recorded without shift
var decisions: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	generator.randomize()
	decisions.randomize()
	
## Reseeds the shared generator.
## [param new_seed] set to `0` will pick a fresh random seed.
func set_seed(new_seed: int) -> void:
	if new_seed == 0:
		generator.randomize()
	else:
		generator.seed = new_seed
	decisions.seed = generator.seed ^ 0x5f3759df
	
func get_seed() -> int:
	return generator.seed
	
## Where the generator is in the sequence
## A seed says which sequence the numbers are from, while a state says how far along it the next one is.
## Battle recordings need both pieces of information to properly replay
func get_state() -> int:
	return generator.state
	
func set_state(new_state: int) -> void:
	generator.state = new_state
	
# === Decision Random Helpers ===
	
## Random integer from the decision stream - Inclusive
func decide_range_int(from: int, to: int) -> int:
	if to <= from:
		return from
	return decisions.randi_range(from, to)
	
## Returns `true` if the percentage chance rolled, from the decision stream
func decide_percent(value: int) -> bool:
	if value <= 0:
		return false
	return decisions.randi_range(1, 100) <= value

# === Random Helpers ===

## Creates a unique generator from [param stream_name], which allows subsystems to isolate
func make_stream(stream_name: StringName, extra_seed: int = 0) -> RandomNumberGenerator:
	var stream: RandomNumberGenerator = RandomNumberGenerator.new()
	stream.seed = hash(String(stream_name)) ^ generator.seed ^ extra_seed
	return stream

## Inclusive random integer	
func range_int(from: int, to: int) -> int:
	if to <= from:
		return from
	return generator.randi_range(from, to)
	
## Random integer in `[0, bound]`
func below(bound: int) -> int:
	if bound <= 1:
		return 0
	return generator.randi_range(0, bound - 1)
	
## Returns `true` wiht a [param numerator] in [param denominator] chance
func chance(numerator: int, denominator: int) -> bool:
	if numerator <= 0 or denominator <= 0:
		return false
	return generator.randi_range(1, denominator) <= numerator
	
## Returns `true` at a percentage chance
func percent(value: int) -> bool:
	return chance(value, 100)
	
## Returns a random selection from [param items]
## Returns `null` if [param items] is empty
func pick(items: Array) -> Variant:
	if items.is_empty():
		return
	return items[below(items.size())]
	
## Shuffles [param items] and then returns it in that random order
func shuffled(items: Array) -> Array:
	var copy: Array = items.duplicate()
	for i: int in range(copy.size() - 1, 0, -1):
		var j: int = generator.randi_range(0, i)
		var swap: Variant = copy[i]
		copy[i] = copy[j]
		copy[j] = swap
	return copy
