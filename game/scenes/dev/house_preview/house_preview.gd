## HousePreview — dev scene (art-house): builds the whole house straight from
## res://data/house/house.json with plain Sprite2D nodes (rooms bg/fg, hotspot props in a chosen
## state + their pre-baked outline sprites, decor, the stage set pieces, apron, footlights, flies,
## proscenium) and frames it like the game camera: at zoom 1.0 one floor (640 interior + 60 slab)
## fills the 1080 px height with 190 px of the floors above and below showing (GDD §3.7).
##
## User args (after `--`):
##   --room=<id>          room to frame (default kitchen)
##   --zoom=1.0|0.5       camera zoom (0.5 = Overview)
##   --x=<px>             camera centre x override (world px)
##   --state=<s>          idle | rigged | occupied | open | spent (falls back to idle per prop)
##   --rects              draw every hit box (+ id labels) and use points
##   --badges             draw mock 56 px badges above the framed room's hotspots
##   --outline            show the pulsing outline sprites for the framed room
##   --locked=a,b         draw those rooms as the unlit set (dim blue-grey) + velvet ropes
##   --chars              mock Bellows / Hush silhouettes at their real sizes (scale check)
## Not exported (scenes/dev/ is filtered out of release builds).
extends Node2D

const HOUSE_PATH := "res://data/house/house.json"
const OUTLINE_COL := Color(1.0, 0.93, 0.62)
const LOCKED_TINT := Color(0.46, 0.5, 0.68)
const FLOOR_Y := {0: 0.0, 1: -700.0}

var house: Dictionary = {}
var room_id: String = "kitchen"
var zoom: float = 1.0
var state: String = "idle"
var show_rects: bool = false
var show_badges: bool = false
var show_outline: bool = false
var show_chars: bool = false
var locked: PackedStringArray = PackedStringArray()
var cam_x_override: float = NAN

var _rooms: Dictionary = {}
var _outlines: Array[Sprite2D] = []
var _t: float = 0.0
var _overlay: Node2D
var _layers: Dictionary = {}
var _font: Font


func _ready() -> void:
	_parse_args(OS.get_cmdline_user_args())
	house = _load_house()
	if house.is_empty():
		push_error("HousePreview: could not load %s" % HOUSE_PATH)
		return
	for r in house.get("rooms", []):
		_rooms[r["id"]] = r
	if not _rooms.has(room_id):
		room_id = "kitchen"
	_font = ThemeDB.fallback_font
	for layer_name in ["stage_back", "pieces", "rooms", "decor_back", "outlines", "props", "props_front", "decor_front", "chars", "fg", "overlay"]:
		var n := Node2D.new()
		n.name = layer_name
		add_child(n)
		_layers[layer_name] = n
	_build_stage()
	_build_rooms()
	_build_decor()
	_build_props()
	if show_chars:
		(_layers["chars"] as Node2D).draw.connect(_draw_chars)
		(_layers["chars"] as Node2D).queue_redraw()
	_overlay = _layers["overlay"]
	_overlay.draw.connect(_draw_overlay)
	_overlay.queue_redraw()
	_setup_camera()


func _process(delta: float) -> void:
	_t += delta
	# outline pulse: alpha 0.6 <-> 1.0 at 1.2 Hz (GDD §3.5)
	var a := 0.8 + 0.2 * sin(_t * TAU * 1.2)
	for s in _outlines:
		s.modulate = Color(OUTLINE_COL.r, OUTLINE_COL.g, OUTLINE_COL.b, a)


## Parses the `--key=value` user args (see the header).
func _parse_args(args: PackedStringArray) -> void:
	for a in args:
		if a.begins_with("--room="):
			room_id = a.substr(7)
		elif a.begins_with("--zoom="):
			zoom = clampf(float(a.substr(7)), 0.25, 2.0)
		elif a.begins_with("--state="):
			state = a.substr(8)
		elif a.begins_with("--x="):
			cam_x_override = float(a.substr(4))
		elif a.begins_with("--locked="):
			locked = a.substr(9).split(",", false)
		elif a == "--rects":
			show_rects = true
		elif a == "--badges":
			show_badges = true
		elif a == "--outline":
			show_outline = true
		elif a == "--chars":
			show_chars = true


