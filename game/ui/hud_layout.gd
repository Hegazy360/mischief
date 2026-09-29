## HudLayout — the pure HUD layout (GDD §3.8): every widget's hit rect from the logical viewport
## size, the safe-area insets and the handedness. Positions are the top-left of each HIT box.
##
##   S = symmetric side inset, T = top, B = bottom, W × H = logical viewport, k = UiScale (0.8 on
##   tablets). Right-handed (default):
##   pause (S+24, T+24) 144 · figgis (S+192, T+24) 144 · meter centred, y T+16, 600 × 144 ·
##   banner centred, y T+164 (not a target) · pip (W−S−472, T+24) 448 × 252 (escalated 704 × 396,
##   same top-right corner) · overview (W−S−168, T+300) 144 (moves below an escalated PiP) ·
##   tray (S+32, H−B−200) 744 × 168 · clarence (S+32, H−B−392) 168 · action centre
##   (W−S−168, H−B−168) 240 · Stalls band x ∈ [S+800, W−S−312] along the bottom: no targets.
##   Left-handed mirrors every rect horizontally (x' = W − x − w): the thumb clusters swap and the
##   top corners swap pause/Figgis with PiP/overview.
class_name HudLayout
extends RefCounted

## Stalls band height reserved at the bottom centre (the heads rise up to 120 px).
const BAND_H := 120.0
## Rects that are touch targets (the layout test checks sizes, gaps and the free band).
const TARGETS: PackedStringArray = ["pause", "figgis", "meter", "pip", "overview", "tray", "clarence", "action"]


## Every rect (Dictionary StringName → Rect2): pause, figgis, meter, banner, pip, pip_escalated,
## overview, overview_escalated, tray, clarence, action, band, safe, edge_zone.
static func compute(vp: Vector2, insets: Vector4, left_handed: bool = false, k: float = 1.0) -> Dictionary:
	var s := maxf(insets.x, insets.z)
	var t := insets.y
	var b := insets.w
	var w := vp.x
	var h := vp.y
	var r := {}
	r[&"pause"] = Rect2(s + 24.0 * k, t + 24.0 * k, 144.0 * k, 144.0 * k)
	r[&"figgis"] = Rect2(s + 192.0 * k, t + 24.0 * k, 144.0 * k, 144.0 * k)
	r[&"meter"] = Rect2((w - 600.0 * k) * 0.5, t + 16.0 * k, 600.0 * k, 144.0 * k)
	r[&"banner"] = Rect2((w - 640.0 * k) * 0.5, t + 164.0 * k, 640.0 * k, 96.0 * k)
	r[&"pip"] = Rect2(w - s - 472.0 * k, t + 24.0 * k, 448.0 * k, 252.0 * k)
	r[&"pip_escalated"] = Rect2(w - s - 728.0 * k, t + 24.0 * k, 704.0 * k, 396.0 * k)
	r[&"overview"] = Rect2(w - s - 168.0 * k, t + 300.0 * k, 144.0 * k, 144.0 * k)
	r[&"overview_escalated"] = Rect2(w - s - 168.0 * k, t + 444.0 * k, 144.0 * k, 144.0 * k)
	r[&"tray"] = Rect2(s + 32.0 * k, h - b - 200.0 * k, 744.0 * k, 168.0 * k)
	r[&"clarence"] = Rect2(s + 32.0 * k, h - b - 392.0 * k, 168.0 * k, 168.0 * k)
	var ac := Vector2(w - s - 168.0 * k, h - b - 168.0 * k)
	r[&"action"] = Rect2(ac - Vector2(120.0, 120.0) * k, Vector2(240.0, 240.0) * k)
	var bx0 := s + 800.0 * k
	var bx1 := w - s - 312.0 * k
	r[&"band"] = Rect2(bx0, h - b - BAND_H * k, maxf(0.0, bx1 - bx0), BAND_H * k)
	r[&"safe"] = Rect2(s, t, w - 2.0 * s, h - t - b)
	# where edge bubbles and pick strips may go: below the top row, above the bottom clusters
	r[&"edge_zone"] = Rect2(s + 32.0 * k, t + 300.0 * k, w - 2.0 * s - 64.0 * k, h - t - b - 300.0 * k - 420.0 * k)
	if left_handed:
		for key in r.keys():
			if key == &"safe" or key == &"meter" or key == &"banner" or key == &"edge_zone":
				continue
			var rc: Rect2 = r[key]
			r[key] = Rect2(w - rc.position.x - rc.size.x, rc.position.y, rc.size.x, rc.size.y)
	return r


