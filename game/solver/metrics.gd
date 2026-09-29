## Metrics — turns a run log into the TECH §8.5 report, checks `expect` blocks, and formats
## summaries (one line per run, a markdown table for review).
##
## Report keys: {duration_s, ticks, catches [{t, cause}], near_misses, first_player_laugh_s,
## first_player_laugh_launch_s, first_prank_s, first_prank_launch_s, laughs [{t, kind}], laughs_by_60,
## dead_air_pct, max_gap_s, prank_interval_mean_s, hold_total_s, freeze_total_s, launch_offset_s}
## (the executor adds ok, fail, stars, applause, lines, hash, steps, warnings).
## Times are seconds since curtain up; `*_launch_s` add the episode's director `launch_offset_s`
## (Prologue 2.3 s) — every launch-relative expect key (first_player_laugh_s_max, first_prank_s_max,
## laughs_by_s) and `laughs_by_60` use the launch clock.
## Dead air (TECH §8.5): a tick with no player input in the previous 180 ticks, no laugh in the
## previous 300, and Bellows not reacting. `max_gap_s`: the longest run of ticks with no input, no
## laugh and no reaction. `dead_air_ff_pct` / `max_gap_ff_s` / `real_time_ff_s` weigh hidden ticks
## 1/3 — the real time of a player who uses ⏩ while hidden (informational; expects use the TECH
## metric).
class_name Metrics
extends RefCounted

const DEAD_INPUT_TICKS := 180
const DEAD_LAUGH_TICKS := 300


## Compute the metrics of `log`. `is_laugh` = Callable(ev) -> bool (default: SolverHooks.is_laugh).
static func compute(log: SolverLog, is_laugh: Callable = Callable()) -> Dictionary:
	var laugh_fn := is_laugh if is_laugh.is_valid() else SolverHooks.is_laugh
	var start := log.start_tick
	var off := log.launch_offset_s
	var r := {}
	var n := log.size()
	var last := log.last_tick()
	r["ticks"] = n
	r["duration_s"] = _s(last - start)
	r["launch_offset_s"] = off
	# Catches, near misses.
	var catches: Array = []
	for ev in log.events_named("caught"):
		catches.append({"t": _s(int(ev.get("t", 0)) - start), "cause": SolverData.sv(ev.get("cause", "?"))})
	r["catches"] = catches
	r["near_misses"] = log.events_named("near_miss").size()
	# Laughs.
	var laughs: Array = []
	var laugh_ticks := PackedInt32Array()
	var first_player := -1
	for ev in log.events:
		if not laugh_fn.call(ev):
			continue
		var t := int(ev.get("t", 0))
		var kind := SolverData.sv(ev.get("e", ""))
		if kind == "director_cue":
			kind = "cue:%s" % ev.get("id", "")
		elif ev.has("prank"):
			kind = "%s:%s" % [kind, ev["prank"]]
		elif ev.has("bit"):
			kind = "%s:%s" % [kind, ev["bit"]]
		laughs.append({"t": _s(t - start), "kind": kind})
		laugh_ticks.append(t)
		if first_player < 0 and SolverData.sv(ev.get("e", "")) != "director_cue":
			first_player = t
	r["laughs"] = laughs
	r["first_player_laugh_s"] = _s(first_player - start) if first_player >= 0 else -1.0
	r["first_player_laugh_launch_s"] = snappedf(float(r["first_player_laugh_s"]) + off, 0.01) if first_player >= 0 else -1.0
	var by60 := 0
	for t in laugh_ticks:
		if _s(t - start) + off <= 60.0:
			by60 += 1
	r["laughs_by_60"] = by60
	# Pranks: accents (the laugh moment), falling back to prank_fire.
	var accents := log.events_named("reaction_accent")
	if accents.is_empty():
		accents = log.events_named("prank_fire")
	r["first_prank_s"] = _s(int(accents[0].get("t", 0)) - start) if not accents.is_empty() else -1.0
	r["first_prank_launch_s"] = snappedf(float(r["first_prank_s"]) + off, 0.01) if not accents.is_empty() else -1.0
	var gaps := 0
	for k in range(1, accents.size()):
		gaps += int(accents[k].get("t", 0)) - int(accents[k - 1].get("t", 0))
	r["prank_interval_mean_s"] = _s(gaps / (accents.size() - 1)) if accents.size() >= 2 else -1.0
	r["pranks_landed"] = accents.size()
	# Dead air + gaps.
	var dead_mask := dead_air_mask(log, laugh_fn)
	var react := _reaction_mask(log)
	var laugh_set := {}
	for t in laugh_ticks:
		laugh_set[t] = true
	var dead := 0
	var gap := 0
	var max_gap := 0
	var hold := 0
	var freeze := 0
	# ⏩-weighted (real time for a player who fast-forwards while hidden, GDD §3.3): a hidden tick
	# lasts 1/3 of a visible one. Weights are in thirds of a tick.
	var w_all := 0
	var w_dead := 0
	var gap_w := 0
	var max_gap_w := 0
	for i in n:
		var t := log.ticks[i]
		var wt := 1 if log.hush_hidden[i] != 0 else 3
		w_all += wt
		dead += dead_mask[i]
		w_dead += dead_mask[i] * wt
		if log.input[i] == 1 or laugh_set.has(t) or log.b_reacting[i] == 1 or react.has(t):
			gap = 0
			gap_w = 0
		else:
			gap += 1
			gap_w += wt
			max_gap = maxi(max_gap, gap)
			max_gap_w = maxi(max_gap_w, gap_w)
		hold += log.hold_rig[i]
		freeze += log.hush_frozen[i]
	r["dead_air_pct"] = snappedf(100.0 * dead / n, 0.1) if n > 0 else 0.0
	r["max_gap_s"] = _s(max_gap)
	r["dead_air_ff_pct"] = snappedf(100.0 * w_dead / w_all, 0.1) if w_all > 0 else 0.0
	r["max_gap_ff_s"] = _s(max_gap_w / 3)
	r["real_time_ff_s"] = _s(w_all / 3)
	r["hold_total_s"] = _s(hold)
	r["freeze_total_s"] = _s(freeze)
	return r


