## SimCmd — the commands of TECH §3.5 (the only way anything changes the sim).
##
## Each command is a Dictionary with key "c". Unknown or invalid commands are ignored and produce a
## `cmd_rejected {c, why}` event (never an error). Helpers below build well-formed commands.
##
## | c | fields |
## |---|---|
## | go | hotspot: String, run: bool |
## | move | room: String, x: int (px), run: bool |
## | pick | item: String |
## | rig | on: bool |
## | freeze | on: bool |
## | squeak | — |
## | wheeze | on: bool |
## | pin | room: String, x: int (px) — or hotspot: String |
## | pop_out | run: bool |
## | bow | — |
## | hint_used | line: String, step: int |
##
## Busy and the queue: Hush is busy while rummaging, diving, popping out, squeaking from a stand, holding
## RIG with the ring filling, in the Lecture, bowing, or crossing a door / the stairs. A go/move while
## busy is stored as the single `queued` command (a newer one replaces it) and runs the tick the busy
## action ends — for a rig: when the step completes or the hold is released. freeze/rig are never queued.
class_name SimCmd
extends RefCounted

const GO := "go"
const MOVE := "move"
const PICK := "pick"
const RIG := "rig"
const FREEZE := "freeze"
const SQUEAK := "squeak"
const WHEEZE := "wheeze"
const PIN := "pin"
const POP_OUT := "pop_out"
const BOW := "bow"
const HINT_USED := "hint_used"
const ALL: Array[String] = [GO, MOVE, PICK, RIG, FREEZE, SQUEAK, WHEEZE, PIN, POP_OUT, BOW, HINT_USED]


## {c: go}
static func go(hotspot: String, run: bool = false) -> Dictionary:
	return {"c": GO, "hotspot": hotspot, "run": run}


## {c: move}
static func move(room: String, x_px: int, run: bool = false) -> Dictionary:
	return {"c": MOVE, "room": room, "x": x_px, "run": run}


## {c: pick}
static func pick(item: String) -> Dictionary:
	return {"c": PICK, "item": item}


## {c: rig}
static func rig(on: bool) -> Dictionary:
	return {"c": RIG, "on": on}


## {c: freeze}
static func freeze(on: bool) -> Dictionary:
	return {"c": FREEZE, "on": on}


## {c: squeak}
static func squeak() -> Dictionary:
	return {"c": SQUEAK}


## {c: wheeze}
static func wheeze(on: bool) -> Dictionary:
	return {"c": WHEEZE, "on": on}


## {c: pin} at a floor point.
static func pin(room: String, x_px: int) -> Dictionary:
	return {"c": PIN, "room": room, "x": x_px}


## {c: pin} at a hotspot.
static func pin_hotspot(hotspot: String) -> Dictionary:
	return {"c": PIN, "hotspot": hotspot}


## {c: pop_out}
static func pop_out(run: bool = false) -> Dictionary:
	return {"c": POP_OUT, "run": run}


## {c: bow}
static func bow() -> Dictionary:
	return {"c": BOW}


## {c: hint_used}
static func hint_used(line: String, step: int) -> Dictionary:
	return {"c": HINT_USED, "line": line, "step": step}
