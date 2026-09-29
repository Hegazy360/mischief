## Planner — the auto-solver (TECH §8.4). It never guesses sim internals: every candidate is
## executed on a `world.clone()` with the real `Executor`.
##
##   var pl := Planner.new(data, "n01_throat_tea")
##   var p := pl.plan(world, pl.all_lines())         # {ok, steps, lines, stars, applause, ticks, catches, …}
##   var proofs := pl.prove(factory)                 # line-alone, whole Script, ★★★, soft-lock
##
## 1. Predict: clone the world, hide Hush, idle two loops → Bellows' activity timeline, loop length,
##    fix-up stations seen.
## 2. Tasks: each Script line → a macro template from content: items → containers, rig steps at their
##    rig points (per-step `at`), double acts rig B before A, stand-in pranks (Mirror, Mirror) add a
##    `stand_in`, panto lines a `panto`, Big Numbers wait for the required lines; goal lines
##    (meltdown, chain) rig every free prank in loop order; unsupported kinds are reported.
## 3. Search: beam search (width 6) over task orderings × timing windows ("now"; "safe" = Bellows out of
##    the task room with an ETA longer than walk + rig + escape, and not hunting; "next" = after his
##    next activity starts, then safe; "later" = two activities on, tried only when all else failed).
##    An exposed Hush with him near first escapes (away from him, into cover); after each task she
##    hides in the nearest spot that isn't `in_use_next`; after a catch she hides, sits out On Guard
##    and redoes the step from its window check.
## 4. Score: lines done > stars > applause ≥ 100 > shorter duration > fewer catches.
## 5. Proofs (`prove`): each line alone, the whole Script, ★★★ reachable, a soft-lock check (3 forced
##    catches at seeded random ticks, re-plan the remaining lines, must still reach ★).
## 6. Budget: `max_macros` candidate executions (deterministic; default 400) and, as a safety cap,
##    `budget_ms` of wall time (default 60 s; 0 = none — solve.sh --auto passes 0 since s2-fix G #13, so a
##    proof no longer depends on the machine's speed). When it runs low the search narrows, and when
##    it is spent the best node is finished greedily.
class_name Planner
extends RefCounted

const WINDOWS: PackedStringArray = ["now", "safe", "next"]
const MACRO_MAX_TICKS := 60 * 150
const UNSUPPORTED_KINDS: PackedStringArray = ["witness", "herd", "prank_witnessed", "combo_witnessed", "chase_trip"]

var data: SolverData
var episode: String
var cond_fn: Callable
var beam_width: int = 6
var budget_ms: int = 60000
var max_macros: int = 400
var windows: PackedStringArray = WINDOWS
var seed: int = 1
var notes: PackedStringArray = []     ## what the planner could not do, and why
var expanded: int = 0                 ## candidate macros executed
var prediction: Dictionary = {}

var _t0: int = 0
var _deadline: int = 0
var _phase_ms: int = 0
var _macro_deadline: int = 0
var _phase_macros: int = 0


func _init(p_data: SolverData, p_episode: String, p_cond_fn: Callable = Callable(), opts: Dictionary = {}) -> void:
	data = p_data
	episode = p_episode
	cond_fn = p_cond_fn
	beam_width = int(opts.get("beam", 6))
	budget_ms = int(opts.get("budget_ms", 60000))
	max_macros = int(opts.get("max_macros", 400))
	seed = int(opts.get("seed", int(data.episode(episode).get("seed", 1))))
	if opts.has("windows"):
		windows = PackedStringArray(opts["windows"])
	_t0 = Time.get_ticks_msec()
	_deadline = _t0 + budget_ms
	_phase_ms = budget_ms
	_macro_deadline = max_macros
	_phase_macros = max_macros


## Milliseconds used since construction.
func elapsed_ms() -> int:
	return Time.get_ticks_msec() - _t0


## > 0 while the current phase still has budget (macros, and wall time when budget_ms > 0).
func _budget_left() -> int:
	if budget_ms > 0 and _deadline - Time.get_ticks_msec() <= 0:
		return 0
	return _macro_deadline - expanded


## True when a third or less of the phase's budget remains.
func _narrow() -> bool:
	if (_macro_deadline - expanded) * 3 < _phase_macros:
		return true
	return budget_ms > 0 and (_deadline - Time.get_ticks_msec()) * 3 < _phase_ms


## Give the next phase `pct` % of the whole budget (capped by what is left of it).
func _phase(pct: int) -> void:
	var now := Time.get_ticks_msec()
	var total_end := _t0 + budget_ms
	_deadline = mini(now + budget_ms * pct / 100, total_end)
	_phase_ms = maxi(1, _deadline - now)
	_macro_deadline = mini(expanded + maxi(1, max_macros * pct / 100), max_macros)
	_phase_macros = maxi(1, _macro_deadline - expanded)


