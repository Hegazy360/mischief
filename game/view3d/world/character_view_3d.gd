## CharacterView3D — one actor on the 3D stage (brief r3d-view3d §4.3; the 2D CharacterView's ClipMap contract on
## `RigPlayer3D`). Reads a ViewSnapshot.Actor every frame, interpolates between ticks with `SimDriver.alpha()`, maps its
## state to clips through ClipMap's 3D format and drives the rig:
##
## * **Placement** (REDESIGN §5.1/§5.5, index R4/R5): x = sim x / 200, floor y = 3.5·f, **lane z −1.0**; Bellows at his
##   station's `bellows_z` (−1.4) with the station yaw while he performs; Hush eases (0.2 s, view only) to the rigged
##   hotspot's `reach_pos` (dx from `use_x`, z ≥ −1.6; ACHOO-RIA! = on Bellows' stool, the clip's pelvis carries the
##   step) and dives toward a hiding spot's `occupant_z`; hidden = not drawn (her eyes show in the prop).
## * **Reaction travel:** the sim moves x along the reaction's travel frames; the view adds the `arc_px` y arc and
##   interpolates z and the pelvis toward the `house3d.json` landing over the same progress, so the sneeze ends with his
##   pelvis in the sink basin (`House3D.landing_box`).
## * **Cheat-out** (REDESIGN §5.1): 35° idle / performing, 20° walking, 5° face-to-face, ≤ 10° while reaching (the head
##   turns to the camera instead), the clip's `cheat_deg` in reactions; the rig yaws, mirrored cells by facing.
## * **Clips:** reactions and one-shots frame-locked, `rig:<prank>` locked to rig progress, micro-gags / cues / shrug /
##   pickup on the masked overlay, glances (`rig_actions.json glances` ‰) as `head` overlays once per mark,
##   `hush/rig_step_down` before any locomotion after a stepped rig released mid-step; a missing reaction plays
##   `bellows/st_double_take` held to the sim's length (+ the caption, GagStager3D); every fallback is counted.
## * **The body is the meter:** tint tier, specs on when Livid, residues → looks and body slots (clip-owned until the
##   clip's release, then the residue's — `set_body_slot(…, &"residue")`); freeze = marble (stone 0.1 s, the plinth
##   pops up; colour back with a shiver 0.15 s on release); blob shadow r 0.34 / 0.45 m, 32 %.
## * **Stand-ins:** without a RigPlayer3D (or when its setup fails) a two-colour capsule at the right height draws the
##   actor — counted as a puppet (`fallback_counts().puppets`).
class_name CharacterView3D
extends Node3D

## Clip events from the rig with "actor" and "pos" (world Vector3) added. One reused Dictionary: do not keep it.
signal clip_event(ev: Dictionary)
## The clips' sound events only (sfx / voice / laugh); not while `mute_sounds`.
signal sound_event(ev: Dictionary)

const RIG_PLAYER := "res://view3d/char/rig_player_3d.gd"
const PLINTH_SCENE := "res://art3d/chars/hush/plinth.glb"
const HEIGHTS := {"hush": 1.60, "bellows": 1.78}
const STAND_IN_COLOURS := {"hush": [Color("#1E2748"), Color("#F4EFE6")], "bellows": [Color("#6B3F8F"), Color("#F2C9A8")]}
const FIDGET_AFTER_S := 3.0
const MG_FALLBACK_F := 90.0
const EMOTE_FACE := {"sing": "sing_mid", "hum": "hum", "smug": "smug", "laugh": "blissful", "tut": "disdain",
	"sniff": "sniff", "yum": "blissful", "yawn": "asleep"}
const STATIC_CLIP := "#static"
const STEP_DOWN_CLIP := "hush/rig_step_down"
const GLANCE_CLIP := "hush/act_glance"
const FALLBACK_REACTION := "bellows/st_double_take"
const PLINTH_POP_S := 0.1
const SHIVER_S := 0.15
const TOMATO_S := 4.0
const LOOK_WEIGHT_EASE := 6.0

var actor: String = "hush"
var rig_id: String = ""
## Settings `hush_head` ("" | "head_b") for Hush's rig variant (ruling R6).
var variant: String = ""
var skin: String = ""
var info: ContentInfo = null
var layout: HouseLayout = null
## house3d.json (Dictionary; empty until r3d-sets lands it).
var house3d: Dictionary = {}
## The set (House3D, or WorldView3D's greybox): reach_pos, landing boxes, hand-offs, decor, props. Duck-typed.
var set3d: Object = null
## rig_actions.json (Hush).
var rig_actions: Dictionary = {}
var map: Dictionary = {}
var ctx: ClipMap.Ctx = ClipMap.Ctx.new()
## True when a RigPlayer3D with a loaded rig draws this actor.
var uses_rig: bool = false
## The RigPlayer3D (duck-typed until r3d-rig's P0 is final) or null.
var rig: Node3D = null
var stand_in: Node3D = null
var blob: MeshInstance3D = null
var plinth: Node3D = null
## Where the actor looks (world; Vector3.INF = nowhere) and how strongly.
var look_target: Vector3 = Vector3.INF
var look_weight: float = 0.0
var replay: bool = false
var mute_sounds: bool = false
var combos_formed: PackedStringArray = PackedStringArray()
## The room light for this actor's char_toon (WorldView3D sets it: Hush = her room, Bellows ≥ 0.9).
var stage_level: float = 1.0
## Pooled decal material for the blob shadow (Decals3D shares one per kind).
var blob_material: ShaderMaterial = null

var clip_fallbacks: int = 0
var puppets: int = 0
var fallback_by_clip: Dictionary = {}

static var _logged: Dictionary = {}
## clip id → the sidecar's optional "stage" block ({x, z, facing, cheat_deg}) or {} (r3d-anim: rig clips are
## authored for one facing; the view plays them that way).
static var _stage_cache: Dictionary = {}

var _pick := ClipMap.Pick.new()
var _clip := ""
var _clip_sig := ""
var _sig_tier := 1
var _sig_supp := false
var _sig_rx := false
var _frame := 0.0
var _ov_clip := ""
var _ov_face := ""
var _t := 0.0
var _view_dt := 0.0
var _ev: Dictionary = {}
var _has: Dictionary = {}
# placement
var _x := 0.0
var _floor_y := 0.0
var _z := View3DConst.LANE_Z
var _z_from := View3DConst.LANE_Z
var _z_to := View3DConst.LANE_Z
var _z_t := 1.0
var _y_off := 0.0
var _dx := 0.0
var _dx_to := 0.0
var _cheat := View3DConst.CHEAT_IDLE
var _facing := 1
var _station_yaw := NAN
var _placed := false
# reaction travel
var _rx_key := ""
var _rx_x0 := 0.0
var _rx_x1 := 0.0
var _rx_z0 := View3DConst.LANE_Z
var _rx_land: Dictionary = {}
var _rx_arc := 0.0
var _landed := false
# meter state
var _tier := -1
var _looks := PackedStringArray()
var _looks_key := ""
var _costume := ""
var _specs := ""
var _slots: Dictionary = {}
var _last_prank := ""
# flavours / fidgets / overlays
var _state := ""
var _reacting := false
var _moving := false
var _snap_facing := 0
var _idle_s := 0.0
var _fidget_n := 0
var _flavour_pending := ""
var _ov_flavour_pending := ""
var _flavour_state := ""
var _mg_len := 0.0
var _mg_state := ""
var _mg_pending: Dictionary = {}
var _cue_len := 0.0
var _last_wanted := ""
var _last_ov_wanted := ""
# rigging extras
var _rig_prank := ""
var _rig_step_used := false
var _glance_done: Dictionary = {}
var _glance_left := 0.0
var _step_down_f := -1.0
# freeze
var _stone := false
var _plinth_t := 0.0
var _shiver_t := 0.0
var _tomato_s := 0.0


