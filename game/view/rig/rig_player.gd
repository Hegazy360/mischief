## RigPlayer — plays data-driven clips on a flat-cutout rig (TECH §5.3). One Node2D that
## draws the whole character from ONE atlas page in `_draw()`: textured parts as batched
## rects (`draw_set_transform_matrix` + `draw_texture_rect_region`), rubber-hose limbs (and
## the hands / feet that end them) as one textured triangle array per z-run. A character is
## typically 4–6 draw calls (budget ≤ 12).
##
## Layers, evaluated every frame (comedy.md §5.3): base clip (crossfaded, default 6 f;
## `blend_in: 0` = pose pop) → masked overlay clip → additive clip → procedural additive
## (breathing, shiver, look-at, rot jitter) → face (keyed presets, runtime overrides, seeded
## blinks, pupils) → residue textures → springs → joint limits → FK → props → smears.
##
##   var p := RigPlayer.new(); add_child(p); p.setup("_mannequin")
##   p.play("_mannequin/loco_walk", {"speed": 225.0})
##   p.play("_mannequin/rx_take", {"tier": 2, "blend_in": 0})
##   p.set_external_frame(world.tick - start + driver.alpha())    # sim-locked reactions
##
## * **Facing**: art faces right; `set_facing(-1)` mirrors (a 6-frame squash turn:
##   scale.x 1 → 0.15 → −1, swapping at the midpoint); `no_mirror` parts counter-flip.
## * **Walks**: a clip with `stride_px` plays at `speed / (stride_px / cycle_seconds)` (opts
##   `speed` in px/s, or `set_speed()` every frame) so feet do not slide.
## * **Tiers / suppressed**: PlayPlan (hold × 1.2 / × 1.5, the T3 falling prop and last beat,
##   the suppressed settle) — lengths match the sim's formula exactly.
## * **Smears** (clips with `smear.auto`, or `smear` events): a textured part moving > 40 px/f
##   or turning > 25°/f is stretched along its motion (≤ 2×) for 2 frames and drawn with 2
##   ghosts of its previous transforms (alpha 0.45 / 0.25).
## * **Time**: `_process` advances by `delta × time_scale` (the view sets time_scale from its
##   view clock); `manual = true` + `advance(dt)` for tools. `self_hitstop` makes the player
##   freeze itself on `hitstop` events (tools / viewers; in game the JuiceClock does it).
class_name RigPlayer
extends Node2D

## Every clip event (sfx, voice, laugh, fx, face, cam, shake, hitstop, slowmo, freeze, prop,
## smear, mark, spring, decor) as its frame is crossed — base, overlay and additive layers
## alike (the event's `clip` names the clip). The Dictionary is shared: do not modify.
signal clip_event(ev: Dictionary)
## A non-looping BASE clip reached its end (the T3 last beat reports separately).
signal clip_finished(clip_id: String)
## An overlay / additive layer finished (faded out after stop_layer() or its clip's end).
signal layer_finished(layer: String, clip_id: String)

const SMEAR_ROT := 25.0
const SMEAR_PX := 40.0
const SMEAR_FRAMES := 2.0
const GHOST_ALPHA_1 := 0.45
const GHOST_ALPHA_2 := 0.25
const TURN_FRAMES := 6.0
const TURN_MIN := 0.15
const LOOK_RATE := 12.0
const HITSTOP_SHAKE_PX := 3.0

const K_LIMB := 0
const K_PART := 1
const K_OVERLAY := 2
const K_PROP := 3
const K_RUN := 7

## Rig to set up in _ready (optional; setup() can be called any time).
@export var rig_id: String = ""
@export var skin: String = ""
## Clip to play in _ready (after setup).
@export var autoplay: String = ""

var rig: RigDef
var poses: PoseLib
var atlas: AtlasSet
var springs: Springs = Springs.new()
var face: FaceState = FaceState.new()
var props: PropSim = PropSim.new()

## Multiplier on delta (the view's clock: hit-stop / slow-mo / fast-forward).
var time_scale: float = 1.0
## When true, _process does nothing: call advance(dt) yourself (tools, sheets, tests).
var manual: bool = false
## Freeze clip time (the rig still breathes / blinks).
var paused: bool = false
## Freeze on the clip's own hitstop events (viewers / captures without a JuiceClock).
var self_hitstop: bool = false
var breathing: bool = true
var smears_enabled: bool = true
var springs_enabled: bool = true
var clamp_to_limits: bool = true
## Atlas raster scale (-1 = HiResTex.ART_SCALE).
var art_scale: float = -1.0

var _pose: PackedFloat32Array = PackedFloat32Array()
var _a: PackedFloat32Array = PackedFloat32Array()
var _b: PackedFloat32Array = PackedFloat32Array()
var _tmp: PackedFloat32Array = PackedFloat32Array()
var _snap: PackedFloat32Array = PackedFloat32Array()
var _xf: Array[Transform2D] = []

var _plan: PlayPlan = null
var _frame: float = 0.0
var _ev_cursor: float = -1.0
var _rate: float = 1.0
var _external: bool = false
var _finished: bool = false
var _from_plan: PlayPlan = null
var _from_frame: float = 0.0
var _from_rate: float = 0.0
var _from_snap: bool = false
var _fade: float = 0.0
var _fade_t: float = 0.0
var _queue_clip: String = ""
var _queue_opts: Dictionary = {}
var _last_face: String = ""
var _clip_df: float = 0.0

## Masked overlay (micro-gags over any activity or walk), the overlay it replaced (fading out
## underneath, so overlay → overlay never pops) and the additive clip layer.
var _ov: _Layer = _Layer.new()
var _ov_prev: _Layer = _Layer.new()
var _ad: _Layer = _Layer.new()

var _time_s: float = 0.0
var _shiver_f: float = 0.0
var _shiver_amp: float = 2.0
var _hitstop_f: float = 0.0
var _vib: Vector2 = Vector2.ZERO
var _facing: int = 1
var _turn_from: int = 1
var _turn_t: float = -1.0
var _fsx: float = 1.0
var _look_on: bool = false
var _look_target: Vector2 = Vector2.ZERO
var _look_w: float = 0.0
var _look_head: float = 0.0
var _look_pupil: Vector2 = Vector2.ZERO
var _jitter: PackedFloat32Array = PackedFloat32Array()
var _jitter_from: PackedFloat32Array = PackedFloat32Array()
var _fade_w: float = 1.0
var _res_on: PackedByteArray = PackedByteArray()      ## effective (after combos)
var _res_user: PackedByteArray = PackedByteArray()    ## as set by set_residue()
var _res_kinds: PackedStringArray = PackedStringArray()
var _limb_fill: PackedColorArray = PackedColorArray()
var _prop_by_res: Dictionary = {}                     ## prop index → residue kind that shows it
var _tint_tier: int = 0
var _events: Array = []
var _prop_anchor: Array[Transform2D] = []   ## node global × character transform at launch
var _prop_frame: float = 0.0
var _static: PackedFloat32Array = PackedFloat32Array()

