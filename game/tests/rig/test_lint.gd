## Animation + rig lints (TECH §10.5): every rule catches its purpose-built bad fixture in
## tests/rig/fixtures/, and the mannequin's rig and demo clips are clean.
extends TestBase

const FIX := "res://tests/rig/fixtures"
const CLIP_RULES := {
	"bad_frames.json": "A01_frames_increase",
	"bad_ids.json": "A02_ids_resolve",
	"bad_limits.json": "A03_joint_limits",
	"bad_seam.json": "A04_loop_seam",
	"bad_accent.json": ["A05_accent_length", "A06_accent_speed"],
	"bad_antic.json": "A07_antic_opposes",
	"bad_rx_short_hold.json": "A08_hold_length",
	"bad_dead.json": "A09_dead_hold",
	"bad_jump.json": "A10_pop_jump",
	"bad_twin.json": "A11_twinning",
	"bad_slide.json": "A12_feet_planted",
	"bad_floor.json": "A13_floor",
	"bad_sync.json": ["A14_sfx_on_key", "A15_face_on_key"],
	"bad_rx_laugh.json": ["A16_laugh_after_accent", "A20_time_jitter", "A22_marks"],
	"bad_rx_long.json": "A17_reaction_length",
	"bad_sil.json": "A18_silhouette_change",
	"bad_beats_match.json": "A19_beats_match",
	"bad_rx_nobeats.json": "A21_reaction_beats",
}
const RIG_RULES := {
	"r01_files": "R01_files",
	"r02_pivots": "R02_pivots",
	"r03_hierarchy": "R03_hierarchy",
	"r04_mirror": "R04_mirror",
	"r05_face": "R05_face",
	"r06_silhouette": "R06_silhouette",
	"r07_refs": "R07_refs",
	"r08_poses": "R08_poses",
}


static func _rules(findings: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for f in findings:
		if not out.has(String(f["rule"])):
			out.append(String(f["rule"]))
	return out


func test_every_animation_rule_catches_its_fixture() -> void:
	var covered := {}
	for file in CLIP_RULES:
		var c := ClipLib.load_file("%s/%s" % [FIX, file])
		var found := AnimLint.lint_clip(c)
		var rules := _rules(found)
		var want: Array = CLIP_RULES[file] if CLIP_RULES[file] is Array else [CLIP_RULES[file]]
		for r in want:
			assert_has(rules, r, "%s triggers %s (got %s)" % [file, r, rules])
			covered[r] = true
		for f in found:
			assert_ne(String(f["file"]), "", "findings name their file")
			assert_true(AnimLint.format(f).begins_with(String(f["severity"]).to_upper()), "stable format")
	for i in range(1, 23):
		var rid := "A%02d" % i
		var any := false
		for k in covered:
			if String(k).begins_with(rid):
				any = true
		assert_true(any, "rule %s has a fixture" % rid)


func test_every_rig_rule_catches_its_fixture() -> void:
	for dir in RIG_RULES:
		var base := "%s/rigs/%s" % [FIX, dir]
		var r := RigDef.load(base + "/rig.json")
		var lib: PoseLib = null
		if FileAccess.file_exists(base + "/poses.json") or FileAccess.file_exists(base + "/faces.json"):
			lib = PoseLib.load(r, base + "/poses.json", base + "/faces.json")
		var rules := _rules(RigLint.lint_rig(r, lib))
		assert_has(rules, RIG_RULES[dir], "%s triggers %s (got %s)" % [dir, RIG_RULES[dir], rules])


func test_mannequin_rig_and_demo_clips_are_lint_clean() -> void:
	var rig_findings := RigLint.lint_all("_mannequin")
	for f in rig_findings:
		fail(AnimLint.format(f))
	var ids := ClipLib.list("_mannequin")
	assert_ge(ids.size(), 5, "idle, walk, take, launch, land (+ beats)")
	for want in ["loco_idle", "loco_walk", "rx_take", "rx_launch", "rx_land"]:
		assert_has(ids, "_mannequin/" + want)
	for cid in ids:
		for f2 in AnimLint.lint_clip(ClipLib.get_clip(cid)):
			fail(AnimLint.format(f2))


func test_lint_cli_exit_codes() -> void:
	# The CLI reports errors through its exit code; here the same counting it uses.
	var bad := AnimLint.lint_clip(ClipLib.load_file(FIX + "/bad_jump.json"))
	assert_gt(AnimLint.error_count(bad), 0)
	var good := AnimLint.lint_clip(ClipLib.get_clip("_mannequin/rx_take"))
	assert_eq(AnimLint.error_count(good), 0)
