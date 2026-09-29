## Metrics — turns a run log into the TECH §8.5 report, checks `expect` blocks, and formats
## summaries (one line per run, a markdown table for review).
##
## Report keys: {duration_s, ticks, catches [{t, cause}], near_misses, first_player_laugh_s,
## first_player_laugh_launch_s, first_prank_s, first_prank_launch_s, laughs [{t, kind}], laughs_by_60,
## dead_air_ff_pct, max_gap_ff_s (THE D1 GATE), dead_air_sim_pct, max_gap_sim_s, dead_air_ff_naive_pct,
## max_gap_ff_naive_s (info), real_time_ff_s, real_time_ff_naive_s, ff_s, beats {total, room, pip, edge, hidden,
## edge_share}, alive_by {input, laugh, reacting, beat_room, beat_pip, beat_edge}, event_counts {e: n},
## prank_interval_mean_s, hold_total_s, freeze_total_s, launch_offset_s} (the executor adds ok, fail, stars,
## applause, lines, hash, steps, warnings). `dead_air_pct` / `max_gap_s` are legacy aliases of the sim-time
## numbers.
## Times are seconds since curtain up; `*_launch_s` add the episode's director `launch_offset_s`
## (Prologue 2.3 s) — every launch-relative expect key (first_player_laugh_s_max, first_prank_s_max,
## laughs_by_s) and `laughs_by_60` use the launch clock.
##
## Dead air (lead decision D1): a tick is dead when there was no player input in the previous 180 ticks, no
## laugh and no VISIBLE micro-gag beat (`micro_gag` with `vis` "room" | "pip" | "edge") in the previous 300,
## and Bellows isn't reacting. The gate weighs ticks by real time with ⏩ (ruling L2): a hidden tick lasts 1/3
## only while the persona's ⏩ is latched — it holds ⏩ while hidden, loses it on every `SimFf.drops` event
## (prank fire, "?" start, entry warning into her room), re-presses `log.ff_repress_ticks` later (never while he
## is reacting: a punchline is watched at ×1), and — the slow first-timer — only once this Night's
## `director_cue {id: ghost_ff}` has taught it (`log.ff_needs_cue`). The Stage-1 weighting (every hidden tick
## 1/3) stays as `*_naive` (info); sim time (every tick 1) as `*_sim` (info). `max_gap_*`: the longest run of
## ticks with no input, no laugh, no visible beat and no reaction, in the same clocks. `alive_by`: % of the
## gate's real time kept alive, by the first reason in the order input, laugh, reacting, beat_room, beat_pip,
## beat_edge (sums to 100 − dead_air_ff_pct); `beats.edge_share` = beat_edge / all beat credit (ruling L1: the
## pre-gate FAILs a route above 1/3).
class_name Metrics
extends RefCounted

const DEAD_INPUT_TICKS := 180
const DEAD_LAUGH_TICKS := 300
## Ruling L1: edge beats may carry at most this share of the beat credit.
const EDGE_SHARE_MAX := 1.0 / 3.0
const ALIVE_REASONS: PackedStringArray = ["input", "laugh", "reacting", "beat_room", "beat_pip", "beat_edge"]
const BEAT_KINDS: PackedStringArray = ["room", "pip", "edge"]


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
	var counts := {}
	for ev in log.events:
		var en := SolverData.sv(ev.get("e", ""))
		counts[en] = int(counts.get(en, 0)) + 1
		if not laugh_fn.call(ev):
			continue
		var t := int(ev.get("t", 0))
		var kind := en
		if kind == "director_cue":
			kind = "cue:%s" % ev.get("id", "")
		elif ev.has("prank"):
			kind = "%s:%s" % [kind, ev["prank"]]
		elif ev.has("bit"):
			kind = "%s:%s" % [kind, ev["bit"]]
		laughs.append({"t": _s(t - start), "kind": kind})
		laugh_ticks.append(t)
		if first_player < 0 and en != "director_cue":
			first_player = t
	r["event_counts"] = counts
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
	var hold := 0
	var freeze := 0
	for i in n:
		hold += log.hold_rig[i]
		freeze += log.hush_frozen[i]
	r["hold_total_s"] = _s(hold)
	r["freeze_total_s"] = _s(freeze)
	r.merge(dead_air(log, laugh_fn), true)
	return r


