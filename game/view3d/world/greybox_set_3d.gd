## GreyboxSet3D — WorldView3D's private stand-in set until `r3d-sets`' House3D lands (index §3.5 rule 1): the built
## rooms as flat walls, floors, wainscots, wing flats, the proscenium header and the stage lip from `house.json`
## rects, and every live hotspot as a verb-coloured box at its `house3d.json` depth (when present). It answers the
## subset of the House3D API the view uses (`hotspot_box`, `set_room_light`, `prop`, `reach_pos`, `landing_box`,
## `lend` / `return_home` / `return_all`, decor visibility, `rooms_built`) so WorldView3D never branches.
## Counted by `fallback_counts().greybox_props` (one per live prop). Deleted when House3D is in every Night.
class_name GreyboxSet3D
extends Node3D

const WALL_COLORS := {"porch": "#9FB9C8", "hall": "#AFB79C", "parlour": "#C9A7A0", "kitchen": "#C7B684",
	"conservatory": "#B9CFC8", "garden": "#9CC08A"}
const FLOOR_COLOR := Color("#8E6E52")
const FLAT_COLOR := Color("#E9DCC4")
const HEADER_COLOR := Color("#1D1728")
const LIP_COLOR := Color("#C9A24A")


## A greybox live prop: a box with the prop shader; the Prop3D verbs it can show (glow, state, tag, progress).
class GreyProp extends Node3D:
	var id: String = ""
	var kind: StringName = &"rig"
	var room: String = ""
	var box: AABB = AABB()
	var mat: ShaderMaterial = null
	var tag: MeshInstance3D = null
	var state: StringName = &"idle"
	var progress: float = 0.0
	var occupied: bool = false
	var home: Transform3D = Transform3D.IDENTITY
	var home_parent: Node = null
	var anchors: Dictionary = {}

	func set_glow(col: Color, amp: float) -> void:
		if mat != null:
			mat.set_shader_parameter("glow_color", col)
			mat.set_shader_parameter("glow_amp", amp)

	func set_state(s: StringName) -> void:
		state = s
		if mat != null:
			mat.set_shader_parameter("spent", 1.0 if s == &"spent" else 0.0)

	func set_rig_progress(frac: float) -> void:
		progress = frac

	func show_tag(on: bool, _animate: bool = true) -> void:
		if tag != null:
			tag.visible = on

	func tag_wiggle() -> void:
		if tag != null:
			tag.rotation.z = 0.35

	func set_occupied(on: bool) -> void:
		occupied = on

	func eyes_look(_dir: Vector2) -> void:
		pass

	func eyes_blink() -> void:
		pass

	func set_part(_name: String, _vis: bool) -> void:
		pass

	func play(_anim: String) -> void:
		pass

	func anchor(kind_: StringName) -> Vector3:
		if anchors.has(kind_):
			return anchors[kind_]
		var c := box.get_center()
		match kind_:
			&"preview":
				return Vector3(c.x, box.end.y + 0.6, c.z)
			&"tag":
				return Vector3(c.x + box.size.x * 0.3, box.end.y, box.end.z)
			&"ring", &"reach":
				return c
			&"item":
				return Vector3(c.x, box.end.y + 0.35, c.z)
			&"eyes":
				return Vector3(c.x, box.position.y + box.size.y * 0.7, box.end.z)
		return c


var props: Dictionary = {}        # hotspot id → GreyProp
var room_mats: Dictionary = {}    # room id → Array[ShaderMaterial]
var built: PackedStringArray = PackedStringArray()
var house3d: Dictionary = {}
var _decor_vis: Dictionary = {}
var _lent: Dictionary = {}


