class_name EventScriptCast
## Converts event script values to the types commands expect.

## Converts a value to message text.
static func to_text(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return ""
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_FLOAT:
			var number: float = float(value)
			return str(int(number)) if is_equal_approx(number, roundf(number)) else str(number)
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var written: PackedStringArray = PackedStringArray()
			for item: Variant in value:
				written.append(to_text(item))
			return ", ".join(written)
	return str(value)

static func to_number(value: Variant) -> float:
	match typeof(value):
		TYPE_BOOL:
			return 1.0 if value else 0.0
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value).to_float()
	return 0.0

## Converts a value to a condition.
static func to_bool(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return not is_zero_approx(float(value))
		TYPE_STRING, TYPE_STRING_NAME:
			return not String(value).is_empty()
		TYPE_ARRAY:
			return not (value as Array).is_empty()
	return value != null

## Converts a value to a database id.
static func to_id(value: Variant) -> StringName:
	return StringName(to_text(value).strip_edges().to_upper())

## Compares two values.
static func equal(left: Variant, right: Variant) -> bool:
	if left == null or right == null:
		return left == right
	var left_kind: int = typeof(left)
	var right_kind: int = typeof(right)
	var left_numeric: bool = left_kind == TYPE_INT or left_kind == TYPE_FLOAT
	var right_numeric: bool = right_kind == TYPE_INT or right_kind == TYPE_FLOAT
	if left_numeric and right_numeric:
		return is_equal_approx(to_number(left), to_number(right))
	if left_kind == TYPE_BOOL or right_kind == TYPE_BOOL:
		return to_bool(left) == to_bool(right)
	if left_numeric != right_numeric:
		# Only compare a number with a numeric name.
		var written: String = to_text(right if left_numeric else left)
		if not written.is_valid_float():
			return false
		return is_equal_approx(to_number(left), to_number(right))
	return to_text(left) == to_text(right)
