## SolverData — a light, standalone reader of the raw `game/data/**` JSON the solver needs.
##
## The solver bot, planner, fuzz bots and lints never depend on `ContentDB` internals: they read
## the TECH §4 files directly (house, items, pranks, activities, episodes, reactions, residues,
## solutions) so they keep working while the sim is being built, and so a data bug is reported
## in data terms ("pranks.json: kettle_drum.rig_point 'kitchen_kettle'…").
##
##   var d := SolverData.load_dir("res://data")
##   d.rig_point("kettle_drum", 0)        # -> "kitchen_kettle"
##   d.hotspot("kitchen_kettle").room     # -> "kitchen"
## Missing files load as empty dictionaries; `errors` lists parse failures.
class_name SolverData
extends RefCounted

## Detour activity ids (TECH §14), plus `exit` (an episode's scripted walk-off, `bellows.exit`).
## Everything else in `b_activity` is a loop activity.
const DETOUR_IDS: PackedStringArray = ["fixup_dry", "fixup_sink", "fixup_honey", "fixup_mirror", "curious",
	"herd_beryl", "search", "exit"]
## Rig prep tiers → ticks (TECH §3.7.4 / GDD §5.1).
const PREP_TICKS := {"Q": 48, "S": 90, "B": 150}
## Size weights for prank-line bases (TECH §3.2): tenths per weight unit.
const SIZE_WEIGHTS := {"S": 10, "M": 14, "L": 20, "SIG": 30}

var root: String = "res://data"
var house: Dictionary = {}
var items: Dictionary = {}          ## id -> item dict
var pranks: Dictionary = {}         ## id -> prank dict
var double_acts: Dictionary = {}    ## id -> {a, b, caption}
var activities: Dictionary = {}     ## id -> activity dict
var squeak_bits: Dictionary = {}
var reactions: Dictionary = {}      ## the whole reactions.json
var residues: Dictionary = {}       ## kind -> {fixup, overlay}
var combos: Dictionary = {}
var episodes: Dictionary = {}       ## id -> episode dict
var errors: PackedStringArray = []

var _hotspots: Dictionary = {}      ## id -> hotspot dict
var _rooms: Dictionary = {}         ## id -> room dict
var _stations: Dictionary = {}      ## id -> station dict
var _links: Dictionary = {}         ## id -> link dict
var _sorted_cache: Dictionary = {}


## Load every file under `data_root` (missing files are fine; parse errors go to `errors`).
static func load_dir(data_root: String = "res://data") -> SolverData:
	var d := SolverData.new()
	d.root = data_root.trim_suffix("/")
	d.house = d._read("house/house.json")
	var it: Dictionary = d._read("items.json")
	d.items = it.get("items", {})
	var pr: Dictionary = d._read("pranks.json")
	d.pranks = pr.get("pranks", {})
	d.double_acts = pr.get("double_acts", {})
	var ac: Dictionary = d._read("activities.json")
	d.activities = ac.get("activities", {})
	var det: Variant = ac.get("detours", {})
	if det is Dictionary:
		for k in det:
			if not d.activities.has(k):
				d.activities[k] = det[k]
	d.squeak_bits = ac.get("squeak_bits", {})
	d.reactions = d._read("reactions.json")
	var rs: Dictionary = d._read("residues.json")
	d.residues = rs.get("residues", {})
	d.combos = rs.get("combos", {})
	d.episodes = d._read_episodes()
	d._index()
	return d


## Build a SolverData from in-memory dictionaries (tests). Keys: house, items, pranks,
## double_acts, activities, reactions, residues, combos, episodes (id -> dict).
static func from_dicts(parts: Dictionary) -> SolverData:
	var d := SolverData.new()
	d.root = ""
	d.house = parts.get("house", {})
	d.items = parts.get("items", {})
	d.pranks = parts.get("pranks", {})
	d.double_acts = parts.get("double_acts", {})
	d.activities = parts.get("activities", {})
	d.reactions = parts.get("reactions", {})
	d.residues = parts.get("residues", {})
	d.combos = parts.get("combos", {})
	d.episodes = parts.get("episodes", {})
	d._index()
	return d


