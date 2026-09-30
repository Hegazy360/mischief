## TagFlight — a landed line's red beret tag flying from the prop's projected tag socket to its
## Script pip (REDESIGN_3D §2.1, §4.1 TRIGGER): 0.6 s on an arc (ease-in-out, a little spin, shrinking
## to the pip's size), then `arrived(line_index)` so the pip fills with a pop. Pooled: `start()`
## reuses the node. Draw: one texture.
class_name TagFlight
extends Node2D

signal arrived(line_index: int)

const DUR_S := 0.6
const SIZE_FROM := 72.0
const SIZE_TO := 34.0
const ARC_PX := 120.0

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var line_index: int = -1
var running: bool = false
var t: float = 0.0
var _tex: Texture2D = null


func _ready() -> void:
	_tex = UiIcons.get_icon(&"stamp_beret")
	visible = false
	set_process(false)


## Fly from `p_from` to `p_to` (screen px) for Script line `p_line`.
func start(p_from: Vector2, p_to: Vector2, p_line: int) -> void:
	from = p_from
	to = p_to
	line_index = p_line
	t = 0.0
	running = true
	visible = true
	position = from
	set_process(true)
	queue_redraw()


## The flight's point at normalised time `u` (pure; tests): an ease-in-out lerp lifted by an arc.
static func point_at(a: Vector2, b: Vector2, u: float) -> Vector2:
	var e := u * u * (3.0 - 2.0 * u)
	return a.lerp(b, e) + Vector2(0.0, -ARC_PX * sin(u * PI))


func _process(delta: float) -> void:
	t += delta
	var u := clampf(t / DUR_S, 0.0, 1.0)
	position = point_at(from, to, u)
	rotation = 0.0 if UiKit.reduce_motion() else sin(u * PI) * 0.6
	queue_redraw()
	if u >= 1.0:
		running = false
		visible = false
		set_process(false)
		arrived.emit(line_index)


func _draw() -> void:
	var u := clampf(t / DUR_S, 0.0, 1.0)
	var s := lerpf(SIZE_FROM, SIZE_TO, u)
	UiKit.draw_icon(self, _tex, Rect2(-s * 0.5, -s * 0.5, s, s))
