## R3D HUD layout (REDESIGN_3D §2.1–§2.2, r3d-hud brief §4.1): the four always-on rects at 20:9
## (2400×1080), 16:9 (1920×1080), 4:3 tablets (1920×1440 → ×0.8) and a 20:9+ notch phone, the
## left-handed mirror, the 1,300 px thumb rule, the Script pill width formula, the contextual rects,
## every target ≥ 24 px apart and inside the safe area, the Stalls band never a target, the middle band.
extends TestBase

const SIZES := [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1920, 1440), Vector2(2520, 1080)]
const INSETS := [Vector4(0, 0, 0, 0), Vector4(162, 0, 162, 58), Vector4(120, 24, 0, 20)]


static func gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return maxf(dx, dy) if (dx == 0.0 or dy == 0.0) else sqrt(dx * dx + dy * dy)


func _each(fn: Callable) -> void:
	for vs in SIZES:
		for ins in INSETS:
			for lh in [false, true]:
				var k := UiScale.factor_for(vs)
				fn.call(HudLayout.compute(vs, ins, lh, k), vs, SafeArea.symmetric(ins), lh, k)


func test_the_four_always_on_rects_match_redesign() -> void:
	for vs in [Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1920, 1440)]:
		for ins in INSETS:
			var k := UiScale.factor_for(vs)
			var si := SafeArea.symmetric(ins)
			var s := si.x
			var t := si.y
			var b := si.w
			var w: float = vs.x
			var h: float = vs.y
			var l := HudLayout.compute(vs, si, false, k)
			assert_eq(l[&"pause"], Rect2(s + 24 * k, t + 24 * k, 144 * k, 144 * k), "pause %s %s" % [vs, ins])
			assert_eq(l[&"script"], Rect2(s + 192 * k, t + 24 * k, 312 * k, 144 * k), "script %s %s" % [vs, ins])
			assert_eq(l[&"clarence"], Rect2(s + 32 * k, h - b - 200 * k, 168 * k, 168 * k), "clarence %s %s" % [vs, ins])
			assert_eq((l[&"action"] as Rect2).get_center(), Vector2(w - s - 168 * k, h - b - 168 * k), "action centre")
			assert_eq((l[&"action"] as Rect2).size, Vector2(240, 240) * k)
	assert_eq(HudLayout.ALWAYS_ON.size(), 4, "REDESIGN §2.1: MUST be ≤ 4")


func test_tablets_scale_by_0_8() -> void:
	assert_eq(UiScale.factor_for(Vector2(1920, 1440)), 0.8, "4:3 logical height 1440 > 1250")
	assert_eq(UiScale.factor_for(Vector2(2400, 1080)), 1.0)
	var l := HudLayout.compute(Vector2(1920, 1440), Vector4.ZERO, false, 0.8)
	assert_eq((l[&"action"] as Rect2).size, Vector2(192, 192))


func test_left_handed_mirrors_every_rect_but_the_meter() -> void:
	for vs in SIZES:
		var k := UiScale.factor_for(vs)
		var r := HudLayout.compute(vs, Vector4(100, 0, 100, 0), false, k)
		var m := HudLayout.compute(vs, Vector4(100, 0, 100, 0), true, k)
		for key in [&"pause", &"script", &"clarence", &"action", &"pip", &"tray", &"figgis", &"bow", &"overview"]:
			var a: Rect2 = r[key]
			var bb: Rect2 = m[key]
			assert_almost_eq(bb.position.x, vs.x - a.position.x - a.size.x, 0.01, "%s mirrored at %s" % [key, vs])
			assert_eq(bb.position.y, a.position.y)
		assert_eq(m[&"meter"], r[&"meter"], "the centred meter stays")
		assert_almost_eq((m[&"edge_left"] as Rect2).position.x, vs.x - (r[&"edge_right"] as Rect2).end.x, 0.01,
			"the edge zones swap")


func test_thumb_rule_1300_px_at_every_aspect() -> void:
	for vs in [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(2520, 1080)]:
		for s in [0.0, 60.0, 120.0, 168.0]:
			var l := HudLayout.compute(vs, Vector4(s, 0, s, 0), false, 1.0)
			var d := (l[&"action"] as Rect2).get_center().x - (l[&"clarence"] as Rect2).get_center().x
			assert_ge(d, 1300.0, "Clarence → action %.0f px at %s, S=%d" % [d, vs, s])
			assert_almost_eq((l[&"clarence"] as Rect2).get_center().x, s + 116.0, 0.01, "Clarence centre S+116")


