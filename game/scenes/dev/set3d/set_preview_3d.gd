## SetPreview3D — the dev scene of the 3D sets (brief r3d-sets §4.6; the tools and the lints use it).
##
##   tools/scripts/shot.sh res://scenes/dev/set3d/SetPreview3D.tscn out.png 40 r3d-sets -- --episode=p00_curtain_up \
##     [--room=kitchen] [--x=<cam x m>] [--hit-rects] [--anchors] [--reach=hush] [--state=<hs>:<idle|armed|spent|rig@0.5>,…]
##     [--glow=<hs>|all] [--tag=<hs>|all|armed] [--occupied=<hide>] [--lit=<room>] [--chars] [--check] [--pass=id --legend=/abs.json]
##     [--decor=<id>:<anim>] [--lend=<hs>] [--zoom=<k>] [--y=<aim y>] [--landings] [--rects-json=/abs.json] [--perf] [--counts]
##
## Characters (`--chars`): `--hush_x/_y/_z/_facing/_cheat/_clip/_frame` (same for `bellows_`), and
## `--<who>_anim_glb=/abs.glb --<who>_anim_name=<action>` for a raw glb action (ClipLib3D.load_glb_action).
## `--state=all:<state>` sets every live prop. `--landings` draws tonight's landing boxes + points. `--rects-json`
## writes the projected screen rects (px) of every live prop's hit box and visual, the landings and the decor pieces
## (the review boards crop from them).
##
## Base framing = CameraDirector3D (r3d-view3d) when present, else the §7.7 numbers directly (FOV 30°, KEEP_HEIGHT,
## camera z +6.5, y 1.9 aimed at 1.35 on the lane). `--check` prints SetCheck's JSON (reach distances, collisions)
## as `[setcheck] {...}` and quits with exit 1 on any error — headless works (tools/scripts/sandbox.sh).
## `--pass=id` renders flat ID colours per region and writes the legend lab.py reads (`--legend=`).
extends Node3D

const CAM_SCRIPT := "res://view3d/camera/camera_director_3d.gd"
const RIG_SCRIPT := "res://view3d/char/rig_player_3d.gd"
const BG := Color("#1D1728")

var args: Dictionary = {}
var db: ContentDB = null
var result: SetList.Result = null
var house: House3D = null
var cam: Camera3D = null
var overlay: Control = null
var chars: Dictionary = {}
var check: Dictionary = {}
var _frame := 0
var _id_regions: Array = []
## Set by SetPreviewBatch3D before the node enters the tree: these user args replace the command line's.
var preset_args: PackedStringArray = PackedStringArray()


func _ready() -> void:
	for a in (preset_args if not preset_args.is_empty() else OS.get_cmdline_user_args()):
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var content := get_node_or_null("/root/Content")
	db = content.get("db") as ContentDB if content != null else ContentDB.load_dir("res://data")
	var ep_id := SetGeo.s(args.get("episode", "p00_curtain_up"))
	var ep: EpisodeDef = db.episodes.get(ep_id, null)
	if ep == null:
		printerr("[SetPreview3D] unknown episode %s" % ep_id)
		get_tree().quit(2)
		return
	result = SetList.for_episode(db, ep)
	house = House3D.new()
	# the ID pass colours every piece: keep them separate meshes
	house.merge_static = SetGeo.s(args.get("pass", "")) != "id" and not args.has("no-merge")
	add_child(house)
	house.build(result, {}, db)
	print("[SetPreview3D] %s built in %.1f ms: %s" % [ep_id, house.build_ms, JSON.stringify(house.stats())])
	print("[SetPreview3D] set %s" % JSON.stringify(result.to_dict()))
	if args.has("counts"):
		# per built room: live props, dressing / decor / furniture pieces, triangles (shell passes included), draws
		var counts := {}
		for rid in house.rooms_built():
			var live_n := result.live_props_in(rid).size()
			var pieces := 0
			for pid in result.dressing + result.decor + result.furniture_pieces:
				var dp := house.decor(pid)
				if dp is Prop3D and (dp as Prop3D).room == rid:
					pieces += 1
			var furn := 0
			for pr in house.props():
				if pr.room == rid and not pr.live:
					furn += 1
			counts[rid] = {"lit": result.rooms_lit.has(rid), "live": live_n, "pieces": pieces, "furniture_props": furn,
				"tris": house.room_tris(rid), "static_draws": house.static_draws(rid), "prop_draws": live_n * 3 + furn}
		print("[counts] " + JSON.stringify(counts))
	if args.has("check"):
		check = SetCheck.run(house)
		print("[setcheck] " + JSON.stringify(check))
		if DisplayServer.get_name() == "headless" or not args.has("shot"):
			get_tree().quit(1 if not (check["errors"] as Array).is_empty() else 0)
			return
	_setup_env()
	_apply_lights()
	_apply_states()
	_setup_camera()
	if args.has("chars"):
		_place_chars()
	if args.has("reach"):
		_draw_reach()
	if SetGeo.s(args.get("pass", "")) == "id":
		_id_pass()
	overlay = _Overlay.new()
	overlay.preview = self
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(overlay)


