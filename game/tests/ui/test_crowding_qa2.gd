## r3d QA round 2, Q2-C1 / Q2-C2 / Q2-S2 / 16(a) (docs/review/r3d-qa/readability.md "Round 2"): a preview badge stays
## ATTACHED to its prop (within WorldOverlays.DETACH_MAX of its stalk, else beside the prop, else it waits; its tail
## runs to the prop), his countdown ring is drawn ONCE per target (on the prop's badge; his bubble and the Bellows
## window's chip show the icon only), the needs cloud shows an empty slot, and the overlays' first show is primed
## under the curtain. Layouts at 20:9 / 16:9 / 4:3.
extends TestBase

const ASPECTS: Array[Vector2] = [Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1440, 1080)]
const P := OverlayPlacer.Pri

var _made: Array = []


## An anchor source with a view-like `overlays.bubble` (WorldView3D.overlays.bubble is an FxThoughtBubble).
class BubbleSrc:
	extends FakeAnchors
	var overlays: Object = null


class FakeOverlays:
	extends RefCounted
	var bubble: Node2D = null


## His bubble that can drop its ring (the contract FxThoughtBubble.ring_hidden).
class RingBubble:
	extends Node2D
	var ring_hidden: bool = false


func after_each() -> void:
	for n in _made:
		if is_instance_valid(n):
			(n as Object).free()
	_made.clear()
	UiKit.now_override = -1


func _hud(vs: Vector2) -> Hud:
	UiKit.now_override = 400000
	var hud := Hud.new()
	_made.append(hud)
	hud.layout_size_override = vs
	hud.insets_override = Vector4.ZERO
	hud.relayout()
	var hm := HudModel.new()
	hud.apply(hm)
	hm.applause = 37
	hm.link = 1
	hm.mult_pct = 100
	hm.fuse_frac = 1.0
	hud.apply(hm)
	hud.banner._process(0.5)
	return hud


func _overlays(vs: Vector2, hud: Object = null, src: FakeAnchors = null) -> Array:
	var fa := src if src != null else FakeAnchors.new()
	fa.size_override = vs
	var wo := WorldOverlays.new()
	wo.size_override = vs
	tree.root.add_child(fa)
	tree.root.add_child(wo)
	_made.append(wo)
	_made.append(fa)
	wo.setup(fa, hud)
	return [fa, wo]


func _gram_preview(m: OverlayModel, ring: float) -> OverlayModel.Preview:
	var p := m.add_preview()
	p.hotspot = "parlour_gramophone"
	p.prank = "allegro_go_go"
	p.pictogram = PackedStringArray(["record", "x3", "spiral"])
	p.his_ring_frac = ring
	return p


## The P00 t2190 frame (crowd pkt_04) at `vs`: the gramophone under the fuse's left end, its preview anchor in the
## air above its horn, the APPLAUSE meter + RUNNING GAG fuse shown (hard keep-outs), Bellows far left, Hush right.
func _p00_t2190(vs: Vector2, src: FakeAnchors = null) -> Array:
	var hud := _hud(vs)
	var s := _overlays(vs, hud, src)
	var fa: FakeAnchors = s[0]
	var fuse := hud.transient_rects()[1]
	var ax := fuse.position.x + 30.0
	# the preview anchor ~134 px above the horn top; the prop (ring ± 72) below it
	fa.set_point("parlour_gramophone", &"preview", Vector2(ax, fuse.end.y + 40.0))
	fa.set_point("parlour_gramophone", &"ring", Vector2(ax, fuse.end.y + 40.0 + 134.0 + 72.0))
	fa.set_actor(&"bellows", Rect2(vs.x * 0.02, 470.0, 220.0, 360.0))
	fa.set_actor(&"hush", Rect2(vs.x * 0.72, 480.0, 160.0, 400.0))
	return [fa, s[1], hud]


# --- Q2-C1: attached badges ---------------------------------------------------------------------------------------

