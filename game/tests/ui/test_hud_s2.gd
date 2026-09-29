## Stage-2 HUD hooks (s2-ui §4.2): the edge-bubble emote lifecycle (D1), "where does this go?"
## tray arrows, the world ghost finger (clamped to the safe area, following a moving target),
## the Figgis cue-card arrow, the "show me" dim, the curtain-up Script flash (timing,
## pass-through) and `Hud.apply` staying allocation-free and cheap with the new fields.
extends TestBase

const INSETS := [Vector4(0, 0, 0, 0), Vector4(162, 0, 162, 58), Vector4(120, 0, 0, 20), Vector4(0, 40, 0, 0)]

var hud: Hud
var _in_tree: bool = false


func before_each() -> void:
	UiKit.now_override = 100000
	hud = Hud.new()
	hud.layout_size_override = Vector2(2400, 1080)
	hud.insets_override = Vector4.ZERO
	hud.relayout()
	_in_tree = false


func after_each() -> void:
	if _in_tree and hud.is_inside_tree():
		hud.get_parent().remove_child(hud)
	hud.free()
	UiKit.now_override = -1


func _into_tree() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(hud)
	_in_tree = true
	hud.relayout()


func _at(ms: int) -> void:
	UiKit.now_override = ms


# --- edge-bubble emotes (D1) ------------------------------------------------------------------

func test_emote_reaches_the_bubble_and_clears() -> void:
	var m := HudModel.new()
	m.edge_bubble_dir = Vector2(1, 0)
	m.edge_bubble_label = "next door →"
	hud.apply(m)
	var plain := hud.edge_bubble.face_texture()
	assert_eq(hud.edge_bubble.emote, "")
	m.edge_bubble_emote = "sing"
	hud.apply(m)
	assert_eq(hud.last_changes, 1, "the emote is one field")
	assert_eq(hud.edge_bubble.emote, "sing")
	assert_ne(hud.edge_bubble.face_texture(), plain, "the face swaps to the emote face")
	assert_eq(hud.edge_bubble.face_texture(), UiIcons.get_icon(&"emote_sing"))
	assert_true(hud.edge_bubble.puff_visible(), "the pictogram puff shows while it plays")
	hud.apply(m)
	assert_eq(hud.last_changes, 0, "a repeat apply is a no-op")
	# the micro-gag's len is over: the presenter clears it
	m.edge_bubble_emote = ""
	hud.apply(m)
	assert_eq(hud.edge_bubble.emote, "")
	assert_true(hud.edge_bubble.puff_visible(), "the puff fades out …")
	_at(100000 + EdgeBubble.PUFF_OUT_MS + 10)
	assert_false(hud.edge_bubble.puff_visible(), "… and is gone")


func test_every_emote_has_a_face_and_a_puff() -> void:
	assert_eq(EdgeBubble.EMOTES, PackedStringArray(["sing", "hum", "smug", "laugh", "tut", "sniff", "yum", "yawn"]),
		"the s2-sim vocabulary")
	var b := EdgeBubble.new()
	for e in EdgeBubble.EMOTES:
		assert_true(UiIcons.get_icon(StringName("emote_" + e)) != null, "face emote_%s.svg" % e)
		assert_true(UiIcons.get_icon(StringName("puff_" + e)) != null, "puff puff_%s.svg" % e)
		b.set_emote(e)
		assert_eq(b.emote, e)
	b.set_emote("juggle")
	assert_eq(b.emote, "", "an unknown emote is his normal face")
	b.free()


func test_emote_switch_mid_play() -> void:
	var b := EdgeBubble.new()
	b.set_emote("hum")
	var t1 := b.face_texture()
	b.set_emote("laugh")
	assert_ne(b.face_texture(), t1)
	assert_eq(b.emote, "laugh")
	b.free()


func test_puff_floats_toward_the_screen_centre() -> void:
	var b := EdgeBubble.new()
	b.set_target(Vector2(1, 0), "x")
	assert_eq(b.puff_side(), -1.0, "right-edge bubble puffs to its left")
	b.set_target(Vector2(-1, 0), "x")
	assert_eq(b.puff_side(), 1.0, "left-edge bubble puffs to its right")
	b.free()


