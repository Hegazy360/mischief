## GagStager3D — the sim's comedy events turned into 3D staging (GDD §2.1 payoff row, §3.7 Gag-Cam, REDESIGN §5.2 C7,
## §4.3; the 2D GagStager's rules on CameraDirector3D): at `reaction_start` the camera requests a punch-in on his
## chest (`actor_anchor(&"bellows", &"chest")`, tracked every frame) with a gentle push through the anticipation
## (the clip's `cam push`, else 40 % of the punch), PUNCHES in at `reaction_accent` with the hit-stop, shake and a
## kick, yaws 3–6° toward his face side on M / L / SIG (8° for MIRROR, MIRROR), pops the pun caption and the
## archetype's particles, holds, and eases out. Signatures and chain finales (link ≥ 4) end in a freeze-frame;
## first-time pranks get the 0.5× approach slow-mo over their last 24 frames. When his reaction clip carries its own
## `cam` / `hitstop` / `shake` events, those drive the camera instead of the synthetic accent (no double hits).
## A reaction whose clip is missing (N1/N2 fallbacks) gets its caption on its own accent all the same.
##
## Wiring: `setup(driver, camera, world_view, pip)`; it connects to `driver.ticked` and both CharacterView3D's
## `clip_event`.
class_name GagStager3D
extends Node

const TIMERS := 12
## Punch yaw by prank size (degrees, toward his face side); MIRROR, MIRROR's face-to-face gets 8°.
const YAW_BY_SIZE := {"S": 0.0, "M": 4.0, "L": 5.0, "SIG": 6.0}
const MIRROR_YAW := 8.0
const ARCHETYPE_FX := {
	"sneeze_blast": [["choo_puff", "head"], ["drops", "head"]],
	"drench": [["drops", "head"]],
	"sing_crack": [["notes", "head"], ["sparkles", "head"]],
	"strain_slip": [["dust", "feet"], ["onions", "head"]],
	"avalanche_helmet": [["dust", "head"], ["sparkles", "head"]],
	"dizzy_spin": [["notes", "head"], ["stars", "head"]],
	"launch_ceiling": [["dust", "feet"], ["sparkles", "head"]],
	"blind_bumble": [["sparkles", "head"]],
	"drop_on": [["stars", "head"], ["dust", "feet"]],
	"fish_slap": [["drops", "head"]],
	"jackhammer_cling": [["dust", "feet"]],
	"surf_out": [["dust", "feet"]],
	"squeaky_voice": [["notes", "head"]],
	"scare_leap": [["drops", "mid"]],
}

var driver: SimDriver = null
var camera: CameraDirector3D = null
var world_view: WorldView3D = null
var pip: PipView3D = null
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
var _captioned := false
var _eta_out := PackedStringArray()
var _prev_eta := -1
var _timers: Array = []
var _fire_link := 0
var _gag_in_pip := false
## Captions staged (tests / the e2e report).
var captions: int = 0


func _init() -> void:
	name = "GagStager3D"
	process_priority = -45
	for i in TIMERS:
		_timers.append([-1.0, "", null])


func setup(d: SimDriver, cam: CameraDirector3D, wv: WorldView3D, p: PipView3D) -> void:
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
			if cv != null and not (cv as CharacterView3D).clip_event.is_connected(on_clip_event):
				(cv as CharacterView3D).clip_event.connect(on_clip_event)


func clear_pending() -> void:
	for t in _timers:
		t[0] = -1.0


func settle_gags() -> void:
	if camera == null:
		return
	var live := _gag_id if _gag_prank != "" else 0
	camera.clear_gags(live)
	if live == 0:
		_gag_id = 0
		_gag_in_pip = false


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


func hush_busy() -> bool:
	if driver == null:
		return false
	var s := driver.snapshot()
	return s.hush.state == "RIGGING" or s.bellows.spot_pct > 0.0 or s.bellows.state == "CHASE"


func _chest() -> Vector3:
	return world_view.actor_anchor(&"bellows", &"chest") if world_view != null else Vector3.ZERO


func _head() -> Vector3:
	return world_view.actor_anchor(&"bellows", &"head") if world_view != null else Vector3.ZERO


func _feet() -> Vector3:
	return world_view.actor_anchor(&"bellows", &"feet") if world_view != null else Vector3.ZERO


