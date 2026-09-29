## Conditions — the condition language of TECH §8.2 (episode `director.when`, gates, solution waits) and the
## prank condition entries of TECH §4.4. Shared by the Director and the solver.
##
## A condition is a Dictionary (every key must hold — AND), an Array (AND of its elements), a bool, or one
## of the gate strings "first_squeak" | "first_rig" | "rigged:<prank>". `{}` is true; null is false.
##
## | key | value | true when |
## |---|---|---|
## | bellows_activity | id | his current task (walking to or doing; routine/detour/curious/search) is `id` |
## | bellows_activity_in | [ids] | … is one of them |
## | bellows_performing | id | he is performing (not walking to) `id` (extension) |
## | bellows_state | "ROUTINE"… | his state (case-insensitive) |
## | bellows_in_room / bellows_not_in_room | room | he is (not) in that room |
## | bellows_eta_to_room_gt_s | [room, s] | he is not in `room` and won't enter it within s (not heading there = true) |
## | bellows_activity_remaining_le_s | s | performing with a known end ≤ s away |
## | bellows_facing_away_from_hush | bool | Hush is behind him or in another room (== value) |
## | hush_visible | bool | he can see her now (== value) |
## | hush_hidden | bool | she is in a hiding spot (== value) |
## | hush_in_room | room | she is in that room (extension) |
## | spot_meter_pct_ge | pct | "?" meter ≥ pct % |
## | prank_state | [id, "RIGGED"] | that prank's state |
## | temper_tier_ge | "irked" / int | tier ≥ |
## | link_ge | n | Running Gag link ≥ n |
## | line_done | id | that Script line is done |
## | all_required_done | bool | every required line is done (== value) |
## | tick_ge_s | s | tick ≥ s × 60 |
## | first_squeak / first_rig | bool | a squeak / a completed rig has happened (== value) |
## | event_seen | "name" or [name, {k: v}] or {"e"/"event": name, "match": {k: v}, "after_s": s, "count_ge": n} | such an event was emitted this Night (≥ n times; the first ≥ s ago) |
## | event_ago_ge_s | [name, {k: v}, s] | the first such event was ≥ s seconds ago (extension) |
## | and / or | [conds] | all / any |
## | not | cond | negation |
class_name Conditions
extends RefCounted

const KEYS: Array[String] = ["bellows_activity", "bellows_activity_in", "bellows_performing", "bellows_state",
	"bellows_in_room", "bellows_not_in_room", "bellows_eta_to_room_gt_s", "bellows_activity_remaining_le_s",
	"bellows_facing_away_from_hush", "hush_visible", "hush_hidden", "hush_in_room", "spot_meter_pct_ge",
	"prank_state", "temper_tier_ge", "link_ge", "line_done", "all_required_done", "tick_ge_s", "first_squeak",
	"first_rig", "event_seen", "event_ago_ge_s", "and", "or", "not"]


## `event_seen` dictionary fields that are not event-payload matches.
const EVENT_SEEN_FIELDS: Array[String] = ["e", "event", "match", "after_s", "count_ge"]


## Evaluate a condition against the world.
static func eval(w: SimWorld, cond: Variant) -> bool:
	match typeof(cond):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return bool(cond)
		TYPE_STRING, TYPE_STRING_NAME:
			return _eval_string(w, str(cond))
		TYPE_ARRAY:
			for c in cond:
				if not eval(w, c):
					return false
			return true
		TYPE_DICTIONARY:
			var d: Dictionary = cond
			for k in d:
				if not _eval_key(w, str(k), d[k]):
					return false
			return true
	return false


static func _eval_string(w: SimWorld, s: String) -> bool:
	if s == "first_squeak":
		return w.bits.first_squeak_tick >= 0
	if s == "first_rig":
		return w.pranks.first_rig_tick >= 0
	if s.begins_with("rigged:"):
		return w.prank_state(s.trim_prefix("rigged:")) >= Pranks.RIGGED
	if KEYS.has(s):
		return _eval_key(w, s, true)
	return false


