## CharacterView — one actor on stage (TECH §5.4, s2-view brief §4.1). Reads a
## ViewSnapshot.Actor every frame, interpolates its position between ticks with
## `SimDriver.alpha()` (stairs on the stair diagonal from the sim's leg), and maps its state to
## clips through ClipMap (`data/anim/<rig>/map.json` over the default map, the map-key schema).
##
## * **Real rigs everywhere.** When the rig loads, a RigPlayer (`res://view/rig/rig_player.gd`,
##   soft) draws the actor — never a puppet. A clip the map wants but nobody authored yet falls
##   through to the next rule (ClipMap), and when nothing at all is authored the rig holds its
##   stand pose; every such fallback is counted (`counts()` → `WorldView.fallback_counts()`) and
##   logged once. Only a rig that fails to load uses the FallbackPuppet (counted as a puppet).
## * **Frame locks.** Reactions (`react_t + alpha`, tier / suppressed remap, the `_ko` knock-on
##   variant, the sim's `last_beat` after the settle) and base one-shots (`oneshot_t + alpha`) are
##   driven with `set_external_frame`; the JuiceClock owns hit-stop (`self_hitstop = false`).
## * **Overlays** (`mg:<id>` micro-gags, `cue:<id>` director cues, overlay one-shots and Hush's
##   shrug / pickup) play on the rig's masked overlay layer over whatever the base is doing and
##   stop on any state change or reaction. A missing micro-gag clip flashes the emote's face
##   preset instead (+ notes for sing / hum).
## * **View flavours** (Hush): snicker → glance after `rigged`, shrug on `cmd_rejected`, pickup
##   on `pick`, idle fidgets after 3 s idle, the standing turn — all stop within one frame of any
##   Hush state change (the flavour rule: a tap never waits for them).
## * **His body is the meter** (Bellows): tint tier + sideburns per tier, specs on the nose when
##   `specs_on` or Livid, the bouffant flipped while blinded, residue looks (`COSTUME:<look>`),
##   combos only after the sim's `combo` event (where a Night forbids combos both residues stay
##   on together).
## * **Driverless** (`show_explicit`): the Busted Cam / Gag Reel / curtain call pose it from a
##   recorded Moment; it re-emits the clips' sound events on `sound_event`.
class_name CharacterView
extends Node2D

## Clip events (sfx, voice, laugh, fx, cam, shake, hitstop, prop, decor, …) from the RigPlayer,
## with `"actor"` and `"pos"` (world) added. One reused Dictionary: do not keep it.
signal clip_event(ev: Dictionary)
## The clips' sound events only (sfx / voice / laugh) — also while driven by `show_explicit`,
## so a re-staging (Gag Reel) can play them at −6 dB. Not emitted while `mute_sounds`.
signal sound_event(ev: Dictionary)

const RIG_PLAYER := "res://view/rig/rig_player.gd"
const HEIGHTS := {"hush": 340.0, "bellows": 380.0}
const TURN_FRAMES := 6.0
## Puppet-only stride (the rig derives its stride from the clip's `stride_px`).
const PUPPET_STRIDES := {"hush": 58.0, "bellows": 46.0}
const FIDGET_AFTER_S := 3.0
const MG_FALLBACK_F := 90.0
## Micro-gag emote → Bellows face preset (the fallback when `mg_<id>` is not authored).
const EMOTE_FACE := {"sing": "sing_mid", "hum": "hum", "smug": "smug", "laugh": "blissful", "tut": "disdain",
	"sniff": "sniff", "yum": "blissful", "yawn": "asleep"}
## Temper tier → sideburn texture (art-bellows request: flat, bristle, bristle, puffed).
const SIDEBURN_BY_TIER: PackedStringArray = ["flat", "bristle", "bristle", "puffed"]
const STATIC_CLIP := "#static"
const TOMATO_S := 4.0