## Where the edge bubble sits (hit box top-left) for a direction toward Bellows (screen space,
## y down). Mostly vertical → top centre under the banner (up) or bottom centre just above the
## Stalls band, between the thumb clusters (down); mostly horizontal → the left / right edge at
## mid-height, between the top-corner column and the bottom cluster. Never overlaps a target.
static func edge_bubble_pos(layout: Dictionary, dir: Vector2, bubble: float = 144.0) -> Vector2:
	var safe: Rect2 = layout[&"safe"]
	var banner: Rect2 = layout[&"banner"]
	var band: Rect2 = layout[&"band"]
	var d := dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	if absf(d.y) > absf(d.x):
		var y := banner.end.y + 24.0 if d.y < 0.0 else band.position.y - 24.0 - bubble
		var x0 := safe.position.x + 24.0
		var x1 := safe.end.x - 24.0 - bubble
		var mid_x := safe.get_center().x
		for key in TARGETS:
			var rc: Rect2 = layout[StringName(key)]
			if rc.end.y + 24.0 <= y or rc.position.y - 24.0 >= y + bubble:
				continue
			if rc.get_center().x < mid_x:
				x0 = maxf(x0, rc.end.x + 24.0)
			else:
				x1 = minf(x1, rc.position.x - 24.0 - bubble)
		var cx := mid_x + d.x * safe.size.x * 0.25 - bubble * 0.5
		return Vector2(clampf(cx, x0, maxf(x0, x1)), y)
	# left / right edge: between the targets in that half's corner column (top) and its thumb
	# cluster (bottom), label (60 px) below when it fits
	var left := d.x < 0.0
	var mid := safe.get_center()
	var y0 := safe.position.y + 24.0
	var y1 := safe.end.y - 24.0 - bubble
	for key in TARGETS:
		var rc: Rect2 = layout[StringName(key)]
		if (rc.get_center().x < mid.x) != left or key == "meter":
			continue
		if rc.get_center().y < mid.y:
			y0 = maxf(y0, rc.end.y + 24.0)
		else:
			y1 = minf(y1, rc.position.y - 24.0 - bubble)
	var want := mid.y - bubble * 0.5
	if y1 - y0 >= 60.0:
		want = minf(want, y1 - 60.0)
	var y := clampf(want, y0, maxf(y0, y1))
	if left:
		return Vector2(safe.position.x + 32.0, y)
	return Vector2(safe.end.x - 32.0 - bubble, y)


## Where a pick strip of `size` goes when asked to pop above `anchor` (screen px): centred on
## the anchor's x, its bottom 24 px above the anchor, clamped into the safe area and above the
## bottom clusters / Stalls band.
static func pick_strip_pos(layout: Dictionary, anchor: Vector2, size: Vector2) -> Vector2:
	var safe: Rect2 = layout[&"safe"]
	var p := Vector2(anchor.x - size.x * 0.5, anchor.y - 24.0 - size.y)
	var min_y := safe.position.y + 300.0
	var clusters_top := minf((layout[&"clarence"] as Rect2).position.y, (layout[&"action"] as Rect2).position.y)
	var max_y := clusters_top - 24.0 - size.y
	var over: Rect2 = layout[&"overview"]
	var min_x := safe.position.x + 32.0
	var max_x := safe.end.x - 32.0 - size.x
	if over.get_center().x > safe.get_center().x:
		max_x = minf(max_x, over.position.x - 24.0 - size.x)
	else:
		min_x = maxf(min_x, over.end.x + 24.0)
	p.x = clampf(p.x, min_x, maxf(min_x, max_x))
	p.y = clampf(p.y, min_y, maxf(min_y, max_y))
	return p
