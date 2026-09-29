## AnimLint — the animation lint (TECH §10.5, comedy.md §7.6, GDD §9.3): comedy timing and
## craft rules as numbers, checked on the clip's own samples (RigSampler, no springs / props /
## runtime layers). Every finding has a stable rule id, the file, a frame (-1 = whole clip)
## and a message; `lint_clip(clip)` returns them (Array of Dictionaries), `format(f)` prints one.
##
## | id | rule |
## |---|---|
## | A01_frames_increase | key frames strictly increase inside [0, length] |
## | A02_ids_resolve | rig, poses, eases, faces, parts, masks, event types, props, springs resolve |
## | A03_joint_limits | every sampled frame keeps each part's rot within rig.json limits |
## | A04_loop_seam | loops: the seam matches within 0.5 (° / px) with continuous velocity (≤ 1 /f) |
## | A05_accent_length | the accent beat is ≤ 4 f |
## | A06_accent_speed | some part turns ≥ 20°/f around the accent (else "mushy accent") |
## | A07_antic_opposes | the anticipation's shape change opposes the accent's (dot < 0; root travel excluded) |
## | A08_hold_length | reaction holds ≥ 24 f and ≥ 36 f once stretched for tier 2 (× 1.2) |
## | A09_dead_hold | no 21+ f span without motion on any channel unless a `freeze` event covers it |
## | A10_pop_jump | no part jumps > 45°/f unless it jumps into a `pop` key or a `smear` event is within 1 f |
## | A11_twinning | left / right partners never move identically (< 1°) for > 10 f |
## | A12_feet_planted | a planted foot (sole on the floor) drifts ≤ 2 px in world space (walks: + stride) |
## | A13_floor | no sole / limb goes > 3 px below the floor |
## | A14_sfx_on_key | every sfx is within ±1 f of a key (`"sync": false` opts out) |
## | A15_face_on_key | face events sit exactly on a key |
## | A16_laugh_after_accent | laughs start after the accent (at or after the hold) |
## | A17_reaction_length | reactions 60–240 f, signatures ≤ 420 f, unless `skippable` |
## | A18_silhouette_change | the bounding box changes ≥ 15 % from the anticipation to the accent |
## | A19_beats_match | beats / length match the clip's reactions.json entry within 2 f |
## | A20_time_jitter | reaction clips have `variation.time_jitter` = 0 (the sim trusts their timing) |
## | A21_reaction_beats | reaction clips define anticipation, accent, hold and settle beats |
## | A22_marks | `mark` names are accent / release / knock_on (warning otherwise) |
## | A23_overlay | overlay clips declare a mask (rig mask name / part list) and blend in and out over ≥ 4 f; warnings: a rig mask the rig lacks (falls back to the keyed parts), locomotion parts in the mask (never written), a `mg_` clip that is not an overlay |
## | A24_bit_length | `<rig>/bit_*` lasts its squeak bit's `len_f` ± 2 f (SliceClips manifest, else activities.json `squeak_bits`) |
## | A25_mg_length | `<rig>/mg_<id>` lasts its micro-gag's `len_f` ± 12 f (manifest, else activities.json `micro_gags`) |
## | A26_cold_curtain | clips tagged `cold` / `curtain` (or `cold_` / `cc_` ids) run ≤ 420 f; their dead holds may last 90 f |
## | A27_walk_speed | a walk (`stride_px`) mapped in `map.json` with `speed_px_s` keeps planted feet within 3 px at that speed at rate 1, and the map's `stride_px` equals the clip's |
## | A28_decor | `decor` events carry an `id` naming a house.json `decor` entry and a bool `visible` |
## | A29_sim_length | every SliceClips.build() row with an expected length (`expect_f`, from the sim) is met exactly (± `tol_f`), or the clip loops where the row is `loop_ok` |
##
## `strict` (lint_anim.gd --strict, the pre-gate) turns every warning into an error.
class_name AnimLint
extends RefCounted

const SEAM_TOL := 0.5
const SEAM_VEL_TOL := 1.0
const ACCENT_MAX := 4
const ACCENT_SPEED := 20.0
const HOLD_MIN := 24
const HOLD_MIN_T2 := 36
const DEAD_SPAN := 21
const DEAD_EPS := 0.1
const POP_DEG := 45.0
const TWIN_DEG := 1.0
const TWIN_SPAN := 10
const PLANT_Y := -1.5
const DRIFT_MAX := 2.0
const FLOOR_MAX := 3.0
const REACTION_MIN := 60
const REACTION_MAX := 240
const SIGNATURE_MAX := 420
const BBOX_MIN := 0.15
const BEAT_TOL := 2
const MARK_NAMES: PackedStringArray = ["accent", "release", "knock_on"]
const BIT_TOL := 2
const MG_TOL := 12
const COLD_MAX := 420
const COLD_DEAD_SPAN := 90
const WALK_DRIFT_MAX := 3.0
const SLICE_CLIPS := "res://view/world/slice_clips.gd"
const HOUSE := "res://data/house/house.json"

