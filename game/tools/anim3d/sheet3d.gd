## Sheet3D — renders the raw frames of the 3D animation review sheets (TECH §11 in 3D, r3d-rig §4.4) with the game's
## own RigPlayer3D; `tools/anim/sheet3d.py` composes them (contact, onion, curves, silhouettes, phone strip, boards).
##   godot --rendering-driver opengl3 --path <sandbox> -s res://tools/anim3d/sheet3d.gd -- --rig=bellows \
##         --clip=bellows/rx_sneeze_blast_a --out=/abs/raw [--mode=clip|turntable|faces] [--room=kitchen] \
##         [--cam=side|game] [--tier=2] [--suppressed] [--variant=head_b] [--frame=N] [--x=<m>] [--cell=420]
##         [--anim-glb=/abs.glb --anim-name=N] [--data-root=res://tests/rig3d/fixtures/data] [--no-phone]
## (tools/scripts/anim_sheet3d.sh wraps it.) Modes:
## * `clip`: every frame is played in order (frame-locked, so springs and blinks run as in the game) and the cell
##   frames (every 3 f + every beat boundary) are saved as `side_<f>.png` (RGBA, transparent background, an
##   orthographic profile camera fitted to the whole clip) and `game_<f>.png` (the 1200×540 base framing in the room,
##   the phone-scale copy); per frame the bone angles for the curves and the screen positions of head top, hands and
##   pelvis for the onion dots go to `manifest.json` with the clip's beats, events and marks.
## * `turntable`: front / 3/4 / side / back at 1200×540 (`turn_<view>.png`), the rest pose or `--clip` at `--frame`.
## * `faces`: every face preset on the head (`face_<preset>.png`, a 3× close-up) + `faces_game.png` crops at 1×.
extends SceneTree

const CURVE_BONES := ["pelvis", "spine_03", "Head", "hand_l", "hand_r", "foot_l", "foot_r"]
const DOT_ROLES := ["top", "hand_l", "hand_r", "pelvis"]
const BG_GAME := Color("#2A2342")

