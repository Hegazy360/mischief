## ApplauseMeter — the TRANSIENT Applause pill (REDESIGN_3D §2.2): centred at (W/2−230, T+24),
## 460 × 104, shown only for 2.5 s after any Applause change (and while a Running Gag is live — the
## Hud decides): a 72 px dial with a sprung needle (0–100 over 240°, the ENCORE zone to 150),
## "APPLAUSE" 36 px, the number 60 px (counts up over 0.6 s), and the delta "+35" (56 px) stamped
## just OUTSIDE the pill. On a catch the three 44 px tomatoes replace the label for 2.5 s.
## Tap → `meter_tap()` (opens the Script). Strings are rebuilt only when a shown number changes.
class_name ApplauseMeter
extends TouchWidget

signal meter_tap()

const W := 460.0
const H_HIT := 104.0
const H_VIS := 104.0
const DIAL := 72.0
const ENCORE_AT := 100
const DISPLAY_CAP := 150
## Needle sweep: 0 at −120°, 100 at +120°, 150 at +150° (from straight up).
const SWEEP_DEG := 120.0
const ENCORE_DEG := 30.0
const SPRING_K := 140.0
const SPRING_C := 11.0
const COUNT_S := 0.6
const DELTA_MS := 2500
const TOMATO_MS := 2500
const FILL := Color(0.106, 0.137, 0.251, 0.78)

var applause: int = 0
var lines_done: int = 0
var lines_total: int = 0

var _shown: float = 0.0
var _shown_int: int = 0
var _num_text: String = "0"
var _label: String = "APPLAUSE"
var _needle: float = 0.0
var _needle_v: float = 0.0
var _bump_ms: int = -100000
var _encore_ms: int = -100000
var _delta: int = 0
var _delta_text: String = ""
var _delta_ms: int = -100000
var _tomato_ms: int = -100000
var _rate: float = 24.0
var _tomatoes: TomatoRow = null
var _star := PackedVector2Array()
var _encore_text: String = "ENCORE!"
var _script_text: String = ""


func _init() -> void:
	super()
	size = Vector2(W, H_HIT)
	custom_minimum_size = size
	_star.resize(10)
	_needle = _angle_for(0)
	_tomatoes = TomatoRow.new()
	_tomatoes.name = "Tomatoes"
	_tomatoes.visible = false
	add_child(_tomatoes)


func _ready() -> void:
	_encore_text = UiStrings.t("hud.encore")
	_label = UiStrings.t("hud.applause") if UiStrings.has("hud.applause") else "APPLAUSE"
	_tomatoes.position = Vector2(DIAL + 34.0, (H_HIT - TomatoRow.SIZE_PX) * 0.5)
	set_process(false)


## Update the shown values. A rise stamps "+n" beside the pill; a used tomato shows the row.
func set_values(p_applause: int, p_done: int, p_total: int, p_tom_left: int, p_tom_max: int) -> void:
	if p_applause != applause:
		var now := UiKit.now_ms()
		if p_applause > applause:
			_bump_ms = now
			# a rise inside a running stamp adds to it ("+10" then "+25" → "+35")
			_delta = (_delta if now - _delta_ms < DELTA_MS else 0) + (p_applause - applause)
			_delta_text = "+%d" % _delta
			_delta_ms = now
		if applause <= ENCORE_AT and p_applause > ENCORE_AT:
			_encore_ms = now
		applause = p_applause
		_rate = maxf(24.0, absf(float(applause) - _shown) / COUNT_S)
		set_process(true)
	if p_done != lines_done or p_total != lines_total:
		lines_done = p_done
		lines_total = p_total
		_script_text = "%d/%d" % [lines_done, lines_total]
	var had_left := _tomatoes.left_count
	_tomatoes.set_counts(p_tom_left, p_tom_max)
	_tomatoes.visible = false
	if p_tom_max > 0 and had_left >= 0 and p_tom_left < had_left:
		_tomato_ms = UiKit.now_ms()
		set_process(true)
	_tomatoes.visible = tomatoes_showing()
	queue_redraw()


## Jump the count-up and the needle to the target (retry, tests).
func snap() -> void:
	_delta = 0
	_delta_text = ""
	_delta_ms = -100000
	_bump_ms = -100000
	_shown = float(applause)
	_set_shown_int(applause)
	_needle = _angle_for(applause)
	_needle_v = 0.0
	queue_redraw()


