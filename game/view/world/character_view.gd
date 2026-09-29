## CharacterView — one actor on stage (TECH §5.4). Reads a ViewSnapshot.Actor every frame,
## interpolates its position between ticks with `SimDriver.alpha()`, and maps its state to a
## clip through ClipMap (`data/anim/<rig>/map.json`, else `view/world/default_maps/`).
##
## * With the rig system (`res://view/rig/rig_player.gd`, owner `rig`, soft) and the actor's
##   rig data, a RigPlayer plays the clips; reactions are frame-locked to the sim
##   (`set_external_frame(react_t + alpha)`), tint follows temper, residues and specs follow
##   the snapshot. Missing rig data falls back to the `_mannequin` stand-in rig.
## * Without it, a FallbackPuppet (flat sprites + squash / stretch / lean / tremble, with the
##   reaction beats taken from reactions.json marks) keeps the view alive and readable.
## * Hush hidden: the body is not drawn; her eyes blink in the hiding spot and track Bellows.
class_name CharacterView
extends Node2D

## Clip events (sfx, voice, laugh, fx, cam, shake, hitstop, …) from the RigPlayer, with
## `"actor"` and `"pos"` (world) added.
signal clip_event(ev: Dictionary)

const RIG_PLAYER := "res://view/rig/rig_player.gd"
const HEIGHTS := {"hush": 340.0, "bellows": 380.0}
const TURN_FRAMES := 6.0
const STRIDES := {"hush": 58.0, "bellows": 46.0}

var actor: String = "hush"
var rig_id: String = ""
var info: ContentInfo = null
var layout: HouseLayout = null
var map: Dictionary = {}
## True when a RigPlayer draws this actor.
var uses_rig: bool = false
var rig: Node2D = null
var puppet: FallbackPuppet = null
## Where Hush's hidden eyes look (Bellows' head, world).
var look_target: Vector2 = Vector2.ZERO
## Overrides for the Busted Cam replay (set by WorldView).
var replay: bool = false

var _pick := ClipMap.Pick.new()
var _clip := ""
var _frame := 0.0
var _flip := 1.0
var _walk_phase := 0.0
var _t := 0.0
var _eyes: _HiddenEyes = null
var _last_x := 0.0
var _residues := PackedStringArray()
var _tier := -1
var _specs := -1
var _rx_info: Dictionary = {}
var _rx_key := ""
var _view_dt := 0.0


func _init() -> void:
	name = "CharacterView"


## Build the drawing for `actor_id` ("hush", "bellows", …). `rig_id_` defaults to the actor.
## `force_fallback` skips the rig system (tests, `--puppets`).
func setup(actor_id: String, rig_id_: String = "", force_fallback: bool = false) -> void:
	actor = actor_id
	rig_id = rig_id_ if rig_id_ != "" else actor_id
	name = "Char_" + actor
	map = ClipMap.load_map(rig_id)
	if not force_fallback:
		_try_rig()
	if not uses_rig:
		puppet = FallbackPuppet.new()
		puppet.kind = actor
		add_child(puppet)
	_eyes = _HiddenEyes.new()
	_eyes.visible = false
	add_child(_eyes)


func _try_rig() -> void:
	var s := ViewKit.soft_script(RIG_PLAYER)
	if s == null:
		return
	var use_id := rig_id
	if not ResourceLoader.exists("res://data/rigs/%s/rig.json" % use_id) and not FileAccess.file_exists("res://data/rigs/%s/rig.json" % use_id):
		var stand_in := ViewKit.s(map.get("stand_in", "_mannequin"))
		if not FileAccess.file_exists("res://data/rigs/%s/rig.json" % stand_in):
			return
		use_id = stand_in
		map = ClipMap.load_map(use_id)
	var n: Variant = s.new()
	if not (n is Node2D) or not (n as Node2D).has_method("setup"):
		if n is Node:
			(n as Node).free()
		return
	rig = n
	add_child(rig)
	rig.call("setup", use_id)
	# A rig whose data failed to load (missing / half-authored), or that has no clips yet (not
	# even its idle), falls back to the puppet: an invisible character is never acceptable.
	var loaded := rig.get("rig") != null and rig.get("poses") != null and rig.get("atlas") != null
	var idle := ViewKit.s(map.get("idle", ""))
	if not loaded or not ClipMap.clip_exists(idle):
		push_warning("CharacterView: rig '%s' %s; using the stand-in puppet" % [use_id,
			"did not load" if not loaded else "has no clips yet (%s)" % idle])
		rig.queue_free()
		rig = null
		map = ClipMap.load_map(rig_id)
		return
	if rig.has_signal("clip_event"):
		rig.connect("clip_event", _on_rig_event)
	uses_rig = true


