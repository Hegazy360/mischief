## Clip reach (docs/research/animation.md, phase 2): the `reach` block parses and validates, the weight
## curve, the player carries the authored gloves onto a `set_target` point at the contact frame (both
## gloves keep their spacing; facing; overlays), plays EXACTLY as authored with no target / above
## `max_height` / at weight 0, every container and rig point has a grab point, and CharacterView feeds
## the hotspot Hush works at to the rig. Positions are measured with independent FK (socket transforms).
extends TestBase

const DT := 1.0 / 60.0
const REACH_CLIPS: PackedStringArray = ["hush/act_tinker_q", "hush/act_tinker_s", "hush/act_tinker_b",
	"hush/act_rummage", "hush/act_pickup"]

var _nodes: Array = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			(n as Node).free()
	_nodes.clear()


func _rig() -> RigDef:
	return RigDef.for_id("hush")


func _clip(extra: Dictionary) -> ClipDef:
	var d := {"version": 1, "clip": "hush/test_reach", "rig": "hush", "length": 40, "loop": true,
		"keys": [{"f": 0, "pose": "h_tinker_q_a"}, {"f": 20, "pose": "h_tinker_q_b"}, {"f": 40, "pose": "h_tinker_q_a"}]}
	d.merge(extra, true)
	return ClipLib.from_dict(d, "hush/test_reach", _rig(), PoseLib.for_rig("hush"))


func _player(x: float = 1000.0, facing: int = 1) -> RigPlayer:
	var p := RigPlayer.new()
	p.configure_for_tools()
	p.springs_enabled = false
	tree.root.add_child(p)
	_nodes.append(p)
	p.setup("hush")
	p.position = Vector2(x, 0)
	p.set_facing(facing, false)
	return p


func _grip(p: RigPlayer, side: String) -> Vector2:
	return p.socket_global_transform("hand_%s:grip" % side).origin


## Step `p` to frame `f` of its base clip (from frame 0).
func _to_frame(p: RigPlayer, f: int) -> void:
	for i in f:
		p.advance(DT)


# --- the block --------------------------------------------------------------------------------

func test_the_ported_clips_carry_a_valid_reach() -> void:
	for cid in REACH_CLIPS:
		var c := ClipLib.get_clip(cid)
		if not assert_true(c != null, cid):
			continue
		assert_eq(c.errors, PackedStringArray(), "%s parses clean" % cid)
		assert_true(c.has_reach(), "%s has a reach block" % cid)
		assert_eq(c.reach_target, "grab", cid)
		assert_true(c.reach_ref.y < -20.0, "%s: the reference grip is above the floor (%s)" % [cid, c.reach_ref])
		assert_almost_eq(c.reach_max_height, 0.0, 0.01, "%s: no height limit (phase 3: the posture adapts the body)" % cid)
		assert_almost_eq(c.reach_max_px, 420.0, 0.01, "%s: reaches up to the clock" % cid)


func test_bad_reach_blocks_are_errors() -> void:
	var cases := {
		"no target": {"limbs": ["arm_r"]},
		"no limbs": {"target": "grab", "limbs": []},
		"not a 2-bone limb": {"target": "grab", "limbs": ["tail"]},
		"ref_f outside": {"target": "grab", "limbs": ["arm_r"], "ref_f": 99},
		"weight not increasing": {"target": "grab", "limbs": ["arm_r"], "weight": [[10, 1], [5, 0]]},
		"weight entry shape": {"target": "grab", "limbs": ["arm_r"], "weight": [[10]]},
	}
	for why in cases:
		var c := _clip({"reach": cases[why]})
		assert_false(c.errors.is_empty(), "%s → an error" % why)
	var ok := _clip({"reach": {"target": "grab", "limbs": ["arm_r", "arm_l"], "ref_f": 10}})
	assert_eq(ok.errors, PackedStringArray(), "a good block parses clean")
	assert_true(ok.has_reach())


func test_weight_curve_smoothsteps_and_wraps_on_loops() -> void:
	var c := _clip({"reach": {"target": "grab", "limbs": ["arm_r"], "weight": [[0, 0], [10, 1], [30, 1], [36, 0]]}})
	assert_almost_eq(c.reach_weight(0.0), 0.0, 0.0001)
	assert_almost_eq(c.reach_weight(5.0), 0.5, 0.0001, "smoothstep midpoint")
	assert_almost_eq(c.reach_weight(2.5), 0.15625, 0.0001, "smoothstep at a quarter (eases in)")
	assert_almost_eq(c.reach_weight(20.0), 1.0, 0.0001)
	assert_almost_eq(c.reach_weight(38.0), 0.0, 0.0001, "36 → 40 wraps to the f0 key (0)")
	assert_almost_eq(c.reach_weight(45.0), 0.5, 0.0001, "loops wrap: f45 = f5")
	var flat := _clip({"reach": {"target": "grab", "limbs": ["arm_r"]}})
	assert_almost_eq(flat.reach_weight(17.0), 1.0, 0.0001, "no weight keys = 1 throughout")


