## SimFf — the one ⏩ drop rule (GDD §3.3, ruling L2). ⏩ (world ×3) is only honoured while Hush is hidden;
## it drops to ×1 on a prank trigger (`prank_fire`), a "?" starting (`spot_start`) or an entry warning for
## Hush's room (`entry_warning` whose room is hers, or unnamed). `SimDriver` uses it to release ⏩, and the
## solver's dead-air model uses it to decide which hidden ticks a player really fast-forwards through.
## Pure; no state.
class_name SimFf
extends RefCounted

## World speed while ⏩ is held and honoured.
const RATE := 3


## True when `ev` drops a held ⏩ (`hush_room`: Hush's room id at that tick).
static func drops(ev: Dictionary, hush_room: String) -> bool:
	match str(ev.get("e", "")):
		"prank_fire", "spot_start":
			return true
		"entry_warning":
			var r := str(ev.get("room", ""))
			return r == "" or r == hush_room
	return false
