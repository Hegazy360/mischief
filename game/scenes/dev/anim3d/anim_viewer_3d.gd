## AnimViewer3D — the 3D animators' bench (r3d-rig §4.1.5): a rig on the game's own RigPlayer3D, a clip (or the
## rest pose, or a raw glb action), a frame or live playback, every look / tint / stone / face / facing / cheat
## state, the game camera in a real room (RoomShell3D, soft) or a studio camera, a second rig, printed events.
## Sidecars hot-reload on mtime every 0.5 s. `--help` prints every flag.
##
## Shot:     tools/scripts/shot.sh res://scenes/dev/anim3d/AnimViewer3D.tscn out.png 40 <sb> -- --rig=bellows --clip=bellows/loco_idle --cam=game --room=kitchen --x=14.7
## Sequence: … -- --rig=hush --anim-glb=/abs/hush_toy.glb --anim-name=Toy_Snicker --play --shot-seq=/abs/dir --every=3 --count=40
extends Node3D

const USAGE := """AnimViewer3D — user args (after `--`):
  --rig=<id> [--variant=head_b]    the rig (data/rigs3d/<id>/rig3d[_<variant>].json)
  --clip=<id>                      a clip id (hush/loco_walk) or a bare name (loco_walk → <rig>/loco_walk)
  --pose=rest                      the rest pose (no clip)
  --anim-glb=/abs.glb [--anim-name=N]   play an action from a raw glb (GLTFDocument; same UAL skeleton)
  --frame=N                        show frame N (frame-locked); with --play: start there
  --play [--speed=k]               play on the view clock
  --tier=1..3 --suppressed         reaction tier remap / suppressed settle
  --overlay=<clip> [--mask=upper]  an overlay clip over the base
  --cam=game|front|q34|side|back|face|turn   game = the base framing (7.5 m, FOV 30); the rest orbit the rig
  --dist=<m> --cam-y=<m>           studio camera distance / height override
  --face=<preset>                  a face preset (the clip's timeline still wins at its entries)
  --looks=A,B                      residue / costume looks on
  --slot=<slot>:<variant>          a residue body slot (bouffant:flipped)
  --prop=<id>:<state>[,…]          prop states (teacup:held, stool:shown)
  --tint=0..4 --stone              temper tier (4 = livid) / the marble statue
  --facing=1|-1 --cheat=<deg>      sim facing / cheat-out toward the camera (default 35 on game cam)
  --look-at=x,y,z                  head + pupils toward a world point
  --room=<room> --x=<m> --z=<m>    the real room (house.json x range; RoomShell3D when built, else a greybox)
  --rig2=<id> --clip2=<id> --x2=<m> --facing2=±1 --frame2=N   a second rig
  --then=<clip>|glb:<action> --then-at=<f> [--then-blend=<f>]   switch clips at view frame f (a stop: jiggle settles)
  --flip-every=<f>                 flip the facing every f view frames (the 6-frame turn)
  --launch=<prop>@<f>[:vx,vy,vz]   launch a bone prop at view frame f (default 1.5, 3.0, 0 m/s, spin 540°/s)
  --stone-at=<f>                   turn to marble at view frame f (0.1 s), back at f + 90
  --events                         print every crossed clip event
  --data-root=res://…              an extra data root (the rig3d test fixtures: res://tests/rig3d/fixtures/data)
  --clean                          no label (strips, boards)
  --help                           this text"""
const PASSTHROUGH: PackedStringArray = ["--shot=", "--frames=", "--shot-seq=", "--every=", "--count=", "--seq-from=",
	"--perf-log", "--scene=", "--log=", "--e2e", "--tex-report"]
const BG := Color("#2A2342")
const ROOM_WALL := {"kitchen": Color("#C7B684"), "parlour": Color("#B9A6C9"), "hall": Color("#A9B79A"), "porch": Color("#9FD6F0")}

var cfg: Dictionary = {}
var rig: RigPlayer3D = null
var rig2: RigPlayer3D = null
var cam: Camera3D = null
var label: Label = null
var clip_id: String = ""
var clip2_id: String = ""
var _t: float = 0.0
var _reload_t: float = 0.0
var _frame_lock: float = -1.0
var _frame2_lock: float = -1.0
var _orbit: float = 0.0
var _cam_mode: String = "game"
var _last_events: PackedStringArray = PackedStringArray()
var _vf: int = 0


