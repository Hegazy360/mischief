## FxThoughtBubble — what he'll do next (GDD §3.9, §4.2): a 150 × 130 cloud above his head
## with the next activity icon (88 px) and a 10 px countdown ring that starts ≥ 4 s before
## he leaves; a progress bar for bath / nap. A route change pops the bubble and swaps the icon the same frame.
## Constant screen size; clamped below the HUD band.
## **One thing per head (r3d QA2 Q2-C1):** while his thought shows, the awareness glyph disc and the empty ear-pip
## slots are not drawn (they read as a third small bubble beside the cloud); the squeaks he has heard (1–3 ear pips,
## the squeak verb's feedback) sit as gold beads on the cloud's lower-right rim instead. Only when no thought shows
## does the glyph disc (+ its pips) draw, alone, where the cloud would be. `ring_hidden` drops the countdown ring
## while a prop's preview badge carries it (WorldOverlays: one ring per target); the icon stays.
## `waiting` fades the bubble while the shared placer's one-cloud rule gives the screen to Hush's thought (its own
## alpha, apart from the gag-hold `quiet`).
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
## The cloud's own span (local units); everything the bubble draws stays inside it (the glyph-only state too).
const CLOUD_SPAN := Vector2(-55.0, 103.0)
## The cloud: game/art/fx/thought_bubble.svg's own path in a viewBox widened 150 → 160 (that file clips its right lobe
## at its edge — hidden behind the glyph disc until Q2-C1 removed it), rasterised once at 2× (ViewKit.svg_tex: one
## textured draw, batched like the old sprite).
const CLOUD_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='160' height='130' viewBox='0 0 160 130'><path d='M30 94 A22 22 0 0 1 14 58 A26 26 0 0 1 44 20 A30 30 0 0 1 96 14 A26 26 0 0 1 136 44 A22 22 0 0 1 130 88 A24 24 0 0 1 92 104 A28 28 0 0 1 52 104 A22 22 0 0 1 30 94 Z' fill='#FFFFFF' stroke='#1B2340' stroke-width='5' stroke-linejoin='round' stroke-linecap='round'/><circle cx='22' cy='112' r='8' fill='#FFFFFF' stroke='#1B2340' stroke-width='4'/><circle cx='9' cy='124' r='4.5' fill='#FFFFFF' stroke='#1B2340' stroke-width='3'/></svg>"
## Heard ear pips on the cloud's rim while a thought shows: radius from the icon centre and the angles (rad, screen y
## down: 30° / 52° / 74° below the right-hand horizontal — the lower-right rim, clear of the tail puffs).
const RIM_PIP_R := 62.0
const RIM_PIP_ANG: PackedFloat32Array = [0.52, 0.91, 1.29]
const RIM_PIP := 18.0

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
## Kept for Overlays3D's duck-typed clamp (fix-perf's edge flip): always false since Q2-C1 — the glyph never sits
## beside the cloud any more, so nothing of the bubble reaches past CLOUD_SPAN.
var glyph_right: bool = false
## Q2-C1 / r3d-fix-hud3 R1: true while a preview badge on screen carries his countdown ring (set by WorldOverlays
## every apply): both ring arcs are skipped, the icon stays.
var ring_hidden: bool = false:
	set(v):
		if v != ring_hidden:
			ring_hidden = v
			queue_redraw()
## True while the awareness glyph disc (+ its ear pips) is drawn: only while no thought shows (read-only).
var glyph_shown: bool = false
var _dot: Texture2D = null
var _cloud: Texture2D = null
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
	_dot = FxArt.sprite("dot")
	_cloud = ViewKit.svg_tex("thought_cloud_160", CLOUD_SVG, 2.0)


## Update from the snapshot; `head_top` = world point above his head; `lift` pushes the
## bubble up (the "?" meter needs the space).
func thought_bubble(snap: ViewSnapshot, head_top: Vector2, unit: float, lift: float = 0.0) -> void:
	var b := snap.bellows
	_shown = enabled and b.present and b.state != "CAUGHT_HOLD"
	visible = _shown
	glyph_shown = _shown and snap.bubble_next == ""
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


