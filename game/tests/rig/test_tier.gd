## Tier / suppressed remap (GDD §5.8, TECH §5.3): the player's timeline length equals the
## sim's formula (TECH §3.7.4) for random clips; events and marks remap like the sim's
## ReactionDef.remap; T3 adds the falling prop + last beat; suppressed swaps the settle.
extends TestBase

const RIG := "_mannequin"
const REACTION_DEF := "res://sim/content/defs/reaction_def.gd"


func _random_clip(rng: RandomNumberGenerator, i: int) -> ClipDef:
	var frames := rng.randi_range(60, 240)
	var accent := rng.randi_range(10, frames / 3)
	var h0 := accent + rng.randi_range(2, 4)
	var h1 := rng.randi_range(h0 + 24, frames - 8)
	var d := {"version": 1, "clip": "_mannequin/rx_rand%d" % i, "rig": RIG, "length": frames, "blend_in": 0,
		"beats": {"anticipation": [maxi(0, accent - 12), accent], "accent": [accent, h0], "hold": [h0, h1], "settle": [h1, frames]},
		"keys": [{"f": 0, "pose": "m_stand"}, {"f": accent, "pose": "m_take_accent", "ease": "pop"},
			{"f": h1, "pose": "m_take_hold", "ease": "in_out_sine"}, {"f": frames, "pose": "m_take_settle", "ease": "out_back"}],
		"events": [{"f": accent, "type": "mark", "name": "accent"}, {"f": (h0 + h1) / 2, "type": "mark", "name": "knock_on"},
			{"f": h1, "type": "sfx", "id": "x"}, {"f": frames, "type": "mark", "name": "release"}]}
	return ClipLib.from_dict(d, d["clip"], RigDef.for_id(RIG), PoseLib.for_rig(RIG))


func test_lengths_equal_the_sim_formula_for_random_clips() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260929
	var rd: Script = load(REACTION_DEF) as Script if ResourceLoader.exists(REACTION_DEF) else null
	var supp := ClipLib.get_clip("_mannequin/beat_suppressed")
	if not assert_true(supp != null, "suppressed beat exists"):
		return
	assert_eq(supp.length, 60, "the suppressed beat is the sim's 60 frames")
	for i in 10:
		var c := _random_clip(rng, i)
		var h := c.beat("hold")
		var sim: Object = null
		if rd != null:
			sim = rd.call("from_dict", "rand%d" % i, {"clip": c.id, "frames": c.length,
				"marks": {"accent": c.beat("accent").x, "hold": [h.x, h.y], "release": c.length}})
		for tier in [1, 2, 3]:
			for sup in [false, true]:
				var plan := PlayPlan.build(c, {"tier": tier, "suppressed": sup, "suppressed_clip": supp.id})
				# Independent recomputation of TECH §3.7.4.
				var scale: int = [100, 100, 120, 150][tier]
				var want := c.length + ((h.y - h.x) * (scale - 100)) / 100
				if sup:
					want = want - (c.length - h.y) + 60
				assert_eq(plan.length, want, "clip %d tier %d suppressed %s" % [i, tier, sup])
				assert_eq(plan.length, PlayPlan.sim_length(c.length, h, tier, sup, 60))
				if sim != null:
					assert_eq(plan.length, int(sim.call("length", tier, sup)), "matches the sim's ReactionDef")
					for ev_i in plan.events.size():
						var ev: Dictionary = plan.events[ev_i]
						if String(ev.get("type", "")) == "mark" and ev.has("src_f") and not ev.has("synthetic"):
							assert_eq(int(ev["f"]), int(sim.call("remap", int(ev["src_f"]), tier)), "mark %s remaps like the sim" % ev.get("name", ""))
	if rd == null:
		skip("sim ReactionDef not built yet — formula checked against its own TECH §3.7.4 recomputation")


