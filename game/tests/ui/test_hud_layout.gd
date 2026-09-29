## HUD layout (GDD §3.8): every target's hit rect ≥ spec, ≥ 24 px apart, none in the
## bottom-centre Stalls band, all inside the safe area (thumb clusters ≥ 32 px in), at 1920×1080,
## 2400×1080, 1920×1440 (tablet ×0.8) and with 162 px notch insets; left-handed mirrors.
extends TestBase

const SIZES := [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1920, 1440), Vector2(2520, 1080)]
const INSETS := [Vector4(0, 0, 0, 0), Vector4(162, 0, 162, 58), Vector4(120, 0, 0, 20)]
## Minimum hit sizes (GDD §3.8) at scale 1.
const SPEC := {
	&"pause": Vector2(144, 144), &"figgis": Vector2(144, 144), &"meter": Vector2(600, 144),
	&"pip": Vector2(448, 252), &"overview": Vector2(144, 144), &"tray": Vector2(744, 168),
	&"clarence": Vector2(168, 168), &"action": Vector2(240, 240),
}


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


func test_positions_match_the_gdd_table() -> void:
	var s := 162.0
	var ins := Vector4(s, 0, s, 58)
	var L := HudLayout.compute(Vector2(2400, 1080), ins, false, 1.0)
	var W := 2400.0
	var H := 1080.0
	var B := 58.0
	assert_eq((L[&"pause"] as Rect2).position, Vector2(s + 24, 24))
	assert_eq((L[&"figgis"] as Rect2).position, Vector2(s + 192, 24))
	assert_eq(L[&"meter"], Rect2((W - 600) / 2, 16, 600, 144))
	assert_eq((L[&"banner"] as Rect2).position.y, 164.0)
	assert_eq(L[&"pip"], Rect2(W - s - 472, 24, 448, 252))
	var e: Rect2 = L[&"pip_escalated"]
	assert_eq(e.end.x, W - s - 24, "escalated PiP keeps the top-right corner")
	assert_eq(e.position.y, 24.0)
	assert_eq(e.position.x, (L[&"meter"] as Rect2).end.x + 24, "…and fits 24 px beside the meter (690 × 388 here)")
	var full := HudLayout.compute(Vector2(2400, 1080), Vector4.ZERO, false, 1.0)
	assert_eq(full[&"pip_escalated"], Rect2(2400 - 24 - 704, 24, 704, 396), "704 × 396 where it fits")
	assert_eq((L[&"overview"] as Rect2).position, Vector2(W - s - 168, 300))
	assert_eq(L[&"tray"], Rect2(s + 32, H - B - 200, 744, 168))
	assert_eq(L[&"clarence"], Rect2(s + 32, H - B - 392, 168, 168))
	assert_eq((L[&"action"] as Rect2).get_center(), Vector2(W - s - 168, H - B - 168))
	var band: Rect2 = L[&"band"]
	assert_eq(band.position.x, s + 800)
	assert_eq(band.end.x, W - s - 312)


func test_hit_sizes_at_least_spec() -> void:
	_each(func(L: Dictionary, vs: Vector2, _i: Vector4, lh: bool, k: float) -> void:
		for key in SPEC:
			var r: Rect2 = L[key]
			var want: Vector2 = SPEC[key] * k
			assert_true(r.size.x >= want.x - 0.01 and r.size.y >= want.y - 0.01,
				"%s %s at %s lh=%s: %s ≥ %s" % [key, r.size, vs, lh, r.size, want])
			if key != &"meter" and key != &"pip" and key != &"tray":
				assert_ge(minf(r.size.x, r.size.y), UiKit.TOUCH_MIN * k - 0.01, "%s ≥ 144 px" % key))


func test_targets_24px_apart() -> void:
	_each(func(L: Dictionary, vs: Vector2, _i: Vector4, lh: bool, k: float) -> void:
		var keys := HudLayout.TARGETS
		for a in keys.size():
			for b in range(a + 1, keys.size()):
				var g := gap(L[StringName(keys[a])], L[StringName(keys[b])])
				assert_ge(g, UiKit.TOUCH_GAP * k - 0.01, "%s ↔ %s gap %.1f at %s lh=%s" % [keys[a], keys[b], g, vs, lh]))


