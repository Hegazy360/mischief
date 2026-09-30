## Executor — plays one route on a world, one tick at a time (TECH §8.2).
##
##   var ex := Executor.new(world, route, "ideal")      # route: {steps, expect} or an Array of steps
##   var report := ex.run(36000)                          # -> Metrics report + {ok, fail, steps, ...}
##
## It turns macro steps into per-tick command arrays for `world.step(cmds)`:
## `go, move, pick, rig, hide, pop_out, freeze, squeak, stand_in, panto, wait, wait_event, idle, bow`.
## - `rig` walks to the rig point (the step's own `at` or the prank's), holds `rig on` until
##   `rig_step_done`, then releases; an already rigged prank is skipped.
## - `hide` walks + dives and waits for the `hide` event.
## - `stand_in` walks to the mirror frame, holds FREEZE until `mirror_round == release_round`
##   (default 3), releases, and waits for the prank to fire.
## - `panto` squeaks only while Bellows faces away and holds FREEZE through his looks.
## - `wait_event` looks at the whole run for one-shot comedy/score events (prank_fire, reaction_*,
##   rigged, line_done, …) and at events since the step began for everything else; `"since":
##   "run"|"step"` overrides.
## Every step has a timeout (`max_s`, default 60 s) → a failure reason naming the step; a step marked
## `"soft": true` (the planner's timing windows) completes on timeout instead.
## Conditions go through `cond_fn(world, cond)`; default: the sim's `Conditions` (soft hook), or the
## solver's fallback `SolverConditions` when the sim has none or the world asks for it
## (`solver_fallback_conditions = true`, e.g. the tests' MockWorld).
## Recovery: after a catch the executor waits for control to return, re-picks lost items and
## restarts the interrupted step (at most `max_recoveries` times).
## Bots (Fuzz): `opts.step_source` = Callable(executor) -> Array supplies more steps whenever the list
## runs out (empty = done); `opts.continue_on_fail` turns step failures into warnings; the internal
## step `{"do": "_raw", "cmds": [...]}` sends raw commands this tick.
class_name Executor
extends RefCounted

enum { RUNNING, DONE, FAILED }

const DEFAULT_MAX_S := 60.0
const DEFAULT_RUN_TICKS := 36000       ## 10 minutes
const CAUGHT_HOLD_TICKS := 240
## Events that happen once per Night: wait_event matches them over the whole run by default.
const RUN_SCOPE_EVENTS: PackedStringArray = ["prank_fire", "reaction_start", "reaction_accent", "reaction_end",
	"rigged", "line_done", "all_lines_done", "big_number_unsealed", "star", "combo", "knock_on",
	"meltdown_start", "fizzle", "mirror_round", "panto_bit"]
## Step kinds that only wait (they may complete while an evasion interrupt keeps Hush hidden).
const PASSIVE_STEPS: PackedStringArray = ["wait", "wait_event", "idle"]

var world: Object
var probe: SolverProbe
var data: SolverData
var persona: Persona
var route: Dictionary = {}
var steps: Array = []
var cond_fn: Callable
var log: SolverLog
var opts: Dictionary = {}
var ok: bool = false
var fail: PackedStringArray = []
var warnings: PackedStringArray = []
var step_log: Array = []            ## [{i, label, t0, t1, ok, why}]
var max_recoveries: int = 3

var _carry: Dictionary = {}          ## item -> uses left
var _hidden: String = ""
var _last_arrive: String = ""
var _rig_hold: bool = false
var _freeze_hold: bool = false
var _rig_done: Dictionary = {}       ## prank -> step completions seen
var _cmds: Array = []
var _i: int = 0
var _st: Dictionary = {}
var _interrupt: Dictionary = {}      ## active evasion {phase, room, spot, calm, t0}
var _control_at: int = -1            ## tick control returns after a catch (−1 none)
var _recoveries: int = 0
var _started: bool = false
var _dawdle_left: int = 0
var _why: String = ""
var _step_ticks: int = 0             ## ticks the current step has been on top


## world: a SimWorld (or MockWorld); p_route: resolved route dict ({steps, expect, persona,
## filter_required}) or an Array of steps; p_persona: Persona, name or null (= route persona);
## p_cond_fn: Callable(world, cond) -> bool (empty = default); p_data: SolverData (null =
## res://data); p_opts: {episode, full_report (true), max_recoveries (3), no_dawdle}.
func _init(p_world: Object, p_route: Variant, p_persona: Variant = null, p_cond_fn: Callable = Callable(),
		p_data: SolverData = null, p_opts: Dictionary = {}) -> void:
	world = p_world
	opts = p_opts
	data = p_data if p_data != null else SolverData.load_dir("res://data")
	probe = SolverProbe.new(world, data)
	if p_route is Array:
		route = {"steps": p_route, "expect": {}}
	elif p_route is Dictionary:
		route = p_route
	var pname := ""
	if p_persona is Persona:
		persona = p_persona
	else:
		pname = String(p_persona) if p_persona != null else SolverData.sv(route.get("persona", "ideal"))
		persona = Persona.make(pname)
	var ep := SolverData.sv(opts.get("episode", probe.episode_id()))
	if ep == "" and data.episodes.size() == 1:
		ep = SolverData.sv(data.episodes.keys()[0])
	opts["episode"] = ep
	steps = persona.transform(route.get("steps", []), data, ep, bool(route.get("filter_required", false)))
	max_recoveries = int(opts.get("max_recoveries", 3))
	log = SolverLog.new()
	log.episode = ep
	log.route = SolverData.sv(route.get("name", ""))
	log.persona = persona.name
	_init_log_facts()
	cond_fn = p_cond_fn
	if not cond_fn.is_valid():
		var sim_c := Callable() if _fallback_hooks() else SolverHooks.sim_conditions()
		if sim_c.is_valid():
			cond_fn = sim_c
		else:
			cond_fn = SolverConditions.new(probe, Executor._history_of(log)).as_callable()
	# Seed tracking from the world (runs that continue from a clone).
	for it in probe.hush_carrying():
		_carry[it] = int(_carry.get(it, 0)) + data.item_count(it)
	var hs := probe.hush_hidden_spot()
	_hidden = hs if hs != "?" else ""
	# Holds left on by whoever drove this world before (fuzz bots, a previous macro).
	_rig_hold = probe.hush_rig_held()
	_freeze_hold = probe.hush_freeze_held()
	var seed_state: Variant = opts.get("seed_state", null)
	if seed_state is Dictionary:
		_carry = (seed_state as Dictionary).get("carry", _carry).duplicate()
		_hidden = SolverData.sv((seed_state as Dictionary).get("hidden", _hidden))
		_rig_done = (seed_state as Dictionary).get("rig_done", {}).duplicate()
	_dawdle_left = 0 if bool(opts.get("no_dawdle", false)) else persona.dawdle_ticks


