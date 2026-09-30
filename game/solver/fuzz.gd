## Fuzz — random and reckless players hammering the sim to prove the fairness rules (TECH §8.6).
##
##   var r := Fuzz.run_bot(factory, data, "n01_throat_tea", "random", 7)   # one seeded run
##   r = {episode, bot, seed, ok, invariants [..], softlock {ok, why}, ticks, catches, near_misses,
##        laughs, commands, hash, log: SolverLog}
##
## Bots (each seeded, deterministic):
## - `random`: a random command (go / move / pick / rig on-off / freeze on-off / squeak / pin /
##   pop_out) every 0.2–2 s;
## - `reckless`: goes straight for every Script prank (picks, rigs, running) ignoring Bellows;
## - `hider`: hides in random spots, squeaks from inside, pops out, repeats;
## - `bait`: stands in front of him to get spotted on purpose, then runs over rigged STEP pranks
##   (or away through the house).
## Every run ends with `Invariants.check` plus a soft-lock probe (the planner on the final state must
## still reach every required line); `replay` re-runs the command log on a fresh world (rule 5).
class_name Fuzz
extends RefCounted

const BOTS: PackedStringArray = ["random", "reckless", "hider", "bait"]
const DEFAULT_TICKS := 60 * 180


## One bot run. opts: {ticks, replay (bool), probe (bool, default true), probe_budget_ms,
## cond_fn, relaxed}.
static func run_bot(factory: Callable, data: SolverData, episode: String, bot: String, seed: int,
		opts: Dictionary = {}) -> Dictionary:
	var world: Object = factory.call()
	if world == null:
		return {"episode": episode, "bot": bot, "seed": seed, "ok": false, "invariants": ["world factory returned null"]}
	var ticks := int(opts.get("ticks", DEFAULT_TICKS))
	var brain := Brain.new(bot, seed, data, episode)
	var ex := Executor.new(world, [], "ideal", opts.get("cond_fn", Callable()), data,
		{"episode": episode, "step_source": brain.next_steps, "continue_on_fail": true, "max_recoveries": 1 << 20,
			"relaxed": bool(opts.get("relaxed", false))})
	brain.ex = ex
	var rep := ex.run(ticks)
	var lg := ex.log
	# Determinism replay (rule 5).
	if bool(opts.get("replay", false)):
		lg.replay_hash = Invariants.replay_hash(factory, lg)
	# Soft-lock probe on the final state (rule 6).
	var sl := {"ok": true, "why": "", "skipped": true}
	if bool(opts.get("probe", true)):
		sl = softlock_probe(world, data, episode, opts)
		if not bool(sl.get("skipped", false)):
			lg.softlock_probes.append({"t": lg.last_tick(), "ok": sl["ok"], "why": sl["why"]})
	var inv := Invariants.check(lg)
	inv.append_array(Invariants.sim_counters(world))
	brain.ex = null
	return {"episode": episode, "bot": bot, "seed": seed, "ok": inv.is_empty(), "invariants": inv,
		"softlock": sl, "ticks": lg.size(), "catches": (rep.get("catches", []) as Array).size(),
		"near_misses": int(rep.get("near_misses", 0)), "laughs": (rep.get("laughs", []) as Array).size(),
		"commands": lg.cmds.size(), "lines": rep.get("lines", []), "hash": lg.final_hash, "log": lg}


