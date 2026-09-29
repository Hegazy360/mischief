## E2eFlows — the e2e driver's flow scenarios (s2-night §4.6), run as a coroutine on the live game:
## * `retry` — PLAY → Retry (the pause menu's) → live control again ≤ 1.5 s (NightScene.retry_done), and
##   the sim restarts from tick 0.
## * `pause_back` — a synthetic NOTIFICATION_APPLICATION_FOCUS_OUT (root.propagate_notification): the
##   pause menu opens, the tick stops, the device log flushes; FOCUS_IN → still paused; Back closes the
##   menu (never quits), play resumes.
## * `curtain_call` — N01 ended → the curtain call (first viewing ≤ 12.8 s unskipped, Next/Retry live
##   on frame 1) → Retry → ended again (repeat viewing ≤ 7.5 s) → Next Night ▶ → N02 → ended → Next ▶
##   → "To be continued…" → the Playbill; then Gate 0 → g0_done → Again ▶ ≤ 1.5 s.
## * `touch_smoke` — synthetic InputEventScreenTouch taps on a real hotspot rect, an action-button hold,
##   a Clarence tap → the commands, the ripple and the feedback in the same frame.
## * `tap_accuracy` — every hotspot on screen at zoom 1.0 and 0.5: 20 seeded taps jittered around its art
##   centre (±40 / ±20 px) → TapAssist must pick it ≥ 19/20 and never a neighbour; drags of 25–200 px in
##   8 directions never move Hush.
## * `cold_<episode>` — boots into that Night's cold open + loading card, then stops.
class_name E2eFlows
extends Node

var scenario: String = ""
var night: Node = null
var driver_node: Node = null
var finished: bool = false
var result: Dictionary = {}
var failures := PackedStringArray()
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta


## Begin the flow on the first NightScene.
func start(s: String, n: Node, host: Node) -> void:
	scenario = s
	night = n
	driver_node = host
	_run.call_deferred()


func _run() -> void:
	match scenario:
		"retry":
			await _flow_retry()
		"pause_back":
			await _flow_pause_back()
		"curtain_call":
			await _flow_curtain_call()
		"touch_smoke":
			await _flow_touch_smoke()
		"tap_accuracy":
			await _flow_tap_accuracy()
		_:
			if scenario.begins_with("cold_"):
				await _flow_cold()
			else:
				failures.append("unknown flow %s" % scenario)
	finished = true


# --- helpers -----------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	var t0 := _t
	while _t - t0 < s:
		await get_tree().process_frame


func _night() -> Node:
	var n := get_tree().get_first_node_in_group("night_scene")
	if n != null:
		night = n
	return night


## Wait until the current NightScene is in `phase` (a name) or `limit_s` passes. Returns true on success.
func _wait_phase(phase: String, limit_s: float = 20.0) -> bool:
	var t0 := _t
	while _t - t0 < limit_s:
		var n := _night()
		if n != null and is_instance_valid(n):
			_close_cards(n)
			if String(n.call("phase_name")) == phase:
				return true
		await get_tree().process_frame
	failures.append("phase %s not reached in %.0f s (at %s)" % [phase, limit_s,
		night.call("phase_name") if night != null and is_instance_valid(night) else "?"])
	return false


## Tap through any loading / Gate-0 card the flow meets (a player would).
func _close_cards(n: Node) -> void:
	var c: Variant = n.get("_card")
	if c is Object and is_instance_valid(c):
		if (c as Object).has_method("close") and (c as Object).get("age") != null and float((c as Object).get("age")) > 0.3:
			(c as Object).call("close")
		elif c is LoadingCard and (c as LoadingCard).age_ms() > 1100:
			(c as LoadingCard).close("start")


func _tick() -> int:
	var w: Variant = night.get("world") if night != null else null
	return int((w as Object).get("tick")) if w is Object else -1


# --- retry --------------------------------------------------------------------------------------

func _flow_retry() -> void:
	if not await _wait_phase("PLAY"):
		return
	await _secs(2.0)
	var before := _tick()
	var t0 := Time.get_ticks_msec()
	var got := [-1]
	night.connect("retry_done", func(ms: int) -> void: got[0] = ms, CONNECT_ONE_SHOT)
	night.call("retry")
	var lim := _t
	while got[0] < 0 and _t - lim < 5.0:
		await get_tree().process_frame
	var wall := Time.get_ticks_msec() - t0
	await _frames(10)
	result = {"retry_ms": got[0], "retry_wall_ms": wall, "tick_before": before, "tick_after": _tick()}
	if got[0] < 0 or got[0] > 1500:
		failures.append("retry took %d ms (> 1500)" % got[0])
	if _tick() >= before:
		failures.append("the sim did not restart from tick 0 (tick %d → %d)" % [before, _tick()])


