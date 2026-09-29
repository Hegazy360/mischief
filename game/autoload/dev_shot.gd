## DevShot — developer screenshot helper, and the host of the device log + debug overlay (ruling L7:
## no new autoloads in Stage 2).
##
## Screenshots (no-op unless requested on the command line):
##   godot --path game res://scenes/x.tscn -- --shot=/abs/out.png --frames=60
## Optional: `--shot-seq=/abs/dir --every=10 --count=6 [--seq-from=N]` captures a sequence (frame
## N + every·k); with `--shot` too, `--frames` is auto-extended to seq-from + every × count (a warning
## says so) — the old "the sequence captures nothing" trap.
## `--perf-log[=WARMUP]` (with --shot) samples the render stats of every frame after WARMUP
## (default 30) and prints them on quit (draw calls, objects, process time, live particles):
## `[perf] … draw calls avg A p95 P max M …`.
## `--e2e` spawns the end-to-end driver res://tools/e2e.gd (see tools/scripts/e2e.sh).
## `--overlay` shows the debug overlay from the start (shots).
## `--tex-report` (with --shot) prints the texture-memory breakdown on quit (TexStats.memory_report:
## `[tex] total … MB | room … | rig … | … | vp … | other …` + the biggest textures).
##
## Device log + overlay (active when `OS.is_debug_build() or OS.has_feature("mnd_devlog")` — the debug
## APK and the L17 profile APK; inert otherwise): `DeviceLog.begin_session()` at startup,
## `DeviceLog.frame(dt)` every frame, `DeviceLog.flush()` on WM close / application paused / focus out.
## A three-finger tap on any screen toggles the DebugOverlay (its own CanvasLayer 100); the tap is
## watched in `_input` without ever marking an event handled, so gameplay never loses a touch.
extends Node

const OVERLAY_LAYER := 100
const TAP_WINDOW_MS := 300
const TAP_MAX_MS := 600
const TAP_SLOP := 60.0

var _out := ""
var _frames := 60
var _seq_dir := ""
var _every := 10
var _count := 0
var _seq_from := 0
var _n := 0
var _taken := 0
var _perf := false
var _perf_from := 30
var _tex_report := false
var _dc := PackedFloat32Array()
var _proc_ms := PackedFloat32Array()
var _objects_max := 0
var _particles_max := 0
var _shooting := false
var _devlog := false
var _overlay_layer: CanvasLayer = null
var overlay: DebugOverlay = null
# three-finger tap tracking
var _touch_down := {}          # index → position at touch-down
var _touch_peak := 0
var _touch_first_ms := 0
var _touch_moved := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	for a in args:
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
		elif a.begins_with("--seq-from="):
			_seq_from = maxi(0, int(a.substr(11)))
		elif a == "--perf-log":
			_perf = true
		elif a.begins_with("--perf-log="):
			_perf = true
			_perf_from = maxi(0, int(a.substr(11)))
		elif a == "--tex-report":
			_tex_report = true
	var need := seq_frames_needed(_seq_from, _every, _count)
	if _out != "" and _seq_dir != "" and _frames < need:
		push_warning("DevShot: --frames=%d is shorter than the sequence (seq-from %d + every %d × count %d); extended to %d" % [
			_frames, _seq_from, _every, _count, need])
		_frames = need
	if args.has("--e2e"):
		_spawn_e2e.call_deferred()
	_shooting = _out != "" or _seq_dir != ""
	_devlog = DeviceLog.active()
	if _devlog:
		DeviceLog.begin_session()
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.layer = OVERLAY_LAYER
		_overlay_layer.name = "DebugOverlayLayer"
		add_child(_overlay_layer)
		overlay = DebugOverlay.new()
		_overlay_layer.add_child(overlay)
		if args.has("--overlay"):
			overlay.set_shown.call_deferred(true)
	set_process(_shooting or _devlog)
	set_process_input(_devlog)


## Frames a `--shot` run needs so a sequence completes: seq-from + every × count (+1).
static func seq_frames_needed(seq_from: int, every: int, count: int) -> int:
	if count <= 0:
		return 0
	return seq_from + maxi(1, every) * count + 1


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