func _ready() -> void:
	cfg = parse_args(OS.get_cmdline_user_args())
	if cfg.has("help"):
		print(USAGE)
		get_tree().quit(0)
		return
	if cfg.has("data-root"):
		add_data_root(String(cfg["data-root"]))
	_build_env()
	var rid := String(cfg.get("rig", "hush"))
	rig = _make_rig(rid, String(cfg.get("variant", "")), "Rig1")
	clip_id = _resolve_clip(rid, String(cfg.get("clip", "")))
	if cfg.has("anim-glb"):
		clip_id = ClipLib3D.load_glb_action(rid, String(cfg["anim-glb"]), String(cfg.get("anim-name", "")))
	_place(rig, float(cfg.get("x", _room_centre())), float(cfg.get("z", -1.0)), int(cfg.get("facing", 1)))
	_apply_state(rig, cfg)
	_start(rig, clip_id, cfg, "frame")
	if cfg.has("rig2"):
		var r2 := String(cfg["rig2"])
		rig2 = _make_rig(r2, "", "Rig2")
		clip2_id = _resolve_clip(r2, String(cfg.get("clip2", "")))
		_place(rig2, float(cfg.get("x2", float(cfg.get("x", _room_centre())) + 1.2)), float(cfg.get("z", -1.0)),
			int(cfg.get("facing2", -1)))
		_start(rig2, clip2_id, {"frame": cfg.get("frame2", cfg.get("frame", null)), "play": cfg.get("play", null)}, "frame")
	_build_camera()
	if not cfg.has("clean"):
		var cl := CanvasLayer.new()
		add_child(cl)
		label = Label.new()
		label.position = Vector2(24, 18)
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color("#F4EFE3"))
		label.add_theme_color_override("font_outline_color", Color("#1B2340"))
		label.add_theme_constant_override("outline_size", 6)
		cl.add_child(label)


## Adds a data root (fixtures: res://tests/rig3d/fixtures/data) to the rig, clip and reaction lookups.
static func add_data_root(r: String) -> void:
	if not RigDef3D.search_roots.has(r):
		RigDef3D.search_roots.append(r)
	if not ClipLib3D.search_roots.has(r):
		ClipLib3D.search_roots.append(r)
	var rf := r.path_join("reactions_fix.json")
	if FileAccess.file_exists(rf) and not PlayPlan3D.reaction_files.has(rf):
		PlayPlan3D.reaction_files.append(rf)


## Parses `--k=v` / `--flag` user args into a dictionary (unknown flags warn; DevShot's pass through).
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a in args:
		var passthrough := false
		for p in PASSTHROUGH:
			if a.begins_with(p):
				passthrough = true
		if passthrough or not a.begins_with("--"):
			continue
		var kv := a.substr(2)
		var eq := kv.find("=")
		if eq < 0:
			out[kv] = true
		else:
			out[kv.substr(0, eq)] = kv.substr(eq + 1)
	return out


func _make_rig(rid: String, variant: String, nm: String) -> RigPlayer3D:
	var r := RigPlayer3D.new()
	r.name = nm
	r.auto_advance = false
	add_child(r)
	if not r.setup(rid, variant):
		push_warning("AnimViewer3D: rig '%s' failed — showing the stand-in" % rid)
	if cfg.has("events"):
		r.clip_event.connect(func(e: Dictionary) -> void:
			var line := "[anim3d] %s f=%d %s %s" % [nm, int(e.get("f", -1)), e.get("type", ""),
				String(e.get("id", e.get("name", e.get("op", ""))))]
			print(line)
			_last_events.append(line.substr(9))
			if _last_events.size() > 6:
				_last_events.remove_at(0))
	return r


static func _resolve_clip(rid: String, c: String) -> String:
	if c == "" or c == "rest":
		return ""
	if c.contains("/"):
		return c
	return "%s/%s" % [rid, c]


func _start(r: RigPlayer3D, id: String, c: Dictionary, frame_key: String) -> void:
	if id == "":
		return
	var opts := {"tier": int(c.get("tier", 1)), "suppressed": c.has("suppressed"), "speed": float(c.get("speed", 1.0))}
	var fr: Variant = c.get(frame_key, null)
	if fr != null and c.has("play"):
		opts["start_frame"] = float(fr)
	r.play(id, opts)
	if fr != null and not c.has("play"):
		if r == rig:
			_frame_lock = float(fr)
		else:
			_frame2_lock = float(fr)
	if c.has("overlay"):
		r.play_overlay(_resolve_clip(r.rig_id, String(c["overlay"])), String(c.get("mask", "upper")), 0)


