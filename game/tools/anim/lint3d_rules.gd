## AnimLint3D — the animation lint on sampled 3D clips (TECH §10.5 in 3D, GDD §9.3; r3d-anim §4.1.7). A clip is its
## sidecar (`data/anim/<rig>3d/<clip>.json`, index §7.2) + its baked `Animation` (`art3d/anim/<rig>/<clip>.res`) on the
## rig's skeleton (`art3d/chars/<rig>/<rig>.glb`, read with GLTFDocument so it works in an unimported sandbox).
## "Angular speed" = the per-frame rotation angle of a bone's LOCAL rotation. World-space rules (feet, bounds) use the
## skeleton's own forward kinematics on the sampled tracks (the same maths as `RigSampler3D`, `r3d-rig`), in the
## character's space: y up, +z her front; walks (`speed_m_s`) are measured in LANE space (+ speed·t along +z).
## Thresholds: `lint3d_limits.json`. Every finding: {rule, severity, file, frame (-1 = whole clip), msg}.
##
## | id | rule |
## |---|---|
## | L01_ids | sidecar v2 / format / clip id / rig resolve; the `.res` loads; event types known; sound ids in sfx_map.json; face presets in the rig; props, sockets, slots in rig3d.json; decor / set pieces / hotspots in the house data |
## | L02_length | `Animation.length` = length / 60 and `loop_mode` = the sidecar's `loop` |
## | L03_frames | events, face entries, gaze and beats lie inside [0, length], beats ordered |
## | L04_loop_seam | loops: every bone's angular velocity is continuous across the seam (≤ max(1°/f, the clip's own worst kink)), frame N = frame 0 within 0.5° |
## | L05_accent_length | the accent beat is ≤ 4 f |
## | L06_accent_speed | some bone turns ≥ 20°/f around the accent (else "mushy accent") |
## | L07_antic_opposes | the dominant accent bone's rotation over the anticipation opposes its rotation over the accent (dot < 0), or the pelvis moves against the accent |
## | L08_hold_length | reaction holds ≥ 24 f and ≥ 36 f once stretched for tier 2 (reactions.json hold scale) |
## | L09_dead_hold | no > 20 f span where every body (UAL) bone moves < 0.3°/f (and the pelvis < 1 mm/f) unless `lint.freeze_holds` covers it or the clip is a freeze (jiggle / prop bones do not count: the view simulates them) |
## | L10_pop_jump | no bone jumps > 45°/f unless the frame is in `lint.pop_frames` |
## | L11_twinning | left / right limbs never mirror-equal (< 1° on every pair) for > 10 f |
## | L12_feet_planted | a planted foot (≥ `plant_min_f` 3 contact frames, or a landing that ends a one-shot) drifts ≤ 0.01 m over its contact (lane space for walks); walks: the planted foot's clip-space velocity = -speed_m_s ± 5 % |
## | L13_floor | no sole point > 0.015 m below its support (the floor, or `step.support` while on a step) |
## | L14_sound_sync | every sound is within ±1 f of a beat boundary, a `mark`, a pop frame or a foot contact (`"sync": false` opts out) |
## | L15_face_accent | a clip with an accent swaps its face within ±1 f of the accent |
## | L16_laugh_after_accent | laughs start after the accent |
## | L17_reaction_length | reactions 60–240 f, signatures ≤ 420 f, unless `lint.skippable` |
## | L18_silhouette_change | the camera-view bounding box changes ≥ 15 % from the anticipation to the accent |
## | L19_beats_match | beats / length / release within 2 f of the clip's reactions.json entry |
## | L20_time_jitter | reaction clips have `variation.time_jitter` 0 |
## | L21_reaction_beats | reaction clips define anticipation, accent, hold and settle |
## | L22_marks | mark names are accent / release / knock_on / contact (warning) |
## | L23_overlay | overlay clips declare a mask and blend in / out over ≥ 4 f |
## | L24_sound_table | sound frames = the audio table (`data/audio/clip_events.json`, R3) for clips with a row and `source.audio` "table"; "own" clips are listed (info) for the table's regeneration |
## | L25_expected_length | lengths = the manifest (`SliceClips.build3d`, else `SliceClips.build`) expect ± tol, or a loop where allowed |
## | L26_cheat | `cheat_deg` in [0, 40]; ≤ 10 on rig clips (they reach; `rig_step_down` — the hop off a released step — is not one) |
## | L27_root_travel | `root.travel` "sim": the root and the pelvis move ≤ 0.15 m in x / z |
## | L28_rig_clip | `rig_*` clips: lock "rig_pm"; a prank clip lasts its tier's frames (rig_actions.json tiers); band clips (`rig_high/mid/low`) ≥ 48 f with no baked glance marks; a stepped clip ends on the floor (pelvis back to rest ± 0.01 m, support 0) |
## | L29_lock | `lock` in {null, sim, rig_pm}; reaction clips are "sim" |
## | L30_size | the `.res` is ≤ 250 KB (warning) |
##
## `lint.draft: true` (R19) exempts a clip only from rubric scoring: every rule above still applies. `make_strict`
## (`lint_anim.gd --format=3d --strict`) turns every warning into an error. Sampling is allocation-light enough for
## the g0 + p00 set in well under a minute headless.
class_name AnimLint3D
extends RefCounted

const LIMITS_PATH := "res://tools/anim/lint3d_limits.json"
const SFX_MAP := "res://audio/sfx_map.json"
const AUDIO_TABLE := "res://data/audio/clip_events.json"
const REACTIONS := "res://data/reactions.json"
const RIG_ACTIONS := "res://data/anim/hush3d/rig_actions.json"
const HOUSE := "res://data/house/house.json"
const HOUSE3D := "res://data/house/house3d.json"
const SLICE_CLIPS := "res://view/world/slice_clips.gd"
const RIG_SAMPLER := "res://view3d/char/rig_sampler_3d.gd"
const FPS := 60.0
## `rig_*` clips that are not reaches (no rig_pm lock, the normal cheat range): the hop off a released step.
const RIG_NOT_REACH: PackedStringArray = ["rig_step_down"]
const EVENT_TYPES: PackedStringArray = ["sfx", "voice", "laugh", "fx", "face", "cam", "shake", "hitstop", "slowmo",
	"freeze", "prop", "mark", "decor", "set_anim", "set_part", "look", "jiggle"]
const SOUND_TYPES: PackedStringArray = ["sfx", "voice"]
const UAL_BONES: PackedStringArray = ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "index_01_l", "index_02_l", "index_03_l", "index_04_leaf_l",
	"middle_01_l", "middle_02_l", "middle_03_l", "middle_04_leaf_l", "pinky_01_l", "pinky_02_l", "pinky_03_l",
	"pinky_04_leaf_l", "ring_01_l", "ring_02_l", "ring_03_l", "ring_04_leaf_l", "thumb_01_l", "thumb_02_l", "thumb_03_l",
	"thumb_04_leaf_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "index_01_r", "index_02_r", "index_03_r",
	"index_04_leaf_r", "middle_01_r", "middle_02_r", "middle_03_r", "middle_04_leaf_r", "pinky_01_r", "pinky_02_r",
	"pinky_03_r", "pinky_04_leaf_r", "ring_01_r", "ring_02_r", "ring_03_r", "ring_04_leaf_r", "thumb_01_r", "thumb_02_r",
	"thumb_03_r", "thumb_04_leaf_r", "thigh_l", "calf_l", "foot_l", "ball_l", "ball_leaf_l", "thigh_r", "calf_r",
	"foot_r", "ball_r", "ball_leaf_r"]
const SCOPE_EXTRA: PackedStringArray = ["hush/rig_high", "hush/rig_mid", "hush/rig_low"]
const SCOPE_NEW_3D: PackedStringArray = ["hush/act_climb_in", "hush/rig_achoo_ria", "hush/rig_allegro_go_go",
	"hush/loco_arrive", "hush/loco_skid", "hush/rig_step_down"]

