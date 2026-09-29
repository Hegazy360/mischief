## FakeWorld — a scripted stand-in for `SimWorld` (TECH §3.4) so the whole view runs, is
## tested and is screenshotted before the real sim exists. It exposes the same accessors
## (`tick`, `hush`, `bellows`, `step`, `drain_events`, `bubble`, `hotspot_state`,
## `bellows_path_preview`, `applause_tenths`, `link`, `fuse_ticks`, `tomatoes`, …) with the
## TECH §3.7.1–§3.7.2 field names and emits TECH §3.8 events from a ≈ 47 s timeline that
## covers every view feature: tiptoe + tap feedback, a Q rig, a squeak (ring + ear pip + bit),
## the thought bubble ring, an entry warning with "BEHIND YOU!", a run + dive, the stare strip
## (specs off / on), footprints, the first-time approach slow-mo, ACHOO-RIA! (T3), a residue
## detour, the PiP (rigging) and the escalated Gag-Cam PiP (an off-screen TIME'S UP, link 2),
## a near miss, a chain (IN A PICKLE link 3 → knock-on TAP DANCE link 4 → freeze-frame), a
## Meltdown with stomps and quake props, a spot → "!" → chase → catch → Busted Cam → Lecture
## → doorstep tomato. `SCENARIOS` maps screenshot names to start ticks (frame 60 after the
## start shows the moment).
##
## It also provides the content lookups the view uses (`prank_info`, `reaction_info`,
## `combo_info`, `activity_info`, `prank_ids`, `hotspot_ids`, `house_layout`, `episode`).
class_name FakeWorld
extends RefCounted

## Scenario → start tick (see ViewSandbox; shoot at frame 60 unless noted).
const SCENARIOS := {
	"walk": 0, "bubble": 140, "squeak_rings": 190, "entry_warning": 390, "stare_off": 465,
	"gag_punch": 732, "captions": 1818, "pip": 1080, "pip_escalate": 1215, "stare_on": 1530,
	"near_miss": 1580, "stalls_t4": 1700, "spotted": 2418, "busted_cam": 2520, "overview": 1000,
	"peek": 950, "full": 0,
	# Stage 2 (s2-view): micro-gags over the tea loop, Hush's hidden eyes tracking him past the
	# pantry, a tap held during the climb-in, the caught sequence (Busted Cam → Lecture →
	# doorstep), the Busted Cam with rigs, the door-frame bonk cue, his legs on the stairs.
	"micro_gag": 540, "hidden_eyes": 500, "queued_tap": 0, "caught": 2600, "busted_rig": 2548,
	"doorframe": 930, "stairs": 0, "residue": 850, "squeak_bit": 236,
}
## Scenarios that switch on a scripted demo instead of the main timeline.
const DEMOS := {"stairs": "stairs"}
const END_TICK := 2830
const WALK := 400.0 / 60.0
const RUN := 720.0 / 60.0


class FakeHush:
	var room: String = "kitchen"
	var floor: int = 0
	var x_sub: int = 0
	var facing: int = -1
	var state: String = "IDLE"
	var hidden_spot: String = ""
	var watched_spot: String = ""
	var frozen: bool = false
	var freeze_pose_seed: int = 3
	var carrying: Array = []
	var rig_prank: String = ""
	var rig_step: int = 0
	var pin: Variant = null
	var queued: Variant = null
	var last_input_tick: int = 0
	var arm_moving_until: int = 0


class FakeBellows:
	var room: String = "parlour"
	var floor: int = 0
	var x_sub: int = 0
	var facing: int = -1
	var state: String = "ROUTINE"
	var activity_id: String = ""
	var activity_t: int = 0
	var activity_len: int = 0
	var detour: Variant = null
	var specs_on: bool = false
	var blinded_until: int = 0
	var temper_q: int = 0
	var tier: int = 0
	var residues: Array = []
	var spot_meter: int = 0
	var spot_fill: int = 60
	var ear_pips: int = 0
	var reacting: Variant = null
	var bump_count: int = 0
	var look_back_until: int = 0
	var on_guard_until: int = 0


var tick: int = 0
var ended: bool = false
var end_reason: String = ""
var hush: FakeHush = null
var bellows: FakeBellows = null
var beryl: Variant = null
var delphine: Variant = null
var episode: Dictionary = {"id": "fake_night", "rooms": ["hall", "parlour", "kitchen"]}
var db: Variant = null
var layout: HouseLayout = null
## Loop back to tick 0 after END_TICK (continuous sandbox runs).
var loop: bool = true
## A side demo ("" = the main timeline; "stairs" = Bellows coming down the stairs into the hall).
var demo: String = ""
var _caught_t0 := -1
var _lecture_var := 0
var _bit_t0 := -1
var _bit_len := 0
var _bit_id := ""
var _oneshot_b := {"id": "", "t": 0, "len": 0, "variant": 0}
var _oneshot_h := {"id": "", "t": 0, "len": 0, "variant": 0}
var _leg_b := {"kind": ""}
var _leg_h := {"kind": ""}

