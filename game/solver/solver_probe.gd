## SolverProbe — the one place the solver READS a world (TECH §3.4 surface). Everything else
## (executor, metrics sampling, fallback conditions, planner, fuzz bots) goes through it, so a
## detail of the sim's field encoding only needs handling here:
## - ids may be interned ints (sorted-id order, TECH §2) or strings → always returned as ids;
## - states may be enum ints (named via the actor script's enums, else the TECH §3.7 order) or
##   strings → always returned as UPPER_CASE names;
## - positions are sub-pixels (`x_sub`, SUB = 60) → `*_x()` returns px.
## Works on the real `SimWorld` and on the tests' `MockWorld` alike. Read-only.
class_name SolverProbe
extends RefCounted

const SUB := 60
const HUSH_STATES: PackedStringArray = ["IDLE", "WALK", "RUN", "STAIRS", "DOOR", "RUMMAGE", "PICK_WINDOW",
	"RIGGING", "DIVING", "HIDDEN", "POPPING", "FROZEN", "SQUEAKING", "CAUGHT", "BOWING"]
const BELLOWS_STATES: PackedStringArray = ["ROUTINE", "DETOUR", "CURIOUS", "SPOTTED", "CHASE", "SEARCH",
	"REACTING", "MELTDOWN", "EXHAUSTED", "CAUGHT_HOLD"]
const PRANK_STATES: PackedStringArray = ["LOCKED", "AVAILABLE", "IN_PROGRESS", "RIGGED", "FIRED", "LANDED"]
## Hush states in which a new go/move would be queued (TECH §3.5 "busy").
const BUSY_STATES: PackedStringArray = ["RUMMAGE", "RIGGING", "DIVING", "POPPING", "SQUEAKING", "CAUGHT",
	"BOWING"]

var world: Object
var data: SolverData
var _enum_cache: Dictionary = {}    ## "<script path>|<field>" -> {int: name}
var _id_cache: Dictionary = {}      ## "<kind>|<index>" -> id


func _init(p_world: Object, p_data: SolverData) -> void:
	world = p_world
	data = p_data


# --- generic helpers ------------------------------------------------------------------------

## A property of an object (null-safe).
static func field(obj: Object, name: String, fallback: Variant = null) -> Variant:
	if obj == null:
		return fallback
	var v: Variant = obj.get(name)
	return fallback if v == null else v


## Normalise an id-ish value (String, StringName or interned int) to a string id of `kind`
## ("rooms", "hotspots", "activities", "items", "pranks", "stations", "lines"). Int indices are
## resolved through the world (`room_id(i)`…), then the ContentDB (`<kind>_id(i)`, `house.<kind>[i].id`,
## `<kind>_list[i].id`), then the sorted-id order of TECH §2.
func id_of(kind: String, v: Variant) -> String:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v)
		TYPE_INT:
			var i: int = v
			if i < 0:
				return ""
			var key := "%s|%d" % [kind, i]
			if _id_cache.has(key):
				return _id_cache[key]
			var out := _resolve_index(kind, i)
			_id_cache[key] = out
			return out
		TYPE_NIL:
			return ""
		TYPE_OBJECT:
			var o: Object = v
			if o != null:
				var idv: Variant = o.get("id")
				if idv != null:
					return String(idv)
	return str(v)


func _resolve_index(kind: String, i: int) -> String:
	var single := kind.trim_suffix("s")
	for m in ["%s_id" % single, "id_of_%s" % single]:
		if world.has_method(m):
			return String(world.call(m, i))
	var db: Object = field(world, "db")
	if db != null:
		for m in ["%s_id" % single, "id_of_%s" % single]:
			if db.has_method(m):
				return String(db.call(m, i))
		var house: Variant = db.get("house")
		if house is Object:
			var arr: Variant = (house as Object).get(kind)
			if arr is Array and i < (arr as Array).size():
				var s := id_of(kind, arr[i])
				if s != "":
					return s
		var lst: Variant = db.get("%s_list" % single)
		if lst is Array and i < (lst as Array).size():
			var s2 := id_of(kind, lst[i])
			if s2 != "":
				return s2
	var ids := data.sorted_ids(kind) if data != null else PackedStringArray()
	if i < ids.size():
		return ids[i]
	return str(i)


## Name of an enum-valued field of `obj` (e.g. hush.state → "RIGGING").
func enum_name(obj: Object, field_name: String, fallback_names: PackedStringArray) -> String:
	var v: Variant = field(obj, field_name, null)
	if v == null:
		return ""
	if v is String or v is StringName:
		return String(v).to_upper()
	if typeof(v) != TYPE_INT:
		return str(v).to_upper()
	var n: int = v
	var names := _enum_names(obj, field_name, fallback_names)
	return SolverData.sv(names.get(n, fallback_names[n] if n >= 0 and n < fallback_names.size() else str(n)))


