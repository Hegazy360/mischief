## TapAssist (GDD §3.1, TECH §6.2): exact hit first, 90 screen px assist scaled by zoom,
## priority hotspot > door/stairs > floor, floor → move.
extends TestBase


func _cands() -> Array:
	return [
		{"id": "kitchen_honey", "kind": "rig_point", "rect": Rect2(1000, -300, 144, 144), "room": "kitchen"},
		{"id": "kitchen_pantry_curtain", "kind": "hiding", "rect": Rect2(1300, -320, 160, 300), "room": "kitchen"},
		{"id": "kitchen_back_door", "kind": "door", "rect": Rect2(1700, -330, 160, 330), "room": "kitchen"},
		{"id": "floor_kitchen", "kind": "floor", "rect": Rect2(900, -640, 1200, 640), "room": "kitchen"},
	]


func test_exact_hit_on_a_hotspot() -> void:
	var r := TapAssist.resolve(Vector2(1050, -250), _cands(), 1.0)
	assert_eq(r.get("c"), "go")
	assert_eq(r.get("hotspot"), "kitchen_honey")
	assert_false(bool(r.get("assisted")), "exact")


func test_exact_hit_beats_a_nearer_assisted_hotspot() -> void:
	# inside the door rect but within 90 px of the curtain too
	var r := TapAssist.resolve(Vector2(1710, -100), _cands(), 1.0)
	assert_eq(r.get("hotspot"), "kitchen_back_door", "an exact door hit wins over assist")


func test_assist_snaps_within_90_screen_px() -> void:
	var r := TapAssist.resolve(Vector2(1000 - 85, -250), _cands(), 1.0)
	assert_eq(r.get("hotspot"), "kitchen_honey", "85 px left of the pepper: snapped")
	assert_true(bool(r.get("assisted")))
	var far := TapAssist.resolve(Vector2(1000 - 95, -250), _cands(), 1.0)
	assert_eq(far.get("c"), "move", "95 px away: floor")


func test_assist_radius_scales_with_zoom() -> void:
	var cands := [
		{"id": "kitchen_honey", "kind": "rig_point", "rect": Rect2(1000, -300, 144, 144), "room": "kitchen"},
		{"id": "floor_kitchen", "kind": "floor", "rect": Rect2(0, -640, 3000, 640), "room": "kitchen"},
	]
	# zoom 0.5 → 90 / 0.5 = 180 world px
	var r := TapAssist.resolve(Vector2(1144 + 150, -250), cands, 0.5)
	assert_eq(r.get("hotspot"), "kitchen_honey", "150 world px at zoom 0.5 = 75 screen px: snapped")
	var r2 := TapAssist.resolve(Vector2(1144 + 150, -250), cands, 1.0)
	assert_eq(r2.get("c"), "move", "the same point at zoom 1.0 is 150 screen px: floor")
	# zoom 1.25 → 72 world px
	var r3 := TapAssist.resolve(Vector2(1144 + 80, -250), cands, 1.25)
	assert_eq(r3.get("c"), "move", "80 world px at zoom 1.25 = 100 screen px: too far")
	var r4 := TapAssist.resolve(Vector2(1144 + 70, -250), cands, 1.25)
	assert_eq(r4.get("hotspot"), "kitchen_honey", "70 world px at zoom 1.25 = 87.5 screen px: snapped")


func test_priority_hotspot_over_door_within_assist() -> void:
	var cands := [
		{"id": "stairs_foot", "kind": "stairs", "rect": Rect2(0, -300, 144, 300), "room": "hall"},
		{"id": "hall_clock_case", "kind": "hiding", "rect": Rect2(224, -300, 144, 300), "room": "hall"},
		{"id": "floor_hall", "kind": "floor", "rect": Rect2(-200, -640, 1000, 640), "room": "hall"},
	]
	# 20 px from the stairs, 60 px from the clock: the hotspot wins (priority first)
	var r := TapAssist.resolve(Vector2(164, -100), cands, 1.0)
	assert_eq(r.get("hotspot"), "hall_clock_case")
	# only the stairs in range → stairs
	var r2 := TapAssist.resolve(Vector2(150, -100), [cands[0], cands[2]], 1.0)
	assert_eq(r2.get("hotspot"), "stairs_foot")
	assert_eq(r2.get("kind"), "stairs")


func test_explicit_priority_field_wins() -> void:
	var cands := [
		{"id": "a", "kind": "door", "rect": Rect2(0, 0, 100, 100), "priority": 5},
		{"id": "b", "kind": "rig_point", "rect": Rect2(150, 0, 100, 100)},
	]
	var r := TapAssist.resolve(Vector2(125, 50), cands, 1.0)
	assert_eq(r.get("hotspot"), "a")


func test_floor_fallback_is_a_move_clamped_to_the_room() -> void:
	var r := TapAssist.resolve(Vector2(1600.4, -500), _cands(), 1.0)
	assert_eq(r, {"c": "move", "room": "kitchen", "x": 1600})
	var edge := TapAssist.resolve(Vector2(2150, -500), _cands(), 1.0)
	assert_eq(edge.get("c"), "move", "just outside the room, within assist")
	assert_eq(edge.get("x"), 2100, "clamped to the room")


func test_nothing_near() -> void:
	assert_eq(TapAssist.resolve(Vector2(9000, 0), _cands(), 1.0), {})
	assert_eq(TapAssist.resolve(Vector2(0, 0), [], 1.0), {})


func test_rect_distance() -> void:
	var rc := Rect2(0, 0, 10, 10)
	assert_eq(TapAssist.rect_distance(Vector2(5, 5), rc), 0.0)
	assert_eq(TapAssist.rect_distance(Vector2(13, 14), rc), 5.0)
