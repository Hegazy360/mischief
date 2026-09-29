## GagStager — turns the sim's comedy events into staging (GDD §2.1 payoff row, §3.7 Gag-Cam,
## §9.3, comedy.md §2): the camera cuts focus to Bellows at `reaction_start`, pushes in
## gently through the anticipation, PUNCHES in on `reaction_accent` together with the
## hit-stop, shake and kick, pops the pun caption and the right particles, holds on his face,
## and eases back. Signatures and chain finales (link ≥ 4) end in a freeze-frame; T3 drops a
## prop on his head 20 f after the accent; first-time pranks get the 0.5× approach slow-mo
## over their last 24 frames. It also runs the PiP visibility rule and the Director's safety
## slow-mo. When a RigPlayer clip carries its own `cam` / `hitstop` / `shake` events, those
## drive the camera instead of the synthetic accent (no double hits).
##
## Wiring (NightScene / ViewSandbox): `setup(driver, camera, world_view, pip)`; it connects to
## `driver.ticked` and to both CharacterViews' `clip_event`.
class_name GagStager
extends Node

const TIMERS := 12
const HEAD_UP := 40.0
## Particle bursts per archetype: [[kind, amount, where ("head" | "feet" | "mid")], …].
const ARCHETYPE_FX := {
	"sneeze_blast": [["steam", 14, "head"], ["drops", 18, "head"]],
	"drench": [["drops", 40, "head"]],
	"sing_crack": [["notes", 10, "head"], ["sparkles", 8, "head"]],
	"strain_slip": [["dust", 16, "feet"], ["sparkles", 8, "head"]],
	"avalanche_helmet": [["dust", 18, "head"], ["sparkles", 10, "head"]],
	"dizzy_spin": [["notes", 12, "head"], ["sparkles", 12, "head"]],
	"launch_ceiling": [["dust", 20, "feet"], ["sparkles", 8, "head"]],
	"blind_bumble": [["sparkles", 10, "head"]],
	"poof": [["flour", 60, "mid"]],
	"drop_on": [["sparkles", 16, "head"], ["dust", 12, "feet"]],
	"fish_slap": [["drops", 14, "head"]],
	"jackhammer_cling": [["dust", 22, "feet"]],
	"surf_out": [["dust", 22, "feet"]],
	"squeaky_voice": [["notes", 14, "head"]],
	"scare_leap": [["drops", 16, "mid"], ["feathers", 10, "mid"]],
	"steam_duel": [["steam", 30, "head"]],
	"feather_burst": [["feathers", 36, "mid"]],
	"costume_burn": [["sparkles", 14, "head"]],
	"balloon_chase": [["notes", 8, "head"], ["dust", 10, "feet"]],
	"headbutt_launch": [["dust", 18, "feet"], ["roses", 8, "mid"]],
	"goat_kiss": [["sparkles", 12, "head"]],
}
const T3_PROPS: PackedStringArray = ["picture_frame", "hat", "sausage", "vase"]

var driver: SimDriver = null
var camera: CameraDirector = null
var world_view: WorldView = null
var pip: PipView = null
var info: ContentInfo = null
var reduce_motion: bool = false

var _gag_id := 0
var _gag_prank := ""
var _gag_zoom := 1.3
var _react_size := "M"
var _react_rx: Dictionary = {}
var _fired: Dictionary = {}
var _slowmo_done: Dictionary = {}
var _clip_driven := false
var _eta_out := PackedStringArray()
var _prev_eta := -1
var _t3_i := 0
var _stomp_i := 0
## Scheduled actions: [remaining_s, kind, arg] in a fixed ring (view time).
var _timers: Array = []
var _pending_ff_label := ""
var _fire_link := 0
var _gag_in_pip := false


func _init() -> void:
	name = "GagStager"
	process_priority = -45
	for i in TIMERS:
		_timers.append([-1.0, "", null])


