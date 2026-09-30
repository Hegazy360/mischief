## REDESIGN_3D §6.2 C4 — the view data the 3D slice reads per prank (`r3d-index.md` §7.10): `data/view/previews.json`
## (what joke each spot's cloud shows, REDESIGN §4.3 BEFORE) and `data/anim/hush3d/rig_actions.json` (tier, reach
## band, action clip, prop animation, held prop, step, glance marks, noise rings). Tiers and hotspots equal
## `pranks.json`; once `house3d.json` exists (`r3d-sets`), every band and step equals its placed reach target and
## `reach_pos.step` (the sets test checks the same data from its side). The rules live in `ViewDataLint`.
extends TestBase

const PREVIEWS := "res://data/view/previews.json"
const RIG_ACTIONS := "res://data/anim/hush3d/rig_actions.json"
const HOUSE3D := "res://data/house/house3d.json"
## REDESIGN §4.3 BEFORE column — the pictogram ids `r3d-hud` draws.
const PICTOGRAMS := {
	"achoo_ria": ["nose", "star_burst"], "allegro_go_go": ["record", "x3", "spiral"],
	"kettle_drum": ["kettle", "notes", "crack"], "tap_dance": ["tap", "water_jet", "face"],
	"in_a_pickle": ["jar", "straining_arm", "onions"], "lift_off": ["chair", "spring", "up_arrow", "chandelier"],
	"cold_open": ["fridge", "avalanche", "jelly_helmet"], "eye_popping_news": ["newspaper", "magnifier", "ballooned_eyes"],
	"something_fishy": ["phone", "fish"], "times_up": ["clock", "zigzag", "exclaim"], "mirror_mirror": ["oval_face", "wink"],
}
## The brief's §4.4 values: [tier, clip, held, glances, noise_rings].
const ACTIONS := {
	"achoo_ria": ["q", "hush/rig_achoo_ria", "pepper_pot", [], false],
	"allegro_go_go": ["q", "hush/rig_allegro_go_go", null, [], false],
	"kettle_drum": ["q", null, "squeaker", [], false], "tap_dance": ["q", null, null, [], false],
	"in_a_pickle": ["s", null, null, [500], false], "lift_off": ["b", null, null, [300, 600, 900], true],
	"cold_open": ["s", null, null, [300, 700], false], "eye_popping_news": ["q", null, "magnifier", [], false],
	"something_fishy": ["q", null, "kipper", [], false], "times_up": ["s", null, null, [300, 700], false],
	"mirror_mirror": ["b", null, null, [300, 700], true],
}

var _data: SolverData = null


func before_each() -> void:
	if _data == null:
		_data = SolverData.load_dir("res://data")


func test_previews_cover_every_slice_prank_with_its_joke() -> void:
	var p: Variant = TestBase.load_json(PREVIEWS)
	if not assert_true(p is Dictionary, PREVIEWS):
		return
	assert_eq(int((p as Dictionary).get("version", 0)), 1)
	var pr: Dictionary = (p as Dictionary).get("pranks", {})
	for id in PICTOGRAMS:
		if not assert_true(pr.has(id), "previews.%s" % id):
			continue
		var e: Dictionary = pr[id]
		assert_eq(e.get("pictogram", []), PICTOGRAMS[id], "%s pictogram (REDESIGN §4.3)" % id)
		var need: Variant = e.get("needs", "missing")
		var want: Variant = _data.step_needs(id, 0) if _data.step_needs(id, 0) != "" else null
		assert_eq(need, want, "%s needs = its item" % id)
	var ach: Array = (pr.get("achoo_ria", {}) as Dictionary).get("combines", [])
	assert_eq(ach, [{"with": "tap_dance", "badge": "to_sink"}], "HOT & COLD: the honey's preview gets the → sink badge")
	assert_eq(ViewDataLint.check_previews(p, _data, ViewDataLint.slice_pranks(_data)), PackedStringArray())


