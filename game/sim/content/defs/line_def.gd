## LineDef — one Script line (TECH §4.6, §3.7.7; GDD §6.2).
class_name LineDef
extends RefCounted

const K_PRANK := 0
const K_DOUBLE_ACT := 1
const K_COMBO := 2
const K_MELTDOWN := 3
const K_CHASE_TRIP := 4
const K_CHAIN := 5
## Stage-3 kinds (loaded, reported by validate_warnings(), never done in Stage 1).
const K_PANTO := 6
const K_WITNESS := 7
const K_HERD := 8
const K_PRANK_WITNESSED := 9
const K_COMBO_WITNESSED := 10
const KIND_NAMES: Array[String] = ["prank", "double_act", "combo", "meltdown", "chase_trip", "chain",
	"panto", "witness", "herd", "prank_witnessed", "combo_witnessed"]
const STAGE3_FIRST := K_PANTO

var id: String = ""
var idx: int = -1
var kind: int = -1
var kind_name: String = ""
var prank: String = ""
var double_act: String = ""
var combo: String = ""
var count: int = 1
var link: int = 0
var req: bool = false
var big_number: bool = false
var text: String = ""
var hint: Dictionary = {}
## Big Number: landed pranks that become riggable again when it unseals (MIRROR, MIRROR's TIME'S UP).
var rearm_on_unseal: PackedStringArray = PackedStringArray()
## Derived (prank lines only): Applause base in tenths; all prank lines sum to exactly 700.
var base_tenths: int = 0


## Parse an episode script entry.
static func from_dict(d: Dictionary) -> LineDef:
	var l := LineDef.new()
	l.id = ContentUtil.s(d, "id")
	l.kind_name = ContentUtil.s(d, "kind", "prank")
	l.kind = KIND_NAMES.find(l.kind_name)
	l.prank = ContentUtil.s(d, "prank")
	l.double_act = ContentUtil.s(d, "double_act")
	l.combo = ContentUtil.s(d, "combo")
	l.count = maxi(1, ContentUtil.i(d, "count", 1))
	l.link = ContentUtil.i(d, "link", 0)
	l.req = ContentUtil.b(d, "req")
	l.big_number = ContentUtil.b(d, "big_number")
	l.text = ContentUtil.s(d, "text")
	l.hint = ContentUtil.dict(d, "hint")
	l.rearm_on_unseal = ContentUtil.strs(d, "rearm_on_unseal")
	return l


## True for the Stage-3 kinds.
func is_stage3() -> bool:
	return kind >= STAGE3_FIRST
