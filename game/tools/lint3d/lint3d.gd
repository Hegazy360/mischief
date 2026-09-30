## Lint3D — the shared record and report helpers of the REDESIGN §6.3 lints (`game/tools/lint3d/`, owner
## `r3d-tools-b`; index §6 rows 9–12 and 16, TECH §10.5).
##
## Every rule of every lint produces **issues**: `{lint, rule, level, night, room, subject, value, limit, owner,
## detail}` with `level` ∈ `error | warning | info | skip`. An error fails the lint; a warning never does (the
## Bellows-window share, R15); a skip (`SKIP <rule>: <what is missing> (<owner>)`) fails only under `--strict`
## (the pre-gate, index §3.5 rule 2). `report()` folds a list of issues into the JSON every `lint3d.sh` mode writes.
class_name Lint3D
extends RefCounted

const ERROR := "error"
const WARNING := "warning"
const INFO := "info"
const SKIP := "skip"

## The final Nights the §6.3 lints cover (+ Gate 0), in play order.
const NIGHTS: PackedStringArray = ["g0_sneeze", "p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]
## Short labels for boards and status rows.
const NIGHT_LABEL := {"g0_sneeze": "g0", "p00_curtain_up": "P00", "n01_throat_tea": "N01", "n02_something_fishy": "N02"}


## One issue record (see the class doc). `value` / `limit` are the measured number and the threshold (any JSON value).
static func issue(lint: String, rule: String, level: String, night: String, room: String, subject: String,
		value: Variant, limit: Variant, owner: String, detail: String = "") -> Dictionary:
	return {"lint": lint, "rule": rule, "level": level, "night": night, "room": room, "subject": subject,
		"value": value, "limit": limit, "owner": owner, "detail": detail}


## A SKIP issue: the rule's input is missing (`what`, built by `owner`).
static func skip(lint: String, rule: String, what: String, owner: String, night: String = "", room: String = "") -> Dictionary:
	return issue(lint, rule, SKIP, night, room, "", null, null, owner, what)


## The label of a Night id (P00, N01 …).
static func label(night: String) -> String:
	return String(NIGHT_LABEL.get(night, night))


## Counts per level of `issues`.
static func counts(issues: Array) -> Dictionary:
	var c := {ERROR: 0, WARNING: 0, INFO: 0, SKIP: 0}
	for i in issues:
		var lv := String((i as Dictionary).get("level", INFO))
		c[lv] = int(c.get(lv, 0)) + 1
	return c


## True when `issues` fail: any error, or (strict) any skip. Warnings never fail.
static func failed(issues: Array, strict: bool) -> bool:
	var c := counts(issues)
	return int(c[ERROR]) > 0 or (strict and int(c[SKIP]) > 0)


## The issues of one level.
static func of_level(issues: Array, level: String) -> Array:
	var out: Array = []
	for i in issues:
		if String((i as Dictionary).get("level", "")) == level:
			out.append(i)
	return out


## One printable line: `ERROR set/live_count P00 kitchen kitchen_honey: 6 > 5 (r3d-content) — …`.
static func line(i: Dictionary) -> String:
	var lv := String(i.get("level", INFO))
	if lv == SKIP:
		return "SKIP %s/%s: %s (%s)" % [i.get("lint", ""), i.get("rule", ""), i.get("detail", ""), i.get("owner", "")]
	var where := PackedStringArray()
	for k in ["night", "room", "subject"]:
		var s := String(i.get(k, ""))
		if s != "":
			where.append(label(s) if k == "night" else s)
	var val := "" if i.get("value", null) == null else "%s" % fmt(i["value"])
	var lim := "" if i.get("limit", null) == null else " (limit %s)" % fmt(i["limit"])
	var det := String(i.get("detail", ""))
	return "%s %s/%s %s: %s%s [%s]%s" % [lv.to_upper(), i.get("lint", ""), i.get("rule", ""), " ".join(where), val, lim,
		i.get("owner", ""), (" — " + det) if det != "" else ""]


## A compact value string (floats to 2 decimals, arrays joined).
static func fmt(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT:
			return str(snappedf(float(v), 0.01))
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for e in v:
				parts.append(fmt(e))
			return "[" + ", ".join(parts) + "]"
		TYPE_VECTOR2:
			return "%s×%s" % [snappedf((v as Vector2).x, 0.1), snappedf((v as Vector2).y, 0.1)]
		TYPE_RECT2:
			var r: Rect2 = v
			return "[%s, %s, %s×%s]" % [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1),
				snappedf(r.size.y, 0.1)]
	return str(v)


## The JSON report of one lint mode: {lint, strict, pass, counts, issues, results}.
static func report(lint: String, issues: Array, results: Dictionary, strict: bool) -> Dictionary:
	return {"lint": lint, "strict": strict, "pass": not failed(issues, strict), "counts": counts(issues),
		"issues": issues, "results": results}


## Prints every non-info issue (info too when `verbose`) and a one-line summary; returns the summary.
static func print_issues(lint: String, issues: Array, strict: bool, verbose: bool = false) -> String:
	for i in issues:
		var d: Dictionary = i
		if d.get("level", "") == INFO and not verbose:
			continue
		print("[lint3d] " + line(d))
	var c := counts(issues)
	var s := "[lint3d] %s: %s — %d error(s), %d warning(s), %d skip(s), %d info" % [lint,
		"FAIL" if failed(issues, strict) else "OK", c[ERROR], c[WARNING], c[SKIP], c[INFO]]
	print(s)
	return s


## Writes `data` as pretty JSON to an absolute path (creates the folder). False on failure.
static func write_json(path: String, data: Variant) -> bool:
	if path == "":
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Lint3D: cannot write %s" % path)
		return false
	f.store_string(JSON.stringify(to_json(data), "  "))
	f.close()
	return true


## Reads a JSON file (null when missing or malformed).
static func read_json(path: String) -> Variant:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("Lint3D: %s:%d %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data


## Converts Godot values (Rect2, Vector2/3, AABB, packed arrays, StringName) into JSON-safe values, recursively.
static func to_json(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out := {}
			for k in (v as Dictionary).keys():
				out[str(k)] = to_json(v[k])
			return out
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
				TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			var arr: Array = []
			for e in v:
				arr.append(to_json(e))
			return arr
		TYPE_RECT2:
			var r: Rect2 = v
			return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]
		TYPE_VECTOR2:
			return [snappedf((v as Vector2).x, 0.001), snappedf((v as Vector2).y, 0.001)]
		TYPE_VECTOR3:
			var p: Vector3 = v
			return [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]
		TYPE_AABB:
			var b: AABB = v
			return [snappedf(b.position.x, 0.001), snappedf(b.position.y, 0.001), snappedf(b.position.z, 0.001),
				snappedf(b.end.x, 0.001), snappedf(b.end.y, 0.001), snappedf(b.end.z, 0.001)]
		TYPE_STRING_NAME:
			return String(v)
		TYPE_FLOAT:
			return snappedf(float(v), 0.0001)
	return v


## A JSON rect [x, y, w, h] → Rect2 (Rect2() when malformed).
static func rect_of(v: Variant) -> Rect2:
	if typeof(v) == TYPE_RECT2:
		return v
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return Rect2()


## The separation of two screen rects: max(horizontal gap, vertical gap) in px — negative when they overlap on both
## axes (the rects intersect). Two rects are "≥ 24 px apart" iff this is ≥ 24 (the Stage-1 hotspot lint's rule:
## side by side, or stacked one over the other).
static func rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var dy := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	return maxf(dx, dy)