var _events: Array = []
var _script: Dictionary = {}
var _hx_target := -1.0
var _hx_speed := WALK
var _hx_state := "WALK"
var _h_after := ""
var _bx_target := -1.0
var _bx_speed := 4.0
var _spot_dir := 0
var _react: Dictionary = {}
var _react_x0 := 0.0
var _hot: Dictionary = {}
var _applause := 0
var _link := 0
var _fuse := 0
var _tomatoes := 0
var _next := "tea"
var _next_detour := false
var _rig_t0 := -1
var _rig_len := 48
var _busy_until := 0
var _busy_state := ""
var _busy_then := ""
var _perform := false


static func create() -> FakeWorld:
	var w := FakeWorld.new()
	w.layout = HouseLayout.load_default()
	w.reset()
	return w


## Retry: back to tick 0 (identical run).
func reset() -> void:
	tick = 0
	ended = false
	end_reason = ""
	_events.clear()
	hush = FakeHush.new()
	bellows = FakeBellows.new()
	hush.x_sub = _sub(_hx("kitchen_window_x", 3800.0))
	bellows.x_sub = _sub(1720.0)
	bellows.activity_id = "warmup"
	bellows.activity_len = 300
	_perform = true
	_next = "tea"
	_next_detour = false
	_hx_target = -1.0
	_bx_target = -1.0
	_spot_dir = 0
	_react = {}
	_applause = 0
	_link = 0
	_fuse = 0
	_tomatoes = 0
	_rig_t0 = -1
	_busy_until = 0
	_h_after = ""
	_caught_t0 = -1
	_bit_t0 = -1
	_init_hotspots()
	_build_script()
	if demo == "stairs":
		_build_stairs_demo()


## Run until `t` (scenario seek). Events stay queued for the caller to drain.
func seek(t: int) -> void:
	while tick < t:
		step([])


# --- SimWorld accessors (TECH §3.4) ---------------------------------------------------------

func step(_cmds: Array) -> void:
	tick += 1
	var acts: Variant = _script.get(tick, null)
	if acts is Array:
		for a in acts:
			_do(a)
	_update_hush()
	if demo == "stairs":
		_update_stairs_demo()
	if _leg_b.get("kind", "") != "stairs":
		_update_bellows()
	if _fuse > 0:
		_fuse -= 1
	if tick >= END_TICK:
		if loop:
			var ev := _events.duplicate()
			reset()
			_events = ev
		else:
			ended = true
			end_reason = "bow"


func drain_events() -> Array:
	var out := _events
	_events = []
	return out


func state_hash() -> int:
	return hash([tick, hush.x_sub, bellows.x_sub, hush.state, bellows.state, _applause])


func applause_tenths() -> int:
	return _applause


func stars() -> Array:
	return [_applause >= 350, false, _applause >= 1000]


func link() -> int:
	return _link


func fuse_ticks() -> int:
	return _fuse


func tomatoes() -> int:
	return _tomatoes


func tomatoes_max() -> int:
	return -1


func line_states() -> Array:
	return []


func prank_state(id: String) -> int:
	var rp := String(prank_info(id).get("rig_point", ""))
	var h: Dictionary = _hot.get(rp, {})
	if bool(h.get("spent", false)):
		return 5
	return 3 if bool(h.get("rigged", false)) else 1


func rig_progress_pm(_id: String) -> int:
	if _rig_t0 < 0:
		return 0
	return clampi((tick - _rig_t0) * 1000 / maxi(1, _rig_len), 0, 1000)


func hotspot_state(id: String) -> Dictionary:
	var h: Variant = _hot.get(id, null)
	if h == null:
		var hs := layout.hotspot(id)
		return {"kind": hs.kind if hs != null else "", "enabled": true, "stock": [], "occupant": false,
			"in_use_next": false, "spent": false, "rigged": false, "needs_item": "", "seen": true}
	return (h as Dictionary).duplicate()


func hotspot_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for hs in layout.hotspots:
		out.append(hs.id)
	return out


func bubble() -> Dictionary:
	var ring := -1
	if _perform and bellows.activity_len > 0 and bellows.state == "ROUTINE":
		var left := bellows.activity_len - bellows.activity_t
		if left <= 240:
			ring = left
	return {"next": _next, "icon": "", "ring_ticks": ring, "glyph": _glyph(), "ear_pips": bellows.ear_pips,
		"detour": _next_detour}


