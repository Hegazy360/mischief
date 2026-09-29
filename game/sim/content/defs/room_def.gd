## RoomDef — one room: a 1-D segment [x0, x1] on a floor (TECH §3.3, §4.1).
class_name RoomDef
extends RefCounted

var id: String = ""
## Interned index (position in the sorted id list).
var idx: int = -1
var floor: int = 0
## Floor line y in px (0 ground, -700 upper).
var floor_y: int = 0
var x0: int = 0
var x1: int = 0
## x0/x1 in sub-pixels.
var x0_sub: int = 0
var x1_sub: int = 0
var outdoor: bool = false
var wallpaper: String = ""
var art: Dictionary = {}


## Parse a house.json room entry.
static func from_dict(d: Dictionary) -> RoomDef:
	var r := RoomDef.new()
	r.id = ContentUtil.s(d, "id")
	r.floor = ContentUtil.i(d, "floor")
	r.x0 = ContentUtil.i(d, "x0")
	r.x1 = ContentUtil.i(d, "x1")
	r.x0_sub = Fx.px(ContentUtil.f(d, "x0"))
	r.x1_sub = Fx.px(ContentUtil.f(d, "x1"))
	r.outdoor = ContentUtil.b(d, "outdoor")
	r.wallpaper = ContentUtil.s(d, "wallpaper")
	r.art = ContentUtil.dict(d, "art")
	return r
