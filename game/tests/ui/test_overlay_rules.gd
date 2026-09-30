## OverlayRules (REDESIGN_3D §4.4–§4.5, r3d-index §7.8): N2 previews, V1 thought + fade, V2 danger
## (only the safety-net marker), V3 hidden, V5 quiet window, N4 idle spotlight, V6 caps, the Settings
## modes, his ring, the needs cloud and the item bubble — on the real content (n01 kitchen: kettle
## drum needs the squeaker, tap dance, in a pickle, achoo-ria) with the previews.json fixture.
extends TestBase

const FIXTURE := "res://tests/ui/fixtures/previews.json"

var db: ContentDB = null


func before_each() -> void:
	if db == null:
		db = ContentDB.load_dir("res://data")


func _ctx(ep_id: String = "n01_throat_tea") -> OverlayCtx:
	var ctx := OverlayCtx.new()
	ctx.prepare(db, db.episodes.get(ep_id), null, TestBase.load_json(FIXTURE))
	ctx.now_s = 10.0
	return ctx


## A snapshot with Hush in `room` at x (px), every rig point of the room available.
func _snap(ctx: OverlayCtx, room: String, x: float) -> ViewSnapshot:
	var s := ViewSnapshot.new()
	s.hush.present = true
	s.hush.room = room
	s.hush.x = x
	s.hush.state = "IDLE"
	s.bellows.present = true
	s.bellows.room = "hall"
	s.bellows.state = "ROUTINE"
	for hs in ctx.rig_pranks:
		s.hotspots[hs] = {"kind": "rig_point", "enabled": true, "rigged": false, "spent": false}
	for r in ctx.room_hides:
		for hs in ctx.room_hides[r]:
			s.hotspots[hs] = {"kind": "hiding", "enabled": true, "occupant": false}
	return s


func _fill(ctx: OverlayCtx, s: ViewSnapshot) -> OverlayModel:
	var m := OverlayModel.new()
	OverlayRules.fill(m, s, ctx)
	return m


func _hotspots(m: OverlayModel) -> PackedStringArray:
	var out := PackedStringArray()
	for i in m.preview_count:
		out.append(m.previews[i].hotspot)
	return out


func test_ctx_tables_from_content() -> void:
	var ctx := _ctx()
	assert_has(ctx.rigs_in("kitchen"), "kitchen_kettle")
	assert_has(ctx.rigs_in("kitchen"), "kitchen_honey")
	assert_eq(ctx.prank_needs.get("kettle_drum"), "squeaker")
	assert_eq(ctx.item_source.get("squeaker"), "hall_confiscated_box")
	assert_eq(ctx.pictogram_of("achoo_ria"), PackedStringArray(["nose", "star_burst"]))
	assert_has(ctx.hides_in("kitchen"), "kitchen_pantry_curtain")


func test_n2_every_available_rig_point_of_her_room_shows_its_preview() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3300.0)
	var m := _fill(ctx, s)
	var hs := _hotspots(m)
	for r in ctx.rigs_in("kitchen"):
		assert_has(hs, r, "preview over %s" % r)
	assert_false(hs.has("parlour_recliner"), "only her room")
	for i in m.preview_count:
		assert_almost_eq(m.previews[i].strength, OverlayModel.STRENGTH_PASSIVE, 0.001, "V4: 80 %")
	# armed → the 3D tag instead; spent → nothing
	s.hotspots["kitchen_honey"]["rigged"] = true
	s.hotspots["kitchen_kettle"]["spent"] = true
	ctx.quiet_until_s = -1.0
	m = _fill(ctx, s)
	ctx.quiet_until_s = -1.0
	m = _fill(ctx, s)
	hs = _hotspots(m)
	assert_false(hs.has("kitchen_honey"), "armed: tag, no preview")
	assert_false(hs.has("kitchen_kettle"), "spent: nothing")


func test_v1_thought_at_a_rig_point_and_others_fade() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 2940.0)
	ctx.at_hotspot = "kitchen_honey"
	var m := _fill(ctx, s)
	assert_eq(m.thought.hotspot, "kitchen_honey")
	assert_eq(m.thought.prank, "achoo_ria")
	assert_eq(m.thought.pictogram, PackedStringArray(["nose", "star_burst"]))
	assert_false(_hotspots(m).has("kitchen_honey"), "her spot's preview is replaced by the thought")
	assert_gt(m.preview_count, 0)
	for i in m.preview_count:
		assert_almost_eq(m.previews[i].strength, OverlayModel.STRENGTH_FADED, 0.001, "V1: others at 30 %")
	assert_le(m.loud_count(), OverlayModel.MAX_LOUD)