func _process(_dt: float) -> void:
	_frame += 1
	if _frame == 4 and args.has("rects-json") and cam != null:
		_write_rects(SetGeo.s(args["rects-json"]))
	if args.has("perf") and _frame > 0 and _frame % 10 == 0:
		# the frame's render counters (the §7 budgets: ≤ 45 draws for a framed room + two dimmed strips)
		print("[perf] frame %d draws %d objects %d primitives %d video_mem_mb %.1f texture_mem_mb %.1f" % [_frame,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0])


## The screen rects (px, [x, y, w, h]) of the live props' hit boxes and visuals, the landings and the decor pieces.
func _write_rects(path: String) -> void:
	var vp := get_viewport().get_visible_rect().size
	var live := {}
	for pr in house.props():
		if not pr.live:
			continue
		live[pr.hotspot_id] = {"room": pr.room, "verb": pr.verb, "hit": _rect_arr(_Overlay.proj_aabb(cam, house.hotspot_box(pr.hotspot_id))),
			"visual": _rect_arr(_Overlay.proj_aabb(cam, pr.home_aabb()))}
	var lands := {}
	for lid in result.landings:
		var lb := house.landing_box(lid)
		if lb.size != Vector3.ZERO:
			var lp := house.landing_point(lid)
			var pt: Vector2 = cam.unproject_position(lp.get("pos", lb.get_center()))
			lands[lid] = {"box": _rect_arr(_Overlay.proj_aabb(cam, lb)), "point": [pt.x, pt.y]}
	var dec := {}
	for pid in result.dressing + result.decor + result.furniture_pieces:
		var d := house.decor(pid)
		if d is Prop3D:
			dec[pid] = {"visual": _rect_arr(_Overlay.proj_aabb(cam, (d as Prop3D).home_aabb()))}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"size": [vp.x, vp.y], "live": live, "landings": lands, "decor": dec}, "  "))
		f.close()


static func _rect_arr(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG if SetGeo.s(args.get("pass", "")) != "id" else Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)


## Room lights by the view3d levels: the framed (or --lit) room 1.0, other lit rooms 0.78 + 40 % desaturation,
## backstage 0.3.
func _apply_lights() -> void:
	var lit := SetGeo.s(args.get("lit", args.get("room", "")))
	for rid in result.rooms_lit:
		if lit == "" or rid == lit:
			house.snap_room_light(rid, 1.0, 0.0)
		else:
			house.snap_room_light(rid, 0.78, 0.4)
	for rid in result.rooms_backstage:
		house.snap_room_light(rid, 0.3, 0.0)


