## WorldView — the stage set of a Night (TECH §5.1, §5.4, s2-view brief §4): the theatre, the
## rooms (bg + fg), a PropView per hotspot, the decor (DecorSet), the CharacterViews (real rigs),
## Hush's hidden eyes and the FX layer, all driven from ViewSnapshot + events (never the sim
## directly).
##
## `setup(db_or_null, episode_or_null, snapshot_source)`: `snapshot_source` is a SimDriver
## (or anything with `snapshot() / prev_snapshot() / alpha() / view_delta()` and a `ticked`
## signal); a bare world (SimWorld / FakeWorld) is accepted too and snapshotted per frame.
## The house comes from the ContentDB / house.json (greybox from GDD §7.1 widths when
## absent); rooms outside the episode are an unlit set with velvet ropes at their doorways.
##
## Per frame it interpolates the characters (alpha), their gaze, the Lecture attach, the stare
## strip, bubble, "?", footprints, outlines, badges and the hidden eyes; per tick it forwards the
## sim events to the characters / CueStager / CaughtStager, records the Busted Cam buffer and
## the MomentRecorder ring, and reacts to readability events (noise rings, entry warnings,
## "!", the Busted Cam replay, tap feedback). Comic staging of reactions (Gag-Cam, captions,
## bursts) is GagStager's; the director's `laugh_*` cues are CueStager's (`cue_staged`).
##
## NightScene API: `fallback_counts()`, `reveal_badges(on)`, `sparkle(hotspot, s)`,
## `preroll(real_dt)`, signal `cue_staged(id, kind)`, `hotspot_rects_in_view()` (+ `enabled`,
## `stack`), `recorder` (MomentRecorder), `tap_feedback(...)`.
class_name WorldView
extends Node2D

signal built
## The Busted Cam replay started / ended.
signal replay_changed(on: bool)
## A director cue was staged (`kind`: "prop", "clip", "stalls", "fx", "none") — s2-night's e2e
## asserts a visible change + a crowd sound within 0.3 s of every `laugh_*` cue.
signal cue_staged(id: String, kind: String)

const BADGE_REFRESH_FRAMES := 6
const SQUEAK_RADIUS := 420.0
const SPARKLE_EVERY_S := 0.35
## Entry-warning lead (ticks) = the sim's eta + its doorway pause: always 90 in total.
const ENTRY_LEAD_TICKS := 90
## The Stalls sit below the stage: a look "at the audience" aims this far below the head.
const STALLS_LOOK_DY := 900.0

var layout: HouseLayout = null
var info: ContentInfo = null
var cam: CameraDirector = null:
	set(v):
		cam = v
		if fx != null:
			fx.cam = v
var source: Object = null
var world: Object = null
var unlocked: PackedStringArray = PackedStringArray()
## Skip the rig system (tests / `--puppets`).
var force_puppets: bool = false
## Draw both characters with this rig instead of their own (e.g. "_mannequin" to exercise
## the rig path before a character's clips exist); "" = each actor's own rig.
var rig_override: String = ""

var stage: StageView = null
var rooms_node: Node2D = null
var decor_back_node: Node2D = null
var props_node: Node2D = null
var props_top_node: Node2D = null
var decor_front_node: Node2D = null
var chars_node: Node2D = null
var decor_over_node: Node2D = null
var front_node: Node2D = null
var fg_node: Node2D = null
var fx: FxLayer = null
var hush_view: CharacterView = null
var bellows_view: CharacterView = null
var props: Dictionary = {}
var rooms: Dictionary = {}
var decor: DecorSet = DecorSet.new()
var eyes: HiddenEyes = null
var busted: BustedCam = BustedCam.new()
var recorder: MomentRecorder = MomentRecorder.new()
var cues: CueStager = CueStager.new()
var caught: CaughtStager = CaughtStager.new()

