## House3D — assembles tonight's set (R3D index §7.10, REDESIGN_3D §3, §5.1): the stage (lip, apron, proscenium
## header, wing flats at the doorways, end flats at the ends of the built set, the velvet rope), one RoomShell3D per
## built room (lit or backstage), tonight's furniture / dressing / decor only (struck = not instanced), every live
## hotspot as a Prop3D / HideSpot3D (with ink + halo) and the hotspots on stage as furniture (no glow, no hit box).
##
## Everything reads `SetList.Result` (what is on stage) and `house3d.json` (where and what it looks like); x / y come
## from the frozen `house.json` (C3). `set_room_light` tweens a room's `stage_light` / `desat` (0.4 s); the levels are
## chosen by r3d-view3d. `hotspot_box` is the hit box TapAssist and the screen-rect lint project.
class_name House3D
extends Node3D

const LIGHT_TWEEN_S := 0.4
const ROPE_COLOR := Color("#B8324B")

var result: SetList.Result = null
var house3d: Dictionary = {}
var db: ContentDB = null
## Milliseconds the last build took.
var build_ms: float = 0.0

var _stage: Node3D = null
var _stage_mats: SetMats = null
var _flat_mats: Dictionary = {}
var _rooms: Dictionary = {}
var _props: Dictionary = {}
var _pieces: Dictionary = {}
var _by_decor: Dictionary = {}
var _room_nodes: Dictionary = {}
var _light: Dictionary = {}
var _solids: Array[Dictionary] = []
var _lent: Dictionary = {}
var _room_x: Dictionary = {}
## Merge each glb room's static geometry (the arch + tonight's static furniture / dressing pieces + its conditional
## built-ins) into one mesh (brief §7: ≤ 3 static draws per room). Set false before build() to keep every piece its own
## mesh (SetPreview3D's ID pass colours each piece).
var merge_static: bool = true
var _merged: PackedStringArray = PackedStringArray()


## Builds tonight's set. `p_house3d` defaults to house3d.json; `p_db` to the Content autoload's db.
func build(p_result: SetList.Result, p_house3d: Dictionary = {}, p_db: ContentDB = null) -> void:
	var t0 := Time.get_ticks_usec()
	_clear()
	result = p_result
	house3d = p_house3d if not p_house3d.is_empty() else SetGeo.load_house3d()
	db = p_db if p_db != null else _content_db()
	if result == null or db == null or db.house == null:
		push_error("House3D.build: no SetList.Result or ContentDB")
		return
	name = "House3D"
	for r in db.house.rooms:
		_room_x[r.id] = Vector2(float(r.x0) / SetGeo.PX_PER_M, float(r.x1) / SetGeo.PX_PER_M)
	_stage = Node3D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_stage_mats = SetMats.new("stage")
	var rooms3: Dictionary = house3d.get("rooms", {})
	var stage: Dictionary = house3d.get("stage", {})
	var built_hs := {}
	for h in db.house.hotspots:
		if result.is_built(h.id):
			built_hs[h.id] = true
	for rid in result.rooms_built():
		if not _room_x.has(rid):
			continue
		var xr: Vector2 = _room_x[rid]
		var shell := RoomShell3D.new()
		shell.setup(rid, xr.x, xr.y, rooms3.get(rid, {}), stage, built_hs)
		add_child(shell)
		_rooms[rid] = shell
		_room_nodes[rid] = []
		_light[rid] = {"level": 1.0, "desat": 0.0, "from_l": 1.0, "from_d": 0.0, "to_l": 1.0, "to_d": 0.0, "t": -1.0}
		for bid in shell.solids.keys():
			_solids.append({"id": bid, "kind": "builtin", "room": rid, "obb": shell.solids[bid]})
	_build_stage(stage)
	_build_hotspots()
	_build_pieces()
	if merge_static:
		_merge_static()
	_build_ropes()
	for rid in result.rooms_backstage:
		_apply_light(rid, 0.3, 0.0)
	build_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	set_process(false)