func _on_rig_event(ev: Dictionary) -> void:
	ev["actor"] = actor
	ev["pos"] = global_position
	clip_event.emit(ev)


## Character height (feet to head top, world px).
func height_px() -> float:
	return float(HEIGHTS.get(actor, 320.0))


## World position of the head centre / eyes / head top (camera focus, captions, bubbles).
func head_position() -> Vector2:
	return global_position + Vector2(0, -height_px() + 75.0)


func eye_position() -> Vector2:
	return global_position + Vector2(18.0 * _flip, -height_px() + 95.0)


func top_position() -> Vector2:
	return global_position + Vector2(0, -height_px())


func current_clip() -> String:
	return _clip


func current_frame() -> float:
	return _frame


## Update from the snapshot actors (`prev` → `cur` at `alpha`). `view_dt` = view-time delta.
func apply(prev: ViewSnapshot.Actor, cur: ViewSnapshot.Actor, alpha: float, view_dt: float) -> void:
	if replay:
		return
	visible = cur.present
	if not cur.present:
		return
	_t += view_dt
	_view_dt = view_dt
	var x := cur.x
	var y := cur.y
	if prev != null and prev.present and prev.room == cur.room and prev.floor == cur.floor:
		x = lerpf(prev.x, cur.x, alpha)
	y = _stairs_y(cur, x, y)
	position = Vector2(x, y)
	_update_facing(float(cur.facing), view_dt)
	var hidden := actor == "hush" and (cur.state == "HIDDEN" or cur.hidden_spot != "")
	_update_eyes(hidden, cur, view_dt)
	ClipMap.resolve(map, cur, alpha, _pick)
	if uses_rig:
		_drive_rig(cur, hidden)
	else:
		_drive_puppet(cur, hidden, view_dt)
	_last_x = x


## Pose from a Busted Cam frame (replay: positions and clips from the ring buffer).
func pose_replay(pos: Vector2, facing: int, clip: String, frame: float, state: String, view_dt: float) -> void:
	visible = true
	position = pos
	_update_facing(float(facing), view_dt)
	_t += view_dt
	if uses_rig and rig != null:
		if clip != "" and clip != _clip:
			_clip = clip
			rig.call("play", clip, {"blend_in": 0})
		if rig.has_method("set_external_frame"):
			rig.call("set_external_frame", frame)
		rig.visible = state != "HIDDEN"
		if rig.has_method("set_facing"):
			rig.call("set_facing", facing, false)
	elif puppet != null:
		puppet.visible = state != "HIDDEN"
		var p := "stand"
		if state == "FROZEN":
			p = "freeze"
		elif state == "SPOTTED" or state == "CHASE":
			p = "shock"
		elif state == "WALK" or state == "RUN" or (actor == "bellows" and state in ["ROUTINE", "DETOUR", "CURIOUS"] and fmod(frame, 28.0) < 14.0):
			p = "step" if fmod(frame, 20.0) < 10.0 else "stand"
		puppet.pose = p
		puppet.set_motion(Vector2.ONE, 0.0, Vector2.ZERO, _flip)
	_eyes.visible = false


func _stairs_y(cur: ViewSnapshot.Actor, x: float, y: float) -> float:
	if cur.state != "STAIRS" or layout == null:
		return y
	for l in layout.links:
		if l.kind != "stairs":
			continue
		var ra := layout.room(l.a)
		var rb := layout.room(l.b)
		if ra == null or rb == null or absf(l.bx - l.ax) < 1.0:
			continue
		var u := clampf((x - l.ax) / (l.bx - l.ax), 0.0, 1.0)
		return lerpf(layout.floor_y(ra.floor), layout.floor_y(rb.floor), u)
	return y


func _update_facing(target: float, dt: float) -> void:
	var step := dt * 60.0 / TURN_FRAMES * 2.0
	_flip = move_toward(_flip, target, step)


