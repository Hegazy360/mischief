## SolutionDef — parses and validates `data/solutions/<episode>.json` (TECH §8.2).
##
##   {"version": 1, "episode": "n01_throat_tea", "routes": {
##     "ideal": {"persona": "ideal", "steps": [{"do": "pick", "item": "squeaker", "from": "..."}, ...],
##               "expect": {"stars": [true, true, true], "applause": [100, 140], ...}},
##     "required": {...}, "slow": {...}}}
##
## Route resolution (`resolve(name)`): a route whose `steps` is empty borrows steps — `slow` from
## `required` (else `ideal`), anything else from `ideal` — and `required`-named routes derived that
## way are filtered to required lines (`filter_required`). The persona is the route's `persona`
## (default: the route name when it names a persona, else `ideal`).
class_name SolutionDef
extends RefCounted

const STEP_KINDS: PackedStringArray = ["go", "move", "pick", "rig", "hide", "pop_out", "freeze", "squeak",
	"stand_in", "panto", "wait", "wait_event", "idle", "bow"]
## Expect keys: Metrics.EXPECT_KEYS, each also as `warn_<key>` (evaluated and reported, never failing).
const EXPECT_KEYS: PackedStringArray = Metrics.EXPECT_KEYS
## `scenario`: authored set pieces (caught → Lecture → doorstep, face to face, Meltdown, chase + door slam),
## not gated on stars / applause / D1; checked with `events_min` / `events_max`.
const PERSONAS: PackedStringArray = ["ideal", "required", "slow", "scenario"]
const ROUTE_KEYS: PackedStringArray = ["persona", "steps", "expect", "note", "description"]
## Optional keys any step may carry: max_s (timeout), run, soft (timeout = done), since (wait_event
## scope), note (free text).
const COND_KEYS: PackedStringArray = ["bellows_activity", "bellows_activity_in", "bellows_state",
	"bellows_in_room", "bellows_not_in_room", "bellows_eta_to_room_gt_s", "bellows_activity_remaining_le_s",
	"bellows_facing_away_from_hush", "hush_visible", "hush_hidden", "spot_meter_pct_ge", "prank_state",
	"temper_tier_ge", "link_ge", "line_done", "all_required_done", "tick_ge_s", "first_squeak", "first_rig",
	"event_seen", "and", "or", "not"]
## Required fields per step kind.
const STEP_FIELDS := {
	"go": ["to"], "move": ["room", "x"], "pick": ["item"], "rig": ["prank"], "hide": ["spot"],
	"pop_out": [], "freeze": [], "squeak": [], "stand_in": ["prank"], "panto": [], "wait": ["until"],
	"wait_event": ["event"], "idle": ["s"], "bow": []}

var episode: String = ""
var routes: Dictionary = {}          ## name -> {persona, steps, expect}
var errors: PackedStringArray = []   ## parse / shape errors (validate() adds reference errors)
var source: String = ""


## Load a solution file ("" episode + an error when missing or invalid).
static func load_file(path: String) -> SolutionDef:
	var errs: Array = []
	var v: Variant = SolverData.read_json(path, errs)
	var s: SolutionDef
	if v is Dictionary:
		s = SolutionDef.from_dict(v, path)
	else:
		s = SolutionDef.new()
		s.source = path
		if errs.is_empty():
			errs.append("%s: missing" % path)
	var all := s.errors.duplicate()
	for e in errs:
		all.append(String(e))
	s.errors = all
	return s


## Build from a parsed dictionary.
static func from_dict(d: Dictionary, p_source: String = "") -> SolutionDef:
	var s := SolutionDef.new()
	s.source = p_source
	var errs := PackedStringArray()
	s.episode = SolverData.sv(d.get("episode", ""))
	if s.episode == "":
		errs.append("%s: no 'episode'" % s._src())
	var r: Variant = d.get("routes", {})
	if not (r is Dictionary):
		errs.append("%s: 'routes' must be an object" % s._src())
		r = {}
	for name in r:
		var rd: Variant = r[name]
		if not (rd is Dictionary):
			errs.append("%s: route '%s' must be an object" % [s._src(), name])
			continue
		var route: Dictionary = (rd as Dictionary).duplicate(true)
		if not (route.get("steps", []) is Array):
			errs.append("%s: route '%s'.steps must be an array" % [s._src(), name])
			route["steps"] = []
		if not route.has("steps"):
			route["steps"] = []
		if not (route.get("expect", {}) is Dictionary):
			errs.append("%s: route '%s'.expect must be an object" % [s._src(), name])
			route["expect"] = {}
		if not route.has("expect"):
			route["expect"] = {}
		s.routes[String(name)] = route
	s.errors = errs
	return s