# --- tray arrows ------------------------------------------------------------------------------

func test_tray_arrows_follow_the_model() -> void:
	var m := HudModel.new()
	m.tray = PackedStringArray(["squeaker", "kipper"])
	hud.apply(m)
	assert_eq(hud.edge_arrows.arrow_count(), 0)
	assert_false(hud.edge_arrows.visible)
	m.tray_arrows = PackedVector2Array([Vector2(1, 0), Vector2(-1, -0.2)])
	hud.apply(m)
	assert_eq(hud.edge_arrows.arrow_count(), 2)
	assert_true(hud.edge_arrows.visible)
	hud.apply(m)
	assert_eq(hud.last_changes, 0, "same arrows: no change")
	m.tray_arrows = PackedVector2Array()
	hud.apply(m)
	assert_eq(hud.edge_arrows.arrow_count(), 0, "3 s later the presenter empties them")


func test_tray_arrows_sit_inside_the_zone_on_the_right_edge() -> void:
	for ins in INSETS:
		hud.insets_override = ins
		hud.relayout()
		var zone: Rect2 = hud.layout[&"arrow_zone"]
		var ea := hud.edge_arrows
		for d in [Vector2(1, 0), Vector2(1, -0.35), Vector2(-1, 0.1), Vector2(0, -1), Vector2(0.3, 1)]:
			var p := ea.edge_point(d)
			assert_true(zone.grow(1.0).has_point(p), "arrow tip %s inside the zone for %s at %s" % [p, d, ins])
			# the tail (arrow + icon disc) stays inside too
			var tail := p - (d as Vector2).normalized() * (EdgeArrows.ARROW + EdgeArrows.DISC + 6.0)
			assert_true(Rect2(Vector2.ZERO, hud.viewport_size()).has_point(tail), "tail on screen")
		# mostly-right lands on the right edge, mostly-up on the top edge
		var zr := ea.inner_zone()
		assert_almost_eq(ea.edge_point(Vector2(1, -0.35)).x, zr.end.x, 0.5, "right edge")
		assert_almost_eq(ea.edge_point(Vector2(0.2, -1)).y, zr.position.y, 0.5, "top edge")


func test_tray_arrows_never_touch_a_target() -> void:
	for vs in [Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1920, 1440)]:
		for ins in INSETS:
			for lh in [false, true]:
				hud.layout_size_override = vs
				hud.insets_override = ins
				hud.left_handed = lh
				hud.relayout()
				var zone: Rect2 = hud.layout[&"arrow_zone"]
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(1, -0.35), Vector2(-1, 0.3), Vector2(0.5, -1),
						Vector2(-0.4, 1)]:
					for poly in hud.edge_arrows.arrow_polygons(d):
						for key in HudLayout.TARGETS:
							if key == "pip":
								continue   # the PiP shows only when he is near: the arrows point elsewhere then
							var r: Rect2 = hud.layout[StringName(key)]
							var rp := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
								Vector2(r.position.x, r.end.y)])
							assert_true(Geometry2D.intersect_polygons(poly, rp).is_empty(),
								"arrow %s clear of %s (%s %s lh=%s)" % [d, key, vs, ins, lh])
				assert_false(zone.intersects(hud.layout[&"band"]), "the zone stays out of the Stalls band")


func test_tray_arrow_icon_is_the_tapped_item() -> void:
	var m := HudModel.new()
	m.tray = PackedStringArray(["squeaker", "kipper"])
	hud.apply(m)
	hud.tray.touch(true, ItemTray.slot_rect(1).get_center(), 0)
	hud.tray.touch(false, ItemTray.slot_rect(1).get_center(), 0)
	m.tray_arrows = PackedVector2Array([Vector2(1, 0)])
	hud.apply(m)
	assert_eq(hud.edge_arrows._icon, UiIcons.item("kipper"), "slot 1 was tapped")
	m.tray_arrows_item = "butter"
	hud.apply(m)
	assert_eq(hud.edge_arrows._icon, UiIcons.item("butter"), "an explicit item wins")


