## HudPresenter — fills the HUD's `HudModel` every frame from the `ViewSnapshot`, the sim's
## `action_context()` and a few view facts (`HudEnv`: PiP state, where Bellows is on screen, …),
## plus the recent events (TECH §5.9, GDD §3.2–§3.9). Pure (no Nodes) and allocation-free per frame:
## strings, the Script lines and the loop strip are rebuilt only when something they show changes.
##
##   presenter.setup(layout, world)            # once (the house, the episode)
##   presenter.on_events(events)               # every sim tick (SimDriver.ticked)
##   presenter.fill(model, snap, ctx, env)     # every frame; ctx = world.action_context() or {}
## Without `action_context()` (the sim piece lands in parallel) the verb falls back to the snapshot:
## hidden → POP OUT (GO ▶ with a pin), RIGGING → RIG, standing at an available rig point → RIG
## (RIG dimmed when the needed item is missing), else FREEZE; the rim from room distance.
class_name HudPresenter
extends RefCounted

## PrankState RIGGED (sim `Pranks.RIGGED`, TECH §3.7.4 order).
const PRANK_RIGGED := 3
const MULTS: PackedInt32Array = [100, 100, 150, 200, 300]
## Hush counts as "at" a rig point within this many px of its use point (fallback verb).
const AT_RIG_PX := 40.0
## Lure fatigue: two lures inside this many ticks grey the lure ring (GDD §3.3, §5.6).
const LURE_WINDOW_TICKS := 3600

## The world view's HouseLayout (rooms, hotspots) — rig points per room for the fallback verb.
var layout: HouseLayout = null
## The SimWorld (or any object with line_states / prank_state / hush_can_see / episode) — read
## only when the Script panel data is refreshed.
var world: Object = null
## Set by `on_events` when the Script panel data needs a refresh (line / rig / room events).
var script_dirty: bool = true
## Reusable output of the last refresh.
var script_lines: Array = []
var script_loop: Array = []
var lines_done: int = 0
var lines_total: int = 0

## Frame facts NightScene supplies (see the class doc).
class HudEnv:
	extends RefCounted
	var pip_shown: bool = false
	var pip_escalated: bool = false
	## Bellows' feet on screen (logical px) and whether his body is inside the view.
	var bellows_screen: Vector2 = Vector2.ZERO
	var bellows_on_screen: bool = true
	var view_size: Vector2 = Vector2(1920, 1080)
	var paused: bool = false
	var figgis_pulse: bool = false
	## Screen point above the rummaged container (pick strip anchor).
	var pick_screen_pos: Vector2 = Vector2.ZERO
	var tick: int = 0

var _rig_points: Dictionary = {}          # room -> Array[HouseLayout.Hotspot]
var _fuse_peak: int = 1
var _pin_set: bool = false
var _pick_container: String = ""
var _pick_items := PackedStringArray()
var _lure_ticks := PackedInt32Array([-100000, -100000])
var _last_tick: int = 0
var _emote: String = ""
var _emote_until: int = -1
var _has_emote_field: int = -1
# Edge-bubble label cache (rebuilt only when its inputs change).
var _e_key: int = -99999
var _e_label: String = ""
var _e_dir := Vector2.ZERO
var _loop_current: int = -1
var _fb_need: String = ""
var _cur_activity: String = ""


## Bind the house (fallback verb, edge bubble distances) and the world (Script panel).
func setup(p_layout: HouseLayout, p_world: Object) -> void:
	layout = p_layout
	world = p_world
	_rig_points.clear()
	if layout != null:
		for hs in layout.hotspots:
			if hs.kind == "rig_point":
				if not _rig_points.has(hs.room):
					_rig_points[hs.room] = []
				(_rig_points[hs.room] as Array).append(hs)
	reset()


## Retry in place: forget transient state.
func reset() -> void:
	_fuse_peak = 1
	_pin_set = false
	_pick_container = ""
	_pick_items = PackedStringArray()
	_lure_ticks[0] = -100000
	_lure_ticks[1] = -100000
	_emote = ""
	_emote_until = -1
	_e_key = -99999
	script_dirty = true
	_loop_current = -1


## The container of the open pick strip ("" = closed).
func pick_container() -> String:
	return _pick_container


