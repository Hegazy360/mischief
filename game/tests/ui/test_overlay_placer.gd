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


# --- r3d QA Q-C1 / Q-C2: face boxes, the transient top band, the safe-rect clamp, one cloud ----------------

## The three phone / tablet logical viewports (1080 base, aspect "expand").
const ASPECTS: Array[Vector2] = [Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1440, 1080)]


## [meter, banner] of HudLayout at `vs` (no insets), grown like WorldOverlays grows them.
func _band(vs: Vector2) -> Array[Rect2]:
	var k := UiScale.factor_for(vs)
	var lay := HudLayout.compute(vs, Vector4.ZERO, false, k)
	var pad := WorldOverlays.TRANSIENT_PAD * k
	var out: Array[Rect2] = [(lay[&"meter"] as Rect2).grow(pad), (lay[&"banner"] as Rect2).grow(pad)]
	return out


func test_hard_rects_push_even_an_exempt_thought_off_a_face() -> void:
	for vs in ASPECTS:
		var safe := Rect2(Vector2.ZERO, vs)
		var face := WorldOverlays.face_rect(Vector2(vs.x * 0.5, 400), Vector2(vs.x * 0.5, 330), 12.0)
		var body: Array[Rect2] = [Rect2(vs.x * 0.5 - 120, 300, 240, 600)]
		var hard: Array[Rect2] = [face]
		var th := _item(&"thought", P.THOUGHT, Rect2(vs.x * 0.5 - 40, 300, 222, 192))
		th.anchor = Vector2(vs.x * 0.5, 400)
		th.exempt_anchor = true
		var pv := _item(&"pv", P.PREVIEW, Rect2(vs.x * 0.5 - 70, 330, 146, 128))
		OverlayPlacer.place([th, pv], body, safe, hard)
		for it in [th, pv]:
			var i: OverlayPlacer.Item = it
			assert_false(i.visible and i.rect.intersects(face), "%s clear of the face at %s" % [i.id, vs])
		assert_true(th.visible, "the thought finds room beside the face at %s" % vs)


func test_banner_keep_out_at_every_aspect() -> void:
	for vs in ASPECTS:
		var safe := Rect2(Vector2.ZERO, vs)
		var band := _band(vs)
		var none: Array[Rect2] = []
		# the gramophone's preview of P00 t2190: anchored just under the fuse, its cloud on the RUNNING GAG label
		var w := band[1]
		var pv := _item(&"pv", P.PREVIEW, Rect2(w.position.x - 30.0, w.end.y - 100.0, 146, 128))
		var cap := _item(&"cap", P.CAPTION, Rect2(w.get_center().x - 150.0, w.position.y, 300, 110))
		OverlayPlacer.place([pv, cap], none, safe, band)
		for it in [pv, cap]:
			var i: OverlayPlacer.Item = it
			for b in band:
				assert_false(i.visible and i.rect.intersects(b), "%s off the meter / fuse at %s" % [i.id, vs])
		assert_true(pv.visible, "the preview slides clear (it does not just vanish) at %s" % vs)
		# hidden band (meter + fuse gone): the preview stays where it wants
		var none_hard: Array[Rect2] = []
		OverlayPlacer.place([pv], none, safe, none_hard)
		assert_eq(pv.rect, pv.want)


func test_everything_lands_inside_the_safe_rect_at_every_aspect() -> void:
	for vs in ASPECTS:
		var safe := Rect2(Vector2(60, 0), vs - Vector2(120, 0))   # a punch-hole inset on both sides
		var none: Array[Rect2] = []
		var bubble := _item(&"bubble", P.BUBBLE, Rect2(-80, 240, 270, 173), true)
		var pv := _item(&"pv", P.PREVIEW, Rect2(vs.x - 60, 300, 146, 128))
		var it := _item(&"it", P.ITEM, Rect2(vs.x * 0.5, -40, 116, 132))
		OverlayPlacer.place([bubble, pv, it], none, safe)
		for x in [bubble, pv, it]:
			var i: OverlayPlacer.Item = x
			if i.visible:
				assert_true(safe.encloses(i.rect), "%s inside the safe rect at %s: %s" % [i.id, vs, i.rect])
		assert_true(bubble.visible and bubble.rect.position.x >= safe.position.x, "his bubble is clamped, not hidden")


