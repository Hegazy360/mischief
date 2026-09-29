## HousePreview — dev scene (art-house / s2-art): builds the whole house straight from
## res://data/house/house.json with plain Sprite2D nodes (rooms bg/fg, hotspot props in a chosen
## state + their pre-baked outline sprites, decor (animated `frames` at their `fps`), the stage set
## pieces, apron, footlights, flies, proscenium) and frames it like the game camera: at zoom 1.0 one
## floor (640 interior + 60 slab) fills the 1080 px height with the floors above and below showing
## (GDD §3.7). It also shows the cold-open sets (res://data/house/cold_sets.json) and the title card.
##
## User args (after `--`):
##   --room=<id>          room to frame (default kitchen)
##   --zoom=1.0|0.5       camera zoom (0.5 = Overview)
##   --x=<px> / --y=<px>  camera centre override (world px)
##   --state=<s>          idle | rigged | occupied | open | spent (falls back to idle per prop)
##   --rects              draw every hit box (+ id labels), use points and hidden-eye points
##   --badges             draw mock 56 px badges above the framed room's hotspots
##   --outline            show the pulsing outline sprites for the framed room
##   --locked=a,b         draw those rooms as the unlit set (dim blue-grey) + velvet ropes
##   --slice=<episode>    shorthand for --locked: every room outside that Night's set (p00, n01, n02)
##   --chars              the REAL Hush and Bellows rigs (RigPlayer static poses) at their usual
##                        stations in the framed room (overrides: --bx= --bpose= --bface= --hx= --hpose=
##                        --hface= --nobellows --nohush)
##   --show=a,b|all       also draw hidden decor (the sink lip, the smashed vase, the door glow)
##   --decor=<id>:<state> draw a decor sprite in a named state (e.g. parlour_picture_frame:falling)
##   --cold=<set>         draw a cold-open set from cold_sets.json (+ --cold_state=<layer>:<state>,…)
##   --title              draw the title card on the curtain (+ --title_scale=0.5 for phone scale)
## Hidden eyes: with --state=occupied every hiding spot gets Hush's animated-eye sprite drawn at its
## `eyes` point exactly as the view will (res://art/chars/hush/hidden_eyes.svg, pivot from rig.json).
## Not exported (scenes/dev/ is filtered out of release builds).
extends Node2D

const HOUSE_PATH := "res://data/house/house.json"
const COLD_PATH := "res://data/house/cold_sets.json"
const TITLE_PATH := "res://art/house/stage/title_card.svg"
const RIG_PLAYER_PATH := "res://view/rig/rig_player.gd"
const HIDDEN_EYES_PATH := "res://art/chars/hush/hidden_eyes.svg"
const HIDDEN_EYES_PIVOT := Vector2(77, 44)
const OUTLINE_COL := Color(1.0, 0.93, 0.62)
const LOCKED_TINT := Color(0.46, 0.5, 0.68)
const FLOOR_Y := {0: 0.0, 1: -700.0}
## Rooms each slice episode opens (everything else is the unlit set).
const SLICE_ROOMS := {"p00": ["parlour", "kitchen"], "n01": ["hall", "parlour", "kitchen", "porch"],
	"n02": ["hall", "parlour", "kitchen", "porch"]}
## Usual placements with the real characters: Bellows = [station, pose], Hush = [x, pose, facing].
const CHAR_SETUPS := {
	"kitchen": {"bellows": ["st_tea", "b_tea_sip"], "hush": [3620.0, "h_snicker_a", -1]},
	"parlour": {"bellows": ["st_gramophone", "b_sing_big"], "hush": [2040.0, "h_tinker_s_a", -1]},
	"hall": {"bellows": ["st_hall_mirror", "b_preen"], "hush": [1290.0, "h_freeze_3", -1]},
	"porch": {"bellows": ["st_front_door", "b_lecture_wag_a"], "hush": [330.0, "h_doorstep_sit", 1]},
}

var house: Dictionary = {}
var room_id: String = "kitchen"
var zoom: float = 1.0
var state: String = "idle"
var show_rects: bool = false
var show_badges: bool = false
var show_outline: bool = false
var show_chars: bool = false
var show_title: bool = false
var title_scale: float = 1.0
var cold_set: String = ""
var locked: PackedStringArray = PackedStringArray()
var shown: PackedStringArray = PackedStringArray()
var cam_x_override: float = NAN
var cam_y_override: float = NAN
var decor_states: Dictionary = {}
var cold_states: Dictionary = {}
var char_over: Dictionary = {}

var _rooms: Dictionary = {}
var _outlines: Array[Sprite2D] = []
var _anims: Array[Dictionary] = []
var _t: float = 0.0
var _overlay: Node2D
var _layers: Dictionary = {}
var _font: Font
var _cold: Dictionary = {}


