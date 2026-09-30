## Generates the r3d-rig test fixtures (run once, output committed):
##   tools/scripts/sandbox.sh r3d-rig -s res://tests/rig3d/fixtures/make_fixtures.gd -- --out=/abs/game/tests/rig3d/fixtures
## Writes `fix_rig.tscn` (a 27-bone UAL-named skeleton + one skinned box mesh with a palette and a face-card UV2 on
## the head), the attachment scenes (`bouffant_flipped.tscn`, `bouffant_frazzled.tscn`, `stool.tscn`) and the baked
## fixture clips `anim/fix/<clip>.tres` (their sidecars are hand-written JSON in `data/anim/fix3d/`).
extends SceneTree

const BONES := [
	# name, parent, rest offset from the parent (metres, Godot axes: +x = her left, +y up, +z toward the camera)
	["root", "", Vector3(0, 0, 0)],
	["pelvis", "root", Vector3(0, 0.80, 0)],
	["spine_01", "pelvis", Vector3(0, 0.10, 0)],
	["spine_02", "spine_01", Vector3(0, 0.12, 0)],
	["spine_03", "spine_02", Vector3(0, 0.12, 0)],
	["neck_01", "spine_03", Vector3(0, 0.10, 0)],
	["Head", "neck_01", Vector3(0, 0.08, 0)],
	["beret", "Head", Vector3(0, 0.25, -0.01)],
	["bouffant", "Head", Vector3(0, 0.20, -0.03)],
	["sideburn_l", "Head", Vector3(0.10, 0.04, 0.0)],
	["sideburn_r", "Head", Vector3(-0.10, 0.04, 0.0)],
	["clavicle_l", "spine_03", Vector3(0.04, 0.08, 0)],
	["upperarm_l", "clavicle_l", Vector3(0.12, 0, 0)],
	["lowerarm_l", "upperarm_l", Vector3(0.20, 0, 0)],
	["hand_l", "lowerarm_l", Vector3(0.20, 0, 0)],
	["prop_l", "hand_l", Vector3(0.08, 0, 0.03)],
	["clavicle_r", "spine_03", Vector3(-0.04, 0.08, 0)],
	["upperarm_r", "clavicle_r", Vector3(-0.12, 0, 0)],
	["lowerarm_r", "upperarm_r", Vector3(-0.20, 0, 0)],
	["hand_r", "lowerarm_r", Vector3(-0.20, 0, 0)],
	["prop_r", "hand_r", Vector3(-0.08, 0, 0.03)],
	["thigh_l", "pelvis", Vector3(0.09, -0.02, 0)],
	["calf_l", "thigh_l", Vector3(0, -0.38, 0)],
	["foot_l", "calf_l", Vector3(0, -0.34, 0)],
	["thigh_r", "pelvis", Vector3(-0.09, -0.02, 0)],
	["calf_r", "thigh_r", Vector3(0, -0.38, 0)],
	["foot_r", "calf_r", Vector3(0, -0.34, 0)],
]
## Palette cells (4×4, 8 px each): the UV centre of each colour.
const PAL := {"navy": 0, "white": 1, "skin": 2, "red": 3, "yellow": 4, "silver": 5, "plum": 6, "brown": 7}
const PAL_COLORS := [Color("#23284A"), Color("#F4F1EA"), Color("#F3E6D8"), Color("#C8243A"), Color("#F2C230"),
	Color("#D9DCE3"), Color("#6B3A6E"), Color("#7A5132")]
