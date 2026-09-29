## ContentValidate — the MUST rules of TECH §4 over a parsed ContentDB (TECH §3.2).
##
## Messages name the file, the entry, the field, the bad value and what it should resolve against, e.g.
## `pranks.json: achoo_ria.rig_point 'kitchen_honey' not in house.json`. Design rules (Script sizes,
## card lengths, lint-only checks) belong to the content lint (TECH §10.5), not here.
class_name ContentValidate
extends RefCounted

## Prank / step condition keys the sim understands (Stage-3 ones load with a warning).
const PRANK_COND_KEYS: Array[String] = ["tier_min", "or_chase", "meltdown_in_room", "hush_in_frame_frozen",
	"beryl_within", "beryl_on", "delphine_present"]
const PRANK_COND_STAGE3: Array[String] = ["beryl_within", "beryl_on", "delphine_present"]
const THIRD_PARTY_ACTORS: Array[String] = ["beryl", "delphine"]


## All errors.
static func run(db: ContentDB) -> PackedStringArray:
	var e := PackedStringArray()
	_versions(db, e)
	_house(db, e)
	_items(db, e)
	_activities(db, e)
	_pranks(db, e)
	_reactions(db, e)
	_residues(db, e)
	for eid in ContentUtil.sorted_keys(db.episodes):
		_episode(db, db.episodes[eid], e)
	return e


## Stage-3 content that loads but is inactive in Stage 1.
static func warnings(db: ContentDB) -> PackedStringArray:
	var w := PackedStringArray()
	for p in db.prank_list:
		if p.trig_type == PrankDef.TRIG_THIRD_PARTY:
			w.append("pranks.json: %s.trigger third_party (%s) is a Stage-3 trigger (inactive)" % [p.id, p.trig_actor])
		if p.knock_headbutt:
			w.append("pranks.json: %s.knock_on headbutt is a Stage-3 knock-on (inactive)" % p.id)
		for c in p.conditions:
			if typeof(c) == TYPE_DICTIONARY:
				for k in (c as Dictionary).keys():
					if PRANK_COND_STAGE3.has(str(k)):
						w.append("pranks.json: %s.conditions '%s' is a Stage-3 condition (always false)" % [p.id, k])
		for si in p.steps.size():
			for c in p.steps[si].conditions:
				if typeof(c) == TYPE_DICTIONARY:
					for k in (c as Dictionary).keys():
						if PRANK_COND_STAGE3.has(str(k)):
							w.append("pranks.json: %s.steps[%d].conditions '%s' is a Stage-3 condition (always false)" % [p.id, si, k])
	for clip in db.t3_last_beats:
		if db.clip_len(clip) <= 0:
			w.append("reactions.json: t3_last_beats '%s' has no clip_timings frames (the sim adds 0 to the reaction)" % clip)
	if not db.t3_last_beats.is_empty() and db.clip_len(SimConst.SLOW_BURN_CLIP) <= 0:
		w.append("reactions.json: '%s' has no clip_timings frames (every 4th reaction's slow burn adds 0)" % SimConst.SLOW_BURN_CLIP)
	for da in db.double_act_list:
		if da.headbutt:
			w.append("pranks.json: double_acts.%s is a Stage-3 headbutt Double Act (inactive)" % da.id)
	for eid in ContentUtil.sorted_keys(db.episodes):
		var ep: EpisodeDef = db.episodes[eid]
		for l in ep.script_lines:
			if l.kind >= 0 and l.is_stage3():
				w.append("episodes/%s.json: line %s kind '%s' is a Stage-3 line kind (never done yet)" % [eid, l.id, l.kind_name])
		for actor in ["beryl", "delphine"]:
			if ep.raw.has(actor) or ep.cast.get(actor, null) != null:
				w.append("episodes/%s.json: actor '%s' is a Stage-3 actor (not simulated yet)" % [eid, actor])
	return w