# --- pause / back ---------------------------------------------------------------------------------

func _flow_pause_back() -> void:
	if not await _wait_phase("PLAY"):
		return
	await _secs(1.5)
	var log_path := DeviceLog.path
	var had := FileAccess.file_exists(log_path)
	var mtime := FileAccess.get_modified_time(log_path) if had else 0
	get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	var menu_open := night.get("_pause_menu") != null and is_instance_valid(night.get("_pause_menu"))
	var t0 := _tick()
	await _frames(30)
	var t1 := _tick()
	var flushed := FileAccess.file_exists(log_path) and (not had or FileAccess.get_modified_time(log_path) >= mtime)
	get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(20)
	var still := bool(night.call("is_paused")) and _tick() == t1
	# Back closes the menu (resume); Back again opens it; the game never quits.
	var r := ViewKit.autoload("Router")
	if r != null and r.has_method("handle_back_request"):
		r.call("handle_back_request")
	else:
		night.call("handle_back")
	await _frames(10)
	var resumed := not bool(night.call("is_paused"))
	await _frames(20)
	var ticking := _tick() > t1
	result = {"menu_open": menu_open, "tick_stopped": t0 == t1, "log_flushed": flushed, "still_paused_after_focus_in": still,
		"back_resumed": resumed, "ticking_after": ticking}
	for k in result:
		if not bool(result[k]):
			failures.append("pause_back: %s is false" % k)


# --- curtain call -----------------------------------------------------------------------------------

## Force the Night to end now (the flow tests the curtain call, not the route).
func _force_end(reason: String) -> void:
	night.call("_on_night_end", reason)


func _cc() -> Node:
	var c: Variant = night.get("curtain_call") if night != null and is_instance_valid(night) else null
	return c if c is Node and is_instance_valid(c) else null


func _measure_call(label: String, limit_s: float) -> Dictionary:
	var c := _cc()
	if c == null:
		failures.append("%s: no curtain call" % label)
		return {}
	await get_tree().process_frame
	var live := false
	var pn: Variant = c.get("proxy_next")
	var rs: Variant = c.get("results")
	if pn is UiButton and is_instance_valid(pn):
		live = not (pn as UiButton).disabled and (pn as UiButton).is_visible_in_tree()
	elif rs is ResultsScreen:
		live = (rs as ResultsScreen).next_button != null and not (rs as ResultsScreen).next_button.disabled
	var t0 := _t
	while not bool(c.get("done")) and _t - t0 < limit_s + 6.0:
		await get_tree().process_frame
	var len_s := snappedf(float(c.get("elapsed")), 0.01)
	var out := {"length_s": len_s, "next_live_frame1": live, "steps": c.get("step_times"), "done": bool(c.get("done"))}
	if not live:
		failures.append("%s: Next ▶ not live on the first frame" % label)
	if len_s > limit_s + 0.25:
		failures.append("%s: unskipped length %.2f s > %.1f s" % [label, len_s, limit_s])
	return out


