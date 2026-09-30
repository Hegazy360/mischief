## VisibilityCheck3D — the visibility test C8 (`lint3d.sh --visibility --routes=all [--aspects=20x9,4x3]
## [--mode=sim|lean]`; REDESIGN §5.2 C8, index §7.9 and §6 row 12, brief r3d-tools-b §4.4).
##
## Every solver route is replayed headless through the real view stack — SimWorld → SimDriver → WorldView3D →
## CameraDirector3D → PipView3D (the window's own C8 decision), fixed 60 fps, the camera advanced in view time — and on
## every frame the sample `WorldView3D.visibility_sample()` {tick, sim (`SimVisibility.beat_vis`), reason
## (`pip_reason`), on_screen (≥ 35 % of his projected bounds inside the viewport), window, badge} is checked:
## * **c8_shown** — sim ∈ {room, pip} ⇒ on screen **or** the Bellows window shown; under `lean` also the HUD edge badge
##   on a tick whose `pip_reason` is `adjacent` (index §7.9). Error.
## * **c8_exclusive** — on screen ⇒ the window closed. Error.
## The shipped mode (`boot_config.json` `bellows_window`, `--mode=` overrides) is checked as errors; the other mode is
## replayed as info. Each route's window share (the headless twin of the e2e `pip_on_share`) is printed per mode.
class_name VisibilityCheck3D
extends RefCounted

const LINT := "visibility"
const DT := 1.0 / 60.0
const OWNER := "r3d-view3d"
const FIELDS: PackedStringArray = ["tick", "sim", "reason", "on_screen", "window", "badge"]
const BOOT_CONFIG := "res://scenes/boot/boot_config.json"


## The shipped Bellows-window mode (boot_config.json `bellows_window`, default "sim").
static func shipped_mode() -> String:
	var v: Variant = Lint3D.read_json(BOOT_CONFIG)
	if v is Dictionary:
		var m := String((v as Dictionary).get("bellows_window", "sim"))
		if m in ["sim", "lean"]:
			return m
	return "sim"


## The C8 rules on one sample row [tick, sim, reason, on_screen, window, badge] (bools may be 0/1). Returns "" when
## the row is fine, else the violated rule: "c8_shown" | "c8_exclusive".
static func check_row(row: Array, mode: String) -> String:
	var sim := String(row[1])
	var reason := String(row[2])
	var on_screen := bool(row[3])
	var window := bool(row[4])
	var badge := bool(row[5])
	if on_screen and window:
		return "c8_exclusive"
	if sim == SimVisibility.ROOM or sim == SimVisibility.PIP:
		if on_screen or window:
			return ""
		if mode == "lean" and reason == "adjacent" and badge:
			return ""
		return "c8_shown"
	return ""


## Checks a whole trace (rows as above, optional extra columns ignored). Returns {violations: [{rule, row index,
## tick, row}], frames, window_frames, share, longest_s, badge_frames}.
static func check_rows(rows: Array, mode: String) -> Dictionary:
	var viol: Array = []
	var win := 0
	var run := 0
	var longest := 0
	var badge := 0
	for i in rows.size():
		var r: Array = rows[i]
		var why := check_row(r, mode)
		if why != "":
			viol.append({"rule": why, "i": i, "tick": int(r[0]), "row": r})
		if bool(r[4]):
			win += 1
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
		if bool(r[5]):
			badge += 1
	return {"violations": viol, "frames": rows.size(), "window_frames": win,
		"share": float(win) / maxf(1.0, float(rows.size())), "longest_s": float(longest) / 60.0,
		"badge_frames": badge}


## Folds a trace's violations into issues: one per (rule, contiguous run), with the first tick, the room pair and the
## camera x (from the rows' extra columns [.., hush_room, bellows_room, cam_x] when present).
static func violation_issues(night: String, route: String, mode: String, aspect: String, checked: Dictionary,
		level: String) -> Array:
	var out: Array = []
	var runs: Array = []
	var prev_i := -9
	var prev_rule := ""
	for v in checked.get("violations", []):
		var vd: Dictionary = v
		if int(vd["i"]) == prev_i + 1 and String(vd["rule"]) == prev_rule:
			(runs[runs.size() - 1] as Dictionary)["n"] = int((runs[runs.size() - 1] as Dictionary)["n"]) + 1
			(runs[runs.size() - 1] as Dictionary)["last_tick"] = vd["tick"]
		else:
			runs.append({"rule": vd["rule"], "first_tick": vd["tick"], "last_tick": vd["tick"], "n": 1, "row": vd["row"]})
		prev_i = int(vd["i"])
		prev_rule = String(vd["rule"])
	for ru in runs:
		var rd: Dictionary = ru
		var row: Array = rd["row"]
		var pair := "%s→%s" % [row[6], row[7]] if row.size() >= 8 else ""
		var camx := Lint3D.fmt(row[8]) if row.size() >= 9 else "?"
		var what := "Bellows neither on screen nor in the window" if String(rd["rule"]) == "c8_shown" \
			else "the window is open while he is on screen"
		out.append(Lint3D.issue(LINT, String(rd["rule"]), level, night, pair, "%s/%s/%s" % [route, mode, aspect],
			"ticks %s–%s (%d frames)" % [rd["first_tick"], rd["last_tick"], rd["n"]], "0 frames", OWNER,
			"%s; sim %s reason %s on_screen %s window %s badge %s; cam x %s" % [what, row[1], row[2], row[3], row[4], row[5], camx]))
	return out