func test_the_p00_badge_stays_attached_to_its_gramophone_at_every_aspect() -> void:
	for vs in ASPECTS:
		var s := _p00_t2190(vs)
		var fa: FakeAnchors = s[0]
		var wo: WorldOverlays = s[1]
		var m := OverlayModel.new()
		var pv := _gram_preview(m, 0.7)
		pv.loud = true
		pv.strength = OverlayModel.STRENGTH_FULL
		wo.apply(m)
		var it := wo.placer.item(&"ov_preview_0")
		var pr := fa.prop_screen_rect("parlour_gramophone")
		for r in wo.hard_now():
			assert_false(it.visible and it.rect.intersects(r), "the badge runs into the HUD band %s at %s" % [r, vs])
		if not it.visible:
			# a waiting badge is fine (nothing attached was free); a floating one is not
			continue
		assert_le(it.detach, WorldOverlays.DETACH_MAX * wo.k + 0.01, "within DETACH_MAX of its stalk (%s)" % vs)
		var gap := OverlayPlacer.point_rect_distance(it.rect.get_center(), pr)
		assert_lt(gap, it.rect.size.length() * 0.75, "its centre sits by the gramophone, not by the meter (%s)" % vs)
		var tgt := it.rect.get_center() + wo.previews[0].tail_to
		assert_true(pr.grow(1.0).has_point(tgt), "its tail ends on the gramophone (%s)" % vs)
		assert_true(Rect2(Vector2.ZERO, vs).encloses(it.rect), "inside the screen (%s)" % vs)
	# 20:9 and 16:9 have room beside the prop: it shows there instead of waiting
	for vs in [ASPECTS[0], ASPECTS[1]]:
		var s := _p00_t2190(vs)
		var wo: WorldOverlays = s[1]
		var m := OverlayModel.new()
		_gram_preview(m, 0.7)
		wo.apply(m)
		var it := wo.placer.item(&"ov_preview_0")
		assert_true(it.visible, "shows beside the prop (%s)" % vs)
		assert_ne(it.side, 0, "beside the gramophone, not slid off toward the meter (%s)" % vs)


func test_every_shown_badge_is_within_detach_max_at_every_aspect() -> void:
	# a row of props under a wide keep-out band: every preview that shows is attached; the rest wait
	for vs in ASPECTS:
		var fa := FakeAnchors.new()
		var s := _overlays(vs, null, fa)
		var wo: WorldOverlays = s[1]
		fa.extra_protected = [Rect2(0.0, 0.0, vs.x, 330.0)]
		var m := OverlayModel.new()
		var ids := ["parlour_gramophone", "parlour_piano", "parlour_recliner", "parlour_newspaper"]
		for j in ids.size():
			var x := vs.x * (0.18 + 0.2 * float(j))
			fa.set_point(ids[j], &"preview", Vector2(x, 300.0))
			fa.set_point(ids[j], &"ring", Vector2(x, 520.0))
			var p := m.add_preview()
			p.hotspot = ids[j]
			p.prank = "allegro_go_go"
			p.pictogram = PackedStringArray(["record"])
		wo.apply(m)
		for i in m.preview_count:
			var it := wo.placer.item(StringName("ov_preview_%d" % i))
			if it.visible:
				assert_le(it.detach, WorldOverlays.DETACH_MAX * wo.k + 0.01, "%s attached at %s" % [it.id, vs])
				assert_false(it.rect.intersects(fa.extra_protected[0]), "%s clear of the band at %s" % [it.id, vs])


func test_an_attached_item_never_floats_off_and_takes_a_beside_spot() -> void:
	var safe := Rect2(0, 0, 2400, 1080)
	var band: Array[Rect2] = [Rect2(900, 0, 700, 260)]
	var none: Array[Rect2] = []
	var a := Vector2(950, 280)
	var i := OverlayPlacer.Item.new()
	i.id = &"pv"
	i.priority = P.PREVIEW
	i.want = Rect2(a - Vector2(73, 146), Vector2(146, 146))
	i.anchor = a
	i.anchor_to = Vector2(950, 410)
	i.prop_rect = Rect2(890, 410, 120, 300)
	i.max_detach = 80.0
	i.alt_a = Rect2(Vector2(890 - 12 - 146, 410 - 50), Vector2(146, 146))
	i.alt_b = Rect2(Vector2(1010 + 12, 410 - 50), Vector2(146, 146))
	OverlayPlacer.place([i], band, safe, none)
	assert_true(i.visible)
	assert_eq(i.side, -1, "beside the prop's left, not slid up-left by the band")
	assert_le(i.detach, 80.0)
	# no beside spots and no attached slide: it waits rather than floating 200 px off
	var j := OverlayPlacer.Item.new()
	j.id = &"pv2"
	j.priority = P.PREVIEW
	j.want = i.want
	j.anchor = a
	j.anchor_to = Vector2(950, 410)
	j.max_detach = 10.0
	var wide: Array[Rect2] = [Rect2(700, 0, 900, 300)]
	OverlayPlacer.place([j], wide, safe, none)
	assert_true(not j.visible or j.detach <= 10.01, "never beyond max_detach")
	# an unattached item keeps the old slide / up / wait rule
	var u := OverlayPlacer.Item.new()
	u.id = &"u"
	u.priority = P.ITEM
	u.want = Rect2(1000, 400, 116, 116)
	OverlayPlacer.place([u], [Rect2(700, 380, 800, 160)] as Array[Rect2], safe, none)
	assert_true(u.visible)
	assert_eq(u.side, 0)