var _own_snap: ViewSnapshot = null
var _own_prev: ViewSnapshot = null
var _frame := 0
var _replay_n := 0
var _replay_t := -1.0
var _path_pts := PackedVector2Array()
var _path_stamp := -1
var _entry_room := ""
var _entry_t := 0.0
var _hotspot_ids := PackedStringArray()
var _empty_snap := ViewSnapshot.new()
var _sparkle: Dictionary = {}
var _gaze_t := 0.0
var _gaze_at := Vector2.INF
var _door_open: Dictionary = {}
var _all_lines := false
var _tap_at := Vector2.INF
var _tap_age := 99.0
var _queued_target := ""
## Rig point → the prank rigged on it (for `rigged_<prank>` art).
var _rigged: Dictionary = {}


func _init() -> void:
	name = "World"
	process_priority = -50


## Build the set. See the class doc for `snapshot_source`.
func setup(db_or_null: Variant, episode_or_null: Variant, snapshot_source: Object) -> void:
	source = snapshot_source
	world = snapshot_source.get("world") if snapshot_source != null and snapshot_source.has_method("snapshot") else snapshot_source
	if world == null:
		world = snapshot_source
	if db_or_null != null:
		layout = HouseLayout.from_any(db_or_null)
	elif world != null and world.get("db") != null:
		layout = HouseLayout.from_any(world.get("db"))
	elif world != null and world.has_method("house_layout"):
		layout = world.call("house_layout")
	else:
		layout = HouseLayout.load_default()
	info = ContentInfo.of(world)
	unlocked = _episode_rooms(episode_or_null if episode_or_null != null else (world.get("episode") if world != null else null))
	_build()
	if source != null and source.has_signal("ticked"):
		source.connect("ticked", on_ticked)
	if source != null and not source.has_method("snapshot"):
		_own_snap = ViewSnapshot.from_sim(world)
		_own_prev = ViewSnapshot.from_sim(world)
	built.emit()


