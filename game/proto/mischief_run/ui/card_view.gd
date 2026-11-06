## CardView — one prank card, drawn with primitives and type. No sprites, no animation frames: the
## whole look of this prototype is code, which is the point (docs/review/pivot/2026_options.md §3.5).
class_name CardView
extends Control

signal tapped(view: CardView)

const W := 212.0
const H := 286.0

static var font_display: Font = null
static var font_body: Font = null

var card_id: String = ""
var data: Dictionary = {}
## Drawn lifted and outlined.
var selected: bool = false
## Greyed: more Nerve than you have left.
var dimmed: bool = false
var lift: float = 0.0
## `emulate_touch_from_mouse` means one click arrives as BOTH a mouse button and a screen touch, in
## the same frame. Without this guard every tap fires twice and a selection toggles straight back off.
var _tap_frame: int = -1


static func load_fonts() -> void:
	if font_display == null:
		font_display = load("res://ui/theme/fonts/LilitaOne-Regular.ttf")
		font_body = load("res://ui/theme/fonts/Nunito-Bold.ttf")


func setup(id: String, d: Dictionary) -> void:
	CardView.load_fonts()
	card_id = id
	data = d
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var hit := false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		hit = true
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		hit = m.pressed and m.button_index == MOUSE_BUTTON_LEFT
	if hit and int(Engine.get_process_frames()) != _tap_frame:
		_tap_frame = int(Engine.get_process_frames())
		accept_event()
		tapped.emit(self)


func _draw() -> void:
	if data.is_empty():
		return
	var r := Rect2(Vector2(0, -lift), size)
	var ink := Color("#0E1328")
	var face := Color("#FFF4E0") if not dimmed else Color("#9A947F")
	var accent := Color("#FFC93C") if selected else ink
	# body + a thick outline that doubles as the selection state
	draw_rect(r.grow(6.0), accent, true)
	draw_rect(r, face, true)
	# glyph panel
	var gh := 120.0
	draw_rect(Rect2(r.position, Vector2(r.size.x, gh)), Color("#2B3566") if not dimmed else Color("#565B74"), true)
	var glyph := str(data.get("glyph", "?"))
	draw_string(CardView.font_display, r.position + Vector2(0, 86), glyph,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 68, Color("#FFF4E0"))
	# cost pip
	var cost := int(data.get("cost", 1))
	var cc := r.position + Vector2(r.size.x - 26, 26)
	draw_circle(cc, 19.0, Color("#E23B4E"))
	draw_string(CardView.font_display, cc + Vector2(-19, 9), str(cost),
		HORIZONTAL_ALIGNMENT_CENTER, 38, 26, Color("#FFF4E0"))
	# base value pip
	var bc := r.position + Vector2(26, 26)
	draw_circle(bc, 19.0, Color("#FFC93C"))
	draw_string(CardView.font_display, bc + Vector2(-19, 9), str(int(data.get("base", 0))),
		HORIZONTAL_ALIGNMENT_CENTER, 38, 26, ink)
	# name
	draw_string(CardView.font_display, r.position + Vector2(8, gh + 32), str(data.get("name", "")),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 25, ink)
	# rules text
	draw_multiline_string(CardView.font_body, r.position + Vector2(12, gh + 60),
		str(data.get("text", "")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 24, 19,
		5, Color("#3A4160"))
