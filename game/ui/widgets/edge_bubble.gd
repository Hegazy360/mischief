## EdgeBubble — where Bellows is while the PiP is hidden (GDD §3.7): a 112 px face circle with
## a pointer toward him and a 36 px label ("↑ upstairs", "2 rooms →"), on a 144 px hit box the Hud
## places at the screen edge in `dir` (HudModel.edge_bubble_dir). Tap → `pip_tap()` (peek).
class_name EdgeBubble
extends TouchWidget

signal pip_tap()

const HIT := 144.0
const FACE := 112.0

var dir: Vector2 = Vector2.RIGHT
var label: String = ""

var _tex_face: Texture2D = null
var _label_w: float = 0.0
var _bob_ms: int = 0


func _init() -> void:
	super()
	hit_circle = true
	size = Vector2(HIT, HIT)
	custom_minimum_size = size
	visible = false


func _ready() -> void:
	_tex_face = UiIcons.get_icon(&"bellows_face")
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


func _touch_down(_pos: Vector2) -> bool:
	UiKit.haptic(&"ui")
	pip_tap.emit()
	return true


func _draw() -> void:
	var c := size * 0.5
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	draw_set_transform(c, 0.0, Vector2(k, k))
	var r := FACE * 0.5
	# pointer toward him
	var tip := dir * (r + 22.0)
	var side := Vector2(-dir.y, dir.x) * 20.0
	var base := dir * (r - 6.0)
	var tri := PackedVector2Array([base + side, tip, base - side])
	draw_colored_polygon(tri, UiKit.NAVY)
	draw_circle(Vector2(0, 5), r, Color(UiKit.NAVY, 0.35))
	UiKit.draw_disc(self, Vector2.ZERO, r, UiKit.CREAM, UiKit.CREAM_SHADE)
	UiKit.draw_icon(self, _tex_face, Rect2(-r + 8.0, -r + 6.0, FACE - 16.0, FACE - 12.0))
	if label != "":
		var f := UiKit.ui_font()
		var w := _label_w + 28.0
		var ly := r + 8.0 if dir.y <= 0.5 else -r - 60.0
		var lr := Rect2(-w * 0.5, ly, w, 52.0)
		UiKit.draw_chunky_rect(self, lr, 24.0, UiKit.NAVY, UiKit.NAVY, 0.0, 0.0)
		UiKit.draw_text_centered(self, f, lr.get_center(), label, UiKit.SIZE_MIN, UiKit.CREAM, 0)
	draw_set_transform(Vector2.ZERO)
