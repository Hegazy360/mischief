## HotspotLint — touch-target and geometry rules over `house.json` (TECH §10.5, GDD §3.5 / §7.1).
##
##   var errs := HotspotLint.lint_file("res://data/house/house.json")
##
## Rules: every hit box ≥ 144 × 144 px; on each FLOOR any two targets (hotspots of every kind —
## containers, hiding, rig points, exits, doors, stairs — plus link rects) never overlap and are
## ≥ 24 px apart (horizontally or, for stacked shared objects, vertically) — checked across room walls, since
## door / exit boxes may straddle their wall (they belong to both rooms), as `tools/art/house/lint_rects.py`
## does; every `house.json stacks` group sits in one column (each member x-overlaps another) with ≥ 24 px
## between x-overlapping members; a door or stairs hotspot names a link unless it is not tappable (the
## Prologue's `kitchen_window`: kind door, no link, `tappable: false`); use points inside their room; station x
## within 80 px of the GDD §7.1 table (embedded below) and in the table's room.
class_name HotspotLint
extends RefCounted

const MIN_SIZE := 144
const MIN_GAP := 24
const STATION_TOL := 80
## GDD §7.1 station positions: id -> [room, x] or [room, x_min, x_max] for spans.
const GDD_STATIONS := {
	"st_front_door": ["hall", 520], "st_phone": ["hall", 980], "st_hall_mirror": ["hall", 1160],
	"st_clock": ["hall", 1340],
	"st_gramophone": ["parlour", 1640], "st_piano": ["parlour", 1840], "st_recliner": ["parlour", 2080],
	"st_fireplace": ["parlour", 2330], "st_chaise": ["parlour", 2560], "st_parlour_centre": ["parlour", 1500, 2800],
	"st_tea": ["kitchen", 2960], "st_pickles": ["kitchen", 3130], "st_fridge": ["kitchen", 3300],
	"st_sink": ["kitchen", 3800],
	"st_feed_bin": ["conservatory", 4020], "st_sun_lounger": ["conservatory", 4480],
	"st_hose": ["garden", 4820], "st_marrow": ["garden", 5180], "st_path": ["garden", 5260, 5560],
	"st_stage": ["garden", 5000, 5800],
	"st_radiator": ["landing", 1450],
	"st_basin": ["bathroom", 1930], "st_bath": ["bathroom", 2520],
	"st_wardrobe": ["bedroom", 2920], "st_bed": ["bedroom", 3200],
	"st_dressing_mirror": ["dressing", 4160], "st_trophy": ["dressing", 4300], "st_dummy": ["dressing", 4420]}


## Lint a house.json file ([] + a note when it is missing).
static func lint_file(path: String) -> PackedStringArray:
	var sink: Array = []
	var v: Variant = SolverData.read_json(path, sink)
	var errs := PackedStringArray(sink)
	if v is Dictionary:
		errs.append_array(lint_house(v))
	elif errs.is_empty():
		errs.append("%s: missing" % path)
	return errs