## Test / tool overrides (null = read the real data): the expectation rows (manifest format
## `{clip, expect_f, tol_f, loop_ok, why}`), the map.json per rig, the house decor ids.
static var expect_override: Variant = null
static var maps_override: Variant = null
static var decor_override: Variant = null
static var _expect: Variant = null      ## clip id → Array of rows (cached)
static var _expect_src: String = ""
static var _maps: Dictionary = {}       ## rig → map Dictionary (cached)
static var _decor: Variant = null       ## Dictionary id → true (cached)


## One finding.
static func finding(rule: String, file: String, frame: int, msg: String, severity: String = "error") -> Dictionary:
	return {"rule": rule, "severity": severity, "file": file, "frame": frame, "msg": msg}


## "ERROR A09_dead_hold res://…/rx_take.json:f40 message".
static func format(f: Dictionary) -> String:
	var at := "" if int(f["frame"]) < 0 else ":f%d" % int(f["frame"])
	return "%s %s %s%s %s" % [String(f["severity"]).to_upper(), f["rule"], f["file"], at, f["msg"]]


## Number of error-severity findings.
static func error_count(findings: Array) -> int:
	var n := 0
	for f in findings:
		if String(f["severity"]) == "error":
			n += 1
	return n


## Lint every clip of every rig (or of `rig_id`); returns all findings.
static func lint_all(rig_id: String = "") -> Array:
	var out: Array = []
	var rigs := PackedStringArray([rig_id]) if rig_id != "" else ClipLib.rigs_with_clips()
	for r in rigs:
		for cid in ClipLib.list(r):
			out.append_array(lint_clip(ClipLib.get_clip(cid)))
	return out


## Every rule on one clip.
static func lint_clip(clip: ClipDef) -> Array:
	var out: Array = []
	if clip == null:
		return out
	var file := clip.path if clip.path != "" else ClipLib.path_of(clip.id)
	for e in clip.errors:
		var rule := "A01_frames_increase" if e.contains("frames must increase") or e.contains("no frame") else "A02_ids_resolve"
		out.append(finding(rule, file, -1, e))
	for w in clip.warnings:
		out.append(finding("A02_ids_resolve", file, -1, w, "warning"))
	if clip.rig == null or clip.key_f.is_empty():
		return out
	var rig := clip.rig
	var n := clip.length
	if clip.key_f[0] < 0 or clip.key_f[clip.key_f.size() - 1] > n:
		out.append(finding("A01_frames_increase", file, clip.key_f[clip.key_f.size() - 1], "keys must lie inside [0, %d]" % n))
	_check_refs(clip, file, out)
	# Sample every frame once.
	var frames: Array[PackedFloat32Array] = []
	var xfs: Array = []
	for f in n + 1:
		var p := rig.rest.duplicate()
		if clip.loop and f == n:
			var last := clip.key_f.size() - 1
			if clip.key_f[last] == n:
				p = clip.key_pose[last].duplicate()
			else:
				RigSampler.sample(clip, float(n), p)
		else:
			RigSampler.sample(clip, float(f), p)
		frames.append(p)
		var xf: Array[Transform2D] = []
		RigSampler.solve(rig, p, xf)
		xfs.append(xf)
	_limits(clip, file, frames, out)
	if clip.loop:
		_seam(clip, file, frames, out)
	_beats(clip, file, frames, xfs, out)
	_dead_hold(clip, file, frames, out)
	_pops(clip, file, frames, out)
	_twinning(clip, file, frames, out)
	_feet(clip, file, frames, xfs, out)
	_events(clip, file, out)
	_reaction(clip, file, out)
	_overlay(clip, file, out)
	_expected_length(clip, file, out)
	_cold(clip, file, out)
	_walk_speed(clip, file, frames, xfs, out)
	_decor_events(clip, file, out)
	return out


## Warnings → errors (the pre-gate's `--strict`), in place; returns `findings`.
static func make_strict(findings: Array) -> Array:
	for f in findings:
		if String(f["severity"]) == "warning":
			f["severity"] = "error"
			f["msg"] = String(f["msg"]) + " [strict]"
	return findings


## Forget cached manifests, maps and decor ids (hot reload, tests).
static func reset_caches() -> void:
	_expect = null
	_expect_src = ""
	_maps.clear()
	_decor = null


## True for a cold-open / curtain-call clip (A26: long clips, long holds allowed).
static func is_cold_or_curtain(clip: ClipDef) -> bool:
	var s := clip.short_name()
	return clip.tags.has("cold") or clip.tags.has("curtain") or s.begins_with("cold_") or s.begins_with("cc_")


# --- A23 overlays --------------------------------------------------------------------------------

