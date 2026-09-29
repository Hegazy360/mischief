## FxStamp — a pooled bonus stamp beside the caption (GDD §3.8, §6.1): "MELTDOWN! +8",
## "COMBO! +4", "NEAR MISS! +2", "EMBARRASSED! +5" — 64 px, cherry red on cream with a
## rubber-stamp border, stamped in 1.6 → 1.0 over 4 frames, tilted the other way.
class_name FxStamp
extends FxCaption

const STAMP_RED := Color("#E23B4E")
const PAPER := Color("#FFF4E0")


func _init() -> void:
	super._init()
	font_size = 64
	tilt = 0.09
	life = 1.4
	fill = STAMP_RED
	ink = PAPER


func start(txt: String, world_pos: Vector2, size: int = 64, _with_plate: bool = false) -> void:
	super.start(txt, world_pos, size, false)
	outline_px = maxi(8, int(round(size * 0.16)))


func _draw() -> void:
	if not active or _font == null:
		return
	var asc := _font.get_ascent(font_size)
	var base := Vector2(-_w * 0.5, -font_size * 0.12)
	var box := Rect2(base.x - 22.0, base.y - asc - 12.0, _w + 44.0, asc + font_size * 0.35 + 24.0)
	draw_rect(box.grow(6.0), ViewKit.INK)
	draw_rect(box, PAPER)
	var inner := box.grow(-7.0)
	var c := STAMP_RED
	draw_line(inner.position, Vector2(inner.end.x, inner.position.y), c, 4.0)
	draw_line(Vector2(inner.end.x, inner.position.y), inner.end, c, 4.0)
	draw_line(inner.end, Vector2(inner.position.x, inner.end.y), c, 4.0)
	draw_line(Vector2(inner.position.x, inner.end.y), inner.position, c, 4.0)
	draw_string(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)
