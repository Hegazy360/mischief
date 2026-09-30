## RigPerf3D — one character on the game camera for N frames (r3d-rig §4.4, pre-gate row 17): the player's CPU per
## frame (clock + tree + events + face + modifiers incl. jiggle, measured around RigPlayer3D.advance), the frame's
## draw calls / primitives, bone / deform-bone / triangle counts; prints one `[rigperf3d] {json}` line.
##   tools/scripts/shot.sh res://scenes/dev/anim3d/RigPerf3D.tscn out.png 600 <sb> -- --rig=hush --clip=hush/loco_run --perf-log
## Flags: --rig=<id> [--variant=head_b] [--clip=<id> | --anim-glb=/abs --anim-name=N] [--frames=N] [--data-root=res://…]
extends Node3D

var rig: RigPlayer3D = null
var prof := RigProfile3D.new()
var _frames: int = 600
var _n: int = 0
var _done: bool = false


func _ready() -> void:
	var cfg := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2)
			var eq := kv.find("=")
			cfg[kv.substr(0, eq) if eq >= 0 else kv] = kv.substr(eq + 1) if eq >= 0 else "true"
	_frames = int(cfg.get("frames", 600))
	if cfg.has("data-root"):
		var r := String(cfg["data-root"])
		RigDef3D.search_roots.append(r)
		ClipLib3D.search_roots.append(r)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2A2342")
	we.environment = env
	add_child(we)
	rig = RigPlayer3D.new()
	rig.auto_advance = false
	add_child(rig)
	var rid := String(cfg.get("rig", "hush"))
	rig.setup(rid, String(cfg.get("variant", "")))
	rig.position = Vector3(0, 0, -1.0)
	rig.set_facing(1, false)
	rig.set_cheat(20.0, 0.0)
	var cid := String(cfg.get("clip", ""))
	if cfg.has("anim-glb"):
		cid = ClipLib3D.load_glb_action(rid, String(cfg["anim-glb"]), String(cfg.get("anim-name", "")))
	if cid != "":
		rig.play(cid, {"loop": true})
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 30.0
	cam.near = 0.5
	cam.far = 60.0
	add_child(cam)
	cam.position = Vector3(0, 1.9, 6.5)
	cam.look_at(Vector3(0, 1.35, -1.0), Vector3.UP)
	cam.current = true


func _process(delta: float) -> void:
	if _done or rig == null:
		return
	prof.step(rig, 1.0 / 60.0 if delta <= 0.0 else delta)
	if _n > 0:
		prof.record_render()
	_n += 1
	if _n >= _frames - 2:
		_done = true
		print("[rigperf3d] " + JSON.stringify(prof.summary(rig)))