## True when the world asks for the solver's own fallbacks (conditions, laughs, constants) instead
## of the sim's modules (the tests' MockWorld sets `solver_fallback_conditions = true`).
func _fallback_hooks() -> bool:
	return bool(SolverProbe.field(world, "solver_fallback_conditions", false))


func _init_log_facts() -> void:
	var ep := SolverData.sv(opts.get("episode", ""))
	var relaxed := bool(opts.get("relaxed", false))
	log.relaxed = relaxed
	log.fill_ticks = data.spot_fill_ticks(ep, relaxed)
	log.loop = data.loop_entries(ep)
	var gated := PackedStringArray()
	for e in log.loop:
		var g: Variant = (e as Dictionary).get("gate", null)
		if g is Dictionary and (g as Dictionary).get("max_s", null) == null:
			gated.append(SolverData.sv(e.get("a", "")))
	for aid in data.fixup_hold_activities(ep):
		if not gated.has(aid):
			gated.append(aid)
	log.gated = gated
	for id in data.hotspot_ids():
		if data.hotspot_kind(id) == "hiding":
			var a := data.in_use_activity(id)
			if a != "":
				log.in_use[id] = a
	log.has_beryl = probe.has_beryl()
	log.b_walk_sub = 240 if _fallback_hooks() else SolverHooks.sim_const("B_WALK", 240)
	log.launch_offset_s = data.launch_offset_s(ep)
	log.ff_repress_ticks = persona.ff_repress_ticks
	# the slow first-timer needs the ghost_ff cue — unless an earlier Night already taught ⏩
	var cue_ix := data.cue_episode_index("ghost_ff")
	log.ff_needs_cue = persona.ff_needs_cue and not (cue_ix >= 0 and data.episode_index(ep) > cue_ix)
	log.enter_ticks = data.enter_ticks(ep)
	log.combos_allowed = data.combos_rule(ep)
	# rule 13 needs a world that applies the live mask (the real sim; mocks without one are exempt)
	var ctx: Variant = SolverProbe.field(world, "ctx", null)
	if ctx is Object and SolverProbe.field(ctx, "live_mask", null) != null:
		log.struck = data.struck_hotspots(ep)
	var bases := data.line_bases(ep)
	if not bases.is_empty():
		var s := 0
		for k in bases:
			s += int(bases[k])
		log.bases_sum = s


## A Callable returning the log's events (static: no reference back to the executor).
static func _history_of(lg: SolverLog) -> Callable:
	return func() -> Array: return lg.events


## State to hand to a follow-up executor on the same world ({carry, hidden, rig_done}).
func carry_state() -> Dictionary:
	return {"carry": _carry.duplicate(), "hidden": _hidden, "rig_done": _rig_done.duplicate()}


## Run the route for at most `max_ticks` ticks. Returns the report (Metrics fields + ok, fail,
## warnings, steps). `opts.full_report = false` returns only {ok, fail, ticks, catches, lines}.
func run(max_ticks: int = DEFAULT_RUN_TICKS) -> Dictionary:
	log.start_tick = probe.tick()
	var status := RUNNING
	var ran := 0
	while true:
		if probe.ended():
			status = _on_ended()
			break
		if ran >= max_ticks:
			fail.append("step %s: run limit of %d ticks (%.1f s) reached" % [_label(), max_ticks, max_ticks / 60.0])
			status = FAILED
			break
		_cmds = []
		status = _update()
		if status != RUNNING:
			if not _cmds.is_empty():
				_step_world()   # apply the releases a failing step queued
			break
		_step_world()
		ran += 1
	ok = status == DONE and fail.is_empty()
	log.final_hash = probe.state_hash()
	log.end_reason = probe.end_reason()
	return _report()


func _step_world() -> void:
	var t_apply := probe.tick() + 1
	world.call("step", _cmds)
	for c in _cmds:
		log.cmds.append([t_apply, c])
	var evs: Variant = world.call("drain_events")
	if evs is Array:
		for ev in evs:
			if ev is Dictionary:
				log.events.append(ev)
				_on_event(ev)
	log.sample(probe, not _cmds.is_empty() or _rig_hold or _freeze_hold, _rig_hold)


func _report() -> Dictionary:
	var r: Dictionary
	if bool(opts.get("full_report", true)):
		r = Metrics.compute(log, SolverHooks.fallback_is_laugh if _fallback_hooks() else SolverHooks.is_laugh)
	else:
		r = {"ticks": log.size(), "catches": log.events_named("caught").size()}
	r["episode"] = log.episode
	r["route"] = log.route
	r["persona"] = persona.name
	r["ok"] = ok
	r["fail"] = Array(fail)
	r["warnings"] = Array(warnings)
	r["steps"] = step_log
	r["stars"] = probe.stars()
	r["applause_tenths"] = probe.applause_tenths()
	r["applause"] = probe.applause_tenths() / 10.0
	r["lines"] = Array(probe.lines_done())
	r["hash"] = log.final_hash
	return r


