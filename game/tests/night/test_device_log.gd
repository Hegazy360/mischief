## DeviceLog (s2-night §4.5): the schema, 5-session rotation, the /proc parse (fixture strings), gating,
## milestones recorded once, and the command log round-trip.
extends TestBase

const TMP := "user://test_device_log.json"


func before_each() -> void:
	DeviceLog.reset_for_tests()
	DeviceLog.enabled_override = 1
	DeviceLog.path = TMP
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func after_each() -> void:
	DeviceLog.reset_for_tests()
	DeviceLog.enabled_override = -1
	DeviceLog.path = DeviceLog.PATH
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	# DevShot owns the real session: restart it so the rest of the suite keeps a live log
	DeviceLog.begin_session()


func test_proc_parse_fixture() -> void:
	# /proc/self/stat with a command name containing spaces and parentheses; starttime (field 22) = 12345 ticks
	var fields := PackedStringArray()
	for i in range(3, 22):
		fields.append(str(i))
	fields.append("12345")
	for i in range(23, 53):
		fields.append("0")
	var stat := "4242 (org.godot (game) x) S " + " ".join(fields.slice(1))
	var up := "200.00 350.12"
	assert_eq(DeviceLog.parse_proc_age_ms(stat, up, 100), 200000 - 123450, "uptime − starttime / CLK_TCK")
	assert_eq(DeviceLog.parse_proc_age_ms("garbage", up, 100), -1)
	assert_eq(DeviceLog.parse_proc_age_ms(stat, "", 100), -1)


func test_schema_fields() -> void:
	DeviceLog.begin_session()
	var s := DeviceLog.session()
	for k in ["id", "build", "model", "os", "gpu", "ram_mb", "clock", "process_start_to_boot_ms", "curtain_up_ms",
			"sim_start_ms", "first_input_ms", "first_squeak_ms", "first_player_laugh_ms", "first_prank_ms", "retry_ms",
			"laughs", "catches", "perf"]:
		assert_true(s.has(k), "session has %s" % k)
	assert_true(String(s["build"]) in ["debug", "profile"])


func test_milestones_once_and_laughs_catches() -> void:
	DeviceLog.begin_session()
	DeviceLog.mark("curtain_up")
	var first := int(DeviceLog.session()["curtain_up_ms"])
	DeviceLog.mark("curtain_up")
	assert_eq(int(DeviceLog.session()["curtain_up_ms"]), first, "a milestone keeps its first time")
	var i := DeviceLog.laugh("reaction_accent:achoo_ria", -1)
	DeviceLog.set_laugh_tier(i, 3)
	assert_eq(int((DeviceLog.session()["laughs"] as Array)[0]["tier"]), 3)
	DeviceLog.catch(1.25, "spotted")
	assert_eq(float((DeviceLog.session()["catches"] as Array)[0]["spot_fill_s"]), 1.25)
	DeviceLog.set_retry_ms(640)
	assert_eq((DeviceLog.session()["retry_ms"] as Array), [640])


func test_perf_windows() -> void:
	DeviceLog.begin_session()
	for i in 700:
		DeviceLog.frame(1.0 / 60.0)
	var perf: Array = DeviceLog.session()["perf"]
	assert_eq(perf.size(), 1, "one summary per 10 s")
	assert_between(float(perf[0]["fps_p50"]), 59.0, 61.0)


func test_rotation_keeps_five_sessions() -> void:
	for n in 7:
		DeviceLog.reset_for_tests()
		DeviceLog.begin_session()
		DeviceLog.session()["id"] = 1000 + n
		assert_eq(DeviceLog.flush(), OK)
	var j := JSON.new()
	assert_eq(j.parse(FileAccess.get_file_as_string(TMP)), OK)
	var ss: Array = (j.data as Dictionary)["sessions"]
	assert_eq(ss.size(), 5)
	assert_eq(int(ss[4]["id"]), 1006, "newest last")
	assert_eq(int(ss[0]["id"]), 1002)


func test_flush_replaces_the_current_session_in_place() -> void:
	DeviceLog.begin_session()
	DeviceLog.flush()
	DeviceLog.mark("first_input")
	DeviceLog.flush()
	var j := JSON.new()
	j.parse(FileAccess.get_file_as_string(TMP))
	assert_eq(((j.data as Dictionary)["sessions"] as Array).size(), 1)


func test_gating_inert_when_off() -> void:
	DeviceLog.enabled_override = 0
	DeviceLog.begin_session()
	assert_eq(DeviceLog.laugh("x", 1), -1)
	assert_eq(DeviceLog.flush(), ERR_UNAVAILABLE)
	assert_false(FileAccess.file_exists(TMP))
	assert_eq(DeviceLog.to_text(), "{}")


func test_process_ms_is_monotonic_and_after_engine_start() -> void:
	var a := DeviceLog.process_ms()
	assert_ge(a, Time.get_ticks_msec())


func test_cmd_log_round_trip_replays_to_the_same_hash() -> void:
	var content := ViewKit.autoload("Content")
	var db: Variant = content.get("db") if content != null else null
	if db == null:
		skip("no Content autoload")
		return
	var w := SimWorld.create(db, "g0_sneeze", {})
	var cmds: Array = [[30, {"c": "go", "hotspot": "kitchen_honey", "run": false}], [200, {"c": "squeak"}]]
	CmdLog.path = "user://test_last_session.json"
	assert_eq(CmdLog.write("g0_sneeze", cmds, 400), OK)
	var back := CmdLog.read()
	assert_eq(String(back["episode"]), "g0_sneeze")
	var norm := NightArgs.normalise_cmds(back)
	assert_eq(norm.size(), 2)
	# replay the file the way sim_run --cmds does vs the original list
	var by := {}
	for c in norm:
		if not by.has(int(c[0])):
			by[int(c[0])] = []
		(by[int(c[0])] as Array).append(c[1])
	for t in range(1, 401):
		w.step(by.get(t, []))
		w.drain_events()
	var w2 := SimWorld.create(db, "g0_sneeze", {})
	for t in range(1, 401):
		w2.step([cmds[0][1]] if t == 30 else ([cmds[1][1]] if t == 200 else []))
		w2.drain_events()
	assert_eq(w.state_hash(), w2.state_hash(), "the logged session replays to the same state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CmdLog.path))
	CmdLog.path = CmdLog.PATH