## Every Script line id of the episode.
func all_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for l in data.script_lines(episode):
		out.append(SolverData.sv(l.get("id", "")))
	return out


## Required line ids.
func required_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for l in data.script_lines(episode):
		if bool(l.get("req", false)):
			out.append(SolverData.sv(l.get("id", "")))
	return out


func _executor(w: Object, steps: Array, seed_state: Variant = null) -> Executor:
	var o := {"episode": episode, "full_report": false, "max_recoveries": 5, "rewind_on_catch": true}
	if seed_state != null:
		o["seed_state"] = seed_state
	return Executor.new(w, steps, "ideal", cond_fn, data, o)


# --- 1. predict -------------------------------------------------------------------------------

## Clone, hide Hush, idle `loops` loops (cap `max_ticks`): {activities [{id, t}], loop_ticks,
## detours [{kind, station, t}], ended}.
func predict(world: Object, loops: int = 2, max_ticks: int = 60 * 300) -> Dictionary:
	var w: Object = world.call("clone")
	var probe := SolverProbe.new(w, data)
	var spot := data.nearest_hiding(probe.hush_room(), probe.hush_x(), _in_use_spots(probe))
	var steps: Array = []
	if spot != "":
		steps.append({"do": "hide", "spot": spot, "max_s": 20})
	var ex := _executor(w, steps)
	ex.run(60 * 30)
	var acts: Array = []
	var detours: Array = []
	var loop := data.loop_ids(episode)
	var first := loop[0] if not loop.is_empty() else ""
	var starts := PackedInt32Array()
	var t := 0
	var pending: Array = ex.log.events.duplicate()
	while t < max_ticks and not probe.ended():
		if pending.is_empty():
			w.call("step", [])
			t += 1
			pending = w.call("drain_events")
		var evs: Array = pending
		pending = []
		for ev in evs:
			match SolverData.sv(ev.get("e", "")):
				"b_activity":
					var id := SolverData.sv(ev.get("id", ""))
					acts.append({"id": id, "t": int(ev.get("t", 0)), "room": probe.bellows_room()})
					if id == first:
						starts.append(int(ev.get("t", 0)))
				"b_detour":
					detours.append({"kind": SolverData.sv(ev.get("kind", "")), "station": SolverData.sv(ev.get("station", "")), "t": int(ev.get("t", 0))})
		if starts.size() > loops:
			break
	var loop_ticks := starts[1] - starts[0] if starts.size() >= 2 else -1
	prediction = {"activities": acts, "loop_ticks": loop_ticks, "detours": detours, "ended": probe.ended()}
	return prediction


func _in_use_spots(probe: SolverProbe) -> PackedStringArray:
	var out := PackedStringArray()
	for id in data.hotspot_ids():
		if data.hotspot_kind(id) == "hiding" and bool(probe.hotspot_state(id).get("in_use_next", false)):
			out.append(id)
	return out


# --- 2. tasks ---------------------------------------------------------------------------------

## Task templates for `line_ids`: [{line, kind, pranks, req, big_number, stand_in, panto, supported, why}].
func tasks_for(line_ids: PackedStringArray) -> Array:
	var out: Array = []
	var loop := data.loop_ids(episode)
	# In the order asked for (it breaks score ties in the beam).
	for want in line_ids:
		var l := data.line(episode, want)
		if l.is_empty():
			continue
		var id := SolverData.sv(l.get("id", ""))
		var kind := SolverData.sv(l.get("kind", "prank"))
		var t := {"line": id, "kind": kind, "pranks": PackedStringArray(), "req": bool(l.get("req", false)),
			"big_number": bool(l.get("big_number", false)), "stand_in": "", "panto": 0, "supported": true, "why": ""}
		match kind:
			"prank", "double_act", "combo":
				t["pranks"] = data.line_pranks(episode, l)
			"meltdown", "chain":
				t["pranks"] = _pranks_in_loop_order(loop)
			"panto":
				t["panto"] = 3
			_:
				if UNSUPPORTED_KINDS.has(kind):
					t["supported"] = false
					t["why"] = "line kind '%s' has no planner template yet (Stage 3)" % kind
				else:
					t["supported"] = false
					t["why"] = "unknown line kind '%s'" % kind
		for p in t["pranks"]:
			if _is_stand_in(p):
				t["stand_in"] = p
		if t["supported"] and (t["pranks"] as PackedStringArray).is_empty() and int(t["panto"]) == 0:
			t["supported"] = false
			t["why"] = "line '%s' resolves to no prank" % id
		out.append(t)
	return out


func _is_stand_in(p: String) -> bool:
	for c in data.prank(p).get("conditions", []):
		if c is Dictionary and bool((c as Dictionary).get("hush_in_frame_frozen", false)):
			return true
	return false