var _args: Dictionary = {}
var _out: String = ""
var _vp: SubViewport = null
var _cam: Camera3D = null
var _rig: RigPlayer3D = null
var _world: Node3D = null
var _phone_crop: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2)
			var eq := kv.find("=")
			if eq < 0:
				_args[kv] = true
			else:
				_args[kv.substr(0, eq)] = kv.substr(eq + 1)
	_out = String(_args.get("out", ""))
	if _out == "" or not _args.has("rig"):
		printerr("[sheet3d] --rig=<id> --out=/abs/dir required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	if _args.has("data-root"):
		var r := String(_args["data-root"])
		RigDef3D.search_roots.append(r)
		ClipLib3D.search_roots.append(r)
		if FileAccess.file_exists(r.path_join("reactions_fix.json")):
			PlayPlan3D.reaction_files.append(r.path_join("reactions_fix.json"))
	_run.call_deferred()


func _run() -> void:
	var mode := String(_args.get("mode", "clip"))
	var code := 0
	match mode:
		"clip":
			code = await _mode_clip()
		"turntable":
			code = await _mode_turntable()
		"faces":
			code = await _mode_faces()
		_:
			printerr("[sheet3d] unknown --mode=%s" % mode)
			code = 2
	quit(code)


func _setup_world(size: Vector2i, transparent: bool) -> void:
	_vp = SubViewport.new()
	_vp.size = size
	_vp.transparent_bg = transparent
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR if transparent else Environment.BG_COLOR
	env.background_color = BG_GAME
	we.environment = env
	_world.add_child(we)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_world.add_child(_cam)
	_cam.current = true
	_rig = RigPlayer3D.new()
	_rig.auto_advance = false
	_world.add_child(_rig)
	if not _rig.setup(String(_args["rig"]), String(_args.get("variant", ""))):
		printerr("[sheet3d] rig %s failed to set up" % _args["rig"])


func _clip_id() -> String:
	if _args.has("anim-glb"):
		if not _args.has("_glb_id"):
			_args["_glb_id"] = ClipLib3D.load_glb_action(String(_args["rig"]), String(_args["anim-glb"]), String(_args.get("anim-name", "")))
		return String(_args["_glb_id"])
	var c := String(_args.get("clip", ""))
	if c != "" and not c.contains("/"):
		c = "%s/%s" % [_args["rig"], c]
	return c


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.save_png(path)


# --- clip ------------------------------------------------------------------------------------------------------

func _mode_clip() -> int:
	var cid := _clip_id()
	var c := ClipLib3D.get_clip(cid)
	if c == null:
		printerr("[sheet3d] no clip %s" % cid)
		return 2
	var cell := int(_args.get("cell", 420))
	_setup_world(Vector2i(cell, cell), true)
	var opts := {"tier": int(_args.get("tier", 1)), "suppressed": _args.has("suppressed")}
	_rig.play(cid, opts)
	var plan := _rig.plan()
	var n := plan.length
	# Pre-pass (no render): the clip's world bounds in profile, for one fixed orthographic camera.
	_rig.set_facing(1, false)
	_rig.set_cheat(0.0, 0.0)
	var bounds := AABB()
	for f in range(0, n + 1):
		_rig.set_external_frame(float(f))
		var b := _rig.screen_aabb()
		bounds = b if f == 0 else bounds.merge(b)
	_rig.reset()
	_rig.play(cid, opts)
	var centre := bounds.get_center()
	var half := maxf(bounds.size.y, bounds.size.x) * 0.5 + 0.12
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = half * 2.0
	_cam.position = Vector3(centre.x, centre.y, 8.0)
	_cam.look_at(Vector3(centre.x, centre.y, 0.0), Vector3.UP)
	# Cell frames: every 3 f + every beat boundary + the last frame.
	var cells: Dictionary = {}
	for f2 in range(0, n + 1, 3):
		cells[f2] = true
	cells[n] = true
	for bn in c.beats:
		var br: Vector2i = c.beats[bn]
		cells[plan.timeline_frame(br.x)] = true
		cells[plan.timeline_frame(br.y)] = true
	var frames: Array = []
	var angles: Dictionary = {}
	var prev_rot: Dictionary = {}
	for bn2 in CURVE_BONES:
		angles[bn2] = []
		angles[bn2 + ".speed"] = []
	var dots: Array = []
	for f3 in range(0, n + 1):
		_rig.set_external_frame(float(f3))
		_rig.advance(1.0 / 60.0)
		for bn3 in CURVE_BONES:
			var bi := _rig.skeleton.find_bone(bn3)
			if bi < 0:
				continue
			var q := _rig.skeleton.get_bone_pose_rotation(bi)
			var rest_q := _rig.skeleton.get_bone_rest(bi).basis.get_rotation_quaternion()
			(angles[bn3] as Array).append(rad_to_deg((rest_q.inverse() * q).get_angle()))
			var pq: Quaternion = prev_rot.get(bn3, q)
			(angles[bn3 + ".speed"] as Array).append(rad_to_deg((pq.inverse() * q).get_angle()))
			prev_rot[bn3] = q
		var d: Dictionary = {"f": f3}
		d["top"] = _px(_rig.top_global(), cell)
		d["pelvis"] = _px(_rig.skeleton.global_transform * _rig.skeleton.get_bone_global_pose(_rig.skeleton.find_bone(_rig.def.bone("pelvis"))).origin, cell)
		for hr in ["hand_l", "hand_r"]:
			var hb := _rig.skeleton.find_bone(_rig.def.bone(hr, hr))
			d[hr] = _px(_rig.skeleton.global_transform * _rig.skeleton.get_bone_global_pose(hb).origin, cell) if hb >= 0 else [0, 0]
		dots.append(d)
		if cells.has(f3):
			await _save(_out.path_join("side_%04d.png" % f3))
			frames.append(f3)
		else:
			await process_frame
	# The phone-scale copy: the game framing in the room (1200×540), every 3 f.
	var phone: Array = []
	if not _args.has("no-phone"):
		phone = await _phone_pass(cid, opts, n)
	var ev: Array = []
	for e in plan.events:
		ev.append({"f": int(e["f"]), "type": String(e.get("type", "")), "id": String(e.get("id", e.get("name", e.get("op", "")))),
			"prop": String(e.get("prop", ""))})
	var beats: Dictionary = {}
	for bn4 in c.beats:
		var br2: Vector2i = c.beats[bn4]
		beats[bn4] = [plan.timeline_frame(br2.x), plan.timeline_frame(br2.y)]
	var man := {"clip": cid, "rig": String(_args["rig"]), "length": n, "loop": c.loop, "tier": plan.tier, "suppressed": plan.suppressed,
		"beats": beats, "events": ev, "marks": c.marks, "cells": frames, "cell_px": cell, "phone": phone, "phone_crop": _phone_crop,
		"channels": angles, "dots": dots, "face": c.face_entries, "lint": c.lint}
	var fa := FileAccess.open(_out.path_join("manifest.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(man, " "))
	fa.close()
	print("[sheet3d] %s: %d cells, %d phone frames → %s" % [cid, frames.size(), phone.size(), _out])
	return 0


func _px(p: Vector3, cell: int) -> Array:
	var s := _cam.unproject_position(p)
	return [snappedf(s.x, 0.1), snappedf(s.y, 0.1)]


func _phone_pass(cid: String, opts: Dictionary, n: int) -> Array:
	_vp.size = Vector2i(1200, 540)
	_vp.transparent_bg = false
	_build_room(String(_args.get("room", "")))
	_rig.reset()
	_rig.play(cid, opts)
	var x := float(_args.get("x", _room_centre(String(_args.get("room", "")))))
	_rig.position = Vector3(x, 0.0, -1.0)
	_rig.set_facing(1, false)
	_rig.set_cheat(float(_args.get("cheat", 35.0)), 0.0)
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = 30.0
	_cam.near = 0.5
	_cam.far = 60.0
	_cam.position = Vector3(x, 1.9, 6.5)
	_cam.look_at(Vector3(x, 1.35, -1.0), Vector3.UP)
	# The crop: the character's projected bounds over the whole clip (+ 24 px), at true phone scale.
	var r := Rect2()
	for f0 in range(0, n + 1, 2):
		_rig.set_external_frame(float(f0))
		var rr := _project_aabb(_rig.screen_aabb())
		r = rr if f0 == 0 else r.merge(rr)
	r = r.grow(24.0).intersection(Rect2(0, 0, 1200, 540))
	_phone_crop = [int(r.position.x), int(r.position.y), int(r.end.x), int(r.end.y)]
	_rig.reset()
	_rig.play(cid, opts)
	var out: Array = []
	for f in range(0, n + 1):
		_rig.set_external_frame(float(f))
		_rig.advance(1.0 / 60.0)
		if f % 3 == 0 or f == n:
			await _save(_out.path_join("game_%04d.png" % f))
			out.append(f)
		else:
			await process_frame
	return out


func _project_aabb(b: AABB) -> Rect2:
	var r := Rect2()
	for i in 8:
		var p := _cam.unproject_position(b.get_endpoint(i))
		r = Rect2(p, Vector2.ZERO) if i == 0 else r.expand(p)
	return r


func _build_room(room: String) -> void:
	var rr := _room_range(room)
	var shell_s := RigPlayer3D._soft_class("RoomShell3D")
	var geo_s := RigPlayer3D._soft_class("SetGeo")
	if room != "" and shell_s != null and rr.y > rr.x:
		var h3d: Dictionary = {}
		if geo_s != null and geo_s.has_method("load_house3d"):
			var hv: Variant = geo_s.call("load_house3d")
			if hv is Dictionary:
				h3d = hv
		var shell: Node3D = shell_s.new()
		_world.add_child(shell)
		if shell.has_method("setup"):
			shell.call("setup", room, rr.x, rr.y, (h3d.get("rooms", {}) as Dictionary).get(room, {}), h3d.get("stage", {}))
			return
		shell.queue_free()
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 8)
	mi.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color("#8E6E52")
	mi.material_override = sm
	mi.position = Vector3(rr.x if rr.y > rr.x else 0.0, 0.0, -1.0)
	_world.add_child(mi)


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


static func _room_centre(room: String) -> float:
	var rr := _room_range(room)
	return (rr.x + rr.y) * 0.5 if rr.y > rr.x else 0.0


# --- turntable / faces -----------------------------------------------------------------------------------------

func _pose_for_board() -> void:
	var cid := _clip_id()
	if cid != "" and ClipLib3D.exists(cid):
		_rig.play(cid)
		_rig.set_external_frame(float(_args.get("frame", 0)))
	_rig.advance(1.0 / 60.0)


func _mode_turntable() -> int:
	_setup_world(Vector2i(1200, 540), false)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	mi.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color("#6E5A7E")
	mi.material_override = sm
	_world.add_child(mi)
	_rig.set_facing(1, false)
	_rig.set_cheat(90.0, 0.0)   # yaw 0: the rig faces +Z; the camera orbits
	_pose_for_board()
	var h := _rig.def.height_m
	var views := {"front": 0.0, "q34": 45.0, "side": 90.0, "back": 180.0}
	_cam.fov = 30.0
	for vn in views:
		var a := deg_to_rad(float(views[vn]))
		var d := h * 2.4
		_cam.position = Vector3(sin(a) * d, h * 0.55, cos(a) * d)
		_cam.look_at(Vector3(0, h * 0.5, 0), Vector3.UP)
		for i in 3:
			_rig.advance(1.0 / 60.0)
			await process_frame
		await _save(_out.path_join("turn_%s.png" % vn))
	print("[sheet3d] turntable → %s" % _out)
	return 0


func _mode_faces() -> int:
	_setup_world(Vector2i(360, 360), false)
	_rig.set_facing(1, false)
	_rig.set_cheat(90.0, 0.0)
	_pose_for_board()
	var names: Array = _rig.def.presets.keys()
	names.sort()
	_cam.fov = 30.0
	for pn in names:
		_rig.face.blinks_enabled = false
		_rig.set_face(String(pn))
		for i in 2:
			_rig.advance(1.0 / 60.0)
			await process_frame
		var hp := _rig.socket_global("face").origin if _rig.def.sockets.has("face") else _rig.head_global() + Vector3(0, 0.12, 0)
		_cam.position = hp + Vector3(0, 0, 1.25)
		_cam.look_at(hp, Vector3.UP)
		await _save(_out.path_join("face_%s.png" % pn))
	var fa := FileAccess.open(_out.path_join("faces.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify({"rig": _args["rig"], "presets": names}))
	fa.close()
	print("[sheet3d] %d faces → %s" % [names.size(), _out])
	return 0
