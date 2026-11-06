## BakeryViewer — plays every baked sprite sheet so the motion can be judged as motion.
##
## This is the runtime half of the proposal, and the point is how little of it there is: the whole
## "animation system" at run time is advancing an integer and blitting a region of a PNG. There is no
## rig, no IK, no springs, no ragdoll, no retarget — none of the things that have broken in this
## project — because by the time a clip reaches the game it is pixels.
##
## Pairs marked FLAT / CARTOON are the same KayKit clip baked twice, differing only in the filter's
## `amount`. That comparison is the thing to look at.
extends Control

const SHEETS := "res://proto/bakery/sheets/"
## Rows of clips to show; "|" pairs a flat bake with its cartoon one.
const LAYOUT := [
	["run_flat|run", "hit_flat|hit", "throw_flat|throw"],
	["idle", "walk", "sneak", "cheer", "pickup", "flat"],
]
const FPS := 12.0

var _index: Dictionary = {}
var _tex: Dictionary = {}
var _t: float = 0.0
var _font_d: Font = null
var _font_b: Font = null
var _scale: float = 1.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#141A33"))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font_d = load("res://ui/theme/fonts/LilitaOne-Regular.ttf")
	_font_b = load("res://ui/theme/fonts/Nunito-Bold.ttf")
	var f := FileAccess.open(SHEETS + "index.json", FileAccess.READ)
	if f == null:
		push_error("no index.json — run: python3 tools/bakery/run.py")
		return
	_index = JSON.parse_string(f.get_as_text())
	for name: String in (_index.get("clips", {}) as Dictionary):
		var p := SHEETS + str((_index["clips"][name] as Dictionary)["sheet"])
		if ResourceLoader.exists(p):
			_tex[name] = load(p)
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _clip(name: String) -> Dictionary:
	return (_index.get("clips", {}) as Dictionary).get(name, {})


## Draw one clip's current frame, with its name underneath. Returns the width it used.
func _draw_clip(name: String, at: Vector2, label: String, tint: Color) -> float:
	var info := _clip(name)
	if info.is_empty() or not _tex.has(name):
		return 0.0
	var tex: Texture2D = _tex[name]
	var fw := float(info["frame_w"])
	var fh := float(info["frame_h"])
	var count := int(info["count"])
	var frame := int(_t * FPS) % maxi(1, count)
	var w := fw * _scale
	var h := fh * _scale
	draw_texture_rect_region(tex, Rect2(at, Vector2(w, h)), Rect2(Vector2(float(frame) * fw, 0.0), Vector2(fw, fh)))
	draw_string(_font_b, at + Vector2(0, h + 22), label, HORIZONTAL_ALIGNMENT_CENTER, w, 19, tint)
	draw_string(_font_b, at + Vector2(0, h + 42), "%d frames" % count, HORIZONTAL_ALIGNMENT_CENTER, w,
		15, Color("#6E78A0"))
	return w


func _draw() -> void:
	var vs := get_viewport_rect().size
	if _index.is_empty():
		draw_string(_font_b, Vector2(40, 80), "no sheets — run:  python3 tools/bakery/run.py",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#FFD98A"))
		return
	draw_string(_font_d, Vector2(34, 54), "THE BAKERY — CC0 clips through the cartoon filter, baked to sprites",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#FFF4E0"))
	draw_string(_font_b, Vector2(34, 84), "Each pair: left is the library clip untouched, right is the same clip filtered. Nothing here was keyframed by hand.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#8E97BF"))
	# one scale that makes every row fit
	var widest := 0.0
	for row: Array in LAYOUT:
		var w := 0.0
		for cell: String in row:
			for n in cell.split("|"):
				var info := _clip(n)
				if not info.is_empty():
					w += float(info["frame_w"]) + 14.0
			w += 44.0
		widest = maxf(widest, w)
	# fit BOTH ways: the stack of rows must also land inside the viewport
	var tall := 0.0
	for row: Array in LAYOUT:
		var rh := 0.0
		for cell: String in row:
			for n in cell.split("|"):
				var inf := _clip(n)
				if not inf.is_empty():
					rh = maxf(rh, float(inf["frame_h"]))
		tall += rh
	var gaps := float(LAYOUT.size()) * 80.0 + 150.0
	_scale = clampf(minf((vs.x - 80.0) / maxf(1.0, widest), (vs.y - gaps) / maxf(1.0, tall)), 0.3, 1.3)
	var y := 130.0
	for row: Array in LAYOUT:
		var x := 40.0
		var row_h := 0.0
		for cell: String in row:
			var parts := cell.split("|")
			if parts.size() == 2:
				draw_rect(Rect2(x - 10.0, y - 8.0, 0.0, 0.0), Color.TRANSPARENT)
			for i in parts.size():
				var n := parts[i]
				var info := _clip(n)
				if info.is_empty():
					continue
				var is_pair := parts.size() == 2
				var lab := str(info.get("clip", n))
				var col := Color("#8E97BF")
				if is_pair:
					lab = ("FLAT  " + lab) if i == 0 else ("CARTOON  " + lab)
					col = Color("#8E97BF") if i == 0 else Color("#FFC93C")
				var used := _draw_clip(n, Vector2(x, y), lab, col)
				row_h = maxf(row_h, float(info["frame_h"]) * _scale)
				x += used + 14.0
			x += 44.0
		y += row_h + 78.0
