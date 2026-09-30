## The Hud owns the Bellows window's frame (REDESIGN_3D §2.2, index §7.9): attach_pip() takes any view
## with get_texture() / is_shown() / is_escalated() and the shown_changed / pip_resized signals
## (PipView3D — here a fake, so the test outlives the 2D PipView); 400 × 225 at (W−S−424, T+24); the
## escalated 704 × 396 Gag-Cam window keeps the top-right corner, clears the Script chip, the meter and
## the action button's column, and pushes the overview button out of its way — at every size and inset.
extends TestBase

const SIZES := [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1920, 1440), Vector2(2520, 1080)]
const INSETS := [Vector4(0, 0, 0, 0), Vector4(162, 0, 162, 58), Vector4(120, 0, 0, 20), Vector4(0, 40, 0, 0)]

var hud: Hud
var pv: _FakeView


## A stand-in for PipView3D's HUD-facing surface.
class _FakeView:
	extends Node
	signal shown_changed(on: bool)
	signal pip_resized(new_size: Vector2i)
	var tex := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var shown := false
	var esc := false

	func get_texture() -> Texture2D:
		return tex

	func is_shown() -> bool:
		return shown

	func is_escalated() -> bool:
		return esc

	func set_visible_if(on: bool) -> void:
		if on != shown:
			shown = on
			shown_changed.emit(on)

	func escalate(on: bool) -> void:
		esc = on
		pip_resized.emit(Vector2i(704, 396) if on else Vector2i(400, 225))


func before_each() -> void:
	UiKit.now_override = 100000
	hud = Hud.new()
	hud.layout_size_override = Vector2(2400, 1080)
	hud.insets_override = Vector4.ZERO
	hud.relayout()


func after_each() -> void:
	if pv != null and is_instance_valid(pv):
		pv.free()
	pv = null
	hud.free()
	UiKit.now_override = -1


static func gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return maxf(dx, dy) if (dx == 0.0 or dy == 0.0) else sqrt(dx * dx + dy * dy)


func test_escalated_window_fits_at_every_size_and_inset() -> void:
	for vs in SIZES:
		for ins in INSETS:
			for lh in [false, true]:
				var k := UiScale.factor_for(vs)
				var L := HudLayout.compute(vs, ins, lh, k)
				var sym := SafeArea.symmetric(ins)
				var safe := Rect2(sym.x, sym.y, vs.x - sym.x - sym.z, vs.y - sym.y - sym.w)
				var e: Rect2 = L[&"pip_escalated"]
				var p: Rect2 = L[&"pip"]
				var tag := "%s ins=%s lh=%s" % [vs, ins, lh]
				assert_true(safe.encloses(e), "escalated inside the safe area " + tag)
				assert_almost_eq(e.size.x / e.size.y, 704.0 / 396.0, 0.01, "aspect kept " + tag)
				assert_ge(e.size.x, 400.0 * k - 0.5, "never smaller than the normal window " + tag)
				assert_almost_eq(e.position.y, p.position.y, 0.01, "same top edge " + tag)
				if lh:
					assert_almost_eq(e.position.x, p.position.x, 0.01, "left-handed: same left edge " + tag)
				else:
					assert_almost_eq(e.end.x, p.end.x, 0.01, "same right edge " + tag)
				assert_ge(gap(e, L[&"meter"]), 24.0 * k - 0.01, "clear of the meter " + tag)
				assert_ge(gap(e, L[&"script"]), 24.0 * k - 0.01, "clear of the Script chip " + tag)
				var a: Rect2 = L[&"action"]
				assert_le(e.end.y + 24.0 * k, a.position.y + 0.01, "above the action column " + tag)
				var ov: Rect2 = L[&"overview_escalated"]
				assert_true(safe.encloses(ov), "overview inside " + tag)
				for key in [&"pip_escalated", &"meter", &"action", &"pause", &"script", &"tray", &"clarence"]:
					assert_ge(gap(ov, L[key]), 24.0 * k - 0.01, "escalated overview vs %s %s" % [key, tag])
				if vs == Vector2(2400, 1080) and ins == Vector4.ZERO:
					assert_eq(e.size, Vector2(704, 396), "full size on a 20:9 phone")