# --- per-tick decision ------------------------------------------------------------------------

func _update() -> int:
	var t := probe.tick()
	if _control_at >= 0:
		if t < _control_at:
			return RUNNING
		_control_at = -1
		_after_catch()
	elif probe.hush_state() == "CAUGHT":
		return RUNNING   # a run that starts inside a catch hold: wait for control
	if _dawdle_left > 0:
		_dawdle_left -= 1
		return RUNNING
	if not _interrupt.is_empty():
		var passive_done := false
		if _i < steps.size() and _started and PASSIVE_STEPS.has(SolverData.sv(steps[_i].get("do", ""))):
			passive_done = _tick_step(steps[_i]) == DONE
		if passive_done:
			_finish_step(true, "")
			_interrupt = {}
		elif _tick_evade():
			_interrupt = {}
			_restart_step()
		return RUNNING
	if _i >= steps.size():
		var src: Variant = opts.get("step_source", null)
		if src is Callable and (src as Callable).is_valid():
			var more: Variant = (src as Callable).call(self)
			if more is Array and not (more as Array).is_empty():
				steps.append_array(more)
		if _i >= steps.size():
			return DONE
	var step: Dictionary = steps[_i]
	if not _started:
		_begin_step(step)
	if int(_st.get("latency", 0)) > 0:
		_st["latency"] = int(_st["latency"]) - 1
		return RUNNING
	_step_ticks += 1
	var limit := int(round(float(step.get("max_s", DEFAULT_MAX_S)) * 60.0))
	var res := _tick_step(step)
	if res == RUNNING and _step_ticks > limit:
		if bool(step.get("soft", false)):
			# A planner window that never opened: act anyway (the beam weighs the risk).
			warnings.append("t=%.1f s: step %s window never opened in %.0f s — acting anyway" % [probe.tick() / 60.0, _label(), limit / 60.0])
			res = DONE
		else:
			res = FAILED
			_why = "timeout after %.1f s (%s)" % [limit / 60.0, _phase_desc(step)]
	if res == DONE:
		_finish_step(true, "")
	elif res == FAILED:
		if bool(step.get("wrong_tap", false)):
			warnings.append("wrong tap %s: %s" % [_label(), _why])
			_finish_step(true, "")
			return RUNNING
		if bool(opts.get("continue_on_fail", false)):
			warnings.append("step %s: %s" % [_label(), _why])
			_finish_step(false, _why)
			_release_holds()
			return RUNNING
		fail.append("step %s: %s" % [_label(), _why])
		_finish_step(false, _why)
		_release_holds()
		return FAILED
	return RUNNING


func _begin_step(step: Dictionary) -> void:
	_started = true
	_step_ticks = 0
	_why = ""
	_st = {"phase": 0, "since": log.events.size(), "t0": probe.tick(), "latency": persona.latency_ticks,
		"mob": 0}
	if step_log.size() < 400:
		step_log.append({"i": _i + 1, "label": SolutionDef.step_label(step, _i), "t0": probe.tick(), "t1": -1,
			"ok": false, "why": ""})


func _restart_step() -> void:
	var since: int = _st.get("since", log.events.size())
	var t0: int = _st.get("t0", probe.tick())
	_st = {"phase": 0, "since": since, "t0": t0, "latency": 0, "mob": 0}


func _finish_step(p_ok: bool, why: String) -> void:
	if not step_log.is_empty() and int(step_log[step_log.size() - 1]["i"]) == _i + 1:
		var e: Dictionary = step_log[step_log.size() - 1]
		e["t1"] = probe.tick()
		e["ok"] = p_ok
		e["why"] = why
	_i += 1
	_started = false


func _label() -> String:
	if _i < steps.size():
		return SolutionDef.step_label(steps[_i], _i)
	return "%d (end)" % (_i + 1)


func _on_ended() -> int:
	if _i >= steps.size():
		return DONE
	var rest_ok := true
	for k in range(_i, steps.size()):
		var kind := SolverData.sv(steps[k].get("do", ""))
		if not (kind in ["bow", "wait", "wait_event", "idle"]):
			rest_ok = false
			break
	if rest_ok:
		while _i < steps.size():
			if not _started:
				_begin_step(steps[_i])
			_finish_step(true, "night ended (%s)" % probe.end_reason())
		return DONE
	fail.append("step %s: the night ended (%s) before the route finished" % [_label(), probe.end_reason()])
	return FAILED


# --- events -----------------------------------------------------------------------------------

func _on_event(ev: Dictionary) -> void:
	match SolverData.sv(ev.get("e", "")):
		"pick":
			var it := SolverData.sv(ev.get("item", ""))
			_carry[it] = int(_carry.get(it, 0)) + data.item_count(it)
		"item_home":
			_carry.erase(SolverData.sv(ev.get("item", "")))
		"rig_step_done":
			var p := SolverData.sv(ev.get("prank", ""))
			var idx := int(_rig_done.get(p, 0))
			_rig_done[p] = idx + 1
			var need := data.step_needs(p, idx)
			if need != "" and _carry.has(need):
				_carry[need] = int(_carry[need]) - 1
				if int(_carry[need]) <= 0:
					_carry.erase(need)
		"hide":
			_hidden = SolverData.sv(ev.get("spot", ""))
			_last_arrive = _hidden
			if bool(ev.get("watched", false)):
				warnings.append("t=%.1f s: dived into %s while watched" % [probe.tick() / 60.0, _hidden])
		"pop_out":
			_last_arrive = SolverData.sv(ev.get("spot", _hidden))
			_hidden = ""
		"hush_arrive":
			_last_arrive = SolverData.sv(ev.get("hotspot", ""))
		"hush_go":
			_last_arrive = ""
		"caught":
			_hidden = ""
			_last_arrive = ""
			_carry.clear()
			_rig_hold = false
			_freeze_hold = false
			_control_at = int(ev.get("t", probe.tick())) + CAUGHT_HOLD_TICKS + 1
			_interrupt = {}
		"entry_warning":
			if persona.hide_on_warning and _interrupt.is_empty() and _control_at < 0:
				_maybe_evade(SolverData.sv(ev.get("room", "")))


