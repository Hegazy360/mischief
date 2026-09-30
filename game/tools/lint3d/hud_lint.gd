## HudLint3D — the REDESIGN §6.3 HUD lint on the e2e reports (`lint3d.sh --hud --from=<dir>`; index §6 row 11,
## brief r3d-tools-b §4.3). Reads each report's `hud_pieces` samples (every 30 PLAY frames: {frame, tick, pieces:
## [{name, rect [x, y, w, h], always_on, persistent}]}), `overlays` {max, loud_max, samples [[frame, shown, loud]]},
## `pip_on_share`, `pip_longest_s`, `pip_windows` (index §7.10).
##
## Rules:
## * **always_on_count** — ≤ 4 always-on pieces in every sample, and only pause, script (script_chip), clarence,
##   action (REDESIGN §2.1). Error.
## * **middle_band** — the band y 250–880 (at 1080 logical, scaled to the viewport) holds no always-on or persistent
##   rect (§2.5); *persistent* = the same piece seen in the band over a continuous run of samples spanning > 5 s.
##   The only contextual pieces allowed there: the edge badge inside the outer 160 px, the Figgis bust / card, the
##   pick strip. **Spec positions:** an always-on piece at exactly its §2.1 rect (the action button's 240 hit circle
##   reaches y 792, Clarence starts at 880) is REDESIGN's own layout — reported as info, not an error (r3d-hud's
##   request; a lead ruling is requested in the report); an always-on piece anywhere else in the band is an error.
##   The escalated Bellows window (704 × 396) and BOW under the open window (T+273) are placed in the band by §2.2
##   itself: a warning while transient (≤ 5 s), an error when persistent. Every other contextual piece in the band is
##   an error.
## * **overlays** — ≤ 6 world overlays of which ≤ 2 loud in every sample (V6). Error.
## * **window_share** — `pip_on_share` > 35 % is a WARNING (index R15: the Bellows window becoming the always-on PiP
##   the owner complained about), printed with `pip_longest_s` and the open/close ticks; never an error.
## Every offending sample is listed (frame, tick, pieces) in the issue's `samples`.
class_name HudLint3D
extends RefCounted

const LINT := "hud"
const MAX_ALWAYS_ON := 4
const ALWAYS_ON_NAMES: PackedStringArray = ["pause", "script", "script_chip", "clarence", "action"]
const BAND_Y0 := 250.0
const BAND_Y1 := 880.0
const PERSIST_S := 5.0
const MAX_OVERLAYS := 6
const MAX_LOUD := 2
const SHARE_WARN := 0.35
const SAMPLE_EVERY := 30
const SPEC_TOL_PX := 2.0
## Contextual pieces §2.5 lets into the band (short-lived, obeying the protected rects).
const BAND_OK: PackedStringArray = ["figgis", "figgis_card", "pick_strip"]
## Contextual pieces §2.2 itself places in the band (spec conflict with §2.5): warning while transient.
const BAND_SPEC_CONFLICT: PackedStringArray = ["pip", "bow"]
const OWNER_HUD := "r3d-hud"


## Lints one e2e report (`name` = its file stem). Returns {issues: Array, stats: Dictionary}.
static func check_report(report: Dictionary, name: String) -> Dictionary:
	var issues: Array = []
	var ep := String(report.get("episode", ""))
	var stats := {"report": name, "episode": ep, "scenario": String(report.get("scenario", name))}
	var samples: Array = report.get("hud_pieces", []) if report.get("hud_pieces", null) is Array else []
	if samples.is_empty():
		issues.append(Lint3D.skip(LINT, "hud_pieces", "%s has no hud_pieces samples (a 3D e2e report from r3d-night)" % name,
			"r3d-night", ep))
	else:
		var vp := viewport_of(report, samples)
		stats["viewport"] = [vp.x, vp.y]
		stats["samples"] = samples.size()
		issues.append_array(_always_on(samples, name, ep, stats))
		issues.append_array(_band(samples, vp, name, ep, stats))
	var ov: Variant = report.get("overlays", null)
	if typeof(ov) != TYPE_DICTIONARY or not (ov as Dictionary).has("samples"):
		issues.append(Lint3D.skip(LINT, "overlays", "%s has no overlays samples" % name, "r3d-night", ep))
	else:
		issues.append_array(_overlays(ov, name, ep, stats))
	issues.append_array(_share(report, name, ep, stats))
	return {"issues": issues, "stats": stats}


