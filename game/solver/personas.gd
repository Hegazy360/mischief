## Persona — how a route is played (TECH §8.3). Personas transform a route and set executor
## behaviour; they never change the sim.
## - `ideal`: zero decision latency; runs when safe (a `go`/`move` without an explicit `run` runs
##   when Bellows is at least two rooms away from both ends); may use pins and the queue.
## - `required`: `ideal` timing, but only the steps serving required Script lines are kept.
## - `slow` (a first-timer): 0.6 s latency before each step, a 3 s dawdle at the start, one wrong
##   glowing tap per Night (a `go` to the nearest non-useful hotspot), tiptoes only, hides as soon as
##   an entry warning into her room appears, never uses pins or the queue.
## - `scenario`: `ideal` timing for authored set pieces (caught → Lecture → doorstep, face to face, Meltdown,
##   a chase + door slam): walks unless a step says run, and a catch does not restart the step — the
##   route wants it. Not gated on stars, applause or D1; checked with `events_min` / `events_max`.
## Every persona also models ⏩ for the dead-air gate (ruling L2): it holds ⏩ while hidden, loses it on every
## `SimFf.drops` event and re-presses `ff_repress_s` later (ideal 0.5, required 1.0, slow 2.0; never during a
## reaction); the slow first-timer uses ⏩ only once the `ghost_ff` cue has taught it (Metrics).
## Fuzz bots (`random`, `reckless`, `hider`, `bait`) live in `Fuzz`.
class_name Persona
extends RefCounted

## ⏩ re-press delay per persona (seconds; ruling L2).
const FF_REPRESS_S := {"ideal": 0.5, "required": 1.0, "slow": 2.0, "scenario": 0.5}

var name: String = "ideal"
var latency_ticks: int = 0        ## idle ticks before each step
var dawdle_ticks: int = 0         ## idle ticks at the start
var wrong_tap: bool = false       ## one wrong glowing tap per Night
var tiptoe_only: bool = false     ## never runs
var hide_on_warning: bool = false ## hides at the first entry warning into her room
var use_pins: bool = true         ## pop_out {to} via a pin (else pop out, then walk)
var use_queue: bool = true        ## may issue go/move while busy (else waits until idle)
var run_when_safe: bool = true    ## unspecified `run` → run when Bellows is far
var required_only: bool = false   ## drop steps of optional lines
var ff_repress_ticks: int = 30    ## ⏩ re-press delay (ticks)
var ff_needs_cue: bool = false    ## uses ⏩ only after the `ghost_ff` cue (unless taught on an earlier Night)
var catch_restarts: bool = true   ## a catch restarts the current step (not for `scenario`)


## A persona by name (`ideal`, `required`, `slow`); unknown names give `ideal`.
static func make(p_name: String) -> Persona:
	var p := Persona.new()
	p.name = p_name
	match p_name:
		"required":
			p.required_only = true
		"scenario":
			p.run_when_safe = false
			p.catch_restarts = false
		"slow":
			p.latency_ticks = 36
			p.dawdle_ticks = 180
			p.wrong_tap = true
			p.tiptoe_only = true
			p.hide_on_warning = true
			p.use_pins = false
			p.use_queue = false
			p.run_when_safe = false
			p.ff_needs_cue = true
		_:
			p.name = "ideal" if p_name == "" else p_name
	p.ff_repress_ticks = int(round(float(FF_REPRESS_S.get(p.name, 0.5)) * 60.0))
	return p


## Transform route steps for this persona (pure; returns a new array):
## - `required_only` (or `force_required`): drop rig/pick/stand_in/wait_event/wait steps that only
##   serve pranks of optional lines of `episode_id`;
## - `tiptoe_only`: every `run` becomes false;
## - `wrong_tap`: insert one `go` to the nearest non-useful glowing hotspot (a rig point, container
##   or hiding spot the route never uses, preferring Hush's start room) before the first action step.
func transform(steps: Array, data: SolverData, episode_id: String, force_required: bool = false) -> Array:
	var out: Array = steps.duplicate(true)
	if (required_only or force_required) and data != null:
		out = Persona.filter_required(out, data, episode_id)
	if tiptoe_only:
		for s in out:
			if s is Dictionary and (s as Dictionary).has("run"):
				s["run"] = false
	if wrong_tap and data != null:
		var tap := Persona.wrong_tap_target(out, data, episode_id)
		if tap != "":
			var at := 0
			for i in out.size():
				var k := SolverData.sv((out[i] as Dictionary).get("do", ""))
				if k in ["go", "move", "pick", "rig", "hide", "stand_in"]:
					at = i
					break
			out.insert(at, {"do": "go", "to": tap, "run": false, "wrong_tap": true, "max_s": 30})
	return out