func test_attach_pip_follows_the_view() -> void:
	pv = _FakeView.new()
	hud.attach_pip(pv)
	assert_eq(hud.pip_view, pv)
	assert_eq(hud.pip.texture, pv.get_texture(), "the frame shows the view's texture")
	assert_false(hud.pip.shown)
	pv.set_visible_if(true)
	assert_true(hud.pip.shown, "shown_changed → frame shown")
	assert_eq(hud.pip_rect(), hud.layout[&"pip"], "400 × 225 at (W−S−424, T+24)")
	assert_eq(hud.pip_rect().position, Vector2(2400 - 424, 24))
	pv.escalate(true)
	assert_true(hud.pip.escalated, "pip_resized → escalated")
	assert_eq(hud.pip_rect(), hud.layout[&"pip_escalated"], "the Gag-Cam window")
	assert_eq(hud.overview.position, (hud.layout[&"overview_escalated"] as Rect2).position, "overview moved")
	pv.escalate(false)
	assert_false(hud.pip.escalated)
	assert_eq(hud.pip_rect(), hud.layout[&"pip"])
	assert_eq(hud.overview.position, (hud.layout[&"overview"] as Rect2).position)
	pv.set_visible_if(false)
	assert_false(hud.pip.shown, "hidden with the view")


func test_attached_view_overrides_the_model() -> void:
	pv = _FakeView.new()
	hud.attach_pip(pv)
	var m := HudModel.new()
	m.pip_visible = true
	m.pip_escalated = true
	m.pip_frame_tier = 3
	m.pip_glyph = "blinded"
	hud.apply(m)
	assert_false(hud.pip.shown, "the view (hidden) wins over pip_visible")
	assert_false(hud.pip.escalated)
	assert_eq(hud.pip.tier, 3, "the tier still comes from the model")
	assert_eq(hud.pip.glyph_id, "blinded")


func test_next_activity_chip_in_the_window() -> void:
	var m := HudModel.new()
	m.pip_visible = true
	m.pip_next_icon = "tea"
	m.pip_ring_frac = 0.4
	hud.apply(m)
	assert_true(hud.pip.next_icon != null, "his next activity's icon")
	assert_almost_eq(hud.pip.ring_frac, 0.4, 0.001, "the bubble's ring")


func test_bow_slides_under_the_open_window() -> void:
	var m := HudModel.new()
	m.bow_visible = true
	hud.apply(m)
	assert_true(hud.bow.visible)
	assert_eq(hud.bow.position, (hud.layout[&"bow"] as Rect2).position, "top-right while the window is closed")
	m.pip_visible = true
	hud.apply(m)
	assert_eq(hud.bow.position, (hud.layout[&"bow_low"] as Rect2).position, "under the open window")
	assert_ge(gap(Rect2(hud.bow.position, hud.bow.size), hud.pip_rect()), 23.99)


func test_escalated_placement_at_16x9_and_notch() -> void:
	pv = _FakeView.new()
	hud.attach_pip(pv)
	pv.set_visible_if(true)
	for ins in INSETS:
		hud.layout_size_override = Vector2(1920, 1080)
		hud.insets_override = ins
		hud.relayout()
		pv.escalate(true)
		var r := hud.pip_rect()
		assert_eq(r, hud.layout[&"pip_escalated"], "placed at %s" % ins)
		assert_ge(gap(r, hud.layout[&"meter"]), 24.0, "meter clear at %s" % ins)
		assert_ge(gap(hud.layout[&"overview_escalated"], r), 24.0, "overview clear at %s" % ins)
		pv.escalate(false)


func test_pip_tap_is_an_intent() -> void:
	pv = _FakeView.new()
	hud.attach_pip(pv)
	pv.set_visible_if(true)
	var n := [0]
	hud.pip_tap.connect(func() -> void: n[0] += 1)
	hud.pip.touch(true, Vector2(100, 100), 3)
	assert_eq(n[0], 1, "touch-down on the window → pip_tap (peek)")
	hud.pip.touch(false, Vector2(100, 100), 3)


func test_detach() -> void:
	pv = _FakeView.new()
	hud.attach_pip(pv)
	hud.attach_pip(null)
	assert_true(hud.pip_view == null)
	pv.set_visible_if(true)
	assert_false(hud.pip.shown, "a detached view no longer drives the frame")