static func _s(ticks: int) -> float:
	return snappedf(ticks / 60.0, 0.01)


## Per-sample dead-air flags (1 = dead): no input in the previous 180 ticks, no laugh in the previous
## 300, and Bellows not reacting (sampled flag or the reaction_start…reaction_end event window).
static func dead_air_mask(log: SolverLog, is_laugh: Callable = Callable()) -> PackedByteArray:
	var laugh_fn := is_laugh if is_laugh.is_valid() else SolverHooks.is_laugh
	var n := log.size()
	var out := PackedByteArray()
	out.resize(n)
	var laugh_set := {}
	for ev in log.events:
		if laugh_fn.call(ev):
			laugh_set[int(ev.get("t", 0))] = true
	var react := _reaction_mask(log)
	var last_input := log.start_tick
	var last_laugh := log.start_tick
	for i in n:
		var t := log.ticks[i]
		if log.input[i] == 1:
			last_input = t
		if laugh_set.has(t):
			last_laugh = t
		var rea := log.b_reacting[i] == 1 or react.has(t)
		out[i] = 1 if (t - last_input > DEAD_INPUT_TICKS and t - last_laugh > DEAD_LAUGH_TICKS and not rea) else 0
	return out


## Ticks during which a reaction (or Meltdown) runs, per the event stream.
static func _reaction_mask(log: SolverLog) -> Dictionary:
	var out := {}
	var open_t := -1
	for ev in log.events:
		var e := SolverData.sv(ev.get("e", ""))
		var t := int(ev.get("t", 0))
		if e == "reaction_start" or e == "meltdown_start":
			if open_t < 0:
				open_t = t
		elif (e == "reaction_end" or e == "exhausted") and open_t >= 0:
			for k in range(open_t, t + 1):
				out[k] = true
			open_t = -1
	if open_t >= 0:
		for k in range(open_t, log.last_tick() + 1):
			out[k] = true
	return out