## Episode pranks sorted by where their trigger activity sits in the loop.
func _pranks_in_loop_order(loop: PackedStringArray) -> PackedStringArray:
	var pairs: Array = []
	for p in data.episode_pranks(episode):
		var tr := data.trigger(p)
		var idx := loop.find(SolverData.sv(tr.get("activity", "")))
		pairs.append([idx if idx >= 0 else 99, float(tr.get("mark_s", 0.0)), p])
	pairs.sort()
	var out := PackedStringArray()
	for pr in pairs:
		out.append(pr[2])
	return out


# --- macros -----------------------------------------------------------------------------------

## Bellows states in which he is hunting: never a safe window.
const HUNTING: PackedStringArray = ["spotted", "chase", "search", "curious"]


## A "safe to act in `room` for `s` seconds" condition: he is out of the room, won't enter it for
## `s` seconds, and isn't hunting.
static func safe_cond(room: String, s: float) -> Dictionary:
	var hunting: Array = []
	for st in HUNTING:
		hunting.append({"bellows_state": st})
	return {"and": [{"bellows_not_in_room": room}, {"bellows_eta_to_room_gt_s": [room, snappedf(s, 0.1)]},
		{"not": {"or": hunting}}]}


## Steps for one task from the state of `probe`'s world with a timing window.
func macro(task: Dictionary, probe: SolverProbe, window: String, carry: PackedStringArray) -> Array:
	var steps: Array = []
	if bool(task.get("big_number", false)):
		# A sealed Big Number unseals after the required lines; an open one (its pranks are already
		# available, e.g. a double act of two Script pranks) must be armed before they land alone.
		var sealed := false
		for p in task["pranks"]:
			if probe.prank_state(p) == "LOCKED":
				sealed = true
		if sealed:
			steps.append({"do": "wait", "until": {"all_required_done": true}, "max_s": 240})
	var have := carry.duplicate()
	var hx := probe.hush_x()
	var hroom := probe.hush_room()
	var first := true
	var last_rp := ""
	# Exposed with Bellows in (or next to) her room: get out of sight before waiting for a window.
	if window != "now" and not probe.hush_hidden() and _danger_near(probe):
		steps.append_array(escape_steps(probe))
	for p in task["pranks"]:
		var ps := probe.prank_state(p)
		if ps in ["RIGGED", "FIRED", "LANDED"]:
			continue
		var n := data.prank_steps(p).size()
		for s in n:
			var need := data.step_needs(p, s)
			var rp := data.rig_point(p, s)
			var room := data.hotspot_room(rp)
			if need != "" and not have.has(need):
				var src := data.item_source(need)
				if window != "now":
					var pos := {"room": hroom, "x": hx}
					var st := _stage_steps(probe, pos, data.hotspot_room(src), window, first)
					if not st.is_empty():
						steps.append_array(st)
						first = false
						hroom = String(pos["room"])
						hx = int(pos["x"])
				if first or window != "now":
					_window_steps(steps, window if first else "safe", data.hotspot_room(src),
						_walk_s(hroom, hx, src) + 1.5, _travel(hroom, hx, data.hotspot_room(src)))
					first = false
				steps.append({"do": "pick", "item": need, "from": src})
				have.append(need)
				hroom = data.hotspot_room(src)
				hx = data.hotspot_x(src)
			if window != "now":
				var pos2 := {"room": hroom, "x": hx}
				var st2 := _stage_steps(probe, pos2, room, window, first)
				if not st2.is_empty():
					steps.append_array(st2)
					first = false
					hroom = String(pos2["room"])
					hx = int(pos2["x"])
			if first or window != "now":
				var d := _walk_s(hroom, hx, rp) + data.step_prep_ticks(p, s) / 60.0 + 2.5
				_window_steps(steps, "safe" if not first else window, room, d, _travel(hroom, hx, room))
				first = false
			steps.append({"do": "rig", "prank": p, "step": s})
			hroom = room
			hx = data.hotspot_x(rp)
			last_rp = rp
	var sp := String(task.get("stand_in", ""))
	if sp != "":
		steps.append({"do": "wait", "until": {"bellows_activity_in": ["mirror", "fixup_mirror"]}, "max_s": 150})
		steps.append({"do": "stand_in", "prank": sp, "release_round": 3, "max_s": 60})
		return steps
	if int(task.get("panto", 0)) > 0:
		steps.append({"do": "wait", "until": {"bellows_activity_in": _panto_activities()}, "max_s": 150})
		steps.append({"do": "panto", "rounds": int(task["panto"]), "max_s": 60})
		return steps
	if last_rp != "":
		var spot := _hide_spot(probe, data.hotspot_room(last_rp), data.hotspot_x(last_rp))
		if spot != "":
			steps.append({"do": "hide", "spot": spot})
	return steps


