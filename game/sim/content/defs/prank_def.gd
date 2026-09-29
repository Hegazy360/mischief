## PrankDef — one prank: rig steps, trigger, conditions, reaction, knock-on, residue (TECH §4.4, GDD §5).
class_name PrankDef
extends RefCounted

const SIZE_S := 0
const SIZE_M := 1
const SIZE_L := 2
const SIZE_SIG := 3
const SIZE_NAMES: Array[String] = ["S", "M", "L", "SIG"]

const TRIG_USE := 0
const TRIG_STEP := 1
const TRIG_QUAKE := 2
const TRIG_THIRD_PARTY := 3
const TRIG_KNOCK_ON_ONLY := 4
const TRIG_NAMES: Array[String] = ["use", "step", "quake", "third_party", "knock_on_only"]

## STEP direction filter.
const DIR_ANY := 0
const DIR_UP := 1
const DIR_DOWN := 2
const DIR_LEFT := 3
const DIR_RIGHT := 4
const DIR_NAMES: Array[String] = ["", "up", "down", "left", "right"]


## One rig step (TECH §4.4).
class Step:
	extends RefCounted
	## "Q" | "S" | "B"
	var prep: String = "Q"
	var prep_ticks: int = SimConst.PREP_Q
	## Needed item id ("" = free).
	var needs: String = ""
	## Derived: the container `needs` comes from (`items.json source`; "" when none).
	var needs_src: String = ""
	## Rig point hotspot of this step (defaults to the prank's rig_point).
	var at: String = ""
	var at_idx: int = -1
	## Step conditions (Stage-3 kinds such as beryl_within).
	var conditions: Array = []
	var fx: String = ""


var id: String = ""
var idx: int = -1
var caption: String = ""
var size: int = SIZE_M
var size_name: String = "M"
var rig_point: String = ""
var rig_idx: int = -1
var steps: Array[Step] = []

var trig_type: int = TRIG_USE
var trig_name: String = "use"
var trig_activity: String = ""
var trig_mark_ticks: int = 0
var trig_resume: bool = false
var trig_fixup_kinds: PackedStringArray = PackedStringArray()
## STEP: hotspot walked over (the `fire_at` one when `at` lists several), direction, fires in chases.
var trig_at: String = ""
var trig_at_idx: int = -1
## STEP: every hotspot listed in `at` (PENNY PINCHER's coins); the prank fires at `trig_at`.
var trig_at_list: PackedStringArray = PackedStringArray()
var trig_dir: int = DIR_ANY
var trig_chase: bool = false
## QUAKE: room.
var trig_room: String = ""
## THIRD_PARTY: actor + event (Stage 3).
var trig_actor: String = ""
var trig_event: String = ""

## Condition entries (AND of all).
var conditions: Array = []
## Fizzle definition (null = none).
var fizzle: Variant = null

var archetype: String = ""
var variants: PackedStringArray = PackedStringArray()
## Reaction end position: room id ("" = stays where he is) and x (sub-px).
var end_room: String = ""
var end_x_sub: int = -1
var end_landing: String = ""

## Knock-on: into a rigged prank at a frame, or the Stage-3 headbutt.
var knock_prank: String = ""
var knock_frame: int = -1
var knock_headbutt: bool = false
var knock_requires: Dictionary = {}

## Residues added at reaction end: [{kind, blind, blind_ticks}].
var residue: Array = []
## Residue kinds this prank clears (MIRROR, MIRROR: he fled) — `clears` or `residue_clear`.
var clears: PackedStringArray = PackedStringArray()
## Stand-in round lengths (`stand_in.rounds_f`, empty = SimConst.MIRROR_ROUNDS) and the poke window.
var stand_rounds: PackedInt32Array = PackedInt32Array()
var stand_poke: int = -1
## Timed blindness after the reaction (BLINDED 15 s), 0 = none.
var blind_ticks: int = 0
var tags: PackedStringArray = PackedStringArray()
var nights: PackedStringArray = PackedStringArray()


