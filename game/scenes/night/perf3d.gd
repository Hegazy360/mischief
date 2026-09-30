## Perf3D — the 3D frame budget of one Night's PLAY frames (REDESIGN §6.3, index §6 row 16; brief r3d-night §4.4):
## frame time, draw calls, primitives (triangles), objects, texture memory (`Performance.RENDER_TEXTURE_MEM_USED`, the
## number of row 16), video memory, live CPUParticles3D emitters (WorldView3D's pool), process time. Fixed-size
## rings, no allocation per frame; `summary(watch)` = the e2e report's `perf3d` + the device log's per-Night line.
class_name Perf3D
extends RefCounted

const CAP := 36000

var frames: int = 0
var _ms := PackedFloat32Array()
var _dc := PackedFloat32Array()
var _n: int = 0
var tris_max: float = 0.0
var objects_max: float = 0.0
var emitters_max: int = 0
var tex_mb_max: float = 0.0
var vmem_mb_max: float = 0.0
var process_ms_max: float = 0.0
var _proc := PackedFloat32Array()
## The scripts' time per PLAY frame (NightScene's _FrameStart → _FrameEnd: every node's _process, sim included), ms.
var _script := PackedFloat32Array()
var _sn: int = 0


func _init() -> void:
	_ms.resize(CAP)
	_dc.resize(CAP)
	_proc.resize(CAP)
	_script.resize(CAP)


## One PLAY frame's script time (ms).
func add_script_ms(ms: float) -> void:
	_script[_sn % CAP] = ms
	_sn += 1


## Forget the samples (a new Night).
func reset() -> void:
	frames = 0
	_n = 0
	_sn = 0
	_last_us = 0
	tris_max = 0.0
	objects_max = 0.0
	emitters_max = 0
	tex_mb_max = 0.0
	vmem_mb_max = 0.0
	process_ms_max = 0.0


var _last_us: int = 0


## One PLAY frame. `wv` = WorldView3D (its Fx3D pool's live emitters) or null. The frame time is the WALL time since
## the previous sampled frame (`--fixed-fps 60` runs pass a fixed `dt`, the budget needs the real one); the first
## frame after a pause uses `dt`.
func frame(dt: float, wv: Object) -> void:
	frames += 1
	var i := _n % CAP
	var now := Time.get_ticks_usec()
	var wall := float(now - _last_us) / 1000.0 if _last_us > 0 else dt * 1000.0
	if wall > 1000.0:
		wall = dt * 1000.0
	_last_us = now
	_ms[i] = wall
	_dc[i] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var pm := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_proc[i] = pm
	_n += 1
	process_ms_max = maxf(process_ms_max, pm)
	tris_max = maxf(tris_max, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	objects_max = maxf(objects_max, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	tex_mb_max = maxf(tex_mb_max, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0)
	vmem_mb_max = maxf(vmem_mb_max, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	if wv != null and frames % 5 == 0:
		var fx: Variant = wv.get("fx3d")
		if fx is Object and (fx as Object).has_method("live_emitters"):
			emitters_max = maxi(emitters_max, int((fx as Object).call("live_emitters")))


## p-th value (0..1) of the sampled frame times (ms).
func frame_ms(p: float) -> float:
	return Perf3D.pct(_ms, mini(_n, CAP), p)


func draw_calls(p: float) -> float:
	return Perf3D.pct(_dc, mini(_n, CAP), p)


static func pct(a: PackedFloat32Array, n: int, p: float) -> float:
	if n <= 0:
		return 0.0
	var s := a.slice(0, n)
	s.sort()
	return s[clampi(int(floor(float(n - 1) * p + 0.5)), 0, n - 1)]


## {frames, frame_ms_p50/p95/max, draw_calls_p95, draw_calls_max, tris_max, objects_max, emitters_max, tex_mb_max,
## vmem_mb_max, process_ms_p95, shader_compiles_play, hitches, hitch_max_ms, compile_method}.
func summary(watch: ShaderWatch = null) -> Dictionary:
	var n := mini(_n, CAP)
	var out := {"frames": frames, "frame_ms_p50": snappedf(frame_ms(0.5), 0.1), "frame_ms_p95": snappedf(frame_ms(0.95), 0.1),
		"frame_ms_max": snappedf(frame_ms(1.0), 0.1), "draw_calls_p95": draw_calls(0.95), "draw_calls_max": draw_calls(1.0),
		"tris_max": tris_max, "objects_max": objects_max, "emitters_max": emitters_max,
		"tex_mb_max": snappedf(tex_mb_max, 0.1), "vmem_mb_max": snappedf(vmem_mb_max, 0.1),
		"process_ms_p95": snappedf(Perf3D.pct(_proc, n, 0.95), 0.01), "script_ms_p95": snappedf(Perf3D.pct(_script, mini(_sn, CAP), 0.95), 0.01) if _sn > 0 else snappedf(Perf3D.pct(_proc, n, 0.95), 0.01),
		"script_ms_p50": snappedf(Perf3D.pct(_script, mini(_sn, CAP), 0.5), 0.01)}
	if watch != null:
		out["shader_compiles_play"] = watch.compiles_play()
		out["hitches"] = watch.hitches.size()
		out["hitch_max_ms"] = snappedf(watch.hitch_max_ms, 0.1)
		out["compile_method"] = watch.method
	return out