# Draw caches (built in setup / on layout change).
var _slot0: PackedInt32Array = PackedInt32Array()      ## first atlas slot of part p
var _slot_region: Array[Rect2] = []
var _slot_uv: Array[Rect2] = []
var _slot_page: PackedInt32Array = PackedInt32Array()
var _slot_size: PackedVector2Array = PackedVector2Array()
var _slot_rect: Array[Rect2] = []      ## trimmed 1× rect inside the canvas (AtlasSet.draw_rect)
var _tri_part: PackedByteArray = PackedByteArray()
var _tri_list: PackedInt32Array = PackedInt32Array()   ## parts drawn as quads in triangle runs
var _tri_pg: PackedInt32Array = PackedInt32Array()     ## page each tri part had at the last layout
var _center: PackedVector2Array = PackedVector2Array()
var _ov_part: PackedInt32Array = PackedInt32Array()
var _ov_res: PackedInt32Array = PackedInt32Array()
var _ov_slot: PackedInt32Array = PackedInt32Array()
var _prop_slot0: PackedInt32Array = PackedInt32Array()
var _items: PackedInt32Array = PackedInt32Array()
var _item_zi: PackedInt32Array = PackedInt32Array()
var _item_zo: PackedInt32Array = PackedInt32Array()
var _is_tint: PackedByteArray = PackedByteArray()
var _has_jitter: bool = false
var _keys: PackedInt32Array = PackedInt32Array()
var _keys_prev: PackedInt32Array = PackedInt32Array()
var _seq: PackedInt32Array = PackedInt32Array()
var _runs: Array[_Run] = []
var _layout_dirty: bool = true
var _curve: PackedVector2Array = PackedVector2Array()
var _joints: PackedVector2Array = PackedVector2Array()
var _empty_i: PackedInt32Array = PackedInt32Array()
var _empty_f: PackedFloat32Array = PackedFloat32Array()

# Smear history.
var _last_xf: Array[Transform2D] = []
var _g1: Array[Transform2D] = []
var _g2: Array[Transform2D] = []
var _last_c: PackedVector2Array = PackedVector2Array()
var _last_rot: PackedFloat32Array = PackedFloat32Array()
var _smear_t: PackedFloat32Array = PackedFloat32Array()
var _smear_dir: PackedVector2Array = PackedVector2Array()
var _smear_len: PackedFloat32Array = PackedFloat32Array()
var _hist: int = 0
var _force_smear: bool = false
var _smearing: bool = false


## One overlay / additive layer: its plan, clock, weight (0..1, blended in / out linearly and
## applied smoothstepped), blend lengths, mask and event cursor.
class _Layer extends RefCounted:
	var plan: PlayPlan = null
	var frame: float = 0.0
	var cursor: float = -1.0
	var w: float = 0.0
	var out: bool = false
	var bi: float = 6.0
	var bo: float = 6.0
	var mask: PackedByteArray = PackedByteArray()
	var events: Array = []

	func clear() -> void:
		plan = null
		w = 0.0
		out = false

	func copy_from(o: _Layer) -> void:
		plan = o.plan
		frame = o.frame
		cursor = o.cursor
		w = o.w
		out = true
		bi = o.bi
		bo = o.bo
		mask = o.mask

	## The applied weight (smoothstep of the linear blend: no velocity kink at either end).
	func weight() -> float:
		return w * w * (3.0 - 2.0 * w)


## One triangle-array run: consecutive limbs + limb-end parts on one page.
class _Run extends RefCounted:
	var page: int = -1
	var items: PackedInt32Array = PackedInt32Array()
	var vbase: PackedInt32Array = PackedInt32Array()
	var pts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	if rig == null and rig_id != "":
		setup(rig_id, skin)
	if autoplay != "" and rig != null:
		play(autoplay)


func _process(delta: float) -> void:
	if not manual and rig != null:
		advance(delta)


# --- public API (TECH §5.3) --------------------------------------------------------------------

## Loads rig, poses and faces and builds the atlas (skin textures swapped by file name, same
## pivots). Resets every layer. Safe to call again (another rig / skin / hot reload).
func setup(p_rig_id: String, p_skin: String = "") -> void:
	rig_id = p_rig_id
	skin = p_skin
	rig = RigDef.for_id(p_rig_id)
	if rig == null:
		push_warning("RigPlayer: rig '%s' not found" % p_rig_id)
		return
	poses = PoseLib.for_rig(p_rig_id)
	var core := rig.core_texture_paths(p_skin)
	var paths := core.duplicate()
	for q in rig.all_texture_paths(p_skin):
		if not core.has(q):
			paths.append(q)
	var s := HiResTex.resolve_scale(art_scale)
	atlas = AtlasBuilder.build("rig:%s:%s:%.2f" % [p_rig_id, p_skin, s], paths, s, {}, core.size())
	var n := rig.names.size()
	_pose = rig.rest.duplicate()
	_a = rig.rest.duplicate()
	_b = rig.rest.duplicate()
	_tmp = rig.rest.duplicate()
	_snap = rig.rest.duplicate()
	_xf.resize(n)
	_last_xf.resize(n)
	_g1.resize(n)
	_g2.resize(n)
	_last_c.resize(n)
	_last_rot.resize(n)
	_smear_t.resize(n)
	_smear_t.fill(0.0)
	_smear_dir.resize(n)
	_smear_len.resize(n)
	_jitter.resize(n)
	_jitter.fill(0.0)
	_jitter_from.resize(n)
	_jitter_from.fill(0.0)
	_hist = 0
	springs.setup(rig)
	face.setup(rig, poses, hash(p_rig_id) & 0x7FFFFFFF)
	props.setup(rig)
	_prop_anchor.resize(props.count)
	_prop_anchor.fill(Transform2D.IDENTITY)
	_res_kinds = PackedStringArray(rig.residues.keys())
	_res_kinds.sort()
	_res_on.resize(_res_kinds.size())
	_res_on.fill(0)
	_res_user.resize(_res_kinds.size())
	_res_user.fill(0)
	_prop_by_res.clear()
	_tint_tier = 0
	_plan = null
	_from_plan = null
	_ov.clear()
	_ov_prev.clear()
	_ad.clear()
	_frame = 0.0
	_finished = false
	_external = false
	_queue_clip = ""
	_facing = 1
	_fsx = 1.0
	_turn_t = -1.0
	_build_draw_cache()
	RigSampler.solve(rig, _pose, _xf)
	queue_redraw()


