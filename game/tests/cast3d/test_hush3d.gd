## Hush in 3D (r3d-cast-hush): the rig descriptor, the glb and its skeleton contract, the face presets and cells,
## the budgets (≤ 10k triangles, ≤ 50 deform bones), B's dimensions (1.60 m, B's arm lengths), UAL rest directions,
## and Hush's props (tag beret, plinth) and the R6 head variant when they exist.
extends TestBase

const RIG_DIR := "res://data/rigs3d/hush/"
const RIG := "res://data/rigs3d/hush/rig3d.json"
const FACES := "res://data/rigs3d/hush/faces.json"
const FACES_2D := "res://data/rigs/hush/faces.json"
const SKELETON := "res://data/rigs3d/hush/skeleton.json"
const RIG_DEF_3D := "res://view3d/char/rig_def_3d.gd"
const TAG := "res://art3d/chars/hush/tag_beret.glb"
const PLINTH := "res://art3d/chars/hush/plinth.glb"
const REQUIRED := ["version", "rig", "scene", "skeleton", "mesh", "height_m", "head_scale", "tris", "deform_bones",
	"bones", "sockets", "props", "attachments", "slots", "anim", "jiggle", "face", "material", "vertex_color", "looks",
	"tint", "stone", "cheat", "blob_shadow_r", "skins"]
const SOCKETS := ["grip_r", "grip_l", "head_top", "brace_r", "carry_1", "carry_2", "feet", "face"]
const MAX_TRIS := 10000
const MAX_DEFORM := 50

var _rig: Dictionary = {}
var _skel_json: Dictionary = {}
var _scene_root: Node3D = null


func before_each() -> void:
	_rig = load_json(RIG) if FileAccess.file_exists(RIG) else {}
	_skel_json = load_json(SKELETON) if FileAccess.file_exists(SKELETON) else {}


func after_each() -> void:
	if _scene_root != null:
		_scene_root.free()
		_scene_root = null


func _instance(path: String) -> Node3D:
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	return ps.instantiate() as Node3D


func _skeleton(root: Node) -> Skeleton3D:
	return root.get_node_or_null(String(_rig.get("skeleton", "Armature/Skeleton3D"))) as Skeleton3D


func _mesh(root: Node) -> MeshInstance3D:
	return root.get_node_or_null(String(_rig.get("mesh", "Armature/Skeleton3D/hush_body"))) as MeshInstance3D


func _hush() -> Node3D:
	if _scene_root == null:
		_scene_root = _instance(String(_rig.get("scene", "")))
	return _scene_root


## Names of the skeleton bones that carry a vertex weight (the deform bones).
func _weighted_bones(mi: MeshInstance3D, sk: Skeleton3D) -> PackedStringArray:
	var used := {}
	var skin: Skin = mi.skin
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in bones.size():
			if weights[i] > 0.0001:
				used[bones[i]] = true
	var out := PackedStringArray()
	for b in used.keys():
		var name := ""
		if skin != null and int(b) < skin.get_bind_count():
			name = String(skin.get_bind_name(int(b)))
			if name == "" and skin.get_bind_bone(int(b)) >= 0:
				name = sk.get_bone_name(skin.get_bind_bone(int(b)))
		else:
			name = sk.get_bone_name(int(b))
		out.append(name)
	return out


func test_rig3d_parses_with_every_field() -> void:
	if not assert_false(_rig.is_empty(), "rig3d.json parses"):
		return
	for k in REQUIRED:
		assert_has(_rig, k, "rig3d.json field " + k)
	assert_eq(_rig["rig"], "hush")
	assert_eq(float(_rig["head_scale"]), 1.0, "the default ships B's head (R6)")
	assert_eq(_rig["slots"], {}, "Hush has no body slots")
	assert_eq(_rig["anim"]["layers"], [], "Hush has no default pose layers")
	assert_true(ResourceLoader.exists(String(_rig["face"]["atlas"])), "face atlas exists")
	assert_true(ResourceLoader.exists(String(_rig["material"]["palette"])), "palette exists")


func test_loads_through_rig_def_3d() -> void:
	if not ResourceLoader.exists(RIG_DEF_3D):
		skip("RigDef3D not built yet — r3d-rig")
		return
	var s: Script = load(RIG_DEF_3D)
	var def: Variant = s.call("load", "hush")
	if not assert_true(def != null, "RigDef3D.load(\"hush\") returns a descriptor"):
		return
	if def.has_method("is_valid"):
		assert_true(def.is_valid(), "RigDef3D validates rig3d.json: %s" % [def.get("errors")])


