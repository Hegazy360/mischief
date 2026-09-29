## ClarenceButton — the left-thumb squeak / ⏩ button (GDD §3.3, TECH §6.4).
##
## 168 px hit, 128 px visual, directly above the tray's left end. Modes (HudModel.ClarenceMode):
##   SQUEAK  a mini Clarence that squashes on press. Touch-up < HOLD_MS = squeak; a hold ≥
##           HOLD_MS emits `clarence_hold()` (start the wheeze) and the lift ends it.
##   FF      ⏩ while Hush is hidden: hold = world ×3 (clarence_down … clarence_up).
## A press that begins within SUPPRESS_MS of an action-button press is ignored entirely
## (two-thumb slips): the Hud writes `last_action_down_ms`.
## An 8 px lure ring around the button shows lure readiness and greys out with lure fatigue.
## Signals: clarence_down(), clarence_hold(), clarence_up(held_ms).
class_name ClarenceButton
extends TouchWidget

signal clarence_down()
## Emitted once when a press reaches HOLD_MS (SQUEAK mode: start the wheeze).
signal clarence_hold()
signal clarence_up(held_ms: int)

const HIT := 168.0
const VISUAL := 128.0
const LURE_W := 8.0
const HOLD_MS := 500
const SUPPRESS_MS := 150

const M := HudModel.ClarenceMode
## art-hush's Clarence prop states (soft): the upright "squeezed" pose (squashed by a transform on
## press), "stretched" on the wheeze. Falls back to res://art/ui/clarence.svg.
const ART_SQUEEZED := "res://art/chars/hush/clarence_squeezed.svg"
const ART_STRETCHED := "res://art/chars/hush/clarence_stretched.svg"

var mode: int = M.SQUEAK
var lure_grey: bool = false
## Real-time ms of the latest action-button touch-down (written by the Hud).
var last_action_down_ms: int = -100000
## Presses dropped by the two-thumb rule (tests).
var suppressed_count: int = 0

var _held_fired: bool = false
var _squash: float = 0.0        # 0..1 press squash
var _boing_ms: int = -100000
var _tex_chicken: Texture2D = null
var _tex_squeezed: Texture2D = null
var _tex_stretched: Texture2D = null
var _tex_ff: Texture2D = null
var _ff_text: String = "×3"


func _init() -> void:
	super()
	hit_circle = true
	size = Vector2(HIT, HIT)
	custom_minimum_size = size


func _ready() -> void:
	# at rest the upright "squeezed" pose reads best at chip size; the squash is a transform
	_tex_chicken = UiIcons.texture(ART_SQUEEZED)
	_tex_squeezed = _tex_chicken
	_tex_stretched = UiIcons.texture(ART_STRETCHED)
	if _tex_chicken == null:
		_tex_chicken = UiIcons.get_icon(&"clarence")
	_tex_ff = UiIcons.get_icon(&"ff")
	_ff_text = UiStrings.t("hud.ff")
	set_process(false)


## Mode SQUEAK / FF (a press in progress keeps its mode's semantics until lifted).
func set_mode(m: int) -> void:
	if m == mode:
		return
	mode = m
	queue_redraw()


func set_lure_grey(on: bool) -> void:
	if on == lure_grey:
		return
	lure_grey = on
	queue_redraw()


## Check the hold threshold (called every frame while pressed; public for tests).
func tick() -> void:
	if is_pressed and not _held_fired and UiKit.now_ms() - down_ms >= HOLD_MS:
		_held_fired = true
		clarence_hold.emit()


func _touch_down(_pos: Vector2) -> bool:
	var now := UiKit.now_ms()
	if now - last_action_down_ms < SUPPRESS_MS:
		suppressed_count += 1
		return false
	_held_fired = false
	UiKit.haptic(&"tap")
	clarence_down.emit()
	set_process(true)
	return true


func _touch_up(_pos: Vector2, _inside: bool) -> void:
	var held := UiKit.now_ms() - down_ms
	_boing_ms = UiKit.now_ms()
	clarence_up.emit(held)


func _touch_cancel() -> void:
	clarence_up.emit(UiKit.now_ms() - down_ms)


func _process(delta: float) -> void:
	tick()
	var target := 1.0 if is_pressed else 0.0
	_squash = move_toward(_squash, target, delta / 0.06)
	queue_redraw()
	if not is_pressed and _squash <= 0.0 and UiKit.now_ms() - _boing_ms > 300 and mode != M.FF:
		set_process(false)


func _draw() -> void:
	var c := size * 0.5
	var r := VISUAL * 0.5
	# lure ring (outside the visual, inside the hit circle)
	var lr := r + 12.0
	draw_arc(c, lr, 0.0, TAU, 64, UiKit.NAVY, LURE_W + 6.0, true)
	draw_arc(c, lr, 0.0, TAU, 64, UiKit.GREY if lure_grey else UiKit.YELLOW, LURE_W, true)
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	draw_set_transform(c, 0.0, Vector2(k, k))
	draw_circle(Vector2(0, 6), r, Color(UiKit.NAVY, 0.35))
	if mode == M.FF:
		var f := UiKit.PLUM if not is_pressed else Color("#46325F")
		UiKit.draw_disc(self, Vector2.ZERO, r, f, Color("#1A1226"))
		var wob := 0.0
		if is_pressed and not UiKit.reduce_motion():
			wob = 6.0 * sin(float(UiKit.now_ms()) * 0.03)
		UiKit.draw_icon(self, _tex_ff, Rect2(-40 + wob, -48, 80, 80))
		UiKit.draw_text_centered(self, UiKit.display_font(), Vector2(0, 38), _ff_text, UiKit.SIZE_MIN, UiKit.CREAM, 8)
	else:
		var fill := UiKit.CREAM if not is_pressed else UiKit.pressed(UiKit.CREAM)
		UiKit.draw_disc(self, Vector2.ZERO, r, fill, UiKit.CREAM_SHADE)
		# squash on press, a springy boing after the lift
		var sx := 1.0 + 0.18 * _squash
		var sy := 1.0 - 0.24 * _squash
		var bt := float(UiKit.now_ms() - _boing_ms) / 300.0
		if bt >= 0.0 and bt < 1.0 and not UiKit.reduce_motion():
			var b := sin(bt * PI * 2.0) * (1.0 - bt) * 0.18
			sx -= b
			sy += b
		var tex := _tex_chicken
		if is_pressed:
			tex = _tex_stretched if (_held_fired and _tex_stretched != null) else _tex_squeezed
			if tex == null:
				tex = _tex_chicken
		draw_set_transform(c + Vector2(0, 72.0 * k), 0.0, Vector2(k * sx, k * sy))
		UiKit.draw_icon(self, tex, Rect2(-75, -152, 150, 150))
	draw_set_transform(Vector2.ZERO)
