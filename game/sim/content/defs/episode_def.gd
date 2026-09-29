## EpisodeDef — one Night (TECH §4.6, GDD §7.2).
class_name EpisodeDef
extends RefCounted


## One loop entry: an activity plus an optional player-led gate (GDD §4.1).
class LoopEntry:
	extends RefCounted
	var activity: String = ""
	var act_idx: int = -1
	var has_gate: bool = false
	## "first_squeak" | "first_rig" | "rigged:<prank>" | a Conditions dictionary.
	var until: Variant = null
	var plus_ticks: int = 0
	## -1 = no cap.
	var max_ticks: int = -1
	var first_loop_only: bool = false


var id: String = ""
var act: int = 1
var index: int = 0
var title: String = ""
var status: String = "draft"
var seed: int = 1
var rooms: PackedStringArray = PackedStringArray()
var entry: String = ""
var rules: Dictionary = {}
var spot_fill_s: float = 1.0
## -1 = unlimited.
var tomatoes: int = -1
var cant_fail: bool = false
var nerves: bool = false
var new_rule: String = ""
var card: Dictionary = {}
var cold_open: Dictionary = {}
var hush_room: String = ""
var hush_x_sub: int = 0
var bellows_room: String = ""
var bellows_x_sub: int = 0
var loop: Array[LoopEntry] = []
## residue kind or fix-up kind → station id
var fixup_overrides: Dictionary = {}
var script_lines: Array[LineDef] = []
## Raw director block ({} = none): gates, cues, safety_net, cant_fail, end_when, launch_offset_s.
var director: Dictionary = {}
var encores: Array = []
## Stars are awarded (rules.curtain_calls, default true; the Prologue sets false).
var curtain_calls: bool = true
## The loop repeats after its last activity (rules.loop_repeat, default true).
var loop_repeat: bool = true
## Opening-night nerves floor (points).
var nerves_temper: int = SimConst.NERVES_TEMPER
## Bellows' scripted exit: after activity `exit_after` he walks to (exit_room, exit_x_sub).
var exit_after: String = ""
var exit_room: String = ""
var exit_x_sub: int = 0
## Hush climbs in: busy (and out of sight) until this tick.
var hush_enter_ticks: int = 0
## Scripted end: a condition and its reason (director.end / director.end_when).
var end_when: Variant = null
var end_reason: String = "prologue_done"
## Stage-3 cast block (beryl / delphine; null entries = absent).
var cast: Dictionary = {}
## Raw JSON (for tools).
var raw: Dictionary = {}