## After a catch: restart the current step; re-pick an item a pending rig needs.
func _after_catch() -> void:
	if _i >= steps.size():
		return
	_recoveries += 1
	if _recoveries > max_recoveries:
		fail.append("step %s: gave up after %d catches" % [_label(), _recoveries])
		_i = steps.size()
		return
	warnings.append("t=%.1f s: caught during step %s — recovering" % [probe.tick() / 60.0, _label()])
	if bool(opts.get("rewind_on_catch", false)):
		# Planner runs: hide, sit out On Guard, then redo from the last window check.
		var from := _i
		# A rig whose item flew home: go back to (before) the pick of that item too.
		var cur: Dictionary = steps[_i]
		if SolverData.sv(cur.get("do", "")) == "rig":
			var pr := SolverData.sv(cur.get("prank", ""))
			var need := data.step_needs(pr, int(cur.get("step", _rig_done.get(pr, 0))))
			if need != "" and not _carrying(need):
				var found := false
				for k in range(_i - 1, -1, -1):
					if SolverData.sv(steps[k].get("do", "")) == "pick" and SolverData.sv(steps[k].get("item", "")) == need:
						from = k
						found = true
						break
				if not found:
					steps.insert(_i, {"do": "pick", "item": need, "from": data.item_source(need), "recovery": true})
		var back := from
		for k in range(from, -1, -1):
			if SolverData.sv(steps[k].get("do", "")) == "wait":
				back = k
				break
		var cover := data.nearest_hiding(probe.hush_room(), probe.hush_x(), PackedStringArray(), PackedStringArray(),
			SolverData.sv(opts.get("episode", "")))
		var extra: Array = []
		if cover != "":
			extra.append({"do": "hide", "spot": cover, "max_s": 20, "recovery": true})
		extra.append({"do": "idle", "s": float(opts.get("catch_cooldown_s", 11.0)), "recovery": true})
		for k in extra.size():
			steps.insert(back + k, extra[k])
		_i = back
		_started = false
		return
	if not persona.catch_restarts:
		return   # a scenario route wants the catch: carry on with the step
	var step: Dictionary = steps[_i]
	if SolverData.sv(step.get("do", "")) == "rig":
		var p := SolverData.sv(step.get("prank", ""))
		var idx := int(step.get("step", _rig_done.get(p, 0)))
		var need := data.step_needs(p, idx)
		if need != "" and not _carry.has(need):
			steps.insert(_i, {"do": "pick", "item": need, "from": data.item_source(need), "recovery": true})
			_started = false
			return
	_restart_step()


func _maybe_evade(room_id: String) -> void:
	if room_id != probe.hush_room() or _hidden != "" or probe.hush_hidden():
		return
	if _i >= steps.size():
		return
	var kind := SolverData.sv(steps[_i].get("do", ""))
	if kind in ["hide", "stand_in", "panto", "freeze", "bow"]:
		return
	_interrupt = {"phase": 0, "room": room_id, "spot": "", "calm": 0, "t0": probe.tick()}


## The slow persona's evasion: hide (or freeze) until Bellows has left the room for 1 s (cap
## 45 s), then pop out. Returns true when done.
func _tick_evade() -> bool:
	var ph := int(_interrupt["phase"])
	var room_id := SolverData.sv(_interrupt["room"])
	var t0 := int(_interrupt["t0"])
	match ph:
		0:
			_release_rig()
			var exclude := PackedStringArray()
			for id in data.hotspots_in(room_id, "hiding"):
				if bool(probe.hotspot_state(id).get("in_use_next", false)):
					exclude.append(id)
			var spot := data.nearest_hiding(room_id, probe.hush_x(), exclude, PackedStringArray([room_id]),
				SolverData.sv(opts.get("episode", "")))
			_interrupt["spot"] = spot
			if spot == "":
				_send({"c": "freeze", "on": true})
				_freeze_hold = true
				_interrupt["phase"] = 2
			else:
				_send({"c": "go", "hotspot": spot, "run": false})
				_interrupt["phase"] = 1
				_interrupt["since"] = log.events.size()
		1:
			if _hidden == SolverData.sv(_interrupt["spot"]) or _event_since(int(_interrupt["since"]), "hide", {}):
				_interrupt["phase"] = 2
			elif probe.tick() - t0 > 600:
				_interrupt["phase"] = 2
		2:
			var away := probe.bellows_room() != room_id
			_interrupt["calm"] = int(_interrupt["calm"]) + 1 if away else 0
			if int(_interrupt["calm"]) >= 60 or probe.tick() - t0 > 2700:
				if _freeze_hold:
					_send({"c": "freeze", "on": false})
					_freeze_hold = false
					return true
				if _hidden != "":
					_send({"c": "pop_out", "run": false})
					_interrupt["phase"] = 3
					_interrupt["since"] = log.events.size()
				else:
					return true
		3:
			if _hidden == "" or probe.tick() - t0 > 3000:
				return true
	return false


# --- helpers ----------------------------------------------------------------------------------

func _send(cmd: Dictionary) -> void:
	_cmds.append(cmd)


