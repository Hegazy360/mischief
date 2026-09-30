## EdgeBubble — the EDGE BADGE (REDESIGN_3D §2.2): where Bellows is while he is off-screen and no
## Bellows window shows (≥ 2 rooms away and not heading here — or, under the `lean` window mode, on
## adjacency-only ticks, index R15). It sits in the 136 × 220 edge zone of the side he is on (x
## S+24…S+160 / W−S−160…W−S−24, y 430–650): his 112 px face (the 3D portrait when
## `res://art3d/chars/bellows/portraits/bellows_<name>.png` exists, else the 2D face), an arrow toward
## him, and his next-activity icon (64 px) under it. No words (icons first). Tap → `pip_tap()` (peek).
##
## Emotes (D1, ruling L1): `set_emote(id)` with id ∈ EMOTES (`sing, hum, smug, laugh, tut, sniff,
## yum, yawn`) swaps the face with a pop and floats a pictogram puff (`puff_<id>.svg`) beside it, on
## the screen-centre side, for as long as the emote is set — what lets an off-screen micro-gag count
## as "seen". `""` (or an unknown id) = his face for his temper tier (`set_tier`).
class_name EdgeBubble
extends TouchWidget

signal pip_tap()

## The badge's hit box (= the edge zone): HIT wide, HIT_H tall.
const HIT := 136.0
const HIT_H := 220.0
const FACE := 112.0
const ICON := 64.0
## The face's centre and the next-activity disc's centre in local px.
const FACE_C := Vector2(68, 62)
const ICON_C := Vector2(68, 172)
## The emote vocabulary (s2-sim §4.1; the same list the content validator accepts).
const EMOTES: PackedStringArray = ["sing", "hum", "smug", "laugh", "tut", "sniff", "yum", "yawn"]
## His face by temper tier (r3d-cast-bellows §4.5 portrait names).
const TIER_FACES: PackedStringArray = ["neutral", "irked", "furious", "livid"]
const PORTRAIT_DIR := "res://art3d/chars/bellows/portraits/"
## The pictogram puff (a cream thought-cloud beside the face; px at scale 1).
const PUFF := 100.0
const POP_MS := 240
const POP_PEAK := 1.2
const PUFF_IN_MS := 160
const PUFF_OUT_MS := 220

var dir: Vector2 = Vector2.RIGHT
var label: String = ""
## The emote playing ("" = none).
var emote: String = ""
var tier: int = 0

var _tex_face: Texture2D = null
var _tex_default: Texture2D = null
var _tex_puff: Texture2D = null
var _tex_next: Texture2D = null
var _emote_ms: int = -100000
var _clear_ms: int = -100000
var _tri := PackedVector2Array()
var _faces: Dictionary = {}


func _init() -> void:
	super()
	_tri.resize(3)
	size = Vector2(HIT, HIT_H)
	custom_minimum_size = size
	visible = false


func _ready() -> void:
	_tex_default = face_for("neutral")
	if emote == "":
		_tex_face = _tex_default
	set_process(false)


## His face `name` (a portrait name or an emote id): the 3D portrait when it exists, else the 2D art.
func face_for(face_name: String) -> Texture2D:
	if _faces.has(face_name):
		return _faces[face_name]
	var p := PORTRAIT_DIR + "bellows_" + face_name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(p) or FileAccess.file_exists(p):
		t = UiIcons.texture(p, 1.0)
	if t == null:
		if EMOTES.has(face_name):
			t = UiIcons.get_icon(StringName("emote_" + face_name))
		elif face_name == "livid" or face_name == "furious":
			t = UiIcons.get_icon(&"bellows_livid")
		else:
			t = UiIcons.get_icon(&"bellows_face")
	_faces[face_name] = t
	return t


## Point toward `d` (normalised); `text` is kept for callers but not drawn (icons first).
func set_target(d: Vector2, text: String) -> void:
	var nd := d.normalized() if d.length_squared() > 0.0 else Vector2.RIGHT
	if nd.is_equal_approx(dir) and text == label:
		return
	dir = nd
	label = text
	queue_redraw()


## His next activity's icon (null = none).
func set_next_icon(tex: Texture2D) -> void:
	if tex == _tex_next:
		return
	_tex_next = tex
	queue_redraw()


## Temper tier 0..3 → his face when no emote plays.
func set_tier(t: int) -> void:
	var nt := clampi(t, 0, TIER_FACES.size() - 1)
	if nt == tier:
		return
	tier = nt
	_tex_default = face_for(TIER_FACES[tier])
	if emote == "":
		_tex_face = _tex_default
	queue_redraw()


## Play emote `id` on the face ("" / unknown = back to the normal face).
func set_emote(id: String) -> void:
	var e := id if EMOTES.has(id) else ""
	if e == emote:
		return
	var now := UiKit.now_ms()
	if e == "":
		_clear_ms = now
		_tex_face = _tex_default if _tex_default != null else face_for("neutral")
	else:
		_emote_ms = now
		_clear_ms = -100000
		_tex_face = face_for(e)
		_tex_puff = UiIcons.get_icon(StringName("puff_" + e))
	emote = e
	set_process(true)
	queue_redraw()


## True while the puff is on screen (an emote is set, or it is still fading out).
func puff_visible() -> bool:
	return emote != "" or UiKit.now_ms() - _clear_ms < PUFF_OUT_MS


## The face texture shown now (tests).
func face_texture() -> Texture2D:
	return _tex_face


func _touch_down(_pos: Vector2) -> bool:
	UiKit.haptic(&"ui")
	pip_tap.emit()
	return true


func _process(_delta: float) -> void:
	queue_redraw()
	if emote == "" and not puff_visible():
		set_process(false)