func test_segment_rect_distance() -> void:
	var r := Rect2(100, 100, 50, 50)
	assert_eq(OverlayPlacer.segment_rect_distance(Vector2(0, 125), Vector2(300, 125), r), 0.0, "crosses it")
	assert_almost_eq(OverlayPlacer.segment_rect_distance(Vector2(200, 0), Vector2(200, 300), r), 50.0, 0.01)
	assert_almost_eq(OverlayPlacer.segment_rect_distance(Vector2(125, 0), Vector2(125, 60), r), 40.0, 0.01)
	assert_eq(OverlayPlacer.point_rect_distance(Vector2(120, 120), r), 0.0)


func test_attached_placing_allocates_nothing() -> void:
	var pl := OverlayPlacer.new()
	var prot: Array[Rect2] = [Rect2(900, 0, 700, 300), Rect2(0, 900, 400, 180)]
	var safe := Rect2(0, 0, 2400, 1080)
	var ids: Array[StringName] = []
	for i in 6:
		ids.append(StringName("p%d" % i))
	for f in 3:
		_attached_frame(pl, ids, prot, safe, f)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for f in 100:
		_attached_frame(pl, ids, prot, safe, f)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


func _attached_frame(pl: OverlayPlacer, ids: Array[StringName], prot: Array[Rect2], safe: Rect2, f: int) -> void:
	pl.begin_frame()
	for i in 6:
		var a := Vector2(800 + i * 150 + float(f % 2) * 3.0, 320)
		pl.request_attached(ids[i], P.PREVIEW, Rect2(a - Vector2(73, 146), Vector2(146, 146)), a,
			Rect2(a + Vector2(-60, 120), Vector2(120, 200)), 80.0, Rect2(a + Vector2(-170, 60), Vector2(146, 146)), Rect2(a + Vector2(30, 60), Vector2(146, 146)))
	pl.solve(prot, safe)


# --- Q2-C1 / Q2-C2: one countdown ring per target -----------------------------------------------------------------

func _rings_on_screen(wo: WorldOverlays, bubble: Node2D) -> int:
	var n := 0
	for pc in wo.previews:
		if pc.visible and pc.ring_frac >= 0.0:
			n += 1
	if bubble != null and bubble.visible and not bool(bubble.get(&"ring_hidden") if "ring_hidden" in bubble else false):
		n += 1
	return n


func test_one_ring_per_target_his_bubble_shows_the_icon_only() -> void:
	for vs in ASPECTS:
		var src := BubbleSrc.new()
		var ov := FakeOverlays.new()
		var bub := RingBubble.new()
		_made.append(bub)
		ov.bubble = bub
		src.overlays = ov
		var s := _p00_t2190(vs, src)
		var wo: WorldOverlays = s[1]
		var hud: Hud = s[2]
		var m := OverlayModel.new()
		_gram_preview(m, 0.7)
		wo.apply(m)
		assert_true(wo.ring_to_badge, "his bubble can drop its ring: the badge carries it (%s)" % vs)
		if wo.previews[0].visible:
			assert_true(bub.ring_hidden, "his bubble shows the icon only (%s)" % vs)
			assert_true(hud.his_ring_on_prop, "the Bellows-window chip drops its ring too (%s)" % vs)
		assert_le(_rings_on_screen(wo, bub), 1, "one countdown ring for the gramophone (%s)" % vs)
		# no badge with his ring on screen: his bubble keeps its ring
		m.clear()
		wo.apply(m)
		assert_false(bub.ring_hidden, "no badge carries it: his bubble keeps the ring (%s)" % vs)
		assert_false(hud.his_ring_on_prop)


func test_a_bubble_that_cannot_drop_its_ring_keeps_it_and_the_badge_shows_none() -> void:
	for vs in ASPECTS:
		var src := BubbleSrc.new()
		var ov := FakeOverlays.new()
		var bub := Node2D.new()   # today's FxThoughtBubble before it has `ring_hidden`
		_made.append(bub)
		ov.bubble = bub
		src.overlays = ov
		var s := _p00_t2190(vs, src)
		var wo: WorldOverlays = s[1]
		var m := OverlayModel.new()
		_gram_preview(m, 0.7)
		wo.apply(m)
		assert_false(wo.ring_to_badge)
		assert_lt(wo.previews[0].ring_frac, 0.0, "the badge draws no second ring (%s)" % vs)
		assert_eq(_rings_on_screen(wo, bub), 1, "exactly one: his bubble's (%s)" % vs)
		# his bubble off screen (he is in another room): the badge carries the ring again
		bub.visible = false
		wo.apply(m)
		assert_true(wo.ring_to_badge)
		if wo.previews[0].visible:
			assert_ge(wo.previews[0].ring_frac, 0.0, "the badge has it back (%s)" % vs)


