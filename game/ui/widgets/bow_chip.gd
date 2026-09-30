## BowChip — "Take a Bow ▶" (REDESIGN_3D §2.2): after ★ (every required line) a 320 × 112 chip in the
## top-right corner (W−S−344, T+24), slid under the Bellows window (T+273) while that is open; the
## front door glows cream in the world meanwhile (r3d-view3d). Tap → `tapped` → Hud.bow_tap. It
## breathes gently (1.0 ↔ 1.04 at 1 Hz) so it is found, never loud.
class_name BowChip
extends TouchWidget

signal tapped()

const W := 320.0
const H := 112.0
const VIS_H := 96.0

var _text: String = "Take a Bow ▶"
var _rose: Texture2D = null
var _show_ms: int = -100000


func _init() -> void:
	super()
	size = Vector2(W, H)
	custom_minimum_size = size
	visible = false


func _ready() -> void:
	_text = UiStrings.t("hud.bow") if UiStrings.has("hud.bow") else _text
	_rose = UiIcons.get_icon(&"rose")


## Show / hide (a pop on show).
func set_shown(on: bool) -> void:
	if on == visible:
		return
	visible = on
	if on:
		_show_ms = UiKit.now_ms()
	set_process(on)


func _touch_up(_pos: Vector2, inside: bool) -> void:
	if inside:
		UiKit.haptic(&"ui")
		tapped.emit()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var now := UiKit.now_ms()
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	if not UiKit.reduce_motion():
		var st := float(now - _show_ms) / 220.0
		if st >= 0.0 and st < 1.0:
			k *= 0.7 + 0.3 * st + 0.12 * sin(st * PI)
		else:
			k *= 1.0 + 0.04 * (0.5 + 0.5 * sin(float(now) * 0.001 * TAU))
	draw_set_transform(size * 0.5, 0.0, Vector2(k, k))
	var r := Rect2(-W * 0.5, -VIS_H * 0.5, W, VIS_H)
	UiKit.draw_chunky_rect(self, r, VIS_H * 0.5, UiKit.CHERRY, UiKit.CHERRY_SHADE, UiKit.BUTTON_OUTLINE, 10.0)
	UiKit.draw_icon(self, _rose, Rect2(r.position + Vector2(18, 16), Vector2(60, 60)))
	UiKit.draw_text_centered(self, UiKit.display_font(), Vector2(34, -4), _text, UiKit.SIZE_PLAY, UiKit.CREAM, 10)
	draw_set_transform(Vector2.ZERO)
