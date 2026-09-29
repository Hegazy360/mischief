## EdgeBubble — where Bellows is while the PiP is hidden (GDD §3.7): a 112 px face circle with
## a pointer toward him and a 36 px label ("↑ upstairs", "2 rooms →"), on a 144 px hit box the Hud
## places at the screen edge in `dir` (HudModel.edge_bubble_dir). Tap → `pip_tap()` (peek).
##
## Emotes (D1, ruling L1): `set_emote(id)` with id ∈ EMOTES (`sing, hum, smug, laugh, tut, sniff,
## yum, yawn`) swaps the face for `art/ui/emote_<id>.svg` with a pop and floats a pictogram puff
## (`puff_<id>.svg`: notes, steam, a teacup …; no words) beside the bubble, on the screen-centre
## side, for as long as the emote is set (the model clears it after the micro-gag's `len`). This is
## what lets an off-screen micro-gag count as "seen", so each face must read in half a second.
## `""` (or an unknown id) = his normal scowl; the puff fades out over PUFF_OUT_MS.
class_name EdgeBubble
extends TouchWidget

signal pip_tap()

const HIT := 144.0
const FACE := 112.0
## The emote vocabulary (s2-sim §4.1; the same list the content validator accepts).
const EMOTES: PackedStringArray = ["sing", "hum", "smug", "laugh", "tut", "sniff", "yum", "yawn"]
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

var _tex_face: Texture2D = null
var _tex_default: Texture2D = null
var _tex_puff: Texture2D = null
var _label_w: float = 0.0
var _emote_ms: int = -100000
var _clear_ms: int = -100000
var _tri := PackedVector2Array()


func _init() -> void:
	super()
	_tri.resize(3)
	hit_circle = true
	size = Vector2(HIT, HIT)
	custom_minimum_size = size
	visible = false


func _ready() -> void:
	_tex_default = UiIcons.get_icon(&"bellows_face")
	if emote == "":
		_tex_face = _tex_default
	set_process(false)


## Point toward `d` (normalised) with `text` (only redraws / measures on change).
func set_target(d: Vector2, text: String) -> void:
	var nd := d.normalized() if d.length_squared() > 0.0 else Vector2.RIGHT
	if nd.is_equal_approx(dir) and text == label:
		return
	dir = nd
	if text != label:
		label = text
		_label_w = UiKit.ui_font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_MIN).x
	queue_redraw()


## Play emote `id` on the face ("" / unknown = back to the normal face).
func set_emote(id: String) -> void:
	var e := id if EMOTES.has(id) else ""
	if e == emote:
		return
	var now := UiKit.now_ms()
	if e == "":
		_clear_ms = now
		_tex_face = _tex_default if _tex_default != null else UiIcons.get_icon(&"bellows_face")
	else:
		_emote_ms = now
		_clear_ms = -100000
		_tex_face = UiIcons.get_icon(StringName("emote_" + e))
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
	var c := size * 0.5
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	var pt := float(now - _emote_ms) / float(POP_MS)
	if emote != "" and pt >= 0.0 and pt < 1.0 and not UiKit.reduce_motion():
		k *= 1.0 + (POP_PEAK - 1.0) * sin(pt * PI)
	draw_set_transform(c, 0.0, Vector2(k, k))
	var r := FACE * 0.5
	# pointer toward him
	var tip := dir * (r + 22.0)
	var side := Vector2(-dir.y, dir.x) * 20.0
	var base := dir * (r - 6.0)
	_tri[0] = base + side
	_tri[1] = tip
	_tri[2] = base - side
	draw_colored_polygon(_tri, UiKit.NAVY)
	draw_circle(Vector2(0, 5), r, Color(UiKit.NAVY, 0.35))
	var fill := UiKit.CREAM if emote == "" else UiKit.GOLD_LIGHT
	UiKit.draw_disc(self, Vector2.ZERO, r, fill, UiKit.CREAM_SHADE)
	UiKit.draw_icon(self, _tex_face, Rect2(-r + 8.0, -r + 6.0, FACE - 16.0, FACE - 12.0))
	if label != "":
		var f := UiKit.ui_font()
		var w := _label_w + 28.0
		var ly := r + 8.0 if dir.y <= 0.5 else -r - 60.0
		var lr := Rect2(-w * 0.5, ly, w, 52.0)
		UiKit.draw_chunky_rect(self, lr, 24.0, UiKit.NAVY, UiKit.NAVY, 0.0, 0.0)
		UiKit.draw_text_centered(self, f, lr.get_center(), label, UiKit.SIZE_MIN, UiKit.CREAM, 0)
	draw_set_transform(c, 0.0, Vector2.ONE)
	_draw_puff(now, r)
	draw_set_transform(Vector2.ZERO)