func test_script_pill_width_formula() -> void:
	assert_eq(HudLayout.script_pill_width(0, 0), 162.0)
	assert_eq(HudLayout.script_pill_width(2, 0), 112.0 + 92.0 + 50.0)
	assert_eq(HudLayout.script_pill_width(3, 2), 112.0 + 138.0 + 44.0 + 50.0)
	assert_eq(HudLayout.script_pill_width(8, 4), 440.0, "≤ 440")
	var l := HudLayout.compute(Vector2(2400, 1080), Vector4.ZERO, false, 1.0, HudLayout.script_pill_width(4, 2))
	assert_eq((l[&"script"] as Rect2).size.x, 112.0 + 184.0 + 44.0 + 50.0, "the hit grows with the pill")
	l = HudLayout.compute(Vector2(2400, 1080), Vector4.ZERO, false, 1.0, HudLayout.script_pill_width(1, 0))
	assert_eq((l[&"script"] as Rect2).size.x, 312.0, "never smaller than 312")


func test_contextual_rects() -> void:
	var s := 100.0
	var t := 20.0
	var b := 30.0
	var w := 2400.0
	var h := 1080.0
	var l := HudLayout.compute(Vector2(w, h), Vector4(s, t, s, b), false, 1.0)
	assert_eq(l[&"meter"], Rect2(w * 0.5 - 230, t + 24, 460, 104))
	assert_eq(l[&"pip"], Rect2(w - s - 424, t + 24, 400, 225))
	var esc: Rect2 = l[&"pip_escalated"]
	assert_eq(esc.size, Vector2(704, 396), "escalated fits at 20:9")
	assert_eq(esc.end.x, w - s - 24, "same top-right corner")
	assert_eq(esc.position.y, t + 24)
	assert_eq(l[&"tray"].position, Vector2(s + 224, h - b - 188), "chips at (S+224, H−B−188)")
	assert_eq((l[&"tray"] as Rect2).size, Vector2(3 * 168 + 144, 144))
	assert_eq(l[&"figgis"].position, Vector2(s + 24, t + 192))
	assert_eq(l[&"bow"], Rect2(w - s - 344, t + 24, 320, 112))
	assert_eq(l[&"bow_low"], Rect2(w - s - 344, t + 273, 320, 112), "slid under the Bellows window")
	assert_eq(l[&"overview"], Rect2(w - s - 168, t + 300, 144, 144))
	var el: Rect2 = l[&"edge_left"]
	var er: Rect2 = l[&"edge_right"]
	assert_eq(el.position.x, s + 24)
	assert_eq(el.end.x, s + 160)
	assert_eq(er.position.x, w - s - 160)
	assert_eq(er.end.x, w - s - 24)
	assert_almost_eq(el.size.y, 220.0, 0.01, "y 430–650 at the 1080 base")


func test_escalated_window_shrinks_only_to_clear_the_chip() -> void:
	var l := HudLayout.compute(Vector2(1920, 1080), Vector4(162, 0, 162, 0), false, 1.0, 440.0)
	var esc: Rect2 = l[&"pip_escalated"]
	assert_ge(esc.position.x, (l[&"script"] as Rect2).end.x + 23.9, "clear of the Script chip")
	assert_almost_eq(esc.size.x / esc.size.y, 704.0 / 396.0, 0.01, "aspect kept")


func test_targets_24px_apart_and_inside_the_safe_area() -> void:
	_each(func(l: Dictionary, vs: Vector2, ins: Vector4, lh: bool, k: float) -> void:
		var safe: Rect2 = l[&"safe"]
		var keys := [&"pause", &"script", &"clarence", &"action", &"tray", &"pip", &"bow", &"figgis"]
		for key in keys:
			var r: Rect2 = l[key]
			assert_true(safe.encloses(r), "%s inside the safe area at %s %s lh=%s" % [key, vs, ins, lh])
		# the always-on pieces and every contextual piece that can show with them
		var pairs := [[&"pause", &"script"], [&"script", &"figgis"], [&"pause", &"figgis"], [&"clarence", &"tray"],
			[&"tray", &"action"], [&"pip", &"action"], [&"bow_low", &"pip"], [&"script", &"pip"], [&"clarence", &"action"],
			[&"bow", &"script"], [&"overview", &"action"]]
		for p in pairs:
			var g := gap(l[p[0]], l[p[1]])
			assert_ge(g, 24.0 * k - 0.01, "%s ↔ %s %.1f px at %s %s lh=%s" % [p[0], p[1], g, vs, ins, lh]))