static func _eval_key(w: SimWorld, k: String, v: Variant) -> bool:
	var b := w.bellows
	var hu := w.hush
	match k:
		"and":
			if typeof(v) != TYPE_ARRAY:
				return eval(w, v)
			for c in v:
				if not eval(w, c):
					return false
			return true
		"or":
			if typeof(v) != TYPE_ARRAY:
				return eval(w, v)
			for c in v:
				if eval(w, c):
					return true
			return false
		"not":
			return not eval(w, v)
		"bellows_activity":
			return _on_task(b) and b.activity_id == str(v)
		"bellows_activity_in":
			if typeof(v) != TYPE_ARRAY:
				return _on_task(b) and b.activity_id == str(v)
			return _on_task(b) and (v as Array).has(b.activity_id)
		"bellows_performing":
			return _on_task(b) and b.phase == SimBellows.PH_PERFORM and b.activity_id == str(v)
		"bellows_state":
			return SimBellows.STATE_NAMES[b.state] == str(v).to_upper()
		"bellows_in_room":
			return w.room_id(b.room) == str(v)
		"bellows_not_in_room":
			return w.room_id(b.room) != str(v)
		"bellows_eta_to_room_gt_s":
			if typeof(v) != TYPE_ARRAY or (v as Array).size() < 2:
				return false
			var r := w.room_idx(str(v[0]))
			if r < 0 or r == b.room:
				return false
			if b.path == null:
				return true
			var eta := b.path.eta_to_room(r)
			return eta < 0 or eta > Fx.ticks(float(v[1]))
		"bellows_activity_remaining_le_s":
			if b.phase != SimBellows.PH_PERFORM or b.activity_len < 0 or not _on_task(b):
				return false
			return b.activity_len - b.activity_t <= Fx.ticks(float(v))
		"bellows_facing_away_from_hush":
			var away := b.room != hu.room or (hu.x_sub - b.x_sub) * b.facing < 0
			return away == _truthy(v)
		"hush_visible":
			return w.senses.can_see(w) == _truthy(v)
		"hush_hidden":
			return hu.is_hidden() == _truthy(v)
		"hush_in_room":
			return w.room_id(hu.room) == str(v)
		"spot_meter_pct_ge":
			return b.spot_meter * 100 >= roundi(float(v)) * maxi(1, w.ctx.spot_fill)
		"prank_state":
			if typeof(v) != TYPE_ARRAY or (v as Array).size() < 2:
				return false
			return Pranks.STATE_NAMES[w.prank_state(str(v[0]))] == str(v[1]).to_upper()
		"temper_tier_ge":
			var t := SimConst.tier_id(str(v)) if typeof(v) == TYPE_STRING else roundi(float(v))
			return t >= 0 and b.tier >= t
		"link_ge":
			return b.link >= roundi(float(v))
		"line_done":
			var l := w.episode.line(str(v))
			return l != null and w.goals.done[l.idx] == 1
		"all_required_done":
			return _required_done(w) == _truthy(v)
		"tick_ge_s":
			return w.tick >= Fx.ticks(float(v))
		"first_squeak":
			return (w.bits.first_squeak_tick >= 0) == _truthy(v)
		"first_rig":
			return (w.pranks.first_rig_tick >= 0) == _truthy(v)
		"event_seen":
			var ft := _event_first_tick(w, v)
			if ft < 0:
				return false
			if typeof(v) == TYPE_DICTIONARY:
				var vd: Dictionary = v
				if vd.has("after_s") and w.tick - ft < Fx.ticks(float(vd["after_s"])):
					return false
				if vd.has("count_ge") and _event_count(w, v) < roundi(float(vd["count_ge"])):
					return false
			return true
		"event_ago_ge_s":
			if typeof(v) != TYPE_ARRAY or (v as Array).size() < 2:
				return false
			var a: Array = v
			var ft := _event_first_tick(w, a.slice(0, a.size() - 1))
			return ft >= 0 and w.tick - ft >= Fx.ticks(float(a[a.size() - 1]))
	return false


static func _truthy(v: Variant) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v) != 0.0
	return v != null


static func _on_task(b: SimBellows) -> bool:
	return b.state == SimBellows.ROUTINE or b.state == SimBellows.DETOUR or b.state == SimBellows.CURIOUS \
		or b.state == SimBellows.SEARCH


static func _required_done(w: SimWorld) -> bool:
	for l in w.episode.script_lines:
		if l.req and not l.big_number and w.goals.done[l.idx] == 0:
			return false
	return true


## How many such events were emitted (multi-field matches: the smallest per-field count).
static func _event_count(w: SimWorld, v: Variant) -> int:
	var d: Dictionary = v
	var name := str(d.get("e", d.get("event", "")))
	var n := int(w.seen_n.get(name, 0))
	var m: Dictionary = d.get("match", {}) if typeof(d.get("match", null)) == TYPE_DICTIONARY else {}
	for k in m:
		n = mini(n, int(w.seen_n.get(_seen_key(name, str(k), m[k]), 0)))
	return n


