## ViewDataLint — the view data of the 3D slice (REDESIGN_3D §6.2 C4, `r3d-index.md` §7.10), part of the content
## lint: `data/view/previews.json` (per prank: pictogram ids, the needed item, "combines with" badges) and
## `data/anim/hush3d/rig_actions.json` (prep tiers, reach bands, per prank: hotspot, tier, band, clip, prop anim,
## held prop, step, glance marks, noise rings). Ids resolve; every slice prank is covered; tiers and hotspots equal
## `pranks.json`; with `data/house/house3d.json` (`r3d-sets`), every band equals the band of the placed reach
## target's world y and every step equals its `reach_pos.step` (one source of truth, two checks).
##
##   var errs := ViewDataLint.lint(parts, data)       # parts from ContentLint.load_parts (previews, rig_actions, house3d)
##   var reach := ViewDataLint.derive_reach(house3d, prank_ids, data)   # {prank: {band, step, y_m, source}}
class_name ViewDataLint
extends RefCounted

## The slice episodes whose pranks the view data must cover.
const SLICE: PackedStringArray = ["p00_curtain_up", "g0_sneeze", "n01_throat_tea", "n02_something_fishy"]
const TIERS := {"q": 48, "s": 90, "b": 150}
const PREP_OF_TIER := {"q": "Q", "s": "S", "b": "B"}
const BANDS: PackedStringArray = ["low", "mid", "high"]
## Band limits by the glove's world y (m, R5c): low < 0.55 ≤ mid < 1.40 ≤ high ≤ 2.15; above 1.70 she needs a step.
const LOW_TOP := 0.55
const MID_TOP := 1.40
const HIGH_TOP := 2.15
const STEP_ABOVE := 1.70
const PX_PER_M := 200.0
const FLOOR_PITCH_M := 3.5


## Every prank the slice Nights name (Script lines, Double Acts, `nights`), sorted.
static func slice_pranks(data: SolverData) -> PackedStringArray:
	var out := PackedStringArray()
	for ep in SLICE:
		if not data.episodes.has(ep):
			continue
		for p in data.named_pranks(ep):
			if not out.has(p):
				out.append(p)
	out.sort()
	return out


## All view-data errors of `parts` (keys `previews`, `rig_actions`, `house3d`; a missing file is an error only for
## the two content files, `house3d` is optional until `r3d-sets` lands it).
static func lint(parts: Dictionary, data: SolverData) -> PackedStringArray:
	var e := PackedStringArray()
	var sl := slice_pranks(data)
	if sl.is_empty():
		return e
	e.append_array(check_previews(parts.get("previews", null), data, sl))
	var h3: Variant = parts.get("house3d", null)
	e.append_array(check_rig_actions(parts.get("rig_actions", null), data, sl, h3 if h3 is Dictionary and not (h3 as Dictionary).is_empty() else null))
	return e


## previews.json errors.
static func check_previews(p: Variant, data: SolverData, slice: PackedStringArray) -> PackedStringArray:
	var e := PackedStringArray()
	if not (p is Dictionary) or (p as Dictionary).is_empty():
		e.append("view/previews.json: missing or not an object")
		return e
	var d: Dictionary = p
	if int(d.get("version", 0)) != 1:
		e.append("view/previews.json: version must be 1")
	var pr: Variant = d.get("pranks", null)
	if not (pr is Dictionary):
		e.append("view/previews.json: pranks must be an object")
		return e
	for id in slice:
		if not (pr as Dictionary).has(id):
			e.append("previews.json: %s missing (every slice prank needs its preview)" % id)
	for id in (pr as Dictionary):
		var pid := String(id)
		var x: Variant = pr[id]
		if not data.pranks.has(pid):
			e.append("previews.json: '%s' not in pranks.json" % pid)
			continue
		if not (x is Dictionary):
			e.append("previews.json: %s must be an object" % pid)
			continue
		var pic: Variant = (x as Dictionary).get("pictogram", null)
		if not (pic is Array) or (pic as Array).is_empty():
			e.append("previews.json: %s.pictogram is empty (the joke needs 1–4 pictogram ids)" % pid)
		else:
			if (pic as Array).size() > 4:
				e.append("previews.json: %s.pictogram has %d ids (≤ 4 read in half a second)" % [pid, (pic as Array).size()])
			for g in pic:
				if not (g is String) or not _is_snake(String(g)):
					e.append("previews.json: %s.pictogram id %s must be a snake_case string" % [pid, str(g)])
		var need: Variant = (x as Dictionary).get("needs", "missing")
		var want := ""
		for i in data.prank_steps(pid).size():
			if data.step_needs(pid, i) != "":
				want = data.step_needs(pid, i)
				break
		if need is String and String(need) != "missing" and String(need) != want:
			e.append("previews.json: %s.needs '%s' is not its item ('%s')" % [pid, need, want])
		elif need == null and want != "":
			e.append("previews.json: %s.needs is null but the prank needs '%s'" % [pid, want])
		elif need is String and String(need) == "missing":
			e.append("previews.json: %s.needs missing (item id or null)" % pid)
		var comb: Variant = (x as Dictionary).get("combines", [])
		if not (comb is Array):
			e.append("previews.json: %s.combines must be a list" % pid)
		else:
			for c in comb:
				var w := String((c as Dictionary).get("with", "")) if c is Dictionary else ""
				if not data.pranks.has(w):
					e.append("previews.json: %s.combines.with '%s' not in pranks.json" % [pid, w])
				elif c is Dictionary and not _is_snake(String((c as Dictionary).get("badge", ""))):
					e.append("previews.json: %s.combines badge must be a snake_case id" % pid)
	return e