func _init() -> void:
	name = "CharacterView3D"


## Build the drawing for `actor_id` ("hush", "bellows"). `force_stand_in` skips the rig (tests).
func setup(actor_id: String, rig_variant: String = "", force_stand_in: bool = false) -> void:
	actor = actor_id
	rig_id = actor_id
	name = "Char3D_" + actor
	skin = String(_setting("hush_skin", ""))
	if skin == "pip":
		if not _logged.has("pip"):
			_logged["pip"] = true
			print_verbose("[view3d] hush_skin 'pip' is not built in R3D (ruling R7): Hush plays")
		skin = ""
	variant = rig_variant
	ctx.rig = actor
	ctx.skin = skin
	ctx.format3d = true
	ctx.exists_fn = ClipMap.clip_exists3d
	ctx.len_fn = ClipMap.clip_length3d
	ctx.activity_clip_fn = _activity_clip
	if actor == "hush":
		rig_actions = ClipMap.rig_actions()
		ctx.rig_actions = rig_actions
	map = ClipMap.load_map3d(actor)
	if not force_stand_in:
		_try_rig()
	if not uses_rig:
		puppets = 1
		if rig == null:
			_make_stand_in()
	_make_blob()


func _try_rig() -> void:
	if not ResourceLoader.exists(RIG_PLAYER):
		return
	var s: Variant = load(RIG_PLAYER)
	if not (s is Script) or not (s as Script).can_instantiate():
		return
	var n: Variant = (s as Script).new()
	if not (n is Node3D):
		if n is Node:
			(n as Node).free()
		return
	rig = n
	add_child(rig)
	if "auto_advance" in rig:
		rig.set("auto_advance", false)
	var ok := bool(rig.call("setup", actor, variant)) if rig.has_method("setup") else false
	for m in ["play", "play_overlay", "stop_overlay", "set_external_frame", "release_external", "set_speed", "advance",
			"set_facing", "set_cheat", "look_at_point", "set_face", "set_tint_tier", "set_stone", "set_look",
			"set_body_slot", "set_prop", "socket_global", "socket_node", "head_global", "top_global", "feet_global",
			"screen_aabb", "reset", "current_frame", "current_clip", "has_clip", "set_stage_light", "flash",
			"set_outline_scale", "warm", "counts", "kick_jiggle"]:
		_has[m] = rig.has_method(m)
	if rig.has_signal("clip_event"):
		rig.connect("clip_event", _on_rig_event)
	uses_rig = ok
	if not ok:
		push_warning("CharacterView3D: rig '%s' did not load; the stand-in plays (counted)" % actor)


func _make_stand_in() -> void:
	var h := float(HEIGHTS.get(actor, 1.6))
	var cols: Array = STAND_IN_COLOURS.get(actor, [Color.GRAY, Color.WHITE])
	var root := Node3D.new()
	root.name = "StandIn"
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.24 if actor == "hush" else 0.36
	cap.height = h * 0.72
	body.mesh = cap
	body.position.y = cap.height * 0.5
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.2 if actor == "hush" else 0.22
	sph.height = sph.radius * 2.0
	head.mesh = sph
	head.position.y = h - sph.radius
	for pair in [[body, cols[0]], [head, cols[1]]]:
		var mi: MeshInstance3D = pair[0]
		var m := ShaderMaterial.new()
		m.shader = load(View3DConst.SH_CHAR)
		m.set_shader_parameter("albedo_color", pair[1])
		m.set_shader_parameter("vc_masks", false)
		var o := ShaderMaterial.new()
		o.shader = load(View3DConst.SH_OUTLINE)
		o.set_shader_parameter("outline_px", View3DConst.OUTLINE_CHAR_PX)
		m.next_pass = o
		mi.material_override = m
		mi.layers = View3DConst.MASK_CHAR
		MaterialWarm3D.register(m, &"char")
		root.add_child(mi)
	stand_in = root
	add_child(root)


func _make_blob() -> void:
	blob = MeshInstance3D.new()
	blob.name = "BlobShadow"
	var q := QuadMesh.new()
	var r := float(View3DConst.BLOB_R.get(actor, 0.34))
	q.size = Vector2(r * 2.0, r * 1.2)
	q.orientation = PlaneMesh.FACE_Y
	blob.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load(View3DConst.SH_DECAL)
	m.set_shader_parameter("shape", View3DConst.DECAL_DISC)
	m.set_shader_parameter("color", Color(0.05, 0.04, 0.10, View3DConst.BLOB_ALPHA))
	m.set_shader_parameter("softness", 0.55)
	m.render_priority = int(View3DConst.DECAL_PRIORITY["blob"])
	blob.material_override = m
	blob_material = m
	blob.layers = View3DConst.MASK_DECAL
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MaterialWarm3D.register(m, &"decal")
	add_child(blob)


func _activity_clip(id: String) -> String:
	if info == null or info.world == null:
		return ""
	var ai := ViewSnapshot.activity_info(info.world, id)
	return str(ai.get("clip", "")) if ai.get("clip", null) != null else ""


func _on_rig_event(ev: Dictionary) -> void:
	var t := str(ev.get("type", ""))
	var sound := t == "sfx" or t == "voice" or t == "laugh"
	if sound and mute_sounds:
		return
	_ev.clear()
	_ev.merge(ev, true)
	_ev["actor"] = actor
	_ev["pos"] = global_position if is_inside_tree() else position
	clip_event.emit(_ev)
	if sound:
		sound_event.emit(_ev)


# --- anchors (the overlay-anchor source reads these) ----------------------------------------------

func height_m() -> float:
	return float(HEIGHTS.get(actor, 1.6))


## World feet point (the root on the floor).
func feet_world() -> Vector3:
	return _world_pos()


## World head centre (the rig's head bone when available).
func head_world() -> Vector3:
	if uses_rig and bool(_has.get("head_global", false)) and rig.is_inside_tree():
		return rig.call("head_global")
	return _world_pos() + Vector3(0.0, height_m() - 0.22, 0.0)


## World head top.
func top_world() -> Vector3:
	if uses_rig and bool(_has.get("top_global", false)) and rig.is_inside_tree():
		return rig.call("top_global")
	return _world_pos() + Vector3(0.0, height_m(), 0.0)