const BOX := {
	# bone: [palette colour, half extents] (a box from the bone to its first child, or a cube at the bone)
	"pelvis": ["navy", Vector3(0.13, 0.08, 0.09)], "spine_01": ["navy", Vector3(0.12, 0.07, 0.08)],
	"spine_02": ["white", Vector3(0.12, 0.07, 0.08)], "spine_03": ["navy", Vector3(0.13, 0.07, 0.08)],
	"neck_01": ["skin", Vector3(0.04, 0.05, 0.04)], "Head": ["skin", Vector3(0.13, 0.13, 0.12)],
	"beret": ["red", Vector3(0.10, 0.03, 0.10)], "bouffant": ["silver", Vector3(0.11, 0.05, 0.09)],
	"sideburn_l": ["silver", Vector3(0.02, 0.05, 0.03)], "sideburn_r": ["silver", Vector3(0.02, 0.05, 0.03)],
	"upperarm_l": ["navy", Vector3(0.10, 0.035, 0.035)], "lowerarm_l": ["navy", Vector3(0.10, 0.03, 0.03)],
	"hand_l": ["white", Vector3(0.05, 0.04, 0.03)], "prop_l": ["yellow", Vector3(0.04, 0.04, 0.04)],
	"upperarm_r": ["navy", Vector3(0.10, 0.035, 0.035)], "lowerarm_r": ["navy", Vector3(0.10, 0.03, 0.03)],
	"hand_r": ["white", Vector3(0.05, 0.04, 0.03)], "prop_r": ["yellow", Vector3(0.05, 0.05, 0.05)],
	"thigh_l": ["navy", Vector3(0.05, 0.19, 0.05)], "calf_l": ["navy", Vector3(0.045, 0.17, 0.045)],
	"foot_l": ["brown", Vector3(0.05, 0.03, 0.09)], "thigh_r": ["navy", Vector3(0.05, 0.19, 0.05)],
	"calf_r": ["navy", Vector3(0.045, 0.17, 0.045)], "foot_r": ["brown", Vector3(0.05, 0.03, 0.09)],
}

var _out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		printerr("[make_fixtures] --out=/abs/dir required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out.path_join("anim/fix"))
	_save_rig()
	_save_attachment("bouffant_flipped", Color("#D9DCE3"), Vector3(0.26, 0.10, 0.20), Vector3(0, 0.02, 0.06))
	_save_attachment("bouffant_frazzled", Color("#B9BCC6"), Vector3(0.30, 0.18, 0.24), Vector3(0, 0.04, 0))
	_save_attachment("stool", Color("#7A5132"), Vector3(0.36, 0.55, 0.36), Vector3(0, -0.28, 0))
	_save_clips()
	print("[make_fixtures] wrote fixtures to %s" % _out)
	quit(0)


func _rest_globals() -> Dictionary:
	var g: Dictionary = {}
	for b in BONES:
		var p := String(b[1])
		g[b[0]] = (g[p] as Vector3 if p != "" else Vector3.ZERO) + (b[2] as Vector3)
	return g


func _save_rig() -> void:
	var root := Node3D.new()
	root.name = "fix"
	var arm := Node3D.new()
	arm.name = "Armature"
	root.add_child(arm)
	arm.owner = root
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	arm.add_child(sk)
	sk.owner = root
	var idx: Dictionary = {}
	for b in BONES:
		var i := sk.get_bone_count()
		sk.add_bone(String(b[0]))
		idx[b[0]] = i
		if String(b[1]) != "":
			sk.set_bone_parent(i, int(idx[b[1]]))
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, b[2] as Vector3))
	sk.reset_bone_poses()
	var skin := sk.create_skin_from_rest_transforms()
	var g := _rest_globals()
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var child_of: Dictionary = {}
	for b in BONES:
		if String(b[1]) != "" and not child_of.has(b[1]):
			child_of[b[1]] = b[0]
	for bn in BOX:
		var spec: Array = BOX[bn]
		var a: Vector3 = g[bn]
		var centre := a
		if child_of.has(bn) and not bn in ["Head", "hand_l", "hand_r", "foot_l", "foot_r", "spine_03"]:
			centre = (a + (g[child_of[bn]] as Vector3)) * 0.5
		if bn == "Head":
			centre = a + Vector3(0, 0.13, 0)
		if bn == "foot_l" or bn == "foot_r":
			centre = a + Vector3(0, -0.02, 0.04)
		_box(st, centre, spec[1] as Vector3, int(idx[bn]), int(PAL[spec[0]]), bn == "Head")
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _palette()
	mat.resource_name = "fix_palette"
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "fix_body"
	mi.mesh = mesh
	mi.skin = skin
	sk.add_child(mi)
	mi.owner = root
	mi.skeleton = NodePath("..")
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, _out.path_join("fix_rig.tscn"))
	print("[make_fixtures] fix_rig.tscn: %s (%d bones, %d verts)" % [error_string(err), sk.get_bone_count(), mesh.surface_get_array_len(0)])
	root.free()


