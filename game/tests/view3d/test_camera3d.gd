## CameraDirector3D — the REDESIGN §5.2 numbers and the C1–C8 framing rules (R3D index §7.7).
extends TestBase

const HOUSE := "res://data/house/house.json"
const N1_ROOMS := ["porch", "hall", "parlour", "kitchen"]
const P00_ROOMS := ["parlour", "kitchen", "hall"]


func _cam(aspect: String = "20x9", rooms: Array = N1_ROOMS) -> CameraDirector3D:
	var cam := CameraDirector3D.new()
	cam.logical_size_override = View3DConst.logical_size(aspect)
	cam.setup(load_json(HOUSE), rooms)
	return cam


func _target(x_m: float, floor_i: int = 0) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(x_m, View3DConst.floor_y(floor_i), View3DConst.LANE_Z)
	return n


func _settle(cam: CameraDirector3D, frames: int = 240) -> void:
	for i in frames:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)


func test_base_framing_px_per_metre() -> void:
	var cam := _cam()
	var t := _target(16.0)
	cam.follow(t, func() -> float: return 0.0)
	cam.advance(0.0, 0.0)
	assert_almost_eq(cam.px_per_m_at(View3DConst.LANE_Z), 269.0, 2.0, "1 m = 269 px at the lane (1080 logical)")
	assert_almost_eq(cam.px_per_m_at(View3DConst.BACK_WALL_Z), 226.0, 2.0, "1 m = 226 px at the back wall")
	assert_almost_eq(cam.px_per_m_at(View3DConst.LIP_Z), 322.0, 3.0, "322 px at the lip")
	assert_almost_eq(cam.fov, 30.0, 0.001)
	assert_eq(cam.keep_aspect, Camera3D.KEEP_HEIGHT)
	assert_almost_eq(cam.near, 0.5, 0.001)
	assert_almost_eq(cam.far, 60.0, 0.001)
	# pitch −4.2°, camera 7.5 m in front of the lane at y 1.9
	var xf := cam.transform
	assert_almost_eq(xf.origin.z, 6.5, 0.001, "z +6.5")
	assert_almost_eq(xf.origin.y, 1.9, 0.001, "y 1.9")
	var pitch := rad_to_deg(asin((-xf.basis.z).y))
	assert_almost_eq(pitch, -4.19, 0.05, "pitch −4.2°")
	t.free()
	cam.free()


func test_visible_lane_width_per_aspect() -> void:
	for pair in [["20x9", 8.93], ["16x9", 7.15], ["4x3", 5.36]]:
		var cam := _cam(pair[0])
		var t := _target(16.0)
		cam.follow(t, func() -> float: return 0.0)
		cam.advance(0.0, 0.0)
		assert_almost_eq(cam.visible_width_at(View3DConst.LANE_Z), pair[1], 0.05, "visible width at %s" % pair[0])
		assert_almost_eq(cam.visible_width_for(CameraDirector3D.BASE_DIST), pair[1], 0.05)
		t.free()
		cam.free()


func test_screen_world_round_trip_on_the_lane() -> void:
	var cam := _cam()
	var t := _target(10.0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam, 10)
	for p in [Vector2(2000, -100), Vector2(2150, -300), Vector2(1800, 0), Vector2(2300, -420)]:
		var s := cam.world_to_screen(p)
		var back := cam.screen_to_world(s)
		assert_almost_eq(back.x, p.x, 0.05, "x round trip %s" % p)
		assert_almost_eq(back.y, p.y, 0.05, "y round trip %s" % p)
	t.free()
	cam.free()


func test_project_aabb_matches_hand_computed_corners() -> void:
	var cam := _cam()
	var t := _target(16.0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam, 10)
	var box := AABB(Vector3(15.5, 0.8, -1.9), Vector3(0.6, 0.5, 0.3))
	var r := cam.project_aabb(box)
	# by hand: the near-bottom-left and far-top-right corners bound the rect for a box right of the aim point
	var xf := cam.transform
	var f := 540.0 / tan(deg_to_rad(15.0))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var q := xf.affine_inverse() * box.get_endpoint(i)
		var s := Vector2(1200.0 + f * q.x / -q.z, 540.0 - f * q.y / -q.z)
		lo = lo.min(s)
		hi = hi.max(s)
	assert_almost_eq(r.position.x, lo.x, 0.01)
	assert_almost_eq(r.position.y, lo.y, 0.01)
	assert_almost_eq(r.end.x, hi.x, 0.01)
	assert_almost_eq(r.end.y, hi.y, 0.01)
	# a 0.72 m data rect at the back wall projects to >= 163 px (REDESIGN §5.5)
	var wall := cam.project_aabb(AABB(Vector3(16.0, 0.5, View3DConst.BACK_WALL_Z), Vector3(0.72, 0.72, 0.0)))
	assert_ge(wall.size.x, 160.0, "0.72 m at the back wall ≥ 160 px")
	t.free()
	cam.free()


