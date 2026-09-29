## StageView — the theatre around the cut-away house (GDD §1.3, §9.1, STYLE §8): read from the
## house.json `stage` block — the flies (tiled along x, bottom edge at the top of the upper floor,
## `fill_color` above), the apron (tiled at y = +60), the additive footlight glows (every 256 px),
## the set pieces (sky flats, roofs: absolute `world_pos`, `z`), the gilded proscenium ends and
## the backstage clear colour — and the velvet ropes (`velvet_rope.anchor` = the sprite's bottom
## centre, placed at the doorway x on the floor line) across doorways into tonight's unlit rooms.
## Without a `stage` block (greybox house) it draws a simple backdrop, flies, apron and
## proscenium itself. Everything static is built once; the flies and apron are tiled sprites.
class_name StageView
extends Node2D

const BACKDROP := Color("#1E1830")
const APRON := Color("#6B3F22")
const APRON_DK := Color("#4E2C17")
const GOLD := Color("#E8B33A")
const CURTAIN := Color("#B3122E")

var layout: HouseLayout = null
var unlocked: PackedStringArray = PackedStringArray()
var _bounds := Rect2()
var _glow: Texture2D = null
var _data := false
var _fill := BACKDROP
var _flies_bottom := 0.0
## Front pieces (proscenium, glows) drawn above the rooms.
var front: Node2D = null


func _init() -> void:
	name = "Stage"
	z_index = -30


func setup(h: HouseLayout, unlocked_rooms: PackedStringArray = PackedStringArray()) -> void:
	layout = h
	unlocked = unlocked_rooms
	_bounds = h.bounds()
	var st := h.stage
	_data = not st.is_empty()
	front = Node2D.new()
	front.name = "StageFront"
	front.z_index = 39
	add_child(front)
	if _data:
		_build_from(st)
	else:
		_glow = _make_glow()
	queue_redraw()


func _build_from(st: Dictionary) -> void:
	var cc: Variant = st.get("clear_color", null)
	if cc is String:
		_fill = Color(ViewKit.s(cc))
	var flies: Dictionary = st.get("flies", {}) if st.get("flies", {}) is Dictionary else {}
	if not flies.is_empty():
		var sz := _v2(flies.get("size", [1024, 400]))
		_flies_bottom = float(flies.get("bottom_y", -1340))
		if flies.get("fill_color", null) is String:
			_fill = Color(ViewKit.s(flies["fill_color"]))
		_tiled(ViewKit.s(flies.get("art", "")), float(flies.get("x0", _bounds.position.x)), float(flies.get("x1", _bounds.end.x)),
			_flies_bottom - sz.y, self, 0)
	var apron: Dictionary = st.get("apron", {}) if st.get("apron", {}) is Dictionary else {}
	if not apron.is_empty():
		_tiled(ViewKit.s(apron.get("art", "")), float(apron.get("x0", 0)), float(apron.get("x1", _bounds.end.x)),
			float(apron.get("top_y", 60)), self, 1)
	for piece in st.get("pieces", []):
		if not (piece is Dictionary):
			continue
		var s := _sprite(ViewKit.s((piece as Dictionary).get("art", "")), _v2((piece as Dictionary).get("world_pos", [0, 0])), self)
		if s != null:
			s.z_index = 2 + int((piece as Dictionary).get("z", 0))
	for key in ["proscenium_l", "proscenium_r"]:
		var pd: Variant = st.get(key, null)
		if pd is Dictionary:
			_sprite(ViewKit.s((pd as Dictionary).get("art", "")), _v2((pd as Dictionary).get("world_pos", [0, 0])), front)
	var glow: Dictionary = st.get("footlight_glow", {}) if st.get("footlight_glow", {}) is Dictionary else {}
	if not glow.is_empty():
		var gsz := _v2(glow.get("size", [512, 220]))
		var x := float(glow.get("first_x", 128))
		var x1 := float(glow.get("x1", _bounds.end.x))
		var every := maxf(32.0, float(glow.get("every_px", 256)))
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var alpha := float(glow.get("alpha", 0.5))
		while x < x1:
			var g := _sprite(ViewKit.s(glow.get("art", "")), Vector2(x - gsz.x * 0.5, float(glow.get("bottom_y", 100)) - gsz.y), front)
			if g == null:
				break
			g.material = mat
			g.modulate = Color(1, 1, 1, alpha)
			x += every