func _apply_states() -> void:
	var glow := SetGeo.s(args.get("glow", ""))
	var lit_room := SetGeo.s(args.get("lit", args.get("room", "")))
	for p in house.props():
		if not p.live:
			continue
		if glow == "all" and (lit_room == "" or p.room == lit_room):
			p.set_glow(Prop3D.verb_color(p.verb), 1.0)
		elif glow != "" and glow.split(",").has(p.hotspot_id):
			p.set_glow(Prop3D.verb_color(p.verb), 2.0)
	for spec in SetGeo.s(args.get("state", "")).split(",", false):
		var kv := spec.split(":")
		if kv.size() != 2:
			continue
		var targets: Array[Prop3D] = []
		if kv[0] == "all":
			for lp in house.props():
				if lp.live:
					targets.append(lp)
		elif house.prop(kv[0]) != null:
			targets.append(house.prop(kv[0]))
		for pr in targets:
			if kv[1].begins_with("rig@"):
				pr.set_rig_progress(float(kv[1].substr(4)))
			else:
				pr.set_state(StringName(kv[1]))
	var tag := SetGeo.s(args.get("tag", ""))
	for p in house.props():
		if tag == "all" or (tag == "armed" and p.state() == &"armed") or tag.split(",").has(p.hotspot_id):
			if p.live:
				p.show_tag(true, false)
	var occ := SetGeo.s(args.get("occupied", ""))
	if occ != "":
		var hp := house.prop(occ)
		if hp != null:
			hp.set_occupied(true)
			hp.eyes_look(Vector2(float(args.get("look", "0.6")), 0.0))
	for spec in SetGeo.s(args.get("decor", "")).split(",", false):
		var kv2 := spec.split(":")
		if kv2.size() == 2:
			house.play_decor(kv2[0], kv2[1])


func _setup_camera() -> void:
	var room := SetGeo.s(args.get("room", ""))
	var x := 0.0
	var span := Vector2(INF, -INF)
	for rid in result.rooms_built():
		var r := db.house.room(rid)
		if r != null:
			span = Vector2(minf(span.x, r.x0 / 200.0), maxf(span.y, r.x1 / 200.0))
	x = (span.x + span.y) * 0.5
	if room != "" and db.house.room(room) != null:
		var rr := db.house.room(room)
		x = (rr.x0 + rr.x1) / 400.0
	if args.has("x"):
		x = float(args["x"])
	var used_director := false
	if ResourceLoader.exists(CAM_SCRIPT) and not args.has("x") and not args.has("zoom"):
		var sc := load(CAM_SCRIPT) as Script
		if sc != null and sc.can_instantiate():
			var cd: Camera3D = sc.new()
			add_child(cd)
			if cd.has_method("setup"):
				# the house.json Dictionary (CameraDirector3D.links_from reads a dict link's "x")
				var hj: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/house/house.json"))
				cd.call("setup", hj if typeof(hj) == TYPE_DICTIONARY else db, result)
			var target := Node3D.new()
			target.position = Vector3(x, 0.0, -1.0)
			add_child(target)
			if cd.has_method("follow"):
				cd.call("follow", target, func() -> int: return 0)
			if cd.has_method("snap_now"):
				cd.call("snap_now")
			if cd.has_method("advance"):
				cd.call("advance", 0.016, 0.016)
			cam = cd
			used_director = true
	if not used_director:
		cam = Camera3D.new()
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 30.0
		cam.near = 0.5
		cam.far = 60.0
		add_child(cam)
		var zoom := float(args.get("zoom", "1.0"))
		var dist := 7.5 / zoom
		var aim := Vector3(x, float(args.get("y", "1.35")), -1.0)
		cam.position = Vector3(x, aim.y + 0.55 * dist / 7.5, -1.0 + dist)
		cam.look_at(aim, Vector3.UP)
	cam.current = true
	print("[SetPreview3D] camera x %.2f (%s)" % [cam.global_position.x, "CameraDirector3D" if used_director else "base framing"])