func _ready() -> void:
	_parse_args(OS.get_cmdline_user_args())
	_font = ThemeDB.fallback_font
	for layer_name in ["stage_back", "pieces", "rooms", "decor_back", "outlines", "props", "props_front", "decor_front",
			"chars", "decor_over", "fg", "overlay"]:
		var n := Node2D.new()
		n.name = layer_name
		add_child(n)
		_layers[layer_name] = n
	_overlay = _layers["overlay"]
	_overlay.draw.connect(_draw_overlay)
	house = _load_json(HOUSE_PATH)
	if cold_set != "":
		_build_cold()
		return
	if show_title:
		_build_title()
		return
	if house.is_empty():
		push_error("HousePreview: could not load %s" % HOUSE_PATH)
		return
	for r in house.get("rooms", []):
		_rooms[r["id"]] = r
	if not _rooms.has(room_id):
		room_id = "kitchen"
	_build_stage()
	_build_rooms()
	_build_decor()
	_build_props()
	if show_chars:
		_build_chars()
	_overlay.queue_redraw()
	_setup_camera()


func _process(delta: float) -> void:
	_t += delta
	# outline pulse: alpha 0.6 <-> 1.0 at 1.2 Hz (GDD §3.5)
	var a := 0.8 + 0.2 * sin(_t * TAU * 1.2)
	for s in _outlines:
		s.modulate = Color(OUTLINE_COL.r, OUTLINE_COL.g, OUTLINE_COL.b, a)
	# decor `frames` at their `fps` (the view plays them the same way)
	for an in _anims:
		var frames: Array = an["tex"]
		var i := int(floor(_t * float(an["fps"]))) % frames.size()
		(an["sprite"] as Sprite2D).texture = frames[i]


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
		elif a.begins_with("--y="):
			cam_y_override = float(a.substr(4))
		elif a.begins_with("--locked="):
			locked = a.substr(9).split(",", false)
		elif a.begins_with("--slice="):
			var ep := a.substr(8).substr(0, 3)
			var open: Array = SLICE_ROOMS.get(ep, [])
			for rid in ["porch", "hall", "parlour", "kitchen", "conservatory", "garden", "landing", "bathroom", "bedroom", "dressing"]:
				if not open.has(rid):
					locked.append(rid)
		elif a.begins_with("--show="):
			shown = a.substr(7).split(",", false)
		elif a.begins_with("--decor="):
			var kv := a.substr(8).split(":")
			if kv.size() == 2:
				decor_states[kv[0]] = kv[1]
		elif a.begins_with("--cold="):
			cold_set = a.substr(7)
		elif a.begins_with("--cold_state="):
			for pair in a.substr(13).split(",", false):
				var kv2 := pair.split(":")
				if kv2.size() == 2:
					cold_states[kv2[0]] = kv2[1]
		elif a == "--title":
			show_title = true
		elif a.begins_with("--title_scale="):
			title_scale = clampf(float(a.substr(14)), 0.1, 2.0)
		elif a == "--rects":
			show_rects = true
		elif a == "--badges":
			show_badges = true
		elif a == "--outline":
			show_outline = true
		elif a == "--chars":
			show_chars = true
		elif a == "--nobellows" or a == "--nohush":
			char_over[a.substr(2)] = true
		else:
			for k in ["bx", "bpose", "bface", "hx", "hpose", "hface"]:
				if a.begins_with("--%s=" % k):
					char_over[k] = a.substr(k.length() + 3)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("HousePreview: %s line %d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return {}
	return j.data as Dictionary if j.data is Dictionary else {}


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


func _add_blend(s: Sprite2D) -> void:
	if s == null:
		return
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat


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
		var gw := float(glow["size"][0])
		var gh := float(glow["size"][1])
		var x := float(glow["first_x"])
		while x < float(glow["x1"]):
			_add_blend(_sprite("fg", glow["art"], Vector2(x - gw * 0.5, float(glow["bottom_y"]) - gh), Color(1, 1, 1, 0.55)))
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
		var id: String = d["id"]
		if bool(d.get("hidden", false)) and not (shown.has(id) or shown.has("all") or decor_states.has(id)):
			continue
		var z := int(d.get("z", 0))
		var layer := "decor_back" if z < 0 else ("decor_over" if z >= 2 else "decor_front")
		var art: Dictionary = d.get("art", {})
		var want: String = decor_states.get(id, state)
		var p: String = art.get(want, art.get("idle", ""))
		var s := _sprite(layer, p, Vector2(float(d["pos"][0]), _floor_y(d["room"]) + float(d["pos"][1])), _tint(d["room"]))
		if s == null:
			continue
		if str(d.get("blend", "")) == "add":
			_add_blend(s)
		var frames: Array = d.get("frames", [])
		if frames.size() >= 2 and not decor_states.has(id):
			var texs: Array[Texture2D] = []
			for f in frames:
				var t := _tex(str(f))
				if t != null:
					texs.append(t)
			if texs.size() >= 2:
				_anims.append({"sprite": s, "tex": texs, "fps": float(d.get("fps", 8.0))})


func _build_props() -> void:
	var eyes_tex: Texture2D = _tex(HIDDEN_EYES_PATH) if state == "occupied" and ResourceLoader.exists(HIDDEN_EYES_PATH) else null
	for h in house.get("hotspots", []):
		if not h.has("art"):
			continue
		var art: Dictionary = h["art"]
		var fy := _floor_y(h["room"])
		var pos := Vector2(float(h["art_pos"][0]), fy + float(h["art_pos"][1]))
		var p: String = art.get(state, art.get("idle", ""))
		var layer := "props_front" if int(h.get("z", 0)) > 0 else "props"
		_sprite(layer, p, pos, _tint(h["room"]))
		if eyes_tex != null and art.has("occupied") and h.has("eyes"):
			# exactly what the view draws: Hush's eye sprite centred (pivot) on the hotspot's `eyes` point
			var e := Sprite2D.new()
			e.texture = eyes_tex
			e.centered = false
			e.position = Vector2(float(h["eyes"][0]), fy + float(h["eyes"][1])) - HIDDEN_EYES_PIVOT
			e.modulate = _tint(h["room"])
			(_layers[layer] as Node2D).add_child(e)
		if show_outline and h["room"] == room_id and art.has("outline"):
			# the outline canvas is the prop canvas grown 4 px on every side (STYLE §6)
			var o := _sprite("outlines", art["outline"], pos - Vector2(4, 4))
			if o:
				_outlines.append(o)


## The real rigs through RigPlayer static poses (soft hook: the preview still runs without the rig module).
func _build_chars() -> void:
	var setup: Dictionary = CHAR_SETUPS.get(room_id, CHAR_SETUPS["kitchen"])
	var fy := _floor_y(room_id)
	if not char_over.has("nobellows"):
		var b: Array = setup["bellows"]
		var bx := 0.0
		var bface := 1
		for s in house.get("stations", []):
			if s["id"] == b[0]:
				bx = float(s["stand_x"])
				bface = int(s["facing"])
		bx = float(char_over.get("bx", bx))
		bface = int(char_over.get("bface", bface))
		_make_rig("bellows", str(char_over.get("bpose", b[1])), Vector2(bx, fy), bface)
	if not char_over.has("nohush"):
		var hs: Array = setup["hush"]
		_make_rig("hush", str(char_over.get("hpose", hs[1])), Vector2(float(char_over.get("hx", hs[0])), fy),
			int(char_over.get("hface", hs[2])))


func _make_rig(rig_id: String, pose: String, at: Vector2, facing: int, layer: String = "chars") -> Node2D:
	if not ResourceLoader.exists(RIG_PLAYER_PATH):
		push_warning("HousePreview: %s missing, no characters" % RIG_PLAYER_PATH)
		return null
	var scr: Script = load(RIG_PLAYER_PATH)
	var p: Node2D = scr.new()
	(_layers[layer] as Node2D).add_child(p)
	if p.has_method("configure_for_tools"):
		p.call("configure_for_tools")
	p.call("setup", rig_id)
	if p.get("rig") == null:
		p.queue_free()
		return null
	p.set("springs_enabled", false)
	p.set("smears_enabled", false)
	var poses: Object = p.get("poses")
	if poses != null and bool(poses.call("has_pose", pose)):
		p.call("set_static_pose", poses.call("pose", pose))
	else:
		push_warning("HousePreview: %s has no pose %s" % [rig_id, pose])
	p.call("set_facing", facing, false)
	p.call("advance", 0.0)
	p.position = at
	return p


func _setup_camera() -> void:
	var r: Dictionary = _rooms[room_id]
	var cx := (float(r["x0"]) + float(r["x1"])) * 0.5 if is_nan(cam_x_override) else cam_x_override
	# one floor (interior 640 + slab 60) centred: its middle is 290 px above the floor line
	var cy := _floor_y(room_id) - 290.0
	if zoom < 0.75:
		# Overview: both floors + the roof and the apron in view (centre of the stage bounds)
		var b: Array = house.get("stage", {}).get("bounds", [-220, -1640, 6640, 1890])
		cy = float(b[1]) + float(b[3]) * 0.5
	if not is_nan(cam_y_override):
		cy = cam_y_override
	# clamp to the stage bounds like the game camera (limits = house bounds, GDD §3.7)
	var bounds: Array = house.get("stage", {}).get("bounds", [])
	if bounds.size() == 4:
		var half_w := get_viewport_rect().size.x * 0.5 / zoom
		var bx0 := float(bounds[0]) + half_w
		var bx1 := float(bounds[0]) + float(bounds[2]) - half_w
		cx = clampf(cx, bx0, maxf(bx0, bx1))
	_place_camera(Vector2(cx, cy), zoom)


func _place_camera(at: Vector2, z: float) -> void:
	var cam := Camera2D.new()
	cam.position = at
	cam.zoom = Vector2(z, z)
	add_child(cam)
	cam.make_current()


# ------------------------------------------------------------------------------ cold opens + title

## A cold-open set in screen space (the 2400 x 1080 logical 20:9 frame; the camera centres it, so a
## 16:9 phone sees its central 1920 px).
func _build_cold() -> void:
	var data := _load_json(COLD_PATH)
	var sets: Dictionary = data.get("sets", {})
	if not sets.has(cold_set):
		push_error("HousePreview: cold set %s not in %s" % [cold_set, COLD_PATH])
		return
	_cold = sets[cold_set]
	var states: Dictionary = _cold.get("states", {})
	var layers: Array = (_cold.get("layers", []) as Array).duplicate()
	layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("z", 0)) < int(b.get("z", 0)))
	for l in layers:
		var id: String = l["id"]
		var path: String = l.get("art", "")
		if states.has(id):
			var st: Dictionary = states[id]
			var want: String = cold_states.get(id, str(l.get("state", st.keys()[0])))
			path = st.get(want, path)
		if bool(l.get("hidden", false)) and not cold_states.has(id):
			continue
		var z := int(l.get("z", 0))
		var layer := "rooms" if z < 0 else ("props" if z < 2 else "fg")
		var s := _sprite(layer, path, _v2(l["pos"]))
		if s != null and str(l.get("blend", "")) == "add":
			_add_blend(s)
	if show_chars:
		var anchors: Dictionary = _cold.get("anchors", {})
		if anchors.has("bellows"):
			var pose := str(char_over.get("bpose", _cold.get("bellows_pose", "b_sing_big")))
			var face := int(char_over.get("bface", _cold.get("bellows_facing", 1)))
			var b := _make_rig("bellows", pose, _v2(anchors["bellows"]), face, "props")
			if b != null:
				b.scale = Vector2.ONE * float(_cold.get("bellows_scale", 1.0))
				b.z_index = 1
	var size: Array = _cold.get("size", [2400, 1080])
	_overlay.queue_redraw()
	_place_camera(Vector2(float(size[0]) * 0.5, float(size[1]) * 0.5), 1.0)