static func _overlay(clip: ClipDef, file: String, out: Array) -> void:
	var sn := clip.short_name()
	if clip.layer != ClipDef.LAYER_OVERLAY:
		if sn.begins_with("mg_"):
			out.append(finding("A23_overlay", file, -1, "micro-gag clips play on the overlay layer: set \"layer\": \"overlay\" and a mask (e.g. \"upper\")", "warning"))
		return
	var spec: Variant = clip.mask_spec
	if spec == null or (spec is String and String(spec) == "") or (spec is Array and (spec as Array).is_empty()):
		out.append(finding("A23_overlay", file, -1, "overlay clips declare a mask: a rig mask name (\"upper\", \"head\"…) or a list of parts"))
	elif spec is String and not clip.rig.has_mask(String(spec)):
		var n := 0
		for v in clip.overlay_mask():
			n += v
		out.append(finding("A23_overlay", file, -1, "rig %s has no mask '%s' (rig.json masks): the overlay falls back to the %d parts it keys" % [clip.rig.id, spec, n], "warning"))
	if not clip.touch_legs and not clip.mask.is_empty():
		var loco := PackedStringArray()
		for p in mini(clip.mask.size(), clip.rig.locomotion.size()):
			if clip.mask[p] == 1 and clip.rig.locomotion[p] == 1:
				loco.append(clip.rig.names[p])
		if not loco.is_empty():
			out.append(finding("A23_overlay", file, -1, "mask names locomotion parts %s: an overlay never writes the root, the feet or their ancestors (set \"touch_legs\": true to allow)" % ", ".join(loco), "warning"))
	if clip.has_blend_in and clip.blend_in < ClipDef.OVERLAY_MIN_BLEND:
		out.append(finding("A23_overlay", file, 0, "overlay blend_in %d f: blend over ≥ %d f (a pop over a walk reads as a glitch)" % [clip.blend_in, ClipDef.OVERLAY_MIN_BLEND]))
	if clip.has_blend_out and clip.blend_out < ClipDef.OVERLAY_MIN_BLEND:
		out.append(finding("A23_overlay", file, clip.length, "overlay blend_out %d f: blend over ≥ %d f" % [clip.blend_out, ClipDef.OVERLAY_MIN_BLEND]))


# --- A24 / A25 / A29 expected lengths -------------------------------------------------------------

## The expectation rows by clip id: the SliceClips manifest when it exists (soft), else the
## squeak bits and micro-gags of activities.json. Cached.
static func expectations() -> Dictionary:
	if expect_override is Array:
		return _index_rows(expect_override)
	if _expect is Dictionary:
		return _expect
	var rows: Array = []
	var from_manifest: Variant = _manifest_rows()
	if from_manifest is Array:
		rows = from_manifest
		_expect_src = "SliceClips"
	else:
		rows = _activity_rows()
		_expect_src = "activities.json"
	_expect = _index_rows(rows)
	return _expect


## Where the expectations came from ("SliceClips" / "activities.json" / "override").
static func expectations_source() -> String:
	if expect_override is Array:
		return "override"
	expectations()
	return _expect_src


static func _index_rows(rows: Array) -> Dictionary:
	var by := {}
	for r in rows:
		if not (r is Dictionary):
			continue
		var cid := str((r as Dictionary).get("clip", ""))
		if cid == "":
			continue
		if not by.has(cid):
			by[cid] = []
		(by[cid] as Array).append(r)
	return by


## SliceClips.build() (s2-view, soft): null until the script exists and returns an Array.
static func _manifest_rows() -> Variant:
	if not ResourceLoader.exists(SLICE_CLIPS):
		return null
	var s := load(SLICE_CLIPS) as Script
	if s == null or not s.can_instantiate():
		return null
	var has := false
	for m in s.get_script_method_list():
		if String(m.get("name", "")) == "build":
			has = true
	if not has:
		return null
	var rows: Variant = s.call("build")
	return rows if rows is Array else null


## activities.json squeak bits (± 2 f) and timed micro-gags (± 12 f) as manifest rows.
static func _activity_rows() -> Array:
	var rows: Array = []
	var p := "%s/activities.json" % RigDef.data_root
	var errs := PackedStringArray()
	var d: Variant = RigDef._read_json(p, errs) if FileAccess.file_exists(p) else null
	if not (d is Dictionary):
		return rows
	var sb: Variant = (d as Dictionary).get("squeak_bits", {})
	if sb is Dictionary:
		for bid in sb:
			var b: Variant = sb[bid]
			if b is Dictionary and (b as Dictionary).has("len_f"):
				var cid := str((b as Dictionary).get("clip", "bellows/%s" % bid))
				rows.append({"clip": cid, "expect_f": int((b as Dictionary)["len_f"]), "tol_f": BIT_TOL, "loop_ok": false, "why": "squeak_bits.%s.len_f" % bid})
	for sect in ["activities", "detours"]:
		var av: Variant = (d as Dictionary).get(sect, {})
		if not (av is Dictionary):
			continue
		for aid in av:
			var a: Variant = av[aid]
			if not (a is Dictionary):
				continue
			var mg: Variant = (a as Dictionary).get("micro_gags", [])
			if not (mg is Array):
				continue
			for g in mg:
				if g is Dictionary and (g as Dictionary).has("id") and (g as Dictionary).has("len_f"):
					rows.append({"clip": "bellows/mg_%s" % (g as Dictionary)["id"], "expect_f": int((g as Dictionary)["len_f"]), "tol_f": MG_TOL,
						"loop_ok": false, "why": "%s.%s.micro_gags" % [sect, aid]})
	return rows