func _release_holds() -> void:
	_release_rig()
	if _freeze_hold:
		_send({"c": "freeze", "on": false})
		_freeze_hold = false


func _release_rig() -> void:
	if _rig_hold:
		_send({"c": "rig", "on": false})
		_rig_hold = false


func _cond(c: Variant) -> bool:
	return bool(cond_fn.call(world, c))


func _carrying(item: String) -> bool:
	return int(_carry.get(item, 0)) > 0 or probe.hush_carrying().has(item)


## First event named `e` matching `m` at index ≥ since (or null).
func _find_event(since: int, e: String, m: Dictionary) -> Variant:
	for k in range(maxi(0, since), log.events.size()):
		var ev: Dictionary = log.events[k]
		if SolverData.sv(ev.get("e", "")) != e:
			continue
		var hit := true
		for key in m:
			if str(ev.get(key, null)) != str(m[key]):
				hit = false
				break
		if hit:
			return ev
	return null


func _event_since(since: int, e: String, m: Dictionary) -> bool:
	return _find_event(since, e, m) != null


func _rejected_since(since: int, c: String) -> String:
	for i in range(maxi(0, since), log.events.size()):
		var ev: Dictionary = log.events[i]
		if SolverData.sv(ev.get("e", "")) != "cmd_rejected" or SolverData.sv(ev.get("c", "")) != c:
			continue
		var why := SolverData.sv(ev.get("why", "?"))
		if why == "here":
			continue   # a go / pin on the spot she is already hiding in (or diving into): nothing to do, not a failure
		return "command '%s' rejected: %s" % [c, why]
	return ""


## Hush has arrived at `id` and stands there (the world's `at_hotspot` when it has one, else the
## last `hush_arrive` / `hide` / `pop_out` event). Being at the same x is NOT enough: the sim only
## rigs / rummages after an arrival.
func _at_hotspot(id: String) -> bool:
	if probe.hush_state() in ["WALK", "RUN", "STAIRS", "DOOR"]:
		return false
	var at := probe.hush_at_hotspot()
	if at != "?":
		return at == id
	return _last_arrive == id


func _at_point(room_id: String, x: int) -> bool:
	return probe.hush_room() == room_id and absi(probe.hush_x() - x) <= 4 \
		and not (probe.hush_state() in ["WALK", "RUN", "STAIRS", "DOOR"])


## Should this movement run? Explicit `run` wins (tiptoe personas never run); otherwise run
## when Bellows is at least two rooms away from both Hush and the target (and not chasing).
func _run_flag(step: Dictionary, target_room: String) -> bool:
	if persona.tiptoe_only:
		return false
	if step.has("run"):
		return bool(step["run"])
	if not persona.run_when_safe or probe.bellows_chasing():
		return false
	var br := probe.bellows_room()
	var near := PackedStringArray([probe.hush_room(), target_room])
	near.append_array(data.neighbours(probe.hush_room()))
	near.append_array(data.neighbours(target_room))
	return not near.has(br)


## Make Hush free to move: pop out of a hiding spot (unless `keep_spot` is it), release FREEZE,
## release RIG, and (personas without the queue) wait until she isn't busy. True when ready.
func _ensure_mobile(keep_spot: String = "") -> bool:
	var mob := int(_st.get("mob", 0))
	if mob == 0 and probe.hush_state() == "DIVING":
		# Mid-dive (0.25 s) a go/move is not queued but pinned for after the pop-out (TECH §3.5):
		# let her land in the spot (its `hide` event sets `_hidden`), then pop out as usual.
		return false
	if mob == 0:
		_release_holds()
		if _hidden != "" and _hidden != keep_spot:
			_send({"c": "pop_out", "run": false})
			_st["mob"] = 1
			_st["mob_since"] = log.events.size()
			_st["mob_t"] = probe.tick()
			return false
		_st["mob"] = 2
	if int(_st["mob"]) == 1:
		if _hidden == "" or _event_since(int(_st["mob_since"]), "pop_out", {}):
			_hidden = ""
			_st["mob"] = 2
		elif probe.tick() - int(_st["mob_t"]) > 120:
			_why = "could not pop out of %s" % _hidden
			return false
		else:
			return false
	if not persona.use_queue and probe.hush_busy():
		return false
	return true


func _phase_desc(step: Dictionary) -> String:
	var kind := SolverData.sv(step.get("do", ""))
	var ph := int(_st.get("phase", 0))
	match kind:
		"go":
			return "walking to %s" % step.get("to", "")
		"move":
			return "walking to %s x=%s" % [step.get("room", ""), step.get("x", "")]
		"pick":
			var from := SolverData.sv(step.get("from", data.item_source(String(step.get("item", "")))))
			return ["walking to %s" % from, "waiting for the pick window of %s" % from,
				"waiting for the pick of %s" % step.get("item", "")][clampi(ph, 0, 2)]
		"rig":
			return "walking to the rig point %s" % _st.get("rp", "") if ph < 2 else "holding rig; waiting for rig_step_done"
		"hide":
			return "waiting for the hide event at %s" % step.get("spot", "")
		"wait":
			return "until %s never became true" % JSON.stringify(step.get("until", null))
		"wait_event":
			return "event %s %s never arrived" % [step.get("event", ""), JSON.stringify(step.get("match", {}))]
		"stand_in":
			return ["walking to the frame", "walking to the frame", "freezing in the frame",
				"frozen in the frame; waiting for mirror_round %d" % int(step.get("release_round", 3)),
				"released; waiting for the prank to fire"][clampi(ph, 0, 4)]
		"panto":
			return "panto rounds seen: %d" % int(_st.get("rounds", 0))
		"freeze":
			return "frozen; until %s never became true" % JSON.stringify(step.get("until", null))
		"bow":
			return "waiting for night_end"
	return "phase %d" % ph