func _load_house() -> Dictionary:
	if not FileAccess.file_exists(HOUSE_PATH):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(HOUSE_PATH)) != OK:
		push_error("HousePreview: %s line %d: %s" % [HOUSE_PATH, j.get_error_line(), j.get_error_message()])
		return {}
	return j.data as Dictionary


func _tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		push_warning("HousePreview: missing texture %s" % path)
		return null
	return load(path) as Texture2D


func _sprite(layer: String, path: String, pos: Vector2, tint: Color = Color.WHITE) -> Sprite2D:
	var tex := _tex(path)
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.modulate = tint
	(_layers[layer] as Node2D).add_child(s)
	return s


func _floor_y(room: String) -> float:
	var r: Dictionary = _rooms.get(room, {})
	return float(FLOOR_Y.get(int(r.get("floor", 0)), 0.0))


func _tint(room: String) -> Color:
	return LOCKED_TINT if locked.has(room) else Color.WHITE


func _v2(a: Variant) -> Vector2:
	var arr: Array = a
	return Vector2(float(arr[0]), float(arr[1]))


# ------------------------------------------------------------------------------ building

func _build_stage() -> void:
	var st: Dictionary = house.get("stage", {})
	if st.is_empty():
		return
	var flies: Dictionary = st.get("flies", {})
	if not flies.is_empty():
		var tw := float(flies["tile_x"])
		var y := float(flies["bottom_y"]) - float(flies["size"][1])
		var x := float(flies["x0"])
		while x < float(flies["x1"]):
			_sprite("stage_back", flies["art"], Vector2(x, y))
			x += tw
	var apron: Dictionary = st.get("apron", {})
	if not apron.is_empty():
		var x := float(apron["x0"])
		while x < float(apron["x1"]):
			_sprite("stage_back", apron["art"], Vector2(x, float(apron["top_y"])))
			x += float(apron["tile_x"])
	for piece in st.get("pieces", []):
		_sprite("pieces", piece["art"], _v2(piece["world_pos"]))
	for key in ["proscenium_l", "proscenium_r"]:
		if st.has(key):
			_sprite("fg", st[key]["art"], _v2(st[key]["world_pos"]))
	var glow: Dictionary = st.get("footlight_glow", {})
	if not glow.is_empty():
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var gw := float(glow["size"][0])
		var gh := float(glow["size"][1])
		var x := float(glow["first_x"])
		while x < float(glow["x1"]):
			var s := _sprite("fg", glow["art"], Vector2(x - gw * 0.5, float(glow["bottom_y"]) - gh), Color(1, 1, 1, 0.55))
			if s:
				s.material = mat
			x += float(glow["every_px"])


func _build_rooms() -> void:
	for r in house.get("rooms", []):
		var fy := _floor_y(r["id"])
		var art: Dictionary = r.get("art", {})
		var pos := Vector2(float(r["x0"]), fy + float(art.get("pos", [0, -640])[1]))
		_sprite("rooms", art.get("bg", ""), pos, _tint(r["id"]))
		_sprite("fg", art.get("fg", ""), pos, _tint(r["id"]))
	# velvet ropes across doorways between an unlocked and a locked room
	if locked.is_empty():
		return
	var rope: Dictionary = house.get("stage", {}).get("velvet_rope", {})
	if rope.is_empty():
		return
	for l in house.get("links", []):
		if not (l.has("x") and _rooms.has(l["a"]) and _rooms.has(l["b"])):
			continue
		if locked.has(l["a"]) != locked.has(l["b"]):
			var anchor := _v2(rope.get("anchor", [100, 176]))
			_sprite("props_front", rope["art"], Vector2(float(l["x"]), _floor_y(l["a"])) - anchor)


func _build_decor() -> void:
	for d in house.get("decor", []):
		if d.get("hidden", false):
			continue
		var layer := "decor_back" if int(d.get("z", 0)) < 0 else "decor_front"
		var art: Dictionary = d.get("art", {})
		var p: String = art.get(state, art.get("idle", ""))
		_sprite(layer, p, Vector2(float(d["pos"][0]), _floor_y(d["room"]) + float(d["pos"][1])), _tint(d["room"]))