## The number currently displayed (tests).
func displayed() -> int:
	return _shown_int


## True while the tomato row replaces the label (2.5 s after a catch).
func tomatoes_showing() -> bool:
	return UiKit.now_ms() - _tomato_ms < TOMATO_MS and _tomatoes.max_count > 0


## The "+n" delta stamp shown now ("" = none).
func delta_text() -> String:
	return _delta_text if UiKit.now_ms() - _delta_ms < DELTA_MS else ""


func _angle_for(v: int) -> float:
	var a := clampi(v, 0, DISPLAY_CAP)
	if a <= ENCORE_AT:
		return deg_to_rad(-SWEEP_DEG + 2.0 * SWEEP_DEG * float(a) / float(ENCORE_AT))
	return deg_to_rad(SWEEP_DEG + ENCORE_DEG * float(a - ENCORE_AT) / float(DISPLAY_CAP - ENCORE_AT))


func _set_shown_int(v: int) -> void:
	if v == _shown_int and _num_text != "":
		return
	_shown_int = v
	_num_text = str(v)


func _touch_up(_pos: Vector2, inside: bool) -> void:
	if inside:
		UiKit.haptic(&"ui")
		meter_tap.emit()


func _process(delta: float) -> void:
	var busy := false
	var target := float(applause)
	if not is_equal_approx(_shown, target):
		_shown = move_toward(_shown, target, _rate * delta)
		_set_shown_int(int(round(_shown)) if absf(_shown - target) > 0.5 else applause)
		busy = true
	var ta := _angle_for(int(round(_shown)))
	var dt := minf(delta, 1.0 / 30.0)
	_needle_v += (ta - _needle) * SPRING_K * dt - _needle_v * SPRING_C * dt
	_needle += _needle_v * dt
	if absf(ta - _needle) > 0.002 or absf(_needle_v) > 0.01:
		busy = true
	var now := UiKit.now_ms()
	if now - _bump_ms < 300 or now - _delta_ms < DELTA_MS or now - _tomato_ms < TOMATO_MS:
		busy = true
	if applause > ENCORE_AT and visible:
		busy = true
	_tomatoes.visible = tomatoes_showing()
	queue_redraw()
	if not busy:
		_needle = ta
		set_process(false)