## A row of the same texture from x0 to x1 as ONE sprite with a repeating region.
func _tiled(path: String, x0: float, x1: float, y: float, parent: Node2D, z: int) -> void:
	var t := ViewKit.tex(path)
	if t == null or x1 <= x0:
		return
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = Vector2(x0, y)
	s.region_enabled = true
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_rect = Rect2(0, 0, x1 - x0, t.get_size().y)
	s.z_index = z
	parent.add_child(s)


func _sprite(path: String, pos: Vector2, parent: Node2D) -> Sprite2D:
	var t := ViewKit.tex(path)
	if t == null:
		return null
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = pos
	parent.add_child(s)
	return s


static func _v2(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


## Velvet ropes across every doorway between an unlocked room and a locked one, into `parent`
## (the foreground layer), anchored per the stage block (on the locked side of the doorway).
func add_ropes(parent: Node2D) -> void:
	if layout == null or parent == null:
		return
	var rope: Dictionary = layout.stage.get("velvet_rope", {}) if layout.stage.get("velvet_rope", {}) is Dictionary else {}
	var rope_tex := ViewKit.tex(ViewKit.s(rope.get("art", "res://art/house/stage/velvet_rope.svg")))
	if rope_tex == null:
		rope_tex = FxArt.sprite("fallback/velvet_rope")
	var sz := rope_tex.get_size()
	var anchor := _v2(rope.get("anchor", [sz.x * 0.5, sz.y]))
	for l in layout.links:
		if l.kind == "stairs":
			continue
		var a_open := unlocked.has(l.a)
		var b_open := unlocked.has(l.b)
		if a_open == b_open:
			continue
		var r := layout.room(l.a if a_open else l.b)
		if r == null:
			continue
		var s := Sprite2D.new()
		s.texture = rope_tex
		s.centered = false
		# Across the doorway, nudged to the locked side so it never covers the open room's props.
		var locked_dir := 1.0 if (l.x >= r.x1 - 1.0) else -1.0
		s.position = Vector2(l.x + locked_dir * sz.x * 0.42, layout.floor_y(r.floor)) - anchor
		s.z_index = 1
		s.name = "Rope_" + l.id
		parent.add_child(s)


## A vertical warm gradient (footlight glow) as one small texture (greybox fallback).
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
	if _data:
		# Backstage behind everything; the flies' fill above their art.
		draw_rect(b.grow(600.0), _fill)
		return
	draw_rect(b.grow(400.0), BACKDROP)
	var top_floor := layout.floor_count() - 1
	var ceil_y := layout.floor_y(top_floor) - layout.interior_h
	var x := b.position.x + 80.0
	while x < b.end.x:
		draw_line(Vector2(x, b.position.y - 400.0), Vector2(x, ceil_y - 30.0), Color("#3A3050"), 3.0)
		x += 260.0
	draw_rect(Rect2(b.position.x, ceil_y - 120.0, b.size.x, 18.0), Color("#2E2542"))
	draw_rect(Rect2(b.position.x, ceil_y - 60.0, b.size.x, 12.0), Color("#2E2542"))
	for r in layout.rooms:
		if r.floor != top_floor:
			continue
		draw_rect(Rect2(r.x0 - 10.0, ceil_y - 34.0, r.width() + 20.0, 34.0), Color("#5A3A4A"))
		draw_rect(Rect2(r.x0 - 10.0, ceil_y - 34.0, r.width() + 20.0, 6.0), Color("#7A5060"))
	var ay := layout.slab_h
	var ah := HouseLayout.APRON_H
	draw_rect(Rect2(b.position.x, ay, b.size.x, ah), APRON)
	var bx := b.position.x
	while bx < b.end.x:
		draw_rect(Rect2(bx, ay + 20.0, 3.0, ah - 20.0), APRON_DK)
		bx += 140.0
	draw_rect(Rect2(b.position.x, ay, b.size.x, 12.0), APRON_DK)
	var fx := b.position.x + 120.0
	while fx < b.end.x:
		draw_rect(Rect2(fx - 30.0, ay + 4.0, 60.0, 22.0), Color("#2A1E3A"))
		draw_rect(Rect2(fx - 22.0, ay + 4.0, 44.0, 8.0), Color("#FFE7A8"))
		fx += 300.0
	if _glow != null:
		draw_texture_rect(_glow, Rect2(b.position.x, ay - 150.0, b.size.x, 150.0), false, Color(1, 1, 1, 0.9))
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