var actor: String = "hush"
var rig_id: String = ""
## Settings `hush_skin` ("" | "pip"): Hush's rig skin and both maps' `skin:<skin>` blocks.
var skin: String = ""
var info: ContentInfo = null
var layout: HouseLayout = null
## The FX layer (micro-gag fallback notes); set by WorldView.
var fx: FxLayer = null
var map: Dictionary = {}
## True when a RigPlayer draws this actor.
var uses_rig: bool = false
var rig: Node2D = null
var puppet: FallbackPuppet = null
## Where the actor looks (world; Vector2.INF = no gaze) and how strongly (0–1). Set by
## WorldView every frame (§4.1.5).
var look_target: Vector2 = Vector2.INF
var look_weight: float = 0.0
## Driven from outside (Busted Cam / re-staging): `apply()` does nothing.
var replay: bool = false
## Drop the clips' sound events (pre-roll, seeks).
var mute_sounds: bool = false
## View-side ClipMap flags (flavours, fidgets, turns, micro-gags, cues).
var ctx: ClipMap.Ctx = ClipMap.Ctx.new()
## Combos the sim has formed this Night (`combo` events).
var combos_formed: PackedStringArray = PackedStringArray()

## Fallback counters (WorldView.fallback_counts()).
var clip_fallbacks: int = 0
var puppets: int = 0
var fallback_by_clip: Dictionary = {}

static var _logged: Dictionary = {}

var _pick := ClipMap.Pick.new()
var _clip := ""
var _clip_sig := ""
var _sig_tier := 1
var _sig_supp := false
var _sig_rx := false
var _frame := 0.0
var _ov_clip := ""
var _ov_face := ""
var _flip := 1.0
var _walk_phase := 0.0
var _t := 0.0
var _last_x := 0.0
var _view_dt := 0.0
var _rx_info: Dictionary = {}
var _rx_key := ""
var _ev: Dictionary = {}
var _has: Dictionary = {}
# Meter state last applied to the rig.
var _tier := -1
var _specs := ""
var _looks := PackedStringArray()
var _looks_key := ""
var _costume := ""
var _sideburn := ""
var _bouffant := ""
# Flavour / fidget / turn / overlay clocks.
var _state := ""
var _reacting := false
var _moving := false
var _facing := 0
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
var _last_prank := ""
var _static_pose := PackedFloat32Array()
var _tomato_s := 0.0
var _prep_key := ""
var _prep := ""
var _prep_step := -1


func _init() -> void:
	name = "CharacterView"


## Build the drawing for `actor_id` ("hush", "bellows", …). `rig_id_` defaults to the actor.
## `force_fallback` skips the rig system (tests, `--puppets`).
func setup(actor_id: String, rig_id_: String = "", force_fallback: bool = false) -> void:
	actor = actor_id
	rig_id = rig_id_ if rig_id_ != "" else actor_id
	name = "Char_" + actor
	skin = ViewKit.s(ViewKit.setting("hush_skin", ""))
	ctx.rig = actor
	ctx.skin = skin
	ctx.activity_clip_fn = _activity_clip
	map = ClipMap.load_map(rig_id)
	if not force_fallback:
		_try_rig()
	if not uses_rig:
		puppet = FallbackPuppet.new()
		puppet.kind = actor
		add_child(puppet)
		puppets = 1


func _try_rig() -> void:
	var s := ViewKit.soft_script(RIG_PLAYER)
	if s == null:
		return
	var use_id := rig_id
	if not FileAccess.file_exists("res://data/rigs/%s/rig.json" % use_id):
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
	rig.call("setup", use_id, skin if actor == "hush" else "")
	var loaded := rig.get("rig") != null and rig.get("poses") != null and rig.get("atlas") != null
	if not loaded:
		push_warning("CharacterView: rig '%s' did not load; using the stand-in puppet" % use_id)
		rig.queue_free()
		rig = null
		map = ClipMap.load_map(rig_id)
		return
	for m in ["set_external_frame", "set_speed", "set_facing", "set_tint_tier", "set_prop_state", "set_residue",
			"set_face", "look_toward", "stop_layer", "set_static_pose", "set_part_texture", "socket_global_transform",
			"layer_clip", "layer_frame", "current_frame", "reset_layers"]:
		_has[m] = rig.has_method(m)
	rig.set("self_hitstop", false)
	# Combos appear only when the sim forms one (`combo` event): L4 forbids them in N01 / N02.
	if "auto_combos" in rig:
		rig.set("auto_combos", false)
	if rig.has_signal("clip_event"):
		rig.connect("clip_event", _on_rig_event)
	_static_pose = _stand_pose(use_id)
	uses_rig = true


