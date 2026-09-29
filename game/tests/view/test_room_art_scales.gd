## WorldView.room_art_scales (s2-fix G #7, texture memory): tonight's rooms at ART_SCALE, the unlit
## set on tonight's floor at 1×, the unlit rooms on another floor (a strip under the HUD band) at ¾×,
## rooms no camera can frame without art.
extends TestBase

var wv: WorldView = null


func before_each() -> void:
	wv = WorldView.new()
	wv.layout = HouseLayout.load_default()


func after_each() -> void:
	if is_instance_valid(wv):
		wv.free()


func test_n01_rooms() -> void:
	wv.unlocked = PackedStringArray(["porch", "hall", "parlour", "kitchen"])
	var s := wv.room_art_scales()
	for r in ["porch", "hall", "parlour", "kitchen"]:
		assert_eq(float(s[r]), -1.0, "%s is lit: ART_SCALE" % r)
	assert_eq(float(s["conservatory"]), ViewKit.LOCKED_SCALE, "same floor, in reach: 1×")
	assert_eq(float(s["garden"]), ViewKit.NO_ART, "out of every camera's reach")
	for r in ["landing", "bathroom", "bedroom", "dressing"]:
		assert_eq(float(s[r]), ViewKit.OTHER_FLOOR_SCALE, "%s is upstairs: ¾×" % r)


func test_an_upstairs_night_dims_the_ground_floor() -> void:
	wv.unlocked = PackedStringArray(["bathroom", "bedroom"])
	var s := wv.room_art_scales()
	assert_eq(float(s["bathroom"]), -1.0)
	assert_eq(float(s["landing"]), ViewKit.LOCKED_SCALE, "same floor as tonight")
	assert_eq(float(s["kitchen"]), ViewKit.OTHER_FLOOR_SCALE, "the ground floor is the other floor tonight")


func test_the_house_plan_packs_the_unlit_set_at_its_room_scale() -> void:
	wv.unlocked = PackedStringArray(["porch", "hall", "parlour", "kitchen"])
	var s := wv.room_art_scales()
	var plan := HouseArt.plan(wv.layout, s)
	var seen_up := 0
	for path in plan:
		var room := String(plan[path][1])
		var sc := float(plan[path][0])
		# (a path shared with a brighter room is packed at the larger scale)
		if s.get(room, -1.0) == ViewKit.OTHER_FLOOR_SCALE:
			assert_true(sc >= ViewKit.OTHER_FLOOR_SCALE - 0.001, "%s (%s) %.2f" % [path, room, sc])
			if is_equal_approx(sc, ViewKit.OTHER_FLOOR_SCALE):
				seen_up += 1
		elif s.get(room, -1.0) == ViewKit.LOCKED_SCALE:
			assert_true(sc >= ViewKit.LOCKED_SCALE - 0.001, "%s (%s) %.2f" % [path, room, sc])
	assert_gt(seen_up, 0, "upstairs props / decor are in the plan")