## Test / tool overrides (null = the real data): manifest rows ({clip, expect_f, tol_f, loop_ok, why}), the audio
## table ({clip: {len_f, events}}), reactions.json, rig_actions.json.
static var expect_override: Variant = null
static var audio_override: Variant = null
static var reactions_override: Variant = null
static var rig_actions_override: Variant = null
static var _limits: Dictionary = {}
static var _json_cache: Dictionary = {}
static var _rigs: Dictionary = {}
static var _expect: Variant = null
static var _expect_src := ""
static var _sound_ids: Dictionary = {}


# --- findings -----------------------------------------------------------------------------------------

static func finding(rule: String, file: String, frame: int, msg: String, severity: String = "error") -> Dictionary:
	return {"rule": rule, "severity": severity, "file": file, "frame": frame, "msg": msg}


## "ERROR L09_dead_hold res://data/anim/hush3d/x.json:f40 message".
static func format(f: Dictionary) -> String:
	var at := "" if int(f["frame"]) < 0 else ":f%d" % int(f["frame"])
	return "%s %s %s%s %s" % [String(f["severity"]).to_upper(), f["rule"], f["file"], at, f["msg"]]


static func error_count(findings: Array) -> int:
	var n := 0
	for f in findings:
		if String(f["severity"]) == "error":
			n += 1
	return n


## Warnings → errors (in place), infos untouched.
static func make_strict(findings: Array) -> Array:
	for f in findings:
		if String(f["severity"]) == "warning":
			f["severity"] = "error"
			f["msg"] = String(f["msg"]) + " [strict]"
	return findings


static func limits() -> Dictionary:
	if _limits.is_empty():
		var d: Variant = _read_json(LIMITS_PATH)
		_limits = d if d is Dictionary else {}
	return _limits


static func lim(key: String, def: Variant) -> Variant:
	return limits().get(key, def)


static func ual_bones() -> Dictionary:
	var out := {}
	for b in UAL_BONES:
		out[b] = true
	return out


## Forget every cache (hot reload, tests).
static func reset_caches() -> void:
	_limits = {}
	_json_cache = {}
	_rigs = {}
	_expect = null
	_expect_src = ""
	_sound_ids = {}


static func _read_json(path: String) -> Variant:
	if _json_cache.has(path):
		return _json_cache[path]
	var v: Variant = null
	var p := path
	if FileAccess.file_exists(p):
		v = JSON.parse_string(FileAccess.get_file_as_string(p))
	_json_cache[path] = v
	return v


# --- the rig skeleton ------------------------------------------------------------------------------------

## Skeleton data of a rig glb (cached): {names, parent, rest (local), rest_global, index, soles, ok}.
static func rig_skeleton(glb_path: String) -> Dictionary:
	if _rigs.has(glb_path):
		return _rigs[glb_path]
	var out := {"ok": false, "path": glb_path}
	var abs_path := ProjectSettings.globalize_path(glb_path) if glb_path.begins_with("res://") else glb_path
	if not FileAccess.file_exists(abs_path):
		out["error"] = "rig skeleton %s not found" % glb_path
		_rigs[glb_path] = out
		return out
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(abs_path, st) != OK:
		out["error"] = "cannot read %s" % glb_path
		_rigs[glb_path] = out
		return out
	var root := doc.generate_scene(st)
	var sk := root.find_child("Skeleton3D", true, false) as Skeleton3D if root != null else null
	if sk == null:
		out["error"] = "%s has no Skeleton3D" % glb_path
		if root != null:
			root.free()
		_rigs[glb_path] = out
		return out
	var n := sk.get_bone_count()
	var names := PackedStringArray()
	var parent := PackedInt32Array()
	var rest: Array[Transform3D] = []
	var rest_g: Array[Transform3D] = []
	var index := {}
	for i in n:
		names.append(sk.get_bone_name(i))
		parent.append(sk.get_bone_parent(i))
		rest.append(sk.get_bone_rest(i))
		index[sk.get_bone_name(i)] = i
	for i in n:
		rest_g.append(sk.get_bone_global_rest(i))
	root.free()
	out["names"] = names
	out["parent"] = parent
	out["rest"] = rest
	out["rest_global"] = rest_g
	out["index"] = index
	out["order"] = _parent_first(parent)
	out["soles"] = _soles(index, rest_g)
	out["ok"] = true
	_rigs[glb_path] = out
	return out


static func _parent_first(parent: PackedInt32Array) -> PackedInt32Array:
	var order := PackedInt32Array()
	var done := {}
	var guard := 0
	while order.size() < parent.size() and guard < parent.size() + 2:
		guard += 1
		for i in parent.size():
			if done.has(i):
				continue
			if parent[i] < 0 or done.has(parent[i]):
				order.append(i)
				done[i] = true
	return order


## Per side "l"/"r": [[bone index, local point]] for heel, ball, toe — the floor points under the ankle (2 cm back),
## the ball joint and the toe tip at rest, carried by foot / ball / ball (the ball pad rides on the toe segment; the
## Blender pipeline uses the same points).
static func _soles(index: Dictionary, rest_g: Array[Transform3D]) -> Dictionary:
	var out := {}
	for s in ["l", "r"]:
		var foot := int(index.get("foot_" + s, -1))
		var ball := int(index.get("ball_" + s, -1))
		var leaf := int(index.get("ball_leaf_" + s, -1))
		if foot < 0 or ball < 0:
			continue
		var fh := rest_g[foot].origin
		var bh := rest_g[ball].origin
		var th := rest_g[leaf].origin if leaf >= 0 else bh + (bh - fh).normalized() * 0.06
		var pts := [Vector3(fh.x, 0.0, fh.z - 0.02), Vector3(bh.x, 0.0, bh.z), Vector3(th.x, 0.0, th.z)]
		var bones := [foot, ball, ball]
		var arr: Array = []
		for k in 3:
			var b: int = bones[k]
			arr.append([b, rest_g[b].affine_inverse() * (pts[k] as Vector3)])
		out[s] = arr
	return out


# --- sampling -----------------------------------------------------------------------------------------------

## Sample every frame 0..n of `anim` on `rig` (from rig_skeleton): {n, rot: [frame][bone] Quaternion (local),
## glob: [frame][bone] Transform3D (skeleton space)}. Loops are sampled without wrapping (frame n = the last key).
static func sample(rig: Dictionary, anim: Animation, n: int) -> Dictionary:
	var a := anim.duplicate() as Animation
	a.loop_mode = Animation.LOOP_NONE
	var names: PackedStringArray = rig["names"]
	var nb := names.size()
	var rt := PackedInt32Array()
	var pt := PackedInt32Array()
	var st := PackedInt32Array()
	rt.resize(nb)
	pt.resize(nb)
	st.resize(nb)
	rt.fill(-1)
	pt.fill(-1)
	st.fill(-1)
	var index: Dictionary = rig["index"]
	for t in a.get_track_count():
		var path := String(a.track_get_path(t))
		if not path.contains(":"):
			continue
		var bi := int(index.get(path.get_slice(":", 1), -1))
		if bi < 0:
			continue
		match a.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				rt[bi] = t
			Animation.TYPE_POSITION_3D:
				pt[bi] = t
			Animation.TYPE_SCALE_3D:
				st[bi] = t
	var rest: Array[Transform3D] = rig["rest"]
	var parent: PackedInt32Array = rig["parent"]
	var order: PackedInt32Array = rig["order"]
	var rots: Array = []
	var globs: Array = []
	for f in n + 1:
		var tm := minf(float(f) / FPS, a.length)
		var fr_r: Array[Quaternion] = []
		var fr_g: Array[Transform3D] = []
		fr_r.resize(nb)
		fr_g.resize(nb)
		for bi in order:
			var r0: Transform3D = rest[bi]
			var q := a.rotation_track_interpolate(rt[bi], tm) if rt[bi] >= 0 else r0.basis.get_rotation_quaternion()
			var p := a.position_track_interpolate(pt[bi], tm) if pt[bi] >= 0 else r0.origin
			var s := a.scale_track_interpolate(st[bi], tm) if st[bi] >= 0 else r0.basis.get_scale()
			var local := Transform3D(Basis(q).scaled(s), p)
			fr_r[bi] = q
			fr_g[bi] = local if parent[bi] < 0 else fr_g[parent[bi]] * local
		rots.append(fr_r)
		globs.append(fr_g)
	return {"n": n, "rot": rots, "glob": globs}