func _content_db() -> ContentDB:
	var c := get_node_or_null("/root/Content") if is_inside_tree() else null
	if c != null and c.get("db") != null:
		return c.get("db") as ContentDB
	return null


func _clear() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_rooms.clear()
	_props.clear()
	_pieces.clear()
	_by_decor.clear()
	_room_nodes.clear()
	_light.clear()
	_solids.clear()
	_lent.clear()
	_flat_mats.clear()
	_merged.clear()


# --- the stage ----------------------------------------------------------------------------------

func _built_span() -> Vector2:
	var lo := INF
	var hi := -INF
	for rid in _rooms.keys():
		var xr: Vector2 = _room_x[rid]
		lo = minf(lo, xr.x)
		hi = maxf(hi, xr.y)
	return Vector2(lo, hi) if lo < hi else Vector2(0, 1)


func _build_stage(stage: Dictionary) -> void:
	var span := _built_span()
	var lip_z := float(stage.get("lip_z", 0.25))
	var pro: Dictionary = stage.get("proscenium", {})
	var wide := Vector2(span.x - 6.0, span.y + 6.0)
	var cx := (wide.x + wide.y) * 0.5
	var w := wide.y - wide.x
	# the lip (a thin gilded edge) and the dark apron below it
	SetPrims._box(_stage, Vector3(span.y - span.x + 0.6, 0.045, 0.05), Vector3((span.x + span.y) * 0.5, -0.0225, lip_z),
		_stage_mats.get_mat(SetGeo.color(stage.get("lip_color", null), Color("#C9A24A")), &"set"), 0.0, "lip")
	var ah := float(stage.get("apron_h_m", 0.7))
	SetPrims._box(_stage, Vector3(span.y - span.x + 0.6, ah, 0.04), Vector3((span.x + span.y) * 0.5, -ah * 0.5 - 0.045, lip_z),
		_stage_mats.get_mat(SetGeo.color(stage.get("apron_color", null), Color("#2A2236")), &"set"), 0.0, "apron")
	# the proscenium header: a dark band closing the top of every frame, a thin gold edge at 3.13 m
	var ey := float(pro.get("edge_y_m", 3.13))
	var ph := float(pro.get("h_m", 0.8))
	var pz := float(pro.get("z", -2.3))
	SetPrims._box(_stage, Vector3(w, ph, 0.06), Vector3(cx, ey + ph * 0.5, pz), _stage_mats.get_mat(SetGeo.color(pro.get("color", null), Color("#1D1728")), &"set"), 0.0, "proscenium")
	SetPrims._box(_stage, Vector3(w, 0.035, 0.07), Vector3(cx, ey + 0.0175, pz + 0.005), _stage_mats.get_mat(SetGeo.color(pro.get("edge_color", null), Color("#C9A24A")), &"set"), 0.0, "proscenium_edge")
	# wing flats at every doorway between two built rooms; end flats at the ends of the built set
	var wf: Dictionary = stage.get("wing_flat", {})
	var thick := float(wf.get("thick_m", 0.22))
	var front := float(wf.get("front_z", -1.4))
	var fcol := SetGeo.color(wf.get("color", null), Color("#E9DCC4"))
	for l in db.house.links:
		if l.kind_name != "doorway":
			continue
		if not (_rooms.has(l.a) and _rooms.has(l.b)):
			continue
		var x := float(l.x_sub) / 12000.0
		var fm := SetMats.new("flat_" + l.id)
		_flat_mats[l.id] = {"mats": fm, "rooms": [l.a, l.b]}
		var node := SetPrims._box(_stage, Vector3(thick, ey, front + 2.4), Vector3(x, ey * 0.5, (front - 2.4) * 0.5), fm.get_mat(fcol, &"set"), 0.0, "wing_" + l.id)
		SetPrims._box(node, Vector3(thick + 0.04, 0.12, front + 2.4 + 0.02), Vector3(0.0, -ey * 0.5 + 0.06, 0.0),
			fm.get_mat(SetGeo.color(wf.get("skirt_color", null), Color("#6E5A4E")), &"set"), 0.0, "skirt")
		_solids.append({"id": "wing_" + l.id, "kind": "flat", "room": l.a,
			"obb": SetGeo.obb_from_box([x - thick * 0.5, 0.0, -2.4, x + thick * 0.5, ey, front])})
	var ef: Dictionary = stage.get("end_flat", {})
	var et := float(ef.get("thick_m", 0.24))
	var ecol := SetGeo.color(ef.get("color", null), Color("#3A2F45"))
	for end in [span.x, span.y]:
		if _has_door_flat_at(end):
			continue
		var sgn := -1.0 if end == span.x else 1.0
		var ex: float = end + sgn * et * 0.5
		var en := SetPrims._box(_stage, Vector3(et, ey, 2.4 + lip_z), Vector3(ex, ey * 0.5, (lip_z - 2.4) * 0.5), _stage_mats.get_mat(ecol, &"set"), 0.0, "end_flat_%s" % ("l" if sgn < 0 else "r"))
		if _link_door_at(end) != "":
			SetPrims._box(en, Vector3(0.06, 2.1, 0.9), Vector3(-sgn * (et * 0.5 + 0.02), -ey * 0.5 + 1.05, -1.0 - (lip_z - 2.4) * 0.5),
				_stage_mats.get_mat(Color("#6B7466"), &"set"), 0.0, "door_leaf")
		_solids.append({"id": "end_flat_%s" % ("l" if sgn < 0 else "r"), "kind": "flat", "room": "",
			"obb": SetGeo.obb_from_box([ex - et * 0.5, 0.0, -2.4, ex + et * 0.5, ey, lip_z])})