## The rig's stand pose (poses.json `<x>_stand`, else the first pose) for the no-clip fallback.
func _stand_pose(use_id: String) -> PackedFloat32Array:
	var lib: Variant = rig.get("poses")
	if not (lib is Object) or not (lib as Object).has_method("pose"):
		return PackedFloat32Array()
	var nv: Variant = (lib as Object).get("names")
	var names: PackedStringArray = nv if nv is PackedStringArray else PackedStringArray()
	var want := ViewKit.s(map.get("stand_pose", ""))
	if want == "":
		for nm in names:
			if nm.ends_with("_stand"):
				want = nm
				break
	if want == "" and not names.is_empty():
		want = names[0]
	if want == "":
		return PackedFloat32Array()
	var p: Variant = (lib as Object).call("pose", want)
	return p if p is PackedFloat32Array else PackedFloat32Array()


func _activity_clip(id: String) -> String:
	if info == null or info.world == null:
		return ""
	var ai := ViewSnapshot.activity_info(info.world, id)
	return ViewKit.s(ai.get("clip", "")) if ai.get("clip", null) != null else ""


func _on_rig_event(ev: Dictionary) -> void:
	var t := ViewKit.s(ev.get("type", ""))
	var sound := t == "sfx" or t == "voice" or t == "laugh"
	if sound and mute_sounds:
		return
	_ev.clear()
	_ev.merge(ev, true)
	_ev["actor"] = actor
	_ev["pos"] = global_position
	clip_event.emit(_ev)
	if sound:
		sound_event.emit(_ev)


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


## Global transform of a rig socket ("part:socket"); the node's transform without a rig.
func socket_transform(socket_name: String) -> Transform2D:
	if uses_rig and bool(_has.get("socket_global_transform", false)):
		return rig.call("socket_global_transform", socket_name)
	return global_transform


func current_clip() -> String:
	return _clip


## The drawn facing (±1).
func get_facing() -> int:
	return 1 if _flip >= 0.0 else -1


func current_frame() -> float:
	return _frame


## The overlay clip playing ("" none) and its frame.
func overlay_clip() -> String:
	return _ov_clip


func overlay_frame() -> float:
	if uses_rig and bool(_has.get("layer_frame", false)) and _ov_clip != "":
		return float(rig.call("layer_frame", "overlay"))
	return 0.0


## The last ClipMap pick (read-only; tests and staging).
func pick() -> ClipMap.Pick:
	return _pick


## The face preset showing as a micro-gag fallback ("" none).
func fallback_face() -> String:
	return _ov_face


## Rig looks currently switched on (residues, costume, combos, the blind sub-look).
func looks() -> PackedStringArray:
	return _looks


## {clip_fallbacks, puppets, by_clip}.
func counts() -> Dictionary:
	return {"clip_fallbacks": clip_fallbacks, "puppets": puppets, "by_clip": fallback_by_clip.duplicate()}


## Forget the fallback counters (retry).
func reset_counts() -> void:
	clip_fallbacks = 0
	fallback_by_clip.clear()
	_last_wanted = ""
	_last_ov_wanted = ""


## Retry: drop flavours, overlays, combos and the meter cache.
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
	_looks_key = "#"
	if uses_rig and bool(_has.get("reset_layers", false)):
		rig.call("reset_layers")


# --- sim events (forwarded by WorldView) ----------------------------------------------------

## A sim event that concerns this actor's view flavours (WorldView forwards every tick's events).
func on_event(ev: Dictionary) -> void:
	var e := ViewKit.s(ev.get("e", ""))
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
				var id := ViewKit.s(ev.get("id", ""))
				if id != "" and not combos_formed.has(id):
					combos_formed.append(id)
			"prank_fire":
				_last_prank = ViewKit.s(ev.get("prank", ""))


## Stage a director cue's overlay clip (`cue:<id>`) for `len_f` frames (≤ 0: the clip's length).
func play_cue(id: String, len_f: float = 0.0) -> void:
	ctx.cue = id
	ctx.cue_f = 0.0
	var clip := ClipMap.clip_of(ClipMap.entry(map, "cue:" + id, skin))
	_cue_len = len_f if len_f > 0.0 else float(maxi(1, ClipMap.clip_length(clip)))