static func _s(ticks: int) -> float:
	return snappedf(ticks / 60.0, 0.01)


## The micro-gag kind of an event: "" (not a beat), "room" | "pip" | "edge" (visible) or "hidden".
static func beat_kind(ev: Dictionary) -> String:
	if SolverData.sv(ev.get("e", "")) != "micro_gag":
		return ""
	var v := SolverData.sv(ev.get("vis", ""))
	return v if BEAT_KINDS.has(v) else "hidden"


## Per-tick clocks shared by the mask, the ⏩ latch and the gap: {laugh: {t: true}, beat: {t: kind}, drop: {t:
## true}, react: {t: true}, cue_ff: first ghost_ff cue tick (−1)}.
static func _clocks(log: SolverLog, laugh_fn: Callable) -> Dictionary:
	var laugh := {}
	var beat := {}
	var drop := {}
	var cue_ff := -1
	for ev in log.events:
		var t := int(ev.get("t", 0))
		if laugh_fn.call(ev):
			laugh[t] = true
		var bk := beat_kind(ev)
		if bk != "" and bk != "hidden":
			# the most visible kind wins when two beats share a tick
			var prev := SolverData.sv(beat.get(t, ""))
			if prev == "" or BEAT_KINDS.find(bk) < BEAT_KINDS.find(prev):
				beat[t] = bk
		var e := SolverData.sv(ev.get("e", ""))
		if e == "director_cue" and SolverData.sv(ev.get("id", "")) == "ghost_ff" and cue_ff < 0:
			cue_ff = t
		if e == "prank_fire" or e == "spot_start" or e == "entry_warning":
			var i := log.index_of_tick(t)
			var hr := log.name_of(log.hush_room[i]) if i >= 0 else ""
			if _drops(ev, hr):
				drop[t] = true
	return {"laugh": laugh, "beat": beat, "drop": drop, "react": _reaction_mask(log), "cue_ff": cue_ff}


## `SimFf.drops` (the sim's one ⏩ drop rule) when the sim exists, else the same rule inline.
static func _drops(ev: Dictionary, hush_room: String) -> bool:
	var s := SolverHooks.soft_script(SolverHooks.SIM_FF)
	if s != null:
		return bool(s.call("drops", ev, hush_room))
	match SolverData.sv(ev.get("e", "")):
		"prank_fire", "spot_start":
			return true
		"entry_warning":
			var room := SolverData.sv(ev.get("room", ""))
			return room == "" or room == hush_room
	return false


