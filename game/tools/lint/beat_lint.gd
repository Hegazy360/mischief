## BeatLint — the D1 content rules (s2-sim §4.5.6) over the raw `game/data/**` JSON:
##
##  (a) cadence: every activity and fix-up detour a `final` Night uses has micro-gags with no gap > 8 s over its
##      `dur_s` (from the start, between beats — the list repeats every `mg_cycle_s` —, to the end) and ≥ 5 s between
##      beats; a gated activity (it performs until the player acts) is checked over its cycle, wrap included, and
##      must have beats at all;
##  (b) every `emote` (activities, detours, `walk_beats`) is in the HUD edge-bubble vocabulary (`SimEvents.EMOTES`)
##      or null;
##  (c) coverage: every clip the slice can play exists under `data/anim/<clip>.json` — the list is `SliceClips.build()`
##      (s2-view, ruling L14: the one manifest; soft-loaded) or, until that exists, this lint's own derivation
##      (activity / detour clips, `mg_<id>`, squeak-bit clips, the pranks' reaction clips, the last beats). Coverage
##      is a WARNING; `lint.sh --strict` (the pre-gate) makes it an error.
##
##   var errs := BeatLint.lint(parts)                      # (a) + (b), parts = ContentLint.load_parts(root)
##   var cov := BeatLint.coverage(parts, "res://data")     # {missing, source, rows}
class_name BeatLint
extends RefCounted

const MAX_GAP_S := 8.0
const MIN_SPACING_S := 5.0
## Legacy micro-gag spacing (the string-list form), as the sim reads it (ActivityDef).
const LEGACY_FIRST_S := 2.0
const LEGACY_EVERY_S := 6.0
const CYCLE_PAD_S := 6.0
## Detours in which beats never play (the sim suppresses them in CURIOUS / SEARCH; the herd is Stage 3).
const NO_BEAT_DETOURS: PackedStringArray = ["curious", "search", "herd_beryl"]
const SLICE_CLIPS := "res://view/world/slice_clips.gd"
## The slice episodes the fallback coverage derivation walks (every episode of a set that has none of them).
const SLICE_EPISODES: PackedStringArray = ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy", "g0_sneeze"]
const SLOW_BURN := "bellows/beat_slow_burn"
const EMOTES: PackedStringArray = ["sing", "hum", "smug", "laugh", "tut", "sniff", "yum", "yawn"]


## (a) + (b): error messages ("activities.json: <where>: <what>").
static func lint(parts: Dictionary) -> PackedStringArray:
	var e := PackedStringArray()
	var acd: Dictionary = parts.get("activities", {})
	var acts: Dictionary = acd.get("activities", {}) if acd.get("activities", {}) is Dictionary else {}
	var dets: Dictionary = acd.get("detours", {}) if acd.get("detours", {}) is Dictionary else {}
	for group in [["activities", acts], ["detours", dets]]:
		var tbl: Dictionary = group[1]
		for id in _sorted(tbl):
			var a: Variant = tbl[id]
			if a is Dictionary:
				for g in _gags(a as Dictionary):
					if not (g is Dictionary):
						continue   # the legacy id-string form has no emote
					var em: Variant = (g as Dictionary).get("emote", null)
					if em != null and not EMOTES.has(str(em)):
						e.append("activities.json: %s.%s micro_gags '%s' emote '%s' not in %s" % [group[0], id,
							(g as Dictionary).get("id", "?"), em, ", ".join(EMOTES)])
	var wb: Variant = acd.get("walk_beats", null)
	if wb is Dictionary:
		for g in (wb as Dictionary).get("ids", []):
			if g is Dictionary and (g as Dictionary).get("emote", null) != null and not EMOTES.has(str(g["emote"])):
				e.append("activities.json: walk_beats '%s' emote '%s' not in %s" % [g.get("id", "?"), g["emote"], ", ".join(EMOTES)])
	# (a) what the final Nights use
	var used := used_by_final(parts)
	for id in _sorted(used):
		var gated: bool = used[id]
		var a2: Variant = acts.get(id, dets.get(id, null))
		if not (a2 is Dictionary):
			continue
		for m in cadence(id, a2 as Dictionary, gated):
			e.append("activities.json: %s" % m)
	return e