func test_scene_instantiates_with_skeleton_and_mesh() -> void:
	var h := _hush()
	if not assert_true(h != null, "the glb instantiates"):
		return
	assert_true(_skeleton(h) != null, "skeleton at " + String(_rig.get("skeleton", "")))
	assert_true(_mesh(h) != null, "mesh at " + String(_rig.get("mesh", "")))


func test_bone_names_are_ual_plus_the_contract_extras() -> void:
	var h := _hush()
	if h == null or _skel_json.is_empty():
		fail("glb or skeleton.json missing")
		return
	var sk := _skeleton(h)
	var names := {}
	for i in sk.get_bone_count():
		names[sk.get_bone_name(i)] = true
	var want: Array = _skel_json["bones"]
	assert_eq(sk.get_bone_count(), want.size(), "bone count = skeleton.json")
	var ual := 0
	for b in want:
		assert_true(names.has(String(b["name"])), "bone " + String(b["name"]))
		if bool(b["ual"]):
			ual += 1
	assert_eq(ual, 65, "the 65 UAL bones")
	for extra in ["beret", "beret_stalk", "hair_l", "hair_r", "brace_l", "brace_r", "prop_clarence", "clarence_comb",
			"clarence_body", "prop_r", "prop_l", "carry_1", "carry_2", "fx_pepper"]:
		assert_true(names.has(extra), "extra bone " + extra)
	# parents as the contract lists
	for b in want:
		var i := sk.find_bone(String(b["name"]))
		var p := sk.get_bone_parent(i)
		var pn: Variant = null if p < 0 else sk.get_bone_name(p)
		if b["parent"] != null:
			assert_eq(pn, String(b["parent"]), "parent of " + String(b["name"]))


func test_budgets_triangles_and_deform_bones() -> void:
	var h := _hush()
	if h == null:
		fail("glb missing")
		return
	var mi := _mesh(h)
	var tris := 0
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	assert_le(tris, MAX_TRIS, "triangles ≤ 10,000 (REDESIGN §5.6)")
	assert_eq(int(_rig.get("tris", -1)), tris, "rig3d.json tris is the built count")
	var deform := _weighted_bones(mi, _skeleton(h))
	assert_le(deform.size(), MAX_DEFORM, "deform bones ≤ 50 (jiggle bones included)")
	assert_eq(int(_rig.get("deform_bones", -1)), deform.size(), "rig3d.json deform_bones is the built count")
	for never in ["pinky_01_l", "pinky_01_r", "index_03_l", "middle_03_r", "root", "ball_leaf_l"]:
		assert_false(deform.has(never), never + " carries no weight (merged finger joints)")
	assert_eq(mi.mesh.get_surface_count(), 1, "one surface = one material")


func test_standing_height_is_b_1_60() -> void:
	var h := _hush()
	if h == null:
		fail("glb missing")
		return
	var mi := _mesh(h)
	var sk := _skeleton(h)
	var skin: Skin = mi.skin
	var stalk := sk.find_bone("beret_stalk")
	var lo := INF
	var hi := -INF
	var hi_all := -INF
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(verts.size(), 1)
		for i in verts.size():
			var y := verts[i].y
			lo = minf(lo, y)
			hi_all = maxf(hi_all, y)
			var on_stalk := false
			for k in per:
				var b := bones[i * per + k]
				var bb := skin.get_bind_bone(b) if skin != null and skin.get_bind_bone(b) >= 0 else b
				if bb == stalk and weights[i * per + k] > 0.5:
					on_stalk = true
			if not on_stalk:
				hi = maxf(hi, y)
	assert_almost_eq(lo, 0.0, 0.005, "feet on y = 0")
	assert_almost_eq(hi - lo, 1.60, 0.01, "1.60 m to the top of the beret, stalk excluded (look B)")
	assert_le(hi_all - lo, 1.64, "the stalk adds at most a few cm")
	assert_almost_eq(float(_rig["height_m"]), 1.60, 0.01, "rig3d.json height_m")