func _caption(text: String, at: Vector3, size: int) -> void:
	if world_view == null or world_view.overlays == null or text == "":
		return
	world_view.overlays.caption(text, at, size)
	captions += 1


func _burst(kind: String, at: Vector3) -> void:
	if world_view != null and world_view.fx3d != null:
		world_view.fx3d.burst(kind, at)


func on_ticked(events: Array) -> void:
	for ev in events:
		var d: Dictionary = ev
		match str(d.get("e", "")):
			"prank_fire":
				_fired[str(d.get("prank", ""))] = true
				_fire_link = int(d.get("link", 0))
			"reaction_start":
				_start_reaction(d)
			"reaction_accent":
				_accent(d)
			"reaction_end":
				if camera != null and _gag_id != 0 and str(d.get("prank", "")) == _gag_prank:
					camera.release_gag(_gag_id)
				_gag_prank = ""
			"knock_on":
				if camera != null and _gag_id != 0:
					camera.release_gag(_gag_id)
			"combo":
				if info != null:
					_caption(info.combo_caption(str(d.get("id", ""))), _head() + Vector3(0, 1.0, 0), 80)
			"meltdown_start":
				if camera != null:
					camera.shake(0.55)
					if _gag_id != 0:
						camera.release_gag(_gag_id)
					_gag_id = camera.request_gag(_chest(), 1.15, 12, 300, 30, 20)
				_caption(ViewKit.word("fx.meltdown", "MELTDOWN!"), _head() + Vector3(0, 0.9, 0), 96)
				_burst("steam", _head())
			"meltdown_stomp":
				if camera != null:
					camera.shake(0.4)
					camera.kick(Vector2.DOWN, 16.0)
				_burst("dust", _feet())
			"spotted":
				if driver != null:
					driver.juice.request_kind(&"hit_small")
				if camera != null:
					camera.kick(Vector2.UP, 10.0)
			"door_slam":
				_small_gag(ViewKit.word("fx.bonk", "BONK!"), 0.35)
				_burst("stars", _head())
			"fizzle":
				_caption(ViewKit.word("fx.hmph", "HMPH!"), _head() + Vector3(0, 0.7, 0), 60)
			"face_to_face":
				_small_gag(ViewKit.word("fx.boo", "BOO!"), 0.3)
			"near_miss":
				if world_view != null:
					_caption(ViewKit.word("fx.near_miss", "NEAR MISS!"), world_view.actor_anchor(&"hush", &"top") + Vector3(0, 0.6, 0), 64)
			"specs":
				if bool(d.get("on", false)):
					_burst("sparkles", _head())
			"temper_tier":
				if int(d.get("tier", 0)) >= 2:
					_burst("steam", _head())
			"wheeze":
				_burst("steam", _head())
			"rigged":
				var p := info.prank(str(d.get("prank", ""))) if info != null else {}
				var rp := str(p.get("rig_point", ""))
				if rp != "" and world_view != null:
					_burst("sparkles", world_view.anchor_of(rp, &"ring"))
			"hide", "pop_out":
				if world_view != null and str(d.get("spot", "")) != "":
					_burst("dust", world_view.anchor_of(str(d.get("spot", "")), &"ring"))
			"safety_net":
				if driver != null:
					driver.set_safety_slowmo(bool(d.get("on", false)))
	_approach_slowmo()


## Clip events: cam (push / punch) / shake / hitstop / slowmo / freeze / fx.
func on_clip_event(ev: Dictionary) -> void:
	var t := str(ev.get("type", ""))
	var drives := str(ev.get("actor", "bellows")) == "bellows" and _gag_prank != ""
	match t:
		"cam":
			if drives:
				_clip_driven = true
				if str(ev.get("op", "punch")) == "punch" and camera != null and _gag_id != 0 and camera.active_gag_id() == _gag_id:
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


