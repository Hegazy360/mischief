## r3d QA round 1, Q-C1 / Q-C2 (docs/review/r3d-qa/readability.md §4): the crowding rules that answer the two
## "yes, crowded" frames — while Hush rigs her thought goes, the ring passes BEHIND a face next to the prop, no
## cloud covers a face box, the transient APPLAUSE meter + RUNNING GAG fuse are keep-outs, one thought cloud at a
## time, the teaching glove steps off the action button once the hold starts and the held button shows one icon.
extends TestBase

const FIXTURE := "res://tests/ui/fixtures/previews.json"
const ASPECTS: Array[Vector2] = [Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1440, 1080)]

var _made: Array = []
var db: ContentDB = null


func before_each() -> void:
	if db == null:
		db = ContentDB.load_dir("res://data")


func after_each() -> void:
	for n in _made:
		if is_instance_valid(n):
			(n as Object).free()
	_made.clear()
	UiKit.now_override = -1


func _overlays(vs: Vector2, hud: Object = null) -> Array:
	var fa := FakeAnchors.new()
	fa.size_override = vs
	var cx := vs.x * 0.5
	fa.set_actor(&"hush", Rect2(cx - 80.0, 480.0, 160.0, 440.0))
	# the prop she reaches for sits right beside her head (the g0 honey on its shelf, t192)
	fa.set_point("kitchen_honey", &"preview", Vector2(cx - 60.0, 470.0))
	fa.set_point("kitchen_honey", &"ring", Vector2(cx - 50.0, 530.0))
	fa.set_point("kitchen_kettle", &"preview", Vector2(cx + 420.0, 520.0))
	var wo := WorldOverlays.new()
	wo.size_override = vs
	tree.root.add_child(fa)
	tree.root.add_child(wo)
	_made.append(wo)
	_made.append(fa)
	wo.setup(fa, hud)
	return [fa, wo]


# --- Q-C1: the rig moment --------------------------------------------------------------------------------

func test_no_thought_while_she_rigs_only_the_ring() -> void:
	var ctx := OverlayCtx.new()
	ctx.prepare(db, db.episodes.get("n01_throat_tea"), null, TestBase.load_json(FIXTURE))
	ctx.now_s = 10.0
	ctx.at_hotspot = "kitchen_honey"
	var s := ViewSnapshot.new()
	s.hush.present = true
	s.hush.room = "kitchen"
	s.hush.x = 2940.0
	s.hush.state = "IDLE"
	s.bellows.present = true
	s.bellows.room = "hall"
	s.bellows.state = "ROUTINE"
	var m := OverlayModel.new()
	OverlayRules.fill(m, s, ctx)
	assert_eq(m.thought.hotspot, "kitchen_honey", "at the rig point: her thought (V1)")
	s.hush.state = "RIGGING"
	s.hush.rig_pm = 450
	OverlayRules.fill(m, s, ctx)
	assert_eq(m.thought.hotspot, "", "the hold has started: the joke is being set up, the thought goes")
	assert_eq(m.rig_ring.hotspot, "kitchen_honey", "the ring at the prop is the one loud thing")
	for i in m.preview_count:
		assert_almost_eq(m.previews[i].strength, OverlayModel.STRENGTH_FADED, 0.001, "the others stay faded")
	s.hush.state = "IDLE"
	OverlayRules.fill(m, s, ctx)
	assert_eq(m.thought.hotspot, "kitchen_honey", "let go early: the thought comes back")


func test_the_ring_passes_behind_a_face_next_to_the_prop() -> void:
	for vs in ASPECTS:
		var s := _overlays(vs)
		var wo: WorldOverlays = s[1]
		var m := OverlayModel.new()
		m.rig_ring.hotspot = "kitchen_honey"
		m.rig_ring.frac = 0.6
		m.rig_ring.active = true
		m.at_hotspot = "kitchen_honey"
		wo.apply(m)
		var face := wo.faces[0]
		assert_true(face.has_area(), "Hush's face box (%s)" % vs)
		assert_true(wo.ring.visible)
		assert_eq(wo.ring.position, Vector2(vs.x * 0.5 - 50.0, 530.0), "the ring stays ON the prop (%s)" % vs)
		assert_true(wo.ring.occluded(), "the part over her face is not drawn (%s)" % vs)
		assert_lt(wo.ring.k, wo.k, "a little smaller next to a face")
	# clear of every face: a full ring at full size
	var fb: Array[Rect2] = [Rect2(1000, 300, 100, 100)]
	assert_eq(WorldOverlays.ring_scale_near(Vector2(400, 500), 127.0, fb), 1.0)
	assert_eq(WorldOverlays.ring_scale_near(Vector2(1000, 380), 127.0, fb), WorldOverlays.RING_NEAR_FACE_SCALE)


