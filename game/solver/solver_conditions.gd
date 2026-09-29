## SolverConditions — the solver's FALLBACK evaluator of the TECH §8.2 condition language, used
## only when the sim's own `Conditions` (res://sim/systems/conditions.gd) is absent (unit tests on
## the MockWorld, or a partial sim). It reads the world through `SolverProbe` and the executor's
## event history. The real `Conditions.eval(world, cond)` always wins when it exists.
##
## A condition is a Dictionary; several keys = AND. Values:
##   {"bellows_not_in_room": "kitchen"}  {"prank_state": ["achoo_ria", "rigged"]}
##   {"bellows_eta_to_room_gt_s": ["kitchen", 4]}  {"tick_ge_s": 3.7}  {"first_rig": true}
##   {"event_seen": "rigged"} or {"event_seen": {"e": "rigged", "prank": "tap_dance"}}
##   {"and": [..]}  {"or": [..]}  {"not": {..}}
class_name SolverConditions
extends RefCounted

const TIERS := {"calm": 0, "irked": 1, "steaming": 2, "livid": 3}

var probe: SolverProbe
## Returns the Array of events seen so far (each {"e", "t", ...}).
var history_fn: Callable
var unknown: PackedStringArray = []   ## condition keys this evaluator did not understand


func _init(p_probe: SolverProbe, p_history_fn: Callable = Callable()) -> void:
	probe = p_probe
	history_fn = p_history_fn


## Callable(world, cond) -> bool bound to this evaluator (the executor's cond_fn shape).
func as_callable() -> Callable:
	return func(_world: Object, cond: Variant) -> bool: return eval_cond(cond)


## Evaluate a condition (Dictionary, Array = AND, bool, or null = true).
func eval_cond(cond: Variant) -> bool:
	if cond == null:
		return true
	if cond is bool:
		return cond
	if cond is Array:
		for c in cond:
			if not eval_cond(c):
				return false
		return true
	if not (cond is Dictionary):
		return false
	var d: Dictionary = cond
	for k in d:
		if not _eval_key(String(k), d[k]):
			return false
	return true


func _events() -> Array:
	if history_fn.is_valid():
		var v: Variant = history_fn.call()
		if v is Array:
			return v
	return []


func _seen(match_d: Dictionary) -> bool:
	for ev in _events():
		var ok := true
		for k in match_d:
			if str(ev.get(k, null)) != str(match_d[k]):
				ok = false
				break
		if ok:
			return true
	return false


func _eval_key(k: String, v: Variant) -> bool:
	match k:
		"and":
			return eval_cond(v if v is Array else [v])
		"or":
			for c in (v if v is Array else [v]):
				if eval_cond(c):
					return true
			return false
		"not":
			return not eval_cond(v)
		"bellows_activity":
			return probe.bellows_activity() == String(v)
		"bellows_activity_in":
			return (v as Array).has(probe.bellows_activity()) if v is Array else false
		"bellows_state":
			return probe.bellows_state() == String(v).to_upper()
		"bellows_in_room":
			return probe.bellows_room() == String(v)
		"bellows_not_in_room":
			return probe.bellows_room() != String(v)
		"bellows_eta_to_room_gt_s":
			var room := SolverData.sv(v[0]) if v is Array and v.size() > 0 else ""
			var s := float(v[1]) if v is Array and v.size() > 1 else 0.0
			var need := int(round(s * 60.0))
			var eta := probe.bellows_eta_to_room(room, maxi(need + 20, 60))
			return eta < 0 or eta > need
		"bellows_activity_remaining_le_s":
			var rem := probe.bellows_activity_remaining()
			return rem >= 0 and rem <= int(round(float(v) * 60.0))
		"bellows_facing_away_from_hush":
			return probe.bellows_facing_away_from_hush() == bool(v)
		"hush_visible":
			return _hush_visible() == bool(v)
		"hush_hidden":
			return probe.hush_hidden() == bool(v)
		"spot_meter_pct_ge":
			var fill := maxi(1, probe.spot_fill())
			return probe.spot_meter() * 100 >= int(v) * fill
		"prank_state":
			if v is Array and v.size() >= 2:
				return probe.prank_state(SolverData.sv(v[0])) == SolverData.sv(v[1]).to_upper()
			return false
		"temper_tier_ge":
			var want: int = int(TIERS.get(String(v).to_lower(), int(v) if (v is int or v is float) else 0))
			return probe.temper_tier() >= want
		"link_ge":
			return probe.link_count() >= int(v)
		"line_done":
			return probe.line_done(String(v))
		"all_required_done":
			return probe.all_required_done() == bool(v)
		"tick_ge_s":
			return probe.tick() >= int(round(float(v) * 60.0))
		"first_squeak":
			return _seen({"e": "squeak"}) == bool(v)
		"first_rig":
			return (_seen({"e": "rig_step_done"}) or _seen({"e": "rigged"})) == bool(v)
		"event_seen":
			if v is Dictionary:
				return _seen(v)
			return _seen({"e": String(v)})
	if not unknown.has(k):
		unknown.append(k)
	return false


func _hush_visible() -> bool:
	if probe.hush_hidden():
		return false
	if probe.bellows_room() != probe.hush_room() or probe.bellows_reacting():
		return false
	return not probe.bellows_facing_away_from_hush()