# --- step kinds -------------------------------------------------------------------------------

func _tick_step(step: Dictionary) -> int:
	match SolverData.sv(step.get("do", "")):
		"go": return _t_go(step, SolverData.sv(step.get("to", "")))
		"move": return _t_move(step)
		"pick": return _t_pick(step)
		"rig": return _t_rig(step)
		"hide": return _t_hide(step)
		"pop_out": return _t_pop_out(step)
		"freeze": return _t_freeze(step)
		"squeak": return _t_squeak(step)
		"stand_in": return _t_stand_in(step)
		"panto": return _t_panto(step)
		"wait": return _t_wait(step)
		"wait_event": return _t_wait_event(step)
		"idle": return _t_idle(step)
		"bow": return _t_bow(step)
		"_raw": return _t_raw(step)
	_why = "unknown step kind '%s'" % step.get("do", "")
	return FAILED


## Walk to a hotspot (shared by go / pick / rig / pop_out). `key` names the phase slot in the
## step state so callers can embed the walk. Returns DONE on arrival.
func _t_go(step: Dictionary, to: String, key: String = "phase") -> int:
	var ph := int(_st.get(key, 0))
	if ph == 0:
		if not data.has_hotspot(to) and not data.house.is_empty():
			_why = "hotspot '%s' not in house.json" % to
			return FAILED
		if not _ensure_mobile():
			return FAILED if _why != "" else RUNNING
		if _at_hotspot(to):
			return DONE
		_send({"c": "go", "hotspot": to, "run": _run_flag(step, data.hotspot_room(to))})
		_st[key] = 1
		_st[key + "_since"] = log.events.size()
		_st[key + "_t"] = probe.tick()
		return RUNNING
	var since := int(_st.get(key + "_since", 0))
	if _event_since(since, "hush_arrive", {"hotspot": to}):
		return DONE
	var rej := _rejected_since(since, "go")
	if rej != "":
		_why = rej
		return FAILED
	if _at_hotspot(to) and probe.tick() - int(_st.get(key + "_t", 0)) > 2:
		return DONE
	# A silent no-op (same target as current) while standing at its use point: arrived.
	if probe.tick() - int(_st.get(key + "_t", 0)) > 10 and not _event_since(since, "hush_go", {}) \
			and probe.hush_room() == data.hotspot_room(to) and absi(probe.hush_x() - data.hotspot_x(to)) <= 4:
		return DONE
	return RUNNING


func _t_move(step: Dictionary) -> int:
	var room_id := SolverData.sv(step.get("room", ""))
	var r := data.room(room_id)
	var x := int(step.get("x", 0))
	if not r.is_empty():
		x = clampi(x, int(r.get("x0", x)), int(r.get("x1", x)))
	var ph := int(_st.get("phase", 0))
	if ph == 0:
		if not _ensure_mobile():
			return FAILED if _why != "" else RUNNING
		if _at_point(room_id, x):
			return DONE
		_send({"c": "move", "room": room_id, "x": x, "run": _run_flag(step, room_id)})
		_st["phase"] = 1
		_st["go_since"] = log.events.size()
		return RUNNING
	var rej := _rejected_since(int(_st["go_since"]), "move")
	if rej != "":
		_why = rej
		return FAILED
	if _at_point(room_id, x):
		return DONE
	return RUNNING


func _t_pick(step: Dictionary) -> int:
	var it := SolverData.sv(step.get("item", ""))
	var from := SolverData.sv(step.get("from", data.item_source(it)))
	var ph := int(_st.get("phase", 0))
	match ph:
		0:
			if _carrying(it):
				return DONE
			var r := _t_go(step, from, "walk")
			if r != DONE:
				return r
			_st["phase"] = 1
			_st["pw_since"] = int(_st.get("walk_since", log.events.size()))
			_st["pw_t"] = probe.tick()
			return RUNNING
		1:
			var pw: Variant = _find_event(int(_st["pw_since"]), "pick_window", {"container": from})
			var waited := probe.tick() - int(_st["pw_t"])
			if pw == null and waited < 60:
				return RUNNING
			var stock := PackedStringArray()
			if pw != null:
				stock = SolverData.as_ids((pw as Dictionary).get("items", ""))
			if pw != null and (pw as Dictionary).has("items") and not stock.has(it):
				if _event_since(int(_st["pw_since"]), "restock", {"item": it}):
					_st["phase"] = 0
					_st["walk"] = 0
					_last_arrive = ""
					return RUNNING
				if waited > 60 * 25:
					_why = "item '%s' not in %s (stock %s) and no restock" % [it, from, JSON.stringify(stock)]
					return FAILED
				return RUNNING
			_send({"c": "pick", "item": it})
			_st["phase"] = 2
			_st["pick_since"] = log.events.size()
			return RUNNING
		2:
			if _event_since(int(_st["pick_since"]), "pick", {"item": it}) or _carrying(it):
				return DONE
			var rej := _rejected_since(int(_st["pick_since"]), "pick")
			if rej != "":
				_why = rej
				return FAILED
			return RUNNING
	return RUNNING


