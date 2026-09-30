## HudLint3D (brief r3d-tools-b §4.3, §5): every rule fails on its fixture and passes on a clean one — 5 always-on
## pieces, a persistent rect at y 400, the action button off its §2.1 position, 7 overlays / 3 loud, the edge badge
## outside its outer zone, a Bellows-window share of 60 % (a warning, never an error).
extends TestBase

const FX := "res://tests/lint3d/fixtures/"


func _lint(file: String) -> Dictionary:
	var rep: Variant = load_json(FX + file)
	assert_true(rep is Dictionary, "fixture %s loads" % file)
	return HudLint3D.check_report(rep if rep is Dictionary else {}, file.get_basename())


func _levels(issues: Array, rule: String) -> PackedStringArray:
	var out := PackedStringArray()
	for i in issues:
		if String((i as Dictionary)["rule"]) == rule:
			out.append(String((i as Dictionary)["level"]))
	return out


func test_clean_report_passes_every_rule() -> void:
	var r := _lint("hud_clean.json")
	var issues: Array = r["issues"]
	assert_false(Lint3D.failed(issues, true), "clean HUD report: no error, no skip (%s)" % [Lint3D.counts(issues)])
	assert_eq(int((r["stats"] as Dictionary)["always_on_max"]), 4)
	assert_eq((r["stats"] as Dictionary)["viewport"], [2400.0, 1080.0], "viewport inferred from pause + action")
	# the action button at its REDESIGN §2.1 rect reaches into the band: reported, not failed
	var spec := false
	for i in issues:
		if String(i["rule"]) == "middle_band" and String(i["subject"]).ends_with(":action"):
			spec = String(i["level"]) == Lint3D.INFO
	assert_true(spec, "action at its spec rect = info")
	# Figgis for 1 s is an allowed contextual piece
	assert_false(_levels(issues, "middle_band").has(Lint3D.ERROR))


func test_five_always_on_pieces_fail() -> void:
	var issues: Array = _lint("hud_five_always_on.json")["issues"]
	assert_eq(_levels(issues, "always_on_count"), PackedStringArray([Lint3D.ERROR]))
	for i in issues:
		if String(i["rule"]) == "always_on_count":
			assert_eq(int(i["value"]), 5)
			assert_eq((i["samples"] as Array).size(), 4, "every offending sample listed")
			assert_has((i["samples"] as Array)[0]["foreign"], "meter")


func test_a_persistent_rect_in_the_middle_band_fails() -> void:
	var issues: Array = _lint("hud_persistent_band.json")["issues"]
	var found := false
	for i in issues:
		if String(i["rule"]) == "middle_band" and String(i["subject"]).ends_with(":chips"):
			found = true
			assert_eq(String(i["level"]), Lint3D.ERROR)
			assert_has(String(i["detail"]), "persistent")
	assert_true(found, "the chip strip at y 400 for 8 s is reported")


func test_the_action_button_off_its_spec_position_fails() -> void:
	var issues: Array = _lint("hud_action_moved.json")["issues"]
	assert_has(_levels(issues, "middle_band"), Lint3D.ERROR)


func test_the_edge_badge_only_in_the_outer_zone() -> void:
	assert_false(_levels(_lint("hud_edge_badge_outer.json")["issues"], "middle_band").has(Lint3D.ERROR),
		"edge badge at x 24–160 is allowed in the band")
	assert_has(_levels(_lint("hud_edge_badge_centre.json")["issues"], "middle_band"), Lint3D.ERROR,
		"edge badge in the middle of the screen is not")


func test_seven_overlays_three_loud_fail() -> void:
	var issues: Array = _lint("hud_overlays_7_3.json")["issues"]
	assert_eq(_levels(issues, "overlays"), PackedStringArray([Lint3D.ERROR]))
	for i in issues:
		if String(i["rule"]) == "overlays":
			assert_eq((i["samples"] as Array).size(), 1, "only the frame over V6")


func test_window_share_60_is_a_warning_never_an_error() -> void:
	var r := _lint("hud_share_60.json")
	var issues: Array = r["issues"]
	assert_eq(_levels(issues, "window_share"), PackedStringArray([Lint3D.WARNING]))
	assert_false(Lint3D.failed(issues, true), "a share warning never fails the lint, strict or not")
	for i in issues:
		if String(i["rule"]) == "window_share":
			assert_has(String(i["detail"]), "longest 21.5 s")
			assert_has(String(i["detail"]), "1340")
	assert_eq(_levels(_lint("hud_clean.json")["issues"], "window_share"), PackedStringArray([Lint3D.INFO]), "20 % = info")


func test_band_scales_with_the_viewport() -> void:
	assert_eq(HudLint3D.band_rect(Vector2(2400, 1080)), Rect2(0, 250, 2400, 630))
	assert_eq(HudLint3D.band_rect(Vector2(1920, 1440)), Rect2(0, 250.0 * 1440.0 / 1080.0, 1920, 630.0 * 1440.0 / 1080.0))


func test_a_report_without_samples_is_a_skip() -> void:
	var r := HudLint3D.check_report({"episode": "g0_sneeze"}, "empty")
	assert_true(Lint3D.counts(r["issues"])[Lint3D.SKIP] >= 2)
	assert_false(Lint3D.failed(r["issues"], false), "skips pass without --strict")
	assert_true(Lint3D.failed(r["issues"], true), "and fail with it")
