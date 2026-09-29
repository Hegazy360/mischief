## TapAssist — resolves a world tap to a sim command (GDD §3.1, TECH §6.2).
##
##   TapAssist.resolve(world_pos, candidates, zoom) -> Dictionary
## `candidates`: Array of {id: String, kind: String, rect: Rect2 (world px), room: String,
## priority: int (optional)}. Kinds: container | hiding | rig_point (hotspots, priority 2),
## door | stairs | exit (priority 1), floor (priority 0: one per room, rect = the room's floor
## band). Order:
##   1. an exact hit on a non-floor rect (highest priority, then nearest centre);
##   2. else the nearest non-floor candidate within ASSIST_PX SCREEN px (= ASSIST_PX / zoom world
##      px) — highest priority first, then distance to its rect;
##   3. else the floor under the tap (or the nearest floor within the assist radius).
## Returns {"c": "go", "hotspot": id, "kind": kind, "room": room, "assisted": bool},
## {"c": "move", "room": room, "x": int} for the floor, or {} when nothing is near.
##
## Stacks (house.json `stacks`, art-house request): candidates may carry `enabled: bool`
## (default true) and `stack: String` (the stack they share; "" = none). A DISABLED hotspot is
## never a target itself; a tap on (or assisted to) a disabled hotspot that shares a stack with
## an enabled one resolves to that enabled partner (the bottom stair steps without RUG BURN →
## climb the stairs; the fridge's top door in Night 1 → open the fridge) and the result carries
## `"via": <disabled id>`. A disabled hotspot with no enabled partner is ignored (the tap falls
## through to the assist / the floor). Coordinates: `world_pos` and every `rect` share one space
## (world px, or screen px with zoom 1.0).
class_name TapAssist
extends RefCounted

const HOTSPOT_KINDS := ["container", "hiding", "rig_point", "hotspot"]
const PASSAGE_KINDS := ["door", "stairs", "exit"]


## See the class doc.
static func resolve(world_pos: Vector2, candidates: Array, zoom: float) -> Dictionary:
	var radius := GestureConfig.ASSIST_PX / maxf(zoom, 0.01)
	var best: Dictionary = {}
	var best_via := ""
	var best_pri := -1
	var best_d := INF
	var best_direct := false
	# 1. exact hits (a disabled stacked hotspot stands in for its enabled partner)
	for c in candidates:
		var cd: Dictionary = c
		if _kind(cd) == "floor":
			continue
		var r: Rect2 = cd.get("rect", Rect2())
		if not r.has_point(world_pos):
			continue
		var target := cd
		var via := ""
		if not is_enabled(cd):
			target = stack_partner(cd, candidates)
			if target.is_empty():
				continue
			via = String(cd.get("id", ""))
		var pri := priority_of(target)
		var d := world_pos.distance_to((target.get("rect", Rect2()) as Rect2).get_center())
		var direct := via == ""
		if pri > best_pri or (pri == best_pri and (direct and not best_direct or direct == best_direct and d < best_d)):
			best = target
			best_via = via
			best_pri = pri
			best_d = d
			best_direct = direct
	if not best.is_empty():
		return _go(best, false, best_via)
	# 2. assisted
	for c in candidates:
		var cd: Dictionary = c
		if _kind(cd) == "floor":
			continue
		var d := rect_distance(world_pos, cd.get("rect", Rect2()))
		if d > radius:
			continue
		var target := cd
		var via := ""
		if not is_enabled(cd):
			target = stack_partner(cd, candidates)
			if target.is_empty():
				continue
			via = String(cd.get("id", ""))
			d = minf(d, rect_distance(world_pos, target.get("rect", Rect2())))
		var pri := priority_of(target)
		if pri > best_pri or (pri == best_pri and d < best_d):
			best = target
			best_via = via
			best_pri = pri
			best_d = d
	if not best.is_empty():
		return _go(best, true, best_via)
	# 3. floor
	best_d = INF
	for c in candidates:
		var cd: Dictionary = c
		if _kind(cd) != "floor":
			continue
		var d := rect_distance(world_pos, cd.get("rect", Rect2()))
		if d <= radius and d < best_d:
			best = cd
			best_d = d
	if best.is_empty():
		return {}
	var fr: Rect2 = best.get("rect", Rect2())
	return {"c": "move", "room": String(best.get("room", "")),
		"x": int(round(clampf(world_pos.x, fr.position.x, fr.end.x)))}


## A candidate is a target unless it says `enabled: false`.
static func is_enabled(c: Dictionary) -> bool:
	return bool(c.get("enabled", true))


## The enabled candidate sharing `c`'s `stack` (highest priority, then nearest centre); {} = none.
static func stack_partner(c: Dictionary, candidates: Array) -> Dictionary:
	var st := String(c.get("stack", ""))
	if st == "":
		return {}
	var cc := (c.get("rect", Rect2()) as Rect2).get_center()
	var best: Dictionary = {}
	var best_pri := -1
	var best_d := INF
	for o in candidates:
		var od: Dictionary = o
		if od == c or not is_enabled(od) or _kind(od) == "floor" or String(od.get("stack", "")) != st:
			continue
		var pri := priority_of(od)
		var d := cc.distance_to((od.get("rect", Rect2()) as Rect2).get_center())
		if pri > best_pri or (pri == best_pri and d < best_d):
			best = od
			best_pri = pri
			best_d = d
	return best


## A candidate's priority: its `priority` field, else 2 hotspot / 1 door-stairs-exit / 0 floor.
static func priority_of(c: Dictionary) -> int:
	if c.has("priority"):
		return int(c["priority"])
	var k := _kind(c)
	if k == "floor":
		return 0
	if PASSAGE_KINDS.has(k):
		return 1
	return 2


## Distance from `p` to the nearest point of `r` (0 inside).
static func rect_distance(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


static func _kind(c: Dictionary) -> String:
	return String(c.get("kind", "hotspot"))


static func _go(c: Dictionary, assisted: bool, via: String = "") -> Dictionary:
	var out := {"c": "go", "hotspot": String(c.get("id", "")), "kind": _kind(c), "room": String(c.get("room", "")),
		"assisted": assisted}
	if via != "":
		out["via"] = via
	return out