func _has_door_flat_at(x: float) -> bool:
	for rid in _rooms.keys():
		var shell: RoomShell3D = _rooms[rid]
		for bid in (shell.def.get("built_ins", {}) as Dictionary).keys():
			var bd: Dictionary = shell.def["built_ins"][bid]
			if bd.has("leaf"):
				var b: Array = bd["box"]
				if absf((float(b[0]) + float(b[3])) * 0.5 - x) < 0.2:
					return true
	return false


func _link_door_at(x: float) -> String:
	for l in db.house.links:
		if l.kind_name == "door" and absf(float(l.x_sub) / 12000.0 - x) < 0.05:
			return l.id
	return ""


func _build_ropes() -> void:
	var vr: Dictionary = house3d.get("velvet_rope", {})
	if vr.is_empty():
		return
	var spots: Array[Vector2] = []
	if bool(vr.get("backstage_doorway", true)):
		for l in db.house.links:
			if l.kind_name != "doorway":
				continue
			var a_lit := result.rooms_lit.has(l.a)
			var b_lit := result.rooms_lit.has(l.b)
			if (a_lit and result.rooms_backstage.has(l.b)) or (b_lit and result.rooms_backstage.has(l.a)):
				var x := float(l.x_sub) / 12000.0
				var sgn := -1.0 if result.rooms_backstage.has(l.a) else 1.0
				spots.append(Vector2(x + sgn * 0.3, -1.0))
	var stairs := SetGeo.s(vr.get("stairs", ""))
	if stairs != "" and result.architecture.has(stairs) and result.rooms_lit.has(result.room_of(stairs)):
		var h := db.house.hotspot(stairs)
		if h != null:
			spots.append(Vector2(float(h.use_sub) / SetGeo.PX_PER_M / 60.0, -1.65))
	var post := _stage_mats.get_mat(SetGeo.color(vr.get("post_color", null), Color("#C9A24A")), &"set")
	var rope := _stage_mats.get_mat(SetGeo.color(vr.get("color", null), ROPE_COLOR), &"set")
	for i in spots.size():
		var s := spots[i]
		var root := Node3D.new()
		root.name = "VelvetRope_%d" % i
		root.position = Vector3(s.x, 0.0, s.y)
		_stage.add_child(root)
		var span_z := 0.9 if s.y > -1.3 else 0.5
		for sz in [-span_z, span_z]:
			SetPrims._cyl(root, 0.025, 0.035, 0.9, Vector3(0.0, 0.45, sz), post, "post")
			SetPrims._ball(root, 0.045, Vector3(0.0, 0.92, sz), post, Vector3.ONE, "knob")
		SetPrims._capsule(root, 0.025, span_z * 2.0, Vector3(0.0, 0.78, 0.0), rope, "rope").rotation_degrees = Vector3(90, 0, 0)