func test_the_bow_under_the_window_clears_it() -> void:
	_each(func(l: Dictionary, vs: Vector2, _ins: Vector4, _lh: bool, k: float) -> void:
		assert_ge(gap(l[&"bow_low"], l[&"pip"]), 24.0 * k - 0.01, "at %s" % vs))


func test_stalls_band_holds_no_target() -> void:
	_each(func(l: Dictionary, vs: Vector2, ins: Vector4, lh: bool, _k: float) -> void:
		var band: Rect2 = l[&"band"]
		for key in [&"clarence", &"action"]:
			assert_false(band.intersects(l[key]), "%s in the Stalls band at %s %s lh=%s" % [key, vs, ins, lh]))


func test_middle_band_holds_no_top_or_left_always_on_piece() -> void:
	# REDESIGN §2.5: y 250–880 holds no always-on / persistent HUD. The top row and Clarence clear it;
	# the action button's 240 px hit circle (centre H−B−168, REDESIGN §2.1) reaches up to y 792 — the
	# two REDESIGN numbers conflict by 88 px; it is reported to r3d-tools-b / the lead (brief report).
	for vs in [Vector2(1920, 1080), Vector2(2400, 1080)]:
		var l := HudLayout.compute(vs, Vector4.ZERO, false, 1.0)
		var band := HudLayout.middle_band(vs)
		for key in [&"pause", &"script", &"clarence", &"pip", &"tray", &"bow"]:
			assert_false(band.intersects(l[key]), "%s in the middle band at %s" % [key, vs])
		assert_true(band.intersects(l[&"bow_low"]), "BOW under an open window is inside it (short-lived, reported)")


func test_edge_badge_rect_picks_the_side() -> void:
	var l := HudLayout.compute(Vector2(2400, 1080), Vector4.ZERO, false, 1.0)
	assert_eq(HudLayout.edge_badge_rect(l, 1), l[&"edge_right"])
	assert_eq(HudLayout.edge_badge_rect(l, -1), l[&"edge_left"])
	assert_eq(HudLayout.edge_badge_rect(l, 0, Vector2(-1, 0.2)), l[&"edge_left"], "side from the direction")
	assert_eq(HudLayout.edge_badge_rect(l, 0, Vector2(0.3, -1)), l[&"edge_right"])


func test_pick_strip_clamped_clear_of_targets() -> void:
	_each(func(l: Dictionary, vs: Vector2, _ins: Vector4, _lh: bool, k: float) -> void:
		var size := Vector2(480, 180) * k
		for anchor in [Vector2(40, 400), Vector2(vs.x - 40, 900), Vector2(vs.x * 0.5, 100)]:
			var p := HudLayout.pick_strip_pos(l, anchor, size)
			var r := Rect2(p, size)
			for key in [&"pause", &"script", &"clarence", &"action"]:
				assert_false(r.intersects(l[key]), "pick strip over %s at %s" % [key, vs])
			assert_true((l[&"safe"] as Rect2).encloses(r), "pick strip inside the safe area"))


func test_hud_widgets_follow_the_layout() -> void:
	for lh in [false, true]:
		var hud := Hud.new()
		hud.layout_size_override = Vector2(2400, 1080)
		hud.insets_override = Vector4(162, 0, 162, 58)
		hud.left_handed = lh
		hud.relayout()
		var got := hud.target_rects()
		for key in [&"pause", &"script", &"clarence", &"action"]:
			assert_true(got.has(key), "%s visible at rest" % key)
			assert_eq(got[key], hud.layout[key], "%s widget rect = layout rect (lh=%s)" % [key, lh])
		for key in [&"meter", &"figgis", &"overview", &"tray", &"bow"]:
			assert_false(got.has(key), "%s hidden at rest" % key)
		hud.free()


func test_hud_tablet_scale_applies_to_widgets() -> void:
	var hud := Hud.new()
	hud.layout_size_override = Vector2(1920, 1440)
	hud.insets_override = Vector4.ZERO
	hud.relayout()
	assert_eq(hud.hud_scale, 0.8)
	var got := hud.target_rects()
	assert_eq((got[&"action"] as Rect2).size, Vector2(192, 192), "240 × 0.8")
	assert_eq(got[&"action"], hud.layout[&"action"])
	hud.free()
