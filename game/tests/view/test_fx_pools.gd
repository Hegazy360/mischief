## FX pools never grow (TECH §5.7, §9): the whole ViewSandbox stack runs 600+ frames of the
## FakeWorld timeline through its gags, bursts, captions, stamps, rings and the Busted Cam,
## and `Performance.OBJECT_COUNT` stays flat after warm-up; particles stay within budget.
extends TestBase

const DT := 1.0 / 60.0

var _sb: ViewSandbox = null
var _audio: Node = null


func before_each() -> void:
	# This test measures the VIEW's pools. The Audio autoload's players each keep their last
	# AudioStreamPlayback and pick random variants, so detach it (AudioDirector no-ops without it)
	# and put it back in after_each.
	_audio = tree.root.get_node_or_null("Audio")
	if _audio != null:
		tree.root.remove_child(_audio)
	_sb = ViewSandbox.new()
	_sb.scenario = "gag_punch"
	tree.root.add_child(_sb)
	await tree.process_frame
	_sb.set_process(false)


func after_each() -> void:
	_sb.queue_free()
	await tree.process_frame
	if _audio != null:
		tree.root.add_child(_audio)
		_audio = null


func _frames(n: int) -> void:
	for i in n:
		_sb._process(DT)


func test_object_count_is_stable_over_600_frames() -> void:
	# Pass 1 warms every lazy cache the window touches (first-use textures, glyphs, icons);
	# pass 2 replays the same 720 frames from the same tick and must not grow.
	var start := _sb.driver.snapshot().tick
	_frames(720)
	_replay_from(start)
	_frames(120)      # the first gag, captions, particles
	var o0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var peak_particles := 0
	var peak_emitters := 0
	for i in 600:
		_sb._process(DT)
		peak_particles = maxi(peak_particles, _sb.world_view.fx.particles.live_particles())
		peak_emitters = maxi(peak_emitters, _sb.world_view.fx.particles.active_emitters())
	var o1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_le(absi(o1 - o0), 2, "objects %d → %d" % [o0, o1])
	assert_le(peak_particles, FxParticlePool.PARTICLE_BUDGET)
	assert_le(peak_emitters, FxParticlePool.MAX_EMITTERS)
	assert_gt(peak_particles, 0, "the timeline did burst")


func _replay_from(t: int) -> void:
	_sb.driver.reset()
	_sb.world_view.reset()
	_sb._seek(t)


func test_pools_are_fixed_size() -> void:
	var fx := _sb.world_view.fx
	assert_eq(fx.particles.emitter_count(), FxParticlePool.MAX_EMITTERS)
	for i in 20:
		fx.caption("TEST!", Vector2(3000, -500))
		fx.stamp("COMBO! +4", Vector2(3000, -500))
		fx.burst("feathers", Vector2(3000, -300), 60)
		fx.noise_ring(Vector2(3000, -60), 500.0)
	assert_le(fx.captions_active(), FxLayer.CAPTIONS)
	assert_le(fx.stamps_active(), FxLayer.STAMPS)
	assert_le(fx.particles.live_particles(), FxParticlePool.PARTICLE_BUDGET)
	assert_le(fx.rings.alive(), FxNoiseRings.RINGS)


func test_busted_cam_replays_the_spot() -> void:
	_sb.world_view.reset()
	_sb._seek(2520)
	var seen := false
	for i in 90:
		_sb._process(DT)
		seen = seen or _sb.world_view.is_replaying()
	assert_true(seen, "the catch at 2550 starts the Busted Cam replay")
	assert_gt(_sb.world_view.busted.replay_count(), 30)
	var f := _sb.world_view.busted.replay_frame(0)
	assert_le(f.tick, 2470, "the replay starts before the ! at 2470")


func test_big_captions_never_stack() -> void:
	var fx := _sb.world_view.fx
	fx.clear()
	var a := fx.caption("POODLE!", Vector2(3000, -500), 80)
	assert_true(a != null and a.active)
	# Deferred while the first is being read, then it stamps in and the first fades.
	var b := fx.caption("MELTDOWN!", Vector2(3000, -470), 96, null, true, true)
	assert_true(b == null, "deferred while POODLE! is fresh")
	assert_eq(fx.captions_active(), 1)
	for i in 30:
		fx.advance(DT)
	assert_eq(fx.captions_active(), 1, "still waiting at 0.5 s")
	for i in 30:
		fx.advance(DT)
	assert_eq(fx.captions_active(), 2, "MELTDOWN! shown once POODLE! was read")
	for i in 15:
		fx.advance(DT)
	assert_false(a.active, "the older big caption faded out")
	# An immediate big caption retires the older one at once (no overlap beyond the fade).
	var c := fx.caption("TAP DANCE!", Vector2(3050, -500), 88)
	for i in 15:
		fx.advance(DT)
	assert_true(c.active)
	assert_eq(fx.captions_active(), 1)
