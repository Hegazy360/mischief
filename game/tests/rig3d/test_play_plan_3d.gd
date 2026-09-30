## PlayPlan3D (GDD §5.8, TECH §5.3 — the 2D test_tier.gd cases on 3D clips): lengths equal the sim formula, the hold
## is time-stretched (not cut), tier events, the suppressed tail, holdless clips ignore tiers, events between frames
## incl. loop wrap and tier remap (none twice), rig progress ‰ → frame.
extends TestBase

const Env := preload("res://tests/rig3d/fixtures/fix_env.gd")
const REACTION_DEF := "res://sim/content/defs/reaction_def.gd"


func before_each() -> void:
	Env.push()


func after_each() -> void:
	Env.pop()


func _random_clip(rng: RandomNumberGenerator, i: int) -> ClipDef3D:
	var frames := rng.randi_range(60, 240)
	var accent := rng.randi_range(10, frames / 3)
	var h0 := accent + rng.randi_range(2, 4)
	var h1 := rng.randi_range(h0 + 24, frames - 8)
	var d := {"version": 2, "format": "anim3d", "clip": "fix/rx_rand%d" % i, "rig": "fix", "anim": "res://none.res",
		"length": frames, "blend_in": 0,
		"beats": {"anticipation": [maxi(0, accent - 12), accent], "accent": [accent, h0], "hold": [h0, h1], "settle": [h1, frames]},
		"events": [{"f": accent, "type": "mark", "name": "accent"}, {"f": (h0 + h1) / 2, "type": "mark", "name": "knock_on"},
			{"f": h1, "type": "sfx", "id": "x"}, {"f": frames, "type": "mark", "name": "release"}]}
	return ClipDef3D.from_dict(d["clip"], d, "")


func test_lengths_equal_the_sim_formula_for_random_clips() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260930
	var rd: Script = load(REACTION_DEF) as Script if ResourceLoader.exists(REACTION_DEF) else null
	var supp := ClipLib3D.get_clip("fix/beat_suppressed")
	if not assert_true(supp != null, "suppressed beat exists"):
		return
	for i in 10:
		var c := _random_clip(rng, i)
		var h: Vector2i = c.beats["hold"]
		var sim: Object = null
		if rd != null:
			sim = rd.call("from_dict", "rand%d" % i, {"clip": c.id, "frames": c.length,
				"marks": {"accent": c.mark("accent"), "hold": [h.x, h.y], "release": c.length}})
		for tier in [1, 2, 3]:
			for sup in [false, true]:
				var plan := PlayPlan3D.build(c, {"tier": tier, "suppressed": sup, "suppressed_clip": supp.id})
				var scale: int = [100, 100, 120, 150][tier]
				var want := c.length + ((h.y - h.x) * (scale - 100)) / 100
				if sup:
					want = want - (c.length - h.y) + 60
				assert_eq(plan.length, want, "clip %d tier %d suppressed %s" % [i, tier, sup])
				assert_eq(plan.length, PlayPlan3D.sim_length(c.length, h, tier, sup, 60))
				if sim != null:
					assert_eq(plan.length, int(sim.call("length", tier, sup)), "matches the sim's ReactionDef")
					for ev in plan.events:
						if String(ev.get("type", "")) == "mark" and ev.has("src_f") and not ev.has("synthetic"):
							assert_eq(int(ev["f"]), int(sim.call("remap", int(ev["src_f"]), tier)), "mark remaps like the sim")


func test_hold_is_time_stretched_not_cut() -> void:
	var c := ClipLib3D.get_clip("fix/rx_take")
	var p1 := PlayPlan3D.build(c, {"tier": 1})
	var p3 := PlayPlan3D.build(c, {"tier": 3})
	assert_eq(p1.length, 90)
	assert_eq(p3.extra, 18, "36 f hold × 1.5 = 54 f")
	assert_eq(p3.length, 108)
	assert_almost_eq(p3.src_frame(10.0), 10.0, 0.0001, "before the hold: unchanged")
	assert_almost_eq(p3.src_frame(33.0 + 27.0), 33.0 + 18.0, 0.0001, "mid-hold runs at 2/3 speed")
	assert_almost_eq(p3.src_frame(33.0 + 54.0), 69.0, 0.0001, "hold end lines up")
	assert_almost_eq(p3.src_frame(100.0), 82.0, 0.0001, "after the hold: shifted by extra")
	assert_almost_eq(p3.frame_at(98.0), p1.frame_at(80.0), 0.0001, "the settle plays unchanged, 18 f later")


