## HouseLayout — the view's read-only picture of the house: rooms, links, stations and
## hotspots in world px (TECH §2, §4.1). Built from the sim's ContentDB house (soft), from
## `res://data/house/house.json` (owner `art-house`), or — when neither exists — a greybox
## from the GDD §7.1 room widths with the TECH §14 hotspot ids, so the view always has a set.
##
## Hotspot rects are converted to absolute world coordinates (house.json stores y relative to
## the room's floor line).
class_name HouseLayout
extends RefCounted

const HOUSE_JSON := "res://data/house/house.json"
## Visible stage dressing around the house (GDD §3.7: ≈ 190 px of flies / apron at zoom 1).
const APRON_H := 190.0
const FLIES_H := 190.0

## GDD §7.1: [id, floor, x0, x1, outdoor, wallpaper].
const GREYBOX_ROOMS := [
	["porch", 0, 0, 500, true, "#9FD6F0"],
	["hall", 0, 500, 1500, false, "#A9B79A"],
	["parlour", 0, 1500, 2800, false, "#D9A7A0"],
	["kitchen", 0, 2800, 3900, false, "#F2DFA6"],
	["conservatory", 0, 3900, 4700, false, "#CDE7E1"],
	["garden", 0, 4700, 6200, true, "#8ACB6A"],
	["landing", 1, 1000, 1800, false, "#C9A27A"],
	["bathroom", 1, 1800, 2800, false, "#BFE3D5"],
	["bedroom", 1, 2800, 3700, false, "#B8C7E6"],
	["dressing", 1, 3700, 4500, false, "#6FA3A8"],
]
## TECH §14 links: [id, kind, a, b, x | ax, bx].
const GREYBOX_LINKS := [
	["front_door", "door", "porch", "hall", 500],
	["hall_parlour", "doorway", "hall", "parlour", 1500],
	["parlour_kitchen", "doorway", "parlour", "kitchen", 2800],
	["back_door", "door", "kitchen", "conservatory", 3900],
	["conservatory_garden", "doorway", "conservatory", "garden", 4700],
	["landing_bathroom", "doorway", "landing", "bathroom", 1800],
	["bathroom_bedroom", "doorway", "bathroom", "bedroom", 2800],
	["bedroom_dressing", "doorway", "bedroom", "dressing", 3700],
	["stairs", "stairs", "hall", "landing", 1450, 1050],
]
## Greybox hotspots (TECH §14 ids, GDD §7.1 x): [id, kind, room, use_x, w, h, y_off, extra].
## Rect = [use_x − w/2, y_off − h, w, h] relative to the floor line.
const GREYBOX_HOTSPOTS := [
	["hall_front_door", "exit", "hall", 560, 150, 330, 0, ""],
	["hall_coat_cupboard", "hiding", "hall", 740, 150, 320, 0, ""],
	["hall_confiscated_box", "container", "hall", 920, 150, 150, 0, ""],
	["hall_phone", "rig_point", "hall", 1090, 150, 150, -140, "st_phone"],
	["hall_piggy_bank", "container", "hall", 1090, 150, 144, 0, ""],
	["hall_mirror", "rig_point", "hall", 1250, 144, 300, 0, "st_hall_mirror"],
	["hall_clock", "rig_point", "hall", 1410, 150, 150, -200, "st_clock"],
	["hall_clock_case", "hiding", "hall", 1410, 150, 180, 0, "clock"],
	["parlour_gramophone", "rig_point", "parlour", 1640, 170, 230, 0, "st_gramophone"],
	["parlour_piano_back", "hiding", "parlour", 1860, 190, 170, 0, ""],
	["parlour_piano_wedge", "rig_point", "parlour", 1860, 190, 150, -194, "st_piano"],
	["parlour_recliner", "rig_point", "parlour", 2090, 170, 180, 0, "st_recliner"],
	["parlour_newspaper", "rig_point", "parlour", 2090, 150, 144, -204, "st_recliner"],
	["parlour_bellows", "rig_point", "parlour", 2330, 170, 200, 0, "st_fireplace"],
	["parlour_chandelier", "rig_point", "parlour", 2330, 180, 150, -420, ""],
	["parlour_chaise_back", "hiding", "parlour", 2580, 200, 170, 0, ""],
	["kitchen_honey", "rig_point", "kitchen", 2950, 150, 170, -60, "st_tea"],
	["kitchen_kettle", "rig_point", "kitchen", 2950, 150, 150, -254, "st_tea"],
	["kitchen_pickle_jar", "rig_point", "kitchen", 3130, 150, 170, -150, "st_pickles"],
	["kitchen_fridge", "container", "kitchen", 3310, 160, 200, 0, ""],
	["kitchen_fridge_shelf", "rig_point", "kitchen", 3310, 160, 150, -224, "st_fridge"],
	["kitchen_table", "hiding", "kitchen", 3480, 160, 170, 0, ""],
	["kitchen_pantry_curtain", "hiding", "kitchen", 3650, 150, 240, 0, ""],
	["kitchen_pantry_shelf", "container", "kitchen", 3650, 150, 150, -264, ""],
	["kitchen_sink_tap", "rig_point", "kitchen", 3810, 144, 190, -40, "st_sink"],
	["kitchen_back_door", "door", "kitchen", 3860, 80, 320, 0, ""],
	["stairs_foot", "stairs", "hall", 1450, 144, 144, -380, ""],
	["stairs_head", "stairs", "landing", 1080, 150, 200, 0, ""],
]
## Stations (TECH §14, GDD §7.1 x): [id, room, x, stand_x, facing, kinds].
const GREYBOX_STATIONS := [
	["st_gramophone", "parlour", 1640, 1720, -1, []],
	["st_piano", "parlour", 1840, 1920, -1, []],
	["st_recliner", "parlour", 2080, 2080, 1, []],
	["st_fireplace", "parlour", 2330, 2260, 1, ["DRY"]],
	["st_chaise", "parlour", 2560, 2560, 1, []],
	["st_tea", "kitchen", 2960, 2900, 1, ["HONEY"]],
	["st_pickles", "kitchen", 3130, 3070, 1, []],
	["st_fridge", "kitchen", 3300, 3240, 1, []],
	["st_sink", "kitchen", 3800, 3740, 1, ["SINK"]],
	["st_hall_mirror", "hall", 1160, 1080, 1, ["MIRROR"]],
	["st_phone", "hall", 980, 930, 1, []],
	["st_clock", "hall", 1340, 1280, 1, []],
	["st_front_door", "hall", 520, 600, -1, []],
]


