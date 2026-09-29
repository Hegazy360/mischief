## PoseLib — a rig's `poses.json` + `faces.json` resolved into FULL poses (TECH §4.7).
##
## * Every pose starts from the rig's rest pose (or from its `base` pose, recursively), then
##   applies `root` and `bones` channel overrides (`rot, x, y, sx, sy, z, tex, vis, alpha`;
##   `tex` by variant name). `mirror_of: {"walk_pass_r": "walk_pass_l"}` (or an inline
##   `"mirror": "<pose>"`) builds a pose by swapping every `_l`/`_r` partner's channels (all
##   but `z`: depth stays with the near/far side; `tex` maps by variant name). A pose may
##   still add overrides on top of its mirror / base.
## * A pose's `face` preset (faces.json `presets`) is baked into the virtual face parts'
##   `tex` / `vis` channels; `face_of(pose)` keeps the name.
## * `tags` and `silhouette` notes are kept for the sheets and lints.
## * faces.json `gaze` (preset → [dx, dy] px) is the resting pupil offset of that preset
##   (FaceState applies it; Bellows' slow burn stares at the Stalls).
## * **Tolerant parser** (the art files evolve while the game loads them): an unknown key or a
##   value of the wrong type warns ONCE (per file and key) and is skipped — the rest of that
##   preset / pose still loads; nothing crashes and no preset is dropped silently. Names that
##   do not resolve (a variant, a base pose) stay errors for the rig lint.
## Pure data; `PoseLib.for_rig(id)` caches by rig id.
class_name PoseLib
extends RefCounted

static var _cache: Dictionary = {}

## Preset → Vector2 resting pupil offset in px (faces.json `gaze`).
var gaze: Dictionary = {}
## Pose → its `props` ({prop: {socket, state}}) and `residues` ([kinds]) notes, as authored
## (tools show them: AnimViewer --pose, the pose sheet; clips set props by events).
var pose_props: Dictionary = {}
var pose_residues: Dictionary = {}
var _warned: Dictionary = {}

## Keys a pose entry may carry; any other key warns once and is ignored.
const POSE_KEYS: PackedStringArray = ["base", "mirror", "mirror_of", "root", "bones", "face", "tags", "silhouette",
	"props", "residues", "notes", "doc", "_comment"]

var rig: RigDef
var path: String = ""
var faces_path: String = ""
## Pose names in file order.
var names: PackedStringArray = PackedStringArray()
var poses: Dictionary = {}        ## name → PackedFloat32Array (full pose)
var tags: Dictionary = {}         ## name → PackedStringArray
var silhouettes: Dictionary = {}  ## name → String
var faces: Dictionary = {}        ## pose name → face preset name ("" = none)
## Face presets: name → PackedInt32Array per face slot (variant index, -1 = unchanged,
## -2 = hidden).
var presets: Dictionary = {}
var preset_names: PackedStringArray = PackedStringArray()
var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()

var _raw: Dictionary = {}
var _mirror_of: Dictionary = {}
var _resolving: Dictionary = {}


## Cached poses of rig `rig_id` (`<data_root>/rigs/<id>/poses.json` + `faces.json`).
static func for_rig(rig_id: String) -> PoseLib:
	var hit: PoseLib = _cache.get(rig_id, null)
	if hit != null:
		return hit
	var rig := RigDef.for_id(rig_id)
	if rig == null:
		return null
	var dir := "%s/rigs/%s" % [RigDef.data_root, rig_id]
	var lib := PoseLib.load(rig, dir + "/poses.json", dir + "/faces.json")
	_cache[rig_id] = lib
	return lib


## Forget cached poses ("" = all).
static func invalidate(rig_id: String = "") -> void:
	if rig_id == "":
		_cache.clear()
	else:
		_cache.erase(rig_id)


## Load and resolve poses for `rig`. `faces_file` may be "" / missing (no presets).
static func load(rig_def: RigDef, file_path: String, faces_file: String = "") -> PoseLib:
	var lib := PoseLib.new()
	lib.rig = rig_def
	lib.path = file_path
	lib.faces_path = faces_file
	var fd: Variant = null
	if faces_file != "" and FileAccess.file_exists(faces_file):
		fd = RigDef._read_json(faces_file, lib.errors)
	var pd: Variant = RigDef._read_json(file_path, lib.errors) if FileAccess.file_exists(file_path) else {}
	if not FileAccess.file_exists(file_path):
		lib.warnings.append("%s: missing (rig has only its rest pose)" % file_path)
	lib._parse(pd if pd is Dictionary else {}, fd if fd is Dictionary else {})
	return lib