## rig_actions.json errors; `house3d` (or null) adds the band / step derivation check.
static func check_rig_actions(r: Variant, data: SolverData, slice: PackedStringArray, house3d: Variant) -> PackedStringArray:
	var e := PackedStringArray()
	if not (r is Dictionary) or (r as Dictionary).is_empty():
		e.append("anim/hush3d/rig_actions.json: missing or not an object")
		return e
	var d: Dictionary = r
	if int(d.get("version", 0)) != 1:
		e.append("rig_actions.json: version must be 1")
	var tiers: Variant = d.get("tiers", {})
	for t in TIERS:
		if not (tiers is Dictionary) or int((tiers as Dictionary).get(t, -1)) != int(TIERS[t]):
			e.append("rig_actions.json: tiers.%s must be %d frames (the prep tier)" % [t, TIERS[t]])
	var bands: Variant = d.get("bands", {})
	for b in BANDS:
		var bd: Variant = (bands as Dictionary).get(b, null) if bands is Dictionary else null
		if not (bd is Dictionary):
			e.append("rig_actions.json: bands.%s missing" % b)
			continue
		var g: Variant = (bd as Dictionary).get("glove_y_m", null)
		if not (g is Array) or (g as Array).size() != 2 or float(g[0]) >= float(g[1]):
			e.append("rig_actions.json: bands.%s.glove_y_m must be [lo, hi] m" % b)
		if not String((bd as Dictionary).get("clip", "")).begins_with("hush/"):
			e.append("rig_actions.json: bands.%s.clip must be a hush/ clip id" % b)
	var pr: Variant = d.get("pranks", null)
	if not (pr is Dictionary):
		e.append("rig_actions.json: pranks must be an object")
		return e
	for id in slice:
		if not (pr as Dictionary).has(id):
			e.append("rig_actions.json: %s missing (every slice prank needs its rig action)" % id)
	var derived := derive_reach(house3d, (pr as Dictionary).keys(), data) if house3d is Dictionary else {}
	for id in (pr as Dictionary):
		var pid := String(id)
		var x: Variant = pr[id]
		if not data.pranks.has(pid):
			e.append("rig_actions.json: '%s' not in pranks.json" % pid)
			continue
		if not (x is Dictionary):
			e.append("rig_actions.json: %s must be an object" % pid)
			continue
		var a: Dictionary = x
		var hs := String(a.get("hotspot", ""))
		if hs != data.rig_point(pid, 0):
			e.append("rig_actions.json: %s.hotspot '%s' is not its rig_point '%s'" % [pid, hs, data.rig_point(pid, 0)])
		var tier := String(a.get("tier", ""))
		var prep := SolverData.sv((data.prank_steps(pid)[0] as Dictionary).get("prep", "Q"))
		if not PREP_OF_TIER.has(tier) or PREP_OF_TIER[tier] != prep:
			e.append("rig_actions.json: %s.tier '%s' is not its prep '%s' (q/s/b)" % [pid, tier, prep])
		var band := String(a.get("band", ""))
		if not BANDS.has(band):
			e.append("rig_actions.json: %s.band '%s' not low|mid|high" % [pid, band])
		var clip: Variant = a.get("clip", null)
		if clip != null and not (clip is String and String(clip).begins_with("hush/")):
			e.append("rig_actions.json: %s.clip must be null (the band clip) or a hush/ clip id" % pid)
		if not (a.get("prop_anim", "") is String) or String(a.get("prop_anim", "")) == "":
			e.append("rig_actions.json: %s.prop_anim must name the prop's animation" % pid)
		var held: Variant = a.get("held", null)
		if held != null and not (held is String):
			e.append("rig_actions.json: %s.held must be null or a prop id" % pid)
		var step: Variant = a.get("step", null)
		if step != null and not (step is String and (String(step) == "mime" or String(step).begins_with("stool:"))):
			e.append("rig_actions.json: %s.step '%s' not null | \"stool:<furniture>\" | \"mime\"" % [pid, str(step)])
		var gl: Variant = a.get("glances", [])
		var ok_gl := gl is Array
		var prev := -1
		if ok_gl:
			for v in gl:
				if not (v is float or v is int) or int(v) <= prev or int(v) <= 0 or int(v) >= 1000:
					ok_gl = false
				prev = int(v) if (v is float or v is int) else prev
		if not ok_gl:
			e.append("rig_actions.json: %s.glances must be ascending ‰ of rig progress in 1..999" % pid)
		if not (a.get("noise_rings", null) is bool):
			e.append("rig_actions.json: %s.noise_rings must be true or false" % pid)
		if derived.has(pid):
			var dv: Dictionary = derived[pid]
			if String(dv.get("band", "")) != "" and band != String(dv["band"]):
				e.append("rig_actions.json: %s.band '%s' ≠ house3d.json's placed reach target (%s, y %.2f m, %s)" % [
					pid, band, dv["band"], float(dv.get("y_m", -1.0)), dv.get("source", "")])
			if dv.has("step") and step != dv["step"]:
				e.append("rig_actions.json: %s.step %s ≠ house3d.json reach_pos.step %s" % [pid, str(step), str(dv["step"])])
			if float(dv.get("y_m", -1.0)) > STEP_ABOVE and dv.get("step", null) == null:
				e.append("house3d.json: %s's reach target is at %.2f m (> %.2f m): reach_pos needs a step (stool or mime)" % [
					hs, float(dv["y_m"]), STEP_ABOVE])
	return e