func test_rest_directions_equal_ual_and_arm_lengths_equal_b() -> void:
	var h := _hush()
	if h == null or _skel_json.is_empty():
		fail("glb or skeleton.json missing")
		return
	var sk := _skeleton(h)
	var worst := 0.0
	var worst_bone := ""
	for b in _skel_json["bones"]:
		if not bool(b["ual"]):
			continue
		var i := sk.find_bone(String(b["name"]))
		var y_axis := sk.get_bone_global_rest(i).basis.y.normalized()
		var d: Array = b["ual_dir_godot"]
		var want := Vector3(float(d[0]), float(d[1]), float(d[2])).normalized()
		var ang := rad_to_deg(y_axis.angle_to(want))
		if ang > worst:
			worst = ang
			worst_bone = String(b["name"])
	assert_le(worst, 0.5, "every UAL bone's rest direction = UAL's within 0.5° (worst %s)" % worst_bone)
	var arms: Dictionary = _skel_json["arms_b"]
	for s in ["l", "r"]:
		var sh := sk.get_bone_global_rest(sk.find_bone("upperarm_" + s)).origin
		var el := sk.get_bone_global_rest(sk.find_bone("lowerarm_" + s)).origin
		var wr := sk.get_bone_global_rest(sk.find_bone("hand_" + s)).origin
		assert_almost_eq(sh.distance_to(el), float(arms["upperarm_m"]), 0.005, "upper arm = B's (%s)" % s)
		assert_almost_eq(el.distance_to(wr), float(arms["forearm_m"]), 0.005, "forearm = B's (%s)" % s)
		assert_almost_eq(sh.y, float(arms["shoulder_z"]), 0.005, "shoulder height = B's (%s)" % s)


func test_every_2d_preset_exists_and_every_cell_resolves() -> void:
	var f3: Dictionary = load_json(FACES)
	var f2: Dictionary = load_json(FACES_2D)
	var presets: Dictionary = f3["presets"]
	assert_eq(presets.size(), (f2["presets"] as Dictionary).size(), "26 presets")
	var cells: Dictionary = _rig["face"]["cells"]
	var grid: Array = _rig["face"]["grid"]
	var n_cells := int(grid[0]) * int(grid[1])
	for name in f2["presets"]:
		if not assert_has(presets, name, "3D preset " + String(name)):
			continue
		var p: Dictionary = presets[name]
		for layer in ["eyes", "brows", "pupils", "mouth", "extra_a", "extra_b"]:
			assert_has(p, layer, "%s.%s" % [name, layer])
			var c: Variant = p.get(layer)
			if c != null:
				assert_true((cells[layer] as Dictionary).has(String(c)), "%s: %s cell %s" % [name, layer, c])
	for layer in cells:
		for c in cells[layer]:
			assert_between(int(cells[layer][c]), 0, n_cells - 1, "cell index in the grid: " + String(c))
	for layer in _rig["face"]["layers"]:
		assert_has(_rig["face"]["layer_rects"], layer, "layer rect " + String(layer))
	var blink: Dictionary = _rig["face"]["blink"]
	assert_true((cells["eyes"] as Dictionary).has(String(blink["cell"])), "blink cell exists")
	for e in blink["blinkable"]:
		assert_true((cells["eyes"] as Dictionary).has(String(e)), "blinkable " + String(e))


func test_mirror_cells_resolve_and_statues_keep_their_eyes() -> void:
	var cells: Dictionary = _rig["face"]["cells"]
	var all := {}
	for layer in cells:
		for c in cells[layer]:
			all[String(c)] = String(layer)
	var mc: Dictionary = _rig["face"]["mirror_cells"]
	assert_gt(mc.size(), 0, "mirrored cells for the asymmetric marks")
	for a in mc:
		assert_has(all, a, "mirror source " + String(a))
		assert_has(all, mc[a], "mirror target " + String(mc[a]))
		if all.has(a) and all.has(mc[a]):
			assert_eq(all[a], all[mc[a]], "a mirror stays in its layer")
	for c in ["eyes_dark_open", "eyes_dark_blink", "pupils_dark"]:
		assert_has(_rig["face"]["card_cells"], c, "hiding-spot eye card cell " + c)
	var f3: Dictionary = load_json(FACES)
	for s in ["statue", "statue_blink"]:
		assert_has(f3["presets"], s)
	assert_has(_rig["stone"]["keep"], "eyes", "the marble keeps her eyes (stone-keep mask)")


