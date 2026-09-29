## PlayPlan — a clip as the player will play it: the tier / suppressed time remap of GDD §5.8
## and TECH §5.3, with its events on the remapped timeline. Pure.
##
## * **Tiers** stretch the HOLD beat [h0, h1] of the clip: tier 2 × 1.2, tier 3 × 1.5. The
##   remapped length is exactly `frames + hold_len × (scale − 100) / 100` (integer floor),
##   the same number the sim computes from reactions.json (TECH §3.7.4, `sim_length()`).
##   Frames before the hold are unchanged; inside it time runs slower; after it everything
##   shifts by `extra`.
## * Tier ≥ 2 adds one extra `shake` event at the hold start; **tier 3** adds a falling-prop
##   event (`{"type": "prop", "op": "fall", "tier": 3}`) at the remapped `t3_prop_f` (the
##   view drops a prop from the room table) and names a `last_beat` clip (from
##   reactions.json `t3_last_beats`, picked by seed) that the player appends AFTER the
##   reaction.
## * **suppressed** replaces the settle (everything after the hold end h1) with the
##   `suppressed` clip (reactions.json: 60 frames): length = h1 + extra + its length, which
##   equals the sim's `frames + extra − settle + 60`.
## The remap needs a hold: from opts `hold`, else the clip's `beats.hold`, else the
## reaction entry's `marks.hold`; without one, tiers do nothing.
class_name PlayPlan
extends RefCounted

## Tier → hold stretch percent (index = tier; tiers ≤ 1 = 100).
const TIER_SCALE: PackedInt32Array = [100, 100, 120, 150]

var clip: ClipDef
var tier: int = 1
var suppressed: bool = false
var loop: bool = false
var h0: int = -1
var h1: int = -1
## Frames added to the hold.
var extra: int = 0
## Timeline length (main clip remapped + the suppressed tail; the T3 last beat is separate).
var length: int = 1
var tail: ClipDef = null
var tail_start: int = -1
var tail_blend: int = 6
## T3: the clip to append after this plan ("" = none).
var last_beat: String = ""
var events: Array[Dictionary] = []
var ev_f: PackedInt32Array = PackedInt32Array()
var warnings: PackedStringArray = PackedStringArray()

var _h1_pose: PackedFloat32Array = PackedFloat32Array()


## The hold stretch in frames for a hold of `hold_len` at `tier` (floor division).
static func stretch_extra(hold_len: int, tier_i: int) -> int:
	var sc := TIER_SCALE[clampi(tier_i, 0, 3)]
	return (maxi(0, hold_len) * (sc - 100)) / 100


## The sim's reaction length (TECH §3.7.4): `frames + hold_len × (tier_scale − 100) / 100`;
## suppressed replaces the settle (frames − hold end) with `supp_frames`.
static func sim_length(frames: int, hold: Vector2i, tier_i: int, is_suppressed: bool, supp_frames: int = 60) -> int:
	var hold_len := maxi(0, hold.y - hold.x)
	var n := frames + stretch_extra(hold_len, tier_i)
	if is_suppressed:
		n = n - (frames - hold.y) + supp_frames
	return n


## A plain plan (no remap).
static func plain(c: ClipDef) -> PlayPlan:
	return build(c, {})


## Build the plan for playing `c` with RigPlayer.play() opts (tier, suppressed, hold,
## t3_prop_f, t3_prop, last_beat, suppressed_clip, seed).
static func build(c: ClipDef, opts: Dictionary) -> PlayPlan:
	var p := PlayPlan.new()
	p.clip = c
	p.loop = c.loop
	p.length = maxi(1, c.length)
	p.tier = clampi(int(opts.get("tier", 1)), 1, 3)
	p.suppressed = bool(opts.get("suppressed", false))
	var entry: Dictionary = {}
	if not c.loop and (p.tier >= 2 or p.suppressed):
		entry = ReactionTable.entry_for_clip(c.id)
	var hv: Variant = opts.get("hold", null)
	var hold := Vector2i(-1, -1)
	if hv is Array and (hv as Array).size() == 2:
		hold = Vector2i(int(hv[0]), int(hv[1]))
	elif c.beats.has("hold"):
		hold = c.beats["hold"]
	elif entry.get("marks", {}) is Dictionary and ((entry.get("marks", {}) as Dictionary).get("hold", null) is Array):
		var mh: Array = (entry["marks"] as Dictionary)["hold"]
		hold = Vector2i(int(mh[0]), int(mh[1]))
	if c.loop or hold.x < 0 or hold.y <= hold.x or hold.y > c.length:
		if p.tier >= 2 or p.suppressed:
			p.warnings.append("%s: no usable hold beat — tier / suppressed ignored" % c.id)
		p.tier = 1
		p.suppressed = false
		p._copy_events()
		return p
	p.h0 = hold.x
	p.h1 = hold.y
	p.extra = stretch_extra(p.h1 - p.h0, p.tier)
	p.length = c.length + p.extra
	if p.suppressed:
		var sid := String(opts.get("suppressed_clip", ""))
		if sid == "":
			sid = String(ReactionTable.suppressed_for(c.rig_id).get("clip", ""))
		var sc: ClipDef = ClipLib.get_clip(sid) if sid != "" else null
		if sc == null:
			p.warnings.append("%s: suppressed clip '%s' not found — plays unsuppressed" % [c.id, sid])
			p.suppressed = false
		else:
			p.tail = sc
			p.tail_start = p.h1 + p.extra
			p.tail_blend = sc.blend_in if sc.has_blend_in else ClipDef.DEFAULT_BLEND
			p.length = p.tail_start + sc.length
			p._h1_pose = c.rig.rest.duplicate()
			RigSampler.sample(c, float(p.h1), p._h1_pose)
	p._remap_events(opts, entry)
	return p


