## ToBeContinued — the card after the last slice Night (s2-night §4.3): "To be continued…"
## (`curtain.to_be_continued`) in gold on the curtain for SHOW_S (a tap skips after MIN_S), then
## `closed` → the Playbill with Night 3 locked. The dots appear one by one.
class_name ToBeContinued
extends Control

signal closed()

const SHOW_S := 2.0
const MIN_S := 0.25

var age: float = 0.0
var auto_close: bool = true

var _text: String = ""
var _curtain: Texture2D = null
var _closed: bool = false
var _down: int = -1


func _init() -> void:
	name = "ToBeContinued"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_text = UiStrings.t("curtain.to_be_continued")
	if ResourceLoader.exists(NightCurtain.ART):
		_curtain = load(NightCurtain.ART) as Texture2D


func _process(delta: float) -> void:
	age += delta
	if auto_close and age >= SHOW_S:
		close()
	queue_redraw()


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit()


func tap() -> void:
	if age >= MIN_S:
		close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		accept_event()
		if st.pressed:
			_down = st.index
		elif st.index == _down:
			_down = -1
			tap()
	elif event is InputEventMouse or event is InputEventScreenDrag:
		accept_event()


func _draw() -> void:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	if _curtain != null:
		var ts := _curtain.get_size()
		var tw := ts.x * (vs.y / maxf(1.0, ts.y))
		var x := 0.0
		while x < vs.x:
			draw_texture_rect(_curtain, Rect2(x, 0, tw, vs.y), false)
			x += tw
	else:
		draw_rect(Rect2(Vector2.ZERO, vs), UiKit.CURTAIN)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(UiKit.NAVY, 0.45))
	# the text types its trailing dots one by one
	var t := _text
	var dots := 0
	while t.ends_with("…") or t.ends_with("."):
		t = t.substr(0, t.length() - 1)
		dots = 3
	var shown := clampi(int(age / 0.3), 0, dots)
	var line := t + ".".repeat(shown)
	var k := clampf(age / 0.35, 0.0, 1.0)
	var y := vs.y * 0.5 + (1.0 - k) * 40.0
	UiKit.draw_text_centered(self, UiKit.display_font(), Vector2(vs.x * 0.5, y), line, UiKit.SIZE_BIG_TITLE,
		Color(UiKit.GOLD_LIGHT, k), 18, Color(UiKit.NAVY, k))
