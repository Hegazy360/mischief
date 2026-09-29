## Rig profiler — where a RigPlayer's per-frame CPU goes, stage by stage (s2-rig §4.3):
##   tools/scripts/sandbox.sh <sb> -s res://tools/anim/rig_profile.gd -- --rig=bellows --clip=<clip|res://file.json> [--n=2000]
## Prints µs per call of every advance stage (sample, blend copy, face, springs, limits, FK,
## smears) and of the draw preparation (sort, triangle-run fill), then the whole advance()
## and the real `_draw` over rendered frames. Headless: the draw numbers exclude the GPU.
extends SceneTree

var _p: RigPlayer
var _n: int = 8000
var _frames: int = 0
var _draw0: int = 0
var _drawn0: int = 0


func _initialize() -> void:
	var rig := "_mannequin"
	var clip := "_mannequin/loco_walk"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rig="):
			rig = a.substr(6)
		elif a.begins_with("--clip="):
			clip = a.substr(7)
		elif a.begins_with("--n="):
			_n = maxi(10, int(a.substr(4)))
	if clip.ends_with(".json"):
		var c := ClipLib.register_file(clip)
		clip = c.id if c != null else ""
	elif not clip.contains("/"):
		clip = rig + "/" + clip
	_p = RigPlayer.new()
	_p.manual = true
	_p.position = Vector2(600, 500)
	root.add_child(_p)
	_p.setup(rig)
	_p.play(clip, {"speed": 180.0})
	_p.clip_finished.connect(func(id: String) -> void: _p.play(id, {"blend_in": 0}))
	for i in 120:
		_p.advance(1.0 / 60.0)


## µs per call: the FASTEST of 20 blocks of n/20 calls, timed in on-CPU nanoseconds of this
## thread (Linux /proc/thread-self/schedstat) when available — a shared, loaded machine
## preempts us, and on-CPU time does not count the waits — else in wall time.
func _t(label: String, fn: Callable) -> void:
	var blocks := 4 if _cpu_clock else 20
	var per := maxi(1, _n / blocks)
	var best := INF
	for blk in blocks:
		var t0 := _now_ns()
		for i in per:
			fn.call()
		best = minf(best, float(_now_ns() - t0) / 1000.0 / float(per))
	print("  %-28s %7.2f µs" % [label, best])


## This thread's on-CPU ns (schedstat: updated per scheduler tick, so blocks are long), else
## wall ns.
static var _cpu_clock: bool = FileAccess.file_exists("/proc/thread-self/schedstat")


static func _now_ns() -> int:
	if _cpu_clock:
		var f := FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
		if f != null:
			return int(f.get_line().get_slice(" ", 0))
	return Time.get_ticks_usec() * 1000


func _stages() -> void:
	var p := _p
	print("[profile] %s %s: %d parts, %d items, %d runs" % [p.rig_id, p.current_clip(), p.rig.names.size(), p._items.size(), p._runs.size()])
	var fr := [0.0]
	_t("(callable overhead)", func() -> void: pass)
	_t("plan.sample", func() -> void:
		fr[0] = fmod(fr[0] + 0.7, float(p.plan().length))
		p._plan.sample(fr[0], p._a))
	_t("copy a→pose", func() -> void: RigSampler.copy(p._a, p._pose))
	_t("face.apply", func() -> void: p.face.apply(p._pose))
	_t("springs step+apply", func() -> void:
		p.springs.step(1.0 / 60.0)
		p.springs.apply(p._pose))
	_t("clamp_limits", func() -> void: RigSampler.clamp_limits(p.rig, p._pose))
	_t("solve (FK)", func() -> void: RigSampler.solve(p.rig, p._pose, p._xf))
	_t("springs.feed", func() -> void: p.springs.feed(p._xf, p.global_position, 1.0, 1.0 / 60.0))
	_t("smears", func() -> void: p._update_smears(1.0))
	_t("_update_pose (all)", func() -> void: p._update_pose(1.0 / 60.0))
	_t("advance (all)", func() -> void: p.advance(1.0 / 60.0))
	_t("_sort_items", func() -> void: p._sort_items())
	var cx := p._char_xf()
	_t("_fill_run (all runs)", func() -> void:
		for r in p._runs:
			p._fill_run(r, cx))
	_t("_sync_render (all)", func() -> void: p._sync_render())
	var rid := p._part_ci[p.rig.idx("head")] if p.rig.idx("head") >= 0 and p._part_ci[p.rig.idx("head")].is_valid() else RID()
	var xf := Transform2D(0.3, Vector2(10, 20))
	_t("30 × RS set_transform", func() -> void:
		for i in 30:
			RenderingServer.canvas_item_set_transform(rid, xf))
	_t("30 × _sync_part", func() -> void:
		for i in 30:
			p._sync_part(p.rig.idx("head")))


func _process(_delta: float) -> bool:
	if _p == null:
		return true
	_p.advance(1.0 / 60.0)
	_frames += 1
	if _frames == 1:
		_draw0 = RigPlayer.draw_us
		_drawn0 = RigPlayer.draw_count
	if _frames >= 301:
		var dn := maxi(1, RigPlayer.draw_count - _drawn0)
		_stages()
		print("  %-28s %7.2f µs (%d draws)" % ["_draw (real frames)", float(RigPlayer.draw_us - _draw0) / float(dn), dn])
		return true
	return false
