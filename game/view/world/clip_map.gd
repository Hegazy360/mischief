## ClipMap — snapshot state → animation clip (TECH §5.4 `map.json` format). Pure.
##
## A map is `data/anim/<rig>/map.json` (owned by each rig's animation task) or, until that
## exists, `view/world/default_maps/<rig>.json`:
##   {"idle": "<clip>", "walk": {"clip": "<clip>", "stride_px": 67, "speed_px_s": 400},
##    "run": …, "activity:<id>": "<clip>", "state:<state lower-case>": "<clip>",
##    "reaction": "<from sim>", "reaction_fallback": "<clip>", "bit:<id>": "<clip>",
##    "freeze": ["<clip>", …]}
## An entry is a clip id string or {"clip", "loop", "stride_px", "speed_px_s"}; "" = no clip
## (the character is not drawn by the rig in that state, e.g. Hush hidden).
## Order: reaction (frame-locked to the sim) → state:<state> → activity:<id> while he
## performs → freeze → run / walk while moving → idle.
class_name ClipMap
extends RefCounted

const DEFAULT_DIR := "res://view/world/default_maps"
const ANIM_DIR := "res://data/anim"
## Reaction marker: the clip comes from the snapshot (`react_clip`).
const FROM_SIM := "<from sim>"


## The chosen clip for one frame (reused; no allocation per frame).
class Pick:
	var clip: String = ""
	var loop: bool = true
	## Playback speed multiplier (walk cycles scale with the actor's speed).
	var speed: float = 1.0
	## True for reactions: the frame is driven from the sim clock (`frame`).
	var external: bool = false
	var frame: float = 0.0
	## Which map key matched (debug / tests).
	var key: String = ""
	## The entry has `stride_px`: RigPlayer takes the actor's speed in px/s.
	var stride: bool = false


static var _exists: Dictionary = {}


## The map for a rig: data/anim/<rig>/map.json when present, else the view's default, else {}.
static func load_map(rig: String) -> Dictionary:
	var p := "%s/%s/map.json" % [ANIM_DIR, rig]
	var v: Variant = ViewKit.json(p)
	if v is Dictionary:
		return v
	var d: Variant = ViewKit.json("%s/%s.json" % [DEFAULT_DIR, rig])
	return d if d is Dictionary else {}


## True when the clip's JSON exists (data/anim/<rig>/<name>.json). Cached.
static func clip_exists(clip_id: String) -> bool:
	if clip_id == "":
		return false
	if _exists.has(clip_id):
		return _exists[clip_id]
	var ok := FileAccess.file_exists("%s/%s.json" % [ANIM_DIR, clip_id])
	_exists[clip_id] = ok
	return ok


## Test hook: forget cached existence checks.
static func clear_cache() -> void:
	_exists.clear()


## Resolve `a` (a ViewSnapshot.Actor) against `map` into `out`. `alpha` = the tick fraction
## (reactions are frame-locked: frame = react_t + alpha). `exists_fn(clip) -> bool` filters
## clips that are not authored yet (default: clip_exists); a missing clip falls through to
## the next rule.
static func resolve(map: Dictionary, a: ViewSnapshot.Actor, alpha: float, out: Pick, exists_fn: Callable = Callable()) -> void:
	out.external = false
	out.frame = 0.0
	out.speed = 1.0
	out.loop = true
	out.key = ""
	out.clip = ""
	out.stride = false
	if a.reacting:
		var rc := a.react_clip
		var entry: Variant = map.get("reaction", FROM_SIM)
		if entry is String and ViewKit.s(entry) != FROM_SIM and ViewKit.s(entry) != "":
			rc = ViewKit.s(entry)
		if not _ok(rc, exists_fn):
			rc = _clip_of(map.get("reaction_fallback", ""))
		if _ok(rc, exists_fn):
			out.clip = rc
			out.external = true
			out.loop = false
			out.frame = float(a.react_t) + alpha
			out.key = "reaction"
			return
	var sk := "state:" + a.state.to_lower()
	if map.has(sk):
		var sc := _clip_of(map[sk])
		if sc == "" or _ok(sc, exists_fn):
			_apply_entry(out, map[sk], sk, a)
			return
	var performing := a.activity != "" and not a.moving and not a.reacting
	if performing:
		var ak := "activity:" + a.activity
		if map.has(ak) and _ok(_clip_of(map[ak]), exists_fn):
			_apply_entry(out, map[ak], ak, a)
			return
	if a.frozen or a.state == "FROZEN":
		var fz: Variant = map.get("freeze", null)
		if fz is Array and not (fz as Array).is_empty():
			var arr: Array = fz
			var c := ViewKit.s(arr[absi(a.freeze_pose_seed) % arr.size()])
			if _ok(c, exists_fn):
				out.clip = c
				out.loop = true
				out.key = "freeze"
				return
	if a.moving:
		var mk := "run" if a.running and map.has("run") else "walk"
		if map.has(mk) and _ok(_clip_of(map[mk]), exists_fn):
			_apply_entry(out, map[mk], mk, a)
			return
	if map.has("idle") and _ok(_clip_of(map["idle"]), exists_fn):
		_apply_entry(out, map["idle"], "idle", a)


static func _apply_entry(out: Pick, entry: Variant, key: String, a: ViewSnapshot.Actor) -> void:
	out.key = key
	out.clip = _clip_of(entry)
	out.loop = true
	out.speed = 1.0
	if entry is Dictionary:
		var d: Dictionary = entry
		out.loop = bool(d.get("loop", true))
		out.stride = d.has("stride_px")
		var nominal := float(d.get("speed_px_s", 0.0))
		if nominal > 0.0 and a.speed_px_s > 0.0:
			out.speed = clampf(a.speed_px_s / nominal, 0.25, 3.0)


static func _clip_of(entry: Variant) -> String:
	if entry is String:
		return ViewKit.s(entry)
	if entry is Dictionary:
		return ViewKit.s((entry as Dictionary).get("clip", ""))
	return ""


static func _ok(clip: String, exists_fn: Callable) -> bool:
	if clip == "":
		return false
	if exists_fn.is_valid():
		return bool(exists_fn.call(clip))
	return ClipMap.clip_exists(clip)
