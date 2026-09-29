## NightScene in the tree (s2-night §5): the sim clock (tick 0 = the curtain-rise frame, nothing before
## it, pre-roll keeps tick 0), title_card swallowed in PLAY, retry work ≤ 300 ms, backgrounding into
## the pause menu, the g0 flow (g0_done → Again ▶), N02 → "To be continued…", save hooks, the FTUE
## hook contract with a stub and the no-FTUE fallback, and freeing cleanly after 600 frames.
extends TestBase

const SAVE_TMP := "user://test_night_save.json"

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


func _make(p: Dictionary) -> NightScene:
	var ps := load(NightScene.SCENE) as PackedScene
	var n: NightScene = ps.instantiate()
	n.setup(p)
	tree.root.add_child(n)
	return n


func _frames(k: int) -> void:
	for i in k:
		await tree.process_frame


func _wait_phase(n: NightScene, ph: int, limit: int = 300) -> bool:
	for i in limit:
		if n.phase == ph:
			return true
		await tree.process_frame
	return n.phase == ph


func _free(n: Node) -> void:
	n.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_sim_clock_starts_on_the_curtain() -> void:
	allow_errors()
	var hold := DeviceLog.process_ms() + 600000
	var n := _make({"episode": "g0_sneeze", "from": "test", "rise_at_ms": hold})
	if not assert_true(n.world != null, "the Night builds"):
		await _free(n)
		return
	await _frames(40)
	assert_eq(n.phase, NightScene.Phase.WARM, "held under the curtain")
	assert_eq(int(n.world.get("tick")), 0, "pre-roll leaves the sim at tick 0")
	assert_eq(n.events_before_rise, 0, "no sim event before the rise")
	assert_true(n.driver.is_paused(), "the driver is paused under the curtain")
	n.start_rise()
	var rise := n.frame_n
	assert_eq(n.rise_frame, rise)
	assert_eq(int(n.world.get("tick")), 0, "tick 0 on the rise frame")
	await _frames(5)
	assert_gt(int(n.world.get("tick")), 0, "the clock runs after the rise")
	assert_le(absi(n.rise_frame - rise), 1, "tick 0 = curtain-rise frame ± 1")
	await _free(n)


func test_title_card_is_swallowed_in_play() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true})
	await _wait_phase(n, NightScene.Phase.RISING, 200)
	var evs: Array = [{"e": "director_cue", "id": "title_card", "t": 5}, {"e": "director_cue", "id": "laugh_x", "t": 5}]
	n._on_ticked(evs)
	assert_eq(evs.size(), 1, "title_card removed before the views see it")
	assert_eq(String(evs[0]["id"]), "laugh_x")
	await _free(n)


func test_retry_work_is_under_300_ms_and_back_at_tick_0() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true})
	await _wait_phase(n, NightScene.Phase.PLAY, 300)
	await _frames(20)
	assert_gt(int(n.world.get("tick")), 0)
	var t0 := Time.get_ticks_usec()
	n.reset_night()
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	assert_lt(ms, 300.0, "retry reset took %.1f ms" % ms)
	assert_eq(int(n.world.get("tick")), 0)
	await _free(n)


func test_retry_in_place_reports_live_control_under_1500_ms() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true})
	await _wait_phase(n, NightScene.Phase.PLAY, 300)
	var got := [-1]
	n.retry_done.connect(func(ms: int) -> void: got[0] = ms)
	n.retry()
	for i in 200:
		if got[0] >= 0:
			break
		await tree.process_frame
	assert_between(got[0], 0, 1500, "tap → live control %d ms" % got[0])
	await _free(n)


func test_backgrounding_opens_the_pause_menu_and_stays_paused() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true})
	await _wait_phase(n, NightScene.Phase.PLAY, 300)
	await _frames(5)
	n._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	assert_true(n.is_paused(), "paused on focus-out")
	assert_true(n.driver.is_paused(), "the tick stops")
	assert_true(n.get("_pause_menu") != null, "the pause menu is open")
	var t := int(n.world.get("tick"))
	n._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(10)
	assert_eq(int(n.world.get("tick")), t, "coming back lands in the menu, not in play")
	assert_true(n.handle_back(), "Back is consumed (never quits)")
	await _frames(3)
	assert_false(n.is_paused(), "Back closed the menu")
	await _free(n)


func test_g0_done_curtain_call_again_retries() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true})
	await _wait_phase(n, NightScene.Phase.PLAY, 300)
	n._on_night_end("g0_done")
	assert_eq(n.phase, NightScene.Phase.CURTAIN_CALL)
	var cc: CurtainCall = n.curtain_call
	assert_eq(cc.kind, "gate0")
	assert_true(cc.results != null, "Again ▶ / Stage door live from the first frame")
	assert_eq(cc.results.variant, "gate0")
	var got := [-1]
	n.retry_done.connect(func(ms: int) -> void: got[0] = ms)
	cc.press("again")
	for i in 200:
		if got[0] >= 0:
			break
		await tree.process_frame
	assert_between(got[0], 0, 1500, "Again ▶ ≤ 1.5 s")
	assert_true(n.phase == NightScene.Phase.RISING or n.phase == NightScene.Phase.PLAY, "back in play")
	await _free(n)


