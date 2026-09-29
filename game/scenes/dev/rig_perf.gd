## RigPerf — N characters on an empty stage for the per-character budget (TECH §9: ≤ 12 draw
## calls and ≤ 0.25 ms CPU per character; pre-gate row 16). Nothing else is drawn, so the
## frame's draw calls are the characters' alone.
##   tools/scripts/shot.sh res://scenes/dev/RigPerf.tscn out.png 600 <sb> -- --rig=bellows --clip=rx_sneeze_blast_a --perf-log
## User args:
##   --rig=<id>          rig (default _mannequin)
##   --clip=<clip>       one clip for every character: a name, `<rig>/<name>` or a res:// file
##   --clips=a,b         clips cycled per character (default: the rig's walk + take)
##   --n=<count>         characters (default 2)
##   --skin=<skin> --looks=K1,K2   skin / residue looks on every character
##   --speed=<px/s>      walk speed for stride clips (default 180)
##   --warmup=<frames>   frames ignored before sampling (default 60)
##   --perf-log          print the medians on exit (DevShot adds its own [perf] line)
##   --breakdown         also print µs per character per frame by section (RigPlayer.profiling)
## Every frame after the warm-up records the advance time (all characters' `advance()`, per
## character), the `_draw` time (RigPlayer.draw_us delta, per character) and the frame's
## draw calls. On exit it prints ONE line the pre-gate parses:
##   [rigperf] <rig> <clip> x<n>: median advance A ms + draw D ms = T ms per character (p95 P) | draw calls C per character | F frames
extends Node2D

const MAX_SAMPLES := 8192

var players: Array[RigPlayer] = []
var rig_id: String = "_mannequin"
var clip_label: String = ""
var warmup: int = 60
var perf_log: bool = false

var _adv := PackedFloat32Array()
var _drw := PackedFloat32Array()
var _dc := PackedFloat32Array()
var _ns: int = 0
var _frames: int = 0
var _draw_us0: int = 0
var _printed: bool = false


## Parse RigPerf's user args (pure; tests call it).
static func parse_args(args: PackedStringArray) -> Dictionary:
	var o := {"rig": "_mannequin", "clip": "", "clips": PackedStringArray(), "n": 2, "skin": "",
		"looks": PackedStringArray(), "speed": 180.0, "warmup": 60, "perf_log": false, "breakdown": false}
	for a in args:
		if a.begins_with("--rig="):
			o["rig"] = a.substr(6)
		elif a.begins_with("--clip="):
			o["clip"] = a.substr(7)
		elif a.begins_with("--clips="):
			o["clips"] = a.substr(8).split(",", false)
		elif a.begins_with("--n="):
			o["n"] = clampi(int(a.substr(4)), 1, 64)
		elif a.begins_with("--skin="):
			o["skin"] = a.substr(7)
		elif a.begins_with("--looks="):
			o["looks"] = a.substr(8).split(",", false)
		elif a.begins_with("--speed="):
			o["speed"] = float(a.substr(8))
		elif a.begins_with("--warmup="):
			o["warmup"] = maxi(0, int(a.substr(9)))
		elif a == "--perf-log" or a.begins_with("--perf-log="):
			o["perf_log"] = true
		elif a == "--breakdown":
			o["breakdown"] = true
	return o


## Median of the first `n` values of `v` (0 when empty). Sorts a copy (called once, on exit).
static func median(v: PackedFloat32Array, n: int) -> float:
	if n <= 0:
		return 0.0
	var s := v.slice(0, n)
	s.sort()
	return s[n / 2] if n % 2 == 1 else 0.5 * (s[n / 2 - 1] + s[n / 2])


## The q-quantile (0..1) of the first `n` values.
static func quantile(v: PackedFloat32Array, n: int, q: float) -> float:
	if n <= 0:
		return 0.0
	var s := v.slice(0, n)
	s.sort()
	return s[clampi(int(ceil(q * float(n))) - 1, 0, n - 1)]