func _process(d: float) -> void:
	if _devlog:
		DeviceLog.frame(d)
	if not _shooting:
		return
	_n += 1
	if _perf and _n > _perf_from:
		_sample()
	if _tex_report:
		_tex_watch()
	if _seq_dir != "" and _n >= _seq_from and (_n - _seq_from) % _every == 0 and _taken < _count:
		_save("%s/frame_%03d.png" % [_seq_dir, _taken])
		_taken += 1
		if _taken >= _count and _out == "":
			_quit()
			return
	if _out != "" and _n >= _frames:
		_save(_out)
		_quit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _devlog:
				DeviceLog.flush()


## Three-finger tap (all three down within TAP_WINDOW_MS, lifted within TAP_MAX_MS, no drag) toggles
## the overlay. Never consumes the event.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var now := Time.get_ticks_msec()
		if st.pressed:
			if _touch_down.is_empty():
				_touch_first_ms = now
				_touch_peak = 0
				_touch_moved = false
			_touch_down[st.index] = st.position
			_touch_peak = maxi(_touch_peak, _touch_down.size())
			if _touch_down.size() == 3 and now - _touch_first_ms > TAP_WINDOW_MS:
				_touch_moved = true
		else:
			_touch_down.erase(st.index)
			if _touch_down.is_empty():
				if _touch_peak == 3 and not _touch_moved and now - _touch_first_ms <= TAP_MAX_MS:
					toggle_overlay()
				_touch_peak = 0
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touch_down.has(sd.index) and (sd.position - (_touch_down[sd.index] as Vector2)).length() > TAP_SLOP:
			_touch_moved = true


## Show / hide the debug overlay (no-op when the log is inactive).
func toggle_overlay() -> void:
	if overlay != null:
		overlay.toggle()


## Print the perf summary (if sampled) and quit.
func _quit() -> void:
	_shooting = false
	set_process(_devlog)
	if _perf:
		print(perf_summary())
	if _tex_report:
		print(tex_report_text(get_tree().root))
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


var _tex_last_untracked := 0.0


## --tex-report: print every frame whose untracked texture memory (engine total − TexStats' tracked
## textures) grew by ≥ 1 MB, so an untracked allocation can be found by its frame.
func _tex_watch() -> void:
	const TS := "res://view/tex/tex_stats.gd"
	if not ResourceLoader.exists(TS):
		return
	var ts: Script = load(TS)
	var total := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var kinds: Dictionary = ts.call("live_bytes_by_kind")
	var tracked := 0.0
	for k in kinds:
		tracked += float(kinds[k]) / 1048576.0
	var un := total - tracked
	if un - _tex_last_untracked >= 1.0:
		var ns := get_tree().get_first_node_in_group("night_scene")
		print("[tex] frame %d: untracked +%.1f MB (now %.1f; total %.1f) phase %s" % [_n, un - _tex_last_untracked, un, total,
			String(ns.call("phase_name")) if ns != null and ns.has_method("phase_name") else "-"])
	_tex_last_untracked = un


## The texture-memory breakdown as printable lines (TexStats, loaded softly: the autoload never
## depends on the game's class graph). Empty when TexStats is missing.
static func tex_report_text(root: Node) -> String:
	const TS := "res://view/tex/tex_stats.gd"
	if not ResourceLoader.exists(TS):
		return ""
	var ts: Script = load(TS)
	var rep: Dictionary = ts.call("memory_report", root)
	var lines: PackedStringArray = ts.call("memory_lines", rep)
	var out := "[tex] total %.1f MB | %s" % [float(rep.get("total", 0.0)), " | ".join(lines)]
	for b in ts.call("biggest", 12):
		out += "\n[tex]   %.2f MB %s %s" % [float(b["mb"]), b["kind"], b["label"]]
	for v in rep.get("viewports", []):
		out += "\n[tex]   %.2f MB viewport %s %s" % [float(v["mb"]), v["name"], str(v["size"])]
	if ts.has_method("scan_untracked"):
		for u in ts.call("scan_untracked", root, 16):
			out += "\n[tex]   %.2f MB untracked %s %s" % [float(u["mb"]), u["label"], str(u["px"])]
	return out


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
