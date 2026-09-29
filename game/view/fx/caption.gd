## FxCaption — a pooled pun caption (GDD §3.8: 88 px Lilita One, 6 px navy outline, stamp-in
## 1.6 → 1.0 over 4 frames, on screen 1.2 s) on a starburst plate, anchored in world space
## by his head and kept at a constant screen size (`unit` = 1 / camera zoom). Animates in
## REAL time so it pops even during a hit-stop freeze. Captions are on visibility layer 1 so
## an off-screen payoff shown in the Gag-Cam PiP still carries its pun.
class_name FxCaption
extends Node2D

const STAMP_IN_S := 4.0 / 60.0
const FADE_S := 0.2
## Seconds on screen (GDD §3.8).
const LIFE_S := 1.2
const FILL := Color("#FFFFFF")
const SHADOW := Color(0.106, 0.137, 0.251, 0.55)
## The head under a caption's anchor (world px, relative to the anchor).
const HEAD_ZONE := Rect2(-130.0, 0.0, 260.0, 230.0)
## Screen px kept clear between a caption and a HUD rect (× unit in world).
const AVOID_GAP := 16.0

var active: bool = false
var text: String = ""
var font_size: int = 88
var outline_px: int = 12
var life: float = LIFE_S
var plate: Texture2D = null
var fill: Color = FILL
var ink: Color = ViewKit.INK
var tilt: float = -0.05
var from_scale: float = 1.6
var reduce_motion: bool = false
var age: float = 0.0
## Optional node the caption rides on (the victim travels during his reaction).
var follow: Node2D = null
var follow_offset: Vector2 = Vector2.ZERO
## Keep inside this world rect every frame (FxLayer sets it for main-view captions).
var keep_in: Rect2 = Rect2()
## World rects the caption must never overlap (the HUD's top band — meter ∪ banner — and the PiP
## while it shows, converted to world space by FxLayer every frame; s2-fix G #2). Empty = none.
var avoid: Array[Rect2] = []
## The zone under the anchor the caption was placed above (his head), relative to the anchor in
## world px: when clearing `avoid` would push the caption onto it, the caption moves beside it.
var head_zone: Rect2 = HEAD_ZONE
var _font: Font = null
var _anchor := Vector2.ZERO
var _w := 0.0
var _unit := 1.0


func _init() -> void:
	visible = false
	z_index = 40


func _ready() -> void:
	_font = ViewKit.display_font()


## Show `txt` at `world_pos` (the anchor = bottom centre of the text).
func start(txt: String, world_pos: Vector2, size: int = 88, with_plate: bool = true) -> void:
	if _font == null:
		_font = ViewKit.display_font()
	text = txt
	font_size = size
	outline_px = maxi(8, int(round(size * 0.14)))
	position = world_pos
	_anchor = world_pos
	age = 0.0
	life = LIFE_S
	active = true
	visible = true
	plate = FxArt.sprite("caption_burst") if with_plate else null
	_w = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	queue_redraw()


func stop() -> void:
	active = false
	visible = false
	follow = null
	keep_in = Rect2()
	avoid = []


## Fade out now: a newer caption takes the spot.
func retire() -> void:
	if active and age < life - FADE_S:
		life = age + FADE_S


## Ride on `node` at `offset` (world px) until the caption ends.
func ride(node: Node2D, offset: Vector2) -> void:
	follow = node
	follow_offset = offset


## What `_draw` covers (plate + outlined text + shadow), in local px around the anchor, unscaled.
func local_rect() -> Rect2:
	if _font == null:
		return Rect2(-_w * 0.5, -float(font_size), _w, float(font_size))
	var asc := _font.get_ascent(font_size)
	var desc := _font.get_descent(font_size)
	var base := Vector2(-_w * 0.5, -font_size * 0.18)
	var o := float(outline_px)
	var r := Rect2(base.x - o, base.y - asc - o, _w + 2.0 * o + 4.0, asc + desc + 2.0 * o + 7.0)
	if plate != null:
		var pw := _w + 150.0
		var ph := font_size * 1.85
		r = r.merge(Rect2(-pw * 0.5, base.y - asc * 0.5 - ph * 0.5 + 4.0, pw, ph))
	# the tilt lifts one end: grow by the rotated half-width
	var lift := absf(sin(tilt)) * r.size.x * 0.5
	return r.grow_individual(0.0, lift, 0.0, lift)


## local_rect() in world px relative to the anchor at world scale `k` (stamp scale × unit).
func world_rect_rel(k: float) -> Rect2:
	var r := local_rect()
	return Rect2(r.position * k, r.size * k)