func _build_props() -> void:
	for h in house.get("hotspots", []):
		if not h.has("art"):
			continue
		var art: Dictionary = h["art"]
		var pos := Vector2(float(h["art_pos"][0]), _floor_y(h["room"]) + float(h["art_pos"][1]))
		var p: String = art.get(state, art.get("idle", ""))
		var layer := "props_front" if int(h.get("z", 0)) > 0 else "props"
		_sprite(layer, p, pos, _tint(h["room"]))
		if show_outline and h["room"] == room_id and art.has("outline"):
			# the outline canvas is the prop canvas grown 4 px on every side (STYLE §6)
			var o := _sprite("outlines", art["outline"], pos - Vector2(4, 4))
			if o:
				_outlines.append(o)


func _setup_camera() -> void:
	var r: Dictionary = _rooms[room_id]
	var cam := Camera2D.new()
	var cx := (float(r["x0"]) + float(r["x1"])) * 0.5 if is_nan(cam_x_override) else cam_x_override
	# one floor (interior 640 + slab 60) centred: its middle is 290 px above the floor line
	var cy := _floor_y(room_id) - 290.0
	if zoom < 0.75:
		# Overview: both floors + the roof and the apron in view (centre of the stage bounds)
		var b: Array = house.get("stage", {}).get("bounds", [-220, -1640, 6640, 1890])
		cy = float(b[1]) + float(b[3]) * 0.5
	# clamp to the stage bounds like the game camera (limits = house bounds, GDD §3.7)
	var bounds: Array = house.get("stage", {}).get("bounds", [])
	if bounds.size() == 4:
		var half_w := get_viewport_rect().size.x * 0.5 / zoom
		var bx0 := float(bounds[0]) + half_w
		var bx1 := float(bounds[0]) + float(bounds[2]) - half_w
		cx = clampf(cx, bx0, maxf(bx0, bx1))
	cam.position = Vector2(cx, cy)
	cam.zoom = Vector2(zoom, zoom)
	add_child(cam)
	cam.make_current()


# ------------------------------------------------------------------------------ overlays

func _draw_overlay() -> void:
	var fy_room := _floor_y(room_id)
	if show_rects:
		for h in house.get("hotspots", []):
			var fy := _floor_y(h["room"])
			var rc: Array = h["rect"]
			var rr := Rect2(float(rc[0]), fy + float(rc[1]), float(rc[2]), float(rc[3]))
			var col := _kind_colour(str(h["kind"]))
			_overlay.draw_rect(rr, Color(col.r, col.g, col.b, 0.16), true)
			_overlay.draw_rect(rr, col, false, 4.0)
			_overlay.draw_line(Vector2(float(h["use_x"]), fy - 14), Vector2(float(h["use_x"]), fy + 14), col, 5.0)
			var label := str(h["id"]).split("_", true, 1)
			var txt: String = label[1] if label.size() > 1 else str(h["id"])
			_overlay.draw_string(_font, rr.position + Vector2(6, 26), txt, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 8, 22, Color.WHITE)
	if show_badges:
		for h in house.get("hotspots", []):
			if h["room"] != room_id:
				continue
			var kind := str(h["kind"])
			if kind in ["exit", "door", "stairs"]:
				continue
			var rc: Array = h["rect"]
			var c := Vector2(float(rc[0]) + float(rc[2]) * 0.5, fy_room + float(rc[1]) - 40.0)
			_draw_badge(c, h)


func _kind_colour(kind: String) -> Color:
	match kind:
		"hiding":
			return Color(0.25, 0.55, 1.0)
		"container":
			return Color(1.0, 0.78, 0.15)
		"rig_point":
			return Color(1.0, 0.36, 0.36)
		_:
			return Color(0.85, 0.85, 0.85)


