## RigPlayer — plays data-driven clips on a flat-cutout rig (TECH §5.3). One Node2D whose
## parts are RenderingServer canvas items under ONE container item (s2-rig §4.3): each
## textured part records its atlas rect once (again only when its texture variant changes)
## and per frame only its transform is sent — rects on the same atlas page batch into one
## draw call; rubber-hose limbs (and the hands / feet that end them) are one textured
## triangle array per z-run. A character is typically 4–6 draw calls (budget ≤ 12).
## Textures: the base atlas (every part variant, face and prop the everyday look uses) is
## built at setup; each residue look's extra textures (overlays, costume props, residue-only
## variants) are a LAZY look page, built on its first `set_residue` or ahead of time by
## `warm_looks(keys, budget_ms)` (Boot warms the Night's looks under the curtain). Pages carry
## mip chains (LINEAR_WITH_MIPMAPS: no shimmer at the overview's 0.5× or in the PiP).
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

const RC := RigDef.ROOT_CH
const ST := RigDef.STRIDE
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
## Derive combos from residues (rig.json `combos`: all of a combo's residues on → its look). False
## (CharacterView in the game, ruling L4): only an explicit set_residue("COMBO:<id>", true) — the
## sim's `combo` event — shows a combo; SOAKED + FRAZZLED stay two looks where a Night forbids it.
var auto_combos: bool = true:
	set(v):
		auto_combos = v
		if rig != null and not _res_kinds.is_empty():
			_refresh_residues()

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
var _slot_page: PackedInt32Array = PackedInt32Array()  ## global page index (-1 = not built yet)
var _slot_size: PackedVector2Array = PackedVector2Array()
var _slot_rect: Array[Rect2] = []      ## trimmed 1× rect inside the canvas (AtlasSet.draw_rect)
var _slot_draw: Array[Rect2] = []      ## the rect drawn in part space (pivot applied)
var _slot_path: PackedStringArray = PackedStringArray()
var _slot_ready: PackedByteArray = PackedByteArray()
var _path_slots: Dictionary = {}       ## texture path → PackedInt32Array of slots
# Pages: the base atlas + every look page registered so far (global page index).
var _pages: Array[Texture2D] = []
var _page_rid: Array[RID] = []
var _page_set: Array[AtlasSet] = []
var _page_local: PackedInt32Array = PackedInt32Array()
var _sets_in: Dictionary = {}          ## atlas key → true (registered)
var _look_sets: Dictionary = {}        ## residue kind → AtlasSet
var _look_of_path: Dictionary = {}     ## look-only path → residue kind that has it
var _warm_pending: PackedStringArray = PackedStringArray()
var _warm_budget: float = 4.0
var _art_s: float = 2.0
var _tex_override: PackedInt32Array = PackedInt32Array()  ## per part: variant (-1 = none)
var _override_parts: PackedInt32Array = PackedInt32Array()  ## parts with an override
# Render items (RenderingServer canvas items under _ci_root).
var _ci_root: RID = RID()
var _root_xf: Transform2D = Transform2D(0.0, Vector2(9.0, 9.0), 0.0, Vector2.ZERO)
var _part_ci: Array[RID] = []
var _part_rec: PackedInt32Array = PackedInt32Array()
var _part_col: PackedColorArray = PackedColorArray()
var _part_shown: PackedByteArray = PackedByteArray()
var _ghost_ci: Array[RID] = []          ## 2 per part (created on its first smear)
var _ghost_rec: PackedInt32Array = PackedInt32Array()
var _ghost_on: PackedByteArray = PackedByteArray()
var _ov_ci: Array[RID] = []
var _ov_rec: PackedInt32Array = PackedInt32Array()
var _ov_alpha: PackedFloat32Array = PackedFloat32Array()
var _ov_shown: PackedByteArray = PackedByteArray()
var _prop_ci: Array[RID] = []
var _prop_rec: PackedInt32Array = PackedInt32Array()
var _prop_shown: PackedByteArray = PackedByteArray()
var _part_in_seq: PackedByteArray = PackedByteArray()  ## rect part in the last layout
var _part_drawn: PackedByteArray = PackedByteArray()   ## rect part visible this frame
var _item_vi: PackedInt32Array = PackedInt32Array()   ## pose index of the item's vis channel (-1 none)
# What the draw order depends on, as of the last sort (skip the sort while it is unchanged).
var _sig: PackedInt64Array = PackedInt64Array()
var _sig_prev: PackedInt64Array = PackedInt64Array()
var _pm_prev: PackedInt32Array = PackedInt32Array()
var _ps_prev: PackedInt32Array = PackedInt32Array()
var _pst_prev: PackedInt32Array = PackedInt32Array()
var _fo_prev: PackedInt32Array = PackedInt32Array()
var _res_prev: PackedByteArray = PackedByteArray()
var _ovr_prev: PackedInt32Array = PackedInt32Array()
var _static_ver: int = 0
var _slots_ver: int = 0
## Skip the per-frame sort when nothing discrete changed (true in game; tests may turn it off).
static var skip_unchanged_sort: bool = true
var _filter: int = RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR
var _ntex: PackedInt32Array = PackedInt32Array()      ## texture variants per part
var _nomirror: PackedByteArray = PackedByteArray()
var _textured: PackedByteArray = PackedByteArray()
var _part_a: PackedFloat32Array = PackedFloat32Array() ## alpha last sent
var _part_tt: PackedInt32Array = PackedInt32Array()    ## tint tier last sent
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
	## The run as a dynamic 2D mesh: recorded once; per frame only its vertex positions are
	## uploaded (no polygon buffers created / freed every frame). `attr_dirty` = uvs / colours
	## changed (a hand's texture variant, tint, smear ghosts): the mesh is rebuilt.
	var mesh: RID = RID()
	var attr_dirty: bool = true
	var qslot: PackedInt32Array = PackedInt32Array()   ## per item: slot + ghost flag last written
	var qcol: PackedColorArray = PackedColorArray()     ## per item: colour last written
	## Per quad item: what its 12 vertices hold — 0 unknown (write all), 1 main quad written with
	## its ghosts collapsed, 2 all collapsed (hidden). Lets a steady quad write positions only.
	var qstate: PackedByteArray = PackedByteArray()
	## The run's own canvas item (reused with the run across layouts) and its identity.
	var ci: RID = RID()
	var sig: String = ""


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
	var s := HiResTex.resolve_scale(art_scale)
	_art_s = s
	atlas = AtlasBuilder.build(base_atlas_key(p_rig_id, p_skin, s), rig.base_texture_paths(p_skin), s, {}, rig.base_core_count(p_skin))
	_free_items()
	_pages.clear()
	_page_rid.clear()
	_page_set.clear()
	_page_local = PackedInt32Array()
	_sets_in.clear()
	_look_sets.clear()
	_look_of_path.clear()
	_warm_pending = PackedStringArray()
	for kind in rig.residues:
		for lp in rig.look_texture_paths(String(kind), p_skin):
			if not _look_of_path.has(lp):
				_look_of_path[lp] = String(kind)
	var n := rig.names.size()
	_tex_override.resize(n)
	_tex_override.fill(-1)
	_override_parts = PackedInt32Array()
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
	_register_set(atlas)
	RigSampler.solve(rig, _pose, _xf)
	queue_redraw()