static func _ang(a: Quaternion, b: Quaternion) -> float:
	return rad_to_deg(a.angle_to(b))


# --- entry points ---------------------------------------------------------------------------------------------

## Lint one clip id ("hush/loco_walk") from the project data.
static func lint_clip_id(clip_id: String) -> Array:
	var rig := clip_id.get_slice("/", 0)
	var short := clip_id.get_slice("/", 1)
	return lint_paths("res://data/anim/%s3d/%s.json" % [rig, short], "", "")


## Lint a sidecar (+ its anim, default the sidecar's `anim`; + the rig glb, default `art3d/chars/<rig>/<rig>.glb`).
## Paths may be res:// or absolute.
static func lint_paths(sidecar_path: String, anim_path: String = "", rig_glb: String = "") -> Array:
	var out: Array = []
	var file := sidecar_path
	if not FileAccess.file_exists(sidecar_path):
		out.append(finding("L01_ids", file, -1, "sidecar not found"))
		return out
	var sc: Variant = JSON.parse_string(FileAccess.get_file_as_string(sidecar_path))
	if not (sc is Dictionary):
		out.append(finding("L01_ids", file, -1, "sidecar is not a JSON object"))
		return out
	var d: Dictionary = sc
	var clip_id := String(d.get("clip", ""))
	var rig_id := String(d.get("rig", clip_id.get_slice("/", 0)))
	if anim_path == "":
		anim_path = String(d.get("anim", ""))
	if rig_glb == "":
		rig_glb = "res://art3d/chars/%s/%s.glb" % [rig_id, rig_id]
	var anim: Animation = null
	var ap := anim_path
	if ap != "" and (ResourceLoader.exists(ap) or FileAccess.file_exists(ap)):
		anim = load(ap) as Animation if ap.begins_with("res://") else ResourceLoader.load(ap, "", ResourceLoader.CACHE_MODE_IGNORE) as Animation
	var rig := rig_skeleton(rig_glb)
	out.append_array(lint_data(d, anim, rig, file, ap))
	return out


## Every rule on one clip's data. `anim` null / `rig` not ok → the rules that need them report it.
static func lint_data(d: Dictionary, anim: Animation, rig: Dictionary, file: String, anim_path: String = "") -> Array:
	var out: Array = []
	var clip_id := String(d.get("clip", ""))
	if int(d.get("version", 0)) != 2 or String(d.get("format", "")) != "anim3d":
		out.append(finding("L01_ids", file, -1, "sidecar must be version 2, format \"anim3d\""))
	if clip_id == "" or not clip_id.contains("/"):
		out.append(finding("L01_ids", file, -1, "clip id must be \"<rig>/<clip>\""))
		return out
	var short := clip_id.get_slice("/", 1)
	if file.ends_with(".json") and file.get_file().get_basename() != short:
		out.append(finding("L01_ids", file, -1, "clip id %s does not match the file name" % clip_id))
	var n := int(d.get("length", 0))
	if n <= 0:
		out.append(finding("L02_length", file, -1, "length must be > 0"))
		return out
	_structure(d, file, n, out)
	_refs(d, file, out)
	if anim == null:
		out.append(finding("L01_ids", file, -1, "animation %s does not load" % anim_path))
		return out
	var loop := bool(d.get("loop", false))
	if absf(anim.length * FPS - float(n)) > 0.5:
		out.append(finding("L02_length", file, -1, "Animation is %.1f f long but the sidecar says %d f" % [anim.length * FPS, n]))
	var lm := Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if anim.loop_mode != lm:
		out.append(finding("L02_length", file, -1, "Animation loop_mode %d does not match loop %s" % [anim.loop_mode, loop]))
	if anim_path != "" and FileAccess.file_exists(anim_path):
		var fa := FileAccess.open(anim_path, FileAccess.READ)
		if fa != null and fa.get_length() > int(lim("res_max_bytes", 256000)):
			out.append(finding("L30_size", file, -1, "%s is %d KB (max %d KB)" % [anim_path.get_file(), fa.get_length() / 1024,
				int(lim("res_max_bytes", 256000)) / 1024], "warning"))
	_timing(d, file, n, out)
	_tables(d, file, n, out)
	if not bool(rig.get("ok", false)):
		out.append(finding("L01_ids", file, -1, "%s — skipping the sampled rules" % rig.get("error", "rig skeleton missing"), "info"))
		return out
	var s := sample(rig, anim, n)
	_sampled(d, file, n, rig, s, out)
	return out


# --- structure / references ------------------------------------------------------------------------------------

static func _structure(d: Dictionary, file: String, n: int, out: Array) -> void:
	var layer := String(d.get("layer", "base"))
	if not ["base", "overlay", "additive"].has(layer):
		out.append(finding("L01_ids", file, -1, "layer '%s' unknown" % layer))
	var lock: Variant = d.get("lock", null)
	if lock != null and not ["sim", "rig_pm"].has(String(lock)):
		out.append(finding("L29_lock", file, -1, "lock '%s' not in null / sim / rig_pm" % lock))
	var fps := int(d.get("fps", 60))
	if fps != 60:
		out.append(finding("L01_ids", file, -1, "fps must be 60"))
	for e in _events(d):
		var t := String(e.get("type", ""))
		var f := int(e.get("f", -1))
		if not EVENT_TYPES.has(t):
			out.append(finding("L01_ids", file, f, "event type '%s' unknown" % t))
		if f < 0 or f > n:
			out.append(finding("L03_frames", file, f, "%s event outside 0..%d" % [t, n]))
	var fv: Variant = d.get("face", [])
	if fv is Array:
		for fe in fv:
			if fe is Dictionary:
				var ff := int((fe as Dictionary).get("f", -1))
				if ff < 0 or ff > n:
					out.append(finding("L03_frames", file, ff, "face entry outside 0..%d" % n))
	var gv: Variant = d.get("gaze", [])
	if gv is Array:
		for g in gv:
			if g is Dictionary and (int((g as Dictionary).get("f0", 0)) < 0 or int((g as Dictionary).get("f1", 0)) > n):
				out.append(finding("L03_frames", file, int((g as Dictionary).get("f0", 0)), "gaze range outside 0..%d" % n))
	var beats := _beats(d)
	for bn in beats:
		var b: Vector2i = beats[bn]
		if b.x < 0 or b.y > n or b.y < b.x:
			out.append(finding("L03_frames", file, b.x, "beat %s [%d, %d] outside 0..%d or reversed" % [bn, b.x, b.y, n]))
	var order := ["anticipation", "accent", "hold", "settle"]
	var last := -1
	for bn2 in order:
		if beats.has(bn2):
			var b2: Vector2i = beats[bn2]
			if b2.x < last:
				out.append(finding("L03_frames", file, b2.x, "beat %s starts before the previous beat ends" % bn2))
			last = b2.y


static func _events(d: Dictionary) -> Array:
	var ev: Variant = d.get("events", [])
	var out: Array = []
	if ev is Array:
		for e in ev:
			if e is Dictionary:
				out.append(e)
	return out


static func _beats(d: Dictionary) -> Dictionary:
	var out := {}
	var bv: Variant = d.get("beats", {})
	if bv is Dictionary:
		for k in bv:
			var v: Variant = bv[k]
			if v is Array and (v as Array).size() == 2:
				out[String(k)] = Vector2i(int(v[0]), int(v[1]))
	return out


static func _marks(d: Dictionary) -> Dictionary:
	var out := {}
	for e in _events(d):
		if String(e.get("type", "")) == "mark":
			out[String(e.get("name", ""))] = int(e.get("f", -1))
	return out