## A mock 56 px badge: gold = usable, blue closed eye = hiding, red = in use next, grey cloud = needs
## an item (GDD §3.5). The real badges belong to the view task.
func _draw_badge(c: Vector2, h: Dictionary) -> void:
	var kind := str(h["kind"])
	var ink := Color("#1B2340")
	var fill := Color("#E8B33A")
	if kind == "hiding":
		fill = Color("#3E7AE0") if h.get("in_use_by") == null else Color("#E0413E")
	elif kind == "rig_point" and str(h["id"]).ends_with("_kettle"):
		fill = Color("#B9C0CC")    # mock "needs an item" (the squeaker)
	_overlay.draw_circle(c, 31.0, ink)
	_overlay.draw_circle(c, 25.0, fill)
	if kind == "hiding":
		_overlay.draw_arc(c + Vector2(0, -4), 14.0, deg_to_rad(20), deg_to_rad(160), 12, ink, 5.0)
		for dx in [-10.0, 0.0, 10.0]:
			_overlay.draw_line(c + Vector2(dx, 8), c + Vector2(dx * 1.3, 15), ink, 3.0)
	elif fill == Color("#B9C0CC"):
		_overlay.draw_circle(c + Vector2(-7, 2), 8.0, Color.WHITE)
		_overlay.draw_circle(c + Vector2(5, -3), 10.0, Color.WHITE)
		_overlay.draw_circle(c + Vector2(10, 5), 6.0, Color.WHITE)
	else:
		var pts := PackedVector2Array()
		for i in 10:
			var ang := -PI / 2.0 + i * PI / 5.0
			var rad := 15.0 if i % 2 == 0 else 6.5
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
		_overlay.draw_colored_polygon(pts, Color.WHITE)


## Mock silhouettes at the real sizes (Bellows 380 px barrel + bouffant, Hush 340 px) so contrast and
## scale can be judged before the character rigs exist.
func _draw_chars() -> void:
	var n: Node2D = _layers["chars"]
	var fy := _floor_y(room_id)
	var ink := Color("#1B2340")
	var bx := NAN
	for s in house.get("stations", []):
		if s["room"] == room_id:
			bx = float(s["stand_x"])
			break
	if not is_nan(bx):
		n.draw_rect(Rect2(bx - 48, fy - 56, 96, 56), Color("#3A3050"))
		n.draw_circle(Vector2(bx, fy - 170), 104.0, ink)
		n.draw_circle(Vector2(bx, fy - 170), 98.0, Color("#7B3F8C"))
		n.draw_circle(Vector2(bx + 6, fy - 312), 74.0, ink)
		n.draw_circle(Vector2(bx + 6, fy - 312), 68.0, Color("#F4C9A8"))
		n.draw_circle(Vector2(bx, fy - 366), 58.0, ink)
		n.draw_circle(Vector2(bx, fy - 366), 52.0, Color("#D9DCE6"))
		n.draw_colored_polygon(PackedVector2Array([Vector2(bx - 14, fy - 250), Vector2(bx + 14, fy - 250), Vector2(bx, fy - 200)]), Color("#E8B33A"))
	# Hush stands at the room's hotspot furthest from Bellows (so the two never overlap)
	var hx := float(_rooms[room_id]["x0"]) + 170.0
	var best := -1.0
	for h in house.get("hotspots", []):
		if h["room"] == room_id and bool(h.get("tappable", true)):
			var d := absf(float(h["use_x"]) - (bx if not is_nan(bx) else 0.0))
			if d > best:
				best = d
				hx = float(h["use_x"])
	n.draw_rect(Rect2(hx - 34, fy - 250, 68, 196), ink)
	for i in 5:
		n.draw_rect(Rect2(hx - 30, fy - 246 + i * 38, 60, 19), Color("#2B3566") if i % 2 == 0 else Color("#FFF6EA"))
	n.draw_rect(Rect2(hx - 30, fy - 56, 60, 56), Color("#2B3566"))
	n.draw_circle(Vector2(hx, fy - 300), 66.0, ink)
	n.draw_circle(Vector2(hx, fy - 300), 60.0, Color("#FFF6EA"))
	n.draw_circle(Vector2(hx - 20, fy - 306), 11.0, ink)
	n.draw_circle(Vector2(hx + 20, fy - 306), 11.0, ink)
	n.draw_circle(Vector2(hx - 36, fy - 282), 10.0, Color("#FF9AA2"))
	n.draw_circle(Vector2(hx + 36, fy - 282), 10.0, Color("#FF9AA2"))
	n.draw_colored_polygon(PackedVector2Array([Vector2(hx - 70, fy - 352), Vector2(hx + 40, fy - 380), Vector2(hx + 60, fy - 344), Vector2(hx - 50, fy - 330)]),
		Color("#E23B4E"))
	for sx in [-1.0, 1.0]:
		n.draw_circle(Vector2(hx + sx * 62, fy - 150), 26.0, ink)
		n.draw_circle(Vector2(hx + sx * 62, fy - 150), 21.0, Color.WHITE)
