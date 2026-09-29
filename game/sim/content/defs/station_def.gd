## StationDef — where Bellows stands for an activity or a fix-up (TECH §4.1, §14).
class_name StationDef
extends RefCounted

var id: String = ""
var idx: int = -1
var room: String = ""
var room_idx: int = -1
## Prop x and stand x, sub-px.
var x_sub: int = 0
var stand_sub: int = 0
var facing: int = 1
## Fix-up kinds this station serves (DRY, SINK, HONEY, MIRROR).
var kinds: PackedStringArray = PackedStringArray()
## Mirror frame x (sub-px), -1 if none.
var frame_sub: int = -1


## Parse a house.json station entry.
static func from_dict(d: Dictionary) -> StationDef:
	var s := StationDef.new()
	s.id = ContentUtil.s(d, "id")
	s.room = ContentUtil.s(d, "room")
	s.x_sub = Fx.px(ContentUtil.f(d, "x"))
	s.stand_sub = Fx.px(ContentUtil.f(d, "stand_x", ContentUtil.f(d, "x")))
	s.facing = 1 if ContentUtil.i(d, "facing", 1) >= 0 else -1
	s.kinds = ContentUtil.strs(d, "kinds")
	s.frame_sub = Fx.px(ContentUtil.f(d, "frame_x")) if d.get("frame_x", null) != null else -1
	return s
