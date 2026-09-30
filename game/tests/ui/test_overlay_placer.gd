## OverlayPlacer (REDESIGN_3D §2.5): priority order, slide sideways → up → wait, protected rects,
## the safe-area clamp, the fixed bubble, previews under the thought fade, the anchor exemption,
## the shared per-frame registry and no allocation once warm.
extends TestBase

const SAFE := Rect2(0, 0, 2400, 1080)
const P := OverlayPlacer.Pri


func _item(id: StringName, pri: int, r: Rect2, fixed: bool = false) -> OverlayPlacer.Item:
	var i := OverlayPlacer.Item.new()
	i.id = id
	i.priority = pri
	i.want = r
	i.fixed = fixed
	return i


func test_free_item_stays_where_it_wants() -> void:
	var a := _item(&"a", P.PREVIEW, Rect2(1000, 400, 112, 90))
	var none: Array[Rect2] = []
	OverlayPlacer.place([a], none, SAFE)
	assert_eq(a.rect, a.want)
	assert_true(a.visible)


func test_lower_priority_slides_sideways_first() -> void:
	var th := _item(&"thought", P.THOUGHT, Rect2(1000, 400, 180, 144))
	var pv := _item(&"item", P.ITEM, Rect2(1100, 420, 116, 132))
	var none: Array[Rect2] = []
	OverlayPlacer.place([pv, th], none, SAFE)
	assert_eq(th.rect, th.want, "the higher one keeps its place (order of the array does not matter)")
	assert_true(pv.visible)
	assert_false(pv.rect.intersects(th.rect))
	assert_eq(pv.rect.position.y, pv.want.position.y, "sideways, not up")
	assert_le(absf(pv.rect.position.x - pv.want.position.x), pv.want.size.x + 0.01, "≤ one width")


func test_then_up_then_wait() -> void:
	# a wide protected band blocks every sideways slot: the item goes up
	var block: Array[Rect2] = [Rect2(700, 380, 800, 160)]
	var it := _item(&"x", P.ITEM, Rect2(1000, 400, 116, 116))
	OverlayPlacer.place([it], block, SAFE)
	assert_true(it.visible)
	assert_lt(it.rect.position.y, it.want.position.y, "slid up")
	assert_le(it.want.position.y - it.rect.position.y, OverlayPlacer.MAX_UP + 0.01)
	assert_false(it.rect.intersects(block[0]))
	# a band too tall to escape: it waits
	var tall: Array[Rect2] = [Rect2(600, 150, 1100, 500)]
	var w := _item(&"w", P.ITEM, Rect2(1000, 400, 116, 116))
	OverlayPlacer.place([w], tall, SAFE)
	assert_false(w.visible, "no room: waits")


func test_fixed_bubble_only_clamps_and_wins() -> void:
	var bubble := _item(&"bubble", P.BUBBLE, Rect2(2350, -40, 200, 170), true)
	var cap := _item(&"caption", P.CAPTION, Rect2(2250, 20, 300, 110))
	var none: Array[Rect2] = []
	OverlayPlacer.place([cap, bubble], none, SAFE)
	assert_eq(bubble.rect, Rect2(2200, 0, 200, 170), "clamped into the safe area, not moved otherwise")
	assert_false(cap.visible and cap.rect.intersects(bubble.rect), "the caption yields")


func test_previews_under_the_thought_fade_instead_of_moving() -> void:
	var th := _item(&"thought", P.THOUGHT, Rect2(1000, 400, 180, 144))
	var pv := _item(&"pv", P.PREVIEW, Rect2(1050, 420, 112, 90))
	var none: Array[Rect2] = []
	OverlayPlacer.place([th, pv], none, SAFE)
	assert_eq(pv.rect, pv.want)
	assert_true(pv.faded)


func test_anchor_exemption_for_the_thought() -> void:
	var hush: Array[Rect2] = [Rect2(900, 300, 300, 500)]
	var th := _item(&"thought", P.THOUGHT, Rect2(1000, 320, 180, 144))
	th.anchor = Vector2(1050, 360)
	th.exempt_anchor = true
	OverlayPlacer.place([th], hush, SAFE)
	assert_eq(th.rect, th.want, "her own +48 rect does not push her thought away")
	var other := _item(&"o", P.PREVIEW, Rect2(1000, 320, 112, 90))
	OverlayPlacer.place([other], hush, SAFE)
	assert_ne(other.rect, other.want, "anything else is pushed off Hush")


func test_shared_registry_pools_by_id() -> void:
	var pl := OverlayPlacer.new()
	pl.begin_frame()
	var a := pl.request(&"cap", P.CAPTION, Rect2(10, 10, 100, 50))
	var none: Array[Rect2] = []
	pl.solve(none, SAFE)
	pl.begin_frame()
	var b := pl.request(&"cap", P.CAPTION, Rect2(20, 10, 100, 50))
	assert_eq(a, b, "same id → same pooled item")
	assert_eq(pl.items().size(), 1)
	pl.begin_frame()
	pl.solve(none, SAFE)
	assert_false(pl.item(&"cap").active, "not requested this frame → skipped")


func test_place_allocates_nothing() -> void:
	var pl := OverlayPlacer.new()
	var prot: Array[Rect2] = [Rect2(900, 300, 300, 500), Rect2(0, 900, 400, 180)]
	for f in 3:
		pl.begin_frame()
		for i in 8:
			pl.request(StringName("p%d" % i), P.PREVIEW, Rect2(200 + i * 150, 420, 112, 90))
		pl.solve(prot, SAFE)
	var ids: Array[StringName] = []
	for i in 8:
		ids.append(StringName("p%d" % i))
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for f in 100:
		pl.begin_frame()
		for i in 8:
			pl.request(ids[i], P.PREVIEW, Rect2(200 + i * 150, 420, 112, 90))
		pl.solve(prot, SAFE)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