## The AtlasBuilder key of a rig's base atlas (shared by every player of that rig / skin /
## scale).
static func base_atlas_key(p_rig_id: String, p_skin: String, s: float) -> String:
	return "rig:%s:%s:%.2f" % [p_rig_id, p_skin, s]


## Start building a rig's base atlas on worker threads (AtlasBuilder.start) so a later setup()
## only waits for it (NightScene starts both characters while it packs the house; s2-fix G #9).
static func start_base(p_rig_id: String, p_skin: String = "", p_art_scale: float = -1.0) -> void:
	var r := RigDef.for_id(p_rig_id)
	if r == null:
		return
	var s := HiResTex.resolve_scale(p_art_scale)
	AtlasBuilder.start(base_atlas_key(p_rig_id, p_skin, s), r.base_texture_paths(p_skin), s, {}, r.base_core_count(p_skin))


## The AtlasBuilder key of a residue look's page.
static func look_atlas_key(p_rig_id: String, p_skin: String, s: float, kind: String) -> String:
	return "rig:%s:%s:%.2f:look:%s" % [p_rig_id, p_skin, s, kind]


## Start building the look pages of `kinds` on worker threads before any player exists (NightScene
## hands its warm list to WorldView, which starts them right after the build's own jobs, so they
## rasterise while the main thread builds nodes; s2-fix G #9). warm_looks() later only polls.
static func start_looks(p_rig_id: String, p_skin: String, kinds: PackedStringArray, p_art_scale: float = -1.0) -> void:
	var r := RigDef.for_id(p_rig_id)
	if r == null:
		return
	var s := HiResTex.resolve_scale(p_art_scale)
	for k in kinds:
		if not r.residues.has(k):
			continue
		var paths := r.look_texture_paths(k, p_skin)
		if not paths.is_empty():
			AtlasBuilder.start(look_atlas_key(p_rig_id, p_skin, s, k), paths, s, {}, 0, {}, false)


## Build the look pages of `keys` (residue kinds: "SOAKED", "COSTUME:jelly_helmet",
## "COMBO:dough_man") ahead of time: rasterisation, packing and page composition run on
## worker threads; this thread only polls (within `budget_ms`) and uploads at most ONE
## finished look page per call (~1–3 ms for a look). Unfinished looks keep warming in the
## following frames' advance() under the same budget, so one call is enough (Boot's warm
## list); calling it every frame until it returns true is fine too. True when every look is
## ready. Looks without extra textures (and unknown kinds) are ready at once.
func warm_looks(keys: PackedStringArray, budget_ms: float = 4.0) -> bool:
	if rig == null:
		return true
	_warm_budget = maxf(0.5, budget_ms)
	for k in keys:
		if not _warm_pending.has(k) and not look_ready(k):
			_warm_pending.append(k)
	return _pump_warm(_warm_budget)


## True when look `kind`'s page is built (or it needs none).
func look_ready(kind: String) -> bool:
	if rig == null or not rig.residues.has(kind):
		return true
	if _look_sets.has(kind):
		return true
	return rig.look_texture_paths(kind, skin).is_empty()


## True when every look of `keys` is ready.
func looks_ready(keys: PackedStringArray) -> bool:
	for k in keys:
		if not look_ready(k):
			return false
	return true


## Texture memory this player's pages hold (bytes; pages shared with other players count).
func texture_memory_bytes() -> int:
	var b := 0
	for k in _sets_in:
		var st: AtlasSet = AtlasBuilder.get_set(String(k))
		if st != null:
			b += st.memory_bytes()
	return b


## A persistent texture variant for one part ("" clears): the view's temper sideburns and the
## BLINDED bouffant. It beats residue swaps; a clip's explicit tex key beats it.
func set_part_texture(part: String, variant: String) -> void:
	if rig == null:
		return
	var i := rig.idx(part)
	if i < 0:
		return
	_tex_override[i] = rig.tex_index(i, variant) if variant != "" else -1
	_override_parts = PackedInt32Array()
	for q in _tex_override.size():
		if _tex_override[q] >= 0:
			_override_parts.append(q)
	if _tex_override[i] >= 0:
		_ensure_slot(_slot0[i] + _tex_override[i])