## World chest (the punch-in focus for Bellows).
func chest_world() -> Vector3:
	return _world_pos() + Vector3(0.0, height_m() * 0.62, 0.0) if not uses_rig else head_world().lerp(feet_world(), 0.42)


## The skinned bounds (world) for projection; the height box when the rig cannot tell.
func world_aabb() -> AABB:
	if uses_rig and bool(_has.get("screen_aabb", false)) and rig.is_inside_tree():
		var b: Variant = rig.call("screen_aabb")
		if b is AABB and (b as AABB).size != Vector3.ZERO:
			return b
	var w := 0.5 if actor == "hush" else 0.8
	var p := _world_pos()
	return AABB(p + Vector3(-w * 0.5, 0.0, -0.2), Vector3(w, height_m(), 0.4))


## A rig socket's world transform (the node's transform without a rig).
func socket_world(socket_name: String) -> Transform3D:
	if uses_rig and bool(_has.get("socket_global", false)) and rig.is_inside_tree():
		return rig.call("socket_global", socket_name)
	return global_transform if is_inside_tree() else transform


## The node a set piece is lent to (a rig socket node; this node without a rig).
func socket_node(socket_name: String) -> Node3D:
	if uses_rig and bool(_has.get("socket_node", false)):
		var n: Variant = rig.call("socket_node", socket_name)
		if n is Node3D:
			return n
	return self


func _world_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func current_clip() -> String:
	return _clip


func current_frame() -> float:
	return _frame


func overlay_clip() -> String:
	return _ov_clip


func pick() -> ClipMap.Pick:
	return _pick


func fallback_face() -> String:
	return _ov_face


func looks() -> PackedStringArray:
	return _looks


func get_facing() -> int:
	return _facing


## The current lane depth (z, m) and the cheat-out (degrees) the view asked for.
func lane_z() -> float:
	return _z


func cheat_deg() -> float:
	return _cheat


func is_stone() -> bool:
	return _stone


func counts() -> Dictionary:
	return {"clip_fallbacks": clip_fallbacks, "puppets": puppets, "by_clip": fallback_by_clip.duplicate()}


func reset_counts() -> void:
	clip_fallbacks = 0
	fallback_by_clip.clear()
	_last_wanted = ""
	_last_ov_wanted = ""


## Retry / seek: drop flavours, overlays, combos, the meter cache and every clip-owned body slot
## (`RigPlayer3D.reset()`); residue looks are re-applied from the next snapshot.
func reset() -> void:
	ctx.flavour = ""
	ctx.ov_flavour = ""
	ctx.fidget_i = -1
	ctx.mg = ""
	ctx.cue = ""
	ctx.turn_f = -1.0
	ctx.state_var = 0
	combos_formed.clear()
	_flavour_pending = ""
	_ov_flavour_pending = ""
	_mg_pending = {}
	_idle_s = 0.0
	_clip = ""
	_clip_sig = ""
	_ov_clip = ""
	_ov_face = ""
	_tier = -1
	_specs = ""
	_looks = PackedStringArray()
	_looks_key = "#"
	_slots.clear()
	_rx_key = ""
	_landed = false
	_placed = false
	_glance_done.clear()
	_step_down_f = -1.0
	_rig_step_used = false
	_stone = false
	_tomato_s = 0.0
	if plinth != null:
		plinth.visible = false
	if uses_rig and bool(_has.get("reset", false)):
		rig.call("reset")
	if uses_rig and bool(_has.get("set_stone", false)):
		rig.call("set_stone", false, 0.0)


# --- sim events -------------------------------------------------------------------------------------

func on_event(ev: Dictionary) -> void:
	var e := str(ev.get("e", ""))
	if actor == "hush":
		match e:
			"rigged":
				_flavour_pending = "snicker"
			"cmd_rejected":
				_ov_flavour_pending = "shrug"
			"pick":
				_ov_flavour_pending = "pickup"
	elif actor == "bellows":
		match e:
			"micro_gag":
				_mg_pending = ev.duplicate()
			"meltdown_start":
				ctx.state_var = int(ev.get("variant", 0))
			"combo":
				var id := str(ev.get("id", ""))
				if id != "" and not combos_formed.has(id):
					combos_formed.append(id)
			"prank_fire":
				_last_prank = str(ev.get("prank", ""))


## Stage a director cue's overlay clip (`cue:<id>`) for `len_f` frames (≤ 0: the clip's length).
func play_cue(id: String, len_f: float = 0.0) -> void:
	ctx.cue = id
	ctx.cue_f = 0.0
	var clip := ClipMap.clip_of(ClipMap.entry(map, "cue:" + id, skin))
	_cue_len = len_f if len_f > 0.0 else float(maxi(1, ClipMap.clip_length3d(clip)))


# --- per frame --------------------------------------------------------------------------------------

## Update from the snapshot actors (`prev` → `cur` at `alpha`); `view_dt` = view-time delta.
func apply(prev: ViewSnapshot.Actor, cur: ViewSnapshot.Actor, alpha: float, view_dt: float) -> void:
	if replay:
		return
	visible = cur.present
	if not cur.present:
		return
	_t += view_dt
	_view_dt = view_dt
	var vf := view_dt * 60.0
	var p2 := CharacterView3D.stage_position_px(prev, cur, alpha)
	_update_ctx(cur, vf)
	ClipMap.resolve(map, cur, alpha, _pick, ctx)
	_step_down_rule(cur)
	_note_fallbacks()
	var hidden := _pick.hidden or (actor == "hush" and (cur.state == "HIDDEN" or cur.hidden_spot != ""
		or (cur.entering and cur.oneshot != "enter")))
	_place(cur, p2, view_dt)
	if uses_rig:
		_drive_rig(cur, hidden)
	elif stand_in != null:
		_drive_stand_in(cur, hidden)
	if blob != null:
		blob.visible = not hidden
		blob.position = Vector3(0.0, View3DConst.DECAL_Y - _y_off, 0.0)
	_update_freeze(cur, view_dt)


## The actor's sim-px position this frame (x lerped inside a room; the stair diagonal on a stairs leg).
static func stage_position_px(prev: ViewSnapshot.Actor, cur: ViewSnapshot.Actor, alpha: float) -> Vector2:
	if cur.leg_kind == "stairs":
		var u1 := float(cur.leg_pm) / 1000.0
		var u := u1
		if prev != null and prev.present and prev.leg_kind == "stairs" and prev.leg_from_x == cur.leg_from_x:
			u = lerpf(float(prev.leg_pm) / 1000.0, u1, alpha)
		return Vector2(lerpf(cur.leg_from_x, cur.leg_to_x, u), lerpf(cur.leg_from_y, cur.leg_to_y, u))
	var x := cur.x
	if prev != null and prev.present and prev.room == cur.room and prev.floor == cur.floor and prev.leg_kind != "stairs":
		x = lerpf(prev.x, cur.x, alpha)
	return Vector2(x, cur.y)


