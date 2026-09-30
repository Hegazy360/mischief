## HudLayout — the pure R3D HUD layout (REDESIGN_3D §2.1–§2.2, r3d-hud brief §4.1–§4.2): every
## piece's HIT rect (top-left + size) from the logical viewport, the safe-area insets, the handedness,
## the tablet scale and the Script chip's width.
##
##   S = symmetric side inset, T = top, B = bottom, W × H = logical viewport, k = UiScale (0.8 on
##   tablets). Right-handed (default); the four ALWAYS-ON pieces:
##   pause (S+24, T+24) 144 · script (S+192, T+24) max(312, pill) × 144 (the pill 96 tall at T+48) ·
##   clarence (S+32, H−B−200) 168 · action centre (W−S−168, H−B−168) 240 circle.
##   CONTEXTUAL pieces: meter centred (W/2−230, T+24) 460 × 104 · banner (the Running-Gag fuse) under
##   it, bar at T+144 · pip (the Bellows window) (W−S−424, T+24) 400 × 225, escalated 704 × 396 in the
##   same top-right corner (scaled down only to clear the Script chip and the meter) · edge badge zones x S+24…S+160 /
##   W−S−160…W−S−24, y 430–650 (centred on the safe height) · chips (S+224 + i·168, H−B−188) 144 ·
##   figgis (S+24, T+192) 144 + its 320 × 200 card to the right · bow (W−S−344, T+24) 320 × 112, slid
##   under the open Bellows window to T+273 (bow_low) · overview (W−S−168, T+300) 144 · Stalls band
##   x ∈ [S+560, W−S−440] along the bottom (never a target).
##   Left-handed mirrors every rect horizontally (x' = W − x − w) except the centred meter / banner.
## Keys kept for older callers: `tray` (= chips), `figgis`, `meter`, `banner`, `pip`, `pip_escalated`,
## `overview`, `overview_escalated`, `band`, `safe`, `edge_zone`, `arrow_zone`.
class_name HudLayout
extends RefCounted

## Stalls band height reserved at the bottom centre (the heads rise up to 150 px on laughs).
const BAND_H := 120.0
## The four always-on pieces (REDESIGN §2.1 — MUST be ≤ 4).
const ALWAYS_ON: PackedStringArray = ["pause", "script", "clarence", "action"]
## Every rect that can be a touch target (layout tests: sizes, gaps).
const TARGETS: PackedStringArray = ["pause", "script", "clarence", "action", "pip", "overview", "tray", "bow",
	"figgis"]
## The Script pill (REDESIGN §2.1): 112 + 46 per required line + 22 per optional line + 50, ≤ 440.
const PILL_BASE := 112.0
const PILL_REQ := 46.0
const PILL_OPT := 22.0
const PILL_BIG := 50.0
const PILL_MAX := 440.0
const PILL_MIN_HIT := 312.0
## The carried-item chips.
const CHIPS := 4
const CHIP_HIT := 144.0
const CHIP_PITCH := 168.0
## The middle band (at the 1080 base) that holds no always-on / persistent HUD (§2.5).
const MIDDLE_Y0 := 250.0
const MIDDLE_Y1 := 880.0


## The Script pill's width for `req` required and `opt` optional lines (pure).
static func script_pill_width(req: int, opt: int) -> float:
	return minf(PILL_MAX, PILL_BASE + PILL_REQ * float(req) + PILL_OPT * float(opt) + PILL_BIG)