# --- per frame -------------------------------------------------------------------------------

## Update from the snapshot actors (`prev` → `cur` at `alpha`). `view_dt` = view-time delta.
func apply(prev: ViewSnapshot.Actor, cur: ViewSnapshot.Actor, alpha: float, view_dt: float) -> void:
	if replay:
		return
	visible = cur.present
	if not cur.present:
		return
	_t += view_dt
	_view_dt = view_dt
	var vf := view_dt * 60.0
	position = CharacterView.stage_position(prev, cur, alpha)
	_update_facing(float(cur.facing), view_dt)
	_update_ctx(cur, vf)
	ClipMap.resolve(map, cur, alpha, _pick, ctx)
	_note_fallbacks()
	var hidden := _pick.hidden or (actor == "hush" and (cur.state == "HIDDEN" or cur.hidden_spot != ""
		or (cur.entering and cur.oneshot != "enter")))   # not in the room before she climbs in (s2-fix G #14)
	if uses_rig:
		_drive_rig(cur, hidden)
	else:
		_drive_puppet(cur, hidden, view_dt)
	_last_x = position.x


## Where the actor stands this frame: x lerped between ticks inside one room; on a stairs leg the
## stair diagonal from the leg's ends by progress (monotonic across the leg); else the floor line.
static func stage_position(prev: ViewSnapshot.Actor, cur: ViewSnapshot.Actor, alpha: float) -> Vector2:
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


func _update_ctx(cur: ViewSnapshot.Actor, vf: float) -> void:
	var changed := cur.state != _state or cur.reacting != _reacting
	var started_moving := cur.moving and not _moving
	# The flavour rule: any state change (or setting off) ends every view flavour at once.
	if changed or started_moving:
		ctx.flavour = ""
		ctx.ov_flavour = ""
		ctx.fidget_i = -1
		_idle_s = 0.0
	# Micro-gag / cue overlays stop on any Bellows state change or reaction.
	if ctx.mg != "" and (cur.state != _mg_state or cur.reacting):
		ctx.mg = ""
	if ctx.cue != "" and cur.reacting:
		ctx.cue = ""
	_state = cur.state
	_reacting = cur.reacting
	_moving = cur.moving
	# Start pending flavours (after the state-change check, so the event's own tick keeps them).
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
		ctx.mg = ViewKit.s(_mg_pending.get("id", ""))
		ctx.mg_f = 0.0
		ctx.mg_emote = ViewKit.s(_mg_pending.get("emote", ""))
		_mg_len = float(_mg_pending.get("len", 0))
		if _mg_len <= 0.0:
			_mg_len = MG_FALLBACK_F
		_mg_state = cur.state
		_mg_pending = {}
		if ctx.mg != "" and fx != null and not ClipMap.clip_exists(ClipMap.clip_of(ClipMap.entry(map, "mg:" + ctx.mg, skin))):
			if ctx.mg_emote == "sing" or ctx.mg_emote == "hum":
				fx.burst("notes", head_position() + Vector2(40.0 * _flip, -20.0), 4, Vector2(0.4 * _flip, -1.0))
	# Clocks (view frames: hit-stop freezes them).
	if ctx.flavour != "":
		ctx.flavour_f += vf
		var fl := _clip_len(ClipMap._k("flavour:", ctx.flavour))
		if ctx.flavour_f >= fl:
			var nxt := ViewKit.s(ClipRules.row("flavour:" + ctx.flavour, actor).get("then_key", ""))
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
	# Idle fidgets (maps with `idle_fidgets`: Hush).
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
			if ctx.fidget_f >= float(maxi(1, ClipMap.clip_length(fid))):
				ctx.fidget_i = -1
	elif not idle:
		ctx.fidget_i = -1
		_idle_s = 0.0
	# Standing turn.
	if cur.facing != _facing and _facing != 0 and not cur.moving and map.has("turn"):
		ctx.turn_f = 0.0
	elif ctx.turn_f >= 0.0:
		ctx.turn_f += vf
		if cur.moving or ctx.turn_f >= _clip_len("turn"):
			ctx.turn_f = -1.0
	_facing = cur.facing
	# Hush's rigging tier for `rigging@q|s|b`.
	ctx.rig_tier = ""
	if cur.state == "RIGGING" and info != null and cur.rig_prank != "":
		if cur.rig_prank != _prep_key or cur.rig_step != _prep_step:
			_prep_key = cur.rig_prank
			_prep_step = cur.rig_step
			_prep = info.step_prep(cur.rig_prank, cur.rig_step)
		ctx.rig_tier = _prep