## Pure placement rules: the lane depth a state wants (z), the view-only x offset (m) and the cheat (degrees).
## `reach` = the rigged hotspot's reach_pos dict ({dx, z, step, step_h}) or {}; `station` = the station's house3d
## entry or {}; `hide_z` = the hiding spot's occupant_z (NAN = none).
static func placement_for(actor_id: String, cur: ViewSnapshot.Actor, reach: Dictionary, station: Dictionary, hide_z: float) -> Dictionary:
	var z := View3DConst.LANE_Z
	var dx := 0.0
	var cheat := View3DConst.CHEAT_IDLE
	var yaw := NAN
	if cur.moving or cur.leg_kind != "":
		cheat = View3DConst.CHEAT_WALK
	if actor_id == "hush":
		if cur.state == "RIGGING":
			dx = float(reach.get("dx", 0.0))
			z = maxf(float(reach.get("z", View3DConst.REACH_Z)), View3DConst.REACH_Z_MIN)
			cheat = minf(cheat, View3DConst.CHEAT_REACH_MAX)
		elif (cur.state == "DIVING" or cur.state == "HIDDEN" or cur.hidden_spot != "") and not is_nan(hide_z):
			z = hide_z
		elif cur.state == "FROZEN" or cur.frozen:
			cheat = View3DConst.CHEAT_PERFORM
	else:
		if not cur.moving and cur.activity != "" and not station.is_empty() and not cur.reacting:
			z = float(station.get("bellows_z", View3DConst.BELLOWS_STATION_Z))
			if station.has("yaw"):
				yaw = float(station["yaw"])
		if cur.oneshot == "face_to_face":
			cheat = View3DConst.CHEAT_FACE_TO_FACE
	return {"z": z, "dx": dx, "cheat": cheat, "yaw": yaw}


func _place(cur: ViewSnapshot.Actor, p2: Vector2, view_dt: float) -> void:
	var reach := _reach_for(cur) if actor == "hush" else {}
	var station := _station_for(cur) if actor == "bellows" else {}
	var hide_z := _hide_z_for(cur) if actor == "hush" else NAN
	var pl := CharacterView3D.placement_for(actor, cur, reach, station, hide_z)
	var want_z: float = pl["z"]
	_dx_to = pl["dx"]
	_cheat = pl["cheat"]
	_station_yaw = pl["yaw"]
	# reactions: travel arc + landing depth / pelvis
	_y_off = 0.0
	if actor == "bellows" and cur.reacting:
		want_z = _reaction_travel(cur, p2, want_z)
	elif actor == "bellows" and _rx_key != "":
		_rx_key = ""
		_landed = false
	if not _placed:
		_z = want_z
		_z_to = want_z
		_z_t = 1.0
		_dx = _dx_to
		_placed = true
	elif not is_equal_approx(want_z, _z_to):
		_z_from = _z
		_z_to = want_z
		_z_t = 0.0 if not (actor == "bellows" and cur.reacting) else 1.0
	if _z_t < 1.0:
		_z_t = minf(1.0, _z_t + view_dt / View3DConst.REACH_EASE_S)
		_z = lerpf(_z_from, _z_to, _z_t * _z_t * (3.0 - 2.0 * _z_t))
	else:
		_z = _z_to
	_dx = move_toward(_dx, _dx_to, view_dt / View3DConst.REACH_EASE_S * maxf(0.3, absf(_dx_to)))
	_x = p2.x / View3DConst.PX_PER_M + _dx
	_floor_y = -p2.y / View3DConst.PX_PER_M
	position = Vector3(_x, _floor_y + _y_off, _z)
	_facing = cur.facing if cur.facing != 0 else _facing


## The sneeze-style travel: z and the pelvis toward the landing, the y arc; returns the wanted z.
func _reaction_travel(cur: ViewSnapshot.Actor, p2: Vector2, base_z: float) -> float:
	var key := "%s|%s|%d" % [cur.react_prank, cur.react_archetype, cur.react_len]
	if key != _rx_key:
		_rx_key = key
		_rx_x0 = p2.x
		_rx_z0 = _z
		_landed = false
		_rx_land = _landing_for(cur.react_prank)
		_rx_arc = _arc_for(cur.react_archetype, cur.react_variant)
		_rx_x1 = float(_rx_land.get("x_px", p2.x))
	if _rx_land.is_empty():
		return _rx_z0
	var span := _rx_x1 - _rx_x0
	var u := 1.0 if absf(span) < 1.0 else clampf((p2.x - _rx_x0) / span, 0.0, 1.0)
	if u >= 0.999:
		_landed = true
	if _landed:
		u = 1.0
	var land_z := float(_rx_land.get("z", base_z))
	var land_y := float(_rx_land.get("y", 0.0))
	_y_off = sin(u * PI) * _rx_arc / View3DConst.PX_PER_M
	if land_y > 0.0:
		_y_off += u * (land_y - _pelvis_local_y())
	return lerpf(_rx_z0, land_z, u)


## The pelvis (seat socket) height above the root in the current pose; a seated default without a rig.
func _pelvis_local_y() -> float:
	if uses_rig and bool(_has.get("socket_global", false)) and rig.is_inside_tree():
		var t: Variant = rig.call("socket_global", "seat")
		if t is Transform3D:
			return (t as Transform3D).origin.y - _world_pos().y + _y_off
	return 0.35 if actor == "bellows" else 0.3


## {x_px, z, y, yaw, room, id} of the landing a prank's reaction ends at (pranks.json reaction.end + house.json
## landings x + house3d.json landings z / y); {} when none.
func _landing_for(prank: String) -> Dictionary:
	var pj: Variant = ViewKit.json("res://data/pranks.json")
	var pr: Variant = null
	if pj is Dictionary:
		var tbl: Variant = (pj as Dictionary).get("pranks", pj)
		if tbl is Dictionary:
			pr = (tbl as Dictionary).get(prank, null)
	if not (pr is Dictionary):
		return {}
	var rx: Variant = (pr as Dictionary).get("reaction", {})
	var end: Variant = (rx as Dictionary).get("end", null) if rx is Dictionary else null
	if not (end is Dictionary):
		return {}
	var room := str((end as Dictionary).get("room", ""))
	var lid := str((end as Dictionary).get("landing", ""))
	var out := {"room": room, "id": lid}
	var x_px := float((end as Dictionary).get("x", -1))
	if layout != null and lid != "" and layout.landings.get(room, null) is Dictionary:
		x_px = float((layout.landings[room] as Dictionary).get(lid, x_px))
	if x_px >= 0.0:
		out["x_px"] = x_px
	var l3: Variant = (house3d.get("landings", {}) as Dictionary).get(room, null) if house3d.get("landings", null) is Dictionary else null
	if l3 is Dictionary and (l3 as Dictionary).get(lid, null) is Dictionary:
		var d: Dictionary = (l3 as Dictionary)[lid]
		out["z"] = float(d.get("z", View3DConst.LANE_Z))
		out["y"] = float(d.get("y", 0.0))
		out["yaw"] = float(d.get("yaw", 0.0))
	return out


