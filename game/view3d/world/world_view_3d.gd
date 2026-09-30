## WorldView3D — the 3D stage of a Night, driven by ViewSnapshot + events (never the sim directly); the drop-in for
## the 2D WorldView (brief r3d-view3d §4.2, R3D index §7.8/§7.9).
##
## `setup(db_or_null, episode_or_null, snapshot_source)` (the 2D signature): `snapshot_source` is a SimDriver (or
## anything with `snapshot() / prev_snapshot() / alpha() / view_delta()` + `ticked`) or a bare world. It builds
## tonight's set (`SetList.for_episode` → `House3D.build`, or the private GreyboxSet3D until r3d-sets lands), the two
## CharacterView3D, the floor decals (Decals3D), the 3D FX (Fx3D), the 2D FX anchored to 3D points (Overlays3D), the
## stage lighting, the CueStager / CaughtStager and the MomentRecorder.
##
## Per frame: interpolated characters, gaze, room lights (Hush's room 1.0, his 0.9, others 0.78 + 40 % desaturation,
## backstage 0.3 but 0.9 while he is in it; his stage light ≥ 0.9), the readability drivers (N1 verb glow in her
## room, the active spot at 2×, armed / tag / spent, rig progress at the prop, the hidden eyes, the safe
## desaturation), the stare strip and footprints; per tick the events (flavours, rings, entry warning, the Busted Cam,
## tap feedback, tags, the spotlight pool).
##
## NightScene / HUD API (the 2D names kept): `reset()`, `character(id)`, `prop(id)`, `fallback_counts()`,
## `reveal_badges(on)`, `sparkle(hotspot, s)` (the N4 spotlight pool), `hotspot_rects_in_view()`, `warm_clips()`,
## `preroll(dt)`, `tap_feedback(screen_or_world)`, `target_point(target)`, `entry_warning_active()`,
## `start_busted_replay(t)`, signals `built`, `cue_staged(id, kind)`, `replay_changed(on)`; plus the anchor source
## (`project`, `anchor_of`, `actor_anchor`, `actor_screen_rect`, `prop_screen_rect`, `protected_rects`, `safe_rect`,
## `on_screen`), `bellows_on_screen()`, `visibility_sample()`, `warm_materials(cam)`, signals `edge_badge_wanted(on)`
## and `tag_flight(hotspot)`.
class_name WorldView3D
extends Node3D

signal built
signal replay_changed(on: bool)
signal cue_staged(id: String, kind: String)
## Under the `lean` Bellows-window mode (R15): the HUD's edge badge should stand in for the window.
signal edge_badge_wanted(on: bool)
## A prank landed: its red beret tag flies from this hotspot to the Script pip (the HUD draws the flight).
signal tag_flight(hotspot: String)

const HOUSE3D := "res://data/house/house3d.json"
const HOUSE3D_SCRIPT := "res://view3d/set/house_3d.gd"
const SET_LIST_SCRIPT := "res://view3d/set/set_list.gd"
const ENTRY_LEAD_TICKS := 90
## The Busted Cam window around `spotted` (ticks) and its replay length (frames), as the 2D BustedCam.
const BUSTED_BEFORE := 45
const BUSTED_AFTER := 15
const BUSTED_REPLAY_F := 60
const PROTECT_PAD := 48.0
const ACTIVE_NEAR_PX := 110.0
const SQUEAK_RADIUS_M := 2.1
const NOISE_EVERY_S := 0.5
const SPARKLE_POOL_S := 0.35

var layout: HouseLayout = null
var info: ContentInfo = null
var house3d: Dictionary = {}
## The camera (set by the host before setup): projection, the anchors, hotspot rects.
var cam: CameraDirector3D = null
var source: Object = null
var world: Object = null
var set3d: Object = null
var set_result: Variant = null
var rooms_lit: PackedStringArray = PackedStringArray()
var rooms_backstage: PackedStringArray = PackedStringArray()
## The live mask {hotspot id: kind} (SetList.Result.live / SimCtx.live_hotspots; empty = every hotspot).
var live: Dictionary = {}
var lighting: StageLighting3D = null
var hush_view: CharacterView3D = null
var bellows_view: CharacterView3D = null
var decals: Decals3D = null
var fx3d: Fx3D = null
var overlays: Overlays3D = null
## The Prologue's director cues staged in the set (vase, doorframe, relief, picture).
var cues: CueStager3D = null
## N1/N2's caught sequence (Lecture attach, doorstep).
var caught: CaughtStager3D = null
## The Gag Reel / Busted Cam ring (what was drawn, per frame).
var recorder: MomentRecorder3D = null
## Skip the rig system (tests / `--stand-ins`).
var force_stand_ins: bool = false
## The Bellows window (PipView3D) — for visibility_sample() and the protected rects.
var pip: Node = null
## Settings `bellows_window` ("sim" | "lean", index R15).
var window_mode: String = "sim"
## The HUD's always-on rects (logical px) for the protected set (NightScene hands them over).
var hud_rects: Array[Rect2] = []
## The safe rect (logical px); the whole screen by default.
var safe: Rect2 = Rect2()

var _own_snap: ViewSnapshot = null
var _own_prev: ViewSnapshot = null
var _frame := 0
var _hotspot_ids := PackedStringArray()
var _rigged: Dictionary = {}          # rig point → prank
var _armed_shown: Dictionary = {}     # hotspot → true (tag shown)
var _spent: Dictionary = {}           # hotspot → true
var _trigger_of: Dictionary = {}      # prank → trigger activity
var _all_lines := false
var _entry_room := ""
var _entry_t := 0.0
var _sparkle: Dictionary = {}
var _gaze_t := 0.0
var _gaze_at := Vector3.INF
var _replay_t := -1.0
var _replay_moment := -1
## actor → {piece id: true} lent to its rig; actor → the base clip last frame (a switch returns what it does not keep)
var _lent := {"hush": {}, "bellows": {}}
var _last_clip := {"hush": "", "bellows": ""}
var _busted_on := false
var _noise_t := 0.0
var _tap_age := 99.0
var _queued_target := ""
var _hidden_desat := 0.0
var _edge_badge := false
var _rects_out: Array = []
var _protected: Array[Rect2] = []
var _vis := {"tick": 0, "sim": "", "reason": &"", "on_screen": false, "window": false, "badge": false}

## NightScene drop-in shims — the 2D WorldView members NightScene / NightInput / NightWarm read today, so the 3D
## view runs in the current NightScene unchanged until `r3d-night` ports it: `warm_hint` (NightWarm's list; its
## clip ids are warmed), `unlocked` (tonight's built rooms), `lit_x_range()` (sim px), `fx` (ripple / path_dots /
## clear / avoid_screen_fn over the 3D decals and overlays).
var warm_hint: Dictionary = {}
## Per-phase µs totals while `profile` (hush apply incl. lights, bellows apply, caught + recorder, props + cues,
## decals + particles, overlays) — ViewSandbox3D's perf line divides by `prof_frames`.
var profile: bool = false
var prof_us := PackedInt64Array([0, 0, 0, 0, 0, 0])
var prof_frames: int = 0
var unlocked: PackedStringArray = PackedStringArray()
var fx: FxShim = null
var _empty_snap := ViewSnapshot.new()