## Sound ids of sfx_map.json (files, banks, aliases, cycles, sequences).
static func sound_ids() -> Dictionary:
	if not _sound_ids.is_empty():
		return _sound_ids
	var m: Variant = _read_json(SFX_MAP)
	if m is Dictionary:
		for k in ["files", "banks", "aliases", "cycles", "sequences"]:
			var v: Variant = (m as Dictionary).get(k, {})
			if v is Dictionary:
				for id in v:
					_sound_ids[String(id)] = true
	return _sound_ids


static func _rig3d(rig_id: String) -> Dictionary:
	var v: Variant = _read_json("res://data/rigs3d/%s/rig3d.json" % rig_id)
	return v if v is Dictionary else {}


static func _face_presets(rig_id: String) -> Dictionary:
	var r3 := _rig3d(rig_id)
	var p := "res://data/rigs3d/%s/faces.json" % rig_id
	var face: Variant = r3.get("face", {})
	if face is Dictionary and (face as Dictionary).get("presets", null) is String:
		p = String((face as Dictionary)["presets"])
	var v: Variant = _read_json(p)
	if not (v is Dictionary):
		v = _read_json("res://data/rigs/%s/faces.json" % rig_id)
	if not (v is Dictionary):
		return {}
	var pr: Variant = (v as Dictionary).get("presets", v)
	return pr if pr is Dictionary else {}


static func _house_ids() -> Dictionary:
	var out := {"hotspots": {}, "decor": {}, "furniture": {}}
	var h: Variant = _read_json(HOUSE)
	if h is Dictionary:
		for key in ["hotspots", "decor"]:
			var v: Variant = (h as Dictionary).get(key, [])
			if v is Array:
				for e in v:
					if e is Dictionary and (e as Dictionary).has("id"):
						(out[key] as Dictionary)[String((e as Dictionary)["id"])] = true
	var h3: Variant = _read_json(HOUSE3D)
	if h3 is Dictionary:
		for key2 in ["hotspots", "furniture", "decor"]:
			var v2: Variant = (h3 as Dictionary).get(key2, {})
			if v2 is Dictionary:
				for id in v2:
					var dst: String = "decor" if String(key2) == "decor" else String(key2)
					(out[dst] as Dictionary)[String(id)] = true
					if key2 == "furniture" and (v2[id] is Dictionary) and ((v2[id] as Dictionary).has("decor_id")):
						(out["decor"] as Dictionary)[String((v2[id] as Dictionary)["decor_id"])] = true
	return out


static func _refs(d: Dictionary, file: String, out: Array) -> void:
	var rig_id := String(d.get("rig", ""))
	var r3 := _rig3d(rig_id)
	var sounds := sound_ids()
	var presets := _face_presets(rig_id)
	var house := _house_ids()
	var props: Dictionary = r3.get("props", {}) if r3.get("props", {}) is Dictionary else {}
	var atts: Dictionary = r3.get("attachments", {}) if r3.get("attachments", {}) is Dictionary else {}
	var sockets: Dictionary = r3.get("sockets", {}) if r3.get("sockets", {}) is Dictionary else {}
	var slots: Dictionary = r3.get("slots", {}) if r3.get("slots", {}) is Dictionary else {}
	var have_r3 := not r3.is_empty()
	if not have_r3:
		out.append(finding("L01_ids", file, -1, "rig descriptor data/rigs3d/%s/rig3d.json not found: props / sockets / slots not checked" % rig_id, "info"))
	for e in _events(d):
		var t := String(e.get("type", ""))
		var f := int(e.get("f", -1))
		match t:
			"sfx", "voice":
				var sid := String(e.get("id", ""))
				if not sounds.is_empty() and not sounds.has(sid):
					out.append(finding("L01_ids", file, f, "sound id '%s' is not in sfx_map.json" % sid))
			"face":
				var pr := String(e.get("preset", e.get("id", "")))
				if not presets.is_empty() and not presets.has(pr):
					out.append(finding("L01_ids", file, f, "face event preset '%s' unknown" % pr))
			"prop":
				var pid := String(e.get("prop", ""))
				if pid.begins_with("set:"):
					var sid2 := pid.substr(4)
					if not (house["hotspots"] as Dictionary).has(sid2) and not (house["furniture"] as Dictionary).has(sid2):
						out.append(finding("L01_ids", file, f, "set piece '%s' is not a hotspot / furniture id" % sid2))
				elif have_r3 and not props.has(pid) and not atts.has(pid):
					out.append(finding("L01_ids", file, f, "prop '%s' is not a prop / attachment of rig %s" % [pid, rig_id]))
				if e.has("socket") and have_r3 and not sockets.has(String(e["socket"])):
					out.append(finding("L01_ids", file, f, "socket '%s' is not in rig3d.json" % e["socket"]))
			"decor":
				var did := String(e.get("id", ""))
				if did == "" or (not (house["decor"] as Dictionary).is_empty() and not (house["decor"] as Dictionary).has(did)):
					out.append(finding("L01_ids", file, f, "decor '%s' is not a decor / furniture id" % did))
			"set_part", "set_anim":
				var hid := String(e.get("hotspot", ""))
				if not (house["hotspots"] as Dictionary).has(hid):
					out.append(finding("L01_ids", file, f, "%s hotspot '%s' unknown" % [t, hid]))
			"look":
				var setv: Variant = e.get("set", {})
				if setv is Dictionary and have_r3:
					for slot in setv:
						if not slots.has(slot):
							out.append(finding("L01_ids", file, f, "look slot '%s' is not in rig3d.json slots" % slot))
						elif slots[slot] is Dictionary and not (slots[slot] as Dictionary).has(String(setv[slot])):
							out.append(finding("L01_ids", file, f, "look slot %s has no variant '%s'" % [slot, setv[slot]]))
			"mark":
				var mn := String(e.get("name", ""))
				if not (lim("mark_names", []) as Array).has(mn):
					out.append(finding("L22_marks", file, f, "mark '%s' is not one of %s" % [mn, str(lim("mark_names", []))], "warning"))
	var fv: Variant = d.get("face", [])
	if fv is Array and not presets.is_empty():
		for fe in fv:
			if fe is Dictionary and (fe as Dictionary).has("preset") and not presets.has(String((fe as Dictionary)["preset"])):
				out.append(finding("L01_ids", file, int((fe as Dictionary).get("f", -1)), "face preset '%s' unknown to rig %s" % [(fe as Dictionary)["preset"], rig_id]))
	elif presets.is_empty():
		out.append(finding("L01_ids", file, -1, "no face presets for rig %s: face entries not checked" % rig_id, "info"))


# --- timing rules that need no samples ---------------------------------------------------------------------------

static func is_reaction(d: Dictionary) -> bool:
	var s := String(d.get("clip", "")).get_slice("/", 1)
	return s.begins_with("rx_") or s.begins_with("sig_") or not reaction_entry(String(d.get("clip", ""))).is_empty()


static func reaction_entry(clip_id: String) -> Dictionary:
	var r: Variant = reactions_override if reactions_override is Dictionary else _read_json(REACTIONS)
	if not (r is Dictionary):
		return {}
	var arch: Variant = (r as Dictionary).get("archetypes", {})
	if not (arch is Dictionary):
		return {}
	for k in arch:
		var e: Variant = arch[k]
		if e is Dictionary and String((e as Dictionary).get("clip", "")) == clip_id:
			var o: Dictionary = (e as Dictionary).duplicate()
			o["archetype"] = String(k)
			return o
	return {}


static func _hold_scale_t2() -> int:
	var r: Variant = reactions_override if reactions_override is Dictionary else _read_json(REACTIONS)
	if r is Dictionary and (r as Dictionary).get("tiers", {}) is Dictionary:
		var hs: Variant = ((r as Dictionary)["tiers"] as Dictionary).get("hold_scale_pct", [100, 120, 150])
		if hs is Array and (hs as Array).size() >= 2:
			return int(hs[1])
	return 120