func test_thought_sits_on_the_side_away_from_the_prop() -> void:
	var ctx := _ctx()
	ctx.at_hotspot = "kitchen_honey"
	var cx := float(ctx.hotspot_cx["kitchen_honey"])
	var m := _fill(ctx, _snap(ctx, "kitchen", cx + 60.0))
	assert_eq(m.thought.side, 1, "prop on her left → cloud on her right")
	m = _fill(ctx, _snap(ctx, "kitchen", cx - 60.0))
	assert_eq(m.thought.side, -1)


func test_rig_ring_while_held_and_partial_after_release() -> void:
	var ctx := _ctx()
	ctx.at_hotspot = "kitchen_honey"
	var s := _snap(ctx, "kitchen", 2940.0)
	s.hush.state = "RIGGING"
	s.hush.rig_pm = 400
	var m := _fill(ctx, s)
	assert_eq(m.rig_ring.hotspot, "kitchen_honey")
	assert_almost_eq(m.rig_ring.frac, 0.4, 0.001)
	assert_true(m.rig_ring.active)
	s.hush.state = "IDLE"
	m = _fill(ctx, s)
	assert_eq(m.rig_ring.hotspot, "kitchen_honey", "release keeps progress: the ring stays partial")
	assert_false(m.rig_ring.active)
	assert_almost_eq(m.rig_ring.frac, 0.4, 0.001)


func test_v2_danger_hides_everything_but_the_safety_marker() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3300.0)
	ctx.entry_warning = true
	var m := _fill(ctx, s)
	assert_eq(m.preview_count, 0, "every preview hides")
	assert_eq(m.item_count, 0)
	assert_eq(m.thought.hotspot, "")
	assert_eq(m.safety_marker.hotspot, "kitchen_pantry_curtain", "the nearest free hiding spot")
	# seen ("?" filling): FREEZE LIVE is the call, no marker
	ctx.entry_warning = false
	ctx.spot_filling = true
	m = _fill(ctx, s)
	assert_eq(m.safety_marker.hotspot, "")
	assert_eq(m.preview_count, 0)
	# a payoff: the consequence gets the screen, no marker
	ctx.spot_filling = false
	s.bellows.reacting = true
	m = _fill(ctx, s)
	assert_eq(m.preview_count, 0)
	assert_eq(m.safety_marker.hotspot, "")


func test_hints_return_one_second_after_danger() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3300.0)
	ctx.chase = true
	_fill(ctx, s)
	ctx.chase = false
	ctx.now_s += 0.5
	assert_eq(_fill(ctx, s).preview_count, 0, "still quiet 0.5 s after")
	ctx.now_s += 0.6
	assert_gt(_fill(ctx, s).preview_count, 0, "back after 1.0 s")


func test_v3_hidden_nothing_loud() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3620.0)
	s.hush.state = "HIDDEN"
	s.hush.hidden_spot = "kitchen_pantry_curtain"
	ctx.prev_hidden = true
	var m := _fill(ctx, s)
	assert_eq(m.thought.hotspot, "")
	assert_eq(m.loud_count(), 0, "V3: nothing loud but POP OUT")
	for i in m.preview_count:
		assert_almost_eq(m.previews[i].strength, OverlayModel.STRENGTH_FADED, 0.001)


func test_v5_nothing_new_for_one_second_after_an_action() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 2940.0)
	_fill(ctx, s)
	s.hotspots["kitchen_honey"]["rigged"] = true
	var m := _fill(ctx, s)
	assert_eq(m.preview_count, 0, "the rig just armed: quiet")
	ctx.now_s += 0.9
	assert_eq(_fill(ctx, s).preview_count, 0)
	ctx.now_s += 0.2
	assert_gt(_fill(ctx, s).preview_count, 0, "previews return after 1.0 s")


func test_n4_next_useful_at_full_size_after_six_idle_seconds() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3300.0)
	ctx.next_useful = "kitchen_sink_tap"
	ctx.idle_s = 5.0
	var m := _fill(ctx, s)
	var p := m.preview_of("kitchen_sink_tap")
	assert_true(p != null)
	assert_false(p.loud)
	ctx.idle_s = 6.5
	m = _fill(ctx, s)
	p = m.preview_of("kitchen_sink_tap")
	assert_true(p != null and p.loud, "N4: loud")
	assert_almost_eq(p.strength, 1.0, 0.001)


func test_settings_modes() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3300.0)
	ctx.previews_mode = OverlayCtx.MODE_IDLE
	ctx.idle_s = 1.0
	assert_eq(_fill(ctx, s).preview_count, 0, "idle_6s: none before 6 s")
	ctx.idle_s = 7.0
	assert_gt(_fill(ctx, s).preview_count, 0, "idle_6s: shown after 6 s")
	ctx.previews_mode = OverlayCtx.MODE_OFF
	assert_eq(_fill(ctx, s).preview_count, 0, "off: no previews")
	ctx.at_hotspot = "kitchen_honey"
	s.hush.x = 2940.0
	var m := _fill(ctx, s)
	assert_eq(m.thought.hotspot, "kitchen_honey", "off: the thought stays")
	ctx.at_hotspot = ""
	ctx.entry_warning = true
	assert_ne(_fill(ctx, s).safety_marker.hotspot, "", "off: the marker stays")


