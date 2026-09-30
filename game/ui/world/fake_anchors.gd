## FakeAnchors — a scripted stand-in for `WorldView3D`'s overlay-anchor API (r3d-index §7.8) for
## UiDemo shots and tests (brief §3): the same methods, answered from
##   * 2D mode (tests): `set_point(hotspot, kind, screen_pos)` / `set_actor(actor, rect)` — anchors are
##     screen points carried in Vector3(x, y, 0) and `project` is the identity;
##   * 3D mode (`build_room(room)`, shots): a greybox of one room from `house.json`'s frozen rects in
##     metres (1 m = 200 sim px, index R4; props in the reach row z −1.75, hiding spots −2.1), two
##     capsule stand-ins for Hush (1.60 m) and Bellows (1.78 m) on the lane (z −1.0) and a Camera3D at
##     the REDESIGN §5.2 base framing (FOV 30°, KEEP_HEIGHT, 7.5 m in front of the lane at y 1.9 m,
##     aimed at y 1.35 m) — anchors are world points projected with `Camera3D.unproject_position`.
## The real WorldView3D replaces it in NightScene.
class_name FakeAnchors
extends Node3D

const HOUSE_PATH := "res://data/house/house.json"
const PX_PER_M := 200.0
const LANE_Z := -1.0
const PROP_Z := -1.75
const HIDE_Z := -2.1
const BACK_Z := -2.4
const ROOM_H := 3.2
const HUSH_H := 1.60
const BELLOWS_H := 1.78
const CAM_DIST := 7.5
const CAM_Y := 1.9
const AIM_Y := 1.35
const FOV := 30.0
const PAD := 48.0

## 2D mode: {"<hotspot>|<kind>": Vector2}; actors {actor: Rect2}.
var points: Dictionary = {}
var actors: Dictionary = {}
## The rig point Hush stands at (its prop + preview is protected); "" none.
var hush_at: String = ""
## Extra protected rects (the Bellows window, his bubble) the scene wants.
var extra_protected: Array[Rect2] = []
## Safe-area insets (logical px) for safe_rect().
var insets: Vector4 = Vector4.ZERO
## Test hook: the viewport size in 2D mode.
var size_override: Vector2 = Vector2.ZERO
var use_3d: bool = false
var camera: Camera3D = null
## 3D mode: hotspot id → AABB (metres); actor → Node3D capsule root.
var boxes: Dictionary = {}
var actor_nodes: Dictionary = {}
var room_id: String = ""

var _house: Dictionary = {}


# --- 2D mode ------------------------------------------------------------------------------------

## Pin `hotspot`'s `kind` anchor to a screen point (2D mode).
func set_point(hotspot: String, kind: StringName, screen: Vector2) -> void:
	points["%s|%s" % [hotspot, kind]] = screen


## Pin an actor's screen bounds (2D mode); its head is the rect's top centre + 12 %.
func set_actor(actor: StringName, rect: Rect2) -> void:
	actors[actor] = rect


# --- 3D mode ------------------------------------------------------------------------------------

