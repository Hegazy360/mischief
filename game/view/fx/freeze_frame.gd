## FxFreezeFrame — the freeze-frame for the biggest gag of a chain and for signatures
## (comedy.md §2: 45–60 f, 70 % desaturation, a paper border, a "+" stamp). Screen space
## (its own CanvasLayer under the HUD); the desaturation is a single screen-texture pass,
## only while the freeze-frame runs (JuiceClock.freeze_frame_changed).
class_name FxFreezeFrame
extends Control

const PAPER := Color("#FFF4E0")
const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.7;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(l * 1.04, l * 0.97, l * 0.86);
	COLOR = vec4(mix(c, sepia, amount), 1.0);
}
"""

var _desat: ColorRect = null
var _t := 0.0
var _on := false
var _label := ""
var _font: Font = null


func _init() -> void:
	name = "FreezeFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	_font = ViewKit.display_font()
	_desat = ColorRect.new()
	_desat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desat.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	_desat.material = m
	_desat.show_behind_parent = true
	add_child(_desat)


## Show / hide (JuiceClock.freeze_frame_changed). `label` = the stamp text ("ENCORE!").
func set_on(on: bool, label: String = "") -> void:
	_on = on
	visible = on
	_t = 0.0
	if label != "":
		_label = label
	queue_redraw()


func is_on() -> bool:
	return _on


func _process(delta: float) -> void:
	if _on:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if not _on:
		return
	var s := size
	var b := 34.0
	draw_rect(Rect2(0, 0, s.x, b), PAPER)
	draw_rect(Rect2(0, s.y - b, s.x, b), PAPER)
	draw_rect(Rect2(0, 0, b, s.y), PAPER)
	draw_rect(Rect2(s.x - b, 0, b, s.y), PAPER)
	var ink := ViewKit.INK
	var inner := Rect2(b, b, s.x - 2.0 * b, s.y - 2.0 * b)
	draw_rect(inner, ink, false, 6.0)
	# Tape corners.
	for c in [Vector2(b, b), Vector2(s.x - b, b), Vector2(b, s.y - b), Vector2(s.x - b, s.y - b)]:
		draw_set_transform(c, 0.785, Vector2.ONE)
		draw_rect(Rect2(-60, -18, 120, 36), Color("#F2DFA6", 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _label != "" and _font != null:
		var fs := 96
		var u := clampf(_t / (4.0 / 60.0), 0.0, 1.0)
		var sc := lerpf(1.6, 1.0, ViewKit.ease_out_cubic(u))
		var w := _font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2(s.x * 0.5, s.y * 0.22), -0.06, Vector2(sc, sc))
		draw_string_outline(_font, Vector2(-w * 0.5, 0), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, ink)
		draw_string(_font, Vector2(-w * 0.5, 0), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#FFD23F"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
