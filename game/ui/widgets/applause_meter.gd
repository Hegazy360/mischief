## ApplauseMeter — the brass Applause-o-Meter, top centre (GDD §3.8, §6.1).
##
## 600 × 132 visual on a 600 × 144 hit box at y = T+16: a 120 px dial with a sprung needle
## (0–100 over 240°, the ENCORE zone to 150), the Applause number (56 px, counts up), the Script
## counter "3/5" (48 px) and 3 × 44 px tomatoes (TomatoRow; hidden when unlimited). Above 100 the
## plate sparkles ENCORE and the number turns gold. Tap → `meter_tap()` (opens the Script).
## Strings are rebuilt only when a shown number changes (no per-frame allocations).
class_name ApplauseMeter
extends TouchWidget

signal meter_tap()

const W := 600.0
const H_HIT := 144.0
const H_VIS := 132.0
const DIAL := 120.0
const ENCORE_AT := 100
const DISPLAY_CAP := 150
## Needle sweep: 0 at −120°, 100 at +120°, 150 at +150° (from straight up).
const SWEEP_DEG := 120.0
const ENCORE_DEG := 30.0
const SPRING_K := 140.0
const SPRING_C := 11.0

var applause: int = 0
var lines_done: int = 0
var lines_total: int = 0

var _shown: float = 0.0            # counting-up value
var _shown_int: int = 0
var _num_text: String = "0"
var _script_text: String = "0/0"
var _needle: float = 0.0           # radians from straight up
var _needle_v: float = 0.0
var _bump_ms: int = -100000
var _encore_ms: int = -100000
var _tomatoes: TomatoRow = null
var _tex_script: Texture2D = null
var _encore_text: String = "ENCORE!"
var _star := PackedVector2Array()
var _layout_tomatoes: bool = false


func _init() -> void:
	super()
	size = Vector2(W, H_HIT)
	custom_minimum_size = size
	_star.resize(10)
	_needle = _angle_for(0)
	_tomatoes = TomatoRow.new()
	_tomatoes.name = "Tomatoes"
	add_child(_tomatoes)


func _ready() -> void:
	_tex_script = UiIcons.get_icon(&"script")
	_encore_text = UiStrings.t("hud.encore")
	_relayout()
	set_process(false)


## Update the shown values (each redraw / string only when something changed).
func set_values(p_applause: int, p_done: int, p_total: int, p_tom_left: int, p_tom_max: int) -> void:
	if p_applause != applause:
		if p_applause > applause:
			_bump_ms = UiKit.now_ms()
		if applause <= ENCORE_AT and p_applause > ENCORE_AT:
			_encore_ms = UiKit.now_ms()
		applause = p_applause
		set_process(true)
	if p_done != lines_done or p_total != lines_total:
		lines_done = p_done
		lines_total = p_total
		_script_text = "%d/%d" % [lines_done, lines_total]
		queue_redraw()
	var had := _tomatoes.visible
	_tomatoes.set_counts(p_tom_left, p_tom_max)
	if had != _tomatoes.visible or _layout_tomatoes != _tomatoes.visible:
		_relayout()


## Jump the count-up and the needle to the target (retry, tests).
func snap() -> void:
	_shown = float(applause)
	_set_shown_int(applause)
	_needle = _angle_for(applause)
	_needle_v = 0.0
	queue_redraw()


## The number currently displayed (tests).
func displayed() -> int:
	return _shown_int


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


func _relayout() -> void:
	_layout_tomatoes = _tomatoes.visible
	_tomatoes.position = Vector2(W - 20.0 - TomatoRow.width_for(3), (H_HIT - TomatoRow.SIZE_PX) * 0.5 + 2.0)
	queue_redraw()


func _touch_up(_pos: Vector2, inside: bool) -> void:
	if inside:
		UiKit.haptic(&"ui")
		meter_tap.emit()


func _process(delta: float) -> void:
	var busy := false
	var target := float(applause)
	if not is_equal_approx(_shown, target):
		var rate := maxf(24.0, absf(target - _shown) * 3.5)
		_shown = move_toward(_shown, target, rate * delta)
		_set_shown_int(int(round(_shown)) if absf(_shown - target) > 0.5 else applause)
		busy = true
	var ta := _angle_for(int(round(_shown)))
	var dt := minf(delta, 1.0 / 30.0)
	_needle_v += (ta - _needle) * SPRING_K * dt - _needle_v * SPRING_C * dt
	_needle += _needle_v * dt
	if absf(ta - _needle) > 0.002 or absf(_needle_v) > 0.01:
		busy = true
	if applause > ENCORE_AT or UiKit.now_ms() - _bump_ms < 300:
		busy = true
	queue_redraw()
	if not busy:
		_needle = ta
		set_process(false)