## Wire the stager (connects driver.ticked and the characters' clip events).
func setup(d: SimDriver, cam: CameraDirector, wv: WorldView, p: PipView) -> void:
	driver = d
	camera = cam
	world_view = wv
	pip = p
	info = wv.info if wv != null else null
	reduce_motion = bool(ViewKit.setting("reduce_motion", false))
	if driver != null and not driver.ticked.is_connected(on_ticked):
		driver.ticked.connect(on_ticked)
	if camera != null:
		camera.pip = pip
		camera.hush_busy_fn = hush_busy
		if not camera.gag_started.is_connected(_on_gag_started):
			camera.gag_started.connect(_on_gag_started)
	if wv != null:
		for cv in [wv.hush_view, wv.bellows_view]:
			if cv != null and not (cv as CharacterView).clip_event.is_connected(on_clip_event):
				(cv as CharacterView).clip_event.connect(on_clip_event)
	if driver != null and driver.juice != null and wv != null:
		if not driver.juice.freeze_frame_changed.is_connected(_on_freeze_frame):
			driver.juice.freeze_frame_changed.connect(_on_freeze_frame)


## Drop scheduled actions (freeze-frames, T3 props) without forgetting what fired.
func clear_pending() -> void:
	for t in _timers:
		t[0] = -1.0


## After a seek (the camera did not run while the sim was stepped): keep only the gag of a
## reaction that is still playing; released, finished or stale ones (a Meltdown hold) go.
func settle_gags() -> void:
	if camera == null:
		return
	var live := _gag_id if _gag_prank != "" else 0
	camera.clear_gags(live)
	if live == 0:
		_gag_id = 0
		_gag_in_pip = false


## Retry: drop pending staging.
func reset() -> void:
	_fired.clear()
	_slowmo_done.clear()
	_gag_id = 0
	_gag_prank = ""
	for t in _timers:
		t[0] = -1.0


func _on_gag_started(id: int, in_pip: bool) -> void:
	if id == _gag_id:
		_gag_in_pip = in_pip


## Hush is busy (rigging) or in danger ("?" filling) — gags go to the PiP when off screen.
func hush_busy() -> bool:
	if driver == null:
		return false
	var s := driver.snapshot()
	return s.hush.state == "RIGGING" or s.bellows.spot_pct > 0.0 or s.bellows.state == "CHASE"


## Bellows' CharacterView (captions ride on him), or null before the world is built.
func _bv() -> Node2D:
	return world_view.bellows_view if world_view != null else null


## His head / feet in world px — from the drawn view when it is live, else the snapshot (so a
## gag requested before the first frame, e.g. during a seek, still frames him).
func _bellows_head() -> Vector2:
	return _bellows_feet() + Vector2(0, -CharacterView.HEIGHTS["bellows"] + 75.0)


func _bellows_feet() -> Vector2:
	var bv := world_view.bellows_view if world_view != null else null
	if driver != null:
		var b := driver.snapshot().bellows
		var snap_pos := Vector2(b.x, b.y)
		if bv != null and bv.visible and bv.global_position.distance_to(snap_pos) < 120.0:
			return bv.global_position
		return snap_pos
	return bv.global_position if bv != null else Vector2.ZERO


func _fx() -> FxLayer:
	return world_view.fx if world_view != null else null