func _init() -> void:
	name = "World3D"
	process_priority = -50


## Build the set. See the class doc for `snapshot_source`.
func setup(db_or_null: Variant, episode_or_null: Variant, snapshot_source: Object) -> void:
	source = snapshot_source
	world = snapshot_source.get("world") if snapshot_source != null and snapshot_source.has_method("snapshot") else snapshot_source
	if world == null:
		world = snapshot_source
	var db: Variant = db_or_null if db_or_null != null else (world.get("db") if world != null else null)
	var ep: Variant = episode_or_null if episode_or_null != null else (world.get("episode") if world != null else null)
	layout = HouseLayout.from_any(db) if db != null else (world.call("house_layout") if world != null and world.has_method("house_layout") else HouseLayout.load_default())
	info = ContentInfo.of(world)
	var hj: Variant = ViewKit.json(HOUSE3D)
	house3d = hj if hj is Dictionary else {}
	window_mode = str(ViewKit.setting("bellows_window", window_mode))
	_resolve_set(db, ep)
	_build()
	if source != null and source.has_signal("ticked"):
		source.connect("ticked", on_ticked)
	var juice: Variant = source.get("juice") if source != null and "juice" in source else null
	if juice is Object and (juice as Object).has_signal("freeze_frame_changed") and overlays != null:
		(juice as Object).connect("freeze_frame_changed", func(on: bool) -> void: overlays.freeze_frame(on))
	if source != null and not source.has_method("snapshot"):
		_own_snap = ViewSnapshot.from_sim(world)
		_own_prev = ViewSnapshot.from_sim(world)
	built.emit()


## Tonight's rooms and live mask: SetList (r3d-sets) when it can run, else the episode's rooms / backstage.
func _resolve_set(db: Variant, ep: Variant) -> void:
	rooms_lit = PackedStringArray()
	rooms_backstage = PackedStringArray()
	live = {}
	set_result = null
	if db is ContentDB and ep is EpisodeDef and ResourceLoader.exists(SET_LIST_SCRIPT):
		var sl: Variant = load(SET_LIST_SCRIPT)
		if sl is Script and (sl as Script).can_instantiate():
			var r: Variant = (sl as Script).call("for_episode", db, ep, house3d)
			if r is Object:
				set_result = r
				rooms_lit = WorldView3D._ids((r as Object).get("rooms_lit"))
				rooms_backstage = WorldView3D._ids((r as Object).get("rooms_backstage"))
				var lv: Variant = (r as Object).get("live")
				if lv is Dictionary:
					live = lv
	if rooms_lit.is_empty():
		rooms_lit = WorldView3D._ids(_ep_get(ep, "rooms"))
		rooms_backstage = WorldView3D._ids(_ep_get(ep, "backstage"))
	if rooms_lit.is_empty():
		for r in layout.rooms:
			if r.floor == 0 and not r.outdoor:
				rooms_lit.append(r.id)
	if live.is_empty() and db is ContentDB and ep is EpisodeDef:
		live = SimCtx.live_hotspots(db as ContentDB, ep as EpisodeDef)
	unlocked = PackedStringArray(rooms_lit + rooms_backstage)