func _arc_for(archetype: String, v: String) -> float:
	var rj: Variant = ViewKit.json("res://data/reactions.json")
	if not (rj is Dictionary):
		return 0.0
	var arch: Variant = ((rj as Dictionary).get("archetypes", {}) as Dictionary).get("%s_%s" % [archetype, v], null)
	if arch is Dictionary and (arch as Dictionary).get("travel", null) is Dictionary:
		return float(((arch as Dictionary)["travel"] as Dictionary).get("arc_px", 0.0))
	return 0.0


## The rigged hotspot's reach_pos (House3D.reach_pos, else house3d.json, else {z −1.6}).
func _reach_for(cur: ViewSnapshot.Actor) -> Dictionary:
	if cur.state != "RIGGING" or cur.rig_prank == "":
		return {}
	var hs := _rig_point_of(cur.rig_prank)
	if hs == "":
		return {"z": View3DConst.REACH_Z}
	if set3d != null and set3d.has_method("reach_pos"):
		var r: Variant = set3d.call("reach_pos", hs)
		if r is Dictionary and not (r as Dictionary).is_empty():
			return r
	var h3: Variant = (house3d.get("hotspots", {}) as Dictionary).get(hs, null) if house3d.get("hotspots", null) is Dictionary else null
	if h3 is Dictionary and (h3 as Dictionary).get("reach_pos", null) is Dictionary:
		return (h3 as Dictionary)["reach_pos"]
	return {"z": View3DConst.REACH_Z}


func _rig_point_of(prank: String) -> String:
	var pr: Variant = (rig_actions.get("pranks", {}) as Dictionary).get(prank, null) if rig_actions.get("pranks", null) is Dictionary else null
	if pr is Dictionary and str((pr as Dictionary).get("hotspot", "")) != "":
		return str((pr as Dictionary)["hotspot"])
	if info != null:
		return str(info.prank(prank).get("rig_point", ""))
	return ""


## The house3d.json station entry of Bellows' current activity ({} when none).
func _station_for(cur: ViewSnapshot.Actor) -> Dictionary:
	if cur.activity == "" or info == null or info.world == null:
		return {}
	var ai := ViewSnapshot.activity_info(info.world, cur.activity)
	var st := str(ai.get("station", "")) if ai.get("station", null) != null else ""
	if st == "" and cur.detour_station != "":
		st = cur.detour_station
	if st == "":
		return {}
	var sd: Variant = (house3d.get("stations", {}) as Dictionary).get(st, null) if house3d.get("stations", null) is Dictionary else null
	return sd if sd is Dictionary else {"bellows_z": View3DConst.BELLOWS_STATION_Z}


func _hide_z_for(cur: ViewSnapshot.Actor) -> float:
	var spot := cur.hidden_spot
	if spot == "" and cur.state == "DIVING":
		spot = cur.watched_spot
	if spot == "":
		return NAN
	var hd: Variant = (house3d.get("hide", {}) as Dictionary).get(spot, null) if house3d.get("hide", null) is Dictionary else null
	if hd is Dictionary and (hd as Dictionary).has("occupant_z"):
		return float((hd as Dictionary)["occupant_z"])
	return -2.1


func _update_ctx(cur: ViewSnapshot.Actor, vf: float) -> void:
	var changed := cur.state != _state or cur.reacting != _reacting
	var started_moving := cur.moving and not _moving
	if changed or started_moving:
		ctx.flavour = ""
		ctx.ov_flavour = ""
		ctx.fidget_i = -1
		_idle_s = 0.0
	if ctx.mg != "" and (cur.state != _mg_state or cur.reacting):
		ctx.mg = ""
	if ctx.cue != "" and cur.reacting:
		ctx.cue = ""
	# rigging: glances and the stepped-rig bookkeeping
	if actor == "hush":
		_rigging_extras(cur, vf)
	_state = cur.state
	_reacting = cur.reacting
	_moving = cur.moving
	if _flavour_pending != "":
		ctx.flavour = _flavour_pending
		ctx.flavour_f = 0.0
		_flavour_state = cur.state
		_flavour_pending = ""
	if _ov_flavour_pending != "":
		ctx.ov_flavour = _ov_flavour_pending
		ctx.ov_flavour_f = 0.0
		_ov_flavour_pending = ""
	if not _mg_pending.is_empty():
		ctx.mg = str(_mg_pending.get("id", ""))
		ctx.mg_f = 0.0
		ctx.mg_emote = str(_mg_pending.get("emote", ""))
		_mg_len = float(_mg_pending.get("len", 0))
		if _mg_len <= 0.0:
			_mg_len = MG_FALLBACK_F
		_mg_state = cur.state
		_mg_pending = {}
	if ctx.flavour != "":
		ctx.flavour_f += vf
		var fl := _clip_len(ClipMap._k("flavour:", ctx.flavour))
		if ctx.flavour_f >= fl:
			var nxt := str(ClipRules.row("flavour:" + ctx.flavour, actor).get("then_key", ""))
			if nxt.begins_with("flavour:") and cur.state == _flavour_state:
				ctx.flavour = nxt.substr(8)
				ctx.flavour_f = 0.0
			else:
				ctx.flavour = ""
	if ctx.ov_flavour != "":
		ctx.ov_flavour_f += vf
		if ctx.ov_flavour_f >= _clip_len(ClipMap._k("flavour:", ctx.ov_flavour)):
			ctx.ov_flavour = ""
	if ctx.mg != "":
		ctx.mg_f += vf
		if ctx.mg_f >= _mg_len:
			ctx.mg = ""
	if ctx.cue != "":
		ctx.cue_f += vf
		if ctx.cue_f >= _cue_len:
			ctx.cue = ""
	var idle := cur.state == "IDLE" and not cur.moving and ctx.flavour == "" and cur.oneshot == "" and not cur.reacting
	if idle and map.has("idle_fidgets"):
		if ctx.fidget_i < 0:
			_idle_s += vf / 60.0
			if _idle_s >= FIDGET_AFTER_S:
				var n := ClipMap.clips_of(map["idle_fidgets"]).size()
				if n > 0:
					ctx.fidget_i = (_fidget_n * 7 + 3) % n
					ctx.fidget_f = 0.0
					_fidget_n += 1
				_idle_s = 0.0
		else:
			ctx.fidget_f += vf
			var fid := ClipMap.clip_of(map["idle_fidgets"], ctx.fidget_i)
			if ctx.fidget_f >= float(maxi(1, ClipMap.clip_length3d(fid))):
				ctx.fidget_i = -1
	elif not idle:
		ctx.fidget_i = -1
		_idle_s = 0.0
	if cur.facing != _snap_facing and _snap_facing != 0 and not cur.moving and map.has("turn"):
		ctx.turn_f = 0.0
	elif ctx.turn_f >= 0.0:
		ctx.turn_f += vf
		if cur.moving or ctx.turn_f >= _clip_len("turn"):
			ctx.turn_f = -1.0
	_snap_facing = cur.facing