class Room:
	var id: String = ""
	var floor: int = 0
	var x0: float = 0.0
	var x1: float = 0.0
	var outdoor: bool = false
	var wallpaper: Color = Color("#C8C0B0")
	var art_bg: String = ""
	var art_fg: String = ""

	func width() -> float:
		return x1 - x0


class Link:
	var id: String = ""
	var kind: String = "doorway"
	var a: String = ""
	var b: String = ""
	var x: float = 0.0
	var ax: float = 0.0
	var bx: float = 0.0
	var art: String = ""


class Hotspot:
	var id: String = ""
	var kind: String = ""
	var room: String = ""
	var use_x: float = 0.0
	var facing: int = 1
	## Absolute world rect (hit box).
	var rect: Rect2 = Rect2()
	var art: Dictionary = {}
	## house.json `art_pos` (world x, absolute y) and `art_size` of the prop sprite, when given.
	var art_pos: Vector2 = Vector2.INF
	var art_size: Vector2 = Vector2.ZERO
	var station: String = ""
	var in_use_by: String = ""
	var link: String = ""


class Station:
	var id: String = ""
	var room: String = ""
	var x: float = 0.0
	var stand_x: float = 0.0
	var facing: int = 1
	var kinds: PackedStringArray = PackedStringArray()


var id: String = "humdrum_7"
var floor_pitch: float = 700.0
var interior_h: float = 640.0
var slab_h: float = 60.0
var rooms: Array[Room] = []
var links: Array[Link] = []
var hotspots: Array[Hotspot] = []
var stations: Array[Station] = []
var room_by_id: Dictionary = {}
var hotspot_by_id: Dictionary = {}
var station_by_id: Dictionary = {}
## room → {name: x} reaction landing targets; room → [{prop, x}] quake props; entries.
var landings: Dictionary = {}
var quake_props: Dictionary = {}
var entries: Dictionary = {}
## "json" | "db" | "greybox".
var source: String = "greybox"
var _dist: Dictionary = {}


