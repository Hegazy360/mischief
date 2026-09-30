## Attachments built by another pipeline keep the palette they were built with: a set / props glb riding on the rig
## (Bellows' kitchen `stool` on bone `ride`, shown by the sneeze from f95) draws with the set shader on the room's
## palette — the same stool as the set's — never with the rig's palette (it rendered salmon before this fix).
extends TestBase

const STOOL := "res://art3d/set/stool.glb"

var _p: RigPlayer3D = null


func after_each() -> void:
	if _p != null and is_instance_valid(_p):
		_p.get_parent().remove_child(_p)
		_p.free()
	_p = null


func test_set_piece_room_and_palette_lookup() -> void:
	if not FileAccess.file_exists(RigPlayer3D.HOUSE3D):
		skip("house3d.json not built yet (r3d-sets)")
		return
	assert_eq(RigPlayer3D.set_piece_room(STOOL), "kitchen", "house3d furniture kitchen_stool places stool.glb in the kitchen")
	assert_eq(RigPlayer3D.set_piece_room("res://art3d/set/kitchen_arch.glb"), "kitchen", "file-name prefix fallback")
	assert_eq(RigPlayer3D.set_piece_room("res://art3d/set/nowhere.glb"), "")
	assert_true(RigPlayer3D.room_palette("kitchen").ends_with("palette_kitchen.png"), RigPlayer3D.room_palette("kitchen"))


func test_bellows_stool_uses_the_set_palette_and_shader() -> void:
	if not ResourceLoader.exists(STOOL) or not RigDef3D.exists("bellows"):
		skip("bellows rig or the set stool not built yet (r3d-cast-bellows / r3d-sets)")
		return
	_p = RigPlayer3D.new()
	_p.auto_advance = false
	tree.root.add_child(_p)
	assert_true(_p.setup("bellows"))
	var holder := _p.find_child("Att_stool", true, false) as Node3D
	assert_true(holder != null, "the stool attachment is built")
	if holder == null:
		return
	var meshes := holder.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0)
	var want_pal := load(RigPlayer3D.room_palette("kitchen")) as Texture2D
	for n in meshes:
		var mi := n as MeshInstance3D
		var m := mi.get_surface_override_material(0) as ShaderMaterial
		assert_true(m != null, "a ShaderMaterial on %s" % mi.name)
		if m == null:
			continue
		assert_eq(m.shader.resource_path, RigPlayer3D.SET_SHADER, "the set shader, not char_toon")
		assert_eq(m.get_shader_parameter("palette"), want_pal, "the kitchen palette the stool was built on")
		assert_true(m.next_pass == null, "no character outline on set furniture")
	# The rig's own attachments (bouffants) keep the character material.
	var bf := _p.find_child("Att_bouffant_flipped", true, false) as Node3D
	if bf != null:
		var bm := (bf.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
		assert_eq(bm.shader.resource_path, RigPlayer3D.CHAR_SHADER, "cast attachments stay on char_toon")
	# Stage light reaches the set material too.
	_p.set_stage_light(0.8, 0.3)
	var sm := (meshes[0] as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	assert_almost_eq(float(sm.get_shader_parameter("stage_light")), 0.8, 0.001)
	assert_almost_eq(float(sm.get_shader_parameter("desat")), 0.3, 0.001)
