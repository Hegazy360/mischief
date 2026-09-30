## ToyStudio — neutral turnaround / expression / pose stage for Toy Box characters.
##   --fig=<abs.glb>@x,z@yaw@anim@t@preset[@k=v;k=v]   repeatable; anim '' = rest; t = clip time (s)
##        flags: bone:<name>:<scale>  temper:<0..1>
##   --cam=ortho,<size>,<cx>,<cy>            orthographic, looking along -Z (default)
##   --cam=persp,<fov>,<x>,<y>,<z>,<tx>,<ty>,<tz>
##   --bg=#rrggbb   --floor=#rrggbb|none   --outline=<px>   --shot=/abs.png --frames=N
extends Node3D

const TOYCHAR := preload("res://toy/toy_char.gd")
const DIO := preload("res://diorama/diorama.gd")

var _shot := ""
var _frames := 8
var _n := 0
var figs: Array = []


func _ready() -> void:
	var opt := {}
	var fig_specs: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fig="):
			fig_specs.append(a.substr(6))
		elif a.begins_with("--") and a.contains("="):
			opt[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_shot = String(opt.get("shot", ""))
	_frames = int(opt.get("frames", "8"))
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(String(opt.get("bg", "#2e2540")))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.68, 0.8)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.name = "Key"
	# same orientation as the diorama key light (basis rows from diorama.tscn)
	key.transform = Transform3D(Basis(Vector3(0.87595, 0, 0.48241), Vector3(0.29836, 0.7858, -0.54176), Vector3(-0.37907, 0.61849, 0.68832)), Vector3(0, 6, 4))
	key.light_energy = 0.45
	key.shadow_enabled = true
	key.shadow_bias = 0.05
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 20.0
	add_child(key)
	var key_dir := key.global_transform.basis.z.normalized()
	var fl := String(opt.get("floor", "#4a3d5e"))
	if fl != "none":
		var floor := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(40, 12)
		floor.mesh = pm
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(fl)
		fm.roughness = 1.0
		fm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		floor.material_override = fm
		floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(floor)
	var cam := Camera3D.new()
	var cs := String(opt.get("cam", "ortho,2.2,0,0.85")).split(",")
	if cs[0] == "ortho":
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(cs[1])
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.position = Vector3(float(cs[2]), float(cs[3]), 10.0)
		cam.far = 40.0
	else:
		cam.fov = float(cs[1])
		cam.position = Vector3(float(cs[2]), float(cs[3]), float(cs[4]))
		add_child(cam)
		cam.look_at(Vector3(float(cs[5]), float(cs[6]), float(cs[7])))
		remove_child(cam)
	add_child(cam)
	cam.make_current()
	var ow := float(opt.get("outline", "2.4"))
	for spec in fig_specs:
		var p := spec.split("@")
		var n: Node3D = DIO.load_character(p[0])
		if n == null:
			continue
		add_child(n)
		var xz := p[1].split(",")
		n.position = Vector3(float(xz[0]), float(xz[2]) if xz.size() > 2 else 0.0, float(xz[1]))
		n.rotation.y = deg_to_rad(float(p[2]))
		var drv: Node = TOYCHAR.setup(n, p[0], key_dir, ow, ow > 0.0) if TOYCHAR.is_toy(n) else null
		var ap: AnimationPlayer = TOYCHAR.find_player(n)
		var anim := p[3] if p.size() > 3 else ""
		if ap != null:
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			if anim != "" and ap.has_animation(anim):
				ap.play(anim)
				ap.seek(float(p[4]) if p.size() > 4 else 0.0, true)
		if drv != null:
			drv.no_blink = true
			if p.size() > 5 and p[5] != "":
				drv.forced = p[5]
			if p.size() > 6:
				for kv in p[6].split(";", false):
					var t := kv.split(":")
					if t[0] == "bone":
						drv.bone_scale(t[1], float(t[2]))
					elif t[0] == "temper":
						drv.temper_override = float(t[1])
		figs.append(n)


func _process(_dt: float) -> void:
	_n += 1
	if _shot != "" and _n >= _frames:
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(_shot.get_base_dir())
		img.save_png(_shot)
		print("[ToyStudio] saved ", _shot, " | texture mem %.2f MB | buffer mem %.2f MB | draw calls %d | primitives %d" % [
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		get_tree().quit()
