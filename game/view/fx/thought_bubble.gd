## FxThoughtBubble — what he'll do next (GDD §3.9, §4.2): a 150 × 130 cloud above his head
## with the next activity icon (88 px) and a 10 px countdown ring that starts ≥ 4 s before
## he leaves; left of it the awareness glyph (48 px, always shown) with up to 3 ear pips
## (20 px) under it; a progress bar for bath / nap. A route change pops the bubble and swaps
## the icon the same frame. Constant screen size; clamped below the HUD band.
## Near the left screen edge the glyph and its pips move to the cloud's right (the screen's inside), so the
## edge never clips them (r3d QA Q-C2, fix-hud R1); `waiting` fades the bubble while the shared placer's
## one-cloud rule gives the screen to Hush's thought (its own alpha, apart from the gag-hold `quiet`).
class_name FxThoughtBubble
extends Node2D

const W := 150.0
const H := 130.0
const ICON := 88.0
const RING_W := 10.0
const RING_R := 50.0
const RING_FULL_TICKS := 240.0
const GLYPH := 48.0
const PIP := 20.0
## Screen y (logical px) the bubble never rises above (HUD band: meter + Running Gag banner).
const HUD_BAND_Y := 212.0
const POP_S := 0.22
const RING_COL := Color("#E23B4E")
const RING_BG := Color("#1B2340", 0.18)
const PIP_COL := Color("#FFD23F")
## Glyph disc span (local units): left of the cloud by default, right of it near the left screen edge.
const GLYPH_L_SPAN := Vector2(-115.0, -55.0)
const GLYPH_R_SPAN := Vector2(95.0, 155.0)
## The cloud's own span (local units).
const CLOUD_SPAN := Vector2(-55.0, 95.0)
## Screen px kept between the glyph disc and the screen edge; the glyph returns left once that side has
## EDGE_PAD + EDGE_HYST px again (no flicker while he walks along the edge).
const EDGE_PAD := 8.0
const EDGE_HYST := 24.0

var cam: Variant = null              ## a camera with world_to_screen / current_zoom (optional; duck-typed)
var enabled: bool = true
## 0..1: dimmed while a caption is on screen.
var dim: float = 0.0
## True while the camera holds a gag on him: the bubble fades out of the close-up.
var quiet: bool = false
var _quiet_a := 1.0
## True while the shared placer keeps his bubble waiting (the one-cloud rule): fades out, comes back.
var waiting: bool = false
var _wait_a := 1.0
## True = the glyph + pips are drawn right of the cloud (the bubble is near the left screen edge).
var glyph_right: bool = false
var _cloud: Texture2D = null
var _dot: Texture2D = null
var _icon: Texture2D = null
var _glyph: Texture2D = null
var _next := ""
var _glyph_id := ""
var _ring := -1.0
var _pips := 0
var _bar := ""
var _bar_pct := 0.0
var _pop := 99.0
var _unit := 1.0
var _shown := false
var _lift := 0.0


func _init() -> void:
	name = "ThoughtBubble"
	visibility_layer = 2
	z_index = 32


func _ready() -> void:
	_cloud = FxArt.sprite("thought_bubble")
	_dot = FxArt.sprite("dot")


## Update from the snapshot; `head_top` = world point above his head; `lift` pushes the
## bubble up (the "?" meter needs the space).
func thought_bubble(snap: ViewSnapshot, head_top: Vector2, unit: float, lift: float = 0.0) -> void:
	var b := snap.bellows
	_shown = enabled and b.present and b.state != "CAUGHT_HOLD"
	visible = _shown
	if not _shown:
		return
	_unit = unit
	_lift = lerpf(_lift, lift, 0.25)
	if snap.bubble_next != _next:
		_next = snap.bubble_next
		_icon = FxArt.activity_icon(snap.bubble_icon if snap.bubble_icon != "" else _next)
		_pop = 0.0
	if snap.bubble_glyph != _glyph_id:
		_glyph_id = snap.bubble_glyph
		_glyph = FxArt.glyph(_glyph_id)
	_ring = float(snap.bubble_ring_ticks) / RING_FULL_TICKS if snap.bubble_ring_ticks >= 0 else -1.0
	_pips = clampi(snap.bubble_ear_pips, 0, 3)
	_bar = snap.bubble_bar
	_bar_pct = snap.bubble_bar_pct
	var p := head_top + Vector2(-float(b.facing) * 30.0 * unit, -30.0 * unit - _lift * unit)
	# Clamp below the HUD band (screen space); if that would sit on his head, move it beside.
	if cam != null:
		var top_screen: float = (cam.world_to_screen(p + Vector2(0, -H * unit)) as Vector2).y
		if top_screen < HUD_BAND_Y:
			var push: float = (HUD_BAND_Y - top_screen) / maxf(0.001, float(cam.current_zoom()))
			p.y += push
			if push > 40.0 * unit:
				p.x += -float(b.facing) * (W * 0.5 + 60.0) * unit
	position = p
	queue_redraw()


