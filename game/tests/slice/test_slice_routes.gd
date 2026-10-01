## Whole-route checks on the real 3D NightScene (r3d-qa brief §3.2; index §6 rows 13–15 in the suite): `g0_sneeze`
## and every Prologue route (ideal / required / slow) are dumped by the solver's Executor (`E2eRoute.dump`) and replayed
## through a NightScene built exactly as the game builds it, the 3D world stepped at a fixed rate (the sim driver,
## its JuiceClock on a test clock, WorldView3D, CameraDirector3D and the Bellows window advanced by hand each frame,
## as `VisibilityCheck3D.replay` does — headless frames are faster than 60 fps). Per route: the Night ends by its own
## reason, **0 view fallbacks per clip id** (`WorldView3D.fallback_counts`), 0 script / engine errors (the runner
## fails the test on any), the **four always-on HUD pieces** (pause, Script, Clarence, action) on every sampled PLAY
## frame and nothing else always-on, and on the g0 route **C8 sampled** on every frame (`VisibilityCheck3D.check_rows`
## in the shipped `bellows_window` mode). The clips each route shows are logged (the rendered e2e rows 13–15 and the
## pre-gate keep the full coverage count). Budget: the four routes ≈ 2 min headless (g0 at 60 fps, P00 at 30 fps).
extends TestBase

## g0 is stepped at 60 fps (C8 is sampled on every frame); the three Prologue routes at a fixed 30 fps (two ticks a
## frame: the same clip picks and fallback counts in half the frames — the suite stays ≤ 3 min; the rendered 60 fps
## replays are pre-gate rows 13–15).
const DT_G0 := 1.0 / 60.0
const DT_P00 := 1.0 / 30.0
const HUD_EVERY := 30
const ALWAYS_ON: PackedStringArray = ["action", "clarence", "pause", "script"]
const SAVE_TMP := "user://test_slice_routes_save.json"
## Frame budget per route (the Prologue is ~3.7k ticks; a hit-stop or a slow-mo adds frames).
const MAX_FRAMES := 9000

var _saved_path: String = ""


func before_each() -> void:
	var sv := ViewKit.autoload("Save")
	if sv != null:
		_saved_path = String(sv.get("path"))
		sv.set("path", SAVE_TMP)
		sv.call("reset")


func after_each() -> void:
	var sv := ViewKit.autoload("Save")
	if sv != null and _saved_path != "":
		sv.set("path", _saved_path)
		sv.call("load_save")
	if FileAccess.file_exists(SAVE_TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TMP))


## One route through the 3D NightScene at a fixed 60 fps. Returns {ok, error, ticks, frames, end_reason, fallbacks,
## by_clip, clips, hud_bad, hud_samples, vis_rows, ms}.
func _replay(ep: String, route: String, dt: float) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var out := {"ok": false, "error": "", "frames": 0, "end_reason": "", "clips": {}, "hud_bad": [], "hud_samples": 0,
		"vis_rows": [], "fallbacks": -1, "by_clip": {}}
	var d := E2eRoute.dump(ep, route)
	if not bool(d.get("ok", false)):
		out["error"] = "the solver could not dump %s/%s: %s %s" % [ep, route, d.get("error", ""), str(d.get("fail", []))]
		return out
	out["ticks"] = int(d.get("ticks", 0))
	var n: NightScene = (load(NightScene.SCENE) as PackedScene).instantiate()
	n.setup({"episode": ep, "from": "test", "skip_intro": true, "cmds": d["cmds"]})
	tree.root.add_child(n)
	if n.world == null:
		out["error"] = "%s did not build" % ep
		n.queue_free()
		return out
	var ph := 0
	while n.phase != NightScene.Phase.PLAY and ph < 600:
		await tree.process_frame
		ph += 1
	if n.phase != NightScene.Phase.PLAY:
		out["error"] = "%s never reached PLAY (phase %s)" % [ep, n.phase_name()]
		await _free(n)
		return out
	# take the 3D world over: one fixed 60 fps step per frame (the sim replays its commands by tick, deterministic)
	var drv := n.driver
	var wv := n.world_view as WorldView3D
	var cam := n.cam as CameraDirector3D
	var pip := n.pip as PipView3D
	for x in [drv, drv.juice, wv, cam, pip]:
		(x as Node).set_process(false)
	var base_us := Time.get_ticks_usec()
	var vt := 0.0
	var clips := {}
	var rows: Array = []
	var frames := 0
	while frames < MAX_FRAMES:
		await tree.process_frame
		vt += dt
		drv.juice.test_now_us = base_us + int(vt * 1000000.0)
		drv.advance(dt)
		wv.advance(dt)
		cam.advance(drv.view_delta(), dt)
		pip.advance(dt)
		frames += 1
		for cv in [wv.hush_view, wv.bellows_view]:
			var c := String(cv.call("current_clip"))
			if c != "":
				clips[c] = true
			var o := String(cv.call("overlay_clip"))
			if o != "":
				clips[o] = true
		var v := wv.visibility_sample()
		rows.append([int(v.get("tick", -1)), String(v.get("sim", "")), String(v.get("reason", "")),
			1 if bool(v.get("on_screen", false)) else 0, 1 if bool(v.get("window", false)) else 0,
			1 if bool(v.get("badge", false)) else 0])
		if n.phase == NightScene.Phase.PLAY and frames % HUD_EVERY == 1:
			out["hud_samples"] = int(out["hud_samples"]) + 1
			var on := PackedStringArray()
			for pc in n.hud.debug_pieces():
				if bool((pc as Dictionary).get("always_on", false)):
					on.append(String((pc as Dictionary).get("name", "")))
			on.sort()
			if on != ALWAYS_ON:
				(out["hud_bad"] as Array).append("tick %d: %s" % [drv.snapshot().tick, ",".join(on)])
		if bool(n.world.get("ended")):
			break
	out["frames"] = frames
	out["end_reason"] = String(n.world.get("end_reason"))
	var fb: Dictionary = wv.fallback_counts()
	out["by_clip"] = fb.get("by_clip", {})
	out["fallbacks"] = int(fb.get("clip_fallbacks", 0)) + int(fb.get("puppets", 0)) + int(fb.get("greybox_props", 0))
	out["clips"] = clips
	out["vis_rows"] = rows
	out["ok"] = true
	out["ms"] = Time.get_ticks_msec() - t0
	await _free(n)
	return out