func _apply_state(r: RigPlayer3D, c: Dictionary) -> void:
	if c.has("face"):
		r.set_face(String(c["face"]))
	for lk in String(c.get("looks", "")).split(",", false):
		r.set_look(lk, true)
	if c.has("slot"):
		var sv := String(c["slot"]).split(":")
		if sv.size() == 2:
			r.set_body_slot(sv[0], sv[1], &"residue")
	for pv in String(c.get("prop", "")).split(",", false):
		var ps := pv.split(":")
		if ps.size() == 2:
			r.set_prop(ps[0], ps[1])
	if c.has("tint"):
		r.set_tint_tier(int(c["tint"]))
	if c.has("stone"):
		r.set_stone(true, 0.0)
	var cam_mode := String(c.get("cam", "game"))
	# The studio cameras orbit a rig that faces the camera (yaw 0 = cheat 90) unless --facing/--cheat say otherwise.
	var studio := cam_mode != "game" and not c.has("facing")
	var cheat := float(c.get("cheat", 35.0 if cam_mode == "game" else (90.0 if studio else 0.0)))
	r.set_cheat(cheat, 0.0)
	if c.has("look-at"):
		var v := String(c["look-at"]).split(",")
		if v.size() == 3:
			r.look_at_point(Vector3(float(v[0]), float(v[1]), float(v[2])), 1.0)


func _place(r: RigPlayer3D, x: float, z: float, facing: int) -> void:
	r.position = Vector3(x, 0.0, z)
	r.set_facing(facing, false)


func _room_centre() -> float:
	var room := String(cfg.get("room", ""))
	var rr := _room_range(room)
	return (rr.x + rr.y) * 0.5 if rr.y > rr.x else 0.0


## The room's x range in metres from house.json (Vector2.ZERO when unknown).
static func _room_range(room: String) -> Vector2:
	if room == "" or not FileAccess.file_exists("res://data/house/house.json"):
		return Vector2.ZERO
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://data/house/house.json")) != OK:
		return Vector2.ZERO
	for r in (j.data as Dictionary).get("rooms", []):
		if String((r as Dictionary).get("id", "")) == room:
			return Vector2(float(r["x0"]) / 200.0, float(r["x1"]) / 200.0)
	return Vector2.ZERO


func _build_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	we.environment = env
	add_child(we)
	var room := String(cfg.get("room", ""))
	if room != "":
		_build_room(room)
	else:
		_build_studio()


func _build_room(room: String) -> void:
	var rr := _room_range(room)
	var shell_s := RigPlayer3D._soft_class("RoomShell3D")
	var geo_s := RigPlayer3D._soft_class("SetGeo")
	if shell_s != null and rr.y > rr.x:
		var h3d: Dictionary = {}
		if geo_s != null and geo_s.has_method("load_house3d"):
			var hv: Variant = geo_s.call("load_house3d")
			if hv is Dictionary:
				h3d = hv
		var rooms: Dictionary = h3d.get("rooms", {})
		var shell: Node3D = shell_s.new()
		add_child(shell)
		if shell.has_method("setup"):
			shell.call("setup", room, rr.x, rr.y, rooms.get(room, {}), h3d.get("stage", {}))
			return
		shell.queue_free()
	# Greybox: floor, back wall, wainscot, the proscenium band.
	var wall: Color = ROOM_WALL.get(room, Color("#B8AE98"))
	var x0 := rr.x if rr.y > rr.x else -6.0
	var x1 := rr.y if rr.y > rr.x else 6.0
	_box(Vector3(x0 - 4.0, -0.1, -2.4), Vector3(x1 + 4.0, 0.0, 0.25), Color("#8E6E52"))
	_box(Vector3(x0, 0.0, -2.5), Vector3(x1, 3.2, -2.4), wall)
	_box(Vector3(x0, 0.0, -2.39), Vector3(x1, 0.9, -2.36), wall.darkened(0.12))
	_box(Vector3(x0 - 4.0, 3.13, -2.5), Vector3(x1 + 4.0, 4.4, 0.4), Color("#1D1728"))


func _build_studio() -> void:
	_box(Vector3(-6, -0.1, -6), Vector3(6, 0.0, 6), Color("#6E5A7E"))


