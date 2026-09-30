## ToyShot — DioramaShot + Toy Box characters. Same arguments as DioramaShot (see diorama/README), plus:
##   --face=<i>@<preset>        force a face preset on character i
##   --seekc=<i>@<s>            seek character i's clip to s seconds (after --seek)
##   --pause=1                  freeze every character on its seeked pose (stills)
##   --prop=<abs.glb>@x,y,z@yaw_deg[@scale]   static toy prop (toy shader + outline), repeatable
##   --toy-outline=<px>         character outline width (default 2.4)
##   --bone=<i>@<bone>@<scale>  bone scale override on a paused character (e.g. specs_face)
##   --temper=<i>@<0..1>        temper tint override
##   --place=<i>@x,z@yaw        move character i off its mark (world x / z, yaw degrees)
##   --camx=<x>,<h>,<look_y>    side camera at x framing h metres around look_y (overrides --cam)
## Characters whose material is a toy_* material get ToyChar (the rest keep the diorama toon look).
extends "res://diorama/diorama_shot.gd"

const TOYCHAR := preload("res://toy/toy_char.gd")

var toys: Array = []   # ToyChar driver per character (null for non-toy)


func _ready() -> void:
	super._ready()
	var args := OS.get_cmdline_user_args()
	var srcs: Array[String] = []
	var opt := {}
	var multi := {"face": [], "seekc": [], "prop": [], "bone": [], "temper": [], "place": []}
	for a in args:
		if a.begins_with("--char="):
			srcs.append(a.substr(7).split("@")[0])
		elif a.begins_with("--") and a.contains("="):
			var k := a.substr(2, a.find("=") - 2)
			var v := a.substr(a.find("=") + 1)
			if multi.has(k):
				multi[k].append(v)
			else:
				opt[k] = v
	for f in multi["place"]:
		var p: PackedStringArray = f.split("@")
		var c: Node3D = chars[int(p[0])]
		var xz := p[1].split(",")
		c.global_position = Vector3(float(xz[0]), float(xz[2]) if xz.size() > 2 else c.global_position.y, float(xz[1]))
		if p.size() > 2:
			c.rotation.y = deg_to_rad(float(p[2]))
	if opt.has("camx"):
		var cv := String(opt["camx"]).split(",")
		rig.target = null
		rig.look_y = float(cv[2])
		rig.frame_x(float(cv[0]), float(cv[1]))
	var key: DirectionalLight3D = dio.get_node("Lights/Key")
	var key_dir := key.global_transform.basis.z.normalized()
	var ow := float(opt.get("toy-outline", "2.4"))
	for i in chars.size():
		var c: Node3D = chars[i]
		var drv: Node = null
		if i < srcs.size() and TOYCHAR.is_toy(c):
			drv = TOYCHAR.setup(c, srcs[i], key_dir, ow, dio.outline_chars)
		toys.append(drv)
	# one-shot clips (no _Loop suffix) play once and hold their last pose
	for c in chars:
		var ap: AnimationPlayer = dio.find_player(c)
		var want: String = c.get_meta("anim", "")
		if ap != null and want != "" and not want.ends_with("_Loop") and ap.has_animation(want):
			ap.get_animation(want).loop_mode = Animation.LOOP_NONE
			ap.play(want)
	for f in multi["face"]:
		var p: PackedStringArray = f.split("@")
		if int(p[0]) < toys.size() and toys[int(p[0])] != null:
			toys[int(p[0])].forced = p[1]
	for f in multi["temper"]:
		var p: PackedStringArray = f.split("@")
		if int(p[0]) < toys.size() and toys[int(p[0])] != null:
			toys[int(p[0])].temper_override = float(p[1])
	for f in multi["seekc"]:
		var p: PackedStringArray = f.split("@")
		var ap: AnimationPlayer = dio.find_player(chars[int(p[0])])
		if ap != null and ap.current_animation != "":
			ap.seek(float(p[1]), true)
	if opt.get("pause", "0") == "1":
		for c in chars:
			var ap: AnimationPlayer = dio.find_player(c)
			if ap != null:
				ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for t in toys:
			if t != null:
				t.no_blink = true
	for f in multi["bone"]:
		var p: PackedStringArray = f.split("@")
		if toys[int(p[0])] != null:
			toys[int(p[0])].bone_scale(p[1], float(p[2]))
	for f in multi["prop"]:
		var p: PackedStringArray = f.split("@")
		var n: Node3D = dio.load_character(p[0])
		if n == null:
			continue
		dio.get_node("Actors").add_child(n)
		var xyz := p[1].split(",")
		n.global_position = Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
		n.rotation.y = deg_to_rad(float(p[2]) if p.size() > 2 else 0.0)
		if p.size() > 3:
			n.scale = Vector3.ONE * float(p[3])
		if TOYCHAR.is_toy(n):
			TOYCHAR.setup(n, p[0], key_dir, ow * 0.8, true)