## Hush and Bellows (RigPlayer3D, r3d-rig) at their typical marks for the framed room.
func _place_chars() -> void:
	if not ResourceLoader.exists(RIG_SCRIPT):
		return
	var sc := load(RIG_SCRIPT) as Script
	var room := SetGeo.s(args.get("room", "kitchen"))
	var marks := {
		"kitchen": {"hush": [14.45, -1.0, 1, "hush/loco_idle"], "bellows": [15.0, -1.4, -1, "bellows/loco_idle"]},
		"parlour": {"hush": [9.0, -1.0, 1, "hush/loco_idle"], "bellows": [8.65, -1.4, -1, "bellows/loco_idle"]},
		"hall": {"hush": [4.4, -1.0, 1, "hush/loco_idle"], "bellows": [5.9, -1.2, -1, "bellows/loco_idle"]},
		"porch": {"hush": [1.2, -1.0, 1, "hush/loco_idle"], "bellows": [2.0, -1.2, -1, "bellows/loco_idle"]},
	}
	var m: Dictionary = marks.get(room, marks["kitchen"])
	for who in ["hush", "bellows"]:
		var spec: Array = m[who]
		if args.has(who + "_x"):
			spec[0] = float(args[who + "_x"])
		if args.has(who + "_z"):
			spec[1] = float(args[who + "_z"])
		var rp: Node3D = sc.new()
		add_child(rp)
		if not bool(rp.call("setup", who)):
			continue
		rp.position = Vector3(float(spec[0]), float(args.get(who + "_y", "0.0")), float(spec[1]))
		if rp.has_method("set_facing"):
			rp.call("set_facing", int(args.get(who + "_facing", spec[2])), false)
		if rp.has_method("set_cheat"):
			rp.call("set_cheat", float(args.get(who + "_cheat", "35")), 0.0)
		var clip_id := SetGeo.s(args.get(who + "_clip", spec[3]))
		if args.has(who + "_anim_glb"):
			# a raw glb action on the same skeleton (e.g. the vendored UAL Sitting_Idle_Loop as a stand-in pose)
			var gid := ClipLib3D.load_glb_action(who, SetGeo.s(args[who + "_anim_glb"]), SetGeo.s(args.get(who + "_anim_name", "")))
			if gid != "":
				clip_id = gid
		if rp.has_method("play"):
			rp.call("play", clip_id)
		if args.has(who + "_frame") and rp.has_method("set_external_frame"):
			rp.call("set_external_frame", float(args[who + "_frame"]))
		chars[who] = rp


