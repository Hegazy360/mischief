## RoomBackdrop — a house.json room drawn behind (or, as the front layer, over) a dev-scene
## rig at game scale (1 world px = 1 house px, the floor at y = 0), so an animator judges
## contrast and staging in the real set: the room's background art, every hotspot's idle
## sprite, the decor sprites (shown / hidden by the clip's `decor` events) and, on the front
## layer, the foreground art (door jambs, slab lip) plus decor / hotspots with `z` ≥ 2 (the
## kitchen sink lip he lands behind). The other rooms of the same floor are drawn too, so a
## 20:9 frame is filled the way the game fills it.
##   var back := RoomBackdrop.new(); back.setup("kitchen")                 # behind the rigs
##   var front := RoomBackdrop.new(); front.setup("kitchen", true)         # over them
## Pure drawing (Node2D, `_draw`); textures via HiResTex (sharp 2× art).
extends Node2D

const HOUSE := "res://data/house/house.json"
const FRONT_Z := 2
const INTERIOR_H := 640.0
const SLAB_H := 60.0

## The room in focus, its floor index, whether this node is the front layer.
var room_id: String = ""
var floor_i: int = 0
var front: bool = false
## World-x extent of the focus room.
var x0: float = 0.0
var x1: float = 1000.0

var _rooms: Array = []     ## [{id, x0, x1, bg, fg, pos, size, wall}]
var _sprites: Array = []   ## [{id, tex, rect, z, decor, hidden}]
var _stations: Dictionary = {}
var _hidden: Dictionary = {}   ## decor id → true while hidden


## Parsed house.json ({} when missing).
static func load_house() -> Dictionary:
	if not FileAccess.file_exists(HOUSE):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(HOUSE)) != OK:
		push_warning("RoomBackdrop: %s: %s" % [HOUSE, j.get_error_message()])
		return {}
	return j.data if j.data is Dictionary else {}


## Room ids of house.json (in file order).
static func room_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var rv: Variant = load_house().get("rooms", [])
	if rv is Array:
		for r in rv:
			if r is Dictionary:
				out.append(str((r as Dictionary).get("id", "")))
	return out


