## r3d-anim-hush-b's Hush clips on the 3D pipeline (brief §5): every clip of the list that exists parses through
## ClipLib3D, its `.res` loads, matches its expected length (or loops where allowed) and lints `--strict` clean; the
## band fallbacks are `rig_pm`, ≥ 48 f, carry no `glance` mark and `rig_high` ends on the floor; `freeze_midjob`'s
## `variants` segments are well formed; `freeze_1..8` are pairwise < 0.80 IoU at 64 px (from the rendered masks' JSON,
## `docs/review/r3d-anim-hush-b/statues_8.json`, found from the working directory — skipped when absent). A clip not
## made yet is a named skip, never a failure.
extends TestBase

const L := preload("res://tools/anim/lint3d_rules.gd")
const CLIP_LIB := "res://view3d/char/clip_lib_3d.gd"
const OWNER := "r3d-anim-hush-b"
## clip -> expected frames (-1 = a loop, any length); the lengths of brief §4 / clip_rules.json / the 2D beats.
const LIST := {"loco_arrive": 8, "freeze_midjob": -1, "act_glance": 30, "loco_skid": 6, "idle_fidget_look": 80,
	"idle_fidget_proud": 84, "idle_fidget_clarence": 80, "act_rummage": -1, "act_wheeze": -1, "st_shrug": 20,
	"st_yanked": 36, "rig_mid": 0, "rig_high": 0, "rig_low": 0, "freeze_5": 150, "freeze_6": 150, "freeze_7": 150,
	"freeze_8": 150}
const BANDS: PackedStringArray = ["rig_mid", "rig_high", "rig_low"]
const STATUES_JSON := "docs/review/r3d-anim-hush-b/statues_8.json"
const IOU_MAX := 0.80


func after_each() -> void:
	L.reset_caches()


static func _soft(path: String) -> Script:
	return load(path) as Script if ResourceLoader.exists(path) else null


func _sidecar(short: String) -> Variant:
	var p := "res://data/anim/hush3d/%s.json" % short
	if not FileAccess.file_exists(p):
		return null
	return TestBase.load_json(p)


## The clips of the list that exist (a missing one is reported as a named skip by the caller).
func _made() -> PackedStringArray:
	var out := PackedStringArray()
	for short in LIST:
		if FileAccess.file_exists("res://data/anim/hush3d/%s.json" % short):
			out.append(String(short))
	return out


func test_every_clip_of_the_list_is_made() -> void:
	var missing := PackedStringArray()
	for short in LIST:
		if not FileAccess.file_exists("res://data/anim/hush3d/%s.json" % short):
			missing.append(String(short))
	if not missing.is_empty():
		skip("%s not made yet — %s" % [", ".join(missing), OWNER])
		return
	assert_eq(_made().size(), LIST.size(), "all 18 clips of the list exist")


func test_sidecars_load_and_lengths_match() -> void:
	var made := _made()
	if made.is_empty():
		skip("no clip of the list made yet — %s" % OWNER)
		return
	var lib := _soft(CLIP_LIB)
	for short in made:
		var sc: Dictionary = _sidecar(short)
		var id := "hush/" + short
		assert_eq(String(sc.get("clip", "")), id, "%s: clip id = its file" % short)
		assert_eq(int(sc.get("version", 0)), 2, "%s: sidecar v2" % short)
		var a := load(String(sc.get("anim", ""))) as Animation
		if not assert_true(a != null, "%s: the .res loads as an Animation" % short):
			continue
		var n := int(sc.get("length", 0))
		assert_almost_eq(a.length * 60.0, float(n), 0.01, "%s: Animation.length = length / 60" % short)
		var want := int(LIST[short])
		if want > 0:
			assert_eq(n, want, "%s: %d f" % [short, want])
			assert_false(bool(sc.get("loop", false)), "%s: plays once" % short)
		elif want < 0:
			assert_true(bool(sc.get("loop", false)), "%s: a loop" % short)
		if lib != null:
			lib.call("invalidate", id)
			assert_true(lib.call("get_clip", id) != null, "%s: ClipLib3D.get_clip" % id)
			var probs: PackedStringArray = lib.call("problems", id)
			assert_eq(probs.size(), 0, "%s: ClipLib3D problems %s" % [id, str(probs)])


func test_lint_strict_clean() -> void:
	var made := _made()
	if made.is_empty():
		skip("no clip of the list made yet — %s" % OWNER)
		return
	for short in made:
		var fs: Array = L.make_strict(L.lint_clip_id("hush/" + short))
		var errs := PackedStringArray()
		for f in fs:
			if String((f as Dictionary)["severity"]) == "error":
				errs.append(L.format(f))
		assert_eq(errs.size(), 0, "hush/%s lints --strict clean: %s" % [short, "\n".join(errs)])