func _pump_warm(budget_ms: float) -> bool:
	if _warm_pending.is_empty():
		return true
	var t0 := Time.get_ticks_usec()
	var i := 0
	while i < _warm_pending.size():
		var k := _warm_pending[i]
		if look_ready(k):
			_warm_pending.remove_at(i)
			continue
		var left := budget_ms - float(Time.get_ticks_usec() - t0) / 1000.0
		if left <= 0.0:
			break
		var key := look_atlas_key(rig_id, skin, _art_s, k)
		if AtlasBuilder.warm(key, rig.look_texture_paths(k, skin), maxi(1, int(left)), _art_s):
			_attach_look(k, AtlasBuilder.get_set(key))
			_warm_pending.remove_at(i)
			break   # at most one page upload per call
		i += 1
	return _warm_pending.is_empty()


## Build look `kind`'s page now (blocking) when it is missing — its first set_residue.
func _ensure_look(kind: String) -> void:
	if look_ready(kind):
		return
	var key := look_atlas_key(rig_id, skin, _art_s, kind)
	var st := AtlasBuilder.get_set(key)
	if st == null:
		st = AtlasBuilder.build(key, rig.look_texture_paths(kind, skin), _art_s)
	_attach_look(kind, st)
	_warm_pending.erase(kind)


func _attach_look(kind: String, st: AtlasSet) -> void:
	if st == null:
		return
	_look_sets[kind] = st
	_register_set(st)


## A slot whose texture is on a look page not built yet: build that look now.
func _ensure_slot(slot: int) -> void:
	if slot < 0 or slot >= _slot_ready.size() or _slot_ready[slot] == 1:
		return
	var kind := String(_look_of_path.get(_slot_path[slot], ""))
	if kind != "":
		_ensure_look(kind)
	if _slot_ready[slot] == 0:
		_slot_ready[slot] = 2   # missing from every set: draw nothing, stop asking


## Add an atlas set's pages to the player and fill every slot whose texture it holds.
func _register_set(st: AtlasSet) -> void:
	if st == null or _sets_in.has(st.key):
		return
	_sets_in[st.key] = true
	var g0 := _pages.size()
	for pi in st.pages.size():
		_pages.append(st.pages[pi])
		_page_rid.append(st.pages[pi].get_rid())
		_page_set.append(st)
		_page_local.append(pi)
	for q in st.paths():
		var slots: Variant = _path_slots.get(q, null)
		if slots == null:
			continue
		for sl in slots:
			if _slot_ready[sl] == 1:
				continue
			_slot_region[sl] = st.region(q)
			_slot_uv[sl] = st.uv_rect(q)
			_slot_page[sl] = g0 + maxi(0, st.page_index(q))
			if _slot_size[sl] == Vector2.ZERO:
				_slot_size[sl] = st.size_1x(q)
			_slot_rect[sl] = st.draw_rect(q)
			_slot_draw[sl] = Rect2(_slot_draw[sl].position + _slot_rect[sl].position, _slot_rect[sl].size)
			_slot_ready[sl] = 1
	# Re-record every item (a slot may have become drawable) and re-layout (run pages).
	_slots_ver += 1
	for r in _runs:
		r.qslot.fill(-1)
		r.qstate.fill(0)
		r.attr_dirty = true
	_part_rec.fill(-1)
	_prop_rec.fill(-1)
	_ov_rec.fill(-1)
	_layout_dirty = true
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
## Calling it every frame with the same direction is a no-op: a running turn finishes and
## only a new direction restarts it. `animate = false` snaps (and ends a running turn).
func set_facing(dir: int, animate: bool = true) -> void:
	var d := 1 if dir >= 0 else -1
	if d == _facing and (animate or _turn_t < 0.0):
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
		if res.combo_of.is_empty() or not auto_combos:
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
	for i4 in _res_kinds.size():
		if on[i4] == 1 and _res_on[i4] == 0:
			_ensure_look(_res_kinds[i4])   # lazy: the look's page is built on first use
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
	_static_ver += 1
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
	if profiling:
		var a0 := Time.get_ticks_usec()
		var before := prof[0] + prof[1] + prof[2] + prof[3]
		_advance(dt)
		prof[8] += Time.get_ticks_usec() - a0 - (prof[0] + prof[1] + prof[2] + prof[3] - before)
		return
	_advance(dt)


