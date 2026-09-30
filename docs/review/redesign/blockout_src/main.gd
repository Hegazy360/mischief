extends Node3D
## REDESIGN_3D blockout: a greybox "dollhouse cutaway" of the Night-1 set (kitchen + parlour edge) with toy
## stand-ins for Hush and Bellows, the proposed camera, lighting, outlines and the decluttered HUD. It exists to
## check the spec's numbers (framing, character px, value hierarchy) on a 20:9 phone frame. Not game code.

const PX := 200.0          # sim px per metre (spec §4.4)
const LANE_Z := -1.0       # the characters' walking lane
const BACK_Z := -2.4       # back wall face
const ROOM_H := 3.2
const CAM_D := 7.5         # camera distance to the lane
const CAM_Y := 1.9
const AIM_Y := 1.35
const FOV := 30.0

var toon: Shader
var outl: Shader
var halo_sh: Shader
var args := {}
var mock := "plan"
var cam: Camera3D
var frames := 0
var shot_frames := 8
var shot_path := ""
var anchors := {}          # name -> Vector3 (HUD overlay anchors)
var hud_root: Control
var pip_vp: SubViewport
var font_display: FontFile
var font_ui: FontFile
var room_stage := {"hall": 0.72, "parlour": 0.78, "kitchen": 1.0}
var room_desat := {"hall": 0.45, "parlour": 0.4, "kitchen": 0.0}

# palette (spec §2.5): walls mid-value, low chroma; interactives saturated; characters extreme values
const INK := Color("1b2340")
const C_WALL := {"hall": Color("9fae96"), "parlour": Color("c49a93"), "kitchen": Color("d7c28e")}
const C_WAINS := {"hall": Color("879a80"), "parlour": Color("aa7f78"), "kitchen": Color("bca772")}
const C_FLOOR := Color("8a5f40")
const C_FLOOR_FRONT := Color("5a3b27")


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	mock = args.get("mock", "plan")
	shot_path = args.get("shot", "")
	shot_frames = int(args.get("frames", "8"))
	toon = load("res://toon.gdshader")
	outl = load("res://outline.gdshader")
	halo_sh = load("res://halo.gdshader")
	font_display = load("res://fonts/LilitaOne-Regular.ttf")
	font_ui = load("res://fonts/Nunito-Black.ttf")
	if mock.begins_with("hall2"):
		room_stage = {"hall": 1.0, "parlour": 0.78, "kitchen": 0.72}
		room_desat = {"hall": 0.0, "parlour": 0.4, "kitchen": 0.45}
	_build_house()
	_build_cast()
	_setup_camera()
	_build_hud()


func _process(_d: float) -> void:
	frames += 1
	if hud_root:
		hud_root.queue_redraw()
	if frames == shot_frames and shot_path != "":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		_report()
		get_tree().quit()


func _report() -> void:
	for k in ["hush_top", "hush_feet", "bellows_top", "bellows_feet"]:
		if anchors.has(k):
			var p: Vector2 = cam.unproject_position(anchors[k])
			var vp := get_viewport().get_visible_rect().size
			print("[measure] %s screen y = %.1f of %.0f (%.1f %%)" % [k, p.y, vp.y, 100.0 * p.y / vp.y])
	var vis_w := 2.0 * CAM_D * tan(deg_to_rad(FOV * 0.5)) * get_viewport().get_visible_rect().size.aspect()
	print("[measure] visible width at the lane = %.2f m" % vis_w)


# ---------------------------------------------------------------------------------------------- materials

