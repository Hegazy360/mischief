## E2E — the end-to-end driver (s2-night §4.6; QA's instrument). Spawned by DevShot on `--e2e`
## (debug only: `tools/` is never exported), it drives the REAL game from `Boot.tscn`:
##
##   godot … res://scenes/boot/Boot.tscn -- --e2e --e2e-scenario=<s> [--e2e-cmds=/abs.cmds.json]
##         [--e2e-report=/abs.json] [--perf-log] [--e2e-strict] [--e2e-hold-s=N]
## (tools/scripts/e2e.sh wraps it; it also works under capture.sh — while Movie Maker writes, the
## driver never quits the tree, so the capture decides the length.)
##
## Route scenarios (E2eScenarios.ROUTE_SCENARIOS): the solver route's commands (from `--e2e-cmds`, else
## dumped in-process by E2eRoute) are replayed through `NightScene.set_replay` → `SimDriver.push_cmd`
## at their logged ticks (the sim is deterministic, so the route plays exactly), and E2eProbe records,
## from process start AND from sim tick 0: curtain up, input live, first input, first player laugh,
## first prank; laughs; director `laugh_*` cues vs `cue_staged` + crowd sound; every sound the
## AudioDirector fired (doubles < 100 ms); draw calls per frame; TexStats pages built in PLAY;
## `WorldView.fallback_counts()`; script / engine errors. Flow scenarios (retry, pause_back,
## curtain_call, touch_smoke, tap_accuracy, cold_<ep>) are E2eFlows. Exit 1 when a threshold fails.
extends Node

const E2E_TAG := "[E2E]"

var scenario: String = "g0_sneeze"
var report_path: String = ""
var cmds_path: String = ""
var strict: bool = false
var hold_s: float = -1.0
## Stop a route after this many sim seconds (a perf sample; the report says `cut`).
var max_s: float = -1.0
var perf: bool = false
var probe: E2eProbe = null
var flows: E2eFlows = null
var night: Node = null
var report: Dictionary = {}
var failures := PackedStringArray()

var _movie: bool = false
var _t: float = 0.0
var _done: bool = false
var _cmds: Array = []
var _route_info: Dictionary = {}
var _end_t: float = -1.0
var _timeout_s: float = 600.0
var _logger: E2eLogger = null
## Clip coverage (r3d-integrate brief §3.2): every clip the two CharacterView3Ds (base + overlay) and the curtain
## call's bows played, sampled every frame of route AND flow runs; the report's `clips_played` (merged with the
## probe's PLAY-phase list).
var _clips_cov := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--e2e-scenario="):
			scenario = a.substr(15)
		elif a.begins_with("--e2e-report="):
			report_path = a.substr(13)
		elif a.begins_with("--report="):
			report_path = a.substr(9)
		elif a.begins_with("--e2e-cmds="):
			cmds_path = a.substr(11)
		elif a == "--e2e-strict":
			strict = true
		elif a.begins_with("--e2e-hold-s="):
			hold_s = float(a.substr(13))
		elif a.begins_with("--e2e-max-s="):
			max_s = float(a.substr(12))
		elif a == "--perf-log" or a.begins_with("--perf-log="):
			perf = true
	_movie = Engine.get_write_movie_path() != ""
	_isolate_user_data()
	_logger = E2eLogger.new()
	OS.add_logger(_logger)
	var ep := E2eScenarios.episode_of(scenario)
	if ep == "":
		_fail_now("unknown scenario '%s'" % scenario)
		return
	BootRouting.override_start = ep
	report.merge({"scenario": scenario, "episode": ep, "strict": strict, "movie": _movie}, true)
	if E2eScenarios.is_route(scenario):
		_prepare_route()
	else:
		flows = E2eFlows.new()
		flows.name = "Flows"
		add_child(flows)
	get_tree().node_added.connect(_on_node_added)
	print("%s scenario=%s episode=%s" % [E2E_TAG, scenario, ep])