## The dead-air block of the report (see the class doc): gate, sim and naive clocks, beats, alive_by.
static func dead_air(log: SolverLog, laugh_fn: Callable = Callable()) -> Dictionary:
	var lf := laugh_fn if laugh_fn.is_valid() else SolverHooks.is_laugh
	var ck := _clocks(log, lf)
	var laugh: Dictionary = ck["laugh"]
	var beat: Dictionary = ck["beat"]
	var drop: Dictionary = ck["drop"]
	var react: Dictionary = ck["react"]
	var cue_ff: int = ck["cue_ff"]
	var n := log.size()
	var last_input := log.start_tick
	var last_laugh := log.start_tick
	var last_beat := {"room": -1 << 30, "pip": -1 << 30, "edge": -1 << 30}
	var hide_start := -1
	var anchor_drop := -1 << 30
	var anchor_react := -1 << 30
	var repress := maxi(0, log.ff_repress_ticks)
	var dead_sim := 0
	var w_all := 0          # thirds of a tick (gate)
	var w_dead := 0
	var nv_all := 0         # thirds (naive)
	var nv_dead := 0
	var ff_ticks := 0
	var alive := {}
	for k in ALIVE_REASONS:
		alive[k] = 0
	var gap := 0
	var gap_w := 0
	var gap_nv := 0
	var max_gap := 0
	var max_gap_w := 0
	var max_gap_nv := 0
	for i in n:
		var t := log.ticks[i]
		if log.input[i] == 1:
			last_input = t
		if laugh.has(t):
			last_laugh = t
		var bk := SolverData.sv(beat.get(t, ""))
		if bk != "":
			last_beat[bk] = t
		var rea := log.b_reacting[i] == 1 or react.has(t)
		var hidden := log.hush_hidden[i] != 0
		# the ⏩ latch
		if not hidden:
			hide_start = -1
		elif hide_start < 0:
			hide_start = t
		if drop.has(t):
			anchor_drop = t
		if rea:
			anchor_react = t
		var avail := not log.ff_needs_cue or (cue_ff >= 0 and t >= cue_ff)
		var latched := hidden and avail and not rea and t - maxi(hide_start, maxi(anchor_drop, anchor_react)) >= repress \
				and not drop.has(t)
		var wt := 1 if latched else 3
		var wn := 1 if hidden else 3
		if latched:
			ff_ticks += 1
		w_all += wt
		nv_all += wn
		var in_ok := t - last_input <= DEAD_INPUT_TICKS
		var la_ok := t - last_laugh <= DEAD_LAUGH_TICKS
		var br_ok := t - int(last_beat["room"]) <= DEAD_LAUGH_TICKS
		var bp_ok := t - int(last_beat["pip"]) <= DEAD_LAUGH_TICKS
		var be_ok := t - int(last_beat["edge"]) <= DEAD_LAUGH_TICKS
		var reason := ""
		if in_ok:
			reason = "input"
		elif la_ok:
			reason = "laugh"
		elif rea:
			reason = "reacting"
		elif br_ok:
			reason = "beat_room"
		elif bp_ok:
			reason = "beat_pip"
		elif be_ok:
			reason = "beat_edge"
		if reason == "":
			dead_sim += 1
			w_dead += wt
			nv_dead += wn
		else:
			alive[reason] = int(alive[reason]) + wt
		if log.input[i] == 1 or laugh.has(t) or bk != "" or rea:
			gap = 0
			gap_w = 0
			gap_nv = 0
		else:
			gap += 1
			gap_w += wt
			gap_nv += wn
			max_gap = maxi(max_gap, gap)
			max_gap_w = maxi(max_gap_w, gap_w)
			max_gap_nv = maxi(max_gap_nv, gap_nv)
	var r := {}
	r["dead_air_ff_pct"] = snappedf(100.0 * w_dead / w_all, 0.1) if w_all > 0 else 0.0
	r["max_gap_ff_s"] = _s(max_gap_w / 3)
	r["real_time_ff_s"] = _s(w_all / 3)
	r["ff_s"] = _s(ff_ticks)
	r["dead_air_sim_pct"] = snappedf(100.0 * dead_sim / n, 0.1) if n > 0 else 0.0
	r["max_gap_sim_s"] = _s(max_gap)
	r["dead_air_ff_naive_pct"] = snappedf(100.0 * nv_dead / nv_all, 0.1) if nv_all > 0 else 0.0
	r["max_gap_ff_naive_s"] = _s(max_gap_nv / 3)
	r["real_time_ff_naive_s"] = _s(nv_all / 3)
	# legacy aliases (Stage 1 names; sim time)
	r["dead_air_pct"] = r["dead_air_sim_pct"]
	r["max_gap_s"] = r["max_gap_sim_s"]
	var ab := {}
	for k in ALIVE_REASONS:
		ab[k] = snappedf(100.0 * int(alive[k]) / w_all, 0.1) if w_all > 0 else 0.0
	r["alive_by"] = ab
	var bt := {"total": 0, "room": 0, "pip": 0, "edge": 0, "hidden": 0}
	for ev in log.events:
		var k2 := beat_kind(ev)
		if k2 != "":
			bt["total"] = int(bt["total"]) + 1
			bt[k2] = int(bt[k2]) + 1
	var credit := int(alive["beat_room"]) + int(alive["beat_pip"]) + int(alive["beat_edge"])
	bt["edge_share"] = snappedf(float(int(alive["beat_edge"])) / credit, 0.001) if credit > 0 else 0.0
	r["beats"] = bt
	return r