## Keep only the steps that serve required lines (plus neutral steps: go, move, hide, pop_out,
## freeze, squeak, idle, bow, and waits that don't name an optional prank).
static func filter_required(steps: Array, data: SolverData, episode_id: String) -> Array:
	var req := data.required_pranks(episode_id)
	var all_p := data.episode_pranks(episode_id)
	var dropped := PackedStringArray()
	for p in all_p:
		if not req.has(p):
			dropped.append(p)
	# Items needed by kept pranks.
	var need_items := PackedStringArray()
	for p in req:
		for i in data.prank_steps(p).size():
			var it := data.step_needs(p, i)
			if it != "" and not need_items.has(it):
				need_items.append(it)
	var out: Array = []
	for s in steps:
		if not (s is Dictionary):
			continue
		var d: Dictionary = s
		match SolverData.sv(d.get("do", "")):
			"rig", "stand_in":
				if dropped.has(SolverData.sv(d.get("prank", ""))):
					continue
			"pick":
				if not need_items.has(SolverData.sv(d.get("item", ""))):
					continue
			"wait_event":
				var m: Variant = d.get("match", {})
				if m is Dictionary and dropped.has(SolverData.sv((m as Dictionary).get("prank", ""))):
					continue
			"wait", "freeze":
				if Persona._cond_names(d.get("until", null), dropped):
					continue
		out.append(d)
	return out


## True when a condition tree names one of `pranks` (prank_state / event_seen prank).
static func _cond_names(cond: Variant, pranks: PackedStringArray) -> bool:
	if cond is Array:
		for c in cond:
			if Persona._cond_names(c, pranks):
				return true
		return false
	if not (cond is Dictionary):
		return false
	for k in cond:
		var v: Variant = cond[k]
		match String(k):
			"prank_state":
				if v is Array and v.size() > 0 and pranks.has(SolverData.sv(v[0])):
					return true
			"event_seen":
				if v is Dictionary and pranks.has(SolverData.sv((v as Dictionary).get("prank", ""))):
					return true
			"and", "or", "not":
				if Persona._cond_names(v, pranks):
					return true
	return false


## The nearest glowing hotspot the route never uses (rig points first, then containers, then hiding spots),
## measured from Hush's start point. For a real episode "glowing" means live tonight and in Hush's start room
## (REDESIGN_3D §4.4 N1: only her room glows) — "" when the decluttered room has no such distractor.
static func wrong_tap_target(steps: Array, data: SolverData, episode_id: String) -> String:
	var used := PackedStringArray()
	for s in steps:
		if not (s is Dictionary):
			continue
		for k in ["to", "from", "spot"]:
			if (s as Dictionary).has(k):
				used.append(SolverData.sv(s[k]))
		if (s as Dictionary).has("prank"):
			var p := SolverData.sv(s["prank"])
			for i in data.prank_steps(p).size():
				used.append(data.rig_point(p, i))
		if SolverData.sv((s as Dictionary).get("do", "")) == "pick" and (s as Dictionary).has("item"):
			used.append(data.item_source(SolverData.sv(s["item"])))
	var ep := data.episode(episode_id)
	var rooms: Array = ep.get("rooms", [])
	var start: Dictionary = (ep.get("hush", {}) as Dictionary).get("start", {}) if ep.get("hush", {}) is Dictionary else {}
	var sroom := SolverData.sv(start.get("room", rooms[0] if not rooms.is_empty() else ""))
	var sx := int(start.get("x", 0))
	var best := ""
	var best_score := 1 << 30
	var kind_rank := {"rig_point": 0, "container": 1, "hiding": 2}
	for id in data.hotspot_ids():
		var h := data.hotspot(id)
		var kind := SolverData.sv(h.get("kind", ""))
		if not kind_rank.has(kind) or used.has(id):
			continue
		var r := SolverData.sv(h.get("room", ""))
		if not rooms.is_empty() and not rooms.has(r):
			continue
		if kind == "hiding" and data.in_use_activity(id) != "":
			continue
		if data.episodes.has(episode_id) and (not data.is_live(episode_id, id) or r != sroom):
			continue   # only live hotspots in Hush's room glow (REDESIGN_3D §4.4 N1, §6.2 C1)
		var score := data.walk_px(sroom, sx, r, int(h.get("use_x", 0))) + int(kind_rank[kind]) * 200
		if score < best_score:
			best_score = score
			best = id
	return best