## The logical viewport of a report: its `viewport` [w, h] when present, else inferred from the action button's
## §2.1 centre (W − S − 168k, H − B − 168k) with S from the pause button (S + 24k) and B = 0; default 2400 × 1080.
static func viewport_of(report: Dictionary, samples: Array) -> Vector2:
	var v: Variant = report.get("viewport", null)
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	for s in samples:
		var by := _by_name(s)
		if by.has("pause") and by.has("action"):
			var pr: Rect2 = by["pause"]
			var ar: Rect2 = by["action"]
			var k := pr.size.x / 144.0
			var side := pr.position.x - 24.0 * k
			var c := ar.get_center()
			return Vector2(c.x + side + 168.0 * k, c.y + 168.0 * k)
	return Vector2(2400.0, 1080.0)


## The middle band for a viewport (§2.5, scaled from 1080 logical).
static func band_rect(vp: Vector2) -> Rect2:
	var f := vp.y / 1080.0
	return Rect2(0.0, BAND_Y0 * f, vp.x, (BAND_Y1 - BAND_Y0) * f)


static func _by_name(sample: Variant) -> Dictionary:
	var out := {}
	if typeof(sample) != TYPE_DICTIONARY:
		return out
	for pc in (sample as Dictionary).get("pieces", []):
		out[String((pc as Dictionary).get("name", ""))] = Lint3D.rect_of((pc as Dictionary).get("rect", null))
	return out


static func _always_on(samples: Array, name: String, ep: String, stats: Dictionary) -> Array:
	var bad: Array = []
	var worst := 0
	for s in samples:
		var sd: Dictionary = s
		var names := PackedStringArray()
		for pc in sd.get("pieces", []):
			if bool((pc as Dictionary).get("always_on", false)):
				names.append(String((pc as Dictionary).get("name", "")))
		worst = maxi(worst, names.size())
		var foreign := PackedStringArray()
		for n in names:
			if not ALWAYS_ON_NAMES.has(n):
				foreign.append(n)
		if names.size() > MAX_ALWAYS_ON or not foreign.is_empty():
			bad.append({"frame": sd.get("frame", -1), "tick": sd.get("tick", -1), "pieces": Array(names),
				"foreign": Array(foreign)})
	stats["always_on_max"] = worst
	if bad.is_empty():
		return [Lint3D.issue(LINT, "always_on_count", Lint3D.INFO, ep, "", name, worst, MAX_ALWAYS_ON, OWNER_HUD,
			"%d samples" % samples.size())]
	var i := Lint3D.issue(LINT, "always_on_count", Lint3D.ERROR, ep, "", name, worst, MAX_ALWAYS_ON, OWNER_HUD,
		"%d of %d samples; first at frame %s: %s" % [bad.size(), samples.size(), bad[0]["frame"], ", ".join(bad[0]["pieces"])])
	i["samples"] = bad
	return [i]


## True when `r` is at the §2.1 spec rect of always-on piece `n` for this viewport (either hand), inferred insets.
static func at_spec(n: String, r: Rect2, by: Dictionary, vp: Vector2) -> bool:
	var key := StringName("script" if n == "script_chip" else n)
	if not (key in [&"pause", &"script", &"clarence", &"action"]):
		return false
	var pr: Rect2 = by.get("pause", Rect2())
	var k := pr.size.x / 144.0 if pr.size.x > 0.0 else 1.0
	var sw: float = (by.get("script", by.get("script_chip", Rect2())) as Rect2).size.x / maxf(0.01, k)
	for lh in [false, true]:
		var side := (vp.x - pr.end.x - 24.0 * k) if lh else (pr.position.x - 24.0 * k)
		var top := pr.position.y - 24.0 * k
		var lay := HudLayout.compute(vp, Vector4(side, top, side, 0.0), lh, k, maxf(HudLayout.PILL_MIN_HIT, sw))
		var spec: Rect2 = lay.get(key, Rect2())
		if absf(spec.position.x - r.position.x) <= SPEC_TOL_PX and absf(spec.position.y - r.position.y) <= SPEC_TOL_PX \
				and absf(spec.size.x - r.size.x) <= SPEC_TOL_PX and absf(spec.size.y - r.size.y) <= SPEC_TOL_PX:
			return true
	return false