# --- the world ghost finger -------------------------------------------------------------------

func test_ghost_finger_at_a_world_point() -> void:
	hud.ghost_finger_at(Vector2(1300, 500), GhostFinger.Mode.TAP)
	assert_true(hud.ghost.visible)
	assert_eq(hud.ghost_target(), Hud.GHOST_WORLD)
	assert_eq(hud.ghost.tip(), Vector2(1300, 500), "tip exactly on the point")
	hud.ghost_finger(&"")
	assert_false(hud.ghost.visible, "&\"\" hides it")


func test_ghost_finger_clamped_to_the_safe_area_at_every_inset() -> void:
	var vs := hud.viewport_size()
	for ins in INSETS:
		hud.insets_override = ins
		hud.relayout()
		var sym := SafeArea.symmetric(ins)
		var safe := Rect2(sym.x, sym.y, vs.x - sym.x - sym.z, vs.y - sym.y - sym.w)
		for p in [Vector2(-500, -500), Vector2(vs.x + 400, 540), Vector2(1200, vs.y + 300), Vector2(10, 10),
				Vector2(vs.x - 2, vs.y - 2)]:
			hud.ghost_finger_at(p, GhostFinger.Mode.HOLD, 0.8)
			var g := Rect2(hud.ghost.position, hud.ghost.size)
			assert_true(safe.grow(0.5).encloses(g), "glove %s inside %s (target %s, insets %s)" % [g, safe, p, ins])
			var reach := Rect2(hud.ghost.tip() - Vector2.ONE * GhostFinger.TIP_REACH, Vector2.ONE * GhostFinger.TIP_REACH * 2.0)
			assert_true(safe.grow(0.5).encloses(reach), "the HOLD ring stays on screen too (%s)" % p)


func test_ghost_finger_follow_tracks_a_moving_target() -> void:
	var pos := [Vector2(900, 500)]
	hud.ghost_finger_follow(func() -> Vector2: return pos[0], GhostFinger.Mode.TAP)
	assert_eq(hud.ghost.tip(), Vector2(900, 500))
	pos[0] = Vector2(1500, 450)
	hud._process(0.016)
	assert_eq(hud.ghost.tip(), Vector2(1500, 450), "re-read every frame (the camera panned)")
	pos[0] = Vector2.INF
	hud._process(0.016)
	assert_false(hud.ghost.visible, "INF hides it (target off the stage)")
	pos[0] = Vector2(1000, 520)
	hud._process(0.016)
	assert_true(hud.ghost.visible, "and it comes back")
	assert_eq(hud.ghost.tip(), Vector2(1000, 520))
	pos[0] = Vector2(-100, 520)
	hud._process(0.016)
	assert_ge(hud.ghost.position.x, 0.0, "a followed point off the edge is clamped")


func test_ghost_follow_of_a_freed_object_hides() -> void:
	var n := _Target.new()
	hud.ghost_finger_follow(Callable(n, "pos"))
	assert_true(hud.ghost.visible)
	n.free()
	hud._process(0.016)
	assert_false(hud.ghost.visible, "the followed node is gone")


func test_ghost_hold_ring_uses_the_taught_tier() -> void:
	hud.ghost_finger(&"action", GhostFinger.Mode.HOLD, 0.8)
	assert_almost_eq(hud.ghost.hold_s, 0.8, 0.001, "Q tier")
	var t0 := UiKit.now_ms()
	assert_almost_eq(hud.ghost.ring_frac_at(t0 + int(GhostFinger.HOLD_APPROACH_S * 1000.0) + 400), 0.5, 0.02,
		"half way at 0.4 s of a 0.8 s hold")
	hud.ghost_finger_at(Vector2(1000, 500), GhostFinger.Mode.HOLD, 2.5)
	assert_almost_eq(hud.ghost.hold_s, 2.5, 0.001, "B tier")