## Per-sample dead-air flags (1 = dead): no input in the previous 180 ticks, no laugh and no visible
## micro-gag beat in the previous 300, and Bellows not reacting (sampled flag or the
## reaction_start…reaction_end event window).
static func dead_air_mask(log: SolverLog, is_laugh: Callable = Callable()) -> PackedByteArray:
	var laugh_fn := is_laugh if is_laugh.is_valid() else SolverHooks.is_laugh
	var n := log.size()
	var out := PackedByteArray()
	out.resize(n)
	var ck := _clocks(log, laugh_fn)
	var laugh: Dictionary = ck["laugh"]
	var beat: Dictionary = ck["beat"]
	var react: Dictionary = ck["react"]
	var last_input := log.start_tick
	var last_laugh := log.start_tick
	var last_beat := -1 << 30
	for i in n:
		var t := log.ticks[i]
		if log.input[i] == 1:
			last_input = t
		if laugh.has(t):
			last_laugh = t
		if beat.has(t):
			last_beat = t
		var rea := log.b_reacting[i] == 1 or react.has(t)
		out[i] = 1 if (t - last_input > DEAD_INPUT_TICKS and t - last_laugh > DEAD_LAUGH_TICKS
			and t - last_beat > DEAD_LAUGH_TICKS and not rea) else 0
	return out


## Per-sample ⏩ flags (1 = the persona's ⏩ is latched: the tick weighs 1/3 in the gate clock).
static func ff_mask(log: SolverLog, is_laugh: Callable = Callable()) -> PackedByteArray:
	var laugh_fn := is_laugh if is_laugh.is_valid() else SolverHooks.is_laugh
	var ck := _clocks(log, laugh_fn)
	var drop: Dictionary = ck["drop"]
	var react: Dictionary = ck["react"]
	var cue_ff: int = ck["cue_ff"]
	var out := PackedByteArray()
	out.resize(log.size())
	var hide_start := -1
	var anchor := -1 << 30
	for i in log.size():
		var t := log.ticks[i]
		var hidden := log.hush_hidden[i] != 0
		if not hidden:
			hide_start = -1
		elif hide_start < 0:
			hide_start = t
		var rea := log.b_reacting[i] == 1 or react.has(t)
		if drop.has(t) or rea:
			anchor = t
		var avail := not log.ff_needs_cue or (cue_ff >= 0 and t >= cue_ff)
		out[i] = 1 if hidden and avail and not rea and not drop.has(t) and t - maxi(hide_start, anchor) >= maxi(0, log.ff_repress_ticks) else 0
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
## judges, as opposed to the correctness keys (stars, lines, applause, catches, duration). A `warn_<key>` is
## a fun key too.
const FUN_KEYS: PackedStringArray = ["first_player_laugh_s_max", "first_prank_s_max", "laughs_by_s",
	"dead_air_pct_max", "max_gap_s_max", "dead_air_ff_pct_max", "max_gap_ff_s_max"]
## Every expect key (without the `warn_` prefix). The dead-air keys check the D1 gate (⏩ + visible beats):
## `dead_air_pct_max` / `dead_air_ff_pct_max` → `dead_air_ff_pct`, `max_gap_s_max` / `max_gap_ff_s_max` →
## `max_gap_ff_s`. `events_min` / `events_max`: {event: n} counts over the run (scenario routes).
const EXPECT_KEYS: PackedStringArray = ["stars", "applause", "lines", "catches_max", "duration_s",
	"first_player_laugh_s_max", "first_prank_s_max", "laughs_by_s", "dead_air_pct_max", "max_gap_s_max",
	"dead_air_ff_pct_max", "max_gap_ff_s_max", "events_min", "events_max"]
## `warn_<key>` (ruling L15): evaluated and reported, never fails the route.
const WARN_PREFIX := "warn_"


## `expect` restricted to (or without) the fun-gate keys.
static func split_expect(expect: Dictionary, fun: bool) -> Dictionary:
	var out := {}
	for k in expect:
		var key := String(k)
		var is_fun := FUN_KEYS.has(key) or key.begins_with(WARN_PREFIX)
		if is_fun == fun:
			out[k] = expect[k]
	return out