static func _expected_length(clip: ClipDef, file: String, out: Array) -> void:
	var rows: Variant = expectations().get(clip.id, null)
	if not (rows is Array):
		return
	var sn := clip.short_name()
	for r in rows:
		var row: Dictionary = r
		var want := int(row.get("expect_f", -1))
		if want <= 0:
			continue
		var rule := "A29_sim_length"
		var tol := int(row.get("tol_f", 0))
		if sn.begins_with("bit_"):
			rule = "A24_bit_length"
			tol = int(row.get("tol_f", BIT_TOL))
		elif sn.begins_with("mg_"):
			rule = "A25_mg_length"
			tol = int(row.get("tol_f", MG_TOL))
		if clip.loop and bool(row.get("loop_ok", false)):
			continue
		if absi(clip.length - want) <= tol:
			continue
		var why := str(row.get("why", row.get("src", "")))
		var hint := " (or loop: the row allows it)" if bool(row.get("loop_ok", false)) else ""
		if clip.loop and not bool(row.get("loop_ok", false)):
			hint = " — a loop is not allowed here"
		out.append(finding(rule, file, -1, "lasts %d f but %s expects %d f%s%s" % [clip.length, why if why != "" else "the manifest",
			want, (" ± %d" % tol) if tol > 0 else "", hint]))


## Every manifest row against the clips that exist (A24 / A25 / A29): findings. Rows whose
## clip does not exist are skipped (the coverage lint reports those).
static func lint_manifest(rows: Array) -> Array:
	var out: Array = []
	var saved: Variant = expect_override
	expect_override = rows
	var seen := {}
	for r in rows:
		if not (r is Dictionary):
			continue
		var cid := str((r as Dictionary).get("clip", ""))
		if cid == "" or seen.has(cid):
			continue
		seen[cid] = true
		var c := ClipLib.get_clip(cid)
		if c != null:
			_expected_length(c, c.path if c.path != "" else ClipLib.path_of(cid), out)
	expect_override = saved
	return out


# --- A26 cold opens / curtain call -----------------------------------------------------------------

static func _cold(clip: ClipDef, file: String, out: Array) -> void:
	if not is_cold_or_curtain(clip) or clip.skippable:
		return
	if clip.length > COLD_MAX:
		out.append(finding("A26_cold_curtain", file, -1, "cold open / curtain call lasts %d f (max %d unless skippable)" % [clip.length, COLD_MAX]))


# --- A27 walks at the map's speed ------------------------------------------------------------------

## A rig's map.json (data/anim/<rig>/map.json; {} when absent). Cached.
static func map_of(rig_id: String) -> Dictionary:
	if maps_override is Dictionary:
		var mo: Variant = (maps_override as Dictionary).get(rig_id, {})
		return mo if mo is Dictionary else {}
	if _maps.has(rig_id):
		return _maps[rig_id]
	var p := "%s/anim/%s/map.json" % [RigDef.data_root, rig_id]
	var errs := PackedStringArray()
	var d: Variant = RigDef._read_json(p, errs) if FileAccess.file_exists(p) else {}
	_maps[rig_id] = d if d is Dictionary else {}
	return _maps[rig_id]


## Map entries ({clip, stride_px, speed_px_s}, nested `skin:*` maps included) that play `clip`.
static func map_entries_for(clip: ClipDef) -> Array:
	var out: Array = []
	_collect_entries(map_of(clip.rig_id), clip, "", out)
	return out


static func _collect_entries(m: Dictionary, clip: ClipDef, prefix: String, out: Array) -> void:
	for k in m:
		var v: Variant = m[k]
		if v is Dictionary:
			var vd: Dictionary = v
			if vd.has("clip"):
				var cid := str(vd["clip"])
				if not cid.contains("/"):
					cid = clip.rig_id + "/" + cid
				if cid == clip.id:
					var e := vd.duplicate()
					e["key"] = prefix + str(k)
					out.append(e)
			else:
				_collect_entries(vd, clip, prefix + str(k) + ".", out)


static func _walk_speed(clip: ClipDef, file: String, frames: Array[PackedFloat32Array], xfs: Array, out: Array) -> void:
	if clip.stride_px <= 0.0:
		return
	for e in map_entries_for(clip):
		var ed: Dictionary = e
		var key := str(ed.get("key", "?"))
		if ed.has("stride_px") and absf(float(ed["stride_px"]) - clip.stride_px) > 1.0:
			out.append(finding("A27_walk_speed", file, -1, "map.json '%s' says stride_px %.1f but the clip's is %.1f (the view's rate would slide the feet)" % [key, float(ed["stride_px"]), clip.stride_px]))
		if not ed.has("speed_px_s"):
			continue
		var speed := float(ed["speed_px_s"])
		var natural := clip.stride_px / (float(maxi(1, clip.length)) / 60.0)
		var before := out.size()
		_plant_drift(clip, file, frames, xfs, speed / 60.0, WALK_DRIFT_MAX, "A27_walk_speed", out)
		if out.size() > before:
			var f: Dictionary = out[out.size() - 1]
			f["msg"] = "at map '%s' speed %.0f px/s (the clip's natural speed is %.0f px/s): %s" % [key, speed, natural, f["msg"]]


# --- A28 decor events -------------------------------------------------------------------------------