# --- the player -------------------------------------------------------------------------------

func test_gloves_land_on_the_target_at_the_contact_frame() -> void:
	for facing in [1, -1]:
		var p := _player(1000.0, facing)
		var c := ClipLib.get_clip("hush/act_rummage")
		p.play(c.id, {"blend_in": 0})
		p.advance(0.0)
		# A target 60 px higher and 20 px further than the clip's own (a taller box than the authored one).
		var ref_world := p.global_transform * Vector2(c.reach_ref.x * facing, c.reach_ref.y)
		var t := ref_world + Vector2(20.0 * facing, -60.0)
		p.set_target("grab", t)
		p.play(c.id, {"blend_in": 0})
		_to_frame(p, c.reach_ref_f)
		p.advance(0.0)
		var mid := (_grip(p, "r") + _grip(p, "l")) * 0.5
		assert_lt(mid.distance_to(t), 1.5, "facing %d: the gloves' midpoint lands on the target (%.2f px)" % [facing, mid.distance_to(t)])
		# Both gloves moved by the same offset: their spacing is the clip's.
		var q := _player(3000.0, facing)
		q.play(c.id, {"blend_in": 0})
		_to_frame(q, c.reach_ref_f)
		q.advance(0.0)
		var authored := _grip(q, "r") - _grip(q, "l")
		var now := _grip(p, "r") - _grip(p, "l")
		assert_lt(now.distance_to(authored), 1.5, "facing %d: the gloves keep their spacing (%.2f px)" % [facing, now.distance_to(authored)])


func test_no_target_means_exactly_the_authored_clip() -> void:
	var a := _player(1000.0)
	var b := _player(1000.0)
	b.set_target("other", Vector2(1000, -150))     # a target no clip reaches for
	for p in [a, b]:
		(p as RigPlayer).play("hush/act_tinker_q", {"blend_in": 0})
	for i in 30:
		a.advance(DT)
		b.advance(DT)
		assert_eq(a.pose_buffer(), b.pose_buffer(), "frame %d: identical pose" % i)
	assert_false(b.is_reaching())


func test_a_clip_with_max_height_keeps_the_authored_motion_above_it() -> void:
	# The real clips have no limit since phase 3; a clip can still opt out of high targets.
	var c := _clip({"clip": "hush/test_reach_capped", "reach": {"target": "grab", "limbs": ["arm_r", "arm_l"], "max_height": 205}})
	assert_eq(c.errors, PackedStringArray())
	c.id = "hush/test_reach_capped"
	ClipLib.register(c)
	var a := _player(1000.0)
	var b := _player(1000.0)
	b.set_target("grab", Vector2(1060, -380))      # the honey jar: above 205
	for p in [a, b]:
		(p as RigPlayer).play(c.id, {"blend_in": 0})
	for i in 20:
		a.advance(DT)
		b.advance(DT)
	assert_eq(a.pose_buffer(), b.pose_buffer(), "skipped: the pose is the authored one (no reach, no posture)")
	assert_false(b.is_reaching())
	assert_eq(b.reach_skipped(), "above max_height")
	ClipLib.invalidate(c.id)


func test_weight_zero_frames_are_authored_and_weight_one_frames_reach() -> void:
	var c := ClipLib.get_clip("hush/act_tinker_b")
	var a := _player(1000.0)
	var b := _player(1000.0)
	var t := b.global_transform * c.reach_ref + Vector2(15, -35)
	b.set_target("grab", t)
	for p in [a, b]:
		(p as RigPlayer).play(c.id, {"blend_in": 0})
	for i in 120:
		a.advance(DT)
		b.advance(DT)
		if i + 1 == 28:
			var mid := (_grip(b, "r") + _grip(b, "l")) * 0.5
			assert_lt(mid.distance_to(t), 1.5, "the f28 slam lands on the target (%.2f px)" % mid.distance_to(t))
	# f120: inside the brow wipe (weight 0 from f104 to f138): the arms are the clip's own again (the
	# body posture, if any, is still easing out — it never pops).
	assert_almost_eq(c.reach_weight(120.0), 0.0, 0.0001)
	assert_false(b.is_reaching(), "no reach during the brow wipe")
	for part in ["arm_upper_r", "arm_lower_r", "hand_r", "arm_upper_l", "arm_lower_l", "hand_l"]:
		var ch := RigDef.ch(b.rig.idx(part), RigDef.C_ROT)
		assert_almost_eq(b.pose_buffer()[ch], a.pose_buffer()[ch], 0.0001, "%s: the authored brow wipe" % part)