## Parse one JSON file; returns null when missing, appends a message to `errs` (an Array, so the
## caller sees it) when invalid.
static func read_json(path: String, errs: Array = []) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		errs.append("%s:%d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data


func _read(rel: String) -> Dictionary:
	var sink: Array = []
	var v: Variant = SolverData.read_json("%s/%s" % [root, rel], sink)
	for e in sink:
		errors.append(String(e))
	return v if v is Dictionary else {}


func _read_episodes() -> Dictionary:
	var out := {}
	var dir := "%s/episodes" % root
	var names := _list_json(dir)
	for n in names:
		var sink: Array = []
		var v: Variant = SolverData.read_json("%s/%s" % [dir, n], sink)
		for e in sink:
			errors.append(String(e))
		if v is Dictionary:
			var id := sv((v as Dictionary).get("id", n.get_basename()))
			out[id] = v
	return out


## Sorted `*.json` file names in a directory (non-recursive).
static func _list_json(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out


func _index() -> void:
	_hotspots.clear()
	_rooms.clear()
	_stations.clear()
	_links.clear()
	_sorted_cache.clear()
	for h in house.get("hotspots", []):
		if h is Dictionary and h.has("id"):
			_hotspots[sv(h["id"])] = h
	for r in house.get("rooms", []):
		if r is Dictionary and r.has("id"):
			_rooms[sv(r["id"])] = r
	for s in house.get("stations", []):
		if s is Dictionary and s.has("id"):
			_stations[sv(s["id"])] = s
	for l in house.get("links", []):
		if l is Dictionary and l.has("id"):
			_links[sv(l["id"])] = l


# --- house ------------------------------------------------------------------------------------

## The hotspot dict (or {}).
func hotspot(id: String) -> Dictionary:
	return _hotspots.get(id, {})


func has_hotspot(id: String) -> bool:
	return _hotspots.has(id)


func room(id: String) -> Dictionary:
	return _rooms.get(id, {})


func has_room(id: String) -> bool:
	return _rooms.has(id)


func station(id: String) -> Dictionary:
	return _stations.get(id, {})


func has_station(id: String) -> bool:
	return _stations.has(id)


func link(id: String) -> Dictionary:
	return _links.get(id, {})


func hotspot_ids() -> PackedStringArray:
	return sorted_ids("hotspots")


func room_ids() -> PackedStringArray:
	return sorted_ids("rooms")


func station_ids() -> PackedStringArray:
	return sorted_ids("stations")


## Sorted id list of a category: rooms, hotspots, stations, links, items, pranks, activities,
## episodes. The sim interns ids to ints in this order (TECH §2), so index i ↔ sorted_ids[i].
func sorted_ids(kind: String) -> PackedStringArray:
	if _sorted_cache.has(kind):
		return _sorted_cache[kind]
	var src: Dictionary = {}
	match kind:
		"rooms": src = _rooms
		"hotspots": src = _hotspots
		"stations": src = _stations
		"links": src = _links
		"items": src = items
		"pranks": src = pranks
		"activities": src = activities
		"episodes": src = episodes
		"double_acts": src = double_acts
	var out := PackedStringArray()
	for k in src:
		out.append(String(k))
	out.sort()
	_sorted_cache[kind] = out
	return out


## Room of a hotspot ("" if unknown).
func hotspot_room(id: String) -> String:
	return sv(hotspot(id).get("room", ""))


## Use point x (px) of a hotspot (0 if unknown).
func hotspot_x(id: String) -> int:
	return int(hotspot(id).get("use_x", 0))


func hotspot_kind(id: String) -> String:
	return sv(hotspot(id).get("kind", ""))


## Floor index of a room (ground 0 when unknown).
func room_floor(id: String) -> int:
	return int(room(id).get("floor", 0))


## Rooms joined to `id` by a doorway or door (both directions), sorted.
func neighbours(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for lid in sorted_ids("links"):
		var l: Dictionary = _links[lid]
		var k := sv(l.get("kind", ""))
		if k != "doorway" and k != "door":
			continue
		var a := sv(l.get("a", ""))
		var b := sv(l.get("b", ""))
		if a == id and not out.has(b):
			out.append(b)
		elif b == id and not out.has(a):
			out.append(a)
	out.sort()
	return out


## Rooms joined by an always-open doorway only (hearing of squeaks, TECH §3.7.3).
func doorway_neighbours(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for lid in sorted_ids("links"):
		var l: Dictionary = _links[lid]
		if sv(l.get("kind", "")) != "doorway":
			continue
		var a := sv(l.get("a", ""))
		var b := sv(l.get("b", ""))
		if a == id:
			out.append(b)
		elif b == id:
			out.append(a)
	out.sort()
	return out


## Hotspot ids of one kind in a room, sorted by use_x.
func hotspots_in(room_id: String, kind: String = "") -> PackedStringArray:
	var pairs: Array = []
	for id in sorted_ids("hotspots"):
		var h: Dictionary = _hotspots[id]
		if sv(h.get("room", "")) != room_id:
			continue
		if kind != "" and sv(h.get("kind", "")) != kind:
			continue
		pairs.append([int(h.get("use_x", 0)), id])
	pairs.sort()
	var out := PackedStringArray()
	for p in pairs:
		out.append(p[1])
	return out


## Rough walking distance in px between two floor points (same floor: |dx| through the rooms;
## other floor: via the stairs link). Only used to rank candidates (nearest hiding spot…).
func walk_px(room_a: String, x_a: int, room_b: String, x_b: int) -> int:
	var fa := room_floor(room_a)
	var fb := room_floor(room_b)
	if fa == fb:
		return absi(x_a - x_b)
	var st := link("stairs")
	if st.is_empty():
		return absi(x_a - x_b) + 2000
	var ax := int(st.get("ax", 0))
	var bx := int(st.get("bx", 0))
	var a_floor := room_floor(sv(st.get("a", "")))
	if fa == a_floor:
		return absi(x_a - ax) + 600 + absi(bx - x_b)
	return absi(x_a - bx) + 600 + absi(ax - x_b)


## Nearest hiding spot to (room, x) among `rooms` (default: that room and its neighbours),
## skipping `exclude`. Returns "" if none.
func nearest_hiding(room_id: String, x: int, exclude: PackedStringArray = PackedStringArray(),
		rooms: PackedStringArray = PackedStringArray()) -> String:
	var cands := rooms
	if cands.is_empty():
		cands = PackedStringArray([room_id])
		cands.append_array(neighbours(room_id))
	var best := ""
	var best_d := 1 << 30
	for r in cands:
		for id in hotspots_in(r, "hiding"):
			if exclude.has(id):
				continue
			var d := walk_px(room_id, x, r, hotspot_x(id)) + (0 if r == room_id else 400)
			if d < best_d:
				best_d = d
				best = id
	return best


## The activity that makes a hiding spot "in use" (hotspot.in_use_by, or an activity's in_use).
func in_use_activity(spot: String) -> String:
	var v: Variant = hotspot(spot).get("in_use_by", null)
	if v is String and v != "":
		return v
	for aid in sorted_ids("activities"):
		var a: Dictionary = activities[aid]
		if sv(a.get("in_use", "")) == spot:
			return aid
	return ""


# --- pranks and items -------------------------------------------------------------------------

func prank(id: String) -> Dictionary:
	return pranks.get(id, {})


func item(id: String) -> Dictionary:
	return items.get(id, {})


## Steps of a prank (always at least one).
func prank_steps(id: String) -> Array:
	var s: Variant = prank(id).get("steps", [])
	if s is Array and not (s as Array).is_empty():
		return s
	return [{"prep": "Q", "needs": null}]


## Rig point hotspot of step `step` (the step's own `at`, else the prank's rig_point).
func rig_point(prank_id: String, step: int = 0) -> String:
	var steps := prank_steps(prank_id)
	if step >= 0 and step < steps.size():
		var st: Dictionary = steps[step]
		if st.get("at", null) is String and sv(st["at"]) != "":
			return sv(st["at"])
	return sv(prank(prank_id).get("rig_point", ""))


## Item needed by a prank step ("" = free).
func step_needs(prank_id: String, step: int) -> String:
	var steps := prank_steps(prank_id)
	if step < 0 or step >= steps.size():
		return ""
	var n: Variant = (steps[step] as Dictionary).get("needs", null)
	return String(n) if n is String else ""


## Prep ticks of a prank step (Q 48 / S 90 / B 150).
func step_prep_ticks(prank_id: String, step: int) -> int:
	var steps := prank_steps(prank_id)
	if step < 0 or step >= steps.size():
		return 48
	return int(PREP_TICKS.get(sv((steps[step] as Dictionary).get("prep", "Q")), 48))


## Source container of an item ("" if unknown).
func item_source(item_id: String) -> String:
	return sv(item(item_id).get("source", ""))


## Uses per pick of an item (coins: 3).
func item_count(item_id: String) -> int:
	return maxi(1, int(item(item_id).get("count", 1)))


## Pranks whose steps need an item.
func pranks_needing(item_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for pid in sorted_ids("pranks"):
		var n := prank_steps(pid).size()
		for i in n:
			if step_needs(pid, i) == item_id:
				out.append(pid)
				break
	return out


## Station of a rig point hotspot (via hotspot.station) or {}.
func rig_station(prank_id: String) -> Dictionary:
	var hs := hotspot(rig_point(prank_id, 0))
	return station(sv(hs.get("station", "")))


## Stand-in (mirror frame) point for a prank: {room, x} from its station's `frame_x`
## (falls back to the rig point's use point).
func frame_point(prank_id: String) -> Dictionary:
	var rp := rig_point(prank_id, 0)
	var st := rig_station(prank_id)
	if not st.is_empty() and st.has("frame_x"):
		return {"room": sv(st.get("room", hotspot_room(rp))), "x": int(st["frame_x"])}
	return {"room": hotspot_room(rp), "x": hotspot_x(rp)}


func trigger(prank_id: String) -> Dictionary:
	var t: Variant = prank(prank_id).get("trigger", {})
	return t if t is Dictionary else {}


## Knock-on target prank of `prank_id` ("" if none / headbutt).
func knock_on_target(prank_id: String) -> String:
	var k: Variant = prank(prank_id).get("knock_on", null)
	if k is Dictionary and (k as Dictionary).get("prank", null) is String:
		return sv(k["prank"])
	return ""


# --- episodes ---------------------------------------------------------------------------------

func episode(id: String) -> Dictionary:
	return episodes.get(id, {})


## Episode ids with `status == "final"` (sorted).
func final_episode_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in sorted_ids("episodes"):
		if sv((episodes[id] as Dictionary).get("status", "draft")) == "final":
			out.append(id)
	return out


func script_lines(ep_id: String) -> Array:
	var s: Variant = episode(ep_id).get("script", [])
	return s if s is Array else []


## Script line dict by id ({} if none).
func line(ep_id: String, line_id: String) -> Dictionary:
	for l in script_lines(ep_id):
		if l is Dictionary and sv(l.get("id", "")) == line_id:
			return l
	return {}


## Pranks a line needs rigged, in rig order (double act: B before A so the knock-on can land).
func line_pranks(ep_id: String, line_dict: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var kind := sv(line_dict.get("kind", "prank"))
	match kind:
		"prank", "prank_witnessed", "chase_trip":
			if line_dict.get("prank", null) is String:
				out.append(sv(line_dict["prank"]))
		"double_act":
			var da: Dictionary = double_acts.get(sv(line_dict.get("double_act", "")), {})
			if da.has("b"):
				out.append(sv(da["b"]))
			if da.has("a"):
				out.append(sv(da["a"]))
		"combo", "combo_witnessed":
			var c: Dictionary = combos.get(sv(line_dict.get("combo", "")), {})
			var kinds: Array = c.get("of", [])
			for pid in episode_pranks(ep_id):
				for r in prank(pid).get("residue", []):
					if r is Dictionary and kinds.has(sv(r.get("kind", ""))) and not out.has(pid):
						out.append(pid)
	return out


## Every prank referenced by an episode's Script (prank lines + double acts), sorted.
func episode_pranks(ep_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for l in script_lines(ep_id):
		if not (l is Dictionary):
			continue
		var d: Dictionary = l
		if d.get("prank", null) is String and not out.has(sv(d["prank"])):
			out.append(sv(d["prank"]))
		if d.get("double_act", null) is String:
			var da: Dictionary = double_acts.get(sv(d["double_act"]), {})
			for k in ["a", "b"]:
				if da.get(k, null) is String and not out.has(sv(da[k])):
					out.append(sv(da[k]))
	out.sort()
	return out


## Pranks referenced by required lines only.
func required_pranks(ep_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for l in script_lines(ep_id):
		if l is Dictionary and bool((l as Dictionary).get("req", false)):
			for p in line_pranks(ep_id, l):
				if not out.has(p):
					out.append(p)
	return out


## Loop activity ids of an episode in order (entries flagged `once`/`first_loop_only` kept).
func loop_ids(ep_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var b: Variant = episode(ep_id).get("bellows", {})
	if not (b is Dictionary):
		return out
	for e in (b as Dictionary).get("loop", []):
		if e is Dictionary:
			out.append(sv((e as Dictionary).get("a", "")))
		elif e is String:
			out.append(String(e))
	return out


## Loop entries as dicts ({a, gate?, once?}).
func loop_entries(ep_id: String) -> Array:
	var out: Array = []
	var b: Variant = episode(ep_id).get("bellows", {})
	if not (b is Dictionary):
		return out
	for e in (b as Dictionary).get("loop", []):
		if e is Dictionary:
			out.append(e)
		elif e is String:
			out.append({"a": e})
	return out


func rules(ep_id: String) -> Dictionary:
	var r: Variant = episode(ep_id).get("rules", {})
	return r if r is Dictionary else {}


## "?" fill window in ticks for an episode (× 1.5 relaxed; default 1.0 s).
func spot_fill_ticks(ep_id: String, relaxed: bool = false) -> int:
	var s := float(rules(ep_id).get("spot_fill_s", 1.0))
	var t := int(round(s * 60.0))
	if relaxed:
		t = t * 3 / 2
	return t


## Director launch offset (s) for launch-relative laugh-clock checks (0 without a director).
func launch_offset_s(ep_id: String) -> float:
	var d: Variant = episode(ep_id).get("director", null)
	if d is Dictionary:
		return float((d as Dictionary).get("launch_offset_s", 0.0))
	return 0.0


## Tomato limit (−1 = unlimited).
func tomatoes_max(ep_id: String) -> int:
	return int(rules(ep_id).get("tomatoes", -1))


## Prank-line bases in tenths by largest remainder over size weights (sum exactly 700 when
## there is at least one prank line). Returns line id -> tenths; ties by line order.
func line_bases(ep_id: String) -> Dictionary:
	return SolverData.normalise_bases(script_lines(ep_id), pranks)


## Largest-remainder normalisation of prank-line weights to 700 tenths (TECH §3.2).
static func normalise_bases(lines: Array, prank_defs: Dictionary, total: int = 700) -> Dictionary:
	var ids: Array = []
	var weights: Array = []
	var wsum := 0
	for l in lines:
		if not (l is Dictionary):
			continue
		var d: Dictionary = l
		if sv(d.get("kind", "prank")) != "prank" or not (d.get("prank", null) is String):
			continue
		var p: Dictionary = prank_defs.get(sv(d["prank"]), {})
		var w := int(SIZE_WEIGHTS.get(sv(p.get("size", "")), 0))
		ids.append(sv(d.get("id", "")))
		weights.append(w)
		wsum += w
	var out := {}
	if wsum <= 0:
		return out
	var floors: Array = []
	var rems: Array = []
	var used := 0
	for i in ids.size():
		var num: int = weights[i] * total
		floors.append(num / wsum)
		rems.append([-(num % wsum), i])
		used += num / wsum
	rems.sort()
	var left := total - used
	for k in rems.size():
		if left <= 0:
			break
		floors[rems[k][1]] += 1
		left -= 1
	for i in ids.size():
		out[ids[i]] = floors[i]
	return out


## A JSON value as a String ("" for null/missing; never "<null>").
static func sv(v: Variant) -> String:
	if v == null:
		return ""
	if v is String or v is StringName:
		return String(v)
	if v is float and v == floor(v):
		return str(int(v))
	return str(v)


## An id list from an event payload: a comma-joined String (the sim's scalar payloads), an
## Array or a PackedStringArray.
static func as_ids(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if v is String or v is StringName:
		for part in String(v).split(",", false):
			out.append(part.strip_edges())
	elif v is Array or v is PackedStringArray:
		for x in v:
			out.append(sv(x))
	return out
