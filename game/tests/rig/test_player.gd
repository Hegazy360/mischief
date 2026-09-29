## RigPlayer (TECH §5.3): crossfades (continuity, pops), events + clip_finished, sim-locked
## frames, the 6-frame facing turn, walk rate from stride, tier plays + T3 last beat,
## smears, props, residues, tint, look, faces, layers.
extends TestBase

const RIG := "_mannequin"
const DT := 1.0 / 60.0

var p: RigPlayer
var events: Array = []
var finished: PackedStringArray = PackedStringArray()


func before_each() -> void:
	p = RigPlayer.new()
	p.configure_for_tools()
	tree.root.add_child(p)
	p.setup(RIG)
	events = []
	finished = PackedStringArray()
	p.clip_event.connect(func(e: Dictionary) -> void: events.append(e))
	p.clip_finished.connect(func(id: String) -> void: finished.append(id))


func after_each() -> void:
	if is_instance_valid(p):
		p.free()


func _step(n: int) -> void:
	for i in n:
		p.advance(DT)


func _ch(part: String, c: int) -> int:
	return RigDef.ch(p.rig.idx(part), c)


func test_setup_builds_one_page_and_rest_pose() -> void:
	assert_true(p.rig != null and p.atlas != null)
	assert_eq(p.atlas.pages.size(), 1, "one atlas page per character")
	assert_eq(p.current_clip(), "")
	p.advance(0.0)
	assert_eq(p.part_transforms().size(), p.rig.names.size())


func test_crossfade_is_continuous_and_reaches_the_new_clip() -> void:
	p.play("_mannequin/loco_idle")
	_step(30)
	var before := p.pose_buffer().duplicate()
	p.play("_mannequin/loco_walk", {"blend_in": 6})
	p.advance(0.0)
	var arm := _ch("arm_upper_r", RigDef.C_ROT)
	assert_almost_eq(p.pose_buffer()[arm], before[arm], 0.01, "no pop on the first crossfade frame")
	_step(3)
	var walk := RigDef.for_id(RIG).rest.duplicate()
	RigSampler.sample(ClipLib.get_clip("_mannequin/loco_walk"), p.current_frame(), walk)
	var mid := p.pose_buffer()[arm]
	assert_true(absf(mid - walk[arm]) > 0.01 or absf(before[arm] - walk[arm]) < 0.01, "still blending at 3/6")
	_step(4)
	RigSampler.sample(ClipLib.get_clip("_mannequin/loco_walk"), p.current_frame(), walk)
	var leg := _ch("leg_upper_r", RigDef.C_ROT)
	assert_almost_eq(p.pose_buffer()[leg], walk[leg], 0.01, "the walk alone after the fade")


func test_reactions_pop_in_with_blend_in_zero() -> void:
	p.play("_mannequin/loco_idle")
	_step(20)
	p.play("_mannequin/rx_land")
	p.advance(0.0)
	var take := RigDef.for_id(RIG).rest.duplicate()
	RigSampler.sample(ClipLib.get_clip("_mannequin/rx_land"), 0.0, take)
	assert_almost_eq(p.pose_buffer()[RigDef.R_Y], take[RigDef.R_Y], 0.01, "pose pop: the reaction's first pose at once")


func test_events_fire_once_in_order_and_clip_finishes() -> void:
	p.play("_mannequin/rx_take")
	_step(95)
	var sfx := PackedStringArray()
	var accent := 0
	for e in events:
		if String(e["type"]) == "sfx":
			sfx.append(String(e["id"]))
		if String(e["type"]) == "mark" and String(e["name"]) == "accent":
			accent += 1
	assert_eq(sfx, PackedStringArray(["slide_up_short", "boing_eyes", "thud"]))
	assert_eq(accent, 1, "the accent mark fires exactly once")
	assert_eq(finished, PackedStringArray(["_mannequin/rx_take"]))
	assert_false(p.is_playing(), "holds its last frame")
	assert_almost_eq(p.current_frame(), 90.0, 0.001)


func test_external_frame_drives_the_clip_like_the_sim() -> void:
	p.play("_mannequin/rx_take", {"tier": 2})
	var seen: Array = []
	for t in [0.0, 12.5, 29.2, 30.4, 55.0, 55.0, 107.9]:
		p.set_external_frame(t)
		p.advance(DT)
		seen.append(p.current_frame())
	assert_almost_eq(p.current_frame(), 107.0 if p.clip_length() == 107 else float(p.clip_length()), 1.0)
	var accents := 0
	for e in events:
		if String(e.get("name", "")) == "accent":
			accents += 1
	assert_eq(accents, 1, "frame 30 crossed once")
	assert_eq(p.clip_length(), 90 + (36 * 20) / 100, "tier 2 stretches the hold")
	assert_eq(finished, PackedStringArray(["_mannequin/rx_take"]))
	# Seeking back fires nothing and does not finish again.
	events.clear()
	p.set_external_frame(10.0)
	assert_eq(events.size(), 0)