## Source frame of the main clip for timeline frame `t` (before the tail).
func src_frame(t: float) -> float:
	if extra == 0 or t <= float(h0):
		return t
	var hold_len := float(h1 - h0)
	var stretched := hold_len + float(extra)
	if t < float(h0) + stretched:
		return float(h0) + (t - float(h0)) * hold_len / stretched
	return t - float(extra)


## Timeline frame of source frame `f` (events, marks) — the sim's own remap
## (ReactionDef.remap): inside the hold `h0 + floor((f − h0) × scale / 100)`, after it `f + extra`.
func timeline_frame(f: int) -> int:
	if extra == 0 or f <= h0:
		return f
	if f <= h1:
		return h0 + ((f - h0) * TIER_SCALE[tier]) / 100
	return f + extra


## True when timeline frame `t` plays the suppressed tail.
func in_tail(t: float) -> bool:
	return tail != null and t >= float(tail_start)


## The clip playing at timeline frame `t`.
func clip_at(t: float) -> ClipDef:
	return tail if in_tail(t) else clip


## Samples the plan at timeline frame `t` into `out` (allocation-free).
func sample(t: float, out: PackedFloat32Array) -> void:
	if not in_tail(t):
		RigSampler.sample(clip, src_frame(t), out)
		return
	var tt := t - float(tail_start)
	RigSampler.sample(tail, tt, out)
	if tt < float(tail_blend) and tail_blend > 0:
		RigSampler.blend(_h1_pose, out, tt / float(tail_blend), out)


## Events crossed from f0 to f1 (f0 < f ≤ f1, wrapping for loops) into `out`.
func between_into(f0: float, f1: float, out: Array) -> int:
	out.clear()
	if loop and f1 < f0:
		ClipEvents.collect(ev_f, events, f0, float(length), out)
		ClipEvents.collect(ev_f, events, -1.0, f1, out)
	else:
		ClipEvents.collect(ev_f, events, f0, f1, out)
	return out.size()


func _copy_events() -> void:
	for e in clip.events:
		events.append(e)
		ev_f.append(int(e["f"]))


func _remap_events(opts: Dictionary, entry: Dictionary) -> void:
	var rows: Array = []
	var n := 0
	for e in clip.events:
		var f := int(e["f"])
		if suppressed and f > h1:
			continue
		var t := timeline_frame(f)
		var ev: Dictionary = e
		if t != f:
			ev = e.duplicate()
			ev["f"] = t
			ev["src_f"] = f
		rows.append([t, n, ev])
		n += 1
	if suppressed and tail != null:
		for e2 in tail.events:
			var ev2: Dictionary = e2.duplicate()
			ev2["f"] = tail_start + int(e2["f"])
			ev2["src_f"] = int(e2["f"])
			rows.append([int(ev2["f"]), n, ev2])
			n += 1
		if clip.marks.has("release"):
			rows.append([length, n, {"f": length, "type": "mark", "name": "release", "clip": clip.id, "synthetic": true}])
			n += 1
	if tier >= 2:
		rows.append([h0, n, {"f": h0, "type": "shake", "trauma": 0.2, "tier_extra": true, "clip": clip.id}])
		n += 1
	if tier >= 3:
		var pf := int(opts.get("t3_prop_f", entry.get("t3_prop_f", -1)))
		if pf < 0:
			pf = clip.mark("accent") + 20 if clip.mark("accent") >= 0 else h0 + 20
		var pt := timeline_frame(pf)
		rows.append([pt, n, {"f": pt, "src_f": pf, "type": "prop", "op": "fall", "prop": String(opts.get("t3_prop", "")),
			"tier": 3, "clip": clip.id}])
		n += 1
		last_beat = String(opts.get("last_beat", ""))
		if last_beat == "":
			var pool := ReactionTable.last_beats_for(clip.rig_id)
			if not pool.is_empty():
				last_beat = pool[posmod(int(opts.get("seed", 0)), pool.size())]
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for r in rows:
		events.append(r[2])
		ev_f.append(int(r[0]))
