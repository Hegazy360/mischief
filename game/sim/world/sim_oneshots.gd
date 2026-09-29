## SimOneshots — the one-shot / phase beats the view plays that are not a state, an activity or a reaction
## (`SimWorld.bellows_oneshot()`, `SimWorld.hush_oneshot()`), and their sim durations in ticks (= clip
## frames). `s2-view`'s `SliceClips` hands these lengths to the rig lint (A29: a one-shot clip's length is
## the sim duration, or it loops). Every number comes from `SimConst`; `-1` = variable (read `len` from the
## accessor: the doorway pause's inserted `90 − eta` ticks, a squeak bit's `squeak_bits.len_f`, the climb-in's
## `hush.enter.busy_s`, a held wheeze).
##
## Accessor shape (one reused Dictionary each, never allocated per call):
##   {id: String ("" = none), t: int (ticks into it, 0 on its first tick), len: int, variant: int}
class_name SimOneshots
extends RefCounted

## Bellows ids.
const HEAD_TURN := "head_turn"
const SPECS_ON := "specs_on"
const DOORWAY_PAUSE := "doorway_pause"
const LOOK_BACK := "look_back"
const BUMP := "bump"
const BUMP_LOOK := "bump_look"
const CURIOUS_STOP := "curious_stop"
const CURIOUS_LOOK := "curious_look"
const CHASE_WHEEZE := "chase_wheeze"
const STUN := "stun"
const FACE_TO_FACE := "face_to_face"
const FIZZLE := "fizzle"
const CAUGHT_GRAB := "caught:grab"
const CAUGHT_LECTURE := "caught:lecture"
const CAUGHT_WIPE := "caught:wipe"
const CAUGHT_DOORSTEP := "caught:doorstep"
## `bit:<bit_id>` — a squeak bit, from its start to `bit_until` (length = `squeak_bits.<id>.len_f`).
const BIT_PREFIX := "bit:"
## Hush ids.
const ENTER := "enter"
const WHEEZE := "wheeze"
const CAUGHT_BUSTED := "caught:busted"
const YANKED := "yanked"
const NEAR_MISS := "near_miss"
const WINK := "wink"

## Sim duration (ticks) per id; -1 = variable (the accessor's `len` is authoritative).
const DURATIONS := {
	"head_turn": SimConst.HEAD_TURN_TICKS,
	"specs_on": SimConst.SPECS_ON_TICKS,
	"doorway_pause": -1,
	"look_back": SimConst.LOOK_BACK_TICKS,
	"bump": SimConst.BUMP_PAT_TICKS + SimConst.BUMP_WALK_ON_TICKS + SimConst.BUMP_TURN_TICKS,
	"bump_look": SimConst.BUMP_LOOK_MAX,
	"curious_stop": SimConst.CURIOUS_STOP_TICKS,
	"curious_look": SimConst.CURIOUS_LOOK_TICKS,
	"chase_wheeze": SimConst.CHASE_WHEEZE,
	"stun": SimConst.DOOR_SLAM_STUN,
	"face_to_face": SimConst.FACE_TO_FACE_TICKS,
	"fizzle": SimConst.FIZZLE_TICKS,
	"caught:grab": SimConst.CAUGHT_BUSTED,
	"caught:lecture": SimConst.CAUGHT_LECTURE,
	"caught:wipe": SimConst.CAUGHT_WIPE,
	"caught:doorstep": SimConst.CAUGHT_HOLD - SimConst.CAUGHT_DOORSTEP_AT,
	"bit:*": -1,
	"enter": -1,
	"wheeze": -1,
	"caught:busted": SimConst.CAUGHT_BUSTED,
	"yanked": SimConst.FIGGIS_YANK_TICKS,
	"near_miss": SimConst.POP_TICKS,
	"wink": SimConst.WINK_TICKS,
}
## Bellows' ids in priority order (the accessor reports the first that applies).
const BELLOWS_IDS: Array[String] = ["caught:grab", "caught:lecture", "caught:wipe", "caught:doorstep", "face_to_face",
	"stun", "chase_wheeze", "bit:*", "bump", "bump_look", "curious_stop", "curious_look", "doorway_pause", "look_back",
	"head_turn", "specs_on", "fizzle"]
## Hush's ids in priority order.
const HUSH_IDS: Array[String] = ["caught:busted", "caught:lecture", "caught:wipe", "caught:doorstep", "enter", "yanked",
	"near_miss", "wink", "wheeze"]