static func _timing(d: Dictionary, file: String, n: int, out: Array) -> void:
	var beats := _beats(d)
	var lint: Dictionary = d.get("lint", {}) if d.get("lint", {}) is Dictionary else {}
	var clip_id := String(d.get("clip", ""))
	var short := clip_id.get_slice("/", 1)
	if beats.has("accent"):
		var acc: Vector2i = beats["accent"]
		if acc.y - acc.x > int(lim("accent_max_f", 4)):
			out.append(finding("L05_accent_length", file, acc.x, "accent lasts %d f (max %d)" % [acc.y - acc.x, int(lim("accent_max_f", 4))]))
		var faces: Variant = d.get("face", [])
		if faces is Array and not (faces as Array).is_empty():
			var ok := false
			for fe in faces:
				if fe is Dictionary and absi(int((fe as Dictionary).get("f", -99)) - acc.x) <= int(lim("face_accent_f", 1)):
					ok = true
			if not ok:
				out.append(finding("L15_face_accent", file, acc.x, "no face swap within ±%d f of the accent (f%d): the take must read on the pop" % [int(lim("face_accent_f", 1)), acc.x]))
	var acc_end := -1
	if beats.has("accent"):
		acc_end = (beats["accent"] as Vector2i).y
	elif _marks(d).has("accent"):
		acc_end = int(_marks(d)["accent"])
	for e in _events(d):
		if String(e.get("type", "")) == "laugh" and acc_end >= 0 and int(e.get("f", 0)) < acc_end:
			out.append(finding("L16_laugh_after_accent", file, int(e["f"]), "laugh before the accent lands (accent ends f%d)" % acc_end))
	if is_reaction(d):
		var sig := short.begins_with("sig_")
		if not bool(lint.get("skippable", false)):
			var mx := int(lim("signature_max_f", 420)) if sig else int(lim("reaction_max_f", 240))
			if n < int(lim("reaction_min_f", 60)) or n > mx:
				out.append(finding("L17_reaction_length", file, -1, "reaction lasts %d f (allowed %d–%d unless skippable)" % [n, int(lim("reaction_min_f", 60)), mx]))
		for bn in ["anticipation", "accent", "hold", "settle"]:
			if not beats.has(bn):
				out.append(finding("L21_reaction_beats", file, -1, "reaction clips need a '%s' beat" % bn))
		if beats.has("hold"):
			var h: Vector2i = beats["hold"]
			var hl := h.y - h.x
			var t2 := hl + (hl * (_hold_scale_t2() - 100)) / 100
			if hl < int(lim("hold_min_f", 24)):
				out.append(finding("L08_hold_length", file, h.x, "hold is %d f (need ≥ %d)" % [hl, int(lim("hold_min_f", 24))]))
			elif t2 < int(lim("hold_min_t2_f", 36)):
				out.append(finding("L08_hold_length", file, h.x, "tier-2 hold is %d f (need ≥ %d)" % [t2, int(lim("hold_min_t2_f", 36))]))
		var var_v: Variant = d.get("variation", {})
		if var_v is Dictionary and float((var_v as Dictionary).get("time_jitter", 0)) != 0.0:
			out.append(finding("L20_time_jitter", file, -1, "reaction clips must have variation.time_jitter 0 (sim-timed)"))
		if String(d.get("lock", "")) != "sim":
			out.append(finding("L29_lock", file, -1, "reaction clips are frame-locked to the sim: lock \"sim\"", "warning"))
		var entry := reaction_entry(clip_id)
		if not entry.is_empty():
			var marks: Dictionary = entry.get("marks", {}) if entry.get("marks", {}) is Dictionary else {}
			var checks: Array = [["frames", int(entry.get("frames", n)), n]]
			if marks.has("antic") and beats.has("anticipation"):
				checks.append(["antic", int(marks["antic"]), (beats["anticipation"] as Vector2i).x])
			if marks.has("accent") and beats.has("accent"):
				checks.append(["accent", int(marks["accent"]), (beats["accent"] as Vector2i).x])
			if marks.get("hold", null) is Array and beats.has("hold"):
				checks.append(["hold start", int(marks["hold"][0]), (beats["hold"] as Vector2i).x])
				checks.append(["hold end", int(marks["hold"][1]), (beats["hold"] as Vector2i).y])
			if marks.has("release"):
				var rel := int(_marks(d).get("release", n))
				checks.append(["release", int(marks["release"]), rel])
			for c in checks:
				if absi(int(c[1]) - int(c[2])) > int(lim("beat_tol_f", 2)):
					out.append(finding("L19_beats_match", file, int(c[2]), "%s is f%d but reactions.json (%s) says f%d" % [c[0], c[2], entry.get("archetype", "?"), c[1]]))
	if String(d.get("layer", "base")) == "overlay":
		var m: Variant = d.get("mask", null)
		if m == null or String(m) == "":
			out.append(finding("L23_overlay", file, -1, "overlay clips declare a mask (upper / head / arms / face)"))
		var mb := int(lim("overlay_min_blend_f", 4))
		if int(d.get("blend_in", 0)) < mb:
			out.append(finding("L23_overlay", file, 0, "overlay blend_in %d f: blend over ≥ %d f" % [int(d.get("blend_in", 0)), mb]))
		if int(d.get("blend_out", 0)) < mb:
			out.append(finding("L23_overlay", file, n, "overlay blend_out %d f: blend over ≥ %d f" % [int(d.get("blend_out", 0)), mb]))
	var cheat := float(d.get("cheat_deg", 0))
	var rig_clip := short.begins_with("rig_") and not RIG_NOT_REACH.has(short)
	var cmax := float(lim("cheat_rig_max_deg", 10.0)) if rig_clip else float(lim("cheat_max_deg", 40.0))
	if cheat < 0.0 or cheat > cmax:
		out.append(finding("L26_cheat", file, -1, "cheat_deg %.0f outside [0, %.0f]%s" % [cheat, cmax, " (a rig clip reaches: ≤ 10, the head turns instead)" if rig_clip else ""]))
	if rig_clip:
		_rig_rules(d, file, n, out)


static func _rig_rules(d: Dictionary, file: String, n: int, out: Array) -> void:
	var short := String(d.get("clip", "")).get_slice("/", 1)
	var lock_v: Variant = d.get("lock", null)
	if lock_v == null or String(lock_v) != "rig_pm":
		out.append(finding("L28_rig_clip", file, -1, "rig clips are sampled at rig progress: lock \"rig_pm\""))
	if bool(d.get("loop", false)):
		out.append(finding("L28_rig_clip", file, -1, "rig clips do not loop (release keeps the pose)"))
	var band := ["rig_high", "rig_mid", "rig_low"].has(short)
	if band:
		if n < int(lim("band_min_f", 48)):
			out.append(finding("L28_rig_clip", file, -1, "band clip lasts %d f (≥ %d)" % [n, int(lim("band_min_f", 48))]))
		for e in _events(d):
			if String(e.get("type", "")) == "mark" and String(e.get("name", "")).begins_with("glance"):
				out.append(finding("L28_rig_clip", file, int(e.get("f", -1)), "band clips carry no baked glance marks (the view overlays act_glance at rig_actions.json ‰)"))
	else:
		var prank := short.substr(4)
		var ra: Variant = rig_actions_override if rig_actions_override is Dictionary else _read_json(RIG_ACTIONS)
		var tiers: Dictionary = lim("rig_tiers_f", {"q": 48, "s": 90, "b": 150})
		var tier := ""
		if ra is Dictionary:
			var tv: Variant = (ra as Dictionary).get("tiers", {})
			if tv is Dictionary and not (tv as Dictionary).is_empty():
				tiers = tv
			var pv: Variant = (ra as Dictionary).get("pranks", {})
			if pv is Dictionary and (pv as Dictionary).get(prank, null) is Dictionary:
				tier = String(((pv as Dictionary)[prank] as Dictionary).get("tier", "")).to_lower()
		if tier == "":
			out.append(finding("L28_rig_clip", file, -1, "prank '%s' not in rig_actions.json: tier length not checked" % prank, "info"))
		elif tiers.has(tier) and int(tiers[tier]) != n:
			out.append(finding("L28_rig_clip", file, -1, "prank clip lasts %d f but its tier %s is %d f" % [n, tier.to_upper(), int(tiers[tier])]))
	var st: Variant = d.get("step", null)
	if st is Dictionary:
		var sup: Variant = (st as Dictionary).get("support", [])
		if sup is Array and not (sup as Array).is_empty():
			var last: Variant = (sup as Array)[(sup as Array).size() - 1]
			if last is Array and float(last[1]) != 0.0:
				out.append(finding("L28_rig_clip", file, n, "a stepped clip ends on the floor: its support ends at %.2f m" % float(last[1])))