func test_hold_is_time_stretched_not_cut() -> void:
	var c := ClipLib.get_clip("_mannequin/rx_take")
	var p1 := PlayPlan.build(c, {"tier": 1})
	var p3 := PlayPlan.build(c, {"tier": 3})
	assert_eq(p1.length, 90)
	assert_eq(p3.extra, 18, "36 f hold × 1.5 = 54 f")
	assert_eq(p3.length, 108)
	assert_almost_eq(p3.src_frame(10.0), 10.0, 0.0001, "before the hold: unchanged")
	assert_almost_eq(p3.src_frame(33.0 + 27.0), 33.0 + 18.0, 0.0001, "mid-hold runs at 2/3 speed")
	assert_almost_eq(p3.src_frame(33.0 + 54.0), 69.0, 0.0001, "hold end lines up")
	assert_almost_eq(p3.src_frame(100.0), 82.0, 0.0001, "after the hold: shifted by extra")
	var a := RigDef.for_id(RIG).rest.duplicate()
	var b := RigDef.for_id(RIG).rest.duplicate()
	p1.sample(80.0, a)
	p3.sample(98.0, b)
	assert_eq(a, b, "the settle plays unchanged, 18 f later")


func test_tier_events() -> void:
	var c := ClipLib.get_clip("_mannequin/rx_take")
	var p2 := PlayPlan.build(c, {"tier": 2})
	var p3 := PlayPlan.build(c, {"tier": 3, "seed": 1})
	var shakes := 0
	for e in p2.events:
		if e.has("tier_extra"):
			shakes += 1
			assert_eq(int(e["f"]), 33, "the extra shake lands at the hold start")
	assert_eq(shakes, 1, "tier 2: one extra shake")
	var fall := {}
	for e2 in p3.events:
		if String(e2.get("type", "")) == "prop" and String(e2.get("op", "")) == "fall":
			fall = e2
	assert_false(fall.is_empty(), "tier 3: a falling-prop event")
	assert_eq(int(fall.get("src_f", -1)), 50, "at reactions.json t3_prop_f")
	assert_eq(int(fall.get("f", -1)), 33 + ((50 - 33) * 150) / 100, "remapped into the stretched hold")
	assert_eq(p3.last_beat, "_mannequin/beat_slow_burn", "tier 3 appends a last beat")
	for i in p3.ev_f.size() - 1:
		assert_le(p3.ev_f[i], p3.ev_f[i + 1], "events stay sorted")
	var rel := -1
	for e3 in p3.events:
		if String(e3.get("type", "")) == "mark" and String(e3.get("name", "")) == "release":
			rel = int(e3["f"])
	assert_eq(rel, p3.length, "release mark at the stretched end")


func test_suppressed_swaps_the_settle_for_the_suppressed_beat() -> void:
	var c := ClipLib.get_clip("_mannequin/rx_take")
	var p := PlayPlan.build(c, {"suppressed": true})
	assert_true(p.suppressed)
	assert_eq(p.tail_start, 69)
	assert_eq(p.length, 69 + 60)
	assert_eq(p.clip_at(70.0).id, "_mannequin/beat_suppressed")
	var has_thud := false
	var has_release := false
	for e in p.events:
		if String(e.get("id", "")) == "thud":
			has_thud = true
		if String(e.get("name", "")) == "release":
			has_release = int(e["f"]) == p.length
	assert_false(has_thud, "settle events are dropped")
	assert_true(has_release, "release moves to the end of the suppressed beat")
	# The tail crossfades from the hold's last pose (no pop).
	var rig := RigDef.for_id(RIG)
	var at_h := rig.rest.duplicate()
	var first := rig.rest.duplicate()
	RigSampler.sample(c, 69.0, at_h)
	p.sample(69.0, first)
	var arm := RigDef.ch(rig.idx("arm_upper_r"), RigDef.C_ROT)
	assert_almost_eq(first[arm], at_h[arm], 0.001, "tail starts from the hold pose")


func test_loops_and_holdless_clips_ignore_tiers() -> void:
	var walk := ClipLib.get_clip("_mannequin/loco_walk")
	var p := PlayPlan.build(walk, {"tier": 3})
	assert_eq(p.length, walk.length)
	assert_eq(p.tier, 1)
	assert_false(p.warnings.is_empty(), "the caller is told why")
