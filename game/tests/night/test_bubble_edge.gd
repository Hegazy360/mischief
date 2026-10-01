## FxThoughtBubble: one thing per head (r3d QA2 Q2-C1) — while his thought shows, no awareness-glyph disc and no
## empty ear-pip slots beside the cloud (heard pips ride on the cloud's rim); the glyph shows alone only without a
## thought; `ring_hidden` (one countdown ring per target, r3d-fix-hud3 R1) drops the ring but keeps the icon; nothing
## is drawn past the cloud's span at a screen edge; `waiting` (the one-cloud rule) fades the bubble apart from `quiet`.
extends TestBase

const U := 1.333

var _b: FxThoughtBubble = null
var _snap: ViewSnapshot = null


func before_each() -> void:
	_b = FxThoughtBubble.new()
	tree.root.add_child(_b)
	_snap = ViewSnapshot.new()
	_snap.bellows.present = true
	_snap.bellows.facing = 1
	_snap.bubble_next = "tea"
	_snap.bubble_glyph = "calm"
	_snap.bubble_ear_pips = 2
	_snap.bubble_ring_ticks = 120


func after_each() -> void:
	if _b != null and is_instance_valid(_b):
		_b.get_parent().remove_child(_b)
		_b.free()
	_b = null


## Places the bubble so its origin lands at screen x `x` (via the head point; no camera, so no HUD-band clamp); the
## route-change pop is run out so the scale is the plain unit.
func _at(x: float) -> void:
	_b.thought_bubble(_snap, Vector2(x + 30.0 * U, 600.0), U)
	_b.tick(0.3)


func test_no_glyph_beside_the_cloud_while_his_thought_shows() -> void:
	_at(600.0)
	assert_true(_b.thought_on(), "the next activity shows")
	assert_false(_b.glyph_shown, "no awareness-glyph disc / pip slots beside the cloud (one thing per head)")
	var sp := _b.screen_span()
	assert_almost_eq(sp.x, _b.position.x + FxThoughtBubble.CLOUD_SPAN.x * U, 0.5, "the span starts at the cloud")
	assert_almost_eq(sp.y, _b.position.x + FxThoughtBubble.CLOUD_SPAN.y * U, 0.5, "and ends at the cloud")


func test_the_glyph_shows_alone_without_a_thought() -> void:
	_snap.bubble_next = ""
	_at(600.0)
	assert_false(_b.thought_on(), "no next activity")
	assert_true(_b.glyph_shown, "the awareness glyph stands alone where the cloud would be")
	_snap.bubble_next = "tea"
	_at(600.0)
	assert_true(_b.thought_on())
	assert_false(_b.glyph_shown, "the thought comes back: the glyph goes")


func test_hidden_bubble_shows_neither() -> void:
	_snap.bellows.present = false
	_at(600.0)
	assert_false(_b.visible)
	assert_false(_b.thought_on())
	assert_false(_b.glyph_shown)


func test_nothing_past_the_cloud_at_the_left_edge() -> void:
	var vw := _b.get_viewport_rect().size.x
	for x in [120.0, 165.0, 260.0, vw * 0.5]:
		_at(x)
		assert_false(_b.glyph_right, "the glyph never sits beside the cloud (x %s)" % x)
		var sp := _b.screen_span()
		assert_almost_eq(sp.x, _b.position.x + FxThoughtBubble.CLOUD_SPAN.x * U, 0.5, "cloud's left lobe (x %s)" % x)


func test_local_span_is_the_cloud_on_both_sides() -> void:
	assert_eq(FxThoughtBubble.local_span(false), FxThoughtBubble.CLOUD_SPAN)
	assert_eq(FxThoughtBubble.local_span(true), FxThoughtBubble.CLOUD_SPAN)


func test_heard_pips_ride_on_the_cloud_rim() -> void:
	# every rim bead: below and right of the icon centre (the lower-right rim, away from the tail puffs), outside the
	# ring, inside the cloud's span
	var c_x := -FxThoughtBubble.W * 0.5 + 20.0 + 75.0
	for i in FxThoughtBubble.RIM_PIP_ANG.size():
		var a := FxThoughtBubble.RIM_PIP_ANG[i]
		var off := Vector2(cos(a), sin(a)) * FxThoughtBubble.RIM_PIP_R
		assert_gt(off.y, 0.0, "below the icon centre (%d)" % i)
		assert_gt(off.x, 0.0, "right of it (%d)" % i)
		assert_le(c_x + off.x + FxThoughtBubble.RIM_PIP * 0.5, FxThoughtBubble.CLOUD_SPAN.y + 0.5, "inside the span (%d)" % i)
		assert_gt(off.length(), FxThoughtBubble.RING_R + FxThoughtBubble.RING_W * 0.5, "outside the ring (%d)" % i)


func test_ring_hidden_flag() -> void:
	_at(600.0)
	assert_false(_b.ring_hidden, "default: the bubble carries his ring")
	assert_true("ring_hidden" in _b, "the duck-typed contract WorldOverlays looks for")
	_b.ring_hidden = true
	_at(600.0)
	assert_true(_b.ring_hidden)
	assert_true(_b.thought_on(), "the icon stays while the ring is on the prop's badge")
	assert_true(_b.visible)


func test_waiting_fades_apart_from_quiet() -> void:
	_at(600.0)
	_b.waiting = true
	for i in 20:
		_b.tick(0.016)
	assert_lt(_b.modulate.a, 0.05, "waiting fades it out")
	_b.waiting = false
	for i in 20:
		_b.tick(0.016)
	assert_gt(_b.modulate.a, 0.95, "and back")
	assert_false(_b.quiet, "quiet untouched")
