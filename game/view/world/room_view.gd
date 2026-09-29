## RoomView — one room of the cut-away house (TECH §5.4). Background layer (walls, windows,
## floorboards, slab) from `house.json` art (`art.bg`, owner `art-house`) or a greybox drawn
## from the room's wallpaper colour; the foreground layer (`art.fg`: door jambs, slab lip —
## whatever must occlude characters) is a separate node the WorldView puts above them.
## Locked rooms (not in tonight's episode) are an unlit set: dimmed to ~30 % with a
## blue-grey tint. Greybox drawing is rects and lines only (batched: ~1–2 draw calls).
class_name RoomView
extends Node2D

## Unlit-set modulate (≈ 30 % brightness, blue-grey).
const LOCKED_MODULATE := Color(0.30, 0.33, 0.44)
const INTERIOR_H := 640.0
const SLAB_H := 60.0
const DOOR_W := 170.0
const DOOR_H := 430.0
const ARCH := Color("#3A3050")
const OAK := Color("#C98B55")
const OAK_DARK := Color("#A96C3C")

var room: HouseLayout.Room = null
var layout: HouseLayout = null
var locked: bool = false
var bg: Sprite2D = null
var fg: Node2D = null
var _door_xs: PackedFloat32Array = PackedFloat32Array()
var _door_kinds: PackedStringArray = PackedStringArray()


func _init() -> void:
	z_index = -20


## Build for `r`. `fg_parent` receives the foreground node (above the characters).
func setup(r: HouseLayout.Room, house: HouseLayout, is_locked: bool, fg_parent: Node2D) -> void:
	room = r
	layout = house
	locked = is_locked
	name = "Room_" + r.id
	position = Vector2(r.x0, house.floor_y(r.floor))
	for l in house.links_of(r.id):
		if l.kind == "stairs":
			continue
		_door_xs.append(l.x - r.x0)
		_door_kinds.append(l.kind)
	var bt := ViewKit.tex(r.art_bg)
	if bt != null:
		bg = Sprite2D.new()
		bg.texture = bt
		bg.centered = false
		bg.position = Vector2(0, -INTERIOR_H)
		add_child(bg)
	var ft := ViewKit.tex(r.art_fg)
	if ft != null and fg_parent != null:
		var s := Sprite2D.new()
		s.texture = ft
		s.centered = false
		s.position = position + Vector2(0, -INTERIOR_H)
		s.z_index = 8
		s.name = "Fg_" + r.id
		fg_parent.add_child(s)
		fg = s
	set_locked(is_locked)
	queue_redraw()


func set_locked(on: bool) -> void:
	locked = on
	modulate = LOCKED_MODULATE if on else Color.WHITE
	if fg != null:
		fg.modulate = modulate


func width() -> float:
	return room.width() if room != null else 1000.0