func _start_reaction(d: Dictionary) -> void:
	var prank := str(d.get("prank", ""))
	var arch := str(d.get("archetype", ""))
	var variant := str(d.get("variant", "a"))
	var p := info.prank(prank) if info != null else {"size": "M", "signature": false}
	_react_size = str(p.get("size", "M"))
	_react_rx = info.reaction(arch, variant, _react_size, int(d.get("len", 0))) if info != null else {"accent": 60, "hold1": 120}
	_clip_driven = _reaction_clip_drives(arch, variant, int(d.get("entry", 0)))
	_captioned = false
	var link := maxi(driver.snapshot().link if driver != null else 0, _fire_link)
	var z := float(_react_rx.get("zoom", 1.3))
	var sig := bool(p.get("signature", false))
	if sig or link >= 3:
		z = ContentInfo.FINALE_ZOOM
	_gag_zoom = z
	var entry := int(d.get("entry", 0))
	var accent := int(_react_rx.get("accent", 60))
	var hold_f := clampi(int(_react_rx.get("hold1", accent + 80)) - accent + 10, 72, 120)
	var approach := maxi(6, accent - entry + 12)
	var size := "SIG" if sig else _react_size
	var yaw := float(YAW_BY_SIZE.get(size, 4.0))
	if arch == "sig_mirror_mirror":
		yaw = MIRROR_YAW
	var facing := float(driver.snapshot().bellows.facing) if driver != null else 1.0
	if camera != null:
		if _gag_id != 0:
			camera.release_gag(_gag_id)
		_gag_id = camera.request_gag(_chest(), z, 11, hold_f, 21, 10, yaw * facing, approach, lerpf(1.0, z, 0.4) if not _clip_driven else 1.0)
		_gag_in_pip = camera.active_gag_id() == _gag_id and camera.gag_in_pip()
	_gag_prank = prank


func _reaction_clip_drives(arch: String, variant: String, entry: int) -> bool:
	var bv := world_view.bellows_view if world_view != null else null
	if bv == null or not bv.uses_rig:
		return false
	var clip := ViewSnapshot.reaction_clip(driver.world.get("db") if driver != null and driver.world != null else null, arch, variant)
	if entry > 0 and ClipMap.clip_exists3d(clip + "_ko"):
		clip += "_ko"
	return GagStager3D.clip_has_events3d(clip, ["cam", "hitstop"])


## True when the 3D clip's sidecar carries an event of one of `types`.
static func clip_has_events3d(clip_id: String, types: Array) -> bool:
	if not ClipMap.clip_exists3d(clip_id):
		return false
	var d: Variant = ViewKit.json(ClipMap.sidecar_path(clip_id))
	if not (d is Dictionary):
		return false
	for e in (d as Dictionary).get("events", []):
		if e is Dictionary and types.has(str((e as Dictionary).get("type", ""))):
			return true
	return false


func _accent(d: Dictionary) -> void:
	var prank := str(d.get("prank", _gag_prank))
	var p := info.prank(prank) if info != null else {"caption": prank.to_upper(), "size": "M", "signature": false}
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
	if not _captioned:
		_captioned = true
		_caption(str(p.get("caption", prank.to_upper())), _head() + Vector3(0.0, 0.75, 0.0), 96)
	var arch := snap.bellows.react_archetype if snap != null else ""
	var list: Array = ARCHETYPE_FX.get(arch, [["sparkles", "head"], ["dust", "feet"]])
	for e in list:
		var where := str(e[1])
		var pos := _head()
		if where == "feet":
			pos = _feet()
		elif where == "mid":
			pos = _chest()
		_burst(str(e[0]), pos)
	if sig or link >= 4:
		_schedule(0.1, "freeze_frame", str(p.get("caption", "")))


func _small_gag(text: String, trauma: float) -> void:
	if camera != null:
		camera.shake(trauma)
	_caption(text, _head() + Vector3(0, 0.7, 0), 72)
	_burst("sparkles", _head())


func _schedule(sec: float, kind: String, arg: Variant) -> void:
	for t in _timers:
		if float(t[0]) < 0.0:
			t[0] = sec
			t[1] = kind
			t[2] = arg
			return


func _process(delta: float) -> void:
	advance(delta)


## Per frame (public for tests): timers and the gag focus (his chest, tracked through the travel).
func advance(delta: float) -> void:
	var vdt := driver.view_delta() if driver != null else delta
	for t in _timers:
		if float(t[0]) < 0.0:
			continue
		t[0] = float(t[0]) - maxf(vdt, delta * 0.05)
		if float(t[0]) <= 0.0:
			t[0] = -1.0
			if str(t[1]) == "freeze_frame" and driver != null and not reduce_motion:
				driver.juice.request_kind(&"freeze_frame")
	if camera != null and _gag_id != 0 and camera.active_gag_id() == _gag_id:
		camera.set_gag_focus(_gag_id, _chest())


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