static func _ids(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if v is PackedStringArray:
		return v
	if v is Array:
		for x in v:
			out.append(str(x) if not (x is Object) else str((x as Object).get("id")))
	return out


func _ep_get(ep: Variant, key: String) -> Variant:
	if ep is Dictionary:
		return (ep as Dictionary).get(key, null)
	if ep is Object and key in (ep as Object):
		return (ep as Object).get(key)
	return null


func _build() -> void:
	for c in get_children():
		c.queue_free()
	lighting = StageLighting3D.new()
	add_child(lighting)
	lighting.setup_rooms(rooms_lit, rooms_backstage)
	lighting.set_dimming(bool(ViewKit.setting("room_dimming", true)))
	lighting.set_outline_scale(1.5 if bool(ViewKit.setting("outline_boost", false)) else 1.0)
	lighting.room_light_changed.connect(_on_room_light)
	set3d = _make_set()
	if cam != null:
		cam.setup(layout, PackedStringArray(rooms_lit + rooms_backstage))
	_hotspot_ids.clear()
	for hs in layout.hotspots:
		if rooms_lit.has(hs.room):
			_hotspot_ids.append(hs.id)
	decals = Decals3D.new()
	add_child(decals)
	fx3d = Fx3D.new()
	add_child(fx3d)
	overlays = Overlays3D.new()
	add_child(overlays)
	overlays.setup(self)
	fx = FxShim.new(self)
	cues = CueStager3D.new()
	cues.setup(self)
	caught = CaughtStager3D.new()
	caught.setup(self)
	var variant := str(ViewKit.setting("hush_head", ""))
	hush_view = _make_char("hush", variant)
	bellows_view = _make_char("bellows", "")
	recorder = MomentRecorder3D.new()
	recorder.setup(self)
	_index_triggers()
	_prop_rows.clear()
	lighting.snap_now()


func _make_set() -> Object:
	if ResourceLoader.exists(HOUSE3D_SCRIPT) and set_result != null:
		var s: Variant = load(HOUSE3D_SCRIPT)
		if s is Script and (s as Script).can_instantiate():
			var h: Variant = (s as Script).new()
			if h is Node3D and (h as Node3D).has_method("build"):
				add_child(h)
				(h as Node3D).call("build", set_result, house3d)
				return h
			if h is Node:
				(h as Node).free()
	var g := GreyboxSet3D.new()
	add_child(g)
	g.build_from(layout, rooms_lit, rooms_backstage, live, house3d)
	return g


func _make_char(actor: String, variant: String) -> CharacterView3D:
	var cv := CharacterView3D.new()
	cv.info = info
	cv.layout = layout
	cv.house3d = house3d
	cv.set3d = set3d
	add_child(cv)
	cv.setup(actor, variant, force_stand_ins)
	cv.clip_event.connect(_on_clip_event)
	return cv


func _index_triggers() -> void:
	_trigger_of.clear()
	if info == null:
		return
	for pk in info.prank_ids():
		_trigger_of[pk] = str(info.prank(pk).get("activity", ""))


## Retry in place: clear transient FX, decals, staging and the ring (the driver resets the sim).
func reset() -> void:
	_replay_t = -1.0
	_entry_room = ""
	_sparkle.clear()
	_rigged.clear()
	_armed_shown.clear()
	_spent.clear()
	_all_lines = false
	_hidden_desat = 0.0
	if decals != null:
		decals.clear()
	if fx3d != null:
		fx3d.clear()
	if overlays != null:
		overlays.clear()
	if cues != null:
		cues.reset()
	if caught != null:
		caught.reset()
	if recorder != null:
		recorder.clear()
	_replay_moment = -1
	for a in _lent:
		(_lent[a] as Dictionary).clear()
	if set3d != null and set3d.has_method("return_all"):
		set3d.call("return_all")
	for row in _prop_rows:
		row[5] = -1.0
	for id in _hotspot_ids:
		var p := prop(id)
		if p != null:
			if p.has_method("show_tag"):
				p.call("show_tag", false, false)
			if p.has_method("set_state"):
				p.call("set_state", &"idle")
	for cv in [hush_view, bellows_view]:
		if cv != null:
			(cv as CharacterView3D).reset()
			(cv as CharacterView3D).replay = false
	if lighting != null:
		lighting.snap_now()


func character(id: String) -> CharacterView3D:
	match id:
		"hush":
			return hush_view
		"bellows":
			return bellows_view
	return null


## The set piece of a hotspot (House3D's Prop3D / the greybox prop), or null.
func prop(id: String) -> Object:
	if set3d != null and set3d.has_method("prop"):
		var p: Variant = set3d.call("prop", id)
		return p if p is Object else null
	return null


func in_replay_now() -> bool:
	return _replay_t >= 0.0


func is_replaying() -> bool:
	return _replay_t >= 0.0


## Every fallback the view took: {clip_fallbacks, puppets, greybox_props, by_clip}.
func fallback_counts() -> Dictionary:
	var by: Dictionary = {}
	var clips := 0
	var pups := 0
	for cv in [hush_view, bellows_view]:
		if cv == null:
			continue
		var c: CharacterView3D = cv
		clips += c.clip_fallbacks
		pups += c.puppets
		for k in c.fallback_by_clip:
			by[k] = int(by.get(k, 0)) + int(c.fallback_by_clip[k])
	var grey := 0
	if set3d is GreyboxSet3D:
		grey = (set3d as GreyboxSet3D).greybox_count()
	elif set3d != null and set3d.has_method("greybox_count"):
		grey = int(set3d.call("greybox_count"))
	return {"clip_fallbacks": clips, "puppets": pups, "greybox_props": grey, "by_clip": by}


## Long-press reveal: every live preview shows (the HUD's overlays read `previews_forced()`).
var _reveal := false


func reveal_badges(on: bool) -> void:
	_reveal = on


func previews_forced() -> bool:
	return _reveal


## N4 / the Prologue's `sparkle_lever`: the spotlight pool on the floor in front of a hotspot for `seconds`.
func sparkle(hotspot_id: String, seconds: float) -> void:
	if seconds <= 0.0:
		_sparkle.erase(hotspot_id)
		if decals != null:
			decals.pool_off(hotspot_id)
	elif layout.hotspot(hotspot_id) != null:
		_sparkle[hotspot_id] = seconds
		if decals != null:
			decals.pool_on(hotspot_id, _pool_point(hotspot_id))


## The spotlight pool's floor point: in front of the prop's hit box, on the lane.
func _pool_point(hotspot_id: String) -> Vector3:
	var b := hotspot_box(hotspot_id)
	var hs := layout.hotspot(hotspot_id)
	var fy := layout.room_floor_y(hs.room) if hs != null else 0.0
	var x := b.get_center().x if b.size != Vector3.ZERO else (hs.use_x / 200.0 if hs != null else 0.0)
	return Vector3(x, -fy / 200.0 + View3DConst.DECAL_Y, View3DConst.LANE_Z - 0.35)


## The hit box of a hotspot (House3D.hotspot_box; the house.json rect at z −1.75 ± 0.3 otherwise).
func hotspot_box(id: String) -> AABB:
	if set3d != null and set3d.has_method("hotspot_box"):
		var b: Variant = set3d.call("hotspot_box", id)
		if b is AABB and (b as AABB).size != Vector3.ZERO:
			return b
	var hs := layout.hotspot(id)
	if hs == null:
		return AABB()
	var fy := -layout.room_floor_y(hs.room) / 200.0
	var z := -1.75
	var h3: Variant = (house3d.get("hotspots", {}) as Dictionary).get(id, null) if house3d.get("hotspots", null) is Dictionary else null
	if h3 is Dictionary:
		z = float((h3 as Dictionary).get("z", z))
	return AABB(Vector3(hs.rect.position.x / 200.0, fy - hs.rect.end.y / 200.0, z - 0.3),
		Vector3(hs.rect.size.x / 200.0, hs.rect.size.y / 200.0, 0.6))


## Hotspots on screen for TapAssist: [{id, kind, rect (logical px, the projected hit box), world_rect (sim px),
## room, priority (2 hotspot, 1 door/stairs/exit), enabled, stack}] + one floor band per built room ({id:
## "floor:<room>", kind "floor", priority 0}). Disabled hotspots are listed only inside a `stacks` entry.
func hotspot_rects_in_view() -> Array:
	_rects_out.clear()
	var snap := _snap()
	var vs := cam.view_size() if cam != null else Vector2(2400, 1080)
	var screen := Rect2(Vector2.ZERO, vs)
	for id in _hotspot_ids:
		var hs := layout.hotspot(id)
		if hs == null or not hs.tappable:
			continue
		if not live.is_empty() and not live.has(id) and not (hs.kind in ["door", "stairs", "exit"]):
			continue
		var st: Variant = snap.hotspots.get(id, null) if snap != null else null
		var enabled := not (st is Dictionary) or bool((st as Dictionary).get("enabled", true))
		var stack := layout.stack_of(id)
		if not enabled and stack == "":
			continue
		var r := cam.project_aabb(hotspot_box(id)) if cam != null else Rect2()
		if not r.intersects(screen):
			continue
		var pr := 1 if hs.kind in ["door", "stairs", "exit"] else 2
		_rects_out.append({"id": id, "kind": hs.kind, "rect": r, "world_rect": hs.rect, "room": hs.room, "priority": pr,
			"enabled": enabled, "stack": stack})
	for room in rooms_lit:
		var rr := layout.room(room)
		if rr == null or cam == null:
			continue
		var fy := -layout.room_floor_y(room) / 200.0
		var band := AABB(Vector3(rr.x0 / 200.0, fy, View3DConst.STARE_STRIP_Z[0]), Vector3((rr.x1 - rr.x0) / 200.0, 0.02,
			View3DConst.STARE_STRIP_Z[1] - View3DConst.STARE_STRIP_Z[0]))
		var fr := cam.project_aabb(band)
		if fr.intersects(screen):
			_rects_out.append({"id": "floor:" + room, "kind": "floor", "rect": fr.intersection(screen), "room": room,
				"priority": 0, "enabled": true, "stack": ""})
	return _rects_out


## World x range (sim px) covered by tonight's built rooms (the 2D CameraDirector.stage_x_range).
func lit_x_range() -> Vector2:
	var lo := INF
	var hi := -INF
	for r in layout.rooms:
		if unlocked.has(r.id):
			lo = minf(lo, r.x0)
			hi = maxf(hi, r.x1)
	return Vector2(lo, hi) if lo < hi else Vector2(-INF, INF)


## Load every clip the characters can play now into ClipLib3D's cache (soft) — no parsing during PLAY.
func warm_clips(extra: PackedStringArray = PackedStringArray()) -> int:
	var ids := {}
	for cv in [hush_view, bellows_view]:
		if cv == null:
			continue
		for k in (cv as CharacterView3D).map:
			for c in ClipMap.clips_of((cv as CharacterView3D).map[k]):
				if not c.contains("{id}"):
					ids[c] = true
	for row in SliceClips.build3d(PackedStringArray(["g0_sneeze", "p00_curtain_up"])):
		ids[str(row.get("clip", ""))] = true
	for e in extra:
		ids[e] = true
	var hinted: Variant = warm_hint.get("clips", null)
	if hinted is Array or hinted is PackedStringArray:
		for e2 in hinted:
			ids[str(e2)] = true
	var n := 0
	var lib: Variant = load("res://view3d/char/clip_lib_3d.gd") if ResourceLoader.exists("res://view3d/char/clip_lib_3d.gd") else null
	for id in ids:
		var cid := str(id)
		if not ClipMap.clip_exists3d(cid):
			continue
		if lib is Script and (lib as Script).has_method("get_clip"):
			if (lib as Script).call("get_clip", cid) != null:
				n += 1
		else:
			n += 1
	return n


## Pre-roll: advance the characters' clips by `real_dt` from the tick-0 snapshot (sounds muted).
func preroll(real_dt: float) -> void:
	if hush_view == null:
		return
	var snap := _snap()
	if snap != null and _frame == 0:
		hush_view.mute_sounds = true
		bellows_view.mute_sounds = true
		hush_view.apply(snap.hush, snap.hush, 1.0, 0.0)
		bellows_view.apply(snap.bellows, snap.bellows, 1.0, 0.0)
		hush_view.mute_sounds = false
		bellows_view.mute_sounds = false
	hush_view.preroll(real_dt)
	bellows_view.preroll(real_dt)


## The current snapshot (the driver's, or this view's own when driven by a bare world).
func snapshot() -> ViewSnapshot:
	return _snap()


func _snap() -> ViewSnapshot:
	if source != null and source.has_method("snapshot"):
		return source.call("snapshot")
	return _own_snap


func _prev() -> ViewSnapshot:
	if source != null and source.has_method("prev_snapshot"):
		return source.call("prev_snapshot")
	return _own_prev


func _process(delta: float) -> void:
	advance(delta)


## One frame (public for tests and fixed-step shots).
func advance(delta: float) -> void:
	if layout == null or hush_view == null:
		return
	if _own_snap != null and world != null:
		var t := _own_prev
		_own_prev = _own_snap
		_own_snap = t
		_own_snap.fill(world, _own_prev)
	var snap := _snap()
	var prev := _prev()
	if snap == null:
		return
	var alpha := float(source.call("alpha")) if source != null and source.has_method("alpha") else 1.0
	var vdt := float(source.call("view_delta")) if source != null and source.has_method("view_delta") else delta
	_frame += 1
	_tap_age += delta
	var t0 := Time.get_ticks_usec() if profile else 0
	_update_lights(snap, delta)
	if _replay_t < 0.0:
		_update_gaze(snap, vdt)
		hush_view.apply(prev.hush, snap.hush, alpha, vdt)
		var t1 := Time.get_ticks_usec() if profile else 0
		bellows_view.apply(prev.bellows, snap.bellows, alpha, vdt)
		if profile:
			prof_us[0] += t1 - t0
			prof_us[1] += Time.get_ticks_usec() - t1
		_return_on_switch("hush", hush_view)
		_return_on_switch("bellows", bellows_view)
	var t2 := Time.get_ticks_usec() if profile else 0
	if caught != null:
		caught.advance(snap, vdt, _replay_t >= 0.0)
	# the Gag Reel ring records what was drawn this frame (after the characters applied)
	if _replay_t < 0.0 and recorder != null:
		recorder.record(snap)
	else:
		_advance_replay(vdt)
	var t3 := Time.get_ticks_usec() if profile else 0
	_update_props(snap, vdt)
	if cues != null:
		cues.advance(snap, vdt)
	var t4 := Time.get_ticks_usec() if profile else 0
	_update_decals(snap, vdt)
	if fx3d != null:
		fx3d.advance(vdt)
	var t5 := Time.get_ticks_usec() if profile else 0
	if overlays != null:
		overlays.set_safe(snap.hush.state == "HIDDEN" and not in_replay_now())
		overlays.advance(snap, delta)
	if profile:
		var t6 := Time.get_ticks_usec()
		prof_us[2] += t3 - t2
		prof_us[3] += t4 - t3
		prof_us[4] += t5 - t4
		prof_us[5] += t6 - t5
		prof_frames += 1
	_update_sparkles(delta)
	if _entry_room != "":
		_entry_t -= delta
		if _entry_t <= 0.0:
			_entry_room = ""
	_update_visibility(snap)


# --- lights --------------------------------------------------------------------------------------------

func _update_lights(snap: ViewSnapshot, delta: float) -> void:
	var b_room := snap.bellows.room if snap.bellows.present else ""
	lighting.set_rooms_of(snap.hush.room, b_room)
	lighting.advance(delta)
	hush_view.stage_level = lighting.hush_level()
	bellows_view.stage_level = lighting.bellows_level()
	# "safe": the world desaturates 20 % while Hush hides
	var want := View3DConst.HIDDEN_DESAT if snap.hush.state == "HIDDEN" else 0.0
	_hidden_desat = move_toward(_hidden_desat, want, delta / 0.4 * View3DConst.HIDDEN_DESAT)


func _on_room_light(room: String, level: float, desat_: float) -> void:
	if set3d != null and set3d.has_method("set_room_light"):
		set3d.call("set_room_light", room, level, clampf(desat_ + _hidden_desat, 0.0, 1.0))


## The eased stage light of a room (tests).
func room_level(room: String) -> float:
	return lighting.level(room) if lighting != null else 1.0


# --- gaze ----------------------------------------------------------------------------------------------

func _update_gaze(snap: ViewSnapshot, vdt: float) -> void:
	var h := snap.hush
	var b := snap.bellows
	hush_view.look_target = Vector3.INF
	hush_view.look_weight = 0.0
	if hush_view.ctx.flavour == "snicker" or hush_view.ctx.flavour == "glance":
		hush_view.look_target = hush_view.head_world() + Vector3(0.0, -0.8, 4.0)
		hush_view.look_weight = 0.9
	elif b.present and b.room == h.room and h.state != "HIDDEN":
		hush_view.look_target = bellows_view.head_world()
		hush_view.look_weight = 0.8
	bellows_view.look_target = Vector3.INF
	bellows_view.look_weight = 0.0
	if bellows_view.current_clip().contains("slow_burn"):
		bellows_view.look_target = bellows_view.head_world() + Vector3(0.0, -0.8, 4.0)
		bellows_view.look_weight = 1.0
	elif _gaze_t > 0.0 and not b.reacting:
		_gaze_t -= vdt
		bellows_view.look_target = _gaze_at
		bellows_view.look_weight = 0.85


# --- readability drivers (REDESIGN §3.7, §4.1–§4.5) --------------------------------------------------------

## Per-hotspot drivers resolved once per build: [id, prop, HouseLayout.Hotspot, verb, has set_glow, last amp].
var _prop_rows: Array = []
const _EMPTY := {}


func _index_props() -> void:
	_prop_rows.clear()
	for id in _hotspot_ids:
		var p := prop(id)
		if p == null:
			continue
		var hs := layout.hotspot(id)
		if hs == null:
			continue
		_prop_rows.append([id, p, hs, GreyboxSet3D.verb_of(hs.kind), p.has_method("set_glow"), -1.0])


func _update_props(snap: ViewSnapshot, _vdt: float) -> void:
	var room := snap.hush.room
	var hidden := snap.hush.state == "HIDDEN" or snap.hush.hidden_spot != ""
	var next_act := snap.bubble_next
	if _prop_rows.is_empty() and not _hotspot_ids.is_empty():
		_index_props()
	for row in _prop_rows:
		var id: String = row[0]
		var p: Object = row[1]
		var hs: HouseLayout.Hotspot = row[2]
		var kind: StringName = row[3]
		var st_v: Variant = snap.hotspots.get(id, null)
		var st: Dictionary = st_v if st_v is Dictionary else _EMPTY
		var rigged := bool(st.get("rigged", false)) or _rigged.has(id)
		var spent := bool(st.get("spent", false)) or _spent.has(id)
		var amp := WorldView3D.glow_amp_for(kind, hs.room == room, bool(st.get("enabled", true)), rigged, spent, hidden,
			_all_lines, _is_active_spot(snap, id, hs, rigged, next_act))
		if bool(row[4]) and amp != float(row[5]):
			row[5] = amp
			p.call("set_glow", View3DConst.verb_color(kind), amp)
		# AFTER: armed look + tag; spent: glow off, tag hidden
		var want_state := &"spent" if spent else (&"armed" if rigged else &"idle")
		if p.has_method("set_state"):
			if p.get_meta("mnd_state", &"") != want_state:
				p.set_meta("mnd_state", want_state)
				p.call("set_state", want_state)
		var tag_on := rigged and not spent
		if tag_on != _armed_shown.has(id):
			if tag_on:
				_armed_shown[id] = true
			else:
				_armed_shown.erase(id)
			if p.has_method("show_tag"):
				p.call("show_tag", tag_on, true)
		# DURING: rig progress at the prop
		if snap.hush.state == "RIGGING" and p.has_method("set_rig_progress"):
			var rp := str(info.prank(snap.hush.rig_prank).get("rig_point", "")) if info != null and snap.hush.rig_prank != "" else ""
			if rp == id:
				p.call("set_rig_progress", float(snap.hush.rig_pm) / 1000.0)
		# hidden eyes
		if hs.kind == "hiding" and p.has_method("set_occupied"):
			var occ := snap.hush.hidden_spot == id and not is_replaying()
			if p.get_meta("mnd_occ", false) != occ:
				p.set_meta("mnd_occ", occ)
				p.call("set_occupied", occ)
			if occ and p.has_method("eyes_look") and snap.bellows.present:
				var d := signf(snap.bellows.x - hs.use_x) if snap.bellows.room == hs.room else 0.0
				p.call("eyes_look", Vector2(d, 0.0))


## Pure: the glow amplitude of a live prop (N1: everything live in Hush's room glows in its verb colour, nothing
## else; the active spot 2×; armed props show the tag instead unless they are the active spot; spent and hidden:
## off; the exit only after ★).
static func glow_amp_for(kind: StringName, in_room: bool, enabled: bool, rigged: bool, spent: bool, hidden: bool,
		all_lines: bool, active: bool) -> float:
	if not in_room or hidden or spent or not enabled:
		return View3DConst.GLOW_OFF
	if kind == &"exit" and not all_lines:
		return View3DConst.GLOW_OFF
	if kind == &"door" or kind == &"stairs":
		return View3DConst.GLOW_OFF
	if active:
		return View3DConst.GLOW_ACTIVE
	if rigged:
		return View3DConst.GLOW_OFF
	return View3DConst.GLOW_NORMAL


## The active spot: the prop Hush is at (rigging it, or standing at its use point), or an armed prop whose trigger
## is his next activity.
func _is_active_spot(snap: ViewSnapshot, id: String, hs: HouseLayout.Hotspot, rigged: bool, next_act: String) -> bool:
	var h := snap.hush
	if h.state == "RIGGING" and h.rig_prank != "" and info != null and str(info.prank(h.rig_prank).get("rig_point", "")) == id:
		return true
	if h.room == hs.room and not h.moving and absf(h.x - hs.use_x) < ACTIVE_NEAR_PX and h.state != "HIDDEN":
		return true
	if rigged and next_act != "":
		var pk := str(_rigged.get(id, ""))
		if pk != "" and str(_trigger_of.get(pk, "")) == next_act:
			return true
	return false


# --- decals ----------------------------------------------------------------------------------------------

func _update_decals(snap: ViewSnapshot, vdt: float) -> void:
	if decals == null:
		return
	var b := snap.bellows
	var in_replay := _replay_t >= 0.0
	# the stare strip: his sight range on the floor while he is in Hush's room
	if not in_replay and b.present and b.sight_known and b.room == snap.hush.room and not b.reacting:
		var bx := bellows_view.position.x
		var dir := float(b.facing)
		var mv := b.sight_moving / View3DConst.PX_PER_M
		var fr := b.sight_frozen / View3DConst.PX_PER_M
		decals.stare_strip(true, bx, dir, mv, fr, bellows_view.position.y, b.blinded)
	else:
		decals.stare_strip(false, 0.0, 1.0, 0.0, 0.0, 0.0, false)
	# run noise rings every 0.5 s while running
	if snap.hush.running and snap.hush.moving and not in_replay:
		_noise_t -= vdt
		if _noise_t <= 0.0:
			_noise_t = NOISE_EVERY_S
			decals.ring(hush_view.feet_world(), 2.5, View3DConst.NOISE_RING, 0.6)
	elif snap.hush.state == "RIGGING" and snap.hush.rig_prank != "" and not in_replay and _rig_noisy(snap.hush.rig_prank):
		# B-tier rigs are loud: a noise ring at the prop every 0.5 s (rig_actions.json `noise_rings`)
		_noise_t -= vdt
		if _noise_t <= 0.0:
			_noise_t = NOISE_EVERY_S
			var hs_id := str(info.prank(snap.hush.rig_prank).get("rig_point", "")) if info != null else ""
			var b_box := hotspot_box(hs_id) if hs_id != "" else AABB()
			var at := hush_view.feet_world()
			if b_box.size != Vector3.ZERO:
				at = Vector3(b_box.get_center().x, hush_view.feet_world().y, View3DConst.LANE_Z)
			decals.ring(at, 2.5, View3DConst.NOISE_RING, 0.6)
	else:
		_noise_t = 0.0
	decals.advance(vdt)


## rig_actions.json `noise_rings` of a prank (B-tier rigs).
func _rig_noisy(prank: String) -> bool:
	var ra: Dictionary = hush_view.rig_actions if hush_view != null else {}
	var pr: Variant = (ra.get("pranks", {}) as Dictionary).get(prank, null) if ra.get("pranks", null) is Dictionary else null
	return pr is Dictionary and bool((pr as Dictionary).get("noise_rings", false))


func _update_sparkles(delta: float) -> void:
	if _sparkle.is_empty():
		return
	for id in _sparkle.keys():
		var s := float(_sparkle[id]) - delta
		if s <= 0.0:
			_sparkle.erase(id)
			decals.pool_off(id)
		else:
			_sparkle[id] = s


# --- the anchor source (index §7.8) -------------------------------------------------------------------------

## World → logical screen px.
func project(p: Vector3) -> Vector2:
	return cam.project(p) if cam != null else Vector2.ZERO


## A hotspot's anchor (kind &"preview" &"tag" &"ring" &"item" &"eyes" &"reach") in world metres.
func anchor_of(hotspot_id: String, kind: StringName) -> Vector3:
	var p := prop(hotspot_id)
	if p != null and p.has_method("anchor"):
		var a: Variant = p.call("anchor", kind)
		if a is Vector3:
			return a
	var b := hotspot_box(hotspot_id)
	var c := b.get_center()
	match kind:
		&"preview":
			return Vector3(c.x, b.end.y + 0.6, c.z)
		&"item":
			return Vector3(c.x, b.end.y + 0.35, c.z)
		&"tag":
			return Vector3(c.x, b.end.y, b.end.z)
	return c


## An actor anchor (&"head" &"top" &"chest" &"feet") in world metres.
func actor_anchor(actor: StringName, kind: StringName) -> Vector3:
	var cv := character(String(actor))
	if cv == null:
		return Vector3.ZERO
	match kind:
		&"head":
			return cv.head_world()
		&"top":
			return cv.top_world()
		&"chest":
			return cv.chest_world()
	return cv.feet_world()


func actor_screen_rect(actor: StringName) -> Rect2:
	var cv := character(String(actor))
	if cv == null or not cv.visible or cam == null:
		return Rect2()
	return cam.project_aabb(cv.world_aabb())


func prop_screen_rect(hotspot_id: String) -> Rect2:
	return cam.project_aabb(hotspot_box(hotspot_id)) if cam != null else Rect2()


## Hush +48, Bellows +48, his bubble, the prop Hush is at (+ its preview), the Bellows window, the HUD's always-on
## rects +48 (REDESIGN §2.5). One reused array.
func protected_rects() -> Array[Rect2]:
	_protected.clear()
	var hr := actor_screen_rect(&"hush")
	if hr.size != Vector2.ZERO:
		_protected.append(hr.grow(PROTECT_PAD))
	var br := actor_screen_rect(&"bellows")
	if br.size != Vector2.ZERO:
		_protected.append(br.grow(PROTECT_PAD))
	if overlays != null and overlays.bubble_rect().size != Vector2.ZERO:
		_protected.append(overlays.bubble_rect())
	var snap := _snap()
	if snap != null:
		var at := _prop_hush_is_at(snap)
		if at != "":
			var pr := prop_screen_rect(at)
			var pv := project(anchor_of(at, &"preview"))
			_protected.append(pr.expand(pv + Vector2(0.0, -60.0)))
	if pip != null and pip.has_method("screen_rect") and bool(pip.get("shown")):
		_protected.append(pip.call("screen_rect"))
	for r in hud_rects:
		_protected.append(r.grow(PROTECT_PAD))
	return _protected


func _prop_hush_is_at(snap: ViewSnapshot) -> String:
	var h := snap.hush
	if h.state == "RIGGING" and h.rig_prank != "" and info != null:
		return str(info.prank(h.rig_prank).get("rig_point", ""))
	for id in _hotspot_ids:
		var hs := layout.hotspot(id)
		if hs != null and hs.room == h.room and absf(h.x - hs.use_x) < ACTIVE_NEAR_PX and (live.is_empty() or live.has(id)):
			return id
	return ""


func safe_rect() -> Rect2:
	if safe.size != Vector2.ZERO:
		return safe
	return Rect2(Vector2.ZERO, cam.view_size() if cam != null else Vector2(2400, 1080))


func on_screen(p: Vector3) -> bool:
	return safe_rect().has_point(project(p))


# --- C8 visibility (index §7.9) ------------------------------------------------------------------------------

## True when ≥ 35 % of Bellows' projected bounds are inside the viewport.
func bellows_on_screen() -> bool:
	if bellows_view == null or not bellows_view.visible or cam == null:
		return false
	return WorldView3D.share_inside(actor_screen_rect(&"bellows"), Rect2(Vector2.ZERO, cam.view_size())) >= 0.35


## Pure: the share of `r` inside `screen` (0 when `r` is empty).
static func share_inside(r: Rect2, screen: Rect2) -> float:
	var a := r.get_area()
	if a <= 0.0:
		return 0.0
	return r.intersection(screen).get_area() / a


func _update_visibility(snap: ViewSnapshot) -> void:
	var sim := ""
	var reason := &""
	if world is SimWorld:
		sim = SimVisibility.beat_vis(world as SimWorld, false)
		reason = SimVisibility.pip_reason(world as SimWorld)
	elif snap.bellows.present:
		sim = "room" if snap.bellows.room == snap.hush.room else "pip"
		reason = &"room" if sim == "room" else &"adjacent"
	_vis["tick"] = snap.tick
	_vis["sim"] = sim
	_vis["reason"] = reason
	_vis["on_screen"] = bellows_on_screen()
	var badge := window_mode == "lean" and reason == &"adjacent" and not PipView3D.is_busy(snap, bellows_view) \
			and not bool(_vis["on_screen"])
	_vis["badge"] = badge
	if badge != _edge_badge:
		_edge_badge = badge
		edge_badge_wanted.emit(badge)


## PipView3D reports whether the window is up this frame (after its C8 decision) and the on-screen share it used
## (after the camera moved this frame; −1 = keep this view's own sample).
func set_window_shown(on: bool, on_screen: int = -1) -> void:
	_vis["window"] = on
	if on_screen >= 0:
		_vis["on_screen"] = on_screen == 1


## {tick, sim, reason, on_screen, window, badge} of this frame (the C8 test and the visibility lint).
func visibility_sample() -> Dictionary:
	return _vis


## True while the `lean` window mode wants the edge badge instead of the window.
func edge_badge_active() -> bool:
	return _edge_badge


# --- materials ---------------------------------------------------------------------------------------------

## NightWarm: every registered material drawn once in front of `cam_` (free the returned rig after two frames).
func warm_materials(cam_: Camera3D) -> Node3D:
	for cv in [hush_view, bellows_view]:
		if cv != null and (cv as CharacterView3D).uses_rig and (cv as CharacterView3D).rig.has_method("warm"):
			(cv as CharacterView3D).rig.call("warm")
	return MaterialWarm3D.build_warm_rig(self, cam_)


# --- events -----------------------------------------------------------------------------------------------

## Per-tick events (SimDriver.ticked).
func on_ticked(events: Array) -> void:
	var snap := _snap()
	if snap == null:
		return
	for ev in events:
		var d: Dictionary = ev
		hush_view.on_event(d)
		bellows_view.on_event(d)
		if cues != null:
			cues.on_event(d, snap)
		if caught != null:
			caught.on_event(d, snap)
		match str(d.get("e", "")):
			"noise":
				var kind := str(d.get("kind", ""))
				var np := _room_point(str(d.get("room", snap.hush.room)), float(d.get("x", snap.hush.x)))
				var r_m := float(d.get("r", 500)) / View3DConst.PX_PER_M
				decals.ring(np, r_m, View3DConst.SQUEAK_RING if kind == "squeak" else View3DConst.NOISE_RING, 0.8)
				_gaze_at = np + Vector3(0.0, 1.0, 0.0)
				_gaze_t = 1.2
			"squeak":
				decals.ring(_room_point(str(d.get("room", snap.hush.room)), float(d.get("x", snap.hush.x))), SQUEAK_RADIUS_M,
					View3DConst.SQUEAK_RING, 0.9)
			"entry_warning":
				var room := str(d.get("room", ""))
				if room == snap.hush.room or room == "":
					var lead := WorldView3D.entry_lead(int(d.get("eta", ENTRY_LEAD_TICKS)), d)
					_entry_room = snap.hush.room
					_entry_t = float(lead) / 60.0 + 0.3
					if overlays != null:
						overlays.entry_warning(snap, lead)
			"b_room":
				if str(d.get("room", "")) == snap.hush.room and overlays != null:
					overlays.entry_stop()
			"all_lines_done":
				_all_lines = true
			"rigged":
				var pk := str(d.get("prank", ""))
				var rp := str(info.prank(pk).get("rig_point", "")) if info != null else ""
				if rp != "":
					_rigged[rp] = pk
			"prank_fire":
				var pk2 := str(d.get("prank", ""))
				for k in _rigged.keys():
					if _rigged[k] == pk2:
						_rigged.erase(k)
						_spent[k] = true
						tag_flight.emit(String(k))
			"fizzle":
				var pk3 := str(d.get("prank", ""))
				for k in _rigged.keys():
					if _rigged[k] == pk3:
						_rigged.erase(k)
			"trigger_near", "prank_armed_next":
				var tp := prop(str(d.get("hotspot", "")))
				if tp != null and tp.has_method("tag_wiggle"):
					tp.call("tag_wiggle")
			"cmd_queued":
				var qp := target_point(str(d.get("target", "")))
				if qp != Vector3.INF:
					_queued_target = str(d.get("target", ""))
					decals.ghost_ring(qp)
			"cmd_rejected":
				if _tap_age < 0.6:
					decals.pop(decals.last_tap(), true)
			"hush_go":
				var tgt := target_point(str(d.get("target", _queued_target)))
				decals.ghost_off()
				_queued_target = ""
				if tgt != Vector3.INF:
					decals.destination(tgt, hush_view.feet_world())
			"hush_arrive":
				decals.destination_done()
			"spotted":
				if overlays != null:
					overlays.spot_bang()
			"caught":
				start_busted_replay(int(d.get("spotted_tick", -1)))


static func entry_lead(eta: int, ev: Dictionary) -> int:
	var pause := int(ev.get("pause", ev.get("doorway_pause", -1)))
	if pause < 0:
		pause = maxi(0, ENTRY_LEAD_TICKS - eta)
	return eta + pause


func entry_warning_active() -> bool:
	return _entry_room != ""


func _room_point(room: String, x_px: float) -> Vector3:
	return Vector3(x_px / View3DConst.PX_PER_M, -layout.room_floor_y(room) / View3DConst.PX_PER_M, View3DConst.LANE_Z)


## A tap landed (logical screen px, or a Vector3 world point): the tapped-spot pop this frame (≤ 16 ms).
func tap_feedback(at: Variant) -> void:
	_tap_age = 0.0
	var p := Vector3.INF
	if at is Vector3:
		p = at
	elif at is Vector2 and cam != null:
		p = cam.screen_to_plane(at, View3DConst.LANE_Z)
		var snap := _snap()
		if snap != null:
			p.y = -layout.room_floor_y(snap.hush.room) / View3DConst.PX_PER_M
	if p != Vector3.INF and decals != null:
		decals.pop(p, false)


## World point of a command target on the floor: a hotspot id (its use point) or "<room>:<x px>".
func target_point(target: String) -> Vector3:
	if target == "":
		return Vector3.INF
	var hs := layout.hotspot(target)
	if hs != null:
		return _room_point(hs.room, hs.use_x)
	var i := target.find(":")
	if i > 0:
		var room := target.substr(0, i)
		if layout.room(room) != null:
			return _room_point(room, float(target.substr(i + 1)))
	return Vector3.INF


## The Busted Cam (N1/N2, GDD §4.6): re-stage the moment he saw her (BUSTED_BEFORE ticks before `spotted` to
## BUSTED_AFTER after, from the MomentRecorder3D ring) at 1×, a two-shot push-in and the red tint; the characters
## are posed from the recording (`show_moment_frame`) and handed back to the snapshots when it ends.
func start_busted_replay(spotted_tick: int) -> void:
	_busted_on = true
	if overlays != null:
		overlays.busted(true)
	_replay_moment = -1
	if recorder != null and recorder.count() > 0:
		var t := spotted_tick if spotted_tick >= 0 else recorder.last_tick() - BUSTED_BEFORE
		var id := recorder.keep(t - BUSTED_BEFORE, t + BUSTED_AFTER, "busted")
		var m := recorder.moment(id)
		if m != null and m.count() > 0:
			_replay_moment = id
			_replay_t = 0.0
			hush_view.replay = true
			bellows_view.replay = true
			var f := m.frame(0)
			if cam != null:
				var mid := (f.hush.pos + f.bellows.pos) * 0.5 + Vector3(0.0, 1.1, 0.0)
				cam.request_gag(mid, 1.15, 6, BUSTED_REPLAY_F - 12, 8, 100)
	replay_changed.emit(true)


func end_busted_replay() -> void:
	if not _busted_on:
		return
	_busted_on = false
	if overlays != null:
		overlays.busted(false)
	if _replay_t >= 0.0:
		_replay_t = -1.0
		_replay_moment = -1
		hush_view.replay = false
		bellows_view.replay = false
	replay_changed.emit(false)


func _advance_replay(vdt: float) -> void:
	if _replay_t < 0.0:
		return
	var m := recorder.moment(_replay_moment) if recorder != null else null
	if m == null:
		end_busted_replay()
		return
	_replay_t += maxf(vdt, 1.0 / 120.0)
	var i := int(_replay_t * 60.0)
	if i >= mini(m.count(), BUSTED_REPLAY_F):
		end_busted_replay()
		return
	show_moment_frame(m.frame(i))


## Pose both characters and the props from a recorded frame (the Busted Cam; r3d-night's Gag Reel).
func show_moment_frame(f: MomentRecorder3D.Frame) -> void:
	hush_view.mute_sounds = true
	bellows_view.mute_sounds = true
	for pair in [[hush_view, f.hush], [bellows_view, f.bellows]]:
		var cv: CharacterView3D = pair[0]
		var a: MomentRecorder3D.ActorFrame = pair[1]
		cv.show_world(a.pos, a.facing, a.cheat, a.clip, a.frame, a.shown, a.looks, a.tint, a.ov_clip, a.ov_frame)
	hush_view.mute_sounds = false
	bellows_view.mute_sounds = false


# --- clip events -------------------------------------------------------------------------------------------

func _on_clip_event(ev: Dictionary) -> void:
	var t := str(ev.get("type", ""))
	var actor := str(ev.get("actor", ""))
	if cues != null:
		cues.on_clip_event(ev)
	match t:
		"decor":
			var id := str(ev.get("id", ""))
			if ev.has("visible") and set3d != null and set3d.has_method("set_decor_visible"):
				set3d.call("set_decor_visible", id, bool(ev["visible"]))
			if ev.has("anim") and set3d != null and set3d.has_method("play_decor"):
				set3d.call("play_decor", id, str(ev["anim"]))
		"set_anim":
			var p := prop(str(ev.get("hotspot", "")))
			if p != null and p.has_method("play"):
				p.call("play", str(ev.get("anim", "")))
		"set_part":
			var p2 := prop(str(ev.get("hotspot", "")))
			if p2 != null and p2.has_method("set_part"):
				p2.call("set_part", str(ev.get("part", "")), bool(ev.get("visible", true)))
		"prop":
			var pid := str(ev.get("prop", ""))
			if pid.begins_with("set:"):
				_handoff(actor, str(ev.get("op", "")), pid.substr(4), str(ev.get("socket", "grip_r")), int(ev.get("frames", 6)))
		"fx":
			if fx3d != null:
				var cv := character(actor)
				var at := cv.head_world() if cv != null else Vector3.ZERO
				fx3d.burst(str(ev.get("id", "")), at)


## Set-piece hand-offs (index §7.2): lend a hotspot prop / furniture piece into a rig socket and home again. The
## piece keeps its state, armed look and tag while lent (House3D moves the Prop3D itself).
func _handoff(actor: String, op: String, piece: String, socket: String, frames: int) -> void:
	if set3d == null:
		return
	var cv := character(actor)
	var lent: Dictionary = _lent.get(actor, {})
	match op:
		"lend":
			if cv != null and set3d.has_method("lend"):
				set3d.call("lend", piece, cv.socket_node(socket), frames)
				lent[piece] = true
		"return":
			if set3d.has_method("return_home"):
				set3d.call("return_home", piece, frames)
			lent.erase(piece)


## A base-clip switch returns every piece the actor holds that the new clip does not `keeps` (index §7.2).
func _return_on_switch(actor: String, cv: CharacterView3D) -> void:
	var clip := cv.current_clip()
	if clip == str(_last_clip.get(actor, "")):
		return
	_last_clip[actor] = clip
	var lent: Dictionary = _lent.get(actor, {})
	if lent.is_empty() or set3d == null or not set3d.has_method("return_home"):
		return
	var keeps := CharacterView3D.clip_keeps(clip)
	for piece in lent.keys():
		if not keeps.has(String(piece)):
			set3d.call("return_home", String(piece), 6)
			lent.erase(piece)


## Pieces lent to an actor now (tests).
func lent_pieces(actor: String) -> PackedStringArray:
	var out := PackedStringArray()
	for k in (_lent.get(actor, {}) as Dictionary):
		out.append(String(k))
	return out


## The 2D FxLayer calls NightScene / NightInput make (`world_view.fx`), mapped onto the 3D view: a tap ripple → the
## tapped-spot pop, `path_dots` → the destination ring + dotted path, `clear()` → decals, particles and overlays off.
## `avoid_screen_fn` (NightScene's caption avoid rects) is kept for Overlays3D's captions.
class FxShim extends RefCounted:
	var avoid_screen_fn: Callable = Callable()
	var _wv: WeakRef = null

	func _init(w: WorldView3D) -> void:
		_wv = weakref(w)

	func _w() -> WorldView3D:
		return _wv.get_ref() as WorldView3D if _wv != null else null

	## A tap at a sim-world point (px).
	func ripple(world_px: Vector2) -> void:
		var w := _w()
		if w != null:
			w.tap_feedback(View3DConst.px_to_world(world_px))

	## Hush's path (sim px points): the ring at the last one, the dots from the first.
	func path_dots(points: PackedVector2Array) -> void:
		var w := _w()
		if w == null or w.decals == null or points.size() < 2:
			return
		w.decals.destination(View3DConst.px_to_world(points[points.size() - 1]), View3DConst.px_to_world(points[0]))

	func clear() -> void:
		var w := _w()
		if w == null:
			return
		if w.decals != null:
			w.decals.clear()
		if w.fx3d != null:
			w.fx3d.clear()
		if w.overlays != null:
			w.overlays.clear()
