## AudioDirector — the view's ears (TECH §5.8, GDD §3.7 "audio is the third channel", §6.5,
## §9.5). Listens to `SimDriver.ticked` and every CharacterView's `clip_event` and plays the
## `data/audio/cues.json` actions (owner `audio`; built-in defaults when absent) through the
## `Audio` autoload (soft, `has_method`):
##   events.<event> = action | [action]; pranks.<id>.fire on prank_fire;
##   archetypes.<a>.accent on reaction_accent (skipped when the clip carries sfx), .ooh on
##   reaction_start; squeak_bits.<bit> on squeak_bit.
##   action = {sfx | voice | sting | crowd | music | chain (n | "link"), delay_s, vol_db,
##   pan ("source" | "hush" | "bellows" | "center"), when (hush_exposed | hush_in_room |
##   bellows_on_screen | first_in_night), by {field, map, default}, then [action]}.
## It pans by screen x, attenuates by rooms between Hush and the source (−6 dB per room),
## decides every gag's laugh tier from its applause delta (T1 < 12, T2 12–24, T3 > 24 or
## link 2, T4 link ≥ 3 / Meltdown / signature), starts the laugh at the hold (`hold_delay_s`,
## merged to the highest tier), and drives the music state (suspense while a "?" fills or he
## is ≤ 2 s from an armed prank; chase in CHASE; chain section = link). Crowd tier actions
## ("t0".."t4") in cues go through the same laugh path, so a laugh never plays twice.
## Without clip events (stand-in puppets) it synthesises footsteps: his slipper strut (every
## 28 f, crescendo during an entry warning) and Hush's pizzicato tiptoe walking up a scale.
## Emits `laugh(tier)` and `crowd_special(kind)` for the Stalls (they react with no Audio).
class_name AudioDirector
extends Node

signal laugh(tier: int)
signal crowd_special(kind: String)
signal music_changed(state: String)

const CUES := "res://data/audio/cues.json"
const MERGE_S := 0.2
const DELAYED := 24
const B_STEP_F := 28.0
const H_STEP_F := 10.0
const TIER_KINDS: PackedStringArray = ["t0", "t1", "t2", "t3", "t4"]
const BELLOWS_EVENTS: PackedStringArray = ["b_activity", "b_activity_end", "b_next", "b_detour", "b_room", "entry_warning",
	"doorway_pause", "specs", "glyph", "look_back", "ear_pip", "squeak_bit", "head_turn", "lure", "lure_fatigue",
	"door_slam", "wheeze", "meltdown_stomp", "bump", "prank_fire", "reaction_start", "reaction_accent", "reaction_end",
	"fizzle", "combo", "temper_tier", "meltdown_start", "exhausted", "search", "spotted", "lecture"]
## Built-in cues (same schema) for when cues.json is absent.
const DEFAULT_EVENTS := {
	"rigged": [{"sting": "rigged"}, {"crowd": "t0", "delay_s": 0.35}],
	"rig_step_done": {"sfx": "rig_done"},
	"hide": {"sfx": "dive", "pan": "hush"},
	"pop_out": {"sfx": "pop_out", "pan": "hush"},
	"squeak": {"sfx": "clarence_squeak", "pan": "hush"},
	"squeak_bit": [{"sting": "bit"}, {"crowd": "t1", "delay_s": 0.4}],
	"entry_warning": [{"sfx": "door_jiggle"}, {"crowd": "behind_you", "when": "hush_exposed", "delay_s": 0.3}],
	"spot_start": [{"sting": "spot"}, {"crowd": "gasp", "delay_s": 0.15}],
	"near_miss": [{"sting": "near_miss"}, {"crowd": "relief", "delay_s": 0.2}],
	"spotted": {"sting": "alert"},
	"chase_start": {"music": "chase"},
	"door_slam": [{"sfx": "door_slam_bonk"}, {"crowd": "t1", "delay_s": 0.3}],
	"caught": [{"sting": "caught"}, {"crowd": "aww", "delay_s": 0.25}],
	"tomato": {"sfx": "tomato_splat", "pan": "hush"},
	"fizzle": [{"sting": "fizzle"}, {"crowd": "aww", "delay_s": 0.5}],
	"combo": [{"sting": "combo"}, {"crowd": "t3", "delay_s": 0.2}],
	"running_gag": {"chain": "link"},
	"running_gag_end": {"chain": 0},
	"meltdown_start": [{"sting": "meltdown"}, {"chain": 4}, {"crowd": "chant", "delay_s": 0.8}],
	"meltdown_stomp": {"sfx": "stomp_quake", "pan": "bellows"},
	"specs": {"by": {"field": "on", "map": {"true": {"sfx": "specs_tink", "pan": "bellows"}}}},
	"bump": {"sfx": "woodblock_bonk", "pan": "bellows"},
	"face_to_face": {"crowd": "gasp"},
}

