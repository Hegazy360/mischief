## PauseButton — always-on piece #1 (REDESIGN_3D §2.1): (S+24, T+24) 144 hit around a 96 px navy disc
## at 62 % with two white 44 px bars. `tapped` → Hud.pause_tap (Android back / iOS edge swipe open the
## same pause panel).
class_name PauseButton
extends HudButton

const DISC := 96.0
const BAR := Vector2(12, 44)
const FILL := Color(0.106, 0.137, 0.251, 0.62)


func _ready() -> void:
	super()
	visual_size = DISC


func _draw() -> void:
	var c := size * 0.5
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0 + 0.06 * sin(_pop * PI)
	draw_set_transform(c, 0.0, Vector2(k, k))
	UiShapes.begin()
	UiShapes.circle(Vector2(0, 3), DISC * 0.5, Color(0, 0, 0, 0.18))
	UiShapes.circle(Vector2.ZERO, DISC * 0.5, FILL if not is_pressed else Color(FILL, 0.8))
	UiShapes.rrect(Rect2(Vector2(-BAR.x - 5.0, -BAR.y * 0.5), BAR), 4.0, UiKit.WHITE)
	UiShapes.rrect(Rect2(Vector2(5.0, -BAR.y * 0.5), BAR), 4.0, UiKit.WHITE)
	UiShapes.flush(self)
	draw_set_transform(Vector2.ZERO)
