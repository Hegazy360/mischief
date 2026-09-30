## SimVisibility — can the player see Bellows right now? The one rule for micro-gag credit (D1, ruling L1)
## and the PiP (GDD §3.7) / the 3D Bellows window, plus why (`pip_reason`, R3D ruling R15). Pure: reads the
## world, changes nothing, allocates nothing.
##
##   "room" — Bellows is in Hush's room (a hidden Hush is in her hiding spot's room);
##   "pip"  — not "room", and the GDD §3.7 PiP rule shows him: his room is link-adjacent to hers (doorway,
##            door or the stairs), or his current path ends in her room, or she is RIGGING;
##   "edge" — neither, but the beat has an emote: the HUD edge bubble plays it on his 112 px face;
##   ""     — the player cannot see it (it does not count against dead air).
class_name SimVisibility
extends RefCounted

const ROOM := "room"
const PIP := "pip"
const EDGE := "edge"
const NONE := ""


## Visibility of a beat Bellows performs now (`has_emote`: the beat carries an edge-bubble emote).
static func beat_vis(w: SimWorld, has_emote: bool) -> String:
	if in_room(w):
		return ROOM
	if pip_shows(w):
		return PIP
	return EDGE if has_emote else NONE


## True when Bellows is in Hush's room.
static func in_room(w: SimWorld) -> bool:
	return w.bellows.room >= 0 and w.bellows.room == w.hush.room


## The GDD §3.7 PiP rule (ignoring the "he is off-screen" half, which only the view knows): he is one link
## away from Hush's room, heading to her room, or she is rigging.
static func pip_shows(w: SimWorld) -> bool:
	var b := w.bellows
	var hr := w.hush.room
	if hr < 0 or b.room < 0:
		return false
	if b.room == hr:
		return true
	if w.db.nav.linked(b.room, hr):
		return true
	if b.path != null and not b.path.is_done() and b.path.final_room() == hr:
		return true
	return w.hush.state == SimHush.RIGGING


## Why the Bellows window may show him (R3D ruling R15; `pip_shows` unchanged): `&""` when `pip_shows` is false,
## `&"room"` (same room), `&"heading"` (his current path ends in her room), `&"rigging"` (she is rigging), else
## `&"adjacent"` (only the nav link) — heading and rigging win over adjacent. The Bellows window's `"lean"` mode
## replaces the window with the HUD edge badge on `&"adjacent"`. Pure and allocation-free (StringName literals).
static func pip_reason(w: SimWorld) -> StringName:
	var b := w.bellows
	var hr := w.hush.room
	if hr < 0 or b.room < 0:
		return &""
	if b.room == hr:
		return &"room"
	if b.path != null and not b.path.is_done() and b.path.final_room() == hr:
		return &"heading"
	if w.hush.state == SimHush.RIGGING:
		return &"rigging"
	if w.db.nav.linked(b.room, hr):
		return &"adjacent"
	return &""
