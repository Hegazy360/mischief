## UiButton — the chunky panel button (ui brief §3.1): a rounded rectangle with a 6 px navy
## outline, one flat fill + a bottom shade strip, an optional icon and a Lilita / Nunito label.
## The Control rect is the hit box; the visual is inset by `hit_pad` (so a 96 px-tall visual can
## carry a taller hit box). Pressed = 0.94 scale + darker shade in the same frame.
## `pressed` fires on touch-up inside (XAG). Touches only — mouse events are ignored.
class_name UiButton
extends TouchWidget

signal pressed()

var text: String = ""
var icon: Texture2D = null
var fill: Color = UiKit.CREAM
var shade: Color = UiKit.CREAM_SHADE
var text_color: Color = UiKit.NAVY
var font_size: int = UiKit.SIZE_PLAY
var display_font: bool = true
var radius: float = 30.0
## Visual inset inside the hit rect (px, all sides).
var hit_pad: Vector2 = Vector2.ZERO
## Icon edge in px (0 = 70 % of the visual height).
var icon_px: float = 0.0
## Icon after the text instead of before (e.g. "Next Night ▶").
var icon_after: bool = false
var disabled: bool = false

var _pop: float = 0.0


## A configured button (convenience).
static func make(p_text: String, p_size: Vector2, p_fill: Color = UiKit.CREAM, p_shade: Color = UiKit.CREAM_SHADE,
		p_icon: Texture2D = null) -> UiButton:
	var b := UiButton.new()
	b.text = p_text
	b.fill = p_fill
	b.shade = p_shade
	b.icon = p_icon
	b.custom_minimum_size = p_size
	b.size = p_size
	return b


func _ready() -> void:
	set_process(false)


## The visual rect (local).
func visual_rect() -> Rect2:
	return Rect2(hit_pad, size - hit_pad * 2.0)


func _touch_down(_pos: Vector2) -> bool:
	if disabled:
		return false
	UiKit.haptic(&"ui")
	return true


func _touch_up(_pos: Vector2, inside: bool) -> void:
	if inside and not disabled:
		UiKit.sfx("ui_tap")
		pressed.emit()


func _draw() -> void:
	var vr := visual_rect()
	var c := vr.get_center()
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	draw_set_transform(c, 0.0, Vector2(k, k))
	var r := Rect2(-vr.size * 0.5, vr.size)
	var f := fill
	var s := shade
	if disabled:
		f = Color("#B9B4C7")
		s = Color("#8E89A3")
	elif is_pressed:
		f = UiKit.pressed(f)
		s = UiKit.pressed(s)
	UiKit.draw_chunky_rect(self, Rect2(r.position + Vector2(0, 6), r.size), radius, Color(UiKit.NAVY, 0.3),
		Color(UiKit.NAVY, 0.3), 0.0, 0.0)
	UiKit.draw_chunky_rect(self, r, radius, f, s, UiKit.BUTTON_OUTLINE, 12.0)
	var fnt := UiKit.display_font() if display_font else UiKit.ui_font()
	var fs := UiKit.text_size(font_size)
	var ip := icon_px if icon_px > 0.0 else r.size.y * 0.62
	var gap := 18.0 if (icon != null and text != "") else 0.0
	# the label always fits the face (Text +20 % shrinks it back, never below SIZE_MIN)
	var room := r.size.x - 36.0 - (ip + gap if icon != null else 0.0)
	var tw := 0.0 if text == "" else fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while text != "" and tw > room and fs > UiKit.SIZE_MIN:
		fs -= 2
		tw = fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total := tw + (ip + gap if icon != null else 0.0)
	var x := -total * 0.5
	var cy := -5.0
	if icon != null and not icon_after:
		UiKit.draw_icon(self, icon, Rect2(x, cy - ip * 0.5, ip, ip))
		x += ip + gap
	if text != "":
		UiKit.draw_text_centered(self, fnt, Vector2(x + tw * 0.5, cy), text, fs,
			text_color if not disabled else Color("#5E5A72"), 0)
		x += tw + gap
	if icon != null and icon_after:
		UiKit.draw_icon(self, icon, Rect2(x, cy - ip * 0.5, ip, ip))
	draw_set_transform(Vector2.ZERO)
