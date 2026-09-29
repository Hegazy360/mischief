## ActivityDef — one routine activity or detour (TECH §4.3, GDD §4.1.1).
class_name ActivityDef
extends RefCounted

const AWARE_NORMAL := 0
const AWARE_ABSORBED := 1
const AWARE_ASLEEP := 2
const AWARE_BLIND := 3
## "searching" (the Prologue hunt, or `"searching": true`): normal sight, specs on, looks both ways.
const AWARE_SEARCHING := 4
const AWARE_NAMES: Array[String] = ["normal", "absorbed", "asleep", "blind", "searching"]
const DETOUR_IDS: Array[String] = ["fixup_dry", "fixup_sink", "fixup_honey", "fixup_mirror", "curious", "herd_beryl", "search"]

var id: String = ""
var idx: int = -1
var station: String = ""
var station_idx: int = -1
var dur_ticks: int = 0
## 0 = use the station's facing.
var facing: int = 0
var specs: bool = false
var awareness: int = AWARE_NORMAL
var awareness_name: String = "normal"
var squeak_bit: String = ""
var panto: bool = false
var bend: bool = false
## Hiding spot this activity opens ("" = none).
var in_use: String = ""
var in_use_idx: int = -1
var bar: String = ""
var clip: String = ""
var icon: String = ""
## Walked path [x0, x1] in sub-px during PERFORM (stroll), empty if none.
var path: PackedInt32Array = PackedInt32Array()
## True for detour entries (fixup_*, curious, search, herd_beryl).
var is_detour: bool = false
## Detours: the fix-up kind they serve (DRY, SINK, HONEY, MIRROR) and their hook mark (ticks, -1 = default).
var fixup_kind: String = ""
var mark_ticks: int = -1
## Derived: USE hooks on this activity, [mark_ticks, prank_idx] pairs flattened, sorted by mark then prank id.
var hooks: PackedInt32Array = PackedInt32Array()


## Parse an activities.json entry.
static func from_dict(act_id: String, d: Dictionary) -> ActivityDef:
	var a := ActivityDef.new()
	a.id = act_id
	a.station = ContentUtil.s(d, "station")
	a.dur_ticks = Fx.ticks(ContentUtil.f(d, "dur_s", 0.0))
	a.facing = Fx.signi(ContentUtil.i(d, "facing", 0))
	a.specs = ContentUtil.b(d, "specs")
	a.awareness_name = ContentUtil.s(d, "awareness", "normal")
	a.awareness = maxi(0, AWARE_NAMES.find(a.awareness_name))
	a.squeak_bit = ContentUtil.s(d, "squeak_bit")
	a.panto = ContentUtil.b(d, "panto")
	a.bend = ContentUtil.b(d, "bend")
	a.in_use = ContentUtil.s(d, "in_use")
	a.bar = ContentUtil.s(d, "bar")
	a.clip = ContentUtil.s(d, "clip")
	a.icon = ContentUtil.s(d, "icon")
	var p := ContentUtil.arr(d, "path")
	if p.size() >= 2:
		a.path = PackedInt32Array([Fx.px(float(p[0])), Fx.px(float(p[1]))])
	var pd := ContentUtil.dict(d, "path")
	if pd.has("from_x") and pd.has("to_x"):
		a.path = PackedInt32Array([Fx.px(ContentUtil.f(pd, "from_x")), Fx.px(ContentUtil.f(pd, "to_x"))])
	if ContentUtil.b(d, "searching") and a.awareness == AWARE_NORMAL:
		a.awareness = AWARE_SEARCHING
	if ContentUtil.b(d, "eyes_shut") and a.awareness == AWARE_NORMAL:
		a.awareness = AWARE_BLIND
	a.is_detour = DETOUR_IDS.has(act_id)
	a.fixup_kind = ContentUtil.s(d, "kind")
	a.mark_ticks = Fx.ticks(ContentUtil.f(d, "mark_s")) if d.get("mark_s", null) != null else -1
	return a


## Number of USE hooks.
func hook_count() -> int:
	return hooks.size() >> 1