## Per-tick events.
func on_ticked(events: Array) -> void:
	for ev in events:
		var d: Dictionary = ev
		match ViewKit.s(d.get("e", "")):
			"prank_fire":
				_fired[ViewKit.s(d.get("prank", ""))] = true
				_fire_link = int(d.get("link", 0))
			"reaction_start":
				_start_reaction(d)
			"reaction_accent":
				_accent(d)
			"reaction_end":
				if camera != null and _gag_id != 0 and ViewKit.s(d.get("prank", "")) == _gag_prank:
					camera.release_gag(_gag_id)
				_gag_prank = ""
			"knock_on":
				if camera != null and _gag_id != 0:
					camera.release_gag(_gag_id)
			"bonus":
				_bonus(d)
			"combo":
				var fx := _fx()
				if fx != null and info != null:
					fx.caption(info.combo_caption(ViewKit.s(d.get("id", ""))), _bellows_head() + Vector2(0, -200), 80,
						_bv(), true, true)
			"meltdown_start":
				_meltdown_start()
			"meltdown_stomp":
				_stomp(int(d.get("n", 1)))
			"spotted":
				if driver != null:
					driver.juice.request_kind(&"hit_small")
				if camera != null:
					camera.kick(Vector2.UP, 10.0)
			"door_slam":
				_small_gag(ViewKit.word("fx.bonk", "BONK!"), 0.35)
				var fxs := _fx()
				if fxs != null:
					fxs.stars_at(_bellows_head())
			"fizzle":
				var fx2 := _fx()
				if fx2 != null:
					fx2.caption(ViewKit.word("fx.hmph", "HMPH!"), _bellows_head() + Vector2(0, -150), 60)
			"face_to_face":
				_small_gag(ViewKit.word("fx.boo", "BOO!"), 0.3)
			"near_miss":
				var fxn := _fx()
				if fxn != null and world_view != null:
					fxn.caption(ViewKit.word("fx.near_miss", "NEAR MISS!"), world_view.hush_view.head_position() + Vector2(0, -150), 64)
			"running_gag":
				var fxr := _fx()
				if fxr != null and int(d.get("link", 0)) >= 2:
					fxr.stamp("%s ×%d" % [ViewKit.word("fx.running_gag", "RUNNING GAG"), int(d.get("link", 2))], _bellows_head() + Vector2(-260, -200))
			"bump":
				if bool(d.get("first", false)):
					var fx3 := _fx()
					if fx3 != null:
						fx3.caption(ViewKit.word("fx.pardon", "PARDON?"), _bellows_head() + Vector2(0, -150), 56)
			"specs":
				if bool(d.get("on", false)) and _fx() != null:
					_fx().burst("sparkles", _bellows_head() + Vector2(20, 10), 6)
			"temper_tier":
				if int(d.get("tier", 0)) >= 2 and _fx() != null:
					_fx().burst("steam", _bellows_head() + Vector2(-60, 0), 8, Vector2(-0.6, -1))
					_fx().burst("steam", _bellows_head() + Vector2(60, 0), 8, Vector2(0.6, -1))
			"wheeze":
				if _fx() != null:
					_fx().burst("steam", _bellows_head(), 8)
			"rigged":
				_rigged(d)
			"hide", "pop_out":
				_dust_at_spot(ViewKit.s(d.get("spot", "")))
			"applause":
				_applause(d)
			"safety_net":
				if driver != null:
					driver.set_safety_slowmo(bool(d.get("on", false)))
	_approach_slowmo()


## Clip events from a RigPlayer (TECH §4.8): cam / shake / hitstop / slowmo / freeze / fx.
func on_clip_event(ev: Dictionary) -> void:
	var t := ViewKit.s(ev.get("type", ""))
	# His reaction clip's own keys time the punch / shake / hit-stop (the sim events still own
	# the framing). Clips outside a reaction, and Hush's, never frame the camera.
	var drives := ViewKit.s(ev.get("actor", "bellows")) == "bellows" and _gag_prank != ""
	match t:
		"cam":
			if drives:
				_clip_driven = true
				if ViewKit.s(ev.get("op", "punch")) == "punch" and camera != null and _gag_id != 0 \
						and camera.active_gag_id() == _gag_id:
					camera.punch_gag(_gag_id)
		"shake":
			_clip_driven = _clip_driven or drives
			if camera != null:
				camera.shake(float(ev.get("trauma", 0.4)))
		"hitstop":
			_clip_driven = _clip_driven or drives
			if driver != null:
				var f := int(ev.get("frames", 5))
				driver.juice.request_kind(&"hit_sig" if f >= 8 else (&"hit_big" if f >= 5 else &"hit_small"))
		"slowmo":
			if driver != null:
				driver.juice.request(&"slowmo", 0, float(ev.get("scale", 0.5)), float(ev.get("frames", 24)) / 60.0, 0.1)
		"freeze":
			if driver != null:
				driver.juice.freeze_frame(int(ev.get("frames", 52)))
		"fx":
			var fx := _fx()
			if fx != null:
				var at_dir := clip_fx_at(ev)
				fx.burst(ViewKit.s(ev.get("id", "sparkles")), at_dir[0], int(ev.get("amount", -1)), at_dir[1])