var driver: SimDriver = null
var camera: CameraDirector = null
var layout: HouseLayout = null
var info: ContentInfo = null
var world_view: WorldView = null
var events: Dictionary = {}
var pranks: Dictionary = {}
var archetypes: Dictionary = {}
var squeak_bits: Dictionary = {}
var t1_max: int = 120
var t2_max: int = 240
var t3_link: int = 2
var t4_link: int = 3
var t4_on: PackedStringArray = PackedStringArray(["meltdown_start", "signature"])
var kind_tiers: Dictionary = {"bit": 1, "combo": 3, "panto_bit": 3, "meltdown": 4, "rig": 0}
var hold_delay_s: float = 0.12
var suspense_eta_ticks: int = 120
var chain_max: int = 4
## Test hook: calls are recorded here as [method, args…] when `record` is true.
var record: bool = false
var calls: Array = []
## No Audio calls at all (scenario seeks); signals still fire.
var muted: bool = false

var _audio: Node = null
var _music := ""
var _chain := -1
var _pending_tier := -1
var _pending_t := 0.0
var _pending_age := 0.0
var _spot_prev := 0.0
var _spot_rising := false
var _eta_out := PackedStringArray()
var _clip_steps := false
var _clip_sfx_t := -100.0
var _b_step := 0.0
var _h_step := 0.0
var _h_note := 0
var _entry_boost := 0.0
var _last_tier := -1
var _seen: Dictionary = {}
var _react_arch := ""
var _react_sig := false
## Delayed actions: [remaining_s, action, event] (fixed ring).
var _delayed: Array = []
var _now := 0.0


func _init() -> void:
	name = "AudioDirector"
	process_priority = -44
	for i in DELAYED:
		_delayed.append([-1.0, null, null])


## Wire to a driver (ticked), camera (panning), world view (positions, clip events).
func setup(d: SimDriver, cam: CameraDirector, wv: WorldView) -> void:
	driver = d
	camera = cam
	world_view = wv
	layout = wv.layout if wv != null else HouseLayout.load_default()
	info = wv.info if wv != null else null
	load_cues()
	_audio = ViewKit.autoload("Audio")
	if driver != null and not driver.ticked.is_connected(on_ticked):
		driver.ticked.connect(on_ticked)
	if wv != null:
		for cv in [wv.hush_view, wv.bellows_view]:
			if cv != null and not (cv as CharacterView).clip_event.is_connected(on_clip_event):
				(cv as CharacterView).clip_event.connect(on_clip_event)


