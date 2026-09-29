## Intents → commands with a stub driver / camera / view (the ui intent table, s2-night §4.1), world
## taps → TapAssist → go / move / pin, and the same-frame feedback.
extends TestBase


class StubDriver:
	extends RefCounted
	var cmds: Array = []
	var ff: Array = []
	var snap := ViewSnapshot.new()
	func push_cmd(c: Dictionary) -> void:
		cmds.append(c)
	func set_ff(on: bool) -> void:
		ff.append(on)
	func snapshot() -> ViewSnapshot:
		return snap


class StubCam:
	extends RefCounted
	var hold: Array = []
	var pans: Array = []
	var peeks: int = 0
	var overview: bool = false
	var zoom: float = 1.0
	func set_hold_offset(on: bool) -> void:
		hold.append(on)
	func pan_by(d: Vector2) -> void:
		pans.append(d)
	func pinch(f: float, _m: Vector2) -> void:
		zoom *= f
	func peek(_p: Vector2, _h: float = 1.8, _f: Callable = Callable()) -> void:
		peeks += 1
	func toggle_overview() -> void:
		overview = not overview
	func is_overview() -> bool:
		return overview
	func current_zoom() -> float:
		return zoom
	func visible_world_rect() -> Rect2:
		return Rect2(2400, -1100, 2400, 1200)
	func world_to_screen(p: Vector2) -> Vector2:
		return p - Vector2(2400, -1100)
	func screen_to_world(p: Vector2) -> Vector2:
		return p + Vector2(2400, -1100)
	func view_size() -> Vector2:
		return Vector2(2400, 1080)


class StubFx:
	extends RefCounted
	var ripples: int = 0
	var paths: int = 0
	func ripple(_p: Vector2) -> void:
		ripples += 1
	func path_dots(_pts: PackedVector2Array) -> void:
		paths += 1


class StubView:
	extends RefCounted
	var layout: HouseLayout = HouseLayout.load_default()
	var fx := StubFx.new()
	var hush_view: Variant = null
	var bellows_view: Variant = null
	var unlocked := PackedStringArray(["hall", "parlour", "kitchen"])
	var sparkled: Array = []
	var revealed: Array = []
	func hotspot_rects_in_view() -> Array:
		var out: Array = []
		for hs in layout.hotspots:
			if unlocked.has(hs.room):
				out.append({"id": hs.id, "kind": hs.kind, "rect": hs.rect, "world_rect": hs.rect, "priority": 2})
		return out
	func sparkle(id: String, _s: float) -> void:
		sparkled.append(id)
	func reveal_badges(on: bool) -> void:
		revealed.append(on)


var ni: NightInput
var drv: StubDriver
var cam: StubCam
var wv: StubView
var sent: Array = []


func before_each() -> void:
	ni = NightInput.new()
	drv = StubDriver.new()
	cam = StubCam.new()
	wv = StubView.new()
	ni.driver = drv
	ni.cam = cam
	ni.world_view = wv
	ni.enabled = true
	drv.snap.hush.present = true
	drv.snap.hush.room = "kitchen"
	drv.snap.hush.x = 3600
	drv.snap.hush.state = "IDLE"
	sent = []
	ni.command.connect(func(c: Dictionary) -> void: sent.append(c))


func _names() -> PackedStringArray:
	var out := PackedStringArray()
	for c in drv.cmds:
		out.append("%s%s" % [c["c"], ":%s" % str(c["on"]) if c.has("on") else ""])
	return out


func test_rig_hold_is_rig_on_off_with_the_hold_offset() -> void:
	ni.on_action_down(HudModel.Verb.RIG)
	ni.on_action_up(HudModel.Verb.RIG, false)
	assert_eq(_names(), PackedStringArray(["rig:true", "rig:false"]))
	assert_eq(cam.hold, [true, false], "camera hold offset while held")


func test_freeze_hold() -> void:
	ni.on_action_down(HudModel.Verb.FREEZE)
	ni.on_action_up(HudModel.Verb.FREEZE, true)
	assert_eq(_names(), PackedStringArray(["freeze:true", "freeze:false"]), "released even when cancelled")


func test_verb_is_latched_at_touch_down() -> void:
	ni.on_action_down(HudModel.Verb.RIG)
	ni.on_action_up(HudModel.Verb.FREEZE, false)
	assert_eq(_names(), PackedStringArray(["rig:true", "rig:false"]), "the up of a latched RIG releases the rig")


func test_pop_out_and_double_tap_runs_to_the_pin() -> void:
	drv.snap.hush.state = "HIDDEN"
	ni.on_tapped(Vector2(3000, -60), false)
	assert_eq(String(drv.cmds[0]["c"]), "pin", "a tap while hidden pins")
	ni.on_action_up(HudModel.Verb.GO, false)
	assert_eq(String(drv.cmds[1]["c"]), "pop_out")
	ni.on_action_double_tap(HudModel.Verb.GO)
	var last: Dictionary = drv.cmds[drv.cmds.size() - 1]
	assert_true(String(last["c"]) in ["go", "move"] and bool(last["run"]), "double tap → run to the pin")


