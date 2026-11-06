## SpikeHud — two lines of text over a spike: a status line and a fixed hint line. Deliberately ugly;
## a spike is judged on how it plays, not how its HUD looks.
class_name SpikeHud
extends CanvasLayer

var status: Label = null
var hint: Label = null


func _init() -> void:
	layer = 50
	status = _label(28, Vector2(28, 18), Color("#FFF4E0"))
	hint = _label(19, Vector2(28, 58), Color("#FFD98A"))


func _label(size: int, at: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#1B2340"))
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l