## --reach=hush: a translucent Hush capsule at every live rig point's reach_pos (+ step) with the shoulder → target
## line (green ≤ 0.50 m, red above) and every collision drawn red.
func _draw_reach() -> void:
	var rep := SetCheck.run(house)
	check = rep
	var cfg := SetGeo.reach_cfg(house.house3d)
	var root := Node3D.new()
	root.name = "ReachDebug"
	add_child(root)
	var hits := {}
	for c in rep["collisions"]:
		hits[SetGeo.s(c["who"])] = true
	for row in rep["reach"]:
		var id := SetGeo.s(row["hotspot"])
		var rp := house.reach_pos(id)
		if rp.is_empty():
			continue
		var bad := hits.has("hush@" + id)
		var col := Color(1.0, 0.25, 0.2, 0.45) if bad else Color(0.35, 0.8, 1.0, 0.35)
		var cap := CapsuleMesh.new()
		cap.radius = float((cfg["hush"] as Dictionary)["radius_m"])
		cap.height = float((cfg["hush"] as Dictionary)["height_m"])
		var mi := MeshInstance3D.new()
		mi.mesh = cap
		mi.material_override = _flat(col)
		mi.position = Vector3(float(rp["x"]), float(rp["step_h"]) + cap.height * 0.5, float(rp["z"]))
		root.add_child(mi)
		var sh := SetGeo.vec3(row["shoulder"])
		var tg := SetGeo.vec3(row["target"])
		_line(root, sh, tg, Color(0.2, 1.0, 0.35) if bool(row["ok"]) else Color(1.0, 0.15, 0.15))
		_dot(root, tg, 0.035, Color(1, 1, 1))
		_dot(root, sh, 0.03, Color(0.2, 1.0, 0.35) if bool(row["ok"]) else Color(1.0, 0.15, 0.15))
	for s in house.collision_solids():
		var o: Dictionary = s["obb"]
		var bad2 := false
		for c in rep["collisions"]:
			if SetGeo.s(c["solid"]) == SetGeo.s(s["id"]):
				bad2 = true
		if bad2:
			var bm := BoxMesh.new()
			bm.size = (o["half"] as Vector3) * 2.0
			var bi := MeshInstance3D.new()
			bi.mesh = bm
			bi.material_override = _flat(Color(1, 0.1, 0.1, 0.4))
			bi.position = o["center"]
			bi.rotation.y = float(o["yaw"])
			root.add_child(bi)
	# Bellows' barrel at each station of tonight (translucent orange)
	for sid in result.stations:
		var st := db.house.station(sid)
		if st == null or not result.is_room_built(st.room):
			continue
		var sd: Dictionary = (house.house3d.get("stations", {}) as Dictionary).get(sid, {})
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.45
		cyl.height = 0.85
		var ci := MeshInstance3D.new()
		ci.mesh = cyl
		var badb := hits.has("bellows@" + sid)
		ci.material_override = _flat(Color(1.0, 0.2, 0.2, 0.4) if badb else Color(1.0, 0.6, 0.2, 0.22))
		var lift := maxf(0.0, float(sd.get("seat_y_m", 0.45)) - 0.45) if sd.has("seat_y_m") else 0.0
		ci.position = Vector3(st.stand_sub / 12000.0, 0.875 + lift, float(sd.get("bellows_z", -1.4)))
		root.add_child(ci)
	print("[setcheck] " + JSON.stringify(rep))


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if c.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.albedo_color = c
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _line(parent: Node3D, a: Vector3, b: Vector3, c: Color) -> void:
	var len := a.distance_to(b)
	if len < 0.001:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = len
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	var m := _flat(c)
	m.no_depth_test = true
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var up := Vector3.UP
	var axis := up.cross(dir)
	if axis.length() > 1e-5:
		mi.global_basis = Basis(axis.normalized(), acos(clampf(up.dot(dir), -1.0, 1.0)))


func _dot(parent: Node3D, p: Vector3, r: float, c: Color) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = s
	var m := _flat(c)
	m.no_depth_test = true
	mi.material_override = m
	mi.position = p
	parent.add_child(mi)


# --- ID pass (lab.py regions) -------------------------------------------------------------------

