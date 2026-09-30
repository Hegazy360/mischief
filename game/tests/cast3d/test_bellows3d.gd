## Horace Bellows in 3D (r3d-cast-bellows): the glb, the rig descriptor, the face presets and their contracts
## (r3d-index §7.3; brief §5). The skeleton reference for the rest-direction check is `ual_ref.json` (UAL's own
## rest frames, generated from the vendored UAL1 by tools/art3d/bellows/skeleton.py --ual-ref).
extends TestBase

const RIG_PATH := "res://data/rigs3d/bellows/rig3d.json"
const FACES_PATH := "res://data/rigs3d/bellows/faces.json"
const FACES_2D := "res://data/rigs/bellows/faces.json"
const UAL_REF := "res://data/rigs3d/bellows/ual_ref.json"
const SKELETON_EXTRAS := ["bouffant", "bouffant_l", "bouffant_r", "sideburn_l", "sideburn_r", "nose", "brow_l", "brow_r",
	"specs_face", "specs_chest", "cravat", "tail_l", "tail_r", "belly", "prop_r", "prop_l", "fx_choo", "fx_stars",
	"fx_notes", "ride"]
const SOCKETS := ["grip_r", "grip_l", "mouth", "head_top", "nose_tip", "belly_front", "seat", "feet", "face"]
const HELD_PROPS := ["teacup", "saucer", "spoon", "comb", "baton", "specs"]

var _rig: Dictionary = {}
var _root: Node3D = null


func before_each() -> void:
	_rig = load_json(RIG_PATH)


func after_each() -> void:
	if _root != null:
		_root.free()
		_root = null


func _scene() -> Node3D:
	if _root == null:
		var ps: PackedScene = load(String(_rig["scene"]))
		_root = ps.instantiate()
	return _root


func _skeleton() -> Skeleton3D:
	return _scene().get_node(String(_rig["skeleton"])) as Skeleton3D


func _mesh() -> MeshInstance3D:
	return _scene().get_node(String(_rig["mesh"])) as MeshInstance3D


## Bone names bound by each vertex's dominant weight (skin bind -> bone name).
func _vertex_bones(mi: MeshInstance3D) -> Array[String]:
	var sk := mi.skin
	var arr := mi.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var n := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var per := bones.size() / maxi(n, 1)
	var out: Array[String] = []
	var skel := _skeleton()
	for v in n:
		var best := 0
		for k in per:
			if weights[v * per + k] > weights[v * per + best]:
				best = k
		var bi := bones[v * per + best]
		var nm := ""
		if sk != null and sk.get_bind_name(bi) != &"":
			nm = String(sk.get_bind_name(bi))
		elif sk != null:
			nm = skel.get_bone_name(sk.get_bind_bone(bi))
		else:
			nm = skel.get_bone_name(bi)
		out.append(nm)
	return out


func test_descriptor_loads_through_rigdef3d() -> void:
	assert_eq(int(_rig.get("version", 0)), 1)
	assert_eq(String(_rig["rig"]), "bellows")
	for key in ["scene", "skeleton", "mesh", "height_m", "head_scale", "tris", "deform_bones", "bones", "sockets", "props",
			"attachments", "slots", "anim", "jiggle", "face", "material", "vertex_color", "looks", "tint", "stone", "cheat",
			"blob_shadow_r", "skins"]:
		assert_has(_rig, key, "rig3d.json field " + key)
	var path := "res://view3d/char/rig_def_3d.gd"
	if not ResourceLoader.exists(path):
		skip("RigDef3D not built yet — r3d-rig")
		return
	var script: Script = load(path)
	var def = script.call("load", "bellows")
	if not assert_true(def != null, "RigDef3D.load(\"bellows\") returns a definition"):
		return
	if def.has_method("is_valid"):
		assert_true(def.is_valid(), "RigDef3D validates bellows: %s" % str(def.get("errors")))
		var warn: PackedStringArray = def.get("warnings")
		for w in warn:
			# allowed: the soft ride-along stool until r3d-sets builds it; the attachment count (the four bouffant
			# variants share one slot, so at most variant + stool = 2 are visible at once)
			assert_true(String(w).contains("stool") or String(w).contains("visible at once"), "RigDef3D warning: " + String(w))


func test_scene_instantiates_with_one_skinned_mesh() -> void:
	assert_true(ResourceLoader.exists(String(_rig["scene"])), "bellows.glb exists")
	var sk := _skeleton()
	assert_true(sk != null, "skeleton at " + String(_rig["skeleton"]))
	var mi := _mesh()
	assert_true(mi != null, "mesh at " + String(_rig["mesh"]))
	if mi == null:
		return
	assert_eq(mi.mesh.get_surface_count(), 1, "one surface = one material")
	var arr := mi.mesh.surface_get_arrays(0)
	assert_true(arr[Mesh.ARRAY_COLOR] != null, "vertex colour masks present")
	assert_true(arr[Mesh.ARRAY_TEX_UV2] != null, "face-card UV2 present")


