## FxSpotMeter — the "?" over his head that fills while he can see Hush (GDD §4.3), turning
## into a red "!" when it fills (spotted). The "?" grows 0.7 → 1.0 and warms white → yellow →
## orange with its fill ring; above 70 % it trembles. Constant screen size.
class_name FxSpotMeter
extends Node2D

const SIZE := 84
const BANG_SIZE := 120
const RING_R := 50.0
const BANG_HOLD_S := 0.9
const POP_S := 4.0 / 60.0

var reduce_motion: bool = false
var _font: Font = null
var _pct := 0.0
var _bang := 99.0
var _t := 0.0
var _unit := 1.0


func _init() -> void:
	name = "SpotMeter"
	visibility_layer = 2
	z_index = 33
	visible = false


var _plate: Texture2D = null


func _ready() -> void:
	_font = ViewKit.display_font()
	_plate = FxArt.sprite("caption_burst")


## Update from the fill fraction (0..1) at `anchor` (world, above his head).
func update_meter(pct: float, anchor: Vector2, unit: float) -> void:
	_pct = pct
	_unit = unit
	position = anchor
	visible = _pct > 0.001 or _bang < BANG_HOLD_S
	queue_redraw()


## The "!" sting (spotted).
func bang() -> void:
	_bang = 0.0
	visible = true


## Height the meter needs above his head (world px at unit 1): 0 when hidden.
func needs_space() -> float:
	return 120.0 if visible else 0.0


func tick(dt: float) -> void:
	_t += dt
	if _bang < BANG_HOLD_S:
		_bang += dt
		if _bang >= BANG_HOLD_S and _pct <= 0.001:
			visible = false
	var s := 0.7 + 0.3 * _pct
	if _bang < BANG_HOLD_S:
		s = 1.0 if reduce_motion or _bang > POP_S else lerpf(1.6, 1.0, _bang / POP_S)
	scale = Vector2.ONE * s * _unit
	if _pct > 0.7 and _bang >= BANG_HOLD_S and not reduce_motion:
		rotation = sin(_t * 40.0) * 0.06
	else:
		rotation = 0.0


func _draw() -> void:
	if _font == null:
		return
	var bang := _bang < BANG_HOLD_S
	var txt := "!" if bang else "?"
	var col := Color("#E23B4E") if bang else Color("#FFFFFF").lerp(Color("#FFD23F"), clampf(_pct * 1.6, 0.0, 1.0)).lerp(Color("#FF8A2A"), clampf((_pct - 0.6) * 2.5, 0.0, 1.0))
	if not bang:
		draw_arc(Vector2(0, -30), RING_R, 0.0, TAU, 36, Color("#1B2340", 0.35), 9.0)
		draw_arc(Vector2(0, -30), RING_R, -PI * 0.5, -PI * 0.5 + TAU * clampf(_pct, 0.0, 1.0), 36, col, 9.0)
	var fs := BANG_SIZE if bang else SIZE
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := Vector2(-w * 0.5, 0.0)
	if bang and _plate != null:
		draw_texture_rect(_plate, Rect2(-110, -fs * 0.95, 220, fs * 1.1), false, Color("#FFE0DC"))
	draw_string_outline(_font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, ViewKit.INK)
	draw_string(_font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