func test_tier_events() -> void:
	var c := ClipLib3D.get_clip("fix/rx_take")
	var p2 := PlayPlan3D.build(c, {"tier": 2})
	var p3 := PlayPlan3D.build(c, {"tier": 3, "seed": 1})
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
	assert_eq(p3.last_beat, "fix/beat_slow_burn", "tier 3 appends a last beat")
	for i in p3.ev_f.size() - 1:
		assert_le(p3.ev_f[i], p3.ev_f[i + 1], "events stay sorted")
	var rel := -1
	for e3 in p3.events:
		if String(e3.get("type", "")) == "mark" and String(e3.get("name", "")) == "release":
			rel = int(e3["f"])
	assert_eq(rel, p3.length, "release mark at the stretched end")


func test_suppressed_swaps_the_settle_for_the_suppressed_beat() -> void:
	var c := ClipLib3D.get_clip("fix/rx_take")
	var p := PlayPlan3D.build(c, {"suppressed": true})
	assert_true(p.suppressed)
	assert_eq(p.tail_start, 69)
	assert_eq(p.length, 69 + 60)
	assert_eq(p.clip_at(70.0).id, "fix/beat_suppressed")
	assert_almost_eq(p.frame_at(70.0), 1.0, 0.0001, "the tail's own frame")
	var has_thud := false
	var has_release := false
	var has_ha := false
	for e in p.events:
		if String(e.get("id", "")) == "thud":
			has_thud = true
		if String(e.get("id", "")) == "vo_ha":
			has_ha = int(e["f"]) == 69 + 44
		if String(e.get("name", "")) == "release":
			has_release = int(e["f"]) == p.length
	assert_false(has_thud, "settle events are dropped")
	assert_true(has_ha, "the tail's events shift to the tail start")
	assert_true(has_release, "release moves to the end of the suppressed beat")


func test_loops_and_holdless_clips_ignore_tiers() -> void:
	var walk := ClipLib3D.get_clip("fix/loco_walk")
	var p := PlayPlan3D.build(walk, {"tier": 3})
	assert_eq(p.length, walk.length)
	assert_eq(p.tier, 1)
	assert_false(p.warnings.is_empty(), "the caller is told why")


func test_events_between_with_wrap_and_remap_never_twice() -> void:
	var walk := ClipLib3D.get_clip("fix/loco_walk")
	var out := []
	assert_eq(ClipEvents3D.between_into(walk, -1.0, 0.0, out), 1, "frame-0 events fire from −1")
	assert_eq(ClipEvents3D.between_into(walk, 0.0, 39.9, out), 0)
	assert_eq(ClipEvents3D.between_into(walk, 39.9, 40.0, out), 1, "f0 < f ≤ f1")
	assert_eq(ClipEvents3D.between_into(walk, 70.0, 5.0, out), 1, "a wrap (f1 < f0) crosses frame 0 of the next cycle")
	# Walk a looping clip across 3 cycles in uneven steps: every event exactly once per cycle.
	var plan := PlayPlan3D.plain(walk)
	var seen := 0
	var prev := -1.0
	var t := 0.0
	var steps := [0.7, 1.3, 2.9, 0.1, 5.0]
	var k := 0
	while true:
		var nt := minf(t + float(steps[k % steps.size()]), 239.5)
		k += 1
		var cur := fmod(nt, 80.0)
		seen += plan.between_into(prev, cur, out)
		prev = cur
		t = nt
		if nt >= 239.5:
			break
	assert_eq(seen, 6, "2 steps × 3 cycles, no event twice")
	# Tier remap: the tier-3 timeline crosses every event once from −1 to its end.
	var c := ClipLib3D.get_clip("fix/rx_take")
	var p3 := PlayPlan3D.build(c, {"tier": 3, "seed": 1})
	var n := 0
	var ff := -1.0
	while ff < float(p3.length):
		var nf := minf(ff + 1.7, float(p3.length))
		n += p3.between_into(ff, nf, out)
		ff = nf
	assert_eq(n, p3.events.size(), "every remapped event once")


func test_rig_progress_maps_to_frames() -> void:
	var c := ClipLib3D.get_clip("fix/rx_take")
	assert_almost_eq(PlayPlan3D.rig_frame(c, 0.0), 0.0)
	assert_almost_eq(PlayPlan3D.rig_frame(c, 500.0), 45.0)
	assert_almost_eq(PlayPlan3D.rig_frame(c, 1000.0), 90.0)
	assert_almost_eq(PlayPlan3D.rig_frame(c, 1500.0), 90.0, 0.0001, "clamped")
