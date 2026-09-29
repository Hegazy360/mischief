## HotspotView — the "you can use this" layer of one hotspot (GDD §3.5): the pre-baked
## outline sprite (`art.outline`, a 4 px white silhouette) pulsing alpha 0.6 ↔ 1.0 at 1.2 Hz
## while Hush shares its room, and a sparkle every 1.2 s. Without outline art it draws a
## rounded rect outline around the prop. Lives on visibility layer 2 (never in the PiP).
class_name HotspotView
extends Node2D

const PULSE_HZ := 1.2
const SPARKLE_EVERY := 1.2
const SPARKLE_LIFE := 0.35
const OUTLINE_COLOR := Color("#FFF4E0")

var hotspot: HouseLayout.Hotspot = null
## Local rect of the drawn prop (for the fallback outline and sparkle points).
var prop_rect: Rect2 = Rect2()
var outline_tex: Texture2D = null
var outline_pos: Vector2 = Vector2.ZERO
var outline_scale: Vector2 = Vector2.ONE
## The outline pulse colour (PropView.outline_tint: gold on the pale rooms).
var tint: Color = OUTLINE_COLOR
var highlighted: bool = false:
	set(v):
		if highlighted != v:
			highlighted = v
			visible = v
			_t = 0.0
			queue_redraw()

var _t := 0.0
var _spark_i := 0
var _sparkle: Texture2D = null


func _init() -> void:
	visibility_layer = 2
	visible = false
	z_index = -1


func _ready() -> void:
	_sparkle = FxArt.particle("sparkles")


## Per-frame pulse (real time; cheap redraw of 1–2 rects).
func tick(dt: float, phase_offset: float) -> void:
	if not highlighted:
		return
	_t += dt
	var a := 0.8 + 0.2 * sin(TAU * PULSE_HZ * (_t + phase_offset))
	modulate.a = a
	queue_redraw()


func _draw() -> void:
	if outline_tex != null:
		draw_texture_rect(outline_tex, Rect2(outline_pos, outline_tex.get_size() * outline_scale), false, tint)
	else:
		var r := prop_rect.grow(6.0)
		var c := Color(tint, 0.95)
		draw_line(r.position, Vector2(r.end.x, r.position.y), c, 5.0)
		draw_line(Vector2(r.end.x, r.position.y), r.end, c, 5.0)
		draw_line(r.end, Vector2(r.position.x, r.end.y), c, 5.0)
		draw_line(Vector2(r.position.x, r.end.y), r.position, c, 5.0)
	# Sparkle: one flash per SPARKLE_EVERY at a corner-ish point of the prop.
	var cyc := fmod(_t, SPARKLE_EVERY)
	if cyc < SPARKLE_LIFE and _sparkle != null:
		var k := int(_t / SPARKLE_EVERY) % 4
		var p := prop_rect.position
		match k:
			1:
				p = Vector2(prop_rect.end.x, prop_rect.position.y)
			2:
				p = prop_rect.end - Vector2(0, prop_rect.size.y * 0.4)
			3:
				p = Vector2(prop_rect.position.x, prop_rect.get_center().y)
		var u := cyc / SPARKLE_LIFE
		var s := sin(u * PI) * 30.0
		draw_texture_rect(_sparkle, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color("#FFE680"))