## Plays a clip. opts: blend_in (frames; default: the clip's, else the previous clip's
## blend_out, else 6), speed (px/s for clips with stride_px, else a rate multiplier), rate,
## loop (override), start_frame, tier (1..3), suppressed, seed (variation + last beat pick),
## hold / t3_prop_f / t3_prop / last_beat / suppressed_clip (PlayPlan overrides).
## `layer` ("base" / "overlay" / "additive") overrides the clip's own layer: overlay and
## additive clips go to their own layer and leave the base clip playing.
## Overlay opts: `mask` (a rig.json `masks` name or a part list; default the clip's, else the
## parts it keys — never the locomotion parts, see RigDef.locomotion), blend_in / blend_out
## (≥ 4 f, default the clip's, else 6). An overlay auto-stops at its clip's end (stop_layer()
## ends it early); a new overlay crossfades from the current one. A base reaction / take
## (`rx_`, `sig_`, tagged `take`) stops a running overlay unless opts `keep_overlay`.
func play(clip_id: String, opts: Dictionary = {}) -> void:
	if rig == null:
		return
	var c := ClipLib.get_clip(clip_id)
	if c == null:
		push_warning("RigPlayer: clip '%s' not found" % clip_id)
		return
	if c.rig_id != rig.id:
		push_warning("RigPlayer: clip '%s' is for rig '%s', not '%s'" % [clip_id, c.rig_id, rig.id])
		return
	var layer := c.layer
	if opts.has("layer"):
		var li := ClipDef.LAYERS.find(String(opts["layer"]))
		if li >= 0:
			layer = li
		else:
			push_warning("RigPlayer: unknown layer '%s'" % opts["layer"])
	var plan := PlayPlan.build(c, opts if layer == ClipDef.LAYER_BASE else {})
	if opts.has("loop"):
		plan.loop = bool(opts["loop"])
	if layer == ClipDef.LAYER_OVERLAY:
		_play_layer(_ov, c, plan, opts, true)
		return
	if layer == ClipDef.LAYER_ADDITIVE:
		_play_layer(_ad, c, plan, opts, false)
		return
	if c.is_take and _ov.plan != null and not bool(opts.get("keep_overlay", false)):
		stop_layer("overlay", ClipDef.OVERLAY_MIN_BLEND)
	var fade := ClipDef.DEFAULT_BLEND
	if opts.has("blend_in"):
		fade = int(opts["blend_in"])
	elif c.has_blend_in:
		fade = c.blend_in
	elif _plan != null and _plan.clip.has_blend_out:
		fade = _plan.clip.blend_out
	if _plan == null:
		fade = 0
	if fade > 0:
		if _from_plan != null:
			# Already fading: fade from a frozen snapshot of the current blend.
			RigSampler.copy(_pose_base(), _snap)
			_from_snap = true
			_from_plan = null
		else:
			_from_plan = _plan
			_from_frame = _frame
			_from_rate = 0.0 if (_finished or _external) else _rate
			_from_snap = false
		_fade = float(fade)
		_fade_t = 0.0
	else:
		_from_plan = null
		_from_snap = false
		_fade = 0.0
	_plan = plan
	_static = PackedFloat32Array()
	_frame = float(opts.get("start_frame", 0.0))
	_ev_cursor = _frame - 0.001
	_external = false
	_finished = false
	_queue_clip = plan.last_beat
	_queue_opts = {"seed": int(opts.get("seed", 0))}
	var sd := int(opts.get("seed", 0))
	_rate = float(opts.get("rate", 1.0))
	if opts.has("speed"):
		if c.stride_px > 0.0:
			set_speed(float(opts["speed"]))
		else:
			_rate *= float(opts["speed"])
	if c.time_jitter > 0.0 and not c.is_reaction():
		_rate *= 1.0 + c.time_jitter * (_hash01(sd, 7) * 2.0 - 1.0)
	for jp in _jitter.size():
		_jitter_from[jp] = lerpf(_jitter_from[jp], _jitter[jp], _fade_w) if fade > 0 else _jitter[jp]
	_jitter.fill(0.0)
	if c.rot_jitter > 0.0:
		for p in rig.names.size():
			_jitter[p] = c.rot_jitter * (_hash01(sd, 100 + p) * 2.0 - 1.0)
	_has_jitter = false
	for jq in _jitter.size():
		if _jitter[jq] != 0.0 or _jitter_from[jq] != 0.0:
			_has_jitter = true
	face.suppressed = c.is_take
	face.on_clip_face_changed()
	_last_face = ""
	_force_smear = false


## Drive the base clip's frame from the sim clock (sim-locked reactions): events between
## the previous external frame and this one fire; seeking backwards fires nothing.
func set_external_frame(frame: float) -> void:
	if _plan == null:
		return
	if not _external:
		_external = true
		_from_rate = 0.0
	var f := frame
	if not _plan.loop:
		f = clampf(f, 0.0, float(_plan.length))
	else:
		f = fposmod(f, float(_plan.length))
	if f + 0.5 < _ev_cursor and not _plan.loop:
		_ev_cursor = f
	_clip_df = absf(f - _frame)
	_frame = f
	_fire_events()
	_check_finished()


## Face right (1) or left (-1); `animate` = the 6-frame squash turn.
func set_facing(dir: int, animate: bool = true) -> void:
	var d := 1 if dir >= 0 else -1
	if d == _facing and _turn_t < 0.0:
		return
	if animate and rig != null:
		_turn_from = 1 if _fsx >= 0.0 else -1
		if _turn_from == d:
			_turn_t = -1.0
			_fsx = float(d)
		else:
			_turn_t = 0.0
	else:
		_turn_t = -1.0
		_fsx = float(d)
	_facing = d
	queue_redraw()


## Override the face with a faces.json preset (until the clip's next keyed face).
func set_face(preset: String) -> void:
	face.set_face(preset)


## Override one face slot ("none" hides, "" clears).
func set_slot(slot: String, variant: String) -> void:
	face.set_slot(slot, variant)


## Show / hide a residue look (rig.json `residues`: texture swaps, overlays, face overlays,
## props, limb fills). Sub-looks are kinds too: "FRAZZLED:blind", "COSTUME:jelly_helmet".
## Combos (rig.json `combos`) switch on by themselves when all their residues are on
## ("COMBO:dough_man"), hiding the residues they replace.
func set_residue(kind: String, on: bool) -> void:
	var i := _res_kinds.find(kind)
	if i < 0:
		return
	_res_user[i] = 1 if on else 0
	_refresh_residues()


## True when `kind` was switched on with set_residue (even while a combo hides it).
func has_residue(kind: String) -> bool:
	var i := _res_kinds.find(kind)
	return i >= 0 and _res_user[i] == 1


## Residue kinds currently shown (combos resolved).
func active_residues() -> PackedStringArray:
	var out := PackedStringArray()
	for i in _res_kinds.size():
		if _res_on[i] == 1:
			out.append(_res_kinds[i])
	return out


func _refresh_residues() -> void:
	var on := _res_user.duplicate()
	for i in _res_kinds.size():
		var res: RigDef.RigResidue = rig.residues[_res_kinds[i]]
		if res.combo_of.is_empty():
			continue
		var all := true
		for k in res.combo_of:
			var ki := _res_kinds.find(k)
			if ki < 0 or _res_user[ki] == 0:
				all = false
		if all:
			on[i] = 1
	for i2 in _res_kinds.size():
		var res2: RigDef.RigResidue = rig.residues[_res_kinds[i2]]
		if on[i2] == 1 and not res2.combo_replaces.is_empty():
			for k2 in res2.combo_replaces:
				var ki2 := _res_kinds.find(k2)
				if ki2 >= 0:
					on[ki2] = 0
	# Props shown by residues.
	for i3 in _res_kinds.size():
		var res3: RigDef.RigResidue = rig.residues[_res_kinds[i3]]
		for pid in res3.props:
			var pi := props.index_of(String(pid))
			if pi < 0:
				continue
			if on[i3] == 1 and _res_on[i3] == 0:
				props.attach(pi, String(res3.props[pid]))
				_prop_by_res[pi] = _res_kinds[i3]
			elif on[i3] == 0 and _res_on[i3] == 1 and String(_prop_by_res.get(pi, "")) == _res_kinds[i3]:
				props.set_state(pi, "hidden")
				_prop_by_res.erase(pi)
	var changed := on != _res_on
	_res_on = on
	_apply_limb_fills()
	if changed and not _slot0.is_empty():
		_rebuild_items()


## Temper tint tier (0..n-1 of rig.json `tint.tiers`).
func set_tint_tier(tier: int) -> void:
	_tint_tier = maxi(0, tier)


## Prop texture state ("hidden" / "shown" / a state name; "attach" re-attaches). A state
## listed in rig.json `state_sockets` also moves the prop to that socket (specs: chain ↔ nose).
func set_prop_state(prop: String, state: String) -> void:
	var i := props.index_of(prop)
	if i < 0:
		return
	if state == "attach":
		props.attach(i)
		return
	props.set_state(i, state)
	var pr: RigDef.RigProp = rig.props[i]
	if pr.state_sockets.has(state):
		props.attach(i, String(pr.state_sockets[state]))


## Additive head / pupil look toward a world position (weight 0 = off).
## NOTE — TECH §5.3 names this `look_at(world_pos, weight)`, but RigPlayer is a Node2D and
## GDScript refuses to override the native `Node2D.look_at(point)` (parse error), so it is
## **`look_toward(world_pos, weight)`**.
func look_toward(world_pos: Vector2, weight: float) -> void:
	_look_target = world_pos
	_look_w = clampf(weight, 0.0, 1.0)
	_look_on = _look_w > 0.0