func _draw() -> void:
	var now := UiKit.now_ms()
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	var pt := float(now - _emote_ms) / float(POP_MS)
	if emote != "" and pt >= 0.0 and pt < 1.0 and not UiKit.reduce_motion():
		k *= 1.0 + (POP_PEAK - 1.0) * sin(pt * PI)
	draw_set_transform(FACE_C, 0.0, Vector2(k, k))
	var r := FACE * 0.5
	# the arrow toward him, then the face disc
	var tip := dir * (r + 18.0)
	var side := Vector2(-dir.y, dir.x) * 18.0
	var base := dir * (r - 8.0)
	_tri[0] = base + side
	_tri[1] = tip
	_tri[2] = base - side
	UiShapes.begin()
	UiShapes.circle(Vector2(0, 4), r, Color(0, 0, 0, 0.2))
	UiShapes.poly(_tri, UiKit.NAVY)
	var fill := UiKit.CREAM if emote == "" else UiKit.GOLD_LIGHT
	UiShapes.circle(Vector2.ZERO, r, UiKit.NAVY)
	UiShapes.circle(Vector2.ZERO, r - 5.0, fill)
	UiShapes.flush(self)
	UiKit.draw_icon(self, _tex_face, Rect2(-r + 7.0, -r + 5.0, FACE - 14.0, FACE - 10.0))
	draw_set_transform(Vector2.ZERO)
	# his next activity under the face
	if _tex_next != null:
		UiShapes.begin()
		UiShapes.circle(ICON_C, ICON * 0.5 + 5.0, UiKit.NAVY)
		UiShapes.circle(ICON_C, ICON * 0.5, UiKit.CREAM)
		UiShapes.flush(self)
		UiKit.draw_icon(self, _tex_next, Rect2(ICON_C - Vector2(ICON, ICON) * 0.36, Vector2(ICON, ICON) * 0.72))
	draw_set_transform(FACE_C, 0.0, Vector2.ONE)
	_draw_puff(now, r)
	draw_set_transform(Vector2.ZERO)


## The pictogram puff: on the screen-centre side of the face, rising and bobbing.
func _draw_puff(now: int, r: float) -> void:
	if _tex_puff == null or not puff_visible():
		return
	var a := 1.0
	if emote != "":
		a = clampf(float(now - _emote_ms) / float(PUFF_IN_MS), 0.0, 1.0)
	else:
		a = 1.0 - clampf(float(now - _clear_ms) / float(PUFF_OUT_MS), 0.0, 1.0)
	if a <= 0.0:
		return
	var sx := puff_side()
	var t := float(now - _emote_ms) * 0.001
	var bob := 0.0 if UiKit.reduce_motion() else sin(t * TAU * 1.4) * 6.0
	var rise := 0.0 if UiKit.reduce_motion() else minf(1.0, t / 0.35) * 14.0
	var ctr := puff_offset(dir, r) + Vector2(0, bob - rise)
	var s := PUFF * (0.6 + 0.4 * a)
	var rr := s * 0.5
	var anchor := Vector2(sx * r * 0.8, -r * 0.2) if not puff_above(dir) else Vector2(r * 0.5, -r * 0.8)
	var t1 := ctr.lerp(anchor, 0.62)
	var t2 := ctr.lerp(anchor, 0.86)
	UiShapes.begin()
	UiShapes.circle(ctr + Vector2(0, 5), rr + 5.0, Color(UiKit.NAVY, 0.3 * a))
	UiShapes.circle(ctr, rr + 5.0, Color(UiKit.NAVY, a))
	UiShapes.circle(ctr, rr, Color(UiKit.CREAM, a))
	UiShapes.circle(t1, 11.0, Color(UiKit.NAVY, a))
	UiShapes.circle(t1, 7.0, Color(UiKit.CREAM, a))
	UiShapes.circle(t2, 7.0, Color(UiKit.NAVY, a))
	UiShapes.circle(t2, 4.0, Color(UiKit.CREAM, a))
	UiShapes.flush(self)
	UiKit.draw_icon(self, _tex_puff, Rect2(ctr - Vector2(rr, rr) * 0.84, Vector2(rr, rr) * 1.68), Color(1, 1, 1, a))


## Which side the puff floats on: −1 = left of the face (the badge sits on the right edge), +1 =
## right.
func puff_side() -> float:
	return -1.0 if dir.x > 0.35 else 1.0


## True when the puff floats ABOVE the face (a mostly-down direction).
static func puff_above(d: Vector2) -> bool:
	var n := d.normalized() if d.length_squared() > 0.0 else Vector2.RIGHT
	return n.y > 0.5 and absf(n.y) > absf(n.x)


## The puff's resting centre relative to the FACE centre for a badge pointing `d` (face radius `r`,
## unscaled px): beside the face toward the screen centre, or above it for a mostly-down direction.
static func puff_offset(d: Vector2, r: float = FACE * 0.5) -> Vector2:
	if puff_above(d):
		return Vector2(r * 0.4, -r - 20.0 - PUFF * 0.5)
	var side := -1.0 if d.normalized().x > 0.35 else 1.0
	return Vector2(side * (r + PUFF * 0.66), -r * 0.35)


## Everything the puff can cover (its cloud + outline, the bob and the rise), relative to the
## FACE centre, unscaled px (layout tests).
static func puff_bounds(d: Vector2) -> Rect2:
	var c := puff_offset(d)
	var rr := PUFF * 0.5 + 5.0
	return Rect2(c.x - rr, c.y - rr - 14.0 - 6.0, rr * 2.0, rr * 2.0 + 14.0 + 12.0)
