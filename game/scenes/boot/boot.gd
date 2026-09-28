## Boot — placeholder title card until the real front end lands.
extends Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.1, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "Mischief Next Door"
	title.add_theme_font_size_override("font_size", 96)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(title)
