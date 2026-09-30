## DeviceLog — the owner's phone log for the Fun Gate (GDD §10.4 checks #1, #5, #7; s2-night §4.5).
##
## A static data class hosted by the `DevShot` autoload (no new autoload, ruling L7): DevShot calls
## `begin_session()` at startup, `frame(dt)` every frame and `flush()` on pause / focus-out / quit;
## NightScene and Boot call `mark()`, `laugh()`, `catch()` and `set_retry_ms()`. Active only when
## `OS.is_debug_build() or OS.has_feature("mnd_devlog")` (the profile APK, ruling L17); inert
## otherwise (every call returns at once).
##
## Written to `user://device_log.json` = `{"version": 1, "sessions": [≤ 5, newest last]}`. A session:
## `{id, build: "debug"|"profile", model, os, gpu, ram_mb, clock: "proc"|"engine",
##   process_start_to_boot_ms, boot_ms, curtain_up_ms, sim_start_ms, first_input_ms, first_squeak_ms,
##   first_player_laugh_ms, first_prank_ms, retry_ms: [..], laughs: [{ms, kind, tier}],
##   catches: [{ms, spot_fill_s, cause}], perf: [{t_s, fps_p50, fps_p95, frame_ms_p95, draw_calls_p95, tex_mb}],
##   tex_mb_peak, values: {night_build_ms, warm_ms, night_view, tex_mb_by_kind: {room, house, rig, look, …},
##   "perf3d:<episode>": {frames, frame_ms_p50/p95/max, draw_calls_p95/max, tris_max, emitters_max, tex_mb_max,
##   vmem_mb_max, shader_compiles_play, hitches, hitch_max_ms, compile_method}},
##   shader_first_use: [{ms, key, kind, tick}] (≤ 50; must stay empty), hitches: [{ms, frame_ms, median_ms, tick}]
##   (≤ 50), hitch_count, marks: {name: ms}}` — every time in ms from **process start**: on Android (and Linux) from
## `/proc/self/stat` starttime vs `/proc/uptime`, so the activity start and splash the engine never
## sees are counted; elsewhere from engine start (`clock: "engine"`). −1 = not reached.
class_name DeviceLog
extends RefCounted

const PATH := "user://device_log.json"
const MAX_SESSIONS := 5
const WINDOW_S := 10.0
const WINDOW_FRAMES := 1200
## Milestones recorded once per session (the first time they happen).
const MILESTONES: PackedStringArray = ["boot", "first_frame", "curtain_up", "sim_start", "first_input", "first_squeak",
	"first_player_laugh", "first_prank"]

static var enabled_override: int = -1          ## tests: 1 on, 0 off, −1 = build rule
static var path: String = PATH
static var _started: bool = false
static var _session: Dictionary = {}
static var _offset_ms: int = 0
static var _fps := PackedFloat32Array()
static var _ms := PackedFloat32Array()
static var _dc := PackedFloat32Array()
static var _n: int = 0
static var _win_t: float = 0.0
static var _total_t: float = 0.0
static var _dirty: bool = false


## True when the log records (debug builds and the `mnd_devlog` profile APK).
static func active() -> bool:
	if enabled_override >= 0:
		return enabled_override == 1
	return OS.is_debug_build() or OS.has_feature("mnd_devlog")


## Start a session (DevShot's _ready). Idempotent.
static func begin_session() -> void:
	if not active() or _started:
		return
	_started = true
	var age := process_age_ms()
	var eng := Time.get_ticks_msec()
	_offset_ms = maxi(0, age - eng) if age >= 0 else 0
	_session = {
		"id": int(Time.get_unix_time_from_system()),
		"build": "debug" if OS.is_debug_build() else "profile",
		"model": OS.get_model_name(),
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"gpu": RenderingServer.get_video_adapter_name(),
		"ram_mb": int(OS.get_memory_info().get("physical", 0) / 1048576),
		"clock": "proc" if age >= 0 else "engine",
		"process_start_to_boot_ms": -1,
		"retry_ms": [],
		"laughs": [],
		"catches": [],
		"perf": [],
		"marks": {},
	}
	for m in MILESTONES:
		_session["%s_ms" % m] = -1
	_fps.resize(WINDOW_FRAMES)
	_ms.resize(WINDOW_FRAMES)
	_dc.resize(WINDOW_FRAMES)
	_n = 0
	_win_t = 0.0
	_total_t = 0.0
	_dirty = true