## The pictogram puff: on the screen-centre side of the bubble, above it, rising and bobbing.
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
	# toward the middle of the screen: a bubble on the right edge puffs to its left, level with
	# the face's upper half (clear of the corner buttons above it)
	var sx := puff_side()
	var t := float(now - _emote_ms) * 0.001
	var bob := 0.0 if UiKit.reduce_motion() else sin(t * TAU * 1.4) * 6.0
	var rise := 0.0 if UiKit.reduce_motion() else minf(1.0, t / 0.35) * 14.0
	var ctr := puff_offset(dir, r) + Vector2(0, bob - rise)
	var s := PUFF * (0.6 + 0.4 * a)
	# a cream comic thought-cloud (navy outline, two tail dots toward his face)
	var rr := s * 0.5
	var anchor := Vector2(sx * r * 0.8, -r * 0.2) if not puff_above(dir) else Vector2(r * 0.5, -r * 0.8)
	var t1 := ctr.lerp(anchor, 0.62)
	var t2 := ctr.lerp(anchor, 0.86)
	draw_circle(ctr + Vector2(0, 5), rr + 5.0, Color(UiKit.NAVY, 0.3 * a))
	draw_circle(ctr, rr + 5.0, Color(UiKit.NAVY, a))
	draw_circle(ctr, rr, Color(UiKit.CREAM, a))
	draw_circle(t1, 11.0, Color(UiKit.NAVY, a))
	draw_circle(t1, 7.0, Color(UiKit.CREAM, a))
	draw_circle(t2, 7.0, Color(UiKit.NAVY, a))
	draw_circle(t2, 4.0, Color(UiKit.CREAM, a))
	UiKit.draw_icon(self, _tex_puff, Rect2(ctr - Vector2(rr, rr) * 0.84, Vector2(rr, rr) * 1.68), Color(1, 1, 1, a))


## Which side the puff floats on: −1 = left of the face (the bubble sits on the right edge), +1 =
## right.
func puff_side() -> float:
	return -1.0 if dir.x > 0.35 else 1.0


## True when the puff floats ABOVE the bubble (it sits at the bottom centre, between the thumb
## clusters, its label above it: the puff goes over the label, where nothing is touchable).
static func puff_above(d: Vector2) -> bool:
	var n := d.normalized() if d.length_squared() > 0.0 else Vector2.RIGHT
	return n.y > 0.5 and absf(n.y) > absf(n.x)


## The puff's resting centre relative to the bubble's centre for a bubble pointing `d` (face radius
## `r`, unscaled px): beside the face toward the screen centre, or above the label for a
## bottom-centre bubble.
static func puff_offset(d: Vector2, r: float = FACE * 0.5) -> Vector2:
	if puff_above(d):
		return Vector2(r * 0.4, -r - 64.0 - PUFF * 0.5)
	var side := -1.0 if d.normalized().x > 0.35 else 1.0
	return Vector2(side * (r + PUFF * 0.66), -r * 0.35)


## Everything the puff can cover (its cloud + outline, the bob and the rise), relative to the
## bubble's centre, unscaled px (layout tests).
static func puff_bounds(d: Vector2) -> Rect2:
	var c := puff_offset(d)
	var rr := PUFF * 0.5 + 5.0
	return Rect2(c.x - rr, c.y - rr - 14.0 - 6.0, rr * 2.0, rr * 2.0 + 14.0 + 12.0)
