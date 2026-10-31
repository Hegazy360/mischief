## OssCastEval — evaluate an off-the-shelf rigged character pack inside the game's own renderer.
##
## Stands one KayKit (or any glTF humanoid) character on the stage floor under the game camera and
## plays a clip from a separate animation-library glTF, the way KayKit ships them (characters and
## animations share the `Rig_Medium` skeleton, so a library's tracks apply by bone name).
##
##   tools/scripts/capture.sh res://scenes/dev/OssCastEval.tscn 180 out/knight_sneak.gif -- \
##       --char=res://art3d/eval/kaykit/Knight.glb --clip=Sneaking --yaw=-55
##
## Flags: --char=<res path>   the character .glb (default KayKit Knight)
##        --libs=<a.glb;b.glb> animation glbs (default every Rig_Medium_*.glb next to the character)
##        --clip=<name>       clip to play (default Sneaking); --speed=<scale>
##        --yaw=<deg>         character yaw; --outline=<px> add the cast outline pass
##        --list              print every clip found, then quit
extends Node3D

const FLOOR_Y := 0.0
const OUTLINE_SHADER := "res://art3d/shaders/cast_outline.gdshader"


func _ready() -> void:
	var a := _args()
	var char_path := String(a.get("char", "res://art3d/eval/kaykit/Knight.glb"))
	_build_stage(String(a.get("bg", "2B2440")))

	var packed: PackedScene = load(char_path)
	if packed == null:
		push_error("OssCastEval: cannot load %s" % char_path)
		return
	var inst := packed.instantiate() as Node3D
	add_child(inst)
	inst.rotation.y = deg_to_rad(float(a.get("yaw", 0.0)))
	var skel := _find(inst, "Skeleton3D") as Skeleton3D

	# Collect animations from the library glbs into one AnimationPlayer parented next to the
	# skeleton, so the library's "Skeleton3D:bone" track paths resolve on this character.
	var libs: Array[String] = []
	if a.has("libs"):
		for p in String(a["libs"]).split(";"):
			libs.append(p)
	else:
		var dir := char_path.get_base_dir()
		for f in DirAccess.get_files_at(dir):
			if f.begins_with("Rig_Medium_") and f.ends_with(".glb"):
				libs.append(dir + "/" + f)
	var ap := AnimationPlayer.new()
	ap.name = "EvalAnim"
	skel.get_parent().add_child(ap)
	var lib := AnimationLibrary.new()
	var names: PackedStringArray = []
	for lp in libs:
		var lpacked: PackedScene = load(lp)
		if lpacked == null:
			push_warning("OssCastEval: cannot load library %s" % lp)
			continue
		var linst := lpacked.instantiate()
		var lap := _find(linst, "AnimationPlayer") as AnimationPlayer
		if lap == null:
			linst.free()
			continue
		for libname in lap.get_animation_library_list():
			var l := lap.get_animation_library(libname)
			for an in l.get_animation_list():
				var anim := l.get_animation(an)
				_retarget_paths(anim, lap, skel)
				if not lib.has_animation(an):
					lib.add_animation(an, anim)
					names.append(an)
		linst.free()
	ap.add_animation_library("", lib)
	if a.has("list"):
		names.sort()
		print("[oss] %d clips: %s" % [names.size(), ", ".join(names)])
		get_tree().quit()
		return

	var clip := String(a.get("clip", "Sneaking"))
	if not lib.has_animation(clip):
		push_warning("OssCastEval: no clip '%s'; have %s" % [clip, names])
	else:
		ap.speed_scale = float(a.get("speed", 1.0))
		var anim := lib.get_animation(clip)
		anim.loop_mode = Animation.LOOP_LINEAR
		ap.play(clip)

	if a.has("outline"):
		var om := ShaderMaterial.new()
		om.shader = load(OUTLINE_SHADER)
		om.set_shader_parameter("width_1080", float(a["outline"]))
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D)
			for s in m.mesh.get_surface_count():
				var base := m.get_active_material(s)
				if base != null:
					var dup := base.duplicate() as Material
					dup.next_pass = om
					m.set_surface_override_material(s, dup)

	var tris := 0
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	print("[oss] %s: %d tris, %d bones, %d clips, playing %s" % [
		char_path.get_file(), tris, skel.get_bone_count() if skel else 0, names.size(), clip])


## A library's tracks are addressed relative to ITS AnimationPlayer's root node; rewrite them so
## they resolve from ours. For KayKit both are "<Rig>/Skeleton3D:bone", so this is usually a no-op.
func _retarget_paths(anim: Animation, src_ap: AnimationPlayer, skel: Skeleton3D) -> void:
	for t in anim.get_track_count():
		var p := anim.track_get_path(t)
		var bone := p.get_concatenated_subnames()
		if bone == "":
			continue
		anim.track_set_path(t, NodePath("%s:%s" % [skel.name, bone]))


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null


func _build_stage(bg_hex: String) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(bg_hex)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 3)
	floor_mesh.mesh = plane
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("3A3252")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = m
	floor_mesh.position = Vector3(0, FLOOR_Y, -0.2)
	add_child(floor_mesh)
	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(0, 0.95, 4.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.88, 0), Vector3.UP)
	cam.make_current()


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var body := a.substr(2)
		var eq := body.find("=")
		out[body if eq < 0 else body.substr(0, eq)] = true if eq < 0 else body.substr(eq + 1)
	return out