## Forget everything (tests).
static func reset_for_tests() -> void:
	_started = false
	_session = {}
	_offset_ms = 0
	_n = 0
	_dirty = false


## Milliseconds since process start (engine ms + the /proc offset).
static func now_ms() -> int:
	return Time.get_ticks_msec() + _offset_ms


static var _proc_offset: int = -1

## Milliseconds since process start whether or not the log records (Boot's launch clock): the
## /proc offset is read once (Android / Linux), else engine ms.
static func process_ms() -> int:
	if _proc_offset < 0:
		var age := process_age_ms()
		_proc_offset = maxi(0, age - Time.get_ticks_msec()) if age >= 0 else 0
	return Time.get_ticks_msec() + _proc_offset


## Record a milestone: the first time for MILESTONES (`<name>_ms`), else in `marks` (latest).
static func mark(name: String) -> void:
	if not _started:
		return
	var key := "%s_ms" % name
	if MILESTONES.has(name):
		if int(_session.get(key, -1)) < 0:
			_session[key] = now_ms()
			if name == "boot":
				_session["process_start_to_boot_ms"] = now_ms()
			_dirty = true
	else:
		(_session["marks"] as Dictionary)[name] = now_ms()
		_dirty = true


## Record a measured value (e.g. `night_build_ms`, `warm_ms`) in the session's `values` (latest wins).
static func note(key: String, value: Variant) -> void:
	if not _started:
		return
	if not _session.has("values"):
		_session["values"] = {}
	(_session["values"] as Dictionary)[key] = value
	_dirty = true


## Record a laugh (a sim laugh event); returns its index (for `set_laugh_tier`), −1 when inactive.
static func laugh(kind: String, tier: int) -> int:
	if not _started:
		return -1
	var list: Array = _session["laughs"]
	list.append({"ms": now_ms(), "kind": kind, "tier": tier})
	_dirty = true
	return list.size() - 1


## The crowd tier that actually played for laugh `index`.
static func set_laugh_tier(index: int, tier: int) -> void:
	if not _started:
		return
	var list: Array = _session["laughs"]
	if index >= 0 and index < list.size():
		(list[index] as Dictionary)["tier"] = tier


## Record a catch with the "?" fill time that preceded it (owner check #5).
static func catch(spot_fill_s: float, cause: String) -> void:
	if not _started:
		return
	(_session["catches"] as Array).append({"ms": now_ms(), "spot_fill_s": snappedf(spot_fill_s, 0.01), "cause": cause})
	_dirty = true


## A shader first used after the curtain rose (it compiled during play; ShaderWatch).
static func shader_first_use(key: String, kind: String, tick: int) -> void:
	if not _started:
		return
	if not _session.has("shader_first_use"):
		_session["shader_first_use"] = []
	var l: Array = _session["shader_first_use"]
	if l.size() < 50:
		l.append({"ms": now_ms(), "key": key, "kind": kind, "tick": tick})
	_dirty = true


## A PLAY frame over the hitch limit (ShaderWatch: > max(50 ms, 2.5 × the median frame)).
static func hitch(frame_ms: float, median_ms: float, tick: int) -> void:
	if not _started:
		return
	_session["hitch_count"] = int(_session.get("hitch_count", 0)) + 1
	if not _session.has("hitches"):
		_session["hitches"] = []
	var l: Array = _session["hitches"]
	if l.size() < 50:
		l.append({"ms": now_ms(), "frame_ms": snappedf(frame_ms, 0.1), "median_ms": snappedf(median_ms, 0.1), "tick": tick})
	_dirty = true


## Retry: tap → live control, in ms.
static func set_retry_ms(ms: int) -> void:
	if not _started:
		return
	(_session["retry_ms"] as Array).append(ms)
	_dirty = true


## Per frame (DevShot): fps / frame ms / draw calls, summarised every 10 s (p50/p95). No allocation
## except the summary row every 10 s.
static func frame(dt: float) -> void:
	if not _started or dt <= 0.0:
		return
	if _n < WINDOW_FRAMES:
		_fps[_n] = 1.0 / dt
		_ms[_n] = dt * 1000.0
		_dc[_n] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_n += 1
	_win_t += dt
	_total_t += dt
	if _win_t >= WINDOW_S:
		_summarise()


