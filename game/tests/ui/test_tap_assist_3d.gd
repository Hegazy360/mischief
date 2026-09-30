## TapAssist on PROJECTED 3D hit boxes (r3d-hud brief §4.6; REDESIGN §5.5): `WorldView3D.
## hotspot_rects_in_view()` hands screen-space rects (8 box corners → the screen bounding rect), so
## TapAssist resolves in screen px with zoom 1.0 — the 90 px assist, priorities and stacks unchanged.
## Cases: perspective rects that overlap (a nearer prop's box over a farther one), a stacked pair
## 24 px apart (the kettle under the honey), the floor band under a projected lane, and a real
## projection through FakeAnchors' Camera3D at the base framing.
extends TestBase

var _made: Array = []


func after_each() -> void:
	for n in _made:
		if is_instance_valid(n):
			(n as Node).free()
	_made.clear()


func _c(id: String, kind: String, r: Rect2, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "kind": kind, "rect": r, "room": "kitchen"}
	d.merge(extra)
	return d


func test_overlapping_perspective_rects_pick_the_nearest_centre() -> void:
	# the nearer fridge box (bigger on screen) overlaps the farther shelf's box
	var near := _c("kitchen_fridge", "container", Rect2(1000, 400, 220, 360))
	var far := _c("kitchen_fridge_shelf", "rig_point", Rect2(1060, 300, 160, 170))
	var cands := [near, far, _c("floor", "floor", Rect2(0, 760, 2400, 200))]
	var r := TapAssist.resolve(Vector2(1150, 330), cands, 1.0)
	assert_eq(r.get("hotspot"), "kitchen_fridge_shelf", "inside only the shelf's part: the shelf")
	r = TapAssist.resolve(Vector2(1100, 440), cands, 1.0)
	assert_eq(r.get("hotspot"), "kitchen_fridge_shelf", "in the overlap: the nearer centre wins")
	r = TapAssist.resolve(Vector2(1100, 700), cands, 1.0)
	assert_eq(r.get("hotspot"), "kitchen_fridge")
	assert_false(bool(r.get("assisted", true)))


func test_stacked_pair_24_px_apart() -> void:
	var honey := _c("kitchen_honey", "rig_point", Rect2(900, 250, 150, 150), {"stack": "kitchen_kettle"})
	var kettle := _c("kitchen_kettle", "rig_point", Rect2(900, 424, 150, 150), {"stack": "kitchen_kettle"})
	var cands := [honey, kettle]
	assert_eq(TapAssist.resolve(Vector2(975, 300), cands, 1.0).get("hotspot"), "kitchen_honey")
	assert_eq(TapAssist.resolve(Vector2(975, 500), cands, 1.0).get("hotspot"), "kitchen_kettle")
	# in the 24 px gap: assisted to the nearer one
	var g := TapAssist.resolve(Vector2(975, 405), cands, 1.0)
	assert_eq(g.get("hotspot"), "kitchen_honey", "5 px under the honey, 19 px over the kettle")
	assert_true(bool(g.get("assisted", false)))
	g = TapAssist.resolve(Vector2(975, 418), cands, 1.0)
	assert_eq(g.get("hotspot"), "kitchen_kettle")
	# the honey struck tonight (disabled): a tap on it is the kettle via the stack
	honey["enabled"] = false
	var v := TapAssist.resolve(Vector2(975, 300), cands, 1.0)
	assert_eq(v.get("hotspot"), "kitchen_kettle")
	assert_eq(v.get("via"), "kitchen_honey")


func test_assist_radius_is_90_screen_px_at_zoom_1() -> void:
	var cands := [_c("kitchen_sink_tap", "rig_point", Rect2(1800, 400, 150, 150))]
	assert_eq(TapAssist.resolve(Vector2(1800 - 89, 450), cands, 1.0).get("hotspot"), "kitchen_sink_tap")
	assert_true(TapAssist.resolve(Vector2(1800 - 91, 450), cands, 1.0).is_empty(), "no floor: nothing")


func test_floor_band_of_the_projected_lane() -> void:
	var cands := [_c("kitchen", "floor", Rect2(300, 780, 1800, 160)), _c("kitchen_table", "hiding", Rect2(1300, 560, 160, 200))]
	var r := TapAssist.resolve(Vector2(700, 850), cands, 1.0)
	assert_eq(r.get("c"), "move")
	assert_eq(int(r.get("x")), 700, "the x the view then maps to the lane (cam.screen_to_world)")


func test_real_projection_through_the_base_camera() -> void:
	var fa := FakeAnchors.new()
	tree.root.add_child(fa)
	_made.append(fa)
	fa.build_room("kitchen", 17.0, NAN)
	var cands := []
	for id in ["kitchen_kettle", "kitchen_honey", "kitchen_pickle_jar", "kitchen_sink_tap"]:
		var r := fa.prop_screen_rect(id)
		assert_true(r.has_area(), "%s projects" % id)
		cands.append(_c(id, "rig_point", r))
	for c in cands:
		var d: Dictionary = c
		var hit := TapAssist.resolve((d["rect"] as Rect2).get_center(), cands, 1.0)
		assert_eq(hit.get("hotspot"), d["id"], "a tap on %s's projected centre is %s" % [d["id"], d["id"]])