# --- the replay ----------------------------------------------------------------------------------------

## Replays one route through the real view stack under `parent` (in the SceneTree). `cmds` = a sim_run --cmds
## Dictionary (solve.sh --dump-cmds; the replay stops at its `ticks`, the solver's run length, or when the Night ends). Returns {rows: [[tick, sim, reason, on_screen, window, badge, hush_room,
## bellows_room, cam_x]], share: PipView3D.share(), frames, ended, ms}.
static func replay(parent: Node, db: ContentDB, episode_id: String, cmds: Dictionary, mode: String, aspect: String,
		max_frames: int = 30000) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var out := {"rows": [], "frames": 0, "ended": false, "share": {}, "ms": 0, "error": ""}
	var w := SimWorld.create(db, episode_id, {})
	if w == null:
		out["error"] = "SimWorld.create(%s) failed" % episode_id
		return out
	var root := Node3D.new()
	root.name = "C8Replay"
	parent.add_child(root)
	var driver := SimDriver.new()
	root.add_child(driver)
	driver.setup(w)
	driver.set_script_cmds(cmds)
	var cam := CameraDirector3D.new()
	cam.time_source = driver
	cam.logical_size_override = View3DConst.logical_size(aspect)
	root.add_child(cam)
	var wv := WorldView3D.new()
	wv.cam = cam
	root.add_child(wv)
	wv.setup(db, null, driver)
	wv.window_mode = mode
	cam.follow(wv.hush_view, func() -> float:
		var s := driver.snapshot()
		return float(s.hush.facing) if s.hush.moving else 0.0)
	cam.set_other(wv.bellows_view)
	var pip := PipView3D.new()
	root.add_child(pip)
	pip.setup(wv, cam)
	wv.pip = pip
	for n in [driver, driver.juice, wv, cam, pip]:
		(n as Node).set_process(false)
	var vt := 0.0
	driver.juice.test_now_us = 0
	var rooms := db.house.rooms
	var rows: Array = []
	var frames := 0
	var end_tick := int(cmds.get("ticks", -1))
	while frames < max_frames:
		vt += DT
		driver.juice.test_now_us = int(vt * 1000000.0)
		driver.juice.advance()
		driver.advance(DT)
		wv.advance(DT)
		cam.advance(driver.view_delta(), DT)
		pip.advance(DT)
		if frames == 0:
			cam.snap_now()
		frames += 1
		var v := wv.visibility_sample()
		var s := driver.snapshot()
		rows.append([int(v.get("tick", -1)), String(v.get("sim", "")), String(v.get("reason", "")),
			1 if bool(v.get("on_screen", false)) else 0, 1 if bool(v.get("window", false)) else 0,
			1 if bool(v.get("badge", false)) else 0, s.hush.room, s.bellows.room, snappedf(cam.aim().x, 0.01)])
		if s.ended:
			out["ended"] = true
			break
		# the solver's run length (a scenario route may stop before the Night ends: a catch, a chase)
		if end_tick > 0 and s.tick >= end_tick:
			out["ended"] = true
			break
	out["rows"] = rows
	out["frames"] = frames
	out["share"] = pip.share()
	out["rooms"] = rooms.size()
	root.queue_free()
	out["ms"] = Time.get_ticks_msec() - t0
	return out


## The route command files of a dump dir: {"<episode>|<route>": abs path} for the given Nights.
static func route_files(dir: String, nights: PackedStringArray) -> Dictionary:
	var out := {}
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".cmds.json"):
			continue
		var stem := f.trim_suffix(".cmds.json")
		for ep in nights:
			if stem.begins_with(ep + "_"):
				out["%s|%s" % [ep, stem.substr(ep.length() + 1)]] = dir.path_join(f)
	return out