static func _audio_rows() -> Dictionary:
	if audio_override is Dictionary:
		return audio_override
	var t: Variant = _read_json(AUDIO_TABLE)
	if t is Dictionary and (t as Dictionary).get("clips", {}) is Dictionary:
		return (t as Dictionary)["clips"]
	return {}


static func _tables(d: Dictionary, file: String, n: int, out: Array) -> void:
	var clip_id := String(d.get("clip", ""))
	var row: Variant = _audio_rows().get(clip_id, null)
	var src: Dictionary = d.get("source", {}) if d.get("source", {}) is Dictionary else {}
	var mode := String(src.get("audio", "table"))
	var sounds: Array = []
	for e in _events(d):
		if SOUND_TYPES.has(String(e.get("type", ""))):
			sounds.append("%d %s" % [int(e.get("f", -1)), e.get("id", "")])
	if row is Dictionary:
		var want: Array = []
		var rv: Variant = (row as Dictionary).get("events", [])
		if rv is Array:
			for e2 in rv:
				if e2 is Dictionary and SOUND_TYPES.has(String((e2 as Dictionary).get("type", "sfx"))):
					want.append("%d %s" % [int((e2 as Dictionary).get("f", -1)), (e2 as Dictionary).get("id", "")])
		var lf: Variant = (row as Dictionary).get("len_f", null)
		if mode == "own":
			out.append(finding("L24_sound_table", file, -1, "own sound frames %s (audio table row %s): r3d-integrate regenerates the row" % [str(sounds), str(want)], "info"))
		else:
			sounds.sort()
			want.sort()
			if sounds != want:
				out.append(finding("L24_sound_table", file, -1, "sound frames %s differ from the audio table %s (R3)" % [str(sounds), str(want)]))
			if lf != null and int(lf) != n:
				out.append(finding("L24_sound_table", file, -1, "length %d f but the audio table times its sounds on %d f" % [n, int(lf)]))
	elif not sounds.is_empty():
		out.append(finding("L24_sound_table", file, -1, "no audio-table row: new sound frames %s for r3d-integrate" % str(sounds), "info"))
	# L25 expected lengths
	var rows: Variant = expectations().get(clip_id, null)
	if rows is Array:
		var loop := bool(d.get("loop", false))
		for r in rows:
			var rd: Dictionary = r
			var want_f := int(rd.get("expect_f", -1))
			if want_f <= 0:
				continue
			if loop and bool(rd.get("loop_ok", false)):
				continue
			var tol := int(rd.get("tol_f", 0))
			if absi(n - want_f) > tol:
				out.append(finding("L25_expected_length", file, -1, "lasts %d f but %s expects %d f%s%s" % [n, rd.get("why", "the manifest"),
					want_f, (" ± %d" % tol) if tol > 0 else "", " (a loop is allowed)" if bool(rd.get("loop_ok", false)) else ""]))


## Manifest rows by clip id: SliceClips.build3d(g0, p00) when r3d-view3d has landed it, else SliceClips.build().
static func expectations() -> Dictionary:
	if expect_override is Array:
		return _index_rows(expect_override)
	if _expect is Dictionary:
		return _expect
	var rows: Variant = manifest_rows()
	_expect = _index_rows(rows if rows is Array else [])
	return _expect


static func expectations_source() -> String:
	if expect_override is Array:
		return "override"
	expectations()
	return _expect_src


static func manifest_rows() -> Variant:
	if not ResourceLoader.exists(SLICE_CLIPS):
		_expect_src = "none"
		return null
	var s := load(SLICE_CLIPS) as Script
	if s == null:
		_expect_src = "none"
		return null
	var has3 := false
	var has2 := false
	for m in s.get_script_method_list():
		var mn := String(m.get("name", ""))
		has3 = has3 or mn == "build3d"
		has2 = has2 or mn == "build"
	if has3:
		_expect_src = "SliceClips.build3d"
		return s.call("build3d", PackedStringArray(["g0_sneeze", "p00_curtain_up"]))
	if has2:
		_expect_src = "SliceClips.build (2D)"
		return s.call("build")
	_expect_src = "none"
	return null


static func _index_rows(rows: Array) -> Dictionary:
	var by := {}
	for r in rows:
		if not (r is Dictionary):
			continue
		var cid := String((r as Dictionary).get("clip", ""))
		if cid == "":
			continue
		if not by.has(cid):
			by[cid] = []
		(by[cid] as Array).append(r)
	return by