func _t_rig(step: Dictionary) -> int:
	var p := SolverData.sv(step.get("prank", ""))
	var ph := int(_st.get("phase", 0))
	match ph:
		0:
			if not data.pranks.is_empty() and not data.pranks.has(p):
				_why = "prank '%s' not in pranks.json" % p
				return FAILED
			var ps := probe.prank_state(p)
			if step.has("step"):
				if int(_rig_done.get(p, 0)) > int(step["step"]):
					return DONE
			elif ps in ["RIGGED", "FIRED", "LANDED"]:
				return DONE
			if ps == "LOCKED":
				_why = "prank %s is LOCKED (sealed, or not in this Night's Script)" % p
				return FAILED
			var idx := int(step.get("step", _rig_done.get(p, 0)))
			var need := data.step_needs(p, idx)
			if need != "" and not _carrying(need):
				_why = "rig %s step %d needs '%s', which Hush isn't carrying" % [p, idx, need]
				return FAILED
			_st["rp"] = data.rig_point(p, idx)
			_st["phase"] = 1
			return _t_rig(step)
		1:
			var r := _t_go(step, SolverData.sv(_st["rp"]), "walk")
			if r != DONE:
				return r
			_send({"c": "rig", "on": true})
			_rig_hold = true
			_st["phase"] = 2
			_st["rig_since"] = log.events.size()
			_st["rig_seen"] = int(_rig_done.get(p, 0))
			return RUNNING
		2:
			if int(_rig_done.get(p, 0)) > int(_st["rig_seen"]):
				_release_rig()
				return DONE
			var rej := _rejected_since(int(_st["rig_since"]), "rig")
			if rej != "":
				_release_rig()
				_why = rej
				return FAILED
			return RUNNING
	return RUNNING


func _t_hide(step: Dictionary) -> int:
	var spot := SolverData.sv(step.get("spot", ""))
	if _hidden == spot:
		return DONE
	var ph := int(_st.get("phase", 0))
	if ph == 0:
		if not data.has_hotspot(spot) and not data.house.is_empty():
			_why = "hiding spot '%s' not in house.json" % spot
			return FAILED
		if not _ensure_mobile():
			return FAILED if _why != "" else RUNNING
		# Always send the go: arriving is what triggers the dive.
		_send({"c": "go", "hotspot": spot, "run": _run_flag(step, data.hotspot_room(spot))})
		_st["phase"] = 1
		_st["hide_since"] = log.events.size()
		return RUNNING
	var since := int(_st["hide_since"])
	if _event_since(since, "hide", {"spot": spot}):
		_hidden = spot
		return DONE
	var rej := _rejected_since(since, "go")
	if rej != "":
		_why = rej
		return FAILED
	var arr: Variant = _find_event(since, "hush_arrive", {"hotspot": spot})
	if arr != null and probe.tick() - int((arr as Dictionary).get("t", probe.tick())) > 60:
		_why = "arrived at %s but never dived in" % spot
		return FAILED
	return RUNNING


func _t_pop_out(step: Dictionary) -> int:
	var to := SolverData.sv(step.get("to", ""))
	var ph := int(_st.get("phase", 0))
	match ph:
		0:
			_release_holds()
			if _hidden == "" and not probe.hush_hidden():
				if to == "":
					return DONE
				_st["phase"] = 3
				return _t_pop_out(step)
			var run := _run_flag(step, data.hotspot_room(to) if to != "" else probe.hush_room())
			if to != "" and persona.use_pins:
				_send({"c": "pin", "hotspot": to})
			_send({"c": "pop_out", "run": run})
			_st["phase"] = 1
			_st["po_since"] = log.events.size()
			_st["po_t"] = probe.tick()
			return RUNNING
		1:
			if _event_since(int(_st["po_since"]), "pop_out", {}) or (_hidden == "" and not probe.hush_hidden()):
				_hidden = ""
				if to == "":
					return DONE
				_st["phase"] = 2 if persona.use_pins else 3
				return RUNNING
			var rej := _rejected_since(int(_st["po_since"]), "pop_out")
			if rej != "":
				_why = rej
				return FAILED
			return RUNNING
		2:
			# Popping out to a pin: she walks there by herself.
			if _event_since(int(_st["po_since"]), "hush_arrive", {"hotspot": to}) or _at_hotspot(to):
				return DONE
			if probe.tick() - int(_st["po_t"]) > 30 and not (probe.hush_state() in ["WALK", "RUN", "STAIRS", "DOOR", "POPPING"]):
				_st["phase"] = 3   # the pin was not honoured: walk there
			return RUNNING
		3:
			return _t_go(step, to, "walk")
	return RUNNING


func _t_freeze(step: Dictionary) -> int:
	var ph := int(_st.get("phase", 0))
	if ph == 0:
		if not _ensure_mobile():
			return FAILED if _why != "" else RUNNING
		_send({"c": "freeze", "on": true})
		_freeze_hold = true
		_st["phase"] = 1
		_st["fz_t"] = probe.tick()
		return RUNNING
	var done := false
	if step.has("until"):
		done = _cond(step["until"])
	else:
		done = probe.tick() - int(_st["fz_t"]) >= int(round(float(step.get("s", 2.0)) * 60.0))
	if done:
		_send({"c": "freeze", "on": false})
		_freeze_hold = false
		return DONE
	return RUNNING


func _t_squeak(step: Dictionary) -> int:
	var n := int(step.get("n", 1))
	var gap := int(round(float(step.get("gap_s", 0.6)) * 60.0))
	var done_n := int(_st.get("sq_n", 0))
	var next_t := int(_st.get("sq_next", 0))
	if done_n >= n:
		return DONE
	if probe.tick() < next_t:
		return RUNNING
	_send({"c": "squeak"})
	_st["sq_n"] = done_n + 1
	_st["sq_next"] = probe.tick() + maxi(1, gap)
	return RUNNING if done_n + 1 < n or gap > 0 else DONE