func _id_pass() -> void:
	var legend := []
	var used := {}
	var idx := 0
	var names: Dictionary = {}
	if FileAccess.file_exists("res://art3d/set/palettes.json"):
		var pj: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art3d/set/palettes.json"))
		if typeof(pj) == TYPE_DICTIONARY:
			names = (pj as Dictionary).get("palettes", {})
	var lit_room := SetGeo.s(args.get("lit", args.get("room", "")))
	for rid in house.rooms_built():
		var shell := house.room_shell(rid)
		var lit := result.rooms_lit.has(rid) and (lit_room == "" or lit_room == rid)
		var cells: Array = names.get(rid, [])
		for mi in shell.find_children("*", "MeshInstance3D", true, false):
			var n := String(mi.name)
			if shell.from_glb() and not cells.is_empty():
				# one merged arch mesh: an ID palette maps every cell to its region (wall / wainscot / floor / other)
				var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
				img.fill(Color.BLACK)
				for ci in cells.size():
					var cname := String(cells[ci])
					var region := rid + "_arch"
					var cls := "architecture"
					if cname == "wall":
						region = rid + "_wall"
						cls = "wall"
					elif cname == "wainscot":
						region = rid + "_wainscot"
						cls = "wainscot"
					elif cname.begins_with("floor_"):
						region = rid + "_floor"
						cls = "floor"
					var col := _id_region(region, cls, rid, lit, legend, used)
					var cx := (ci % 16) * 16
					var cy := int(ci / 16.0) * 16
					img.fill_rect(Rect2i(cx, cy, 16, 16), col)
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_texture = ImageTexture.create_from_image(img)
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mi.material_override = m
				continue
			var cls2 := "architecture"
			var region2 := "%s_arch" % rid
			if n == "back_wall":
				cls2 = "wall"
				region2 = rid + "_wall"
			elif n == "wainscot":
				cls2 = "wainscot"
				region2 = rid + "_wainscot"
			elif n.begins_with("floor_"):
				cls2 = "floor"
				region2 = rid + "_floor"
			_id_flat(mi, _id_region(region2, cls2, rid, lit, legend, used))
	for p in house.props():
		var cls3 := "live_prop" if p.live else "furniture"
		var col3 := _id_region(p.hotspot_id, cls3, p.room, true, legend, used, {"halo": true} if p.live else {})
		for mi in p.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).ends_with("_ink") or String(mi.name).ends_with("_halo"):
				(mi as MeshInstance3D).visible = false
				continue
			_id_flat(mi, col3)
	for pid in result.dressing + result.decor + result.furniture_pieces:
		var d := house.decor(pid)
		if d == null:
			continue
		var is_dress := result.dressing.has(pid) or result.decor.has(pid)
		var extra := {"wall": (d as Prop3D).room + "_wall"} if is_dress else {}
		if pid == "kitchen_lamp":
			extra["exempt"] = "the light source (REDESIGN §3.7)"
		var col4 := _id_region(pid, "dressing" if is_dress else "furniture", (d as Prop3D).room, true, legend, used, extra)
		for mi in d.find_children("*", "MeshInstance3D", true, false):
			_id_flat(mi, col4)
	var stage_col := _id_region("stage", "architecture", "", true, legend, used)
	for n2 in house.get_children():
		if String(n2.name) == "Stage":
			for mi in n2.find_children("*", "MeshInstance3D", true, false):
				_id_flat(mi, stage_col)
	for who in chars.keys():
		var colc := _id_region(who, "character", "", true, legend, used)
		for mi in (chars[who] as Node3D).find_children("*", "MeshInstance3D", true, false):
			_id_flat(mi, colc)
	var path := SetGeo.s(args.get("legend", ""))
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"regions": legend}, "  "))
			f.close()
	print("[SetPreview3D] id pass: %d regions" % legend.size())


func _id_region(region: String, cls: String, room: String, lit: bool, legend: Array, used: Dictionary, extra: Dictionary = {}) -> Color:
	if used.has(region):
		return used[region]
	var col := _id_color(used.size() + 1)
	used[region] = col
	var row := {"color": "#" + col.to_html(false).to_upper(), "name": region, "class": cls}
	if room != "":
		row["room"] = room
	if (cls == "wall" or cls == "floor") and not lit:
		row["lit"] = false
	for k in extra.keys():
		row[k] = extra[k]
	legend.append(row)
	return col


func _id_flat(mi: MeshInstance3D, col: Color) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mi.material_override = m
	for c in mi.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false


static func _id_color(i: int) -> Color:
	# well-separated 8-bit ids that survive the sRGB round trip: 5 levels per channel (50…250), never black
	var lv := [50, 100, 150, 200, 250]
	return Color8(lv[i % 5], lv[int(i / 5.0) % 5], lv[int(i / 25.0) % 5])


# --- the 2D overlay (hit rects, anchors, reach table) --------------------------------------------

