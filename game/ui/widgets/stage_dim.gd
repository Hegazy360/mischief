## StageDim — the house lights going down (FTUE "show me", GDD §6.4 step 3; `Hud.set_dim`): a
## full-screen navy wash over the world and the Stalls, under the HUD widgets, never a touch
## target. An optional **spotlight** (a screen rect, e.g. where the ghost Hush acts out the step)
## stays lit: the wash is four rects around it plus one soft radial-gradient texture inside it,
## so moving the spotlight every frame costs nothing (no allocation, one redraw).
## Fades in over FADE_IN_MS and out over FADE_OUT_MS (instant with Reduce motion).
class_name StageDim
extends Control

const ALPHA := 0.62
const FADE_IN_MS := 220
const FADE_OUT_MS := 180
## Size of the gradient texture (square; stretched to the spotlight rect).
const GRAD_PX := 128

## Dim wanted (the fade runs toward it).
var on: bool = false
## Lit rect (screen px; zero size = no spotlight).
var spotlight: Rect2 = Rect2()

var _t0: int = -100000
var _from: float = 0.0
var _grad: GradientTexture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var g := Gradient.new()
	g.set_color(0, Color(UiKit.NAVY, 0.0))
	g.set_color(1, Color(UiKit.NAVY, ALPHA))
	g.add_point(0.62, Color(UiKit.NAVY, 0.0))
	_grad = GradientTexture2D.new()
	_grad.gradient = g
	_grad.width = GRAD_PX
	_grad.height = GRAD_PX
	_grad.fill = GradientTexture2D.FILL_RADIAL
	_grad.fill_from = Vector2(0.5, 0.5)
	_grad.fill_to = Vector2(1.0, 0.5)


func _ready() -> void:
	set_process(false)


## Dim on / off; `lit` keeps a spotlight clear (Rect2() = none). Cheap to call every frame.
func set_dim(p_on: bool, lit: Rect2 = Rect2()) -> void:
	if not lit.is_equal_approx(spotlight):
		spotlight = lit
		queue_redraw()
	if p_on == on:
		return
	_from = alpha()
	on = p_on
	_t0 = UiKit.now_ms()
	visible = true
	set_process(true)
	queue_redraw()


## The wash's alpha now (0..ALPHA).
func alpha() -> float:
	var target := ALPHA if on else 0.0
	if UiKit.reduce_motion():
		return target
	var dur := FADE_IN_MS if on else FADE_OUT_MS
	var k := clampf(float(UiKit.now_ms() - _t0) / float(dur), 0.0, 1.0)
	return lerpf(_from, target, k)


func _process(_delta: float) -> void:
	var a := alpha()
	queue_redraw()
	if (on and a >= ALPHA) or (not on and a <= 0.0):
		set_process(false)
		if not on:
			visible = false


func _draw() -> void:
	var a := alpha()
	if a <= 0.0:
		return
	var full := Rect2(Vector2.ZERO, size)
	var c := Color(UiKit.NAVY, a)
	if spotlight.size.x <= 1.0 or spotlight.size.y <= 1.0:
		draw_rect(full, c)
		return
	var s := spotlight.intersection(full)
	if s.size.x <= 0.0 or s.size.y <= 0.0:
		draw_rect(full, c)
		return
	# four rects around the spotlight, the soft gradient inside it
	draw_rect(Rect2(0, 0, size.x, s.position.y), c)
	draw_rect(Rect2(0, s.end.y, size.x, size.y - s.end.y), c)
	draw_rect(Rect2(0, s.position.y, s.position.x, s.size.y), c)
	draw_rect(Rect2(s.end.x, s.position.y, size.x - s.end.x, s.size.y), c)
	draw_texture_rect(_grad, spotlight, false, Color(1, 1, 1, a / ALPHA))
