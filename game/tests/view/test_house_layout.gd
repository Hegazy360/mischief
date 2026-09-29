## HouseLayout: the GDD §7.1 greybox, house.json parsing (rects to world space), room
## distances, bounds, and the real house.json when present (soft).
extends TestBase


func test_greybox_matches_gdd_widths() -> void:
	var h := HouseLayout.greybox()
	var widths := {"porch": 500, "hall": 1000, "parlour": 1300, "kitchen": 1100, "conservatory": 800,
		"garden": 1500, "landing": 800, "bathroom": 1000, "bedroom": 900, "dressing": 800}
	for id in widths:
		var r := h.room(id)
		assert_true(r != null, id)
		if r != null:
			assert_almost_eq(r.width(), float(widths[id]), 0.01, id)
	assert_eq(h.room("landing").floor, 1)
	assert_eq(h.floor_y(1), -700.0)


func test_room_distance_and_links() -> void:
	var h := HouseLayout.greybox()
	assert_eq(h.room_distance("kitchen", "kitchen"), 0)
	assert_eq(h.room_distance("kitchen", "parlour"), 1)
	assert_eq(h.room_distance("kitchen", "hall"), 2)
	assert_eq(h.room_distance("kitchen", "landing"), 3, "via the stairs")
	assert_true(h.link_between("hall", "landing") != null)
	assert_eq(h.room_at(0, 3000.0), "kitchen")
	assert_eq(h.room_at(1, 2000.0), "bathroom")


func test_bounds_include_flies_and_apron() -> void:
	var b := HouseLayout.greybox().bounds()
	assert_eq(b.position.x, 0.0)
	assert_eq(b.end.x, 6200.0)
	assert_almost_eq(b.position.y, -700.0 - 640.0 - 190.0, 0.01)
	assert_almost_eq(b.end.y, 60.0 + 190.0, 0.01)


func test_from_json_converts_rects_to_world() -> void:
	var d := {"version": 1, "floor_pitch": 700,
		"rooms": [{"id": "hall", "floor": 0, "x0": 500, "x1": 1500, "wallpaper": "#A9B79A"},
			{"id": "landing", "floor": 1, "x0": 1000, "x1": 1800}],
		"links": [{"id": "stairs", "kind": "stairs", "a": "hall", "ax": 1450, "b": "landing", "bx": 1050}],
		"hotspots": [{"id": "stairs_head", "kind": "stairs", "room": "landing", "use_x": 1080, "rect": [1000, -200, 150, 200]}]}
	var h := HouseLayout.from_json(d)
	assert_eq(h.rooms.size(), 2)
	var hs := h.hotspot("stairs_head")
	assert_almost_eq(hs.rect.position.y, -900.0, 0.01, "y relative to the floor line")
	var l := h.link_between("hall", "landing")
	assert_almost_eq(l.ax, 1450.0, 0.01)
	assert_almost_eq(l.bx, 1050.0, 0.01)


func test_real_house_json_if_present() -> void:
	if not FileAccess.file_exists(HouseLayout.HOUSE_JSON):
		skip("house.json not written yet (art-house)")
		return
	var h := HouseLayout.load_default()
	assert_eq(h.source, "json")
	for id in HouseLayout.default_room_ids():
		assert_true(h.room(id) != null, "room %s" % id)
	for hid in ["kitchen_honey", "kitchen_pantry_curtain", "hall_front_door", "stairs_foot"]:
		assert_true(h.hotspot(hid) != null, "hotspot %s" % hid)