static func _versions(db: ContentDB, e: PackedStringArray) -> void:
	for k in ContentDB.FILES:
		var d: Variant = db.raw.get(k, null)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		if ContentUtil.i(d, "version", -1) != 1:
			e.append("%s: version must be 1" % _fname(k))


static func _fname(k: String) -> String:
	return "house.json" if k == "house" else k + ".json"


# --- house.json ---------------------------------------------------------------------------------

static func _house(db: ContentDB, e: PackedStringArray) -> void:
	var h := db.house
	if h.rooms.is_empty():
		e.append("house.json: no rooms")
	for r in h.rooms:
		if r.id == "":
			e.append("house.json: a room has no id")
		if r.x1_sub <= r.x0_sub:
			e.append("house.json: room %s.x1 %d must be > x0 %d" % [r.id, r.x1, r.x0])
	for l in h.links:
		if l.kind < 0:
			e.append("house.json: link %s.kind '%s' not doorway|door|stairs" % [l.id, l.kind_name])
			continue
		if l.a_idx < 0:
			e.append("house.json: link %s.a '%s' not a room in house.json" % [l.id, l.a])
		if l.b_idx < 0:
			e.append("house.json: link %s.b '%s' not a room in house.json" % [l.id, l.b])
		if l.a_idx < 0 or l.b_idx < 0:
			continue
		var ra := h.rooms[l.a_idx]
		var rb := h.rooms[l.b_idx]
		if l.kind == LinkDef.STAIRS:
			if ra.floor == rb.floor:
				e.append("house.json: link %s is stairs between rooms on the same floor" % l.id)
			if not _in_room(ra, l.ax_sub):
				e.append("house.json: link %s.ax %d outside room %s" % [l.id, Fx.to_px(l.ax_sub), ra.id])
			if not _in_room(rb, l.bx_sub):
				e.append("house.json: link %s.bx %d outside room %s" % [l.id, Fx.to_px(l.bx_sub), rb.id])
		else:
			if ra.floor != rb.floor:
				e.append("house.json: link %s joins rooms on different floors (use stairs)" % l.id)
			if not _in_room(ra, l.x_sub) or not _in_room(rb, l.x_sub):
				e.append("house.json: link %s.x %d is not on the %s/%s boundary" % [l.id, Fx.to_px(l.x_sub), ra.id, rb.id])
	for s in h.stations:
		if s.room_idx < 0:
			e.append("house.json: station %s.room '%s' not a room in house.json" % [s.id, s.room])
			continue
		if not _in_room(h.rooms[s.room_idx], s.stand_sub):
			e.append("house.json: station %s.stand_x %d outside room %s" % [s.id, Fx.to_px(s.stand_sub), s.room])
		for k in s.kinds:
			if not SimConst.FIXUP_KINDS.has(k):
				e.append("house.json: station %s.kinds '%s' not DRY|SINK|HONEY|MIRROR" % [s.id, k])
	for hs in h.hotspots:
		if hs.kind < 0:
			e.append("house.json: hotspot %s.kind '%s' not container|hiding|rig_point|exit|stairs|door" % [hs.id, hs.kind_name])
		if hs.room_idx < 0:
			e.append("house.json: hotspot %s.room '%s' not a room in house.json" % [hs.id, hs.room])
		elif not _in_room(h.rooms[hs.room_idx], hs.use_sub):
			e.append("house.json: hotspot %s.use_x %d outside room %s" % [hs.id, Fx.to_px(hs.use_sub), hs.room])
		if hs.rect.size() != 4:
			e.append("house.json: hotspot %s.rect must be [x, y, w, h]" % hs.id)
		if hs.station != "" and hs.station_idx < 0:
			e.append("house.json: hotspot %s.station '%s' not a station in house.json" % [hs.id, hs.station])
		if (hs.kind == HotspotDef.STAIRS or hs.kind == HotspotDef.DOOR) and hs.link_idx < 0 and hs.tappable:
			e.append("house.json: hotspot %s.link '%s' not a link in house.json" % [hs.id, hs.link])
		if hs.in_use_by != "":
			if hs.kind != HotspotDef.HIDING:
				e.append("house.json: hotspot %s.in_use_by is only valid on hiding spots" % hs.id)
			if not db.activities.is_empty() and not db.activities.has(hs.in_use_by):
				e.append("house.json: hotspot %s.in_use_by '%s' not in activities.json" % [hs.id, hs.in_use_by])
	for en in ContentUtil.sorted_keys(h.entries):
		var ed: Variant = h.entries[en]
		if typeof(ed) != TYPE_DICTIONARY or not h.room_index.has(ContentUtil.s(ed, "room")):
			e.append("house.json: entries.%s.room not a room in house.json" % en)
	for rid in ContentUtil.sorted_keys(h.landings):
		if not h.room_index.has(rid):
			e.append("house.json: landings '%s' not a room in house.json" % rid)


