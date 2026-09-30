## ItemBubble — tonight's item over the container that holds it (REDESIGN_3D §4.1, §4.2 "Pick up"):
## a 116 px cream disc with the item icon and a small pointer toward the container. The node's
## position is the disc's centre.
class_name ItemBubbleView
extends Node2D

const D := 116.0
const ICON := 84.0

var icon: Texture2D = null
var k: float = 1.0
var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func set_data(tex: Texture2D, p_k: float) -> void:
	if tex == icon and is_equal_approx(p_k, k):
		return
	icon = tex
	k = p_k
	queue_redraw()


func box_size() -> Vector2:
	return Vector2(D, D + 16.0) * k


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var r := D * 0.5
	_tri[0] = Vector2(-16, r - 8)
	_tri[1] = Vector2(0, r + 18)
	_tri[2] = Vector2(16, r - 8)
	UiShapes.begin()
	UiShapes.circle(Vector2(0, 6), r, Color(UiKit.NAVY, 0.28))
	UiShapes.poly(_tri, UiKit.NAVY)
	UiShapes.circle(Vector2.ZERO, r, UiKit.NAVY)
	UiShapes.circle(Vector2.ZERO, r - 5.0, UiKit.CREAM_SHADE)
	UiShapes.circle(Vector2(0, -4), r - 9.0, UiKit.CREAM)
	UiShapes.flush(self)
	UiKit.draw_icon(self, icon, Rect2(-ICON * 0.5, -ICON * 0.5 - 2.0, ICON, ICON))
	draw_set_transform(Vector2.ZERO)
