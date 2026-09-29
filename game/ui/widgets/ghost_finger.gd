## GhostFinger — the one-time teaching glove (GDD §2.3, §4.10): a white glove that taps or holds
## over a HUD widget (Clarence, the action button, a tray slot …) or a screen point. Never a
## touch target. Driven by `Hud.ghost_finger(target, mode)` from the Director's cues.
class_name GhostFinger
extends Control

enum Mode { TAP, HOLD }

var mode: int = Mode.TAP
var _tex: Texture2D = null
var _t0: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(120, 150)
	visible = false


func _ready() -> void:
	_tex = UiIcons.get_icon(&"ghost_finger")
	set_process(false)


## Show the glove with its fingertip at `screen_point` (the Hud converts to local).
func show_at(tip: Vector2, p_mode: int) -> void:
	mode = p_mode
	position = tip - Vector2(size.x * 0.5, size.y)
	visible = true
	_t0 = UiKit.now_ms()
	set_process(true)


## Hide it.
func stop() -> void:
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := float(UiKit.now_ms() - _t0) / 1000.0
	var y := 0.0
	var press := 0.0
	if mode == Mode.TAP:
		var ph := fmod(t, 1.1) / 1.1
		y = -26.0 * absf(sin(ph * PI))
		press = 1.0 if ph < 0.12 or ph > 0.94 else 0.0
	else:
		var ph := fmod(t, 2.4) / 2.4
		y = -26.0 * clampf(1.0 - ph * 5.0, 0.0, 1.0) if ph < 0.8 else -26.0 * (ph - 0.8) * 5.0
		press = 1.0 if ph >= 0.2 and ph < 0.8 else 0.0
		if press > 0.0:
			var fr := clampf((ph - 0.2) / 0.6, 0.0, 1.0)
			draw_arc(Vector2(size.x * 0.5, size.y + 4.0), 46.0, -PI * 0.5, -PI * 0.5 + TAU * fr, 40,
				Color(UiKit.YELLOW, 0.85), 8.0, true)
	if press > 0.0:
		draw_circle(Vector2(size.x * 0.5, size.y + 4.0), 30.0, Color(1, 1, 1, 0.35))
	UiKit.draw_icon(self, _tex, Rect2(Vector2(0, y), size), Color(1, 1, 1, 0.9))