## Show a fixed pose (no clip): tools, pose sheets, AnimViewer's pose mode. Layers on top
## (breathing, springs, face, props) still apply.
func set_static_pose(pose: PackedFloat32Array) -> void:
	_static = pose.duplicate()
	_plan = null
	_from_plan = null
	_from_snap = false
	_finished = false


## Tool setup: manual stepping, no breathing, no random blinks (sheets must be repeatable).
func configure_for_tools() -> void:
	manual = true
	breathing = false
	face.blinks_enabled = false


## Id of the base clip being played ("" = none).
func current_clip() -> String:
	return _plan.clip.id if _plan != null else ""


## Timeline frame of the base clip.
func current_frame() -> float:
	return _frame


# --- extras ------------------------------------------------------------------------------------

## Walk speed in px/s (clips with stride_px): playback rate = speed / (stride / cycle s).
func set_speed(px_per_s: float) -> void:
	if _plan == null or _plan.clip.stride_px <= 0.0:
		return
	var natural := _plan.clip.stride_px / (float(_plan.clip.length) / 60.0)
	_rate = absf(px_per_s) / natural if natural > 0.0 else 1.0


## Stop an overlay / additive layer ("overlay" / "additive") with its blend out
## (`blend_out` ≥ 0 overrides it; overlays never blend out in under 4 f).
func stop_layer(layer: String, blend_out: int = -1) -> void:
	var l := _layer(layer)
	if l == null or l.plan == null:
		return
	l.out = true
	if blend_out >= 0:
		l.bo = float(maxi(ClipDef.OVERLAY_MIN_BLEND if l == _ov else 1, blend_out))
	if l == _ov and _ov_prev.plan != null:
		_ov_prev.out = true


## Drop the overlay and additive layers at once (no blend out; retry / seek / tools).
func reset_layers() -> void:
	_ov.clear()
	_ov_prev.clear()
	_ad.clear()


## Clip id playing on a layer ("base", "overlay", "additive"; "" = none).
func layer_clip(layer: String) -> String:
	if layer == "base":
		return current_clip()
	var l := _layer(layer)
	return l.plan.clip.id if l != null and l.plan != null else ""


## Frame of a layer's clip (base: current_frame()).
func layer_frame(layer: String) -> float:
	if layer == "base":
		return _frame
	var l := _layer(layer)
	return l.frame if l != null and l.plan != null else 0.0


## Applied weight of an overlay / additive layer (0..1; base = 1).
func layer_weight(layer: String) -> float:
	if layer == "base":
		return 1.0
	var l := _layer(layer)
	return l.weight() if l != null and l.plan != null else 0.0


## The per-part mask an overlay layer writes (1 = the overlay drives that part).
func overlay_mask() -> PackedByteArray:
	return _ov.mask


func _layer(layer: String) -> _Layer:
	match layer:
		"overlay":
			return _ov
		"additive":
			return _ad
	return null


func _play_layer(l: _Layer, c: ClipDef, plan: PlayPlan, opts: Dictionary, overlay: bool) -> void:
	var min_b := ClipDef.OVERLAY_MIN_BLEND if overlay else 0
	if overlay and _ov.plan != null and _ov.w > 0.0:
		# Crossfade overlay → overlay: the current one fades out underneath the new one.
		_ov_prev.copy_from(_ov)
		_ov_prev.bo = maxf(float(ClipDef.OVERLAY_MIN_BLEND), float(int(opts.get("blend_in", c.blend_in))))
	l.plan = plan
	l.frame = float(opts.get("start_frame", 0.0))
	l.cursor = l.frame - 0.001
	l.bi = float(maxi(min_b, int(opts.get("blend_in", c.blend_in))))
	l.bo = float(maxi(min_b, int(opts.get("blend_out", c.blend_out))))
	l.out = false
	l.w = 0.0 if l.bi > 0.0 else 1.0
	if not overlay:
		l.mask = PackedByteArray()
		return
	if opts.has("mask"):
		var mv: Variant = opts["mask"]
		var errs := PackedStringArray()
		var m := PackedByteArray()
		if (mv is String and rig.has_mask(String(mv))) or mv is Array:
			m = rig.mask_from(mv, errs)
		if not ClipDef.mask_any(m):
			m = c.keyed_parts().duplicate()
		ClipDef.strip_locomotion(rig, m, c.touch_legs)
		l.mask = m
	else:
		l.mask = c.overlay_mask()


## Timeline length of the base clip (frames).
func clip_length() -> int:
	return _plan.length if _plan != null else 0


## The current PlayPlan (null when idle).
func plan() -> PlayPlan:
	return _plan


## True while a non-looping base clip has not finished.
func is_playing() -> bool:
	return _plan != null and not _finished


## Current facing (±1).
func facing() -> int:
	return _facing


## The final pose of the last update (read-only).
func pose_buffer() -> PackedFloat32Array:
	return _pose


## Solved part transforms (character space) of the last update.
func part_transforms() -> Array[Transform2D]:
	return _xf


## A part joint's global position.
func part_global_position(part: String) -> Vector2:
	var p := rig.idx(part) if rig != null else -1
	if p < 0:
		return global_position
	return global_transform * (_char_xf() * _xf[p].origin)


## Global transform of a socket ("part:socket").
func socket_global_transform(socket_name: String) -> Transform2D:
	var s := rig.socket_index(socket_name) if rig != null else -1
	if s < 0:
		return global_transform
	return global_transform * _char_xf() * _socket_xf(s)


## Local bounding rect (node space) of the current pose.
func get_bounds() -> Rect2:
	if rig == null:
		return Rect2()
	var r := RigBounds.bbox(rig, _pose, _xf)
	var c := _char_xf()
	var a := c * r.position
	var b := c * r.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## Kick the self-hitstop shake for `frames` (viewers).
func hitstop(frames: float) -> void:
	_hitstop_f = maxf(_hitstop_f, frames)


## Shiver ±amp° at 12 Hz for `frames`.
func shiver(frames: float, amp_deg: float = 2.0) -> void:
	_shiver_f = frames
	_shiver_amp = amp_deg


## Advance every layer by `dt` seconds of view time and redraw.
func advance(dt: float) -> void:
	if rig == null:
		return
	var vdt := maxf(0.0, dt * time_scale)
	var frames := vdt * 60.0
	var clip_frames := 0.0 if paused else frames
	if _hitstop_f > 0.0:
		_hitstop_f -= frames
		clip_frames = 0.0
		_vib = Vector2(HITSTOP_SHAKE_PX if (Engine.get_process_frames() & 1) == 0 else -HITSTOP_SHAKE_PX, 0.0)
	else:
		_vib = Vector2.ZERO
	_time_s += vdt
	_clip_df = 0.0
	if _plan != null and not _external and not _finished:
		var df := clip_frames * _rate
		_clip_df = df
		if _plan.loop:
			_frame = fposmod(_frame + df, float(_plan.length))
		else:
			_frame = minf(_frame + df, float(_plan.length))
		_fire_events()
		_check_finished()
	if _from_plan != null or _from_snap:
		_from_frame += clip_frames * _from_rate
		if _from_plan != null and _from_plan.loop:
			_from_frame = fposmod(_from_frame, float(_from_plan.length))
		_fade_t += clip_frames if not _external else frames
	_advance_layer_frames(clip_frames)
	if _shiver_f > 0.0:
		_shiver_f -= frames
	if _turn_t >= 0.0:
		_turn_t += frames
		if _turn_t >= TURN_FRAMES:
			_turn_t = -1.0
			_fsx = float(_facing)
		elif _turn_t < TURN_FRAMES * 0.5:
			_fsx = float(_turn_from) * lerpf(1.0, TURN_MIN, _turn_t / (TURN_FRAMES * 0.5))
		else:
			_fsx = float(_facing) * lerpf(TURN_MIN, 1.0, (_turn_t - TURN_FRAMES * 0.5) / (TURN_FRAMES * 0.5))
	face.advance(frames)
	_update_pose(vdt)
	queue_redraw()