func _draw() -> void:
	if room == null or bg != null:
		return
	var w := width()
	if room.outdoor:
		_draw_outdoor(w)
		return
	var wall := room.wallpaper
	var wall_dk := wall.darkened(0.12)
	var wall_lt := wall.lightened(0.10)
	# Wall + wallpaper stripes.
	draw_rect(Rect2(0, -INTERIOR_H, w, INTERIOR_H), wall)
	var sx := 40.0
	while sx < w:
		draw_rect(Rect2(sx, -INTERIOR_H + 60, 18, INTERIOR_H - 200), wall_lt)
		sx += 80.0
	# Cornice + picture rail + wainscot.
	draw_rect(Rect2(0, -INTERIOR_H, w, 44), wall_dk.darkened(0.1))
	draw_rect(Rect2(0, -INTERIOR_H + 44, w, 8), Color("#FFF4E0", 0.7))
	draw_rect(Rect2(0, -150, w, 118), wall_dk)
	draw_rect(Rect2(0, -150, w, 7), wall_lt)
	# Skirting board.
	draw_rect(Rect2(0, -32, w, 32), Color("#F3EAD6"))
	draw_rect(Rect2(0, -32, w, 4), ARCH.lightened(0.3))
	# Windows (flavour): one per 450 px of wall away from doorways.
	var wx := 180.0
	while wx < w - 180.0:
		if _clear_of_doors(wx, 200.0):
			_draw_window(Vector2(wx, -470))
			wx += 450.0
		else:
			wx += 90.0
	# Doorway openings (darker recess) at links.
	for i in _door_xs.size():
		var dx := _door_xs[i]
		var half := DOOR_W * 0.5
		var x0 := clampf(dx - half, -half, w)
		draw_rect(Rect2(x0, -DOOR_H, DOOR_W, DOOR_H), Color(0.16, 0.13, 0.2, 0.55))
		draw_rect(Rect2(x0 - 10, -DOOR_H - 14, DOOR_W + 20, 14), OAK_DARK)
	# Floorboards and the slab.
	draw_rect(Rect2(0, 0, w, 16), OAK)
	var bx := 0.0
	var k := 0
	while bx < w:
		draw_rect(Rect2(bx, 0, 2, 16), OAK_DARK)
		bx += 120.0 + float((k * 37) % 50)
		k += 1
	draw_rect(Rect2(0, 16, w, SLAB_H - 16), Color("#4A3B5C"))
	draw_rect(Rect2(0, 16, w, 5), Color("#5E4C72"))
	# Architecture lines (3 px, 80 %).
	var ink := Color(ARCH, 0.8)
	draw_line(Vector2(0, -INTERIOR_H), Vector2(w, -INTERIOR_H), ink, 3.0)
	draw_line(Vector2(0, 0), Vector2(w, 0), ink, 3.0)
	draw_line(Vector2(0, -INTERIOR_H), Vector2(0, 0), ink, 3.0)
	draw_line(Vector2(w, -INTERIOR_H), Vector2(w, 0), ink, 3.0)


func _draw_outdoor(w: float) -> void:
	draw_rect(Rect2(0, -INTERIOR_H, w, INTERIOR_H * 0.55), Color("#9FD6F0"))
	draw_rect(Rect2(0, -INTERIOR_H * 0.45, w, INTERIOR_H * 0.45), Color("#BFE6F5"))
	# Hedge band + lawn.
	draw_rect(Rect2(0, -170, w, 150), Color("#4E9A4A"))
	var hx := 0.0
	while hx < w:
		draw_rect(Rect2(hx + 10, -190, 90, 30), Color("#5CAF57"))
		hx += 120.0
	draw_rect(Rect2(0, -24, w, 24), Color("#8ACB6A"))
	draw_rect(Rect2(0, 0, w, 16), Color("#7BB85C"))
	draw_rect(Rect2(0, 16, w, SLAB_H - 16), Color("#5B4A3A"))
	# Clouds.
	draw_rect(Rect2(w * 0.2, -560, 160, 34), Color("#FFFFFF", 0.8))
	draw_rect(Rect2(w * 0.2 + 40, -588, 90, 30), Color("#FFFFFF", 0.8))
	draw_rect(Rect2(w * 0.65, -500, 130, 30), Color("#FFFFFF", 0.7))


func _draw_window(c: Vector2) -> void:
	var r := Rect2(c.x - 90, c.y - 110, 180, 220)
	draw_rect(r.grow(12), Color("#F3EAD6"))
	draw_rect(r, Color("#9FD6F0"))
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.55, r.size.x, r.size.y * 0.45), Color("#BFE6F5"))
	draw_rect(Rect2(c.x - 4, r.position.y, 8, r.size.y), Color("#F3EAD6"))
	draw_rect(Rect2(r.position.x, c.y - 4, r.size.x, 8), Color("#F3EAD6"))
	draw_rect(Rect2(r.position.x - 24, r.end.y + 10, r.size.x + 48, 14), Color("#F3EAD6"))
	var ink := Color(ARCH, 0.8)
	draw_line(r.position - Vector2(12, 12), Vector2(r.end.x + 12, r.position.y - 12), ink, 3.0)
	draw_line(Vector2(r.position.x - 12, r.end.y + 12), r.end + Vector2(12, 12), ink, 3.0)
	draw_line(r.position - Vector2(12, 12), Vector2(r.position.x - 12, r.end.y + 12), ink, 3.0)
	draw_line(Vector2(r.end.x + 12, r.position.y - 12), r.end + Vector2(12, 12), ink, 3.0)


func _clear_of_doors(x: float, half: float) -> bool:
	for dx in _door_xs:
		if absf(dx - x) < half + DOOR_W:
			return false
	return true