func _draw() -> void:
	var now := UiKit.now_ms()
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	draw_set_transform(Vector2(W * 0.5, H_HIT * 0.5), 0.0, Vector2(k, k))
	var o := Vector2(-W * 0.5, -H_HIT * 0.5)
	var pill := Rect2(o, Vector2(W, H_VIS))
	var encore := applause > ENCORE_AT
	UiShapes.begin()
	UiShapes.rrect(Rect2(pill.position + Vector2(0, 4), pill.size), H_VIS * 0.5, Color(0, 0, 0, 0.18))
	UiShapes.rrect(pill, H_VIS * 0.5, FILL)
	# dial
	var dc := o + Vector2(16.0 + DIAL * 0.5, H_HIT * 0.5)
	UiShapes.circle(dc, DIAL * 0.5, UiKit.NAVY)
	UiShapes.circle(dc, DIAL * 0.5 - 4.0, UiKit.CREAM)
	var r_arc := DIAL * 0.5 - 12.0
	var a0 := -PI * 0.5 - deg_to_rad(SWEEP_DEG)
	var a1 := -PI * 0.5 + deg_to_rad(SWEEP_DEG)
	UiShapes.arc(dc, r_arc, a0, a0 + (a1 - a0) * 0.34, 8.0, UiKit.CHERRY, 12)
	UiShapes.arc(dc, r_arc, a0 + (a1 - a0) * 0.34, a0 + (a1 - a0) * 0.67, 8.0, UiKit.YELLOW, 12)
	UiShapes.arc(dc, r_arc, a0 + (a1 - a0) * 0.67, a1, 8.0, UiKit.GREEN, 12)
	UiShapes.arc(dc, r_arc, a1, a1 + deg_to_rad(ENCORE_DEG), 8.0, UiKit.GOLD if not encore else UiKit.GOLD_LIGHT, 6)
	var nd := Vector2(sin(_needle), -cos(_needle))
	UiShapes.line(dc - nd * 5.0, dc + nd * (DIAL * 0.5 - 9.0), UiKit.NAVY, 5.0)
	UiShapes.circle(dc, 7.0, UiKit.NAVY)
	UiShapes.circle(dc, 3.5, UiKit.BRASS_LIGHT)
	UiShapes.flush(self)
	var f := UiKit.display_font()
	# the label (or the tomatoes after a catch)
	if not tomatoes_showing():
		UiKit.draw_text(self, f, o + Vector2(16.0 + DIAL + 18.0, H_HIT * 0.5 + 13.0), _label, 36, UiKit.CREAM, 0)
	# the number, right-aligned in the pill, bumping on a rise
	var nb := 1.0
	var bt := float(now - _bump_ms) / 300.0
	if bt >= 0.0 and bt < 1.0 and not UiKit.reduce_motion():
		nb = 1.0 + 0.22 * sin(bt * PI)
	var nw := f.get_string_size(_num_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 60).x
	var nc := o + Vector2(W - 32.0 - nw * 0.5, H_HIT * 0.5)
	draw_set_transform(Vector2(W * 0.5, H_HIT * 0.5) + nc * k, 0.0, Vector2(k * nb, k * nb))
	UiKit.draw_text_centered(self, f, Vector2.ZERO, _num_text, 60, UiKit.GOLD_LIGHT if encore else UiKit.WHITE, 10)
	# the "+35" stamp just outside the pill (1.4 → 1.0 in, fades out)
	var dtx := delta_text()
	if dtx != "":
		var t := float(now - _delta_ms) / float(DELTA_MS)
		var a := clampf((1.0 - t) * 4.0, 0.0, 1.0)
		var sc := 1.0 if UiKit.reduce_motion() else 1.4 - 0.4 * minf(1.0, t * 10.0)
		draw_set_transform(Vector2(W * 0.5, H_HIT * 0.5) + Vector2(W * 0.5 + 64.0, 0.0) * k, -0.08, Vector2(sc * k, sc * k))
		UiKit.draw_text_centered(self, f, Vector2.ZERO, dtx, 56, Color(UiKit.GOLD_LIGHT, a), 12, Color(UiKit.NAVY, a))
	if encore:
		draw_set_transform(Vector2(W * 0.5, H_HIT * 0.5), 0.0, Vector2(k, k))
		_draw_sparkles(now, o)
	draw_set_transform(Vector2.ZERO)


func _draw_sparkles(now: int, o: Vector2) -> void:
	if UiKit.reduce_flash():
		return
	var t := float(now) * 0.001
	UiShapes.begin()
	for i in 5:
		var ph := t * 1.6 + float(i) * 1.257
		var s := 0.5 + 0.5 * sin(ph * 2.0)
		var x := o.x + 90.0 + fmod(float(i) * 83.0 + t * 30.0, W - 120.0)
		var y := o.y + (6.0 if i % 2 == 0 else H_HIT - 6.0)
		UiKit.star_points(_star, Vector2(x, y), 5.0 + 7.0 * s, 2.5 + 2.5 * s, ph)
		UiShapes.poly(_star, Color(UiKit.GOLD_LIGHT, 0.5 + 0.5 * s))
	UiShapes.flush(self)
	var et := float(now - _encore_ms) / 1400.0
	if et >= 0.0 and et < 1.0:
		var a := clampf((1.0 - et) * 3.0, 0.0, 1.0)
		var sc := 1.6 - 0.6 * minf(1.0, et * 6.0)
		draw_set_transform(Vector2(W * 0.5, H_HIT + 30.0), -0.12, Vector2(sc, sc))
		var f := UiKit.display_font()
		var tw := f.get_string_size(_encore_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
		UiKit.draw_chunky_rect(self, Rect2(-tw * 0.5 - 20.0, -34.0, tw + 40.0, 68.0), 18.0, Color(UiKit.CURTAIN, a),
			Color(UiKit.CURTAIN_SHADE, a), 5.0, 6.0)
		UiKit.draw_text_centered(self, f, Vector2(0, -3), _encore_text, 48, Color(UiKit.GOLD_LIGHT, a), 10,
			Color(UiKit.NAVY, a))