func test_lane_point_and_units() -> void:
	var cam := _cam()
	var p := cam.lane_point(3000.0, 1)
	assert_almost_eq(p.x, 15.0, 0.0001)
	assert_almost_eq(p.y, 3.5, 0.0001)
	assert_almost_eq(p.z, -1.0, 0.0001)
	assert_almost_eq(View3DConst.x_m(2800.0), 14.0, 0.0001)
	var w := View3DConst.px_to_world(Vector2(3760, -110))
	assert_almost_eq(w.y, 0.55, 0.0001, "house.json y maps to −y/200")
	cam.free()


func test_c2_night1_kitchen_frames_at_15_33() -> void:
	var cam := _cam("20x9", N1_ROOMS)
	var t := _target(17.0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam)
	assert_almost_eq(cam.aim().x, 15.33, 0.02, "C2: the N1 kitchen frames at x 15.33 m (20:9)")
	var rect := cam.visible_world_rect()
	assert_le(rect.end.x / 200.0, 19.5 + 0.3 + 0.01, "≤ 0.3 m of unbuilt space past the kitchen wall")
	t.free()
	cam.free()


func test_c1_room_fit_keeps_the_whole_room_in_view() -> void:
	# the parlour (7.5–14.0 m) fits at 20:9: every Hush x inside it keeps the room in view (+0.3 m margins)
	var cam := _cam("20x9", N1_ROOMS)
	for x in [7.8, 9.0, 10.75, 12.5, 13.8]:
		var t := _target(x)
		cam.follow(t, func() -> float: return 1.0)
		_settle(cam)
		var r := cam.visible_world_rect()
		assert_le(r.position.x / 200.0, 7.5 - 0.29, "parlour left wall in view (x %s)" % x)
		assert_ge(r.end.x / 200.0, 14.0 + 0.29, "parlour right wall in view (x %s)" % x)
		t.free()
	cam.free()


func test_c1_follow_in_a_room_wider_than_the_view() -> void:
	# at 4:3 (5.36 m) the parlour (6.5 m) does not fit: the camera follows Hush with the look-ahead
	var cam := _cam("4x3", N1_ROOMS)
	var t := _target(9.5)
	cam.follow(t, func() -> float: return 1.0)
	_settle(cam)
	var s := cam.project(t.position)
	var frac := s.x / cam.view_size().x
	assert_between(frac, 0.33, 0.47, "walking right she sits left of centre (look-ahead)")
	t.free()
	cam.free()


func test_c1_doorway_crossing_eases_never_cuts() -> void:
	var cam := _cam("20x9", N1_ROOMS)
	var t := _target(13.6)
	cam.follow(t, func() -> float: return 1.0)
	_settle(cam)
	var x0 := cam.aim().x
	t.position.x = 14.3   # into the kitchen
	var max_step := 0.0
	var last := x0
	for i in 60:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)
		max_step = maxf(max_step, absf(cam.aim().x - last))
		last = cam.aim().x
	assert_gt(absf(last - x0), 1.0, "the camera moved to the kitchen framing")
	assert_lt(max_step, 0.25, "no cut: ≤ 0.25 m per frame")
	t.free()
	cam.free()


func test_neighbour_strips_per_room() -> void:
	# REDESIGN §3.1: under C1 framing (Hush at the room centre) ≤ 1.7 m of each neighbour at 20:9 and ≤ 0.8 m at
	# 16:9 — where the room is wide enough for it; narrower rooms centre (equal strips) and the Night's outer rooms
	# take C2's clamp (the edge wins). The numbers are reported in docs/review/r3d-view3d/neighbour_strips.md.
	var house: Dictionary = load_json(HOUSE)
	for night in [N1_ROOMS, P00_ROOMS]:
		for aspect in ["20x9", "16x9"]:
			var cam := _cam(aspect, night)
			var lim: float = View3DConst.NEIGHBOUR_STRIP_M[aspect]
			for rd in house["rooms"]:
				if not night.has(rd["id"]) or int(rd["floor"]) != 0:
					continue
				var x0 := float(rd["x0"]) / 200.0
				var x1 := float(rd["x1"]) / 200.0
				var t := _target((x0 + x1) * 0.5)
				cam.follow(t, func() -> float: return 0.0)
				_settle(cam)
				var r := cam.visible_world_rect()
				var left := maxf(0.0, x0 - r.position.x / 200.0)
				var right := maxf(0.0, r.end.x / 200.0 - x1)
				var V := cam.visible_width_at()
				var slack := maxf(0.0, V - (x1 - x0))
				var allowed := maxf(lim, slack * 0.5) + 0.05
				var edge := cam.aim().x
				var c2_binds := absf(edge - (x0 + x1) * 0.5) > 0.05
				if not c2_binds:
					assert_le(left, allowed, "%s %s left strip %.2f m" % [aspect, rd["id"], left])
					assert_le(right, allowed, "%s %s right strip %.2f m" % [aspect, rd["id"], right])
				t.free()
			cam.free()


