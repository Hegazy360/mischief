## DoubleActDef — an authored knock-on A → B (TECH §4.4, GDD §5.5).
class_name DoubleActDef
extends RefCounted

var id: String = ""
var idx: int = -1
var a: String = ""
var b: String = ""
var caption: String = ""
## Stage-3 headbutt Double Act (A's knock-on is Beryl's headbutt; no B prank).
var headbutt: bool = false


## Parse a pranks.json double_acts entry.
static func from_dict(da_id: String, d: Dictionary) -> DoubleActDef:
	var x := DoubleActDef.new()
	x.id = da_id
	x.a = ContentUtil.s(d, "a")
	x.b = ContentUtil.s(d, "b")
	x.caption = ContentUtil.s(d, "caption", da_id)
	x.headbutt = ContentUtil.b(d, "headbutt")
	return x