func test_t3_appends_the_last_beat() -> void:
	p.play("_mannequin/rx_take", {"tier": 3, "seed": 3})
	var len3 := p.clip_length()
	assert_eq(len3, 90 + 18)
	_step(len3 + 2)
	assert_eq(p.current_clip(), "_mannequin/beat_slow_burn", "last beat queued after the reaction")
	var fall := false
	for e in events:
		if String(e.get("op", "")) == "fall":
			fall = true
	assert_true(fall, "T3 falling-prop event emitted")
	_step(80)
	assert_eq(finished, PackedStringArray(["_mannequin/rx_take", "_mannequin/beat_slow_burn"]))


func test_facing_turn_is_a_six_frame_squash() -> void:
	p.advance(0.0)
	p.set_facing(-1, true)
	var sx: Array[float] = []
	for i in 7:
		p.advance(DT)
		sx.append(p._fsx)
	assert_between(sx[1], 0.15, 0.7, "squashing toward 0.15 on the old side")
	assert_gt(sx[1], 0.0)
	assert_lt(sx[3], 0.0, "swapped after the midpoint")
	assert_almost_eq(sx[5], -1.0, 0.001, "done after 6 frames")
	assert_eq(p.facing(), -1)
	p.set_facing(1, false)
	assert_almost_eq(p._fsx, 1.0, 0.0001, "instant flip without animation")


func test_walk_rate_matches_speed_over_stride() -> void:
	p.play("_mannequin/loco_walk", {"speed": 360.0})
	var c := ClipLib.get_clip("_mannequin/loco_walk")
	var natural := c.stride_px / (float(c.length) / 60.0)
	_step(10)
	assert_almost_eq(p.current_frame(), 10.0 * 360.0 / natural, 0.01, "360 px/s plays %.2f× (natural %.0f px/s)" % [360.0 / natural, natural])
	p.set_speed(natural * 0.5)
	var f0 := p.current_frame()
	_step(4)
	assert_almost_eq(p.current_frame() - f0, 2.0, 0.01, "half speed → half rate")


func test_smears_trigger_on_fast_parts() -> void:
	p.smears_enabled = true
	p.play("_mannequin/rx_take")
	var smeared := false
	for f in 40:
		p.advance(DT)
		for part in p.rig.names.size():
			if p._smear_t[part] > 0.0:
				smeared = true
	assert_true(smeared, "the take's pop smears (auto smear, > 40 px/f)")
	var q := RigPlayer.new()
	q.configure_for_tools()
	tree.root.add_child(q)
	q.setup(RIG)
	q.play("_mannequin/loco_idle")
	var any := false
	for f2 in 120:
		q.advance(DT)
		for part2 in q.rig.names.size():
			if q._smear_t[part2] > 0.0:
				any = true
	assert_false(any, "no smears in a gentle idle")
	q.free()


func test_prop_launch_residue_tint_and_face() -> void:
	p.play("_mannequin/rx_launch")
	_step(2)
	var mug := p.props.index_of("mug")
	assert_eq(p.props.mode[mug], PropSim.ATTACHED, "attached by the f0 event")
	_step(30)
	assert_eq(p.props.mode[mug], PropSim.FLYING, "launched at the accent")
	var up := p._prop_xf(mug).origin.y
	assert_lt(up, -300.0, "flying up")
	# A launched prop flies in the world: moving the character does not drag it along.
	var world_before := p.to_global(p._char_xf() * p._prop_xf(mug).origin)
	p.position += Vector2(250, 0)
	p.scale = Vector2(0.5, 0.5)
	var world_after := p.to_global(p._char_xf() * p._prop_xf(mug).origin)
	assert_almost_eq(world_before.distance_to(world_after), 0.0, 0.01, "prop stays put in the world")
	p.position -= Vector2(250, 0)
	p.scale = Vector2.ONE
	p.set_residue("SOAKED", true)
	p.advance(DT)
	var hat := p.rig.idx("hat")
	assert_eq(int(p.pose_buffer()[_ch("hat", RigDef.C_TEX)]), p.rig.tex_index(hat, "wet"), "residue swaps the hat")
	p.set_tint_tier(3)
	assert_eq(p._part_color(p.rig.idx("head"), 1.0).to_html(false), p.rig.tint_tiers[3].to_html(false))
	p.set_face("smug")
	p.advance(DT)
	assert_eq(int(p.pose_buffer()[_ch("face_mouth", RigDef.C_TEX)]), p.rig.tex_index(p.rig.idx("face_mouth"), "smile"))