func test_no_cloud_covers_a_face_box_at_every_aspect() -> void:
	for vs in ASPECTS:
		for side in [-1, 1]:
			var s := _overlays(vs)
			var wo: WorldOverlays = s[1]
			var m := OverlayModel.new()
			m.thought.hotspot = "kitchen_honey"
			m.thought.prank = "achoo_ria"
			m.thought.side = side
			var p := m.add_preview()
			p.hotspot = "kitchen_honey"
			p.prank = "achoo_ria"
			p.pictogram = PackedStringArray(["nose", "star_burst"])
			wo.apply(m)
			var face := wo.faces[0]
			for it in wo.placer.items():
				var i: OverlayPlacer.Item = it
				if i.active and i.visible:
					assert_false(i.rect.intersects(face), "%s covers her face at %s side %d" % [i.id, vs, side])
			assert_true(wo.thought.visible, "the thought still shows beside her (%s, side %d)" % [vs, side])
			assert_true(Rect2(Vector2.ZERO, vs).encloses(wo.placer.item(&"ov_thought").rect), "inside the screen")


func test_the_glove_steps_off_the_button_once_the_hold_starts() -> void:
	UiKit.now_override = 100000
	var hud := Hud.new()
	_made.append(hud)
	hud.layout_size_override = Vector2(2400, 1080)
	hud.insets_override = Vector4.ZERO
	hud.relayout()
	var m := HudModel.new()
	m.verb = HudModel.Verb.RIG
	m.verb_target_icon = "sneeze"
	hud.apply(m)
	hud.ghost_finger(&"action", GhostFinger.Mode.HOLD, 1.5)
	assert_true(hud.ghost.visible, "teaching the hold")
	# the presenter's hold flag
	m.holding = true
	m.ring_frac = 0.2
	hud.apply(m)
	hud._process(0.016)
	assert_false(hud.ghost.visible, "the hold has started: the glove leaves the button")
	assert_true(hud.action.is_holding())
	assert_eq(hud.ghost_target(), &"action", "the cue is kept (it comes back if she lets go)")
	# no flag: the ring rising alone counts, for HOLD_GRACE_MS
	m.holding = false
	m.ring_frac = 0.3
	hud.apply(m)
	hud._process(0.016)
	assert_false(hud.ghost.visible, "the ring rose just now")
	UiKit.now_override = 100000 + ActionButton.HOLD_GRACE_MS + 50
	hud._process(0.016)
	assert_true(hud.ghost.visible, "she let go before the ring completed: the glove comes back")
	# a widget other than the action button is unaffected
	m.holding = true
	hud.apply(m)
	hud.ghost_finger(&"clarence", GhostFinger.Mode.TAP)
	hud._process(0.016)
	assert_true(hud.ghost.visible)


func test_the_held_button_shows_one_icon_and_its_ring() -> void:
	UiKit.now_override = 200000
	var b := ActionButton.new()
	_made.append(b)
	b.set_icons("pepper", "sneeze")
	b.set_face(HudModel.Verb.RIG, true)
	assert_false(b.is_holding())
	b.set_holding(true)
	assert_true(b.is_holding())
	assert_true(b._held_face, "held: no target disc, no arrow, no verb tag")
	b.set_holding(false)
	b._refresh_held()
	assert_false(b._held_face)
	b.set_ring(0.4)
	assert_true(b.is_holding(), "a rising ring counts as held")
	UiKit.now_override = 200000 + ActionButton.HOLD_GRACE_MS + 1
	assert_false(b.is_holding())


# --- Q-C2: the transient top band, the safe rect, one cloud ------------------------------------------------

func test_hud_reports_the_shown_meter_and_fuse() -> void:
	for vs in ASPECTS:
		UiKit.now_override = 300000
		var hud := Hud.new()
		_made.append(hud)
		hud.layout_size_override = vs
		hud.insets_override = Vector4.ZERO
		hud.relayout()
		var m := HudModel.new()
		hud.apply(m)
		var tr := hud.transient_rects()
		assert_false(tr[0].has_area() or tr[1].has_area(), "nothing shown at rest (%s)" % vs)
		m.applause = 35
		m.link = 1
		m.mult_pct = 150
		m.fuse_frac = 0.8
		hud.apply(m)
		hud.banner._process(0.5)
		tr = hud.transient_rects()
		assert_true(tr[0].has_area(), "the meter (%s)" % vs)
		assert_true(tr[1].has_area(), "the fuse (%s)" % vs)
		assert_true(tr[0].encloses(Rect2(hud.meter.position, hud.meter.size * hud.meter.scale)), "covers the pill")
		assert_gt(tr[0].end.x, hud.meter.position.x + hud.meter.size.x * hud.meter.scale.x, "and its +n stamp")
		assert_true(tr == hud.transient_rects(), "the same array every call")