## Load cues.json (soft); the built-in defaults when absent.
func load_cues(path: String = CUES) -> void:
	events = DEFAULT_EVENTS.duplicate(true)
	pranks = {}
	archetypes = {}
	squeak_bits = {}
	var v: Variant = ViewKit.json(path)
	if not (v is Dictionary):
		return
	var d: Dictionary = v
	if d.get("events", null) is Dictionary:
		events = d["events"]
	if d.get("pranks", null) is Dictionary:
		pranks = d["pranks"]
	if d.get("archetypes", null) is Dictionary:
		archetypes = d["archetypes"]
	if d.get("squeak_bits", null) is Dictionary:
		squeak_bits = d["squeak_bits"]
	var lt: Variant = d.get("laugh_tiers", {})
	if lt is Dictionary:
		var l: Dictionary = lt
		t1_max = int(l.get("t1_max", t1_max))
		t2_max = int(l.get("t2_max", t2_max))
		t3_link = int(l.get("t3_link", t3_link))
		t4_link = int(l.get("t4_link", t4_link))
		hold_delay_s = float(l.get("hold_delay_s", hold_delay_s))
		if l.get("t4_on", null) is Array:
			t4_on = PackedStringArray(l["t4_on"])
		if l.get("kinds", null) is Dictionary:
			kind_tiers = {}
			for k in l["kinds"]:
				var tv := ViewKit.s(l["kinds"][k])
				kind_tiers[k] = TIER_KINDS.find(tv) if TIER_KINDS.has(tv) else int(tv)
	var mu: Variant = d.get("music", {})
	if mu is Dictionary:
		suspense_eta_ticks = int(round(float((mu as Dictionary).get("suspense_eta_s", 2.0)) * 60.0))
		chain_max = int((mu as Dictionary).get("chain_max", chain_max))


# --- pure rules (tests) ------------------------------------------------------------------

## GDD §6.5 laugh tier of a landed gag: T4 link ≥ 3 / Meltdown / signature; T3 > 24 Applause
## (240 tenths) or link 2; T2 12–24; T1 below 12.
static func laugh_tier(delta_tenths: int, link: int, signature: bool, meltdown: bool,
		t1: int = 120, t2: int = 240, l3: int = 2, l4: int = 3) -> int:
	if meltdown or signature or link >= l4:
		return 4
	if delta_tenths > t2 or link == l3:
		return 3
	if delta_tenths >= t1:
		return 2
	return 1


## Music state: "chase" in CHASE; "suspense" while a "?" fills or ≤ 2 s (`eta_max` ticks)
## from an armed prank; else "sneak".
static func music_for(bellows_state: String, spot_pct: float, spot_rising: bool, armed_eta: int, eta_max: int = 120) -> String:
	if bellows_state == "CHASE":
		return "chase"
	if (spot_pct > 0.0 and spot_rising) or (armed_eta >= 0 and armed_eta <= eta_max):
		return "suspense"
	return "sneak"


## Stereo pan (−1 … 1) for a screen x.
static func pan_for(screen_x: float, width: float) -> float:
	if width <= 0.0:
		return 0.0
	return clampf((screen_x / width) * 2.0 - 1.0, -1.0, 1.0) * 0.85


## Volume drop for sources `rooms` rooms away from Hush (0 → 0 dB, −6 dB per room, −24
## floor; unreachable = −24).
static func attenuation_db(rooms: int) -> float:
	if rooms < 0:
		return -24.0
	return maxf(-24.0, -6.0 * float(rooms))


# --- events -----------------------------------------------------------------------------

func on_ticked(evs: Array) -> void:
	var snap := driver.snapshot() if driver != null else null
	for ev in evs:
		var d: Dictionary = ev
		var e := ViewKit.s(d.get("e", ""))
		match e:
			"applause":
				_on_applause(d, snap)
			"entry_warning":
				if snap != null and ViewKit.s(d.get("room", "")) == snap.hush.room:
					_entry_boost = 6.0
			"prank_fire":
				var pc: Variant = pranks.get(ViewKit.s(d.get("prank", "")), null)
				if pc is Dictionary:
					_run((pc as Dictionary).get("fire", null), d, snap)
			"reaction_start":
				_react_arch = ViewKit.s(d.get("archetype", ""))
				_react_sig = info != null and bool(info.prank(ViewKit.s(d.get("prank", ""))).get("signature", false))
				var ac: Variant = archetypes.get(_react_arch, null)
				if ac is Dictionary and bool((ac as Dictionary).get("ooh", false)):
					_crowd("ooh")
			"reaction_accent":
				var ac2: Variant = archetypes.get(_react_arch, null)
				if ac2 is Dictionary and _clip_sfx_t < _now - 0.25:
					_run((ac2 as Dictionary).get("accent", null), d, snap)
			"squeak_bit":
				_run(squeak_bits.get(ViewKit.s(d.get("bit", "")), null), d, snap)
		if t4_on.has(e):
			_queue_laugh(4)
		var cue: Variant = events.get(e, null)
		if cue != null:
			_run(cue, d, snap)
	if snap != null:
		_spot_rising = snap.bellows.spot_pct > _spot_prev
		_spot_prev = snap.bellows.spot_pct


