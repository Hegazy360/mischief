## NavGraph / NavPath: costs per mover, doorways, doors, stairs, masks, eta_to_room.
extends TestBase


func _nav() -> NavGraph:
	return SimTestUtil.db().nav


func _r(id: String) -> int:
	return int(SimTestUtil.db().house.room_index[id])


func _sub(px: int) -> int:
	return px * SimConst.SUB


func test_same_room_is_one_walk_leg() -> void:
	var p := _nav().path(_r("kitchen"), _sub(3800), _r("kitchen"), _sub(3000), SimConst.MOVER_HUSH_WALK)
	assert_true(p.ok)
	assert_eq(p.size(), 1)
	assert_eq(p.kinds[0], NavPath.WALK)
	assert_eq(p.remaining_ticks(), 120, "800 px at 400 px/s = 2 s")


func test_doorways_cost_nothing_extra() -> void:
	var p := _nav().path(_r("hall"), _sub(1000), _r("kitchen"), _sub(3000), SimConst.MOVER_B_WALK)
	assert_true(p.ok)
	assert_eq(p.remaining_ticks(), 500, "2000 px at 240 px/s")
	assert_eq(p.final_room(), _r("kitchen"))


func test_door_ticks_per_mover() -> void:
	var ph := _nav().path(_r("porch"), _sub(350), _r("hall"), _sub(700), SimConst.MOVER_HUSH_WALK)
	var pb := _nav().path(_r("porch"), _sub(350), _r("hall"), _sub(700), SimConst.MOVER_B_WALK)
	assert_true(ph.kinds.has(NavPath.DOOR))
	assert_eq(ph.ticks[ph.kinds.find(NavPath.DOOR)], SimConst.HUSH_DOOR_TICKS)
	assert_eq(pb.ticks[pb.kinds.find(NavPath.DOOR)], SimConst.B_DOOR_TICKS)
	assert_eq(ph.remaining_ticks(), Fx.div_ceil(_sub(150), 400) + Fx.div_ceil(_sub(200), 400) + 21)


func test_stairs_ticks_per_mover() -> void:
	var ph := _nav().path(_r("hall"), _sub(1450), _r("landing"), _sub(1050), SimConst.MOVER_HUSH_WALK)
	var pb := _nav().path(_r("hall"), _sub(1450), _r("landing"), _sub(1050), SimConst.MOVER_B_WALK)
	assert_eq(ph.remaining_ticks(), 60)
	assert_eq(pb.remaining_ticks(), 108)
	var pr := _nav().path(_r("kitchen"), _sub(3800), _r("landing"), _sub(1450), SimConst.MOVER_HUSH_RUN)
	# legs round up separately (no carry-over): kitchen 1000 px, parlour 1300, hall 50, stairs, landing 400
	var legs := Fx.div_ceil(_sub(1000), 720) + Fx.div_ceil(_sub(1300), 720) + Fx.div_ceil(_sub(50), 720)
	assert_eq(pr.remaining_ticks(), legs + 60 + Fx.div_ceil(_sub(400), 720))


func test_room_mask_blocks_locked_rooms() -> void:
	var mask := (1 << _r("parlour")) | (1 << _r("kitchen"))
	var p := _nav().path(_r("kitchen"), _sub(3800), _r("landing"), _sub(1200), SimConst.MOVER_HUSH_WALK, mask)
	assert_false(p.ok, "the hall is locked")
	var q := _nav().path(_r("kitchen"), _sub(3800), _r("parlour"), _sub(2000), SimConst.MOVER_HUSH_WALK, mask)
	assert_true(q.ok)


func test_eta_to_room_matches_walking() -> void:
	var p := _nav().path(_r("parlour"), _sub(1700), _r("kitchen"), _sub(2900), SimConst.MOVER_B_WALK)
	var eta := p.eta_to_room(_r("kitchen"))
	assert_eq(eta, 275)
	assert_eq(p.eta_to_room(_r("hall")), -1)
	assert_eq(p.eta_to_room(_r("parlour")), 0)
	var n := 0
	while p.room != _r("kitchen"):
		p.advance()
		n += 1
	assert_eq(n, eta, "entered on the eta-th advance")


func test_eta_through_stairs_and_pause() -> void:
	var p := _nav().path(_r("parlour"), _sub(1700), _r("landing"), _sub(1420), SimConst.MOVER_B_WALK)
	var e := p.eta_to_room(_r("landing"))
	assert_eq(e, Fx.div_ceil(_sub(250), 240))
	p.insert_pause(p.entry_leg(_r("landing")), 30, NavPath.AUX_DOORWAY_PAUSE)
	assert_eq(p.eta_to_room(_r("landing")), e + 30)
	var total := p.remaining_ticks()
	var n := 0
	while not p.is_done():
		p.advance()
		n += 1
	assert_eq(n, total)


func test_doorway_joined_and_floor_distance() -> void:
	var nav := _nav()
	assert_true(nav.doorway_joined(_r("parlour"), _r("kitchen")))
	assert_true(nav.doorway_joined(_r("hall"), _r("hall")))
	assert_false(nav.doorway_joined(_r("hall"), _r("kitchen")))
	assert_false(nav.doorway_joined(_r("porch"), _r("hall")), "the front door is a door, not a doorway")
	assert_eq(nav.floor_distance(_r("hall"), _sub(1000), _r("kitchen"), _sub(3000)), _sub(2000))
	assert_eq(nav.floor_distance(_r("hall"), _sub(1000), _r("landing"), _sub(1000)), -1)
