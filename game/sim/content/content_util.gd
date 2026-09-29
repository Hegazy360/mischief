## ContentUtil — typed accessors for parsed JSON (numbers arrive as floats; ids as strings).
class_name ContentUtil
extends RefCounted


## String field (null / missing → `def`).
static func s(d: Dictionary, key: String, def: String = "") -> String:
	var v: Variant = d.get(key, null)
	if v == null:
		return def
	return str(v)


## Float field.
static func f(d: Dictionary, key: String, def: float = 0.0) -> float:
	var v: Variant = d.get(key, null)
	if v == null:
		return def
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v)
	if typeof(v) == TYPE_BOOL:
		return 1.0 if v else 0.0
	if typeof(v) == TYPE_STRING and String(v).is_valid_float():
		return String(v).to_float()
	return def


## Int field (floats rounded half away from zero).
static func i(d: Dictionary, key: String, def: int = 0) -> int:
	var v: Variant = d.get(key, null)
	if v == null:
		return def
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		return roundi(float(v))
	if typeof(v) == TYPE_BOOL:
		return 1 if v else 0
	if typeof(v) == TYPE_STRING and String(v).is_valid_int():
		return String(v).to_int()
	return def


## Bool field.
static func b(d: Dictionary, key: String, def: bool = false) -> bool:
	var v: Variant = d.get(key, null)
	if v == null:
		return def
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v) != 0.0
	return def


## Dictionary field (anything else → {}).
static func dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, null)
	return v if typeof(v) == TYPE_DICTIONARY else {}


## Array field (anything else → []).
static func arr(d: Dictionary, key: String) -> Array:
	var v: Variant = d.get(key, null)
	return v if typeof(v) == TYPE_ARRAY else []


## Array of strings (a single string becomes a 1-element array; null → empty).
static func strs(d: Dictionary, key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var v: Variant = d.get(key, null)
	if typeof(v) == TYPE_ARRAY:
		for e in v:
			if e != null:
				out.append(str(e))
	elif typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME:
		out.append(str(v))
	return out


## Sorted keys of a Dictionary as strings.
static func sorted_keys(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in d.keys():
		out.append(str(k))
	out.sort()
	return out