func _t_stand_in(step: Dictionary) -> int:
	var p := SolverData.sv(step.get("prank", ""))
	var rr := int(step.get("release_round", 3))
	var fp := data.frame_point(p)
	var ph := int(_st.get("phase", 0))
	match ph:
		0:
			if not _ensure_mobile():
				return FAILED if _why != "" else RUNNING
			if _at_point(SolverData.sv(fp["room"]), int(fp["x"])):
				_st["phase"] = 2
				return RUNNING
			_send({"c": "move", "room": SolverData.sv(fp["room"]), "x": int(fp["x"]), "run": _run_flag(step, SolverData.sv(fp["room"]))})
			_st["phase"] = 1
			_st["go_since"] = log.events.size()
			return RUNNING
		1:
			var rej := _rejected_since(int(_st["go_since"]), "move")
			if rej != "":
				_why = rej
				return FAILED
			if _at_point(SolverData.sv(fp["room"]), int(fp["x"])):
				_st["phase"] = 2
			return RUNNING
		2:
			_send({"c": "freeze", "on": true})
			_freeze_hold = true
			_st["phase"] = 3
			_st["mr_since"] = log.events.size()
			return RUNNING
		3:
			if _event_since(int(_st["mr_since"]), "mirror_round", {"round": rr}):
				_send({"c": "freeze", "on": false})
				_freeze_hold = false
				_st["phase"] = 4
				_st["rel_t"] = probe.tick()
				_st["rel_since"] = log.events.size()
			elif _event_since(int(_st["mr_since"]), "face_to_face", {}) or _event_since(int(_st["mr_since"]), "caught", {}):
				_why = "caught in the frame before round %d" % rr
				return FAILED
			return RUNNING
		4:
			var since := int(_st["mr_since"])
			if _event_since(since, "prank_fire", {"prank": p}) or _event_since(since, "reaction_start", {"prank": p}):
				return DONE
			if probe.tick() - int(_st["rel_t"]) > 120:
				_why = "released FREEZE in mirror round %d but %s did not fire" % [rr, p]
				return FAILED
			return RUNNING
	return RUNNING


func _t_panto(step: Dictionary) -> int:
	var want := int(step.get("rounds", 3))
	var since := int(_st.get("since", 0))
	if _event_since(since, "panto_bit", {}):
		_release_holds()
		return DONE
	var rounds := 0
	for k in range(since, log.events.size()):
		if SolverData.sv(log.events[k].get("e", "")) == "panto_round":
			rounds = maxi(rounds, int(log.events[k].get("round", 0)))
	_st["rounds"] = rounds
	if _event_since(since, "spotted", {}):
		_release_holds()
		_why = "spotted during the panto (round %d)" % rounds
		return FAILED
	var ph := int(_st.get("phase", 0))
	var away := probe.bellows_facing_away_from_hush()
	match ph:
		0:
			if not _ensure_mobile():
				return FAILED if _why != "" else RUNNING
			_st["phase"] = 1
			_st["away_n"] = 0
			return RUNNING
		1:
			# Ready to squeak: only behind his back, after he has faced away for 20 ticks.
			if rounds >= want and away and int(_st.get("away_n", 0)) >= 20:
				return DONE
			_st["away_n"] = int(_st.get("away_n", 0)) + 1 if away else 0
			if away and int(_st["away_n"]) >= 20:
				_send({"c": "squeak"})
				_st["phase"] = 2
				_st["sq_t"] = probe.tick()
			return RUNNING
		2:
			# Freeze right after the squeak (the arm is moving for 18 ticks).
			if probe.tick() - int(_st["sq_t"]) >= 1:
				_send({"c": "freeze", "on": true})
				_freeze_hold = true
				_st["phase"] = 3
				_st["turned"] = false
				_st["away_n"] = 0
			return RUNNING
		3:
			# Hold through his look: release once he has turned and faced away again for 20 ticks,
			# or after 4 s when he never turned.
			if not away:
				_st["turned"] = true
				_st["away_n"] = 0
			else:
				_st["away_n"] = int(_st.get("away_n", 0)) + 1
			var held := probe.tick() - int(_st["sq_t"])
			if (bool(_st["turned"]) and int(_st["away_n"]) >= 20) or (not bool(_st["turned"]) and held > 240):
				_send({"c": "freeze", "on": false})
				_freeze_hold = false
				_st["phase"] = 1
				_st["away_n"] = 0
			return RUNNING
	return RUNNING


func _t_wait(step: Dictionary) -> int:
	return DONE if _cond(step.get("until", null)) else RUNNING


func _t_wait_event(step: Dictionary) -> int:
	var e := SolverData.sv(step.get("event", ""))
	var m: Variant = step.get("match", {})
	var scope := SolverData.sv(step.get("since", "run" if RUN_SCOPE_EVENTS.has(e) else "step"))
	var since := 0 if scope == "run" else int(_st.get("since", 0))
	return DONE if _event_since(since, e, m if m is Dictionary else {}) else RUNNING


func _t_idle(step: Dictionary) -> int:
	var n := int(round(float(step.get("s", 1.0)) * 60.0))
	return DONE if probe.tick() - int(_st.get("t0", 0)) >= n else RUNNING


## Internal (bots): send raw commands this tick, tracking holds.
func _t_raw(step: Dictionary) -> int:
	for c in step.get("cmds", []):
		if not (c is Dictionary):
			continue
		var cmd: Dictionary = c
		match SolverData.sv(cmd.get("c", "")):
			"rig":
				_rig_hold = bool(cmd.get("on", false))
			"freeze":
				_freeze_hold = bool(cmd.get("on", false))
			"go", "move":
				_rig_hold = false
		_send(cmd)
	return DONE


func _t_bow(_step: Dictionary) -> int:
	var ph := int(_st.get("phase", 0))
	if ph == 0:
		_release_holds()
		_send({"c": "bow"})
		_st["phase"] = 1
		_st["bow_since"] = log.events.size()
		return RUNNING
	if probe.ended() or _event_since(int(_st["bow_since"]), "night_end", {}):
		return DONE
	var rej := _rejected_since(int(_st["bow_since"]), "bow")
	if rej != "":
		_why = rej + " (is ★ earned? lines done: %s)" % ", ".join(probe.lines_done())
		return FAILED
	return RUNNING
