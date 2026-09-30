## ThoughtCloud — Hush's thought at a rig point (REDESIGN_3D §4.1, V1): a 180 × 144 cloud with a
## 124 px pictogram of the payoff she imagines, beside her head on the side away from the prop, its
## tail bubbles toward her head. It is the one loud thing of V1 (with the LIVE button). Pops in over
## 0.15 s. The node's position is the cloud's centre.
class_name ThoughtCloud
extends Node2D

const W := 180.0
const H := 144.0
const ICON := 124.0
const POP_S := 0.15

var pict: Texture2D = null
## Direction from the cloud centre to her head (the tail).
var tail_dir: Vector2 = Vector2.DOWN
var k: float = 1.0

var _pop: float = 0.0
var _shown: bool = false


## Show `tex` (null hides). Redraws only on change.
func set_data(tex: Texture2D, p_tail: Vector2, p_k: float) -> void:
	var on := tex != null
	if on and not _shown:
		_pop = 0.0
		set_process(true)
	_shown = on
	visible = on
	if tex == pict and p_tail.is_equal_approx(tail_dir) and is_equal_approx(p_k, k):
		return
	pict = tex
	tail_dir = p_tail
	k = p_k
	queue_redraw()


func box_size() -> Vector2:
	return Vector2(W, H) * k


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_pop = minf(1.0, _pop + delta / POP_S)
	queue_redraw()
	if _pop >= 1.0:
		set_process(false)


func _draw() -> void:
	if pict == null:
		return
	var p := 1.0 if UiKit.reduce_motion() else (0.6 + 0.4 * _pop + 0.12 * sin(_pop * PI))
	var s := k * p
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	UiShapes.begin()
	PreviewCloud.cloud(Vector2.ZERO, W, H, 1.0, tail_dir)
	UiShapes.flush(self)
	UiKit.draw_icon(self, pict, Rect2(-ICON * 0.5, -ICON * 0.5 - 6.0, ICON, ICON))
	draw_set_transform(Vector2.ZERO)
