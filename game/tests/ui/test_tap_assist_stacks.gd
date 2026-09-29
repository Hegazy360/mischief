## TapAssist stacks (art-house request, s2-ui §4.1.4): a tap inside a DISABLED hotspot that shares
## a house.json `stacks` entry with an enabled one resolves to the enabled partner; a disabled
## hotspot with no partner is ignored (floor move).
extends TestBase


## The hall stairs in a Night without RUG BURN: the rug rods (rig point) are disabled and stacked
## with the stairs foot.
func _stairs() -> Array:
	return [
		{"id": "stairs_rods", "kind": "rig_point", "rect": Rect2(0, -200, 200, 200), "room": "hall",
			"enabled": false, "stack": "stairs_rods+stairs_foot"},
		{"id": "stairs_foot", "kind": "stairs", "rect": Rect2(220, -420, 180, 420), "room": "hall",
			"enabled": true, "stack": "stairs_rods+stairs_foot"},
		{"id": "hall_clock_case", "kind": "hiding", "rect": Rect2(900, -330, 160, 330), "room": "hall"},
		{"id": "floor_hall", "kind": "floor", "rect": Rect2(-400, -640, 2000, 640), "room": "hall"},
	]


## The fridge in Night 1: the top door (DINNER's rig point) is disabled, the fridge container live.
func _fridge() -> Array:
	return [
		{"id": "kitchen_fridge", "kind": "container", "rect": Rect2(2000, -300, 180, 300), "room": "kitchen",
			"enabled": true, "stack": "kitchen_fridge+kitchen_fridge_shelf"},
		{"id": "kitchen_fridge_shelf", "kind": "rig_point", "rect": Rect2(2000, -470, 180, 150), "room": "kitchen",
			"enabled": false, "stack": "kitchen_fridge+kitchen_fridge_shelf"},
		{"id": "kitchen_honey", "kind": "rig_point", "rect": Rect2(1400, -300, 144, 144), "room": "kitchen"},
		{"id": "floor_kitchen", "kind": "floor", "rect": Rect2(1000, -640, 1600, 640), "room": "kitchen"},
	]


func test_bottom_stair_steps_without_rug_burn_climb_the_stairs() -> void:
	var r := TapAssist.resolve(Vector2(100, -100), _stairs(), 1.0)
	assert_eq(r.get("c"), "go")
	assert_eq(r.get("hotspot"), "stairs_foot", "the disabled rods resolve to the stairs")
	assert_eq(r.get("kind"), "stairs")
	assert_eq(r.get("via"), "stairs_rods")
	assert_false(bool(r.get("assisted")), "an exact tap on the stack")


func test_fridge_top_door_in_night_1_opens_the_fridge() -> void:
	var r := TapAssist.resolve(Vector2(2090, -400), _fridge(), 1.0)
	assert_eq(r.get("hotspot"), "kitchen_fridge")
	assert_eq(r.get("kind"), "container")
	assert_eq(r.get("via"), "kitchen_fridge_shelf")


func test_enabled_partner_itself_is_unchanged() -> void:
	var r := TapAssist.resolve(Vector2(2090, -100), _fridge(), 1.0)
	assert_eq(r.get("hotspot"), "kitchen_fridge")
	assert_false(r.has("via"), "a direct hit has no via")


func test_disabled_hotspot_with_no_partner_is_a_floor_move() -> void:
	var cands := [
		{"id": "hall_phone", "kind": "rig_point", "rect": Rect2(500, -300, 144, 144), "room": "hall", "enabled": false},
		{"id": "floor_hall", "kind": "floor", "rect": Rect2(-400, -640, 2000, 640), "room": "hall"},
	]
	var r := TapAssist.resolve(Vector2(560, -240), cands, 1.0)
	assert_eq(r.get("c"), "move", "no partner: the tap falls through to the floor")
	assert_eq(r.get("room"), "hall")
	assert_eq(int(r.get("x")), 560)


func test_disabled_stack_whose_partners_are_all_disabled_is_a_floor_move() -> void:
	var cands := _stairs()
	(cands[1] as Dictionary)["enabled"] = false
	var r := TapAssist.resolve(Vector2(100, -100), cands, 1.0)
	assert_eq(r.get("c"), "move")


func test_disabled_hotspot_never_wins_the_assist_itself() -> void:
	# 60 px right of the disabled rods and 40 px left of the stairs foot's rect? no: pick a point
	# only near the rods: it must resolve to the partner, never to "stairs_rods"
	var r := TapAssist.resolve(Vector2(-60, -100), _stairs(), 1.0)
	assert_eq(r.get("hotspot"), "stairs_foot", "assisted onto a disabled stacked hotspot → its partner")
	assert_true(bool(r.get("assisted")))
	assert_eq(r.get("via"), "stairs_rods")


func test_candidates_without_the_new_fields_behave_as_before() -> void:
	var cands := [
		{"id": "kitchen_honey", "kind": "rig_point", "rect": Rect2(1000, -300, 144, 144), "room": "kitchen"},
		{"id": "floor_kitchen", "kind": "floor", "rect": Rect2(900, -640, 1200, 640), "room": "kitchen"},
	]
	var r := TapAssist.resolve(Vector2(1050, -250), cands, 1.0)
	assert_eq(r.get("hotspot"), "kitchen_honey")
	assert_true(TapAssist.is_enabled(cands[0]), "enabled defaults to true")
	assert_true(TapAssist.stack_partner(cands[0], cands).is_empty(), "no stack: no partner")