func test_the_bellows_window_chip_drops_its_ring_while_a_badge_carries_it() -> void:
	var hud := _hud(ASPECTS[0])
	var hm := HudModel.new()
	hm.pip_next_icon = "tea"
	hm.pip_ring_frac = 0.6
	hud.apply(hm)
	assert_almost_eq(hud.pip.ring_frac, 0.6, 0.001)
	hud.set_his_ring_on_prop(true)
	hud.apply(hm)
	assert_lt(hud.pip.ring_frac, 0.0, "icon only")
	hud.set_his_ring_on_prop(false)
	hud.apply(hm)
	assert_almost_eq(hud.pip.ring_frac, 0.6, 0.001, "back when no badge carries it")


# --- Q2-C2: the N1 kettle (crowd pkt_07) ------------------------------------------------------------------------

func test_the_n1_kettle_badge_reaches_its_kettle_at_every_aspect() -> void:
	for vs in ASPECTS:
		var fa := FakeAnchors.new()
		var s := _overlays(vs, null, fa)
		var wo: WorldOverlays = s[1]
		# t6768: the kettle on its cupboard left of centre, its preview anchor ~150 px above the kettle's top
		var kx := vs.x * 0.41
		fa.set_point("kitchen_kettle", &"preview", Vector2(kx, 420.0))
		fa.set_point("kitchen_kettle", &"ring", Vector2(kx, 642.0))
		fa.set_actor(&"hush", Rect2(vs.x * 0.5, 460.0, 160.0, 420.0))
		fa.set_actor(&"bellows", Rect2(vs.x * 0.8, 420.0, 230.0, 440.0))
		var m := OverlayModel.new()
		var p := m.add_preview()
		p.hotspot = "kitchen_kettle"
		p.prank = "kettle_drum"
		p.pictogram = PackedStringArray(["kettle", "notes", "crack"])
		p.his_ring_frac = 0.4
		wo.apply(m)
		var it := wo.placer.item(&"ov_preview_0")
		assert_true(it.visible, "the kettle's badge shows (%s)" % vs)
		assert_le(it.detach, WorldOverlays.DETACH_MAX * wo.k + 0.01)
		var pr := fa.prop_screen_rect("kitchen_kettle")
		var tgt := it.rect.get_center() + wo.previews[0].tail_to
		assert_true(pr.grow(1.0).has_point(tgt), "its tail runs down to the kettle (%s)" % vs)
		assert_ge(wo.previews[0].tail_to.length(), it.rect.size.y * 0.5, "a chain long enough to reach it (%s)" % vs)


func test_tail_target_is_on_the_props_top_edge() -> void:
	var pr := Rect2(900, 400, 120, 300)
	var t := WorldOverlays.tail_target(Vector2(700, 380), pr, Vector2(960, 260), 1.0)
	assert_true(pr.has_point(t), "on the prop")
	assert_lt(t.y, pr.position.y + 10.0, "at its top")
	assert_lt(t.x, pr.get_center().x, "on the side nearest the cloud")
	assert_eq(WorldOverlays.tail_target(Vector2(700, 380), Rect2(), Vector2(960, 260), 1.0), Vector2(960, 260),
		"no prop rect: the anchor")


# --- Q2-S2: the needs cloud reads as "missing" ---------------------------------------------------------------------

func test_the_needs_cloud_draws_an_empty_slot_without_errors() -> void:
	var pc := PreviewCloud.new()
	pc.set_data(PreviewArt.texture("kettle_drum"), 0.8, UiIcons.item("squeaker"), 0.4, null, false, 1.0)
	pc.set_tail(Vector2(10, 200))
	tree.root.add_child(pc)
	_made.append(pc)
	await tree.process_frame
	assert_true(pc.need_tex != null)
	# the slot sits outside the 78 px pictogram (it never hides part of the joke) and inside the placer's box
	var nc := PreviewCloud.need_center()
	var icon := Rect2(-PreviewCloud.ICON * 0.5, -PreviewCloud.ICON * 0.5 - 4.0, PreviewCloud.ICON, PreviewCloud.ICON)
	assert_lt(Rect2(nc - Vector2(14, 14), Vector2(28, 28)).intersection(icon).get_area(), 60.0, "the slot is off the joke")
	var half := pc.box_size() * 0.5
	assert_ge(half.x, nc.x + PreviewCloud.NEED_DISC * 0.5, "the placer's box covers the slot")