## A key's clip length in frames (≥ 1; 1 when the clip is missing, so a flavour never waits).
func _clip_len(key: String) -> float:
	var e: Variant = ClipMap.entry(map, key, skin)
	var c := ClipMap.clip_of(e, 0)
	return float(maxi(1, ClipMap.clip_length(c)))


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
		print_verbose("[view] clip fallback: %s wants '%s' (%s)" % [actor, clip, key])


func _drive_rig(cur: ViewSnapshot.Actor, hidden: bool) -> void:
	rig.visible = not hidden
	var real := get_process_delta_time()
	rig.set("time_scale", clampf(_view_dt / real, 0.0, 4.0) if real > 0.0 else 1.0)
	_play_base(cur)
	_play_overlay()
	if bool(_has.get("set_facing", false)):
		if actor == "hush" and cur.entering:
			rig.call("set_facing", 1, false)   # the climb-in is authored facing +1: never flipped (s2-fix G #14)
		else:
			rig.call("set_facing", cur.facing, true)
	if bool(_has.get("look_toward", false)):
		rig.call("look_toward", look_target if look_target != Vector2.INF else global_position, look_weight if look_target != Vector2.INF else 0.0)
	if actor == "bellows":
		_apply_meter(cur)
	else:
		_apply_hush_looks(cur)


## Hush's TOMATO look: on from the doorstep splat until 4 s after control returns.
func _apply_hush_looks(cur: ViewSnapshot.Actor) -> void:
	if cur.oneshot == "caught:doorstep" and cur.oneshot_t >= CaughtStager.DOORSTEP_KNOCK_F + 6:
		_tomato_s = TOMATO_S
	elif _tomato_s > 0.0:
		_tomato_s -= _view_dt
	var on := _tomato_s > 0.0
	if on != _looks.has("TOMATO") and bool(_has.get("set_residue", false)):
		rig.call("set_residue", "TOMATO", on)
		if on:
			_looks.append("TOMATO")
		else:
			_looks.remove_at(_looks.find("TOMATO"))


func _play_base(cur: ViewSnapshot.Actor) -> void:
	if _pick.clip == "":
		if _clip != STATIC_CLIP and bool(_has.get("set_static_pose", false)) and not _static_pose.is_empty():
			rig.call("set_static_pose", _static_pose)
		_clip = STATIC_CLIP
		_clip_sig = STATIC_CLIP
		_frame = 0.0
		return
	# Restart only when the clip (or, for a reaction, its tier / suppressed plan) changes; no
	# string building per frame.
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
			opts["speed"] = maxf(1.0, cur.speed_px_s)
		else:
			opts["rate"] = _pick.speed
		if _pick.key == "reaction" or _pick.key == "reaction_fallback" or _pick.key == "reaction:last_beat":
			opts["blend_in"] = 0
			opts["tier"] = _pick.tier
			opts["suppressed"] = _pick.suppressed
			if _pick.last_beat != "":
				opts["last_beat"] = _pick.last_beat
		rig.call("play", _clip, opts)
	if _pick.external and bool(_has.get("set_external_frame", false)):
		rig.call("set_external_frame", _pick.frame)
		_frame = _pick.frame
	else:
		if _pick.stride and cur.moving and bool(_has.get("set_speed", false)):
			rig.call("set_speed", maxf(1.0, cur.speed_px_s))
		_frame = float(rig.call("current_frame")) if bool(_has.get("current_frame", false)) else 0.0