## Build from parsed dictionaries (tests).
static func from_dicts(rig_def: RigDef, poses_d: Dictionary, faces_d: Dictionary = {}) -> PoseLib:
	var lib := PoseLib.new()
	lib.rig = rig_def
	lib._parse(poses_d, faces_d)
	return lib


## True when `pose_name` exists.
func has_pose(pose_name: String) -> bool:
	return poses.has(pose_name)


## The resolved pose (the rig's rest pose when unknown). Shared: duplicate() before editing.
func pose(pose_name: String) -> PackedFloat32Array:
	return poses.get(pose_name, rig.rest)


## Face preset name of a pose ("" when it has none).
func face_of(pose_name: String) -> String:
	return String(faces.get(pose_name, ""))


## Tags of a pose.
func tags_of(pose_name: String) -> PackedStringArray:
	return tags.get(pose_name, PackedStringArray())


## True when `preset` exists.
func has_preset(preset: String) -> bool:
	return presets.has(preset)


## Writes preset `preset` into the face parts of `out` (tex / vis). Unknown → no change.
func apply_preset(out: PackedFloat32Array, preset: String) -> void:
	var p: Variant = presets.get(preset, null)
	if p == null:
		return
	var arr: PackedInt32Array = p
	for s in arr.size():
		var v := arr[s]
		if v == -1:
			continue
		var b := RigDef.ROOT_CH + rig.face_slot_part[s] * RigDef.STRIDE
		if v == -2:
			out[b + RigDef.C_VIS] = 0.0
		else:
			out[b + RigDef.C_TEX] = float(v)
			out[b + RigDef.C_VIS] = 1.0


## Applies a JSON channel dictionary ({"rot": 5, "tex": "fist"}) to part `i` of `out`.
## A variant name that does not resolve goes to `errs` (prefixed with `where`); an unknown
## channel or a value of the wrong type goes to `errs` too, or — `tolerant` (poses.json) —
## warns once per key and is skipped.
func apply_channels(out: PackedFloat32Array, i: int, chans: Dictionary, where: String, errs: PackedStringArray, tolerant: bool = false) -> void:
	var b := RigDef.ROOT_CH + i * RigDef.STRIDE
	for cn in chans:
		var c := RigDef.CHANNELS.find(str(cn))
		if c < 0:
			_problem(errs, tolerant, "chan:" + str(cn), "%s: unknown channel '%s' on '%s' — skipped" % [where, cn, rig.names[i]])
			continue
		var v: Variant = chans[cn]
		if c == RigDef.C_TEX:
			if not (v is String or v is StringName or _is_num(v)):
				_problem(errs, tolerant, "type:tex", "%s: part '%s' tex must be a variant name (got %s) — skipped" % [where, rig.names[i], str(v)])
				continue
			var vi := rig.tex_index(i, str(v)) if (v is String or v is StringName) else int(v)
			if vi < 0 or vi >= rig.tex_names[i].size():
				errs.append("%s: part '%s' has no texture '%s'" % [where, rig.names[i], v])
				continue
			out[b + c] = float(vi)
		elif c == RigDef.C_VIS:
			if not (v is bool or _is_num(v)):
				_problem(errs, tolerant, "type:vis", "%s: part '%s' vis must be a bool (got %s) — skipped" % [where, rig.names[i], str(v)])
				continue
			out[b + c] = 1.0 if (v is bool and v) or (not (v is bool) and float(v) > 0.5) else 0.0
		elif _is_num(v):
			out[b + c] = float(v)
		else:
			_problem(errs, tolerant, "type:" + str(cn), "%s: part '%s' channel '%s' must be a number (got %s) — skipped" % [where, rig.names[i], cn, str(v)])