func test_bones_are_ual_plus_extras_and_deform_budget() -> void:
	var ref: Dictionary = load_json(UAL_REF)["bones"]
	var sk := _skeleton()
	var names: Array[String] = []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	for n in ref.keys():
		assert_has(names, String(n), "UAL bone " + String(n))
	for n in SKELETON_EXTRAS:
		assert_has(names, n, "extra bone " + n)
	assert_eq(ref.size(), 65, "UAL has 65 bones")
	# deform = bones that carry weights, jiggle bones not counted (brief §4.2 budgets)
	var jig: Array[String] = []
	for g in _rig["jiggle"]:
		for b in g["bones"]:
			jig.append(String(b))
	var used := {}
	for b in _vertex_bones(_mesh()):
		if not jig.has(b):
			used[b] = true
	assert_le(used.size(), 50, "deform bones (excluding jiggle) <= 50, got %d" % used.size())
	assert_le(int(_rig["deform_bones"]), 50)


func test_triangle_budget() -> void:
	var mi := _mesh()
	var idx: PackedInt32Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	assert_le(idx.size() / 3, 10000, "skinned mesh <= 10,000 triangles")
	assert_eq(idx.size() / 3, int(_rig["tris"]), "descriptor tris matches the glb")


func test_height_to_the_top_of_the_bouffant() -> void:
	# the rest-pose top of every vertex that is not a hidden prop/FX part (they ride above his head at scale 0)
	var hidden: Array = _rig["hidden_bones"]
	var mi := _mesh()
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var owner := _vertex_bones(mi)
	var top := -10.0
	var bottom := 10.0
	for i in verts.size():
		if hidden.has(owner[i]):
			continue
		top = maxf(top, verts[i].y)
		bottom = minf(bottom, verts[i].y)
	assert_between(top, 1.77, 1.79, "1.78 m to the top of the bouffant (got %.3f)" % top)
	assert_between(bottom, -0.01, 0.01, "feet on y = 0 (got %.3f)" % bottom)


func test_ual_rest_directions_and_rolls_kept() -> void:
	var ref: Dictionary = load_json(UAL_REF)["bones"]
	var sk := _skeleton()
	var worst := 0.0
	var worst_bone := ""
	# upper arms first (the arm-out is a pose layer, never the rest pose), then every UAL bone
	var order: Array = ["upperarm_l", "upperarm_r"] + ref.keys()
	for n in order:
		var bi := sk.find_bone(String(n))
		if not assert_true(bi >= 0, "bone " + String(n)):
			continue
		var b := sk.get_bone_global_rest(bi).basis.orthonormalized()
		var r: Dictionary = ref[n]
		var ry := Vector3(r["y"][0], r["y"][1], r["y"][2]).normalized()
		var rx := Vector3(r["x"][0], r["x"][1], r["x"][2]).normalized()
		var ay := rad_to_deg(b.y.normalized().angle_to(ry))
		var ax := rad_to_deg(b.x.normalized().angle_to(rx))
		if maxf(ay, ax) > worst:
			worst = maxf(ay, ax)
			worst_bone = String(n)
	assert_le(worst, 0.5, "every UAL bone keeps its rest direction + roll (worst %s %.3f deg)" % [worst_bone, worst])


func test_anim_layers_arm_out() -> void:
	assert_eq(_rig["anim"]["layers"], ["arm_out"])
	var rots: Dictionary = _rig["anim"]["layer_params"]["arm_out"]["rots"]
	assert_has(rots, "upperarm_l")
	assert_has(rots, "upperarm_r")


func test_all_45_presets_and_their_cells() -> void:
	var f3: Dictionary = load_json(FACES_PATH)["presets"]
	var f2: Dictionary = load_json(FACES_2D)["presets"]
	assert_eq(f2.size(), 45, "the 2D vocabulary has 45 presets")
	var cells: Dictionary = _rig["face"]["cells"]
	var grid: Array = _rig["face"]["grid"]
	for name in f2.keys():
		if not assert_has(f3, name, "preset " + String(name)):
			continue
		var p: Dictionary = f3[name]
		for layer in p.keys():
			var cell = p[layer]
			if cell == null:
				continue
			assert_has(cells, layer, "layer %s (%s)" % [layer, name])
			if cells.has(layer):
				assert_has(cells[layer], cell, "cell %s/%s of %s" % [layer, cell, name])
				if (cells[layer] as Dictionary).has(cell):
					assert_between(int(cells[layer][cell]), 0, int(grid[0]) * int(grid[1]) - 1)
	for layer in _rig["face"]["layers"]:
		assert_has(_rig["face"]["layer_rects"], layer, "rect for layer " + String(layer))
	# mirrored marks resolve both ways
	var mc: Dictionary = _rig["face"]["mirror_cells"]
	for layer in mc.keys():
		for a in mc[layer].keys():
			var b := String(mc[layer][a])
			assert_has(cells[layer], a)
			assert_has(cells[layer], b)
			assert_eq(String(mc[layer][b]), String(a), "mirror pair %s/%s" % [layer, a])
	assert_true(ResourceLoader.exists(String(_rig["face"]["atlas"])), "face atlas exists")