static func _band(samples: Array, vp: Vector2, name: String, ep: String, stats: Dictionary) -> Array:
	var out: Array = []
	var band := band_rect(vp)
	var k := 1.0
	var side := 0.0
	var first := _by_name(samples[0])
	if first.has("pause"):
		k = (first["pause"] as Rect2).size.x / 144.0
		side = (first["pause"] as Rect2).position.x - 24.0 * k
	# runs per piece name: [first_frame, last_frame, samples, rect, tick0, tick1, frames list]
	var runs := {}
	var closed: Array = []
	var spec_seen := {}
	var always_bad: Array = []
	var prev_frame := -999999
	for s in samples:
		var sd: Dictionary = s
		var fr := int(sd.get("frame", -1))
		var by := _by_name(sd)
		var in_band := {}
		for pc in sd.get("pieces", []):
			var d: Dictionary = pc
			var n := String(d.get("name", ""))
			var r := Lint3D.rect_of(d.get("rect", null))
			if not r.intersects(band):
				continue
			if bool(d.get("always_on", false)):
				if at_spec(n, r, by, vp):
					spec_seen[n] = r
				else:
					always_bad.append({"frame": fr, "tick": sd.get("tick", -1), "piece": n, "rect": d.get("rect", [])})
				continue
			if n == "edge_badge" and (r.end.x <= side + 160.0 * k + SPEC_TOL_PX or r.position.x >= vp.x - side - 160.0 * k - SPEC_TOL_PX):
				continue
			in_band[n] = r
		var gap := fr - prev_frame > SAMPLE_EVERY + 1
		prev_frame = fr
		for n in runs.keys():
			if gap or not in_band.has(n):
				closed.append([n, runs[n]])
				runs.erase(n)
		for n in in_band.keys():
			if runs.has(n):
				var ru: Array = runs[n]
				ru[1] = fr
				ru[2] = int(ru[2]) + 1
				ru[5] = sd.get("tick", -1)
			else:
				runs[n] = [fr, fr, 1, in_band[n], sd.get("tick", -1), sd.get("tick", -1)]
	for n in runs.keys():
		closed.append([n, runs[n]])
	for n in spec_seen.keys():
		out.append(Lint3D.issue(LINT, "middle_band", Lint3D.INFO, ep, "", name + ":" + String(n), spec_seen[n], band,
			OWNER_HUD, "always-on piece at its REDESIGN §2.1 position reaches into the band (spec layout; lead ruling requested)"))
	if not always_bad.is_empty():
		var i := Lint3D.issue(LINT, "middle_band", Lint3D.ERROR, ep, "", name, always_bad.size(), 0, OWNER_HUD,
			"always-on piece off its §2.1 position inside the band y %d–%d; first: %s at frame %s" % [int(band.position.y),
			int(band.end.y), always_bad[0]["piece"], always_bad[0]["frame"]])
		i["samples"] = always_bad
		out.append(i)
	var band_runs: Array = []
	for c in closed:
		var n: String = c[0]
		var ru: Array = c[1]
		var span_s := float(int(ru[1]) - int(ru[0])) / 60.0
		var persistent := span_s > PERSIST_S
		var row := {"piece": n, "from_frame": ru[0], "to_frame": ru[1], "from_tick": ru[4], "to_tick": ru[5],
			"samples": ru[2], "span_s": snappedf(span_s, 0.01), "rect": ru[3]}
		band_runs.append(row)
		var base := n.split("_")[0] if n.begins_with("pip") or n.begins_with("bow") else n
		var level := Lint3D.ERROR
		var why := ""
		if BAND_OK.has(n):
			level = Lint3D.WARNING if persistent else Lint3D.INFO
			why = "allowed contextual piece (§2.5)%s" % (", but shown > 5 s" if persistent else "")
		elif BAND_SPEC_CONFLICT.has(base):
			level = Lint3D.ERROR if persistent else Lint3D.WARNING
			why = "§2.2 places it in the band (spec conflict with §2.5)%s" % ("; persistent" if persistent else "; transient")
		else:
			why = "contextual piece in the middle band%s" % (" (persistent)" if persistent else "")
		var iss := Lint3D.issue(LINT, "middle_band", level, ep, "", name + ":" + n, "%.1f s" % span_s, "0 s (≤ 5 s = transient)",
			OWNER_HUD, "%s; frames %s–%s, ticks %s–%s, rect %s" % [why, ru[0], ru[1], ru[4], ru[5], Lint3D.fmt(ru[3])])
		iss["samples"] = [row]
		out.append(iss)
	stats["band"] = [band.position.y, band.end.y]
	stats["band_runs"] = band_runs
	if spec_seen.is_empty() and always_bad.is_empty() and band_runs.is_empty():
		out.append(Lint3D.issue(LINT, "middle_band", Lint3D.INFO, ep, "", name, 0, 0, OWNER_HUD, "band clear"))
	return out


