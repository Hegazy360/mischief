## SimCtx — immutable per-episode data derived once in `SimWorld.create()` and shared by clones.
class_name SimCtx
extends RefCounted

var db: ContentDB = null
var episode: EpisodeDef = null
var relaxed: bool = false
var seed: int = 1
var act: int = 1
## Stars are not awarded (the Prologue, act 0).
var no_stars: bool = false
## Rooms Hush may enter (episode rooms + the porch doorstep), bit per room idx.
var hush_mask: int = 0
## "?" fill ticks (rules × relaxed, clamped ≥ 0.8 s except the Prologue's larger value).
var spot_fill: int = 60
## Face-to-face window ticks.
var f2f_ticks: int = SimConst.FACE_TO_FACE_TICKS
## −1 = unlimited.
var tomatoes_max: int = -1
var cant_fail: bool = false
var nerves: bool = false
## Doorstep (porch) where a caught Hush lands.
var doorstep_room: int = -1
var doorstep_x: int = 0
## Per prank idx: 1 when the prank belongs to this Night (Script lines, Double Acts, `nights`).
var prank_in_ep: PackedByteArray = PackedByteArray()
## Per prank idx: 1 when only the Big Number line references it (sealed until ★).
var prank_bn_only: PackedByteArray = PackedByteArray()
## Per prank idx: Applause base (tenths) from its prank line; 0 if none.
var prank_base: PackedInt32Array = PackedInt32Array()
## Per item idx: 1 when some prank of this Night needs it.
var item_in_ep: PackedByteArray = PackedByteArray()
## STEP and QUAKE pranks of this Night (prank idx, sorted).
var step_pranks: PackedInt32Array = PackedInt32Array()
var quake_pranks: PackedInt32Array = PackedInt32Array()
## Stand-in pranks (Mirror, Mirror) of this Night.
var stand_in_pranks: PackedInt32Array = PackedInt32Array()
## Big Number line idx (-1 none).
var bn_line: int = -1
## Director block pieces.
var cues: Array = []
## Per cue: `SimWorld.seen` keys its `when` needs (Conditions.required_seen_keys) — evaluated only once all exist.
var cue_req: Array[PackedStringArray] = []
## Per cue: 1 when its `when` depends on emitted events only (Conditions.is_event_only).
var cue_event_only: PackedByteArray = PackedByteArray()
var safety_net: Dictionary = {}
var end_when: Variant = null
var end_req: PackedStringArray = PackedStringArray()
var end_event_only: bool = false
var end_reason: String = "prologue_done"
## Nerves floor (q).
var nerves_q: int = SimConst.NERVES_TEMPER * SimConst.TEMPER_Q
## Hush is busy climbing in until this tick; the climb-in starts at `hush_enter_at`.
var hush_enter_ticks: int = 0
var hush_enter_at: int = 0
## Backstage rooms (bit per room idx): Bellows walks there, Hush never enters (`cmd_rejected {why: backstage}`).
var backstage_mask: int = 0
## Rooms whose stations may serve a fix-up: the Night's rooms + backstage (bit per room idx; −1 = any).
var fixup_mask: int = -1
## Per combo idx: 1 when `rules.combos` allows it (all 1 when the key is absent; all 0 for `[]`).
var combo_ok: PackedByteArray = PackedByteArray()
## `rules.senses` (false: Bellows never starts a "?" by sight or hearing and never catches — the Gate-0 scene).
var senses: bool = true
## Bellows' scripted exit (after an activity) and whether the loop repeats.
var exit_after: String = ""
var exit_room: int = -1
var exit_x: int = 0
var loop_repeat: bool = true


