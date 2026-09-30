## RigPerf3D — one character on the game camera for N frames (r3d-rig §4.4, pre-gate row 17): the player's CPU per
## frame (clock + tree + events + face + modifiers incl. jiggle, measured around RigPlayer3D.advance: `cpu_us_*` with
## the meshes unbound in the second half = the player's own cost; `cpu_us_with_skin_*` in the first half incl. the
## renderer's bone upload), the frame's draw calls / primitives, bone / deform-bone / triangle counts, the box's load
## average; prints one `[rigperf3d] {json}` line.
##   tools/scripts/shot.sh res://scenes/dev/anim3d/RigPerf3D.tscn out.png 600 <sb> -- --rig=hush --clip=hush/loco_run --perf-log
## Flags: --rig=<id> [--variant=head_b] [--clip=<id> | --anim-glb=/abs --anim-name=N] [--frames=N] [--data-root=res://…] [--no-gaze]
## **Switch mode** (the in-game clip churn, skin bound the whole run): `--switch-every=N` plays the next base clip every
## N frames (`--clips=a,b,…`, else every base clip of the rig with a baked Animation, in order, cycling) and
## `--look-every=M` toggles the rig's looks in turn every M frames; `--prepare` calls `RigPlayer3D.prepare_clips(list)`
## after setup (the Night's warm step). The line then carries `switch`: {every, clips, switches, prepare_ms,
## play_us / advance_us / advance_switch_us (the advance right after a play) / advance_other_us / set_look_us:
## {n, mean, p95, max}, slowest_advance: the 5 slowest [µs, frame, clip, clip frame, "switch" | "look" | ""],
## looks_passes}.
extends Node3D

var rig: RigPlayer3D = null
var prof := RigProfile3D.new()
var prof_skin := RigProfile3D.new()
var _frames: int = 600
var _n: int = 0
var _done: bool = false
var _every: int = 0
var _look_every: int = 0
var _list := PackedStringArray()
var _next: int = 0
var _looks := PackedStringArray()
var _look_i: int = 0
var _prepare_ms: float = -1.0
var _play_us := PackedFloat32Array()
var _adv_us := PackedFloat32Array()
var _adv_sw_us := PackedFloat32Array()
var _adv_other_us := PackedFloat32Array()
var _look_us := PackedFloat32Array()
var _slow: Array = []                        ## the 5 slowest advances: [µs, frame, clip, clip frame, what]


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
	rig.gaze_enabled = not cfg.has("no-gaze")
	rig.position = Vector3(0, 0, -1.0)
	rig.set_facing(1, false)
	rig.set_cheat(20.0, 0.0)
	_every = int(cfg.get("switch-every", 0))
	_look_every = int(cfg.get("look-every", 0))
	if _every > 0:
		_list = switch_list(rid, String(cfg.get("clips", "")))
		if rig.ok and rig.def != null:
			for lk in rig.def.looks:
				_looks.append(String(lk))
		if cfg.has("prepare") and rig.has_method("prepare_clips"):
			var t0 := Time.get_ticks_usec()
			rig.call("prepare_clips", _list)
			_prepare_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	var cid := String(cfg.get("clip", ""))
	if cfg.has("anim-glb"):
		cid = ClipLib3D.load_glb_action(rid, String(cfg["anim-glb"]), String(cfg.get("anim-name", "")))
	if cid != "" and _every <= 0:
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


## The switch list: `csv` ids, else every base (non-overlay) clip of `rig` whose baked Animation exists (checked on
## disk only — nothing is loaded before the measured run).
static func switch_list(rig_id: String, csv: String) -> PackedStringArray:
	var out := PackedStringArray()
	if csv != "":
		for s in csv.split(",", false):
			out.append(s.strip_edges())
		return out
	for id in ClipLib3D.clips_of(rig_id):
		var c := ClipLib3D.get_clip(id)
		if c != null and c.layer != "overlay" and c.anim_path != "" and ResourceLoader.exists(c.anim_path):
			out.append(id)
	return out


func _process(delta: float) -> void:
	if _done or rig == null:
		return
	var dt := 1.0 / 60.0 if delta <= 0.0 else delta
	if _every > 0:
		_switch_frame(dt)
		return
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


## One frame of the switch mode: maybe a play() (every `_every` frames), maybe a set_look (every `_look_every`), then
## the advance — each timed on its own.
func _switch_frame(dt: float) -> void:
	var switched := false
	var looked := false
	if not _list.is_empty() and _n % _every == 0:
		var id := _list[_next % _list.size()]
		_next += 1
		var t0 := Time.get_ticks_usec()
		rig.play(id)
		_play_us.append(float(Time.get_ticks_usec() - t0))
		switched = true
	if _look_every > 0 and not _looks.is_empty() and _n % _look_every == _look_every / 2:
		var lk := _looks[(_look_i / 2) % _looks.size()]
		var on := _look_i % 2 == 0
		_look_i += 1
		var t1 := Time.get_ticks_usec()
		rig.set_look(lk, on)
		_look_us.append(float(Time.get_ticks_usec() - t1))
		looked = true
	var t2 := Time.get_ticks_usec()
	rig.advance(dt)
	var us := float(Time.get_ticks_usec() - t2)
	_adv_us.append(us)
	if switched:
		_adv_sw_us.append(us)
	else:
		_adv_other_us.append(us)
	if _n >= 2 and (_slow.size() < 5 or us > float(_slow[_slow.size() - 1][0])):
		_slow.append([us, _n, rig.current_clip(), snappedf(rig.current_frame(), 0.1),
			"switch" if switched else ("look" if looked else "")])
		_slow.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		if _slow.size() > 5:
			_slow.resize(5)
	_n += 1
	if _n >= _frames - 2:
		_done = true
		var sm := {"rig": rig.rig_id, "variant": rig.variant, "frames": _n, "loadavg": _loadavg(), "switch": {
			"every": _every, "clips": _list.size(), "switches": _play_us.size(), "prepare_ms": _prepare_ms,
			"play_us": stats(_play_us), "advance_us": stats(_adv_us), "advance_switch_us": stats(_adv_sw_us),
			"advance_other_us": stats(_adv_other_us), "set_look_us": stats(_look_us), "slowest_advance": _slow,
			"looks_passes": rig.looks_passes}}
		print("[rigperf3d] " + JSON.stringify(sm))


## {n, mean, p95, max} of `a` (µs, rounded to 0.1).
static func stats(a: PackedFloat32Array) -> Dictionary:
	if a.is_empty():
		return {"n": 0, "mean": 0.0, "p95": 0.0, "max": 0.0}
	var s := a.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	return {"n": s.size(), "mean": snappedf(sum / float(s.size()), 0.1),
		"p95": s[clampi(int(round(0.95 * float(s.size() - 1))), 0, s.size() - 1)], "max": s[s.size() - 1]}


static func _loadavg() -> float:
	var out: Array = []
	if OS.execute("cat", ["/proc/loadavg"], out) != 0 or out.is_empty():
		return -1.0
	return str(out[0]).split(" ")[0].to_float()
