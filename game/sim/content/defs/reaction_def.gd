## ReactionDef — reaction timings the sim trusts (TECH §4.5, §3.7.4).
##
## Length per tier: `frames + hold_len × (tier_scale − 100) / 100` (tier_scale 100/120/150);
## suppressed replaces the settle (hold end → frames) with SimConst.SUPPRESSED_SETTLE frames.
## Frames after the hold start are time-remapped by the tier stretch (`remap()`), exactly as the rig
## player stretches the hold interval.
class_name ReactionDef
extends RefCounted

var id: String = ""
var clip: String = ""
var frames: int = SimConst.DEFAULT_RX_FRAMES
var antic: int = 0
var accent: int = SimConst.DEFAULT_RX_ACCENT
var hold0: int = SimConst.DEFAULT_RX_ACCENT + 3
var hold1: int = SimConst.DEFAULT_RX_FRAMES - 10
var release: int = SimConst.DEFAULT_RX_FRAMES
var knock_on: int = -1
var has_travel: bool = false
var travel_from: int = 0
var travel_to: int = 0
var travel_ease: String = "linear"
var travel_ease_id: int = 0
var arc_px: int = 0
var t3_prop_f: int = -1
var cam: Dictionary = {}
## Derived lengths: [unused, T1, T2, T3] and suppressed [unused, T1, T2, T3].
var len_by_tier: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var len_suppressed: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## True when this def was synthesised because reactions.json lacked the key.
var fallback: bool = false


## Parse a reactions.json archetypes entry.
static func from_dict(key: String, d: Dictionary) -> ReactionDef:
	var r := ReactionDef.new()
	r.id = key
	r.clip = ContentUtil.s(d, "clip")
	r.frames = maxi(1, ContentUtil.i(d, "frames", SimConst.DEFAULT_RX_FRAMES))
	var m := ContentUtil.dict(d, "marks")
	r.antic = ContentUtil.i(m, "antic", 0)
	r.accent = ContentUtil.i(m, "accent", mini(SimConst.DEFAULT_RX_ACCENT, r.frames - 1))
	var hold := ContentUtil.arr(m, "hold")
	if hold.size() >= 2:
		r.hold0 = roundi(float(hold[0]))
		r.hold1 = roundi(float(hold[1]))
	else:
		r.hold0 = mini(r.accent + 3, r.frames)
		r.hold1 = maxi(r.hold0, r.frames - 10)
	r.release = ContentUtil.i(m, "release", r.frames)
	r.knock_on = ContentUtil.i(m, "knock_on", -1)
	var tr := ContentUtil.dict(d, "travel")
	if not tr.is_empty():
		r.has_travel = true
		r.travel_from = ContentUtil.i(tr, "from_f", r.accent)
		r.travel_to = maxi(r.travel_from, ContentUtil.i(tr, "to_f", r.accent))
		r.travel_ease = ContentUtil.s(tr, "ease", "linear")
		r.travel_ease_id = EaseI.id_of(r.travel_ease)
		r.arc_px = ContentUtil.i(tr, "arc_px", 0)
	r.t3_prop_f = ContentUtil.i(d, "t3_prop_f", -1)
	r.cam = ContentUtil.dict(d, "cam")
	r.derive()
	return r


## A default reaction used when reactions.json lacks an archetype key (validate() reports it).
static func make_fallback(key: String) -> ReactionDef:
	var r := ReactionDef.new()
	r.id = key
	r.fallback = true
	r.derive()
	return r


## Compute the per-tier lengths.
func derive() -> void:
	var hold_len := maxi(0, hold1 - hold0)
	var settle := maxi(0, frames - hold1)
	for t in [1, 2, 3]:
		var ext := Fx.div(hold_len * (SimConst.TIER_SCALE[t] - 100), 100)
		len_by_tier[t] = frames + ext
		len_suppressed[t] = frames + ext - settle + SimConst.SUPPRESSED_SETTLE


## Reaction length for a tier (1..3) and the suppressed flag.
func length(tier: int, suppressed: bool) -> int:
	var t := clampi(tier, 1, 3)
	return len_suppressed[t] if suppressed else len_by_tier[t]


## Map an authored clip frame to its tier-stretched frame (hold interval scaled).
func remap(f: int, tier: int) -> int:
	var t := clampi(tier, 1, 3)
	var scale: int = SimConst.TIER_SCALE[t]
	if f <= hold0 or scale == 100:
		return f
	if f <= hold1:
		return hold0 + Fx.div((f - hold0) * scale, 100)
	return f + Fx.div((hold1 - hold0) * (scale - 100), 100)