# --- hotspots (live props and furniture-role hotspots) ----------------------------------------

func _build_hotspots() -> void:
	var hs3: Dictionary = house3d.get("hotspots", {})
	var rooms3: Dictionary = house3d.get("rooms", {})
	var merged: Dictionary = {}
	for h in db.house.hotspots:
		var role := result.role(h.id)
		if role != &"live" and role != &"furniture":
			continue
		var e: Dictionary = hs3.get(h.id, {})
		if e.is_empty() or e.has("part_of") or bool(e.get("architecture", false)):
			continue
		var model := SetGeo.s(e.get("model", ""))
		if model.begins_with("arch:"):
			continue
		var mkey := SetGeo.s(e.get("merge", ""))
		if mkey != "" and merged.has(mkey):
			var host: Prop3D = merged[mkey]
			host.zone_ids.append(h.id)
			_props[h.id] = host
			if role == &"live" and not host.live:
				pass
			continue
		var verb := SetGeo.s(result.live.get(h.id, _verb_of(h.kind_name)))
		var p: Prop3D = HideSpot3D.new() if h.kind == HotspotDef.HIDING else Prop3D.new()
		var room_col := SetGeo.color((rooms3.get(h.room, {}) as Dictionary).get("wall", null))
		var live_any := role == &"live"
		if mkey != "":
			for h2 in db.house.hotspots:
				var e2: Dictionary = hs3.get(h2.id, {})
				if SetGeo.s(e2.get("merge", "")) == mkey and result.role(h2.id) == &"live":
					live_any = true
		p.setup(h.id, e, SetGeo.prop_xform(h.rect, e), h.room, verb, live_any, room_col)
		add_child(p)
		_props[h.id] = p
		_add_room_node(h.room, p)
		if mkey != "":
			merged[mkey] = p
		for o in SetGeo.world_obbs(SetGeo.prop_xform(h.rect, e), e):
			_solids.append({"id": h.id, "kind": "prop" if live_any else "furniture", "room": h.room, "obb": o})


static func _verb_of(kind_name: String) -> String:
	return SetGeo.s(SetList.LIVE_KIND_BY_HS.get(kind_name, "rig"))


# --- furniture, dressing, decor -----------------------------------------------------------------

