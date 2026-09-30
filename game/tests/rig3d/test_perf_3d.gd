## Per-character budget (REDESIGN §5.6, r3d-rig §7): the player's frame cost (clock + tree + events + face +
## modifiers) ≤ 0.25 ms median of 5 on the cast rigs (skipped until a clip is baked for the rig), no objects created
## per frame, prepare_clips ≤ 3 ms a clip, warm() ≤ 20 ms once the clips are prepared, ≤ 4 draw calls per character;
## after prepare_clips a play() loads / builds / adds nothing (no new Animation, no new object), a clip switch with
## unchanged looks runs no looks pass, and a clip churn (a switch every 10 frames, D14 fix pass 2) keeps play() and
## the frame after it cheap.
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
		var tp := Time.get_ticks_usec()
		var prepared := p.prepare_all_clips()
		var prep_ms := float(Time.get_ticks_usec() - tp) / 1000.0
		assert_lt(prep_ms, 3.0 * float(maxi(1, prepared)) * cpu_load_scale(),
			"%s: prepare_all_clips %d clips in %.1f ms" % [rig, prepared, prep_ms])
		var t0 := Time.get_ticks_usec()
		p.warm()
		p.advance(1.0 / 60.0)
		p.advance(1.0 / 60.0)
		var warm_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		assert_lt(warm_ms, 20.0 * cpu_load_scale(), "%s: warm() in %.1f ms (clips prepared)" % [rig, warm_ms])
		if pick == "":
			continue
		p.play(pick, {"loop": true})
		var us := _median_cost(p)
		print("[perf3d] %s %s: %.0f µs / frame (median of 5)" % [rig, pick, us])
		assert_lt(us, BUDGET_US * cpu_load_scale(), "%s: %.0f µs / frame" % [rig, us])
		measured += 1
	if measured == 0:
		skip("no baked clip on the cast rigs yet — r3d-anim (RigPerf3D numbers are in the r3d-rig report)")


## The base clips of `rig` with a baked Animation on disk (nothing loaded).
func _base_clips(rig: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ClipLib3D.clips_of(rig):
		var c := ClipLib3D.get_clip(id)
		if c != null and c.layer != "overlay" and c.anim_path != "" and ResourceLoader.exists(c.anim_path):
			out.append(id)
	return out


func _lib_count(p: RigPlayer3D) -> int:
	var n := 0
	for ln in p.tree.get_animation_library_list():
		n += p.tree.get_animation_library(ln).get_animation_list().size()
	return n


func test_play_after_prepare_allocates_nothing() -> void:
	var p := _make("fix")
	var ids := _base_clips("fix")
	assert_gt(ids.size(), 2, "fixture has base clips")
	assert_eq(p.prepare_clips(ids), ids.size(), "every fixture clip prepared")
	assert_eq(p.prepare_clips(ids), ids.size(), "idempotent")
	var libs := _lib_count(p)
	var anims := {}
	for id in ids:
		anims[id] = ClipLib3D.animation(id)
	p.play(ids[0])
	p.advance(1.0 / 60.0)
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var passes := 0
	for k in 3:
		for id in ids:
			p.play(id)
			p.advance(1.0 / 60.0)
			p.play(id, {"loop": true})
			p.advance(1.0 / 60.0)
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_le(after - before, 0, "play() after prepare_clips creates no object — no Animation, plan or library (%d → %d)" % [before, after])
	assert_eq(_lib_count(p), libs, "no library entry added by play()")
	for id2 in ids:
		assert_true(ClipLib3D.animation(id2) == anims[id2], "%s: the same Animation (nothing re-loaded)" % id2)
	p.reset(true)
	passes = p.looks_passes
	for k2 in 5:
		p.play("fix/loco_walk")
		p.advance(1.0 / 60.0)
		p.play("fix/loco_idle")
		p.advance(1.0 / 60.0)
	assert_eq(p.looks_passes, passes, "a clip switch with unchanged looks runs no looks pass")
	p.set_body_slot("bouffant", "flipped", &"residue")
	assert_eq(p.looks_passes, passes + 1, "a look change runs one looks pass")
	# A tiered play still builds its own plan (tier remap) — the cached plain plan is never mutated.
	p.play("fix/rx_sneeze", {"tier": 3, "seed": 1})
	var tiered := p.plan()
	p.play("fix/rx_sneeze")
	assert_ne(p.plan(), tiered, "a plain play does not reuse a tiered plan")
	assert_eq(p.plan().tier, 1, "the plain plan is tier 1")
	assert_false(p.plan().loop, "the plain plan keeps the clip's loop mode")
	p.play("fix/rx_sneeze", {"loop": true})
	assert_true(p.plan().loop, "opts.loop gets its own cached plan")
	p.play("fix/rx_sneeze")
	assert_false(p.plan().loop, "… and the clip's own plan is untouched")


func test_clip_churn_costs() -> void:
	var rig := "hush" if RigDef3D.exists("hush") and not _base_clips("hush").is_empty() else "fix"
	var p := _make(rig)
	var ids := _base_clips(rig)
	p.prepare_clips(ids)
	var play_us := PackedFloat32Array()
	var adv_us := PackedFloat32Array()
	for i in 300:
		if i % 10 == 0:
			var t0 := Time.get_ticks_usec()
			p.play(ids[(i / 10) % ids.size()])
			play_us.append(float(Time.get_ticks_usec() - t0))
		var t1 := Time.get_ticks_usec()
		p.advance(1.0 / 60.0)
		if i % 10 == 0:
			adv_us.append(float(Time.get_ticks_usec() - t1))
	play_us.sort()
	adv_us.sort()
	var pm := play_us[play_us.size() / 2]
	var am := adv_us[adv_us.size() / 2]
	print("[perf3d] %s churn: play() median %.0f µs, the advance after it median %.0f µs, p95 %.0f µs" % [rig, pm, am,
		adv_us[int(0.95 * float(adv_us.size() - 1))]])
	assert_lt(pm, 300.0 * cpu_load_scale(), "%s: play() after prepare_clips %.0f µs (median)" % [rig, pm])
	assert_lt(am, 1000.0 * cpu_load_scale(), "%s: the advance after a switch %.0f µs (median)" % [rig, am])