func _on_applause(d: Dictionary, snap: ViewSnapshot) -> void:
	var kind := ViewKit.s(d.get("kind", ""))
	var delta := int(d.get("delta", 0))
	if delta <= 0:
		return
	if kind_tiers.has(kind):
		_queue_laugh(int(kind_tiers[kind]))
	elif kind == "gag" or kind == "prank":
		var link := snap.link if snap != null else 0
		_queue_laugh(AudioDirector.laugh_tier(delta, link, _react_sig, false, t1_max, t2_max, t3_link, t4_link))
	elif kind == "bonus":
		var label := ViewKit.s(d.get("label", "")).to_lower()
		if label.contains("meltdown"):
			_queue_laugh(4)
		elif label.contains("combo"):
			_queue_laugh(3)


## A laugh starts `hold_delay_s` from now (the start of the hold); laughs within 0.2 s merge.
func _queue_laugh(tier: int) -> void:
	tier = clampi(tier, 0, 4)
	if _pending_tier >= 0 and _pending_age < MERGE_S:
		_pending_tier = maxi(_pending_tier, tier)
		return
	_pending_tier = tier
	_pending_t = hold_delay_s if tier > 0 else 0.0
	_pending_age = 0.0


func _fire_laugh(tier: int) -> void:
	_last_tier = tier
	laugh.emit(tier)
	_call("crowd", ["t%d" % tier])


## The tier of the latest laugh fired (tests).
func last_laugh_tier() -> int:
	return _last_tier


func _crowd(kind: String) -> void:
	if TIER_KINDS.has(kind):
		_queue_laugh(TIER_KINDS.find(kind))
		return
	crowd_special.emit(kind)
	_call("crowd", [kind])


## Run an action or a list of actions for event `ev`.
func _run(a: Variant, ev: Dictionary, snap: ViewSnapshot) -> void:
	if a is Array:
		for x in a:
			_run(x, ev, snap)
		return
	if not (a is Dictionary):
		return
	var act: Dictionary = a
	var by: Variant = act.get("by", null)
	if by is Dictionary:
		var bd: Dictionary = by
		var key := ViewKit.s(ev.get(ViewKit.s(bd.get("field", "")), null), "")
		var m: Variant = bd.get("map", {})
		var sub: Variant = (m as Dictionary).get(key, null) if m is Dictionary else null
		_run(sub if sub != null else bd.get("default", null), ev, snap)
		return
	if act.has("when") and not _when(ViewKit.s(act["when"]), ev, snap):
		return
	var delay := float(act.get("delay_s", 0.0))
	if delay > 0.0:
		_schedule(delay, act, ev)
		return
	_do(act, ev, snap)


