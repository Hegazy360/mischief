## HudButton — a round HUD icon button (hit HIT px square, visual VISUAL px disc): the base of
## PauseButton and OverviewButton. Fires `tapped` on touch-up inside (XAG: activate on
## touch-end); sliding off and lifting cancels. Pressed = 0.94 scale + darker shade in the same
## frame as the touch.
class_name HudButton
extends TouchWidget

signal tapped()

var visual_size: float = 112.0
var fill: Color = UiKit.NAVY_SOFT
var shade: Color = UiKit.NAVY
var icon: Texture2D = null
var icon_scale: float = 0.62

var _pop: float = 0.0


func _init() -> void:
	super()
	custom_minimum_size = Vector2(144, 144)
	size = Vector2(144, 144)


## Swap the icon (redraws only on change).
func set_icon(tex: Texture2D) -> void:
	if tex == icon:
		return
	icon = tex
	queue_redraw()


func _touch_up(_pos: Vector2, inside: bool) -> void:
	if inside:
		UiKit.haptic(&"ui")
		_pop = 1.0
		set_process(true)
		tapped.emit()


func _process(delta: float) -> void:
	_pop = maxf(0.0, _pop - delta / 0.16)
	queue_redraw()
	if _pop <= 0.0:
		set_process(false)


func _ready() -> void:
	set_process(false)


func _draw() -> void:
	var c := size * 0.5
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0 + 0.06 * sin(_pop * PI)
	draw_set_transform(c, 0.0, Vector2(k, k))
	var r := visual_size * 0.5
	var f := UiKit.pressed(fill) if is_pressed else fill
	UiShapes.begin()   # shadow + disc: one draw call (s2-fix G #8)
	UiShapes.circle(Vector2(0, 5), r, Color(UiKit.NAVY, 0.35))
	UiKit.draw_disc(self, Vector2.ZERO, r, f, UiKit.pressed(shade) if is_pressed else shade)
	UiShapes.flush(self)
	var e := visual_size * icon_scale
	UiKit.draw_icon(self, icon, Rect2(Vector2(-e, -e) * 0.5, Vector2(e, e)))
	draw_set_transform(Vector2.ZERO)
