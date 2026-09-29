## Rig performance (TECH §9): sampling 20+ parts × 1,000 frames allocates no objects after
## warm-up and fits the time budget; a full RigPlayer update fits the per-character budget.
## Time budgets are loose ceilings (CI and dev machines are shared and noisy); the measured
## numbers are printed for the report. Allocation checks are strict. Draw calls and _draw CPU
## are measured by the DevShot run of scenes/dev/RigPerf.tscn.
extends TestBase

const RIG := "_mannequin"


func test_sampler_is_allocation_free_and_fast() -> void:
	var rig := RigDef.for_id(RIG)
	assert_ge(rig.names.size(), 20, "a 20-part rig")
	var clips: Array[ClipDef] = [ClipLib.get_clip("_mannequin/rx_take"), ClipLib.get_clip("_mannequin/loco_walk"),
		ClipLib.get_clip("_mannequin/rx_land")]
	var plan := PlayPlan.build(clips[0], {"tier": 3, "suppressed": true})
	var out := rig.rest.duplicate()
	var other := rig.rest.duplicate()
	var xf: Array[Transform2D] = []
	var evs: Array = []
	# Warm-up (lazy caches, the event buffer's growth).
	for f in 200:
		RigSampler.sample(clips[f % 3], float(f) * 0.37, out)
		plan.sample(float(f), other)
		RigSampler.blend(out, other, 0.5, out)
		RigSampler.solve(rig, out, xf)
		plan.between_into(float(f) - 1.0, float(f), evs)
	var objects0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var t0 := Time.get_ticks_usec()
	for f2 in 1000:
		var fr := float(f2) * 0.37
		RigSampler.sample(clips[f2 % 3], fr, out)
		plan.sample(fmod(fr, float(plan.length)), other)
		RigSampler.blend(out, other, 0.5, out)
		RigSampler.apply_mask(out, other, _mask, 0.5)
		RigSampler.breathe(rig, out, fr / 60.0)
		RigSampler.clamp_limits(rig, out)
		RigSampler.solve(rig, out, xf)
		plan.between_into(fr - 1.0, fr, evs)
	var us := Time.get_ticks_usec() - t0
	var objects1 := Performance.get_monitor(Performance.OBJECT_COUNT)
	assert_eq(objects1, objects0, "no objects allocated while sampling")
	var per := float(us) / 1000.0 / 1000.0
	print("  [perf] sample+plan+blend+mask+breathe+limits+FK: %.4f ms/frame (%d parts)" % [per, rig.names.size()])
	assert_lt(per, 0.5, "sampling ceiling (%.4f ms/frame)" % per)


var _mask: PackedByteArray = PackedByteArray()


func before_each() -> void:
	_mask = RigDef.for_id(RIG).mask_from("upper")


func test_player_update_budget() -> void:
	var p := RigPlayer.new()
	p.manual = true
	tree.root.add_child(p)
	p.setup(RIG)
	p.play("_mannequin/loco_walk", {"speed": 200.0})
	for i in 120:
		p.advance(1.0 / 60.0)
	var objects0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var t0 := Time.get_ticks_usec()
	for i in 600:
		p.advance(1.0 / 60.0)
		if i == 300:
			p.play("_mannequin/rx_take", {"tier": 2})
	var us := Time.get_ticks_usec() - t0
	var per := float(us) / 600.0 / 1000.0
	print("  [perf] RigPlayer.advance (all layers, springs, face, smears): %.4f ms/frame" % per)
	assert_lt(per, 0.5, "player update ceiling (%.4f ms/frame)" % per)
	var grown := Performance.get_monitor(Performance.OBJECT_COUNT) - objects0
	assert_le(grown, 2.0, "no per-frame object churn (play() builds one PlayPlan)")
	p.free()


func test_atlas_build_time() -> void:
	var rig := RigDef.for_id(RIG)
	AtlasBuilder.forget("perf:atlas")
	var t0 := Time.get_ticks_msec()
	var set := AtlasBuilder.build("perf:atlas", rig.all_texture_paths(), 2.0)
	var ms := Time.get_ticks_msec() - t0
	print("  [perf] mannequin atlas (%d images, %s px page, %.1f %% packed): %d ms" % [set.paths().size(), set.page_sizes[0], set.pack_ratio() * 100.0, ms])
	assert_lt(ms, 3000, "atlas builds in < 3 s on desktop")
	AtlasBuilder.forget("perf:atlas")