func test_pop_out_cancelled_does_nothing() -> void:
	ni.on_action_up(HudModel.Verb.POP_OUT, true)
	assert_eq(drv.cmds.size(), 0)


func test_clarence_tap_squeaks_and_hold_wheezes() -> void:
	ni.on_clarence_down()
	ni.on_clarence_up(120)
	ni.on_clarence_down()
	ni.on_clarence_hold()
	ni.on_clarence_up(900)
	assert_eq(_names(), PackedStringArray(["squeak", "wheeze:true", "wheeze:false"]))


func test_clarence_is_ff_while_hidden() -> void:
	drv.snap.hush.state = "HIDDEN"
	ni.on_clarence_down()
	ni.on_clarence_hold()
	ni.on_clarence_up(1400)
	assert_eq(drv.ff, [true, false], "⏩ on while held")
	assert_eq(drv.cmds.size(), 0, "never a squeak from a hiding spot")


## A floor point in an open room ≥ 120 px from every hotspot (TapAssist snaps within 90 px at zoom 1).
func _open_floor() -> Vector2:
	for r in wv.layout.rooms:
		if not wv.unlocked.has(r.id):
			continue
		var fy := wv.layout.room_floor_y(r.id)
		var x := float(r.x0) + 20.0
		while x < float(r.x1) - 20.0:
			var p := Vector2(x, fy - 20)
			var ok := true
			for hs in wv.layout.hotspots:
				if hs.rect.grow(120.0).has_point(p):
					ok = false
					break
			if ok:
				return p
			x += 20.0
	return Vector2.INF


func test_floor_tap_is_move_and_double_is_run() -> void:
	var p := _open_floor()
	if p == Vector2.INF:
		skip("no open kitchen floor away from hotspots")
		return
	ni.on_tapped(p, false)
	assert_eq(String(drv.cmds[0]["c"]), "move")
	assert_false(bool(drv.cmds[0]["run"]))
	ni.on_tapped(p, true)
	assert_true(bool(drv.cmds[1]["run"]), "double tap runs")


func test_hotspot_tap_is_go_with_feedback_in_the_same_frame() -> void:
	var hs := wv.layout.hotspot("kitchen_honey")
	if hs == null:
		skip("no kitchen_honey hotspot")
		return
	ni.on_tapped(hs.rect.get_center(), false)
	assert_eq(String(drv.cmds[0]["c"]), "go")
	assert_eq(String(drv.cmds[0]["hotspot"]), "kitchen_honey")
	assert_eq(wv.fx.ripples, 1, "ripple this frame")
	assert_eq(wv.fx.paths, 1, "path dots this frame")


func test_frozen_tap_pins() -> void:
	drv.snap.hush.state = "FROZEN"
	var fy := wv.layout.room_floor_y("kitchen")
	ni.on_tapped(Vector2(3300, fy - 20), false)
	assert_eq(String(drv.cmds[0]["c"]), "pin")


func test_pan_and_pinch_never_move_hush() -> void:
	ni.on_pan(Vector2(120, 0))
	ni.on_pinch(0.8, Vector2(1200, 540))
	assert_eq(drv.cmds.size(), 0)
	assert_eq(cam.pans.size(), 1)
	assert_between(cam.zoom, 0.79, 0.81)


func test_pip_peek_holds_while_the_finger_is_down() -> void:
	ni.on_pip_tap()
	ni.advance(0.016)
	ni.advance(0.016)
	var held := cam.peeks
	ni.on_pip_release()
	ni.advance(0.016)
	assert_ge(held, 3, "peek re-issued every frame while held")
	assert_eq(cam.peeks, held, "stops on release")


func test_overview_toggles() -> void:
	ni.on_overview_tap()
	assert_true(cam.overview)


func test_long_press_reveals_badges() -> void:
	ni.on_long_pressed(Vector2(3000, -100))
	assert_eq(wv.revealed, [true])
	ni.advance(2.1)
	assert_eq(wv.revealed, [true, false], "2 s reveal")


func test_disabled_input_pushes_nothing() -> void:
	ni.enabled = false
	ni.on_action_down(HudModel.Verb.RIG)
	ni.on_clarence_down()
	ni.on_clarence_up(100)
	ni.on_tapped(Vector2(3300, -20), false)
	assert_eq(drv.cmds.size(), 0)


func test_release_holds_on_pause() -> void:
	ni.on_action_down(HudModel.Verb.RIG)
	ni.release_holds()
	assert_eq(_names(), PackedStringArray(["rig:true", "rig:false"]))


func test_command_signal_mirrors_pushes() -> void:
	ni.on_clarence_down()
	ni.on_clarence_up(100)
	assert_eq(sent.size(), 1)