func test_n02_next_shows_to_be_continued() -> void:
	allow_errors()
	var n := _make({"episode": "n02_something_fishy", "from": "test", "skip_intro": true})
	await _wait_phase(n, NightScene.Phase.PLAY, 300)
	n._on_night_end("bow")
	var cc: CurtainCall = n.curtain_call
	assert_eq(cc.kind, "night")
	assert_true(cc.proxy_next != null and not cc.proxy_next.disabled, "Next ▶ live on frame 1")
	assert_true(cc.proxy_retry != null, "Retry live on frame 1")
	n._on_curtain_call_action("next")
	await _frames(2)
	var found := false
	for c in n.curtain_layer.get_children():
		if c is ToBeContinued:
			found = true
	assert_true(found, "N02 → Next ▶ → To be continued…")
	await _free(n)


func test_save_hooks_record_the_night_and_the_prologue_flag() -> void:
	allow_errors()
	var sv := ViewKit.autoload("Save")
	if sv == null:
		skip("no Save autoload")
		return
	var n := _make({"episode": "p00_curtain_up", "from": "test", "skip_intro": true})
	await _wait_phase(n, NightScene.Phase.PLAY, 300)
	await _frames(10)
	n._on_night_end("prologue_done")
	var rec: Dictionary = sv.call("night", "p00_curtain_up")
	assert_false(rec.is_empty(), "record_result wrote the Night")
	for k in ["played"]:
		assert_true(rec.has(k), "save row has %s" % k)
	assert_true(bool(sv.call("prologue_done")), "set_prologue_done()")
	assert_eq(n.curtain_call.kind, "prologue")
	await _free(n)


func test_ftue_hook_contract_with_a_stub() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true,
		"ftue_path": "res://tests/night/fixtures/stub_ftue.gd"})
	assert_true(n.ftue != null, "the FTUE director was created")
	assert_true(n.cues == null, "never both: the no-FTUE fallback is off")
	var ctx: Dictionary = n.ftue.get("ctx")
	for k in ["driver", "world_view", "cam", "hud", "fx", "episode", "db"]:
		assert_true(ctx.has(k), "setup ctx has %s" % k)
	await _wait_phase(n, NightScene.Phase.PLAY, 300)
	await _frames(10)
	assert_gt(int(n.ftue.get("ticked")), 0, "on_ticked every tick")
	assert_gt(float(n.ftue.get("advanced")), 0.0, "advance every frame")
	n._intent(&"figgis_tap", [])
	assert_has(n.ftue.get("intents"), &"figgis_tap")
	assert_true(n.model.figgis_pulse, "figgis_pulse copied into the HudModel")
	n.ftue.emit_signal("pause_request", true)
	assert_true(n.driver.is_paused(), "pause_request pauses the driver")
	n.ftue.emit_signal("pause_request", false)
	n.reset_night()
	assert_eq(int(n.ftue.get("resets")), 1, "reset on retry")
	await _free(n)


func test_no_ftue_fallback_presents_the_gate0_cues() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "ftue_path": "res://nope.gd"})
	if ResourceLoader.exists(NightScene.FTUE_DIRECTOR):
		skip("the real FTUE director exists: the fallback is off")
		await _free(n)
		return
	assert_true(n.cues != null, "the fallback presents cues")
	await _wait_phase(n, NightScene.Phase.PLAY, 300)
	for i in 120:
		n.driver.step_now()
	await _frames(2)
	assert_has(n.cues.shown, "ghost_honey", "ghost finger on the honey at 1 s")
	await _free(n)


func test_frees_cleanly_after_600_frames() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true})
	for i in 900:
		if n.warmer.done:
			break
		await tree.process_frame
	assert_true(n.warmer.done, "the warm list finished")
	# + the Gag Reel's clone ring filling (4 world clones, one per 60 ticks): bounded, then flat
	await _frames(300)
	var samples: Array = []
	for k in 4:
		samples.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		await _frames(100)
	var drift := int(samples[3]) - int(samples[0])
	# bounded, event-driven growth only (a reel moment keeps one world clone per reaction; the view
	# builds a few lazy resources on first gags): no steady leak
	assert_le(absi(drift), 40, "OBJECT_COUNT after warm-up %s" % str(samples))
	var id := n.get_instance_id()
	await _free(n)
	assert_false(is_instance_id_valid(id), "freed")