## Applies a JSON root dictionary ({"y": 10, "sx": 1.1}) to `out` (`tolerant`: as above).
func apply_root(out: PackedFloat32Array, chans: Dictionary, where: String, errs: PackedStringArray, tolerant: bool = false) -> void:
	for cn in chans:
		var c := RigDef.ROOT_CHANNELS.find(str(cn))
		if c < 0:
			_problem(errs, tolerant, "rootchan:" + str(cn), "%s: unknown root channel '%s' — skipped" % [where, cn])
			continue
		if not _is_num(chans[cn]):
			_problem(errs, tolerant, "roottype:" + str(cn), "%s: root channel '%s' must be a number (got %s) — skipped" % [where, cn, str(chans[cn])])
			continue
		out[c] = float(chans[cn])


func _problem(errs: PackedStringArray, tolerant: bool, key: String, msg: String) -> void:
	if tolerant:
		_warn_once(key, msg)
	else:
		errs.append(msg)


## Swaps every mirror pair of `src` into `out` (all channels but z; tex by variant name).
func mirror_into(src: PackedFloat32Array, out: PackedFloat32Array) -> void:
	for k in src.size():
		out[k] = src[k]
	for i in rig.names.size():
		var j := rig.mirror_idx[i]
		if j < 0:
			continue
		var bi := RigDef.ROOT_CH + i * RigDef.STRIDE
		var bj := RigDef.ROOT_CH + j * RigDef.STRIDE
		for c in RigDef.STRIDE:
			if c == RigDef.C_Z:
				continue
			if c == RigDef.C_TEX:
				var vn := ""
				var vj := int(src[bj + c])
				if vj >= 0 and vj < rig.tex_names[j].size():
					vn = rig.tex_names[j][vj]
				var mapped := rig.tex_index(i, vn)
				out[bi + c] = float(mapped) if mapped >= 0 else src[bi + c]
			else:
				out[bi + c] = src[bj + c]


# --- parsing ---------------------------------------------------------------------------------

func _parse(pd: Dictionary, fd: Dictionary) -> void:
	_parse_presets(fd)
	var pv: Variant = pd.get("poses", {})
	_raw = pv if pv is Dictionary else {}
	var mv: Variant = pd.get("mirror_of", {})
	_mirror_of = mv if mv is Dictionary else {}
	for pn in _raw:
		names.append(str(pn))
	for pn2 in _mirror_of:
		if not _raw.has(pn2):
			names.append(str(pn2))
	for n in names:
		_resolve(n)


func _parse_presets(fd: Dictionary) -> void:
	var pv: Variant = fd.get("presets", {})
	if not (pv is Dictionary):
		if fd.has("presets"):
			_warn_once("presets", "%s: 'presets' must be an object (got %s) — no face presets loaded" % [faces_path, type_string(typeof(pv))])
		return
	for key in pv:
		var name := str(key)
		var e: Variant = pv[key]
		if not (e is Dictionary):
			errors.append("%s: preset '%s' is not an object" % [faces_path, name])
			continue
		var arr := PackedInt32Array()
		arr.resize(rig.face_slots.size())
		arr.fill(-1)
		for slot_k in e:
			var slot := str(slot_k)
			var s := rig.face_slots.find(slot)
			if s < 0:
				_warn_once("slot:" + slot, "%s: preset '%s' key '%s' is not a face slot of %s — skipped" % [faces_path, name, slot, rig.id])
				continue
			var v: Variant = (e as Dictionary)[slot_k]
			if v == null:
				arr[s] = -2
				continue
			if not (v is String or v is StringName):
				_warn_once("type:" + slot, "%s: preset '%s' slot '%s' must name a variant (got %s %s) — skipped" % [faces_path, name, slot, type_string(typeof(v)), str(v)])
				continue
			var vname := str(v)
			if vname == "none" or vname == "":
				arr[s] = -2
				continue
			var vi := rig.tex_names[rig.face_slot_part[s]].find(vname)
			if vi < 0:
				errors.append("%s: preset '%s' slot '%s' has no variant '%s'" % [faces_path, name, slot, vname])
				continue
			arr[s] = vi
		presets[name] = arr
		preset_names.append(name)
	var gv: Variant = fd.get("gaze", {})
	if gv is Dictionary:
		for gk in gv:
			var g: Variant = gv[gk]
			if g is Array and (g as Array).size() >= 2 and _is_num(g[0]) and _is_num(g[1]):
				gaze[str(gk)] = Vector2(float(g[0]), float(g[1]))
			else:
				_warn_once("gaze:" + str(gk), "%s: gaze '%s' must be [dx, dy] (got %s) — skipped" % [faces_path, gk, str(g)])
	elif fd.has("gaze"):
		_warn_once("gaze", "%s: 'gaze' must be an object — skipped" % faces_path)


