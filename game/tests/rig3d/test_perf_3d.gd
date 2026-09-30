## Per-character budget (REDESIGN §5.6, r3d-rig §7): the player's frame cost (clock + tree + events + face +
## modifiers) ≤ 0.25 ms median of 5 on the cast rigs (skipped until a clip is baked for the rig), no objects created
## per frame, warm() ≤ 20 ms, ≤ 4 draw calls per character.
extends TestBase

const Env := preload("res://tests/rig3d/fixtures/fix_env.gd")
const BUDGET_US := 250.0

var _players: Array[RigPlayer3D] = []


func before_each() -> void:
	Env.push()


func after_each() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.get_parent().remove_child(p)
			p.free()
	_players.clear()
	Env.pop()


func _make(rig: String) -> RigPlayer3D:
	var p := RigPlayer3D.new()
	p.auto_advance = false
	tree.root.add_child(p)
	_players.append(p)
	p.setup(rig)
	return p


## Median of 5 blocks, each the median µs of 60 frames.
func _median_cost(p: RigPlayer3D) -> float:
	for i in 30:
		p.advance(1.0 / 60.0)
	var blocks := PackedFloat32Array()
	for b in 5:
		var prof := RigProfile3D.new()
		for i in 60:
			prof.step(p, 1.0 / 60.0)
		var s := prof.samples_us.duplicate()
		s.sort()
		blocks.append(s[s.size() / 2])
	blocks.sort()
	return blocks[2]


func test_fixture_cost_and_no_per_frame_objects() -> void:
	var p := _make("fix")
	p.play("fix/loco_walk")
	p.play_overlay("fix/mg_wave", "upper", 6)
	var us := _median_cost(p)
	assert_lt(us, BUDGET_US * cpu_load_scale(), "fixture: %.0f µs / frame" % us)
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in 300:
		p.advance(1.0 / 60.0)
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_le(after - before, 0, "no objects created per frame (%d → %d)" % [before, after])


func test_cast_rigs_within_budget() -> void:
	var measured := 0
	for rig in ["hush", "bellows"]:
		if not RigDef3D.exists(rig):
			continue
		var clips := ClipLib3D.clips_of(rig)
		var pick := ""
		for c in clips:
			if ClipLib3D.animation(c) != null:
				pick = c
				break
		var p := _make(rig)
		if not assert_true(p.ok, "%s sets up" % rig):
			continue
		var counts := RigProfile3D.rig_counts(p)
		assert_le(int(counts["draw_calls"]), 4, "%s: ≤ 4 draw calls (%s)" % [rig, counts])
		assert_le(int(counts["tris"]), 10000, "%s: ≤ 10k triangles" % rig)
		var t0 := Time.get_ticks_usec()
		p.warm()
		p.advance(1.0 / 60.0)
		p.advance(1.0 / 60.0)
		var warm_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		assert_lt(warm_ms, 20.0 * cpu_load_scale(), "%s: warm() in %.1f ms" % [rig, warm_ms])
		if pick == "":
			continue
		p.play(pick, {"loop": true})
		var us := _median_cost(p)
		print("[perf3d] %s %s: %.0f µs / frame (median of 5)" % [rig, pick, us])
		assert_lt(us, BUDGET_US * cpu_load_scale(), "%s: %.0f µs / frame" % [rig, us])
		measured += 1
	if measured == 0:
		skip("no baked clip on the cast rigs yet — r3d-anim (RigPerf3D numbers are in the r3d-rig report)")