func test_look_toward_turns_head_and_pupils() -> void:
	p.position = Vector2(500, 500)
	p.advance(0.0)
	var h0 := p.pose_buffer()[_ch("head", RigDef.C_ROT)]
	p.look_toward(Vector2(900, 0), 1.0)
	_step(40)
	var h1 := p.pose_buffer()[_ch("head", RigDef.C_ROT)]
	assert_lt(h1, h0 - 5.0, "looks up (head rot goes negative)")
	assert_ge(h1, h0 - p.rig.look_max_deg - 0.01, "clamped to ±20°")
	assert_lt(p.pose_buffer()[_ch("face_pupils", RigDef.C_Y)], -0.5, "pupils up")
	p.look_toward(Vector2.ZERO, 0.0)
	_step(60)
	assert_almost_eq(p.pose_buffer()[_ch("head", RigDef.C_ROT)], h0, 0.05, "eases back")


func test_overlay_and_additive_layers() -> void:
	var over := ClipLib.from_dict({"version": 1, "rig": RIG, "length": 30, "loop": true, "layer": "overlay", "mask": "upper",
		"blend_in": 1, "keys": [{"f": 0, "pose": "m_take_accent"}, {"f": 30, "pose": "m_take_accent"}]}, "_mannequin/_ov_test")
	ClipLib._cache["_mannequin/_ov_test"] = over
	p.play("_mannequin/loco_walk")
	p.play("_mannequin/_ov_test")
	_step(5)
	var acc := PoseLib.for_rig(RIG).pose("m_take_accent")
	var arm := _ch("arm_upper_r", RigDef.C_ROT)
	assert_almost_eq(p.pose_buffer()[arm], acc[arm], 0.5, "upper body from the overlay")
	assert_eq(p.current_clip(), "_mannequin/loco_walk", "base keeps walking")
	p.stop_layer("overlay")
	_step(12)
	assert_eq(p.layer_clip("overlay"), "", "overlay faded out")
	ClipLib.invalidate("_mannequin/_ov_test")


func test_draw_uses_few_runs() -> void:
	p.play("_mannequin/loco_walk")
	_step(3)
	p._sort_items()
	p._rebuild_layout()
	var rect_runs := 0
	var tri_runs := p._runs.size()
	var prev_kind := -1
	for code in p._seq:
		var k := code >> 16
		if k != RigPlayer.K_RUN and prev_kind != 1:
			rect_runs += 1
		prev_kind = 1 if k != RigPlayer.K_RUN else 0
	assert_le(tri_runs + rect_runs, 8, "≤ 8 batches (%d triangle runs + %d rect runs) — budget 12" % [tri_runs, rect_runs])


## A `smear` event on a clip without smear.auto: the ghosts follow the part's real history
## and the smear ends (regression: ghosts stuck at the character's origin).
func test_smear_event_without_auto_ends_and_ghosts_follow() -> void:
	var c := ClipLib.from_dict({"version": 1, "rig": RIG, "length": 30, "keys": [{"f": 0, "pose": "m_stand"},
		{"f": 30, "pose": "m_notice", "ease": "in_out_sine"}], "events": [{"f": 5, "type": "smear", "part": "head", "frames": 6}]},
		"_mannequin/_smear_ev")
	ClipLib.register(c)
	p.play("_mannequin/_smear_ev", {"blend_in": 0})
	_step(7)
	var h := p.rig.idx("head")
	assert_gt(p._smear_t[h], 0.0, "smearing after the event")
	assert_true(p._g1[h].origin.distance_to(p._xf[h].origin) < 40.0, "ghost 1 sits on the head's recent path")
	_step(6)
	assert_eq(p._smear_t[h], 0.0, "the smear ends")
	ClipLib.invalidate("_mannequin/_smear_ev")


## The render sync skips the z sort while nothing discrete changed: over a whole take with a
## launched prop, blinks and a face override, the skipped frames' draw order always equals a
## fresh sort (no stale layering).
func test_sort_skip_never_leaves_a_stale_order() -> void:
	p.configure_for_tools()
	p.face.blinks_enabled = true
	p.play("_mannequin/rx_launch", {"blend_in": 0})
	var skipped := 0
	for f in 150:
		p.advance(DT)
		if f == 40:
			p.set_face("shock" if p.poses.has_preset("shock") else p.poses.preset_names[0])
		if f == 90:
			p.set_residue("SOAKED", true)
		var was := p._keys.duplicate()
		if RigPlayer.skip_unchanged_sort and p._discrete_same() and not p._layout_dirty:
			skipped += 1
			p._sort_items()
			assert_eq(p._keys, was, "frame %d: the skipped sort would have given the same order" % f)
		else:
			p._sort_items()
		if p._layout_dirty:
			p._rebuild_layout()
	assert_gt(skipped, 60, "most frames skip the sort (%d / 150)" % skipped)
