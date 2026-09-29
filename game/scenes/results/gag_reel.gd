## GagReel — the curtain call's Gag Reel (GDD §6.2, s2-night §4.3): the Night's best moments re-staged
## with both actors, the props, the camera punch-in, the captions and the sound — exactly as played.
##
## Recording (`GagReel.Log`, fed by NightScene every tick during PLAY): a world clone every
## `clone_every` ticks (a small ring), and one **moment** per reaction: `reaction_start` (antic − 12 f)
## → `reaction_end` (hold end + the sim's last beat, which the sim includes in the length); a knock-on
## (`reaction_start.entry > 0` right after its trigger) merges into the moment of its trigger (the
## sneeze → the drench is ONE moment); each moment keeps the newest clone taken before it starts, its
## Applause (the gag's `applause` events), tier, variant and the "+NEW!" keys it produced.
##
## Playback (the GagReel node): the deterministic sim re-plays each chosen moment from its clone with the
## Night's command log (so every prop state, the stool, the sink, the residue and both characters are the
## real ones), on NightScene's own WorldView, and a SubViewport (704 × 396, sharing the world, the FX
## marker layer culled like the PiP) films it through a camera that mirrors the CameraDirector — the
## punch-in and the pun caption included. Clip sounds play at −6 dB (SFX + Voice buses), the laugh at
## full level. `skip()` (a tap) ends the current moment; `budget_s` caps the whole reel.
## (Deviation from the brief's `MomentRecorder` re-stage: this replays the real sim + view instead of a
## recorded pose buffer, so frame 0 and the accent frame are the live frames by construction.)
class_name GagReel
extends Node

signal moment_started(index: int, moment: Dictionary)
signal finished()

const SIZE := Vector2i(704, 396)
const PRE_TICKS := 12
const FX_LAYER_BIT := 2
const DUCK_DB := -6.0
const DUCK_BUSES: PackedStringArray = ["SFX", "Voice"]


## Per-Night recording of reel moments (pure data + world clones).
class Log:
	extends RefCounted
	var clone_every: int = 60
	var ring_size: int = 4
	var moments: Array = []
	var _ring: Array = []          # [[tick, clone], …] oldest first
	var _open: int = -1

	func reset() -> void:
		moments.clear()
		_ring.clear()
		_open = -1

	## Per tick (NightScene._on_ticked): clones on the ring cadence, moments from the reaction events.
	func on_events(events: Array, world: Object) -> void:
		if world == null or not world.has_method("clone"):
			return
		var t := int(world.get("tick"))
		if _ring.is_empty() or t - int(_ring[_ring.size() - 1][0]) >= clone_every:
			_ring.append([t, world.call("clone")])
			while _ring.size() > ring_size:
				_ring.pop_front()
		for ev in events:
			var d: Dictionary = ev
			match String(d.get("e", "")):
				"reaction_start":
					_start(d, t)
				"reaction_accent":
					if _open >= 0 and int(moments[_open]["accent"]) < 0:
						moments[_open]["accent"] = int(d.get("t", t))
				"reaction_end":
					if _open >= 0:
						moments[_open]["end"] = int(d.get("t", t))
				"applause":
					if _open >= 0 and String(d.get("kind", "")) != "catch":
						moments[_open]["applause"] = int(moments[_open]["applause"]) + int(d.get("delta", 0))

	func _start(d: Dictionary, t: int) -> void:
		var st := int(d.get("t", t))
		var entry := int(d.get("entry", 0))
		var prank := String(d.get("prank", ""))
		var key := "rx:%s:t%d:%s" % [prank, int(d.get("tier", 1)), String(d.get("variant", "a"))]
		if entry > 0 and _open >= 0 and st - int(moments[_open]["end"]) <= 30:
			var m: Dictionary = moments[_open]
			(m["chain"] as Array).append(prank)
			(m["keys"] as Array).append(key)
			m["end"] = st + int(d.get("len", 0))
			m["tier"] = maxi(int(m["tier"]), int(d.get("tier", 1)))
			return
		var base: Variant = null
		var base_tick := -1
		for i in range(_ring.size() - 1, -1, -1):
			if int(_ring[i][0]) <= st - GagReel.PRE_TICKS:
				base = (_ring[i][1] as Object).call("clone")
				base_tick = int(_ring[i][0])
				break
		moments.append({"prank": prank, "chain": [prank], "keys": [key], "start": st, "accent": -1,
			"end": st + int(d.get("len", 0)), "tier": int(d.get("tier", 1)), "variant": String(d.get("variant", "a")),
			"applause": 0, "base": base, "base_tick": base_tick, "new": false})
		_open = moments.size() - 1

	## The moments to show: best `n` by Applause (ties: higher tier, then later), in Night order;
	## `new_keys` marks "+NEW!" moments; `repeat` = best 1 + every new one.
	func best(n: int, repeat: bool = false) -> Array:
		var ok: Array = []
		for m in moments:
			if (m as Dictionary).get("base") != null:
				ok.append(m)
		ok.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["applause"]) != int(b["applause"]):
				return int(a["applause"]) > int(b["applause"])
			if int(a["tier"]) != int(b["tier"]):
				return int(a["tier"]) > int(b["tier"])
			return int(a["start"]) > int(b["start"]))
		var pick: Array = []
		for m in ok:
			if pick.size() < (1 if repeat else n):
				pick.append(m)
			elif repeat and bool(m.get("new", false)) and pick.size() < n:
				pick.append(m)
		pick.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["start"]) < int(b["start"]))
		return pick