## house.json decor ids (Dictionary id → true; empty when house.json is missing). Cached.
static func decor_ids() -> Dictionary:
	if decor_override is Dictionary:
		return decor_override
	if _decor is Dictionary:
		return _decor
	var ids := {}
	var errs := PackedStringArray()
	var d: Variant = RigDef._read_json(HOUSE, errs) if FileAccess.file_exists(HOUSE) else null
	if d is Dictionary:
		var dv: Variant = (d as Dictionary).get("decor", [])
		if dv is Array:
			for it in dv:
				if it is Dictionary and (it as Dictionary).has("id"):
					ids[str((it as Dictionary)["id"])] = true
		elif dv is Dictionary:
			for k in dv:
				ids[str(k)] = true
	_decor = ids
	return ids


static func _decor_events(clip: ClipDef, file: String, out: Array) -> void:
	var ids := {}
	var have := false
	for e in clip.events:
		if String(e.get("type", "")) != "decor":
			continue
		if not have:
			ids = decor_ids()
			have = true
		var f := int(e.get("f", -1))
		var id: Variant = e.get("id", null)
		if not (id is String) or String(id) == "":
			out.append(finding("A28_decor", file, f, "decor event needs an \"id\" (a house.json decor id)"))
		elif not ids.is_empty() and not ids.has(String(id)):
			out.append(finding("A28_decor", file, f, "decor '%s' is not a house.json decor id" % id))
		if not (e.get("visible", null) is bool):
			out.append(finding("A28_decor", file, f, "decor event needs \"visible\": true / false"))


static func _check_refs(clip: ClipDef, file: String, out: Array) -> void:
	var rig := clip.rig
	for e in clip.events:
		var t := String(e.get("type", ""))
		var f := int(e.get("f", -1))
		if t == "prop" and String(e.get("op", "")) != "fall":
			var pid := String(e.get("prop", ""))
			if not rig.prop_index.has(pid):
				out.append(finding("A02_ids_resolve", file, f, "prop '%s' is not a prop of rig %s" % [pid, rig.id]))
		elif t == "spring":
			var pi := rig.idx(String(e.get("part", "")))
			if pi < 0 or rig.spring_part.find(pi) < 0:
				out.append(finding("A02_ids_resolve", file, f, "spring part '%s' has no spring in rig %s" % [e.get("part", ""), rig.id]))
		elif t == "smear" and e.has("part") and rig.idx(String(e["part"])) < 0:
			out.append(finding("A02_ids_resolve", file, f, "smear part '%s' is not in rig %s" % [e["part"], rig.id]))
		elif t == "face":
			var pr := String(e.get("preset", e.get("id", "")))
			if not clip.poses.has_preset(pr):
				out.append(finding("A02_ids_resolve", file, f, "face event preset '%s' unknown" % pr))


static func _limits(clip: ClipDef, file: String, frames: Array[PackedFloat32Array], out: Array) -> void:
	var rig := clip.rig
	for p in rig.names.size():
		if rig.rot_min[p] <= -RigDef.NO_LIMIT and rig.rot_max[p] >= RigDef.NO_LIMIT:
			continue
		var i := RigDef.ch(p, RigDef.C_ROT)
		for f in frames.size():
			var v := frames[f][i]
			if v < rig.rot_min[p] - 0.01 or v > rig.rot_max[p] + 0.01:
				out.append(finding("A03_joint_limits", file, f, "%s rot %.1f outside [%.0f, %.0f]" % [rig.names[p], v, rig.rot_min[p], rig.rot_max[p]]))
				break


## Continuous channels as (index, weight): rot / x / y in ° and px, scales ×100, alpha ×100.
static func _cont_channels(rig: RigDef, with_root_travel: bool) -> Array:
	var out: Array = []
	if with_root_travel:
		out.append([RigDef.R_X, 1.0])
		out.append([RigDef.R_Y, 1.0])
	out.append([RigDef.R_ROT, 1.0])
	out.append([RigDef.R_SX, 100.0])
	out.append([RigDef.R_SY, 100.0])
	for p in rig.names.size():
		var b := RigDef.ch(p, 0)
		out.append([b + RigDef.C_ROT, 1.0])
		out.append([b + RigDef.C_X, 1.0])
		out.append([b + RigDef.C_Y, 1.0])
		out.append([b + RigDef.C_SX, 100.0])
		out.append([b + RigDef.C_SY, 100.0])
		out.append([b + RigDef.C_ALPHA, 100.0])
	return out


static func _seam(clip: ClipDef, file: String, frames: Array[PackedFloat32Array], out: Array) -> void:
	var n := clip.length
	var chans := _cont_channels(clip.rig, true)
	var worst := 0.0
	var worst_v := 0.0
	var wn := ""
	var wvn := ""
	for c in chans:
		var i: int = c[0]
		var w: float = c[1]
		var d := absf(frames[n][i] - frames[0][i]) * w
		if d > worst:
			worst = d
			wn = _chan_name(clip.rig, i)
		if n >= 2:
			var v_end := (frames[n][i] - frames[n - 1][i]) * w
			var v_start := (frames[1][i] - frames[0][i]) * w
			if absf(v_end - v_start) > worst_v:
				worst_v = absf(v_end - v_start)
				wvn = _chan_name(clip.rig, i)
	if worst > SEAM_TOL:
		out.append(finding("A04_loop_seam", file, n, "loop seam jumps %.2f on %s (max %.1f)" % [worst, wn, SEAM_TOL]))
	# Velocity: the seam may not kink more than the clip already does at its own keys
	# (a walk's heel strike kinks at every contact; an idle loop must be smooth).
	var interior := 0.0
	for k in clip.key_f.size():
		var kf := clip.key_f[k]
		if kf <= 0 or kf >= n:
			continue
		for c2 in chans:
			var i2: int = c2[0]
			var w2: float = c2[1]
			interior = maxf(interior, absf(((frames[kf + 1][i2] - frames[kf][i2]) - (frames[kf][i2] - frames[kf - 1][i2])) * w2))
	var allow := maxf(SEAM_VEL_TOL, interior + 0.1)
	if worst_v > allow:
		out.append(finding("A04_loop_seam", file, n, "loop seam velocity changes by %.2f/f on %s (allowed %.1f)" % [worst_v, wvn, allow]))


