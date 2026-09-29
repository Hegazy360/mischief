## StageView — the theatre around the cut-away house (GDD §1.3, §9.1): the dark backstage
## backdrop behind everything, the flies above the upper floor (roofline + rigging), the
## apron with footlight cups and a warm glow below the ground floor, and a gilded proscenium
## at the house's far ends. Uses art-house's `stage/*.svg` when present, else draws it.
class_name StageView
extends Node2D

const BACKDROP := Color("#1E1830")
const APRON := Color("#6B3F22")
const APRON_DK := Color("#4E2C17")
const GOLD := Color("#E8B33A")
const CURTAIN := Color("#B3122E")
const ART_APRON := "res://art/house/stage/apron.svg"
const ART_GLOW := "res://art/house/stage/footlight_glow.svg"
const ART_FLIES := "res://art/house/stage/flies.svg"
const ART_PRO_L := "res://art/house/stage/proscenium_l.svg"
const ART_PRO_R := "res://art/house/stage/proscenium_r.svg"

var layout: HouseLayout = null
var _bounds := Rect2()
var _glow: Texture2D = null
var _apron_tex: Texture2D = null


func _init() -> void:
	name = "Stage"
	z_index = -30


func setup(h: HouseLayout) -> void:
	layout = h
	_bounds = h.bounds()
	_glow = _make_glow()
	_apron_tex = ViewKit.tex(ART_APRON)
	for p in [[ART_FLIES, Vector2(_bounds.position.x, _bounds.position.y)]]:
		var t := ViewKit.tex(String(p[0]))
		if t != null:
			var s := Sprite2D.new()
			s.texture = t
			s.centered = false
			s.position = p[1]
			s.region_enabled = true
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_rect = Rect2(0, 0, _bounds.size.x, t.get_size().y)
			add_child(s)
	queue_redraw()


## A vertical warm gradient (footlight glow) as one small texture (batched rect).
static func _make_glow() -> Texture2D:
	var img := Image.create_empty(4, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var a := pow(1.0 - float(y) / 63.0, 1.6) * 0.55
		for x in 4:
			img.set_pixel(x, y, Color(1.0, 0.78, 0.42, a))
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	if layout == null:
		return
	var b := _bounds
	# Backdrop (everything not covered by a room).
	draw_rect(b.grow(400.0), BACKDROP)
	# Flies above the top floor: rigging battens and ropes.
	var top_floor := layout.floor_count() - 1
	var ceil_y := layout.floor_y(top_floor) - layout.interior_h
	var x := b.position.x + 80.0
	while x < b.end.x:
		draw_line(Vector2(x, b.position.y - 400.0), Vector2(x, ceil_y - 30.0), Color("#3A3050"), 3.0)
		x += 260.0
	draw_rect(Rect2(b.position.x, ceil_y - 120.0, b.size.x, 18.0), Color("#2E2542"))
	draw_rect(Rect2(b.position.x, ceil_y - 60.0, b.size.x, 12.0), Color("#2E2542"))
	# Roofline over each upper room (a simple gable band so the set reads as a house).
	for r in layout.rooms:
		if r.floor != top_floor:
			continue
		draw_rect(Rect2(r.x0 - 10.0, ceil_y - 34.0, r.width() + 20.0, 34.0), Color("#5A3A4A"))
		draw_rect(Rect2(r.x0 - 10.0, ceil_y - 34.0, r.width() + 20.0, 6.0), Color("#7A5060"))
	# Apron below the ground floor.
	var ay := layout.slab_h
	var ah := HouseLayout.APRON_H
	if _apron_tex != null:
		draw_texture_rect(_apron_tex, Rect2(b.position.x, ay, b.size.x, ah), true)
	else:
		draw_rect(Rect2(b.position.x, ay, b.size.x, ah), APRON)
		var bx := b.position.x
		while bx < b.end.x:
			draw_rect(Rect2(bx, ay + 20.0, 3.0, ah - 20.0), APRON_DK)
			bx += 140.0
		draw_rect(Rect2(b.position.x, ay, b.size.x, 12.0), APRON_DK)
		# Footlight cups.
		var fx := b.position.x + 120.0
		while fx < b.end.x:
			draw_rect(Rect2(fx - 30.0, ay + 4.0, 60.0, 22.0), Color("#2A1E3A"))
			draw_rect(Rect2(fx - 22.0, ay + 4.0, 44.0, 8.0), Color("#FFE7A8"))
			fx += 300.0
	# Warm glow up the front of the set.
	if _glow != null:
		draw_texture_rect(_glow, Rect2(b.position.x, ay - 150.0, b.size.x, 150.0), false, Color(1, 1, 1, 0.9))
	# Proscenium at the ends.
	_draw_pro(b.position.x, 1.0, b)
	_draw_pro(b.end.x, -1.0, b)


func _draw_pro(x: float, dir: float, b: Rect2) -> void:
	var w := 70.0
	var x0 := x if dir > 0.0 else x - w
	draw_rect(Rect2(x0, b.position.y, w, b.size.y), CURTAIN)
	var fx := x0 + (w - 22.0 if dir > 0.0 else 0.0)
	draw_rect(Rect2(fx, b.position.y, 22.0, b.size.y), GOLD)
	draw_rect(Rect2(fx + (18.0 if dir > 0.0 else 0.0), b.position.y, 4.0, b.size.y), Color("#9A6A12"))
	var y := b.position.y + 60.0
	while y < b.end.y:
		draw_rect(Rect2(x0 + 14.0, y, 10.0, 90.0), CURTAIN.darkened(0.25))
		y += 140.0