func test_c3_two_shot_pulls_back_at_most_1_15() -> void:
	var cam := _cam("20x9", N1_ROOMS)
	var h := _target(7.8)
	var b := _target(15.5)
	cam.follow(h, func() -> float: return 0.0)
	cam.set_other(b)
	_settle(cam, 400)
	assert_true(cam.is_two_shot(), "Bellows 1.5 m past the shared doorway → two-shot")
	assert_le(cam.distance(), 8.63 + 0.01, "≤ 1.15× (8.63 m)")
	assert_gt(cam.distance(), 7.5, "pulled back")
	var sh := cam.project(h.position).x / cam.view_size().x
	assert_between(sh, 0.195, 0.805, "Hush ≥ 20 % from either edge")
	# his far side inside the frame when the pull-back suffices
	b.position.x = 14.8
	_settle(cam, 400)
	var sb := cam.project(b.position).x / cam.view_size().x
	assert_between(sb, 0.0, 1.0, "Bellows in frame")
	assert_between(cam.project(h.position).x / cam.view_size().x, 0.195, 0.805)
	h.free()
	b.free()
	cam.free()


func test_c4_hold_offset_keeps_hush_at_40_to_55_percent() -> void:
	var cam := _cam("4x3", N1_ROOMS)
	var t := _target(10.0)
	cam.follow(t, func() -> float: return 1.0)
	cam.set_hold_offset(true)
	_settle(cam)
	var f := cam.project(t.position).x / cam.view_size().x
	assert_between(f, 0.395, 0.555, "held: Hush at 40–55 %")
	t.free()
	cam.free()


func test_c6_safe_rect_keeps_props_inside() -> void:
	var cam := _cam("16x9", N1_ROOMS)
	var t := _target(9.0)
	var box := AABB(Vector3(13.8, 0.6, -1.9), Vector3(0.5, 0.6, 0.3))
	cam.follow(t, func() -> float: return -1.0)
	cam.set_safe_rect(Rect2(Vector2(120, 60), Vector2(1920 - 240, 960)))
	cam.set_keep_visible(func() -> Array: return [box])
	_settle(cam)
	var r := cam.project_aabb(box)
	assert_le(r.end.x, 1920.0 - 120.0 + 1.0, "the live prop inside the safe rect")
	var hs := cam.project(t.position)
	assert_between(hs.x, 120.0, 1800.0, "Hush inside the safe rect")
	t.free()
	cam.free()


func test_c5_floor_change_cranes_in_0_4_s() -> void:
	var cam := _cam("20x9", [])
	var t := _target(9.0, 0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam, 10)
	t.position.y = 3.5
	for i in 12:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)
	var mid := cam.aim().y
	assert_between(mid, 1.4, 4.8, "mid-crane")
	for i in 14:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_almost_eq(cam.aim().y, 3.5 + 1.35, 0.01, "crane done by 0.43 s")
	t.free()
	cam.free()


func test_c7_punch_in_distances_and_yaw() -> void:
	for pair in [[1.15, 6.52], [1.3, 5.77], [1.4, 5.36], [1.6, 4.69], [2.5, 4.5]]:
		var cam := _cam("20x9", N1_ROOMS)
		var t := _target(10.0)
		cam.follow(t, func() -> float: return 0.0)
		_settle(cam, 30)
		var focus := Vector3(10.5, 1.2, -1.0)
		cam.request_gag(focus, pair[0], 11, 90, 21, 0, 5.0)
		for i in 20:
			cam.advance(1.0 / 60.0, 1.0 / 60.0)
		assert_eq(cam.gag_phase(), CameraDirector3D.GagPhase.HOLD, "in the hold")
		assert_almost_eq(cam.transform.origin.distance_to(cam.aim()) / sqrt(1.0 + CameraDirector3D.PITCH_TAN ** 2), pair[1], 0.02, "zoom %s → %s m" % pair)
		assert_almost_eq(cam.yaw_deg(), 5.0, 0.01, "yaw toward his face side")
		t.free()
		cam.free()