static func _chan_name(rig: RigDef, i: int) -> String:
	if i < RigDef.ROOT_CH:
		return "root.%s" % RigDef.ROOT_CHANNELS[i]
	var p := (i - RigDef.ROOT_CH) / RigDef.STRIDE
	return "%s.%s" % [rig.names[p], RigDef.CHANNELS[(i - RigDef.ROOT_CH) % RigDef.STRIDE]]


static func _beats(clip: ClipDef, file: String, frames: Array[PackedFloat32Array], xfs: Array, out: Array) -> void:
	var rig := clip.rig
	var acc := clip.beat("accent")
	if acc.x >= 0:
		if acc.y - acc.x > ACCENT_MAX:
			out.append(finding("A05_accent_length", file, acc.x, "accent lasts %d f (max %d)" % [acc.y - acc.x, ACCENT_MAX]))
		var peak := 0.0
		for f in range(maxi(0, acc.x - 1), mini(acc.y, clip.length)):
			for p in rig.names.size():
				var i := RigDef.ch(p, RigDef.C_ROT)
				peak = maxf(peak, absf(frames[f + 1][i] - frames[f][i]))
		if peak < ACCENT_SPEED:
			out.append(finding("A06_accent_speed", file, acc.x, "mushy accent: peak %.1f°/f (need ≥ %.0f°/f on some part)" % [peak, ACCENT_SPEED]))
		var ant := clip.beat("anticipation")
		if ant.x >= 0:
			var chans := _cont_channels(rig, false)
			var dot := 0.0
			var a0 := frames[ant.x]
			var a1 := frames[clampi(acc.x - 1, 0, clip.length)]
			var x0 := frames[clampi(acc.x - 1, 0, clip.length)]
			var x1 := frames[clampi(acc.y, 0, clip.length)]
			for c in chans:
				var i2: int = c[0]
				var w: float = c[1]
				dot += (a1[i2] - a0[i2]) * w * (x1[i2] - x0[i2]) * w
			if dot >= 0.0:
				out.append(finding("A07_antic_opposes", file, ant.x, "anticipation moves WITH the accent (dot %.0f ≥ 0): wind up the other way" % dot))
			var b0 := RigBounds.bbox(rig, a1, xfs[clampi(acc.x - 1, 0, clip.length)])
			var b1 := RigBounds.bbox(rig, x1, xfs[clampi(acc.y, 0, clip.length)])
			var ch := 0.0
			if b0.size.x > 0.0 and b0.size.y > 0.0:
				ch = maxf(absf(b1.size.x - b0.size.x) / b0.size.x, absf(b1.size.y - b0.size.y) / b0.size.y)
				ch = maxf(ch, absf(b1.get_area() - b0.get_area()) / b0.get_area())
			if ch < BBOX_MIN:
				out.append(finding("A18_silhouette_change", file, acc.x, "silhouette changes only %d%% from anticipation to accent (need ≥ %d%%)" % [int(ch * 100.0), int(BBOX_MIN * 100.0)]))


static func _dead_hold(clip: ClipDef, file: String, frames: Array[PackedFloat32Array], out: Array) -> void:
	var n := clip.length
	var span := COLD_DEAD_SPAN if is_cold_or_curtain(clip) else DEAD_SPAN
	if n < span:
		return
	# Most active channels first: a moving window exits on its first channel.
	var chans := _cont_channels(clip.rig, true)
	var act := {}
	for c0 in chans:
		var tv := 0.0
		var ci: int = c0[0]
		for k0 in n:
			tv += absf(frames[k0 + 1][ci] - frames[k0][ci])
		act[ci] = tv * float(c0[1])
	chans = chans.filter(func(c1: Array) -> bool: return float(act[c1[0]]) > 0.0)
	chans.sort_custom(func(a: Array, b: Array) -> bool: return float(act[a[0]]) > float(act[b[0]]))
	var frozen := PackedByteArray()
	frozen.resize(n + 1)
	for e in clip.events:
		if String(e.get("type", "")) == "freeze":
			var f0 := int(e["f"])
			for f in range(f0, mini(n, f0 + int(e.get("frames", 0))) + 1):
				frozen[f] = 1
	var f := 0
	while f + span - 1 <= n:
		var dead := true
		for c in chans:
			var i: int = c[0]
			var w: float = c[1]
			var lo := INF
			var hi := -INF
			for k in range(f, f + span):
				lo = minf(lo, frames[k][i])
				hi = maxf(hi, frames[k][i])
			if (hi - lo) * w >= DEAD_EPS:
				dead = false
				break
		if dead:
			var covered := true
			for k2 in range(f, f + span):
				if frozen[k2] == 0:
					covered = false
					break
			if not covered:
				var end := f + span - 1
				out.append(finding("A09_dead_hold", file, f, "no motion for ≥ %d f (%d–%d): make it a moving hold (drift, tremble) or add a freeze event" % [span, f, end]))
				return
		f += 1