## Hook every NightScene as it enters the tree (its `ready` runs before its first frame, so tick 0
## and the curtain rise are never missed).
func _on_node_added(n: Node) -> void:
	if n.is_in_group("night_scene") and n != night:
		n.ready.connect(func() -> void:
			night = n
			_on_night(n), CONNECT_ONE_SHOT)


## Keep the e2e run's save / device log / command log out of the shared user:// files (every sandbox
## of this project shares one user data dir): a fresh per-process folder.
func _isolate_user_data() -> void:
	var dir := "user://e2e/%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	DeviceLog.path = dir + "/device_log.json"
	CmdLog.path = dir + "/last_session.json"
	var sv := get_node_or_null("/root/Save")
	if sv != null:
		sv.set("path", dir + "/save.json")
		if sv.has_method("load_save"):
			sv.call("load_save")
	report["user_dir"] = ProjectSettings.globalize_path(dir)


func _prepare_route() -> void:
	var rt := E2eScenarios.route_of(scenario)
	if cmds_path != "":
		_cmds = E2eRoute.read_file(cmds_path)
		_route_info = {"source": cmds_path, "ok": not _cmds.is_empty()}
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(cmds_path)) == OK and j.data is Dictionary:
			_route_info["ticks"] = int((j.data as Dictionary).get("ticks", 0))
			_route_info["hash"] = int((j.data as Dictionary).get("hash", 0))
	else:
		var t0 := Time.get_ticks_msec()
		var d := E2eRoute.dump(String(rt[0]), String(rt[1]))
		_cmds = d.get("cmds", [])
		_route_info = {"source": "E2eRoute.dump", "ok": bool(d.get("ok", false)), "ticks": int(d.get("ticks", 0)),
			"end_reason": String(d.get("end_reason", "")), "error": String(d.get("error", "")), "dump_ms": Time.get_ticks_msec() - t0,
			"hash": int(d.get("hash", 0))}
		if String(d.get("error", "")) != "":
			if E2eScenarios.OPTIONAL.has(scenario):
				report["skipped"] = String(d["error"])
				print("%s SKIP %s: %s" % [E2E_TAG, scenario, d["error"]])
				_finish()
				return
			_fail_now(String(d["error"]))
			return
	report["route"] = _route_info
	var last := int(_cmds[_cmds.size() - 1][0]) if not _cmds.is_empty() else 0
	_timeout_s = maxf(60.0, float(maxi(last, int(_route_info.get("ticks", 0)))) / 60.0 + 30.0)
	probe = E2eProbe.new()
	probe.name = "Probe"
	probe.perf = true
	probe.hash_tick = int(_route_info.get("ticks", 0))
	add_child(probe)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_sample_cov()
	if probe != null:
		_route_tick()
	elif flows != null and flows.finished:
		report["flow"] = flows.result
		for f in flows.failures:
			failures.append(f)
		_finish()
		return
	if _t > _timeout_s + (10.0 if flows == null else 120.0):
		failures.append("timeout after %.0f s (phase %s)" % [_t, night.call("phase_name") if night != null else "no NightScene"])
		_finish()


func _on_night(n: Node) -> void:
	# A headless run has no 20:9 window (its viewport is square): project as the phone does, so the on-screen tests,
	# the Bellows window share and the visibility rows read as on a rendered run.
	if DisplayServer.get_name() == "headless":
		var c: Variant = n.get("cam")
		if c is Object and (c as Object).get("logical_size_override") != null:
			(c as Object).set("logical_size_override", Vector2(2400, 1080))
	if probe != null:
		if probe.night == null:
			n.call("set_replay", _cmds)
			probe.attach(n)
	elif flows != null and flows.scenario == "":
		flows.start(scenario, n, self)