static func _summarise() -> void:
	if _n > 0:
		var f := _fps.slice(0, _n)
		var m := _ms.slice(0, _n)
		var d := _dc.slice(0, _n)
		f.sort()
		m.sort()
		d.sort()
		var tex_mb := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0)
		_session["tex_mb_peak"] = maxi(int(_session.get("tex_mb_peak", 0)), tex_mb)
		(_session["perf"] as Array).append({"t_s": snappedf(_total_t, 0.1), "frames": _n,
			"fps_p50": snappedf(percentile(f, 0.5), 0.1), "fps_p95": snappedf(percentile(f, 0.05), 0.1),
			"frame_ms_p95": snappedf(percentile(m, 0.95), 0.01), "draw_calls_p95": int(percentile(d, 0.95)),
			"tex_mb": tex_mb})
		if (_session["perf"] as Array).size() > 180:
			(_session["perf"] as Array).pop_front()
		_dirty = true
	_n = 0
	_win_t = 0.0


## p-th value of a sorted array (0..1).
static func percentile(sorted: PackedFloat32Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(floor(float(sorted.size() - 1) * p + 0.5)), 0, sorted.size() - 1)]


## The current session (a copy is not made; do not mutate).
static func session() -> Dictionary:
	return _session


## Write the log (last 5 sessions, this one replaced in place). Returns OK or an error.
static func flush() -> int:
	if not _started:
		return ERR_UNAVAILABLE
	var all: Array = []
	if FileAccess.file_exists(path):
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Dictionary:
			var prev: Variant = (j.data as Dictionary).get("sessions", [])
			if prev is Array:
				all = prev
	var sid := int(_session.get("id", 0))
	var out: Array = []
	for s in all:
		if s is Dictionary and int((s as Dictionary).get("id", -1)) != sid:
			out.append(s)
	out.append(_session)
	while out.size() > MAX_SESSIONS:
		out.pop_front()
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": 1, "sessions": out}, " "))
	f.close()
	var da := DirAccess.open(path.get_base_dir())
	var err := da.rename(path.get_file() + ".tmp", path.get_file()) if da != null else ERR_CANT_OPEN
	_dirty = false
	return err


## True when something changed since the last flush.
static func is_dirty() -> bool:
	return _dirty


## The log as pasteable text (the overlay's "Copy log"): the current session as JSON.
static func to_text() -> String:
	return JSON.stringify(_session, " ") if _started else "{}"


## Process age in ms from /proc (Android / Linux), or −1 when unavailable.
static func process_age_ms() -> int:
	var stat := _read_proc_line("/proc/self/stat")
	var up := _read_proc_line("/proc/uptime")
	if stat == "" or up == "":
		return -1
	return parse_proc_age_ms(stat, up, 100)


## procfs files report length 0, so read a line instead of get_file_as_string().
static func _read_proc_line(p: String) -> String:
	if OS.get_name() != "Android" and OS.get_name() != "Linux":
		return ""
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_line()
	f.close()
	return s


## Pure: process age from `/proc/self/stat` (field 22 `starttime`, clock ticks since boot; the
## command name in parentheses may contain spaces) and `/proc/uptime` (seconds since boot).
static func parse_proc_age_ms(stat: String, uptime: String, clk_tck: int = 100) -> int:
	var close := stat.rfind(")")
	if close < 0:
		return -1
	var rest := stat.substr(close + 1).strip_edges().split(" ", false)
	# rest[0] is field 3 (state) → starttime (field 22) is rest[19].
	if rest.size() < 20 or not rest[19].is_valid_int():
		return -1
	var start_ticks := rest[19].to_int()
	var parts := uptime.strip_edges().split(" ", false)
	if parts.is_empty() or not parts[0].is_valid_float():
		return -1
	var up_ms := parts[0].to_float() * 1000.0
	var start_ms := float(start_ticks) * 1000.0 / float(maxi(1, clk_tck))
	var age := int(round(up_ms - start_ms))
	return age if age >= 0 else -1