static func _in_room(r: RoomDef, x_sub: int) -> bool:
	return x_sub >= r.x0_sub and x_sub <= r.x1_sub


# --- items / activities ---------------------------------------------------------------------------

static func _items(db: ContentDB, e: PackedStringArray) -> void:
	for it in db.item_list:
		var hs := db.house.hotspot(it.source)
		if hs == null:
			e.append("items.json: %s.source '%s' not in house.json" % [it.id, it.source])
		elif hs.kind != HotspotDef.CONTAINER:
			e.append("items.json: %s.source '%s' is not a container" % [it.id, it.source])
		for pid in it.pranks:
			if not db.pranks.has(pid):
				e.append("items.json: %s.pranks '%s' not in pranks.json" % [it.id, pid])


static func _activities(db: ContentDB, e: PackedStringArray) -> void:
	for m in db.wb_errors:
		e.append("activities.json: %s" % m)
	for a in db.activity_list:
		for m in a.mg_errors:
			e.append("activities.json: %s.%s" % [a.id, m])
		if a.station != "" and a.station_idx < 0:
			e.append("activities.json: %s.station '%s' not in house.json" % [a.id, a.station])
		if not a.is_detour:
			if a.station == "":
				e.append("activities.json: %s.station missing" % a.id)
			if a.dur_ticks <= 0:
				e.append("activities.json: %s.dur_s must be > 0" % a.id)
		if ActivityDef.AWARE_NAMES.find(a.awareness_name) < 0:
			e.append("activities.json: %s.awareness '%s' not normal|absorbed|asleep|blind" % [a.id, a.awareness_name])
		if a.squeak_bit != "" and not db.squeak_bits.has(a.squeak_bit):
			e.append("activities.json: %s.squeak_bit '%s' not in squeak_bits" % [a.id, a.squeak_bit])
		if a.in_use != "":
			var hs := db.house.hotspot(a.in_use)
			if hs == null:
				e.append("activities.json: %s.in_use '%s' not in house.json" % [a.id, a.in_use])
			elif hs.kind != HotspotDef.HIDING:
				e.append("activities.json: %s.in_use '%s' is not a hiding spot" % [a.id, a.in_use])


# --- pranks ---------------------------------------------------------------------------------------

