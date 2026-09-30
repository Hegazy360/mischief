## RigPerf3D — one character on the game camera for N frames (r3d-rig §4.4, pre-gate row 17): the player's CPU per
## frame (clock + tree + events + face + modifiers incl. jiggle, measured around RigPlayer3D.advance: `cpu_us_*` with
## the meshes unbound in the second half = the player's own cost; `cpu_us_with_skin_*` in the first half incl. the
## renderer's bone upload), the frame's draw calls / primitives, bone / deform-bone / triangle counts, the box's load
## average; prints one `[rigperf3d] {json}` line.
##   tools/scripts/shot.sh res://scenes/dev/anim3d/RigPerf3D.tscn out.png 600 <sb> -- --rig=hush --clip=hush/loco_run --perf-log
## Flags: --rig=<id> [--variant=head_b] [--clip=<id> | --anim-glb=/abs --anim-name=N] [--frames=N] [--data-root=res://…]
extends Node3D

var rig: RigPlayer3D = null
var prof := RigProfile3D.new()
var prof_skin := RigProfile3D.new()
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
	var dt := 1.0 / 60.0 if delta <= 0.0 else delta
	# Phase A (first half): the skinned meshes bound — the renderer's bone upload lands in the measured frame too.
	# Phase B (second half): the meshes unbound from the skeleton — the player's own cost (clock, tree, events,
	# modifiers incl. jiggle, face); the brief's budget line ("skinning is the renderer's").
	var half := (_frames - 2) / 2
	if _n == half and rig.skeleton != null:
		for mi in rig.skeleton.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).skeleton = NodePath()
	if _n < half:
		prof_skin.step(rig, dt)
	else:
		prof.step(rig, dt)
	if _n > 0:
		prof.record_render()
	_n += 1
	if _n >= _frames - 2:
		_done = true
		var sm := prof.summary(rig, 10)
		var sk := prof_skin.summary(rig, 30)
		sm["cpu_us_with_skin_median"] = sk["cpu_us_median"]
		sm["cpu_us_with_skin_p95"] = sk["cpu_us_p95"]
		sm["frame_draw_calls_median"] = prof.summary(rig)["frame_draw_calls_median"]
		sm["loadavg"] = _loadavg()
		print("[rigperf3d] " + JSON.stringify(sm))


static func _loadavg() -> float:
	var out: Array = []
	if OS.execute("cat", ["/proc/loadavg"], out) != 0 or out.is_empty():
		return -1.0
	return str(out[0]).split(" ")[0].to_float()