func _flow_curtain_call() -> void:
	var out := {}
	if not await _wait_phase("PLAY"):
		return
	await _secs(0.5)
	_force_end("bow")
	await _frames(1)
	out["n01_first"] = await _measure_call("n01 first viewing", CurtainCall.total_s(CurtainCall.KIND_NIGHT, false))
	# Retry → play → end again: a repeat viewing
	var c := _cc()
	if c != null:
		c.call("press", "retry")
	if not await _wait_phase("PLAY", 5.0):
		result = out
		return
	await _secs(0.5)
	_force_end("bow")
	await _frames(1)
	out["n01_repeat"] = await _measure_call("n01 repeat viewing", CurtainCall.total_s(CurtainCall.KIND_NIGHT, true))
	# Next Night ▶ → N02
	c = _cc()
	if c != null:
		c.call("press", "next")
	var t0 := _t
	while _t - t0 < 15.0:
		var n := get_tree().get_first_node_in_group("night_scene")
		if n != null and n != night and is_instance_valid(n) and String(n.get("episode_id")) == "n02_something_fishy":
			night = n
			break
		await get_tree().process_frame
	out["next_to_n02"] = String(night.get("episode_id")) == "n02_something_fishy"
	if not bool(out["next_to_n02"]):
		failures.append("Next Night ▶ after N01 did not load N02")
		result = out
		return
	if not await _wait_phase("PLAY", 20.0):
		result = out
		return
	await _secs(0.5)
	_force_end("bow")
	await _secs(0.5)
	c = _cc()
	if c != null:
		c.call("press", "next")
	await _secs(0.3)
	var tbc := _find_class(get_tree().root, "ToBeContinued")
	out["to_be_continued"] = tbc != null
	t0 = _t
	var playbill := false
	while _t - t0 < 8.0:
		if get_tree().current_scene != null and get_tree().current_scene.get_script() != null and \
				String((get_tree().current_scene.get_script() as Script).get_global_name()) == "Playbill":
			playbill = true
			break
		await get_tree().process_frame
	out["playbill"] = playbill
	if not bool(out["to_be_continued"]):
		failures.append("N02 → Next ▶ showed no 'To be continued…' card")
	if not playbill:
		failures.append("'To be continued…' did not lead to the Playbill")
	# Gate 0 → Again ▶ ≤ 1.5 s
	var r := ViewKit.autoload("Router")
	if r != null:
		r.call("replace", "night", {"episode": "g0_sneeze", "from": "e2e"})
	t0 = _t
	while _t - t0 < 15.0:
		var n2 := get_tree().get_first_node_in_group("night_scene")
		if n2 != null and is_instance_valid(n2) and String(n2.get("episode_id")) == "g0_sneeze":
			night = n2
			break
		await get_tree().process_frame
	if await _wait_phase("PLAY", 20.0):
		await _secs(0.5)
		_force_end("g0_done")
		await _secs(1.0)
		var got := [-1]
		night.connect("retry_done", func(ms: int) -> void: got[0] = ms, CONNECT_ONE_SHOT)
		c = _cc()
		var gate0_live := c != null and c.get("results") is ResultsScreen
		if c != null:
			c.call("press", "again")
		t0 = _t
		while got[0] < 0 and _t - t0 < 5.0:
			await get_tree().process_frame
		out["g0_again_ms"] = got[0]
		out["g0_buttons_live"] = gate0_live
		if got[0] < 0 or got[0] > 1500:
			failures.append("g0 Again ▶ took %d ms" % got[0])
	result = out


static func _find_class(n: Node, cls: String) -> Node:
	var s: Variant = n.get_script()
	if s is Script and String((s as Script).get_global_name()) == cls:
		return n
	for ch in n.get_children():
		var f := _find_class(ch, cls)
		if f != null:
			return f
	return null


# --- touch --------------------------------------------------------------------------------------------