## Parse an episodes/<id>.json file.
static func from_dict(d: Dictionary) -> EpisodeDef:
	var e := EpisodeDef.new()
	e.raw = d
	e.id = ContentUtil.s(d, "id")
	e.act = ContentUtil.i(d, "act", 1)
	e.index = ContentUtil.i(d, "index", 0)
	e.title = ContentUtil.s(d, "title")
	e.status = ContentUtil.s(d, "status", "draft")
	e.seed = ContentUtil.i(d, "seed", 1)
	e.rooms = ContentUtil.strs(d, "rooms")
	e.entry = ContentUtil.s(d, "entry")
	e.rules = ContentUtil.dict(d, "rules")
	var act_i := clampi(e.act, 0, SimConst.SPOT_FILL_S.size() - 1)
	e.spot_fill_s = ContentUtil.f(e.rules, "spot_fill_s", SimConst.SPOT_FILL_S[act_i])
	e.tomatoes = ContentUtil.i(e.rules, "tomatoes", -1)
	e.cant_fail = ContentUtil.b(e.rules, "cant_fail")
	e.nerves = ContentUtil.b(e.rules, "nerves")
	e.curtain_calls = ContentUtil.b(e.rules, "curtain_calls", true)
	e.loop_repeat = ContentUtil.b(e.rules, "loop_repeat", true)
	e.nerves_temper = ContentUtil.i(e.rules, "nerves_temper", SimConst.NERVES_TEMPER)
	e.new_rule = ContentUtil.s(d, "new_rule")
	e.card = ContentUtil.dict(d, "card")
	e.cold_open = ContentUtil.dict(d, "cold_open")
	var hd := ContentUtil.dict(d, "hush")
	var hen := ContentUtil.dict(hd, "enter")
	if not hen.is_empty():
		e.hush_enter_ticks = Fx.ticks(ContentUtil.f(hen, "at_s", 0.0) + ContentUtil.f(hen, "busy_s", 0.0))
	e.cast = ContentUtil.dict(d, "cast")
	var hs := ContentUtil.dict(hd, "start")
	e.hush_room = ContentUtil.s(hs, "room")
	e.hush_x_sub = Fx.px(ContentUtil.f(hs, "x"))
	var bd := ContentUtil.dict(d, "bellows")
	var bs := ContentUtil.dict(bd, "start")
	e.bellows_room = ContentUtil.s(bs, "room")
	e.bellows_x_sub = Fx.px(ContentUtil.f(bs, "x"))
	for le in ContentUtil.arr(bd, "loop"):
		var entry_d: Dictionary = le if typeof(le) == TYPE_DICTIONARY else {"a": str(le)}
		var l := LoopEntry.new()
		l.activity = ContentUtil.s(entry_d, "a", ContentUtil.s(entry_d, "activity"))
		var g := ContentUtil.dict(entry_d, "gate")
		if not g.is_empty():
			_apply_gate(l, g)
		e.loop.append(l)
	e.fixup_overrides = ContentUtil.dict(d, "fixup_overrides")
	for ld in ContentUtil.arr(d, "script"):
		if typeof(ld) == TYPE_DICTIONARY:
			var line := LineDef.from_dict(ld)
			line.idx = e.script_lines.size()
			e.script_lines.append(line)
	e.director = ContentUtil.dict(d, "director")
	var ex := ContentUtil.dict(bd, "exit")
	if ex.is_empty():
		ex = ContentUtil.dict(e.director, "exit")
	if not ex.is_empty():
		e.exit_after = ContentUtil.s(ex, "after")
		var to := ContentUtil.dict(ex, "to")
		e.exit_room = ContentUtil.s(to, "room")
		e.exit_x_sub = Fx.px(ContentUtil.f(to, "x"))
	e.end_when = e.director.get("end_when", null)
	var endd := ContentUtil.dict(e.director, "end")
	if not endd.is_empty():
		e.end_when = endd.get("when", null)
		e.end_reason = ContentUtil.s(endd, "reason", "prologue_done")
	if e.director.has("cant_fail"):
		e.cant_fail = e.cant_fail or ContentUtil.b(e.director, "cant_fail")
	# Director gates: [{"loop": i, "until": ..., "plus_s", "max_s", "first_loop_only"}] merge into the loop.
	for gd in ContentUtil.arr(e.director, "gates"):
		if typeof(gd) != TYPE_DICTIONARY:
			continue
		var at := -1
		for k in ["loop", "index", "at"]:
			if (gd as Dictionary).has(k):
				at = ContentUtil.i(gd, k, -1)
				break
		if at >= 0 and at < e.loop.size():
			var inner := ContentUtil.dict(gd, "gate")
			_apply_gate(e.loop[at], inner if not inner.is_empty() else gd)
	e.encores = ContentUtil.arr(d, "encores")
	return e


static func _apply_gate(l: LoopEntry, g: Dictionary) -> void:
	l.has_gate = true
	l.until = g.get("until", null)
	l.plus_ticks = Fx.ticks(ContentUtil.f(g, "plus_s", 0.0))
	l.max_ticks = Fx.ticks(ContentUtil.f(g, "max_s")) if g.get("max_s", null) != null else -1
	l.first_loop_only = ContentUtil.b(g, "first_loop_only")


## Line by id (null if none).
func line(line_id: String) -> LineDef:
	for l in script_lines:
		if l.id == line_id:
			return l
	return null