func _route_tick() -> void:
	if night == null:
		return
	# scenario routes (caught, chase, meltdown, face to face) stop after their beat, not at a curtain:
	# done when the replay reaches the solver run's last tick
	var end_tick := int(_route_info.get("ticks", 0))
	if E2eScenarios.OPTIONAL.has(scenario) and end_tick > 0 and not probe.ended:
		var w0: Variant = night.get("world")
		if w0 is Object and int((w0 as Object).get("tick")) >= end_tick:
			probe.ended = true
			probe.end_reason = "route_end"
			probe.end_tick = end_tick
	if max_s > 0.0 and not probe.ended:
		var w: Variant = night.get("world")
		if w is Object and float(int((w as Object).get("tick"))) / 60.0 >= max_s:
			report["cut_at_s"] = max_s
			probe.ended = true
			probe.end_reason = "cut"
			_finish()
			return
	if probe.ended and _end_t < 0.0:
		_end_t = _t
	var hold := hold_s if hold_s >= 0.0 else (3.0 if scenario == "g0_sneeze" else 1.5)
	if _end_t >= 0.0 and _t - _end_t >= hold:
		_finish()


## Evaluate the scenario's thresholds on the probe's report.
static func check(s: String, rep: Dictionary, p_strict: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var t := E2eScenarios.thresholds(s)
	if t.has("ends_with") and String(rep.get("end_reason", "")) != String(t["ends_with"]) and not rep.has("cut_at_s"):
		out.append("ended with '%s', expected '%s'" % [rep.get("end_reason", ""), t["ends_with"]])
	if int(rep.get("tick0_frame_error", 99)) > int(t.get("tick0_frames_max", 1)):
		out.append("tick 0 is %d frames off the curtain-rise frame" % int(rep.get("tick0_frame_error", 99)))
	if int(rep.get("events_before_rise", 0)) > 0:
		out.append("%d sim events before the curtain rose" % int(rep["events_before_rise"]))
	for pair in [["input_live_s_max", "input_live_s"], ["first_laugh_s_max", "first_player_laugh_s"],
			["first_prank_s_max", "first_prank_s"]]:
		if t.has(pair[0]):
			var v := float(rep.get(pair[1], -1.0))
			# input goes live on the first frame at/after half up: allow that one frame of quantisation
			var q := float(rep.get("input_live_dt", 0.0)) if pair[1] == "input_live_s" else 0.0
			if v < 0.0 or v - q > float(t[pair[0]]) + 0.0005:
				out.append("%s = %.2f s > %.2f s" % [pair[1], v, float(t[pair[0]])])
	if t.has("laughs_by_60_min") and int(rep.get("laughs_by_60", 0)) < int(t["laughs_by_60_min"]):
		out.append("%d laughs by 60 s launch-relative < %d" % [int(rep.get("laughs_by_60", 0)), int(t["laughs_by_60_min"])])
	# R11: frame-quantised timings compare against max(threshold, one measured frame) (the report carries the frame)
	var frame_s := float(rep.get("frame_ms_p95", 0.0)) / 1000.0
	if t.has("cue_crowd_s_max"):
		for c in rep.get("laugh_cues", []):
			var d: Dictionary = c
			if not bool(d.get("staged", false)) or not E2eScenarios.within_quantised(float(d.get("crowd_s", 99.0)),
					float(t["cue_crowd_s_max"]), frame_s):
				out.append("laugh cue %s: staged %s, crowd after %.2f s (frame %.0f ms)" % [d.get("id", "?"),
					str(d.get("staged", false)), float(d.get("crowd_s", 99.0)), frame_s * 1000.0])
	if t.has("draw_p95_max") and float(rep.get("draw_p95", 0)) > float(t["draw_p95_max"]):
		out.append("draw calls p95 %.0f > %d" % [float(rep["draw_p95"]), int(t["draw_p95_max"])])
	if t.has("draw_max") and float(rep.get("draw_max", 0)) > float(t["draw_max"]):
		out.append("draw calls max %.0f > %d" % [float(rep["draw_max"]), int(t["draw_max"])])
	if t.has("tex_mb_peak_max") and float(rep.get("tex_mb_peak", 0.0)) > float(t["tex_mb_peak_max"]):
		out.append("texture memory peak %.1f MB > %d MB" % [float(rep["tex_mb_peak"]), int(t["tex_mb_peak_max"])])
	if t.has("pages_in_play_max") and int(rep.get("pages_built_in_play", 0)) > int(t["pages_in_play_max"]):
		out.append("%d texture pages built during PLAY" % int(rep["pages_built_in_play"]))
	if int((rep.get("doubles", []) as Array).size()) > int(t.get("doubles_max", 0)):
		out.append("%d sound ids fired twice within 100 ms: %s" % [(rep["doubles"] as Array).size(),
			str((rep["doubles"] as Array).slice(0, 5))])
	var want_hash := int((rep.get("route", {}) as Dictionary).get("hash", 0)) if rep.get("route") is Dictionary else 0
	if want_hash != 0 and int(rep.get("replay_hash", 0)) != 0 and int(rep["replay_hash"]) != want_hash:
		out.append("the replay diverged from the solver run (state hash %d ≠ %d at tick %d)" % [int(rep["replay_hash"]),
			want_hash, int((rep["route"] as Dictionary).get("ticks", 0))])
	if int(rep.get("script_errors", 0)) > int(t.get("errors_max", 0)):
		out.append("%d script errors" % int(rep["script_errors"]))
	if t.has("shader_compiles_play_max") and rep.get("perf3d") is Dictionary:
		var sc := int((rep["perf3d"] as Dictionary).get("shader_compiles_play", 0))
		if sc > int(t["shader_compiles_play_max"]):
			out.append("%d shaders compiled during PLAY: %s" % [sc, str(((rep["perf3d"] as Dictionary).get("compile_detail", {})
				as Dictionary).get("first_use", []).slice(0, 4))])
	if p_strict and is_route_strict(s):
		# R3D (r3d-integrate §3.2): C8 on every tick of the Gate-0 / Prologue replays, the sneeze staged on its accent
		var c8: Dictionary = rep.get("c8", {}) if rep.get("c8") is Dictionary else {}
		if int(c8.get("violations", 0)) > 0:
			out.append("C8: %d of %d ticks (unseen %d, on screen + window %d), first %s" % [int(c8["violations"]),
				int(c8.get("ticks", 0)), int(c8.get("unseen", 0)), int(c8.get("on_screen_and_window", 0)), str(c8.get("first", []))])
		var sn: Dictionary = rep.get("sneeze", {}) if rep.get("sneeze") is Dictionary else {}
		if s == "g0_sneeze" or not sn.is_empty():
			for f in E2eScenarios.sneeze_failures(sn, float(rep.get("frame_ms_p95", 0.0))):
				out.append(f)
	if p_strict and t.has("fallbacks_max"):
		var fb: Dictionary = rep.get("fallbacks", {})
		var n := int(fb.get("clip_fallbacks", 0)) + int(fb.get("puppets", 0)) + int(fb.get("greybox_props", 0))
		if n > int(t["fallbacks_max"]):
			out.append("%d view fallbacks (%d clip, %d puppets, %d greybox)" % [n, int(fb.get("clip_fallbacks", 0)),
				int(fb.get("puppets", 0)), int(fb.get("greybox_props", 0))])
	return out


## A route scenario of the strict episodes (Gate 0 and the Prologue, R9).
static func is_route_strict(s: String) -> bool:
	return E2eScenarios.is_route(s) and E2eScenarios.STRICT_EPISODES.has(E2eScenarios.episode_of(s))


func _fail_now(msg: String) -> void:
	failures.append(msg)
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if probe != null:
		report.merge(probe.summary(), true)
		for f in check(scenario, report, strict):
			failures.append(f)
	var cov: Array = report.get("clips_played", [])
	for c in _clips_cov:
		if not cov.has(c):
			cov.append(c)
	cov.sort()
	report["clips_played"] = cov
	var errs := _logger.take()
	report["script_errors"] = int(report.get("script_errors", 0)) + int(errs[0])
	report["engine_errors"] = int(errs[1])
	report["error_messages"] = errs[2]
	if int(errs[0]) > 0 and not failures.has("script errors"):
		failures.append("%d script errors: %s" % [int(errs[0]), str((errs[2] as Array).slice(0, 3))])
	report["failures"] = Array(failures)
	report["ok"] = failures.is_empty()
	if report_path != "":
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "  "))
			f.close()
	_print_summary()
	if _movie:
		return
	get_tree().quit(0 if failures.is_empty() else 1)