func _box(lo: Vector3, hi: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = hi - lo
	mi.mesh = bm
	mi.position = (lo + hi) * 0.5
	var sh_path := "res://art3d/shaders/set_toon.gdshader"
	if ResourceLoader.exists(sh_path):
		var m := ShaderMaterial.new()
		m.shader = load(sh_path)
		m.set_shader_parameter("albedo_color", col)
		mi.material_override = m
	else:
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = col
		mi.material_override = sm
	add_child(mi)


func _build_camera() -> void:
	_cam_mode = String(cfg.get("cam", "game"))
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 30.0
	cam.near = 0.1
	cam.far = 80.0
	add_child(cam)
	cam.current = true
	_aim_camera()


func _aim_camera() -> void:
	var p := rig.position
	var h := rig.def.height_m if rig.def != null else 1.6
	match _cam_mode:
		"game":
			cam.near = 0.5
			cam.far = 60.0
			cam.position = Vector3(p.x, 1.9, 6.5)
			cam.look_at(Vector3(p.x, 1.35, -1.0), Vector3.UP)
		"face":
			var hp := rig.head_global() + Vector3(0, 0.1, 0)
			var d := float(cfg.get("dist", 1.1))
			cam.position = hp + Vector3(0, 0.0, d)
			cam.look_at(hp, Vector3.UP)
		_:
			var ang := 0.0
			match _cam_mode:
				"q34":
					ang = 45.0
				"side":
					ang = 90.0
				"back":
					ang = 180.0
				"turn":
					ang = _orbit
			var d2 := float(cfg.get("dist", maxf(4.2, h * 2.6)))
			var y := float(cfg.get("cam-y", h * 0.55))
			var a := deg_to_rad(ang)
			cam.position = p + Vector3(sin(a) * d2, y, cos(a) * d2)
			cam.look_at(p + Vector3(0, h * 0.5, 0), Vector3.UP)


## The scripted view-frame actions (--then, --flip-every, --launch, --stone-at).
func _timeline_actions() -> void:
	if cfg.has("then") and _vf == int(cfg.get("then-at", 60)):
		_frame_lock = -1.0
		var tv := String(cfg["then"])
		var tid := ClipLib3D.load_glb_action(rig.rig_id, String(cfg.get("anim-glb", "")), tv.substr(4)) if tv.begins_with("glb:") else _resolve_clip(rig.rig_id, tv)
		rig.play(tid, {"blend_in": int(cfg.get("then-blend", 8))})
		clip_id = tid
	var fe := int(cfg.get("flip-every", 0))
	if fe > 0 and _vf % fe == 0:
		rig.set_facing(-rig.facing, true)
	if cfg.has("launch"):
		var spec := String(cfg["launch"])
		var at := spec.find("@")
		var prop := spec.substr(0, at) if at >= 0 else spec
		var rest := spec.substr(at + 1) if at >= 0 else "30"
		var parts := rest.split(":")
		if _vf == int(parts[0]):
			var v := Vector3(1.5, 3.0, 0.0)
			if parts.size() > 1:
				var c := parts[1].split(",")
				if c.size() == 3:
					v = Vector3(float(c[0]), float(c[1]), float(c[2]))
			rig.launch_prop(prop, v, 540.0)
	if cfg.has("stone-at"):
		var sa := int(cfg["stone-at"])
		if _vf == sa:
			rig.set_stone(true, 0.1)
		elif _vf == sa + 90:
			rig.set_stone(false, 0.15)


func _process(delta: float) -> void:
	_t += delta
	_reload_t += delta
	if _reload_t >= 0.5:
		_reload_t = 0.0
		for pair in [[rig, clip_id], [rig2, clip2_id]]:
			var r: RigPlayer3D = pair[0]
			var id: String = pair[1]
			if r != null and id != "" and ClipLib3D.reload_if_changed(id):
				var f := r.current_frame()
				r.play(id, {"start_frame": f})
				print("[anim3d] reloaded %s" % id)
	for pair2 in [[rig, _frame_lock], [rig2, _frame2_lock]]:
		var r2: RigPlayer3D = pair2[0]
		if r2 == null:
			continue
		if float(pair2[1]) >= 0.0:
			r2.set_external_frame(float(pair2[1]))
		r2.advance(delta)
	_vf += 1
	_timeline_actions()
	if _cam_mode == "turn":
		_orbit = fmod(_orbit + delta * 90.0, 360.0)
	if _cam_mode != "game":
		_aim_camera()
	if label != null:
		var c := rig.current_clip()
		label.text = "%s%s  %s  f %.1f / %d   face %s%s%s" % [rig.rig_id, " (%s)" % rig.variant if rig.variant != "" else "",
			c if c != "" else "rest pose", rig.current_frame(), rig.clip_length(c) if c != "" else 0, rig.face.active_preset,
			"  tint %d" % rig.tint_tier() if rig.tint_tier() > 0 else "", "  STONE" if rig.stone_amount() > 0.5 else ""]
		if not _last_events.is_empty():
			label.text += "\n" + "\n".join(_last_events)
