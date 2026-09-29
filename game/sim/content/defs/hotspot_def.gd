## HotspotDef — a tappable thing: container, hiding spot, rig point, exit, stairs or door (TECH §4.1).
class_name HotspotDef
extends RefCounted

const CONTAINER := 0
const HIDING := 1
const RIG_POINT := 2
const EXIT := 3
const STAIRS := 4
const DOOR := 5
const KIND_NAMES: Array[String] = ["container", "hiding", "rig_point", "exit", "stairs", "door"]

var id: String = ""
var idx: int = -1
var kind_name: String = ""
var kind: int = -1
var room: String = ""
var room_idx: int = -1
## Use point (where Hush stands), sub-px.
var use_sub: int = 0
## Facing on arrival (0 = keep / face the station).
var facing: int = 0
## Hit box [x, y, w, h] in world px (y relative to the floor line).
var rect: Array = []
## Activity id that opens this hiding spot ("" = never).
var in_use_by: String = ""
## Station this rig point belongs to ("" = none).
var station: String = ""
var station_idx: int = -1
## Link for stairs/door hotspots.
var link: String = ""
var link_idx: int = -1
## False for set dressing Hush can't tap (the kitchen window she climbs in through).
var tappable: bool = true
## Entry name (house.json `entries`) this hotspot stands for ("" = none).
var entry: String = ""
var art: Dictionary = {}


## Parse a house.json hotspot entry.
static func from_dict(d: Dictionary) -> HotspotDef:
	var h := HotspotDef.new()
	h.id = ContentUtil.s(d, "id")
	h.kind_name = ContentUtil.s(d, "kind")
	h.kind = KIND_NAMES.find(h.kind_name)
	h.room = ContentUtil.s(d, "room")
	h.use_sub = Fx.px(ContentUtil.f(d, "use_x"))
	h.facing = Fx.signi(ContentUtil.i(d, "facing", 0))
	h.rect = ContentUtil.arr(d, "rect")
	h.in_use_by = ContentUtil.s(d, "in_use_by")
	h.station = ContentUtil.s(d, "station")
	h.link = ContentUtil.s(d, "link")
	h.tappable = ContentUtil.b(d, "tappable", true)
	h.entry = ContentUtil.s(d, "entry")
	h.art = ContentUtil.dict(d, "art")
	return h