# --- update ------------------------------------------------------------------------------------

func _pose_base() -> PackedFloat32Array:
	return _pose


func _advance_layer_frames(clip_frames: float) -> void:
	_step_layer(_ov_prev, clip_frames, "")
	_step_layer(_ov, clip_frames, "overlay")
	_step_layer(_ad, clip_frames, "additive")


## Advance one layer: clock (wrapping loops, clamping one-shots at their end), weight (in
## over bi, out over bo; a one-shot starts blending out bo frames before its end), events.
## `name` "" = the outgoing overlay (no events, no signal).
func _step_layer(l: _Layer, clip_frames: float, name: String) -> void:
	if l.plan == null:
		return
	var ln := float(l.plan.length)
	var f := l.frame + clip_frames
	if l.plan.loop:
		f = fposmod(f, ln)
	else:
		f = minf(f, ln)
		if f >= ln - l.bo:
			l.out = true
	l.frame = f
	if l.out:
		l.w = maxf(0.0, l.w - clip_frames / maxf(1.0, l.bo)) if l.bo > 0.0 else 0.0
	else:
		l.w = minf(1.0, l.w + clip_frames / maxf(1.0, l.bi)) if l.bi > 0.0 else 1.0
	if name != "" and absf(l.frame - l.cursor) > 0.00001:
		l.plan.between_into(l.cursor, l.frame, l.events)
		l.cursor = l.frame
		for e in l.events:
			_handle_event(e)
	if l.out and l.w <= 0.0 and l.plan != null:
		var id := l.plan.clip.id
		l.clear()
		if name != "":
			layer_finished.emit(name, id)


func _fire_events() -> void:
	if _plan == null:
		return
	var f1 := _frame
	if absf(f1 - _ev_cursor) < 0.00001:
		return
	_plan.between_into(_ev_cursor, f1, _events)
	_ev_cursor = f1
	for e in _events:
		_handle_event(e)


func _check_finished() -> void:
	if _plan == null or _plan.loop or _finished:
		return
	if _frame >= float(_plan.length) - 0.0001:
		_finished = true
		var id := _plan.clip.id
		clip_finished.emit(id)
		if _queue_clip != "" and _plan != null and _plan.clip.id == id:
			var q := _queue_clip
			_queue_clip = ""
			play(q, _queue_opts)


func _handle_event(e: Dictionary) -> void:
	var t := String(e.get("type", ""))
	match t:
		"prop":
			var i := props.index_of(String(e.get("prop", "")))
			var op := String(e.get("op", ""))
			if i >= 0:
				match op:
					"launch":
						var v := _v2(e.get("vel", [0, -600]))
						var st := _prop_xf(i)
						props.launch(i, _prop_frame, st, v, float(e.get("spin", 0.0)))
						_prop_anchor[i] = global_transform * _char_xf()
					"attach":
						props.attach(i, String(e.get("socket", "")))
					"detach":
						props.detach(i, _prop_xf(i))
						_prop_anchor[i] = global_transform * _char_xf()
					"state":
						set_prop_state(String(e.get("prop", "")), String(e.get("state", "")))
					"hide":
						props.set_state(i, "hidden")
					"show":
						props.set_state(i, "shown")
		"hitstop":
			if self_hitstop:
				hitstop(float(e.get("frames", 4)))
		"face":
			var pr := String(e.get("preset", e.get("id", "")))
			if pr != "":
				face.set_face(pr)
		"smear":
			var p := rig.idx(String(e.get("part", "")))
			if p >= 0:
				_smear_t[p] = float(e.get("frames", SMEAR_FRAMES))
				_smear_len[p] = clampf(float(e.get("stretch", 1.6)), 1.0, 2.0)
				var dv := _v2(e.get("dir", [0, 0]))
				_smear_dir[p] = dv.normalized() if dv != Vector2.ZERO else Vector2.ZERO
			else:
				_force_smear = true
		"spring":
			springs.kick_part(String(e.get("part", "")), float(e.get("kick", 20.0)))
		"fx":
			if String(e.get("id", "")) == "shiver":
				shiver(float(e.get("dur", 30)), float(e.get("amp", 2.0)))
	clip_event.emit(e)


func _update_pose(vdt: float) -> void:
	_prop_frame += vdt * 60.0
	# 1. base (+ crossfade)
	if _plan != null:
		_plan.sample(_frame, _a)
		if _from_plan != null or _from_snap:
			if _from_snap:
				RigSampler.copy(_snap, _b)
			else:
				_from_plan.sample(_from_frame, _b)
			var w := clampf(_fade_t / maxf(1.0, _fade), 0.0, 1.0)
			RigSampler.blend(_b, _a, w, _pose)
			_fade_w = w
			if w >= 1.0:
				_from_plan = null
				_from_snap = false
		else:
			RigSampler.copy(_a, _pose)
			_fade_w = 1.0
		_track_face_keys()
	elif _static.size() == _pose.size():
		RigSampler.copy(_static, _pose)
	else:
		RigSampler.copy(rig.rest, _pose)
	# 2. overlay (the outgoing one underneath while it fades), 3. additive clip
	if _ov_prev.plan != null and _ov_prev.w > 0.0:
		_ov_prev.plan.sample(_ov_prev.frame, _tmp)
		RigSampler.apply_mask(_pose, _tmp, _ov_prev.mask, _ov_prev.weight())
	if _ov.plan != null and _ov.w > 0.0:
		_ov.plan.sample(_ov.frame, _tmp)
		RigSampler.apply_mask(_pose, _tmp, _ov.mask, _ov.weight())
	if _ad.plan != null and _ad.w > 0.0:
		_ad.plan.sample(_ad.frame, _tmp)
		RigSampler.apply_additive(_pose, _tmp, rig.rest, _ad.weight())
	# 4. procedural additive layers
	if _has_jitter:
		for p in _jitter.size():
			var jv := _jitter[p] if _fade_w >= 1.0 else lerpf(_jitter_from[p], _jitter[p], _fade_w)
			_pose[RigDef.ROOT_CH + p * RigDef.STRIDE] += jv
	if breathing:
		RigSampler.breathe(rig, _pose, _time_s, 1.0)
	var shiv := _shiver_f > 0.0 or (_plan != null and _plan.clip.tags.has("shiver"))
	if shiv:
		RigSampler.shiver(rig, _pose, _time_s, _shiver_amp)
	_update_look(vdt)
	if _look_head != 0.0:
		RigSampler.look(rig, _pose, _look_head, Vector2.ZERO)
	# 5. face
	face.look = _look_pupil
	face.apply(_pose)
	# 6. residue textures (only over default textures: a clip's explicit swap wins) and
	#    face overlays (sweat, singe…) shown while the residue is on.
	for r in _res_kinds.size():
		if _res_on[r] == 0:
			continue
		var res: RigDef.RigResidue = rig.residues[_res_kinds[r]]
		for k in res.tex_part.size():
			var b := RigDef.ROOT_CH + res.tex_part[k] * RigDef.STRIDE + RigDef.C_TEX
			if int(_pose[b]) == 0:
				_pose[b] = float(res.tex_var[k])
		for fs in res.face_slots:
			var fb := RigDef.ROOT_CH + rig.face_slot_part[fs] * RigDef.STRIDE
			_pose[fb + RigDef.C_VIS] = 1.0
	# 7. springs (driven by last frame's motion), 8. limits, 9. FK
	if springs_enabled:
		springs.step(vdt)
		springs.apply(_pose)
	if clamp_to_limits:
		RigSampler.clamp_limits(rig, _pose)
	RigSampler.solve(rig, _pose, _xf)
	if springs_enabled:
		springs.feed(_xf, global_position, _fsx, vdt)
	# 11. smear history
	_update_smears(vdt * 60.0)