func test_c7_punch_lands_in_0_18_s_real_time_and_eases_out() -> void:
	var cam := _cam()
	var t := _target(10.0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam, 30)
	var id := cam.request_gag(Vector3(10.2, 1.2, -1.0), 1.4, 11, 60, 21)
	var done := [false]
	cam.gag_finished.connect(func(gid: int) -> void: done[0] = gid == id)
	for i in 11:
		cam.advance(0.0, 1.0 / 60.0)   # hit-stop: view time frozen, the punch still lands
	assert_eq(cam.gag_phase(), CameraDirector3D.GagPhase.HOLD)
	for i in 100:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_true(done[0], "gag finished")
	assert_almost_eq(cam.distance(), 7.5, 0.05, "back to the base distance")
	t.free()
	cam.free()


func test_c7_push_then_punch() -> void:
	var cam := _cam()
	var t := _target(10.0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam, 30)
	var id := cam.request_gag(Vector3(10.4, 1.2, -1.0), 1.4, 11, 60, 21, 0, 0.0, 120, 1.15)
	for i in 130:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_eq(cam.gag_phase(), CameraDirector3D.GagPhase.APPROACH, "the push holds until the accent")
	assert_almost_eq(cam.transform.origin.distance_to(cam.aim()) / sqrt(1.0 + CameraDirector3D.PITCH_TAN ** 2), 6.52, 0.05, "pushed to 1.15")
	cam.punch_gag(id)
	for i in 12:
		cam.advance(0.0, 1.0 / 60.0)
	assert_almost_eq(cam.transform.origin.distance_to(cam.aim()) / sqrt(1.0 + CameraDirector3D.PITCH_TAN ** 2), 5.36, 0.05, "punched to 1.4")
	t.free()
	cam.free()


func test_reduce_motion_caps_punch_and_drops_yaw_and_shake() -> void:
	var cam := _cam()
	cam.set_reduce_motion(true)
	var t := _target(10.0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam, 30)
	cam.request_gag(Vector3(10.2, 1.2, -1.0), 1.6, 11, 60, 21, 0, 6.0)
	cam.shake(0.8)
	for i in 30:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_ge(cam.transform.origin.distance_to(cam.aim()) / sqrt(1.0 + CameraDirector3D.PITCH_TAN ** 2), 6.51, "punch ≤ 1.15×")
	assert_almost_eq(cam.yaw_deg(), 0.0, 0.001, "no yaw")
	assert_almost_eq(cam.trauma(), 0.0, 0.001, "no shake")
	t.free()
	cam.free()


func test_one_punchline_at_a_time() -> void:
	var cam := _cam()
	var t := _target(10.0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam, 10)
	var a := cam.request_gag(Vector3(10.2, 1.2, -1.0), 1.4, 11, 60, 21)
	var b := cam.request_gag(Vector3(11.2, 1.2, -1.0), 1.3, 11, 60, 21)
	assert_eq(cam.active_gag_id(), a)
	assert_eq(cam.queued_gags(), 1)
	for i in 120:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_eq(cam.active_gag_id(), b, "the queued gag follows")
	t.free()
	cam.free()


func test_overview_dollies_to_15_m() -> void:
	var cam := _cam()
	var t := _target(10.0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam, 10)
	cam.toggle_overview()
	_settle(cam, 60)
	assert_true(cam.is_overview())
	assert_almost_eq(cam.distance(), 15.0, 0.05)
	cam.toggle_overview()
	_settle(cam, 60)
	assert_almost_eq(cam.distance(), 7.5, 0.05)
	t.free()
	cam.free()


func test_peek_flies_holds_and_returns() -> void:
	var cam := _cam()
	var t := _target(9.0)
	cam.follow(t, func() -> float: return 0.0)
	_settle(cam)
	var home := cam.aim().x
	cam.peek(Vector2(3400, 0), 1.8)
	for i in 30:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_true(cam.is_peeking())
	assert_gt(cam.aim().x, home + 2.0, "flew toward the peek target")
	for i in 200:
		cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_false(cam.is_peeking())
	assert_almost_eq(cam.aim().x, home, 0.05, "returned")
	t.free()
	cam.free()


func test_play_framings_keep_the_back_wall_within_10_m() -> void:
	var cam := _cam()
	var h := _target(7.6)
	var b := _target(16.9)
	cam.follow(h, func() -> float: return 0.0)
	cam.set_other(b)
	_settle(cam, 400)
	assert_ge(cam.px_per_m_at(View3DConst.BACK_WALL_Z), View3DConst.PX_PER_M_MIN_PLAY - 0.5, "≥ 201 px/m at the back wall in the two-shot")
	h.free()
	b.free()
	cam.free()