func _episode_rooms(ep: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	var rv: Variant = null
	if ep is Dictionary:
		rv = (ep as Dictionary).get("rooms", null)
	elif ep is Object:
		rv = (ep as Object).get("rooms")
	if rv is Array or rv is PackedStringArray:
		for r in rv:
			out.append(ViewKit.id_of(r, layout.sorted_room_ids()))
	if out.is_empty():
		for r in layout.rooms:
			out.append(r.id)
	return out


func _layer(n: String, z: int) -> Node2D:
	var node := Node2D.new()
	node.name = n
	node.z_index = z
	add_child(node)
	return node


func _build() -> void:
	for c in get_children():
		c.queue_free()
	props.clear()
	rooms.clear()
	stage = StageView.new()
	add_child(stage)
	stage.setup(layout, unlocked)
	rooms_node = _layer("Rooms", -20)
	decor_back_node = _layer("DecorBack", -12)
	props_node = _layer("Props", -10)
	props_top_node = _layer("PropsTop", -9)
	decor_front_node = _layer("DecorFront", -6)
	chars_node = _layer("Characters", 0)
	decor_over_node = _layer("DecorOver", 2)
	front_node = _layer("PropsFront", 3)
	fg_node = _layer("RoomsFg", 8)
	var locked := PackedStringArray()
	for r in layout.rooms:
		var rv := RoomView.new()
		rv.z_index = 0
		rooms_node.add_child(rv)
		rv.setup(r, layout, not unlocked.has(r.id), fg_node)
		rooms[r.id] = rv
		if not unlocked.has(r.id):
			locked.append(r.id)
	stage.add_ropes(fg_node)
	fx = FxLayer.new()
	fx.cam = cam
	fx.layout = layout
	fx.time_source = source if source != null and source.has_method("view_delta") else null
	add_child(fx)
	fx.warm()
	_hotspot_ids.clear()
	for hs in layout.hotspots:
		var pv := PropView.new()
		(props_top_node if hs.z > 0 else props_node).add_child(pv)
		pv.setup(hs, layout, not unlocked.has(hs.room), front_node)
		props[hs.id] = pv
		_hotspot_ids.append(hs.id)
		fx.badges.register(hs.id, pv.badge_anchor(), hs.room)
	decor.back = decor_back_node
	decor.front = decor_front_node
	decor.over = decor_over_node
	decor.build(layout, locked)
	var skin := ViewKit.s(ViewKit.setting("hush_skin", ""))
	eyes = HiddenEyes.new()
	eyes.z_index = 1
	props_top_node.add_child(eyes)
	eyes.setup(skin, 7)
	hush_view = _make_char("hush")
	bellows_view = _make_char("bellows")
	recorder.setup(self)
	cues.setup(self)
	caught.setup(self)


func _make_char(actor: String) -> CharacterView:
	var cv := CharacterView.new()
	cv.info = info
	cv.layout = layout
	cv.fx = fx
	chars_node.add_child(cv)
	cv.setup(actor, rig_override, force_puppets)
	cv.clip_event.connect(_on_clip_event)
	return cv


## Retry in place: clear transient FX, staging, decor, the Busted Cam buffer and the ring (the
## driver resets the sim).
func reset() -> void:
	busted.clear()
	recorder.clear()
	_replay_t = -1.0
	if fx != null:
		fx.clear()
	_entry_room = ""
	_path_stamp = -1
	_sparkle.clear()
	_door_open.clear()
	_rigged.clear()
	_all_lines = false
	decor.reset()
	cues.reset()
	caught.reset()
	for cv in [hush_view, bellows_view]:
		if cv != null:
			(cv as CharacterView).reset()
			(cv as CharacterView).replay = false


## World x range covered by tonight's unlocked rooms (CameraDirector.stage_x_range).
func lit_x_range() -> Vector2:
	var lo := INF
	var hi := -INF
	for r in layout.rooms:
		if unlocked.has(r.id):
			lo = minf(lo, r.x0)
			hi = maxf(hi, r.x1)
	return Vector2(lo, hi) if lo < hi else Vector2(-INF, INF)


func character(id: String) -> CharacterView:
	match id:
		"hush":
			return hush_view
		"bellows":
			return bellows_view
	return null


func prop(id: String) -> PropView:
	return props.get(id, null)


func is_replaying() -> bool:
	return _replay_t >= 0.0


## Every fallback the view took (the pre-gate requires all 0 over whole routes, s2-index §6 row
## 12): `{clip_fallbacks, puppets, greybox_props, by_clip: {"<wanted clip>": n}}`.
func fallback_counts() -> Dictionary:
	var by: Dictionary = {}
	var clips := 0
	var pups := 0
	for cv in [hush_view, bellows_view]:
		if cv == null:
			continue
		var c: CharacterView = cv
		clips += c.clip_fallbacks
		pups += c.puppets
		for k in c.fallback_by_clip:
			by[k] = int(by.get(k, 0)) + int(c.fallback_by_clip[k])
	var grey := 0
	for id in props:
		var pv: PropView = props[id]
		if pv.is_greybox() and not pv.locked:
			grey += 1
	return {"clip_fallbacks": clips, "puppets": pups, "greybox_props": grey, "by_clip": by}


## Long-press reveal (GDD §3.1): every hotspot in view shows its badge for 2 s (`on` false
## ends it early).
func reveal_badges(on: bool) -> void:
	if fx == null:
		return
	if on:
		fx.badges.reveal()
	else:
		fx.badges.stop_reveal()


## FTUE: sparkles on a hotspot for `seconds` (0 stops them).
func sparkle(hotspot_id: String, seconds: float) -> void:
	if seconds <= 0.0:
		_sparkle.erase(hotspot_id)
	elif layout.hotspot(hotspot_id) != null:
		_sparkle[hotspot_id] = [seconds, 0.0]


## Hotspots on screen for tap-assist (TECH §5.4): [{id, kind, rect (screen), world_rect,
## priority (2 hotspot, 1 door / stairs / exit), enabled, stack}] in unlocked rooms. Disabled
## hotspots are listed only when they sit in a house.json `stacks` entry (`stack` = its ids
## joined with "+"), so TapAssist can resolve a tap on one to its enabled partner.
func hotspot_rects_in_view() -> Array:
	var out: Array = []
	var vis := cam.visible_world_rect() if cam != null else Rect2(-1e6, -1e6, 2e6, 2e6)
	var snap := _snap()
	for hs in layout.hotspots:
		if not unlocked.has(hs.room) or not vis.intersects(hs.rect) or not hs.tappable:
			continue
		var st: Variant = snap.hotspots.get(hs.id, null) if snap != null else null
		var enabled := not (st is Dictionary) or bool((st as Dictionary).get("enabled", true))
		var stack := layout.stack_of(hs.id)
		if not enabled and stack == "":
			continue
		var sr := hs.rect
		if cam != null:
			var a := cam.world_to_screen(hs.rect.position)
			var b := cam.world_to_screen(hs.rect.end)
			sr = Rect2(a, b - a)
		var pr := 1 if hs.kind in ["door", "stairs", "exit"] else 2
		out.append({"id": hs.id, "kind": hs.kind, "rect": sr, "world_rect": hs.rect, "priority": pr,
			"enabled": enabled, "stack": stack})
	return out


## Load every clip the characters can play now (their merged maps + the slice manifest,
## SliceClips) into ClipLib's cache, so no clip is parsed during PLAY (NightScene calls it under
## the curtain; OBJECT_COUNT then stays flat). Returns the number of clips loaded.
func warm_clips(extra: PackedStringArray = PackedStringArray()) -> int:
	var ids := {}
	for cv in [hush_view, bellows_view]:
		if cv == null:
			continue
		for k in (cv as CharacterView).map:
			for c in ClipMap.clips_of((cv as CharacterView).map[k]):
				if not c.contains("{id}"):
					ids[c] = true
	for row in SliceClips.build(ViewKit.s(ViewKit.setting("hush_skin", ""))):
		ids[ViewKit.s(row.get("clip", ""))] = true
	for e in extra:
		ids[e] = true
	var n := 0
	for id in ids:
		if ClipMap.clip_exists(ViewKit.s(id)) and ClipLib.get_clip(ViewKit.s(id)) != null:
			n += 1
	return n


## Pre-roll (ruling L13): advance every CharacterView's clip time from the tick-0 snapshot, the
## FX idle loops and the decor animation by `real_dt` — never the sim, never the vase — with
## clip sound events muted. NightScene calls it under the curtain.
func preroll(real_dt: float) -> void:
	if layout == null or hush_view == null:
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
	decor.advance(real_dt)
	if fx != null:
		fx.advance(real_dt)


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


## One frame (public for tests).
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
	if _replay_t >= 0.0:
		_advance_replay(vdt)
	else:
		_update_gaze(snap, vdt)
		hush_view.apply(prev.hush, snap.hush, alpha, vdt)
		bellows_view.apply(prev.bellows, snap.bellows, alpha, vdt)
	caught.advance(snap, vdt, _replay_t >= 0.0)
	# The Gag Reel ring records what was drawn this frame (after the characters applied).
	if _replay_t < 0.0:
		recorder.record(snap)
	_update_eyes(snap, vdt)
	decor.advance(vdt)
	decor.release_clip_overrides(_still_forcing)
	cues.advance(snap, vdt)
	_update_fx(snap, delta)
	_update_props(snap, delta)
	_update_sparkles(delta)


## Gaze (§4.1.5): Hush looks at Bellows while he's in her room (at the Stalls on a snicker);
## Bellows looks at the last noise for 1.2 s, and at the Stalls during slow burns.
func _update_gaze(snap: ViewSnapshot, vdt: float) -> void:
	var h := snap.hush
	var b := snap.bellows
	hush_view.look_target = Vector2.INF
	hush_view.look_weight = 0.0
	if hush_view.ctx.flavour == "snicker" or hush_view.ctx.flavour == "glance":
		hush_view.look_target = hush_view.head_position() + Vector2(0, STALLS_LOOK_DY)
		hush_view.look_weight = 0.9
	elif b.present and b.room == h.room and h.state != "HIDDEN":
		hush_view.look_target = bellows_view.head_position()
		hush_view.look_weight = 0.8
	bellows_view.look_target = Vector2.INF
	bellows_view.look_weight = 0.0
	if bellows_view.current_clip().contains("slow_burn"):
		bellows_view.look_target = bellows_view.head_position() + Vector2(0, STALLS_LOOK_DY)
		bellows_view.look_weight = 1.0
	elif _gaze_t > 0.0 and not b.reacting:
		_gaze_t -= vdt
		bellows_view.look_target = _gaze_at
		bellows_view.look_weight = 0.85


func _update_eyes(snap: ViewSnapshot, vdt: float) -> void:
	var spot := snap.hush.hidden_spot
	var hs := layout.hotspot(spot) if spot != "" else null
	var show := hs != null and snap.hush.state == "HIDDEN" and not is_replaying()
	if show:
		eyes.global_position = hs.eyes if hs.eyes != Vector2.INF else hs.rect.get_center() + Vector2(0, -hs.rect.size.y * 0.12)
		eyes.look_target = bellows_view.head_position() if snap.bellows.present else Vector2.INF
	eyes.visible = show
	eyes.tick(vdt)


## True while `actor`'s clip `clip` still justifies a decor visibility it forced.
func _still_forcing(actor: String, clip: String) -> bool:
	var cv := character(actor)
	if cv == null:
		return false
	var snap := _snap()
	var a := snap.bellows if actor == "bellows" else snap.hush
	return a.reacting or cv.current_clip() == clip


func _update_fx(snap: ViewSnapshot, delta: float) -> void:
	var b := snap.bellows
	var in_replay := _replay_t >= 0.0
	if in_replay:
		fx.stare_strip(_empty_snap, 0.0)
	else:
		fx.stare_strip(snap, bellows_view.position.x)
	var top := bellows_view.top_position()
	fx.spot_meter(b.spot_pct if not in_replay else 0.0, top + Vector2(0, -34.0))
	fx.thought_bubble(snap, top)
	fx.bubble.visible = fx.bubble.visible and not in_replay
	# Footprints when he's in Hush's room or the next one.
	var near := layout.room_distance(snap.hush.room, b.room)
	if not in_replay and b.present and near >= 0 and near <= 1 and b.moving and snap.path_x.size() >= 2:
		if _path_stamp != snap.tick - snap.tick % SimDriver.SLOW_REFRESH_TICKS:
			_path_stamp = snap.tick - snap.tick % SimDriver.SLOW_REFRESH_TICKS
			_path_pts.clear()
			_path_pts.append(Vector2(bellows_view.position.x, b.y))
			for i in snap.path_x.size():
				var rid := snap.path_rooms[i]
				_path_pts.append(Vector2(snap.path_x[i], layout.room_floor_y(rid)))
			fx.footprints(_path_pts)
	elif _path_stamp != -2:
		_path_stamp = -2
		_path_pts.clear()
		fx.footprints(_path_pts)
	if _entry_room != "":
		_entry_t -= delta
		if _entry_t <= 0.0:
			_entry_room = ""


func _update_props(snap: ViewSnapshot, delta: float) -> void:
	var room := snap.hush.room
	fx.badges.set_current_room(room)
	var hints := fx.badges.hints
	var refresh := _frame % BADGE_REFRESH_FRAMES == 0
	var i := 0
	for id in _hotspot_ids:
		var pv: PropView = props[id]
		var in_room := pv.hotspot.room == room and not pv.locked
		pv.set_highlight(in_room and hints != "off" and snap.hush.state != "HIDDEN")
		pv.highlight.tick(delta, float(i) * 0.13)
		i += 1
		pv.set_front(pv.has_front() and room == pv.hotspot.room and snap.hush.state != "HIDDEN"
				and absf(snap.hush.x - pv.hotspot.use_x) < 110.0)
		if not refresh:
			continue
		var hs: Variant = snap.hotspots.get(id, null)
		var st: Dictionary = hs if hs is Dictionary else {}
		var at_container := pv.hotspot.kind == "container" and (snap.hush.state == "RUMMAGE" or snap.hush.state == "PICK_WINDOW") \
				and absf(snap.hush.x - pv.hotspot.use_x) < 120.0
		pv.set_state_from(st, at_container or _door_open.has(id), ViewKit.s(st.get("rigged_prank", _rigged.get(id, ""))))
		fx.badge(id, PropView.badge_kind(pv.hotspot.kind, st, snap.hush.carrying) if not pv.locked and not st.is_empty() else "")
	_update_doors(snap)


## Doors show `open` while someone traverses them (a DOOR leg), the kitchen window during the
## climb-in; the front door flashes once every line is done.
func _update_doors(snap: ViewSnapshot) -> void:
	for a in [snap.hush, snap.bellows]:
		var ac: ViewSnapshot.Actor = a
		if ac.leg_kind != "door":
			continue
		var l := layout.link_between(ac.leg_from_room, ac.leg_to_room)
		if l == null:
			continue
		for hs in layout.hotspots:
			if hs.link == l.id:
				_door_open[hs.id] = 2
	var win := "kitchen_window"
	if snap.hush.oneshot == "enter" and props.has(win):
		_door_open[win] = 2
	if _door_open.is_empty():
		return
	for id in _door_open.keys():
		var n := int(_door_open[id]) - 1
		var pv: PropView = props.get(id, null)
		if n <= 0:
			_door_open.erase(id)
			if pv != null:
				pv.set_state_from(snap.hotspots.get(id, {}) if snap.hotspots.get(id, null) is Dictionary else {}, false, "")
		else:
			_door_open[id] = n
			if pv != null:
				pv.show_open(true)


## A tap landed at `world_pos` (NightScene's InputRouter): the ripple this very frame. The
## sim's answer upgrades it — `cmd_queued` → a pulsing marker with "…" at the target until
## `hush_go`, then the dotted path; `cmd_rejected` → a grey ripple (and Hush's shrug).
func tap_feedback(world_pos: Vector2) -> void:
	_tap_at = world_pos
	_tap_age = 0.0
	if fx != null:
		fx.ripple(world_pos)


## World point of a command target: a hotspot id (its use point on the floor line) or
## "<room>:<x px>" (Vector2.INF when unknown).
func target_point(target: String) -> Vector2:
	if target == "":
		return Vector2.INF
	var hs := layout.hotspot(target)
	if hs != null:
		return Vector2(hs.use_x, layout.room_floor_y(hs.room))
	var i := target.find(":")
	if i > 0:
		var room := target.substr(0, i)
		if layout.room(room) != null:
			return Vector2(float(target.substr(i + 1)), layout.room_floor_y(room))
	return Vector2.INF


func _update_sparkles(delta: float) -> void:
	_tap_age += delta
	if _sparkle.is_empty():
		return
	for id in _sparkle.keys():
		var s: Array = _sparkle[id]
		s[0] = float(s[0]) - delta
		s[1] = float(s[1]) - delta
		if float(s[1]) <= 0.0:
			s[1] = SPARKLE_EVERY_S
			var pv: PropView = props.get(id, null)
			if pv != null:
				fx.burst("sparkles", pv.badge_anchor() + Vector2(0, 30), 5)
		if float(s[0]) <= 0.0:
			_sparkle.erase(id)


# --- events ---------------------------------------------------------------------------------

## Per-tick events (SimDriver.ticked): characters' flavours, staging, recorders, readability FX.
func on_ticked(events: Array) -> void:
	var snap := _snap()
	if snap == null:
		return
	if _replay_t < 0.0:
		busted.record(snap.tick, snap.hush, hush_view.current_clip(), hush_view.current_frame(),
			snap.bellows, bellows_view.current_clip(), bellows_view.current_frame())
	var squeak_ring := false
	for ev in events:
		var d: Dictionary = ev
		hush_view.on_event(d)
		bellows_view.on_event(d)
		cues.on_event(d, snap)
		caught.on_event(d, snap)
		match ViewKit.s(d.get("e", "")):
			"noise":
				var kind := ViewKit.s(d.get("kind", ""))
				var col := FxNoiseRings.SQUEAK if kind == "squeak" else FxNoiseRings.WHITE
				squeak_ring = squeak_ring or kind == "squeak"
				var np := _room_point(ViewKit.s(d.get("room", snap.hush.room)), float(d.get("x", snap.hush.x)), -60.0)
				fx.noise_ring(np, float(d.get("r", 500)), col)
				_gaze_at = np + Vector2(0, -100)
				_gaze_t = 1.2
			"squeak":
				if not squeak_ring:
					fx.noise_ring(_room_point(ViewKit.s(d.get("room", snap.hush.room)), float(d.get("x", snap.hush.x)), -150.0),
						SQUEAK_RADIUS, FxNoiseRings.SQUEAK)
			"entry_warning":
				var room := ViewKit.s(d.get("room", ""))
				if room == snap.hush.room or room == "":
					var lead := WorldView.entry_lead(int(d.get("eta", ENTRY_LEAD_TICKS)), d)
					_entry_room = snap.hush.room
					_entry_t = float(lead) / 60.0 + 0.3
					fx.entry.own_legs = bellows_view.uses_rig
					fx.entry_warning(snap.hush.room, _entry_from(snap), lead)
			"b_room":
				if ViewKit.s(d.get("room", "")) == snap.hush.room:
					fx.entry.stop()
			"spotted":
				busted.on_spotted(int(d.get("t", snap.tick)))
				fx.spot_bang()
			"caught":
				start_busted_replay(int(d.get("spotted_tick", -1)))
			"b_next", "b_detour":
				fx.bubble.bump()
			"combo":
				pass
			"all_lines_done":
				_all_lines = true
				decor.set_visible("hall_front_door_glow", true)
			"rigged":
				var rp := ViewKit.s(info.prank(ViewKit.s(d.get("prank", ""))).get("rig_point", "")) if info != null else ""
				if rp != "":
					_rigged[rp] = ViewKit.s(d.get("prank", ""))
			"prank_fire", "fizzle":
				var pk := ViewKit.s(d.get("prank", ""))
				for k in _rigged.keys():
					if _rigged[k] == pk:
						_rigged.erase(k)
			"figgis_hook":
				_figgis_cane(snap)
			"cmd_queued":
				var qp := target_point(ViewKit.s(d.get("target", "")))
				if qp != Vector2.INF:
					_queued_target = ViewKit.s(d.get("target", ""))
					fx.queued_marker(qp + Vector2(0, -6))
			"cmd_rejected":
				if _tap_at != Vector2.INF and _tap_age < 0.6:
					fx.ripple(_tap_at, true)
			"hush_go":
				var tp := target_point(ViewKit.s(d.get("target", _queued_target)))
				if fx.is_queued():
					fx.queued_done()
				_queued_target = ""
				if tp != Vector2.INF:
					var from := hush_view.global_position
					fx.path_dots(PackedVector2Array([from + Vector2(0, -6), Vector2(tp.x, from.y if absf(tp.y - from.y) < 1.0 else tp.y) + Vector2(0, -6)]))



## The entry-warning lead in ticks: the event's `eta` plus the doorway pause the sim inserts
## (`pause` / `doorway_pause` ticks in the payload) — the sim keeps the total at 90 (GDD §4.2).
static func entry_lead(eta: int, ev: Dictionary) -> int:
	var pause := int(ev.get("pause", ev.get("doorway_pause", -1)))
	if pause < 0:
		pause = maxi(0, ENTRY_LEAD_TICKS - eta)
	return eta + pause


## The room Bellows comes from for an entry warning (the last room on his path before hers).
func _entry_from(snap: ViewSnapshot) -> String:
	var from := snap.bellows.room
	for r in snap.path_rooms:
		if r != snap.hush.room:
			from = r
		else:
			break
	return from


## True while an entry warning for Hush's room is live (PiP rule "heading to her room").
func entry_warning_active() -> bool:
	return _entry_room != ""


func _room_point(room: String, x: float, up: float) -> Vector2:
	return Vector2(x, layout.room_floor_y(room) + up)


## A Meltdown stomp knocks quake prop `qp` (house.json `quake_props[room][i]`) off its hook: its
## decor sprite hides while FxLayer's falling copy drops (GagStager), so the prop never doubles.
func quake_decor(qp: Dictionary) -> void:
	var did := ViewKit.s(qp.get("decor", ""))
	if did != "" and decor.is_visible(did):
		decor.drop(did)


## Figgis's hook (GDD §6.4): a vaudeville cane sweeps in from the wing toward Hush.
func _figgis_cane(snap: ViewSnapshot) -> void:
	var from_right := snap.hush.facing < 0
	var hp := hush_view.global_position + Vector2(0, -150)
	fx.cane(hp, from_right)


# --- clip events ----------------------------------------------------------------------------

func _on_clip_event(ev: Dictionary) -> void:
	var t := ViewKit.s(ev.get("type", ""))
	var actor := ViewKit.s(ev.get("actor", ""))
	match t:
		"decor":
			var id := ViewKit.s(ev.get("id", ""))
			var cv := character(actor)
			if ev.has("visible"):
				decor.set_visible(id, bool(ev["visible"]), actor, cv.current_clip() if cv != null else "")
			if ev.has("state"):
				decor.set_state(id, ViewKit.s(ev["state"]))
		"spring":
			var sid := ViewKit.s(ev.get("id", ev.get("decor", "")))
			if sid != "":
				decor.wobble(sid)
		"prop":
			if ViewKit.s(ev.get("op", "")) == "fall":
				_t3_prop(ev)
	cues.on_clip_event(ev)


## A T3 falling prop (PlayPlan's `prop fall` event at the remapped `t3_prop_f`).
func _t3_prop(ev: Dictionary) -> void:
	var b := bellows_view
	var name_ := ViewKit.s(ev.get("prop", ""))
	if name_ == "":
		name_ = GagStager.T3_PROPS[absi(_frame) % GagStager.T3_PROPS.size()]
	fx.drop_prop(name_, b.global_position.x, b.global_position.y - 640.0, b.top_position().y + 60.0, b.global_position.y)


# --- Busted Cam -------------------------------------------------------------------------------

## Re-stage the moment he saw her (60 ticks) with the Busted Cam look (GDD §4.6): the real rigs
## replay their recorded clips + frames (RigPlayer `play(clip, {start_frame})` +
## `set_external_frame`), the red vignette, the split frame, the `fx.spotted` stamp and the
## dotted sight line.
func start_busted_replay(spotted_tick: int) -> void:
	_replay_n = fx.busted_cam(busted, spotted_tick)
	if _replay_n <= 0:
		return
	_replay_t = 0.0
	hush_view.replay = true
	bellows_view.replay = true
	var f := busted.replay_frame(0)
	if cam != null:
		var mid := (f.h_pos + f.b_pos) * 0.5 + Vector2(0, -200)
		var span := absf(f.h_pos.x - f.b_pos.x) + 700.0
		var z := clampf(2200.0 / span, 0.8, 1.3)
		cam.request_gag(mid, z, 6, BustedCam.REPLAY - 12, 8, 100)
	replay_changed.emit(true)


func _advance_replay(vdt: float) -> void:
	_replay_t += maxf(vdt, 1.0 / 120.0)
	var i := int(_replay_t * 60.0)
	if i >= _replay_n:
		_replay_t = -1.0
		hush_view.replay = false
		bellows_view.replay = false
		fx.end_busted()
		replay_changed.emit(false)
		return
	var f := busted.replay_frame(i)
	hush_view.mute_sounds = true
	bellows_view.mute_sounds = true
	hush_view.pose_replay(f.h_pos, f.h_facing, f.h_clip, f.h_frame, f.h_state, vdt)
	bellows_view.pose_replay(f.b_pos, f.b_facing, f.b_clip, f.b_frame, f.b_state, vdt)
	hush_view.mute_sounds = false
	bellows_view.mute_sounds = false
	fx.sight_line(bellows_view.eye_position(), hush_view.global_position + Vector2(0, -170), true)
	if cam != null:
		var sx := (cam.world_to_screen(hush_view.global_position).x + cam.world_to_screen(bellows_view.global_position).x) * 0.5
		fx.busted.split_x = sx / maxf(1.0, cam.view_size().x)