## {activity or detour id: gated (bool)} for every loop activity of a `final` episode (gated = a gate on any of
## its loop entries) and every fix-up detour one of its Script pranks can cause (by its residues).
static func used_by_final(parts: Dictionary) -> Dictionary:
	var out := {}
	var pranks: Dictionary = (parts.get("pranks", {}) as Dictionary).get("pranks", {})
	var das: Dictionary = (parts.get("pranks", {}) as Dictionary).get("double_acts", {})
	var residues: Dictionary = (parts.get("residues", {}) as Dictionary).get("residues", {})
	var eps: Dictionary = parts.get("episodes", {})
	for eid in _sorted(eps):
		var ep: Dictionary = eps[eid]
		if SolverData.sv(ep.get("status", "")) != "final":
			continue
		var b: Dictionary = ep.get("bellows", {}) if ep.get("bellows", {}) is Dictionary else {}
		for le in b.get("loop", []):
			if not (le is Dictionary):
				continue
			var aid := SolverData.sv((le as Dictionary).get("a", ""))
			var gated := (le as Dictionary).get("gate", null) is Dictionary
			out[aid] = bool(out.get(aid, false)) or gated
		var ps := PackedStringArray()
		for l in ep.get("script", []):
			if not (l is Dictionary):
				continue
			var pid := SolverData.sv((l as Dictionary).get("prank", ""))
			if pid != "":
				ps.append(pid)
			var da: Variant = das.get(SolverData.sv((l as Dictionary).get("double_act", "")), null)
			if da is Dictionary:
				for side in ["a", "b"]:
					if (da as Dictionary).get(side, null) != null:
						ps.append(SolverData.sv(da[side]))
		for pid in ps:
			var p: Variant = pranks.get(pid, null)
			if not (p is Dictionary):
				continue
			for r in (p as Dictionary).get("residue", []):
				if not (r is Dictionary):
					continue
				var res: Variant = residues.get(SolverData.sv((r as Dictionary).get("kind", "")), null)
				if res is Dictionary:
					var fk := SolverData.sv((res as Dictionary).get("fixup", ""))
					if fk != "":
						out["fixup_" + fk.to_lower()] = bool(out.get("fixup_" + fk.to_lower(), false))
	for d in NO_BEAT_DETOURS:
		out.erase(d)
	return out


## Cadence problems of one activity (messages without the file prefix).
static func cadence(id: String, a: Dictionary, gated: bool) -> PackedStringArray:
	var e := PackedStringArray()
	var at := PackedFloat64Array()
	var i := 0
	for g in _gags(a):
		if g is Dictionary:
			at.append(float((g as Dictionary).get("at_s", LEGACY_FIRST_S)))
		else:
			at.append(LEGACY_FIRST_S + LEGACY_EVERY_S * i)
		i += 1
	var dur := float(a.get("dur_s", 0.0))
	if at.is_empty():
		if gated:
			e.append("%s: no micro_gags, but a gated Night holds him here until the player acts (D1: a beat every 5–8 s)" % id)
		elif dur > MAX_GAP_S:
			e.append("%s: no micro_gags over its %.1f s (D1: no gap > %.0f s)" % [id, dur, MAX_GAP_S])
		return e
	var cycle := float(a["mg_cycle_s"]) if a.get("mg_cycle_s", null) != null else at[at.size() - 1] + CYCLE_PAD_S
	# the beats over the whole performance: the list repeats every cycle
	var times := PackedFloat64Array()
	var span := dur if not gated else cycle + at[0]
	var k := 0
	while k * cycle < span + 0.001 and k < 64:
		for t in at:
			var tt: float = k * cycle + t
			if tt < span - 0.001 or (gated and tt <= span + 0.001):
				times.append(tt)
		k += 1
	var prev := 0.0
	var where := "start"
	for t in times:
		if t - prev > MAX_GAP_S + 0.001:
			e.append("%s: %.1f s without a micro-gag (%s → %.1f s; D1 max %.0f s)" % [id, t - prev, where, t, MAX_GAP_S])
		if where != "start" and t - prev < MIN_SPACING_S - 0.001:
			e.append("%s: micro-gags only %.1f s apart (%.1f s → %.1f s; min %.0f s)" % [id, t - prev, prev, t, MIN_SPACING_S])
		prev = t
		where = "%.1f s" % t
	if not gated and dur - prev > MAX_GAP_S + 0.001:
		e.append("%s: %.1f s without a micro-gag (%s → the end at %.1f s; D1 max %.0f s)" % [id, dur - prev, where, dur, MAX_GAP_S])
	return e