static func _overlays(ov: Dictionary, name: String, ep: String, stats: Dictionary) -> Array:
	var bad: Array = []
	var mx := 0
	var lmx := 0
	for s in ov.get("samples", []):
		var a: Array = s
		if a.size() < 3:
			continue
		var n := int(a[1])
		var loud := int(a[2])
		mx = maxi(mx, n)
		lmx = maxi(lmx, loud)
		if n > MAX_OVERLAYS or loud > MAX_LOUD:
			bad.append({"frame": a[0], "shown": n, "loud": loud})
	stats["overlays_max"] = mx
	stats["overlays_loud_max"] = lmx
	if bad.is_empty():
		return [Lint3D.issue(LINT, "overlays", Lint3D.INFO, ep, "", name, "%d / %d loud" % [mx, lmx],
			"%d / %d loud" % [MAX_OVERLAYS, MAX_LOUD], OWNER_HUD, "%d samples" % (ov.get("samples", []) as Array).size())]
	var i := Lint3D.issue(LINT, "overlays", Lint3D.ERROR, ep, "", name, "%d / %d loud" % [mx, lmx],
		"%d / %d loud" % [MAX_OVERLAYS, MAX_LOUD], OWNER_HUD, "%d samples over V6; first at frame %s (%d shown, %d loud)" % [
		bad.size(), bad[0]["frame"], bad[0]["shown"], bad[0]["loud"]])
	i["samples"] = bad
	return [i]


static func _share(report: Dictionary, name: String, ep: String, stats: Dictionary) -> Array:
	if not report.has("pip_on_share"):
		return [Lint3D.skip(LINT, "window_share", "%s has no pip_on_share" % name, "r3d-night", ep)]
	var share := float(report["pip_on_share"])
	var longest := float(report.get("pip_longest_s", 0.0))
	var wins: Array = report.get("pip_windows", []) if report.get("pip_windows", null) is Array else []
	var mode := String(report.get("bellows_window", report.get("window_mode", "sim")))
	stats["pip_on_share"] = share
	stats["pip_longest_s"] = longest
	stats["pip_windows"] = wins
	stats["window_mode"] = mode
	var det := "mode %s; longest %.1f s; windows (open→close tick) %s" % [mode, longest, Lint3D.fmt(wins)]
	if report.has("pip_on_share_lean"):
		stats["pip_on_share_lean"] = float(report["pip_on_share_lean"])
		det += "; lean %.1f %%" % (100.0 * float(report["pip_on_share_lean"]))
	var level := Lint3D.WARNING if share > SHARE_WARN else Lint3D.INFO
	return [Lint3D.issue(LINT, "window_share", level, ep, "", name, "%.1f %%" % (100.0 * share), "35 % (warning)",
		"r3d-view3d / orchestrator (R15 window default)", det)]