## Glances (rig_actions `glances` ‰ → a `head` overlay once per mark) and the stepped-rig state for the step-down.
func _rigging_extras(cur: ViewSnapshot.Actor, vf: float) -> void:
	if cur.state == "RIGGING" and cur.rig_prank != "":
		if cur.rig_prank != _rig_prank:
			_rig_prank = cur.rig_prank
			_glance_done.clear()
		var pr: Variant = (rig_actions.get("pranks", {}) as Dictionary).get(cur.rig_prank, null) if rig_actions.get("pranks", null) is Dictionary else null
		if pr is Dictionary:
			var step: Variant = (pr as Dictionary).get("step", null)
			_rig_step_used = step is String and str(step) != ""
			var gl: Variant = (pr as Dictionary).get("glances", [])
			if gl is Array:
				for g in gl:
					var mark := int(g)
					if cur.rig_pm >= mark and not _glance_done.has(mark):
						_glance_done[mark] = true
						_glance_left = float(maxi(1, ClipMap.clip_length3d(GLANCE_CLIP)))
	elif _state == "RIGGING" and cur.state != "RIGGING":
		# released: a stepped rig released mid-step hops down before any locomotion
		if _rig_step_used and cur.rig_pm > 0 and cur.rig_pm < 1000:
			_step_down_f = 0.0
		_rig_prank = ""
		_rig_step_used = false
	if _glance_left > 0.0:
		_glance_left -= vf
	if _step_down_f >= 0.0:
		_step_down_f += vf
		var sl := float(maxi(1, ClipMap.clip_length3d(STEP_DOWN_CLIP)))
		if _step_down_f >= sl or ClipMap.clip_length3d(STEP_DOWN_CLIP) <= 0 and _step_down_f >= 8.0:
			_step_down_f = -1.0


## True while the step-down plays (tests).
func stepping_down() -> bool:
	return _step_down_f >= 0.0


func _step_down_rule(_cur: ViewSnapshot.Actor) -> void:
	if _step_down_f < 0.0 or actor != "hush":
		return
	var e: Variant = ClipMap.entry(map, "flavour:step_down", skin)
	var clip := ClipMap.clip_of(e) if e != null else STEP_DOWN_CLIP
	if ClipMap.clip_exists3d(clip):
		_pick.clip = clip
		_pick.key = "flavour:step_down"
		_pick.external = true
		_pick.frame = _step_down_f
		_pick.loop = false
		_pick.stride = false
	elif _pick.wanted == "":
		_pick.wanted = clip
		_pick.wanted_key = "flavour:step_down"


func _clip_len(key: String) -> float:
	var e: Variant = ClipMap.entry(map, key, skin)
	var c := ClipMap.clip_of(e, 0)
	return float(maxi(1, ClipMap.clip_length3d(c)))


func _note_fallbacks() -> void:
	if _pick.wanted != _last_wanted:
		_last_wanted = _pick.wanted
		if _pick.wanted != "":
			_count(_pick.wanted, _pick.wanted_key)
	var ow := _pick.ov_wanted
	if ow != _last_ov_wanted:
		_last_ov_wanted = ow
		if ow != "":
			_count(ow, _pick.ov_wanted_key)


func _count(clip: String, key: String) -> void:
	clip_fallbacks += 1
	fallback_by_clip[clip] = int(fallback_by_clip.get(clip, 0)) + 1
	if not _logged.has(clip):
		_logged[clip] = true
		print_verbose("[view3d] clip fallback: %s wants '%s' (%s)" % [actor, clip, key])


# --- driving the rig --------------------------------------------------------------------------------

func _drive_rig(cur: ViewSnapshot.Actor, hidden: bool) -> void:
	rig.visible = not hidden
	_play_base(cur)
	_play_overlay()
	var facing := 1 if (actor == "hush" and cur.entering) else cur.facing
	var cheat := _cheat
	if not is_nan(_station_yaw):
		facing = 1 if _station_yaw > 0.0 else -1
		cheat = 90.0 - absf(_station_yaw)
	if _rx_key != "" and not _rx_land.is_empty() and _rx_land.has("yaw") and _landed:
		cheat = View3DConst.CHEAT_PERFORM
	if actor == "hush" and cur.state == "RIGGING":
		var st := CharacterView3D.rig_stage(_clip, facing, cheat)
		facing = st.x
		cheat = st.y
	if bool(_has.get("set_facing", false)):
		rig.call("set_facing", facing, not (actor == "hush" and cur.entering))
	if bool(_has.get("set_cheat", false)):
		rig.call("set_cheat", cheat, View3DConst.CHEAT_EASE_S)
	if bool(_has.get("look_at_point", false)):
		var lt := look_target
		var lw := look_weight
		if actor == "hush" and cur.state == "RIGGING" and lt == Vector3.INF:
			# R5d: while reaching the body cheats ≤ 10°, the head gives the face to the camera
			lt = _world_pos() + Vector3(0.0, height_m() - 0.2, 4.0)
			lw = 0.6
		rig.call("look_at_point", lt if lt != Vector3.INF else _world_pos() + Vector3(0, 1.4, 3.0), lw if lt != Vector3.INF else 0.0)
	if bool(_has.get("set_stage_light", false)):
		rig.call("set_stage_light", stage_level, 0.0)
	if actor == "bellows":
		_apply_meter(cur)
	else:
		_apply_hush_looks(cur)
	if bool(_has.get("advance", false)):
		rig.call("advance", _view_dt)


func _play_base(cur: ViewSnapshot.Actor) -> void:
	if _pick.clip == "":
		if _clip != STATIC_CLIP:
			_clip = STATIC_CLIP
			_clip_sig = STATIC_CLIP
			_frame = 0.0
		return
	var rx := _pick.key == "reaction"
	var changed := _pick.clip != _clip_sig or (rx and (_pick.tier != _sig_tier or _pick.suppressed != _sig_supp or not _sig_rx))
	if changed:
		_clip_sig = _pick.clip
		_sig_tier = _pick.tier
		_sig_supp = _pick.suppressed
		_sig_rx = rx
		_clip = _pick.clip
		var opts := {"loop": _pick.loop}
		if _pick.stride:
			opts["speed"] = maxf(0.05, cur.speed_px_s / View3DConst.PX_PER_M)
		else:
			opts["speed"] = _pick.speed
		if _pick.key == "reaction" or _pick.key == "reaction_fallback" or _pick.key == "reaction:last_beat":
			opts["blend_in"] = 0
			opts["tier"] = _pick.tier
			opts["suppressed"] = _pick.suppressed
			if _pick.last_beat != "":
				opts["last_beat"] = _pick.last_beat
			if _pick.key == "reaction_fallback":
				opts["hold"] = true
		rig.call("play", _clip, opts)
	if _pick.external and bool(_has.get("set_external_frame", false)):
		rig.call("set_external_frame", _pick.frame)
		_frame = _pick.frame
	else:
		if bool(_has.get("release_external", false)) and changed:
			rig.call("release_external")
		if _pick.stride and cur.moving and bool(_has.get("set_speed", false)):
			rig.call("set_speed", maxf(0.05, cur.speed_px_s / View3DConst.PX_PER_M))
		_frame = float(rig.call("current_frame")) if bool(_has.get("current_frame", false)) else 0.0