## (c3d, R3D ruling R9) The 3D clip coverage: every clip of `SliceClips.build3d(["g0_sneeze", "p00_curtain_up"])` + the
## band fallbacks `hush/rig_high|mid|low` must exist as a v2 sidecar (`data/anim/<rig>3d/<clip>.json`, `"version": 2`) —
## `missing` (WARN; an error under `--strict`); the N01/N02-only rows of `build3d(["n01_throat_tea",
## "n02_something_fishy"])` are reported as `info_missing` (never failing). Soft: `source` "none" (no rows) until
## `r3d-view3d`'s build3d exists. {missing, rows, source, info_missing, info_rows}.
static func coverage3d(data_root: String = "res://data") -> Dictionary:
	var out := {"missing": PackedStringArray(), "rows": 0, "source": "none", "info_missing": PackedStringArray(), "info_rows": 0}
	if data_root != "res://data" or not ResourceLoader.exists(SLICE_CLIPS):
		return out
	var s: Script = load(SLICE_CLIPS) as Script
	if s == null or not s.can_instantiate() or not (s as GDScript).has_method("build3d"):
		return out
	var gate := {}
	var rows: Variant = s.call("build3d", PackedStringArray(["g0_sneeze", "p00_curtain_up"]))
	if not (rows is Array):
		return out
	for r in rows:
		var c := SolverData.sv((r as Dictionary).get("clip", "")) if r is Dictionary else ""
		if c != "":
			gate[c] = true
	for b in BAND_CLIPS:
		gate[b] = true
	out["source"] = "SliceClips.build3d"
	out["rows"] = gate.size()
	var miss := PackedStringArray()
	for c in gate:
		if not sidecar3d_ok(String(c), data_root):
			miss.append(String(c))
	miss.sort()
	out["missing"] = miss
	var info := {}
	var rows2: Variant = s.call("build3d", PackedStringArray(["n01_throat_tea", "n02_something_fishy"]))
	if rows2 is Array:
		for r in rows2:
			var c2 := SolverData.sv((r as Dictionary).get("clip", "")) if r is Dictionary else ""
			if c2 != "" and not gate.has(c2):
				info[c2] = true
	var im := PackedStringArray()
	for c in info:
		if not sidecar3d_ok(String(c), data_root):
			im.append(String(c))
	im.sort()
	out["info_missing"] = im
	out["info_rows"] = info.size()
	return out


## The band fallback clips (normalised ‰, `rig_actions.json` bands) — in the R9 lint scope beyond build3d(g0, p00).
const BAND_CLIPS: PackedStringArray = ["hush/rig_high", "hush/rig_low", "hush/rig_mid"]


## True when `rig/clip` has a v2 3D sidecar (`data/anim/<rig>3d/<clip>.json` with `"version": 2`).
static func sidecar3d_ok(clip: String, data_root: String = "res://data") -> bool:
	var parts := clip.split("/", false, 1)
	if parts.size() != 2:
		return false
	var path := "%s/anim/%s3d/%s.json" % [data_root, parts[0], parts[1]]
	if not FileAccess.file_exists(path):
		return false
	var v: Variant = SolverData.read_json(path)
	return v is Dictionary and int((v as Dictionary).get("version", 0)) == 2


## (c) {missing: PackedStringArray (clip ids), source: "SliceClips" | "fallback", rows: int}.
static func coverage(parts: Dictionary, data_root: String = "res://data", use_manifest: bool = true) -> Dictionary:
	var clips := PackedStringArray()
	var source := "fallback"
	if use_manifest and data_root == "res://data" and ResourceLoader.exists(SLICE_CLIPS):
		var s: Script = load(SLICE_CLIPS) as Script
		if s != null and s.can_instantiate():
			var rows: Variant = s.call("build")
			if rows is Array:
				for r in rows:
					if r is Dictionary and SolverData.sv((r as Dictionary).get("clip", "")) != "":
						clips.append(SolverData.sv(r["clip"]))
				source = "SliceClips"
	if source == "fallback":
		clips = derive_clips(parts)
	var missing := PackedStringArray()
	for c in clips:
		if not FileAccess.file_exists("%s/anim/%s.json" % [data_root, c]):
			missing.append(c)
	missing.sort()
	return {"missing": missing, "source": source, "rows": clips.size()}


