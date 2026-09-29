## HouseDef — house.json: rooms, links, stations, hotspots, landings, quake props, entries (TECH §4.1).
##
## Every list is sorted by id; `idx` fields are positions in those lists (the interned ids).
class_name HouseDef
extends RefCounted

var id: String = ""
var floor_pitch: int = 700
var interior_h: int = 640
var slab_h: int = 60
## [{index, y}] as in the JSON.
var floors: Array = []
var rooms: Array[RoomDef] = []
var links: Array[LinkDef] = []
var stations: Array[StationDef] = []
var hotspots: Array[HotspotDef] = []
## room id → {name: x px}
var landings: Dictionary = {}
## room id → [{prop, x}]
var quake_props: Dictionary = {}
## entry name → {room, x}
var entries: Dictionary = {}

var room_index: Dictionary = {}
var link_index: Dictionary = {}
var station_index: Dictionary = {}
var hotspot_index: Dictionary = {}
## Links touching each room (room idx → PackedInt32Array of link idx, sorted).
var room_links: Array[PackedInt32Array] = []
## Fix-up kind → PackedInt32Array of station idx (sorted by id).
var stations_by_kind: Dictionary = {}


## Parse house.json. Structural problems are appended to `errs`.
static func from_dict(d: Dictionary, errs: PackedStringArray) -> HouseDef:
	var h := HouseDef.new()
	h.id = ContentUtil.s(d, "id")
	h.floor_pitch = ContentUtil.i(d, "floor_pitch", 700)
	h.interior_h = ContentUtil.i(d, "interior_h", 640)
	h.slab_h = ContentUtil.i(d, "slab_h", 60)
	h.floors = ContentUtil.arr(d, "floors")
	h.landings = ContentUtil.dict(d, "landings")
	h.quake_props = ContentUtil.dict(d, "quake_props")
	h.entries = ContentUtil.dict(d, "entries")
	var floor_y := {}
	for fl in h.floors:
		if typeof(fl) == TYPE_DICTIONARY:
			floor_y[ContentUtil.i(fl, "index")] = ContentUtil.i(fl, "y")
	for e in ContentUtil.arr(d, "rooms"):
		if typeof(e) != TYPE_DICTIONARY:
			errs.append("house.json: rooms entry is not an object")
			continue
		var r := RoomDef.from_dict(e)
		r.floor_y = int(floor_y.get(r.floor, -h.floor_pitch * r.floor))
		h.rooms.append(r)
	h.rooms.sort_custom(func(p: RoomDef, q: RoomDef) -> bool: return p.id < q.id)
	for e in ContentUtil.arr(d, "links"):
		if typeof(e) != TYPE_DICTIONARY:
			errs.append("house.json: links entry is not an object")
			continue
		h.links.append(LinkDef.from_dict(e))
	h.links.sort_custom(func(p: LinkDef, q: LinkDef) -> bool: return p.id < q.id)
	for e in ContentUtil.arr(d, "stations"):
		if typeof(e) != TYPE_DICTIONARY:
			errs.append("house.json: stations entry is not an object")
			continue
		h.stations.append(StationDef.from_dict(e))
	h.stations.sort_custom(func(p: StationDef, q: StationDef) -> bool: return p.id < q.id)
	for e in ContentUtil.arr(d, "hotspots"):
		if typeof(e) != TYPE_DICTIONARY:
			errs.append("house.json: hotspots entry is not an object")
			continue
		h.hotspots.append(HotspotDef.from_dict(e))
	h.hotspots.sort_custom(func(p: HotspotDef, q: HotspotDef) -> bool: return p.id < q.id)
	h._index(errs)
	return h


func _index(errs: PackedStringArray) -> void:
	for i in rooms.size():
		rooms[i].idx = i
		if room_index.has(rooms[i].id):
			errs.append("house.json: duplicate room id '%s'" % rooms[i].id)
		room_index[rooms[i].id] = i
	room_links.resize(rooms.size())
	for i in rooms.size():
		room_links[i] = PackedInt32Array()
	for i in links.size():
		var l := links[i]
		l.idx = i
		if link_index.has(l.id):
			errs.append("house.json: duplicate link id '%s'" % l.id)
		link_index[l.id] = i
		l.a_idx = int(room_index.get(l.a, -1))
		l.b_idx = int(room_index.get(l.b, -1))
		if l.a_idx >= 0:
			room_links[l.a_idx].append(i)
		if l.b_idx >= 0 and l.b_idx != l.a_idx:
			room_links[l.b_idx].append(i)
	for i in stations.size():
		var s := stations[i]
		s.idx = i
		if station_index.has(s.id):
			errs.append("house.json: duplicate station id '%s'" % s.id)
		station_index[s.id] = i
		s.room_idx = int(room_index.get(s.room, -1))
		for k in s.kinds:
			if not stations_by_kind.has(k):
				stations_by_kind[k] = PackedInt32Array()
			var arr: PackedInt32Array = stations_by_kind[k]
			arr.append(i)
			stations_by_kind[k] = arr
	for i in hotspots.size():
		var hs := hotspots[i]
		hs.idx = i
		if hotspot_index.has(hs.id):
			errs.append("house.json: duplicate hotspot id '%s'" % hs.id)
		hotspot_index[hs.id] = i
		hs.room_idx = int(room_index.get(hs.room, -1))
		hs.station_idx = int(station_index.get(hs.station, -1))
		hs.link_idx = int(link_index.get(hs.link, -1))


## Room by id (null if missing).
func room(room_id: String) -> RoomDef:
	var i: int = room_index.get(room_id, -1)
	return rooms[i] if i >= 0 else null


## Hotspot by id (null if missing).
func hotspot(hotspot_id: String) -> HotspotDef:
	var i: int = hotspot_index.get(hotspot_id, -1)
	return hotspots[i] if i >= 0 else null


## Station by id (null if missing).
func station(station_id: String) -> StationDef:
	var i: int = station_index.get(station_id, -1)
	return stations[i] if i >= 0 else null


## Room idx containing x_sub on `floor` (-1 if none). Boundaries resolve to the lower-x room.
func room_at(floor_i: int, x_sub: int) -> int:
	for r in rooms:
		if r.floor == floor_i and x_sub >= r.x0_sub and x_sub <= r.x1_sub:
			return r.idx
	return -1


## Landing x (sub-px) for `room_id` / `name`, or -1.
func landing_sub(room_id: String, landing_name: String) -> int:
	var d: Variant = landings.get(room_id, null)
	if typeof(d) != TYPE_DICTIONARY or not (d as Dictionary).has(landing_name):
		return -1
	return Fx.px(float((d as Dictionary)[landing_name]))
