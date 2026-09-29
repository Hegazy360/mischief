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
class_name TapAssist
extends RefCounted

const HOTSPOT_KINDS := ["container", "hiding", "rig_point", "hotspot"]
const PASSAGE_KINDS := ["door", "stairs", "exit"]


## See the class doc.
static func resolve(world_pos: Vector2, candidates: Array, zoom: float) -> Dictionary:
	var radius := GestureConfig.ASSIST_PX / maxf(zoom, 0.01)
	var best: Dictionary = {}
	var best_pri := -1
	var best_d := INF
	# 1. exact hits
	for c in candidates:
		var cd: Dictionary = c
		if _kind(cd) == "floor":
			continue
		var r: Rect2 = cd.get("rect", Rect2())
		if not r.has_point(world_pos):
			continue
		var pri := priority_of(cd)
		var d := world_pos.distance_to(r.get_center())
		if pri > best_pri or (pri == best_pri and d < best_d):
			best = cd
			best_pri = pri
			best_d = d
	if not best.is_empty():
		return _go(best, false)
	# 2. assisted
	for c in candidates:
		var cd: Dictionary = c
		if _kind(cd) == "floor":
			continue
		var d := rect_distance(world_pos, cd.get("rect", Rect2()))
		if d > radius:
			continue
		var pri := priority_of(cd)
		if pri > best_pri or (pri == best_pri and d < best_d):
			best = cd
			best_pri = pri
			best_d = d
	if not best.is_empty():
		return _go(best, true)
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


static func _go(c: Dictionary, assisted: bool) -> Dictionary:
	return {"c": "go", "hotspot": String(c.get("id", "")), "kind": _kind(c), "room": String(c.get("room", "")),
		"assisted": assisted}