static func _pranks(db: ContentDB, e: PackedStringArray) -> void:
	for p in db.prank_list:
		var pid := p.id
		if p.size < 0:
			e.append("pranks.json: %s.size '%s' not S|M|L|SIG" % [pid, p.size_name])
		var rp := db.house.hotspot(p.rig_point)
		if rp == null:
			e.append("pranks.json: %s.rig_point '%s' not in house.json" % [pid, p.rig_point])
		elif rp.kind != HotspotDef.RIG_POINT:
			e.append("pranks.json: %s.rig_point '%s' is not a rig_point" % [pid, p.rig_point])
		if p.steps.is_empty():
			e.append("pranks.json: %s.steps must have at least one step" % pid)
		for si in p.steps.size():
			var st := p.steps[si]
			if not ["Q", "S", "B"].has(st.prep):
				e.append("pranks.json: %s.steps[%d].prep '%s' not Q|S|B" % [pid, si, st.prep])
			if st.needs != "" and not db.items.has(st.needs):
				e.append("pranks.json: %s.steps[%d].needs '%s' not in items.json" % [pid, si, st.needs])
			var at := db.house.hotspot(st.at)
			if at == null:
				e.append("pranks.json: %s.steps[%d].at '%s' not in house.json" % [pid, si, st.at])
			elif at.kind != HotspotDef.RIG_POINT:
				e.append("pranks.json: %s.steps[%d].at '%s' is not a rig_point" % [pid, si, st.at])
			_prank_conds(db, st.conditions, "pranks.json: %s.steps[%d].conditions" % [pid, si], e)
		match p.trig_type:
			PrankDef.TRIG_USE:
				if not db.activities.has(p.trig_activity):
					e.append("pranks.json: %s.trigger.activity '%s' not in activities.json" % [pid, p.trig_activity])
			PrankDef.TRIG_STEP:
				if db.house.hotspot(p.trig_at) == null:
					e.append("pranks.json: %s.trigger.at '%s' not in house.json" % [pid, p.trig_at])
				for a_id in p.trig_at_list:
					if a_id != p.trig_at and db.house.hotspot(a_id) == null:
						e.append("pranks.json: %s.trigger.at '%s' not in house.json" % [pid, a_id])
			PrankDef.TRIG_QUAKE:
				if not db.house.room_index.has(p.trig_room):
					e.append("pranks.json: %s.trigger.room '%s' not a room in house.json" % [pid, p.trig_room])
			PrankDef.TRIG_THIRD_PARTY:
				if not THIRD_PARTY_ACTORS.has(p.trig_actor):
					e.append("pranks.json: %s.trigger.actor '%s' not beryl|delphine" % [pid, p.trig_actor])
			PrankDef.TRIG_KNOCK_ON_ONLY:
				pass
			_:
				e.append("pranks.json: %s.trigger.type '%s' not use|step|quake|third_party|knock_on_only" % [pid, p.trig_name])
		for k in p.trig_fixup_kinds:
			if not SimConst.FIXUP_KINDS.has(k):
				e.append("pranks.json: %s.trigger.fixup_kinds '%s' not DRY|SINK|HONEY|MIRROR" % [pid, k])
		if not p.trig_fixup_kinds.is_empty() and rp != null and rp.station_idx < 0:
			e.append("pranks.json: %s has fixup_kinds but rig_point '%s' has no station" % [pid, p.rig_point])
		_prank_conds(db, p.conditions, "pranks.json: %s.conditions" % pid, e)
		if p.archetype == "":
			e.append("pranks.json: %s.reaction.archetype missing" % pid)
		elif p.variants.is_empty():
			if not db.reactions.has(p.archetype):
				e.append("pranks.json: %s.reaction.archetype '%s' not in reactions.json" % [pid, p.archetype])
		else:
			for v in p.variants:
				var key := "%s_%s" % [p.archetype, v]
				if not db.reactions.has(key):
					e.append("pranks.json: %s.reaction '%s' not in reactions.json" % [pid, key])
		if p.end_room != "":
			if not db.house.room_index.has(p.end_room):
				e.append("pranks.json: %s.reaction.end.room '%s' not a room in house.json" % [pid, p.end_room])
			elif p.end_landing != "" and db.house.landing_sub(p.end_room, p.end_landing) < 0:
				e.append("pranks.json: %s.reaction.end.landing '%s' not in house.json landings.%s" % [pid, p.end_landing, p.end_room])
		if p.knock_prank != "" and not db.pranks.has(p.knock_prank):
			e.append("pranks.json: %s.knock_on.prank '%s' not in pranks.json" % [pid, p.knock_prank])
		if (p.knock_prank != "" or p.knock_headbutt) and p.knock_frame < 0:
			e.append("pranks.json: %s.knock_on.frame missing" % pid)
		for r in p.residue:
			if not db.residues.has(str(r["kind"])):
				e.append("pranks.json: %s.residue '%s' not in residues.json" % [pid, r["kind"]])
		for k in p.clears:
			if not db.residues.has(k):
				e.append("pranks.json: %s.clears '%s' not in residues.json" % [pid, k])
		for n in p.nights:
			if not db.episodes.is_empty() and not db.episodes.has(n):
				e.append("pranks.json: %s.nights '%s' not an episode" % [pid, n])
	for da in db.double_act_list:
		if da.headbutt:
			if not db.pranks.has(da.a):
				e.append("pranks.json: double_acts.%s.a '%s' not in pranks.json" % [da.id, da.a])
			continue
		if not db.pranks.has(da.a):
			e.append("pranks.json: double_acts.%s.a '%s' not in pranks.json" % [da.id, da.a])
		if not db.pranks.has(da.b):
			e.append("pranks.json: double_acts.%s.b '%s' not in pranks.json" % [da.id, da.b])
		if db.pranks.has(da.a) and db.pranks.has(da.b):
			var pa: PrankDef = db.pranks[da.a]
			if pa.knock_prank != da.b and not pa.knock_headbutt:
				e.append("pranks.json: double_acts.%s: %s.knock_on.prank must be '%s'" % [da.id, da.a, da.b])