## GDD §7.1 room ids in layout order.
static func default_room_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in GREYBOX_ROOMS:
		out.append(ViewKit.s(r[0]))
	return out


## The house the game ships with: house.json when present, else the greybox.
static func load_default() -> HouseLayout:
	var d: Variant = ViewKit.json(HOUSE_JSON)
	if d is Dictionary and (d as Dictionary).has("rooms"):
		var h := HouseLayout.from_json(d)
		if not h.rooms.is_empty():
			return h
	return HouseLayout.greybox()


## A HouseLayout from whatever the caller has: a HouseLayout, a house.json Dictionary, a
## ContentDB (reads `house`) or a HouseDef-like object, else load_default().
static func from_any(v: Variant) -> HouseLayout:
	if v is HouseLayout:
		return v
	if v is Dictionary and (v as Dictionary).has("rooms"):
		return HouseLayout.from_json(v)
	if v is Object:
		var o: Object = v
		var house: Variant = o.get("house")
		if house is Object:
			o = house
		var h := HouseLayout.from_object(o)
		if not h.rooms.is_empty():
			return h
	return HouseLayout.load_default()


## Parse a house.json Dictionary (TECH §4.1).
static func from_json(d: Dictionary) -> HouseLayout:
	var h := HouseLayout.new()
	h.source = "json"
	h.id = ViewKit.s(d.get("id", h.id))
	h.floor_pitch = float(d.get("floor_pitch", 700))
	h.interior_h = float(d.get("interior_h", 640))
	h.slab_h = float(d.get("slab_h", 60))
	for rv in d.get("rooms", []):
		var rd: Dictionary = rv
		var r := Room.new()
		r.id = ViewKit.s(rd.get("id", ""))
		r.floor = int(rd.get("floor", 0))
		r.x0 = float(rd.get("x0", 0))
		r.x1 = float(rd.get("x1", 0))
		r.outdoor = bool(rd.get("outdoor", false))
		r.wallpaper = Color(ViewKit.s(rd.get("wallpaper", "#C8C0B0")))
		var art: Dictionary = rd.get("art", {}) if rd.get("art", {}) is Dictionary else {}
		r.art_bg = ViewKit.s(art.get("bg", ""))
		r.art_fg = ViewKit.s(art.get("fg", ""))
		h._add_room(r)
	for lv in d.get("links", []):
		var ld: Dictionary = lv
		var l := Link.new()
		l.id = ViewKit.s(ld.get("id", ""))
		l.kind = ViewKit.s(ld.get("kind", "doorway"))
		l.a = ViewKit.s(ld.get("a", ""))
		l.b = ViewKit.s(ld.get("b", ""))
		l.x = float(ld.get("x", ld.get("ax", 0)))
		l.ax = float(ld.get("ax", l.x))
		l.bx = float(ld.get("bx", l.x))
		l.art = ViewKit.s(ld.get("art", "")) if ld.get("art", null) is String else ""
		h.links.append(l)
	for sv in d.get("stations", []):
		var sd: Dictionary = sv
		var s := Station.new()
		s.id = ViewKit.s(sd.get("id", ""))
		s.room = ViewKit.s(sd.get("room", ""))
		s.x = float(sd.get("x", 0))
		s.stand_x = float(sd.get("stand_x", s.x))
		s.facing = int(sd.get("facing", 1))
		for k in sd.get("kinds", []):
			s.kinds.append(ViewKit.s(k))
		h._add_station(s)
	for hv in d.get("hotspots", []):
		var hd: Dictionary = hv
		var hs := Hotspot.new()
		hs.id = ViewKit.s(hd.get("id", ""))
		hs.kind = ViewKit.s(hd.get("kind", ""))
		hs.room = ViewKit.s(hd.get("room", ""))
		hs.use_x = float(hd.get("use_x", 0))
		hs.facing = int(hd.get("facing", 1))
		var fy := h.room_floor_y(hs.room)
		var rr: Array = hd.get("rect", [hs.use_x - 72, -144, 144, 144])
		if rr.size() >= 4:
			hs.rect = Rect2(float(rr[0]), float(rr[1]) + fy, float(rr[2]), float(rr[3]))
		hs.art = hd.get("art", {}) if hd.get("art", {}) is Dictionary else {}
		var ap: Variant = hd.get("art_pos", null)
		if ap is Array and (ap as Array).size() >= 2:
			hs.art_pos = Vector2(float(ap[0]), float(ap[1]) + fy)
		var asz: Variant = hd.get("art_size", null)
		if asz is Array and (asz as Array).size() >= 2:
			hs.art_size = Vector2(float(asz[0]), float(asz[1]))
		hs.station = ViewKit.s(hd.get("station", "")) if hd.get("station", null) != null else ""
		hs.in_use_by = ViewKit.s(hd.get("in_use_by", "")) if hd.get("in_use_by", null) != null else ""
		hs.link = ViewKit.s(hd.get("link", "")) if hd.get("link", null) != null else ""
		h._add_hotspot(hs)
	h.landings = d.get("landings", {}) if d.get("landings", {}) is Dictionary else {}
	h.quake_props = d.get("quake_props", {}) if d.get("quake_props", {}) is Dictionary else {}
	h.entries = d.get("entries", {}) if d.get("entries", {}) is Dictionary else {}
	return h