func _update_eyes(hidden: bool, cur: ViewSnapshot.Actor, dt: float) -> void:
	if _eyes == null:
		return
	_eyes.visible = hidden
	if not hidden:
		return
	var spot := layout.hotspot(cur.hidden_spot) if layout != null else null
	var c := global_position + Vector2(0, -150)
	if spot != null:
		c = spot.rect.get_center() + Vector2(0, -spot.rect.size.y * 0.12)
	_eyes.global_position = c
	_eyes.look = (look_target - c).normalized() if look_target != Vector2.ZERO else Vector2.ZERO
	_eyes.tick(dt)


func _drive_rig(cur: ViewSnapshot.Actor, hidden: bool) -> void:
	rig.visible = not hidden and _pick.clip != ""
	var real := get_process_delta_time()
	rig.set("time_scale", clampf(_view_dt / real, 0.0, 4.0) if real > 0.0 else 1.0)
	if _pick.clip != "" and _pick.clip != _clip:
		_clip = _pick.clip
		var opts := {"loop": _pick.loop}
		if _pick.stride:
			opts["speed"] = maxf(1.0, cur.speed_px_s)
		else:
			opts["rate"] = _pick.speed
		if _pick.external:
			opts["blend_in"] = 0
			opts["tier"] = cur.react_tier
			opts["suppressed"] = cur.react_suppressed
		rig.call("play", _clip, opts)
	if _pick.external and rig.has_method("set_external_frame"):
		rig.call("set_external_frame", _pick.frame)
	elif _pick.stride and cur.moving and rig.has_method("set_speed"):
		rig.call("set_speed", maxf(1.0, cur.speed_px_s))
	_frame = _pick.frame if _pick.external else (float(rig.call("current_frame")) if rig.has_method("current_frame") else 0.0)
	if rig.has_method("set_facing"):
		rig.call("set_facing", cur.facing, true)
	if actor == "bellows":
		if cur.tier != _tier and rig.has_method("set_tint_tier"):
			_tier = cur.tier
			rig.call("set_tint_tier", cur.tier)
		var sp := 1 if cur.specs_on else 0
		if sp != _specs and rig.has_method("set_prop_state"):
			_specs = sp
			rig.call("set_prop_state", "specs", "on" if cur.specs_on else "dangling")
		if cur.residues != _residues and rig.has_method("set_residue"):
			for r in _residues:
				if not cur.residues.has(r):
					rig.call("set_residue", r, false)
			for r in cur.residues:
				if not _residues.has(r):
					rig.call("set_residue", r, true)
			_residues = cur.residues.duplicate()


func _drive_puppet(cur: ViewSnapshot.Actor, hidden: bool, dt: float) -> void:
	puppet.visible = not hidden
	if hidden:
		return
	_clip = _pick.clip
	_frame = _pick.frame
	puppet.tier = cur.tier if actor == "bellows" else 0
	puppet.specs = cur.specs_on
	var sq := Vector2.ONE
	var lean := 0.0
	var off := Vector2.ZERO
	var pose := "stand"
	var stride := float(STRIDES.get(actor, 50.0))
	if cur.moving:
		_walk_phase += absf(position.x - _last_x) / stride
		pose = "step" if int(_walk_phase) % 2 == 1 else "stand"
		var b := absf(sin(_walk_phase * PI))
		off.y = -b * (7.0 if actor == "hush" else 4.0)
		sq = Vector2(1.0 - 0.03 * b, 1.0 + 0.03 * b)
		if cur.running:
			lean = 0.12 * _flip
	if cur.reacting:
		var r := _reaction_pose(cur)
		pose = ViewKit.s(r[0])
		sq = r[1]
		lean = float(r[2]) * _flip
		off += r[3]
	else:
		match cur.state:
			"FROZEN":
				pose = "freeze"
			"RIGGING":
				pose = "step" if int(_t * 12.0) % 2 == 0 else "stand"
				off.x = sin(_t * 40.0) * 2.0
				sq = Vector2(1.04, 0.96)
			"SQUEAKING":
				pose = "shock"
			"RUMMAGE", "PICK_WINDOW":
				pose = "step" if int(_t * 8.0) % 2 == 0 else "stand"
				sq = Vector2(1.05, 0.93)
			"SPOTTED":
				pose = "shock"
				sq = Vector2(0.9, 1.12)
			"CHASE":
				pose = "shock" if int(_t * 6.0) % 2 == 0 else "step"
				lean = 0.16 * _flip
			"MELTDOWN":
				pose = "shock"
				var stomp := absf(sin(_t * 9.0))
				off.y = -stomp * 22.0
				sq = Vector2(1.0 + 0.08 * (1.0 - stomp), 1.0 - 0.08 * (1.0 - stomp))
			"EXHAUSTED":
				sq = Vector2(1.06, 0.9)
				lean = -0.06 * _flip
			"CAUGHT":
				off.y = -60.0 + sin(_t * 14.0) * 4.0
			"CAUGHT_HOLD":
				pose = "shock" if int(_t * 5.0) % 2 == 0 else "stand"
	if not cur.moving and not cur.reacting and cur.state != "FROZEN":
		sq.y *= 1.0 + 0.012 * sin(_t * TAU / 3.2)
	puppet.pose = pose
	puppet.set_motion(sq, lean, off, _flip)