## Parse a pranks.json entry.
static func from_dict(prank_id: String, d: Dictionary) -> PrankDef:
	var p := PrankDef.new()
	p.id = prank_id
	p.caption = ContentUtil.s(d, "caption", prank_id)
	p.size_name = ContentUtil.s(d, "size", "M")
	p.size = SIZE_NAMES.find(p.size_name)
	p.rig_point = ContentUtil.s(d, "rig_point")
	for sd in ContentUtil.arr(d, "steps"):
		if typeof(sd) != TYPE_DICTIONARY:
			continue
		var st := Step.new()
		st.prep = ContentUtil.s(sd, "prep", "Q")
		st.prep_ticks = SimConst.prep_ticks(st.prep)
		st.needs = ContentUtil.s(sd, "needs")
		st.at = ContentUtil.s(sd, "at", p.rig_point)
		st.conditions = ContentUtil.arr(sd, "conditions")
		st.fx = ContentUtil.s(sd, "fx")
		p.steps.append(st)
	var t := ContentUtil.dict(d, "trigger")
	p.trig_name = ContentUtil.s(t, "type", "use")
	p.trig_type = TRIG_NAMES.find(p.trig_name)
	p.trig_activity = ContentUtil.s(t, "activity")
	p.trig_mark_ticks = Fx.ticks(ContentUtil.f(t, "mark_s", 0.0))
	p.trig_resume = ContentUtil.b(t, "resume")
	p.trig_fixup_kinds = ContentUtil.strs(t, "fixup_kinds")
	p.trig_at_list = ContentUtil.strs(t, "at")
	p.trig_at = ContentUtil.s(t, "fire_at", p.trig_at_list[p.trig_at_list.size() - 1] if p.trig_at_list.size() > 0 else "")
	p.trig_dir = maxi(0, DIR_NAMES.find(ContentUtil.s(t, "dir")))
	p.trig_chase = ContentUtil.b(t, "chase")
	p.trig_room = ContentUtil.s(t, "room")
	p.trig_actor = ContentUtil.s(t, "actor")
	p.trig_event = ContentUtil.s(t, "event")
	p.conditions = ContentUtil.arr(d, "conditions")
	p.fizzle = d.get("fizzle", null)
	var rx := ContentUtil.dict(d, "reaction")
	p.archetype = ContentUtil.s(rx, "archetype")
	p.variants = ContentUtil.strs(rx, "variants")
	var end := ContentUtil.dict(rx, "end")
	if not end.is_empty():
		p.end_room = ContentUtil.s(end, "room")
		p.end_landing = ContentUtil.s(end, "landing")
		p.end_x_sub = Fx.px(ContentUtil.f(end, "x")) if end.get("x", null) != null else -1
	var ko := ContentUtil.dict(d, "knock_on")
	if not ko.is_empty():
		p.knock_prank = ContentUtil.s(ko, "prank")
		p.knock_frame = ContentUtil.i(ko, "frame", -1)
		p.knock_headbutt = ContentUtil.b(ko, "headbutt")
		p.knock_requires = ContentUtil.dict(ko, "requires")
	for rd in ContentUtil.arr(d, "residue"):
		if typeof(rd) == TYPE_DICTIONARY:
			p.residue.append({"kind": ContentUtil.s(rd, "kind"), "blind": ContentUtil.b(rd, "blind"),
				"blind_ticks": Fx.ticks(ContentUtil.f(rd, "blind_s", 0.0))})
		elif typeof(rd) == TYPE_STRING:
			p.residue.append({"kind": str(rd), "blind": false, "blind_ticks": 0})
	p.clears = ContentUtil.strs(d, "clears")
	if p.clears.is_empty():
		p.clears = ContentUtil.strs(d, "residue_clear")
	var si := ContentUtil.dict(d, "stand_in")
	for r in ContentUtil.arr(si, "rounds_f"):
		p.stand_rounds.append(roundi(float(r)))
	p.stand_poke = ContentUtil.i(si, "poke_window_f", -1)
	p.blind_ticks = Fx.ticks(ContentUtil.f(d, "blind_s", 0.0))
	p.tags = ContentUtil.strs(d, "tags")
	p.nights = ContentUtil.strs(d, "nights")
	return p


## True when a fizzle is defined.
func has_fizzle() -> bool:
	return fizzle != null and not (typeof(fizzle) == TYPE_BOOL and not fizzle)


## Number of rig steps (at least 1 for a well-formed prank).
func step_count() -> int:
	return steps.size()
