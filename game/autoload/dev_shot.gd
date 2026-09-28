## DevShot — developer screenshot helper (no-op unless requested on the command line).
## Usage: godot --path game res://scenes/x.tscn -- --shot=/abs/out.png --frames=60
## Optional: --shot-seq=/abs/dir --every=10 --count=6 to capture a sequence.
## `--perf-log[=WARMUP]` (with --shot) samples the render stats of every frame after WARMUP
## (default 30) and prints them on quit (draw calls, objects, process time, live particles): `[perf] … draw calls avg A p95 P max M …`.
## `--e2e` spawns the end-to-end driver res://tools/e2e.gd (see tools/scripts/e2e.sh).
extends Node

var _out := ""
var _frames := 60
var _seq_dir := ""
var _every := 10
var _count := 0
var _n := 0
var _taken := 0
var _perf := false
var _perf_from := 30
var _dc := PackedFloat32Array()
var _proc_ms := PackedFloat32Array()
var _objects_max := 0
var _particles_max := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_out = a.substr(7)
		elif a.begins_with("--frames="):
			_frames = int(a.substr(9))
		elif a.begins_with("--shot-seq="):
			_seq_dir = a.substr(11)
		elif a.begins_with("--every="):
			_every = maxi(1, int(a.substr(8)))
		elif a.begins_with("--count="):
			_count = int(a.substr(8))
		elif a == "--perf-log":
			_perf = true
		elif a.begins_with("--perf-log="):
			_perf = true
			_perf_from = maxi(0, int(a.substr(11)))
	if OS.get_cmdline_user_args().has("--e2e"):
		_spawn_e2e.call_deferred()
	if _out == "" and _seq_dir == "":
		set_process(false)
	else:
		process_mode = Node.PROCESS_MODE_ALWAYS


## --e2e: the end-to-end driver (res://tools/e2e.gd — not exported, so a no-op in builds).
func _spawn_e2e() -> void:
	const E2E := "res://tools/e2e.gd"
	if not ResourceLoader.exists(E2E):
		push_warning("DevShot: --e2e given but %s is not in this build" % E2E)
		return
	var s := load(E2E) as GDScript
	if s == null or not s.can_instantiate():
		printerr("[E2E] FAIL: %s does not compile" % E2E)
		get_tree().quit(1)
		return
	var n: Node = s.new()
	n.name = "E2E"
	get_tree().root.add_child(n)


func _process(_d: float) -> void:
	_n += 1
	if _perf and _n > _perf_from:
		_sample()
	if _seq_dir != "" and _n % _every == 0 and _taken < _count:
		_save("%s/frame_%03d.png" % [_seq_dir, _taken])
		_taken += 1
		if _taken >= _count and _out == "":
			_quit()
			return
	if _out != "" and _n >= _frames:
		_save(_out)
		_quit()


## Print the perf summary (if sampled) and quit.
func _quit() -> void:
	set_process(false)
	if _perf:
		print(perf_summary())
	get_tree().quit()


func _sample() -> void:
	_dc.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_objects_max = maxi(_objects_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	if _n % 5 == 0:
		_particles_max = maxi(_particles_max, count_particles(get_tree().root))


## One line: the sampled frames' draw calls (avg / p95 / max), max objects, process time
## (avg / p95 ms) and the most live particles seen (CPU + GPU particle amounts emitting).
func perf_summary() -> String:
	if _dc.is_empty():
		return "[perf] no frames sampled"
	var dc := Array(_dc)
	var pt := Array(_proc_ms)
	dc.sort()
	pt.sort()
	var avg := func(a: Array) -> float:
		var t := 0.0
		for v in a:
			t += float(v)
		return t / float(maxi(1, a.size()))
	var p95 := func(a: Array) -> float: return float(a[mini(a.size() - 1, int(floor(float(a.size()) * 0.95)))])
	return "[perf] %d frames: draw calls avg %.1f p95 %.0f max %.0f | objects max %d | process ms avg %.2f p95 %.2f | particles max %d" % [
		dc.size(), avg.call(dc), p95.call(dc), float(dc.back()), _objects_max, avg.call(pt), p95.call(pt), _particles_max]


## Emitting particle amounts under `n` (CPUParticles2D / GPUParticles2D).
static func count_particles(n: Node) -> int:
	var total := 0
	if n is CPUParticles2D and (n as CPUParticles2D).emitting and (n as CPUParticles2D).is_visible_in_tree():
		total += (n as CPUParticles2D).amount
	elif n is GPUParticles2D and (n as GPUParticles2D).emitting and (n as GPUParticles2D).is_visible_in_tree():
		total += (n as GPUParticles2D).amount
	for c in n.get_children():
		total += count_particles(c)
	return total


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[DevShot] saved ", path)