## First tick such an event was emitted (-1 = never). Multi-field matches use the latest of the fields'
## first ticks (each field is indexed separately).
static func _event_first_tick(w: SimWorld, v: Variant) -> int:
	var name := ""
	var match_d := {}
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			name = str(v)
		TYPE_ARRAY:
			if (v as Array).size() >= 1:
				name = str(v[0])
			if (v as Array).size() >= 2 and typeof(v[1]) == TYPE_DICTIONARY:
				match_d = v[1]
		TYPE_DICTIONARY:
			var vd: Dictionary = v
			name = str(vd.get("e", vd.get("event", "")))
			if typeof(vd.get("match", null)) == TYPE_DICTIONARY:
				match_d = vd["match"]
			var extra := false
			for k in vd:
				if not EVENT_SEEN_FIELDS.has(str(k)):
					extra = true
			if extra:
				match_d = match_d.duplicate()
				for k in vd:
					if not EVENT_SEEN_FIELDS.has(str(k)):
						match_d[k] = vd[k]
	if name == "" or not w.seen.has(name):
		return -1
	var first := int(w.seen[name])
	for k in match_d:
		var key := _seen_key(name, str(k), match_d[k])
		if not w.seen.has(key):
			return -1
		first = maxi(first, int(w.seen[key]))
	return first


## The `SimWorld.seen` index key for "event name, field = value" (whole floats print as ints).
static func _seen_key(name: String, k: String, val: Variant) -> String:
	var sval := str(val)
	if typeof(val) == TYPE_FLOAT and float(val) == floorf(float(val)):
		sval = str(int(val))
	return "%s|%s=%s" % [name, k, sval]


