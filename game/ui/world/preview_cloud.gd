## PreviewCloud — the passive preview above an available rig point (REDESIGN_3D §4.1): a 112 × 90
## cream thought-cloud with a 78 px pictogram of the JOKE, at 80 % strength; 30 % while faded (V1),
## 100 % and ×1.35 for the N4 "next useful" spot. Variants on the same node:
##   needs cloud   the pictogram dimmed + the missing item's grey silhouette in a disc (bottom-right);
##   his ring      a red countdown ring round the cloud ("he's coming for this next");
##   combine badge (pictogram empty) a small navy pill "→ <icon>" beside the armed prop's tag.
## The node's position is the cloud's CENTRE; `size()` is its box (for the placer). Drawn as one
## UiShapes batch + the pictogram texture (+ the silhouette): 2–3 draw calls.
class_name PreviewCloud
extends Node2D

const W := 112.0
const H := 90.0
const ICON := 78.0
const NEED_DISC := 46.0
const RING_W := 8.0
const RED := Color("#E8413C")
const INK := 5.0
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
func box_size() -> Vector2:
	if pict == null and badge_tex != null:
		return Vector2(96.0, 56.0) * k
	var s := OverlayRules.LOUD_SCALE if loud else 1.0
	var e := cloud_half_extent(W, H)
	if ring_frac >= 0.0:
		var rr := W * 0.5 + 10.0 + (RING_W + 6.0) * 0.5
		e = Vector2(maxf(e.x, rr), maxf(e.y, rr))
	return e * 2.0 * k * s


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
	# with his ring round it the tail starts outside the ring, so a cloud the placer moved still points at its prop
	cloud(Vector2.ZERO, W, H, a, tail_dir, (W * 0.5 + 10.0 + RING_W * 0.5 + 6.0) if ring_frac >= 0.0 else 0.0)
	if ring_frac >= 0.0:
		UiShapes.arc(Vector2.ZERO, W * 0.5 + 10.0, 0.0, TAU, RING_W + 6.0, Color(UiKit.NAVY, 0.55 * a), 48)
		if ring_frac > 0.0:
			var a0 := -PI * 0.5
			UiShapes.arc(Vector2.ZERO, W * 0.5 + 10.0, a0, a0 + TAU * ring_frac, RING_W, Color(RED, a), 48)
	if need_tex != null:
		var dc := Vector2(W * 0.5 - 14.0, H * 0.5 - 10.0)
		UiShapes.circle(dc, NEED_DISC * 0.5 + 4.0, Color(UiKit.NAVY, a))
		UiShapes.circle(dc, NEED_DISC * 0.5, Color("#D9D6E2", a))
	UiShapes.flush(self)
	var icon_a := a * (0.55 if need_tex != null else 1.0)
	UiKit.draw_icon(self, pict, Rect2(-ICON * 0.5, -ICON * 0.5 - 4.0, ICON, ICON), Color(1, 1, 1, icon_a))
	if need_tex != null:
		var dc := Vector2(W * 0.5 - 14.0, H * 0.5 - 10.0)
		UiKit.draw_icon(self, need_tex, Rect2(dc - Vector2(17, 17), Vector2(34, 34)), Color(0.2, 0.19, 0.3, 0.75 * a))
	draw_set_transform(Vector2.ZERO)


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
static func cloud(c: Vector2, w: float, h: float, a: float, tail: Vector2, tail_from: float = 0.0) -> void:
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
			UiShapes.circle(t1, 9.0 + INK, Color(UiKit.NAVY, a))
			UiShapes.circle(t2, 5.0 + INK * 0.8, Color(UiKit.NAVY, a))
			UiShapes.circle(t1, 9.0, Color(UiKit.CREAM, a))
			UiShapes.circle(t2, 5.0, Color(UiKit.CREAM, a))