func test_needs_cloud_after_she_has_seen_the_container() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3300.0)
	var p := _fill(ctx, s).preview_of("kitchen_kettle")
	assert_true(p != null)
	assert_eq(p.needs_item, "", "the container is unseen: the plain joke")
	# she walks through the hall (the squeaker's confiscated box)
	var hall := _snap(ctx, "hall", 900.0)
	_fill(ctx, hall)
	assert_true(ctx.seen_containers.has("hall_confiscated_box"))
	ctx.quiet_until_s = -1.0
	p = _fill(ctx, s).preview_of("kitchen_kettle")
	assert_eq(p.needs_item, "squeaker", "needs cloud: the missing item's silhouette")
	s.hush.carrying = PackedStringArray(["squeaker"])
	ctx.prev_carry = 1
	p = _fill(ctx, s).preview_of("kitchen_kettle")
	assert_eq(p.needs_item, "", "carried: a full preview again")


func test_item_bubble_over_a_container_with_tonights_item() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "hall", 900.0)
	s.hotspots["hall_confiscated_box"] = {"kind": "container", "enabled": true, "stock": ["squeaker", "croc"]}
	var m := _fill(ctx, s)
	assert_eq(m.item_count, 1)
	assert_eq(m.item_bubbles[0].hotspot, "hall_confiscated_box")
	assert_eq(m.item_bubbles[0].item, "squeaker", "tonight's item only (not the croc)")
	s.hush.carrying = PackedStringArray(["squeaker"])
	ctx.prev_carry = 1
	assert_eq(_fill(ctx, s).item_count, 0, "carried: no bubble")


func test_his_ring_on_the_spot_his_next_activity_triggers() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3300.0)
	# the kettle drum fires on his tea
	var act := ""
	for a in ctx.trig_hotspots:
		if (ctx.trig_hotspots[a] as PackedStringArray).has("kitchen_kettle"):
			act = a
	assert_ne(act, "", "kettle_drum has a use trigger")
	s.bubble_next = act
	s.bubble_ring_ticks = 240
	_fill(ctx, s)
	s.bubble_ring_ticks = 120
	var p := _fill(ctx, s).preview_of("kitchen_kettle")
	assert_eq(p.his_ring_ticks, 120)
	assert_almost_eq(p.his_ring_frac, 0.5, 0.001)


func test_v6_caps() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3300.0)
	s.hotspots["kitchen_pantry_shelf"] = {"kind": "container", "enabled": true, "stock": ["flour"]}
	s.hotspots["kitchen_fridge"] = {"kind": "container", "enabled": true, "stock": ["kipper"]}
	var m := _fill(ctx, s)
	assert_le(m.overlay_count(), OverlayModel.MAX_ON_SCREEN)
	assert_le(m.loud_count(), OverlayModel.MAX_LOUD)


func test_fill_allocates_nothing_steady_state() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", 3300.0)
	var m := OverlayModel.new()
	for i in 3:
		OverlayRules.fill(m, s, ctx)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 200:
		OverlayRules.fill(m, s, ctx)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "no objects created per frame")


func test_suggest_next_useful_is_the_nearest_rig_point_she_can_rig_now() -> void:
	var ctx := _ctx()
	var s := _snap(ctx, "kitchen", float(ctx.hotspot_x.get("kitchen_honey", 3300.0)))
	var pick := OverlayRules.suggest_next_useful(s, ctx)
	assert_eq(pick, "kitchen_honey", "standing at the honey (needs nothing)")
	# kettle drum needs the squeaker: never suggested without it
	for hs in ctx.rigs_in("kitchen"):
		if hs != "kitchen_kettle":
			s.hotspots[hs]["rigged"] = true
	s.hush.x = float(ctx.hotspot_x.get("kitchen_kettle", 3300.0))
	assert_eq(OverlayRules.suggest_next_useful(s, ctx), "", "the kettle needs the squeaker she lacks")
	s.hush.carrying = PackedStringArray(["squeaker"])
	assert_eq(OverlayRules.suggest_next_useful(s, ctx), "kitchen_kettle")
	assert_eq(OverlayRules.suggest_next_useful(null, ctx), "")


func test_model_carries_the_rig_point_she_is_at() -> void:
	var ctx := _ctx()
	ctx.at_hotspot = "kitchen_honey"
	var s := _snap(ctx, "kitchen", float(ctx.hotspot_x.get("kitchen_honey", 3300.0)))
	var m := _fill(ctx, s)
	assert_eq(m.at_hotspot, "kitchen_honey")
	ctx.at_hotspot = ""
	s.hush.x = 100.0
	m = _fill(ctx, s)
	assert_true(m.at_hotspot != "kitchen_honey" or s.hush.state == "RIGGING", "cleared once she walks off")