## Build a greybox of `room` (house.json) with the camera framing it; Hush at `hush_x_m`, Bellows at
## `bellows_x_m` (NAN = off stage).
func build_room(room: String, hush_x_m: float = NAN, bellows_x_m: float = NAN) -> void:
	use_3d = true
	room_id = room
	for c in get_children():
		c.free()
	boxes.clear()
	actor_nodes.clear()
	_house = _read_json(HOUSE_PATH)
	var rd := _room(room)
	var x0 := float(rd.get("x0", 0)) / PX_PER_M
	var x1 := float(rd.get("x1", 1000)) / PX_PER_M
	var wall := Color(String(rd.get("wallpaper", "#C7B684")))
	_box(Vector3((x0 + x1) * 0.5, ROOM_H * 0.5, BACK_Z - 0.05), Vector3(x1 - x0 + 4.0, ROOM_H, 0.1), wall.lerp(Color("#C7B684"), 0.5))
	_box(Vector3((x0 + x1) * 0.5, -0.05, -0.8), Vector3(x1 - x0 + 4.0, 0.1, 3.4), Color("#8E6E52"))
	_box(Vector3((x0 + x1) * 0.5, 0.45, -1.95), Vector3(x1 - x0, 0.9, 0.7), wall.darkened(0.12))
	_box(Vector3(x0 - 0.1, ROOM_H * 0.5, -1.4), Vector3(0.22, ROOM_H, 2.0), Color("#E9DCC4"))
	_box(Vector3(x1 + 0.1, ROOM_H * 0.5, -1.4), Vector3(0.22, ROOM_H, 2.0), Color("#E9DCC4"))
	for h in _house.get("hotspots", []):
		var hd: Dictionary = h
		if String(hd.get("room", "")) != room:
			continue
		var r: Array = hd.get("rect", [0, 0, 144, 144])
		var kind := String(hd.get("kind", ""))
		var cx := (float(r[0]) + float(r[2]) * 0.5) / PX_PER_M
		var bot := -(float(r[1]) + float(r[3])) / PX_PER_M
		var w := float(r[2]) / PX_PER_M * 0.55
		var hh := float(r[3]) / PX_PER_M * 0.6
		var z := HIDE_Z if kind == "hiding" else PROP_Z
		if kind == "door":
			continue
		var col := Color("#5C9EFF") if kind == "hiding" else (Color("#FFC838") if kind == "rig_point" else Color("#FFF4DB"))
		if kind == "hiding":
			hh = float(r[3]) / PX_PER_M * 0.9
			w = float(r[2]) / PX_PER_M * 0.8
		var c := Vector3(cx, maxf(0.0, bot) + hh * 0.5, z)
		_box(c, Vector3(w, hh, 0.3), col.lerp(Color.WHITE, 0.25))
		boxes[String(hd.get("id", ""))] = AABB(c - Vector3(w, hh, 0.3) * 0.5, Vector3(w, hh, 0.3))
	if not is_nan(hush_x_m):
		actor_nodes[&"hush"] = _capsule(Vector3(hush_x_m, 0, LANE_Z), HUSH_H, Color("#2B3566"), Color("#FFF6EA"), Color("#E23B4E"))
	if not is_nan(bellows_x_m):
		actor_nodes[&"bellows"] = _capsule(Vector3(bellows_x_m, 0, LANE_Z - 0.4), BELLOWS_H, Color("#7B3F8C"), Color("#F4C9A8"), Color("#D9DCE6"))
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.5
	camera.far = 60.0
	add_child(camera)
	var cam_x := (x0 + x1) * 0.5
	camera.position = Vector3(cam_x, CAM_Y, LANE_Z + CAM_DIST)
	camera.look_at(Vector3(cam_x, AIM_Y, LANE_Z), Vector3.UP)
	camera.current = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1D1728")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.7, 0.76)
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.8
	add_child(sun)


## Move a stand-in actor (3D mode).
func move_actor(actor: StringName, x_m: float) -> void:
	var n: Node3D = actor_nodes.get(actor, null)
	if n != null:
		n.position.x = x_m


## The world x (m) of a hotspot's box centre (3D mode; NAN when unknown).
func hotspot_x_m(hotspot: String) -> float:
	var b: Variant = boxes.get(hotspot, null)
	return (b as AABB).get_center().x if b is AABB else NAN


# --- the §7.8 anchor-source API ----------------------------------------------------------------------

## World point → logical screen px.
func project(p: Vector3) -> Vector2:
	if use_3d and camera != null and camera.is_inside_tree():
		return camera.unproject_position(p)
	return Vector2(p.x, p.y)


## The anchor of `kind` on `hotspot` (&"preview" &"tag" &"ring" &"item" &"eyes" &"reach"); Vector3.INF
## when unknown.
func anchor_of(hotspot_id: String, kind: StringName) -> Vector3:
	if not use_3d:
		var key := "%s|%s" % [hotspot_id, kind]
		if points.has(key):
			var s: Vector2 = points[key]
			return Vector3(s.x, s.y, 0.0)
		var pk := "%s|preview" % hotspot_id
		if points.has(pk):
			var s2: Vector2 = points[pk]
			return Vector3(s2.x, s2.y + 90.0, 0.0)
		return Vector3.INF
	var b: Variant = boxes.get(hotspot_id, null)
	if not (b is AABB):
		return Vector3.INF
	var bb: AABB = b
	var c := bb.get_center()
	var top := bb.position.y + bb.size.y
	match kind:
		&"preview":
			return Vector3(c.x, top + 0.42, c.z)
		&"tag":
			return Vector3(bb.end.x, top - 0.05, bb.end.z)
		&"item":
			return Vector3(c.x, top + 0.30, c.z)
		&"eyes":
			return Vector3(c.x, bb.position.y + bb.size.y * 0.7, bb.end.z)
	return c