## Build for `room`; false when the room is unknown. `is_front` = the layer over the rigs.
func setup(room: String, is_front: bool = false) -> bool:
	room_id = room
	front = is_front
	z_index = 20 if front else -20
	_rooms.clear()
	_sprites.clear()
	_stations.clear()
	var h := load_house()
	var rv: Variant = h.get("rooms", [])
	var found := false
	if rv is Array:
		for r in rv:
			if r is Dictionary and str((r as Dictionary).get("id", "")) == room:
				floor_i = int((r as Dictionary).get("floor", 0))
				x0 = float((r as Dictionary).get("x0", 0))
				x1 = float((r as Dictionary).get("x1", 1000))
				found = true
	if not found:
		push_warning("RoomBackdrop: room '%s' is not in %s" % [room, HOUSE])
		return false
	var on_floor := {}
	for r2 in rv:
		if not (r2 is Dictionary) or int((r2 as Dictionary).get("floor", 0)) != floor_i:
			continue
		var rd: Dictionary = r2
		var art: Dictionary = rd.get("art", {}) if rd.get("art", {}) is Dictionary else {}
		on_floor[str(rd.get("id", ""))] = true
		_rooms.append({"id": str(rd.get("id", "")), "x0": float(rd.get("x0", 0)), "x1": float(rd.get("x1", 0)),
			"bg": _tex(str(art.get("bg", ""))), "fg": _tex(str(art.get("fg", ""))),
			"pos": _v2(art.get("pos", [rd.get("x0", 0), -INTERIOR_H])), "size": _v2(art.get("size", [float(rd.get("x1", 0)) - float(rd.get("x0", 0)), 700])),
			"wall": Color.from_string(str(rd.get("wallpaper", "#C9B8A0")), Color("#C9B8A0"))})
	var hv: Variant = h.get("hotspots", [])
	if hv is Array:
		for hs in hv:
			if not (hs is Dictionary) or not on_floor.has(str((hs as Dictionary).get("room", ""))):
				continue
			var hd: Dictionary = hs
			var art2: Dictionary = hd.get("art", {}) if hd.get("art", {}) is Dictionary else {}
			var p := str(art2.get("idle", ""))
			if p == "" or not hd.has("art_pos"):
				continue
			_sprites.append({"id": str(hd.get("id", "")), "tex": _tex(p), "rect": Rect2(_v2(hd["art_pos"]), _v2(hd.get("art_size", [0, 0]))),
				"z": int(hd.get("z", 0)), "decor": false})
	var dv: Variant = h.get("decor", [])
	if dv is Array:
		for de in dv:
			if not (de is Dictionary) or not on_floor.has(str((de as Dictionary).get("room", ""))):
				continue
			var dd: Dictionary = de
			var art3: Dictionary = dd.get("art", {}) if dd.get("art", {}) is Dictionary else {}
			var p2 := str(art3.get("idle", ""))
			if p2 == "":
				continue
			var id := str(dd.get("id", ""))
			_sprites.append({"id": id, "tex": _tex(p2), "rect": Rect2(_v2(dd.get("pos", [0, 0])), _v2(dd.get("size", [0, 0]))),
				"z": int(dd.get("z", 0)), "decor": true})
			if bool(dd.get("hidden", false)):
				_hidden[id] = true
	_sprites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["z"]) < int(b["z"]))
	var sv: Variant = h.get("stations", [])
	if sv is Array:
		for st in sv:
			if st is Dictionary:
				_stations[str((st as Dictionary).get("id", ""))] = st
	queue_redraw()
	return true


## Show / hide a decor sprite (a clip's `decor` event).
func set_decor_visible(id: String, on: bool) -> void:
	if on:
		_hidden.erase(id)
	else:
		_hidden[id] = true
	queue_redraw()


## True while decor `id` is shown.
func decor_visible(id: String) -> bool:
	return not _hidden.has(id)


## A station's stand x (or x) in world px; NAN when unknown.
func station_x(station: String) -> float:
	var s: Variant = _stations.get(station, null)
	if not (s is Dictionary):
		return NAN
	return float((s as Dictionary).get("stand_x", (s as Dictionary).get("x", 0)))


## A station's facing (±1; 1 when unknown).
func station_facing(station: String) -> int:
	var s: Variant = _stations.get(station, null)
	return -1 if s is Dictionary and int((s as Dictionary).get("facing", 1)) < 0 else 1


## The focus room's centre x.
func centre_x() -> float:
	return (x0 + x1) * 0.5


func _draw() -> void:
	if not front:
		for r in _rooms:
			var rd: Dictionary = r
			draw_rect(Rect2(float(rd["x0"]), -INTERIOR_H, float(rd["x1"]) - float(rd["x0"]), INTERIOR_H + SLAB_H), rd["wall"])
			if rd["bg"] != null:
				draw_texture_rect(rd["bg"], Rect2(rd["pos"], rd["size"]), false)
	for s in _sprites:
		var sd: Dictionary = s
		if (int(sd["z"]) >= FRONT_Z) != front:
			continue
		if bool(sd["decor"]) and _hidden.has(String(sd["id"])):
			continue
		if sd["tex"] != null:
			draw_texture_rect(sd["tex"], sd["rect"], false)
	if front:
		for r2 in _rooms:
			var rd2: Dictionary = r2
			if rd2["fg"] != null:
				draw_texture_rect(rd2["fg"], Rect2(rd2["pos"], rd2["size"]), false)


static func _tex(p: String) -> Texture2D:
	if p == "" or not (FileAccess.file_exists(p) or ResourceLoader.exists(p)):
		return null
	return HiResTex.get_texture(p)


static func _v2(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO
