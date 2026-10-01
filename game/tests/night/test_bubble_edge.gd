## FxThoughtBubble near a screen edge (r3d QA Q-C2, fix-hud R1): the awareness glyph and its ear pips move to the
## cloud's inside when the left edge would clip them, come back with hysteresis, and `waiting` (the one-cloud
## rule) fades the bubble apart from `quiet`.
extends TestBase

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


func after_each() -> void:
	if _b != null and is_instance_valid(_b):
		_b.get_parent().remove_child(_b)
		_b.free()
	_b = null


## Places the bubble so its origin lands at screen x `x` (via the head point; no camera, so no HUD-band clamp).
func _at(x: float) -> void:
	_b.thought_bubble(_snap, Vector2(x + 30.0 * 1.333, 600.0), 1.333)
	_b.tick(0.016)


func test_glyph_moves_inside_at_the_left_edge_and_back() -> void:
	var vw := _b.get_viewport_rect().size.x
	_at(vw * 0.5)
	assert_false(_b.glyph_right, "mid-screen: the glyph is left of the cloud")
	var sp := _b.screen_span()
	assert_lt(sp.x, _b.position.x - 100.0, "the drawn span starts at the glyph disc")
	_at(120.0)
	assert_true(_b.glyph_right, "at x 120 the left glyph would clip: drawn right of the cloud")
	sp = _b.screen_span()
	assert_ge(sp.x, 0.0, "nothing drawn past the left edge (%s)" % sp)
	assert_le(sp.y, vw, "nor past the right edge")
	_at(165.0)
	assert_true(_b.glyph_right, "hysteresis: still right just past the threshold")
	_at(260.0)
	assert_false(_b.glyph_right, "back left once the left side clears the edge")


func test_local_span_covers_both_sides() -> void:
	var l := FxThoughtBubble.local_span(false)
	var r := FxThoughtBubble.local_span(true)
	assert_eq(l, Vector2(-115.0, 95.0))
	assert_eq(r, Vector2(-55.0, 155.0))


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
