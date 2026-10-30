## CastWorkbench — the review scene for the 3D cast (REDESIGN_3D §6.4, stage R2).
##
## The 3D counterpart of `scenes/dev/AnimViewer.tscn`: it stands one or both characters on the
## stage floor under the game camera and plays a clip, so every change to the models, the shaders
## or the procedural animation layers can be looked at at phone size before it reaches a Night.
##
##   tools/scripts/shot.sh res://scenes/dev/CastWorkbench.tscn out.png 120 cast -- \
##       --who=hush --clip=loco_walk --speed=400
##
## Flags (all optional):
##   --who=hush|bellows|both   who is on stage (default both)
##   --clip=<name>             clip to play, without the rig prefix (default loco_walk)
##   --speed=<px/s>            walk speed for a clip with stride_px (default 400)
##   --face=<preset>           face preset (default the clip's own)
##   --turn                    turnaround: yaw the character 360° over the capture
##   --mode=pose               hold frame 0 instead of playing
##   --no-jiggle / --no-ground / --no-face   switch one procedural layer off (A/B shots)
##   --temper=<0..1>           temper tint
##   --bg=<hex>                backdrop colour
extends Node3D

const FLOOR_Y := 0.0

var _chars: Array[Character3D] = []
var _turn := false
var _t := 0.0


func _ready() -> void:
	var a := _args()
	var who := String(a.get("who", "both"))
	var clip := String(a.get("clip", "loco_walk"))
	var speed := float(a.get("speed", 400.0))
	_turn = a.has("turn")

	_build_stage(String(a.get("bg", "2B2440")))

	var cast: Array[String] = []
	match who:
		"both": cast = ["hush", "bellows"]
		_: cast = [who]

	var x := -0.45 * (cast.size() - 1)
	for rig in cast:
		var c := Character3D.new()
		add_child(c)
		if not c.setup(rig):
			push_error("CastWorkbench: %s failed to build" % rig)
			continue
		c.floor_y = FLOOR_Y
		c.base_position = Vector3(x, 0.0, 0.0)
		if a.has("no-jiggle"):
			c.jiggle.set_enabled(false)
		if a.has("no-ground"):
			c.ground_weight = 0.0
		if a.has("temper"):
			c.set_temper(float(a["temper"]))
		if a.has("face"):
			c.set_face(String(a["face"]))
		if a.has("outline"):
			c.set_outline_px(float(a["outline"]))
		if a.has("fk") and c.retarget != null:
			# A/B the sagittal axis without a rebuild (see PoseRetarget3D's angle convention).
			c.retarget.set_axis({"x": Vector3(1, 0, 0), "y": Vector3(0, 1, 0), "z": Vector3(0, 0, 1)}
				.get(String(a["fk"]), Vector3(1, 0, 0)))
		if a.has("yaw"):
			c.rotation.y = deg_to_rad(float(a["yaw"]))
		var clip_id := "%s/%s" % [rig, clip]
		if ClipLib.get_clip(clip_id) == null:
			clip_id = "%s/loco_idle" % rig
		if String(a.get("mode", "")) == "pose":
			c.set_manual(true)
			c.play(clip_id)
			c.advance(0.0)
		else:
			c.play(clip_id, {"speed": speed})
		_chars.append(c)
		x += 0.90

	_report()


func _process(delta: float) -> void:
	if not _turn:
		return
	_t += delta
	for c in _chars:
		c.rotation.y = _t * TAU * 0.25


## A side-on perspective camera at the spec's framing (§5.2) plus a plain backdrop and floor, so a
## shot shows the characters and nothing that could be mistaken for set dressing.
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
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(0, 0.95, 4.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.88, 0), Vector3.UP)   # must be in the tree first
	cam.make_current()


## One line per character so a headless run records the budgets the spec asks for (§5.6).
func _report() -> void:
	for c in _chars:
		if c.rig3d == null:
			continue
		print("[cast] %s: %d tris, %d bones, %d jiggle, clip %s" % [
			c.rig_id, c.rig3d.tris, c.rig3d.bone_count, c.jiggle.bone_count(), c.clip_id()])


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var body := a.substr(2)
		var eq := body.find("=")
		if eq < 0:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