## Resting pupil offset (px) of face preset `preset` (ZERO when it has none).
func gaze_of(preset: String) -> Vector2:
	return gaze.get(preset, Vector2.ZERO)


func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	warnings.append(msg)


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


func _resolve(n: String) -> PackedFloat32Array:
	if poses.has(n):
		return poses[n]
	if _resolving.has(n):
		errors.append("%s: pose '%s' is in a base/mirror cycle" % [path, n])
		return rig.rest
	_resolving[n] = true
	var out := rig.rest.duplicate()
	var raw: Variant = _raw.get(n, {})
	var d: Dictionary = raw if raw is Dictionary else {}
	var where := "%s: pose '%s'" % [path, n]
	if not (raw is Dictionary):
		_warn_once("pose:" + n, "%s is not an object (got %s) — it is the rest pose" % [where, type_string(typeof(raw))])
	for pk in d:
		if not POSE_KEYS.has(str(pk)):
			_warn_once("posekey:" + str(pk), "%s: unknown key '%s' — ignored (warned once per key)" % [where, pk])
	var mirror := str(_mirror_of.get(n, d.get("mirror", d.get("mirror_of", ""))))
	var face := ""
	var tg := PackedStringArray()
	if mirror != "":
		if not _raw.has(mirror) and not _mirror_of.has(mirror):
			errors.append("%s mirrors unknown pose '%s'" % [where, mirror])
		else:
			mirror_into(_resolve(mirror), out)
			face = face_of(mirror)
			tg = tags_of(mirror).duplicate()
	else:
		var base := str(d.get("base", ""))
		if base != "":
			if not _raw.has(base) and not _mirror_of.has(base):
				errors.append("%s has unknown base '%s'" % [where, base])
			else:
				var bp := _resolve(base)
				for k in bp.size():
					out[k] = bp[k]
				face = face_of(base)
	var rv: Variant = d.get("root", {})
	if rv is Dictionary:
		apply_root(out, rv, where, errors, true)
	elif rv != null:
		_warn_once("root:" + n, "%s: 'root' must be an object of channels — skipped" % where)
	var bv: Variant = d.get("bones", {})
	if not (bv is Dictionary) and bv != null:
		_warn_once("bones:" + n, "%s: 'bones' must be an object of parts — skipped" % where)
	if bv is Dictionary:
		for pn in bv:
			var i := rig.idx(str(pn))
			if i < 0:
				errors.append("%s: bone '%s' is not a part of %s" % [where, pn, rig.id])
				continue
			if bv[pn] is Dictionary:
				apply_channels(out, i, bv[pn], where, errors, true)
			else:
				_warn_once("bone:%s:%s" % [n, pn], "%s: bone '%s' must be a channel object — skipped" % [where, pn])
	if d.has("face"):
		face = str(d["face"]) if d["face"] != null else ""
		if face != "" and not presets.has(face):
			errors.append("%s: face preset '%s' unknown" % [where, face])
	if face != "":
		apply_preset(out, face)
	var tv: Variant = d.get("tags", null)
	if tv is Array:
		tg = PackedStringArray()
		for t in tv:
			tg.append(str(t))
	elif tv != null:
		_warn_once("tags:" + n, "%s: 'tags' must be a list — skipped" % where)
	if d.get("props", null) is Dictionary:
		pose_props[n] = d["props"]
	if d.get("residues", null) is Array:
		pose_residues[n] = PackedStringArray(Array(d["residues"]).map(func(x: Variant) -> String: return str(x)))
	poses[n] = out
	faces[n] = face
	tags[n] = tg
	silhouettes[n] = str(d.get("silhouette", ""))
	_resolving.erase(n)
	return out