func _play_overlay() -> void:
	var want := _pick.ov_clip
	var mask := ""
	if want == "" and _glance_left > 0.0 and ClipMap.clip_exists3d(GLANCE_CLIP):
		want = GLANCE_CLIP
		mask = "head"
	if want != "" and want != _ov_clip:
		if mask == "":
			mask = ClipRules.mask_of(_pick.ov_key, actor)
		if bool(_has.get("play_overlay", false)):
			rig.call("play_overlay", want, mask if mask != "" else "upper", 6)
		_ov_clip = want
	elif want == "" and _ov_clip != "":
		if bool(_has.get("stop_overlay", false)):
			rig.call("stop_overlay", 6)
		_ov_clip = ""
	var face := str(EMOTE_FACE.get(_pick.ov_face, "")) if _pick.ov_face != "" else ""
	if face != _ov_face:
		_ov_face = face
		if face != "" and bool(_has.get("set_face", false)):
			rig.call("set_face", face)


## Tint tier, specs, residue looks and body slots (clip-owned until release, then the residue's).
func _apply_meter(cur: ViewSnapshot.Actor) -> void:
	var tier := clampi(cur.tier, 0, 3)
	if tier != _tier:
		_tier = tier
		if bool(_has.get("set_tint_tier", false)):
			rig.call("set_tint_tier", tier)
	var specs := "on" if cur.specs_on or cur.tier >= 3 else "hidden"
	if specs != _specs and bool(_has.get("set_prop", false)):
		_specs = specs
		rig.call("set_prop", "specs", specs)
	if cur.residues.has("COSTUME") and _costume == "" and info != null:
		_costume = info.costume_look(cur.react_prank if cur.react_prank != "" else _last_prank)
	elif not cur.residues.has("COSTUME"):
		_costume = ""
	var key := "%s|%s|%s|%s" % [",".join(cur.residues), ",".join(combos_formed), "b" if cur.blinded else "", _costume]
	if key == _looks_key:
		return
	_looks_key = key
	var want := _known_looks(CharacterView3D.rig_looks(cur.residues, combos_formed, cur.blinded, _costume))
	if bool(_has.get("set_look", false)):
		for r in _looks:
			if not want.has(r):
				rig.call("set_look", r, false)
		for r2 in want:
			if not _looks.has(r2):
				rig.call("set_look", r2, true)
	_looks = want
	# body slots owned by the residue from now on (e.g. FRAZZLED + blind → BLINDED → bouffant: flipped)
	var slots := _known_slots(CharacterView3D.residue_slots(cur.residues, cur.blinded))
	if bool(_has.get("set_body_slot", false)):
		for s in slots:
			if str(_slots.get(s, "")) != str(slots[s]):
				rig.call("set_body_slot", s, slots[s], &"residue")
		for s0 in _slots:
			if not slots.has(s0):
				rig.call("set_body_slot", s0, "", &"residue")
	_slots = slots


## The body slots / variants of `want` the rig's descriptor knows.
func _known_slots(want: Dictionary) -> Dictionary:
	var d: Variant = rig.get("def") if rig != null else null
	var known: Variant = (d as Object).get("slots") if d is Object else null
	if not (known is Dictionary):
		return want
	var out := {}
	for s in want:
		if (known as Dictionary).has(s) and ((known as Dictionary)[s] as Dictionary).has(want[s]):
			out[s] = want[s]
	return out


## Hush's TOMATO look: on from the doorstep splat until 4 s after control returns.
func _apply_hush_looks(cur: ViewSnapshot.Actor) -> void:
	if cur.oneshot == "caught:doorstep" and cur.oneshot_t >= CaughtStager.DOORSTEP_KNOCK_F + 6:
		_tomato_s = TOMATO_S
	elif _tomato_s > 0.0:
		_tomato_s -= _view_dt
	var on := _tomato_s > 0.0
	if on != _looks.has("TOMATO") and bool(_has.get("set_look", false)):
		rig.call("set_look", "TOMATO", on)
		if on:
			_looks.append("TOMATO")
		else:
			_looks.remove_at(_looks.find("TOMATO"))


## The looks of `list` the rig's descriptor knows (an unknown look is dropped, never an error).
func _known_looks(list: PackedStringArray) -> PackedStringArray:
	var d: Variant = rig.get("def") if rig != null else null
	var known: Variant = (d as Object).get("looks") if d is Object else null
	if not (known is Dictionary):
		return list
	var out := PackedStringArray()
	for l in list:
		if (known as Dictionary).has(l):
			out.append(l)
	return out


## The rig looks for a set of residues: each residue kind, `COSTUME:<look>`, `BLINDED` when blinded, and a
## formed combo's `COMBO:<id>` when all its residues are present (residues.json combos).
## The sidecar "stage" block of a 3D clip ({} when none; cached).
static func clip_stage(clip_id: String) -> Dictionary:
	if clip_id == "" or clip_id == STATIC_CLIP:
		return {}
	if _stage_cache.has(clip_id):
		return _stage_cache[clip_id]
	var out := {}
	var path := ClipMap.sidecar_path(clip_id)
	if path != "" and FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and (d as Dictionary).get("stage") is Dictionary:
			out = (d as Dictionary)["stage"]
	_stage_cache[clip_id] = out
	return out


## While a rig clip plays: its authored facing (the prop's side) and a cheat ≤ CHEAT_REACH_MAX (r3d-anim's
## "stage" block); otherwise (`facing`, `cheat`) unchanged. Returns Vector2i(facing, cheat).
static func rig_stage(clip_id: String, facing: int, cheat: float) -> Vector2i:
	var st := CharacterView3D.clip_stage(clip_id)
	if st.is_empty():
		return Vector2i(facing, roundi(cheat))
	var f := facing
	if st.has("facing"):
		f = 1 if float(st["facing"]) >= 0.0 else -1
	var c := minf(cheat, View3DConst.CHEAT_REACH_MAX)
	if st.has("cheat_deg"):
		c = minf(float(st["cheat_deg"]), View3DConst.CHEAT_REACH_MAX)
	return Vector2i(f, roundi(c))


static func rig_looks(residues: PackedStringArray, formed: PackedStringArray, blinded: bool, costume: String) -> PackedStringArray:
	var out := PackedStringArray()
	for r in residues:
		out.append(r)
		if r == "COSTUME" and costume != "":
			out.append("COSTUME:" + costume)
		if r == "FRAZZLED" and blinded:
			out.append("BLINDED")
	if not formed.is_empty():
		var rj: Variant = ViewKit.json("res://data/residues.json")
		var combos: Dictionary = (rj as Dictionary).get("combos", {}) if rj is Dictionary else {}
		for id in formed:
			var c: Variant = combos.get(id, null)
			var of: Array = (c as Dictionary).get("of", []) if c is Dictionary else []
			var all := not of.is_empty()
			for k in of:
				if not residues.has(str(k)):
					all = false
			if all:
				out.append("COMBO:" + id)
	return out


