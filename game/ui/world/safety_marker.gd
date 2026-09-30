## SafetyMarker — the safety-net hiding marker (REDESIGN_3D §4.2 "Hide", V2): a white 88 px disc with
## a blue closed eye on the nearest free hiding spot while he threatens Hush — the ONLY teaching
## allowed in danger. It breathes (1.0 ↔ 1.08 at 1.5 Hz) so the eye finds it. Position = centre.
class_name SafetyMarker
extends Node2D

const D := 88.0
const BLUE := Color("#3A7BD5")

var k: float = 1.0
var _eye: Texture2D = null


func _ready() -> void:
	_eye = UiIcons.get_icon(&"badge_hide")


func set_scale_k(p_k: float) -> void:
	if not is_equal_approx(p_k, k):
		k = p_k
		queue_redraw()


func box_size() -> Vector2:
	return Vector2(D, D) * k * 1.1


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var b := 1.0
	if not UiKit.reduce_motion():
		b = 1.0 + 0.08 * (0.5 + 0.5 * sin(float(UiKit.now_ms()) * 0.001 * TAU * 1.5))
	var s := k * b
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var r := D * 0.5
	UiShapes.begin()
	UiShapes.circle(Vector2(0, 5), r + 3.0, Color(UiKit.NAVY, 0.3))
	UiShapes.circle(Vector2.ZERO, r + 3.0, BLUE)
	UiShapes.circle(Vector2.ZERO, r - 3.0, UiKit.WHITE)
	UiShapes.flush(self)
	UiKit.draw_icon(self, _eye, Rect2(-r * 0.72, -r * 0.72, r * 1.44, r * 1.44))
	draw_set_transform(Vector2.ZERO)
