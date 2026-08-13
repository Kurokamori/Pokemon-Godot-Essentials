class_name DictRead
extends RefCounted

## Typed readers for `Dictionary` values save data.
## 
## `Dictionary.get()` hands back a `Variant`
## This centralizes the widening once so it doesn't cost a static type at every call.

## [param key] stored as an `int` or [param fallback] when it is missing or can't be read as a number.
static func read_int(source: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = source.get(key, fallback)
	match typeof(value):
		TYPE_INT:
			var as_integer: int = value
			return as_integer
		TYPE_FLOAT:
			var as_float: float = value
			return int(as_float)
		TYPE_BOOL:
			var as_boolean: bool = value
			return 1 if as_boolean else 0
	return fallback
	
## [param key] value stored as a `float` or [param fallback] when it is missing or can't ber read as a number.
static func read_float(source: Dictionary, key: String, fallback: float = 0.0) -> float:
	var value: Variant = source.get(key, fallback)
	match typeof(value):
		TYPE_FLOAT:
			var as_float: float = value
			return as_float
		TYPE_INT:
			var as_int: int = value
			return float(as_int)
		TYPE_BOOL:
			var as_bool: bool = value
			return 1.0 if as_bool else 0.0
	return fallback
	
## [param key] value stored as a `bool`. 
## Numbers count as `true` when they're non-zero.
static func read_bool(source: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = source.get(key)
	match typeof(value):
		TYPE_BOOL:
			var as_bool: bool = value
			return as_bool
		TYPE_INT:
			var as_integer: int = value
			return as_integer != 0
		TYPE_FLOAT:
			var as_float: float = value
			return not is_zero_approx(as_float)
	return fallback
	
## [param key] value stored as a `String` or [param fallback] when it's missing or not text.
static func read_string(source: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = source.get(key)
	match typeof(value):
		TYPE_STRING:
			var as_str: String = value
			return as_str
		TYPE_STRING_NAME:
			var as_name: StringName = value
			return String(as_name)
	return fallback
	
## [param key] value stored as a `StringName` or [param fallback] when it's missing or not text.
static func read_string_name(source: Dictionary, key: String, fallback: StringName = &"") -> StringName:
	var value: Variant = source.get(key)
	match typeof(value):
		TYPE_STRING_NAME:
			var as_name: StringName = value
			return as_name
		TYPE_STRING:
			var as_str: String = value
			return StringName(as_str)
	return fallback
	
## [param key] value stored as a `Dictionary` or empty when not parsable as a Dictionary.
static func read_dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var as_dictionary: Dictionary = value
	return as_dictionary
	
## [param key] as an untyped Array or [param fallback] when missing or another type.
## PackedArrays are widened, so they can survive binary saves.
static func read_array(source: Dictionary, key: String, fallback: Array = []) -> Array:
	var value: Variant = source.get(key)
	if not (value is Array or value is PackedInt32Array or value is PackedStringArray or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedByteArray):
		return fallback
	var result: Array = []
	for entry: Variant in value:
		result.append(entry)
	return result
	
## [param key] as a `PackedInt32Array` or [param fallback] when missing or not a number list.
static func read_int_array(source: Dictionary, key: String, fallback: PackedInt32Array = PackedInt32Array()) -> PackedInt32Array:
	var value: Variant = source.get(key, fallback)
	if typeof(value) == TYPE_PACKED_INT32_ARRAY:
		var as_packed: PackedInt32Array = value
		return as_packed
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var as_array: Array = value
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(as_array.size())
	for index: int in as_array.size():
		var entry: Variant = as_array[index]
		match typeof(entry):
			TYPE_INT:
				var as_int: int = entry
				result[index] = as_int
			TYPE_FLOAT:
				var as_float: float = entry
				result[index] = int(as_float)
			_:
				result[index] = 0
	return result
	
## [param value] as a `Dictionary` for the elements of a list of resources
static func as_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var as_dict: Dictionary = value
	return as_dict
	
## [param value] as a `StringName` used for the elements of a list of IDs
static func as_string_name(value: Variant) -> StringName:
	match typeof(value):
		TYPE_STRING_NAME:
			var as_name: StringName = value
			return as_name
		TYPE_STRING:
			var as_string: String = value
			return StringName(as_string)
	return &""
	
## [param value] as a `bool` for the elements in a list of flags.
static func as_bool(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			var as_bool: bool = value
			return as_bool
		TYPE_INT:
			var as_int: int = value
			return as_int != 0
		TYPE_FLOAT:
			var as_flaot: float = value
			return not is_zero_approx(as_flaot)
	return false
	
## [param value] as an `int` for elements of a list of numbers
static func as_int(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			var as_integer: int = value
			return as_integer
		TYPE_FLOAT:
			var as_float: float = value
			return int(as_float)
		TYPE_BOOL:
			var as_bool: bool = value
			return 1 if as_bool else 0
	return 0