func _palette() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for i in PAL_COLORS.size():
		var cx := (i % 4) * 8
		var cy := (i / 4) * 8
		img.fill_rect(Rect2i(cx, cy, 8, 8), PAL_COLORS[i])
	return ImageTexture.create_from_image(img)


static func _pal_uv(cell: int) -> Vector2:
	return Vector2((float(cell % 4) * 8.0 + 4.0) / 32.0, (float(cell / 4) * 8.0 + 4.0) / 32.0)


func _box(st: SurfaceTool, c: Vector3, h: Vector3, bone: int, cell: int, face_front: bool) -> void:
	var uv := _pal_uv(cell)
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for fi in faces.size():
		var n: Vector3 = faces[fi][0]
		var u: Vector3 = faces[fi][1]
		var v: Vector3 = faces[fi][2]
		var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		var pts: Array[Vector3] = []
		var uv2s: Array[Vector2] = []
		for k in corners:
			var q: Vector2 = k
			pts.append(c + (n * h.dot(n.abs()) + u * q.x * h.dot(u.abs()) + v * q.y * h.dot(v.abs())))
			# The head's front face carries the face card UV2 (u right, v DOWN from the brow: char_toon flips it).
			uv2s.append(Vector2((q.x + 1.0) * 0.5, 1.0 - (q.y + 1.0) * 0.5) if face_front and fi == 0 else Vector2(-1, -1))
		# Godot's front faces wind clockwise (as seen from outside).
		for tri in [[0, 2, 1], [0, 3, 2]]:
			for t in tri:
				st.set_color(Color(1.0 if cell == PAL["skin"] else 0.0, 1.0 if cell == PAL["red"] else 0.0, 0.0, 1.0))
				st.set_uv(uv)
				st.set_uv2(uv2s[t])
				st.set_bones(PackedInt32Array([bone, 0, 0, 0]))
				st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				st.set_normal(n)
				st.add_vertex(pts[t])


func _save_attachment(n: String, col: Color, size: Vector3, offset: Vector3) -> void:
	var root := Node3D.new()
	root.name = n
	var mi := MeshInstance3D.new()
	mi.name = "mesh"
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	bm.material = m
	mi.mesh = bm
	mi.position = offset
	root.add_child(mi)
	mi.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, _out.path_join("%s.tscn" % n))
	root.free()


# --- clips ------------------------------------------------------------------------------------------------------

func _track(a: Animation, bone: String, keys: Array) -> void:
	## keys: [[frame, Vector3 euler degrees], ...]
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, NodePath("Armature/Skeleton3D:%s" % bone))
	for k in keys:
		var e: Vector3 = k[1]
		a.rotation_track_insert_key(t, float(k[0]) / 60.0, Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z))))


func _ptrack(a: Animation, bone: String, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath("Armature/Skeleton3D:%s" % bone))
	for k in keys:
		a.position_track_insert_key(t, float(k[0]) / 60.0, k[1] as Vector3)


func _anim(frames: int, loop: bool) -> Animation:
	var a := Animation.new()
	a.length = float(frames) / 60.0
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return a


func _save_anim(a: Animation, n: String) -> void:
	var err := ResourceSaver.save(a, _out.path_join("anim/fix/%s.tres" % n))
	print("[make_fixtures] anim/fix/%s.tres: %s" % [n, error_string(err)])