func _advance(dt: float) -> void:
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
	if not _warm_pending.is_empty():
		_pump_warm(_warm_budget)
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
			_smearing = true   # history + countdown run even on clips without smear.auto
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
	var t0 := Time.get_ticks_usec() if profiling else 0
	_prop_frame += vdt * 60.0
	# 1. base (+ crossfade)
	if _plan != null:
		if _from_plan != null or _from_snap:
			_plan.sample(_frame, _a)
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
			_plan.sample(_frame, _pose)   # straight into the pose: no copy
			_fade_w = 1.0
		_track_face_keys()
	elif _static.size() == _pose.size():
		RigSampler.copy(_static, _pose)
	else:
		RigSampler.copy(rig.rest, _pose)
	var t1 := Time.get_ticks_usec() if profiling else 0
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
	# 6. part texture overrides (set_part_texture), then residue textures — each only over a
	#    part's default texture (a clip's explicit swap wins) — and face overlays (sweat,
	#    singe…) shown while the residue is on.
	for tp in _override_parts:
		var tb := RigDef.ROOT_CH + tp * RigDef.STRIDE + RigDef.C_TEX
		if _pose[tb] == rig.rest[tb]:
			_pose[tb] = float(_tex_override[tp])
	for r in _res_kinds.size():
		if _res_on[r] == 0:
			continue
		var res: RigDef.RigResidue = rig.residues[_res_kinds[r]]
		for k in res.tex_part.size():
			var b := RigDef.ROOT_CH + res.tex_part[k] * RigDef.STRIDE + RigDef.C_TEX
			if _pose[b] == rig.rest[b]:
				_pose[b] = float(res.tex_var[k])
		for fs in res.face_slots:
			var fb := RigDef.ROOT_CH + rig.face_slot_part[fs] * RigDef.STRIDE
			_pose[fb + RigDef.C_VIS] = 1.0
	var t2 := Time.get_ticks_usec() if profiling else 0
	# 7. springs (driven by last frame's motion), 8. limits, 9. FK
	if springs_enabled:
		springs.step(vdt)
		springs.apply(_pose)
	if clamp_to_limits:
		RigSampler.clamp_limits(rig, _pose)
	RigSampler.solve(rig, _pose, _xf)
	if springs_enabled:
		springs.feed(_xf, global_position, _fsx, vdt)
	var t3 := Time.get_ticks_usec() if profiling else 0
	# 11. smear history
	_update_smears(vdt * 60.0)
	if profiling:
		var t4 := Time.get_ticks_usec()
		prof[0] += t1 - t0
		prof[1] += t2 - t1
		prof[2] += t3 - t2
		prof[3] += t4 - t3


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
	# History by whole arrays (no per-part copies): ghost 2 ← ghost 1 ← last frame ← now.
	if _hist > 0:
		var spare := _g2
		var g1_old := _g1
		if _hist > 1:
			_g2 = g1_old
			_g1 = _last_xf
			_last_xf = spare
		else:
			spare.assign(_last_xf)
			_g2 = spare
			_g1 = _last_xf
			_last_xf = g1_old
		_last_xf.assign(_xf)
	else:
		_g1.assign(_xf)
		_g2.assign(_xf)
		_last_xf.assign(_xf)
	var detect := auto and _hist > 0 and df > 0.25 and df < 2.5
	for p in n:
		if _smear_t[p] > 0.0:
			_smear_t[p] = maxf(0.0, _smear_t[p] - frames)
			_smearing = true
		if _textured[p] == 0:
			continue
		var cur := _xf[p]
		var c := cur * _center[p]
		var rot := cur.get_rotation()
		if detect:
			var mv := c - _last_c[p]
			var v := mv.length() / df
			var av := absf(rad_to_deg(wrapf(rot - _last_rot[p], -PI, PI))) / df
			if v > SMEAR_PX or av > SMEAR_ROT:
				_smear_t[p] = SMEAR_FRAMES
				_smear_dir[p] = mv / mv.length() if v > SMEAR_PX else Vector2.ZERO
				_smear_len[p] = clampf(1.0 + v / 80.0, 1.0, 2.0) if v > SMEAR_PX else 1.0
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
	# Limb colours are baked into the runs' static arrays: rebuild the runs.
	_free_runs()
	_runs.clear()
	_keys_prev.resize(0)
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
	_slot_draw.clear()
	_slot_path = PackedStringArray()
	_slot_ready = PackedByteArray()
	_path_slots.clear()
	_center.resize(n)
	_tri_part.resize(n)
	_tri_part.fill(0)
	var add_slot := func(path: String, size_1x: Vector2, pivot: Vector2) -> void:
		var q := rig.skin_path(path, skin)
		var sl := _slot_region.size()
		_slot_region.append(Rect2())
		_slot_uv.append(Rect2())
		_slot_page.append(-1)
		_slot_size.append(size_1x)
		_slot_rect.append(Rect2())
		_slot_draw.append(Rect2(-pivot, Vector2.ZERO))
		_slot_path.append(q)
		_slot_ready.append(0)
		if not _path_slots.has(q):
			_path_slots[q] = PackedInt32Array()
		var arr: PackedInt32Array = _path_slots[q]
		arr.append(sl)
		_path_slots[q] = arr
	for p in n:
		_slot0[p] = _slot_region.size()
		var files: PackedStringArray = rig.tex_files[p]
		var sizes: PackedVector2Array = rig.tex_sizes[p]
		for v in files.size():
			add_slot.call(files[v], sizes[v], rig.pivot[p])
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
			add_slot.call(res.overlay_file[k], res.overlay_size[k], rig.pivot[res.overlay_part[k]])
	_prop_slot0 = PackedInt32Array()
	for pr in rig.props:
		var prd: RigDef.RigProp = pr
		_prop_slot0.append(_slot_region.size())
		for k2 in prd.state_files.size():
			add_slot.call(prd.state_files[k2], prd.state_sizes[k2], prd.pivot)
	_is_tint.resize(n)
	_is_tint.fill(0)
	for tp in rig.tint_parts:
		_is_tint[tp] = 1
	_ntex.resize(n)
	_nomirror.resize(n)
	_textured.resize(n)
	for q in n:
		_ntex[q] = maxi(1, rig.tex_files[q].size())
		_nomirror[q] = rig.no_mirror[q]
		_textured[q] = 1 if rig.is_textured(q) else 0
	_curve.resize(LineLimb.SAMPLES)
	_build_items()
	_rebuild_items()
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
	# z / vis sources per item: pose indices (props: -1, computed by _item_z / props.mode).
	_item_zi.resize(_items.size())
	_item_zo.resize(_items.size())
	_item_vi.resize(_items.size())
	for k in _items.size():
		var code := _items[k]
		var kind := code >> 16
		var i := code & 0xFFFF
		_item_zo[k] = 0
		match kind:
			K_LIMB:
				var lb: RigDef.RigLimb = rig.limbs[i]
				_item_zi[k] = RigDef.ch(lb.joints[0], RigDef.C_Z) if not lb.joints.is_empty() else -1
				_item_vi[k] = RigDef.ch(lb.joints[0], RigDef.C_VIS) if not lb.joints.is_empty() else -1
			K_PART:
				_item_zi[k] = RigDef.ch(i, RigDef.C_Z)
				_item_vi[k] = RigDef.ch(i, RigDef.C_VIS)
			K_OVERLAY:
				_item_zi[k] = RigDef.ch(_ov_part[i], RigDef.C_Z)
				_item_vi[k] = RigDef.ch(_ov_part[i], RigDef.C_VIS)
			_:
				_item_zi[k] = -1
				_item_vi[k] = -1
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