## The planner on (a clone of) `world`: can every required line still be done?
static func softlock_probe(world: Object, data: SolverData, episode: String, opts: Dictionary = {}) -> Dictionary:
	var probe := SolverProbe.new(world, data)
	if probe.ended():
		return {"ok": true, "why": "night ended (%s)" % probe.end_reason(), "skipped": true}
	var left := PackedStringArray()
	for l in data.script_lines(episode):
		var id := SolverData.sv(l.get("id", ""))
		if bool(l.get("req", false)) and not probe.line_done(id):
			left.append(id)
	if left.is_empty():
		return {"ok": true, "why": "all required lines already done", "skipped": false}
	var pl := Planner.new(data, episode, opts.get("cond_fn", Callable()),
		{"beam": 2, "budget_ms": int(opts.get("probe_budget_ms", 0)), "max_macros": int(opts.get("probe_macros", 60)),
			"windows": ["safe", "next"]})
	var p := pl.plan(world, left, {"beam": 2, "bow": false})
	var done := PackedStringArray(p.get("lines", []))
	var missing := PackedStringArray()
	for l in left:
		if not done.has(l):
			missing.append(l)
	if not missing.is_empty():
		# Second opinion: the missing lines first, a wider beam, every window, a fresh budget.
		var pl2 := Planner.new(data, episode, opts.get("cond_fn", Callable()),
			{"beam": 3, "budget_ms": int(opts.get("probe_budget_ms", 0)), "max_macros": int(opts.get("probe_macros", 60)) * 2})
		var first := missing.duplicate()
		for l in left:
			if not first.has(l):
				first.append(l)
		var p2 := pl2.plan(world, first, {"beam": 3, "bow": false})
		var done2 := PackedStringArray(p2.get("lines", []))
		var still := PackedStringArray()
		for l in left:
			if not done2.has(l):
				still.append(l)
		missing = still
		p = p2
	return {"ok": missing.is_empty(), "skipped": false, "why": "" if missing.is_empty() else
		"planner could not finish %s from t=%.1f s (%s)" % [missing, probe.tick() / 60.0, "; ".join(PackedStringArray(p.get("notes", [])))]}


## Several seeded runs of several bots: {runs: [...], failed: n, summary: [lines]}.
static func run_many(factory: Callable, data: SolverData, episode: String, bots: PackedStringArray,
		runs: int, seed: int, opts: Dictionary = {}) -> Dictionary:
	var out: Array = []
	var failed := 0
	var replay_every := int(opts.get("replay_every", 5))
	for bot in bots:
		for k in runs:
			var o := opts.duplicate()
			o["replay"] = replay_every > 0 and k % replay_every == 0
			var r := run_bot(factory, data, episode, bot, seed + k, o)
			r.erase("log")
			if not bool(r["ok"]):
				failed += 1
			out.append(r)
	return {"runs": out, "failed": failed}


## One-line summary of a run.
static func summary_line(r: Dictionary) -> String:
	var inv: Array = r.get("invariants", [])
	return "[fuzz] %s %s seed=%d %s %.1f s, %d cmds, %d catches, %d near misses, %d laughs%s" % [
		r.get("episode", "?"), r.get("bot", "?"), int(r.get("seed", 0)), "OK" if bool(r.get("ok", false)) else "FAIL",
		int(r.get("ticks", 0)) / 60.0, int(r.get("commands", 0)), int(r.get("catches", 0)), int(r.get("near_misses", 0)),
		int(r.get("laughs", 0)), "" if inv.is_empty() else " — " + String(inv[0]) + (" (+%d)" % (inv.size() - 1) if inv.size() > 1 else "")]