static func _pops(clip: ClipDef, file: String, frames: Array[PackedFloat32Array], out: Array) -> void:
	var rig := clip.rig
	var smears := PackedInt32Array()
	for e in clip.events:
		if String(e.get("type", "")) == "smear":
			smears.append(int(e["f"]))
	for f in clip.length:
		for p in rig.names.size():
			var i := RigDef.ch(p, RigDef.C_ROT)
			var d := absf(frames[f + 1][i] - frames[f][i])
			if d <= POP_DEG:
				continue
			var ok := false
			for k in clip.key_f.size():
				if clip.key_f[k] > f and clip.key_f[k] <= f + 1 and clip.key_ease[k] == RigEase.POP:
					ok = true
			for s in smears:
				if absi(s - (f + 1)) <= 1:
					ok = true
			if not ok:
				out.append(finding("A10_pop_jump", file, f + 1, "%s jumps %.0f°/f without a pop key or smear" % [rig.names[p], d]))
				return


static func _twinning(clip: ClipDef, file: String, frames: Array[PackedFloat32Array], out: Array) -> void:
	var rig := clip.rig
	var pairs := PackedInt32Array()
	for i in rig.names.size():
		var j := rig.mirror_idx[i]
		if j > i:
			pairs.append(i)
			pairs.append(j)
	if pairs.is_empty():
		return
	var run := 0
	for f in frames.size():
		var twin := true
		for k in range(0, pairs.size(), 2):
			var a := frames[f][RigDef.ch(pairs[k], RigDef.C_ROT)]
			var b := frames[f][RigDef.ch(pairs[k + 1], RigDef.C_ROT)]
			if absf(a - b) >= TWIN_DEG:
				twin = false
				break
		run = run + 1 if twin else 0
		if run > TWIN_SPAN:
			out.append(finding("A11_twinning", file, f - run + 1, "left and right move identically for > %d f: offset one side" % TWIN_SPAN))
			return


static func _feet(clip: ClipDef, file: String, frames: Array[PackedFloat32Array], xfs: Array, out: Array) -> void:
	var rig := clip.rig
	var travel := clip.stride_px / float(maxi(1, clip.length)) if clip.stride_px > 0.0 else 0.0
	for foot in rig.feet:
		for f in frames.size():
			var xf: Array[Transform2D] = []
			xf.assign(xfs[f])
			var pts := sole_points(rig, frames[f], xf, foot)
			var low := maxf(pts[0].y, maxf(pts[1].y, pts[2].y))
			if low > FLOOR_MAX:
				out.append(finding("A13_floor", file, f, "%s sole %.1f px below the floor (max %.0f)" % [rig.names[foot], low, FLOOR_MAX]))
				break
	_plant_drift(clip, file, frames, xfs, travel, DRIFT_MAX, "A12_feet_planted", out)
	for f2 in frames.size():
		var xf2: Array[Transform2D] = []
		xf2.assign(xfs[f2])
		var lo2 := RigBounds.limb_lowest(rig, xf2)
		if lo2 > FLOOR_MAX + 6.0:
			out.append(finding("A13_floor", file, f2, "a limb reaches %.1f px below the floor" % lo2))
			break


## Planted-foot drift: over every run of frames where a foot's contact point (sole centre when
## flat, else heel / toe) sits on the floor, its world x (x + `travel` px per frame: the
## character's own motion) must stay within `max_px`. One finding per foot run over the limit.
static func _plant_drift(clip: ClipDef, file: String, frames: Array[PackedFloat32Array], xfs: Array, travel: float, max_px: float, rule: String, out: Array) -> void:
	var rig := clip.rig
	for foot in rig.feet:
		var run_x := PackedFloat32Array()
		var run_f0 := -1
		var run_kind := -1
		for f in frames.size():
			var xf: Array[Transform2D] = []
			xf.assign(xfs[f])
			var pts := sole_points(rig, frames[f], xf, foot)
			var kind := -1
			var flat := absf(rad_to_deg(xf[foot].get_rotation())) <= 3.0
			if flat and pts[1].y >= PLANT_Y:
				kind = 1
			elif pts[0].y >= PLANT_Y and pts[0].y >= pts[2].y:
				kind = 0
			elif pts[2].y >= PLANT_Y:
				kind = 2
			var last := f == frames.size() - 1
			if run_f0 >= 0 and (kind != run_kind or last):
				if kind == run_kind and last:
					run_x.append(pts[kind].x + travel * float(f))
				_drift(rig, file, foot, run_f0, run_x, max_px, rule, out)
				run_f0 = -1
			if kind >= 0 and run_f0 < 0 and not last:
				run_f0 = f
				run_kind = kind
				run_x = PackedFloat32Array()
			if kind >= 0 and run_f0 >= 0:
				run_x.append(pts[kind].x + travel * float(f))