# --- 16(a): the first show is primed under the curtain -----------------------------------------------------------

func test_first_show_primer_pools_every_item_then_hands_the_nodes_back() -> void:
	var s := _overlays(ASPECTS[0])
	var wo: WorldOverlays = s[1]
	wo.warm_first_show(null)
	assert_eq(wo.warm_left, WorldOverlays.WARM_FRAMES)
	for pc in wo.previews:
		assert_true(pc.visible, "every preview kind drawn once")
		assert_lt(pc.modulate.a, 0.05, "nearly transparent")
	assert_true(wo.thought.visible and wo.ring.visible and wo.marker.visible)
	var pooled := wo.placer.items().size()
	assert_ge(pooled, OverlayModel.MAX_PREVIEWS + OverlayModel.MAX_ITEMS + 2, "every placer item exists before PLAY")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	assert_eq(wo.warm_left, 0, "the primer ends after its frames")
	for pc in wo.previews:
		assert_false(pc.visible)
		assert_eq(pc.modulate.a, 1.0)
	assert_false(wo.thought.visible)
	assert_false(wo.marker.visible)
	var m := OverlayModel.new()
	_gram_preview(m, 0.5)
	var fa: FakeAnchors = s[0]
	fa.set_point("parlour_gramophone", &"preview", Vector2(1200, 500))
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	wo.apply(m)
	assert_eq(wo.placer.items().size(), pooled, "no Item made on the first show")
	assert_true(wo.previews[0].visible, "the model owns the nodes again")
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


func test_a_primer_without_frames_gives_the_nodes_back_to_apply() -> void:
	var s := _overlays(ASPECTS[1])
	var wo: WorldOverlays = s[1]
	var fa: FakeAnchors = s[0]
	fa.set_point("parlour_gramophone", &"preview", Vector2(900, 500))
	wo.warm_first_show(null)
	var m := OverlayModel.new()
	_gram_preview(m, -1.0)
	for f in WorldOverlays.WARM_FRAMES + 2:
		wo.apply(m)
	assert_eq(wo.warm_left, 0)
	assert_true(wo.previews[0].visible)
	assert_eq(wo.previews[0].modulate.a, 1.0)


func test_a_tail_never_runs_through_another_cloud() -> void:
	# two props stacked (the N1 spice shelf over the kettle's cupboard): the upper prop's preview would chain down
	# through the kettle's cloud and read as joined to it — it keeps the short tail instead
	for vs in ASPECTS:
		var fa := FakeAnchors.new()
		var s := _overlays(vs, null, fa)
		var wo: WorldOverlays = s[1]
		var x := vs.x * 0.4
		fa.set_point("kitchen_honey", &"preview", Vector2(x, 260.0))
		fa.set_point("kitchen_honey", &"ring", Vector2(x, 620.0))
		fa.set_point("kitchen_kettle", &"preview", Vector2(x, 560.0))
		fa.set_point("kitchen_kettle", &"ring", Vector2(x, 900.0))
		var m := OverlayModel.new()
		for hs in ["kitchen_honey", "kitchen_kettle"]:
			var p := m.add_preview()
			p.hotspot = hs
			p.prank = "achoo_ria" if hs == "kitchen_honey" else "kettle_drum"
			p.pictogram = PackedStringArray(["nose"])
		wo.apply(m)
		var a := wo.placer.item(&"ov_preview_0")
		var b := wo.placer.item(&"ov_preview_1")
		if a.visible and b.visible:
			var end_a := a.rect.get_center() + wo.previews[0].tail_to
			assert_false(wo.previews[0].tail_to != Vector2.ZERO and OverlayPlacer.segment_hits_rect(a.rect.get_center(),
				end_a, b.rect), "the upper chain does not cross the kettle's cloud (%s)" % vs)
		assert_true(b.visible, "the kettle's preview shows (%s)" % vs)
		assert_ne(wo.previews[1].tail_to, Vector2.ZERO, "and keeps its chain to the kettle (%s)" % vs)


func test_rect_rect_distance() -> void:
	assert_eq(OverlayPlacer.rect_rect_distance(Rect2(0, 0, 10, 10), Rect2(5, 5, 10, 10)), 0.0)
	assert_almost_eq(OverlayPlacer.rect_rect_distance(Rect2(0, 0, 10, 10), Rect2(13, 14, 5, 5)), 5.0, 0.001)