func test_bottom_centre_band_is_free() -> void:
	_each(func(L: Dictionary, vs: Vector2, ins: Vector4, lh: bool, k: float) -> void:
		var band: Rect2 = L[&"band"]
		# check the whole height of the bottom clusters, not just the heads' 120 px
		var tall := Rect2(band.position.x, vs.y - ins.w - 288.0 * k, band.size.x, 288.0 * k)
		assert_gt(band.size.x, 0.0, "the band exists at %s" % vs)
		for key in HudLayout.TARGETS:
			assert_false((L[StringName(key)] as Rect2).intersects(tall),
				"%s stays out of the Stalls band at %s lh=%s" % [key, vs, lh]))


func test_inside_the_safe_area() -> void:
	_each(func(L: Dictionary, vs: Vector2, ins: Vector4, lh: bool, k: float) -> void:
		var safe := Rect2(ins.x, ins.y, vs.x - ins.x - ins.z, vs.y - ins.y - ins.w)
		for key in HudLayout.TARGETS:
			var r: Rect2 = L[StringName(key)]
			assert_true(safe.encloses(r), "%s inside the safe area at %s ins=%s lh=%s" % [key, vs, ins, lh])
		# thumb clusters sit ≥ 32 px inside (the Android back gesture lives at the side edges)
		for key in [&"tray", &"clarence"]:
			var r: Rect2 = L[key]
			var side := minf(r.position.x - safe.position.x, safe.end.x - r.end.x)
			assert_ge(side, 32.0 * k - 0.01, "%s ≥ 32 px from the side" % key)
			assert_ge(safe.end.y - r.end.y, 32.0 * k - 0.01, "%s ≥ 32 px from the bottom" % key)
		var a: Rect2 = L[&"action"]
		assert_ge(minf(a.position.x - safe.position.x, safe.end.x - a.end.x), 32.0 * k - 0.01, "action ≥ 32 px from the side")
		assert_ge(safe.end.y - a.end.y, 32.0 * k - 0.01, "action ≥ 32 px from the bottom")
		# the top row follows the table: 24 px (meter 16 px) from the top, 24 px from the sides
		for key in [&"pause", &"figgis", &"pip", &"overview"]:
			var r: Rect2 = L[key]
			assert_ge(r.position.y - safe.position.y, 24.0 * k - 0.01, "%s top margin" % key)
			assert_ge(minf(r.position.x - safe.position.x, safe.end.x - r.end.x), 24.0 * k - 0.01, "%s side margin" % key)
		assert_ge((L[&"meter"] as Rect2).position.y - safe.position.y, 16.0 * k - 0.01, "meter top margin"))


func test_thumb_cluster_distance() -> void:
	# GDD §3.3: Clarence's centre is ≥ 1,300 px from the action button's on a 16:9 phone and up
	for vs in [Vector2(1920, 1080), Vector2(2400, 1080)]:
		var L := HudLayout.compute(vs, Vector4.ZERO, false, 1.0)
		var d := (L[&"clarence"] as Rect2).get_center().distance_to((L[&"action"] as Rect2).get_center())
		assert_ge(d, 1300.0, "Clarence ↔ action %.0f px at %s" % [d, vs])


func test_left_handed_mirrors() -> void:
	var vs := Vector2(2400, 1080)
	var ins := Vector4(162, 0, 162, 58)
	var R := HudLayout.compute(vs, ins, false, 1.0)
	var L := HudLayout.compute(vs, ins, true, 1.0)
	for key in [&"pause", &"figgis", &"pip", &"overview", &"tray", &"clarence", &"action", &"band"]:
		var r: Rect2 = R[key]
		var l: Rect2 = L[key]
		assert_eq(l.size, r.size, "%s same size" % key)
		assert_almost_eq(l.position.x, vs.x - r.end.x, 0.01, "%s mirrored in x" % key)
		assert_eq(l.position.y, r.position.y, "%s same y" % key)
	assert_eq(L[&"meter"], R[&"meter"], "the meter stays centred")
	assert_lt((L[&"action"] as Rect2).position.x, vs.x * 0.5, "left-handed: the action button is bottom-left")
	assert_gt((L[&"tray"] as Rect2).position.x, vs.x * 0.5, "…and the tray bottom-right")
	assert_gt((L[&"pause"] as Rect2).position.x, vs.x * 0.5, "pause swaps to the top-right")
	assert_lt((L[&"pip"] as Rect2).position.x, vs.x * 0.5, "the PiP swaps to the top-left")