func mat(col: Color, ol := 0.0, box := false, room := "", rim := 0.0, glow := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = toon
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("glow", glow)
	if room != "":
		m.set_shader_parameter("stage", room_stage.get(room, 1.0))
		m.set_shader_parameter("desat", room_desat.get(room, 0.0))
	if ol > 0.0:
		var o := ShaderMaterial.new()
		o.shader = outl
		o.set_shader_parameter("width_1080", ol)
		o.set_shader_parameter("pos_dir", 1.0 if box else 0.0)
		if room != "":
			o.set_shader_parameter("stage", room_stage.get(room, 1.0))
		m.next_pass = o
	return m


## Interactive prop material: toon + ink outline + verb halo. verb: "rig" gold, "hide" blue, "take" cream.
func imat(col: Color, verb: String, box := false, room := "") -> ShaderMaterial:
	var m := mat(col, 2.5, box, room)
	var gc: Color = {"rig": Color(1.0, 0.78, 0.25), "hide": Color(0.4, 0.65, 1.0), "take": Color(1.0, 0.95, 0.8)}[verb]
	m.set_shader_parameter("glow", 0.22)
	m.set_shader_parameter("glow_col", gc)
	var hc: Color = {"rig": Color(1.0, 0.80, 0.22, 0.75), "hide": Color(0.36, 0.62, 1.0, 0.75), "take": Color(1.0, 0.96, 0.86, 0.8)}[verb]
	var hm := ShaderMaterial.new()
	hm.shader = halo_sh
	hm.set_shader_parameter("col", hc)
	hm.set_shader_parameter("width_1080", 8.0)
	hm.set_shader_parameter("pos_dir", 1.0 if box else 0.0)
	(m.next_pass as ShaderMaterial).next_pass = hm
	return m


func flat_mat(col: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func add_mesh(mesh: Mesh, m: Material, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	(parent if parent else self).add_child(mi)
	return mi


func box(sz: Vector3, pos: Vector3, m: Material, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = sz
	return add_mesh(b, m, pos, rot, Vector3.ONE, parent)


func ball(r: float, pos: Vector3, m: Material, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return add_mesh(s, m, pos, Vector3.ZERO, scl, parent)


func cyl(rt: float, rb: float, h: float, pos: Vector3, m: Material, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 24
	return add_mesh(c, m, pos, rot, Vector3.ONE, parent)


func caps(r: float, h: float, pos: Vector3, m: Material, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 6
	return add_mesh(c, m, pos, rot, Vector3.ONE, parent)


func torus(ri: float, ro: float, pos: Vector3, m: Material, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = ri
	t.outer_radius = ro
	t.rings = 24
	t.ring_segments = 10
	return add_mesh(t, m, pos, rot, Vector3.ONE, parent)


func mx(px: float) -> float:
	return px / PX


# ---------------------------------------------------------------------------------------------- the set

func _room_shell(id: String, x0px: float, x1px: float) -> void:
	var x0 := mx(x0px)
	var x1 := mx(x1px)
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var wall := mat(C_WALL[id], 0.0, true, id)
	var wains := mat(C_WAINS[id], 0.0, true, id)
	box(Vector3(w, ROOM_H, 0.1), Vector3(cx, ROOM_H * 0.5, BACK_Z - 0.05), wall)
	box(Vector3(w, 0.95, 0.04), Vector3(cx, 0.475, BACK_Z + 0.02), wains)
	# picture rail (one thin line, low contrast)
	box(Vector3(w, 0.05, 0.05), Vector3(cx, 2.35, BACK_Z + 0.025), wains)
	# floor with the stage lip
	box(Vector3(w, 0.3, 2.65), Vector3(cx, -0.15, BACK_Z * 0.5 + 0.125), mat(C_FLOOR, 0.0, true, id))
	box(Vector3(w, 0.3, 0.02), Vector3(cx, -0.15, 0.26), mat(C_FLOOR_FRONT, 0.0, true, id))
	# ceiling (dark fly space edge)
	box(Vector3(w, 0.25, 2.7), Vector3(cx, ROOM_H + 0.125, BACK_Z * 0.5 + 0.1), mat(Color("2a2238"), 0.0, true, id))


func _wing_flat(xpx: float, room: String) -> void:
	# a partition "wing": from the back wall to mid depth, so the front lane is open between rooms
	var x := mx(xpx)
	box(Vector3(0.22, ROOM_H, 1.0), Vector3(x, ROOM_H * 0.5, BACK_Z + 0.5), mat(Color("e9dcc4"), 0.0, true, room))
	box(Vector3(0.26, 0.12, 1.02), Vector3(x, 0.06, BACK_Z + 0.5), mat(Color("6d4a33"), 0.0, true, room))


func _build_house() -> void:
	# Night 1 set: hall | parlour | kitchen (kitchen live). Only what N1 uses is on stage.
	_room_shell("hall", 500, 1500)
	_room_shell("parlour", 1500, 2800)
	_room_shell("kitchen", 2800, 3900)
	_wing_flat(1500, "parlour")
	_wing_flat(2800, "kitchen")
	# right end: back door + closed stage flat (conservatory not built)
	box(Vector3(0.24, ROOM_H, 2.6), Vector3(mx(3900) + 0.12, ROOM_H * 0.5, BACK_Z * 0.5 + 0.1), mat(Color("3a2f45"), 0.0, true, "kitchen"))
	box(Vector3(0.06, 2.1, 0.9), Vector3(mx(3900) - 0.02, 1.05, -1.9), mat(Color("4f7a5a"), 2.0, true, "kitchen"))
	# floor lip gilded edge (the stage front) across the whole set
	box(Vector3(mx(3900) - mx(500) + 0.3, 0.05, 0.04), Vector3((mx(500) + mx(3900)) * 0.5, -0.02, 0.28), mat(Color("c99a3a"), 0.0, true, ""))
	# proscenium header: a clean dark band across the top of the frame (the HUD row sits on it)
	box(Vector3(40.0, 0.8, 0.1), Vector3(12.0, ROOM_H + 0.32, 0.45), mat(Color("1d1728"), 0.0, true, ""))
	box(Vector3(40.0, 0.05, 0.12), Vector3(12.0, ROOM_H - 0.07, 0.45), mat(Color("b8923a"), 0.0, true, ""))
	# the dark void beyond the built set
	box(Vector3(12.0, 8.0, 0.1), Vector3(mx(3900) + 6.2, 2.0, BACK_Z - 0.2), mat(Color("120e18"), 0.0, true, ""))
	_kitchen_n1()
	_parlour_n1()
	if mock.begins_with("hall2"):
		_hall_n2()
	else:
		_hall_n1()


func _kitchen_n1() -> void:
	var r := "kitchen"
	var cab := mat(Color("a9b7a0"), 0.0, true, r)        # station furniture: close to the wall value
	var top := mat(Color("d8d2c0"), 0.0, true, r)
	# tea counter (st_tea 2940) with the stool
	var tx := mx(2940)
	box(Vector3(1.15, 0.88, 0.62), Vector3(tx, 0.44, BACK_Z + 0.31), cab)
	box(Vector3(1.2, 0.05, 0.66), Vector3(tx, 0.905, BACK_Z + 0.33), top)
	# stool (dressing, low contrast)
	var stool := mat(Color("a8805e"), 0.0, false, r)
	cyl(0.2, 0.2, 0.06, Vector3(tx + 0.35, 0.72, -1.55), stool)
	for dx in [-0.12, 0.12]:
		cyl(0.025, 0.03, 0.7, Vector3(tx + 0.35 + dx, 0.35, -1.55), stool)
	# KETTLE (interactive: kettle_drum) — big copper, outlined
	var cop := imat(Color("c8662e"), "rig", false, r)
	var kx := tx - 0.18
	ball(0.25, Vector3(kx, 1.16, BACK_Z + 0.34), cop, Vector3(1.0, 0.82, 0.9))
	cyl(0.045, 0.075, 0.3, Vector3(kx + 0.3, 1.2, BACK_Z + 0.34), cop, null, Vector3(0, 0, -55))
	torus(0.12, 0.155, Vector3(kx, 1.42, BACK_Z + 0.34), mat(Color("3a2a22"), 2.0, false, r), null, Vector3(90, 0, 0))
	ball(0.05, Vector3(kx, 1.37, BACK_Z + 0.34), mat(Color("3a2a22"), 1.5, false, r))
	anchors["kettle"] = Vector3(kx, 1.62, BACK_Z + 0.34)
	# the squeaker tail poking out when armed (mock "armed")
	if mock == "armed" or mock == "trigger":
		ball(0.05, Vector3(kx + 0.43, 1.37, BACK_Z + 0.34), mat(Color("ffd23f"), 2.0, false, r))
	# wall shelf + HONEY jar + pepper pot (interactive: achoo_ria)
	box(Vector3(0.9, 0.05, 0.3), Vector3(tx + 0.1, 1.78, BACK_Z + 0.15), mat(Color("a8805e"), 0.0, true, r))
	var hx := tx + 0.22
	var honey := imat(Color("f2a51f"), "rig", false, r)
	cyl(0.17, 0.17, 0.34, Vector3(hx, 1.975, BACK_Z + 0.16), honey)
	cyl(0.18, 0.18, 0.06, Vector3(hx, 2.17, BACK_Z + 0.16), mat(Color("e23b4e"), 2.0, false, r))
	var pep := mat(Color("f4f1ea"), 2.0, false, r)
	cyl(0.06, 0.075, 0.22, Vector3(hx - 0.3, 1.915, BACK_Z + 0.16), pep)
	ball(0.065, Vector3(hx - 0.3, 2.05, BACK_Z + 0.16), mat(Color("22252e"), 1.5, false, r))
	anchors["honey"] = Vector3(hx - 0.05, 2.3, BACK_Z + 0.16)
	anchors["honey_mid"] = Vector3(hx - 0.1, 1.95, BACK_Z + 0.16)
	if mock == "armed" or mock == "trigger":
		# pepper speckle ring on the rim + the lid askew
		for i in 6:
			ball(0.018, Vector3(hx - 0.12 + i * 0.05, 2.21, BACK_Z + 0.3), mat(Color("22252e"), 0.0, false, r))
	# PICKLE jar on its own small shelf (interactive: in_a_pickle)
	var px := mx(3110)
	box(Vector3(0.55, 0.05, 0.3), Vector3(px, 1.72, BACK_Z + 0.15), mat(Color("a8805e"), 0.0, true, r))
	cyl(0.19, 0.19, 0.42, Vector3(px, 1.955, BACK_Z + 0.17), imat(Color("5fae5b"), "rig", false, r))
	cyl(0.2, 0.2, 0.07, Vector3(px, 2.2, BACK_Z + 0.17), mat(Color("e8b33a"), 2.0, false, r))
	for i in 3:
		ball(0.07, Vector3(px - 0.08 + i * 0.08, 1.87 + (i % 2) * 0.1, BACK_Z + 0.3), mat(Color("f3f0e2"), 0.0, false, r))
	anchors["pickle"] = Vector3(px, 2.38, BACK_Z + 0.17)
	# pans rail (quake prop; dressing: low contrast, no outline)
	box(Vector3(0.7, 0.04, 0.04), Vector3(px + 0.05, 2.75, BACK_Z + 0.06), mat(Color("9c8a66"), 0.0, true, r))
	for i in 2:
		cyl(0.14, 0.14, 0.04, Vector3(px - 0.12 + i * 0.3, 2.55, BACK_Z + 0.08), mat(Color("a48a64"), 0.0, false, r), null, Vector3(90, 0, 0))
	# pendant lamp (dressing)
	cyl(0.01, 0.01, 0.6, Vector3(mx(3320), ROOM_H - 0.3, -1.6), mat(Color("3a3050"), 0.0, false, r))
	cyl(0.08, 0.28, 0.2, Vector3(mx(3320), ROOM_H - 0.65, -1.6), mat(Color("e9e0c8"), 0.0, false, r))
	# PANTRY alcove + curtain (hiding: kitchen_pantry_curtain), blue rim = hiding language
	var pnx := mx(3620)
	box(Vector3(0.95, 2.15, 0.08), Vector3(pnx, 1.075, BACK_Z + 0.02), mat(Color("1d1826"), 0.0, true, r))
	var cur := imat(Color("d8a02a"), "hide", false, r)
	for i in 5:
		caps(0.1, 2.05, Vector3(pnx - 0.36 + i * 0.18, 1.08, BACK_Z + 0.12), cur)
	box(Vector3(1.05, 0.08, 0.1), Vector3(pnx, 2.19, BACK_Z + 0.1), mat(Color("6d4a33"), 0.0, true, r))
	anchors["pantry"] = Vector3(pnx, 2.3, BACK_Z + 0.12)
	# SINK unit + TAP (interactive: tap_dance) + window above (entry, dressing)
	var sx := mx(3788)
	box(Vector3(0.9, 0.88, 0.62), Vector3(sx, 0.44, BACK_Z + 0.31), cab)
	box(Vector3(0.95, 0.05, 0.66), Vector3(sx, 0.905, BACK_Z + 0.33), top)
	box(Vector3(0.6, 0.2, 0.45), Vector3(sx, 1.0, BACK_Z + 0.33), mat(Color("eef2f4"), 2.0, true, r))
	var chrome := imat(Color("aebccb"), "rig", false, r)
	cyl(0.04, 0.05, 0.42, Vector3(sx - 0.1, 1.3, BACK_Z + 0.12), chrome)
	cyl(0.035, 0.035, 0.34, Vector3(sx + 0.03, 1.5, BACK_Z + 0.2), chrome, null, Vector3(0, 0, 90))
	ball(0.07, Vector3(sx - 0.1, 1.55, BACK_Z + 0.12), mat(Color("3d7bd9"), 2.0, false, r))
	if mock == "armed" or mock == "trigger":
		cyl(0.1, 0.05, 0.1, Vector3(sx + 0.2, 1.43, BACK_Z + 0.2), mat(Color("3d7bd9"), 2.0, false, r))
	anchors["tap"] = Vector3(sx, 1.85, BACK_Z + 0.2)
	box(Vector3(0.95, 1.05, 0.05), Vector3(sx, 2.35, BACK_Z + 0.03), mat(Color("e6ddc6"), 0.0, true, r))
	box(Vector3(0.8, 0.9, 0.05), Vector3(sx, 2.35, BACK_Z + 0.05), mat(Color("a9d3e8"), 0.0, true, r))
	anchors["tea_stand"] = Vector3(mx(3000), 0.0, LANE_Z)
	if mock == "armed":
		# Hush's calling card on every armed prop: a little red beret tag on a string (spec §3.3 AFTER)
		_tag(Vector3(kx + 0.22, 1.45, BACK_Z + 0.62))
		_tag(Vector3(hx + 0.2, 2.1, BACK_Z + 0.4))
		_tag(Vector3(sx + 0.28, 1.35, BACK_Z + 0.45))


func _tag(p: Vector3) -> void:
	var red := mat(Color("e23b4e"), 2.5, false, "", 0.3, 0.25)
	var t := ball(0.14, p, red, Vector3(1.0, 0.42, 1.0))
	t.rotation_degrees = Vector3(20, 0, -18)
	cyl(0.012, 0.012, 0.05, p + Vector3(0.0, 0.05, 0.0), red)
	cyl(0.004, 0.004, 0.16, p + Vector3(-0.03, 0.14, 0.0), mat(Color("fff6ea"), 0.0, false, ""), null, Vector3(0, 0, 20))


func _parlour_n1() -> void:
	var r := "parlour"
	# fireplace (st_fireplace 2330; DRY fix-up station) — station furniture, no outline
	var fx := mx(2330)
	var marble := mat(Color("e4ddd2"), 0.0, true, r)
	box(Vector3(1.3, 0.12, 0.45), Vector3(fx, 1.3, BACK_Z + 0.22), marble)
	box(Vector3(0.22, 1.25, 0.4), Vector3(fx - 0.5, 0.63, BACK_Z + 0.2), marble)
	box(Vector3(0.22, 1.25, 0.4), Vector3(fx + 0.5, 0.63, BACK_Z + 0.2), marble)
	box(Vector3(0.8, 0.95, 0.1), Vector3(fx, 0.48, BACK_Z + 0.06), mat(Color("2a1f22"), 0.0, true, r))
	box(Vector3(0.5, 0.35, 0.1), Vector3(fx, 0.22, BACK_Z + 0.14), mat(Color("ff8a2a"), 0.0, true, r, 0.0, 0.6))
	# log basket (LIFT-OFF landing)
	cyl(0.25, 0.2, 0.3, Vector3(fx + 0.85, 0.15, -1.9), mat(Color("9b7a52"), 0.0, false, r))
	# portrait (quake prop): dressing, low contrast
	box(Vector3(0.7, 0.85, 0.05), Vector3(fx, 2.0, BACK_Z + 0.03), mat(Color("a58a55"), 0.0, true, r))
	box(Vector3(0.55, 0.7, 0.05), Vector3(fx, 2.0, BACK_Z + 0.05), mat(Color("8e7a86"), 0.0, true, r))
	# chandelier (LIFT-OFF landing): dressing silhouette, high
	cyl(0.01, 0.01, 0.35, Vector3(fx, ROOM_H - 0.18, -1.7), mat(Color("3a3050"), 0.0, false, r))
	torus(0.3, 0.36, Vector3(fx, ROOM_H - 0.52, -1.7), mat(Color("b69a55"), 0.0, false, r))
	for i in 5:
		var a := i * TAU / 5.0
		cyl(0.02, 0.02, 0.1, Vector3(fx + cos(a) * 0.33, ROOM_H - 0.44, -1.7 + sin(a) * 0.33), mat(Color("efe6cf"), 0.0, false, r))
	# RECLINER (interactive: lift_off) at 2080
	var rx := mx(2080)
	var yel := mat(Color("e4b62a"), 2.5, true, r)
	box(Vector3(0.95, 0.45, 0.8), Vector3(rx, 0.32, -1.85), yel)
	box(Vector3(0.95, 0.9, 0.22), Vector3(rx - 0.1, 0.85, -2.15), yel, null, Vector3(0, 0, 8))
	anchors["recliner"] = Vector3(rx, 1.55, -1.9)
	# the window (dressing)
	box(Vector3(0.9, 1.4, 0.05), Vector3(mx(1720), 1.9, BACK_Z + 0.03), mat(Color("a9c9da"), 0.0, true, r))
	# gramophone (warmup station, not interactive in N1) - low contrast
	var gx := mx(1640)
	box(Vector3(0.5, 0.8, 0.45), Vector3(gx, 0.4, -2.0), mat(Color("8a6a4e"), 0.0, true, r))
	cyl(0.3, 0.05, 0.5, Vector3(gx + 0.15, 1.2, -2.0), mat(Color("a58a55"), 0.0, false, r), null, Vector3(0, 0, -50))
	# piano (hiding: parlour_piano_back) at 1830 - blue-rim hiding language
	var pix := mx(1830)
	box(Vector3(1.2, 1.1, 0.7), Vector3(pix, 0.75, -2.0), mat(Color("2e3440"), 2.5, true, r))


func _hall_n2() -> void:
	# Night 2 hall: 5 interactive (phone, clock, mirror = rig; CONFISCATED box = take; coat cupboard = hide)
	var r := "hall"
	# porch (outdoor) left of the front door: sky flat + step + hedge
	box(Vector3(2.5, ROOM_H, 0.1), Vector3(1.25, ROOM_H * 0.5, BACK_Z - 0.05), mat(Color("9cc6d8"), 0.0, true, ""))
	box(Vector3(2.5, 0.3, 2.65), Vector3(1.25, -0.15, BACK_Z * 0.5 + 0.125), mat(Color("9a9486"), 0.0, true, ""))
	ball(0.6, Vector3(0.9, 0.5, -2.0), mat(Color("6f9a5e"), 0.0, false, ""), Vector3(1.3, 0.9, 0.7))
	# the front wall with the FRONT DOOR in the lane (exit; lit only after the first star)
	box(Vector3(0.24, ROOM_H, 1.3), Vector3(2.5, ROOM_H * 0.5, BACK_Z + 0.65), mat(Color("e9dcc4"), 0.0, true, r))
	box(Vector3(0.24, 1.0, 1.0), Vector3(2.5, ROOM_H - 0.5, -1.0), mat(Color("e9dcc4"), 0.0, true, r))
	box(Vector3(0.24, ROOM_H, 0.55), Vector3(2.5, ROOM_H * 0.5, -0.22), mat(Color("e9dcc4"), 0.0, true, r))
	box(Vector3(0.08, 2.15, 0.95), Vector3(2.58, 1.08, -1.0), mat(Color("3f7a52"), 2.0, true, r))
	ball(0.05, Vector3(2.64, 1.3, -0.7), mat(Color("e8b33a"), 1.5, false, r))
	# COAT CUPBOARD (hide)
	var cu := imat(Color("8a5a3a"), "hide", true, r)
	box(Vector3(0.82, 2.3, 0.55), Vector3(mx(608), 1.15, BACK_Z + 0.28), cu)
	box(Vector3(0.04, 1.9, 0.02), Vector3(mx(608), 1.15, BACK_Z + 0.57), mat(Color("5a3a26"), 0.0, true, r))
	anchors["cupboard"] = Vector3(mx(608), 2.45, BACK_Z + 0.3)
	# CONFISCATED box (take: the magnifier)
	var bx := mx(776)
	box(Vector3(0.72, 0.55, 0.55), Vector3(bx, 0.28, -1.95), imat(Color("d2a866"), "take", true, r))
	box(Vector3(0.74, 0.12, 0.02), Vector3(bx, 0.34, -1.66), mat(Color("c8323f"), 0.0, true, r))
	cyl(0.02, 0.02, 0.3, Vector3(bx + 0.18, 0.66, -1.95), mat(Color("6d4a33"), 1.5, false, r), null, Vector3(0, 0, -30))
	torus(0.07, 0.1, Vector3(bx + 0.28, 0.84, -1.95), mat(Color("e8b33a"), 1.5, false, r), null, Vector3(90, 0, 0))
	anchors["box"] = Vector3(bx, 0.95, -1.95)
	# coat stand (dressing: MIRROR, MIRROR landing) - low contrast, no outline
	cyl(0.025, 0.03, 1.9, Vector3(mx(862), 0.95, -2.1), mat(Color("7d6a57"), 0.0, false, r))
	ball(0.16, Vector3(mx(862) + 0.1, 1.85, -2.1), mat(Color("75806f"), 0.0, false, r), Vector3(1.2, 0.5, 1.0))
	# phone table (station) + PHONE (rig: something_fishy, needs the kipper)
	var ph := mx(944)
	box(Vector3(0.6, 0.05, 0.45), Vector3(ph, 0.85, -2.05), mat(Color("8a6a4e"), 0.0, true, r))
	for dx in [-0.25, 0.25]:
		cyl(0.02, 0.025, 0.85, Vector3(ph + dx, 0.42, -2.05), mat(Color("8a6a4e"), 0.0, false, r))
	var phm := imat(Color("26242c"), "rig", false, r)
	cyl(0.1, 0.13, 0.05, Vector3(ph, 0.9, -2.05), phm)
	cyl(0.03, 0.03, 0.35, Vector3(ph, 1.08, -2.05), phm)
	cyl(0.07, 0.05, 0.1, Vector3(ph, 1.28, -2.05), phm)
	caps(0.035, 0.28, Vector3(ph + 0.14, 1.12, -2.0), mat(Color("26242c"), 2.0, false, r), null, Vector3(0, 0, 10))
	anchors["phone"] = Vector3(ph, 1.5, -2.05)
	# CHEVAL MIRROR (rig: mirror_mirror, the signature)
	var mi := mx(1112)
	var wood := imat(Color("8a5a3a"), "rig", false, r)
	torus(0.3, 0.37, Vector3(mi, 1.35, -2.1), wood, null, Vector3(90, 0, 0)).scale = Vector3(0.8, 1.0, 1.35)
	ball(0.3, Vector3(mi, 1.35, -2.12), mat(Color("bcd6e6"), 0.0, false, r, 0.4), Vector3(0.8, 1.35, 0.08))
	for dx in [-0.3, 0.3]:
		cyl(0.03, 0.03, 1.1, Vector3(mi + dx, 0.55, -2.1), mat(Color("8a5a3a"), 1.5, false, r))
	anchors["mirror"] = Vector3(mi, 2.05, -2.1)
	# GRANDFATHER CLOCK (rig: times_up)
	var ck := mx(1280)
	var ckm := imat(Color("7a4a2c"), "rig", true, r)
	box(Vector3(0.6, 2.25, 0.45), Vector3(ck, 1.125, BACK_Z + 0.25), ckm)
	cyl(0.22, 0.22, 0.04, Vector3(ck, 1.85, BACK_Z + 0.49), mat(Color("f3ecd8"), 2.0, false, r), null, Vector3(90, 0, 0))
	box(Vector3(0.02, 0.16, 0.02), Vector3(ck, 1.9, BACK_Z + 0.52), mat(INK, 0.0, true, r))
	box(Vector3(0.12, 0.02, 0.02), Vector3(ck + 0.05, 1.85, BACK_Z + 0.52), mat(INK, 0.0, true, r))
	ball(0.07, Vector3(ck, 0.9, BACK_Z + 0.48), mat(Color("e8b33a"), 1.5, false, r))
	anchors["clock"] = Vector3(ck, 2.45, BACK_Z + 0.25)
	# stair foot, roped off in Act I (upstairs closed): three dark steps + a velvet rope
	for i in 3:
		box(Vector3(0.35, 0.18, 1.0), Vector3(mx(1450) - 0.05 - i * 0.3, 0.09 + i * 0.18, -1.95), mat(Color("4a3a30"), 0.0, true, r))
	cyl(0.03, 0.03, 0.9, Vector3(mx(1450) + 0.25, 0.45, -1.45), mat(Color("c99a3a"), 0.0, false, r))
	cyl(0.02, 0.02, 0.7, Vector3(mx(1450) - 0.1, 0.8, -1.45), mat(Color("b3122e"), 0.0, false, r), null, Vector3(0, 0, 80))
	# a single window (dressing)
	box(Vector3(0.7, 1.0, 0.05), Vector3(mx(700) + 0.9, 2.2, BACK_Z + 0.03), mat(Color("b4cbd3"), 0.0, true, r))


func _hall_n1() -> void:
	var r := "hall"
	box(Vector3(0.8, 2.3, 0.5), Vector3(mx(608), 1.15, -2.1), mat(Color("7b5236"), 2.5, true, r))
	box(Vector3(0.7, 0.55, 0.55), Vector3(mx(776), 0.28, -1.9), mat(Color("c9a468"), 2.5, true, r))
	box(Vector3(0.1, 1.9, 0.1), Vector3(mx(1112), 0.95, -2.1), mat(Color("7b5236"), 0.0, true, r))
	ball(0.35, Vector3(mx(1112), 1.35, -2.1), mat(Color("c5cfd8"), 0.0, false, r), Vector3(0.8, 1.3, 0.1))


# ---------------------------------------------------------------------------------------------- the cast

func _hush(pos: Vector3, facing: int, pose: String) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	# the body yaws toward the camera ("cheat out"): facing ±x, turned 35° toward the audience
	root.rotation_degrees.y = 90.0 * facing - 35.0 * facing
	var navy := mat(Color("26305e"), 3.5, false, "", 0.55)
	var white := mat(Color("fff6ea"), 3.5, false, "", 0.35)
	var red := mat(Color("e23b4e"), 3.5, false, "", 0.4)
	var black := mat(Color("15131c"), 0.0, false, "")
	var hair := mat(Color("3b2a2a"), 3.5, false, "", 0.4)
	var crouch := 0.0
	if pose == "freeze":
		crouch = 0.0
	# legs + shoes
	for sx in [-0.09, 0.09]:
		caps(0.075, 0.66, Vector3(sx, 0.33 - crouch, 0), navy, root)
		ball(0.09, Vector3(sx, 0.05, 0.06), mat(Color("15131c"), 3.5, false, ""), Vector3(1.0, 0.6, 1.5), root)
	# torso: Breton stripes (bands)
	caps(0.19, 0.62, Vector3(0, 0.93, 0), navy, root)
	for i in 4:
		cyl(0.196, 0.196, 0.045, Vector3(0, 0.76 + i * 0.1, 0), mat(Color("fff6ea"), 0.0, false, ""), root)
	# braces
	for sx in [-0.09, 0.09]:
		box(Vector3(0.04, 0.5, 0.04), Vector3(sx, 0.95, 0.18), red, root)
	# Clarence in the braces (yellow)
	ball(0.07, Vector3(0.16, 0.86, 0.13), mat(Color("ffd23f"), 3.0, false, "", 0.3), Vector3(1, 1.3, 1), root)
	ball(0.03, Vector3(0.17, 0.99, 0.15), red, Vector3.ONE, root)
	# head, hair, face
	var head_y := 1.37
	ball(0.235, Vector3(0, head_y, 0), white, Vector3(1, 1.02, 1), root)
	ball(0.245, Vector3(0, head_y + 0.03, -0.05), hair, Vector3(1.02, 0.95, 0.92), root)
	for sx in [-0.075, 0.075]:
		ball(0.05, Vector3(sx, head_y + 0.02, 0.2), mat(Color("ffffff"), 0.0, false, ""), Vector3(1, 1.25, 0.6), root)
		ball(0.032, Vector3(sx + 0.005, head_y + 0.015, 0.23), black, Vector3(1, 1.2, 0.6), root)
		ball(0.035, Vector3(sx * 1.45, head_y - 0.07, 0.19), mat(Color("ff9aa2"), 0.0, false, ""), Vector3(1, 0.7, 0.4), root)
	ball(0.04, Vector3(0, head_y - 0.1, 0.22), mat(Color("b8324b"), 0.0, false, ""), Vector3(1.4, 0.55, 0.5), root)
	# beret (tilted) + stalk
	var ber := ball(0.25, Vector3(0.06, head_y + 0.2, 0.0), red, Vector3(1.0, 0.38, 1.0), root)
	ber.rotation_degrees = Vector3(12, 0, -16)
	cyl(0.014, 0.02, 0.07, Vector3(0.04, head_y + 0.3, 0.0), red, root, Vector3(0, 0, -16))
	# arms + big gloves by pose
	var arm := navy
	var glove := white
	match pose:
		"rig_high":
			# right arm up shaking the pepper over the jar, left hand holding the lid
			caps(0.055, 0.5, Vector3(0.2, 1.3, 0.05), arm, root, Vector3(0, 0, -160))
			ball(0.105, Vector3(0.28, 1.58, 0.08), glove, Vector3.ONE, root)
			cyl(0.055, 0.07, 0.2, Vector3(0.3, 1.72, 0.08), mat(Color("f4f1ea"), 2.0, false, ""), root, Vector3(0, 0, 160))
			caps(0.055, 0.45, Vector3(-0.22, 1.12, 0.1), arm, root, Vector3(20, 0, 60))
			ball(0.105, Vector3(-0.38, 1.22, 0.16), glove, Vector3.ONE, root)
		"statue":
			caps(0.055, 0.5, Vector3(0.2, 1.42, 0.02), arm, root, Vector3(0, 0, -150))
			ball(0.105, Vector3(0.3, 1.7, 0.04), glove, Vector3.ONE, root)
			caps(0.055, 0.45, Vector3(-0.24, 1.18, 0.05), arm, root, Vector3(0, 0, 100))
			ball(0.105, Vector3(-0.48, 1.2, 0.06), glove, Vector3.ONE, root)
		"sneak":
			caps(0.055, 0.42, Vector3(0.22, 1.08, 0.1), arm, root, Vector3(-40, 0, -70))
			ball(0.105, Vector3(0.36, 1.2, 0.22), glove, Vector3.ONE, root)
			caps(0.055, 0.42, Vector3(-0.22, 1.08, 0.1), arm, root, Vector3(-40, 0, 70))
			ball(0.105, Vector3(-0.36, 1.2, 0.22), glove, Vector3.ONE, root)
		_:
			caps(0.055, 0.45, Vector3(0.23, 0.95, 0.02), arm, root, Vector3(0, 0, 12))
			ball(0.105, Vector3(0.28, 0.7, 0.04), glove, Vector3.ONE, root)
			caps(0.055, 0.45, Vector3(-0.23, 0.95, 0.02), arm, root, Vector3(0, 0, -12))
			ball(0.105, Vector3(-0.28, 0.7, 0.04), glove, Vector3.ONE, root)
	anchors["hush_top"] = pos + Vector3(0, 1.62, 0)
	anchors["hush_feet"] = pos
	anchors["hush_head"] = pos + Vector3(0, 1.4, 0)
	return root


func _bellows(pos: Vector3, facing: int, pose: String) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	root.rotation_degrees.y = 90.0 * facing - 35.0 * facing
	var plum := mat(Color("7b3f8c"), 3.5, false, "", 0.5)
	var cream := mat(Color("f3e3c3"), 3.5, false, "", 0.3)
	var peach := mat(Color("f4c09c"), 3.5, false, "", 0.35)
	var silver := mat(Color("e3e6ee"), 3.5, false, "", 0.35)
	var gold := mat(Color("e8b33a"), 3.0, false, "", 0.3)
	var trous := mat(Color("3a3050"), 3.5, false, "", 0.4)
	for sx in [-0.12, 0.12]:
		caps(0.085, 0.42, Vector3(sx, 0.2, 0), trous, root)
		ball(0.1, Vector3(sx, 0.05, 0.07), mat(Color("b8324b"), 3.5, false, ""), Vector3(1.0, 0.6, 1.6), root)
	# barrel torso
	ball(0.42, Vector3(0, 0.82, 0), plum, Vector3(1.0, 1.05, 0.88), root)
	ball(0.34, Vector3(0, 0.8, 0.12), cream, Vector3(0.8, 0.95, 0.75), root)
	for i in 3:
		ball(0.025, Vector3(0.0, 0.66 + i * 0.12, 0.38), gold, Vector3.ONE, root)
	# cravat
	ball(0.1, Vector3(0, 1.2, 0.2), gold, Vector3(1.3, 0.8, 0.8), root)
	# head
	var hy := 1.38
	ball(0.22, Vector3(0, hy, 0.02), peach, Vector3(1, 1.05, 1), root)
	ball(0.085, Vector3(0, hy - 0.02, 0.24), mat(Color("f09a86"), 3.0, false, ""), Vector3(1, 0.9, 1), root)
	for sx in [-1.0, 1.0]:
		ball(0.11, Vector3(sx * 0.19, hy - 0.06, 0.05), silver, Vector3(0.7, 1.2, 0.9), root)
		ball(0.045, Vector3(sx * 0.075, hy + 0.06, 0.19), mat(Color("ffffff"), 0.0, false, ""), Vector3(1, 1.15, 0.6), root)
		ball(0.026, Vector3(sx * 0.075, hy + 0.055, 0.22), mat(Color("15131c"), 0.0, false, ""), Vector3(1, 1.1, 0.6), root)
		ball(0.05, Vector3(sx * 0.08, hy + 0.13, 0.19), silver, Vector3(1.2, 0.45, 0.5), root)
	# bouffant: a dandelion clock of silver puffs
	var puffs := [Vector3(0, 0.2, 0), Vector3(-0.15, 0.16, -0.02), Vector3(0.15, 0.16, -0.02), Vector3(-0.08, 0.3, -0.04),
		Vector3(0.08, 0.3, -0.04), Vector3(0, 0.36, -0.08), Vector3(-0.2, 0.05, -0.06), Vector3(0.2, 0.05, -0.06)]
	for p in puffs:
		ball(0.13, Vector3(0, hy, 0) + p, silver, Vector3.ONE, root)
	# specs dangling on a chain (specs off)
	torus(0.035, 0.05, Vector3(0.06, 1.1, 0.34), mat(Color("2a2438"), 0.0, false, ""), root, Vector3(90, 0, 0))
	torus(0.035, 0.05, Vector3(-0.06, 1.1, 0.34), mat(Color("2a2438"), 0.0, false, ""), root, Vector3(90, 0, 0))
	# arms
	match pose:
		"walk_cup":
			caps(0.07, 0.45, Vector3(0.36, 0.95, 0.1), plum, root, Vector3(-50, 0, -40))
			ball(0.09, Vector3(0.46, 0.9, 0.34), peach, Vector3.ONE, root)
			caps(0.07, 0.45, Vector3(-0.38, 0.9, 0.0), plum, root, Vector3(0, 0, -20))
			ball(0.09, Vector3(-0.44, 0.66, 0.04), peach, Vector3.ONE, root)
		"sneeze":
			caps(0.07, 0.45, Vector3(0.36, 1.1, 0.1), plum, root, Vector3(0, 0, -120))
			ball(0.09, Vector3(0.58, 1.22, 0.1), peach, Vector3.ONE, root)
			caps(0.07, 0.45, Vector3(-0.36, 1.1, 0.1), plum, root, Vector3(0, 0, 120))
			ball(0.09, Vector3(-0.58, 1.22, 0.1), peach, Vector3.ONE, root)
		_:
			caps(0.07, 0.45, Vector3(0.38, 0.9, 0.0), plum, root, Vector3(0, 0, 20))
			ball(0.09, Vector3(0.44, 0.66, 0.04), peach, Vector3.ONE, root)
			caps(0.07, 0.45, Vector3(-0.38, 0.9, 0.0), plum, root, Vector3(0, 0, -20))
			ball(0.09, Vector3(-0.44, 0.66, 0.04), peach, Vector3.ONE, root)
	anchors["bellows_top"] = pos + Vector3(0, 1.78, 0)
	anchors["bellows_feet"] = pos
	anchors["bellows_head"] = pos + Vector3(0, 1.95, 0)
	return root


func _stone(n: Node) -> void:
	# FREEZE look: every part turns to marble (desaturated, lightened) with the ink outline kept
	for c in n.get_children():
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).material_override as ShaderMaterial
			if m:
				var a: Color = m.get_shader_parameter("albedo")
				var g := a.get_luminance()
				if (c as MeshInstance3D).mesh is SphereMesh and ((c as MeshInstance3D).mesh as SphereMesh).radius < 0.06:
					continue   # eyes, pupils, blush, mouth stay alive (the eyes dart)
				if a.is_equal_approx(Color("e23b4e")):
					continue   # the beret and braces stay red: the player never loses Hush
				m.set_shader_parameter("albedo", Color(0.78 + g * 0.2, 0.77 + g * 0.2, 0.75 + g * 0.2))
				m.set_shader_parameter("rim", 0.25)
		_stone(c)


func _blob(pos: Vector3, r: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.004
	add_mesh(c, flat_mat(Color("1a1024"), 0.32), pos + Vector3(0, 0.006, 0), Vector3.ZERO, Vector3(1, 1, 0.55))


func _stare(from: Vector3, facing: int, moving_m: float, frozen_m: float, specs_on: bool) -> void:
	var col := Color("ffb23f") if not specs_on else Color("ff6a3a")
	var q := PlaneMesh.new()
	q.size = Vector2(moving_m, 1.0)
	add_mesh(q, flat_mat(col, 0.34), Vector3(from.x + facing * moving_m * 0.5, 0.01, LANE_Z + 0.05))
	var q2 := PlaneMesh.new()
	q2.size = Vector2(frozen_m, 1.0)
	add_mesh(q2, flat_mat(col, 0.3), Vector3(from.x + facing * frozen_m * 0.5, 0.012, LANE_Z + 0.05))


func _build_cast() -> void:
	match mock:
		"hall2":
			# Hush frozen as a statue on a pop-up plinth, just outside his frozen sight
			var hp := Vector3(mx(700), 0.0, LANE_Z - 0.05)
			box(Vector3(0.62, 0.26, 0.5), hp + Vector3(0, 0.13, 0), mat(Color("c9c4bb"), 3.0, true, ""))
			var st := _hush(hp + Vector3(0, 0.26, 0), -1, "statue")
			_stone(st)
			_blob(hp, 0.4)
			_bellows(Vector3(mx(1230), 0, LANE_Z), -1, "idle")
			_blob(Vector3(mx(1230), 0, LANE_Z), 0.45)
			_stare(Vector3(mx(1230) - 0.4, 0, LANE_Z), -1, 3.0, 1.25, false)
		"hall2c":
			_hush(Vector3(mx(1195), 0, LANE_Z + 0.1), -1, "idle")
			_blob(Vector3(mx(1195), 0, LANE_Z + 0.1), 0.34)
			_bellows(Vector3(mx(2080), 0, LANE_Z - 0.2), 1, "idle")
			_blob(Vector3(mx(2080), 0, LANE_Z - 0.2), 0.45)
		"plan":
			_hush(Vector3(mx(2900), 0, LANE_Z + 0.1), 1, "idle")
			_blob(Vector3(mx(2900), 0, LANE_Z + 0.1), 0.34)
			_bellows(Vector3(mx(2480), 0, LANE_Z), 1, "walk_cup")
			_blob(Vector3(mx(2480), 0, LANE_Z), 0.45)
			_stare(Vector3(mx(2480) + 0.4, 0, LANE_Z), 1, 3.0, 1.25, false)
		"rig":
			_hush(Vector3(mx(3000), 0, LANE_Z - 0.45), 1, "rig_high")
			_blob(Vector3(mx(3000), 0, LANE_Z - 0.45), 0.34)
			_bellows(Vector3(mx(2250), 0, LANE_Z), 1, "walk_cup")
			_blob(Vector3(mx(2250), 0, LANE_Z), 0.45)
		"armed":
			_hush(Vector3(mx(3560), 0, LANE_Z + 0.1), 1, "sneak")
			_blob(Vector3(mx(3560), 0, LANE_Z + 0.1), 0.34)
			_bellows(Vector3(mx(2700), 0, LANE_Z), 1, "walk_cup")
			_blob(Vector3(mx(2700), 0, LANE_Z), 0.45)
			_stare(Vector3(mx(2700) + 0.4, 0, LANE_Z), 1, 3.0, 1.25, false)
		"trigger":
			_bellows(Vector3(mx(3040), 0, LANE_Z - 0.3), -1, "sneeze")
			_blob(Vector3(mx(3040), 0, LANE_Z - 0.3), 0.45)


# ---------------------------------------------------------------------------------------------- camera

func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.fov = FOV
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.5
	cam.far = 60.0
	add_child(cam)
	var vp := get_viewport().get_visible_rect().size
	var vis_w := 2.0 * CAM_D * tan(deg_to_rad(FOV * 0.5)) * vp.aspect()
	# room framing: the kitchen fully in view, clamped so at most 0.3 m of unbuilt space shows past x 19.5
	var cx := clampf(mx(3280), mx(2800) - 0.3 + vis_w * 0.5 - 2.0, mx(3900) + 0.3 - vis_w * 0.5)
	if mock.begins_with("hall2"):
		cx = maxf(mx(1000), -0.3 + vis_w * 0.5)
	var d := CAM_D
	var aim := Vector3(cx, AIM_Y, LANE_Z)
	if mock == "trigger":
		d = CAM_D / 1.4
		aim = Vector3(mx(3040) + 0.3, 1.25, LANE_Z)
		cx = aim.x
	cam.position = Vector3(cx, CAM_Y - (0.25 if mock == "trigger" else 0.0), LANE_Z + d)
	if mock == "trigger":
		cam.position.x += d * sin(deg_to_rad(5.0))
	cam.look_at(aim, Vector3.UP)
	print("[measure] camera x %.2f d %.2f visible width %.2f m" % [cx, d, vis_w])


# ---------------------------------------------------------------------------------------------- HUD

class Hud extends Control:
	var m: Node   # main
	func _draw() -> void:
		m._draw_hud(self)


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	var h := Hud.new()
	h.m = self
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(h)
	hud_root = h
	if mock == "hall2c":
		pip_vp = SubViewport.new()
		pip_vp.size = Vector2i(400, 225)
		pip_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(pip_vp)
		var pc := Camera3D.new()
		pc.fov = 30.0
		pip_vp.add_child(pc)
		pc.position = Vector3(mx(2080) + 0.2, 1.5, LANE_Z + 4.6)
		pc.look_at(Vector3(mx(2080), 1.1, LANE_Z - 0.2), Vector3.UP)


func _scr(p: Vector3, h: Control) -> Vector2:
	# 3D -> HUD logical coordinates (the canvas is stretched to the logical viewport)
	var win := get_viewport().get_visible_rect().size
	var s: Vector2 = cam.unproject_position(p)
	return s * (h.size / win)


func _cloud(h: Control, c: Vector2, w: float, alpha: float, big := false) -> void:
	# opaque colours (a faded cloud is drawn in a lighter, greyer palette, never as overlapping alpha)
	var col := Color(1, 1, 1).lerp(Color(0.80, 0.78, 0.80), 1.0 - alpha)
	var ink := Color(INK).lerp(Color(0.60, 0.58, 0.64), (1.0 - alpha) * 1.2)
	var hh := w * 0.8
	var pts := [Vector2(0, 0), Vector2(-0.3, -0.08), Vector2(0.3, -0.08), Vector2(-0.15, 0.12), Vector2(0.17, 0.12), Vector2(0, -0.2)]
	for p in pts:
		h.draw_circle(c + Vector2(p.x * w, p.y * hh), w * 0.33 + 5, ink)
	for p in pts:
		h.draw_circle(c + Vector2(p.x * w, p.y * hh), w * 0.33, col)
	# tail dots
	h.draw_circle(c + Vector2(0, hh * 0.55), w * 0.07 + 3, ink)
	h.draw_circle(c + Vector2(0, hh * 0.55), w * 0.07, col)
	h.draw_circle(c + Vector2(w * 0.04, hh * 0.72), w * 0.04 + 3, ink)
	h.draw_circle(c + Vector2(w * 0.04, hh * 0.72), w * 0.04, col)


func _picto(h: Control, id: String, c: Vector2, s: float, alpha: float) -> void:
	var ink := Color(INK, alpha)
	var lw := maxf(3.0, s * 0.07)
	match id:
		"kettle_drum":
			h.draw_circle(c + Vector2(-s * 0.12, s * 0.08), s * 0.26, Color(Color("c8662e"), alpha))
			h.draw_arc(c + Vector2(-s * 0.12, s * 0.08), s * 0.26, 0, TAU, 24, ink, lw * 0.6)
			# music notes
			for i in 2:
				var nc := c + Vector2(s * (0.22 + i * 0.16), -s * (0.1 + i * 0.12))
				h.draw_circle(nc, s * 0.06, ink)
				h.draw_line(nc + Vector2(s * 0.05, 0), nc + Vector2(s * 0.05, -s * 0.2), ink, lw * 0.6)
			# crack
			h.draw_polyline(PackedVector2Array([c + Vector2(s * 0.3, s * 0.12), c + Vector2(s * 0.38, s * 0.2), c + Vector2(s * 0.33, s * 0.26), c + Vector2(s * 0.42, s * 0.34)]), Color(Color("e23b4e"), alpha), lw * 0.8)
		"achoo_ria":
			# nose + burst
			h.draw_circle(c + Vector2(-s * 0.18, 0), s * 0.16, Color(Color("f4c09c"), alpha))
			h.draw_arc(c + Vector2(-s * 0.18, 0), s * 0.16, 0, TAU, 20, ink, lw * 0.6)
			for i in 7:
				var a := -1.2 + i * 0.4
				h.draw_line(c + Vector2(s * 0.05, 0) + Vector2(cos(a), sin(a)) * s * 0.1, c + Vector2(s * 0.05, 0) + Vector2(cos(a), sin(a)) * s * 0.36, ink, lw * 0.7)
		"in_a_pickle":
			h.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.12), Vector2(s * 0.3, s * 0.36)), Color(Color("5fae5b"), alpha))
			h.draw_rect(Rect2(c + Vector2(-s * 0.2, -s * 0.2), Vector2(s * 0.34, s * 0.09)), Color(Color("e8b33a"), alpha))
			for i in 3:
				var oc := c + Vector2(s * (0.24 + i * 0.07), -s * (0.25 - i * 0.14))
				h.draw_circle(oc, s * 0.06, Color(Color("f3f0e2"), alpha))
				h.draw_arc(oc, s * 0.06, 0, TAU, 12, ink, lw * 0.4)
		"tap_dance":
			h.draw_line(c + Vector2(-s * 0.3, -s * 0.2), c + Vector2(-s * 0.05, -s * 0.2), Color(Color("aebccb"), alpha), lw * 1.6)
			for i in 4:
				h.draw_line(c + Vector2(-s * 0.02, -s * 0.18 + i * s * 0.04), c + Vector2(s * 0.3, -s * 0.05 + i * s * 0.1), Color(Color("3d7bd9"), alpha), lw * 0.8)
			h.draw_circle(c + Vector2(s * 0.34, s * 0.12), s * 0.12, Color(Color("f4c09c"), alpha))
		"hide":
			# closed eye
			h.draw_arc(c + Vector2(0, -s * 0.05), s * 0.25, 0.2, PI - 0.2, 16, Color(Color("3d7bd9"), alpha), lw * 1.2)
			for i in 3:
				var a := 0.6 + i * 0.95
				h.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.25 + Vector2(0, -s * 0.05), c + Vector2(cos(a), sin(a)) * s * 0.36 + Vector2(0, -s * 0.05), Color(Color("3d7bd9"), alpha), lw * 0.8)
		"lift_off":
			h.draw_rect(Rect2(c + Vector2(-s * 0.25, s * 0.05), Vector2(s * 0.35, s * 0.16)), Color(Color("e4b62a"), alpha))
			h.draw_line(c + Vector2(s * 0.15, s * 0.1), c + Vector2(s * 0.15, -s * 0.3), ink, lw)
			h.draw_polygon(PackedVector2Array([c + Vector2(s * 0.05, -s * 0.22), c + Vector2(s * 0.25, -s * 0.22), c + Vector2(s * 0.15, -s * 0.38)]), PackedColorArray([ink]))
		"something_fishy":
			h.draw_rect(Rect2(c + Vector2(-s * 0.32, -s * 0.05), Vector2(s * 0.22, s * 0.3)), Color(Color("26242c"), alpha))
			h.draw_circle(c + Vector2(-s * 0.21, -s * 0.12), s * 0.08, Color(Color("26242c"), alpha))
			var fish := PackedVector2Array([c + Vector2(-s * 0.02, 0), c + Vector2(s * 0.2, -s * 0.12), c + Vector2(s * 0.34, 0), c + Vector2(s * 0.2, s * 0.12)])
			h.draw_colored_polygon(fish, Color(Color("9fb8c8"), alpha))
			h.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.32, 0), c + Vector2(s * 0.44, -s * 0.12), c + Vector2(s * 0.44, s * 0.12)]), Color(Color("9fb8c8"), alpha))
			h.draw_circle(c + Vector2(s * 0.08, -s * 0.02), s * 0.025, ink)
		"times_up":
			h.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.3), Vector2(s * 0.26, s * 0.6)), Color(Color("7a4a2c"), alpha))
			h.draw_circle(c + Vector2(-s * 0.17, -s * 0.16), s * 0.09, Color(Color("f3ecd8"), alpha))
			h.draw_polyline(PackedVector2Array([c + Vector2(s * 0.02, -s * 0.28), c + Vector2(s * 0.14, -s * 0.18), c + Vector2(s * 0.04, -s * 0.06), c + Vector2(s * 0.18, s * 0.06), c + Vector2(s * 0.06, s * 0.18), c + Vector2(s * 0.2, s * 0.3)]), ink, lw)
			h.draw_line(c + Vector2(s * 0.3, -s * 0.3), c + Vector2(s * 0.3, s * 0.05), Color(Color("e23b4e"), alpha), lw * 1.2)
			h.draw_circle(c + Vector2(s * 0.3, s * 0.16), lw * 0.7, Color(Color("e23b4e"), alpha))
		"mirror_mirror":
			h.draw_arc(c + Vector2(-s * 0.08, 0), s * 0.26, 0, TAU, 28, Color(Color("8a5a3a"), alpha), lw * 1.3)
			h.draw_circle(c + Vector2(-s * 0.08, 0), s * 0.2, Color(Color("fff6ea"), alpha))
			h.draw_circle(c + Vector2(-s * 0.15, -s * 0.03), s * 0.03, ink)
			h.draw_arc(c + Vector2(-s * 0.01, -s * 0.03), s * 0.035, 0.2, PI - 0.2, 8, ink, lw * 0.6)
			h.draw_arc(c + Vector2(-s * 0.08, s * 0.07), s * 0.07, 0.3, PI - 0.3, 8, ink, lw * 0.6)
			for i in 3:
				var a := -0.9 + i * 0.45
				h.draw_line(c + Vector2(s * 0.24, -s * 0.1) + Vector2(cos(a), sin(a)) * s * 0.02, c + Vector2(s * 0.24, -s * 0.1) + Vector2(cos(a), sin(a)) * s * 0.14, Color(Color("e8b33a"), alpha), lw * 0.7)
		"magnifier":
			h.draw_arc(c + Vector2(-s * 0.06, -s * 0.06), s * 0.2, 0, TAU, 24, Color(Color("e8b33a"), alpha), lw * 1.2)
			h.draw_circle(c + Vector2(-s * 0.06, -s * 0.06), s * 0.17, Color(Color("cfe6f2"), alpha))
			h.draw_line(c + Vector2(s * 0.08, s * 0.08), c + Vector2(s * 0.3, s * 0.3), Color(Color("6d4a33"), alpha), lw * 1.6)
		"fire":
			h.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.22, s * 0.25), c + Vector2(-s * 0.26, -s * 0.02), c + Vector2(-s * 0.1, -s * 0.34), c + Vector2(-s * 0.02, -s * 0.1), c + Vector2(s * 0.1, -s * 0.3), c + Vector2(s * 0.26, 0.0), c + Vector2(s * 0.22, s * 0.25)]), Color(Color("ff8a2a"), alpha))
			h.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, s * 0.25), c + Vector2(-s * 0.1, s * 0.05), c + Vector2(0, -s * 0.08), c + Vector2(s * 0.1, s * 0.05), c + Vector2(s * 0.1, s * 0.25)]), Color(Color("ffd23f"), alpha))
		"phone":
			h.draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.05), Vector2(s * 0.24, s * 0.3)), Color(Color("26242c"), alpha))
			h.draw_circle(c + Vector2(0, -s * 0.12), s * 0.1, Color(Color("26242c"), alpha))
			h.draw_arc(c + Vector2(s * 0.2, -s * 0.1), s * 0.1, -1.0, 1.0, 8, ink, lw * 0.6)
			h.draw_arc(c + Vector2(s * 0.2, -s * 0.1), s * 0.18, -1.0, 1.0, 8, ink, lw * 0.6)
		"tea":
			h.draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.05), Vector2(s * 0.36, s * 0.26)), Color(Color("ffffff"), alpha))
			h.draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.05), Vector2(s * 0.36, s * 0.26)), ink, false, lw * 0.6)
			h.draw_arc(c + Vector2(s * 0.17, s * 0.07), s * 0.08, -1.4, 1.4, 10, ink, lw * 0.6)
			for i in 2:
				h.draw_arc(c + Vector2(-s * 0.1 + i * s * 0.14, -s * 0.2), s * 0.06, 1.2, 5.0, 10, ink, lw * 0.5)


