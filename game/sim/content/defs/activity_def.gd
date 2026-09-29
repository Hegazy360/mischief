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
## Micro-gag beats (GDD §2.1; TECH §4.3 as amended by D1), parallel arrays in list order: id, `at_s` from
## the activity's start (ticks), clip length (frames), emote ("" = none). The legacy form (a list of id
## strings) spreads them at 2.0 + 6·i s, 48 f, no emote.
var mg_ids: PackedStringArray = PackedStringArray()
var mg_at: PackedInt32Array = PackedInt32Array()
var mg_len: PackedInt32Array = PackedInt32Array()
var mg_emote: PackedStringArray = PackedStringArray()
## The list repeats every `mg_cycle` ticks while the activity keeps performing (default: last at + 6 s).
var mg_cycle: int = 0
## True when `micro_gags` used the legacy string-list form.
var mg_legacy: bool = false
## Schema problems found while parsing `micro_gags` (ContentValidate reports them).
var mg_errors: PackedStringArray = PackedStringArray()
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
	a._parse_micro_gags(d)
	return a


## Legacy micro-gag spacing: the i-th id plays at 2.0 + 6·i s for 48 frames with no emote.
const MG_LEGACY_FIRST_S := 2.0
const MG_LEGACY_EVERY_S := 6.0
const MG_LEGACY_LEN_F := 48
## Default cycle: the last beat's at_s plus this.
const MG_CYCLE_PAD_S := 6.0


func _parse_micro_gags(d: Dictionary) -> void:
	var raw: Variant = d.get("micro_gags", null)
	if raw == null:
		return
	if typeof(raw) != TYPE_ARRAY:
		mg_errors.append("micro_gags must be a list")
		return
	var i := 0
	for e in raw:
		match typeof(e):
			TYPE_STRING:
				mg_legacy = true
				mg_ids.append(str(e))
				mg_at.append(Fx.ticks(MG_LEGACY_FIRST_S + MG_LEGACY_EVERY_S * i))
				mg_len.append(MG_LEGACY_LEN_F)
				mg_emote.append("")
			TYPE_DICTIONARY:
				var g: Dictionary = e
				var gid := ContentUtil.s(g, "id")
				if gid == "":
					mg_errors.append("micro_gags[%d] has no id" % i)
				if g.get("at_s", null) == null:
					mg_errors.append("micro_gags[%d] (%s) has no at_s" % [i, gid])
				var em: Variant = g.get("emote", null)
				var em_s := "" if em == null else str(em)
				if em_s != "" and not SimEvents.EMOTES.has(em_s):
					mg_errors.append("micro_gags[%d] (%s) emote '%s' not in %s" % [i, gid, em_s, ", ".join(SimEvents.EMOTES)])
				mg_ids.append(gid)
				mg_at.append(maxi(1, Fx.ticks(ContentUtil.f(g, "at_s", MG_LEGACY_FIRST_S))))
				mg_len.append(maxi(1, ContentUtil.i(g, "len_f", MG_LEGACY_LEN_F)))
				mg_emote.append(em_s)
			_:
				mg_errors.append("micro_gags[%d] must be an id string or {id, at_s, len_f, emote}" % i)
		i += 1
	for k in range(1, mg_at.size()):
		if mg_at[k] <= mg_at[k - 1]:
			mg_errors.append("micro_gags[%d] (%s) at_s must be after the previous beat's" % [k, mg_ids[k]])
	if mg_at.is_empty():
		return
	var last := mg_at[mg_at.size() - 1]
	if d.get("mg_cycle_s", null) != null:
		mg_cycle = Fx.ticks(ContentUtil.f(d, "mg_cycle_s"))
		if mg_cycle <= last:
			mg_errors.append("mg_cycle_s %.2f must be greater than the last at_s" % ContentUtil.f(d, "mg_cycle_s"))
			mg_cycle = last + Fx.ticks(MG_CYCLE_PAD_S)
	else:
		mg_cycle = last + Fx.ticks(MG_CYCLE_PAD_S)


## Number of micro-gag beats.
func mg_count() -> int:
	return mg_ids.size()


## Index of the micro-gag due at PERFORM tick `t` (1-based activity clock; the list repeats every
## `mg_cycle`), −1 if none. Pure; no allocation.
func mg_due(t: int) -> int:
	if mg_cycle <= 0 or t <= 0:
		return -1
	var pos := t % mg_cycle
	for k in mg_at.size():
		if mg_at[k] == pos:
			return k
	return -1


## Number of USE hooks.
func hook_count() -> int:
	return hooks.size() >> 1
