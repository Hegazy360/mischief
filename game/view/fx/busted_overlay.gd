## FxBustedOverlay — the Busted Cam look (GDD §4.6): a red vignette, a split-frame comic
## border (a slanted divider between his side and hers), a "SPOTTED!" stamp and a blinking
## "REPLAY" chip. Screen space on the FX CanvasLayer; the dotted sight line is drawn in world
## space by FxLayer. Shown for the replay's duration.
class_name FxBustedOverlay
extends Control

const RED := Color("#E23B4E")
const PAPER := Color("#FFF4E0")

var _vig: Texture2D = null
var _font: Font = null
var _t := 0.0
var _on := false
## The split-frame divider's x as a fraction of the width (between the two characters).
var split_x: float = 0.5


func _init() -> void:
	name = "BustedOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	_vig = FxArt.sprite("vignette_red")
	_font = ViewKit.display_font()


func set_on(on: bool) -> void:
	_on = on
	visible = on
	_t = 0.0
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
	if _vig != null:
		draw_texture_rect(_vig, Rect2(Vector2.ZERO, s), false, Color(1, 1, 1, 0.95))
	var ink := ViewKit.INK
	var b := 26.0
	# Comic frame.
	draw_rect(Rect2(0, 0, s.x, b), ink)
	draw_rect(Rect2(0, s.y - b, s.x, b), ink)
	draw_rect(Rect2(0, 0, b, s.y), ink)
	draw_rect(Rect2(s.x - b, 0, b, s.y), ink)
	draw_rect(Rect2(b, b, s.x - 2.0 * b, s.y - 2.0 * b), PAPER, false, 7.0)
	# Split-frame divider (slanted), gutters in paper.
	var mx := clampf(split_x, 0.2, 0.8) * s.x
	var top := Vector2(mx + s.x * 0.04, b)
	var bot := Vector2(mx - s.x * 0.04, s.y - b)
	draw_line(top, bot, PAPER, 30.0)
	draw_line(top, bot, ink, 16.0)
	# SPOTTED! stamp, popping in over 4 frames.
	if _font != null:
		var fs := 110
		var txt := ViewKit.word("fx.spotted", "SPOTTED!")
		var u := clampf(_t / (4.0 / 60.0), 0.0, 1.0)
		var sc := lerpf(1.7, 1.0, ViewKit.ease_out_cubic(u))
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2(s.x * 0.5, s.y * 0.2 + 30.0), -0.05, Vector2(sc, sc))
		draw_string_outline(_font, Vector2(-w * 0.5 + 5, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 22, Color(ink, 0.5))
		draw_string_outline(_font, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 22, PAPER)
		draw_string(_font, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RED)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# REPLAY chip.
		var chip := Rect2(b + 30.0, b + 26.0, 250.0, 64.0)
		draw_rect(chip, Color(ink, 0.85))
		if int(_t * 3.0) % 2 == 0:
			draw_circle(chip.position + Vector2(34, 32), 13.0, RED)
		draw_string(_font, chip.position + Vector2(60, 48), ViewKit.word("fx.replay", "REPLAY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 44, PAPER)