func test_one_thought_cloud_at_a_time_the_nearest_the_action() -> void:
	var none: Array[Rect2] = []
	var no_hard: Array[Rect2] = []
	for vs in ASPECTS:
		var safe := Rect2(Vector2.ZERO, vs)
		var bubble := _item(&"bubble", P.BUBBLE, Rect2(100, 260, 270, 173), true)
		var th := _item(&"thought", P.THOUGHT, Rect2(vs.x - 500, 300, 222, 192))
		th.anchor = Vector2(vs.x - 560, 380)
		# the action is at Hush (right): her thought shows, his bubble waits
		OverlayPlacer.place([bubble, th], none, safe, no_hard, Vector2(vs.x - 600, 420))
		assert_true(th.visible, "her thought, nearest the action (%s)" % vs)
		assert_false(bubble.visible, "his bubble waits (%s)" % vs)
		# the action is by him: his bubble
		OverlayPlacer.place([bubble, th], none, safe, no_hard, Vector2(200, 420))
		assert_true(bubble.visible)
		assert_false(th.visible)
		# no focus: the §2.5 priority (his bubble)
		OverlayPlacer.place([bubble, th], none, safe)
		assert_true(bubble.visible)
		assert_false(th.visible)
	# previews are not thought clouds: they still show beside one
	var safe2 := Rect2(0, 0, 2400, 1080)
	var b2 := _item(&"bubble", P.BUBBLE, Rect2(100, 260, 270, 173), true)
	var pv := _item(&"pv", P.PREVIEW, Rect2(900, 300, 146, 128))
	OverlayPlacer.place([b2, pv], none, safe2, no_hard, Vector2(1000, 400))
	assert_true(b2.visible and pv.visible)


func test_shared_solve_keeps_its_inputs_and_hard_rects_allocate_nothing() -> void:
	var pl := OverlayPlacer.new()
	var prot: Array[Rect2] = [Rect2(900, 300, 300, 500)]
	var hard: Array[Rect2] = [Rect2(970, 24, 508, 224), Rect2(1000, 320, 90, 90)]
	for f in 3:
		pl.begin_frame()
		pl.request(&"fx_bubble", P.BUBBLE, Rect2(100, 260, 270, 173), Vector2.INF, true)
		pl.request(&"ov_thought", P.THOUGHT, Rect2(1100, 300, 222, 192), Vector2(1040, 380), false, true)
		for i in 6:
			pl.request(StringName("p%d" % i), P.PREVIEW, Rect2(200 + i * 300, 200, 146, 128))
		pl.solve(prot, Rect2(0, 0, 2400, 1080), hard, Vector2(1040, 380))
	assert_eq(pl.last_hard, hard)
	assert_eq(pl.last_focus, Vector2(1040, 380))
	assert_false(pl.item(&"fx_bubble").visible, "one cloud: her thought is nearer the action")
	var ids: Array[StringName] = []
	for i in 6:
		ids.append(StringName("p%d" % i))
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for f in 100:
		pl.begin_frame()
		pl.request(&"fx_bubble", P.BUBBLE, Rect2(100, 260, 270, 173), Vector2.INF, true)
		pl.request(&"ov_thought", P.THOUGHT, Rect2(1100, 300, 222, 192), Vector2(1040, 380), false, true)
		for i in 6:
			pl.request(ids[i], P.PREVIEW, Rect2(200 + i * 300, 200, 146, 128))
		pl.solve(prot, Rect2(0, 0, 2400, 1080), hard, Vector2(1040, 380))
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