## Read a HouseDef-like object (the sim's typed defs; soft — field names per TECH §4.1).
## Falls back to house.json when the object's shape is unknown.
static func from_object(o: Object) -> HouseLayout:
	var rooms_v: Variant = o.get("rooms")
	if rooms_v == null:
		return HouseLayout.new()
	# The sim loads house.json itself; reading the JSON file keeps the two views identical
	# without depending on the def classes' internals.
	var d: Variant = ViewKit.json(HOUSE_JSON)
	if d is Dictionary:
		var h := HouseLayout.from_json(d)
		h.source = "db"
		return h
	return HouseLayout.greybox()


## The GDD §7.1 greybox house with the TECH §14 slice hotspots.
static func greybox() -> HouseLayout:
	var h := HouseLayout.new()
	h.source = "greybox"
	for rv in GREYBOX_ROOMS:
		var r := Room.new()
		r.id = ViewKit.s(rv[0])
		r.floor = int(rv[1])
		r.x0 = float(rv[2])
		r.x1 = float(rv[3])
		r.outdoor = bool(rv[4])
		r.wallpaper = Color(ViewKit.s(rv[5]))
		h._add_room(r)
	for lv in GREYBOX_LINKS:
		var l := Link.new()
		l.id = ViewKit.s(lv[0])
		l.kind = ViewKit.s(lv[1])
		l.a = ViewKit.s(lv[2])
		l.b = ViewKit.s(lv[3])
		l.x = float(lv[4])
		l.ax = float(lv[4])
		l.bx = float(lv[5]) if lv.size() > 5 else float(lv[4])
		h.links.append(l)
	for sv in GREYBOX_STATIONS:
		var s := Station.new()
		s.id = ViewKit.s(sv[0])
		s.room = ViewKit.s(sv[1])
		s.x = float(sv[2])
		s.stand_x = float(sv[3])
		s.facing = int(sv[4])
		for k in sv[5]:
			s.kinds.append(ViewKit.s(k))
		h._add_station(s)
	for hv in GREYBOX_HOTSPOTS:
		var hs := Hotspot.new()
		hs.id = ViewKit.s(hv[0])
		hs.kind = ViewKit.s(hv[1])
		hs.room = ViewKit.s(hv[2])
		hs.use_x = float(hv[3])
		var w := float(hv[4])
		var hh := float(hv[5])
		var yo := float(hv[6])
		var fy := h.room_floor_y(hs.room)
		hs.rect = Rect2(hs.use_x - w * 0.5, fy + yo - hh, w, hh)
		var extra := ViewKit.s(hv[7])
		if hs.kind == "rig_point":
			hs.station = extra
		elif hs.kind == "hiding":
			hs.in_use_by = extra
		if hs.kind == "stairs":
			hs.link = "stairs"
		h._add_hotspot(hs)
	h.landings = {"kitchen": {"sink": 3760, "table": 3470}, "parlour": {"log_basket": 2380, "chandelier": 2330},
		"hall": {"coat_stand": 660, "umbrella_stand": 1420, "front_door": 540}}
	h.quake_props = {"parlour": [{"prop": "picture_frame", "x": 2150}, {"prop": "vase", "x": 2330}, {"prop": "portrait", "x": 1960}],
		"kitchen": [{"prop": "pans", "x": 3050}], "hall": [{"prop": "hats", "x": 660}]}
	h.entries = {"window": {"room": "kitchen", "x": 3800}, "gate": {"room": "garden", "x": 6150},
		"doorstep": {"room": "porch", "x": 350}}
	return h