## Builds the greybox. `live` = {hotspot id: kind} (SimCtx.live_hotspots / SetList.Result.live; empty = every hotspot
## of the lit rooms).
func build_from(layout: HouseLayout, rooms_lit: PackedStringArray, rooms_backstage: PackedStringArray, live: Dictionary, h3: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	props.clear()
	room_mats.clear()
	house3d = h3
	built = rooms_lit.duplicate()
	built.append_array(rooms_backstage)
	var lo := INF
	var hi := -INF
	for r in layout.rooms:
		if not built.has(r.id) or r.floor != 0:
			continue
		lo = minf(lo, r.x0 / 200.0)
		hi = maxf(hi, r.x1 / 200.0)
		_room(r)
	if lo < hi:
		_stage(lo, hi)
	for hs in layout.hotspots:
		var lit := rooms_lit.has(hs.room)
		if not lit or not hs.tappable:
			continue
		if not live.is_empty() and not live.has(hs.id):
			continue
		if hs.kind in ["door", "stairs", "exit", "entry"] and not live.has(hs.id):
			continue
		_prop(hs, layout)


func _mat(shader: String, col: Color, room: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	m.set_shader_parameter("albedo_color", col)
	if room != "":
		if not room_mats.has(room):
			room_mats[room] = []
		(room_mats[room] as Array).append(m)
	MaterialWarm3D.register(m, &"set" if shader == View3DConst.SH_SET else &"prop")
	return m


func _box(pos: Vector3, size: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = m
	mi.layers = View3DConst.MASK_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(mi)
	return mi


func _room(r: HouseLayout.Room) -> void:
	var x0 := r.x0 / 200.0
	var x1 := r.x1 / 200.0
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var wall := Color(str(WALL_COLORS.get(r.id, "#C0B8A8")))
	var wall_m := _mat(View3DConst.SH_SET, wall, r.id)
	var wains_m := _mat(View3DConst.SH_SET, wall.darkened(0.12), r.id)
	var floor_m := _mat(View3DConst.SH_SET, FLOOR_COLOR, r.id)
	var d := View3DConst.SET_DEPTH_M + View3DConst.LIP_Z
	_box(Vector3(cx, View3DConst.ROOM_H_M * 0.5, View3DConst.BACK_WALL_Z - 0.05), Vector3(w, View3DConst.ROOM_H_M, 0.1), wall_m)
	_box(Vector3(cx, 0.45, View3DConst.BACK_WALL_Z + 0.01), Vector3(w, 0.9, 0.04), wains_m)
	_box(Vector3(cx, -0.05, View3DConst.BACK_WALL_Z + d * 0.5), Vector3(w, 0.1, d), floor_m)
	# wing flats at the room ends (from the back wall to z −1.4)
	var flat_m := _mat(View3DConst.SH_SET, FLAT_COLOR, r.id)
	var fd := View3DConst.WING_FRONT_Z - View3DConst.BACK_WALL_Z
	var fz := (View3DConst.WING_FRONT_Z + View3DConst.BACK_WALL_Z) * 0.5
	for x in [x0, x1]:
		_box(Vector3(x, View3DConst.ROOM_H_M * 0.5, fz), Vector3(0.22, View3DConst.ROOM_H_M, fd), flat_m)


func _stage(lo: float, hi: float) -> void:
	var w := hi - lo + 4.0
	var cx := (lo + hi) * 0.5
	var head := _mat(View3DConst.SH_SET, HEADER_COLOR, "")
	_box(Vector3(cx, 3.13 + 0.4, 0.0), Vector3(w, 0.8, 6.0), head)
	var lip := _mat(View3DConst.SH_SET, LIP_COLOR, "")
	_box(Vector3(cx, -0.06, View3DConst.LIP_Z), Vector3(w, 0.12, 0.06), lip)
	var apron := _mat(View3DConst.SH_SET, Color("#241C30"), "")
	_box(Vector3(cx, -0.6, View3DConst.LIP_Z + 0.5), Vector3(w, 1.0, 1.0), apron)


func _prop(hs: HouseLayout.Hotspot, layout: HouseLayout) -> void:
	var fy := View3DConst.floor_y(_floor_of_room(layout, hs.room))
	var h3: Dictionary = {}
	if house3d.get("hotspots", null) is Dictionary and (house3d["hotspots"] as Dictionary).get(hs.id, null) is Dictionary:
		h3 = house3d["hotspots"][hs.id]
	var z := float(h3.get("z", -1.75))
	var off: Array = h3.get("visual_offset", [0.0, 0.0]) if h3.get("visual_offset", null) is Array else [0.0, 0.0]
	var x0 := hs.rect.position.x / 200.0 + float(off[0])
	var x1 := hs.rect.end.x / 200.0 + float(off[0])
	var y0 := fy - hs.rect.end.y / 200.0 + float(off[1])
	var y1 := fy - hs.rect.position.y / 200.0 + float(off[1])
	var size := Vector3(maxf(0.2, (x1 - x0) * 0.7), maxf(0.2, (y1 - y0) * 0.8), 0.3)
	var centre := Vector3((x0 + x1) * 0.5, y0 + size.y * 0.5, z)
	var gp := GreyProp.new()
	gp.id = hs.id
	gp.name = "Grey_" + hs.id
	gp.room = hs.room
	gp.kind = GreyboxSet3D.verb_of(hs.kind)
	gp.box = AABB(Vector3(x0, y0, z - 0.3), Vector3(x1 - x0, y1 - y0, 0.6))
	add_child(gp)
	var col := Color(str(h3.get("color", "#D8452F")))
	gp.mat = _mat(View3DConst.SH_PROP, col, hs.room)
	var mi := _box(centre, size, gp.mat, gp)
	var ink := ShaderMaterial.new()
	ink.shader = load(View3DConst.SH_OUTLINE)
	ink.set_shader_parameter("outline_px", View3DConst.OUTLINE_PROP_PX)
	ink.set_shader_parameter("width_from_alpha", false)
	gp.mat.next_pass = ink
	mi.name = "Body"
	var tag := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.1
	sp.height = 0.12
	tag.mesh = sp
	tag.position = Vector3(centre.x + size.x * 0.35, centre.y + size.y * 0.5 + 0.05, z + 0.16)
	tag.material_override = _mat(View3DConst.SH_PROP, Color("#D8263A"), hs.room)
	tag.visible = false
	gp.add_child(tag)
	gp.tag = tag
	gp.home = gp.transform
	props[hs.id] = gp


static func verb_of(kind: String) -> StringName:
	match kind:
		"rig_point":
			return &"rig"
		"hiding":
			return &"hide"
		"container":
			return &"take"
		"exit", "door":
			return &"exit"
	return StringName(kind)


func _floor_of_room(layout: HouseLayout, room: String) -> int:
	var r := layout.room(room)
	return r.floor if r != null else 0


# --- the House3D subset -------------------------------------------------------------------------------

func prop(id: String) -> Object:
	return props.get(id, null)


func hotspot_box(id: String) -> AABB:
	var p: GreyProp = props.get(id, null)
	return p.box if p != null else AABB()


func set_room_light(room: String, level: float, desat_: float) -> void:
	for m in room_mats.get(room, []):
		(m as ShaderMaterial).set_shader_parameter("stage_light", level)
		(m as ShaderMaterial).set_shader_parameter("desat", desat_)


func reach_pos(id: String) -> Dictionary:
	if house3d.get("hotspots", null) is Dictionary:
		var h: Variant = (house3d["hotspots"] as Dictionary).get(id, null)
		if h is Dictionary and (h as Dictionary).get("reach_pos", null) is Dictionary:
			return (h as Dictionary)["reach_pos"]
	return {"dx": 0.0, "z": View3DConst.REACH_Z, "step": null, "step_h": 0.0}


func landing_box(id: String) -> AABB:
	var parts := id.split(".")
	if parts.size() == 2 and house3d.get("landings", null) is Dictionary:
		var r: Variant = (house3d["landings"] as Dictionary).get(parts[0], null)
		if r is Dictionary and (r as Dictionary).get(parts[1], null) is Dictionary:
			var b: Variant = (r as Dictionary)[parts[1]].get("box", null)
			if b is Array and (b as Array).size() == 6:
				var a: Array = b
				return AABB(Vector3(a[0], a[1], a[2]), Vector3(float(a[3]) - float(a[0]), float(a[4]) - float(a[1]), float(a[5]) - float(a[2])))
	return AABB()


## Slides a set piece into a socket node over `frames` (the greybox snaps).
func lend(id: String, to: Node3D, _frames: int = 6) -> Node3D:
	var p: GreyProp = props.get(id, null)
	if p == null or to == null:
		return null
	if not _lent.has(id):
		_lent[id] = [p.get_parent(), p.transform]
	var gt := p.global_transform if p.is_inside_tree() else p.transform
	p.get_parent().remove_child(p)
	to.add_child(p)
	p.global_transform = gt
	p.position = Vector3.ZERO
	return p


func return_home(id: String, _frames: int = 6) -> void:
	var p: GreyProp = props.get(id, null)
	if p == null or not _lent.has(id):
		return
	var home: Array = _lent[id]
	_lent.erase(id)
	p.get_parent().remove_child(p)
	(home[0] as Node).add_child(p)
	p.transform = home[1]


func return_all() -> void:
	for id in _lent.keys():
		return_home(String(id))


func is_lent(id: String) -> bool:
	return _lent.has(id)


func set_decor_visible(id: String, on: bool) -> void:
	_decor_vis[id] = on


func play_decor(_id: String, _anim: String) -> void:
	pass


func decor(_id: String) -> Node3D:
	return null


func rooms_built() -> PackedStringArray:
	return built


func greybox_count() -> int:
	return props.size()
