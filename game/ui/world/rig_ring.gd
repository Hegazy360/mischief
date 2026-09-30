## RigRing — the rig progress ring AT THE PROP (REDESIGN_3D §4.1, §4.2 "Rig", W2): radius 118 px,
## a 14 px stroke yellow #F2D23A → green #5CCF6A on an 18 px 35 % black track, centred on the prop's
## ring anchor, filling from 12 o'clock. It pulses at 3 Hz over the last 20 % while held; after a
## release it stays partial (dimmer, no pulse); completion pops it 1.0 → 1.18 → 1.0 and fades.
## Echoed on the action button. The node's position is the ring's centre.
class_name RigRing
extends Node2D

const RADIUS := 118.0
const STROKE := 14.0
const TRACK := 18.0
const YELLOW := Color("#F2D23A")
const GREEN := Color("#5CCF6A")
const PULSE_FROM := 0.8
const DONE_S := 0.35

var frac: float = 0.0
var active: bool = false
var k: float = 1.0

var _done_t: float = -1.0
var _shown: bool = false


## Set the ring (frac 0..1; active = she holds now). Hidden via `visible`.
func set_data(p_frac: float, p_active: bool, p_k: float) -> void:
	var f := clampf(p_frac, 0.0, 1.0)
	if f >= 1.0 and frac < 1.0 and _shown:
		_done_t = 0.0
	_shown = true
	if is_equal_approx(f, frac) and p_active == active and is_equal_approx(p_k, k):
		_update_process()
		return
	frac = f
	active = p_active
	k = p_k
	queue_redraw()
	_update_process()


## Hide (keeps the completion pop running to its end).
func clear() -> void:
	_shown = false
	if _done_t < 0.0:
		visible = false


## The ring's colour at `f` (yellow → green).
static func color_at(f: float) -> Color:
	return YELLOW.lerp(GREEN, clampf(f, 0.0, 1.0))


func _ready() -> void:
	set_process(false)


func _update_process() -> void:
	set_process(_done_t >= 0.0 or (active and frac >= PULSE_FROM and frac < 1.0))


func _process(delta: float) -> void:
	if _done_t >= 0.0:
		_done_t += delta
		if _done_t >= DONE_S:
			_done_t = -1.0
			if not _shown:
				visible = false
	queue_redraw()
	_update_process()


func _draw() -> void:
	var s := k
	var a := 1.0 if active or frac >= 1.0 else 0.7
	if _done_t >= 0.0 and not UiKit.reduce_motion():
		var t := _done_t / DONE_S
		s *= 1.0 + 0.18 * sin(minf(1.0, t * 2.0) * PI)
		a *= 1.0 - maxf(0.0, t * 2.0 - 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var pulse := 0.0
	if active and frac >= PULSE_FROM and frac < 1.0 and not UiKit.reduce_flash():
		pulse = 0.5 + 0.5 * sin(float(UiKit.now_ms()) * 0.001 * TAU * 3.0)
	UiShapes.begin()
	UiShapes.arc(Vector2.ZERO, RADIUS, 0.0, TAU, TRACK, Color(0, 0, 0, 0.35 * a), 72)
	if frac > 0.0:
		var a0 := -PI * 0.5
		var col := color_at(frac).lightened(0.25 * pulse)
		UiShapes.arc(Vector2.ZERO, RADIUS, a0, a0 + TAU * frac, STROKE + 4.0 * pulse, Color(col, a), maxi(8, int(72.0 * frac)))
	UiShapes.flush(self)
	draw_set_transform(Vector2.ZERO)