## Where and which way a clip `fx` event bursts (s2-fix G #16): at the event's `part` (the rig's
## joint in world space — the CHOO's drops leave his nose, the dunk's his torso, the drip his
## hand), else his head; its `dir` is clip-local (+x = the way he faces) and is mirrored by the
## rig's facing. Returns [world_pos, world_dir].
func clip_fx_at(ev: Dictionary) -> Array:
	var actor := ViewKit.s(ev.get("actor", "bellows"))
	var cv: Node2D = world_view.character(actor) if world_view != null and world_view.has_method("character") else null
	var rig: Variant = cv.get("rig") if cv != null else null
	var part := ViewKit.s(ev.get("part", ""))
	var pos := _bellows_head() if actor == "bellows" else (ev.get("pos", Vector2.ZERO) as Vector2)
	var facing := 1
	if rig is Node2D:
		if part != "" and (rig as Node2D).has_method("part_global_position"):
			pos = (rig as Node2D).call("part_global_position", part)
		if (rig as Node2D).has_method("facing"):
			facing = int((rig as Node2D).call("facing"))
	var d := Vector2.UP
	var dv: Variant = ev.get("dir", null)
	if dv is Array and (dv as Array).size() >= 2:
		d = Vector2(float(dv[0]) * float(facing), float(dv[1]))
	elif dv is Vector2:
		d = Vector2((dv as Vector2).x * float(facing), (dv as Vector2).y)
	return [pos, d.normalized() if d.length_squared() > 0.0 else Vector2.UP]


# --- reactions --------------------------------------------------------------------------

func _start_reaction(d: Dictionary) -> void:
	var prank := ViewKit.s(d.get("prank", ""))
	var arch := ViewKit.s(d.get("archetype", ""))
	var variant := ViewKit.s(d.get("variant", "a"))
	var p := info.prank(prank) if info != null else {"size": "M", "signature": false}
	_react_size = ViewKit.s(p.get("size", "M"))
	_react_rx = info.reaction(arch, variant, _react_size, int(d.get("len", 0))) if info != null else {"accent": 60, "hold1": 120}
	# A real reaction clip with its own cam / hitstop keys drives the punch, hit-stop and shake
	# (decided now, before the accent tick: the clip's accent frame fires later in the same frame).
	_clip_driven = _reaction_clip_drives(arch, variant, int(d.get("entry", 0)))
	var link := maxi(driver.snapshot().link if driver != null else 0, _fire_link)
	var z := float(_react_rx.get("zoom", 1.3))
	if bool(p.get("signature", false)) or link >= 3:
		z = ContentInfo.FINALE_ZOOM
	_gag_zoom = z
	var entry := int(d.get("entry", 0))
	var accent := int(_react_rx.get("accent", 60))
	var hold_f := clampi(int(_react_rx.get("hold1", accent + 80)) - accent + 10, 72, 120)
	var approach := maxi(6, accent - entry + 12)
	if camera != null:
		if _gag_id != 0:
			camera.release_gag(_gag_id)
		_gag_id = camera.request_gag(_bellows_head(), z, 11, hold_f, 21, 10, approach, lerpf(1.0, z, 0.4))
		_gag_in_pip = camera.active_gag_id() == _gag_id and camera.gag_in_pip()
	_gag_prank = prank


## True when Bellows' rig will play this reaction from a clip carrying `cam` or `hitstop` events.
func _reaction_clip_drives(arch: String, variant: String, entry: int) -> bool:
	var bv := world_view.bellows_view if world_view != null else null
	if bv == null or not bv.uses_rig:
		return false
	var clip := ViewSnapshot.reaction_clip(driver.world.get("db") if driver != null and driver.world != null else null, arch, variant)
	if entry > 0 and ClipMap.clip_exists(clip + "_ko"):
		clip += "_ko"
	return GagStager.clip_has_events(clip, ["cam", "hitstop"])


## True when clip `clip_id` exists and carries an event of one of `types`.
static func clip_has_events(clip_id: String, types: Array) -> bool:
	if not ClipMap.clip_exists(clip_id):
		return false
	var c: Variant = ClipLib.get_clip(clip_id)
	if c == null:
		return false
	for e in (c as Object).get("events"):
		if e is Dictionary and types.has(ViewKit.s((e as Dictionary).get("type", ""))):
			return true
	return false


