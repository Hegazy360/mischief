## LookdevStudio3D — a neutral stage for shading comparisons (ViewSandbox3D `--studio`): loads look-dev glbs from
## ABSOLUTE paths at runtime (GLTFDocument; shots only, never shipped — R3D index §3.5 rule 1), swaps their materials
## for `char_toon` + `outline` (the game's), and poses them on a clip frame. Same argument grammar as look A's
## ToyStudio so both sides of `shading_a_vs_char_toon.png` share one framing:
##   --fig=<abs.glb>@x,z@yaw@anim@t@preset   (repeatable; anim '' = rest; t = clip time in s)
##   --cam=persp,<fov>,<x>,<y>,<z>,<tx>,<ty>,<tz>   --bg=#rrggbb   --floor=#rrggbb|none   --outline=<px>
##   --face-dir=/abs/dir   (face_<who>.png + face_<who>.json in char_toon's grid format; <who> from the glb's
##                          sidecar .json "character", else the file stem's first word)
class_name LookdevStudio3D
extends Node3D

var figs: Array[Node3D] = []
var materials: Array[ShaderMaterial] = []


## Builds the studio from the command-line options (see the class doc).
func build(opt: Dictionary, fig_specs: PackedStringArray) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(String(opt.get("bg", "#2e2540")))
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var fl := String(opt.get("floor", "#4a3d5e"))
	if fl != "none":
		var floor_mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(40, 12)
		floor_mi.mesh = pm
		var fm := ShaderMaterial.new()
		fm.shader = load(View3DConst.SH_SET)
		fm.set_shader_parameter("albedo_color", Color(fl))
		floor_mi.material_override = fm
		add_child(floor_mi)
	var cam := Camera3D.new()
	var cs := String(opt.get("cam", "persp,30,0,1.3,5.5,0,0.8,0")).split(",")
	cam.fov = float(cs[1])
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(cam)
	cam.look_at_from_position(Vector3(float(cs[2]), float(cs[3]), float(cs[4])), Vector3(float(cs[5]), float(cs[6]), float(cs[7])), Vector3.UP)
	cam.make_current()
	var ow := float(opt.get("outline", str(View3DConst.OUTLINE_CHAR_PX)))
	var face_dir := String(opt.get("face-dir", ""))
	for spec in fig_specs:
		var p := spec.split("@")
		var n := LookdevStudio3D.load_glb(p[0])
		if n == null:
			push_warning("LookdevStudio3D: cannot load %s" % p[0])
			continue
		add_child(n)
		var xz := p[1].split(",") if p.size() > 1 else PackedStringArray(["0", "0"])
		n.position = Vector3(float(xz[0]), 0.0, float(xz[1]) if xz.size() > 1 else 0.0)
		n.rotation.y = deg_to_rad(float(p[2]) if p.size() > 2 else 0.0)
		var who := LookdevStudio3D.who_of(p[0])
		var mat := LookdevStudio3D.apply_char_toon(n, face_dir, who, ow)
		materials.append(mat)
		var preset := p[5] if p.size() > 5 else "neutral"
		LookdevStudio3D.set_face(mat, face_dir, who, preset)
		var ap := LookdevStudio3D.find_player(n)
		var anim := p[3] if p.size() > 3 else ""
		if ap != null:
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var aname := LookdevStudio3D.anim_name(ap, anim)
			if aname != "":
				ap.play(aname)
				ap.seek(float(p[4]) if p.size() > 4 else 0.0, true)
		figs.append(n)


## A glb from an absolute path (GLTFDocument), or null.
static func load_glb(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var scene := doc.generate_scene(state)
	return scene as Node3D


## The character a look-dev glb shows ("hush", "bellows"), from its sidecar json or its file name.
static func who_of(path: String) -> String:
	var side := path.get_basename() + ".json"
	if FileAccess.file_exists(side):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(side))
		if d is Dictionary and (d as Dictionary).has("character"):
			return str(d["character"])
	return path.get_file().get_basename().split("_")[0]