func test_tablet_scale() -> void:
	assert_eq(UiScale.factor_for(Vector2(1920, 1440)), 0.8, "logical height > 1250 → ×0.8")
	assert_eq(UiScale.factor_for(Vector2(1920, 1200)), 1.0, "16:10 stays ×1")
	assert_eq(UiScale.factor_for(Vector2(2400, 1080)), 1.0)


func test_edge_bubble_positions_avoid_targets() -> void:
	_each(func(L: Dictionary, vs: Vector2, ins: Vector4, lh: bool, k: float) -> void:
		var safe := Rect2(ins.x, ins.y, vs.x - ins.x - ins.z, vs.y - ins.y - ins.w)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1, -0.3), Vector2(-1, 0.4)]:
			var p := HudLayout.edge_bubble_pos(L, d, 144.0 * k)
			var r := Rect2(p, Vector2(144, 144) * k)
			assert_true(safe.encloses(r), "edge bubble %s inside the safe area at %s" % [d, vs])
			for key in HudLayout.TARGETS:
				assert_ge(gap(r, L[StringName(key)]), 24.0 * k - 0.01, "edge bubble %s vs %s at %s lh=%s" % [d, key, vs, lh]))


func test_edge_bubble_emote_puff_clear_of_targets() -> void:
	_each(func(L: Dictionary, vs: Vector2, ins: Vector4, lh: bool, k: float) -> void:
		var safe := Rect2(ins.x, ins.y, vs.x - ins.x - ins.z, vs.y - ins.y - ins.w)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1, -0.3), Vector2(-1, 0.4)]:
			var p := HudLayout.edge_bubble_pos(L, d, 144.0 * k)
			var centre := p + Vector2(72, 72) * k
			var pb := EdgeBubble.puff_bounds(d)
			var r := Rect2(centre + pb.position * k, pb.size * k)
			assert_true(safe.encloses(r), "emote puff %s inside the safe area at %s lh=%s" % [d, vs, lh])
			for key in HudLayout.TARGETS:
				assert_false(r.intersects(L[StringName(key)]), "emote puff %s never covers %s at %s lh=%s" % [d, key, vs, lh]))


func test_pick_strip_clamped_clear_of_targets() -> void:
	_each(func(L: Dictionary, vs: Vector2, _ins: Vector4, lh: bool, k: float) -> void:
		var sz := PickStrip.size_for(4) * k
		for anchor in [Vector2(40, 900), Vector2(vs.x - 10, 200), Vector2(vs.x * 0.5, 700), Vector2(vs.x * 0.3, 380)]:
			var r := Rect2(HudLayout.pick_strip_pos(L, anchor, sz), sz)
			for key in HudLayout.TARGETS:
				assert_ge(gap(r, L[StringName(key)]), 24.0 * k - 0.01, "pick strip at %s vs %s (%s lh=%s)" % [anchor, key, vs, lh]))


func test_tray_slots() -> void:
	for i in 4:
		var r := ItemTray.slot_rect(i)
		assert_eq(r.size, Vector2(168, 168))
		if i > 0:
			assert_eq(r.position.x - ItemTray.slot_rect(i - 1).end.x, 24.0, "24 px between slots")
	assert_eq(ItemTray.slot_rect(3).end.x, 744.0)


func test_hud_widgets_follow_the_layout() -> void:
	for lh in [false, true]:
		var hud := Hud.new()
		hud.layout_size_override = Vector2(2400, 1080)
		hud.insets_override = Vector4(162, 0, 162, 58)
		hud.left_handed = lh
		hud.relayout()
		var got := hud.target_rects()
		for key in [&"pause", &"figgis", &"meter", &"overview", &"tray", &"clarence", &"action"]:
			assert_true(got.has(key), "%s visible" % key)
			assert_eq(got[key], hud.layout[key], "%s widget rect = layout rect (lh=%s)" % [key, lh])
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