## Steps that take an exposed Hush out of Bellows' way: with him in her room, run to the
## neighbouring room on her side (away from him) and hide there (else just get there); with him
## next door, hide in the nearest spot of her room.
func escape_steps(probe: SolverProbe) -> Array:
	var hr := probe.hush_room()
	var hx := probe.hush_x()
	if probe.bellows_room() == hr:
		var r := data.room(hr)
		var away_left := hx < probe.bellows_x()
		var best := ""
		for nb in data.neighbours(hr):
			var nr := data.room(nb)
			if nr.is_empty() or data.room_floor(nb) != data.room_floor(hr):
				continue
			var left := int(nr.get("x1", 0)) <= int(r.get("x0", 0))
			if left == away_left:
				best = nb
		if best != "":
			var spot := data.nearest_hiding(best, hx, _in_use_spots(probe), PackedStringArray([best]))
			if spot != "":
				return [{"do": "hide", "spot": spot, "run": true, "max_s": 20}]
			var nr2 := data.room(best)
			var x := int(nr2.get("x0", 0)) + 60 if away_left else int(nr2.get("x1", 0)) - 60
			return [{"do": "move", "room": best, "x": x, "run": true, "max_s": 20}]
	var cover := _hide_spot(probe, hr, hx)
	return [{"do": "hide", "spot": cover, "max_s": 20}] if cover != "" else []


## Bellows is in Hush's room or a neighbouring one (and not reacting).
func _danger_near(probe: SolverProbe) -> bool:
	var br := probe.bellows_room()
	var hr := probe.hush_room()
	return br == hr or data.neighbours(hr).has(br)


## Loop length in seconds: the prediction when there is one, else Σ activity durations + 5 s of
## walking per activity.
func loop_estimate_s() -> float:
	if int(prediction.get("loop_ticks", -1)) > 0:
		return int(prediction["loop_ticks"]) / 60.0
	var s := 0.0
	for a in data.loop_ids(episode):
		s += float(data.activities.get(a, {}).get("dur_s", 6.0)) + 5.0
	return maxf(s, 30.0)


## Rooms strictly between `from_room` and `to_room` on one floor, ordered from `from_room`.
func _between(from_room: String, to_room: String) -> PackedStringArray:
	var out := PackedStringArray()
	var a := data.room(from_room)
	var b := data.room(to_room)
	if a.is_empty() or b.is_empty() or data.room_floor(from_room) != data.room_floor(to_room):
		return out
	var lo := mini(int(a.get("x1", 0)), int(b.get("x1", 0)))
	var hi := maxi(int(a.get("x0", 0)), int(b.get("x0", 0)))
	var pairs: Array = []
	for rid in data.room_ids():
		var r := data.room(rid)
		if rid == from_room or rid == to_room or data.room_floor(rid) != data.room_floor(from_room):
			continue
		if int(r.get("x0", 0)) >= lo and int(r.get("x1", 0)) <= hi:
			pairs.append([absi(int(r.get("x0", 0)) - int(a.get("x0", 0))), rid])
	pairs.sort()
	for pr in pairs:
		out.append(pr[1])
	return out


## Stage a long trip: when rooms lie between Hush and the target, first slip into the one next to
## the target and hide there (its own window), so the last leg needs only one room to be clear.
## Returns the staging steps (possibly empty) and updates `pos` = {room, x}.
func _stage_steps(probe: SolverProbe, pos: Dictionary, to_room: String, window: String, first: bool) -> Array:
	var mid := _between(String(pos["room"]), to_room)
	if mid.is_empty():
		return []
	var stage := mid[mid.size() - 1]
	var spot := data.nearest_hiding(stage, int(data.room(stage).get("x0", 0)), _in_use_spots(probe), PackedStringArray([stage]))
	if spot == "":
		return []
	var steps: Array = []
	_window_steps(steps, window if first else "safe", stage, _walk_s(String(pos["room"]), int(pos["x"]), spot) + 1.0,
		_travel(String(pos["room"]), int(pos["x"]), stage))
	steps.append({"do": "hide", "spot": spot, "max_s": 30})
	pos["room"] = stage
	pos["x"] = data.hotspot_x(spot)
	return steps


## Extra conditions for walking from (room, x) to `to_room`: Bellows is in none of the rooms she
## crosses, and if he shares her starting room he faces away from her.
func _travel(from_room: String, _from_x: int, to_room: String) -> Array:
	var out: Array = []
	if from_room == to_room or from_room == "" or data.room(from_room).is_empty() or data.room(to_room).is_empty():
		return out
	for rid in _between(from_room, to_room):
		out.append({"bellows_not_in_room": rid})
	out.append({"or": [{"bellows_not_in_room": from_room}, {"bellows_facing_away_from_hush": true}]})
	return out