func test_band_fallbacks() -> void:
	var n_made := 0
	for short in BANDS:
		var v: Variant = _sidecar(short)
		if v == null:
			continue
		n_made += 1
		var sc: Dictionary = v
		assert_eq(String(sc.get("lock", "")), "rig_pm", "%s: normalised to rig progress (rig_pm)" % short)
		assert_ge(int(sc.get("length", 0)), 48, "%s: ≥ 48 f" % short)
		assert_false(bool(sc.get("loop", false)), "%s: does not loop" % short)
		assert_le(float(sc.get("cheat_deg", 99)), 10.0, "%s: cheat ≤ 10° while reaching" % short)
		for e in (sc.get("events", []) as Array):
			var ev: Dictionary = e
			if String(ev.get("type", "")) == "mark":
				assert_false(String(ev.get("name", "")).begins_with("glance"), "%s: no baked glance mark (f%d)" % [short, int(ev.get("f", -1))])
		var st: Variant = sc.get("stage", null)
		if assert_true(st is Dictionary, "%s: carries its stage (the view plays it with that facing)" % short):
			assert_eq(int((st as Dictionary).get("facing", 0)), 1, "%s: baked facing +1" % short)
	var hv: Variant = _sidecar("rig_high")
	if hv is Dictionary:
		var step: Variant = (hv as Dictionary).get("step", null)
		if assert_true(step is Dictionary, "rig_high: the mime step is recorded"):
			assert_eq(String((step as Dictionary).get("kind", "")), "mime", "rig_high: the mime's invisible step")
			var sup: Array = (step as Dictionary).get("support", [])
			assert_gt(sup.size(), 1, "rig_high: steps up")
			if not sup.is_empty():
				assert_almost_eq(float((sup[sup.size() - 1] as Array)[1]), 0.0, 0.0001, "rig_high ends on the floor")
			var top := 0.0
			for s in sup:
				top = maxf(top, float((s as Array)[1]))
			assert_between(top, 0.30, 0.45, "rig_high: the mime step is 0.30–0.45 m (R5c)")
	if n_made == 0:
		skip("rig_mid / rig_high / rig_low not made yet — %s" % OWNER)


func test_overlays_and_variants() -> void:
	var g: Variant = _sidecar("act_glance")
	if g is Dictionary:
		assert_eq(String((g as Dictionary).get("layer", "")), "overlay", "act_glance: an overlay")
		assert_eq(String((g as Dictionary).get("mask", "")), "head", "act_glance: head mask (the rig glances)")
	var s: Variant = _sidecar("st_shrug")
	if s is Dictionary:
		assert_eq(String((s as Dictionary).get("layer", "")), "overlay", "st_shrug: an overlay (clip_rules.json)")
		assert_eq(String((s as Dictionary).get("mask", "")), "upper", "st_shrug: upper mask")
	var m: Variant = _sidecar("freeze_midjob")
	if m is Dictionary:
		var md: Dictionary = m
		var n := int(md.get("length", 0))
		var vv: Variant = md.get("variants", null)
		if assert_true(vv is Dictionary, "freeze_midjob: sidecar variants"):
			var v: Dictionary = vv
			for band in ["mid", "high", "low"]:
				if assert_true(v.has(band), "freeze_midjob: a %s segment" % band):
					var seg: Array = v[band]
					assert_between(int(seg[0]), 0, n, "freeze_midjob %s start inside the clip" % band)
					assert_between(int(seg[1]), int(seg[0]), n, "freeze_midjob %s end inside the clip" % band)
			assert_eq(int((v["mid"] as Array)[0]), 0, "freeze_midjob: frame 0 is the mid statue (the default)")
			var holds: Array = (md.get("lint", {}) as Dictionary).get("freeze_holds", [])
			assert_eq(holds.size(), 3, "freeze_midjob: each segment is a freeze hold")
	if g == null and s == null and m == null:
		skip("act_glance / st_shrug / freeze_midjob not made yet — %s" % OWNER)


func test_statues_distinct_at_64px() -> void:
	var path := OS.get_environment("PWD").path_join(STATUES_JSON)
	if not FileAccess.file_exists(path):
		skip("64 px statue masks not rendered here (%s) — %s" % [STATUES_JSON, OWNER])
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not assert_true(d is Dictionary, "statues_8.json parses"):
		return
	var names: Array = (d as Dictionary).get("names", [])
	var iou: Array = (d as Dictionary).get("iou", [])
	for i in names.size():
		for j in range(i + 1, names.size()):
			assert_lt(float((iou[i] as Array)[j]), IOU_MAX, "%s vs %s: distinct silhouettes (IoU < %.2f)" % [names[i], names[j], IOU_MAX])
	for k in range(5, 9):
		assert_has(names, "freeze_%d" % k, "statue %d measured" % k)