## A bot's decision-maker: produces the next few steps whenever the executor runs dry.
class Brain extends RefCounted:
	var bot: String
	var rng: Planner._Rng
	var data: SolverData
	var episode: String
	var ex: Executor = null
	var rooms: PackedStringArray = []
	var spots: PackedStringArray = []       ## glowing hotspots in the episode's rooms
	var hiding: PackedStringArray = []
	var pranks: PackedStringArray = []
	var _reckless_i: int = 0

	func _init(p_bot: String, seed: int, p_data: SolverData, p_episode: String) -> void:
		bot = p_bot
		rng = Planner._Rng.new(seed * 2654435761 + 97)
		data = p_data
		episode = p_episode
		for r in data.episode(episode).get("rooms", []):
			rooms.append(SolverData.sv(r))
		if rooms.is_empty():
			rooms = data.room_ids()
		# `spots` keeps the struck hotspots too: random taps on them must be refused (invariant rule 13);
		# the hider only uses tonight's hiding spots.
		for id in data.hotspot_ids():
			if rooms.has(data.hotspot_room(id)):
				spots.append(id)
				if data.hotspot_kind(id) == "hiding" and data.is_live(episode, id):
					hiding.append(id)
		pranks = data.episode_pranks(episode)
		# Shuffle the prank order for reckless.
		for i in range(pranks.size() - 1, 0, -1):
			var j := rng.range_int(0, i)
			var t := pranks[i]
			pranks[i] = pranks[j]
			pranks[j] = t

	func _pick(arr: PackedStringArray) -> String:
		return arr[rng.range_int(0, arr.size() - 1)] if not arr.is_empty() else ""

	func _gap() -> Dictionary:
		return {"do": "idle", "s": snappedf(rng.range_int(12, 120) / 60.0, 0.01)}

	func next_steps(_e: Executor) -> Array:
		match bot:
			"random":
				return _random()
			"reckless":
				return _reckless()
			"hider":
				return _hider()
			"bait":
				return _bait()
		return [_gap()]

	func _random() -> Array:
		var p := ex.probe
		var cmd := {}
		match rng.range_int(0, 9):
			0, 1, 2:
				cmd = {"c": "go", "hotspot": _pick(spots), "run": rng.range_int(0, 3) == 0}
			3:
				var room := _pick(rooms)
				var r := data.room(room)
				cmd = {"c": "move", "room": room, "x": rng.range_int(int(r.get("x0", 0)), int(r.get("x1", 1))),
					"run": rng.range_int(0, 3) == 0}
			4:
				var its: PackedStringArray = []
				for ev in ex.log.events_named("pick_window"):
					its = SolverData.as_ids(ev.get("items", ""))
				cmd = {"c": "pick", "item": _pick(its) if not its.is_empty() else _pick(data.sorted_ids("items"))}
			5:
				cmd = {"c": "rig", "on": rng.range_int(0, 2) != 0}
			6:
				cmd = {"c": "freeze", "on": rng.range_int(0, 1) == 0}
			7:
				cmd = {"c": "squeak"}
			8:
				if p.hush_hidden():
					cmd = {"c": "pin", "hotspot": _pick(spots)}
				else:
					cmd = {"c": "freeze", "on": false}
			9:
				cmd = {"c": "pop_out", "run": rng.range_int(0, 1) == 0}
		return [{"do": "_raw", "cmds": [cmd]}, _gap()]

	func _reckless() -> Array:
		if pranks.is_empty():
			return [_gap()]
		var p := pranks[_reckless_i % pranks.size()]
		_reckless_i += 1
		var out: Array = []
		for s in data.prank_steps(p).size():
			var need := data.step_needs(p, s)
			if need != "":
				out.append({"do": "pick", "item": need, "from": data.item_source(need), "max_s": 30, "run": true})
			out.append({"do": "rig", "prank": p, "step": s, "max_s": 30, "run": true})
		out.append({"do": "idle", "s": 0.5})
		return out

	func _hider() -> Array:
		var spot := _pick(hiding)
		if spot == "":
			return [{"do": "squeak", "n": 1}, _gap()]
		return [{"do": "hide", "spot": spot, "max_s": 30, "run": rng.range_int(0, 2) == 0},
			{"do": "squeak", "n": rng.range_int(1, 3), "gap_s": 1.0},
			{"do": "idle", "s": snappedf(rng.range_int(60, 240) / 60.0, 0.01)},
			{"do": "pop_out", "run": rng.range_int(0, 1) == 0}]

	func _bait() -> Array:
		var p := ex.probe
		var room := p.bellows_room()
		if not rooms.has(room):
			return [{"do": "idle", "s": 2.0}]
		var r := data.room(room)
		var x := clampi(p.bellows_x() + p.bellows_facing() * 300, int(r.get("x0", 0)) + 20, int(r.get("x1", 0)) - 20)
		var out: Array = [{"do": "move", "room": room, "x": x, "max_s": 20},
			{"do": "wait", "until": {"or": [{"event_seen": "spotted"}, {"spot_meter_pct_ge": 100}]}, "max_s": 8}]
		# Run over a rigged STEP prank if there is one, else far away.
		var step_spot := ""
		for pr in pranks:
			var tr := data.trigger(pr)
			if SolverData.sv(tr.get("type", "")) == "step" and p.prank_state(pr) == "RIGGED":
				step_spot = SolverData.sv(tr.get("at", data.rig_point(pr, 0)))
		if step_spot == "":
			var far := ""
			var far_d := -1
			for id in spots:
				var d := data.walk_px(room, x, data.hotspot_room(id), data.hotspot_x(id))
				if d > far_d:
					far_d = d
					far = id
			step_spot = far
		if step_spot != "":
			out.append({"do": "go", "to": step_spot, "run": true, "max_s": 15})
		out.append({"do": "idle", "s": 4.0})
		return out