func _track_face_keys() -> void:
	var c := _plan.clip_at(_frame)
	if c.key_f.is_empty():
		return
	var src := _plan.src_frame(_frame) if not _plan.in_tail(_frame) else _frame - float(_plan.tail_start)
	var k := clampi(c.key_f.bsearch(int(floor(src)), false) - 1, 0, c.key_f.size() - 1)
	var fname := c.key_face[k]
	if fname != _last_face:
		_last_face = fname
		face.clip_preset = fname
		face.on_clip_face_changed()


func _update_look(vdt: float) -> void:
	var th := 0.0
	var tp := Vector2.ZERO
	if _look_on and rig.look_part >= 0 and is_inside_tree():
		var head := global_transform * (_char_xf() * _xf[rig.look_part].origin)
		var d := _look_target - head
		var local := Vector2(d.x * signf(_fsx) if _fsx != 0.0 else d.x, d.y)
		if local.length() > 1.0:
			th = rad_to_deg(atan2(local.y, absf(local.x))) * _look_w
			tp = local.normalized() * _look_w
	var k := 1.0 - exp(-LOOK_RATE * vdt)
	_look_head = lerpf(_look_head, th, k)
	_look_pupil = _look_pupil.lerp(tp, k)
	if absf(_look_head) < 0.01 and not _look_on:
		_look_head = 0.0
	if _look_pupil.length() < 0.001 and not _look_on:
		_look_pupil = Vector2.ZERO


func _update_smears(frames: float) -> void:
	var n := rig.names.size()
	var auto := smears_enabled and _plan != null and (_plan.clip_at(_frame).smear_auto or _force_smear)
	if not auto and not _smearing:
		_hist = 0
		return
	_smearing = false
	var df := _clip_df
	for p in n:
		if _smear_t[p] > 0.0:
			_smear_t[p] = maxf(0.0, _smear_t[p] - frames)
			_smearing = true
		if not rig.is_textured(p):
			continue
		var cur := _xf[p]
		var c := cur * _center[p]
		var rot := cur.get_rotation()
		if _hist > 0:
			_g2[p] = _g1[p] if _hist > 1 else _last_xf[p]
			_g1[p] = _last_xf[p]
			if auto and df > 0.25 and df < 2.5:
				var mv := c - _last_c[p]
				var v := mv.length() / df
				var av := absf(rad_to_deg(wrapf(rot - _last_rot[p], -PI, PI))) / df
				if v > SMEAR_PX or av > SMEAR_ROT:
					_smear_t[p] = SMEAR_FRAMES
					_smear_dir[p] = mv / mv.length() if v > SMEAR_PX else Vector2.ZERO
					_smear_len[p] = clampf(1.0 + v / 80.0, 1.0, 2.0) if v > SMEAR_PX else 1.0
		else:
			_g1[p] = cur
			_g2[p] = cur
		_last_xf[p] = cur
		_last_c[p] = c
		_last_rot[p] = rot
	if df > 0.0 or _hist == 0:
		_hist = mini(_hist + 1, 2)


# --- drawing ---------------------------------------------------------------------------------

func _char_xf() -> Transform2D:
	return Transform2D(0.0, Vector2(_fsx, 1.0), 0.0, _vib)


func _socket_xf(s: int) -> Transform2D:
	var p := rig.socket_part[s]
	var so := rig.socket_xf[s]
	return _xf[p] * Transform2D(deg_to_rad(so.z), Vector2(so.x, so.y) - rig.pivot[p])


func _prop_xf(i: int) -> Transform2D:
	match props.mode[i]:
		PropSim.ATTACHED:
			return _socket_xf(props.socket[i]) if props.socket[i] >= 0 else Transform2D.IDENTITY
		PropSim.FLYING, PropSim.LOOSE:
			# The prop flies in the WORLD frame it was launched in: map it into today's
			# character space (the character may have walked on, turned, been moved or scaled).
			var xf := props.flying_xf(i, _prop_frame)
			return (global_transform * _char_xf()).affine_inverse() * _prop_anchor[i] * xf
	return Transform2D.IDENTITY


func _apply_limb_fills() -> void:
	var sk := rig.skin_limb_fills(skin)
	_limb_fill.resize(rig.limbs.size())
	for li in rig.limbs.size():
		_limb_fill[li] = sk.get(li, rig.limbs[li].fill)
	for r in _res_kinds.size():
		if _res_on[r] == 1:
			var res: RigDef.RigResidue = rig.residues[_res_kinds[r]]
			for li2 in res.limb_fill:
				_limb_fill[li2] = res.limb_fill[li2]
	_layout_dirty = true


func _build_draw_cache() -> void:
	_apply_limb_fills()
	var n := rig.names.size()
	_slot0.resize(n)
	_slot_region.clear()
	_slot_uv.clear()
	_slot_page = PackedInt32Array()
	_slot_size = PackedVector2Array()
	_slot_rect.clear()
	_center.resize(n)
	_tri_part.resize(n)
	_tri_part.fill(0)
	var add_slot := func(path: String, size_1x: Vector2) -> void:
		var q := rig.skin_path(path, skin)
		_slot_region.append(atlas.region(q))
		_slot_uv.append(atlas.uv_rect(q))
		_slot_page.append(maxi(0, atlas.page_index(q)))
		_slot_size.append(size_1x if size_1x != Vector2.ZERO else atlas.size_1x(q))
		_slot_rect.append(atlas.draw_rect(q))
	for p in n:
		_slot0[p] = _slot_region.size()
		var files: PackedStringArray = rig.tex_files[p]
		var sizes: PackedVector2Array = rig.tex_sizes[p]
		for v in files.size():
			add_slot.call(files[v], sizes[v])
		var s0 := sizes[0] if not sizes.is_empty() else Vector2.ZERO
		_center[p] = s0 * 0.5 - rig.pivot[p]
	# Limb ends (the part after a limb's last bone, or the last joint when textured) join the
	# limb's triangle run.
	for l in rig.limbs:
		var lb: RigDef.RigLimb = l
		for j in lb.joints:
			if rig.is_textured(j):
				_tri_part[j] = 1
		var last := lb.joints[lb.joints.size() - 1] if not lb.joints.is_empty() else -1
		if last >= 0:
			for c in rig.names.size():
				if rig.parent[c] == last and rig.is_textured(c) and rig.face_slot_of[c] < 0:
					_tri_part[c] = 1
	_tri_list = PackedInt32Array()
	for tp0 in n:
		if _tri_part[tp0] == 1:
			_tri_list.append(tp0)
	_tri_pg.resize(n)
	_tri_pg.fill(-1)
	_ov_part = PackedInt32Array()
	_ov_res = PackedInt32Array()
	_ov_slot = PackedInt32Array()
	for r in _res_kinds.size():
		var res: RigDef.RigResidue = rig.residues[_res_kinds[r]]
		for k in res.overlay_part.size():
			_ov_part.append(res.overlay_part[k])
			_ov_res.append(r)
			_ov_slot.append(_slot_region.size())
			add_slot.call(res.overlay_file[k], res.overlay_size[k])
	_prop_slot0 = PackedInt32Array()
	for pr in rig.props:
		var prd: RigDef.RigProp = pr
		_prop_slot0.append(_slot_region.size())
		for k2 in prd.state_files.size():
			add_slot.call(prd.state_files[k2], prd.state_sizes[k2])
	_rebuild_items()
	_is_tint.resize(n)
	_is_tint.fill(0)
	for tp in rig.tint_parts:
		_is_tint[tp] = 1
	_curve.resize(LineLimb.SAMPLES)
	_layout_dirty = true