## Build for an episode.
static func build(p_db: ContentDB, ep: EpisodeDef, config: Dictionary) -> SimCtx:
	var c := SimCtx.new()
	c.db = p_db
	c.episode = ep
	c.relaxed = bool(config.get("relaxed", false))
	c.seed = int(config.get("seed", ep.seed))
	c.act = ep.act
	c.no_stars = ep.act == 0 or not ep.curtain_calls
	var fill := Fx.ticks(ep.spot_fill_s)
	if ep.act > 0:
		fill = maxi(fill, SimConst.SPOT_FILL_MIN)
	fill = maxi(1, fill)
	if c.relaxed:
		fill = Fx.mul_pct(fill, SimConst.RELAXED_PCT)
	c.spot_fill = fill
	c.f2f_ticks = Fx.mul_pct(SimConst.FACE_TO_FACE_TICKS, SimConst.RELAXED_PCT) if c.relaxed else SimConst.FACE_TO_FACE_TICKS
	c.tomatoes_max = -1 if c.relaxed else ep.tomatoes
	c.cant_fail = ep.cant_fail
	c.nerves = ep.nerves
	var h := p_db.house
	for rid in ep.backstage:
		var bi: int = h.room_index.get(rid, -1)
		if bi >= 0:
			c.backstage_mask |= 1 << bi
	for rid in ep.rooms:
		var ri: int = h.room_index.get(rid, -1)
		if ri >= 0 and (c.backstage_mask & (1 << ri)) == 0:
			c.hush_mask |= 1 << ri
	if not ep.rooms.is_empty():
		c.fixup_mask = c.backstage_mask
		for rid in ep.rooms:
			var fi: int = h.room_index.get(rid, -1)
			if fi >= 0:
				c.fixup_mask |= 1 << fi
	c.combo_ok.resize(p_db.combo_list.size())
	for cb in p_db.combo_list:
		c.combo_ok[cb.idx] = 1 if (ep.combos_all or ep.combos.has(cb.id)) else 0
	c.senses = ep.senses
	var ds: Variant = h.entries.get("doorstep", null)
	if typeof(ds) == TYPE_DICTIONARY:
		c.doorstep_room = int(h.room_index.get(ContentUtil.s(ds, "room"), -1))
		c.doorstep_x = Fx.px(ContentUtil.f(ds, "x"))
	if c.doorstep_room < 0:
		c.doorstep_room = int(h.room_index.get(ep.hush_room, 0))
		c.doorstep_x = ep.hush_x_sub
	if (c.backstage_mask & (1 << c.doorstep_room)) == 0:
		c.hush_mask |= 1 << c.doorstep_room
	var np := p_db.prank_list.size()
	c.prank_in_ep.resize(np)
	c.prank_bn_only.resize(np)
	c.prank_base.resize(np)
	for i in np:
		c.prank_in_ep[i] = 0
		c.prank_bn_only[i] = 0
		c.prank_base[i] = 0
	var non_bn := {}
	var bn := {}
	for l in ep.script_lines:
		if l.big_number:
			c.bn_line = l.idx
		var refs := PackedStringArray()
		match l.kind:
			LineDef.K_PRANK, LineDef.K_PRANK_WITNESSED, LineDef.K_CHASE_TRIP:
				if l.prank != "":
					refs.append(l.prank)
			LineDef.K_DOUBLE_ACT:
				var da: DoubleActDef = p_db.double_acts.get(l.double_act, null)
				if da != null:
					refs.append(da.a)
					refs.append(da.b)
		for pid in refs:
			if l.big_number:
				bn[pid] = true
			else:
				non_bn[pid] = true
		if l.kind == LineDef.K_PRANK and p_db.pranks.has(l.prank):
			c.prank_base[p_db.prank_idx(l.prank)] = l.base_tenths
	for p in p_db.prank_list:
		if non_bn.has(p.id) or bn.has(p.id) or p.nights.has(ep.id):
			c.prank_in_ep[p.idx] = 1
		if bn.has(p.id) and not non_bn.has(p.id) and not p.nights.has(ep.id):
			c.prank_bn_only[p.idx] = 1
	# double acts whose A is in the Night pull in B (the knock-on target must be riggable)
	for p in p_db.prank_list:
		if c.prank_in_ep[p.idx] == 1 and p.knock_prank != "" and p_db.pranks.has(p.knock_prank):
			var bi := p_db.prank_idx(p.knock_prank)
			if c.prank_in_ep[bi] == 0 and non_bn.has(p.id):
				c.prank_in_ep[bi] = 1
	c.item_in_ep.resize(p_db.item_list.size())
	for i in p_db.item_list.size():
		c.item_in_ep[i] = 0
	for p in p_db.prank_list:
		if c.prank_in_ep[p.idx] == 0:
			continue
		for st in p.steps:
			if st.needs != "" and p_db.items.has(st.needs):
				c.item_in_ep[p_db.item_idx(st.needs)] = 1
		if p.trig_type == PrankDef.TRIG_STEP:
			c.step_pranks.append(p.idx)
		elif p.trig_type == PrankDef.TRIG_QUAKE:
			c.quake_pranks.append(p.idx)
		if Conditions.is_stand_in(p):
			c.stand_in_pranks.append(p.idx)
	c.cues = ContentUtil.arr(ep.director, "cues")
	c.safety_net = ContentUtil.dict(ep.director, "safety_net")
	for cue in c.cues:
		var when: Variant = (cue as Dictionary).get("when", {}) if typeof(cue) == TYPE_DICTIONARY else null
		c.cue_req.append(Conditions.required_seen_keys(when))
		c.cue_event_only.append(1 if when != null and Conditions.is_event_only(when) else 0)
	c.end_when = ep.end_when
	c.end_req = Conditions.required_seen_keys(ep.end_when)
	c.end_event_only = ep.end_when != null and Conditions.is_event_only(ep.end_when)
	c.end_reason = ep.end_reason
	c.nerves_q = ep.nerves_temper * SimConst.TEMPER_Q
	c.hush_enter_ticks = ep.hush_enter_ticks
	c.hush_enter_at = mini(ep.hush_enter_at_ticks, ep.hush_enter_ticks)
	c.exit_after = ep.exit_after
	c.exit_room = p_db.house.room_index.get(ep.exit_room, -1) if ep.exit_room != "" else -1
	c.exit_x = ep.exit_x_sub
	c.loop_repeat = ep.loop_repeat
	return c


## True when Hush may be in room `r`.
func hush_allowed(r: int) -> bool:
	return r >= 0 and (hush_mask & (1 << r)) != 0


## True when room `r` is backstage this Night.
func is_backstage(r: int) -> bool:
	return r >= 0 and (backstage_mask & (1 << r)) != 0


## True when a station in room `r` may serve a fix-up this Night.
func fixup_room_ok(r: int) -> bool:
	return fixup_mask < 0 or (r >= 0 and (fixup_mask & (1 << r)) != 0)