## Every rect (Dictionary StringName → Rect2); see the class doc. `script_w` = the Script pill width
## (script_pill_width), unscaled.
static func compute(vp: Vector2, insets: Vector4, left_handed: bool = false, k: float = 1.0,
		script_w: float = PILL_MIN_HIT) -> Dictionary:
	var s := maxf(insets.x, insets.z)
	var t := insets.y
	var b := insets.w
	var w := vp.x
	var h := vp.y
	var r := {}
	# --- always on
	r[&"pause"] = Rect2(s + 24.0 * k, t + 24.0 * k, 144.0 * k, 144.0 * k)
	r[&"script"] = Rect2(s + 192.0 * k, t + 24.0 * k, maxf(PILL_MIN_HIT, script_w) * k, 144.0 * k)
	r[&"clarence"] = Rect2(s + 32.0 * k, h - b - 200.0 * k, 168.0 * k, 168.0 * k)
	var ac := Vector2(w - s - 168.0 * k, h - b - 168.0 * k)
	r[&"action"] = Rect2(ac - Vector2(120.0, 120.0) * k, Vector2(240.0, 240.0) * k)
	# --- contextual
	r[&"meter"] = Rect2(w * 0.5 - 230.0 * k, t + 24.0 * k, 460.0 * k, 104.0 * k)
	r[&"banner"] = Rect2(w * 0.5 - 230.0 * k, t + 136.0 * k, 460.0 * k, 88.0 * k)
	r[&"pip"] = Rect2(w - s - 424.0 * k, t + 24.0 * k, 400.0 * k, 225.0 * k)
	# the escalated window keeps the top-right corner; it shrinks (aspect kept) only to stay 24 px
	# clear of the Script chip and of the transient meter (an off-screen payoff scores: the meter shows)
	var right := w - s - 24.0 * k
	var left_limit := maxf((r[&"script"] as Rect2).end.x, (r[&"meter"] as Rect2).end.x) + 24.0 * k
	var ek := minf(1.0, (right - left_limit) / (704.0 * k))
	var esz := Vector2(704.0, 396.0) * k * maxf(0.4, ek)
	r[&"pip_escalated"] = Rect2(right - esz.x, t + 24.0 * k, esz.x, esz.y)
	r[&"overview"] = Rect2(w - s - 168.0 * k, t + 300.0 * k, 144.0 * k, 144.0 * k)
	r[&"overview_escalated"] = Rect2(w - s - 168.0 * k, t + 24.0 * k + esz.y + 24.0 * k, 144.0 * k, 144.0 * k)
	r[&"tray"] = Rect2(s + 224.0 * k, h - b - 188.0 * k, (CHIP_PITCH * float(CHIPS - 1) + CHIP_HIT) * k, CHIP_HIT * k)
	r[&"figgis"] = Rect2(s + 24.0 * k, t + 192.0 * k, 144.0 * k, 144.0 * k)
	r[&"figgis_card"] = Rect2(s + 180.0 * k, t + 192.0 * k, 320.0 * k, 200.0 * k)
	r[&"bow"] = Rect2(w - s - 344.0 * k, t + 24.0 * k, 320.0 * k, 112.0 * k)
	r[&"bow_low"] = Rect2(w - s - 344.0 * k, t + 273.0 * k, 320.0 * k, 112.0 * k)
	var mid := (t + h - b) * 0.5
	r[&"edge_left"] = Rect2(s + 24.0 * k, mid - 110.0 * k, 136.0 * k, 220.0 * k)
	r[&"edge_right"] = Rect2(w - s - 160.0 * k, mid - 110.0 * k, 136.0 * k, 220.0 * k)
	var bx0 := s + 560.0 * k
	var bx1 := w - s - 440.0 * k
	r[&"band"] = Rect2(bx0, h - b - BAND_H * k, maxf(0.0, bx1 - bx0), BAND_H * k)
	r[&"safe"] = Rect2(s, t, w - 2.0 * s, h - t - b)
	# where pick strips and "it's over there" arrows may go: below the top row, above the thumbs
	r[&"edge_zone"] = Rect2(s + 32.0 * k, t + 300.0 * k, w - 2.0 * s - 64.0 * k, h - t - b - 300.0 * k - 420.0 * k)
	var az_top := t + 300.0 * k
	r[&"arrow_zone"] = Rect2(s + 200.0 * k, az_top, w - 2.0 * s - 400.0 * k, maxf(0.0, h - b - 320.0 * k - az_top))
	if left_handed:
		for key in r.keys():
			if key == &"safe" or key == &"meter" or key == &"banner" or key == &"edge_zone" or key == &"arrow_zone":
				continue
			var rc: Rect2 = r[key]
			r[key] = Rect2(w - rc.position.x - rc.size.x, rc.position.y, rc.size.x, rc.size.y)
		var el: Rect2 = r[&"edge_left"]
		r[&"edge_left"] = r[&"edge_right"]
		r[&"edge_right"] = el
	return r


## The middle band (REDESIGN §2.5: y 250–880 at the 1080 base, scaled to `vp.y`) as a full-width rect.
static func middle_band(vp: Vector2) -> Rect2:
	var f := vp.y / 1080.0
	return Rect2(0.0, MIDDLE_Y0 * f, vp.x, (MIDDLE_Y1 - MIDDLE_Y0) * f)


## Where the edge badge sits (hit box top-left) in `layout` for a side (−1 left, +1 right; any other
## value picks from `dir.x`) — the 136 × 220 edge zone of that side.
static func edge_badge_rect(layout: Dictionary, side: int, dir: Vector2 = Vector2.RIGHT) -> Rect2:
	var sd := side if side != 0 else (1 if dir.x >= 0.0 else -1)
	return layout[&"edge_right"] if sd > 0 else layout[&"edge_left"]


## Stage-2 API: the edge bubble's top-left for a direction (now: the edge badge zone of that side).
static func edge_bubble_pos(layout: Dictionary, dir: Vector2, _bubble: float = 144.0) -> Vector2:
	return edge_badge_rect(layout, 0, dir).position


## Where a pick strip of `size` goes when asked to pop above `anchor` (screen px): centred on
## the anchor's x, its bottom 24 px above the anchor, clamped into the safe area and above the
## bottom clusters / Stalls band.
static func pick_strip_pos(layout: Dictionary, anchor: Vector2, size: Vector2) -> Vector2:
	var safe: Rect2 = layout[&"safe"]
	var p := Vector2(anchor.x - size.x * 0.5, anchor.y - 24.0 - size.y)
	var min_y := safe.position.y + 300.0
	var clusters_top := minf((layout[&"clarence"] as Rect2).position.y, (layout[&"action"] as Rect2).position.y)
	var max_y := clusters_top - 24.0 - size.y
	var min_x := safe.position.x + 32.0
	var max_x := safe.end.x - 32.0 - size.x
	p.x = clampf(p.x, min_x, maxf(min_x, max_x))
	p.y = clampf(p.y, min_y, maxf(min_y, max_y))
	return p