func test_tint_tiers_parse() -> void:
	var t: Dictionary = _rig["tint"]
	assert_eq(t["tiers"].size(), 4)
	for c in t["tiers"] + [t["livid"]]:
		assert_true(Color.html_is_valid(String(c)), "colour " + String(c))
	assert_eq(t["sideburn_scale"].size(), 4)
	assert_eq(Color(String(t["livid"])), Color("#B8324B"))


func test_props_attachments_looks_resolve() -> void:
	var sk := _skeleton()
	for pid in HELD_PROPS:
		assert_has(_rig["props"], pid, "held prop " + pid)
	for pid in _rig["props"].keys():
		var p: Dictionary = _rig["props"][pid]
		assert_true(sk.find_bone(String(p["bone"])) >= 0, "prop bone " + String(p["bone"]))
		for st in p.get("states", {}).keys():
			var sock := String(p["states"][st])
			assert_true(sock == "hidden" or (_rig["sockets"] as Dictionary).has(sock), "prop %s state %s -> %s" % [pid, st, sock])
		for h in p.get("hides", []):
			assert_has(_rig["props"], h)
	for aid in _rig["attachments"].keys():
		var a: Dictionary = _rig["attachments"][aid]
		assert_true(sk.find_bone(String(a["bone"])) >= 0, "attachment bone " + String(a["bone"]))
		if a.get("soft", false):
			continue   # the ride-along stool is r3d-sets' mesh: missing = logged, not fatal
		assert_true(ResourceLoader.exists(String(a["scene"])), "attachment scene " + String(a["scene"]))
	assert_has(_rig["attachments"], "stool")
	for fx in _rig.get("fx", {}).keys():
		assert_true(sk.find_bone(String(_rig["fx"][fx]["bone"])) >= 0, "fx bone " + String(fx))


func test_slots_and_looks() -> void:
	var slots: Dictionary = _rig["slots"]
	assert_has(slots, "bouffant")
	for v in ["neat", "flipped", "frazzled", "wet", "floured"]:
		assert_has(slots["bouffant"], v, "bouffant variant " + v)
	assert_eq(slots["bouffant"]["neat"], null, "neat = the base mesh")
	for slot in slots.keys():
		for variant in slots[slot].keys():
			var att = slots[slot][variant]
			if att != null:
				assert_has(_rig["attachments"], att, "slot %s/%s -> %s" % [slot, variant, att])
	var looks: Dictionary = _rig["looks"]
	assert_eq(looks["FRAZZLED"]["swap"], {"bouffant": "frazzled"})
	assert_eq(looks["BLINDED"]["swap"], {"bouffant": "flipped"})
	for lid in looks.keys():
		var lk: Dictionary = looks[lid]
		for slot in lk.get("swap", {}).keys():
			assert_has(slots, slot, "look %s swaps a declared slot" % lid)
			if slots.has(slot):
				assert_has(slots[slot], lk["swap"][slot], "look %s swaps to a declared variant" % lid)
		for aid in lk.get("show", []) + lk.get("hide", []):
			assert_has(_rig["attachments"], aid)
		for layer in lk.get("face_extra", {}).keys():
			assert_has(_rig["face"]["cells"][layer], lk["face_extra"][layer])


func test_sockets_resolve() -> void:
	var sk := _skeleton()
	for s in SOCKETS:
		if not assert_has(_rig["sockets"], s, "socket " + s):
			continue
		assert_true(sk.find_bone(String(_rig["sockets"][s]["bone"])) >= 0, "socket bone of " + s)
	# the mouth socket sits in front of the face, the head top at 1.78 m (rest, world)
	var m: Dictionary = _rig["sockets"]["mouth"]
	var g := sk.get_bone_global_rest(sk.find_bone(String(m["bone"])))
	var p: Array = m["pos"]
	var w := g * Vector3(p[0], p[1], p[2])
	assert_between(w.y, 1.05, 1.20, "mouth height")
	assert_gt(w.z, 0.15, "mouth in front of the head (+z = his front)")
	var t: Dictionary = _rig["sockets"]["head_top"]
	var gt := sk.get_bone_global_rest(sk.find_bone(String(t["bone"])))
	var pt: Array = t["pos"]
	assert_almost_eq((gt * Vector3(pt[0], pt[1], pt[2])).y, 1.78, 0.01, "head_top at 1.78 m")


func test_portraits_exist() -> void:
	var pr: Dictionary = _rig.get("portraits", {})
	var names: Array = pr.get("names", [])
	if names.is_empty():
		skip("portraits not rendered yet — r3d-cast-bellows P2 (needs AnimViewer3D, r3d-rig)")
		return
	for n in names:
		assert_true(ResourceLoader.exists(String(pr["dir"]).path_join("bellows_%s.png" % n)), "portrait " + String(n))