## Every MeshInstance3D under a node.
static func meshes(n: Node, out: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		meshes(c, out)
	return out


static func find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := find_player(c)
		if r != null:
			return r
	return null


## The animation name an AnimationPlayer knows for `want` (with or without the `_Loop` suffix); "" = none.
static func anim_name(ap: AnimationPlayer, want: String) -> String:
	if want == "":
		return ""
	for cand in [want, want.trim_suffix("_Loop"), want + "_Loop"]:
		if ap.has_animation(cand):
			return cand
	for lib in ap.get_animation_library_list():
		for cand in [want, want.trim_suffix("_Loop")]:
			var full: String = ("%s/%s" % [lib, cand]) if lib != "" else String(cand)
			if ap.has_animation(full):
				return full
	return ""


## Replaces every surface material with ONE char_toon material (palette from the glb's albedo texture) + the outline
## next pass; the mesh has no vertex colours, so `vc_masks` is off (look A's palette-alpha skin flag).
static func apply_char_toon(root: Node3D, face_dir: String, who: String, outline_px: float) -> ShaderMaterial:
	var pal: Texture2D = null
	for mi in meshes(root):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i)
			if base is BaseMaterial3D and (base as BaseMaterial3D).albedo_texture != null and pal == null:
				pal = (base as BaseMaterial3D).albedo_texture
	var m := ShaderMaterial.new()
	m.shader = load(View3DConst.SH_CHAR)
	if pal != null:
		m.set_shader_parameter("palette", pal)
	m.set_shader_parameter("vc_masks", false)
	m.set_shader_parameter("rim", 0.45)
	if face_dir != "" and FileAccess.file_exists(face_dir.path_join("face_%s.png" % who)):
		var img := Image.load_from_file(face_dir.path_join("face_%s.png" % who))
		img.generate_mipmaps()
		m.set_shader_parameter("face_atlas", ImageTexture.create_from_image(img))
	var o := ShaderMaterial.new()
	o.shader = load(View3DConst.SH_OUTLINE)
	o.set_shader_parameter("outline_px", outline_px)
	o.set_shader_parameter("width_from_alpha", false)
	m.next_pass = o
	for mi in meshes(root):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, m)
		mi.layers = View3DConst.MASK_CHAR
	MaterialWarm3D.register(m, &"char")
	return m


## Sets a face preset from a converted face map (face_<who>.json: grid, rects, cells, presets).
static func set_face(m: ShaderMaterial, face_dir: String, who: String, preset: String) -> void:
	var path := face_dir.path_join("face_%s.json" % who)
	if face_dir == "" or not FileAccess.file_exists(path):
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var grid: Array = d.get("grid", [8, 8])
	m.set_shader_parameter("face_grid", Vector2i(int(grid[0]), int(grid[1])))
	var rects: Dictionary = d.get("rects", {})
	var order := ["brows", "eyes", "pupils", "mouth", "extra_a", "extra_b"]
	var arr: Array[Vector4] = []
	for ln in order:
		var r: Array = rects.get(ln, [0, 0, 0, 0])
		arr.append(Vector4(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	m.set_shader_parameter("face_rect", arr)
	var cells: Dictionary = d.get("cells", {})
	var pr: Dictionary = (d.get("presets", {}) as Dictionary).get(preset, {})
	var pick := func(layer: String, key: String) -> int:
		var names: Dictionary = cells.get(layer, {})
		var want := str(pr.get(key, ""))
		return int(names.get(want, -1)) if want != "" else -1
	m.set_shader_parameter("face_cell_a", Vector4i(pick.call("brows", "brows"), pick.call("eyes", "eyes"), -1, pick.call("mouth", "mouth")))
	m.set_shader_parameter("face_cell_b", Vector4i(pick.call("extra_a", "extra"), -1, -1, -1))
	if pr.has("temper"):
		var t := float(pr["temper"])
		m.set_shader_parameter("tint_color", Color(0.72, 0.2, 0.29, t))