func test_widget_ghost_still_targets_widgets() -> void:
	hud.ghost_finger(&"clarence", GhostFinger.Mode.TAP)
	var c := Rect2(hud.clarence.position, hud.clarence.size * hud.clarence.scale)
	assert_true(c.grow(40.0).has_point(hud.ghost.tip()), "on Clarence")
	hud.ghost_finger(&"tray:2")
	var tr := Rect2(hud.tray.position, hud.tray.size * hud.tray.scale)
	assert_true(tr.has_point(hud.ghost.tip()), "on the tray")


# --- Figgis cue card + arrow, dim ---------------------------------------------------------------

func test_figgis_card_with_an_off_screen_arrow() -> void:
	hud.show_figgis_card(PackedStringArray(["rig", "arrow", "tea"]), 4.0, Vector2(3200, 500))
	assert_true(hud.figgis.card_visible())
	assert_eq(hud.figgis.card_icon_count(), 2, "the spelled-out arrow is a separator, not an icon")
	assert_eq(hud.edge_arrows.arrow_count(), 1, "one arrow toward the target")
	assert_false(hud.edge_arrows.point_on_screen(), "off screen → an edge arrow")
	assert_true(hud.edge_arrows._point_icon != null, "with the target icon at its tail")
	_at(100000 + 4100)
	assert_false(hud.figgis.card_visible(), "the card is gone after 4 s")
	assert_eq(hud.edge_arrows.arrow_count(), 0, "and so is the arrow")


func test_figgis_card_arrow_on_screen_and_none() -> void:
	hud.show_figgis_card(PackedStringArray(["tray", "rig"]), 4.0, Vector2(1400, 520))
	assert_true(hud.edge_arrows.point_on_screen(), "an on-screen target gets an arrow above it")
	hud.show_figgis_card(PackedStringArray(["tray", "rig"]))
	assert_eq(hud.edge_arrows.arrow_count(), 0, "no arrow_to → no arrow")
	hud.show_figgis_card(PackedStringArray(["tray", "rig"]), 4.0, Vector2(1400, 520))
	hud.hide_figgis_card()
	assert_false(hud.figgis.card_visible())
	assert_eq(hud.edge_arrows.arrow_count(), 0)