func _play_overlay() -> void:
	var want := _pick.ov_clip
	if want != "" and want != _ov_clip:
		var mask := ClipRules.mask_of(_pick.ov_key, actor)
		rig.call("play", want, {"layer": "overlay", "mask": mask if mask != "" else "upper", "blend_in": 6})
		_ov_clip = want
	elif want == "" and _ov_clip != "":
		if bool(_has.get("stop_layer", false)):
			rig.call("stop_layer", "overlay", 6)
		_ov_clip = ""
	var face := ViewKit.s(EMOTE_FACE.get(_pick.ov_face, "")) if _pick.ov_face != "" else ""
	if face != _ov_face:
		_ov_face = face
		if face != "" and bool(_has.get("set_face", false)):
			rig.call("set_face", face)
		elif face == "":
			var fs: Variant = rig.get("face")
			if fs is Object and (fs as Object).has_method("clear"):
				(fs as Object).call("clear")


## Temper tint + sideburns, specs, the blind bouffant, residue / costume / combo looks.
func _apply_meter(cur: ViewSnapshot.Actor) -> void:
	var tier := clampi(cur.tier, 0, 3)
	if tier != _tier:
		_tier = tier
		if bool(_has.get("set_tint_tier", false)):
			rig.call("set_tint_tier", tier)
		var sb := SIDEBURN_BY_TIER[tier]
		if sb != _sideburn and bool(_has.get("set_part_texture", false)):
			_sideburn = sb
			rig.call("set_part_texture", "sideburn_l", sb)
			rig.call("set_part_texture", "sideburn_r", sb)
	var specs := CharacterView.specs_state(cur.specs_on, cur.tier)
	if specs != _specs and bool(_has.get("set_prop_state", false)):
		_specs = specs
		rig.call("set_prop_state", "specs", specs)
	if cur.residues.has("COSTUME") and _costume == "" and info != null:
		_costume = info.costume_look(cur.react_prank if cur.react_prank != "" else _last_prank)
	elif not cur.residues.has("COSTUME"):
		_costume = ""
	var key := "%s|%s|%s|%s" % [",".join(cur.residues), ",".join(combos_formed), "b" if cur.blinded else "", _costume]
	if key != _looks_key:
		_looks_key = key
		var want := CharacterView.rig_looks(cur.residues, combos_formed, cur.blinded, _costume)
		if bool(_has.get("set_residue", false)):
			for r in _looks:
				if not want.has(r):
					rig.call("set_residue", r, false)
			for r2 in want:
				if not _looks.has(r2):
					rig.call("set_residue", r2, true)
		_looks = want
		# Blinded without a residue sub-look: flip the bouffant directly (soft rig API).
		var bf := "flipped" if cur.blinded and not want.has("FRAZZLED:blind") else ""
		if bf != _bouffant and bool(_has.get("set_part_texture", false)):
			_bouffant = bf
			rig.call("set_part_texture", "bouffant", bf)


## Specs prop state: on the nose when the sim says so or when Livid (tier 3), else dangling.
static func specs_state(specs_on: bool, tier: int) -> String:
	return "on" if specs_on or tier >= 3 else "dangling"


## The rig looks for a set of sim residues (brief §4.1.3): each residue kind; COSTUME adds
## `COSTUME:<look>`; blinded FRAZZLED adds `FRAZZLED:blind` (the flipped bouffant); a formed
## combo whose residues are all present adds `COMBO:<id>` (the rig hides the two it replaces).
## Unformed combos add nothing, so SOAKED + FRAZZLED with combos forbidden stay two looks.
static func rig_looks(residues: PackedStringArray, formed: PackedStringArray, blinded: bool, costume: String) -> PackedStringArray:
	var out := PackedStringArray()
	for r in residues:
		out.append(r)
		if r == "COSTUME" and costume != "":
			out.append("COSTUME:" + costume)
		if r == "FRAZZLED" and blinded:
			out.append("FRAZZLED:blind")
	if not formed.is_empty():
		var rj: Variant = ViewKit.json("res://data/residues.json")
		var combos: Dictionary = (rj as Dictionary).get("combos", {}) if rj is Dictionary else {}
		for id in formed:
			var c: Variant = combos.get(id, null)
			var of: Array = (c as Dictionary).get("of", []) if c is Dictionary else []
			var all := not of.is_empty()
			for k in of:
				if not residues.has(ViewKit.s(k)):
					all = false
			if all:
				out.append("COMBO:" + id)
	return out