static func _prank_conds(db: ContentDB, conds: Array, where: String, e: PackedStringArray) -> void:
	for c in conds:
		if typeof(c) != TYPE_DICTIONARY:
			e.append("%s entry is not an object" % where)
			continue
		for k in (c as Dictionary).keys():
			var ks := str(k)
			if not PRANK_COND_KEYS.has(ks):
				e.append("%s '%s' not a known condition" % [where, ks])
			elif ks == "tier_min" and SimConst.tier_id(str(c[k])) < 0:
				e.append("%s tier_min '%s' not calm|irked|steaming|livid" % [where, c[k]])
			elif ks == "meltdown_in_room" and not db.house.room_index.has(str(c[k])):
				e.append("%s meltdown_in_room '%s' not a room in house.json" % [where, c[k]])
			elif ks == "beryl_on" and db.house.hotspot(str(c[k])) == null:
				e.append("%s beryl_on '%s' not in house.json" % [where, c[k]])


# --- reactions / residues ------------------------------------------------------------------------

static func _reactions(db: ContentDB, e: PackedStringArray) -> void:
	for key in ContentUtil.sorted_keys(db.reactions):
		var r: ReactionDef = db.reactions[key]
		if r.accent < 0 or r.accent >= r.frames:
			e.append("reactions.json: %s.marks.accent %d outside 0..%d" % [key, r.accent, r.frames - 1])
		if r.hold0 > r.hold1 or r.hold1 > r.frames:
			e.append("reactions.json: %s.marks.hold [%d, %d] invalid for %d frames" % [key, r.hold0, r.hold1, r.frames])
		if r.hold0 < r.accent:
			e.append("reactions.json: %s.marks.hold starts before the accent" % key)
		if r.has_travel and (r.travel_from < 0 or r.travel_to > r.frames):
			e.append("reactions.json: %s.travel [%d, %d] outside the clip" % [key, r.travel_from, r.travel_to])


static func _residues(db: ContentDB, e: PackedStringArray) -> void:
	for r in db.residue_list:
		if not SimConst.FIXUP_KINDS.has(r.fixup):
			e.append("residues.json: %s.fixup '%s' not DRY|SINK|HONEY|MIRROR" % [r.id, r.fixup])
	for c in db.combo_list:
		if c.of.size() < 2:
			e.append("residues.json: combos.%s.of needs two residues" % c.id)
		for k in c.of:
			if not db.residues.has(k):
				e.append("residues.json: combos.%s.of '%s' not in residues" % [c.id, k])