## An actor's anchor (&"head" &"top" &"chest" &"feet").
func actor_anchor(actor: StringName, kind: StringName) -> Vector3:
	if not use_3d:
		var r: Variant = actors.get(actor, null)
		if not (r is Rect2):
			return Vector3.INF
		var rr: Rect2 = r
		var y := rr.position.y
		match kind:
			&"head":
				y = rr.position.y + rr.size.y * 0.12
			&"chest":
				y = rr.position.y + rr.size.y * 0.35
			&"feet":
				y = rr.end.y
		return Vector3(rr.get_center().x, y, 0.0)
	var n: Node3D = actor_nodes.get(actor, null)
	if n == null:
		return Vector3.INF
	var h := HUSH_H if actor == &"hush" else BELLOWS_H
	match kind:
		&"head":
			return n.position + Vector3(0, h * 0.88, 0)
		&"top":
			return n.position + Vector3(0, h, 0)
		&"chest":
			return n.position + Vector3(0, h * 0.65, 0)
	return n.position


## An actor's projected bounds (Rect2() when absent).
func actor_screen_rect(actor: StringName) -> Rect2:
	if not use_3d:
		return actors.get(actor, Rect2())
	var n: Node3D = actor_nodes.get(actor, null)
	if n == null:
		return Rect2()
	var h := HUSH_H if actor == &"hush" else BELLOWS_H
	return _project_aabb(AABB(n.position - Vector3(0.28, 0, 0.2), Vector3(0.56, h, 0.4)))


## A prop's projected bounds (Rect2() when unknown).
func prop_screen_rect(hotspot_id: String) -> Rect2:
	if not use_3d:
		var p := anchor_of(hotspot_id, &"ring")
		return Rect2(p.x - 72.0, p.y - 72.0, 144.0, 144.0) if p.is_finite() else Rect2()
	var b: Variant = boxes.get(hotspot_id, null)
	return _project_aabb(b) if b is AABB else Rect2()


## Hush +48, Bellows +48, the prop Hush is at (+ its preview), then `extra_protected`.
func protected_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for a in [&"hush", &"bellows"]:
		var r := actor_screen_rect(a)
		if r.has_area():
			out.append(r.grow(PAD))
	if hush_at != "":
		var pr := prop_screen_rect(hush_at)
		if pr.has_area():
			var pv := anchor_of(hush_at, &"preview")
			if pv.is_finite():
				pr = pr.expand(project(pv))
			out.append(pr)
	out.append_array(extra_protected)
	return out


## The viewport minus the safe-area insets.
func safe_rect() -> Rect2:
	var vs := _view_size()
	return Rect2(insets.x, insets.y, vs.x - insets.x - insets.z, vs.y - insets.y - insets.w)


## True when `p` projects inside the viewport (and is in front of the camera).
func on_screen(p: Vector3) -> bool:
	if use_3d and camera != null and camera.is_inside_tree():
		if camera.is_position_behind(p):
			return false
	var s := project(p)
	return Rect2(Vector2.ZERO, _view_size()).has_point(s)


func _view_size() -> Vector2:
	if size_override != Vector2.ZERO:
		return size_override
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1920, 1080)


func _project_aabb(b: AABB) -> Rect2:
	var r := Rect2(project(b.position), Vector2.ZERO)
	for i in 8:
		r = r.expand(project(b.get_endpoint(i)))
	return r


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return {}
	return j.data


func _room(room: String) -> Dictionary:
	for r in _house.get("rooms", []):
		if String((r as Dictionary).get("id", "")) == room:
			return r
	return {}


func _box(center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if color.v > 0.9 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.material = mat
	mi.mesh = m
	mi.position = center
	add_child(mi)
	return mi


func _capsule(feet: Vector3, h: float, body: Color, face: Color, hat: Color) -> Node3D:
	var root := Node3D.new()
	root.position = feet
	add_child(root)
	var bm := CapsuleMesh.new()
	bm.radius = 0.2
	bm.height = h * 0.72
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = body
	bm.material = bmat
	var bi := MeshInstance3D.new()
	bi.mesh = bm
	bi.position = Vector3(0, h * 0.36, 0)
	root.add_child(bi)
	var hm := SphereMesh.new()
	hm.radius = h * 0.12
	hm.height = h * 0.24
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = face
	hm.material = hmat
	var hi := MeshInstance3D.new()
	hi.mesh = hm
	hi.position = Vector3(0, h * 0.86, 0)
	root.add_child(hi)
	var cm := CylinderMesh.new()
	cm.top_radius = h * 0.1
	cm.bottom_radius = h * 0.13
	cm.height = 0.07
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = hat
	cm.material = cmat
	var ci := MeshInstance3D.new()
	ci.mesh = cm
	ci.position = Vector3(0.02, h * 0.98, 0)
	ci.rotation_degrees = Vector3(0, 0, -12)
	root.add_child(ci)
	return root