## Per-tick events.
func on_events(events: Array) -> void:
	for ev in events:
		var d: Dictionary = ev
		var e := String(d.get("e", ""))
		match e:
			"pick_window":
				_pick_container = String(d.get("container", ""))
				_pick_items = _items_of(d.get("items", []))
			"pick", "hush_go":
				_pick_container = ""
				_pick_items = PackedStringArray()
			"pin":
				_pin_set = true
			"pop_out", "hide", "caught":
				_pin_set = false
			"lure":
				_lure_ticks[0] = _lure_ticks[1]
				_lure_ticks[1] = int(d.get("t", 0))
			"lure_fatigue":
				_lure_ticks[0] = int(d.get("t", 0))
				_lure_ticks[1] = int(d.get("t", 0))
			"micro_gag":
				if String(d.get("vis", "")) == "edge" and String(d.get("emote", "")) != "":
					_emote = String(d.get("emote", ""))
					_emote_until = int(d.get("t", 0)) + maxi(1, int(d.get("len", 60)))
			"line_done", "big_number_unsealed", "rigged", "reaction_end", "hush_room", "prank_fire", "rig_start":
				script_dirty = true
			"b_activity":
				script_dirty = true
		_last_tick = maxi(_last_tick, int(d.get("t", _last_tick)))


static func _items_of(v: Variant) -> PackedStringArray:
	if v is String:
		return PackedStringArray((v as String).split(",", false))
	if v is Array or v is PackedStringArray:
		return PackedStringArray(v)
	return PackedStringArray()


## Fill `m` for this frame. `ctx` = `world.action_context()` ({} when the sim lacks it).
func fill(m: HudModel, snap: ViewSnapshot, ctx: Dictionary, env: HudEnv) -> void:
	var h := snap.hush
	var b := snap.bellows
	if b.activity != _cur_activity:
		_cur_activity = b.activity
		script_dirty = true
	if script_dirty and world != null:
		refresh_script()
	m.applause = snap.applause_tenths / 10
	m.lines_done = lines_done
	m.lines_total = lines_total
	m.tomatoes_max = snap.tomatoes_max
	m.tomatoes_left = snap.tomatoes_max - snap.tomatoes if snap.tomatoes_max >= 0 else -1
	# Running Gag
	m.link = snap.link
	m.mult_pct = MULTS[clampi(snap.link, 0, MULTS.size() - 1)]
	if snap.link <= 0:
		_fuse_peak = 1
		m.fuse_frac = 0.0
	else:
		_fuse_peak = maxi(_fuse_peak, snap.fuse_ticks)
		m.fuse_frac = clampf(float(snap.fuse_ticks) / float(maxi(1, _fuse_peak)), 0.0, 1.0)
	m.temper_tier = clampi(b.tier, 0, 3)
	# Action button
	if ctx.has("verb"):
		_fill_verb_ctx(m, snap, ctx)
	else:
		_fill_verb_fallback(m, snap)
	# Clarence / ⏩ (⏩ only while hidden; she can never squeak from a hiding spot)
	m.clarence_mode = HudModel.ClarenceMode.FF if h.state == "HIDDEN" else HudModel.ClarenceMode.SQUEAK
	m.lure_grey = env.tick - _lure_ticks[0] < LURE_WINDOW_TICKS and _lure_ticks[0] > -100000
	# Tray
	if m.tray != h.carrying:
		m.tray = h.carrying
	var need := String(ctx.get("item_needed", "")) if ctx.has("verb") else _fb_need
	m.tray_highlight = h.carrying.find(need) if need != "" and (m.verb == HudModel.Verb.RIG) else -1
	# Figgis, pause
	m.figgis_pulse = env.figgis_pulse
	m.paused = env.paused
	# PiP
	m.pip_visible = env.pip_shown
	m.pip_escalated = env.pip_escalated
	m.pip_frame_tier = m.temper_tier
	m.pip_glyph = snap.bubble_glyph
	# Edge bubble: Bellows off screen and the PiP not showing him.
	_fill_edge(m, snap, env)
	if _has_emote_field < 0:
		_has_emote_field = 1 if "edge_bubble_emote" in m else 0
	if _has_emote_field == 1:
		var em := _emote if env.tick < _emote_until and m.edge_bubble_dir != Vector2.ZERO else ""
		if String(m.get("edge_bubble_emote")) != em:
			m.set("edge_bubble_emote", em)
	# Pick strip
	if _pick_container != "" and h.state != "PICK_WINDOW" and h.state != "RUMMAGE":
		_pick_container = ""
		_pick_items = PackedStringArray()
	if m.pick_strip_container != _pick_container:
		m.pick_strip_container = _pick_container
	if m.pick_strip_items != _pick_items:
		m.pick_strip_items = _pick_items
	m.pick_strip_pos = env.pick_screen_pos if _pick_container != "" else Vector2.ZERO
	# Script panel data (arrays swapped only when rebuilt)
	m.script_lines = script_lines
	m.script_loop = script_loop