func _src() -> String:
	return source if source != "" else "solution"


## Route names, sorted.
func route_names() -> PackedStringArray:
	var out := PackedStringArray()
	for k in routes:
		out.append(String(k))
	out.sort()
	return out


func has_route(name: String) -> bool:
	return routes.has(name)


## The route as authored ({} if missing).
func route(name: String) -> Dictionary:
	return routes.get(name, {})


## The route ready to run: {name, persona, steps, expect, derived_from, filter_required}.
func resolve(name: String) -> Dictionary:
	var r := route(name)
	if r.is_empty():
		return {}
	var persona := SolverData.sv(r.get("persona", name if PERSONAS.has(name) else "ideal"))
	var steps: Array = r.get("steps", [])
	var derived := ""
	var filt := false
	if steps.is_empty():
		var order: Array = ["required", "ideal"] if name == "slow" else ["ideal"]
		for src in order:
			if src != name and has_route(src) and not (route(src).get("steps", []) as Array).is_empty():
				steps = route(src)["steps"]
				derived = src
				break
		if derived == "" and name == "slow" and has_route("required"):
			var req := resolve("required")
			steps = req.get("steps", [])
			derived = "required"
			filt = bool(req.get("filter_required", false))
		if derived == "ideal" and (name == "required" or name == "slow"):
			filt = true
	return {"name": name, "persona": persona, "steps": steps.duplicate(true), "expect": r.get("expect", {}),
		"derived_from": derived, "filter_required": filt or persona == "required"}


## Shape + reference checks (pass `data` to resolve hotspots / items / pranks / episode).
func validate(data: SolverData = null) -> PackedStringArray:
	var out := errors.duplicate()
	if data != null and episode != "" and data.episode(episode).is_empty() and not data.episodes.is_empty():
		out.append("%s: episode '%s' not in data/episodes" % [_src(), episode])
	for name in route_names():
		var r: Dictionary = routes[name]
		for k in r:
			if not ROUTE_KEYS.has(String(k)):
				out.append("%s: route '%s' has unknown key '%s'" % [_src(), name, k])
		var persona := SolverData.sv(r.get("persona", name if PERSONAS.has(name) else "ideal"))
		if not PERSONAS.has(persona):
			out.append("%s: route '%s' persona '%s' not in %s" % [_src(), name, persona, PERSONAS])
		var steps: Array = r.get("steps", [])
		for i in steps.size():
			for e in validate_step(steps[i], data):
				out.append("%s: %s step %d: %s" % [_src(), name, i + 1, e])
		var ex: Dictionary = r.get("expect", {})
		for k in ex:
			if not Metrics.known_key(String(k)):
				out.append("%s: route '%s' expect has unknown key '%s'" % [_src(), name, k])
		for e in _validate_expect(ex):
			out.append("%s: route '%s' expect: %s" % [_src(), name, e])
	return out