## The fallback manifest: every clip the slice episodes can play, derived from the data (sorted, unique).
static func derive_clips(parts: Dictionary) -> PackedStringArray:
	var acc := {}
	var acd: Dictionary = parts.get("activities", {})
	var acts: Dictionary = acd.get("activities", {}) if acd.get("activities", {}) is Dictionary else {}
	var dets: Dictionary = acd.get("detours", {}) if acd.get("detours", {}) is Dictionary else {}
	var bits: Dictionary = acd.get("squeak_bits", {}) if acd.get("squeak_bits", {}) is Dictionary else {}
	var rx: Dictionary = parts.get("reactions", {})
	var archs: Dictionary = rx.get("archetypes", {}) if rx.get("archetypes", {}) is Dictionary else {}
	var pranks: Dictionary = (parts.get("pranks", {}) as Dictionary).get("pranks", {})
	var eps: Dictionary = parts.get("episodes", {})
	var any := false
	var ids: Array = Array(SLICE_EPISODES)
	var present := false
	for eid in ids:
		present = present or eps.has(eid)
	if not present:
		ids = _sorted(eps)   # a fixture set: every episode it has
	for eid in ids:
		var ep: Variant = eps.get(eid, null)
		if not (ep is Dictionary):
			continue
		any = true
		var b: Dictionary = (ep as Dictionary).get("bellows", {}) if (ep as Dictionary).get("bellows", {}) is Dictionary else {}
		for le in b.get("loop", []):
			if le is Dictionary:
				_act_clips(acc, acts.get(SolverData.sv((le as Dictionary).get("a", "")), null), bits)
		for l in (ep as Dictionary).get("script", []):
			if l is Dictionary:
				_prank_clips(acc, pranks.get(SolverData.sv((l as Dictionary).get("prank", "")), null), archs)
	if any:
		for d in dets:
			_act_clips(acc, dets[d], bits)
		for c in rx.get("t3_last_beats", []):
			acc[SolverData.sv(c)] = true
		acc[SLOW_BURN] = true
	acc.erase("")
	var out := PackedStringArray(acc.keys())
	out.sort()
	return out


static func _act_clips(acc: Dictionary, a: Variant, bits: Dictionary) -> void:
	if not (a is Dictionary):
		return
	var ad: Dictionary = a
	if ad.get("clip", null) != null:
		acc[SolverData.sv(ad["clip"])] = true
	for g in _gags(ad):
		var gid := SolverData.sv((g as Dictionary).get("id", "")) if g is Dictionary else SolverData.sv(g)
		if gid != "":
			acc["bellows/mg_%s" % gid] = true
	var bit := SolverData.sv(ad.get("squeak_bit", ""))
	if bit != "" and bits.get(bit, null) is Dictionary:
		acc[SolverData.sv((bits[bit] as Dictionary).get("clip", ""))] = true


static func _prank_clips(acc: Dictionary, p: Variant, archs: Dictionary) -> void:
	if not (p is Dictionary):
		return
	var reac: Dictionary = (p as Dictionary).get("reaction", {}) if (p as Dictionary).get("reaction", {}) is Dictionary else {}
	var arch := SolverData.sv(reac.get("archetype", ""))
	var keys := PackedStringArray()
	for v in reac.get("variants", []):
		keys.append("%s_%s" % [arch, SolverData.sv(v)])
	if keys.is_empty():
		keys.append(arch if archs.has(arch) else arch + "_a")
	for k in keys:
		var row: Variant = archs.get(k, null)
		if row is Dictionary and (row as Dictionary).get("clip", null) != null:
			acc[SolverData.sv(row["clip"])] = true


static func _gags(a: Dictionary) -> Array:
	var g: Variant = a.get("micro_gags", [])
	return g if g is Array else []


static func _sorted(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k
