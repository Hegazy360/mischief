## VisibilityCheck3D (brief r3d-tools-b §4.4, §5): C8 on synthetic traces — Bellows off screen with sim `room` and
## the window closed fails; the window open while he is on screen fails; under `lean` an adjacency-only tick with the
## edge badge passes and a `heading` tick with only the badge fails; under `sim` the badge never counts. Plus a short
## replay of the real g0 route through the view stack (the plumbing: rows, columns, the window share).
extends TestBase

const FX := "res://tests/lint3d/fixtures/"

var _traces: Dictionary = {}


func before_each() -> void:
	var v: Variant = load_json(FX + "visibility_traces.json")
	_traces = v if v is Dictionary else {}


func _rules(trace: String, mode: String) -> PackedStringArray:
	var out := PackedStringArray()
	for v in VisibilityCheck3D.check_rows(_traces.get(trace, []), mode)["violations"]:
		out.append(String((v as Dictionary)["rule"]))
	return out


func test_clean_trace_passes_both_modes() -> void:
	assert_eq(_rules("c8_clean", "sim"), PackedStringArray())
	assert_eq(_rules("c8_clean", "lean"), PackedStringArray())


func test_off_screen_in_her_room_with_the_window_closed_fails() -> void:
	assert_eq(_rules("c8_hidden", "sim"), PackedStringArray(["c8_shown", "c8_shown"]))
	var chk := VisibilityCheck3D.check_rows(_traces["c8_hidden"], "sim")
	var iss := VisibilityCheck3D.violation_issues("p00_curtain_up", "ideal", "sim", "20x9", chk, Lint3D.ERROR)
	assert_eq(iss.size(), 1, "one contiguous run → one issue")
	assert_has(String(iss[0]["value"]), "ticks 2–3")


func test_window_open_while_on_screen_fails() -> void:
	assert_eq(_rules("c8_double", "sim"), PackedStringArray(["c8_exclusive"]))


func test_lean_accepts_the_badge_only_on_adjacency_ticks() -> void:
	assert_eq(_rules("lean_adjacent_badge", "lean"), PackedStringArray(), "adjacent + badge passes under lean")
	assert_eq(_rules("lean_heading_badge", "lean"), PackedStringArray(["c8_shown"]), "heading + only the badge fails")
	assert_eq(_rules("lean_adjacent_badge", "sim").size(), 2, "under sim the badge never counts")


func test_window_share_of_a_trace() -> void:
	var chk := VisibilityCheck3D.check_rows(_traces["c8_clean"], "sim")
	assert_almost_eq(float(chk["share"]), 0.5, 0.001)
	assert_eq(int(chk["badge_frames"]), 0)


func test_route_files_parse_episode_and_route() -> void:
	var dir := OS.get_user_data_dir().path_join("lint3d_test_cmds")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in ["p00_curtain_up_ideal.cmds.json", "n01_throat_tea_meltdown.cmds.json", "other.json"]:
		var fa := FileAccess.open(dir.path_join(f), FileAccess.WRITE)
		fa.store_string("{}")
		fa.close()
	var got := VisibilityCheck3D.route_files(dir, Lint3D.NIGHTS)
	assert_true(got.has("p00_curtain_up|ideal"))
	assert_true(got.has("n01_throat_tea|meltdown"))
	assert_eq(got.size(), 2)


func test_replay_plumbing_on_the_real_g0_route() -> void:
	allow_errors()   # other tasks' in-flight assets (clips, cast) may log while the view builds
	var cmds: Variant = load_json("res://tests/view/fixtures/cmds/g0_sneeze_ideal.cmds.json")
	if not (cmds is Dictionary):
		skip("g0 route commands not in tests/view/fixtures (r3d-view3d)")
		return
	var db := ContentDB.load_dir("res://data")
	var rp := VisibilityCheck3D.replay(tree.root, db, "g0_sneeze", cmds, "sim", "20x9", 240)
	await tree.process_frame
	assert_eq(String(rp["error"]), "")
	assert_eq(int(rp["frames"]), 240)
	var rows: Array = rp["rows"]
	assert_eq(rows.size(), 240)
	assert_eq((rows[0] as Array).size(), 9, "tick, sim, reason, on_screen, window, badge, rooms, cam x")
	var chk := VisibilityCheck3D.check_rows(rows, "sim")
	assert_eq((chk["violations"] as Array).size(), 0, "C8 holds on the first 4 s of g0 (sim)")