## Pure placement (s2-fix G #2): the anchor `p` moved so the caption (`rel`: its rect relative to
## the anchor, world px) clears every `avoid` rect by `gap` — pushed below the band it hits — then,
## when that lands it on the head (`head`, relative to the ORIGINAL anchor), beside the head on the
## side with room inside `keep` (empty = unbounded); finally kept above `keep`'s bottom.
static func place(p: Vector2, rel: Rect2, avoid: Array[Rect2], keep: Rect2, head: Rect2, gap: float) -> Vector2:
	var q := p
	for _i in 3:
		var moved := false
		for a in avoid:
			if Rect2(q + rel.position, rel.size).intersects(a.grow(gap)):
				q.y = a.end.y + gap - rel.position.y
				moved = true
		if not moved:
			break
	var hz := Rect2(p + head.position, head.size)
	if head.size.x > 0.0 and q.y != p.y and Rect2(q + rel.position, rel.size).intersects(hz):
		var left := hz.position.x - gap - rel.end.x
		var right := hz.end.x + gap - rel.position.x
		var room_l := keep.size.x <= 0.0 or left + rel.position.x >= keep.position.x
		var room_r := keep.size.x <= 0.0 or right + rel.end.x <= keep.end.x
		var clear_l := room_l and not _hits(Vector2(left, q.y), rel, avoid, gap)
		var clear_r := room_r and not _hits(Vector2(right, q.y), rel, avoid, gap)
		var centre := keep.get_center().x if keep.size.x > 0.0 else p.x
		if clear_l and (not clear_r or absf(left - centre) <= absf(right - centre)):
			q.x = left
		elif clear_r:
			q.x = right
	# pushed off the bottom of the view: back up as far as the band allows
	if keep.size.y > 0.0 and q.y != p.y and q.y + rel.end.y > keep.end.y:
		var up := maxf(p.y, keep.end.y - rel.end.y)
		if not _hits(Vector2(q.x, up), rel, avoid, gap):
			q.y = up
	return q


static func _hits(q: Vector2, rel: Rect2, avoid: Array[Rect2], gap: float) -> bool:
	var r := Rect2(q + rel.position, rel.size)
	for a in avoid:
		if r.intersects(a.grow(gap)):
			return true
	return false


## Width of the text box in world px at the current unit (for stacking stamps).
func world_width() -> float:
	return (_w + (140.0 if plate != null else 20.0)) * _unit


func tick(dt: float, unit: float) -> void:
	if not active:
		return
	age += dt
	_unit = unit
	if age >= life:
		stop()
		return
	# The anchor (by his head) before any clamping: placement is recomputed from it every frame, so
	# a camera zoom or a ride never accumulates.
	var anchor := follow.global_position + follow_offset if follow != null and is_instance_valid(follow) else _anchor
	position = anchor
	var s := 1.0
	if age < STAMP_IN_S and not reduce_motion:
		s = lerpf(from_scale, 1.0, ViewKit.ease_out_cubic(age / STAMP_IN_S))
	elif age < STAMP_IN_S + 0.12 and not reduce_motion:
		s = 1.0 + 0.04 * sin((age - STAMP_IN_S) / 0.12 * PI)
	if keep_in.size.x > 0.0:
		var hw := (_w * 0.5 + (80.0 if plate != null else 30.0)) * unit
		if keep_in.size.x > hw * 2.0:
			position.x = clampf(position.x, keep_in.position.x + hw, keep_in.end.x - hw)
	if not avoid.is_empty():
		position = FxCaption.place(position, world_rect_rel(s * unit), avoid, keep_in, head_zone, AVOID_GAP * unit)
	scale = Vector2.ONE * s * unit
	rotation = tilt
	var a := 1.0
	if age > life - FADE_S:
		a = clampf((life - age) / FADE_S, 0.0, 1.0)
	modulate.a = a


func _draw() -> void:
	if not active or _font == null:
		return
	var asc := _font.get_ascent(font_size)
	var base := Vector2(-_w * 0.5, -font_size * 0.18)
	if plate != null:
		var pw := _w + 150.0
		var ph := font_size * 1.85
		draw_texture_rect(plate, Rect2(-pw * 0.5, base.y - asc * 0.5 - ph * 0.5 + 4.0, pw, ph), false)
	draw_string_outline(_font, base + Vector2(4, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_px, SHADOW)
	draw_string_outline(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_px, ink)
	draw_string(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)