func _build_pieces() -> void:
	var rooms3: Dictionary = house3d.get("rooms", {})
	var groups := [["furniture", result.furniture_pieces], ["dressing", result.dressing], ["decor", result.decor]]
	for g in groups:
		var table: Dictionary = house3d.get(SetGeo.s(g[0]), {})
		for pid in g[1]:
			var d: Dictionary = table.get(pid, {})
			if d.is_empty():
				continue
			var room := SetGeo.s(d.get("room", ""))
			if not _rooms.has(room):
				continue
			var piece_entry := {
				"model": d.get("model", null) if d.get("model", null) != null else "primitive:" + SetGeo.s(d.get("primitive", "box")),
				"silhouette": SetGeo.s(d.get("primitive", "box")),
				"color": d.get("color", "#9C8466"), "bounds": d.get("box", [-0.2, 0.0, -0.2, 0.2, 0.4, 0.2]),
				"scale": 1.0, "yaw": float(d.get("yaw", 0.0)), "z": float(d.get("z", -2.2)),
				"anims": {}, "tag_socket": null,
			}
			var model := SetGeo.s(piece_entry["model"])
			if model.begins_with("res://") and not ResourceLoader.exists(model):
				piece_entry["model"] = "primitive:" + SetGeo.s(d.get("primitive", "box"))
			var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(d.get("yaw", 0.0)))),
				Vector3(float(d.get("x_m", 0.0)), float(d.get("y_m", 0.0)), float(d.get("z", -2.2))))
			var p := Prop3D.new()
			var room_col := SetGeo.color((rooms3.get(room, {}) as Dictionary).get("wall", null))
			var shell: RoomShell3D = _rooms[room]
			p.setup(String(pid), piece_entry, xf, room, "", false, room_col, shell.mats, shell.palette)
			if bool(d.get("hidden", false)):
				p.visible = false
			add_child(p)
			_pieces[String(pid)] = p
			_by_decor[SetGeo.s(d.get("decor_id", pid))] = p
			_by_decor[String(pid)] = p
			if SetGeo.s(g[0]) == "furniture":
				_solids.append({"id": String(pid), "kind": "furniture", "room": room, "obb": SetGeo.world_obb(xf, piece_entry)})


## One mesh per glb room: the shell's meshes (the door leaf excepted — it opens) + the static pieces of tonight
## (furniture / dressing from a .glb, no anims, not a quake prop tonight, not hidden). They share the room material,
## so the room light still drives them; each merged piece keeps its Prop3D (API, boxes, landings), visual hidden.
func _merge_static() -> void:
	var tables := {"furniture": house3d.get("furniture", {}), "dressing": house3d.get("dressing", {})}
	var by_room := {}
	for g in tables.keys():
		var ids: PackedStringArray = result.furniture_pieces if g == "furniture" else result.dressing
		for pid in ids:
			var d: Dictionary = (tables[g] as Dictionary).get(pid, {})
			var an: Variant = d.get("anims", [])
			if (typeof(an) == TYPE_ARRAY and not (an as Array).is_empty()) or (typeof(an) == TYPE_DICTIONARY and not (an as Dictionary).is_empty()):
				continue
			if bool(d.get("hidden", false)) or result.quake.has(pid):
				continue
			var pc: Prop3D = _pieces.get(String(pid), null)
			if pc == null or not pc.is_static_glb():
				continue
			if not by_room.has(pc.room):
				by_room[pc.room] = []
			(by_room[pc.room] as Array).append(pc)
	for rid in _rooms.keys():
		var shell: RoomShell3D = _rooms[rid]
		if not shell.from_glb():
			continue
		var sources: Array[MeshInstance3D] = []
		for n in shell.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh != null and not String(mi.name).contains("leaf"):
				sources.append(mi)
		var pieces: Array = by_room.get(rid, [])
		for pc in pieces:
			sources.append_array((pc as Prop3D).static_meshes())
		if sources.size() < 2:
			continue
		var st := SurfaceTool.new()
		var mat: Material = sources[0].material_override
		var inv := _house_xform(shell).affine_inverse()
		var used: Array[MeshInstance3D] = []
		for mi in sources:
			if mi.material_override != mat:
				continue
			var ok := true
			for si in mi.mesh.get_surface_count():
				if mi.mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
					ok = false
			if not ok:
				continue
			var xf := inv * _house_xform(mi)
			for si in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, si, xf)
			used.append(mi)
		if used.size() < 2:
			continue
		var merged := MeshInstance3D.new()
		merged.name = "StaticMerged"
		merged.mesh = st.commit()
		merged.material_override = mat
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.add_child(merged)
		for mi in used:
			mi.visible = false
		for pc in pieces:
			var pp := pc as Prop3D
			var all_in := true
			for m2 in pp.static_meshes():
				if not used.has(m2):
					all_in = false
			if all_in:
				pp.hide_visual()
				_merged.append(pp.hotspot_id)


