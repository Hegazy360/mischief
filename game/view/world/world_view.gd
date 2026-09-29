## WorldView — the stage set of a Night (TECH §5.1, §5.4): the theatre, the rooms (bg + fg),
## a PropView per hotspot, the CharacterViews and the FX layer, all driven from ViewSnapshot
## + events (never the sim directly).
##
## `setup(db_or_null, episode_or_null, snapshot_source)`: `snapshot_source` is a SimDriver
## (or anything with `snapshot() / prev_snapshot() / alpha() / view_delta()` and a `ticked`
## signal); a bare world (SimWorld / FakeWorld) is accepted too and snapshotted per frame.
## The house comes from the ContentDB / house.json (greybox from GDD §7.1 widths when
## absent); rooms outside the episode are an unlit set with velvet ropes at their doorways.
##
## Per frame it interpolates the characters (alpha), updates the stare strip, bubble, "?",
## footprints, outlines and badges; per tick it records the Busted Cam buffer and reacts to
## readability events (noise rings, entry warnings, "!", the Busted Cam replay). Comic
## staging (Gag-Cam, captions, bursts) is GagStager's.
class_name WorldView
extends Node2D

signal built
## The Busted Cam replay started / ended.
signal replay_changed(on: bool)

const BADGE_REFRESH_FRAMES := 6
const SQUEAK_RADIUS := 420.0

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
var props_node: Node2D = null
var chars_node: Node2D = null
var fg_node: Node2D = null
var fx: FxLayer = null
var hush_view: CharacterView = null
var bellows_view: CharacterView = null
var props: Dictionary = {}
var rooms: Dictionary = {}
var busted: BustedCam = BustedCam.new()

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


func _build() -> void:
	for c in get_children():
		c.queue_free()
	props.clear()
	rooms.clear()
	stage = StageView.new()
	add_child(stage)
	stage.setup(layout)
	rooms_node = Node2D.new()
	rooms_node.name = "Rooms"
	add_child(rooms_node)
	props_node = Node2D.new()
	props_node.name = "Props"
	add_child(props_node)
	chars_node = Node2D.new()
	chars_node.name = "Characters"
	add_child(chars_node)
	fg_node = Node2D.new()
	fg_node.name = "RoomsFg"
	fg_node.z_index = 8
	add_child(fg_node)
	for r in layout.rooms:
		var rv := RoomView.new()
		rooms_node.add_child(rv)
		rv.setup(r, layout, not unlocked.has(r.id), fg_node)
		rooms[r.id] = rv
	_add_ropes()
	fx = FxLayer.new()
	fx.cam = cam
	fx.layout = layout
	fx.time_source = source if source != null and source.has_method("view_delta") else null
	add_child(fx)
	fx.warm()
	_hotspot_ids.clear()
	for hs in layout.hotspots:
		var pv := PropView.new()
		props_node.add_child(pv)
		pv.setup(hs, layout, not unlocked.has(hs.room))
		props[hs.id] = pv
		_hotspot_ids.append(hs.id)
		fx.badges.register(hs.id, pv.badge_anchor(), hs.room)
	hush_view = CharacterView.new()
	hush_view.info = info
	hush_view.layout = layout
	chars_node.add_child(hush_view)
	hush_view.setup("hush", rig_override, force_puppets)
	bellows_view = CharacterView.new()
	bellows_view.info = info
	bellows_view.layout = layout
	chars_node.add_child(bellows_view)
	bellows_view.setup("bellows", rig_override, force_puppets)


## Velvet ropes across doorways between an open room and a locked one.
func _add_ropes() -> void:
	var rope_tex := ViewKit.tex("res://art/house/stage/velvet_rope.svg")
	if rope_tex == null:
		rope_tex = FxArt.sprite("fallback/velvet_rope")
	for l in layout.links:
		if l.kind == "stairs":
			continue
		var a_open := unlocked.has(l.a)
		var b_open := unlocked.has(l.b)
		if a_open == b_open:
			continue
		var r := layout.room(l.a if a_open else l.b)
		if r == null:
			continue
		var s := Sprite2D.new()
		s.texture = rope_tex
		s.centered = false
		var sz := rope_tex.get_size()
		# Across the doorway, on the locked side so it never covers the open room's props.
		var locked_dir := 1.0 if (l.x >= r.x1 - 1.0) else -1.0
		s.position = Vector2(l.x - sz.x * 0.5 + locked_dir * sz.x * 0.42, layout.floor_y(r.floor) - sz.y + 6.0)
		s.z_index = 9
		s.name = "Rope_" + l.id
		fg_node.add_child(s)