func test_sockets_props_jiggle_bones_exist() -> void:
	var h := _hush()
	if h == null:
		fail("glb missing")
		return
	var sk := _skeleton(h)
	for s in SOCKETS:
		if assert_has(_rig["sockets"], s, "socket " + s):
			assert_ge(sk.find_bone(String(_rig["sockets"][s]["bone"])), 0, "socket bone of " + s)
	for p in _rig["props"]:
		var pd: Dictionary = _rig["props"][p]
		assert_ge(sk.find_bone(String(pd["bone"])), 0, "prop bone of " + String(p))
		for st in pd["states"]:
			var target := String(pd["states"][st])
			assert_true(target == "hidden" or (_rig["sockets"] as Dictionary).has(target), "prop state %s.%s" % [p, st])
	assert_has(_rig["props"], "clarence")
	assert_has(_rig["props"], "pepper_pot")
	assert_eq(_rig["props"]["pepper_pot"]["default"], "hidden", "the pepper pot is hidden by default")
	for g in _rig["jiggle"]:
		for b in g["bones"]:
			assert_ge(sk.find_bone(String(b)), 0, "jiggle bone " + String(b))
		for k in ["stiffness", "drag", "gravity", "radius", "clamp_deg"]:
			assert_has(g, k, "jiggle param " + k)
	for b in _rig["bones"]:
		assert_ge(sk.find_bone(String(_rig["bones"][b])), 0, "descriptor bone " + String(b))


func test_socket_model_points_match_the_skeleton() -> void:
	var h := _hush()
	if h == null:
		fail("glb missing")
		return
	var sk := _skeleton(h)
	for s in _rig["sockets"]:
		var so: Dictionary = _rig["sockets"][s]
		var p: Array = so["pos"]
		var m: Array = so["model_pos"]
		var g := sk.get_bone_global_rest(sk.find_bone(String(so["bone"]))) * Vector3(float(p[0]), float(p[1]), float(p[2]))
		assert_lt(g.distance_to(Vector3(float(m[0]), float(m[1]), float(m[2]))), 0.003, "socket %s at its model point" % s)


func test_vertex_colours_present() -> void:
	var h := _hush()
	if h == null:
		fail("glb missing")
		return
	var mi := _mesh(h)
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if not assert_eq(cols.size(), verts.size(), "COLOR_0 on every vertex"):
		return
	var keep := 0
	var damp := 0
	var skin := 0
	for c in cols:
		if c.g > 0.5:
			keep += 1
		if c.b > 0.5:
			damp += 1
		if c.r > 0.01:
			skin += 1
	assert_eq(skin, 0, "R skin tint unused on Hush")
	assert_gt(keep, 0, "G stone keep on the eyes / beret / braces")
	assert_gt(damp, 0, "B rim damp on the navy")
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	assert_eq(uv2.size(), verts.size(), "FaceUV (TEXCOORD_1) present")


func test_props_tag_beret_and_plinth_load() -> void:
	if not ResourceLoader.exists(TAG) or not ResourceLoader.exists(PLINTH):
		skip("tag_beret.glb / plinth.glb not built yet — r3d-cast-hush P1")
		return
	for path in [TAG, PLINTH]:
		var n := _instance(path)
		if assert_true(n != null, path + " instantiates"):
			n.free()
	var t := _instance(TAG)
	var sk := t.find_child("Skeleton3D", true, false) as Skeleton3D
	if assert_true(sk != null, "the tag has a skeleton"):
		assert_ge(sk.find_bone("string"), 0, "the tag's string bone (wiggle)")
	t.free()


func test_head_variant_shares_every_bone_name() -> void:
	var path := RIG_DIR + "rig3d_head_b.json"
	if not FileAccess.file_exists(path):
		skip("no head variant (R6 step 1 passed or step 2 not run)")
		return
	var v: Dictionary = load_json(path)
	assert_eq(v.get("variant", ""), "head_b")
	assert_gt(float(v["head_scale"]), 1.0, "the proposal grows the head")
	var a := _hush()
	var b := _instance(String(v["scene"]))
	if not assert_true(b != null, "the head_b glb instantiates"):
		return
	var sa := _skeleton(a)
	var sb := b.get_node_or_null(String(v["skeleton"])) as Skeleton3D
	assert_eq(sb.get_bone_count(), sa.get_bone_count(), "same bone count")
	for i in sa.get_bone_count():
		assert_eq(sb.get_bone_name(i), sa.get_bone_name(i), "same bone %d" % i)
	b.free()
