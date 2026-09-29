## HapticsDirector — the view's thumb channel (GDD §3.10, s2-view brief §4.2.5): maps sim events to
## the `Haptics` autoload's named pulses. NightScene instantiates it and calls `setup(driver)`.
##
## | Event | Pulse |
## |---|---|
## | `rigged` | `rig_done` (30 ms / 0.7) |
## | `reaction_accent` | `accent` (40 + 60 ms) |
## | `near_miss` | `near_miss` (20 ms) |
## | `caught` | `caught` (3 × 30 ms) |
## | `meltdown_stomp` | `stomp` (60 ms each) |
## | `cmd_rejected` | none (a grey ripple and a shrug are enough) |
##
## The Settings `haptics` toggle and the rate limit (6 pulses per rolling second) live in the
## autoload; this class also checks the toggle itself so a missing autoload never vibrates.
class_name HapticsDirector
extends Node

const MAP := {"rigged": &"rig_done", "reaction_accent": &"accent", "near_miss": &"near_miss",
	"caught": &"caught", "meltdown_stomp": &"stomp"}

var driver: SimDriver = null
## The Haptics node (the autoload by default; tests inject a stand-in).
var haptics: Node = null
## Every pulse requested, in order (tests).
var requested: Array[StringName] = []
## No pulses at all (scenario seeks, retries).
var muted: bool = false


func _init() -> void:
	name = "HapticsDirector"


## Connect to the driver's per-tick events. `h` overrides the Haptics autoload (tests).
func setup(d: SimDriver, h: Node = null) -> void:
	driver = d
	haptics = h if h != null else ViewKit.autoload("Haptics")
	if driver != null and not driver.ticked.is_connected(on_ticked):
		driver.ticked.connect(on_ticked)


## The pulse name for a sim event (&"" = none).
static func pulse_for(ev: Dictionary) -> StringName:
	return MAP.get(ViewKit.s(ev.get("e", "")), &"")


func on_ticked(events: Array) -> void:
	if muted:
		return
	for ev in events:
		var p := HapticsDirector.pulse_for(ev)
		if p == &"":
			continue
		if not bool(ViewKit.setting("haptics", true)):
			continue
		requested.append(p)
		if haptics != null and haptics.has_method("pulse"):
			haptics.call("pulse", p)