## Sort keys (z << 18 | item code; hidden items last) — the layout is rebuilt only when they
## change. A drawn part whose texture sits on a look page not built yet builds it here.
func _sort_items() -> void:
	var n := _items.size()
	for k in n:
		var code := _items[k]
		var kind := code >> 16
		var vi := _item_vi[k]
		var drawn := true
		if kind == K_PART:
			var p := code & 0xFFFF
			drawn = _pose[vi] >= 0.5 and _pose[vi + 1] > 0.001
			if drawn:
				var tv := int(_pose[vi - 1])
				var nt := _ntex[p]
				var sl := _slot0[p] + (0 if tv < 0 else (tv if tv < nt else nt - 1))
				if _slot_ready[sl] != 1:
					_ensure_slot(sl)
					drawn = _slot_ready[sl] == 1
			if _tri_part[p] == 0:
				_part_drawn[p] = 1 if drawn else 0
				# A rect part that blinks off stays in the layout (hidden, not re-laid-out).
				if not drawn and _part_in_seq[p] == 1:
					drawn = true
		elif kind == K_PROP:
			drawn = props.mode[code & 0xFFFF] != PropSim.HIDDEN
		elif vi >= 0:
			drawn = _pose[vi] >= 0.5
		if not drawn:
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


## True when nothing the draw order depends on changed since the last sort: the base / overlay
## key segments (discrete channels step only on keys), crossfades, the face overrides and blink
## phase, props, residues, texture overrides, static pose and page registrations. Anything
## continuous that could hide a part (animated alpha, a crossfade, an additive layer) → false.
func _discrete_same() -> bool:
	if _layout_dirty or _ad.plan != null or _from_plan != null or _from_snap:
		return false
	_sig.resize(12)
	if _plan == null:
		_sig[0] = -1
		_sig[1] = _static_ver
	else:
		if _plan.in_tail(_frame):
			var tt := _frame - float(_plan.tail_start)
			if tt < float(_plan.tail_blend) or _plan.tail.live_alpha():
				return false
			_sig[1] = (1 << 32) + _plan.tail.segment_at(tt)
		else:
			if _plan.clip.live_alpha():
				return false
			_sig[1] = _plan.clip.segment_at(_plan.src_frame(_frame))
		_sig[0] = _plan.get_instance_id()
	if not _layer_sig(_ov, 2) or not _layer_sig(_ov_prev, 4):
		return false
	_sig[6] = face.blink_phase() * 2 + (1 if face.suppressed else 0)
	_sig[7] = _slots_ver
	_sig[8] = 0
	var same := _sig == _sig_prev
	if face._override != _fo_prev:
		_fo_prev = face._override.duplicate()
		same = false
	if props.mode != _pm_prev or props.socket != _ps_prev or props.state != _pst_prev:
		_pm_prev = props.mode.duplicate()
		_ps_prev = props.socket.duplicate()
		_pst_prev = props.state.duplicate()
		same = false
	if _res_on != _res_prev:
		_res_prev = _res_on.duplicate()
		same = false
	if _tex_override != _ovr_prev:
		_ovr_prev = _tex_override.duplicate()
		same = false
	if not same:
		_sig_prev = _sig.duplicate()
	return same


## An overlay layer's part of the signature at `_sig[at]`, `_sig[at + 1]`; false when it can
## change visibility continuously (animated alpha).
func _layer_sig(ly: _Layer, at: int) -> bool:
	if ly.plan != null and ly.w > 0.0:
		if ly.plan.clip.live_alpha():
			return false
		_sig[at] = ly.plan.get_instance_id()
		_sig[at + 1] = ly.plan.clip.segment_at(ly.frame) * 2 + (1 if ly.weight() >= 0.5 else 0)
	else:
		_sig[at] = 0
		_sig[at + 1] = 0
	return true


## Atlas page (global index) of part `p`'s current texture variant (-1 = not built).
func _cur_page(p: int) -> int:
	var b := RigDef.ROOT_CH + p * RigDef.STRIDE
	return _slot_page[_slot0[p] + clampi(int(_pose[b + RigDef.C_TEX]), 0, rig.tex_files[p].size() - 1)]


## Cumulative CPU time spent in _draw() (the render sync) by every RigPlayer (µs) and draw
## count — perf logs.
static var draw_us: int = 0
static var draw_count: int = 0
## Per-section CPU µs of every player since the last reset (RigPerf --breakdown): sample,
## layers+face+residues, springs+limits+FK, smears, sort, layout, parts, limb runs, advance
## overhead. Off unless `profiling`.
static var profiling: bool = false
static var prof: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
const PROF_NAMES: PackedStringArray = ["sample", "layers+face", "springs+FK", "smears", "sort", "layout", "parts", "limb runs", "advance other"]


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_items()


## The node's own canvas item draws nothing: _draw is the per-frame render sync that sends
## the parts' transforms / textures / colours to their canvas items.
func _draw() -> void:
	if rig == null or _pages.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	_sync_render()
	draw_us += Time.get_ticks_usec() - t0
	draw_count += 1


# --- render items ------------------------------------------------------------------------------