# --- episodes -------------------------------------------------------------------------------------

static func _episode(db: ContentDB, ep: EpisodeDef, e: PackedStringArray) -> void:
	var f := "episodes/%s.json" % ep.id
	if ContentUtil.i(ep.raw, "version", -1) != 1:
		e.append("%s: version must be 1" % f)
	if ep.act < 0 or ep.act > 4:
		e.append("%s: act %d not 0..4" % [f, ep.act])
	if not ["draft", "final"].has(ep.status):
		e.append("%s: status '%s' not draft|final" % [f, ep.status])
	for r in ep.rooms:
		if not db.house.room_index.has(r):
			e.append("%s: rooms '%s' not a room in house.json" % [f, r])
	for r in ep.backstage:
		if not db.house.room_index.has(r):
			e.append("%s: backstage '%s' not a room in house.json" % [f, r])
		elif ep.rooms.has(r):
			e.append("%s: backstage '%s' is also one of the Night's rooms" % [f, r])
	if ep.rules.has("combos"):
		if typeof(ep.rules["combos"]) != TYPE_ARRAY:
			e.append("%s: rules.combos must be a list of combo ids ([] = none)" % f)
		else:
			for cid in ep.combos:
				if not db.combos.has(cid):
					e.append("%s: rules.combos '%s' not in residues.json combos" % [f, cid])
	if ep.rules.has("senses") and typeof(ep.rules["senses"]) != TYPE_BOOL:
		e.append("%s: rules.senses must be true or false" % f)
	if ep.entry != "" and not db.house.entries.has(ep.entry):
		e.append("%s: entry '%s' not in house.json entries" % [f, ep.entry])
	if ep.act > 0 and Fx.ticks(ep.spot_fill_s) < SimConst.SPOT_FILL_MIN:
		e.append("%s: rules.spot_fill_s %.2f below 0.8" % [f, ep.spot_fill_s])
	for k in ep.rules.keys():
		if not SimConst.RULE_KEYS.has(str(k)):
			e.append("%s: rules.%s is not an overridable rule" % [f, k])
	if not db.house.room_index.has(ep.hush_room):
		e.append("%s: hush.start.room '%s' not a room in house.json" % [f, ep.hush_room])
	elif not ep.rooms.has(ep.hush_room):
		e.append("%s: hush.start.room '%s' not in the episode's rooms" % [f, ep.hush_room])
	if not db.house.room_index.has(ep.bellows_room):
		e.append("%s: bellows.start.room '%s' not a room in house.json" % [f, ep.bellows_room])
	if ep.loop.is_empty():
		e.append("%s: bellows.loop is empty" % f)
	for i in ep.loop.size():
		var le := ep.loop[i]
		if not db.activities.has(le.activity):
			e.append("%s: bellows.loop[%d] '%s' not in activities.json" % [f, i, le.activity])
		elif (db.activities[le.activity] as ActivityDef).is_detour:
			e.append("%s: bellows.loop[%d] '%s' is a detour, not an activity" % [f, i, le.activity])
		if le.has_gate:
			_gate(db, le.until, "%s: bellows.loop[%d].gate.until" % [f, i], e)
		elif le.hooks_after_gate:
			e.append("%s: bellows.loop[%d] has hooks: after_gate but no gate" % [f, i])
	var ids := {}
	for l in ep.script_lines:
		if l.id == "":
			e.append("%s: a script line has no id" % f)
		elif ids.has(l.id):
			e.append("%s: duplicate script line id '%s'" % [f, l.id])
		ids[l.id] = true
		match l.kind:
			LineDef.K_PRANK, LineDef.K_PRANK_WITNESSED:
				if not db.pranks.has(l.prank):
					e.append("%s: line %s.prank '%s' not in pranks.json" % [f, l.id, l.prank])
			LineDef.K_DOUBLE_ACT:
				if not db.double_acts.has(l.double_act):
					e.append("%s: line %s.double_act '%s' not in pranks.json double_acts" % [f, l.id, l.double_act])
			LineDef.K_COMBO, LineDef.K_COMBO_WITNESSED:
				if not db.combos.has(l.combo):
					e.append("%s: line %s.combo '%s' not in residues.json combos" % [f, l.id, l.combo])
			LineDef.K_CHAIN:
				if l.link < 1:
					e.append("%s: line %s.link must be >= 1" % [f, l.id])
			LineDef.K_CHASE_TRIP:
				if l.prank != "" and not db.pranks.has(l.prank):
					e.append("%s: line %s.prank '%s' not in pranks.json" % [f, l.id, l.prank])
			-1:
				e.append("%s: line %s.kind '%s' unknown" % [f, l.id, l.kind_name])
	var bn := 0
	for l in ep.script_lines:
		if l.big_number:
			bn += 1
	if bn > 1:
		e.append("%s: more than one Big Number line" % f)
	var sum := 0
	var n_prank := 0
	for l in ep.script_lines:
		if l.kind == LineDef.K_PRANK and db.pranks.has(l.prank):
			sum += l.base_tenths
			n_prank += 1
	if n_prank > 0 and sum != SimConst.BASE_TOTAL:
		e.append("%s: prank-line bases sum to %d, not %d" % [f, sum, SimConst.BASE_TOTAL])
	for k in ContentUtil.sorted_keys(ep.fixup_overrides):
		var sid := str(ep.fixup_overrides[k])
		var st := db.house.station(sid)
		if st == null:
			e.append("%s: fixup_overrides.%s '%s' not a station in house.json" % [f, k, sid])
		else:
			var fk := k
			if db.residues.has(k):
				fk = (db.residues[k] as ResidueDef).fixup
			if not st.kinds.has(fk):
				e.append("%s: fixup_overrides.%s station '%s' has no kind %s" % [f, k, sid, fk])
	var dir := ep.director
	if not dir.is_empty():
		for c in ContentUtil.arr(dir, "cues"):
			if typeof(c) != TYPE_DICTIONARY or ContentUtil.s(c, "id") == "":
				e.append("%s: director.cues entry needs an id" % f)
				continue
			for m in Conditions.validate(ContentUtil.dict(c, "when")):
				e.append("%s: director.cues.%s.when %s" % [f, ContentUtil.s(c, "id"), m])
		if dir.has("end_when"):
			for m in Conditions.validate(dir["end_when"]):
				e.append("%s: director.end_when %s" % [f, m])
		var sn := ContentUtil.dict(dir, "safety_net")
		if not sn.is_empty() and ContentUtil.s(sn, "pulse") != "" and db.house.hotspot(ContentUtil.s(sn, "pulse")) == null:
			e.append("%s: director.safety_net.pulse '%s' not in house.json" % [f, ContentUtil.s(sn, "pulse")])


static func _gate(db: ContentDB, until: Variant, where: String, e: PackedStringArray) -> void:
	if typeof(until) == TYPE_STRING:
		var s := str(until)
		if s == "first_squeak" or s == "first_rig":
			return
		if s.begins_with("rigged:"):
			if not db.pranks.has(s.trim_prefix("rigged:")):
				e.append("%s '%s' not in pranks.json" % [where, s])
			return
		e.append("%s '%s' not first_squeak|first_rig|rigged:<prank>" % [where, s])
	elif typeof(until) == TYPE_DICTIONARY:
		for m in Conditions.validate(until):
			e.append("%s %s" % [where, m])
	elif until != null:
		e.append("%s must be a string or a condition" % where)
