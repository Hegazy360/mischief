## ClipDef3D — one parsed clip sidecar v2 (`data/anim/<rig>3d/<clip>.json`, r3d-index §7.2): every field typed,
## events sorted by frame (each carries `clip`, `rig` and `f`, so the player emits them without building
## dictionaries), `marks` from `mark` events, the face timeline, beats. Pure data, headless-safe.
##
## Validation (`errors` / `warnings`, `"<file>: <key>: <what>"`): format anim3d, length > 0, fps 60, every frame
## inside the clip, known event types, beats inside the clip, the face timeline sorted, layer / mask / lock known.
class_name ClipDef3D
extends RefCounted

const EVENT_TYPES: PackedStringArray = ["sfx", "voice", "laugh", "fx", "face", "cam", "shake", "hitstop", "slowmo",
	"freeze", "prop", "mark", "decor", "set_anim", "set_part", "look", "jiggle"]
const LAYERS: PackedStringArray = ["base", "overlay", "additive"]
const MASKS: PackedStringArray = ["upper", "head", "arms", "face"]
const LOCKS: PackedStringArray = ["sim", "rig_pm"]
const DEFAULT_BLEND := 6

var id: String = ""
var rig_id: String = ""
var name: String = ""
var path: String = ""
var raw: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()

var version: int = 2
var anim_path: String = ""
var length: int = 1
var fps: int = 60
var loop: bool = false
var layer: String = "base"
var mask: String = ""
var blend_in: int = 0
var has_blend_in: bool = false
var blend_out: int = 10
var lock: String = ""                 ## "sim" | "rig_pm" | "" (the view clock)
var beats: Dictionary = {}            ## name -> Vector2i
var events: Array[Dictionary] = []
var ev_f: PackedInt32Array = PackedInt32Array()
var marks: Dictionary = {}            ## name -> frame
var face_f: PackedInt32Array = PackedInt32Array()
var face_entries: Array[Dictionary] = []
## The preset in force at each face entry (an entry with only `slots` keeps the previous entry's preset; "" = none).
var face_presets: PackedStringArray = PackedStringArray()
var cheat_deg: float = -1.0           ## −1 = none (the view's staging default)
var root_travel: String = "sim"
var stride_m: float = 0.0
var speed_m_s: float = 0.0
var time_jitter: float = 0.0
var rot_jitter_deg: float = 0.0
var source: Dictionary = {}
var lint: Dictionary = {}
var keeps: PackedStringArray = PackedStringArray()   ## set pieces kept lent across a switch to this clip


## Parses sidecar dictionary `d` for clip `clip_id` found at `p`.
static func from_dict(clip_id: String, d: Dictionary, p := "") -> ClipDef3D:
	var c := ClipDef3D.new()
	c.parse(clip_id, d, p)
	return c


## Fills this def from sidecar `d`.
func parse(clip_id: String, d: Dictionary, p := "") -> void:
	id = clip_id
	path = p
	raw = d
	rig_id = clip_id.get_slice("/", 0)
	name = clip_id.get_slice("/", 1) if clip_id.contains("/") else clip_id
	version = int(d.get("version", 2))
	if String(d.get("format", "anim3d")) != "anim3d":
		_err("format", "is '%s', expected 'anim3d'" % d.get("format"))
	if d.has("clip") and String(d["clip"]) != clip_id:
		_err("clip", "is '%s', expected '%s'" % [d["clip"], clip_id])
	if d.has("rig") and String(d["rig"]) != rig_id:
		_err("rig", "is '%s', expected '%s'" % [d["rig"], rig_id])
	anim_path = String(d.get("anim", ""))
	if anim_path == "":
		_err("anim", "missing")
	length = int(d.get("length", 0))
	if length <= 0:
		_err("length", "must be > 0 (is %d)" % length)
		length = 1
	fps = int(d.get("fps", 60))
	if fps != 60:
		_err("fps", "must be 60 (is %d)" % fps)
	loop = bool(d.get("loop", false))
	layer = String(d.get("layer", "base"))
	if not LAYERS.has(layer):
		_err("layer", "unknown '%s'" % layer)
		layer = "base"
	mask = String(d["mask"]) if d.get("mask", null) != null else ""
	if mask != "" and not MASKS.has(mask):
		_err("mask", "unknown '%s'" % mask)
	if layer == "overlay" and mask == "":
		mask = "upper"
	has_blend_in = d.has("blend_in")
	blend_in = int(d.get("blend_in", DEFAULT_BLEND))
	blend_out = int(d.get("blend_out", 10))
	lock = String(d["lock"]) if d.get("lock", null) != null else ""
	if lock != "" and not LOCKS.has(lock):
		_err("lock", "unknown '%s'" % lock)
	var bv: Variant = d.get("beats", {})
	if bv is Dictionary:
		for bn in (bv as Dictionary):
			var b: Variant = (bv as Dictionary)[bn]
			if b is Array and (b as Array).size() == 2:
				var r := Vector2i(int(b[0]), int(b[1]))
				if r.x < 0 or r.y > length or r.y < r.x:
					_err("beats.%s" % bn, "[%d, %d] outside the clip (0..%d)" % [r.x, r.y, length])
				beats[String(bn)] = r
			else:
				_err("beats.%s" % bn, "must be [f0, f1]")
	_parse_events(d.get("events", []))
	_parse_face(d.get("face", []))
	cheat_deg = float(d["cheat_deg"]) if d.get("cheat_deg", null) != null else -1.0
	var root: Variant = d.get("root", {})
	if root is Dictionary:
		root_travel = String((root as Dictionary).get("travel", "sim"))
	stride_m = float(d["stride_m"]) if d.get("stride_m", null) != null else 0.0
	speed_m_s = float(d["speed_m_s"]) if d.get("speed_m_s", null) != null else 0.0
	var var_v: Variant = d.get("variation", {})
	if var_v is Dictionary:
		time_jitter = float((var_v as Dictionary).get("time_jitter", 0.0))
		rot_jitter_deg = float((var_v as Dictionary).get("rot_jitter_deg", 0.0))
	var sv: Variant = d.get("source", {})
	source = (sv as Dictionary) if sv is Dictionary else {}
	var lv: Variant = d.get("lint", {})
	lint = (lv as Dictionary) if lv is Dictionary else {}
	var kv: Variant = d.get("keeps", [])
	if kv is Array:
		for k in kv:
			keeps.append(String(k))