func _window_steps(steps: Array, window: String, room: String, secs: float, travel: Array = []) -> void:
	var c := Planner.safe_cond(room, secs)
	if not travel.is_empty():
		(c["and"] as Array).append_array(travel)
	var wait := {"do": "wait", "until": c, "max_s": 75, "soft": true}
	match window:
		"safe":
			steps.append(wait)
		"next":
			steps.append({"do": "wait_event", "event": "b_activity", "max_s": 60, "soft": true})
			steps.append(wait)
		"later":
			steps.append({"do": "wait_event", "event": "b_activity", "max_s": 60, "soft": true})
			steps.append({"do": "wait_event", "event": "b_activity_end", "max_s": 60, "soft": true})
			steps.append({"do": "wait_event", "event": "b_activity", "max_s": 60, "soft": true})
			steps.append(wait)


func _walk_s(room: String, x: int, hotspot: String) -> float:
	return data.walk_px(room, x, data.hotspot_room(hotspot), data.hotspot_x(hotspot)) / 400.0


func _hide_spot(probe: SolverProbe, room: String, x: int) -> String:
	var exclude := _in_use_spots(probe)
	var act_spots := PackedStringArray()
	for id in data.hotspot_ids():
		if data.hotspot_kind(id) == "hiding" and data.in_use_activity(id) != "":
			act_spots.append(id)
	var ex2 := exclude.duplicate()
	ex2.append_array(act_spots)
	var s := data.nearest_hiding(room, x, ex2)
	return s if s != "" else data.nearest_hiding(room, x, exclude)


func _panto_activities() -> Array:
	var out: Array = []
	for a in data.loop_ids(episode):
		if bool(data.activities.get(a, {}).get("panto", false)) and not out.has(a):
			out.append(a)
	return out


# --- 3. search --------------------------------------------------------------------------------

## Plan `line_ids` from `world`'s current state. opts: {beam, windows, finalize (true), bow (true)}.
## Returns {ok, steps, lines, target, stars, applause, ticks, catches, score, world, notes}.
func plan(world: Object, line_ids: PackedStringArray, opts: Dictionary = {}) -> Dictionary:
	var width := int(opts.get("beam", beam_width))
	var wins: PackedStringArray = PackedStringArray(opts.get("windows", windows))
	var tasks := tasks_for(line_ids)
	var plan_notes := PackedStringArray()
	var todo: Array = []
	for i in tasks.size():
		if bool(tasks[i]["supported"]):
			todo.append(i)
		else:
			plan_notes.append("%s: %s" % [tasks[i]["line"], tasks[i]["why"]])
	var root := {"world": world.call("clone"), "steps": [], "left": todo, "catches": 0, "carry": null,
		"score": []}
	var probe0 := SolverProbe.new(root["world"], data)
	root["score"] = _score(probe0, line_ids, 0, 0)
	var beam: Array = [root]
	var finished: Array = []
	while not beam.is_empty():
		if _budget_left() <= 0:
			# Out of budget: finish the best node greedily (safe windows, list order).
			finished.append(_greedy_rest(beam[0], tasks, line_ids))
			break
		var next: Array = []
		var seen := {}
		var narrow := _narrow()
		for node in beam:
			if (node["left"] as Array).is_empty():
				finished.append(node)
				continue
			var cand_tasks: Array = node["left"]
			for ti in cand_tasks:
				var task: Dictionary = tasks[ti]
				var p := SolverProbe.new(node["world"], data)
				if _task_done(p, task):
					var skip: Dictionary = node.duplicate()
					skip["left"] = (node["left"] as Array).filter(func(x): return x != ti)
					next.append(skip)
					continue
				var wl: PackedStringArray = wins if not narrow else PackedStringArray(["safe"])
				var made := 0
				for win in wl:
					if _budget_left() <= 0:
						break
					var child := _expand(node, task, ti, win, line_ids)
					if child.is_empty():
						continue
					made += 1
					var key := "%s|%d" % [str(child["left"]), int(child["hash"])]
					if seen.has(key):
						continue
					seen[key] = true
					next.append(child)
				if made == 0 and _budget_left() > 0:
					# Every window failed from here: try once more two activities later.
					var late := _expand(node, task, ti, "later", line_ids)
					if not late.is_empty():
						next.append(late)
				if narrow:
					break
		if next.is_empty():
			break
		next.sort_custom(func(a, b): return Planner._better(a["score"], b["score"]))
		beam = next.slice(0, width if _budget_left() > 0 else 1)
		if _budget_left() <= 0:
			# Out of budget: finish greedily in list order.
			for node in beam:
				finished.append(_greedy_rest(node, tasks, line_ids))
			break
	if finished.is_empty():
		finished = beam
	var best: Dictionary = {}
	var best_score: Array = []
	for node in finished:
		var fin: Dictionary = _finalize(node, line_ids, opts) if bool(opts.get("finalize", true)) else node
		if best.is_empty() or Planner._better(fin["score"], best_score):
			best = fin
			best_score = fin["score"]
	if best.is_empty():
		return {"ok": false, "steps": [], "lines": [], "target": Array(line_ids), "notes": Array(plan_notes),
			"why": "no candidate survived"}
	var pr := SolverProbe.new(best["world"], data)
	var done := pr.lines_done()
	var all_done := true
	for l in line_ids:
		if not done.has(l):
			all_done = false
	return {"ok": all_done, "steps": best["steps"], "lines": Array(done), "target": Array(line_ids),
		"stars": pr.stars(), "applause": pr.applause_tenths() / 10.0, "ticks": pr.tick(),
		"catches": int(best["catches"]), "score": best["score"], "world": best["world"],
		"notes": Array(plan_notes), "expanded": expanded, "elapsed_ms": elapsed_ms(), "carry": best.get("carry", null)}