func test_previews_keep_out_of_the_shown_meter_and_fuse_at_every_aspect() -> void:
	for vs in ASPECTS:
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
		var s := _overlays(vs, hud)
		var fa: FakeAnchors = s[0]
		var wo: WorldOverlays = s[1]
		# the P00 t2190 gramophone: its preview anchored under the fuse's left end
		var fuse := hud.transient_rects()[1]
		fa.set_point("parlour_gramophone", &"preview", Vector2(fuse.position.x + 20.0, fuse.end.y + 60.0))
		var m := OverlayModel.new()
		var p := m.add_preview()
		p.hotspot = "parlour_gramophone"
		p.prank = "allegro_go_go"
		p.pictogram = PackedStringArray(["record", "x3", "spiral"])
		p.his_ring_frac = 0.7
		wo.apply(m)
		var it := wo.placer.item(&"ov_preview_0")
		for r in wo.hard_now():
			assert_false(it.visible and it.rect.intersects(r), "the preview runs into %s at %s" % [r, vs])
		if vs.x / vs.y < 1.5:
			# 4:3 tablet: the Script chip's keep-out leaves no room left of the fuse — it may wait instead
			assert_true(not it.visible or Rect2(Vector2.ZERO, vs).encloses(it.rect))
		else:
			assert_true(it.visible, "it slides clear rather than vanishing (%s)" % vs)
			assert_true(Rect2(Vector2.ZERO, vs).encloses(it.rect), "inside the screen (%s)" % vs)
			var tail := (it.anchor - it.rect.get_center()).normalized()
			assert_true(wo.previews[0].tail_dir.is_equal_approx(tail), "its tail still points at the gramophone")
		hud.free()
		_made.erase(hud)


func test_his_bubble_waits_while_her_thought_is_the_action() -> void:
	var s := _overlays(Vector2(2400, 1080))
	var wo: WorldOverlays = s[1]
	# r3d-view3d's Overlays3D requests his bubble FIXED between two applies
	wo.placer.request(&"fx_bubble", OverlayPlacer.Pri.BUBBLE, Rect2(100, 260, 270, 173), Vector2.INF, true)
	var m := OverlayModel.new()
	m.thought.hotspot = "kitchen_honey"
	m.thought.prank = "achoo_ria"
	m.at_hotspot = "kitchen_honey"
	wo.apply(m)
	assert_true(wo.thought.visible, "her thought, at the action")
	assert_false(wo.placer.item(&"fx_bubble").visible, "one thought cloud on screen: his waits")
	# no thought of hers: his bubble shows (clamped only)
	wo.placer.request(&"fx_bubble", OverlayPlacer.Pri.BUBBLE, Rect2(-40, 260, 270, 173), Vector2.INF, true)
	m.thought.hotspot = ""
	wo.apply(m)
	var b := wo.placer.item(&"fx_bubble")
	assert_true(b.visible)
	assert_eq(b.rect.position.x, 0.0, "clamped inside the safe rect, glyph and all")


func test_cloud_boxes_cover_what_they_draw() -> void:
	var pc := PreviewCloud.new()
	_made.append(pc)
	pc.set_data(null, 0.8, null, -1.0, null, false, 1.0)
	var e := PreviewCloud.cloud_half_extent(PreviewCloud.W, PreviewCloud.H)
	assert_gt(e.x, PreviewCloud.W * 0.5, "the lobes reach past the 112 px body")
	assert_eq(pc.box_size(), e * 2.0)
	pc.set_data(null, 0.8, null, 0.5, null, false, 1.0)
	assert_ge(pc.box_size().x, (PreviewCloud.W * 0.5 + 10.0 + (PreviewCloud.RING_W + 6.0) * 0.5) * 2.0, "his ring too")
	var tc := ThoughtCloud.new()
	_made.append(tc)
	assert_eq(tc.box_size(), PreviewCloud.cloud_half_extent(ThoughtCloud.W, ThoughtCloud.H) * 2.0)