static func _drift(rig: RigDef, file: String, foot: int, f0: int, xs: PackedFloat32Array, max_px: float, rule: String, out: Array) -> void:
	if xs.size() < 2:
		return
	var lo := INF
	var hi := -INF
	for v in xs:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if hi - lo > max_px:
		out.append(finding(rule, file, f0, "planted %s slides %.1f px over f%d–%d (max %.0f)" % [rig.names[foot], hi - lo, f0, f0 + xs.size() - 1, max_px]))


## Heel, centre and toe of a foot's sole (bottom edge at 15 / 50 / 85 % of its canvas,
## inset by the canvas margin), character space.
static func sole_points(rig: RigDef, pose: PackedFloat32Array, xf: Array[Transform2D], foot: int) -> PackedVector2Array:
	var s := RigBounds.part_size(rig, pose, foot)
	var y := s.y - RigBounds.MARGIN
	var piv := rig.pivot[foot]
	return PackedVector2Array([xf[foot] * (Vector2(s.x * 0.15, y) - piv), xf[foot] * (Vector2(s.x * 0.5, y) - piv), xf[foot] * (Vector2(s.x * 0.85, y) - piv)])


static func _events(clip: ClipDef, file: String, out: Array) -> void:
	var acc := clip.beat("accent")
	var acc_end := acc.y if acc.x >= 0 else clip.mark("accent")
	for e in clip.events:
		var t := String(e.get("type", ""))
		var f := int(e.get("f", -1))
		match t:
			"sfx":
				if bool(e.get("sync", true)) and not clip.near_key(f, 1):
					out.append(finding("A14_sfx_on_key", file, f, "sfx '%s' is not within ±1 f of a key" % e.get("id", "")))
			"face":
				if clip.key_at(f) < 0:
					out.append(finding("A15_face_on_key", file, f, "face swap between keys: put it on a key"))
			"laugh":
				if acc_end >= 0 and f < acc_end:
					out.append(finding("A16_laugh_after_accent", file, f, "laugh before the accent lands (accent ends f%d)" % acc_end))
			"mark":
				var mn := String(e.get("name", ""))
				if not MARK_NAMES.has(mn):
					out.append(finding("A22_marks", file, f, "mark '%s' is not one the sim reads (accent, release, knock_on)" % mn, "warning"))


static func _reaction(clip: ClipDef, file: String, out: Array) -> void:
	if not clip.is_reaction():
		return
	var sig := clip.short_name().begins_with("sig_")
	if not clip.skippable:
		var mx := SIGNATURE_MAX if sig else REACTION_MAX
		if clip.length < REACTION_MIN or clip.length > mx:
			out.append(finding("A17_reaction_length", file, -1, "reaction lasts %d f (allowed %d–%d unless skippable)" % [clip.length, REACTION_MIN, mx]))
	for bn in ["anticipation", "accent", "hold", "settle"]:
		if not clip.beats.has(bn):
			out.append(finding("A21_reaction_beats", file, -1, "reaction clips need a '%s' beat" % bn))
	var h := clip.beat("hold")
	if h.x >= 0:
		var hl := h.y - h.x
		if hl < HOLD_MIN:
			out.append(finding("A08_hold_length", file, h.x, "hold is %d f (need ≥ %d)" % [hl, HOLD_MIN]))
		elif hl + PlayPlan.stretch_extra(hl, 2) < HOLD_MIN_T2:
			out.append(finding("A08_hold_length", file, h.x, "tier-2 hold is %d f (need ≥ %d)" % [hl + PlayPlan.stretch_extra(hl, 2), HOLD_MIN_T2]))
	if clip.time_jitter != 0.0:
		out.append(finding("A20_time_jitter", file, -1, "reaction clips must have variation.time_jitter 0 (sim-timed)"))
	var entry := ReactionTable.entry_for_clip(clip.id)
	if entry.is_empty():
		return
	var marks: Dictionary = entry.get("marks", {}) if entry.get("marks", {}) is Dictionary else {}
	var checks: Array = [["frames", int(entry.get("frames", clip.length)), clip.length]]
	if marks.has("antic") and clip.beats.has("anticipation"):
		checks.append(["antic", int(marks["antic"]), clip.beat("anticipation").x])
	if marks.has("accent") and clip.beats.has("accent"):
		checks.append(["accent", int(marks["accent"]), clip.beat("accent").x])
	if marks.get("hold", null) is Array and clip.beats.has("hold"):
		checks.append(["hold start", int(marks["hold"][0]), h.x])
		checks.append(["hold end", int(marks["hold"][1]), h.y])
	if marks.has("release"):
		var rel := clip.mark("release") if clip.mark("release") >= 0 else clip.length
		checks.append(["release", int(marks["release"]), rel])
	for c in checks:
		if absi(int(c[1]) - int(c[2])) > BEAT_TOL:
			out.append(finding("A19_beats_match", file, int(c[2]), "%s is f%d but reactions.json (%s) says f%d" % [c[0], c[2], entry.get("archetype", "?"), c[1]]))