func _do(act: Dictionary, ev: Dictionary, snap: ViewSnapshot) -> void:
	var pan_mode := ViewKit.s(act.get("pan", "source"))
	var pan := _pan_of(pan_mode, ev, snap)
	var vol := float(act.get("vol_db", 0.0)) + _atten_of(pan_mode, ev, snap)
	var sfx: Variant = act.get("sfx", null)
	if sfx is String:
		_call("play_sfx", [ViewKit.s(sfx), pan, vol, 1.0])
	elif sfx is Array:
		for x in sfx:
			_call("play_sfx", [ViewKit.s(x), pan, vol, 1.0])
	if act.has("voice"):
		_call("play_voice", [ViewKit.s(act["voice"]), vol, pan])
	if act.has("sting"):
		_call("sting", [ViewKit.s(act["sting"])])
	if act.has("crowd"):
		_crowd(ViewKit.s(act["crowd"]))
	if act.has("music"):
		_set_music(ViewKit.s(act["music"]))
	if act.has("chain"):
		var c: Variant = act["chain"]
		if ViewKit.s(c) == "link":
			_set_chain(clampi(int(ev.get("link", 0)), 1, chain_max))
		else:
			_set_chain(clampi(int(c), 0, chain_max))
	if act.get("then", null) is Array:
		_run(act["then"], ev, snap)


func _when(cond: String, ev: Dictionary, snap: ViewSnapshot) -> bool:
	match cond:
		"hush_exposed":
			return snap != null and snap.hush.state != "HIDDEN"
		"hush_in_room":
			return snap != null and ViewKit.s(ev.get("room", snap.bellows.room)) == snap.hush.room
		"bellows_on_screen":
			if camera == null or snap == null:
				return true
			return camera.visible_world_rect().has_point(Vector2(snap.bellows.x, snap.bellows.y - 150.0))
		"first_in_night":
			var k := ViewKit.s(ev.get("e", "")) + "|" + ViewKit.s(ev.get("prank", ev.get("id", ev.get("bit", ""))))
			if _seen.has(k):
				return false
			_seen[k] = true
			return true
	return true


func _source_pos(pan: String, ev: Dictionary, snap: ViewSnapshot) -> Vector2:
	if snap == null:
		return Vector2.INF
	match pan:
		"hush":
			return Vector2(snap.hush.x, snap.hush.y - 170.0)
		"bellows":
			return Vector2(snap.bellows.x, snap.bellows.y - 200.0)
		"center":
			return Vector2.INF
	if ev.has("x") and ev.has("room") and layout != null:
		return Vector2(float(ev["x"]), layout.room_floor_y(ViewKit.s(ev["room"])) - 150.0)
	if BELLOWS_EVENTS.has(ViewKit.s(ev.get("e", ""))):
		return Vector2(snap.bellows.x, snap.bellows.y - 200.0)
	return Vector2(snap.hush.x, snap.hush.y - 170.0)


func _pan_of(pan: String, ev: Dictionary, snap: ViewSnapshot) -> float:
	var p := _source_pos(pan, ev, snap)
	if camera == null or p == Vector2.INF:
		return 0.0
	return AudioDirector.pan_for(camera.world_to_screen(p).x, camera.view_size().x)


func _atten_of(pan: String, ev: Dictionary, snap: ViewSnapshot) -> float:
	if snap == null or layout == null or pan == "center" or pan == "hush":
		return 0.0
	var room := ViewKit.s(ev.get("room", ""))
	if room == "":
		room = snap.bellows.room if pan == "bellows" or BELLOWS_EVENTS.has(ViewKit.s(ev.get("e", ""))) else snap.hush.room
	return AudioDirector.attenuation_db(layout.room_distance(snap.hush.room, room))


func _schedule(delay: float, act: Dictionary, ev: Dictionary) -> void:
	for slot in _delayed:
		if float(slot[0]) < 0.0:
			slot[0] = delay
			slot[1] = act
			slot[2] = ev
			return