func bellows_path_preview(ticks: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if _bx_target < 0.0 or bellows.state == "REACTING":
		return out
	var x := float(bellows.x_sub) / 60.0
	var dir := signf(_bx_target - x)
	var n := ticks / 10
	for i in n:
		x += dir * _bx_speed * 10.0
		if (dir > 0.0 and x > _bx_target) or (dir < 0.0 and x < _bx_target):
			x = _bx_target
		out.append(layout.sorted_room_ids().find(layout.room_at(bellows.floor, x)))
		out.append(int(x * 60.0))
	return out


func hush_can_see(_hotspot_id: String) -> bool:
	return true


## s2-sim §4.4b one-shot accessors: {id, t, len, variant} (the caught phases, the squeak bit, the
## climb-in, the look-back); one reused Dictionary each.
func bellows_oneshot() -> Dictionary:
	var o := _oneshot_b
	o["id"] = ""
	o["t"] = 0
	o["len"] = 0
	o["variant"] = 0
	if _caught_t0 >= 0 and bellows.state == "CAUGHT_HOLD":
		var ct := tick - _caught_t0
		if ct < 60:
			_os(o, "caught:grab", ct, 60, 0)
		elif ct < 192:
			_os(o, "caught:lecture", ct - 60, 132, _lecture_var)
		elif ct < 204:
			_os(o, "caught:wipe", ct - 192, 12, 0)
		else:
			_os(o, "caught:doorstep", ct - 204, 36, 0)
		return o
	if _bit_t0 >= 0 and tick < _bit_t0 + _bit_len:
		_os(o, "bit:" + _bit_id, tick - _bit_t0, _bit_len, 0)
		return o
	if bellows.look_back_until > tick and bellows.state != "REACTING":
		_os(o, "look_back", 30 - (bellows.look_back_until - tick), 30, 0)
	return o


func hush_oneshot() -> Dictionary:
	var o := _oneshot_h
	o["id"] = ""
	o["t"] = 0
	o["len"] = 0
	o["variant"] = 0
	if _caught_t0 >= 0 and hush.state == "CAUGHT" or (_caught_t0 >= 0 and tick - _caught_t0 < 240 and bellows.state == "CAUGHT_HOLD"):
		var ct := tick - _caught_t0
		if ct < 60:
			_os(o, "caught:busted", ct, 60, 0)
		elif ct < 192:
			_os(o, "caught:lecture", ct - 60, 132, _lecture_var)
		elif ct < 204:
			_os(o, "caught:wipe", ct - 192, 12, 0)
		else:
			_os(o, "caught:doorstep", ct - 204, 36, 0)
		return o
	if tick < 40 and demo == "":
		_os(o, "enter", tick, 40, 0)
	return o


static func _os(o: Dictionary, id: String, t: int, n: int, v: int) -> void:
	o["id"] = id
	o["t"] = t
	o["len"] = n
	o["variant"] = v


## s2-sim §4.5.2 leg accessors: {kind, from_room, to_room, from_x, to_x, progress_pm}.
func bellows_leg() -> Dictionary:
	return _leg_b


func hush_leg() -> Dictionary:
	return _leg_h


## s2-sim §4.4 sight: {moving_px, frozen_px, to_wall, blind}.
func sight_ranges() -> Dictionary:
	var b := bellows
	if b.state == "REACTING" or b.state == "MELTDOWN" or b.state == "CAUGHT_HOLD":
		return {"moving_px": 0, "frozen_px": 0, "to_wall": false, "blind": true}
	if b.blinded_until > tick:
		return {"moving_px": 150, "frozen_px": 150, "to_wall": false, "blind": false}
	if b.specs_on:
		return {"moving_px": -1, "frozen_px": 600, "to_wall": true, "blind": false}
	return {"moving_px": 600, "frozen_px": 250, "to_wall": false, "blind": false}


func house_layout() -> HouseLayout:
	return layout


# --- content lookups (the view's ContentInfo reads these) ---------------------------------

func prank_ids() -> PackedStringArray:
	return PackedStringArray(["achoo_ria", "in_a_pickle", "tap_dance", "times_up"])


func prank_info(id: String) -> Variant:
	match id:
		"achoo_ria":
			return {"caption": "ACHOO-RIA!", "size": "M", "rig_point": "kitchen_honey",
				"trigger": {"type": "use", "activity": "tea", "mark_s": 2.4}, "reaction": {"archetype": "sneeze_blast"}}
		"times_up":
			return {"caption": "TIME'S UP!", "size": "M", "rig_point": "hall_clock",
				"trigger": {"type": "use", "activity": "clock", "mark_s": 1.0}, "reaction": {"archetype": "jackhammer_cling"}}
		"in_a_pickle":
			return {"caption": "IN A PICKLE", "size": "L", "rig_point": "kitchen_pickle_jar",
				"trigger": {"type": "use", "activity": "pickles", "mark_s": 1.0}, "reaction": {"archetype": "strain_slip"}}
		"tap_dance":
			return {"caption": "TAP DANCE!", "size": "S", "rig_point": "kitchen_sink_tap",
				"trigger": {"type": "use", "activity": "rinse", "mark_s": 1.0}, "reaction": {"archetype": "drench"}}
	return null


func reaction_info(key: String) -> Variant:
	match key:
		"sneeze_blast_a":
			return {"frames": 150, "marks": {"antic": 62, "accent": 92, "hold": [95, 140], "release": 150},
				"cam": {"zoom": 1.4, "hitstop": 5}, "t3_prop_f": 112}
		"jackhammer_cling_a":
			return {"frames": 150, "marks": {"antic": 40, "accent": 60, "hold": [63, 130], "release": 150},
				"cam": {"zoom": 1.3, "hitstop": 5}, "t3_prop_f": 80}
		"strain_slip_a":
			return {"frames": 180, "marks": {"antic": 40, "accent": 70, "hold": [73, 150], "release": 180},
				"cam": {"zoom": 1.3, "hitstop": 5}, "t3_prop_f": 90}
		"drench_a":
			return {"frames": 120, "marks": {"antic": 30, "accent": 40, "hold": [43, 105], "release": 120},
				"cam": {"zoom": 1.6, "hitstop": 8}, "t3_prop_f": 60}
	return null


func combo_info(id: String) -> Variant:
	return {"caption": id.to_upper().replace("_", " ") + "!"}


func activity_info(id: String) -> Variant:
	match id:
		"nap":
			return {"awareness": "asleep", "bar": "sleep"}
		"bath":
			return {"awareness": "absorbed", "bar": "bath"}
	return {"awareness": "normal", "bar": null}


# --- script --------------------------------------------------------------------------------

func _hx(id: String, def: float) -> float:
	var hs := layout.hotspot(id) if layout != null else null
	return hs.use_x if hs != null else def


func _init_hotspots() -> void:
	_hot.clear()
	for hs in layout.hotspots:
		_hot[hs.id] = {"kind": hs.kind, "enabled": true, "stock": [], "occupant": false, "in_use_next": false,
			"spent": false, "rigged": false, "needs_item": "", "seen": true}
	_set_hot("hall_confiscated_box", "stock", ["squeaker", "magnifier"])
	_set_hot("kitchen_fridge", "stock", ["kipper", "butter"])
	_set_hot("kitchen_pantry_shelf", "stock", ["flour"])
	_set_hot("kitchen_kettle", "needs_item", "squeaker")
	_set_hot("hall_clock", "rigged", true)
	_set_hot("hall_clock_case", "in_use_next", true)


func _set_hot(id: String, key: String, v: Variant) -> void:
	if _hot.has(id):
		(_hot[id] as Dictionary)[key] = v


func _at(t: int, a: Array) -> void:
	if not _script.has(t):
		_script[t] = []
	(_script[t] as Array).append(a)


func _ev(t: int, e: Dictionary) -> void:
	_at(t, ["ev", e])


func _build_script() -> void:
	_script.clear()
	var honey := _hx("kitchen_honey", 2950.0)
	var pantry := _hx("kitchen_pantry_curtain", 3650.0)
	var sink := _hx("kitchen_sink_tap", 3810.0)
	var pickle := _hx("kitchen_pickle_jar", 3130.0)
	# A — tiptoe, rig, squeak, bubble, entry warning, run + dive, specs-off strip, ACHOO-RIA!
	# A tap held during the climb-in (cmd_queued → the pulsing "…" marker until hush_go).
	_ev(12, {"e": "_tap", "room": "kitchen", "x": honey})
	_ev(12, {"e": "cmd_queued", "c": "go", "why": "entering", "target": "kitchen_honey"})
	_ev(50, {"e": "hush_go", "target": "kitchen_honey", "run": false})
	# Micro-gags (s2-sim micro_gag events): over the warm-up, then over the tea loop.
	_ev(110, {"e": "micro_gag", "id": "admire_reflection_horn", "activity": "warmup", "room": "parlour", "x": 1720,
		"len": 60, "emote": "smug", "vis": "pip"})
	_ev(566, {"e": "micro_gag", "id": "admire_in_kettle", "activity": "tea", "room": "kitchen", "x": 2940,
		"len": 48, "emote": "smug", "vis": "room"})
	_ev(630, {"e": "micro_gag", "id": "pinkie_up", "activity": "tea", "room": "kitchen", "x": 2940,
		"len": 48, "emote": "yum", "vis": "room"})
	_at(50, ["h_move", honey, WALK, ""])
	_at(180, ["h_rig", "achoo_ria", 48])
	_ev(180, {"e": "rig_start", "prank": "achoo_ria", "step": 0})
	_at(228, ["h_rigged", "achoo_ria", "kitchen_honey"])
	_at(240, ["h_squeak"])
	_ev(240, {"e": "squeak", "room": "kitchen", "x": int(honey), "heard": true})
	_ev(240, {"e": "noise", "kind": "squeak", "room": "kitchen", "x": int(honey), "r": 700})
	_at(242, ["b_pips", 1])
	_ev(242, {"e": "ear_pip", "n": 1})
	_ev(244, {"e": "squeak_bit", "bit": "bit_warmup", "score": 20})
	_at(244, ["bit", "bit_warmup", 90])
	_at(244, ["applause", 20, "bit", "bit_warmup"])
	_ev(300, {"e": "b_activity_end", "id": "warmup"})
	_at(300, ["b_move", 2900.0, 5.0, 1])
	_ev(426, {"e": "entry_warning", "room": "kitchen", "eta": 90})
	_ev(436, {"e": "hush_go", "target": "kitchen_pantry_curtain", "run": true})
	_at(436, ["h_move", pantry, RUN, "dive:kitchen_pantry_curtain"])
	_ev(446, {"e": "noise", "kind": "run", "room": "kitchen", "x": int(honey + 120.0), "r": 500})
	_ev(476, {"e": "noise", "kind": "run", "room": "kitchen", "x": int(honey + 480.0), "r": 500})
	_ev(516, {"e": "b_room", "room": "kitchen"})
	_at(536, ["b_activity", "tea", 300, "pickles"])
	_ev(536, {"e": "b_activity", "id": "tea"})
	_ev(536, {"e": "b_next", "id": "pickles", "detour": false})
	_at(680, ["b_react", "achoo_ria", "sneeze_blast", "a", 150, 0, 92, 110, 3760.0, 1])
	_ev(680, {"e": "prank_fire", "prank": "achoo_ria", "trigger": "use", "link": 1, "tier": 1, "witnessed": false})
	_ev(680, {"e": "reaction_start", "prank": "achoo_ria", "archetype": "sneeze_blast", "variant": "a", "tier": 1,
		"suppressed": false, "len": 150, "entry": 0})
	_ev(772, {"e": "reaction_accent", "prank": "achoo_ria"})
	_at(772, ["applause", 350, "gag", "achoo_ria"])
	_at(772, ["temper", 35, 1])
	_at(772, ["link", 1])
	_at(830, ["b_react_end", "achoo_ria", "kitchen_honey"])
	_at(830, ["residue", "FRAZZLED", 600])
	_ev(830, {"e": "b_detour", "kind": "fixup_mirror", "station": "st_hall_mirror", "why": "FRAZZLED"})
	_at(830, ["b_next", "fixup_mirror", true])
	# B — detour to the hall mirror; Hush rigs the sink (PiP: rigging) and the pickle jar while
	# TIME'S UP fires off screen (the escalated Gag-Cam PiP).
	_at(850, ["b_move", 1080.0, 8.0, -1])
	_ev(970, {"e": "b_room", "room": "parlour"})
	_ev(968, {"e": "director_cue", "id": "laugh_doorframe"})
	_ev(1132, {"e": "b_room", "room": "hall"})
	_at(880, ["h_pop"])
	_ev(880, {"e": "pop_out", "spot": "kitchen_pantry_curtain"})
	_at(892, ["h_move", sink, WALK, ""])
	_at(930, ["h_rig", "tap_dance", 90])
	_ev(930, {"e": "rig_start", "prank": "tap_dance", "step": 0})
	_at(1020, ["h_rigged", "tap_dance", "kitchen_sink_tap"])
	_at(1030, ["h_move", pickle, WALK, ""])
	_at(1140, ["h_rig", "in_a_pickle", 110])
	_ev(1140, {"e": "rig_start", "prank": "in_a_pickle", "step": 0})
	_at(1185, ["b_activity", "fixup_mirror", 240, "clock"])
	_at(1200, ["b_react", "times_up", "jackhammer_cling", "a", 150, 0, 60, 80, 1330.0, -1])
	_ev(1200, {"e": "prank_fire", "prank": "times_up", "trigger": "use", "link": 2, "tier": 1, "witnessed": false})
	_ev(1200, {"e": "reaction_start", "prank": "times_up", "archetype": "jackhammer_cling", "variant": "a", "tier": 1,
		"suppressed": false, "len": 150, "entry": 0})
	_ev(1260, {"e": "reaction_accent", "prank": "times_up"})
	_at(1260, ["applause", 196, "gag", "times_up"])
	_at(1260, ["temper", 70, 2])
	_at(1260, ["link", 2])
	_at(1250, ["h_rigged", "in_a_pickle", "kitchen_pickle_jar"])
	_at(1350, ["b_react_end", "times_up", "hall_clock"])
	# C — Livid: specs jammed on, into Hush's room; the "?" fills on frozen Hush, he turns, NEAR MISS.
	_at(1352, ["temper", 80, 3])
	_at(1352, ["specs", true])
	_at(1352, ["b_next", "pickles", false])
	_at(1360, ["b_move", pickle - 60.0, 8.0, 1])
	_ev(1454, {"e": "entry_warning", "room": "kitchen", "eta": 90})
	_at(1440, ["h_move", pickle + 330.0, WALK, "freeze"])
	_ev(1544, {"e": "b_room", "room": "kitchen"})
	_at(1555, ["spot", 1])
	_ev(1555, {"e": "spot_start", "by": "bellows"})
	_at(1592, ["b_face", -1])
	_ev(1592, {"e": "look_back"})
	_at(1592, ["spot", -1])
	_ev(1612, {"e": "near_miss", "by": "bellows"})
	_ev(1612, {"e": "bonus", "kind": "near_miss", "amount": 20})
	_at(1612, ["applause", 20, "bonus", "NEAR MISS!"])
	# D — the chain: IN A PICKLE (link 3) → knock-on TAP DANCE (link 4) → Meltdown.
	_at(1600, ["b_activity", "pickles", 180, "rinse"])
	_ev(1600, {"e": "b_activity", "id": "pickles"})
	_at(1660, ["b_react", "in_a_pickle", "strain_slip", "a", 180, 0, 100, 125, sink - 50.0, 1])
	_ev(1660, {"e": "prank_fire", "prank": "in_a_pickle", "trigger": "use", "link": 3, "tier": 3, "witnessed": false})
	_ev(1660, {"e": "reaction_start", "prank": "in_a_pickle", "archetype": "strain_slip", "variant": "a", "tier": 3,
		"suppressed": false, "len": 180, "entry": 0})
	_ev(1730, {"e": "reaction_accent", "prank": "in_a_pickle"})
	_at(1730, ["applause", 400, "gag", "in_a_pickle"])
	_at(1730, ["link", 3])
	_ev(1790, {"e": "knock_on", "a": "in_a_pickle", "b": "tap_dance"})
	_at(1790, ["b_react_end", "in_a_pickle", "kitchen_pickle_jar"])
	_at(1790, ["b_react", "tap_dance", "drench", "a", 120, 38, 0, 0, sink - 50.0, 1])
	_ev(1790, {"e": "prank_fire", "prank": "tap_dance", "trigger": "knock_on", "link": 4, "tier": 3, "witnessed": false})
	_ev(1790, {"e": "reaction_start", "prank": "tap_dance", "archetype": "drench", "variant": "a", "tier": 3,
		"suppressed": false, "len": 120, "entry": 38})
	_ev(1792, {"e": "reaction_accent", "prank": "tap_dance"})
	_at(1792, ["applause", 300, "gag", "tap_dance"])
	_at(1792, ["link", 4])
	_at(1792, ["temper", 100, 3])
	_at(1872, ["b_react_end", "tap_dance", "kitchen_sink_tap"])
	_at(1872, ["residue", "SOAKED", 0])
	_ev(1872, {"e": "combo", "id": "poodle"})
	_ev(1872, {"e": "bonus", "kind": "combo", "amount": 40})
	_at(1874, ["b_state", "MELTDOWN"])
	_ev(1874, {"e": "meltdown_start"})
	_ev(1874, {"e": "bonus", "kind": "meltdown", "amount": 80})
	_at(1874, ["applause", 80, "bonus", "MELTDOWN!"])
	_ev(1934, {"e": "meltdown_stomp", "n": 1})
	_ev(2024, {"e": "meltdown_stomp", "n": 2})
	_ev(2114, {"e": "meltdown_stomp", "n": 3})
	_at(1890, ["h_unfreeze"])
	_at(1900, ["h_move", 3000.0, WALK, ""])
	_at(2204, ["b_state", "EXHAUSTED"])
	_ev(2204, {"e": "exhausted"})
	_at(2204, ["temper", 60, 2])
	# E — On Guard: he spots Hush moving → "!" → chase → catch → Busted Cam → Lecture → doorstep.
	_at(2380, ["b_state", "ROUTINE"])
	_at(2380, ["specs", true])
	_ev(2380, {"e": "on_guard"})
	_at(2385, ["b_move", 2950.0, 4.0, -1])
	_at(2410, ["spot", 1])
	_ev(2410, {"e": "spot_start", "by": "bellows"})
	_at(2470, ["spot", 0])
	_at(2470, ["b_state", "SPOTTED"])
	_ev(2470, {"e": "spotted", "by": "bellows"})
	_at(2488, ["b_state", "CHASE"])
	_ev(2488, {"e": "chase_start"})
	_at(2488, ["b_move", 2960.0, 10.0, -1])
	_at(2490, ["h_move", 2880.0, RUN, "freeze"])
	_ev(2550, {"e": "caught", "cause": "grab", "spotted_tick": 2470, "by": "bellows"})
	_ev(2550, {"e": "busted_cam"})
	_at(2550, ["caught"])
	_ev(2610, {"e": "lecture", "variant": 0})
	_at(2754, ["doorstep"])
	_ev(2754, {"e": "doorstep"})
	_ev(2754, {"e": "tomato", "n": 1})
	_at(2754, ["applause", -50, "catch", "caught"])
	_at(2790, ["b_state", "ROUTINE"])
	_ev(2790, {"e": "running_gag_end"})
	_at(2790, ["link", 0])


func _do(a: Array) -> void:
	var op := String(a[0])
	match op:
		"ev":
			var e: Dictionary = (a[1] as Dictionary).duplicate()
			e["t"] = tick
			_events.append(e)
		"h_move":
			_hx_target = float(a[1])
			_hx_speed = float(a[2])
			_hx_state = "RUN" if _hx_speed > WALK + 0.1 else "WALK"
			_h_after = String(a[3])
			hush.state = _hx_state
			hush.frozen = false
			hush.facing = 1 if _hx_target > float(hush.x_sub) / 60.0 else -1
		"h_rig":
			hush.state = "RIGGING"
			hush.rig_prank = String(a[1])
			_rig_t0 = tick
			_rig_len = int(a[2])
		"h_rigged":
			hush.state = "IDLE"
			hush.rig_prank = ""
			_rig_t0 = -1
			_set_hot(String(a[2]), "rigged", true)
			_events.append({"e": "rigged", "t": tick, "prank": String(a[1])})
		"h_squeak":
			_busy(18, "SQUEAKING", "IDLE")
		"h_pop":
			_set_hot(hush.hidden_spot, "occupant", false)
			hush.hidden_spot = ""
			_busy(12, "POPPING", "IDLE")
		"h_unfreeze":
			hush.frozen = false
			hush.state = "IDLE"
			_events.append({"e": "freeze", "t": tick, "on": false})
		"b_pips":
			bellows.ear_pips = int(a[1])
		"b_move":
			_bx_target = float(a[1])
			_bx_speed = float(a[2])
			bellows.facing = int(a[3])
			_perform = false
			bellows.activity_t = 0
		"b_activity":
			bellows.activity_id = String(a[1])
			bellows.activity_len = int(a[2])
			bellows.activity_t = 0
			_perform = true
			_bx_target = -1.0
			_next = String(a[3])
			_next_detour = false
		"b_next":
			_next = String(a[1])
			_next_detour = bool(a[2])
			_events.append({"e": "b_next", "t": tick, "id": _next, "detour": _next_detour})
		"b_face":
			bellows.facing = int(a[1])
			bellows.look_back_until = tick + 30
		"b_state":
			bellows.state = String(a[1])
			if bellows.state != "ROUTINE":
				_perform = false
		"b_react":
			bellows.state = "REACTING"
			_perform = false
			_bx_target = -1.0
			_react = {"prank": String(a[1]), "archetype": String(a[2]), "variant": String(a[3]), "len": int(a[4]),
				"t": int(a[5]), "from_f": int(a[6]), "to_f": int(a[7]), "to_x": float(a[8]), "dir": int(a[9]), "start": tick}
			_react_x0 = float(bellows.x_sub) / 60.0
			bellows.reacting = {"prank": String(a[1]), "archetype": String(a[2]), "variant": String(a[3]), "tier": _tier_of(),
				"suppressed": false, "t": int(a[5]), "len": int(a[4]), "travel": null}
		"b_react_end":
			_events.append({"e": "reaction_end", "t": tick, "prank": String(a[1])})
			_set_hot(String(a[2]), "rigged", false)
			_set_hot(String(a[2]), "spent", true)
			bellows.state = "ROUTINE"
			bellows.reacting = null
			_react = {}
		"residue":
			if not bellows.residues.has(String(a[1])):
				bellows.residues.append(String(a[1]))
			if int(a[2]) > 0:
				bellows.blinded_until = tick + int(a[2])
			_events.append({"e": "residue_add", "t": tick, "kind": String(a[1])})
		"applause":
			_applause = maxi(0, _applause + int(a[1]))
			_events.append({"e": "applause", "t": tick, "delta": int(a[1]), "total": _applause, "kind": String(a[2]),
				"label": String(a[3])})
		"temper":
			var old := bellows.tier
			bellows.temper_q = int(a[1]) * 60
			bellows.tier = int(a[2])
			if bellows.tier != old:
				_events.append({"e": "temper_tier", "t": tick, "tier": bellows.tier})
		"link":
			_link = int(a[1])
			_fuse = 600 if _link > 0 else 0
			if _link > 0:
				_events.append({"e": "running_gag", "t": tick, "link": _link, "mult": [100, 100, 150, 200, 300][mini(_link, 4)]})
		"specs":
			bellows.specs_on = bool(a[1])
			_events.append({"e": "specs", "t": tick, "on": bellows.specs_on})
		"spot":
			_spot_dir = int(a[1])
			if _spot_dir == 0:
				bellows.spot_meter = 0
		"bit":
			_bit_id = String(a[1])
			_bit_len = int(a[2])
			_bit_t0 = tick
		"caught":
			_caught_t0 = tick
			bellows.state = "CAUGHT_HOLD"
			hush.state = "CAUGHT"
			hush.frozen = false
			_hx_target = -1.0
			_bx_target = -1.0
			bellows.spot_meter = 0
			_spot_dir = 0
		"doorstep":
			hush.state = "IDLE"
			hush.room = "porch"
			hush.x_sub = _sub(350.0)
			hush.facing = 1
			_tomatoes += 1


## The stairs demo (scenario "stairs"): Hush waits in the hall by the stair foot; Bellows walks
## the landing, comes down the stairs (a 120-tick STAIRS leg with progress) and into the hall;
## the entry warning for the hall fires 90 ticks ahead. Loops every 420 ticks.
func _build_stairs_demo() -> void:
	_script.clear()
	hush.room = "hall"
	hush.floor = 0
	hush.x_sub = _sub(1260.0)
	hush.facing = 1
	hush.state = "IDLE"
	bellows.room = "landing"
	bellows.floor = 1
	bellows.x_sub = _sub(1500.0)
	bellows.facing = -1
	bellows.activity_id = ""
	_perform = false
	_at(10, ["b_move", 1060.0, 4.0, -1])
	_ev(30, {"e": "entry_warning", "room": "hall", "eta": 90})


func _update_stairs_demo() -> void:
	var t := tick % 420
	var b := bellows
	_leg_b = {"kind": ""}
	if t >= 120 and t < 240:
		var pm := (t - 120) * 1000 / 120
		_leg_b = {"kind": "stairs", "from_room": "landing", "to_room": "hall", "from_x": 1050, "to_x": 1450,
			"from_floor": 1, "to_floor": 0, "progress_pm": pm}
		b.room = "hall"
		b.floor = 0
		b.x_sub = _sub(1450.0)
		b.state = "ROUTINE"
		b.facing = 1
		_bx_target = -1.0
	elif t == 240:
		_events.append({"e": "b_room", "t": tick, "room": "hall"})
		_bx_target = 1180.0
		_bx_speed = 4.0
		b.facing = -1
	elif t == 0 and tick > 0:
		b.room = "landing"
		b.floor = 1
		b.x_sub = _sub(1500.0)
		_bx_target = 1060.0
		_bx_speed = 4.0
		b.facing = -1
		_events.append({"e": "entry_warning", "t": tick, "room": "hall", "eta": 90})


func _busy(ticks: int, state: String, then: String) -> void:
	_busy_until = tick + ticks
	_busy_state = state
	_busy_then = then
	hush.state = state


func _tier_of() -> int:
	return 1 if bellows.tier < 2 else (2 if bellows.tier == 2 else 3)


func _update_hush() -> void:
	if _busy_until > 0:
		if tick >= _busy_until:
			_busy_until = 0
			hush.state = _busy_then
		return
	if hush.state == "CAUGHT":
		hush.x_sub = bellows.x_sub + bellows.facing * 95 * 60
		hush.facing = -bellows.facing
		return
	if _hx_target >= 0.0:
		var x := float(hush.x_sub) / 60.0
		var dx := _hx_target - x
		if absf(dx) <= _hx_speed:
			hush.x_sub = _sub(_hx_target)
			_hx_target = -1.0
			hush.state = "IDLE"
			_arrive_hush()
		else:
			hush.x_sub = _sub(x + signf(dx) * _hx_speed)
		_room_check(hush, "hush_room")


func _arrive_hush() -> void:
	var after := _h_after
	_h_after = ""
	if after.begins_with("dive:"):
		var spot := after.substr(5)
		_busy(15, "DIVING", "HIDDEN")
		hush.hidden_spot = spot
		_set_hot(spot, "occupant", true)
		_events.append({"e": "hide", "t": tick, "spot": spot, "watched": false})
	elif after == "freeze":
		hush.state = "FROZEN"
		hush.frozen = true
		_events.append({"e": "freeze", "t": tick, "on": true})


func _update_bellows() -> void:
	var b := bellows
	if b.state == "REACTING" and not _react.is_empty():
		var t := int(_react["t"]) + 1
		_react["t"] = t
		(b.reacting as Dictionary)["t"] = t
		var f0 := int(_react["from_f"])
		var f1 := int(_react["to_f"])
		if f1 > f0 and t >= f0:
			var u := clampf(float(t - f0) / float(f1 - f0), 0.0, 1.0)
			b.x_sub = _sub(lerpf(_react_x0, float(_react["to_x"]), ViewKit.ease_out_cubic(u)))
		_room_check(b, "b_room")
		return
	if b.state == "MELTDOWN" or b.state == "EXHAUSTED" or b.state == "CAUGHT_HOLD" or b.state == "SPOTTED":
		return
	if _bx_target >= 0.0:
		var x := float(b.x_sub) / 60.0
		var dx := _bx_target - x
		if absf(dx) <= _bx_speed:
			b.x_sub = _sub(_bx_target)
			_bx_target = -1.0
		else:
			b.x_sub = _sub(x + signf(dx) * _bx_speed)
		_room_check(b, "")
	elif _perform:
		b.activity_t = mini(b.activity_t + 1, b.activity_len)
	if _spot_dir > 0:
		b.spot_meter = mini(b.spot_meter + 1, b.spot_fill)
	elif _spot_dir < 0:
		b.spot_meter = maxi(0, b.spot_meter - 2)
		if b.spot_meter == 0:
			_spot_dir = 0


func _room_check(a: Object, ev_name: String) -> void:
	var x := float(a.get("x_sub")) / 60.0
	var r := layout.room_at(int(a.get("floor")), x)
	if r != "" and r != String(a.get("room")):
		a.set("room", r)
		if ev_name != "":
			_events.append({"e": ev_name, "t": tick, "room": r})


func _glyph() -> String:
	var b := bellows
	if b.state == "REACTING" or b.state == "MELTDOWN":
		return "stars"
	if b.blinded_until > tick or b.state == "EXHAUSTED":
		return "blinded"
	return "specs_on" if b.specs_on else "specs_off"


static func _sub(px: float) -> int:
	return int(round(px * 60.0))