## Create the container and one canvas item per textured part and prop (overlays, ghosts and
## runs are created on first use). Every item uses the node's material and draws with the
## atlas filter (LINEAR_WITH_MIPMAPS when the pages have mips).
func _build_items() -> void:
	_free_items()
	var n := rig.names.size()
	_filter = RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if atlas != null and atlas.mipmaps else RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	_ci_root = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_ci_root, get_canvas_item())
	RenderingServer.canvas_item_set_draw_index(_ci_root, -1)
	RenderingServer.canvas_item_set_use_parent_material(_ci_root, true)
	RenderingServer.canvas_item_set_visibility_layer(_ci_root, visibility_layer)
	_root_xf = Transform2D(0.0, Vector2(9.0, 9.0), 0.0, Vector2.ZERO)
	_part_ci.resize(n)
	_part_rec.resize(n)
	_part_rec.fill(-1)
	_part_col.resize(n)
	_part_col.fill(Color(-1, -1, -1, -1))
	_part_a.resize(n)
	_part_a.fill(-1.0)
	_part_tt.resize(n)
	_part_tt.fill(-1)
	_part_shown.resize(n)
	_part_shown.fill(0)
	_ghost_ci.resize(n * 2)
	_ghost_ci.fill(RID())
	_ghost_rec.resize(n)
	_ghost_rec.fill(-1)
	_ghost_on.resize(n)
	_ghost_on.fill(0)
	for p in n:
		_part_ci[p] = _new_item() if rig.is_textured(p) and _tri_part[p] == 0 else RID()
	_ov_ci.resize(_ov_part.size())
	_ov_ci.fill(RID())
	_ov_rec.resize(_ov_part.size())
	_ov_rec.fill(-1)
	_ov_alpha.resize(_ov_part.size())
	_ov_alpha.fill(-1.0)
	_ov_shown.resize(_ov_part.size())
	_ov_shown.fill(0)
	_prop_ci.resize(rig.props.size())
	_prop_rec.resize(rig.props.size())
	_prop_rec.fill(-1)
	_prop_shown.resize(rig.props.size())
	_prop_shown.fill(0)
	for pi in rig.props.size():
		_prop_ci[pi] = _new_item()
	_part_in_seq.resize(n)
	_part_in_seq.fill(0)
	_part_drawn.resize(n)
	_part_drawn.fill(0)


func _new_item() -> RID:
	var ci := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(ci, _ci_root)
	RenderingServer.canvas_item_set_use_parent_material(ci, true)
	RenderingServer.canvas_item_set_default_texture_filter(ci, _filter)
	RenderingServer.canvas_item_set_visibility_layer(ci, visibility_layer)
	RenderingServer.canvas_item_set_visible(ci, false)
	return ci


func _free_items() -> void:
	_free_runs()
	for arr in [_part_ci, _ghost_ci, _ov_ci, _prop_ci]:
		for r in arr:
			if (r as RID).is_valid():
				RenderingServer.free_rid(r)
	_part_ci.clear()
	_ghost_ci.clear()
	_ov_ci.clear()
	_prop_ci.clear()
	_runs.clear()
	if _ci_root.is_valid():
		RenderingServer.free_rid(_ci_root)
	_ci_root = RID()


func _set_shown(ci: RID, flags: PackedByteArray, i: int, on: bool) -> void:
	var v := 1 if on else 0
	if flags[i] != v:
		flags[i] = v
		RenderingServer.canvas_item_set_visible(ci, on)


## Record slot `slot`'s atlas rect into canvas item `ci` (once per texture change).
func _record(ci: RID, slot: int) -> void:
	RenderingServer.canvas_item_clear(ci)
	if slot >= 0 and _slot_ready[slot] == 1:
		RenderingServer.canvas_item_add_texture_rect_region(ci, _slot_draw[slot], _page_rid[_slot_page[slot]], _slot_region[slot])


## Per frame: sort, re-layout when the z order changed, then per item one transform (and a
## colour / texture only when they change); limb runs rebuild their triangles.
func _sync_render() -> void:
	var t0 := Time.get_ticks_usec() if profiling else 0
	if not skip_unchanged_sort or not _discrete_same():
		_sort_items()
	var t1 := Time.get_ticks_usec() if profiling else 0
	if _layout_dirty:
		_rebuild_layout()
	var t2 := Time.get_ticks_usec() if profiling else 0
	var run_us := 0
	var cx := _char_xf()
	if cx != _root_xf:
		_root_xf = cx
		RenderingServer.canvas_item_set_transform(_ci_root, cx)
	for code in _seq:
		var kind := code >> 16
		var i := code & 0xFFFF
		if kind == K_PART:
			if _part_drawn[i] == 1:
				_set_shown(_part_ci[i], _part_shown, i, true)
				_sync_part(i)
			else:
				_set_shown(_part_ci[i], _part_shown, i, false)
				if _ghost_on[i] == 1:
					_hide_ghosts(i)
		elif kind == K_RUN:
			var r0 := Time.get_ticks_usec() if profiling else 0
			var run: _Run = _runs[i]
			_fill_run(run, Transform2D.IDENTITY)
			_submit_run(run, run.ci)
			if profiling:
				run_us += Time.get_ticks_usec() - r0
		elif kind == K_OVERLAY:
			_sync_overlay(i)
		elif kind == K_PROP:
			_sync_prop(i)
	if profiling:
		var t3 := Time.get_ticks_usec()
		prof[4] += t1 - t0
		prof[5] += t2 - t1
		prof[6] += t3 - t2 - run_us
		prof[7] += run_us


## Limb runs draw as dynamic meshes (true) or as per-frame triangle arrays (false: the Stage-1
## path, kept for comparison).
static var mesh_runs: bool = true
const RUN_AABB := AABB(Vector3(-4000.0, -6000.0, -1.0), Vector3(8000.0, 8000.0, 2.0))