func _pill(h: Control, r: Rect2, fill: Color, border: Color, bw := 4.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(int(bw))
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	h.draw_style_box(sb, r)


func _draw_hud(h: Control) -> void:
	var W := h.size.x
	var H := h.size.y
	var S := 0.0
	var T := 0.0
	var B := 0.0
	var navy := Color("1b2340")
	var quiet := Color(0.106, 0.137, 0.251, 0.62)
	# --- always-on 1: pause (hit 144 at S+24,T+24; visual 96)
	var pc := Vector2(S + 96, T + 96)
	h.draw_circle(pc, 48, quiet)
	h.draw_rect(Rect2(pc + Vector2(-16, -18), Vector2(10, 36)), Color.WHITE)
	h.draw_rect(Rect2(pc + Vector2(6, -18), Vector2(10, 36)), Color.WHITE)
	# --- always-on 2: Script chip (hit S+192..S+504, visual pill 312 x 96 centred on the pause row)
	var sr := Rect2(S + 192, T + 48, 312, 96)
	_pill(h, sr, quiet, Color(1, 1, 1, 0.0), 0)
	# playbill icon
	h.draw_rect(Rect2(sr.position + Vector2(30, 22), Vector2(40, 52)), Color("fff6ea"))
	for i in 3:
		h.draw_line(sr.position + Vector2(38, 36 + i * 12), sr.position + Vector2(62, 36 + i * 12), navy, 4)
	var done := 1 if mock in ["armed", "trigger"] else 0
	# required lines: big pips (3 in N1); optional lines: small dots (2); the sealed Big Number: star
	for i in 3:
		var pp := sr.position + Vector2(112 + i * 46, 48)
		if i < done:
			h.draw_circle(pp, 17, Color("ffd23f"))
		else:
			h.draw_arc(pp, 15, 0, TAU, 24, Color(1, 1, 1, 0.9), 5)
	for i in 2:
		h.draw_circle(sr.position + Vector2(236 + i * 22, 48), 7, Color(1, 1, 1, 0.55))
	# sealed Big Number star
	var st := sr.position + Vector2(286, 48)
	var star := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := 16.0 if i % 2 == 0 else 7.0
		star.append(st + Vector2(cos(a), sin(a)) * rr)
	h.draw_colored_polygon(star, Color(1, 1, 1, 0.5))
	# --- always-on 3: Clarence (hit S+32,H-B-200 168; visual 128)
	var cc := Vector2(S + 116, H - B - 116)
	h.draw_circle(cc, 64, quiet)
	h.draw_circle(cc + Vector2(0, 8), 30, Color("ffd23f"))
	h.draw_circle(cc + Vector2(6, -26), 18, Color("ffd23f"))
	h.draw_circle(cc + Vector2(8, -44), 8, Color("e23b4e"))
	h.draw_circle(cc + Vector2(12, -28), 4, navy)
	h.draw_polygon(PackedVector2Array([cc + Vector2(22, -26), cc + Vector2(36, -22), cc + Vector2(22, -18)]), PackedColorArray([Color("f29a2e")]))
	# carried item chip (contextual): the squeaker, next to Clarence
	if mock in ["plan"]:
		var ic := Vector2(S + 290, H - B - 116)
		h.draw_circle(ic, 50, quiet)
		h.draw_circle(ic, 26, Color("ffd23f"))
		h.draw_circle(ic + Vector2(22, -14), 10, Color("e23b4e"))
	# --- always-on 4: the action button (centre W-S-168, H-B-168; visual 190, ring 14)
	var ac := Vector2(W - S - 168, H - B - 168)
	var live := mock in ["plan", "rig"]
	if mock == "hall2":
		# FREEZE, live and held: stone-white face, amber danger rim (he is in her room), hold ring
		h.draw_circle(ac, 95 * 1.08 + 6, navy)
		h.draw_circle(ac, 95 * 1.08, Color("e9e4da"))
		h.draw_arc(ac, 95 * 1.08 + 14, 0, TAU, 48, Color("ff9a2e"), 12)
		h.draw_rect(Rect2(ac + Vector2(-34, 34), Vector2(68, 18)), navy)
		h.draw_circle(ac + Vector2(0, -38), 16, navy)
		h.draw_rect(Rect2(ac + Vector2(-16, -20), Vector2(32, 52)), navy)
		h.draw_line(ac + Vector2(12, -14), ac + Vector2(34, -46), navy, 10)
		live = false
		ac = Vector2(-999, -999)
	if live:
		var k := 1.08
		h.draw_circle(ac, 95 * k + 6, navy)
		h.draw_circle(ac, 95 * k, Color("f2b632"))
		# item -> target icon (squeaker -> kettle / pepper -> honey)
		if mock == "plan":
			h.draw_circle(ac + Vector2(-40, 8), 24, Color("ffd23f"))
			h.draw_arc(ac + Vector2(-40, 8), 24, 0, TAU, 16, navy, 4)
			h.draw_circle(ac + Vector2(-22, -12), 9, Color("e23b4e"))
		else:
			h.draw_rect(Rect2(ac + Vector2(-56, -18), Vector2(30, 46)), Color("f4f1ea"))
			h.draw_rect(Rect2(ac + Vector2(-56, -18), Vector2(30, 46)), navy, false, 4)
			h.draw_circle(ac + Vector2(-41, -22), 13, Color("22252e"))
		h.draw_line(ac + Vector2(-8, 8), ac + Vector2(10, 8), navy, 7)
		h.draw_polygon(PackedVector2Array([ac + Vector2(8, -6), ac + Vector2(24, 8), ac + Vector2(8, 22)]), PackedColorArray([navy]))
		if mock == "plan":
			h.draw_circle(ac + Vector2(50, 12), 28, Color("c8662e"))
			h.draw_arc(ac + Vector2(50, 12), 28, 0, TAU, 20, navy, 4)
			h.draw_line(ac + Vector2(74, 4), ac + Vector2(90, -12), Color("c8662e"), 9)
			h.draw_circle(ac + Vector2(50, -18), 7, navy)
		else:
			h.draw_rect(Rect2(ac + Vector2(28, -16), Vector2(46, 50)), Color("f2a51f"))
			h.draw_rect(Rect2(ac + Vector2(28, -16), Vector2(46, 50)), navy, false, 4)
			h.draw_rect(Rect2(ac + Vector2(24, -28), Vector2(54, 14)), Color("e23b4e"))
		var frac := 0.0 if mock == "plan" else 0.6
		if frac > 0.0:
			h.draw_arc(ac, 95 * k + 16, -PI / 2, -PI / 2 + TAU * frac, 48, Color("5ccf6a"), 14)
	else:
		h.draw_circle(ac, 95, quiet)
		# statue icon (FREEZE, quiet)
		h.draw_rect(Rect2(ac + Vector2(-30, 30), Vector2(60, 16)), Color(1, 1, 1, 0.9))
		h.draw_circle(ac + Vector2(0, -34), 14, Color(1, 1, 1, 0.9))
		h.draw_rect(Rect2(ac + Vector2(-14, -18), Vector2(28, 46)), Color(1, 1, 1, 0.9))
		h.draw_line(ac + Vector2(10, -12), ac + Vector2(30, -40), Color(1, 1, 1, 0.9), 9)
	# --- world-anchored overlays
	var bub := Vector2(-9999, -9999)
	if anchors.has("bellows_head") and mock != "trigger" and mock != "hall2c":
		var bh := _scr(anchors["bellows_head"], h) + Vector2(0, -70)
		bh.x = clampf(bh.x, 260.0, h.size.x - 260.0)   # bubbles clamp inside the safe area
		bub = bh
		_cloud(h, bh, 190, 1.0)
		_picto(h, "phone" if mock == "hall2" else "tea", bh + Vector2(0, -8), 110, 1.0)
		# countdown ring on the bubble (spec: 12 px)
		h.draw_arc(bh + Vector2(0, -8), 92, -PI / 2, -PI / 2 + TAU * 0.62, 48, Color("e23b4e"), 12)
		# awareness glyph: specs dangling
		var gp := bh + Vector2(-150, 20)
		h.draw_circle(gp, 30, Color(1, 1, 1, 0.95))
		h.draw_arc(gp + Vector2(-10, 4), 9, 0, TAU, 12, navy, 4)
		h.draw_arc(gp + Vector2(10, 4), 9, 0, TAU, 12, navy, 4)
		h.draw_line(gp + Vector2(-1, 4), gp + Vector2(1, 4), navy, 3)
	var props := {"kettle": "kettle_drum", "honey": "achoo_ria", "pickle": "in_a_pickle", "tap": "tap_dance"}
	if mock.begins_with("hall2"):
		props = {"phone": "something_fishy", "clock": "times_up", "mirror": "mirror_mirror"}
		if mock == "hall2":
			props = {}   # rule V4: danger hides every preview
	var active := ""
	if mock == "plan":
		active = "kettle"
	elif mock == "rig":
		active = "honey"
	for k in props.keys():
		if not anchors.has(k):
			continue
		if mock == "trigger":
			continue
		var armed: bool = mock == "armed" and k in ["kettle", "honey", "tap"]
		if armed:
			continue
		var p := _scr(anchors[k], h) + Vector2(0, -56)
		if k == active:
			# rule V3: at a rig point the preview becomes HUSH's own thought cloud (she imagines the payoff),
			# up-and-behind her head on the side away from the prop, so it covers neither her face nor the prop
			var hh := _scr(anchors["hush_head"], h)
			var side := -1.0 if p.x >= hh.x else 1.0
			var big := hh + Vector2(side * 190, -170)
			# never on Bellows' bubble: try the other side, then straight up (spec §3.1 V6)
			if big.distance_to(bub) < 260.0:
				big = hh + Vector2(-side * 190, -170)
				if big.distance_to(bub) < 260.0 or _scr(anchors[k], h).distance_to(big) < 120.0:
					big = hh + Vector2(0, -300)
			_cloud(h, big, 180, 1.0)
			_picto(h, props[k], big + Vector2(0, -6), 124, 1.0)
		elif mock == "rig":
			pass   # rule V3: while rigging, every other preview hides
		else:
			var a := 0.8 if active == "" else 0.3
			_cloud(h, p, 112, a)
			_picto(h, props[k], p + Vector2(0, -4), 78, a)
	if mock == "hall2c":
		# container: the item it holds tonight, in a cream bubble (take-verb colour)
		var bp := _scr(anchors["box"], h) + Vector2(0, -70)
		h.draw_circle(bp, 58, INK)
		h.draw_circle(bp, 53, Color("fff6ea"))
		_picto(h, "magnifier", bp, 80, 1.0)
		# the Bellows window (contextual PiP): he is next door and off-screen
		if pip_vp:
			var pr := Rect2(W - S - 24 - 400, T + 24, 400, 225)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("f29a6e")   # frame colour = temper tier (irked pink)
			sb.set_corner_radius_all(22)
			h.draw_style_box(sb, pr.grow(6))
			h.draw_texture_rect(pip_vp.get_texture(), pr, false)
			# his next-activity chip in the window corner
			var nc := pr.position + Vector2(40, pr.size.y - 40)
			h.draw_circle(nc, 36, INK)
			h.draw_circle(nc, 32, Color.WHITE)
			_picto(h, "fire", nc, 50, 1.0)
			h.draw_arc(nc, 34, -PI / 2, -PI / 2 + TAU * 0.4, 24, Color("e23b4e"), 6)
	# the world progress ring while rigging (at the prop)
	if mock == "rig":
		var rp := _scr(anchors["honey_mid"], h)
		h.draw_arc(rp, 118, 0, TAU, 48, Color(0, 0, 0, 0.35), 18)
		h.draw_arc(rp, 118, -PI / 2, -PI / 2 + TAU * 0.6, 48, Color("f2d23a"), 14)
		# pepper grains
		for i in 9:
			h.draw_circle(rp + Vector2(-20 + (i * 37) % 60, -40 + (i * 23) % 50), 4, Color("22252e"))
	# pantry: hiding marker (small, blue) only in the danger mock
	if mock == "armed" and anchors.has("pantry"):
		var pp := _scr(anchors["pantry"], h) + Vector2(0, -30)
		h.draw_circle(pp, 44, Color(1, 1, 1, 0.95))
		h.draw_arc(pp, 44, 0, TAU, 24, Color("3d7bd9"), 6)
		_picto(h, "hide", pp + Vector2(0, 6), 70, 1.0)
	# armed tags are 3D (see _tags); entry warning in the armed mock: BEHIND YOU! plate
	if mock == "trigger":
		var bh2 := _scr(Vector3(mx(3040), 1.9, LANE_Z - 0.3), h)
		var cap := "ACHOO-RIA!"
		var fs := 104
		var tw := font_display.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cpos := Vector2(bh2.x - tw * 0.5 - 180, T + 250)
		for o in [Vector2(-6, 0), Vector2(6, 0), Vector2(0, -6), Vector2(0, 6), Vector2(-4, -4), Vector2(4, 4), Vector2(-4, 4), Vector2(4, -4)]:
			h.draw_string(font_display, cpos + o, cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, navy)
		h.draw_string(font_display, cpos, cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd23f"))
		# transient applause meter (contextual): top centre
		var mr := Rect2(W * 0.5 - 230, T + 24, 460, 104)
		_pill(h, mr, Color(0.106, 0.137, 0.251, 0.88), Color("e8b33a"), 5)
		h.draw_circle(mr.position + Vector2(56, 52), 36, Color("fff6ea"))
		h.draw_line(mr.position + Vector2(56, 52), mr.position + Vector2(80, 30), Color("e23b4e"), 6)
		h.draw_string(font_ui, mr.position + Vector2(106, 66), "APPLAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1, 0.85))
		h.draw_string(font_display, mr.position + Vector2(330, 76), "35", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color.WHITE)
		h.draw_string(font_display, mr.position + Vector2(482, 78), "+35", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color("ffd23f"))
		# the Stalls risen (contextual): bottom band between the thumb clusters
		var aud := Color(0.09, 0.07, 0.13, 0.9)
		for i in 20:
			var x := S + 460 + i * ((W - 2 * S - 920) / 19.0)
			var up := 64.0 + float((i * 37) % 44)
			var hy := H - up
			h.draw_circle(Vector2(x, hy), 30, aud)
			_pill(h, Rect2(Vector2(x - 46, hy + 22), Vector2(92, 120)), aud, Color(0, 0, 0, 0), 0)
			match i % 5:
				1:
					h.draw_rect(Rect2(Vector2(x - 20, hy - 70), Vector2(40, 48)), aud)
					h.draw_rect(Rect2(Vector2(x - 32, hy - 26), Vector2(64, 8)), aud)
				3:
					h.draw_circle(Vector2(x, hy - 34), 26, aud)
				4:
					h.draw_line(Vector2(x + 30, hy + 30), Vector2(x + 56, hy - 40), aud, 16)
		# Hush's eyes in the pantry gap (hidden, watching)
		var pe := _scr(Vector3(mx(3620) - 0.05, 1.45, BACK_Z + 0.3), h)
		h.draw_rect(Rect2(pe + Vector2(-60, -34), Vector2(120, 70)), Color(0.05, 0.04, 0.07, 1))
		for ex in [-22.0, 22.0]:
			h.draw_circle(pe + Vector2(ex, 0), 17, Color.WHITE)
			h.draw_circle(pe + Vector2(ex - 7, 1), 8, Color("15131c"))
	if mock == "armed":
		# entry warning plate — only danger speaks: BEHIND YOU! (bottom centre, Stalls voice)
		var txt := "BEHIND YOU!"
		var fs2 := 60
		var tw2 := font_display.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var rr := Rect2(W * 0.5 - tw2 * 0.5 - 30, H - B - 150, tw2 + 60, 92)
		_pill(h, rr, Color("fff6ea"), navy, 6)
		h.draw_string(font_display, rr.position + Vector2(30, 68), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, navy)