## Sim duration of a one-shot id in ticks (`bit:<id>` → -1: see `squeak_bits`); -1 variable or unknown.
static func duration(id: String) -> int:
	if id.begins_with(BIT_PREFIX):
		return -1
	return int(DURATIONS.get(id, -1))


## The duration of `id` for a given world (resolves the variable ones where the data fixes them:
## `bit:<id>` from `squeak_bits`, `enter` from `hush.enter.busy_s`, `face_to_face` in relaxed mode).
static func duration_in(w: SimWorld, id: String) -> int:
	if id.begins_with(BIT_PREFIX):
		var info: Dictionary = w.db.squeak_bits.get(id.trim_prefix(BIT_PREFIX), {})
		return int(info.get("len", -1))
	match id:
		ENTER:
			return w.ctx.hush_enter_ticks - w.ctx.hush_enter_at
		FACE_TO_FACE:
			return w.ctx.f2f_ticks
	return duration(id)


## Write {id, t, len, variant} into `out` (cleared first).
static func set_to(out: Dictionary, id: String, t: int, length: int, variant: int = 0) -> void:
	out["id"] = id
	out["t"] = t
	out["len"] = length
	out["variant"] = variant


## Bellows' current one-shot into `out` (id "" when none). Read-only.
static func fill_bellows(w: SimWorld, out: Dictionary) -> void:
	var b := w.bellows
	var tk := w.tick
	set_to(out, "", 0, 0, 0)
	if b.state == SimBellows.CAUGHT_HOLD:
		var ct := b.caught_t
		var variant := posmod(b.catches - 1, SimConst.LECTURE_VARIANTS)
		if ct < SimConst.CAUGHT_BUSTED:
			set_to(out, CAUGHT_GRAB, ct, SimConst.CAUGHT_BUSTED, 0)
		elif ct < SimConst.CAUGHT_BUSTED + SimConst.CAUGHT_LECTURE:
			set_to(out, CAUGHT_LECTURE, ct - SimConst.CAUGHT_BUSTED, SimConst.CAUGHT_LECTURE, variant)
		elif ct < SimConst.CAUGHT_DOORSTEP_AT:
			set_to(out, CAUGHT_WIPE, ct - SimConst.CAUGHT_BUSTED - SimConst.CAUGHT_LECTURE, SimConst.CAUGHT_WIPE, 0)
		else:
			set_to(out, CAUGHT_DOORSTEP, ct - SimConst.CAUGHT_DOORSTEP_AT, SimConst.CAUGHT_HOLD - SimConst.CAUGHT_DOORSTEP_AT, 0)
		return
	if w.senses.f2f_active():
		var fl := w.ctx.f2f_ticks
		set_to(out, FACE_TO_FACE, tk - (w.senses.f2f_until - fl), fl, 0)
		return
	if b.state == SimBellows.CHASE:
		if tk < w.chase.stun_until:
			set_to(out, STUN, tk - (w.chase.stun_until - SimConst.DOOR_SLAM_STUN), SimConst.DOOR_SLAM_STUN, 0)
			return
		var wt := w.chase.t - SimConst.CHASE_RUN1
		if wt >= 0 and wt < SimConst.CHASE_WHEEZE:
			set_to(out, CHASE_WHEEZE, wt, SimConst.CHASE_WHEEZE, 0)
		return
	if tk < b.bit_until and b.bit_id != "":
		set_to(out, BIT_PREFIX + b.bit_id, tk - b.bit_t0, b.bit_until - b.bit_t0, 0)
		return
	if b.state == SimBellows.ROUTINE or b.state == SimBellows.DETOUR or b.state == SimBellows.CURIOUS:
		match b.bump_phase:
			SimBellows.BUMP_PAT:
				set_to(out, BUMP, SimConst.BUMP_PAT_TICKS - b.bump_t, duration(BUMP), 0)
				return
			SimBellows.BUMP_WALK_ON:
				set_to(out, BUMP, SimConst.BUMP_PAT_TICKS + SimConst.BUMP_WALK_ON_TICKS - b.bump_t, duration(BUMP), 0)
				return
			SimBellows.BUMP_TURN:
				set_to(out, BUMP, duration(BUMP) - b.bump_t, duration(BUMP), 0)
				return
			SimBellows.BUMP_LOOK:
				set_to(out, BUMP_LOOK, b.look_t, SimConst.BUMP_LOOK_MAX, 0)
				return
	if b.state == SimBellows.CURIOUS:
		var ce := tk - b.curious_t0
		if ce >= 0 and ce < SimConst.CURIOUS_STOP_TICKS:
			set_to(out, CURIOUS_STOP, ce, SimConst.CURIOUS_STOP_TICKS, 0)
			return
		if b.task_kind == SimBellows.T_CURIOUS and b.phase == SimBellows.PH_PERFORM:
			set_to(out, CURIOUS_LOOK, b.activity_t, maxi(1, b.activity_len), 0)
			return
	if b.path != null and not b.path.is_done() and b.path.current_kind() == NavPath.PAUSE:
		var aux := b.path.current_pause_aux()
		var pl: int = b.path.ticks[b.path.cursor]
		if aux == NavPath.AUX_DOORWAY_PAUSE:
			set_to(out, DOORWAY_PAUSE, b.path.leg_t, pl, 0)
			return
		if aux == NavPath.AUX_LOOK_BACK:
			set_to(out, LOOK_BACK, b.path.leg_t, pl, 0)
			return
	if tk < b.head_turn_until:
		set_to(out, HEAD_TURN, tk - (b.head_turn_until - SimConst.HEAD_TURN_TICKS), SimConst.HEAD_TURN_TICKS, 0)
		return
	var se := tk - b.specs_t0
	if b.specs_on and se >= 0 and se < SimConst.SPECS_ON_TICKS:
		set_to(out, SPECS_ON, se, SimConst.SPECS_ON_TICKS, 0)
		return
	var fe := tk - b.fizzle_t0
	if fe >= 0 and fe < SimConst.FIZZLE_TICKS:
		set_to(out, FIZZLE, fe, SimConst.FIZZLE_TICKS, 0)