## Fallback reaction beats from the reaction marks: [pose, squash, lean, offset].
func _reaction_pose(cur: ViewSnapshot.Actor) -> Array:
	var key := cur.react_archetype + "_" + cur.react_variant
	if key != _rx_key:
		_rx_key = key
		var size := "M"
		if info != null:
			size = ViewKit.s(info.prank(cur.react_prank).get("size", "M"))
			_rx_info = info.reaction(cur.react_archetype, cur.react_variant, size, cur.react_len)
		else:
			_rx_info = {"antic": 30, "accent": 60, "hold0": 63, "hold1": 120, "release": 150}
	var f := float(cur.react_t)
	var antic := float(_rx_info.get("antic", 30))
	var accent := float(_rx_info.get("accent", 60))
	var hold1 := float(_rx_info.get("hold1", 120))
	var release := float(maxi(int(_rx_info.get("release", 150)), cur.react_len))
	if f < antic:
		return ["stand", Vector2.ONE, 0.0, Vector2.ZERO]
	if f < accent:
		var u := clampf((f - antic) / maxf(1.0, accent - antic), 0.0, 1.0)
		var e := u * u
		return ["stand", Vector2(1.0 + 0.12 * e, 1.0 - 0.16 * e), -0.10 * e, Vector2(0, 0)]
	if f < accent + 3.0:
		return ["shock", Vector2(0.78, 1.32), 0.12, Vector2(0, -18)]
	if f < hold1:
		var tr := Vector2(sin(f * 2.1) * 2.5, cos(f * 1.7) * 1.5)
		var u2 := clampf((f - accent - 3.0) / 8.0, 0.0, 1.0)
		var sy := lerpf(1.32, 1.06, ViewKit.ease_out_back(u2)) + 0.015 * sin(f * 0.3)
		return ["shock", Vector2(1.0 / sy, sy), 0.05, tr]
	var u3 := clampf((f - hold1) / maxf(1.0, release - hold1), 0.0, 1.0)
	var over := sin(u3 * PI) * 0.06
	return ["stand", Vector2(1.0 + over, 1.0 - over), 0.0, Vector2.ZERO]


## Hush's eyes in the dark gap of a hiding spot: blink every 2–4 s, pupils track Bellows.
class _HiddenEyes extends Node2D:
	var look := Vector2.ZERO
	var _blink_t := 2.2
	var _blink := 0.0
	var _eyes: Texture2D = null
	var _dot: Texture2D = null
	var _seed := 7

	func _ready() -> void:
		_eyes = FxArt.sprite("fallback/eyes")
		_dot = FxArt.sprite("dot")
		z_index = 3

	func tick(dt: float) -> void:
		_blink_t -= dt
		if _blink_t <= 0.0:
			_blink = 0.1
			_seed = (_seed * 1103515245 + 12345) & 0x7fffffff
			_blink_t = 2.0 + float(_seed % 2000) / 1000.0
		_blink = maxf(0.0, _blink - dt)
		queue_redraw()

	func _draw() -> void:
		var sy := 0.12 if _blink > 0.0 else 1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, sy))
		draw_rect(Rect2(-40, -22, 80, 44), Color(0.05, 0.05, 0.1, 0.55))
		if _eyes != null:
			draw_texture(_eyes, Vector2(-32, -16))
		if _dot != null and sy > 0.5:
			var o := look * 5.0
			draw_texture_rect(_dot, Rect2(Vector2(-14 - 5, -5) + o - Vector2(0, 0), Vector2(10, 10)), false, ViewKit.INK)
			draw_texture_rect(_dot, Rect2(Vector2(14 - 5, -5) + o, Vector2(10, 10)), false, ViewKit.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
