## LinkDef — a doorway (always open, shared x), a door (open/close time) or the stairs (TECH §3.3, §4.1).
class_name LinkDef
extends RefCounted

const DOORWAY := 0
const DOOR := 1
const STAIRS := 2
const KIND_NAMES: Array[String] = ["doorway", "door", "stairs"]

var id: String = ""
var idx: int = -1
var kind: int = DOORWAY
var kind_name: String = "doorway"
var a: String = ""
var b: String = ""
var a_idx: int = -1
var b_idx: int = -1
## Shared x (doorway/door), sub-px.
var x_sub: int = 0
## Stairs ends (room a at ax, room b at bx), sub-px.
var ax_sub: int = 0
var bx_sub: int = 0
## Traversal ticks per mover (doors: open/close; stairs: climb).
var hush_ticks: int = 0
var bellows_ticks: int = 0
var art: String = ""


## Parse a house.json link entry.
static func from_dict(d: Dictionary) -> LinkDef:
	var l := LinkDef.new()
	l.id = ContentUtil.s(d, "id")
	l.kind_name = ContentUtil.s(d, "kind", "doorway")
	l.kind = KIND_NAMES.find(l.kind_name)
	l.a = ContentUtil.s(d, "a")
	l.b = ContentUtil.s(d, "b")
	l.x_sub = Fx.px(ContentUtil.f(d, "x"))
	l.ax_sub = Fx.px(ContentUtil.f(d, "ax", ContentUtil.f(d, "x")))
	l.bx_sub = Fx.px(ContentUtil.f(d, "bx", ContentUtil.f(d, "x")))
	l.art = ContentUtil.s(d, "art")
	match l.kind:
		STAIRS:
			l.hush_ticks = Fx.ticks(ContentUtil.f(d, "hush_s", SimConst.HUSH_STAIRS_TICKS / 60.0))
			l.bellows_ticks = Fx.ticks(ContentUtil.f(d, "bellows_s", SimConst.B_STAIRS_TICKS / 60.0))
		DOOR:
			l.hush_ticks = Fx.ticks(ContentUtil.f(d, "hush_s", SimConst.HUSH_DOOR_TICKS / 60.0))
			l.bellows_ticks = Fx.ticks(ContentUtil.f(d, "bellows_s", SimConst.B_DOOR_TICKS / 60.0))
		_:
			l.hush_ticks = 0
			l.bellows_ticks = 0
	return l


## The x of this link's end in room `room_idx` (sub-px).
func x_in(room_idx: int) -> int:
	if kind == STAIRS:
		return ax_sub if room_idx == a_idx else bx_sub
	return x_sub


## The room on the other side of `room_idx` (-1 if the link doesn't touch it).
func other(room_idx: int) -> int:
	if room_idx == a_idx:
		return b_idx
	if room_idx == b_idx:
		return a_idx
	return -1