func _print_summary() -> void:
	var keys := ["night_build_ms", "warm_ms", "curtain_up_ms", "sim_start_ms", "input_live_s", "first_input_s", "first_player_laugh_s", "first_prank_s",
		"first_player_laugh_ms", "first_prank_ms", "laughs", "laughs_by_60", "end_reason", "end_tick", "draw_p95", "draw_max",
		"tex_mb_peak", "pages_built_in_play", "retry_ms"]
	var parts := PackedStringArray()
	for k in keys:
		if report.has(k):
			parts.append("%s=%s" % [k, str(report[k])])
	print("%s %s %s" % [E2E_TAG, scenario, " ".join(parts)])
	if report.has("fallbacks"):
		print("%s fallbacks %s" % [E2E_TAG, JSON.stringify(report["fallbacks"])])
	if report.has("perf3d"):
		var p3: Dictionary = report["perf3d"]
		print("%s perf3d view=%s frame_ms p50 %s p95 %s | draw p95 %s max %s | tris %s | emitters %s | tex %s MB | shader_compiles_play %s | hitches %s | script p95 %s ms (view + HUD %s, sim %s)" % [
			E2E_TAG, report.get("view", "?"), report.get("frame_ms_p50"), report.get("frame_ms_p95"), p3.get("draw_calls_p95"),
			p3.get("draw_calls_max"), p3.get("tris_max"), p3.get("emitters_max"), p3.get("tex_mb_max"),
			p3.get("shader_compiles_play"), p3.get("hitches"), p3.get("script_ms_p95"), p3.get("view_ms_p95"), p3.get("sim_ms_p95")])
	if report.has("pip_on_share"):
		print("%s window pip_on_share %.3f pip_longest_s %.1f windows %d | overlays max %s loud %s | hud samples %d" % [E2E_TAG,
			float(report["pip_on_share"]), float(report.get("pip_longest_s", 0.0)), (report.get("pip_windows", []) as Array).size(),
			(report.get("overlays", {}) as Dictionary).get("max"), (report.get("overlays", {}) as Dictionary).get("loud_max"),
			(report.get("hud_pieces", []) as Array).size()])
	if report.has("flow"):
		print("%s flow %s" % [E2E_TAG, JSON.stringify(report["flow"])])
	for f in failures:
		print("%s   FAIL: %s" % [E2E_TAG, f])
	print("%s %s %s" % [E2E_TAG, "PASS" if failures.is_empty() else "FAIL", scenario])


## One frame of the clip coverage (see `_clips_cov`).
func _sample_cov() -> void:
	if night == null or not is_instance_valid(night):
		return
	var wv: Variant = night.get("world_view")
	if wv is Object:
		for who in ["hush_view", "bellows_view"]:
			var cv: Variant = (wv as Object).get(who)
			if cv is Object and (cv as Object).has_method("current_clip"):
				_cov_add(String((cv as Object).call("current_clip")))
				if (cv as Object).has_method("overlay_clip"):
					_cov_add(String((cv as Object).call("overlay_clip")))
	var cc: Variant = night.get("curtain_call")
	var bw: Variant = (cc as Object).get("bows") if cc is Object and is_instance_valid(cc) else null
	if bw is Object and (bw as Object).has_method("current_clip"):
		_cov_add(String((bw as Object).call("current_clip", "hush")))
		_cov_add(String((bw as Object).call("current_clip", "bellows")))


func _cov_add(c: String) -> void:
	if c != "" and not _clips_cov.has(c):
		_clips_cov[c] = true