## The drawn span along x (local units, before `scale`): x = left, y = right. Since Q2-C1 it is the cloud's span
## on either side (`right_side` is kept for old callers): the glyph never sits beside the cloud.
static func local_span(_right_side: bool = false) -> Vector2:
	return CLOUD_SPAN


## The drawn span in screen px (x = left, y = right) as placed now.
func screen_span() -> Vector2:
	var xf := get_global_transform_with_canvas()
	return Vector2((xf * Vector2(CLOUD_SPAN.x, 0.0)).x, (xf * Vector2(CLOUD_SPAN.y, 0.0)).x)


## True while his thought (the next activity) shows: the cloud, its icon and ring. Then the glyph disc and the empty
## ear-pip slots are not drawn (one thing per head, Q2-C1).
func thought_on() -> bool:
	return _shown and _next != ""


func _draw() -> void:
	if not _shown:
		return
	var o := Vector2(-W * 0.5 + 20.0, -H)
	var c := o + Vector2(75, 58)
	if not thought_on():
		_draw_glyph(c - Vector2(GLYPH, GLYPH) * 0.5 - Vector2(0.0, 10.0))
		return
	# Cloud: bottom-left tail puffs point down toward his head.
	if _cloud != null:
		draw_texture(_cloud, o)
	if _icon != null:
		draw_texture_rect(_icon, Rect2(c - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), false)
	if _ring >= 0.0 and not ring_hidden:
		draw_arc(c, RING_R, 0.0, TAU, 40, RING_BG, RING_W)
		var frac := clampf(_ring, 0.0, 1.0)
		if frac > 0.0:
			draw_arc(c, RING_R, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, RING_COL, RING_W)
	# the squeaks he has heard: gold beads on the cloud's lower-right rim (no empty slots, no glyph disc)
	for i in _pips:
		var ang := RIM_PIP_ANG[i]
		var pc := c + Vector2(cos(ang), sin(ang)) * RIM_PIP_R
		draw_texture_rect(_dot, Rect2(pc - Vector2(RIM_PIP, RIM_PIP) * 0.5, Vector2(RIM_PIP, RIM_PIP)), false, ViewKit.INK)
		var inner := RIM_PIP - 7.0
		draw_texture_rect(_dot, Rect2(pc - Vector2(inner, inner) * 0.5, Vector2(inner, inner)), false, PIP_COL)
	if _bar != "":
		var br := Rect2(o + Vector2(15, H - 6.0), Vector2(120, 14))
		draw_rect(br.grow(3.0), ViewKit.INK)
		draw_rect(br, Color("#FFFFFF"))
		var fill := Color("#8FB8F0") if _bar == "sleep" else Color("#7FD6C8")
		draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(_bar_pct, 0.0, 1.0), br.size.y)), fill)


## The awareness glyph disc at `gp` (its top-left) with its 3 ear-pip slots under it — drawn only while no thought
## shows (then it stands alone above his head, where the cloud would be).
func _draw_glyph(gp: Vector2) -> void:
	draw_texture_rect(_dot, Rect2(gp - Vector2(6, 6), Vector2(GLYPH + 12, GLYPH + 12)), false, Color("#FFFFFF", 0.92))
	if _glyph != null:
		draw_texture_rect(_glyph, Rect2(gp, Vector2(GLYPH, GLYPH)), false)
	for i in 3:
		var pc := gp + Vector2(2.0 + float(i) * 16.0, GLYPH + 10.0)
		var col := PIP_COL if i < _pips else Color("#FFFFFF", 0.35)
		draw_texture_rect(_dot, Rect2(pc - Vector2(1, 1), Vector2(PIP - 6.0, PIP - 6.0)), false, ViewKit.INK)
		draw_texture_rect(_dot, Rect2(pc + Vector2(1.5, 1.5), Vector2(PIP - 11.0, PIP - 11.0)), false, col)