func _accent(d: Dictionary) -> void:
	var prank := ViewKit.s(d.get("prank", _gag_prank))
	var p := info.prank(prank) if info != null else {"caption": prank.to_upper(), "size": "M", "signature": false}
	var fx := _fx()
	var head := _bellows_head()
	var snap := driver.snapshot() if driver != null else null
	var tier := snap.bellows.react_tier if snap != null else 1
	var link := maxi(snap.link if snap != null else 0, _fire_link)
	var sig := bool(p.get("signature", false))
	if not _clip_driven:
		if driver != null:
			var hs := int(_react_rx.get("hitstop", 5))
			driver.juice.request_kind(&"hit_sig" if hs >= 8 or sig else (&"hit_big" if hs >= 5 else &"hit_small"))
		if camera != null:
			if _gag_id != 0:
				camera.punch_gag(_gag_id)
			camera.shake(0.32 + 0.1 * float(tier - 1) + (0.15 if sig else 0.0))
			var facing := float(snap.bellows.facing) if snap != null else 1.0
			camera.kick(Vector2(-facing, -0.4), 12.0)
	if fx != null:
		var bv := world_view.bellows_view if world_view != null else null
		fx.caption(ViewKit.s(p.get("caption", prank.to_upper())), head + Vector2(0, -HEAD_UP - 120.0), 88, bv, not _gag_in_pip)
		var arch := snap.bellows.react_archetype if snap != null else ""
		var list: Array = ARCHETYPE_FX.get(arch, [["sparkles", 14, "head"], ["dust", 12, "feet"]])
		for e in list:
			var where := ViewKit.s(e[2])
			var pos := head
			if where == "feet":
				pos = _bellows_feet() + Vector2(0, -10)
			elif where == "mid":
				pos = _bellows_feet() + Vector2(0, -200)
			fx.burst(ViewKit.s(e[0]), pos, int(e[1]))
	if tier >= 3 and not _clip_driven:
		var t3 := float(int(_react_rx.get("t3_prop_f", int(_react_rx.get("accent", 60)) + 20)) - int(_react_rx.get("accent", 60)))
		_schedule(maxf(0.1, t3 / 60.0), "t3_prop", T3_PROPS[_t3_i % T3_PROPS.size()])
		_t3_i += 1
	if sig or link >= 4:
		_schedule(0.1, "freeze_frame", ViewKit.s(p.get("caption", "")))


func _on_freeze_frame(on: bool) -> void:
	var fx := _fx()
	if fx != null:
		fx.set_freeze_frame(on, _pending_ff_label if on else "")


func _bonus(d: Dictionary) -> void:
	var fx := _fx()
	if fx == null:
		return
	var kind := ViewKit.s(d.get("kind", ""))
	var amount := int(d.get("amount", 0))
	var label := kind.to_upper().replace("_", " ") + "!"
	if kind == "near_miss":
		label = ViewKit.word("fx.near_miss", label)
	var pts := amount / 10 if amount >= 10 else amount
	fx.stamp("%s +%d" % [label, pts], _bellows_head() + Vector2(230, -170))


func _applause(d: Dictionary) -> void:
	if ViewKit.s(d.get("kind", "")) != "bit":
		return
	var fx := _fx()
	if fx == null:
		return
	var delta := int(d.get("delta", 0))
	if delta > 0:
		fx.caption("+%d" % maxi(1, delta / 10), _bellows_head() + Vector2(0, -150), 56)


func _rigged(d: Dictionary) -> void:
	var fx := _fx()
	if fx == null or world_view == null:
		return
	var p := info.prank(ViewKit.s(d.get("prank", ""))) if info != null else {}
	var rp := ViewKit.s(p.get("rig_point", ""))
	var hs := world_view.layout.hotspot(rp) if rp != "" else null
	var pos := hs.rect.get_center() if hs != null else world_view.hush_view.head_position()
	fx.burst("sparkles", pos, 14)


func _dust_at_spot(spot: String) -> void:
	var fx := _fx()
	if fx == null or world_view == null:
		return
	var hs := world_view.layout.hotspot(spot)
	if hs != null:
		fx.burst("dust", Vector2(hs.rect.get_center().x, hs.rect.end.y - 20.0), 10)


func _small_gag(text: String, trauma: float) -> void:
	if camera != null:
		camera.shake(trauma)
	var fx := _fx()
	if fx != null:
		fx.caption(text, _bellows_head() + Vector2(0, -140), 72)
		fx.burst("sparkles", _bellows_head(), 10)


func _meltdown_start() -> void:
	if camera != null:
		camera.shake(0.55)
		if _gag_id != 0:
			camera.release_gag(_gag_id)
		_gag_id = camera.request_gag(_bellows_head(), 1.15, 12, 300, 30, 20)
	var fx := _fx()
	if fx != null:
		fx.caption(ViewKit.word("fx.meltdown", "MELTDOWN!"), _bellows_head() + Vector2(0, -170), 96, _bv(), true, true)
		fx.burst("steam", _bellows_head(), 24)