## Retry in place: clear transient FX and the Busted Cam buffer (the driver resets the sim).
func reset() -> void:
	busted.clear()
	_replay_t = -1.0
	if fx != null:
		fx.clear()
	_entry_room = ""
	_path_stamp = -1


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


## Hotspots on screen for tap-assist (TECH §5.4): [{id, kind, rect (screen), world_rect,
## priority (2 hotspot, 1 door / stairs / exit)}] in unlocked rooms.
func hotspot_rects_in_view() -> Array:
	var out: Array = []
	var vis := cam.visible_world_rect() if cam != null else Rect2(-1e6, -1e6, 2e6, 2e6)
	for hs in layout.hotspots:
		if not unlocked.has(hs.room) or not vis.intersects(hs.rect):
			continue
		var sr := hs.rect
		if cam != null:
			var a := cam.world_to_screen(hs.rect.position)
			var b := cam.world_to_screen(hs.rect.end)
			sr = Rect2(a, b - a)
		var pr := 1 if hs.kind in ["door", "stairs", "exit"] else 2
		out.append({"id": hs.id, "kind": hs.kind, "rect": sr, "world_rect": hs.rect, "priority": pr})
	return out


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
		hush_view.apply(prev.hush, snap.hush, alpha, vdt)
		bellows_view.apply(prev.bellows, snap.bellows, alpha, vdt)
	hush_view.look_target = bellows_view.head_position()
	_update_fx(snap, delta)
	_update_props(snap, delta)


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
		if not refresh:
			continue
		var hs: Variant = snap.hotspots.get(id, null)
		var st: Dictionary = hs if hs is Dictionary else {}
		var at_container := pv.hotspot.kind == "container" and (snap.hush.state == "RUMMAGE" or snap.hush.state == "PICK_WINDOW") \
				and absf(snap.hush.x - pv.hotspot.use_x) < 120.0
		pv.set_state_from(st, at_container)
		fx.badge(id, PropView.badge_kind(pv.hotspot.kind, st, snap.hush.carrying) if not pv.locked and not st.is_empty() else "")


## Per-tick events (SimDriver.ticked): Busted Cam buffer + readability FX.
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
		match ViewKit.s(d.get("e", "")):
			"noise":
				var kind := ViewKit.s(d.get("kind", ""))
				var col := FxNoiseRings.SQUEAK if kind == "squeak" else FxNoiseRings.WHITE
				squeak_ring = squeak_ring or kind == "squeak"
				fx.noise_ring(_room_point(ViewKit.s(d.get("room", snap.hush.room)), float(d.get("x", snap.hush.x)), -60.0),
					float(d.get("r", 500)), col)
			"squeak":
				if not squeak_ring:
					fx.noise_ring(_room_point(ViewKit.s(d.get("room", snap.hush.room)), float(d.get("x", snap.hush.x)), -150.0),
						SQUEAK_RADIUS, FxNoiseRings.SQUEAK)
			"entry_warning":
				var room := ViewKit.s(d.get("room", ""))
				if room == snap.hush.room or room == "":
					_entry_room = snap.hush.room
					_entry_t = float(d.get("eta", 90)) / 60.0 + 0.3
					var from := snap.bellows.room
					for r in snap.path_rooms:
						if r != snap.hush.room:
							from = r
						else:
							break
					fx.entry_warning(snap.hush.room, from, int(d.get("eta", 90)))
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


## True while an entry warning for Hush's room is live (PiP rule "heading to her room").
func entry_warning_active() -> bool:
	return _entry_room != ""


func _room_point(room: String, x: float, up: float) -> Vector2:
	return Vector2(x, layout.room_floor_y(room) + up)


## Re-stage the moment he saw her (60 ticks) with the Busted Cam look.
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
	hush_view.pose_replay(f.h_pos, f.h_facing, f.h_clip, f.h_frame, f.h_state, vdt)
	bellows_view.pose_replay(f.b_pos, f.b_facing, f.b_clip, f.b_frame, f.b_state, vdt)
	fx.sight_line(bellows_view.eye_position(), hush_view.global_position + Vector2(0, -170), true)
	if cam != null:
		var sx := (cam.world_to_screen(hush_view.global_position).x + cam.world_to_screen(bellows_view.global_position).x) * 0.5
		fx.busted.split_x = sx / maxf(1.0, cam.view_size().x)