func test_set_dim_fades_and_keeps_a_spotlight() -> void:
	assert_false(hud.dim.visible)
	hud.set_dim(true, Rect2(800, 300, 400, 500))
	assert_true(hud.dim.visible)
	assert_almost_eq(hud.dim.alpha(), 0.0, 0.01, "fades in from 0")
	_at(100000 + StageDim.FADE_IN_MS)
	assert_almost_eq(hud.dim.alpha(), StageDim.ALPHA, 0.01, "full dim")
	assert_eq(hud.dim.spotlight, Rect2(800, 300, 400, 500))
	hud.set_dim(true, Rect2(900, 300, 400, 500))
	assert_eq(hud.dim.spotlight.position.x, 900.0, "the spotlight moves without refading")
	assert_almost_eq(hud.dim.alpha(), StageDim.ALPHA, 0.01)
	hud.set_dim(false)
	_at(100000 + StageDim.FADE_IN_MS + StageDim.FADE_OUT_MS)
	assert_almost_eq(hud.dim.alpha(), 0.0, 0.01, "lights back up")
	assert_eq(hud.dim.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never a touch target")
	assert_eq(hud.dim.get_index(), 0, "under every widget")


func test_dim_is_not_weakened_by_the_pause() -> void:
	var m := HudModel.new()
	m.paused = true
	hud.apply(m)
	hud.set_dim(true)
	assert_eq(hud.root.modulate, Color.WHITE, "the root is not faded (the widgets are)")
	assert_lt(hud.meter.modulate.a, 1.0)


# --- the curtain-up Script flash --------------------------------------------------------------

func _lines() -> Array:
	return [
		{"id": "a", "text": "Bellows sings a duet with his kettle", "req": true},
		{"id": "b", "text": "A sneeze worthy of the opera", "req": true},
		{"id": "c", "text": "The news makes his eyes pop"},
		{"id": "bn", "text": "HOT & COLD", "big_number": true, "sealed": true},
	]


func test_script_flash_slides_in_holds_and_leaves() -> void:
	_into_tree()
	var done := [0]
	hud.script_flash_finished.connect(func() -> void: done[0] += 1)
	var p := hud.flash_script(_lines(), [], 2.5)
	assert_true(p.flash_mode)
	assert_eq(hud.script_flash, p)
	assert_eq(hud.top_panel(), null, "a flash is not a panel (Back / panel_closed never see it)")
	var rest := p.flash_rest_y()
	assert_lt(p.flash_y(), 0.0, "starts above the screen")
	_at(100000 + ScriptPanel.FLASH_IN_MS)
	assert_almost_eq(p.flash_y(), rest, 0.5, "in after 300 ms, just under the meter")
	_at(100000 + 1500)
	assert_almost_eq(p.flash_y(), rest, 0.5, "holds")
	_at(100000 + 2500 - ScriptPanel.FLASH_OUT_MS + 140)
	assert_lt(p.flash_y(), rest, "sliding out")
	_at(100000 + 2500)
	p._tick()
	assert_eq(done[0], 1, "finished at 2.5 s")
	assert_eq(hud.script_flash, null)


func test_script_flash_passes_touches_through() -> void:
	_into_tree()
	var p := hud.flash_script(_lines(), [], 2.5)
	assert_eq(p.mouse_filter, Control.MOUSE_FILTER_IGNORE, "outside the card touches reach the game")
	assert_eq(p.card.mouse_filter, Control.MOUSE_FILTER_STOP, "the card itself takes a tap")
	assert_eq(hud.flash_host.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(p.scrim.a, 0.0, "no scrim")
	# a tap on the card slides it away early
	_at(100000 + 800)
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	p._on_flash_card_input(ev)
	_at(100000 + 800 + ScriptPanel.FLASH_OUT_MS + 5)
	p._tick()
	assert_eq(hud.script_flash, null, "gone early")


func test_script_flash_keeps_play_text_size_and_clears_the_targets() -> void:
	_into_tree()
	var p := hud.flash_script(_lines(), [], 2.5)
	_at(100000 + 1000)
	p._tick()
	assert_almost_eq(p.card.scale.x, 1.0, 0.001, "full size: rows stay at 44 px")
	assert_almost_eq(p.card.size.y, p.flash_height(), 0.5, "lines only")
	var card := Rect2(p.card.position, p.card.size * p.card.scale)
	for key in HudLayout.TARGETS:
		if key == "meter":
			continue
		var r: Rect2 = hud.layout[StringName(key)]
		assert_false(card.intersects(r), "the flash never covers %s" % key)
	assert_ge(card.position.y, (hud.layout[&"meter"] as Rect2).end.y, "under the meter")


func test_a_second_flash_replaces_the_first() -> void:
	_into_tree()
	var a := hud.flash_script(_lines(), [], 2.5)
	var b := hud.flash_script(_lines(), [], 2.5)
	assert_ne(a, b)
	assert_eq(hud.script_flash, b)


# --- apply stays cheap ------------------------------------------------------------------------

func test_apply_with_the_new_fields_is_a_no_op_on_repeat_and_fast() -> void:
	var m := HudModel.new()
	m.applause = 55
	m.tray = PackedStringArray(["kipper", "flour"])
	m.edge_bubble_dir = Vector2(-1, 0)
	m.edge_bubble_label = "← next door"
	m.edge_bubble_emote = "yum"
	m.tray_arrows = PackedVector2Array([Vector2(1, 0)])
	m.pick_strip_items = PackedStringArray(["flour", "salt"])
	m.script_lines = _lines()
	hud.apply(m)
	hud.apply(m)
	assert_eq(hud.last_changes, 0)
	var objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		hud.apply(m)
	var per := float(Time.get_ticks_usec() - t0) / 1000.0
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objs, "no objects created by 1000 applies")
	assert_lt(per, 300.0, "Hud.apply ≤ 0.3 ms (measured %.1f µs)" % per)
	print("[perf] Hud.apply repeat: %.2f µs" % per)


## A followed object (ghost_finger_follow with a bound method).
class _Target:
	extends Node

	func pos() -> Vector2:
		return Vector2(1100, 500)
