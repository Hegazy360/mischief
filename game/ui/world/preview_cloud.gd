## PreviewCloud — the passive preview above an available rig point (REDESIGN_3D §4.1): a 112 × 90
## cream thought-cloud with a 78 px pictogram of the JOKE, at 80 % strength; 30 % while faded (V1),
## 100 % and ×1.35 for the N4 "next useful" spot. Variants on the same node:
##   needs cloud   the pictogram a little dimmed + an EMPTY SLOT on the cloud's top-right shoulder (outside the
##                 pictogram, so it never hides part of the joke): a dashed ring round the missing item's faint
##                 silhouette with a gold "?" — "fetch this first", not part of the rig (r3d QA round 2, Q2-S2:
##                 the solid grey horn inside the cloud read as "rigged with a honking horn");
##   his ring      a red countdown ring round the cloud ("he's coming for this next");
##   combine badge (pictogram empty) a small navy pill "→ <icon>" beside the armed prop's tag.
## The node's position is the cloud's CENTRE; `size()` is its box (for the placer). Drawn as one
## UiShapes batch + the pictogram texture (+ the silhouette): 2–3 draw calls.
## The TAIL (`set_tail`, r3d QA round 2, Q2-C1) is a chain of shrinking thought-dots from the cloud's edge (outside his
## ring) to its prop's top — 2 dots when the prop is close, up to TAIL_MAX_DOTS when the placer had to move the cloud
## (beside the prop, or slid clear of the HUD band) — so the eye can follow it to the thing it belongs to.
class_name PreviewCloud
extends Node2D

const W := 112.0
const H := 90.0
const ICON := 78.0
const NEED_DISC := 40.0
const NEED_DASHES := 8
const RING_W := 8.0
const RED := Color("#E8413C")
const INK := 5.0
const GOLD := Color("#F2B632")
## Tail chain: dot spacing (local px) and the most dots.
const TAIL_STEP := 30.0
const TAIL_MAX_DOTS := 4
## Cloud lobes (x, y as fractions of the half-size, radius as a fraction of min(w, 1.25 h)): a big
## centre and four round shoulders — reads as a cloud at 78 px, not a blob.
const LOBES: PackedVector3Array = [Vector3(0.0, 0.06, 0.46), Vector3(-0.52, 0.18, 0.33), Vector3(0.52, 0.18, 0.33),
	Vector3(-0.24, -0.34, 0.36), Vector3(0.26, -0.32, 0.38)]

var pict: Texture2D = null
var need_tex: Texture2D = null
var badge_tex: Texture2D = null
var strength: float = 0.8
var ring_frac: float = -1.0
var loud: bool = false
## Screen-space direction from the cloud centre to its anchor (the tail points there).
var tail_dir: Vector2 = Vector2.DOWN
## Screen-space vector from the cloud centre to where the tail ends (its prop's top); ZERO = the short 2-dot tail.
var tail_to: Vector2 = Vector2.ZERO
## Overall scale (the HUD's world-overlay scale × the loud boost).
var k: float = 1.0

var _c_key := Vector4(-1, -1, -1, -1)


## Set everything; redraws only when something visible changed.
func set_data(p_pict: Texture2D, p_strength: float, p_need: Texture2D, p_ring: float, p_badge: Texture2D,
		p_loud: bool, p_k: float) -> void:
	var key := Vector4(p_strength, p_ring, p_k, (1.0 if p_loud else 0.0) + (2.0 if p_need != null else 0.0))
	if p_pict == pict and p_need == need_tex and p_badge == badge_tex and key == _c_key:
		return
	pict = p_pict
	need_tex = p_need
	badge_tex = p_badge
	strength = p_strength
	ring_frac = p_ring
	loud = p_loud
	k = p_k
	_c_key = key
	queue_redraw()


## The cloud's box size in screen px (placer input): everything it draws — the lobes with their ink
## and drop shadow, and his ring when it shows (not the two tail bubbles, which point at the prop) —
## so two placed clouds never overlap on screen (r3d QA Q-C1/Q-C2: 112 × 90 was the spec's body, the
## drawing reaches 142 × 128).
## The tail ends at `to` (screen px from the centre); redraws on a change of more than half a pixel.
func set_tail(to: Vector2) -> void:
	if to.distance_squared_to(tail_to) < 0.25:
		return
	tail_to = to
	tail_dir = to.normalized() if to != Vector2.ZERO else Vector2.DOWN
	queue_redraw()