func _enum_names(obj: Object, field_name: String, fallback_names: PackedStringArray) -> Dictionary:
	var scr: Script = obj.get_script() as Script
	# Keyed by script instance (inner classes share their outer file's resource_path).
	var key := "%d|%s|%s" % [scr.get_instance_id() if scr != null else 0, field_name, fallback_names[0]]
	if _enum_cache.has(key):
		return _enum_cache[key]
	var out := {}
	if scr != null:
		var cmap := scr.get_script_constant_map()
		for cname in cmap:
			var c: Variant = cmap[cname]
			if c is Dictionary:
				var d: Dictionary = c
				var hit := false
				for k in d:
					if fallback_names.has(String(k)):
						hit = true
						break
				if hit:
					for k in d:
						out[int(d[k])] = String(k)
					break
		if out.is_empty():
			# Unnamed enums / plain int constants named like the states (SimBellows.CHASE …).
			for cname in cmap:
				if fallback_names.has(String(cname)) and typeof(cmap[cname]) == TYPE_INT:
					out[int(cmap[cname])] = String(cname)
	_enum_cache[key] = out
	return out


# --- world ------------------------------------------------------------------------------------

func tick() -> int:
	return int(field(world, "tick", 0))


func ended() -> bool:
	return bool(field(world, "ended", false))


func end_reason() -> String:
	return String(field(world, "end_reason", ""))


func state_hash() -> int:
	return int(world.call("state_hash")) if world.has_method("state_hash") else 0


func applause_tenths() -> int:
	return int(world.call("applause_tenths")) if world.has_method("applause_tenths") else 0


## [bool, bool, bool] (★, ★★, ★★★).
func stars() -> Array:
	if world.has_method("stars"):
		var s: Variant = world.call("stars")
		if s is Array and (s as Array).size() >= 3:
			return [bool(s[0]), bool(s[1]), bool(s[2])]
	return [false, false, false]


func line_states() -> Array:
	if world.has_method("line_states"):
		var v: Variant = world.call("line_states")
		if v is Array:
			return v
	return []


## Ids of the Script lines that are done.
func lines_done() -> PackedStringArray:
	var out := PackedStringArray()
	for l in line_states():
		if l is Dictionary and bool((l as Dictionary).get("done", false)):
			out.append(id_of("lines", (l as Dictionary).get("id", "")))
	return out


## True when every required line is done.
func all_required_done() -> bool:
	var any := false
	for l in line_states():
		if l is Dictionary and bool((l as Dictionary).get("req", false)):
			any = true
			if not bool((l as Dictionary).get("done", false)):
				return false
	return any


func line_done(line_id: String) -> bool:
	return lines_done().has(line_id)


## Prank state name (LOCKED / AVAILABLE / IN_PROGRESS / RIGGED / FIRED / LANDED).
func prank_state(prank_id: String) -> String:
	if not world.has_method("prank_state"):
		return ""
	var v: Variant = world.call("prank_state", prank_id)
	if v is String or v is StringName:
		return String(v).to_upper()
	var n := int(v)
	var sysobj: Variant = field(world, "pranks", null)
	if sysobj is Object:
		var names := _enum_names(sysobj, "state", PRANK_STATES)
		if names.has(n):
			return String(names[n])
	return PRANK_STATES[n] if n >= 0 and n < PRANK_STATES.size() else str(n)


func hotspot_state(id: String) -> Dictionary:
	if world.has_method("hotspot_state"):
		var v: Variant = world.call("hotspot_state", id)
		if v is Dictionary:
			return v
	return {}


func link_count() -> int:
	return int(world.call("link")) if world.has_method("link") else 0


func tomatoes() -> int:
	return int(world.call("tomatoes")) if world.has_method("tomatoes") else 0


func tomatoes_max() -> int:
	return int(world.call("tomatoes_max")) if world.has_method("tomatoes_max") else -1


func has_beryl() -> bool:
	return field(world, "beryl", null) != null


func episode_id() -> String:
	var ep: Variant = field(world, "episode", null)
	if ep is Object:
		return String(field(ep, "id", ""))
	if ep is Dictionary:
		return SolverData.sv((ep as Dictionary).get("id", ""))
	return ""


# --- Hush ---------------------------------------------------------------------------------------

func hush() -> Object:
	return field(world, "hush", null)


func hush_room() -> String:
	return id_of("rooms", field(hush(), "room", ""))


func hush_x() -> int:
	return int(field(hush(), "x_sub", 0)) / SUB


func hush_x_sub() -> int:
	return int(field(hush(), "x_sub", 0))


func hush_state() -> String:
	return enum_name(hush(), "state", HUSH_STATES)


func hush_facing() -> int:
	return int(field(hush(), "facing", 1))