## A node's transform relative to this House3D (walks the parents; works before the node enters the tree).
func _house_xform(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != self:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## The pieces merged into their room's static mesh tonight (their Prop3D stays, visual hidden).
func merged_pieces() -> PackedStringArray:
	return _merged


## The draw calls of a room's static set: visible meshes of its shell + its unmerged furniture / dressing / decor pieces
## (live and furniture-role hotspot props not counted).
func static_draws(room: String) -> int:
	var n := 0
	var shell: RoomShell3D = _rooms.get(room, null)
	if shell == null:
		return 0
	for m in shell.find_children("*", "MeshInstance3D", true, false):
		if _visible_chain(m as Node3D):
			n += 1
	for pid in _pieces.keys():
		var pc: Prop3D = _pieces[pid]
		if pc.room != room or _merged.has(String(pid)) or not _visible_chain(pc):
			continue
		for m3 in pc.static_meshes():
			if _visible_chain(m3):
				n += 1
	return n


## Triangles drawn for a room's set (brief §7: ≤ 25k per lit room): its visible shell meshes, its pieces, its
## hotspot props — with every ink / halo shell pass counted as another draw of the same mesh.
func room_tris(room: String) -> int:
	var nodes: Array[Node3D] = []
	var shell: RoomShell3D = _rooms.get(room, null)
	if shell != null:
		nodes.append(shell)
	for pid in _pieces.keys():
		if (_pieces[pid] as Prop3D).room == room:
			nodes.append(_pieces[pid])
	for pr in props():
		if pr.room == room:
			nodes.append(pr)
	var n := 0
	for root in nodes:
		for m in root.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or not _visible_chain(mi):
				continue
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				var idx: Variant = arr[Mesh.ARRAY_INDEX]
				n += (idx as PackedInt32Array).size() / 3 if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _visible_chain(n: Node3D) -> bool:
	var cur: Node = n
	while cur != null and cur != self:
		if cur is Node3D and not (cur as Node3D).visible:
			return false
		cur = cur.get_parent()
	return true


func _add_room_node(room: String, n: Prop3D) -> void:
	if not _room_nodes.has(room):
		_room_nodes[room] = []
	(_room_nodes[room] as Array).append(n)


# --- the public API (R3D index §7.10) -----------------------------------------------------------

## The Prop3D of a hotspot (live or furniture-role; merged zones return their shared model), else null.
func prop(id: String) -> Prop3D:
	return _props.get(id, null)


## Every Prop3D of tonight's hotspots (unique).
func props() -> Array[Prop3D]:
	var out: Array[Prop3D] = []
	for k in _props.keys():
		var p: Prop3D = _props[k]
		if not out.has(p):
			out.append(p)
	return out


## The built rooms (lit, then backstage).
func rooms_built() -> PackedStringArray:
	return result.rooms_built() if result != null else PackedStringArray()


## Tweens a room's stage light (0.4 s): architecture, furniture, dressing and its props.
func set_room_light(room: String, level: float, desat: float) -> void:
	if not _light.has(room):
		return
	var L: Dictionary = _light[room]
	if is_equal_approx(float(L["to_l"]), level) and is_equal_approx(float(L["to_d"]), desat):
		return
	L["from_l"] = L["level"]
	L["from_d"] = L["desat"]
	L["to_l"] = level
	L["to_d"] = desat
	L["t"] = 0.0
	set_process(true)


## The current (level, desat) of a room (tests).
func room_light(room: String) -> Vector2:
	if not _light.has(room):
		return Vector2(-1, -1)
	return Vector2(float(_light[room]["level"]), float(_light[room]["desat"]))


## Jumps a room's light (no tween).
func snap_room_light(room: String, level: float, desat: float) -> void:
	if not _light.has(room):
		return
	var L: Dictionary = _light[room]
	L["to_l"] = level
	L["to_d"] = desat
	L["t"] = -1.0
	_apply_light(room, level, desat)


func _apply_light(room: String, level: float, desat: float) -> void:
	var L: Dictionary = _light.get(room, {})
	if L.is_empty():
		return
	L["level"] = level
	L["desat"] = desat
	(_rooms[room] as RoomShell3D).set_light(level, desat)
	for n in _room_nodes.get(room, []):
		(n as Prop3D).set_light(level, desat)
	for lid in _flat_mats.keys():
		var fm: Dictionary = _flat_mats[lid]
		if (fm["rooms"] as Array).has(room):
			var mx := 0.0
			for r in fm["rooms"]:
				mx = maxf(mx, float((_light.get(r, {"level": 1.0}) as Dictionary)["level"]))
			(fm["mats"] as SetMats).set_light(mx, 0.0)


func _process(delta: float) -> void:
	advance(delta)


## Steps the light tweens (the tree calls it; tests call it directly).
func advance(dt: float) -> void:
	var busy := false
	for room in _light.keys():
		var L: Dictionary = _light[room]
		if float(L["t"]) < 0.0:
			continue
		L["t"] = float(L["t"]) + dt
		var k := clampf(float(L["t"]) / LIGHT_TWEEN_S, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		_apply_light(room, lerpf(float(L["from_l"]), float(L["to_l"]), e), lerpf(float(L["from_d"]), float(L["to_d"]), e))
		if k >= 1.0:
			L["t"] = -1.0
		else:
			busy = true
	if not busy:
		set_process(false)


## The hit box of a hotspot (R5a): `hit_box` when given, else the house.json rect + `visual_offset`; z = prop z ±
## 0.3 m. Works for any hotspot with a house.json rect (a default z −1.8 when house3d.json has no entry).
func hotspot_box(id: String) -> AABB:
	var h := db.house.hotspot(id) if db != null else null
	if h == null:
		return AABB()
	var e: Dictionary = (house3d.get("hotspots", {}) as Dictionary).get(id, {})
	return SetGeo.hit_box(h.rect, e)


## The lane floor of a room (floor taps): x0…x1, y ±0.05, z −1.6…−0.4.
func floor_band(room: String) -> AABB:
	var xr: Vector2 = _room_x.get(room, Vector2.ZERO)
	return AABB(Vector3(xr.x, -0.05, -1.6), Vector3(xr.y - xr.x, 0.1, 1.2))


## A furniture / dressing / decor piece by its id or house.json decor id (kitchen_stool, parlour_vase …).
func decor(id: String) -> Node3D:
	return _by_decor.get(id, null)


## Plays a decor animation (the stool's `wobble`, the vase's `nudge` / `smash`, the picture's `fall`).
func play_decor(id: String, anim: String) -> void:
	var p: Prop3D = _by_decor.get(id, null)
	if p == null:
		return
	if anim == "smash":
		var d: Dictionary = (house3d.get("decor", {}) as Dictionary).get(id, {})
		var sm := SetGeo.s(d.get("smashed", ""))
		p.visible = false
		if sm != "" and _by_decor.has(sm):
			(_by_decor[sm] as Node3D).visible = true
		return
	p.play(anim)


## Shows / hides a decor piece (the clip event `decor {id: kitchen_stool, visible: false}`).
func set_decor_visible(id: String, on: bool) -> void:
	var n: Node3D = _by_decor.get(id, null)
	if n != null:
		n.visible = on


## Lends a set piece (a hotspot prop or a furniture / decor piece; "set:<id>" accepted) to a socket node over
## `frames`; returns the piece (null when not built).
func lend(id: String, to: Node3D, frames: int = 6) -> Node3D:
	var pid := id.substr(4) if id.begins_with("set:") else id
	var p: Prop3D = _props.get(pid, _by_decor.get(pid, null))
	if p == null or to == null:
		return null
	p.lend(to, frames)
	_lent[pid] = p
	return p


## Slides a lent piece home.
func return_home(id: String, frames: int = 6) -> void:
	var pid := id.substr(4) if id.begins_with("set:") else id
	var p: Prop3D = _lent.get(pid, null)
	if p == null:
		return
	p.return_home(frames)
	_lent.erase(pid)


## Returns every lent piece (a clip switch without `keeps`, a retry).
func return_all(frames: int = 6) -> void:
	for pid in _lent.keys():
		(_lent[pid] as Prop3D).return_home(frames)
	_lent.clear()


## The volume a landing must end inside ("kitchen.sink"): house3d.json `landings.<room>.<id>.box`.
func landing_box(id: String) -> AABB:
	var parts := id.split(".")
	if parts.size() != 2:
		return AABB()
	var ld: Dictionary = ((house3d.get("landings", {}) as Dictionary).get(parts[0], {}) as Dictionary).get(parts[1], {})
	var b: Array = ld.get("box", [])
	if b.size() < 6:
		return AABB()
	return AABB(Vector3(float(b[0]), float(b[1]), float(b[2])), Vector3(float(b[3]) - float(b[0]), float(b[4]) - float(b[1]), float(b[5]) - float(b[2])))


## The landing point (x from house.json landings, y / z / yaw from house3d.json): {pos: Vector3, yaw: float}.
func landing_point(id: String) -> Dictionary:
	var parts := id.split(".")
	if parts.size() != 2 or db == null:
		return {}
	var ld: Dictionary = ((house3d.get("landings", {}) as Dictionary).get(parts[0], {}) as Dictionary).get(parts[1], {})
	var x := float(db.house.landing_sub(parts[0], parts[1])) / (SetGeo.PX_PER_M * 60.0)
	return {"pos": Vector3(x, float(ld.get("y", 0.0)), float(ld.get("z", -1.8))), "yaw": float(ld.get("yaw", 0.0))}


## The world AABBs of the built furniture, built-ins, flats and furniture-role hotspot props (the collision test).
func furniture_boxes() -> Array[AABB]:
	var out: Array[AABB] = []
	for s in _solids:
		if SetGeo.s(s["kind"]) != "prop":
			out.append(SetGeo.obb_aabb(s["obb"]))
	return out


## Every solid as {id, kind: "builtin" | "flat" | "furniture" | "prop", room, obb} (SetGeo OBBs).
func collision_solids() -> Array[Dictionary]:
	return _solids


## Where Hush stands to rig a hotspot: {x, z, step, step_h, dx, stand: Vector3} (house3d.json `reach_pos`, x from
## use_x). {} for a hotspot without one.
func reach_pos(hotspot: String) -> Dictionary:
	var h := db.house.hotspot(hotspot) if db != null else null
	var e: Dictionary = (house3d.get("hotspots", {}) as Dictionary).get(hotspot, {})
	if h == null or not e.has("reach_pos"):
		return {}
	var st := SetGeo.reach_stand(float(h.use_sub) / (SetGeo.PX_PER_M * 60.0), e)
	st["dx"] = float((e["reach_pos"] as Dictionary).get("dx", 0.0))
	st["stand"] = Vector3(float(st["x"]), float(st["step_h"]), float(st["z"]))
	return st


## The body materials of a room set (the "one material per room" budget; greybox rooms have one per colour).
func room_material_count(room: String) -> int:
	var shell: RoomShell3D = _rooms.get(room, null)
	return shell.mats.materials().size() if shell != null else 0


## The RoomShell3D of a built room.
func room_shell(room: String) -> RoomShell3D:
	return _rooms.get(room, null)


## Build statistics: {rooms, props, pieces, solids, build_ms}.
func stats() -> Dictionary:
	return {"rooms": _rooms.size(), "props": props().size(), "pieces": _pieces.size(), "solids": _solids.size(),
		"merged": _merged.size(), "build_ms": build_ms}