## Send a run to its canvas item: positions only when the mesh is current, else rebuild it.
func _submit_run(run: _Run, rci: RID) -> void:
	if not mesh_runs:
		RenderingServer.canvas_item_clear(rci)
		RenderingServer.canvas_item_add_triangle_array(rci, run.idx, run.pts, run.cols, run.uvs, _empty_i, _empty_f, _page_rid[run.page])
		return
	if run.mesh.is_valid() and not run.attr_dirty:
		RenderingServer.mesh_surface_update_vertex_region(run.mesh, 0, 0, run.pts.to_byte_array())
		return
	if not run.mesh.is_valid():
		run.mesh = RenderingServer.mesh_create()
	else:
		RenderingServer.mesh_clear(run.mesh)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = run.pts
	arrays[Mesh.ARRAY_COLOR] = run.cols
	arrays[Mesh.ARRAY_TEX_UV] = run.uvs
	arrays[Mesh.ARRAY_INDEX] = run.idx
	RenderingServer.mesh_add_surface_from_arrays(run.mesh, RenderingServer.PRIMITIVE_TRIANGLES, arrays, [], {},
		RenderingServer.ARRAY_FLAG_USE_2D_VERTICES | RenderingServer.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	RenderingServer.mesh_set_custom_aabb(run.mesh, RUN_AABB)
	RenderingServer.canvas_item_clear(rci)
	RenderingServer.canvas_item_add_mesh(rci, run.mesh, Transform2D.IDENTITY, Color.WHITE, _page_rid[run.page])
	run.attr_dirty = false


func _free_runs() -> void:
	for run in _runs:
		_free_run(run)


func _free_run(run: _Run) -> void:
	if run.mesh.is_valid():
		RenderingServer.free_rid(run.mesh)
		run.mesh = RID()
	if run.ci.is_valid():
		RenderingServer.free_rid(run.ci)
		run.ci = RID()


func _sync_part(p: int) -> void:
	var b := RC + p * ST
	var tv := int(_pose[b + RigDef.C_TEX])
	var nt := _ntex[p]
	var slot := _slot0[p] + (0 if tv < 0 else (tv if tv < nt else nt - 1))
	var ci := _part_ci[p]
	if slot != _part_rec[p]:
		_record(ci, slot)
		_part_rec[p] = slot
	var a := _pose[b + RigDef.C_ALPHA]
	var tt := _tint_tier if _is_tint[p] == 1 else 0
	if a != _part_a[p] or tt != _part_tt[p]:
		_part_a[p] = a
		_part_tt[p] = tt
		_part_col[p] = _part_color(p, a)
		RenderingServer.canvas_item_set_self_modulate(ci, _part_col[p])
	if _smear_t[p] > 0.0:
		RenderingServer.canvas_item_set_transform(ci, _part_xf(p))
		_sync_ghosts(p, slot, _part_col[p])
		return
	if _ghost_on[p] == 1:
		_hide_ghosts(p)
	if _nomirror[p] == 0 or _fsx >= 0.0:
		RenderingServer.canvas_item_set_transform(ci, _xf[p])
	else:
		RenderingServer.canvas_item_set_transform(ci, _flip(p, _xf[p]))


## The two smear ghosts of part `p` (previous transforms, alpha 0.25 / 0.45), just under it.
func _sync_ghosts(p: int, slot: int, col: Color) -> void:
	var g2 := _ghost_ci[p * 2]
	if not g2.is_valid():
		g2 = _new_item()
		_ghost_ci[p * 2] = g2
		_ghost_ci[p * 2 + 1] = _new_item()
		_layout_dirty = true   # draw indices next frame
	var g1 := _ghost_ci[p * 2 + 1]
	if _ghost_rec[p] != slot:
		_ghost_rec[p] = slot
		_record(g2, slot)
		_record(g1, slot)
	RenderingServer.canvas_item_set_transform(g2, _flip(p, _g2[p]))
	RenderingServer.canvas_item_set_transform(g1, _flip(p, _g1[p]))
	RenderingServer.canvas_item_set_self_modulate(g2, Color(col.r, col.g, col.b, col.a * GHOST_ALPHA_2))
	RenderingServer.canvas_item_set_self_modulate(g1, Color(col.r, col.g, col.b, col.a * GHOST_ALPHA_1))
	if _ghost_on[p] == 0:
		_ghost_on[p] = 1
		RenderingServer.canvas_item_set_visible(g2, true)
		RenderingServer.canvas_item_set_visible(g1, true)


func _hide_ghosts(p: int) -> void:
	_ghost_on[p] = 0
	if _ghost_ci[p * 2].is_valid():
		RenderingServer.canvas_item_set_visible(_ghost_ci[p * 2], false)
		RenderingServer.canvas_item_set_visible(_ghost_ci[p * 2 + 1], false)


func _sync_overlay(o: int) -> void:
	var ci := _ov_ci[o]
	var slot := _ov_slot[o]
	if _ov_rec[o] != slot:
		_ov_rec[o] = slot
		_record(ci, slot)
	var p := _ov_part[o]
	var a := _pose[RigDef.ROOT_CH + p * RigDef.STRIDE + RigDef.C_ALPHA]
	if a != _ov_alpha[o]:
		_ov_alpha[o] = a
		RenderingServer.canvas_item_set_self_modulate(ci, Color(1, 1, 1, a))
	RenderingServer.canvas_item_set_transform(ci, _part_xf(p))


func _sync_prop(i: int) -> void:
	var pr: RigDef.RigProp = rig.props[i]
	var slot := _prop_slot0[i] + clampi(props.state[i], 0, pr.state_files.size() - 1)
	if _slot_ready[slot] != 1:
		_ensure_slot(slot)
	var ci := _prop_ci[i]
	if _prop_rec[i] != slot:
		_prop_rec[i] = slot
		_record(ci, slot)
	RenderingServer.canvas_item_set_transform(ci, _prop_xf(i))


func _rebuild_layout() -> void:
	_layout_dirty = false
	_keys_prev = _keys.duplicate()
	for tp in _tri_list:
		_tri_pg[tp] = _cur_page(tp)
	_seq = PackedInt32Array()
	var old := {}
	for r0 in _runs:
		old[r0.sig] = r0
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
	# Runs whose page and items did not change keep their mesh and canvas item.
	for ri in _runs.size():
		var nr: _Run = _runs[ri]
		if nr.page < 0:
			nr.page = 0
		nr.sig = "%d|%s" % [nr.page, nr.items]
		var prev: _Run = old.get(nr.sig, null)
		if prev != null:
			old.erase(nr.sig)
			_runs[ri] = prev
	for gone in old.values():
		_free_run(gone)
	for run in _runs:
		if run.ci.is_valid():
			continue
		run.ci = _new_item()
		RenderingServer.canvas_item_set_visible(run.ci, true)
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
		run.qslot.resize(run.items.size())
		run.qslot.fill(-1)
		run.qcol.resize(run.items.size())
		run.qcol.fill(Color(-1, -1, -1, -1))
		run.qstate.resize(run.items.size())
		run.qstate.fill(0)
		run.attr_dirty = true
		var w := 0
		var line_uv := _page_set[run.page].builtin_uv(AtlasSet.LINE, _page_local[run.page])
		var disc_uv := _page_set[run.page].builtin_uv(AtlasSet.DISC, _page_local[run.page])
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
	_apply_layout()


## Draw order (draw index = sequence position; ghosts just under their part) and visibility of
## every canvas item for the new layout.
func _apply_layout() -> void:
	var want_part := PackedByteArray()
	want_part.resize(_part_ci.size())
	var want_ov := PackedByteArray()
	want_ov.resize(_ov_ci.size())
	var want_prop := PackedByteArray()
	want_prop.resize(_prop_ci.size())
	for k in _seq.size():
		var code := _seq[k]
		var kind := code >> 16
		var i := code & 0xFFFF
		var di := k * 4 + 3
		match kind:
			K_PART:
				want_part[i] = 1
				RenderingServer.canvas_item_set_draw_index(_part_ci[i], di)
				if _ghost_ci[i * 2].is_valid():
					RenderingServer.canvas_item_set_draw_index(_ghost_ci[i * 2], di - 2)
					RenderingServer.canvas_item_set_draw_index(_ghost_ci[i * 2 + 1], di - 1)
			K_RUN:
				RenderingServer.canvas_item_set_draw_index((_runs[i] as _Run).ci, di)
			K_OVERLAY:
				if not _ov_ci[i].is_valid():
					_ov_ci[i] = _new_item()
				want_ov[i] = 1
				RenderingServer.canvas_item_set_draw_index(_ov_ci[i], di)
			K_PROP:
				want_prop[i] = 1
				RenderingServer.canvas_item_set_draw_index(_prop_ci[i], di)
	for p in _part_ci.size():
		_part_in_seq[p] = want_part[p]
		if _part_ci[p].is_valid():
			_set_shown(_part_ci[p], _part_shown, p, want_part[p] == 1 and _part_drawn[p] == 1)
			if want_part[p] == 0 and _ghost_on[p] == 1:
				_hide_ghosts(p)
	for o in _ov_ci.size():
		if _ov_ci[o].is_valid():
			_set_shown(_ov_ci[o], _ov_shown, o, want_ov[o] == 1)
	for pi in _prop_ci.size():
		_set_shown(_prop_ci[pi], _prop_shown, pi, want_prop[pi] == 1)


func _fill_run(run: _Run, cx: Transform2D) -> void:
	var pose := _pose
	var ident := cx == Transform2D.IDENTITY
	for j in run.items.size():
		var code := run.items[j]
		var i := code & 0xFFFF
		var vb := run.vbase[j]
		if (code >> 16) == K_LIMB:
			var lb: RigDef.RigLimb = rig.limbs[i]
			var jn := lb.joints.size()
			if _joints.size() < jn:
				_joints.resize(jn)
			if pose[RigDef.ROOT_CH + lb.joints[0] * RigDef.STRIDE + RigDef.C_VIS] <= 0.5:
				LineLimb.collapse(run.pts, vb, LineLimb.VERTS)
				continue
			for k in jn:
				_joints[k] = _xf[lb.joints[k]].origin
			if ident:
				LineLimb.write_limb(_joints, jn, lb.width * 0.5 + lb.outline, lb.width * 0.5, run.pts, vb, _curve)
			else:
				LineLimb.curve(_joints, jn, _curve)
				LineLimb.write_positions(_curve, lb.width * 0.5 + lb.outline, lb.width * 0.5, cx, run.pts, vb)
		else:
			var b := RigDef.ROOT_CH + i * RigDef.STRIDE
			var alpha := pose[b + RigDef.C_ALPHA]
			if pose[b + RigDef.C_VIS] < 0.5 or alpha <= 0.001:
				if run.qstate[j] != 2:
					LineLimb.collapse(run.pts, vb, LineLimb.QUAD_VERTS)
					run.qstate[j] = 2
				continue
			var slot := _slot0[i] + clampi(int(pose[b + RigDef.C_TEX]), 0, rig.tex_files[i].size() - 1)
			var r: Rect2 = _slot_draw[slot]
			var col := _part_color(i, alpha)
			var smear := _smear_t[i] > 0.0
			var qk := slot * 2 + (1 if smear else 0)
			var attrs := qk != run.qslot[j] or col != run.qcol[j]
			if attrs:
				run.qslot[j] = qk
				run.qcol[j] = col
				run.attr_dirty = true
			if smear:
				var uv: Rect2 = _slot_uv[slot]
				var c2 := col
				c2.a *= GHOST_ALPHA_2
				LineLimb.write_quad(_flip(i, _g2[i]), r, uv, c2, run.pts, run.uvs, run.cols, vb)
				var c1 := col
				c1.a *= GHOST_ALPHA_1
				LineLimb.write_quad(_flip(i, _g1[i]), r, uv, c1, run.pts, run.uvs, run.cols, vb + 4)
				LineLimb.write_quad(_part_xf(i), r, uv, col, run.pts, run.uvs, run.cols, vb + 8)
				run.qstate[j] = 0
				continue
			# Steady quad (the common case): positions only; uvs / colours only when they changed.
			var main := _xf[i] if _nomirror[i] == 0 or _fsx >= 0.0 else _flip(i, _xf[i])
			if attrs or run.qstate[j] != 1:
				LineLimb.collapse(run.pts, vb, 8)
				LineLimb.write_quad(main, r, _slot_uv[slot], col, run.pts, run.uvs, run.cols, vb + 8)
				run.qstate[j] = 1
			else:
				LineLimb.write_quad_pos(main, r, run.pts, vb + 8)


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
	if _tint_tier > 0 and _is_tint[p] == 1 and not rig.tint_tiers.is_empty():
		var t := rig.tint_tiers[mini(_tint_tier, rig.tint_tiers.size() - 1)]
		return Color(t.r, t.g, t.b, alpha)
	return Color(1, 1, 1, alpha)


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