func _free(n: Node) -> void:
	n.queue_free()
	await tree.process_frame
	await tree.process_frame


func _check_route(ep: String, route: String, end_reason: String, dt: float) -> Dictionary:
	var r: Dictionary = await _replay(ep, route, dt)
	if not assert_true(bool(r["ok"]), "%s/%s replayed: %s" % [ep, route, r["error"]]):
		return r
	print("    %s/%s: %d frames, %d ticks, %d clips shown, %d ms" % [ep, route, r["frames"], r.get("ticks", 0),
		(r["clips"] as Dictionary).size(), r.get("ms", 0)])
	assert_eq(String(r["end_reason"]), end_reason, "%s/%s ends by %s" % [ep, route, end_reason])
	assert_eq(int(r["fallbacks"]), 0, "%s/%s: 0 view fallbacks, by clip id %s" % [ep, route, str(r["by_clip"])])
	assert_eq(r["by_clip"], {}, "%s/%s: no fallback clip id" % [ep, route])
	assert_gt(int(r["hud_samples"]), 10, "%s/%s: HUD sampled in PLAY" % [ep, route])
	assert_eq(r["hud_bad"], [], "%s/%s: exactly the four always-on pieces on every sampled PLAY frame" % [ep, route])
	assert_gt((r["clips"] as Dictionary).size(), 10, "%s/%s: both characters played their clips" % [ep, route])
	return r


func test_g0_sneeze_in_3d_with_c8() -> void:
	var r: Dictionary = await _check_route("g0_sneeze", "ideal", "g0_done", DT_G0)
	if not bool(r.get("ok", false)):
		return
	assert_true((r["clips"] as Dictionary).has("bellows/rx_sneeze_blast_a"), "the sneeze played")
	assert_true((r["clips"] as Dictionary).has("hush/rig_achoo_ria"), "ACHOO-RIA! rigged on its own clip")
	var mode := VisibilityCheck3D.shipped_mode()
	var c8: Dictionary = VisibilityCheck3D.check_rows(r["vis_rows"], mode)
	assert_gt(int(c8.get("frames", (r["vis_rows"] as Array).size())), 1000, "C8 sampled on every frame of the g0 route")
	var viol: Array = c8.get("violations", [])
	assert_eq(viol.size(), 0, "C8 (%s): %d violations, first %s" % [mode, viol.size(), str(viol.slice(0, 3))])


func test_prologue_ideal_in_3d() -> void:
	var r: Dictionary = await _check_route("p00_curtain_up", "ideal", "prologue_done", DT_P00)
	if bool(r.get("ok", false)):
		var cl: Dictionary = r["clips"]
		assert_true(cl.has("bellows/rx_dizzy_spin_a"), "the dizzy spin played")
		assert_true(cl.has("hush/rig_allegro_go_go"), "ALLEGRO-GO-GO! rigged on its own clip")


func test_prologue_required_in_3d() -> void:
	await _check_route("p00_curtain_up", "required", "prologue_done", DT_P00)


func test_prologue_slow_in_3d() -> void:
	await _check_route("p00_curtain_up", "slow", "prologue_done", DT_P00)