## The R9 lint scope: the Gate-0 + Prologue clip ids (+ the band fallbacks) of `rig` ("" = every rig).
static func scope_ids(scope: PackedStringArray, rig: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	var rows: Variant = manifest_rows()
	var src := _expect_src
	if rows is Array:
		for r in rows:
			if not (r is Dictionary):
				continue
			var cid := String((r as Dictionary).get("clip", ""))
			var why := String((r as Dictionary).get("why", ""))
			var hit := src == "SliceClips.build3d"
			for s in scope:
				if why.contains(s + ":") or why.contains(s + " "):
					hit = true
			if cid.contains("act_tinker_") or cid.begins_with("figgis/"):
				hit = false
			if hit and not out.has(cid):
				out.append(cid)
	for extra in SCOPE_NEW_3D:
		if not out.has(extra):
			out.append(extra)
	for extra2 in SCOPE_EXTRA:
		if not out.has(extra2):
			out.append(extra2)
	if rig != "":
		var f := PackedStringArray()
		for c in out:
			if c.begins_with(rig + "/"):
				f.append(c)
		out = f
	out.sort()
	return out


# --- sampled rules ----------------------------------------------------------------------------------------------

static func _sampled(d: Dictionary, file: String, n: int, rig: Dictionary, s: Dictionary, out: Array) -> void:
	var names: PackedStringArray = rig["names"]
	var nb := names.size()
	var rots: Array = s["rot"]
	var globs: Array = s["glob"]
	var beats := _beats(d)
	var lint: Dictionary = d.get("lint", {}) if d.get("lint", {}) is Dictionary else {}
	var pops := {}
	for pf in (lint.get("pop_frames", []) if lint.get("pop_frames", []) is Array else []):
		pops[int(pf)] = true
	var loop := bool(d.get("loop", false))
	var index: Dictionary = rig["index"]
	var pelvis := int(index.get("pelvis", -1))
	var root := int(index.get("root", -1))
	# per-frame angular speed per bone (deg/f), frame f = f-1 -> f
	var speed: Array = [PackedFloat32Array()]
	(speed[0] as PackedFloat32Array).resize(nb)
	for f in range(1, n + 1):
		var row := PackedFloat32Array()
		row.resize(nb)
		var a: Array = rots[f - 1]
		var b: Array = rots[f]
		for bi in nb:
			row[bi] = _ang(a[bi], b[bi])
		speed.append(row)
	var shortn := String(d.get("clip", "")).get_slice("/", 1)
	var is_freeze := shortn.begins_with("freeze")
	# L04 loop seam
	if loop and n >= 3:
		var worst := 0.0
		var wn := ""
		var worst_v := 0.0
		var wvn := ""
		var interior := 0.0
		var r0: Array = rots[0]
		var rn: Array = rots[n]
		for bi in nb:
			var dd := _ang(r0[bi], rn[bi])
			if dd > worst:
				worst = dd
				wn = names[bi]
			var v_end := (speed[n] as PackedFloat32Array)[bi]
			var v_start := (speed[1] as PackedFloat32Array)[bi]
			if absf(v_end - v_start) > worst_v:
				worst_v = absf(v_end - v_start)
				wvn = names[bi]
			for f in range(2, n):
				interior = maxf(interior, absf((speed[f] as PackedFloat32Array)[bi] - (speed[f - 1] as PackedFloat32Array)[bi]))
		if worst > float(lim("seam_deg", 0.5)):
			out.append(finding("L04_loop_seam", file, n, "loop seam jumps %.2f° on %s (max %.1f°)" % [worst, wn, float(lim("seam_deg", 0.5))]))
		var allow := maxf(float(lim("seam_vel_deg", 1.0)), interior + 0.1)
		if worst_v > allow:
			out.append(finding("L04_loop_seam", file, n, "loop seam velocity changes by %.2f°/f on %s (allowed %.2f)" % [worst_v, wvn, allow]))
	# L06 / L07 / L18 accent
	if beats.has("accent"):
		var acc: Vector2i = beats["accent"]
		var peak := 0.0
		var dom := -1
		for f in range(maxi(1, acc.x), mini(acc.y, n) + 1):
			var row2: PackedFloat32Array = speed[f]
			for bi in nb:
				if row2[bi] > peak:
					peak = row2[bi]
					dom = bi
		if peak < float(lim("accent_speed_deg", 20.0)):
			out.append(finding("L06_accent_speed", file, acc.x, "mushy accent: peak %.1f°/f (need ≥ %.0f°/f on some bone)" % [peak, float(lim("accent_speed_deg", 20.0))]))
		if beats.has("anticipation") and dom >= 0:
			var ant: Vector2i = beats["anticipation"]
			var a0 := clampi(ant.x, 0, n)
			var a1 := clampi(acc.x, 0, n)
			var x1 := clampi(acc.y, 0, n)
			var q_a0: Quaternion = (rots[a0] as Array)[dom]
			var q_a1: Quaternion = (rots[a1] as Array)[dom]
			var q_x1: Quaternion = (rots[x1] as Array)[dom]
			var w_ant := _rotvec(q_a0, q_a1)
			var w_acc := _rotvec(q_a1, q_x1)
			var opposes := w_ant.dot(w_acc) < 0.0
			var pel_ok := false
			if pelvis >= 0:
				var p0 := ((globs[a0] as Array)[pelvis] as Transform3D).origin
				var p1 := ((globs[a1] as Array)[pelvis] as Transform3D).origin
				var p2 := ((globs[x1] as Array)[pelvis] as Transform3D).origin
				pel_ok = (p1 - p0).dot(p2 - p1) < -1e-6
			if not opposes and not pel_ok:
				out.append(finding("L07_antic_opposes", file, ant.x, "anticipation moves WITH the accent on %s (and the pelvis does not wind up against it): wind up the other way" % names[dom]))
			var yaw := _view_yaw(d)
			var b0 := _bbox(globs[a1], yaw)
			var b1 := _bbox(globs[x1], yaw)
			var ch := 0.0
			if b0.size.x > 0.0 and b0.size.y > 0.0:
				ch = maxf(absf(b1.size.x - b0.size.x) / b0.size.x, absf(b1.size.y - b0.size.y) / b0.size.y)
				ch = maxf(ch, absf(b1.get_area() - b0.get_area()) / b0.get_area())
			if ch < float(lim("bbox_min", 0.15)):
				out.append(finding("L18_silhouette_change", file, acc.x, "silhouette changes only %d%% from anticipation to accent (need ≥ %d%%)" % [int(ch * 100.0), int(float(lim("bbox_min", 0.15)) * 100.0)]))
	# L09 dead hold
	var span := int(lim("dead_span_f", 21))
	if not is_freeze and n >= span:
		var frozen := PackedByteArray()
		frozen.resize(n + 1)
		var fh: Variant = lint.get("freeze_holds", [])
		if fh is Array:
			for h in fh:
				if h is Array and (h as Array).size() == 2:
					for f in range(clampi(int(h[0]), 0, n), clampi(int(h[1]), 0, n) + 1):
						frozen[f] = 1
		for e in _events(d):
			if String(e.get("type", "")) == "freeze":
				var f0 := int(e.get("f", 0))
				for f in range(clampi(f0, 0, n), clampi(f0 + int(e.get("frames", 0)), 0, n) + 1):
					frozen[f] = 1
		var run := 0
		var dead_deg := float(lim("dead_deg_f", 0.3))
		var dead_pos := float(lim("dead_pos_m_f", 0.001))
		var body := ual_bones()
		for f in range(1, n + 1):
			var row3: PackedFloat32Array = speed[f]
			var still := true
			for bi in nb:
				if row3[bi] >= dead_deg and body.has(names[bi]):
					still = false
					break
			if still and pelvis >= 0:
				var pa := ((globs[f - 1] as Array)[pelvis] as Transform3D).origin
				var pb := ((globs[f] as Array)[pelvis] as Transform3D).origin
				if pa.distance_to(pb) >= dead_pos:
					still = false
			run = run + 1 if (still and frozen[f] == 0) else 0
			if run >= span:
				out.append(finding("L09_dead_hold", file, f - run + 1, "no motion for ≥ %d f (every bone < %.1f°/f from f%d): make it a moving hold (breath, tremble) or list it in lint.freeze_holds" % [span, dead_deg, f - run + 1]))
				break
	# L10 pops
	var pop_deg := float(lim("pop_deg_f", 45.0))
	var done_pop := false
	for f in range(1, n + 1):
		if done_pop:
			break
		var row4: PackedFloat32Array = speed[f]
		for bi in nb:
			if row4[bi] > pop_deg and not pops.has(f):
				out.append(finding("L10_pop_jump", file, f, "%s jumps %.0f°/f without a pop (lint.pop_frames)" % [names[bi], row4[bi]]))
				done_pop = true
				break
	# L11 twinning
	var pairs: Array = []
	for pr in lim("twin_pairs", []):
		var il := int(index.get(String(pr[0]), -1))
		var ir := int(index.get(String(pr[1]), -1))
		if il >= 0 and ir >= 0:
			pairs.append([il, ir])
	if not pairs.is_empty():
		var rest_g: Array[Transform3D] = rig["rest_global"]
		var trun := 0
		var tdeg := float(lim("twin_deg", 1.0))
		var tspan := int(lim("twin_span_f", 10))
		for f in n + 1:
			var g: Array = globs[f]
			var twin := true
			for p in pairs:
				var ql := ((g[p[0]] as Transform3D).basis.get_rotation_quaternion()) * rest_g[p[0]].basis.get_rotation_quaternion().inverse()
				var qr := ((g[p[1]] as Transform3D).basis.get_rotation_quaternion()) * rest_g[p[1]].basis.get_rotation_quaternion().inverse()
				var qm := Quaternion(qr.x, -qr.y, -qr.z, qr.w)
				if _ang(ql, qm) >= tdeg:
					twin = false
					break
			trun = trun + 1 if twin else 0
			if trun > tspan:
				out.append(finding("L11_twinning", file, f - trun + 1, "left and right limbs mirror each other for > %d f: offset one side (timing or angle)" % tspan))
				break
	# L12 / L13 feet, L14 sound sync
	var contacts := _feet(d, file, n, rig, s, out)
	_sync(d, file, n, beats, pops, contacts, out)
	# L27 root travel
	var travel := "sim"
	if d.get("root", {}) is Dictionary:
		travel = String((d["root"] as Dictionary).get("travel", "sim"))
	if travel == "sim":
		var lim_m := float(lim("root_travel_m", 0.15))
		var rest_g2: Array[Transform3D] = rig["rest_global"]
		for bi2 in [root, pelvis]:
			if bi2 < 0:
				continue
			var r0p := rest_g2[bi2].origin
			var worst_m := 0.0
			var wf := 0
			for f in n + 1:
				var o := ((globs[f] as Array)[bi2] as Transform3D).origin
				var dxz := Vector2(o.x - r0p.x, o.z - r0p.z).length()
				if dxz > worst_m:
					worst_m = dxz
					wf = f
			if worst_m > lim_m:
				out.append(finding("L27_root_travel", file, wf, "%s moves %.2f m in x/z (root.travel \"sim\": ≤ %.2f m — the view moves the character)" % [names[bi2], worst_m, lim_m]))
	# L28 stepped clip ends on the floor (its lowest sole point on y 0 at the last frame)
	if d.get("step", null) is Dictionary:
		var low := lowest_sole(rig, globs[n])
		if absf(low) > float(lim("step_end_m", 0.01)):
			out.append(finding("L28_rig_clip", file, n, "a stepped clip ends on the floor: the lowest sole is %.3f m off the floor at the last frame" % low))


## The lowest sole point (heel / ball / toe of both feet) of one sampled frame, skeleton space y.
static func lowest_sole(rig: Dictionary, g: Array) -> float:
	var low := INF
	var soles: Dictionary = rig["soles"]
	for side in soles:
		for pt in soles[side]:
			var p: Vector3 = (g[int(pt[0])] as Transform3D) * (pt[1] as Vector3)
			low = minf(low, p.y)
	return low


static func _rotvec(a: Quaternion, b: Quaternion) -> Vector3:
	var dq := b * a.inverse()
	if dq.w < 0.0:
		dq = -dq
	var ang := 2.0 * acos(clampf(dq.w, -1.0, 1.0))
	var ax := Vector3(dq.x, dq.y, dq.z)
	if ax.length() < 1e-9:
		return Vector3.ZERO
	return ax.normalized() * ang


## The body yaw the view plays the clip with (facing right unless the sidecar's stage says otherwise, minus cheat).
static func _view_yaw(d: Dictionary) -> float:
	var facing := 1
	var st: Variant = d.get("stage", null)
	if st is Dictionary:
		facing = int((st as Dictionary).get("facing", 1))
	var cheat := float(d.get("cheat_deg", 0))
	return deg_to_rad(float(facing) * (90.0 - cheat))


## Camera-view (x/y after the body yaw) bounding box of every bone head, +0.08 m.
static func _bbox(g: Array, yaw: float) -> Rect2:
	var bas := Basis(Vector3.UP, yaw)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for t in g:
		var p := bas * (t as Transform3D).origin
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo - Vector2(0.08, 0.08), hi - lo + Vector2(0.16, 0.16))


