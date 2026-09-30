## PerfCheck3D (brief r3d-tools-b §4.5, §5): a report within budget passes; 180 draw calls p95, a shader compiled
## in PLAY each fail; a report without a perf3d block is a SKIP.
extends TestBase

const FX := "res://tests/lint3d/fixtures/"


func _lint(file: String) -> Dictionary:
	var rep: Variant = load_json(FX + file)
	return PerfCheck3D.check(rep if rep is Dictionary else {}, file.get_basename())


func test_within_budget_passes() -> void:
	var r := _lint("perf_ok.json")
	assert_false(Lint3D.failed(r["issues"], true))
	assert_eq(String((r["row"] as Dictionary)["status"]), "PASS")


func test_180_draw_calls_p95_fails() -> void:
	var r := _lint("perf_draws_180.json")
	var issues: Array = r["issues"]
	assert_eq(issues.size(), 1)
	assert_eq(String(issues[0]["rule"]), "draw_calls_p95")
	assert_eq(float(issues[0]["value"]), 180.0)
	assert_eq(String((r["row"] as Dictionary)["status"]), "FAIL")


func test_a_shader_compiled_in_play_fails_with_its_key() -> void:
	var issues: Array = _lint("perf_compile.json")["issues"]
	assert_eq(issues.size(), 1)
	assert_eq(String(issues[0]["rule"]), "shader_compiles_play")
	assert_has(String(issues[0]["detail"]), "reg:prop|tag")


func test_a_report_without_perf3d_is_a_skip() -> void:
	var r := _lint("perf_missing.json")
	assert_eq(Lint3D.counts(r["issues"])[Lint3D.SKIP], 1)
	assert_eq(String((r["row"] as Dictionary)["status"]), "SKIP")


func test_table_has_a_row_per_report() -> void:
	var rows: Array = [_lint("perf_ok.json")["row"], _lint("perf_draws_180.json")["row"]]
	var t := PerfCheck3D.table(rows)
	assert_eq(t.split("\n", false).size(), 4, "header, rule, two rows")
	assert_has(t, "| perf_draws_180 | FAIL | 180.0")


func test_the_script_budget_judges_view_plus_hud_when_split() -> void:
	var rep: Variant = load_json(FX + "perf_ok.json")
	(rep["perf3d"] as Dictionary)["view_ms_p95"] = 5.7
	(rep["perf3d"] as Dictionary)["script_ms_p95"] = 3.0
	var r := PerfCheck3D.check(rep, "split")
	var rules := PackedStringArray()
	for i in r["issues"]:
		if String(i["level"]) == Lint3D.ERROR:
			rules.append(String(i["rule"]))
	assert_eq(rules, PackedStringArray(["script_ms_p95"]), "view + HUD 5.7 ms > 4 fails even when all scripts read 3.0")
	assert_eq(float((r["row"] as Dictionary)["script_ms_p95"]), 5.7)
