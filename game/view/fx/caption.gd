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
var _font: Font = null
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


## Fade out now: a newer caption takes the spot.
func retire() -> void:
	if active and age < life - FADE_S:
		life = age + FADE_S


## Ride on `node` at `offset` (world px) until the caption ends.
func ride(node: Node2D, offset: Vector2) -> void:
	follow = node
	follow_offset = offset


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
	if follow != null and is_instance_valid(follow):
		position = follow.global_position + follow_offset
	if keep_in.size.x > 0.0:
		var hw := (_w * 0.5 + (80.0 if plate != null else 30.0)) * unit
		if keep_in.size.x > hw * 2.0:
			position.x = clampf(position.x, keep_in.position.x + hw, keep_in.end.x - hw)
	var s := 1.0
	if age < STAMP_IN_S and not reduce_motion:
		s = lerpf(from_scale, 1.0, ViewKit.ease_out_cubic(age / STAMP_IN_S))
	elif age < STAMP_IN_S + 0.12 and not reduce_motion:
		s = 1.0 + 0.04 * sin((age - STAMP_IN_S) / 0.12 * PI)
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
