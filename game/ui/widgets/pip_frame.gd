## PipFrame — the Bellows window (REDESIGN_3D §2.2, index §7.9): shows the Bellows window view's
## texture (`set_texture(tex)`, PipView3D) inside a 6 px frame coloured by his temper tier (calm
## cream, irked pink, steaming red, livid beetroot) with his NEXT-activity chip (72 px, with his
## bubble's red countdown ring — `set_next(icon, ring_frac)`) in the lower-left corner (the awareness
## glyph when no next activity is known). 400 × 225 at (W−S−424, T+24); `set_escalated(true)` grows
## it to the 704 × 396 Gag-Cam window (the Hud moves it; anchored top-right). Pops in / out (0.15 s)
## with `set_shown(on)` — shown exactly when the view says so (C8 is r3d-view3d's).
## Touch-down → `pip_tap()` (peek at once), touch-up → `pip_release()` (the peek may end).
class_name PipFrame
extends TouchWidget

signal pip_tap()
signal pip_release()

const SIZE_NORMAL := Vector2(400, 225)
const SIZE_ESCALATED := Vector2(704, 396)
const BORDER := 6.0
const INK := 4.0
const GLYPH := 56.0
const CHIP := 72.0
const RING_RED := Color("#E8413C")

var texture: Texture2D = null
var tier: int = 0
var glyph_id: String = "specs_off"
var escalated: bool = false
var shown: bool = false

var next_icon: Texture2D = null
var ring_frac: float = -1.0
var _glyph_tex: Texture2D = null
var _show_k: float = 0.0
var _tier_ms: int = -100000


func _init() -> void:
	super()
	size = SIZE_NORMAL
	custom_minimum_size = Vector2.ZERO
	visible = false


func _ready() -> void:
	_glyph_tex = UiIcons.glyph(glyph_id)
	set_process(false)


## The PiP SubViewport texture (PipView.get_texture()); null = a dark placeholder.
func set_texture(tex: Texture2D) -> void:
	if tex == texture:
		return
	texture = tex
	queue_redraw()


## Temper tier 0..3 → border colour (a short flash on change).
func set_tier(t: int) -> void:
	if t == tier:
		return
	tier = t
	_tier_ms = UiKit.now_ms()
	set_process(true)
	queue_redraw()


## Awareness glyph id (UiIcons.glyph ids).
func set_glyph(id: String) -> void:
	if id == glyph_id:
		return
	glyph_id = id
	_glyph_tex = UiIcons.glyph(id)
	queue_redraw()


## His next activity's icon (null = the awareness glyph) and the bubble's ring 0..1 (< 0 none).
func set_next(icon: Texture2D, p_ring: float) -> void:
	if icon == next_icon and is_equal_approx(p_ring, ring_frac):
		return
	next_icon = icon
	ring_frac = p_ring
	queue_redraw()


## Normal 400 × 225 or the escalated 704 × 396 Gag-Cam window.
func set_escalated(on: bool) -> void:
	if on == escalated:
		return
	escalated = on
	size = SIZE_ESCALATED if on else SIZE_NORMAL
	queue_redraw()


## Show / hide with a quick pop.
func set_shown(on: bool) -> void:
	if on == shown:
		return
	shown = on
	if on:
		visible = true
	set_process(true)


## The frame size for the current mode.
func frame_size() -> Vector2:
	return SIZE_ESCALATED if escalated else SIZE_NORMAL


func _touch_down(_pos: Vector2) -> bool:
	if not shown:
		return false
	UiKit.haptic(&"ui")
	pip_tap.emit()
	return true


func _touch_up(_pos: Vector2, _inside: bool) -> void:
	pip_release.emit()


func _touch_cancel() -> void:
	pip_release.emit()


func _process(delta: float) -> void:
	_show_k = move_toward(_show_k, 1.0 if shown else 0.0, delta / 0.15)
	if not shown and _show_k <= 0.0:
		visible = false
	queue_redraw()
	if (_show_k >= 1.0 and shown or _show_k <= 0.0 and not shown) and UiKit.now_ms() - _tier_ms > 400:
		set_process(false)


func _draw() -> void:
	var s := size
	var k := (0.85 + 0.15 * _show_k) * (UiKit.PRESS_SCALE if is_pressed else 1.0)
	draw_set_transform(s * 0.5, 0.0, Vector2(k, k))
	var r := Rect2(-s * 0.5, s)
	var col := UiKit.tier_color(tier)
	var ft := float(UiKit.now_ms() - _tier_ms) / 400.0
	if ft >= 0.0 and ft < 1.0 and not UiKit.reduce_flash():
		col = col.lerp(UiKit.WHITE, 0.6 * (1.0 - ft))
	var a := _show_k
	UiShapes.begin()   # the frame: one triangle array (s2-fix G #8)
	UiKit.draw_chunky_rect(self, r.grow(INK), 14.0, Color(UiKit.NAVY, a), Color(UiKit.NAVY, a), 0.0, 0.0)
	UiKit.draw_chunky_rect(self, r, 10.0, Color(col, a), Color(col, a), 0.0, 0.0)
	UiShapes.flush(self)
	var inner := r.grow(-BORDER)
	if texture != null:
		draw_texture_rect(texture, inner, false, Color(1, 1, 1, a))
	else:
		draw_rect(inner, Color(UiKit.PLUM, a))
	draw_rect(inner, Color(UiKit.NAVY, a), false, 3.0)
	# his next-activity chip (lower-left), with the bubble's countdown ring
	var d := CHIP if next_icon != null else GLYPH
	var gc := inner.position + Vector2(d * 0.5 + 10.0, inner.size.y - d * 0.5 - 10.0)
	UiShapes.begin()
	UiShapes.circle(gc, d * 0.5 + 6.0, Color(UiKit.NAVY, a))
	UiShapes.circle(gc, d * 0.5 + 1.0, Color(UiKit.CREAM, a))
	if next_icon != null and ring_frac >= 0.0:
		var a0 := -PI * 0.5
		UiShapes.arc(gc, d * 0.5 + 2.0, a0, a0 + TAU * clampf(ring_frac, 0.0, 1.0), 6.0, Color(RING_RED, a), 40)
	UiShapes.flush(self)
	var tex := next_icon if next_icon != null else _glyph_tex
	UiKit.draw_icon(self, tex, Rect2(gc - Vector2(d, d) * 0.36, Vector2(d, d) * 0.72), Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)