## Canvas (logical) px → window px: synthetic events enter where the OS's would.
func _win(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos


func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _win(pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(pos: Vector2, rel: Vector2, index: int = 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = _win(pos)
	ev.relative = get_viewport().get_final_transform().basis_xform(rel)
	Input.parse_input_event(ev)


func _flow_touch_smoke() -> void:
	if not await _wait_phase("PLAY", 30.0):
		return
	await _secs(1.0)
	var ni: Object = night.get("night_input")
	var cmds: Array = []
	ni.connect("command", func(c: Dictionary) -> void: cmds.append(c))
	var fb := [0]
	ni.connect("tap_feedback", func(_a: Vector2, _b: Vector2) -> void: fb[0] += 1)
	# 1. a tap on a real hotspot's screen rect
	var wv: Object = night.get("world_view")
	var rects: Array = wv.call("hotspot_rects_in_view")
	var vs := get_viewport().get_visible_rect().size
	# a hotspot well inside the screen (clear of the HUD's corners and edges)
	rects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absf((a["rect"] as Rect2).get_center().x - vs.x * 0.5) < absf((b["rect"] as Rect2).get_center().x - vs.x * 0.5))
	var tapped := ""
	for r in rects:
		var d: Dictionary = r
		var cy := (d.get("rect", Rect2()) as Rect2).get_center().y
		if String(d.get("kind", "")) in ["container", "rig_point", "hiding"] and cy > vs.y * 0.2 and cy < vs.y * 0.75:
			var sr: Rect2 = d.get("rect", Rect2())
			var p := sr.get_center()
			# down + up in the same frame: a crisp tap (≤ 300 ms) however slow the frame is
			_touch(p, true)
			_touch(p, false)
			tapped = String(d.get("id", ""))
			break
	await _frames(3)
	var go_ok := false
	for c in cmds:
		if String((c as Dictionary).get("c", "")) in ["go", "move", "pin"]:
			go_ok = true
	# 2. an action-button hold (touch on the action button's rect, 0.6 s)
	var hud: Object = night.get("hud")
	var tr: Dictionary = hud.call("target_rects")
	var act: Rect2 = tr.get("action", Rect2())
	var n_before := cmds.size()
	if act.size.x > 0.0:
		_touch(act.get_center(), true, 1)
		await _secs(0.6)
		_touch(act.get_center(), false, 1)
	await _frames(3)
	var action_ok := cmds.size() > n_before
	# 3. a Clarence tap
	var cl: Rect2 = tr.get("clarence", Rect2())
	n_before = cmds.size()
	if cl.size.x > 0.0:
		_touch(cl.get_center(), true, 2)
		await _frames(1)
		_touch(cl.get_center(), false, 2)
	await _frames(3)
	var squeak_ok := false
	for i in range(n_before, cmds.size()):
		if String((cmds[i] as Dictionary).get("c", "")) in ["squeak", "wheeze"]:
			squeak_ok = true
	var names := PackedStringArray()
	for c in cmds:
		names.append(String((c as Dictionary).get("c", "")))
	result = {"tapped": tapped, "tap_command": go_ok, "tap_feedback": fb[0], "action_command": action_ok,
		"clarence_command": squeak_ok, "commands": names}
	if not go_ok:
		failures.append("touch_smoke: a hotspot tap pushed no go/move/pin")
	if fb[0] < 1:
		failures.append("touch_smoke: no ripple/path feedback on the tap")
	if not action_ok:
		failures.append("touch_smoke: the action-button hold pushed no command")
	if not squeak_ok:
		failures.append("touch_smoke: the Clarence tap pushed no squeak")


func _flow_tap_accuracy() -> void:
	if not await _wait_phase("PLAY", 30.0):
		return
	await _secs(0.5)
	night.get("driver").call("set_paused", true)
	var cam: Object = night.get("cam")
	var table: Array = []
	var ni: Object = night.get("night_input")
	for zoom in [1.0, 0.5]:
		cam.call("pinch", zoom / float(cam.call("current_zoom")), Vector2(960, 540))
		await _frames(30)
		var rng := RandomNumberGenerator.new()
		rng.seed = 60606
		var cands: Array = ni.call("candidates")
		for c in cands:
			var d: Dictionary = c
			if String(d.get("kind", "")) == "floor" or not d.get("enabled", true):
				continue
			var wr: Rect2 = d.get("rect", Rect2())
			var centre := wr.get_center()
			var jitter := 40.0 / float(cam.call("current_zoom")) if zoom == 1.0 else 20.0 / float(cam.call("current_zoom"))
			var hits := 0
			var neighbour := 0
			for k in 20:
				var p := centre + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
				var r: Dictionary = TapAssist.resolve(p, cands, float(cam.call("current_zoom")))
				var got := String(r.get("hotspot", r.get("via", "")))
				if got == String(d.get("id", "")) or String(r.get("via", "")) == String(d.get("id", "")):
					hits += 1
				elif got != "":
					neighbour += 1
			table.append({"id": d.get("id", ""), "zoom": zoom, "hits": hits, "neighbour": neighbour})
			if hits < 19 or neighbour > 0:
				failures.append("tap_accuracy: %s at zoom %.1f: %d/20, %d neighbour picks" % [d.get("id", ""), zoom, hits, neighbour])
	# drags never move Hush
	var cmds: Array = []
	ni.connect("command", func(cm: Dictionary) -> void: cmds.append(cm))
	var moved := 0
	var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1),
		Vector2(-1, -1)]
	for dist in [25.0, 60.0, 120.0, 200.0]:
		for dv in dirs:
			var st := Vector2(1200, 540)
			var n0 := cmds.size()
			_touch(st, true, 3)
			for s in 6:
				var p: Vector2 = st + (dv as Vector2).normalized() * float(dist) * float(s + 1) / 6.0
				_drag(p, (dv as Vector2).normalized() * float(dist) / 6.0, 3)
				await get_tree().process_frame
			_touch(st + (dv as Vector2).normalized() * float(dist), false, 3)
			await _frames(2)
			for i in range(n0, cmds.size()):
				if String((cmds[i] as Dictionary).get("c", "")) in ["go", "move"]:
					moved += 1
	result = {"table": table, "drags_that_moved": moved}
	if moved > 0:
		failures.append("tap_accuracy: %d drags moved Hush" % moved)


# --- cold opens ------------------------------------------------------------------------------------

func _flow_cold() -> void:
	var t0 := _t
	var seen := PackedStringArray()
	while _t - t0 < 20.0:
		var n := _night()
		if n != null and is_instance_valid(n):
			var ph := String(n.call("phase_name"))
			if not seen.has(ph):
				seen.append(ph)
			if ph == "WARM" or ph == "RISING" or ph == "PLAY":
				break
		await get_tree().process_frame
	result = {"phases": seen}