## True when `key` is known (optionally with the `warn_` prefix).
static func known_key(key: String) -> bool:
	return EXPECT_KEYS.has(key.trim_prefix(WARN_PREFIX))


## Check a report against an `expect` block. Returns failure messages ([] = pass). `warn_` keys are
## skipped (see `check_warn`).
static func check_expect(report: Dictionary, expect: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in EXPECT_KEYS:
		if expect.has(k):
			out.append_array(check_key(report, k, expect[k]))
	return out


## The `warn_<key>` keys of `expect`, evaluated: messages "warn_<key>: …" ([] = all would pass).
static func check_warn(report: Dictionary, expect: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in expect:
		var key := String(k)
		if not key.begins_with(WARN_PREFIX):
			continue
		for m in check_key(report, key.trim_prefix(WARN_PREFIX), expect[k]):
			out.append("%s: %s" % [key, m])
	return out


## Per-key results of every expect key (incl. `warn_` ones): {key: {ok: bool, msgs: [..]}} — what
## `solve.sh --baseline` compares.
static func expect_results(report: Dictionary, expect: Dictionary) -> Dictionary:
	var out := {}
	for k in expect:
		var key := String(k)
		var msgs := check_key(report, key.trim_prefix(WARN_PREFIX), expect[k])
		out[key] = {"ok": msgs.is_empty(), "msgs": Array(msgs)}
	return out


## Failure messages of one expect key ([] = pass; unknown keys pass — SolutionDef.validate reports them).
static func check_key(report: Dictionary, key: String, want: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	match key:
		"stars":
			var ws: Array = want if want is Array else []
			var got: Array = report.get("stars", [false, false, false])
			for i in mini(3, ws.size()):
				if ws[i] != null and i < got.size() and bool(ws[i]) != bool(got[i]):
					out.append("stars[%d] (%s): want %s, got %s" % [i, ["★", "★★", "★★★"][i], ws[i], got[i]])
		"applause":
			var appl := float(report.get("applause", 0.0))
			var a: Array = want if want is Array else [null, null]
			if a.size() > 0 and a[0] != null and appl < float(a[0]):
				out.append("applause %.1f < min %s" % [appl, a[0]])
			if a.size() > 1 and a[1] != null and appl > float(a[1]):
				out.append("applause %.1f > max %s" % [appl, a[1]])
		"lines":
			var done: Array = report.get("lines", [])
			for l in (want if want is Array else []):
				if not done.has(String(l)):
					out.append("line '%s' not done (done: %s)" % [l, ", ".join(PackedStringArray(done))])
		"catches_max":
			var c: int = (report.get("catches", []) as Array).size()
			if c > int(want):
				out.append("%d catch(es) > max %d" % [c, int(want)])
		"duration_s":
			var d: Array = want if want is Array else [null, null]
			var dur := float(report.get("duration_s", 0.0))
			if d.size() > 0 and d[0] != null and dur < float(d[0]):
				out.append("duration %.1f s < min %s s" % [dur, d[0]])
			if d.size() > 1 and d[1] != null and dur > float(d[1]):
				out.append("duration %.1f s > max %s s" % [dur, d[1]])
		"first_player_laugh_s_max":
			var f := float(report.get("first_player_laugh_launch_s", -1.0))
			if f < 0.0:
				out.append("no player-caused laugh at all (want ≤ %s s from launch)" % want)
			elif f > float(want):
				out.append("first player laugh at %.2f s from launch > max %s s" % [f, want])
		"first_prank_s_max":
			var f2 := float(report.get("first_prank_launch_s", -1.0))
			if f2 < 0.0:
				out.append("no prank landed (want ≤ %s s from launch)" % want)
			elif f2 > float(want):
				out.append("first prank at %.2f s from launch > max %s s" % [f2, want])
		"laughs_by_s":
			var off := float(report.get("launch_offset_s", 0.0))
			for pair in (want if want is Array else []):
				var sec := float(pair[0])
				var want_n := int(pair[1])
				var got_n := 0
				for l in report.get("laughs", []):
					if float(l["t"]) + off <= sec:
						got_n += 1
				if got_n < want_n:
					out.append("%d laugh(s) by %.0f s from launch < %d" % [got_n, sec, want_n])
		"dead_air_pct_max", "dead_air_ff_pct_max":
			var da := float(report.get("dead_air_ff_pct", 0.0))
			if da > float(want):
				out.append("dead air ⏩ %.1f %% > max %s %% (sim %.1f %%)" % [da, want, float(report.get("dead_air_sim_pct", 0.0))])
		"max_gap_s_max", "max_gap_ff_s_max":
			var g := float(report.get("max_gap_ff_s", 0.0))
			if g > float(want):
				out.append("longest gap ⏩ %.1f s > max %s s (sim %.1f s)" % [g, want, float(report.get("max_gap_sim_s", 0.0))])
		"events_min", "events_max":
			var counts: Dictionary = report.get("event_counts", {})
			var wd: Dictionary = want if want is Dictionary else {}
			for e in wd:
				var got_e := int(counts.get(String(e), 0))
				if key == "events_min" and got_e < int(wd[e]):
					out.append("%d '%s' event(s) < min %d" % [got_e, e, int(wd[e])])
				elif key == "events_max" and got_e > int(wd[e]):
					out.append("%d '%s' event(s) > max %d" % [got_e, e, int(wd[e])])
	return out


## Pre-gate checks the solver can make on one run (s2-qa's pregate.sh reads `pregate_fail`; `solve.sh
## --pregate` gates on it): no `warn_` expect keys left, and (ruling L1) the edge-beat share ≤ 1/3 —
## scenario routes are exempt from D1.
static func pregate_fail(report: Dictionary, expect: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in expect:
		if String(k).begins_with(WARN_PREFIX):
			out.append("expect key '%s' is still a warn_ key" % k)
	if SolverData.sv(report.get("persona", "")) != "scenario":
		var es := float((report.get("beats", {}) as Dictionary).get("edge_share", 0.0))
		if es > EDGE_SHARE_MAX + 0.0005:
			out.append("edge beats carry %.0f %% of the beat credit (> 1/3, ruling L1)" % (es * 100.0))
	return out


## "★★☆" for a stars array.
static func stars_text(stars: Array) -> String:
	var s := ""
	for i in 3:
		s += "★" if i < stars.size() and bool(stars[i]) else "☆"
	return s


## The one-line summary: `[solve] n01_throat_tea ideal OK 214.3 s ★★★ 118 …` — the D1 gate numbers (⏩ +
## visible beats) first, sim time and the naive ⏩ in brackets; the edge-beat share in red above 1/3.
static func summary_line(r: Dictionary, tag: String = "solve") -> String:
	var ok := bool(r.get("ok", false))
	var bt: Dictionary = r.get("beats", {})
	var es := float(bt.get("edge_share", 0.0))
	var es_txt := "%.2f" % es
	if es > EDGE_SHARE_MAX + 0.0005:
		es_txt = "\u001b[31m%.2f\u001b[0m" % es
	var line := "[%s] %s %s %s %.1f s %s %.0f applause, lines %d, catches %d, 1st laugh %s, 1st prank %s, laughs@60 %d, dead air ⏩ %.1f%% [sim %.1f%%, naive %.1f%%], gap ⏩ %.1f s [sim %.1f s], beats %d (room %d pip %d edge %d hidden %d, edge share %s), hold %.1f s" % [
		tag, r.get("episode", "?"), r.get("route", "?"), "OK" if ok else "FAIL", float(r.get("duration_s", 0.0)),
		stars_text(r.get("stars", [])), float(r.get("applause", 0.0)), (r.get("lines", []) as Array).size(),
		(r.get("catches", []) as Array).size(), _fmt_s(float(r.get("first_player_laugh_launch_s", -1.0))),
		_fmt_s(float(r.get("first_prank_launch_s", -1.0))), int(r.get("laughs_by_60", 0)),
		float(r.get("dead_air_ff_pct", 0.0)), float(r.get("dead_air_sim_pct", 0.0)), float(r.get("dead_air_ff_naive_pct", 0.0)),
		float(r.get("max_gap_ff_s", 0.0)), float(r.get("max_gap_sim_s", 0.0)), int(bt.get("total", 0)), int(bt.get("room", 0)),
		int(bt.get("pip", 0)), int(bt.get("edge", 0)), int(bt.get("hidden", 0)), es_txt, float(r.get("hold_total_s", 0.0))]
	var f: Array = r.get("fail", [])
	if not f.is_empty():
		line += " — " + SolverData.sv(f[0])
		if f.size() > 1:
			line += " (+%d more)" % (f.size() - 1)
	var wk: Array = r.get("warn_keys", [])
	if not wk.is_empty():
		line += " | warn_ keys: %s" % ", ".join(PackedStringArray(wk))
	return line


static func _fmt_s(v: float) -> String:
	return "—" if v < 0.0 else "%.1f s" % v


## A markdown table of reports (one row per run) plus failure details. Gate numbers (⏩ + visible beats)
## first, sim time in brackets.
static func to_markdown(reports: Array, title: String = "Solver runs") -> String:
	var md := "# %s\n\n" % title
	md += "| episode | route | ok | duration | stars | applause | lines | catches | 1st laugh* | 1st prank* | laughs@60* | dead air ⏩ [sim] | max gap ⏩ [sim] | ⏩ naive | beats room/pip/edge (hidden) | edge share | hold | near misses |\n"
	md += "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for r in reports:
		var bt: Dictionary = r.get("beats", {})
		var es := float(bt.get("edge_share", 0.0))
		md += "| %s | %s | %s | %.1f s | %s | %.1f | %d | %d | %s | %s | %d | %.1f %% [%.1f %%] | %.1f s [%.1f s] | %.1f %% | %d/%d/%d (%d) | %s | %.1f s | %d |\n" % [
			r.get("episode", "?"), r.get("route", "?"), "OK" if bool(r.get("ok", false)) else "**FAIL**",
			float(r.get("duration_s", 0.0)), stars_text(r.get("stars", [])), float(r.get("applause", 0.0)),
			(r.get("lines", []) as Array).size(), (r.get("catches", []) as Array).size(),
			_fmt_s(float(r.get("first_player_laugh_launch_s", -1.0))), _fmt_s(float(r.get("first_prank_launch_s", -1.0))),
			int(r.get("laughs_by_60", 0)), float(r.get("dead_air_ff_pct", 0.0)), float(r.get("dead_air_sim_pct", 0.0)),
			float(r.get("max_gap_ff_s", 0.0)), float(r.get("max_gap_sim_s", 0.0)), float(r.get("dead_air_ff_naive_pct", 0.0)),
			int(bt.get("room", 0)), int(bt.get("pip", 0)), int(bt.get("edge", 0)), int(bt.get("hidden", 0)),
			("**%.2f**" % es) if es > EDGE_SHARE_MAX + 0.0005 else "%.2f" % es,
			float(r.get("hold_total_s", 0.0)), int(r.get("near_misses", 0))]
	md += "\n\\* launch-relative (sim time + the episode's director `launch_offset_s`). ⏩ = the D1 gate: real time with the persona's ⏩ latch (hidden ticks weigh 1/3 only while ⏩ is held; dropped on prank fire / \"?\" / entry warning; ruling L2) and visible micro-gag beats. naive = every hidden tick 1/3 (Stage 1). Edge share **bold** above 1/3 (ruling L1).\n"
	var any_fail := false
	for r in reports:
		var f: Array = r.get("fail", [])
		var inv: Array = r.get("invariants", [])
		var wn: Array = r.get("warn", [])
		if f.is_empty() and inv.is_empty() and wn.is_empty():
			continue
		if not any_fail:
			md += "\n## Failures and warnings\n"
			any_fail = true
		md += "\n**%s / %s**\n" % [r.get("episode", "?"), r.get("route", "?")]
		for x in f:
			md += "- %s\n" % x
		for x in inv:
			md += "- invariant: %s\n" % x
		for x in wn:
			md += "- (warn) %s\n" % x
	return md