## The draw items: limbs, textured parts, the overlays of ACTIVE residues only (Bellows has
## 60+ overlays; the per-frame sort should not walk them), props. Rebuilt on residue change.
func _rebuild_items() -> void:
	_items = PackedInt32Array()
	for li in rig.limbs.size():
		_items.append((K_LIMB << 16) | li)
	for p2 in rig.names.size():
		if rig.is_textured(p2):
			_items.append((K_PART << 16) | p2)
	for o in _ov_part.size():
		if _res_on.size() > _ov_res[o] and _res_on[_ov_res[o]] == 1:
			_items.append((K_OVERLAY << 16) | o)
	for pi in rig.props.size():
		_items.append((K_PROP << 16) | pi)
	# z source per item: a pose index + offset (props: -1, computed by _item_z).
	_item_zi.resize(_items.size())
	_item_zo.resize(_items.size())
	for k in _items.size():
		var code := _items[k]
		var kind := code >> 16
		var i := code & 0xFFFF
		_item_zo[k] = 0
		match kind:
			K_LIMB:
				var lb: RigDef.RigLimb = rig.limbs[i]
				_item_zi[k] = RigDef.ch(lb.joints[0], RigDef.C_Z) if not lb.joints.is_empty() else -1
			K_PART:
				_item_zi[k] = RigDef.ch(i, RigDef.C_Z)
			K_OVERLAY:
				_item_zi[k] = RigDef.ch(_ov_part[i], RigDef.C_Z)
			_:
				_item_zi[k] = -1
	_keys.resize(_items.size())
	_keys_prev.resize(0)
	_layout_dirty = true


## Items that draw nothing this frame (hidden parts, inactive overlays, hidden props) stay
## out of the layout, so they never split a batch.
const HIDDEN_KEY := 1023 << 18


func _item_drawn(code: int) -> bool:
	var kind := code >> 16
	var i := code & 0xFFFF
	match kind:
		K_PART:
			var b := RigDef.ROOT_CH + i * RigDef.STRIDE
			return _pose[b + RigDef.C_VIS] >= 0.5 and _pose[b + RigDef.C_ALPHA] > 0.001
		K_OVERLAY:
			return _res_on[_ov_res[i]] == 1 and _pose[RigDef.ROOT_CH + _ov_part[i] * RigDef.STRIDE + RigDef.C_VIS] >= 0.5
		K_PROP:
			return props.mode[i] != PropSim.HIDDEN
		K_LIMB:
			var lb: RigDef.RigLimb = rig.limbs[i]
			return lb.joints.is_empty() or _pose[RigDef.ROOT_CH + lb.joints[0] * RigDef.STRIDE + RigDef.C_VIS] >= 0.5
	return true


func _item_z(code: int) -> int:
	var kind := code >> 16
	var i := code & 0xFFFF
	match kind:
		K_LIMB:
			var lb: RigDef.RigLimb = rig.limbs[i]
			return int(_pose[RigDef.ROOT_CH + lb.joints[0] * RigDef.STRIDE + RigDef.C_Z]) if not lb.joints.is_empty() else 0
		K_PART:
			return int(_pose[RigDef.ROOT_CH + i * RigDef.STRIDE + RigDef.C_Z])
		K_OVERLAY:
			return int(_pose[RigDef.ROOT_CH + _ov_part[i] * RigDef.STRIDE + RigDef.C_Z])
		K_PROP:
			if props.mode[i] == PropSim.FLYING or props.mode[i] == PropSim.LOOSE:
				return 400
			var pr: RigDef.RigProp = rig.props[i]
			var s := props.socket[i]
			if s >= 0 and pr.z_by_socket.has(rig.socket_names[s]):
				return int(pr.z_by_socket[rig.socket_names[s]])
			if pr.z_abs >= 0 and s == pr.socket_i:
				return pr.z_abs
			var zp := int(_pose[RigDef.ROOT_CH + rig.socket_part[s] * RigDef.STRIDE + RigDef.C_Z]) if s >= 0 else 0
			var st := pr.states[clampi(props.state[i], 0, pr.states.size() - 1)] if not pr.states.is_empty() else ""
			return zp + int(pr.state_z_offset.get(st, pr.z_offset))
	return 0


func _sort_items() -> void:
	var n := _items.size()
	for k in n:
		var code := _items[k]
		if not _item_drawn(code):
			_keys[k] = HIDDEN_KEY | code   # sorted last, skipped by the layout
			continue
		var zi := _item_zi[k]
		var z: int
		if zi >= 0:
			z = int(_pose[zi]) + _item_zo[k]
		else:
			z = _item_z(code)   # props: attached / flying decides
		z = clampi(z + 512, 0, 1022)
		_keys[k] = (z << 18) | code
	_keys.sort()
	if _keys != _keys_prev:
		_layout_dirty = true
	# A texture variant on another atlas page (Bellows' tiptoe slippers) moves its quad to a
	# run on that page.
	for tp in _tri_list:
		if _cur_page(tp) != _tri_pg[tp]:
			_layout_dirty = true
			break


## Atlas page of part `p`'s current texture variant.
func _cur_page(p: int) -> int:
	var b := RigDef.ROOT_CH + p * RigDef.STRIDE
	return _slot_page[_slot0[p] + clampi(int(_pose[b + RigDef.C_TEX]), 0, rig.tex_files[p].size() - 1)]


## Cumulative CPU time spent in _draw() by every RigPlayer (µs) and draw count — perf logs.
static var draw_us: int = 0
static var draw_count: int = 0


func _draw() -> void:
	if rig == null or atlas == null or atlas.pages.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	_draw_all()
	draw_us += Time.get_ticks_usec() - t0
	draw_count += 1


func _draw_all() -> void:
	_sort_items()
	if _layout_dirty:
		_rebuild_layout()
	var cx := _char_xf()
	var ci := get_canvas_item()
	for code in _seq:
		var kind := code >> 16
		var i := code & 0xFFFF
		if kind == K_RUN:
			var run: _Run = _runs[i]
			_fill_run(run, Transform2D.IDENTITY)
			draw_set_transform_matrix(cx)
			RenderingServer.canvas_item_add_triangle_array(ci, run.idx, run.pts, run.cols, run.uvs, _empty_i, _empty_f,
				atlas.pages[run.page].get_rid())
		elif kind == K_PART:
			_draw_part(i, cx)
		elif kind == K_OVERLAY:
			_draw_overlay(i, cx)
		elif kind == K_PROP:
			_draw_prop(i, cx)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _rebuild_layout() -> void:
	_layout_dirty = false
	_keys_prev = _keys.duplicate()
	for tp in _tri_list:
		_tri_pg[tp] = _cur_page(tp)
	_seq = PackedInt32Array()
	_runs.clear()
	var cur: _Run = null
	for key in _keys:
		if key >= HIDDEN_KEY:
			break
		var code := key & 0x3FFFF
		var kind := code >> 16
		var i := code & 0xFFFF
		var tri := kind == K_LIMB or (kind == K_PART and _tri_part[i] == 1)
		if not tri:
			cur = null
			_seq.append(code)
			continue
		var pg := -1
		if kind == K_PART:
			pg = _tri_pg[i]
		if cur == null or (pg >= 0 and cur.page >= 0 and pg != cur.page):
			cur = _Run.new()
			_runs.append(cur)
			_seq.append((K_RUN << 16) | (_runs.size() - 1))
		if pg >= 0 and cur.page < 0:
			cur.page = pg
		cur.items.append(code)
	for run in _runs:
		if run.page < 0:
			run.page = 0
		var nv := 0
		var nt := 0
		for code2 in run.items:
			run.vbase.append(nv)
			if (code2 >> 16) == K_LIMB:
				nv += LineLimb.VERTS
				nt += LineLimb.TRIS
			else:
				nv += LineLimb.QUAD_VERTS
				nt += LineLimb.QUAD_TRIS
		run.pts.resize(nv)
		run.uvs.resize(nv)
		run.cols.resize(nv)
		run.idx.resize(nt * 3)
		var w := 0
		var line_uv := atlas.builtin_uv(AtlasSet.LINE, run.page)
		var disc_uv := atlas.builtin_uv(AtlasSet.DISC, run.page)
		for j in run.items.size():
			var code3 := run.items[j]
			if (code3 >> 16) == K_LIMB:
				var lb: RigDef.RigLimb = rig.limbs[code3 & 0xFFFF]
				LineLimb.write_indices(run.idx, w, run.vbase[j])
				LineLimb.write_static(run.uvs, run.cols, run.vbase[j], line_uv, disc_uv, lb.ink, _limb_fill[code3 & 0xFFFF])
				w += LineLimb.TRIS * 3
			else:
				LineLimb.write_quad_indices(run.idx, w, run.vbase[j])
				w += LineLimb.QUAD_TRIS * 3