func _stomp(n: int) -> void:
	if camera != null:
		camera.shake(0.4)
		camera.kick(Vector2.DOWN, 16.0)
	var fx := _fx()
	if fx == null or world_view == null:
		return
	fx.burst("dust", _bellows_feet() + Vector2(0, -8), 18)
	var snap := driver.snapshot() if driver != null else null
	if snap == null:
		return
	var room := snap.bellows.room
	var list: Variant = world_view.layout.quake_props.get(room, [])
	if list is Array and not (list as Array).is_empty():
		var qp: Dictionary = (list as Array)[(n - 1 + _stomp_i) % (list as Array).size()]
		var fy := world_view.layout.room_floor_y(room)
		var x := float(qp.get("x", snap.bellows.x))
		var top := fy - 600.0
		# It falls from where its decor sprite hung (which hides as the copy drops).
		var dr := world_view.decor.rect_of(ViewKit.s(qp.get("decor", "")))
		if dr.size != Vector2.ZERO and world_view.decor.is_visible(ViewKit.s(qp.get("decor", ""))):
			x = dr.get_center().x
			top = dr.position.y
		world_view.quake_decor(qp)
		fx.drop_prop(ViewKit.s(qp.get("prop", "picture_frame")), x, top, INF, fy)
	_stomp_i += 1


# --- scheduled actions / per frame --------------------------------------------------------

func _schedule(sec: float, kind: String, arg: Variant) -> void:
	for t in _timers:
		if float(t[0]) < 0.0:
			t[0] = sec
			t[1] = kind
			t[2] = arg
			return


func _process(delta: float) -> void:
	advance(delta)


## Per frame (public for tests): timers, gag focus tracking, PiP rule.
func advance(delta: float) -> void:
	var vdt := driver.view_delta() if driver != null else delta
	for t in _timers:
		if float(t[0]) < 0.0:
			continue
		t[0] = float(t[0]) - maxf(vdt, delta * 0.05)
		if float(t[0]) <= 0.0:
			t[0] = -1.0
			_run(ViewKit.s(t[1]), t[2])
	var holding := camera != null and _gag_id != 0 and camera.active_gag_id() == _gag_id
	if holding:
		camera.set_gag_focus(_gag_id, _bellows_head())
	if world_view != null and world_view.fx != null:
		world_view.fx.quiet = holding and not _gag_in_pip and camera.gag_phase() != CameraDirector.GagPhase.APPROACH
	if pip != null and driver != null and camera != null and world_view != null:
		var snap := driver.snapshot()
		if camera.is_gag_active() and not camera.gag_in_pip() and camera.gag_phase() != CameraDirector.GagPhase.APPROACH:
			pip.hide_now()
		else:
			var vr := camera.visible_world_rect()
			var z := maxf(0.001, camera.current_zoom())
			if not pip.is_escalated() and PipView.on_screen(snap, vr, Vector4(0.0, PipView.HUD_TOP_PX / z, 0.0, PipView.HUD_BOTTOM_PX / z)):
				pip.hide_now()   # he is plainly on screen: never twice (s2-fix G #19)
			else:
				var want := PipView.rule(snap, vr, world_view.layout, world_view.entry_warning_active())
				pip.set_visible_if(want or pip.is_escalated())


func _run(kind: String, arg: Variant) -> void:
	match kind:
		"t3_prop":
			var fx := _fx()
			if fx != null and world_view != null:
				var b := world_view.bellows_view
				fx.drop_prop(ViewKit.s(arg), b.global_position.x, b.global_position.y - 640.0, b.top_position().y + 60.0, b.global_position.y)
		"freeze_frame":
			_pending_ff_label = ViewKit.s(arg)
			if driver != null and not reduce_motion:
				driver.juice.request_kind(&"freeze_frame")


## First time a prank fires this Night: the last 24 frames of his approach at 0.5×.
func _approach_slowmo() -> void:
	if driver == null or info == null:
		return
	var eta := info.armed_eta(driver.snapshot(), _eta_out)
	if eta >= 0 and eta <= 24 and (_prev_eta < 0 or _prev_eta > 24) and not _eta_out.is_empty():
		var id := _eta_out[0]
		if not _fired.has(id) and not _slowmo_done.has(id):
			_slowmo_done[id] = true
			driver.juice.request_kind(&"approach_slowmo")
	_prev_eta = eta
