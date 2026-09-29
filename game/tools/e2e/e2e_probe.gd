## E2eProbe — watches one NightScene for the e2e driver (s2-night §4.6): the launch clock (from
## process start and from sim tick 0), laughs, the director's `laugh_*` cues vs `cue_staged` + the
## crowd sound, every AudioDirector call (→ doubled sound ids within 100 ms), draw calls per PLAY
## frame, TexStats pages built during PLAY, the view's fallbacks, and how the Night ended.
## Game time = the sum of frame deltas (with `--fixed-fps 60` exactly frames / 60).
class_name E2eProbe
extends Node

const DOUBLE_S := 0.1
const LAUNCH_OFFSET_S := 2.3

var night: Node = null
var perf: bool = true
var ended: bool = false
var end_reason: String = ""
var end_tick: int = -1
## Capture the world's state hash when the replay reaches this tick (the solver run's last tick): the
## replay played the route exactly when it equals the solver's final hash.
var hash_tick: int = -1
var hash_at_tick: int = 0

var _t: float = 0.0
var _frame: int = 0
var _rise_t: float = -1.0
var _rise_frame: int = -1
var _rise_ms: int = -1
var _tick_at_rise: int = -1
var _live_t: float = -1.0
var _first_cmd_tick: int = -1
var _first_laugh_tick: int = -1
var _first_laugh_ms: int = -1
var _first_prank_tick: int = -1
var _first_prank_ms: int = -1
var _laughs: Array = []
var _cues: Array = []                 # [{id, tick, t, staged_t, crowd_t}]
var _sounds: Array = []               # [t, method, id]
var _calls_i: int = 0
var _draws := PackedFloat32Array()
var _objects := PackedFloat32Array()
var _pages_at_play: int = -1
var _pages_now: int = -1
var _play_frames: int = 0
var _curtain_up_ms: int = -1
var _play_from_frame: int = -1


## Hook a NightScene (its driver, view and audio director).
func attach(n: Node) -> void:
	night = n
	n.connect("curtain_rose", _on_rose)
	n.connect("night_ended", _on_ended)
	var drv: Variant = n.get("driver")
	if drv is Node:
		(drv as Node).connect("ticked", _on_ticked)
	var ad: Variant = n.get("audio_dir")
	if ad is Object:
		(ad as Object).set("record", true)
	var wv: Variant = n.get("world_view")
	if wv is Object and (wv as Object).has_signal("cue_staged"):
		(wv as Object).connect("cue_staged", _on_cue_staged)
	var replay: Variant = n.get("replay")
	if replay is Object:
		var cm: Array = (replay as Object).get("cmds")
		if not cm.is_empty():
			_first_cmd_tick = int(cm[0][0])


func _process(delta: float) -> void:
	_t += delta
	_frame += 1
	if night == null or not is_instance_valid(night):
		return
	_read_sounds()
	if _rise_t >= 0.0 and _live_t < 0.0 and bool(night.get("_live_input")):
		_live_t = _t - _rise_t
	var ph := String(night.call("phase_name"))
	if ph == "PLAY" and not ended:
		_play_frames += 1
		if perf:
			_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_objects.append(Performance.get_monitor(Performance.OBJECT_COUNT))
		var pg := pages_built()
		if _pages_at_play < 0:
			_pages_at_play = pg
			_play_from_frame = Engine.get_process_frames()
		_pages_now = pg
	if _curtain_up_ms < 0 and ph == "PLAY":
		_curtain_up_ms = DeviceLog.process_ms()


func _on_rose() -> void:
	_rise_t = _t
	_rise_frame = int(night.get("frame_n"))
	_rise_ms = DeviceLog.process_ms()
	var w: Variant = night.get("world")
	_tick_at_rise = int((w as Object).get("tick")) if w is Object else -1


func _on_ended(reason: String) -> void:
	if ended:
		return
	ended = true
	end_reason = reason
	var w: Variant = night.get("world")
	end_tick = int((w as Object).get("tick")) if w is Object else -1