## Clip ids for rig `rig`: `clip` (a name, id or res:// file) or `clips`, else the rig's walk
## and take.
static func resolve_clips(rig: String, clip: String, clips: PackedStringArray) -> PackedStringArray:
	var src := PackedStringArray()
	if clip != "":
		src.append(clip)
	else:
		src = clips
	var out := PackedStringArray()
	for c in src:
		if c.ends_with(".json"):
			var cd := ClipLib.register_file(c)
			if cd != null:
				out.append(cd.id)
		else:
			out.append(c if c.contains("/") else rig + "/" + c)
	if out.is_empty():
		var have := ClipLib.list(rig)
		for pick in ["loco_walk", "loco_strut", "loco_run", "rx_take", "rx_sneeze_blast_a"]:
			if have.has(rig + "/" + pick):
				out.append(rig + "/" + pick)
		if out.is_empty() and not have.is_empty():
			out.append(have[0])
	return out


func _ready() -> void:
	var o := parse_args(OS.get_cmdline_user_args())
	rig_id = String(o["rig"])
	warmup = int(o["warmup"])
	perf_log = bool(o["perf_log"])
	var n := int(o["n"])
	RigPlayer.profiling = bool(o["breakdown"])
	var clips := resolve_clips(rig_id, String(o["clip"]), o["clips"])
	clip_label = ",".join(clips) if not clips.is_empty() else "(rest pose)"
	_adv.resize(MAX_SAMPLES)
	_drw.resize(MAX_SAMPLES)
	_dc.resize(MAX_SAMPLES)
	RenderingServer.set_default_clear_color(Color("#2A2342"))
	var vs := get_viewport_rect().size
	for i in n:
		var p := RigPlayer.new()
		p.manual = true
		p.position = Vector2(vs.x * float(i + 1) / float(n + 1), vs.y * 0.8)
		add_child(p)
		p.setup(rig_id, String(o["skin"]))
		for k in o["looks"]:
			p.set_residue(String(k), true)
		if not clips.is_empty():
			var cid := clips[i % clips.size()]
			var sd := i + 1
			# `speed` is a walk speed (px/s): only stride clips take it (on any other clip
			# RigPlayer reads it as a rate multiplier — 180× would replay the clip every frame).
			var cd := ClipLib.get_clip(cid)
			var opts := {"seed": sd}
			if cd != null and cd.stride_px > 0.0:
				opts["speed"] = float(o["speed"])
			p.play(cid, opts)
			var again := opts.duplicate()
			again["blend_in"] = 0
			p.clip_finished.connect(func(id: String) -> void: p.play(id, again))
		players.append(p)
	_draw_us0 = RigPlayer.draw_us


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	for p in players:
		p.advance(delta)
	var adv_us := Time.get_ticks_usec() - t0
	# _draw runs after _process: this frame's delta is the previous frame's draw.
	var drw_us := RigPlayer.draw_us - _draw_us0
	_draw_us0 = RigPlayer.draw_us
	_frames += 1
	if _frames == warmup + 1 and RigPlayer.profiling:
		RigPlayer.prof.fill(0)
	if _frames > warmup and _ns < MAX_SAMPLES:
		var n := float(maxi(1, players.size()))
		_adv[_ns] = float(adv_us) / 1000.0 / n
		_drw[_ns] = float(drw_us) / 1000.0 / n
		_dc[_ns] = float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)) / n
		_ns += 1
	if _frames % 120 == 0 and _ns > 0:
		print("[rigperf] %d characters: advance %.3f ms + _draw %.3f ms per character (running medians)" % [
			players.size(), median(_adv, _ns), median(_drw, _ns)])


## The summary line (medians over every sampled frame).
func summary() -> String:
	var a := median(_adv, _ns)
	var d := median(_drw, _ns)
	var tot := PackedFloat32Array()
	tot.resize(_ns)
	for i in _ns:
		tot[i] = _adv[i] + _drw[i]
	return "[rigperf] %s %s x%d: median advance %.3f ms + draw %.3f ms = %.3f ms per character (p95 %.3f) | draw calls %.1f per character | %d frames" % [
		rig_id, clip_label, players.size(), a, d, median(tot, _ns), quantile(tot, _ns, 0.95), median(_dc, _ns), _ns]


func _exit_tree() -> void:
	if perf_log and not _printed:
		_printed = true
		print(summary())
		if RigPlayer.profiling and _ns > 0:
			var parts := PackedStringArray()
			var per := float(_ns * maxi(1, players.size()))
			for i in RigPlayer.PROF_NAMES.size():
				parts.append("%s %.1f" % [RigPlayer.PROF_NAMES[i], float(RigPlayer.prof[i]) / per])
			print("[rigperf] breakdown µs per character per frame (means): " + ", ".join(parts))