## True when a task needs no macro: its line is done, or (plain prank lines) its prank is armed.
## A double act / combo whose pranks already fired without the line is dead: also "done" (skipped).
func _task_done(p: SolverProbe, task: Dictionary) -> bool:
	if p.line_done(String(task["line"])):
		return true
	var prs: PackedStringArray = task["pranks"]
	if prs.is_empty() or String(task.get("stand_in", "")) != "" or int(task.get("panto", 0)) > 0:
		return false
	var armed := true
	var spent := false
	for pr in prs:
		var st := p.prank_state(pr)
		if not (st in ["RIGGED", "FIRED", "LANDED"]):
			armed = false
		if st in ["FIRED", "LANDED"]:
			spent = true
	if String(task.get("kind", "prank")) == "prank":
		return armed
	return spent


## Run one task macro on a clone of the node's world. {} when the macro failed outright.
func _expand(node: Dictionary, task: Dictionary, ti: int, win: String, line_ids: PackedStringArray) -> Dictionary:
	var w: Object = (node["world"] as Object).call("clone")
	var probe := SolverProbe.new(w, data)
	var carry := PackedStringArray()
	var cs: Variant = node.get("carry", null)
	if cs is Dictionary:
		for k in (cs as Dictionary).get("carry", {}):
			carry.append(String(k))
	else:
		carry = probe.hush_carrying()
	var steps := macro(task, probe, win, carry)
	var ex := _executor(w, steps, cs)
	var r := ex.run(MACRO_MAX_TICKS)
	expanded += 1
	if not bool(r.get("ok", false)):
		return {}
	var catches := int(node["catches"]) + int(r.get("catches", 0))
	var child := {"world": w, "steps": (node["steps"] as Array) + steps,
		"left": (node["left"] as Array).filter(func(x): return x != ti), "catches": catches,
		"carry": ex.carry_state(), "hash": probe.state_hash()}
	child["score"] = _score(probe, line_ids, catches, _rigged_pending(probe, line_ids))
	return child


func _greedy_rest(node: Dictionary, tasks: Array, line_ids: PackedStringArray) -> Dictionary:
	var cur := node
	for ti in (node["left"] as Array).duplicate():
		var c := _expand(cur, tasks[ti], ti, "safe", line_ids)
		if c.is_empty():
			c = _expand(cur, tasks[ti], ti, "later", line_ids)
		if c.is_empty():
			var skip: Dictionary = cur.duplicate()
			skip["left"] = (cur["left"] as Array).filter(func(x): return x != ti)
			cur = skip
		else:
			cur = c
	return cur


## Wait for the payoffs (up to 2.5 loops), then bow when ★ is earned.
func _finalize(node: Dictionary, line_ids: PackedStringArray, opts: Dictionary) -> Dictionary:
	var w: Object = (node["world"] as Object).call("clone")
	var probe := SolverProbe.new(w, data)
	var loop_s := loop_estimate_s()
	var all_c: Array = []
	for l in line_ids:
		all_c.append({"line_done": l})
	var deadline := snappedf(probe.tick() / 60.0 + loop_s * 2.5, 0.1)
	var steps: Array = []
	if not probe.hush_hidden():
		steps.append_array(escape_steps(probe))
	steps.append({"do": "wait", "until": {"or": [{"and": all_c}, {"tick_ge_s": deadline}]},
		"max_s": loop_s * 2.5 + 25.0})
	var ex := _executor(w, steps, node.get("carry", null))
	ex.max_recoveries = 20   # waiting is passive: keep waiting after a catch
	ex.run(int((loop_s * 2.5 + 30.0) * 60.0))
	var extra: Array = steps.duplicate()
	if bool(opts.get("bow", true)) and not probe.ended() and bool(probe.stars()[0]):
		var bow: Array = [{"do": "bow"}]
		var ex2 := _executor(w, bow)
		ex2.run(600)
		extra.append_array(bow)
	var catches := int(node["catches"]) + ex.log.events_named("caught").size()
	var fin := {"world": w, "steps": (node["steps"] as Array) + extra, "left": [], "catches": catches,
		"carry": ex.carry_state()}
	fin["score"] = _score(probe, line_ids, catches, 0)
	return fin