static func _support_at(d: Dictionary, f: int) -> float:
	var st: Variant = d.get("step", null)
	if not (st is Dictionary):
		return 0.0
	var sup: Variant = (st as Dictionary).get("support", [])
	var h := 0.0
	if sup is Array:
		for e in sup:
			if e is Array and f >= int(e[0]):
				h = float(e[1])
	return h


## Feet: L13 (below the support) and L12 (planted drift in lane space, stance speed for walks), per sole point
## (heel, ball, toe): a point is in contact while it is within `plant_y_m` of its support; over each run of contact
## frames it must stay put in lane space (a flat foot: heel and ball both; a rolling foot: each pivot in turn).
## Returns the contact start frames (for L14).
static func _feet(d: Dictionary, file: String, n: int, rig: Dictionary, s: Dictionary, out: Array) -> PackedInt32Array:
	var contacts := PackedInt32Array()
	var soles: Dictionary = rig["soles"]
	var globs: Array = s["glob"]
	var spd: Variant = d.get("speed_m_s", null)
	var speed := float(spd) if spd != null else 0.0
	var plant_y := float(lim("plant_y_m", 0.012))
	var floor_m := float(lim("floor_m", 0.015))
	var drift_m := float(lim("drift_m", 0.01))
	var tol := float(lim("stance_speed_tol", 0.05))
	var min_f := int(lim("stance_min_f", 4))
	var plant_min := int(lim("plant_min_f", 3))
	var below_done := false
	var names := ["heel", "ball", "toe"]
	for side in soles:
		var pts: Array = soles[side]
		var reported := false
		for k in 3:
			var bi: int = pts[k][0]
			var lp: Vector3 = pts[k][1]
			var run_f0 := -1
			var run_lane: Array[Vector3] = []
			var run_clip: Array[Vector3] = []
			for f in n + 2:
				var planted := false
				var p := Vector3.ZERO
				if f <= n:
					p = (globs[f][bi] as Transform3D) * lp
					var sup := _support_at(d, f)
					if not below_done and p.y < sup - floor_m:
						out.append(finding("L13_floor", file, f, "foot_%s %s %.3f m below its support (%.2f m; max %.3f)" % [side, names[k], sup - p.y, sup, floor_m]))
						below_done = true
					planted = p.y <= sup + plant_y
				if planted:
					if run_f0 < 0:
						run_f0 = f
						run_lane = []
						run_clip = []
						if not contacts.has(f):
							contacts.append(f)
					run_clip.append(p)
					run_lane.append(p + Vector3(0, 0, speed * float(f) / FPS))
				elif run_f0 >= 0:
					if not reported:
						# a touch / lift-off (< plant_min_f frames of contact) is not a plant — the bake's planner agrees
						if run_lane.size() >= plant_min or (f > n and run_f0 > 0 and not bool(d.get("loop", false)) and run_lane.size() >= 2):
							reported = _check_run(file, "%s %s" % [side, names[k]], run_f0, run_lane, run_clip, speed, drift_m, tol, min_f, out)
					run_f0 = -1
	return contacts


## One contact run of one sole point; returns true when it reported a finding (one report per foot keeps it readable).
static func _check_run(file: String, side: String, f0: int, lane: Array[Vector3], clip: Array[Vector3], speed: float, drift_m: float, tol: float, min_f: int, out: Array) -> bool:
	if lane.size() < 2:
		return false
	var found := false
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in lane:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var drift := (hi - lo).length()
	if drift > drift_m:
		out.append(finding("L12_feet_planted", file, f0, "planted foot_%s slides %.3f m over f%d–%d (max %.3f m%s)" % [side, drift, f0, f0 + lane.size() - 1, drift_m, ", lane space" if speed > 0.0 else ""]))
		found = true
	if speed > 0.0 and clip.size() >= min_f:
		var v := (clip[clip.size() - 1].z - clip[0].z) / (float(clip.size() - 1) / FPS)
		if absf(v + speed) > tol * speed:
			out.append(finding("L12_feet_planted", file, f0, "stance foot_%s moves %.2f m/s in clip space over f%d–%d; the walk's speed_m_s needs %.2f (± %d %%)" % [side, v, f0, f0 + clip.size() - 1, -speed, int(tol * 100.0)]))
			found = true
	return found


static func _sync(d: Dictionary, file: String, n: int, beats: Dictionary, pops: Dictionary, contacts: PackedInt32Array, out: Array) -> void:
	var anchors := {}
	for bn in beats:
		var b: Vector2i = beats[bn]
		anchors[b.x] = true
		anchors[b.y] = true
	for e in _events(d):
		if String(e.get("type", "")) == "mark":
			anchors[int(e.get("f", -99))] = true
	for pf in pops:
		anchors[int(pf)] = true
	for c in contacts:
		anchors[c] = true
	anchors[0] = true
	var tol := int(lim("sync_f", 1))
	for e2 in _events(d):
		if not SOUND_TYPES.has(String(e2.get("type", ""))):
			continue
		if not bool(e2.get("sync", true)):
			continue
		var f := int(e2.get("f", -1))
		var ok := false
		for k in range(f - tol, f + tol + 1):
			if anchors.has(k):
				ok = true
		if not ok:
			out.append(finding("L14_sound_sync", file, f, "sound '%s' is not within ±%d f of a beat boundary, mark, pop or foot contact" % [e2.get("id", ""), tol]))
