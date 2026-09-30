## ToyChar — runtime side of a Toy Box character (.glb built by look-toy/src/build_*.py).
##
## setup() swaps the imported material for ONE toy ShaderMaterial (palette + face atlas, own lighting)
## with an inverted-hull outline pass, and adds this node as the character's face driver: every frame
## it maps (playing clip, clip time) -> face preset through the clip face timelines exported by the
## Blender build (<glb>.json "faces"), blinks on its own, and writes the four face-layer indices and
## the temper tint into the material. Presets and the atlas layout come from face_<who>.json.
extends Node

const TOY := preload("res://toy/toy.gdshader")
const OUTLINE := preload("res://diorama/shaders/outline.gdshader")
const BLINKABLE := ["open", "sly", "pompous", "suspicious"]

var mat: ShaderMaterial
var layout: Dictionary = {}
var presets: Dictionary = {}
var clip_faces: Dictionary = {}
var ap: AnimationPlayer = null
var skeleton: Skeleton3D = null
var forced := ""
var temper_override := -1.0
var no_blink := false
var _blink_in := 2.2
var _blink_left := 0.0
var _rng := RandomNumberGenerator.new()
var _cur := ""


static func meshes(n: Node, out: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		meshes(c, out)
	return out


static func is_toy(root: Node) -> bool:
	for mi in meshes(root):
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var m := mi.mesh.surface_get_material(0)
			if m != null and m.resource_name.begins_with("toy_"):
				return true
	return false


static func load_tex(path: String, mip := true) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null:
		return null
	if mip:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := find_player(c)
		if r != null:
			return r
	return null


static func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := find_skeleton(c)
		if r != null:
			return r
	return null


## glb_path: the character .glb (its <basename>.json meta and face_<who>.json/.png sit next to it).
static func setup(root: Node3D, glb_path: String, key_dir: Vector3, outline_px: float = 2.4, outline_on: bool = true) -> Node:
	var dir := glb_path.get_base_dir()
	var meta: Dictionary = {}
	if FileAccess.file_exists(glb_path.get_basename() + ".json"):
		meta = JSON.parse_string(FileAccess.get_file_as_string(glb_path.get_basename() + ".json"))
	var who := String(meta.get("character", "prop"))
	var lay: Dictionary = {}
	if FileAccess.file_exists(dir.path_join("face_%s.json" % who)):
		lay = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("face_%s.json" % who)))
	var drv: Node = load("res://toy/toy_char.gd").new()
	drv.name = "ToyFace"
	drv.layout = lay
	drv.presets = lay.get("presets", {})
	var cf: Dictionary = meta.get("faces", {})
	for k in cf.keys():
		drv.clip_faces[String(k).trim_suffix("_Loop")] = cf[k]
	var m := ShaderMaterial.new()
	m.shader = TOY
	# textures come from the .glb itself (palette = albedo, face atlas = emission on TEXCOORD_1); the face
	# atlas gets mipmaps (faces are minified ~5x in game). Files next to the .glb are only a fallback.
	var pal: Texture2D = null
	var atlas: Texture2D = null
	for mi in meshes(root):
		if mi.mesh == null:
			continue
		var base := mi.mesh.surface_get_material(0)
		if base is BaseMaterial3D:
			if (base as BaseMaterial3D).albedo_texture != null:
				pal = (base as BaseMaterial3D).albedo_texture
			if (base as BaseMaterial3D).emission_texture != null:
				atlas = (base as BaseMaterial3D).emission_texture
	if pal == null and FileAccess.file_exists(dir.path_join("toy_palette.png")):
		pal = load_tex(dir.path_join("toy_palette.png"), false)
	m.set_shader_parameter("palette", pal)
	if not lay.is_empty():
		if atlas != null:
			var img := atlas.get_image()
			if img != null and not img.has_mipmaps():
				img.generate_mipmaps()
				atlas = ImageTexture.create_from_image(img)
		else:
			atlas = load_tex(dir.path_join("face_%s.png" % who))
		m.set_shader_parameter("face_atlas", atlas)
	m.set_shader_parameter("key_dir", key_dir)
	var A := float(lay.get("atlas", 1024))
	for ln in (["brows", "eyes", "mouth", "extra"] if not lay.is_empty() else []):
		var L: Dictionary = lay["layers"][ln]
		var band: Array = L["band"]
		m.set_shader_parameter("layer_" + ln, Vector4(float(band[0]), float(band[1]), float(L["origin_px"][1]) / A, float(L["cell_px"][1]) / A))
		m.set_shader_parameter("cell_w", float(L["cell_px"][0]) / A)
		m.set_shader_parameter("per_row", int(L["per_row"]))
	if outline_on:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("width_px", outline_px)
		o.set_shader_parameter("use_color_normal", false)
		o.set_shader_parameter("max_world", 0.02)
		o.set_shader_parameter("outline_color", Color(0.16, 0.11, 0.2))
		m.next_pass = o
	for mi in meshes(root):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			mi.mesh.surface_set_material(i, m)       # drops the imported StandardMaterial3D (+ its textures)
			mi.set_surface_override_material(i, null)
	drv.mat = m
	drv.ap = find_player(root)
	drv.skeleton = find_skeleton(root)
	root.add_child(drv)
	if not lay.is_empty():
		drv.set_preset_now("neutral")
	else:
		drv.set_process(false)
	return drv


func set_preset_now(p: String) -> void:
	_apply(p, false)


func _preset_for_time() -> String:
	if forced != "":
		return forced
	if ap == null or ap.current_animation == "":
		return "neutral"
	var tl: Array = clip_faces.get(String(ap.current_animation), [])
	if tl.is_empty():
		return "neutral"
	var t := ap.current_animation_position
	var p := String(tl[0][1])
	for k in tl:
		if float(k[0]) <= t + 1e-4:
			p = String(k[1])
	return p


func _process(dt: float) -> void:
	var p := _preset_for_time()
	_blink_in -= dt
	var blink := false
	if _blink_left > 0.0:
		_blink_left -= dt
		blink = true
	elif _blink_in <= 0.0:
		_blink_left = 0.12
		_blink_in = _rng.randf_range(2.4, 4.6)
	_apply(p, blink and not no_blink)


func _apply(p: String, blink: bool) -> void:
	var pr: Dictionary = presets.get(p, presets.get("neutral", {}))
	var idx := Vector4i.ZERO
	var names := ["brows", "eyes", "mouth", "extra"]
	for i in 4:
		var L: Dictionary = layout["layers"][names[i]]
		var cells: Array = L["cells"]
		var want := String(pr.get(names[i], cells[0]))
		if i == 1 and blink and BLINKABLE.has(want) and cells.has("closed"):
			want = "closed"
		idx[i] = maxi(0, cells.find(want))
	mat.set_shader_parameter("face_idx", idx)
	var tmp := float(pr.get("temper", 0.0)) if temper_override < 0.0 else temper_override
	mat.set_shader_parameter("temper", tmp)
	_cur = p


## Bone scale override (e.g. specs_face / specs_chest) — for stills with a manually advanced player.
func bone_scale(bone: String, s: float) -> void:
	if skeleton == null:
		return
	var i := skeleton.find_bone(bone)
	if i >= 0:
		skeleton.set_bone_pose_scale(i, Vector3.ONE * maxf(s, 0.0001))