## Body slots a residue set owns (index §7.2): BLINDED (FRAZZLED + blind) → bouffant flipped; FRAZZLED → frazzled;
## SOAKED → wet; FLOURED → floured. `{slot: variant}`.
static func residue_slots(residues: PackedStringArray, blinded: bool) -> Dictionary:
	var out := {}
	if residues.has("FRAZZLED"):
		out["bouffant"] = "flipped" if blinded else "frazzled"
	elif residues.has("SOAKED"):
		out["bouffant"] = "wet"
	elif residues.has("FLOURY") or residues.has("FLOURED"):
		out["bouffant"] = "floured"
	return out


func _drive_stand_in(cur: ViewSnapshot.Actor, hidden: bool) -> void:
	stand_in.visible = not hidden
	_clip = _pick.clip
	_frame = _pick.frame
	var yaw_deg := (90.0 - _cheat) * float(_facing)
	if not is_nan(_station_yaw):
		yaw_deg = _station_yaw
	stand_in.rotation.y = deg_to_rad(yaw_deg)
	var bob := 0.0
	if cur.moving:
		bob = absf(sin(_t * 8.0)) * 0.04
	stand_in.position.y = bob
	var sc := Vector3.ONE
	if cur.state == "RIGGING":
		sc = Vector3(1.04, 0.96 + 0.03 * sin(_t * 30.0), 1.04)
	elif cur.reacting:
		sc = Vector3(0.9, 1.12, 0.9) if cur.react_t % 30 < 15 else Vector3(1.08, 0.92, 1.08)
	stand_in.scale = sc
	for c in stand_in.get_children():
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).material_override as ShaderMaterial
			if m != null:
				m.set_shader_parameter("stage_light", stage_level)
				m.set_shader_parameter("stone", 1.0 if _stone else 0.0)


# --- the marble freeze ----------------------------------------------------------------------------

func _update_freeze(cur: ViewSnapshot.Actor, dt: float) -> void:
	if actor != "hush":
		return
	var want := cur.state == "FROZEN" or cur.frozen
	if want != _stone:
		_stone = want
		if uses_rig and bool(_has.get("set_stone", false)):
			rig.call("set_stone", want, 0.1 if want else SHIVER_S)
		if want:
			_plinth_t = 0.0
			_ensure_plinth()
		else:
			_shiver_t = SHIVER_S
			if uses_rig and bool(_has.get("kick_jiggle", false)):
				rig.call("kick_jiggle", 0.6)
	if plinth != null:
		if _stone:
			_plinth_t = minf(PLINTH_POP_S, _plinth_t + dt)
			var k := _plinth_t / PLINTH_POP_S
			plinth.visible = true
			plinth.scale = Vector3(1.0, maxf(0.01, k * (1.0 + 0.15 * sin(k * PI))), 1.0)
		else:
			plinth.visible = false
	if _shiver_t > 0.0:
		_shiver_t = maxf(0.0, _shiver_t - dt)
		var s := sin(_shiver_t * 120.0) * 0.012 * (_shiver_t / SHIVER_S)
		if uses_rig:
			rig.position.x = s
		elif stand_in != null:
			stand_in.position.x = s
	elif uses_rig and rig.position.x != 0.0:
		rig.position.x = 0.0


func _ensure_plinth() -> void:
	if plinth != null:
		return
	if ResourceLoader.exists(PLINTH_SCENE):
		var ps: Variant = load(PLINTH_SCENE)
		if ps is PackedScene:
			plinth = (ps as PackedScene).instantiate() as Node3D
	if plinth == null:
		var mi := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.25
		cy.bottom_radius = 0.27
		cy.height = 0.12
		mi.mesh = cy
		mi.position.y = 0.06
		var m := ShaderMaterial.new()
		m.shader = load(View3DConst.SH_SET)
		m.set_shader_parameter("albedo_color", View3DConst.STONE)
		mi.material_override = m
		MaterialWarm3D.register(m, &"set")
		var holder := Node3D.new()
		holder.add_child(mi)
		plinth = holder
	plinth.name = "Plinth"
	add_child(plinth)
	plinth.visible = false


# --- driverless (Busted Cam, Gag Reel, curtain call) ------------------------------------------------

## Pose the actor from a recorded / scripted frame: world position (sim px + the lane), facing, clip + frame
## (frame-locked), visibility, looks and tier.
func show_explicit(pos_px: Vector2, facing: int, clip: String, frame: float, shown: bool,
		looks_on: PackedStringArray = PackedStringArray(), tier: int = -1, ov_clip: String = "", ov_frame: float = 0.0) -> void:
	visible = true
	position = Vector3(pos_px.x / View3DConst.PX_PER_M, -pos_px.y / View3DConst.PX_PER_M, _z)
	_facing = facing
	if uses_rig and rig != null:
		rig.visible = shown
		if clip != "" and clip != _clip and ClipMap.clip_exists3d(clip):
			_clip = clip
			_clip_sig = clip
			rig.call("play", clip, {"blend_in": 0, "start_frame": frame})
		if bool(_has.get("set_external_frame", false)) and _clip != STATIC_CLIP and _clip != "":
			rig.call("set_external_frame", frame)
		_frame = frame
		if ov_clip != _ov_clip:
			if ov_clip != "" and ClipMap.clip_exists3d(ov_clip) and bool(_has.get("play_overlay", false)):
				rig.call("play_overlay", ov_clip, "upper", 0)
			elif bool(_has.get("stop_overlay", false)):
				rig.call("stop_overlay", 4)
			_ov_clip = ov_clip
		if bool(_has.get("set_facing", false)):
			rig.call("set_facing", facing, false)
		if tier >= 0 and tier != _tier and bool(_has.get("set_tint_tier", false)):
			_tier = tier
			rig.call("set_tint_tier", tier)
		if looks_on != _looks and bool(_has.get("set_look", false)):
			for r in _looks:
				if not looks_on.has(r):
					rig.call("set_look", r, false)
			for r2 in looks_on:
				if not _looks.has(r2):
					rig.call("set_look", r2, true)
			_looks = looks_on.duplicate()
			_looks_key = "#explicit"
		if bool(_has.get("advance", false)):
			rig.call("advance", 0.0)
	elif stand_in != null:
		stand_in.visible = shown
		_clip = clip
		_frame = frame
		stand_in.rotation.y = deg_to_rad((90.0 - _cheat) * float(facing))
	if blob != null:
		blob.visible = shown


func pose_replay(pos_px: Vector2, facing: int, clip: String, frame: float, state: String, _view_dt_: float) -> void:
	show_explicit(pos_px, facing, clip, frame, state != "HIDDEN")


## Pre-roll: advance the clip by `dt` of real time without a new snapshot (sound events muted).
func preroll(dt: float) -> void:
	if not uses_rig or rig == null:
		return
	var was := mute_sounds
	mute_sounds = true
	if _pick.external and bool(_has.get("set_external_frame", false)):
		_pick.frame += dt * 60.0
		rig.call("set_external_frame", _pick.frame)
		_frame = _pick.frame
	if bool(_has.get("advance", false)):
		rig.call("advance", dt)
	mute_sounds = was


func _setting(key: String, def: Variant) -> Variant:
	return ViewKit.setting(key, def)