func _on_ticked(events: Array) -> void:
	if hash_tick > 0 and hash_at_tick == 0 and night != null:
		var w: Variant = night.get("world")
		if w is Object and int((w as Object).get("tick")) == hash_tick:
			hash_at_tick = int((w as Object).call("state_hash"))
	if ended:
		return
	for ev in events:
		var d: Dictionary = ev
		var e := String(d.get("e", ""))
		var tk := int(d.get("t", 0))
		if SimEvents.is_laugh(d):
			_laughs.append({"tick": tk, "e": e, "id": String(d.get("id", d.get("prank", d.get("bit", ""))))})
			if e != "director_cue" and _first_laugh_tick < 0:
				_first_laugh_tick = tk
				_first_laugh_ms = DeviceLog.process_ms()
		if e == "reaction_accent" and _first_prank_tick < 0:
			_first_prank_tick = tk
			_first_prank_ms = DeviceLog.process_ms()
		if e == "director_cue" and String(d.get("id", "")).begins_with("laugh_"):
			_cues.append({"id": String(d.get("id", "")), "tick": tk, "t": _t, "staged_t": -1.0, "crowd_t": -1.0})


func _on_cue_staged(id: String, _kind: String) -> void:
	for c in _cues:
		if String(c["id"]) == id and float(c["staged_t"]) < 0.0:
			c["staged_t"] = _t
			return


func _read_sounds() -> void:
	var ad: Variant = night.get("audio_dir")
	if not (ad is Object):
		return
	var calls: Array = (ad as Object).get("calls")
	while _calls_i < calls.size():
		var row: Array = calls[_calls_i]
		_calls_i += 1
		var m := String(row[0])
		if m == "play_sfx" or m == "play_voice" or m == "crowd" or m == "sting":
			var id := String(row[1]) if row.size() > 1 else ""
			_sounds.append([_t, m, id])
			if m == "crowd":
				for c in _cues:
					if float(c["crowd_t"]) < 0.0 and _t >= float(c["t"]) - 0.02:
						c["crowd_t"] = _t


## TexStats.pages_built() when the rig task's class exists (−1 otherwise).
static func pages_built() -> int:
	var v: Variant = tex_stats_call("pages_built")
	return int(v) if v != null else -1


## Call a static TexStats method softly (null when the class is missing).
static func tex_stats_call(method: String) -> Variant:
	for c in ProjectSettings.get_global_class_list():
		if String((c as Dictionary).get("class", "")) == "TexStats":
			var s: Variant = load(String((c as Dictionary)["path"]))
			if s is Script and (s as Script).has_method(method):
				return (s as Script).call(method)
	return null


## Sound ids fired twice within DOUBLE_S (game time): [{id, t, dt}].
static func doubles(sounds: Array) -> Array:
	var out: Array = []
	var last := {}
	for s in sounds:
		var key := "%s:%s" % [s[1], s[2]]
		if last.has(key) and float(s[0]) - float(last[key]) < DOUBLE_S:
			out.append({"id": String(s[2]), "method": String(s[1]), "t": snappedf(float(s[0]), 0.001),
				"dt": snappedf(float(s[0]) - float(last[key]), 0.001)})
		last[key] = float(s[0])
	return out


static func _pct(a: PackedFloat32Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(floor(float(s.size() - 1) * p + 0.5)), 0, s.size() - 1)]