static func verb_of(name: String) -> int:
	match name:
		"rig":
			return HudModel.Verb.RIG
		"rig_dim":
			return HudModel.Verb.RIG_DIM
		"pop_out":
			return HudModel.Verb.POP_OUT
		"go":
			return HudModel.Verb.GO
	return HudModel.Verb.FREEZE


static func rim_of(name: String) -> int:
	match name:
		"amber":
			return HudModel.Rim.AMBER
		"red":
			return HudModel.Rim.RED
	return HudModel.Rim.GREEN


func _fill_verb_ctx(m: HudModel, _snap: ViewSnapshot, ctx: Dictionary) -> void:
	m.verb = verb_of(String(ctx.get("verb", "freeze")))
	m.rim = rim_of(String(ctx.get("danger", "green")))
	if m.verb == HudModel.Verb.RIG or m.verb == HudModel.Verb.RIG_DIM:
		var item := String(ctx.get("item_needed", ""))
		var icon := String(ctx.get("target_icon", ""))
		if m.verb_item_icon != item:
			m.verb_item_icon = item
		if m.verb_target_icon != icon:
			m.verb_target_icon = icon
		m.ring_frac = clampf(float(ctx.get("ring_pm", 0)) / 1000.0, 0.0, 1.0)
	else:
		m.ring_frac = 0.0


func _fill_verb_fallback(m: HudModel, snap: ViewSnapshot) -> void:
	var h := snap.hush
	_fb_need = ""
	m.rim = _rim_fallback(snap)
	m.ring_frac = 0.0
	if h.state == "HIDDEN":
		m.verb = HudModel.Verb.GO if _pin_set else HudModel.Verb.POP_OUT
		return
	if h.state == "RIGGING":
		m.verb = HudModel.Verb.RIG
		m.ring_frac = clampf(float(h.rig_pm) / 1000.0, 0.0, 1.0)
		return
	var hs := _rig_point_here(snap)
	if hs == null:
		m.verb = HudModel.Verb.FREEZE
		return
	var st: Variant = snap.hotspots.get(hs.id, null)
	var need := String((st as Dictionary).get("needs_item", "")) if st is Dictionary else ""
	_fb_need = need
	var have := need == "" or h.carrying.has(need)
	m.verb = HudModel.Verb.RIG if have else HudModel.Verb.RIG_DIM
	if m.verb_item_icon != need:
		m.verb_item_icon = need
	if m.verb_target_icon != "":
		m.verb_target_icon = ""
	if have and h.rig_prank != "":
		m.ring_frac = clampf(float(h.rig_pm) / 1000.0, 0.0, 1.0)


## The available rig point Hush stands at (fallback verb), or null.
func _rig_point_here(snap: ViewSnapshot) -> HouseLayout.Hotspot:
	var h := snap.hush
	if h.moving or not (h.state == "IDLE" or h.state == "FROZEN"):
		return null
	var list: Variant = _rig_points.get(h.room, null)
	if list == null:
		return null
	for hs in list:
		var spot: HouseLayout.Hotspot = hs
		if absf(spot.use_x - h.x) > AT_RIG_PX:
			continue
		var st: Variant = snap.hotspots.get(spot.id, null)
		if st is Dictionary and bool((st as Dictionary).get("enabled", false)) and not bool((st as Dictionary).get("spent", false)) \
				and not bool((st as Dictionary).get("rigged", false)):
			return spot
	return null


func _rim_fallback(snap: ViewSnapshot) -> int:
	var b := snap.bellows
	var h := snap.hush
	if not b.present or layout == null:
		return HudModel.Rim.GREEN
	var d := layout.room_distance(h.room, b.room)
	if d == 0:
		return HudModel.Rim.RED
	if d == 1 or snap.path_rooms.has(h.room):
		return HudModel.Rim.AMBER
	return HudModel.Rim.GREEN