class _Overlay:
	extends Control
	var preview: Node = null

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var p: Node = preview
		if p == null or p.get("cam") == null:
			return
		var cam: Camera3D = p.get("cam")
		var a: Dictionary = p.get("args")
		var house: House3D = p.get("house")
		var res: SetList.Result = p.get("result")
		var font := ThemeDB.fallback_font
		var sc := get_viewport_rect().size.y / 1080.0
		if a.has("hit-rects"):
			for id in res.live.keys():
				var box := house.hotspot_box(id)
				var r := _proj_aabb(cam, box)
				var kind := SetGeo.s(res.live[id])
				var c := Prop3D.verb_color(kind)
				draw_rect(r, Color(c, 0.9), false, 3.0 * sc)
				var logical := r.size / sc
				draw_string(font, r.position + Vector2(4, 26 * sc), "%s %dx%d" % [id.replace("kitchen_", "").replace("parlour_", "").replace("hall_", ""),
					int(logical.x), int(logical.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * sc), Color(1, 1, 1))
		if a.has("anchors"):
			for pr in house.props():
				if not pr.live:
					continue
				for k in [&"preview", &"tag", &"ring", &"item", &"eyes", &"reach"]:
					if pr.entry.get({&"preview": "preview_anchor", &"tag": "tag_socket", &"ring": "ring_anchor", &"item": "item_anchor",
							&"eyes": "eyes_anchor", &"reach": "reach_target"}[k], null) == null:
						continue
					var w := pr.anchor(k)
					var s := cam.unproject_position(w)
					draw_circle(s, 7.0 * sc, {&"preview": Color(1, 0.9, 0.2), &"tag": Color(1, 0.2, 0.3), &"ring": Color(0.3, 1, 0.4),
						&"item": Color(1, 1, 1), &"eyes": Color(0.4, 0.6, 1), &"reach": Color(1, 0.5, 0)}[k])
		if a.has("landings"):
			for lid in res.landings:
				var lb := house.landing_box(lid)
				if lb.size == Vector3.ZERO:
					continue
				var lr := _proj_aabb(cam, lb)
				draw_rect(lr, Color(0.35, 0.85, 1.0, 0.18), true)
				draw_rect(lr, Color(0.35, 0.85, 1.0, 0.95), false, 3.0 * sc)
				var lp: Dictionary = house.landing_point(lid)
				var pt := cam.unproject_position(lp.get("pos", lb.get_center()))
				draw_circle(pt, 9.0 * sc, Color(1, 1, 1))
				draw_circle(pt, 6.0 * sc, Color(0.1, 0.5, 0.9))
				draw_string(font, lr.position + Vector2(6, 28 * sc), "landing %s" % lid, HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * sc), Color(1, 1, 1))
		var chk: Dictionary = p.get("check")
		if a.has("reach") and not chk.is_empty():
			var y := 90.0 * sc
			for row in chk["reach"]:
				draw_string(font, Vector2(24 * sc, y), "%s  %.3f m  %s  %s" % [row["hotspot"], row["dist"], row["band"], "OK" if row["ok"] else "TOO FAR"],
					HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * sc), Color(0.6, 1, 0.6) if row["ok"] else Color(1, 0.4, 0.4))
				y += 30.0 * sc
			for c in chk["collisions"]:
				draw_string(font, Vector2(24 * sc, y), "HIT %s → %s %.3f" % [c["who"], c["solid"], c["depth"]], HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * sc), Color(1, 0.3, 0.3))
				y += 30.0 * sc

	func _proj_aabb(cam: Camera3D, b: AABB) -> Rect2:
		return proj_aabb(cam, b)

	## The screen rect of a world AABB (its 8 corners projected).
	static func proj_aabb(cam: Camera3D, b: AABB) -> Rect2:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for i in 8:
			var s := cam.unproject_position(b.get_endpoint(i))
			lo = lo.min(s)
			hi = hi.max(s)
		return Rect2(lo, hi - lo)