## Clip events: sfx / voice / laugh from RigPlayer clips (panned and attenuated by the actor).
func on_clip_event(ev: Dictionary) -> void:
	var t := ViewKit.s(ev.get("type", ""))
	var pos: Variant = ev.get("pos", Vector2.INF)
	var pan := 0.0
	if camera != null and pos is Vector2 and pos != Vector2.INF:
		pan = AudioDirector.pan_for(camera.world_to_screen(pos).x, camera.view_size().x)
	var vol := 0.0
	var snap := driver.snapshot() if driver != null else null
	if snap != null and layout != null:
		var room := snap.bellows.room if ViewKit.s(ev.get("actor", "")) == "bellows" else snap.hush.room
		vol = AudioDirector.attenuation_db(layout.room_distance(snap.hush.room, room))
	match t:
		"sfx":
			var id := ViewKit.s(ev.get("id", ""))
			if id.contains("step") or id.contains("slipper") or id.contains("pizz"):
				_clip_steps = true
			_clip_sfx_t = _now
			_call("play_sfx", [id, pan, vol + float(ev.get("vol_db", 0.0)), float(ev.get("pitch", 1.0))])
		"voice":
			_call("play_voice", [ViewKit.s(ev.get("id", ev.get("bank", ""))), vol, pan])
		"laugh":
			var tier := ViewKit.s(ev.get("tier", "auto"))
			if tier != "auto":
				_queue_laugh(int(tier))


## Drop delayed actions and a pending laugh (retry / scenario seek).
func clear_pending() -> void:
	for slot in _delayed:
		slot[0] = -1.0
		slot[1] = null
		slot[2] = null
	_pending_tier = -1


# --- per frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	advance(delta)


## Per frame (public for tests): delayed actions, pending laughs, music, fallback footsteps.
func advance(delta: float) -> void:
	_now += delta
	var vdt := driver.view_delta() if driver != null else delta
	var snap := driver.snapshot() if driver != null else null
	for slot in _delayed:
		if float(slot[0]) < 0.0:
			continue
		slot[0] = float(slot[0]) - delta
		if float(slot[0]) <= 0.0:
			slot[0] = -1.0
			var act: Dictionary = slot[1]
			var ev: Dictionary = slot[2]
			slot[1] = null
			slot[2] = null
			_do(act, ev, snap)
	if _pending_tier >= 0:
		_pending_age += delta
		_pending_t -= maxf(vdt, delta * 0.05)
		if _pending_t <= 0.0:
			var t := _pending_tier
			_pending_tier = -1
			_fire_laugh(t)
	if snap == null:
		return
	var eta := info.armed_eta(snap, _eta_out) if info != null else -1
	_set_music(AudioDirector.music_for(snap.bellows.state, snap.bellows.spot_pct, _spot_rising, eta, suspense_eta_ticks))
	_entry_boost = maxf(0.0, _entry_boost - delta * 3.0)
	if not _clip_steps:
		_fallback_steps(snap, vdt)


func _fallback_steps(snap: ViewSnapshot, vdt: float) -> void:
	var b := snap.bellows
	if b.present and b.moving:
		_b_step += vdt * 60.0 * (2.0 if b.running else 1.0)
		if _b_step >= B_STEP_F:
			_b_step = 0.0
			var pan := 0.0
			if camera != null:
				pan = AudioDirector.pan_for(camera.world_to_screen(Vector2(b.x, b.y)).x, camera.view_size().x)
			var vol := AudioDirector.attenuation_db(layout.room_distance(snap.hush.room, b.room)) + _entry_boost
			_call("play_sfx", ["bellows_step", pan, vol, 1.0])
	var h := snap.hush
	if h.present and h.moving and not h.frozen:
		_h_step += vdt * 60.0
		if _h_step >= H_STEP_F:
			_h_step = 0.0
			_h_note = (_h_note % 8) + 1
			_call("play_sfx", ["step_pizz_%d" % _h_note, 0.0, -4.0 if not h.running else 0.0, 1.0])


func _set_music(state: String) -> void:
	if state == _music:
		return
	_music = state
	music_changed.emit(state)
	_call("music_state", [state])


func _set_chain(n: int) -> void:
	if n == _chain:
		return
	_chain = n
	_call("chain_section", [n])


func music() -> String:
	return _music


func _call(method: String, args: Array) -> void:
	if record:
		var row := [method]
		row.append_array(args)
		calls.append(row)
	if not muted and _audio != null and _audio.has_method(method):
		_audio.callv(method, args)