func _save_clips() -> void:
	# rx_take — 90 f reaction: anticipation 18..30, accent 30..33 (a 60°/f snap of the right arm), hold 33..69, settle.
	var a := _anim(90, false)
	_track(a, "upperarm_r", [[0, Vector3.ZERO], [18, Vector3(0, 0, -20)], [30, Vector3(0, 0, -20)], [33, Vector3(0, 0, 160)],
		[69, Vector3(0, 0, 150)], [90, Vector3.ZERO]])
	_track(a, "spine_02", [[0, Vector3.ZERO], [30, Vector3(10, 0, 0)], [33, Vector3(-15, 0, 0)], [69, Vector3(-12, 0, 0)], [90, Vector3.ZERO]])
	_track(a, "Head", [[0, Vector3.ZERO], [33, Vector3(-20, 0, 0)], [90, Vector3.ZERO]])
	_ptrack(a, "pelvis", [[0, Vector3(0, 0.80, 0)], [30, Vector3(0, 0.72, 0)], [33, Vector3(0, 0.86, 0)], [90, Vector3(0, 0.80, 0)]])
	_save_anim(a, "rx_take")
	# rx_sneeze — 165 f, the Gate-0 sneeze timing (accent 94, hold 97..145, release 165).
	var s := _anim(165, false)
	_track(s, "spine_02", [[0, Vector3.ZERO], [74, Vector3(-20, 0, 0)], [94, Vector3(-25, 0, 0)], [97, Vector3(30, 0, 0)], [145, Vector3(25, 0, 0)], [165, Vector3.ZERO]])
	_track(s, "Head", [[0, Vector3.ZERO], [94, Vector3(-30, 0, 0)], [97, Vector3(25, 0, 0)], [165, Vector3.ZERO]])
	_save_anim(s, "rx_sneeze")
	# loco_walk — an 80 f in-place loop (stride 1.6 m at 2.0 m/s = 48 f/stride... here 80 f, speed 1.2 m/s).
	var w := _anim(80, true)
	_track(w, "thigh_l", [[0, Vector3(25, 0, 0)], [40, Vector3(-25, 0, 0)], [80, Vector3(25, 0, 0)]])
	_track(w, "thigh_r", [[0, Vector3(-25, 0, 0)], [40, Vector3(25, 0, 0)], [80, Vector3(-25, 0, 0)]])
	_track(w, "upperarm_l", [[0, Vector3(0, 0, -70)], [40, Vector3(0, 0, -60)], [80, Vector3(0, 0, -70)]])
	_track(w, "upperarm_r", [[0, Vector3(0, 0, 70)], [40, Vector3(0, 0, 60)], [80, Vector3(0, 0, 70)]])
	_save_anim(w, "loco_walk")
	# loco_idle — a 120 f breathing loop.
	var i := _anim(120, true)
	_track(i, "spine_02", [[0, Vector3.ZERO], [60, Vector3(4, 0, 0)], [120, Vector3.ZERO]])
	_track(i, "upperarm_l", [[0, Vector3(0, 0, -75)], [60, Vector3(0, 0, -72)], [120, Vector3(0, 0, -75)]])
	_track(i, "upperarm_r", [[0, Vector3(0, 0, 75)], [60, Vector3(0, 0, 72)], [120, Vector3(0, 0, 75)]])
	_save_anim(i, "loco_idle")
	# mg_wave — a 48 f upper-body overlay (the right arm waves).
	var o := _anim(48, false)
	_track(o, "upperarm_r", [[0, Vector3(0, 0, 75)], [12, Vector3(0, 0, -60)], [24, Vector3(0, 0, -40)], [36, Vector3(0, 0, -60)], [48, Vector3(0, 0, 75)]])
	_track(o, "thigh_l", [[0, Vector3(0, 0, 40)], [48, Vector3(0, 0, 40)]])
	_save_anim(o, "mg_wave")
	# beat_suppressed — 60 f; beat_slow_burn — 70 f (the T3 last beat).
	var b := _anim(60, false)
	_track(b, "Head", [[0, Vector3(0, 10, 0)], [60, Vector3(0, -10, 0)]])
	_save_anim(b, "beat_suppressed")
	var sb := _anim(70, false)
	_track(sb, "Head", [[0, Vector3.ZERO], [35, Vector3(0, 30, 0)], [70, Vector3.ZERO]])
	_save_anim(sb, "beat_slow_burn")