## Force a pop (a route change the same tick, `b_next` / `b_detour`).
func bump() -> void:
	_pop = 0.0


func tick(dt: float) -> void:
	if _pop < POP_S:
		_pop += dt
	var s := 1.0
	if _pop < POP_S:
		s = 1.0 + 0.28 * sin(_pop / POP_S * PI) * (1.0 - _pop / POP_S)
	scale = Vector2.ONE * s * _unit
	_quiet_a = move_toward(_quiet_a, 0.0 if quiet else 1.0, dt * 6.0)
	_wait_a = move_toward(_wait_a, 0.0 if waiting else 1.0, dt * 6.0)
	modulate.a = lerpf(1.0, 0.35, dim) * _quiet_a * _wait_a
	if _shown and is_inside_tree():
		_update_glyph_side()


## The drawn span along x (local units, before `scale`): x = left, y = right; with the glyph on `right_side`.
static func local_span(right_side: bool) -> Vector2:
	return Vector2(CLOUD_SPAN.x, GLYPH_R_SPAN.y) if right_side else Vector2(GLYPH_L_SPAN.x, CLOUD_SPAN.y)


## The drawn span in screen px (x = left, y = right) as placed now.
func screen_span() -> Vector2:
	var xf := get_global_transform_with_canvas()
	var sp := local_span(glyph_right)
	return Vector2((xf * Vector2(sp.x, 0.0)).x, (xf * Vector2(sp.y, 0.0)).x)


## Glyph side from the bubble's screen position (no allocation): right of the cloud when the left side would
## clip at the screen edge and the right side fits; back left once the left side clears the edge again.
func _update_glyph_side() -> void:
	var xf := get_global_transform_with_canvas()
	var vw := get_viewport_rect().size.x
	var l := (xf * Vector2(GLYPH_L_SPAN.x, 0.0)).x
	var r := (xf * Vector2(GLYPH_R_SPAN.y, 0.0)).x
	var want := glyph_right
	if not glyph_right and l < EDGE_PAD and r <= vw - EDGE_PAD:
		want = true
	elif glyph_right and (l >= EDGE_PAD + EDGE_HYST or r > vw - EDGE_PAD):
		want = false
	if want != glyph_right:
		glyph_right = want
		queue_redraw()


func _draw() -> void:
	if not _shown:
		return
	# Cloud: bottom-left tail puffs point down toward his head.
	var o := Vector2(-W * 0.5 + 20.0, -H)
	if _cloud != null:
		draw_texture(_cloud, o)
	var c := o + Vector2(75, 58)
	if _icon != null:
		draw_texture_rect(_icon, Rect2(c - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), false)
	if _ring >= 0.0:
		draw_arc(c, RING_R, 0.0, TAU, 40, RING_BG, RING_W)
		var frac := clampf(_ring, 0.0, 1.0)
		if frac > 0.0:
			draw_arc(c, RING_R, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, RING_COL, RING_W)
	# Awareness glyph (left of the cloud; right of it near the left screen edge) + ear pips under it.
	var gp := o + (Vector2(W + 6.0, 30.0) if glyph_right else Vector2(-GLYPH - 6.0, 30.0))
	draw_texture_rect(_dot, Rect2(gp - Vector2(6, 6), Vector2(GLYPH + 12, GLYPH + 12)), false, Color("#FFFFFF", 0.92))
	if _glyph != null:
		draw_texture_rect(_glyph, Rect2(gp, Vector2(GLYPH, GLYPH)), false)
	for i in 3:
		var pc := gp + Vector2(2.0 + float(i) * 16.0, GLYPH + 10.0)
		var col := PIP_COL if i < _pips else Color("#FFFFFF", 0.35)
		draw_texture_rect(_dot, Rect2(pc - Vector2(1, 1), Vector2(PIP - 6.0, PIP - 6.0)), false, ViewKit.INK)
		draw_texture_rect(_dot, Rect2(pc + Vector2(1.5, 1.5), Vector2(PIP - 11.0, PIP - 11.0)), false, col)
	if _bar != "":
		var br := Rect2(o + Vector2(15, H - 6.0), Vector2(120, 14))
		draw_rect(br.grow(3.0), ViewKit.INK)
		draw_rect(br, Color("#FFFFFF"))
		var fill := Color("#8FB8F0") if _bar == "sleep" else Color("#7FD6C8")
		draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(_bar_pct, 0.0, 1.0), br.size.y)), fill)