## Hiding spot Hush is in ("" = not hidden).
func hush_hidden_spot() -> String:
	var v: Variant = field(hush(), "hidden_spot", "")
	var s := id_of("hotspots", v)
	if s == "" and hush_state() == "HIDDEN":
		return "?"
	return s


## The hotspot Hush has arrived at and stands at ("" none; "?" when the world doesn't expose it).
func hush_at_hotspot() -> String:
	var h := hush()
	if h == null:
		return "?"
	var v: Variant = h.get("at_hotspot")
	if v == null:
		return "?"
	return id_of("hotspots", v)


func hush_hidden() -> bool:
	return hush_hidden_spot() != "" or hush_state() == "HIDDEN"


## True when she dived in while he watched (the spot is compromised).
func hush_watched() -> bool:
	var v: Variant = field(hush(), "watched_spot", "")
	if v is bool:
		return v
	if v is int:
		return int(v) >= 0
	return id_of("hotspots", v) != ""


func hush_frozen() -> bool:
	var v: Variant = field(hush(), "frozen", null)
	if v is bool:
		return v
	return hush_state() == "FROZEN"


## The RIG button is held in the world (SimHush.rig_held, else the RIGGING state).
func hush_rig_held() -> bool:
	var v: Variant = field(hush(), "rig_held", null)
	if v is bool:
		return v
	return hush_state() == "RIGGING"


## The FREEZE button is held in the world (SimHush.freeze_held, else frozen).
func hush_freeze_held() -> bool:
	var v: Variant = field(hush(), "freeze_held", null)
	if v is bool:
		return v
	return hush_frozen()


func hush_busy() -> bool:
	return BUSY_STATES.has(hush_state())


## Item ids Hush carries (oldest first).
func hush_carrying() -> PackedStringArray:
	var out := PackedStringArray()
	var v: Variant = field(hush(), "carrying", [])
	if v is Array or v is PackedInt32Array or v is PackedStringArray:
		for it in v:
			out.append(id_of("items", it))
	return out


# --- Bellows ------------------------------------------------------------------------------------

func bellows() -> Object:
	return field(world, "bellows", null)


func bellows_room() -> String:
	return id_of("rooms", field(bellows(), "room", ""))


func bellows_x() -> int:
	return int(field(bellows(), "x_sub", 0)) / SUB


func bellows_x_sub() -> int:
	return int(field(bellows(), "x_sub", 0))


func bellows_facing() -> int:
	return int(field(bellows(), "facing", 1))


func bellows_state() -> String:
	return enum_name(bellows(), "state", BELLOWS_STATES)


func bellows_activity() -> String:
	return id_of("activities", field(bellows(), "activity_id", ""))


## Remaining PERFORM ticks of his activity (−1 unknown).
func bellows_activity_remaining() -> int:
	var t: Variant = field(bellows(), "activity_t", null)
	var n: Variant = field(bellows(), "activity_len", null)
	if t == null or n == null:
		return -1
	return maxi(0, int(n) - int(t))


func bellows_reacting() -> bool:
	var s := bellows_state()
	return s == "REACTING" or s == "MELTDOWN"


func bellows_chasing() -> bool:
	return bellows_state() == "CHASE"


func specs_on() -> bool:
	return bool(field(bellows(), "specs_on", false))


func spot_meter() -> int:
	return int(field(bellows(), "spot_meter", 0))


## Ticks the "?" needs to fill (0 unknown).
func spot_fill() -> int:
	return int(field(bellows(), "spot_fill", 0))


## Temper tier 0..3 (Calm, Irked, Steaming, Livid).
func temper_tier() -> int:
	return int(field(bellows(), "tier", 0))


## True when Bellows faces away from Hush (or is on another floor / room).
func bellows_facing_away_from_hush() -> bool:
	if bellows_room() != hush_room():
		return true
	var dx := hush_x_sub() - bellows_x_sub()
	if dx == 0:
		return false
	return signi(dx) != bellows_facing()


## Ticks until Bellows enters `room` along his current path (0 = he is in it, −1 = not
## within the preview horizon). Uses `bellows_path_preview` (samples every 10 ticks).
func bellows_eta_to_room(room_id: String, horizon: int = 1800) -> int:
	if bellows_room() == room_id:
		return 0
	if not world.has_method("bellows_path_preview"):
		return -1
	var pv: Variant = world.call("bellows_path_preview", horizon)
	if not (pv is PackedInt32Array or pv is Array):
		return -1
	var n: int = pv.size() / 2
	for i in n:
		if id_of("rooms", int(pv[i * 2])) == room_id:
			return (i + 1) * 10
	return -1


## Where he goes next (the bubble's `next`), "" if unknown.
func bubble_next() -> String:
	if not world.has_method("bubble"):
		return ""
	var b: Variant = world.call("bubble")
	if b is Dictionary:
		return id_of("activities", (b as Dictionary).get("next", ""))
	return ""