# --- driverless (Busted Cam, Gag Reel, curtain call) ------------------------------------------

## Pose the actor from a recorded / scripted frame without a SimDriver: world position, facing,
## base clip + frame (frame-locked; its events between the previous frame and this one fire and
## sound events go out on `sound_event`), visibility, residue looks, tint tier and an optional
## overlay clip + frame.
func show_explicit(pos: Vector2, facing: int, clip: String, frame: float, shown: bool,
		looks_on: PackedStringArray = PackedStringArray(), tier: int = -1, ov_clip: String = "", ov_frame: float = 0.0) -> void:
	visible = true
	position = pos
	_flip = float(facing)
	if uses_rig and rig != null:
		rig.visible = shown
		if clip != "" and clip != _clip and ClipMap.clip_exists(clip):
			_clip = clip
			_clip_sig = clip
			rig.call("play", clip, {"blend_in": 0, "start_frame": frame})
		elif clip == "" and _clip != STATIC_CLIP and not _static_pose.is_empty():
			_clip = STATIC_CLIP
			_clip_sig = STATIC_CLIP
			rig.call("set_static_pose", _static_pose)
		if bool(_has.get("set_external_frame", false)) and _clip != STATIC_CLIP:
			rig.call("set_external_frame", frame)
		_frame = frame
		if ov_clip != _ov_clip:
			if ov_clip != "" and ClipMap.clip_exists(ov_clip):
				rig.call("play", ov_clip, {"layer": "overlay", "blend_in": 0, "start_frame": ov_frame})
			elif bool(_has.get("stop_layer", false)):
				rig.call("stop_layer", "overlay", 4)
			_ov_clip = ov_clip
		if bool(_has.get("set_facing", false)):
			rig.call("set_facing", facing, false)
		if tier >= 0 and tier != _tier and bool(_has.get("set_tint_tier", false)):
			_tier = tier
			rig.call("set_tint_tier", tier)
		if looks_on != _looks and bool(_has.get("set_residue", false)):
			for r in _looks:
				if not looks_on.has(r):
					rig.call("set_residue", r, false)
			for r2 in looks_on:
				if not _looks.has(r2):
					rig.call("set_residue", r2, true)
			_looks = looks_on.duplicate()
			_looks_key = "#explicit"
	elif puppet != null:
		puppet.visible = shown
		_clip = clip
		_frame = frame
		puppet.pose = "shock" if clip.contains("busted") or clip.contains("double_take") or clip.contains("grab") else \
				("step" if fmod(frame, 20.0) < 10.0 and (clip.contains("walk") or clip.contains("strut") or clip.contains("run")) else "stand")
		puppet.set_motion(Vector2.ONE, 0.0, Vector2.ZERO, _flip)


## Stage-1 name of `show_explicit` for the Busted Cam replay buffer (state "HIDDEN" hides).
func pose_replay(pos: Vector2, facing: int, clip: String, frame: float, state: String, _view_dt_: float) -> void:
	show_explicit(pos, facing, clip, frame, state != "HIDDEN")


## Pre-roll (ruling L13): advance the clips by `dt` seconds of real time without a new snapshot
## (the curtain rises on a Bellows already mid-note); sound events stay muted.
func preroll(dt: float) -> void:
	if not uses_rig or rig == null:
		return
	var was := mute_sounds
	mute_sounds = true
	if _pick.external and bool(_has.get("set_external_frame", false)):
		_pick.frame += dt * 60.0
		rig.call("set_external_frame", _pick.frame)
		_frame = _pick.frame
	elif rig.has_method("advance"):
		rig.call("advance", dt)
		_frame = float(rig.call("current_frame")) if bool(_has.get("current_frame", false)) else _frame
	mute_sounds = was


func _update_facing(target: float, dt: float) -> void:
	var step := dt * 60.0 / TURN_FRAMES * 2.0
	_flip = move_toward(_flip, target, step)


# --- the stand-in puppet (only when the rig fails to load) ----------------------------------

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
	var stride := float(PUPPET_STRIDES.get(actor, 50.0))
	if cur.moving or cur.leg_kind == "stairs":
		_walk_phase += maxf(absf(position.x - _last_x), 2.0 if cur.leg_kind == "stairs" else 0.0) / stride
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