## The probe's findings (merged into the e2e report).
func summary() -> Dictionary:
	var out := {}
	var fb: Variant = {}
	var wv: Variant = night.get("world_view") if night != null and is_instance_valid(night) else null
	if wv is Object and (wv as Object).has_method("fallback_counts"):
		fb = (wv as Object).call("fallback_counts")
	out["fallbacks"] = fb
	out["night_build_ms"] = int(night.get("build_ms")) if night != null and is_instance_valid(night) else -1
	var wr: Variant = night.get("warmer") if night != null and is_instance_valid(night) else null
	out["warm_ms"] = int((wr as Object).get("elapsed_ms")) if wr is Object else -1
	out["curtain_up_ms"] = _curtain_up_ms
	out["sim_start_ms"] = _rise_ms
	out["tick_at_rise"] = _tick_at_rise
	var ns_rise := int(night.get("rise_frame")) if night != null and is_instance_valid(night) else -1
	out["tick0_frame_error"] = absi(ns_rise - _rise_frame) if ns_rise >= 0 and _rise_frame >= 0 else 99
	out["events_before_rise"] = int(night.get("events_before_rise")) if night != null and is_instance_valid(night) else 0
	var live_s: Variant = night.get("input_live_s") if night != null and is_instance_valid(night) else null
	out["input_live_s"] = snappedf(float(live_s), 0.001) if live_s != null and float(live_s) >= 0.0 else snappedf(_live_t, 0.001)
	out["input_live_dt"] = snappedf(float(night.get("input_live_dt")), 0.001) if night != null and is_instance_valid(night) else 0.0
	out["input_live_probe_s"] = snappedf(_live_t, 0.001)
	out["first_input_s"] = snappedf(float(_first_cmd_tick) / 60.0, 0.001) if _first_cmd_tick >= 0 else -1.0
	out["first_player_laugh_s"] = snappedf(float(_first_laugh_tick) / 60.0, 0.001) if _first_laugh_tick >= 0 else -1.0
	out["first_player_laugh_ms"] = _first_laugh_ms
	out["first_prank_s"] = snappedf(float(_first_prank_tick) / 60.0, 0.001) if _first_prank_tick >= 0 else -1.0
	out["first_prank_ms"] = _first_prank_ms
	out["laughs"] = _laughs.size()
	var by60 := 0
	for l in _laughs:
		if float(int((l as Dictionary)["tick"])) / 60.0 + LAUNCH_OFFSET_S <= 60.0:
			by60 += 1
	out["laughs_by_60"] = by60
	out["laugh_list"] = _laughs
	var cues: Array = []
	for c in _cues:
		var d: Dictionary = c
		cues.append({"id": d["id"], "tick": d["tick"], "staged": float(d["staged_t"]) >= 0.0,
			"staged_s": snappedf(float(d["staged_t"]) - float(d["t"]), 0.001) if float(d["staged_t"]) >= 0.0 else -1.0,
			"crowd_s": snappedf(float(d["crowd_t"]) - float(d["t"]), 0.001) if float(d["crowd_t"]) >= 0.0 else 99.0})
	out["laugh_cues"] = cues
	out["sounds"] = _sounds.size()
	out["sound_ids"] = _sound_ids()
	out["doubles"] = doubles(_sounds)
	out["end_reason"] = end_reason
	out["replay_hash"] = hash_at_tick
	out["end_tick"] = end_tick
	out["play_frames"] = _play_frames
	out["draw_p50"] = _pct(_draws, 0.5)
	out["draw_p95"] = _pct(_draws, 0.95)
	out["draw_max"] = _pct(_draws, 1.0)
	out["objects_min"] = _pct(_objects, 0.0)
	out["objects_max"] = _pct(_objects, 1.0)
	out["pages_built_in_play"] = maxi(0, _pages_now - _pages_at_play) if _pages_at_play >= 0 else -1
	var recent: Variant = tex_stats_call("recent")
	var in_play: Array = []
	if recent is Array:
		for r in recent:
			if r is Dictionary and int((r as Dictionary).get("frame", -1)) >= _play_from_frame and _play_from_frame >= 0:
				in_play.append(r)
	out["pages_in_play_recent"] = in_play
	return out


func _sound_ids() -> Dictionary:
	var ids := {}
	for s in _sounds:
		var k := String(s[2])
		ids[k] = int(ids.get(k, 0)) + 1
	return ids