func box_size() -> Vector2:
	if pict == null and badge_tex != null:
		return Vector2(96.0, 56.0) * k
	var s := OverlayRules.LOUD_SCALE if loud else 1.0
	var e := cloud_half_extent(W, H)
	if ring_frac >= 0.0:
		var rr := W * 0.5 + 10.0 + (RING_W + 6.0) * 0.5
		e = Vector2(maxf(e.x, rr), maxf(e.y, rr))
	if need_tex != null:
		# the slot on the top-right shoulder and its "?" badge
		var nc := need_center()
		e = Vector2(maxf(e.x, nc.x + NEED_DISC * 0.5 + 16.0), maxf(e.y, -nc.y + NEED_DISC * 0.5 + 4.0))
	return e * 2.0 * k * s


## The distance from the centre to the edge of the rx × ry ellipse along the unit direction `d`.
static func _edge_along(d: Vector2, rx: float, ry: float) -> float:
	var q := (d.x / maxf(rx, 1.0)) * (d.x / maxf(rx, 1.0)) + (d.y / maxf(ry, 1.0)) * (d.y / maxf(ry, 1.0))
	return 1.0 / sqrt(maxf(q, 1e-6))


## Half the drawn size of `cloud(…, w, h, …)` round its centre (lobes + ink + the 6 px shadow; the
## larger of the top and bottom halves; tail bubbles excluded).
static func cloud_half_extent(w: float, h: float) -> Vector2:
	var rx := w * 0.5
	var ry := h * 0.5
	var ex := 0.0
	var ey := 0.0
	for v in LOBES:
		var r := v.z * minf(w, h * 1.25) + INK
		ex = maxf(ex, absf(v.x * rx) + r)
		ey = maxf(ey, maxf(-(v.y * ry) + r, v.y * ry + r + 6.0))
	return Vector2(ex, ey)


