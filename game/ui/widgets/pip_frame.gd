## PipFrame — the Bellows-Cam window (GDD §3.7, TECH §5.6): shows PipView's viewport texture
## (`set_texture(tex)`) inside a 6 px border coloured by his temper tier (calm cream, irked pink,
## steaming red, livid beetroot) with the awareness glyph in the bottom-left corner.
## 448 × 252 at (W−S−472, T+24); `set_escalated(true)` grows it to the 704 × 396 Gag-Cam window
## (the Hud moves it; anchored top-right). Pops in / out (0.15 s) with `set_shown(on)`.
## Touch-down → `pip_tap()` (peek at once), touch-up → `pip_release()` (the peek may end).
class_name PipFrame
extends TouchWidget

signal pip_tap()
signal pip_release()

const SIZE_NORMAL := Vector2(448, 252)
const SIZE_ESCALATED := Vector2(704, 396)
const BORDER := 6.0
const INK := 4.0
const GLYPH := 56.0

var texture: Texture2D = null
var tier: int = 0
var glyph_id: String = "specs_off"
var escalated: bool = false
var shown: bool = false

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


## Normal 448 × 252 or the escalated 704 × 396 Gag-Cam window.
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
	UiKit.draw_chunky_rect(self, r.grow(INK), 14.0, Color(UiKit.NAVY, a), Color(UiKit.NAVY, a), 0.0, 0.0)
	UiKit.draw_chunky_rect(self, r, 10.0, Color(col, a), Color(col, a), 0.0, 0.0)
	var inner := r.grow(-BORDER)
	if texture != null:
		draw_texture_rect(texture, inner, false, Color(1, 1, 1, a))
	else:
		draw_rect(inner, Color(UiKit.PLUM, a))
	draw_rect(inner, Color(UiKit.NAVY, a), false, 3.0)
	var gc := inner.position + Vector2(GLYPH * 0.5 + 8.0, inner.size.y - GLYPH * 0.5 - 8.0)
	draw_circle(gc, GLYPH * 0.5 + 6.0, Color(UiKit.NAVY, a))
	draw_circle(gc, GLYPH * 0.5 + 1.0, Color(UiKit.CREAM, a))
	UiKit.draw_icon(self, _glyph_tex, Rect2(gc - Vector2(GLYPH, GLYPH) * 0.42, Vector2(GLYPH, GLYPH) * 0.84),
		Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)