## Hush's current one-shot into `out` (id "" when none). Read-only.
static func fill_hush(w: SimWorld, out: Dictionary) -> void:
	var hu := w.hush
	var tk := w.tick
	set_to(out, "", 0, 0, 0)
	if hu.state == SimHush.CAUGHT and w.bellows.state == SimBellows.CAUGHT_HOLD:
		var ct := w.bellows.caught_t
		var variant := posmod(w.bellows.catches - 1, SimConst.LECTURE_VARIANTS)
		if ct < SimConst.CAUGHT_BUSTED:
			set_to(out, CAUGHT_BUSTED, ct, SimConst.CAUGHT_BUSTED, 0)
		elif ct < SimConst.CAUGHT_BUSTED + SimConst.CAUGHT_LECTURE:
			set_to(out, CAUGHT_LECTURE, ct - SimConst.CAUGHT_BUSTED, SimConst.CAUGHT_LECTURE, variant)
		elif ct < SimConst.CAUGHT_DOORSTEP_AT:
			set_to(out, CAUGHT_WIPE, ct - SimConst.CAUGHT_BUSTED - SimConst.CAUGHT_LECTURE, SimConst.CAUGHT_WIPE, 0)
		else:
			set_to(out, CAUGHT_DOORSTEP, ct - SimConst.CAUGHT_DOORSTEP_AT, SimConst.CAUGHT_HOLD - SimConst.CAUGHT_DOORSTEP_AT, 0)
		return
	if hu.entering:
		var at := w.ctx.hush_enter_at
		if tk >= at:
			set_to(out, ENTER, tk - at, w.ctx.hush_enter_ticks - at, 0)
		return
	var ye := tk - hu.yank_t0
	if ye >= 0 and ye < SimConst.FIGGIS_YANK_TICKS:
		set_to(out, YANKED, ye, SimConst.FIGGIS_YANK_TICKS, 0)
		return
	var ne := tk - hu.near_miss_t0
	if ne >= 0 and ne < SimConst.POP_TICKS:
		set_to(out, NEAR_MISS, ne, SimConst.POP_TICKS, 0)
		return
	var we := tk - hu.wink_t0
	if we >= 0 and we < SimConst.WINK_TICKS:
		set_to(out, WINK, we, SimConst.WINK_TICKS, 0)
		return
	if hu.wheezing:
		set_to(out, WHEEZE, hu.wheeze_t, SimConst.WHEEZE_MAX_TICKS, 0)