## Errors of one step ([] when valid).
static func validate_step(step: Variant, data: SolverData = null) -> PackedStringArray:
	var out := PackedStringArray()
	if not (step is Dictionary):
		out.append("must be an object")
		return out
	var s: Dictionary = step
	var kind := SolverData.sv(s.get("do", ""))
	if not STEP_KINDS.has(kind):
		out.append("unknown 'do' '%s' (want one of %s)" % [kind, ", ".join(STEP_KINDS)])
		return out
	for f in STEP_FIELDS[kind]:
		if not s.has(f):
			out.append("%s needs '%s'" % [kind, f])
	if s.has("max_s") and not (s["max_s"] is float or s["max_s"] is int):
		out.append("max_s must be a number")
	for ck in ["until"]:
		if s.has(ck):
			for e in validate_condition(s[ck]):
				out.append("%s.%s: %s" % [kind, ck, e])
	if data == null:
		return out
	var has_house := not data.house.is_empty()
	match kind:
		"go":
			if has_house and not data.has_hotspot(SolverData.sv(s.get("to", ""))):
				out.append("go: hotspot '%s' not in house.json" % s.get("to", ""))
		"move":
			if has_house and not data.has_room(SolverData.sv(s.get("room", ""))):
				out.append("move: room '%s' not in house.json" % s.get("room", ""))
		"pick":
			var it := SolverData.sv(s.get("item", ""))
			if not data.items.is_empty() and not data.items.has(it):
				out.append("pick: item '%s' not in items.json" % it)
			if s.has("from"):
				var from := SolverData.sv(s["from"])
				if has_house and not data.has_hotspot(from):
					out.append("pick: container '%s' not in house.json" % from)
				elif data.items.has(it) and data.item_source(it) != "" and data.item_source(it) != from:
					out.append("pick: '%s' comes from '%s', not '%s'" % [it, data.item_source(it), from])
		"rig", "stand_in":
			var p := SolverData.sv(s.get("prank", ""))
			if not data.pranks.is_empty() and not data.pranks.has(p):
				out.append("%s: prank '%s' not in pranks.json" % [kind, p])
			if kind == "rig" and s.has("step") and data.pranks.has(p):
				var n := data.prank_steps(p).size()
				if int(s["step"]) < 0 or int(s["step"]) >= n:
					out.append("rig: %s has %d step(s), step %s out of range (0-based)" % [p, n, s["step"]])
		"hide":
			var sp := SolverData.sv(s.get("spot", ""))
			if has_house and not data.has_hotspot(sp):
				out.append("hide: spot '%s' not in house.json" % sp)
			elif has_house and data.hotspot_kind(sp) != "hiding":
				out.append("hide: '%s' is a %s, not a hiding spot" % [sp, data.hotspot_kind(sp)])
		"pop_out":
			if s.has("to") and has_house and not data.has_hotspot(SolverData.sv(s["to"])):
				out.append("pop_out: hotspot '%s' not in house.json" % s["to"])
	return out


## Errors of a condition tree (unknown keys, bad shapes).
static func validate_condition(cond: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if cond == null or cond is bool:
		return out
	if cond is Array:
		for c in cond:
			out.append_array(validate_condition(c))
		return out
	if not (cond is Dictionary):
		out.append("condition must be an object")
		return out
	for k in cond:
		var key := String(k)
		if not COND_KEYS.has(key):
			out.append("unknown condition '%s'" % key)
			continue
		match key:
			"and", "or":
				out.append_array(validate_condition(cond[k]))
			"not":
				out.append_array(validate_condition(cond[k]))
			"prank_state", "bellows_eta_to_room_gt_s":
				if not (cond[k] is Array) or (cond[k] as Array).size() != 2:
					out.append("'%s' takes [a, b]" % key)
	return out


static func _validate_expect(ex: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if ex.has("stars") and (not (ex["stars"] is Array) or (ex["stars"] as Array).size() != 3):
		out.append("stars must be [bool|null, bool|null, bool|null]")
	for k in ["applause", "duration_s"]:
		if ex.has(k) and (not (ex[k] is Array) or (ex[k] as Array).size() != 2):
			out.append("%s must be [min, max]" % k)
	if ex.has("laughs_by_s"):
		if not (ex["laughs_by_s"] is Array):
			out.append("laughs_by_s must be [[s, n], ...]")
		else:
			for p in ex["laughs_by_s"]:
				if not (p is Array) or (p as Array).size() != 2:
					out.append("laughs_by_s entries must be [s, n]")
	if ex.has("lines") and not (ex["lines"] is Array):
		out.append("lines must be an array of line ids")
	for k in ["events_min", "events_max", "warn_events_min", "warn_events_max"]:
		if ex.has(k):
			if not (ex[k] is Dictionary):
				out.append("%s must be {event: n}" % k)
			else:
				for e in ex[k]:
					if not (ex[k][e] is int or ex[k][e] is float):
						out.append("%s.%s must be a number" % [k, e])
	return out


## A short human label of a step for failure messages: `3 (rig kettle_drum)`.
static func step_label(step: Dictionary, index: int) -> String:
	var kind := SolverData.sv(step.get("do", "?"))
	var arg := ""
	for k in ["prank", "to", "item", "spot", "event", "room"]:
		if step.has(k):
			arg = " %s" % str(step[k])
			break
	if kind == "wait" and step.has("until"):
		arg = " %s" % JSON.stringify(step["until"])
	return "%d (%s%s)" % [index + 1, kind, arg]


## Serialise (for `_auto/` output).
func to_dict() -> Dictionary:
	return {"version": 1, "episode": episode, "routes": routes.duplicate(true)}