func _draw() -> void:
	var a := clampf(strength, 0.0, 1.0)
	if pict == null and badge_tex != null:
		_draw_badge(a)
		return
	var s := k * (OverlayRules.LOUD_SCALE if loud else 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	UiShapes.begin()
	# with his ring round it the tail starts outside the ring, so a cloud the placer moved still points at its prop;
	# the chain runs to the prop's top (tail_to, in local units)
	cloud(Vector2.ZERO, W, H, a, tail_dir, (W * 0.5 + 10.0 + RING_W * 0.5 + 6.0) if ring_frac >= 0.0 else 0.0,
		tail_to.length() / s if tail_to != Vector2.ZERO else 0.0)
	if ring_frac >= 0.0:
		UiShapes.arc(Vector2.ZERO, W * 0.5 + 10.0, 0.0, TAU, RING_W + 6.0, Color(UiKit.NAVY, 0.55 * a), 48)
		if ring_frac > 0.0:
			var a0 := -PI * 0.5
			UiShapes.arc(Vector2.ZERO, W * 0.5 + 10.0, a0, a0 + TAU * ring_frac, RING_W, Color(RED, a), 48)
	if need_tex != null:
		# an EMPTY SLOT: a pale disc, a dashed navy ring round it (not a solid badge stuck on the joke)
		var dc := need_center()
		UiShapes.circle(dc, NEED_DISC * 0.5 + 2.0, Color(UiKit.CREAM, a))
		for d in NEED_DASHES:
			var a0 := TAU * float(d) / float(NEED_DASHES)
			UiShapes.arc(dc, NEED_DISC * 0.5, a0, a0 + TAU * 0.6 / float(NEED_DASHES), 4.5, Color(UiKit.NAVY, a), 6)
	UiShapes.flush(self)
	var icon_a := a * (0.75 if need_tex != null else 1.0)
	UiKit.draw_icon(self, pict, Rect2(-ICON * 0.5, -ICON * 0.5 - 4.0, ICON, ICON), Color(1, 1, 1, icon_a))
	if need_tex != null:
		var dc := need_center()
		# the missing item's faint silhouette in the slot, and a gold "?" badge on the slot's shoulder
		UiKit.draw_icon(self, need_tex, Rect2(dc - Vector2(14, 14), Vector2(28, 28)), Color(0.2, 0.19, 0.3, 0.38 * a))
		var qc := dc + Vector2(NEED_DISC * 0.42, NEED_DISC * 0.34)
		UiShapes.begin()
		UiShapes.circle(qc, 13.0, Color(UiKit.NAVY, a))
		UiShapes.circle(qc, 10.0, Color(GOLD, a))
		UiShapes.flush(self)
		UiKit.draw_text_centered(self, UiKit.display_font(), qc, "?", 20, Color(UiKit.NAVY, a), 0)
	draw_set_transform(Vector2.ZERO)


## The needs slot's centre in local units (the cloud's top-right shoulder, just outside the pictogram).
static func need_center() -> Vector2:
	return Vector2(W * 0.5 + 4.0, -H * 0.5 + 4.0)


func _draw_badge(a: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var r := Rect2(-48, -28, 96, 56)
	UiKit.draw_chunky_rect(self, r, 28.0, Color(UiKit.NAVY, a), Color(UiKit.NAVY, a), 0.0, 0.0)
	# the arrow → then the icon
	UiShapes.begin()
	UiShapes.line(Vector2(-36, 0), Vector2(-10, 0), Color(UiKit.CREAM, a), 6.0)
	UiShapes.line(Vector2(-18, -9), Vector2(-9, 0), Color(UiKit.CREAM, a), 6.0)
	UiShapes.line(Vector2(-18, 9), Vector2(-9, 0), Color(UiKit.CREAM, a), 6.0)
	UiShapes.flush(self)
	UiKit.draw_icon(self, badge_tex, Rect2(-2, -22, 44, 44), Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)


## A comic thought-cloud of w × h centred on `c` (navy ink, cream fill, soft drop shadow) with two
## tail bubbles toward `tail` (a direction; ZERO = no tail) — into the current UiShapes batch.
## `tail_from` > 0: the tail bubbles start that far from the centre along `tail` (outside a ring).
## `tail_len` > 0: the tail is a chain of dots from the cloud's edge (or `tail_from`) to `tail_len` from the centre
## (its prop's top) — 2 dots when that is close, up to TAIL_MAX_DOTS, shrinking toward the prop.
static func cloud(c: Vector2, w: float, h: float, a: float, tail: Vector2, tail_from: float = 0.0,
		tail_len: float = 0.0) -> void:
	var rx := w * 0.5
	var ry := h * 0.5
	# shadow, ink, fill (three passes over the same lobes)
	for pass_i in 3:
		for v in LOBES:
			var p := c + Vector2(v.x * rx, v.y * ry)
			var r := v.z * minf(w, h * 1.25)
			match pass_i:
				0:
					UiShapes.circle(p + Vector2(0, 6), r + INK, Color(UiKit.NAVY, 0.28 * a))
				1:
					UiShapes.circle(p, r + INK, Color(UiKit.NAVY, a))
				2:
					UiShapes.circle(p, r, Color(UiKit.CREAM, a))
		if pass_i == 1 and tail != Vector2.ZERO:
			var d := tail.normalized()
			var t1 := c + Vector2(d.x * rx * 0.75, d.y * ry * 1.25)
			var t2 := c + Vector2(d.x * rx * 1.05, d.y * ry * 1.75)
			if tail_from > 0.0:
				t1 = c + d * (tail_from + 10.0)
				t2 = c + d * (tail_from + 28.0)
			var n := 2
			var s0 := (t1 - c).length()
			var s1 := (t2 - c).length()
			if tail_len > 0.0:
				# the chain: from just past the edge to a dot's width short of the prop
				var edge := tail_from + 10.0 if tail_from > 0.0 else _edge_along(d, rx * 1.05, ry * 1.25) + 6.0
				s0 = edge
				s1 = maxf(edge + 18.0, tail_len - 8.0)
				n = clampi(int((s1 - s0) / TAIL_STEP) + 1, 2, TAIL_MAX_DOTS)
			for ti in n:
				var f := float(ti) / float(n - 1)
				var pt := c + d * lerpf(s0, s1, f)
				var rr := lerpf(9.0, 4.5, f)
				UiShapes.circle(pt, rr + INK * lerpf(1.0, 0.8, f), Color(UiKit.NAVY, a))
				UiShapes.circle(pt, rr, Color(UiKit.CREAM, a))