func _add_room(r: Room) -> void:
	rooms.append(r)
	room_by_id[r.id] = r


func _add_station(s: Station) -> void:
	stations.append(s)
	station_by_id[s.id] = s


func _add_hotspot(hs: Hotspot) -> void:
	hotspots.append(hs)
	hotspot_by_id[hs.id] = hs


func room(id_: String) -> Room:
	return room_by_id.get(id_, null)


func hotspot(id_: String) -> Hotspot:
	return hotspot_by_id.get(id_, null)


func station(id_: String) -> Station:
	return station_by_id.get(id_, null)


## World y of a floor's line (TECH §2).
func floor_y(floor: int) -> float:
	return -floor_pitch * float(floor)


func room_floor_y(room_id: String) -> float:
	var r := room(room_id)
	return floor_y(r.floor) if r != null else 0.0


## Room on `floor` containing x (nearest room on that floor when between rooms).
func room_at(floor: int, x: float) -> String:
	var best := ""
	var best_d := INF
	for r in rooms:
		if r.floor != floor:
			continue
		if x >= r.x0 and x <= r.x1:
			return r.id
		var d := minf(absf(x - r.x0), absf(x - r.x1))
		if d < best_d:
			best_d = d
			best = r.id
	return best


## Number of floors (1 + highest floor index).
func floor_count() -> int:
	var n := 0
	for r in rooms:
		n = maxi(n, r.floor + 1)
	return n


## World x range of all rooms.
func x_range() -> Vector2:
	var lo := INF
	var hi := -INF
	for r in rooms:
		lo = minf(lo, r.x0)
		hi = maxf(hi, r.x1)
	return Vector2(lo, hi) if lo < hi else Vector2(0, 6200)


## Camera bounds: every room plus the flies above the top floor and the apron below the
## ground floor (GDD §3.7: limits = house bounds).
func bounds() -> Rect2:
	var xr := x_range()
	var top := floor_y(floor_count() - 1) - interior_h - FLIES_H
	var bottom := slab_h + APRON_H
	return Rect2(xr.x, top, xr.y - xr.x, bottom - top)


## Room ids sorted (the sim's interning order).
func sorted_room_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in rooms:
		out.append(r.id)
	out.sort()
	return out


## Links touching a room.
func links_of(room_id: String) -> Array[Link]:
	var out: Array[Link] = []
	for l in links:
		if l.a == room_id or l.b == room_id:
			out.append(l)
	return out


## Rooms between a and b in link hops (0 same room, −1 unreachable). Cached BFS.
func room_distance(a: String, b: String) -> int:
	if a == b:
		return 0
	var key := a + "|" + b
	if _dist.has(key):
		return _dist[key]
	var seen := {a: 0}
	var q: Array[String] = [a]
	var out := -1
	while not q.is_empty():
		var cur: String = q.pop_front()
		var dcur: int = seen[cur]
		for l in links_of(cur):
			var nxt := l.b if l.a == cur else l.a
			if seen.has(nxt):
				continue
			seen[nxt] = dcur + 1
			if nxt == b:
				out = dcur + 1
				q.clear()
				break
			q.append(nxt)
	_dist[key] = out
	_dist[b + "|" + a] = out
	return out


## The link joining two rooms directly (null if none).
func link_between(a: String, b: String) -> Link:
	for l in links:
		if (l.a == a and l.b == b) or (l.a == b and l.b == a):
			return l
	return null


## Nearest station of `kind` (fix-up kinds) on `floor`; "" when none.
func station_of_kind(kind: String, floor: int, x: float) -> String:
	var best := ""
	var bd := INF
	for s in stations:
		if not s.kinds.has(kind):
			continue
		var r := room(s.room)
		if r == null or r.floor != floor:
			continue
		var d := absf(s.x - x)
		if d < bd:
			bd = d
			best = s.id
	return best