## The title card slammed down over the curtain (`--title_scale` shows it at phone scale).
func _build_title() -> void:
	var st: Dictionary = house.get("stage", {})
	var curtain: Dictionary = st.get("curtain", {})
	for i in 2:
		_sprite("rooms", curtain.get("art", ""), Vector2(float(i) * 1920.0 - 240.0, 0.0))
	var spot: Dictionary = st.get("bow_spot", {})
	if not spot.is_empty():
		var sz: Array = spot.get("size", [900, 260])
		_add_blend(_sprite("fg", spot["art"], Vector2(1200 - float(sz[0]) * 0.5, 1080 - float(sz[1])),
			Color(1, 1, 1, float(spot.get("alpha", 0.8)))))
	var tex := _tex(TITLE_PATH)
	if tex != null:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = true
		s.position = Vector2(1200, 470)
		s.scale = Vector2.ONE * title_scale
		(_layers["props"] as Node2D).add_child(s)
	_place_camera(Vector2(1200, 540), 1.0)


# ------------------------------------------------------------------------------ overlays

func _draw_overlay() -> void:
	if cold_set != "":
		if show_rects:
			for k in (_cold.get("anchors", {}) as Dictionary):
				var p := _v2(_cold["anchors"][k])
				_overlay.draw_circle(p, 12.0, Color(1, 0.3, 0.3))
				_overlay.draw_string(_font, p + Vector2(16, -8), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
			var size: Array = _cold.get("size", [2400, 1080])
			var safe := Rect2((float(size[0]) - 1920.0) * 0.5, 0, 1920, float(size[1]))
			_overlay.draw_rect(safe, Color(1, 1, 1, 0.8), false, 4.0)
		return
	if house.is_empty() or show_title:
		return
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
			if h.has("eyes"):
				var ep := Vector2(float(h["eyes"][0]), fy + float(h["eyes"][1]))
				_overlay.draw_circle(ep, 7.0, Color(0.3, 0.9, 1.0))
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
## an item (GDD §3.5). The real badges belong to the view / ui tasks.
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