func _draw() -> void:
	var now := UiKit.now_ms()
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	var top := (H_HIT - H_VIS) * 0.5
	draw_set_transform(Vector2(W * 0.5, H_HIT * 0.5), 0.0, Vector2(k, k))
	var o := Vector2(-W * 0.5, -H_HIT * 0.5)
	var plate := Rect2(o + Vector2(0, top), Vector2(W, H_VIS))
	var encore := applause > ENCORE_AT
	var fill := UiKit.BRASS if not is_pressed else UiKit.pressed(UiKit.BRASS)
	UiKit.draw_chunky_rect(self, plate, 34.0, fill, UiKit.BRASS_SHADE, UiKit.BUTTON_OUTLINE, 12.0)
	draw_line(plate.position + Vector2(40, 13), plate.position + Vector2(W - 40, 13), Color(UiKit.BRASS_LIGHT, 0.8), 4.0, true)
	# dial
	var dc := o + Vector2(20.0 + DIAL * 0.5, H_HIT * 0.5 + 4.0)
	draw_circle(dc, DIAL * 0.5, UiKit.NAVY)
	draw_circle(dc, DIAL * 0.5 - 6.0, UiKit.CREAM)
	var r_arc := DIAL * 0.5 - 18.0
	var a0 := -PI * 0.5 - deg_to_rad(SWEEP_DEG)
	var a1 := -PI * 0.5 + deg_to_rad(SWEEP_DEG)
	draw_arc(dc, r_arc, a0, a0 + (a1 - a0) * 0.34, 16, UiKit.CHERRY, 12.0, true)
	draw_arc(dc, r_arc, a0 + (a1 - a0) * 0.34, a0 + (a1 - a0) * 0.67, 16, UiKit.YELLOW, 12.0, true)
	draw_arc(dc, r_arc, a0 + (a1 - a0) * 0.67, a1, 16, UiKit.GREEN, 12.0, true)
	draw_arc(dc, r_arc, a1, a1 + deg_to_rad(ENCORE_DEG), 8, UiKit.GOLD if not encore else UiKit.GOLD_LIGHT, 12.0, true)
	var nd := Vector2(sin(_needle), -cos(_needle))
	draw_line(dc - nd * 8.0, dc + nd * (DIAL * 0.5 - 14.0), UiKit.NAVY, 7.0, true)
	draw_line(dc + nd * (DIAL * 0.5 - 30.0), dc + nd * (DIAL * 0.5 - 14.0), UiKit.CHERRY, 5.0, true)
	draw_circle(dc, 11.0, UiKit.NAVY)
	draw_circle(dc, 6.0, UiKit.BRASS_LIGHT)
	# applause number
	var f := UiKit.display_font()
	var nb := 1.0
	var bt := float(now - _bump_ms) / 300.0
	if bt >= 0.0 and bt < 1.0 and not UiKit.reduce_motion():
		nb = 1.0 + 0.22 * sin(bt * PI)
	var num_c := o + Vector2(20.0 + DIAL + 18.0 + 58.0, H_HIT * 0.5 + 2.0)
	draw_set_transform(Vector2(W * 0.5, H_HIT * 0.5) + (num_c - o - Vector2(W, H_HIT) * 0.5) * k, 0.0, Vector2(k * nb, k * nb))
	var ncol := UiKit.GOLD_LIGHT if encore else UiKit.CREAM
	UiKit.draw_text_centered(self, f, Vector2.ZERO, _num_text, UiKit.SIZE_HUD_NUM, ncol, 14)
	draw_set_transform(Vector2(W * 0.5, H_HIT * 0.5), 0.0, Vector2(k, k))
	# script counter
	var sx := o.x + 20.0 + DIAL + 18.0 + 116.0 + 10.0
	if not _layout_tomatoes:
		sx += 70.0
	draw_line(Vector2(sx - 12.0, o.y + top + 26.0), Vector2(sx - 12.0, o.y + top + H_VIS - 30.0), Color(UiKit.BRASS_SHADE, 0.9), 4.0)
	UiKit.draw_icon(self, _tex_script, Rect2(sx, o.y + H_HIT * 0.5 - 24.0, 46.0, 50.0))
	UiKit.draw_text(self, f, Vector2(sx + 54.0, o.y + H_HIT * 0.5 + 18.0), _script_text, UiKit.SIZE_HUD_NUM_S,
		UiKit.CREAM, 12)
	if encore:
		_draw_sparkles(now, o)
	draw_set_transform(Vector2.ZERO)


func _draw_sparkles(now: int, o: Vector2) -> void:
	if UiKit.reduce_flash():
		return
	var t := float(now) * 0.001
	for i in 6:
		var ph := t * 1.6 + float(i) * 1.047
		var s := 0.5 + 0.5 * sin(ph * 2.0)
		var x := o.x + 40.0 + fmod(float(i) * 97.0 + t * 30.0, W - 80.0)
		var y := o.y + (8.0 if i % 2 == 0 else H_HIT - 8.0)
		UiKit.star_points(_star, Vector2(x, y), 6.0 + 9.0 * s, 3.0 + 3.0 * s, ph)
		draw_colored_polygon(_star, Color(UiKit.GOLD_LIGHT, 0.5 + 0.5 * s))
	var et := float(now - _encore_ms) / 1400.0
	if et >= 0.0 and et < 1.0:
		# a stamp slammed across the plate (1.6 → 1.0 in the first 6th), then it fades
		var a := clampf((1.0 - et) * 3.0, 0.0, 1.0)
		var sc := 1.6 - 0.6 * minf(1.0, et * 6.0)
		draw_set_transform(Vector2(W * 0.5 + 10.0, H_HIT * 0.5), -0.12, Vector2(sc, sc))
		var f := UiKit.display_font()
		var tw := f.get_string_size(_encore_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BANNER).x
		UiKit.draw_chunky_rect(self, Rect2(-tw * 0.5 - 22.0, -40.0, tw + 44.0, 80.0), 20.0, Color(UiKit.CURTAIN, a),
			Color(UiKit.CURTAIN_SHADE, a), 5.0, 6.0)
		UiKit.draw_text_centered(self, f, Vector2(0, -3), _encore_text, UiKit.SIZE_BANNER, Color(UiKit.GOLD_LIGHT, a), 10,
			Color(UiKit.NAVY, a))