## Band + step per prank from `house3d.json` (`r3d-index.md` §7.4): the band of the placed reach target's world y
## (rect bottom-y + visual_offset.y + reach_target.y × scale + the floor) when the hotspot has a `reach_target`,
## else its `reach` field; the step is `reach_pos.step`. {prank: {band, step, y_m (−1 unknown), source}}.
static func derive_reach(house3d: Variant, prank_ids: Array, data: SolverData) -> Dictionary:
	var out := {}
	if not (house3d is Dictionary):
		return out
	var hot: Dictionary = (house3d as Dictionary).get("hotspots", {}) if (house3d as Dictionary).get("hotspots", {}) is Dictionary else {}
	for pid_v in prank_ids:
		var pid := String(pid_v)
		var hs := data.rig_point(pid, 0)
		if not hot.has(hs) or not (hot[hs] is Dictionary):
			continue
		var h3: Dictionary = hot[hs]
		var rec := {"band": "", "y_m": -1.0, "source": ""}
		var y := world_reach_y(h3, data.hotspot(hs), data)
		if y >= 0.0:
			rec["y_m"] = y
			rec["band"] = band_of(y)
			rec["source"] = "reach_target"
		elif h3.get("reach", null) is String:
			rec["band"] = String(h3["reach"])
			rec["source"] = "reach"
		var rp: Variant = h3.get("reach_pos", null)
		if rp is Dictionary:
			var st: Variant = (rp as Dictionary).get("step", null)
			rec["step"] = String(st) if st is String and String(st) != "" else null
		out[pid] = rec
	return out


## World y (m) of a placed reach target, −1 when `reach_target` is absent: floor + rect bottom-y + visual_offset.y +
## reach_target.y × scale (the prop frame of `r3d-index.md` §7.4; anchors in metres before `scale`).
static func world_reach_y(h3: Dictionary, h: Dictionary, data: SolverData) -> float:
	var rt: Variant = h3.get("reach_target", null)
	var rect: Variant = h.get("rect", null)
	if not (rt is Array) or (rt as Array).size() < 2 or not (rect is Array) or (rect as Array).size() != 4:
		return -1.0
	var vo: Variant = h3.get("visual_offset", null)
	var dy := float(vo[1]) if vo is Array and (vo as Array).size() >= 2 else 0.0
	var sc := float(h3.get("scale", 1.0))
	var bottom_m := -(float(rect[1]) + float(rect[3])) / PX_PER_M
	var fl := data.room_floor(SolverData.sv(h.get("room", "")))
	return FLOOR_PITCH_M * maxf(0.0, float(fl)) + bottom_m + dy + float(rt[1]) * sc


## The reach band of a glove height (m).
static func band_of(y_m: float) -> String:
	if y_m < LOW_TOP:
		return "low"
	if y_m < MID_TOP:
		return "mid"
	return "high"


static func _is_snake(s: String) -> bool:
	if s == "":
		return false
	for ch in s:
		if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_"):
			return false
	return true