## The fun-gate expect keys (laugh clock, dead air, gaps): design targets the owner's fun gate
## judges, as opposed to the correctness keys (stars, lines, applause, catches, duration).
const FUN_KEYS: PackedStringArray = ["first_player_laugh_s_max", "first_prank_s_max", "laughs_by_s",
	"dead_air_pct_max", "max_gap_s_max"]


## `expect` restricted to (or without) the fun-gate keys.
static func split_expect(expect: Dictionary, fun: bool) -> Dictionary:
	var out := {}
	for k in expect:
		if FUN_KEYS.has(String(k)) == fun:
			out[k] = expect[k]
	return out


## Check a report against an `expect` block. Returns failure messages ([] = pass).
static func check_expect(report: Dictionary, expect: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if expect.has("stars"):
		var want: Array = expect["stars"]
		var got: Array = report.get("stars", [false, false, false])
		for i in mini(3, want.size()):
			if want[i] != null and bool(want[i]) != bool(got[i]):
				out.append("stars[%d] (%s): want %s, got %s" % [i, ["★", "★★", "★★★"][i], want[i], got[i]])
	var appl := float(report.get("applause", 0.0))
	if expect.has("applause"):
		var a: Array = expect["applause"]
		if a[0] != null and appl < float(a[0]):
			out.append("applause %.1f < min %s" % [appl, a[0]])
		if a.size() > 1 and a[1] != null and appl > float(a[1]):
			out.append("applause %.1f > max %s" % [appl, a[1]])
	if expect.has("lines"):
		var done: Array = report.get("lines", [])
		for l in expect["lines"]:
			if not done.has(String(l)):
				out.append("line '%s' not done (done: %s)" % [l, ", ".join(PackedStringArray(done))])
	if expect.has("catches_max"):
		var c: int = (report.get("catches", []) as Array).size()
		if c > int(expect["catches_max"]):
			out.append("%d catch(es) > max %d" % [c, int(expect["catches_max"])])
	if expect.has("duration_s"):
		var d: Array = expect["duration_s"]
		var dur := float(report.get("duration_s", 0.0))
		if d[0] != null and dur < float(d[0]):
			out.append("duration %.1f s < min %s s" % [dur, d[0]])
		if d.size() > 1 and d[1] != null and dur > float(d[1]):
			out.append("duration %.1f s > max %s s" % [dur, d[1]])
	if expect.has("first_player_laugh_s_max"):
		var f := float(report.get("first_player_laugh_launch_s", -1.0))
		if f < 0.0:
			out.append("no player-caused laugh at all (want ≤ %s s from launch)" % expect["first_player_laugh_s_max"])
		elif f > float(expect["first_player_laugh_s_max"]):
			out.append("first player laugh at %.2f s from launch > max %s s" % [f, expect["first_player_laugh_s_max"]])
	if expect.has("first_prank_s_max"):
		var f2 := float(report.get("first_prank_launch_s", -1.0))
		if f2 < 0.0:
			out.append("no prank landed (want ≤ %s s from launch)" % expect["first_prank_s_max"])
		elif f2 > float(expect["first_prank_s_max"]):
			out.append("first prank at %.2f s from launch > max %s s" % [f2, expect["first_prank_s_max"]])
	if expect.has("laughs_by_s"):
		var off := float(report.get("launch_offset_s", 0.0))
		for pair in expect["laughs_by_s"]:
			var s := float(pair[0])
			var want_n := int(pair[1])
			var got_n := 0
			for l in report.get("laughs", []):
				if float(l["t"]) + off <= s:
					got_n += 1
			if got_n < want_n:
				out.append("%d laugh(s) by %.0f s from launch < %d" % [got_n, s, want_n])
	if expect.has("dead_air_pct_max"):
		var da := float(report.get("dead_air_pct", 0.0))
		if da > float(expect["dead_air_pct_max"]):
			out.append("dead air %.1f %% > max %s %%" % [da, expect["dead_air_pct_max"]])
	if expect.has("max_gap_s_max"):
		var g := float(report.get("max_gap_s", 0.0))
		if g > float(expect["max_gap_s_max"]):
			out.append("longest gap %.1f s > max %s s" % [g, expect["max_gap_s_max"]])
	return out


## "★★☆" for a stars array.
static func stars_text(stars: Array) -> String:
	var s := ""
	for i in 3:
		s += "★" if i < stars.size() and bool(stars[i]) else "☆"
	return s


## The one-line summary: `[solve] n01_throat_tea ideal OK 214.3 s ★★★ 118 …`.
static func summary_line(r: Dictionary, tag: String = "solve") -> String:
	var ok := bool(r.get("ok", false))
	var line := "[%s] %s %s %s %.1f s %s %.0f applause, lines %d, catches %d, 1st laugh %s, 1st prank %s, laughs@60 %d, dead air %.1f%%, gap %.1f s, hold %.1f s" % [
		tag, r.get("episode", "?"), r.get("route", "?"), "OK" if ok else "FAIL", float(r.get("duration_s", 0.0)),
		stars_text(r.get("stars", [])), float(r.get("applause", 0.0)), (r.get("lines", []) as Array).size(),
		(r.get("catches", []) as Array).size(), _fmt_s(float(r.get("first_player_laugh_launch_s", -1.0))),
		_fmt_s(float(r.get("first_prank_launch_s", -1.0))), int(r.get("laughs_by_60", 0)),
		float(r.get("dead_air_pct", 0.0)), float(r.get("max_gap_s", 0.0)), float(r.get("hold_total_s", 0.0))]
	var f: Array = r.get("fail", [])
	if not f.is_empty():
		line += " — " + SolverData.sv(f[0])
		if f.size() > 1:
			line += " (+%d more)" % (f.size() - 1)
	return line


static func _fmt_s(v: float) -> String:
	return "—" if v < 0.0 else "%.1f s" % v


## A markdown table of reports (one row per run) plus failure details.
static func to_markdown(reports: Array, title: String = "Solver runs") -> String:
	var md := "# %s\n\n" % title
	md += "| episode | route | ok | duration | stars | applause | lines | catches | 1st laugh* | 1st prank* | laughs@60* | dead air | max gap | dead air ⏩ | max gap ⏩ | hold | near misses |\n"
	md += "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for r in reports:
		md += "| %s | %s | %s | %.1f s | %s | %.1f | %d | %d | %s | %s | %d | %.1f %% | %.1f s | %.1f %% | %.1f s | %.1f s | %d |\n" % [
			r.get("episode", "?"), r.get("route", "?"), "OK" if bool(r.get("ok", false)) else "**FAIL**",
			float(r.get("duration_s", 0.0)), stars_text(r.get("stars", [])), float(r.get("applause", 0.0)),
			(r.get("lines", []) as Array).size(), (r.get("catches", []) as Array).size(),
			_fmt_s(float(r.get("first_player_laugh_launch_s", -1.0))), _fmt_s(float(r.get("first_prank_launch_s", -1.0))),
			int(r.get("laughs_by_60", 0)), float(r.get("dead_air_pct", 0.0)), float(r.get("max_gap_s", 0.0)),
			float(r.get("dead_air_ff_pct", 0.0)), float(r.get("max_gap_ff_s", 0.0)),
			float(r.get("hold_total_s", 0.0)), int(r.get("near_misses", 0))]
	md += "\n\\* launch-relative (sim time + the episode's director `launch_offset_s`). ⏩ = hidden ticks weigh 1/3 (a player fast-forwarding while hidden).\n"
	var any_fail := false
	for r in reports:
		var f: Array = r.get("fail", [])
		var inv: Array = r.get("invariants", [])
		if f.is_empty() and inv.is_empty():
			continue
		if not any_fail:
			md += "\n## Failures\n"
			any_fail = true
		md += "\n**%s / %s**\n" % [r.get("episode", "?"), r.get("route", "?")]
		for x in f:
			md += "- %s\n" % x
		for x in inv:
			md += "- invariant: %s\n" % x
	return md