func _parse_events(ev: Variant) -> void:
	if not (ev is Array):
		_err("events", "must be an array")
		return
	var rows: Array = []
	var i := 0
	for e in ev:
		if not (e is Dictionary) or not (e as Dictionary).has("f") or not (e as Dictionary).has("type"):
			_err("events[%d]" % i, "needs f and type")
			i += 1
			continue
		var ed: Dictionary = (e as Dictionary).duplicate(true)
		var f := int(ed["f"])
		var t := String(ed["type"])
		if not EVENT_TYPES.has(t):
			if t == "smear":
				_warn("events[%d]" % i, "'smear' is dropped in 3D")
			else:
				_err("events[%d].type" % i, "unknown '%s'" % t)
		if f < 0 or f > length:
			_err("events[%d].f" % i, "frame %d outside the clip (0..%d)" % [f, length])
		ed["f"] = f
		ed["clip"] = id
		ed["rig"] = rig_id
		if t == "mark" and ed.has("name"):
			marks[String(ed["name"])] = f
		rows.append([f, i, ed])
		i += 1
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for r in rows:
		events.append(r[2])
		ev_f.append(int(r[0]))


func _parse_face(fv: Variant) -> void:
	if not (fv is Array):
		_err("face", "must be an array")
		return
	var prev := -1
	var i := 0
	for e in fv:
		if not (e is Dictionary) or not (e as Dictionary).has("f"):
			_err("face[%d]" % i, "needs f")
			i += 1
			continue
		var ed: Dictionary = (e as Dictionary).duplicate(true)
		var f := int(ed["f"])
		if f < prev:
			_err("face[%d].f" % i, "timeline not sorted (%d after %d)" % [f, prev])
		if f < 0 or f > length:
			_err("face[%d].f" % i, "frame %d outside the clip" % f)
		prev = f
		ed["f"] = f
		face_entries.append(ed)
		face_f.append(f)
		var pn := String(ed.get("preset", face_presets[face_presets.size() - 1] if not face_presets.is_empty() else ""))
		face_presets.append(pn)
		i += 1


## Frame of mark `n` (−1 when absent).
func mark(n: String) -> int:
	return int(marks.get(n, -1))


## The face timeline entry in force at frame `f` (index into face_entries; −1 = none yet).
func face_index_at(f: float) -> int:
	if face_f.is_empty():
		return -1
	var i := face_f.bsearch(int(floor(f)) + 1, true) - 1
	return i


## Duration in seconds.
func seconds() -> float:
	return float(length) / 60.0


## True when this clip is a take whose hold beat covers frame `f` (blinks are suppressed there).
func in_hold(f: float) -> bool:
	if not beats.has("hold"):
		return false
	var h: Vector2i = beats["hold"]
	return f >= float(h.x) and f < float(h.y)


## True when valid.
func is_valid() -> bool:
	return errors.is_empty()


func _err(key: String, what: String) -> void:
	errors.append("%s: %s: %s" % [path if path != "" else id, key, what])


func _warn(key: String, what: String) -> void:
	warnings.append("%s: %s: %s" % [path if path != "" else id, key, what])