## Lint a parsed house dictionary.
static func lint_house(house: Dictionary) -> PackedStringArray:
	var e := PackedStringArray()
	var rooms := {}
	for r in house.get("rooms", []):
		rooms[SolverData.sv(r.get("id", ""))] = r
	var links := {}
	for l in house.get("links", []):
		links[SolverData.sv(l.get("id", ""))] = l
	# Targets per floor: [id, Rect2i].
	var by_floor := {}
	var rects := {}
	for h in house.get("hotspots", []):
		var id := SolverData.sv(h.get("id", ""))
		var room := SolverData.sv(h.get("room", ""))
		var rect: Variant = h.get("rect", null)
		if not (rect is Array) or (rect as Array).size() != 4:
			e.append("house.json: hotspot %s has no [x, y, w, h] rect" % id)
			continue
		var rc := Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))
		rects[id] = rc
		if rc.size.x < MIN_SIZE or rc.size.y < MIN_SIZE:
			e.append("house.json: hotspot %s hit box %d × %d < %d × %d" % [id, rc.size.x, rc.size.y, MIN_SIZE, MIN_SIZE])
		var kind := SolverData.sv(h.get("kind", ""))
		var tappable := bool(h.get("tappable", true))
		if (kind == "door" or kind == "stairs") and tappable:
			var lk := SolverData.sv(h.get("link", ""))
			if lk == "" or not links.has(lk):
				e.append("house.json: %s %s is tappable but names no link ('%s'); only a non-tappable one may have none" % [
					kind, id, lk])
		var fl := 0
		if not rooms.has(room):
			e.append("house.json: hotspot %s room '%s' not in rooms" % [id, room])
		else:
			var r: Dictionary = rooms[room]
			fl = int(r.get("floor", 0))
			var ux := int(h.get("use_x", -1))
			if ux < int(r.get("x0", 0)) or ux > int(r.get("x1", 0)):
				e.append("house.json: hotspot %s use_x %d outside %s [%d, %d]" % [id, ux, room, int(r.get("x0", 0)), int(r.get("x1", 0))])
		if not by_floor.has(fl):
			by_floor[fl] = []
		(by_floor[fl] as Array).append([id, rc])
	for l in house.get("links", []):
		var rect2: Variant = l.get("rect", null)
		if rect2 is Array and (rect2 as Array).size() == 4:
			var rc2 := Rect2i(int(rect2[0]), int(rect2[1]), int(rect2[2]), int(rect2[3]))
			var ra: Variant = rooms.get(SolverData.sv(l.get("a", "")), null)
			var fl2 := int((ra as Dictionary).get("floor", 0)) if ra is Dictionary else 0
			if not by_floor.has(fl2):
				by_floor[fl2] = []
			(by_floor[fl2] as Array).append(["link:" + SolverData.sv(l.get("id", "")), rc2])
	var floors: Array = by_floor.keys()
	floors.sort()
	for fl3 in floors:
		var ts: Array = by_floor[fl3]
		for i in ts.size():
			for j in range(i + 1, ts.size()):
				var a: Rect2i = ts[i][1]
				var b: Rect2i = ts[j][1]
				var gx := maxi(b.position.x - a.end.x, a.position.x - b.end.x)
				var gy := maxi(b.position.y - a.end.y, a.position.y - b.end.y)
				if gx < 0 and gy < 0:
					e.append("house.json: floor %d: %s and %s hit boxes overlap" % [fl3, ts[i][0], ts[j][0]])
				elif maxi(gx, gy) < MIN_GAP:
					e.append("house.json: floor %d: %s and %s are only %d px apart (min %d)" % [fl3, ts[i][0], ts[j][0], maxi(gx, gy), MIN_GAP])
	# Stacks: one column, stacked with a gap.
	for grp in house.get("stacks", []):
		if not (grp is Array):
			continue
		var mem: Array = []
		var unknown := false
		for g in grp:
			if rects.has(SolverData.sv(g)):
				mem.append([SolverData.sv(g), rects[SolverData.sv(g)]])
			else:
				unknown = true
		if unknown:
			e.append("house.json: stack %s has unknown members" % JSON.stringify(grp))
			continue
		for m in mem:
			var col := false
			for o in mem:
				if o[0] == m[0]:
					continue
				var ra2: Rect2i = m[1]
				var rb2: Rect2i = o[1]
				if maxi(rb2.position.x - ra2.end.x, ra2.position.x - rb2.end.x) < 0:
					col = true
			if not col:
				e.append("house.json: stack %s: %s is not in the same column as the others" % [JSON.stringify(grp), m[0]])
	# Stations against the GDD table.
	for s in house.get("stations", []):
		var sid := SolverData.sv(s.get("id", ""))
		if not GDD_STATIONS.has(sid):
			continue
		var want: Array = GDD_STATIONS[sid]
		var sroom := SolverData.sv(s.get("room", ""))
		if sroom != String(want[0]):
			e.append("house.json: station %s in %s, GDD §7.1 puts it in %s" % [sid, sroom, want[0]])
		var x := int(s.get("x", 0))
		var lo: int = int(want[1]) - STATION_TOL
		var hi: int = (int(want[2]) if want.size() > 2 else int(want[1])) + STATION_TOL
		if x < lo or x > hi:
			var target := "%d" % int(want[1]) if want.size() == 2 else "%d–%d" % [int(want[1]), int(want[2])]
			e.append("house.json: station %s x %d is more than %d px from the GDD §7.1 x %s" % [sid, x, STATION_TOL, target])
	return e