func test_rig_actions_carry_the_tiers_bands_and_actions() -> void:
	var r: Variant = TestBase.load_json(RIG_ACTIONS)
	if not assert_true(r is Dictionary, RIG_ACTIONS):
		return
	var d: Dictionary = r
	assert_eq(int(d.get("version", 0)), 1)
	assert_eq(d.get("tiers", {}), {"q": 48, "s": 90, "b": 150}, "tiers = the prep tiers 0.8 / 1.5 / 2.5 s")
	var bands: Dictionary = d.get("bands", {})
	assert_eq((bands.get("low", {}) as Dictionary).get("glove_y_m", []), [0.0, 0.55])
	assert_eq((bands.get("mid", {}) as Dictionary).get("glove_y_m", []), [0.55, 1.4])
	assert_eq((bands.get("high", {}) as Dictionary).get("glove_y_m", []), [1.4, 2.15])
	assert_almost_eq(float((bands.get("high", {}) as Dictionary).get("step_above_m", 0.0)), 1.70, 0.001)
	for b in ["low", "mid", "high"]:
		assert_eq((bands.get(b, {}) as Dictionary).get("clip", ""), "hush/rig_%s" % b)
	var pr: Dictionary = d.get("pranks", {})
	for id in ACTIONS:
		if not assert_true(pr.has(id), "rig_actions.%s" % id):
			continue
		var e: Dictionary = pr[id]
		var want: Array = ACTIONS[id]
		assert_eq(e.get("hotspot", ""), _data.rig_point(id, 0), "%s hotspot = pranks.json rig_point" % id)
		assert_eq(e.get("tier", ""), want[0], "%s tier" % id)
		assert_eq(int(d["tiers"][e.get("tier", "q")]), _data.step_prep_ticks(id, 0), "%s tier = pranks.json prep" % id)
		assert_eq(e.get("clip", "missing"), want[1], "%s clip" % id)
		assert_eq(e.get("held", "missing"), want[2], "%s held" % id)
		assert_eq(e.get("glances", []), want[3], "%s glances (‰ of rig progress)" % id)
		assert_eq(e.get("noise_rings", null), want[4], "%s noise rings" % id)
		assert_eq(e.get("prop_anim", ""), "rig", "%s prop anim" % id)
	assert_eq((pr["achoo_ria"] as Dictionary).get("step", null), "stool:kitchen_stool", "ACHOO-RIA! climbs Bellows' stool")
	for id in ["times_up", "mirror_mirror"]:
		assert_eq((pr[id] as Dictionary).get("step", null), "mime", "%s: above 1.70 m, the mime's invisible step (house3d.json)" % id)
	assert_eq(ViewDataLint.check_rig_actions(r, _data, ViewDataLint.slice_pranks(_data), null), PackedStringArray())


func test_bands_and_steps_equal_the_placed_reach_targets() -> void:
	if not FileAccess.file_exists(HOUSE3D):
		skip("house3d.json not built yet — r3d-sets P0")
		return
	var h3: Variant = TestBase.load_json(HOUSE3D)
	var r: Variant = TestBase.load_json(RIG_ACTIONS)
	var errs := ViewDataLint.check_rig_actions(r, _data, ViewDataLint.slice_pranks(_data), h3)
	assert_eq(errs, PackedStringArray(), "rig_actions.json bands / steps = house3d.json's placed reach targets")
	var derived := ViewDataLint.derive_reach(h3, (r as Dictionary).get("pranks", {}).keys(), _data)
	for id in derived:
		var e: Dictionary = (r as Dictionary)["pranks"][id]
		assert_eq(e.get("band", ""), (derived[id] as Dictionary).get("band", ""), "%s band" % id)
		assert_eq(e.get("step", null), (derived[id] as Dictionary).get("step", null), "%s step" % id)


func test_the_lint_catches_bad_view_data() -> void:
	var sl := ViewDataLint.slice_pranks(_data)
	var p := {"version": 1, "pranks": {"achoo_ria": {"pictogram": [], "needs": "squeaker", "combines": [{"with": "nope", "badge": ""}]}}}
	var e := ViewDataLint.check_previews(p, _data, sl)
	assert_true(_has(e, "previews.json: allegro_go_go missing"), str(e))
	assert_true(_has(e, "achoo_ria.pictogram is empty"), str(e))
	assert_true(_has(e, "achoo_ria.needs 'squeaker'"), str(e))
	assert_true(_has(e, "achoo_ria.combines.with 'nope'"), str(e))
	var r := {"version": 1, "tiers": {"q": 48, "s": 90, "b": 150}, "bands": {}, "pranks": {"achoo_ria": {"hotspot": "kitchen_kettle",
		"tier": "s", "band": "top", "clip": 3, "prop_anim": "rig", "held": null, "step": "ladder", "glances": [700, 300], "noise_rings": 1}}}
	e = ViewDataLint.check_rig_actions(r, _data, sl, null)
	for needle in ["bands.mid missing", "achoo_ria.hotspot 'kitchen_kettle'", "achoo_ria.tier 's'", "achoo_ria.band 'top'",
			"achoo_ria.clip", "achoo_ria.step 'ladder'", "achoo_ria.glances", "achoo_ria.noise_rings", "rig_actions.json: tap_dance missing"]:
		assert_true(_has(e, needle), "%s in %s" % [needle, str(e)])


func _has(errs: PackedStringArray, needle: String) -> bool:
	for x in errs:
		if x.contains(needle):
			return true
	return false