func test_overlay_pickup_reaches_over_an_idle() -> void:
	var c := ClipLib.get_clip("hush/act_pickup")
	var p := _player(1000.0)
	p.play("hush/loco_idle", {"blend_in": 0})
	p.advance(DT)
	var t := p.global_transform * (c.reach_ref + Vector2(15, 30))
	p.set_target("grab", t)
	p.play(c.id, {"layer": "overlay", "mask": "upper", "blend_in": 0})
	_to_frame(p, c.reach_ref_f)
	p.advance(0.0)
	# The overlay reference ignores the clip's crouch (overlays never write the root); the idle
	# under it is not the rest pose, so allow a few px.
	assert_lt(_grip(p, "r").distance_to(t), 6.0, "the scoop lands near the target over an idle (%.2f px)" % _grip(p, "r").distance_to(t))
	assert_true(p.is_reaching())


# --- data + the view ---------------------------------------------------------------------------

func test_every_container_and_rig_point_has_a_grab_point_in_its_room() -> void:
	var lay := HouseLayout.load_default()
	var house: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/house/house.json"))
	var n := 0
	for hv in house["hotspots"]:
		var hd: Dictionary = hv
		if not (String(hd["kind"]) in ["container", "rig_point"]):
			continue
		n += 1
		var h := lay.hotspot(String(hd["id"]))
		if not assert_true(h != null and h.grab != Vector2.INF and h.grab_l != Vector2.INF, "%s has grab points for both facings" % hd["id"]):
			continue
		var r := lay.room(h.room)
		var fy := lay.room_floor_y(h.room)
		for f in [1, -1]:
			var g := h.grab_for(f)
			assert_between(g.x, r.x0, r.x1, "%s facing %d: grab inside its room" % [h.id, f])
			assert_between(g.y - fy, -640.0, 0.0, "%s facing %d: grab between the floor and the ceiling (absolute y applies the floor)" % [h.id, f])
			# On her facing side of the stand point (or as near as the art allows).
			assert_gt((g.x - h.use_x) * f, -70.0, "%s facing %d: grab not behind her (%+.0f px)" % [h.id, f, (g.x - h.use_x) * f])
	assert_eq(n, 40, "every container / rig point checked")


class _StubHush:
	var room: String = "parlour"
	var x_sub: int = 2728 * 60
	var facing: int = 1
	var state: String = "RIGGING"
	var at_hotspot: String = "parlour_tea_tray"


class _StubWorld:
	var tick: int = 1
	var hush: _StubHush = _StubHush.new()


func test_snapshot_carries_at_hotspot() -> void:
	var s := ViewSnapshot.new()
	s.fill(_StubWorld.new(), null)
	assert_eq(s.hush.at_hotspot, "parlour_tea_tray")
	var b := ViewSnapshot.Actor.new()
	b.copy_from(s.hush)
	assert_eq(b.at_hotspot, "parlour_tea_tray", "copy_from keeps it")


func test_character_view_feeds_the_grab_point_and_clears_it() -> void:
	var cv := CharacterView.new()
	cv.layout = HouseLayout.load_default()
	tree.root.add_child(cv)
	_nodes.append(cv)
	cv.setup("hush")
	if not assert_true(cv.uses_rig, "Hush draws with her rig"):
		return
	var a := ViewSnapshot.Actor.new()
	a.present = true
	a.room = "parlour"
	a.x = 2728.0
	a.state = "RIGGING"
	a.facing = 1
	a.at_hotspot = "parlour_tea_tray"
	var rig: RigPlayer = cv.rig
	rig.manual = true    # the view's rig advances in _process; step it with the view here
	for i in 20:
		cv.apply(a, a, 0.0, DT)
		rig.advance(DT)
	var want := cv.layout.hotspot("parlour_tea_tray").grab_for(1)
	var par := cv.get_parent() as Node2D
	var want_g := par.to_global(want) if par != null else want
	assert_lt(rig.target_of("grab").distance_to(want_g), 0.01, "the tea tray's grab point is the rig's target")
	assert_true(rig.is_reaching(), "the tinker carries her gloves to it (state %s, clip %s)" % [a.state, rig.current_clip()])
	# She faces left at it (she walked in from the right): the left-side point.
	a.facing = -1
	for i in 10:
		cv.apply(a, a, 0.0, DT)
		rig.advance(DT)
	var want_l := cv.layout.hotspot("parlour_tea_tray").grab_for(-1)
	assert_lt(rig.target_of("grab").distance_to(par.to_global(want_l) if par != null else want_l), 0.01, "facing left: the left grab point")
	assert_ne(want_l, want, "the two sides differ")
	a.moving = true
	a.at_hotspot = ""
	a.state = "WALK"
	cv.apply(a, a, 0.0, DT)
	assert_eq(rig.target_of("grab"), Vector2.INF, "walking off clears it")
	CharacterView.reach_enabled = false
	a.moving = false
	a.state = "RIGGING"
	a.at_hotspot = "parlour_tea_tray"
	cv.apply(a, a, 0.0, DT)
	assert_eq(rig.target_of("grab"), Vector2.INF, "--no-reach: no target")
	CharacterView.reach_enabled = true
