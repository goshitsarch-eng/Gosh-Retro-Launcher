class_name Jsonx
extends RefCounted
## JSON-model helpers. All persisted data is plain Dictionary/Array/String/float/bool
## (the same shape electron-store wrote), so JS-compatible number handling lives here.


static func is_num(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func is_num_any(value: Variant) -> bool:
	## typeof number, finite or not (JS `typeof x === 'number'`).
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func finite(value: Variant, fallback: float) -> float:
	return float(value) if is_num(value) else fallback


static func is_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and floorf(value) == value


static func is_obj(value: Variant) -> bool:
	return typeof(value) == TYPE_DICTIONARY


static func is_str(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME


static func is_bool(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL


static func is_arr(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY


static func clone(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value


## Recursively turns whole-number floats into ints so JSON text matches what
## JavaScript would have written ("1" not "1.0"). NaN/Inf become null like JSON.stringify.
static func clean(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			if not is_finite(value):
				return null
			if floorf(value) == value and absf(value) < 9.0e15:
				return int(value)
			return value
		TYPE_DICTIONARY:
			var out := {}
			for k in value:
				out[str(k)] = clean(value[k])
			return out
		TYPE_ARRAY:
			var arr := []
			for v in value:
				arr.append(clean(v))
			return arr
		TYPE_STRING_NAME:
			return str(value)
		_:
			return value


static func stringify(value: Variant, indent: String = "  ") -> String:
	return JSON.stringify(clean(value), indent)


## Key-sorted canonical text, used by tests and equality helpers.
static func canon(value: Variant) -> String:
	return JSON.stringify(clean(value), "", true)


static func equal(a: Variant, b: Variant) -> bool:
	return canon(a) == canon(b)


static func parse(text: String) -> Variant:
	## Returns null on failure (JS JSON.parse would throw).
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


static func parse_checked(text: String) -> Array:
	## [ok, data]
	var json := JSON.new()
	if json.parse(text) != OK:
		return [false, null]
	return [true, json.data]