## Tick window [from, to] of a moment within a per-moment share of the reel (seconds).
static func window(m: Dictionary, share_s: float) -> Vector2i:
	var start := int(m.get("start", 0)) - PRE_TICKS
	var accent := int(m.get("accent", -1))
	var end := int(m.get("end", start + 120))
	var share := maxi(60, int(share_s * 60.0))
	var from := start
	if accent >= 0 and accent - start > int(share * 0.45):
		from = accent - int(share * 0.45)
	var to := mini(end, from + share)
	return Vector2i(from, maxi(from + 1, to))


var night: Node = null
var viewport: SubViewport = null
var reel_cam: Camera2D = null
var moments: Array = []
var budget_s: float = 8.0
var index: int = -1
var playing: bool = false
## Ticks actually played per moment (tests / the report).
var played: Array = []

var _cmds: Array = []
var _replay := CmdReplay.new()
var _to_tick: int = 0
var _world_saved: Object = null
var _bus_saved: Dictionary = {}
var _elapsed: float = 0.0


func _init() -> void:
	name = "GagReel"
	viewport = SubViewport.new()
	viewport.name = "ReelViewport"
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.canvas_cull_mask = 0xFFFFF & ~FX_LAYER_BIT
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	reel_cam = Camera2D.new()
	reel_cam.name = "ReelCamera"
	viewport.add_child(reel_cam)


func _ready() -> void:
	var host := get_tree().root
	viewport.world_2d = host.world_2d
	reel_cam.make_current()


## The reel's texture (ResultsScreen.set_gag_reel_texture).
func get_texture() -> Texture2D:
	return viewport.get_texture()


## Play `p_moments` (from `Log.best`) on `p_night` (NightScene) within `p_budget_s`.
func start(p_night: Node, p_moments: Array, p_budget_s: float, cmds: Array) -> void:
	night = p_night
	moments = p_moments
	budget_s = p_budget_s
	_cmds = cmds
	index = -1
	played.clear()
	_elapsed = 0.0
	if night == null or moments.is_empty():
		_finish()
		return
	var drv: SimDriver = night.get("driver")
	_world_saved = drv.world
	_duck(true)
	playing = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_next()


## A tap: end the current moment now.
func skip() -> void:
	if playing:
		_end_moment()


## End the whole reel now.
func stop() -> void:
	if playing:
		_finish()


func _share() -> float:
	return budget_s / float(maxi(1, moments.size()))


func _next() -> void:
	index += 1
	if index >= moments.size() or _elapsed >= budget_s:
		_finish()
		return
	var m: Dictionary = moments[index]
	var w := GagReel.window(m, _share())
	var drv: SimDriver = night.get("driver")
	var ad: AudioDirector = night.get("audio_dir")
	var base: Object = (m["base"] as Object).call("clone")
	drv.set_paused(true)
	drv.setup(base)
	_replay.start(drv, _cmds)
	ad.muted = true
	var guard := 0
	while int(base.get("tick")) < w.x and guard < 20000:
		drv.step_now()
		guard += 1
	ad.muted = false
	ad.clear_pending()
	var st: GagStager = night.get("stager")
	st.clear_pending()
	st.settle_gags()
	var wv: WorldView = night.get("world_view")
	wv.fx.clear()
	wv.advance(0.0)
	var cam: CameraDirector = night.get("cam")
	cam.snap_now()
	cam.reset_motion()
	_to_tick = w.y
	played.append(Vector2i(w.x, w.y))
	drv.set_paused(false)
	moment_started.emit(index, m)


func _end_moment() -> void:
	var drv: SimDriver = night.get("driver")
	drv.set_paused(true)
	_replay.stop()
	_next()


func _process(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta
	var cam: CameraDirector = night.get("cam")
	if cam != null:
		reel_cam.global_position = cam.get_screen_center_position()
		var vw := maxf(1.0, cam.view_size().x)
		reel_cam.zoom = cam.zoom * (float(SIZE.x) / vw)
	var drv: SimDriver = night.get("driver")
	if int(drv.world.get("tick")) >= _to_tick or bool(drv.world.get("ended")) or _elapsed >= budget_s:
		_end_moment()


func _finish() -> void:
	playing = false
	_replay.stop()
	_duck(false)
	if night != null and _world_saved != null:
		var drv: SimDriver = night.get("driver")
		drv.set_paused(true)
		drv.setup(_world_saved)
		var ad: AudioDirector = night.get("audio_dir")
		ad.clear_pending()
		ad.muted = true
	_world_saved = null
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	finished.emit()


func _duck(on: bool) -> void:
	for bus in DUCK_BUSES:
		var i := AudioServer.get_bus_index(bus)
		if i < 0:
			continue
		if on:
			_bus_saved[bus] = AudioServer.get_bus_volume_db(i)
			AudioServer.set_bus_volume_db(i, float(_bus_saved[bus]) + DUCK_DB)
		elif _bus_saved.has(bus):
			AudioServer.set_bus_volume_db(i, float(_bus_saved[bus]))
	if not on:
		_bus_saved.clear()