## `SimWorld.seen` keys that must all exist for `cond` to be true (event_seen / event_ago_ge_s at the top
## level or under `and`; nothing is required under `or` / `not`). Seen keys are never removed during a
## Night, so a caller may skip evaluating the condition while any of them is missing.
static func required_seen_keys(cond: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	_required(cond, out)
	return out


static func _required(cond: Variant, out: PackedStringArray) -> void:
	match typeof(cond):
		TYPE_ARRAY:
			for c in cond:
				_required(c, out)
		TYPE_DICTIONARY:
			var d: Dictionary = cond
			for k in d:
				var ks := str(k)
				var v: Variant = d[k]
				if ks == "and":
					_required(v, out)
				elif ks == "event_seen":
					_required_event(v, out)
				elif ks == "event_ago_ge_s" and typeof(v) == TYPE_ARRAY and (v as Array).size() >= 2:
					_required_event((v as Array).slice(0, (v as Array).size() - 1), out)


static func _required_event(v: Variant, out: PackedStringArray) -> void:
	var name := ""
	var match_d := {}
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			name = str(v)
		TYPE_ARRAY:
			if (v as Array).size() >= 1:
				name = str(v[0])
			if (v as Array).size() >= 2 and typeof(v[1]) == TYPE_DICTIONARY:
				match_d = v[1]
		TYPE_DICTIONARY:
			var vd: Dictionary = v
			name = str(vd.get("e", vd.get("event", "")))
			if typeof(vd.get("match", null)) == TYPE_DICTIONARY:
				match_d = vd["match"]
			for k in vd:
				if not EVENT_SEEN_FIELDS.has(str(k)):
					out.append(_seen_key(name, str(k), vd[k]))
	if name == "":
		return
	out.append(name)
	for k in match_d:
		out.append(_seen_key(name, str(k), match_d[k]))


## True when `cond` reads nothing but the event index (`event_seen` without `after_s`, under and / or / not):
## its value can only change when an event is emitted.
static func is_event_only(cond: Variant) -> bool:
	match typeof(cond):
		TYPE_BOOL:
			return true
		TYPE_ARRAY:
			for c in cond:
				if not is_event_only(c):
					return false
			return true
		TYPE_DICTIONARY:
			var d: Dictionary = cond
			for k in d:
				var ks := str(k)
				var v: Variant = d[k]
				if ks == "and" or ks == "or" or ks == "not":
					if not is_event_only(v):
						return false
				elif ks == "event_seen":
					if typeof(v) == TYPE_DICTIONARY and (v as Dictionary).has("after_s"):
						return false
				else:
					return false
			return true
	return false


## True when every key is in `SimWorld.seen`.
static func seen_all(w: SimWorld, keys: PackedStringArray) -> bool:
	for k in keys:
		if not w.seen.has(k):
			return false
	return true


## Validation messages for a condition (unknown keys, bad shapes). Empty = valid.
static func validate(cond: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	_validate(cond, out)
	return out


static func _validate(cond: Variant, out: PackedStringArray) -> void:
	match typeof(cond):
		TYPE_NIL, TYPE_BOOL:
			return
		TYPE_STRING, TYPE_STRING_NAME:
			var s := str(cond)
			if s != "first_squeak" and s != "first_rig" and not s.begins_with("rigged:") and not KEYS.has(s):
				out.append("'%s' is not a condition" % s)
		TYPE_ARRAY:
			for c in cond:
				_validate(c, out)
		TYPE_DICTIONARY:
			for k in cond:
				var ks := str(k)
				if not KEYS.has(ks):
					out.append("'%s' is not a condition key" % ks)
					continue
				var v: Variant = cond[k]
				match ks:
					"and", "or":
						if typeof(v) != TYPE_ARRAY:
							out.append("'%s' needs an array" % ks)
						else:
							for c in v:
								_validate(c, out)
					"not":
						_validate(v, out)
					"bellows_eta_to_room_gt_s", "prank_state", "event_ago_ge_s":
						if typeof(v) != TYPE_ARRAY or (v as Array).size() < 2:
							out.append("'%s' needs [id, value]" % ks)
		_:
			out.append("unsupported condition value")


# --- prank condition entries (TECH §4.4) ----------------------------------------------------------

## AND of the prank's condition entries. Within an entry, every key must hold; `or_chase: true` makes the
## entry also true while he is chasing. Stage-3 keys (beryl_*, delphine_present) are false until the cast
## exists.
static func prank_conditions(w: SimWorld, conds: Array, p: int) -> bool:
	for c in conds:
		if typeof(c) != TYPE_DICTIONARY:
			return false
		if not _prank_entry(w, c, p):
			return false
	return true


static func _prank_entry(w: SimWorld, c: Dictionary, p: int) -> bool:
	var b := w.bellows
	var or_chase := bool(c.get("or_chase", false))
	var n_other := 0
	var all_ok := true
	for k in c:
		var ks := str(k)
		if ks == "or_chase":
			continue
		n_other += 1
		if not _prank_key(w, ks, c[k], p):
			all_ok = false
	if n_other > 0 and all_ok:
		return true
	if or_chase and b.state == SimBellows.CHASE:
		return true
	return n_other == 0 and not or_chase


static func _prank_key(w: SimWorld, k: String, v: Variant, p: int) -> bool:
	var b := w.bellows
	match k:
		"tier_min":
			var t := SimConst.tier_id(str(v))
			return t >= 0 and b.tier >= t
		"meltdown_in_room":
			return b.state == SimBellows.MELTDOWN and w.room_id(b.room) == str(v)
		"hush_in_frame_frozen":
			return hush_in_frame_frozen(w, p) == _truthy(v)
		"beryl_within", "beryl_on", "delphine_present":
			return false
	return false


## True when the prank is a stand-in (Mirror, Mirror: Hush must be frozen in the frame).
static func is_stand_in(pd: PrankDef) -> bool:
	for c in pd.conditions:
		if typeof(c) == TYPE_DICTIONARY and (c as Dictionary).has("hush_in_frame_frozen"):
			return true
	return false


## Hush stands in the frame of the prank's station (frame_x, else the rig point).
static func hush_in_frame(w: SimWorld, p: int) -> bool:
	if p < 0:
		return false
	var hu := w.hush
	if hu.is_hidden() or hu.in_transit() or hu.state == SimHush.CAUGHT:
		return false
	var pd := w.db.prank_list[p]
	if pd.rig_idx < 0:
		return false
	var hs := w.db.house.hotspots[pd.rig_idx]
	var fx := hs.use_sub
	var fr := hs.room_idx
	if hs.station_idx >= 0:
		var st := w.db.house.stations[hs.station_idx]
		fr = st.room_idx
		if st.frame_sub >= 0:
			fx = st.frame_sub
	return hu.room == fr and absi(hu.x_sub - fx) <= SimConst.MIRROR_FRAME_PX * SimConst.SUB


## Hush is FROZEN in the frame.
static func hush_in_frame_frozen(w: SimWorld, p: int) -> bool:
	return w.hush.state == SimHush.FROZEN and hush_in_frame(w, p)