func _fill_edge(m: HudModel, snap: ViewSnapshot, env: HudEnv) -> void:
	var b := snap.bellows
	var h := snap.hush
	if not b.present or not h.present or env.bellows_on_screen or env.pip_shown:
		if m.edge_bubble_dir != Vector2.ZERO:
			m.edge_bubble_dir = Vector2.ZERO
		if m.edge_bubble_label != "":
			m.edge_bubble_label = ""
		_e_key = -99999
		return
	var floor_d := b.floor - h.floor
	var right := env.bellows_screen.x >= env.view_size.x * 0.5
	var rooms := layout.room_distance(h.room, b.room) if layout != null else 1
	var key := floor_d * 1000 + (rooms if rooms >= 0 else 99) * 2 + (1 if right else 0)
	if key != _e_key:
		_e_key = key
		if floor_d > 0:
			_e_label = UiStrings.t("hud.edge_upstairs")
			_e_dir = Vector2(0, -1)
		elif floor_d < 0:
			_e_label = UiStrings.t("hud.edge_downstairs")
			_e_dir = Vector2(0, 1)
		else:
			_e_dir = Vector2(1, 0) if right else Vector2(-1, 0)
			if rooms <= 0:
				_e_label = ""
			elif rooms == 1:
				_e_label = UiStrings.t("hud.edge_room_right" if right else "hud.edge_room_left")
			else:
				_e_label = UiStrings.t("hud.edge_rooms_right" if right else "hud.edge_rooms_left", {"n": rooms})
	if floor_d == 0:
		# Point along the true screen direction (vertical component keeps the bubble honest).
		var c := env.view_size * 0.5
		var v := env.bellows_screen - c
		_e_dir = v.normalized() if v.length_squared() > 1.0 else _e_dir
	if m.edge_bubble_dir != _e_dir:
		m.edge_bubble_dir = _e_dir
	if m.edge_bubble_label != _e_label:
		m.edge_bubble_label = _e_label


## Rebuild the Script panel rows and the loop strip from the world (allocates; on change only).
func refresh_script() -> void:
	script_dirty = false
	if world == null:
		return
	var ep: Variant = world.get("episode")
	var states: Array = world.call("line_states") if world.has_method("line_states") else []
	var lines: Array = []
	var done_n := 0
	for st in states:
		var s: Dictionary = st
		var id := String(s.get("id", ""))
		var ld: Variant = ep.call("line", id) if ep is Object and (ep as Object).has_method("line") else null
		var text := String((ld as Object).get("text")) if ld is Object else id
		var prank := String((ld as Object).get("prank")) if ld is Object else ""
		var hint: Dictionary = (ld as Object).get("hint") if ld is Object and (ld as Object).get("hint") is Dictionary else {}
		var rp := String(hint.get("rig_point", "")) if hint.get("rig_point") != null else ""
		var done := bool(s.get("done", false))
		if done:
			done_n += 1
		var rigged := prank != "" and world.has_method("prank_state") and int(world.call("prank_state", prank)) == PRANK_RIGGED
		var discovered := done or rp == "" or (world.has_method("hush_can_see") and bool(world.call("hush_can_see", rp)))
		lines.append({"id": id, "text": text, "req": bool(s.get("req", false)), "done": done, "rigged": rigged,
			"discovered": discovered, "big_number": bool(s.get("big_number", false)), "sealed": bool(s.get("sealed", false)),
			"candle": bool(s.get("candle", false)), "icon": ""})
	script_lines = lines
	lines_done = done_n
	lines_total = states.size()
	var loop: Array = []
	var cur := _cur_activity
	var rigged_acts := {}
	if ep is Object:
		var db: Variant = world.get("db")
		for ld in (ep as Object).get("script_lines"):
			var pr := String((ld as Object).get("prank"))
			if pr == "" or int(world.call("prank_state", pr)) != PRANK_RIGGED:
				continue
			var pd: Variant = null
			if db is Object and (db as Object).get("pranks") is Dictionary:
				pd = ((db as Object).get("pranks") as Dictionary).get(pr, null)
			if pd is Object:
				rigged_acts[String((pd as Object).get("trig_activity"))] = true
		var entries: Variant = (ep as Object).get("loop")
		if entries is Array:
			for le in entries:
				var a := String((le as Object).get("activity"))
				loop.append({"activity": a, "icon": ViewSnapshot.icon_for(a), "rigged": rigged_acts.has(a),
					"current": a == cur})
	script_loop = loop
