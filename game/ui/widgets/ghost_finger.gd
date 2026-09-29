## GhostFinger — the teaching glove (GDD §2.3, §6.4): a white glove that taps or holds over a HUD
## widget (Clarence, the action button, a tray slot …) or a point in the world (a hotspot, moving
## with the camera). Never a touch target. Driven by `Hud.ghost_finger(target, mode)`,
## `Hud.ghost_finger_at(screen_pos, mode)` and `Hud.ghost_finger_follow(fn, mode)`.
##   TAP   the glove bobs down and presses every TAP_CYCLE_S with a white press ripple;
##   HOLD  the glove presses and stays down while a ring fills round the fingertip in `hold_s`
##         (the action button's prep tier: Q 0.8 s, S 1.5 s, B 2.5 s), yellow → green like the
##         real RIG ring, then lifts and repeats.
class_name GhostFinger
extends Control

enum Mode { TAP, HOLD }

const TAP_CYCLE_S := 1.1
## HOLD cycle = approach + hold_s + release.
const HOLD_APPROACH_S := 0.3
const HOLD_RELEASE_S := 0.45
const RING_R := 46.0
const RING_W := 12.0
## How far the tap ripple / HOLD ring reach from the fingertip (the Hud keeps this inside the
## safe area).
const TIP_REACH := 64.0

var mode: int = Mode.TAP
## Seconds the HOLD ring takes to fill (the prep tier of the rig being taught).
var hold_s: float = 1.5
var _tex: Texture2D = null
var _t0: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(120, 150)
	visible = false


func _ready() -> void:
	_tex = UiIcons.get_icon(&"ghost_finger")
	set_process(false)


## Show the glove with its fingertip at `p_tip` (the parent's local px). The animation restarts
## only when the mode changes or the glove was hidden (following a moving target keeps its phase).
func show_at(p_tip: Vector2, p_mode: int, p_hold_s: float = -1.0) -> void:
	if p_mode != mode or not visible:
		_t0 = UiKit.now_ms()
	mode = p_mode
	if p_hold_s > 0.0:
		hold_s = p_hold_s
	position = p_tip - Vector2(size.x * 0.5, size.y)
	visible = true
	set_process(true)


## Hide it.
func stop() -> void:
	visible = false
	set_process(false)


## The fingertip in the parent's local px.
func tip() -> Vector2:
	return position + Vector2(size.x * 0.5, size.y)


## HOLD ring progress 0..1 at `now_ms` (0 outside the press phase; tests).
func ring_frac_at(now_ms: int) -> float:
	if mode != Mode.HOLD:
		return 0.0
	var t := fmod(float(now_ms - _t0) / 1000.0, _hold_cycle())
	if t < HOLD_APPROACH_S:
		return 0.0
	return clampf((t - HOLD_APPROACH_S) / maxf(0.05, hold_s), 0.0, 1.0)


func _hold_cycle() -> float:
	return HOLD_APPROACH_S + hold_s + HOLD_RELEASE_S


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var now := UiKit.now_ms()
	var t := float(now - _t0) / 1000.0
	var y := 0.0
	var press := 0.0
	var fc := Vector2(size.x * 0.5, size.y + 4.0)
	if mode == Mode.TAP:
		var ph := fmod(t, TAP_CYCLE_S) / TAP_CYCLE_S
		y = -26.0 * absf(sin(ph * PI))
		press = 1.0 if ph < 0.12 or ph > 0.94 else 0.0
		if ph < 0.4:
			var rp := ph / 0.4
			draw_arc(fc, 20.0 + 40.0 * rp, 0.0, TAU, 32, Color(1, 1, 1, 0.7 * (1.0 - rp)), 6.0, true)
	else:
		var ct := fmod(t, _hold_cycle())
		var released := ct >= HOLD_APPROACH_S + hold_s
		if ct < HOLD_APPROACH_S:
			y = -26.0 * (1.0 - ct / HOLD_APPROACH_S)
		elif not released:
			press = 1.0
		else:
			y = -26.0 * clampf((ct - HOLD_APPROACH_S - hold_s) / HOLD_RELEASE_S, 0.0, 1.0)
		if press > 0.0 or released:
			var fr := 1.0 if released else ring_frac_at(now)
			draw_arc(fc, RING_R, 0.0, TAU, 48, Color(UiKit.NAVY, 0.55), RING_W + 8.0, true)
			UiKit.draw_ring(self, fc, RING_R, fr, RING_W, UiKit.YELLOW.lerp(UiKit.GREEN, fr))
	if press > 0.0:
		draw_circle(fc, 30.0, Color(1, 1, 1, 0.35))
	UiKit.draw_icon(self, _tex, Rect2(Vector2(0, y), size), Color(1, 1, 1, 0.92))