## Score tuple: [lines done, rigged-but-pending, stars, applause ≥ 100, −ticks, −catches].
func _score(probe: SolverProbe, line_ids: PackedStringArray, catches: int, pending: int) -> Array:
	var done := 0
	for l in probe.lines_done():
		if line_ids.has(l):
			done += 1
	var st := 0
	for s in probe.stars():
		if s:
			st += 1
	var app := probe.applause_tenths()
	return [done, pending, st, 1 if app >= 1000 else 0, -probe.tick(), -catches]


func _rigged_pending(probe: SolverProbe, line_ids: PackedStringArray) -> int:
	var n := 0
	for t in tasks_for(line_ids):
		for p in t["pranks"]:
			if probe.prank_state(p) == "RIGGED":
				n += 1
	return n


## a better than b (lexicographic, higher wins).
static func _better(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


# --- 5. proofs --------------------------------------------------------------------------------

## Run every proof from fresh worlds made by `factory` (Callable() -> world). Returns
## {line_alone: {line: {ok, why}}, script: {ok, lines, applause, stars, steps}, three_stars: bool,
##  softlock: {ok, catches, why}, notes, elapsed_ms, budget_ms}.
func prove(factory: Callable, opts: Dictionary = {}) -> Dictionary:
	var out := {"line_alone": {}, "notes": []}
	var w0: Object = factory.call()
	if w0 == null:
		out["error"] = "world factory returned null"
		return out
	predict(w0)
	out["prediction"] = {"loop_s": int(prediction.get("loop_ticks", -1)) / 60.0,
		"activities": (prediction.get("activities", []) as Array).slice(0, 16)}
	var lines := all_lines()
	var req := required_lines()
	# Whole Script first (it gets the widest beam and 45 % of the budget).
	_phase(45)
	var whole := plan(factory.call(), lines)
	out["script"] = {"ok": bool(whole.get("ok", false)), "lines": whole.get("lines", []),
		"applause": whole.get("applause", 0.0), "stars": whole.get("stars", []), "ticks": whole.get("ticks", 0),
		"catches": whole.get("catches", 0), "steps": whole.get("steps", [])}
	out["three_stars"] = bool((whole.get("stars", [false, false, false]) as Array)[2]) if whole.has("stars") else false
	for n in whole.get("notes", []):
		(out["notes"] as Array).append(n)
	# Each line alone (a Big Number needs the required lines first; a director-led Prologue plays its
	# lines in Script order, so there "alone" means with the lines before it): 30 % split.
	var linear := script_order(data.episode(episode))
	var per_line := maxi(1, 30 / maxi(1, lines.size()))
	var prefix := PackedStringArray()
	for l in lines:
		_phase(per_line)
		prefix.append(l)
		if _budget_left() <= 0:
			out["line_alone"][l] = {"ok": false, "why": "budget exhausted"}
			continue
		var ids := PackedStringArray([l]) if not linear else prefix.duplicate()
		if linear and (whole.get("lines", []) as Array).has(l):
			# The Prologue plays its lines in Script order (director-led): "alone" = with the lines
			# before it, which the whole-Script plan already proves when it landed this one
			# (s2-fix G #13; the Big Number rule below is the same argument).
			out["line_alone"][l] = {"ok": true, "why": "", "via": "whole Script (Script order)"}
			continue
		var ld := data.line(episode, l)
		if bool(ld.get("big_number", false)):
			# The Big Number needs the required lines first; the whole-Script plan already proves
			# that combination when it landed the Big Number.
			if (whole.get("lines", []) as Array).has(l):
				out["line_alone"][l] = {"ok": true, "why": "", "via": "whole Script"}
				continue
			ids = req.duplicate()
			ids.append(l)
		var p := plan(factory.call(), ids, {"beam": 2, "bow": false})
		var ok := (p.get("lines", []) as Array).has(l)
		out["line_alone"][l] = {"ok": ok, "why": "" if ok else "not landed (done: %s)" % [p.get("lines", [])]}
	# Soft-lock check: the rest.
	_phase(100)
	out["softlock"] = softlock_check(factory, whole, int(opts.get("catches", 3)))
	out["elapsed_ms"] = elapsed_ms()
	out["budget_ms"] = budget_ms
	out["max_macros"] = max_macros
	out["expanded"] = expanded
	return out


## True when an episode plays its Script in order: the Prologue (act 0: its director leads the
## player through the lines, an uncapped player-led gate). Every other Night's `director` block is
## timing (cues, the launch offset), not order, so its lines are proved alone (s2-fix G #13). Pure.
static func script_order(ep: Dictionary) -> bool:
	return ep.get("director", null) is Dictionary and int(ep.get("act", 1)) == 0


## Inject up to `n` forced catches at seeded random ticks along `whole`'s route, re-planning the
## remaining lines after each; must still end with ★ (every required line).
func softlock_check(factory: Callable, whole: Dictionary, n: int = 3) -> Dictionary:
	var tmax := data.tomatoes_max(episode)
	if tmax > 0:
		n = mini(n, tmax - 1)
	var steps: Array = whole.get("steps", [])
	var dur := int(whole.get("ticks", 0))
	if steps.is_empty() or dur <= 0:
		return {"ok": false, "catches": 0, "why": "no whole-Script plan to perturb"}
	var rng := _Rng.new(seed * 7919 + 13)
	var at: Array = []
	for i in n:
		at.append(int(dur * (10 + rng.range_int(0, 60)) / 100))
	at.sort()
	var w: Object = factory.call()
	var probe := SolverProbe.new(w, data)
	var cur_steps: Array = steps
	var carry: Variant = null
	var injected := 0
	var req := required_lines()
	for k in at.size():
		var run_for := int(at[k]) - probe.tick()
		if run_for > 0:
			var ex := _executor(w, cur_steps, carry)
			ex.run(run_for)
			carry = ex.carry_state()
		if probe.ended():
			break
		var got := _force_catch(w, probe)
		if got:
			injected += 1
		carry = null
		var left := PackedStringArray()
		for l in all_lines():
			if not probe.line_done(l):
				left.append(l)
		var re := plan(w, left, {"beam": 2, "finalize": false})
		cur_steps = re.get("steps", [])
		if re.has("world"):
			pass
	var ex2 := _executor(w, cur_steps, carry)
	ex2.run(60 * 400)
	var fin_left := PackedStringArray()
	for l in req:
		if not probe.line_done(l):
			fin_left.append(l)
	if not fin_left.is_empty() and not probe.ended():
		var re2 := plan(w, fin_left, {"beam": 2})
		var ex3 := _executor(w, re2.get("steps", []))
		ex3.run(60 * 400)
	var missing := PackedStringArray()
	for l in req:
		if not probe.line_done(l):
			missing.append(l)
	var cant_fail := bool(data.rules(episode).get("cant_fail", false))
	if cant_fail and injected == 0:
		# Nothing to perturb: a can't-fail Night never catches Hush (the whole-Script plan stands).
		return {"ok": bool(whole.get("ok", false)), "catches": 0, "at": at, "cant_fail": true,
			"why": "" if bool(whole.get("ok", false)) else "the whole-Script plan failed",
			"note": "can't-fail: no catch can be forced"}
	var ok := missing.is_empty()
	var why := "" if ok else "after %d forced catch(es) the required lines %s never landed" % [injected, missing]
	if injected == 0:
		why += (" " if why != "" else "") + "(no catch could be forced)"
	return {"ok": ok, "catches": injected, "at": at, "why": why, "cant_fail": cant_fail}


## Walk into Bellows' view and wait to be caught (≤ 40 s). True if a catch happened.
func _force_catch(w: Object, probe: SolverProbe) -> bool:
	var room := probe.bellows_room()
	var x := probe.bellows_x() + probe.bellows_facing() * 150
	var steps: Array = [{"do": "move", "room": room, "x": x, "max_s": 30},
		{"do": "wait_event", "event": "caught", "since": "step", "max_s": 40}]
	var ex := _executor(w, steps)
	ex.max_recoveries = 0
	ex.run(60 * 75)
	var caught := ex.log.events_named("caught").size() > 0
	if caught:
		# Let control return.
		var t_end := probe.tick() + 260
		while probe.tick() < t_end and not probe.ended():
			w.call("step", [])
			w.call("drain_events")
	return caught


## The best plan as an `_auto/` solution dict (route "auto").
func to_solution(p: Dictionary) -> Dictionary:
	var stars: Array = p.get("stars", [false, false, false])
	var app := float(p.get("applause", 0.0))
	return {"version": 1, "episode": episode, "generated_by": "tools/solve.gd --write-auto", "routes": {
		"auto": {"persona": "ideal", "steps": p.get("steps", []),
			"expect": {"stars": stars, "applause": [floorf(app * 0.9), ceilf(app * 1.1) + 1.0],
				"catches_max": int(p.get("catches", 0))}}}}


## xorshift32 (deterministic; the sim's Rng is not a dependency of the solver).
class _Rng extends RefCounted:
	var state: int = 1

	func _init(s: int) -> void:
		state = s & 0xFFFFFFFF
		if state == 0:
			state = 0x9E3779B9

	func next_u32() -> int:
		var x := state
		x ^= (x << 13) & 0xFFFFFFFF
		x ^= x >> 17
		x ^= (x << 5) & 0xFFFFFFFF
		state = x & 0xFFFFFFFF
		return state

	## Uniform in [lo, hi].
	func range_int(lo: int, hi: int) -> int:
		return lo + int(next_u32() % (hi - lo + 1))