func _fill_run(run: _Run, cx: Transform2D) -> void:
	for j in run.items.size():
		var code := run.items[j]
		var i := code & 0xFFFF
		var vb := run.vbase[j]
		if (code >> 16) == K_LIMB:
			var lb: RigDef.RigLimb = rig.limbs[i]
			var jn := lb.joints.size()
			if _joints.size() < jn:
				_joints.resize(jn)
			var vis := true
			for k in jn:
				_joints[k] = _xf[lb.joints[k]].origin
			vis = _pose[RigDef.ROOT_CH + lb.joints[0] * RigDef.STRIDE + RigDef.C_VIS] > 0.5
			if not vis:
				LineLimb.collapse(run.pts, vb, LineLimb.VERTS)
				continue
			LineLimb.curve(_joints, jn, _curve)
			LineLimb.write_positions(_curve, lb.width * 0.5 + lb.outline, lb.width * 0.5, cx, run.pts, vb)
		else:
			var b := RigDef.ROOT_CH + i * RigDef.STRIDE
			var alpha := _pose[b + RigDef.C_ALPHA]
			if _pose[b + RigDef.C_VIS] < 0.5 or alpha <= 0.001:
				LineLimb.collapse(run.pts, vb, LineLimb.QUAD_VERTS)
				continue
			var slot := _slot0[i] + clampi(int(_pose[b + RigDef.C_TEX]), 0, rig.tex_files[i].size() - 1)
			var r := Rect2(-rig.pivot[i] + _slot_rect[slot].position, _slot_rect[slot].size)
			var uv: Rect2 = _slot_uv[slot]
			var col := _part_color(i, alpha)
			var main := _part_xf(i)
			if _smear_t[i] > 0.0:
				var c2 := col
				c2.a *= GHOST_ALPHA_2
				LineLimb.write_quad(_flip(i, _g2[i]), r, uv, c2, run.pts, run.uvs, run.cols, vb)
				var c1 := col
				c1.a *= GHOST_ALPHA_1
				LineLimb.write_quad(_flip(i, _g1[i]), r, uv, c1, run.pts, run.uvs, run.cols, vb + 4)
			else:
				LineLimb.collapse(run.pts, vb, 8)
			LineLimb.write_quad(main, r, uv, col, run.pts, run.uvs, run.cols, vb + 8)


## Part transform with smear stretch and the no_mirror counter-flip (character space).
func _part_xf(p: int) -> Transform2D:
	var xf := _xf[p]
	if _smear_t[p] > 0.0 and _smear_len[p] > 1.001 and _smear_dir[p] != Vector2.ZERO:
		var c := xf * _center[p]
		var d := _smear_dir[p]
		var ln := _smear_len[p]
		var rot := Transform2D(d.angle(), Vector2.ZERO)
		var stretch := Transform2D(Vector2(ln, 0.0), Vector2(0.0, 1.0 / sqrt(ln)), Vector2.ZERO)
		var m := Transform2D(0.0, c) * rot * stretch * rot.affine_inverse() * Transform2D(0.0, -c)
		xf = m * xf
	return _flip(p, xf)


func _flip(p: int, xf: Transform2D) -> Transform2D:
	if rig.no_mirror[p] == 0 or _fsx >= 0.0:
		return xf
	var cx := _center[p].x
	return xf * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(2.0 * cx, 0.0))


func _part_color(p: int, alpha: float) -> Color:
	var col := Color(1, 1, 1, alpha)
	if _tint_tier > 0 and _is_tint[p] == 1 and not rig.tint_tiers.is_empty():
		var t := rig.tint_tiers[mini(_tint_tier, rig.tint_tiers.size() - 1)]
		col = Color(t.r, t.g, t.b, alpha)
	return col


func _draw_part(p: int, cx: Transform2D) -> void:
	var b := RigDef.ROOT_CH + p * RigDef.STRIDE
	var alpha := _pose[b + RigDef.C_ALPHA]
	if _pose[b + RigDef.C_VIS] < 0.5 or alpha <= 0.001:
		return
	var slot := _slot0[p] + clampi(int(_pose[b + RigDef.C_TEX]), 0, rig.tex_files[p].size() - 1)
	var tex: Texture2D = atlas.pages[_slot_page[slot]]
	var r := Rect2(-rig.pivot[p] + _slot_rect[slot].position, _slot_rect[slot].size)
	var region: Rect2 = _slot_region[slot]
	var col := _part_color(p, alpha)
	if _smear_t[p] > 0.0:
		draw_set_transform_matrix(cx * _flip(p, _g2[p]))
		draw_texture_rect_region(tex, r, region, Color(col.r, col.g, col.b, col.a * GHOST_ALPHA_2))
		draw_set_transform_matrix(cx * _flip(p, _g1[p]))
		draw_texture_rect_region(tex, r, region, Color(col.r, col.g, col.b, col.a * GHOST_ALPHA_1))
	draw_set_transform_matrix(cx * _part_xf(p))
	draw_texture_rect_region(tex, r, region, col)


func _draw_overlay(o: int, cx: Transform2D) -> void:
	if _res_on[_ov_res[o]] == 0:
		return
	var p := _ov_part[o]
	var b := RigDef.ROOT_CH + p * RigDef.STRIDE
	if _pose[b + RigDef.C_VIS] < 0.5:
		return
	var slot := _ov_slot[o]
	draw_set_transform_matrix(cx * _part_xf(p))
	draw_texture_rect_region(atlas.pages[_slot_page[slot]], Rect2(-rig.pivot[p] + _slot_rect[slot].position, _slot_rect[slot].size), _slot_region[slot],
		Color(1, 1, 1, _pose[b + RigDef.C_ALPHA]))


func _draw_prop(i: int, cx: Transform2D) -> void:
	if props.mode[i] == PropSim.HIDDEN:
		return
	var pr: RigDef.RigProp = rig.props[i]
	var slot := _prop_slot0[i] + clampi(props.state[i], 0, pr.state_files.size() - 1)
	draw_set_transform_matrix(cx * _prop_xf(i))
	draw_texture_rect_region(atlas.pages[_slot_page[slot]], Rect2(-pr.pivot + _slot_rect[slot].position, _slot_rect[slot].size), _slot_region[slot])


# --- helpers ---------------------------------------------------------------------------------

static func _v2(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


## Deterministic 0..1 from (seed, salt).
static func _hash01(seed: int, salt: int) -> float:
	var x := (seed * 73856093) ^ (salt * 19349663) ^ 0x5bd1e995
	x = (x ^ (x >> 13)) * 0x5bd1e995
	x = x ^ (x >> 15)
	return float(x & 0xFFFF) / 65535.0
