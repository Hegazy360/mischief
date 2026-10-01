## NightScene — one playable Night: the sim, view, HUD, input and audio wired together (TECH §5.1).
## It owns no gameplay rules: the SimWorld decides, the view shows, this scene connects them and runs
## the Night's flow (s2-night §4.1–§4.4):
##
##   BUILD → COLD OPEN (FTUE hook) → LOADING (the rule card / the Gate-0 card) → WARM (under the curtain)
##   → RISING (tick 0 = the curtain-rise frame, input live at half up) → PLAY → END (the curtain falls)
##   → CURTAIN CALL (bow, roses, results, Gag Reel) → Next Night ▶ / Retry / Playbill (Again ▶ / Stage door
##   for Gate 0).
##
## Scene tree (built in `_build`, TECH §5.1), the 3D view (the 2D view was removed, index §5.4):
## SimDriver · WorldEnvironment · CameraDirector3D (current camera) · World (WorldView3D: House3D set, the two
## CharacterView3D, decals, 3D FX, Overlays3D) · InputRouter (screen space) · PipView3D (the Bellows window) ·
## GagStager3D · AudioDirector · WorldOverlays (CanvasLayer 8: previews, thought, rig ring, tags) · Stalls (layer 9,
## hidden at rest) · Hud (layer 10) · HapticsDirector · Curtain (layer 20).
##
## Hooks: `setup(params)` before `_ready` — `{episode, relaxed, from, rise_at_ms, card, skip_intro, cmds, view}`;
## `handle_back() -> bool` (closes the Map / the top panel, else opens the pause menu; never quits).
## As the main scene (debug) it reads the NightArgs flags: `--episode --cmds --seek-tick --paused
## --relaxed --no-curtain --msaa --no-captions --hud=off --window`.
## Every material of the Night is drawn once under the curtain (NightWarmer + MaterialWarm3D) and `shader_watch`
## counts every shader first used after the rise (`perf3d.shader_compiles_play`, REDESIGN §6.3); `perf3d` samples
## the frame budget during PLAY (both land in the device log and the e2e report).
class_name NightScene
extends Node

signal phase_changed(phase: int)
## The curtain started to rise: the sim clock starts on this frame (tick 0).
signal curtain_rose()
## The Night ended (`night_end` reason, or "retry" / "quit").
signal night_ended(reason: String)
## Retry finished: tap → live control in ms.
signal retry_done(ms: int)
## The curtain call's choice: next | retry | playbill | again | stage_door.
signal curtain_call_action(action: String)

enum Phase { BUILD, COLD_OPEN, LOADING, WARM, RISING, PLAY, END, CURTAIN_CALL }

const PHASE_NAMES: PackedStringArray = ["BUILD", "COLD_OPEN", "LOADING", "WARM", "RISING", "PLAY", "END", "CURTAIN_CALL"]
const SCENE := "res://scenes/night/NightScene.tscn"
const FTUE_DIRECTOR := "res://ui/ftue/ftue_director.gd"
const COLD_OPEN_PLAYER := "res://ui/ftue/cold_open_player.gd"
const HAPTICS_DIRECTOR := "res://view/haptics_director.gd"
const CONDITIONS := "res://sim/systems/conditions.gd"
const G0_EPISODE := "g0_sneeze"
const PROLOGUE := "p00_curtain_up"
const VIEW_3D := "3d"
## The Map's peek hold (s) on a tapped room.
const MAP_PEEK_S := 2.4
## Rise anyway when the warm-up is not done this long after the flow reached WARM.
const WARM_CAP_S := 3.0
const SCRIPT_FLASH_S := 2.5
const CURTAIN_LAYER := 20
const RETRY_DROP_S := 0.3
const RETRY_RISE_S := 0.5
## Gag Reel: a world clone every this many ticks (the base a moment re-stages from).
const CLONE_EVERY := 60

var params: Dictionary = {}
var episode_id: String = ""
var relaxed: bool = false
var from: String = ""
var phase: int = Phase.BUILD
## True when the scene runs as the main scene with CLI flags (debug shots).
var cli: bool = false
var cli_args: Dictionary = {}

var db: Object = null
var world: Object = null
var driver: SimDriver = null
## Always "3d" (the 2D view was removed by r3d-integrate, index §5.4; kept for the e2e report and the device log).
var view_mode: String = VIEW_3D
## WorldView3D (duck-typed: layout, fx, hotspot_rects_in_view, … — the NightScene-facing names).
var world_view: Variant = null
## CameraDirector3D.
var cam: Variant = null
var input_router: InputRouter = null
var audio_dir: AudioDirector = null
## PipView3D (the Bellows window).
var pip: Variant = null
## GagStager3D.
var stager: Variant = null
## 3D: the world overlays (CanvasLayer 8) and their per-frame model / context (index §7.8).
var overlays: WorldOverlays = null
var omodel := OverlayModel.new()
var octx := OverlayCtx.new()
## 3D: the render settings in effect ({msaa: "off"|"2"|"4", render_scale, outline}).
var render_cfg: Dictionary = {}
## 3D: "no shader compiled during play" (armed at the rise) and the PLAY frame budget.
var shader_watch := ShaderWatch.new()
var perf3d := Perf3D.new()
## 3D: the Map (the pause panel's Map: the 15 m overview, a tap on a room peeks at it).
var map_open: bool = false
var stalls: StallsView = null
var stalls_layer: CanvasLayer = null
var hud: Hud = null
var haptics_dir: Node = null
var ftue: Node = null
var cues: CueFallback = null
var curtain_layer: CanvasLayer = null
var curtain: NightCurtain = null
var warmer: NightWarmer = null
var curtain_call: Node = null
var reel_log: GagReel.Log = GagReel.Log.new()

var model := HudModel.new()
var presenter := HudPresenter.new()
var env := HudPresenter.HudEnv.new()
var night_input := NightInput.new()
var replay := CmdReplay.new()

## Process ms (DeviceLog.process_ms) of the first allowed rise (Boot passes the launch target, ≈ 2.3 s;
## 0 = as soon as warm) and of the latest (rise even when not warm).
var rise_at_ms: int = 0
var rise_cap_ms: int = 0
## Tick-0 bookkeeping for the sim clock contract (tests / e2e).
var rise_frame: int = -1
var frame_n: int = 0
var events_before_rise: int = 0
## Retry measurement.
var last_retry_ms: int = -1
## Curtain time (s) when input went live (half up, design 0.4 s) and that frame's delta (the
## quantisation: live at most one frame after 0.4 s).
var input_live_s: float = -1.0
## Wall ms of `_build()` (the scene tree, rooms, rigs, atlases) — the launch budget's biggest item.
var build_ms: int = -1
var input_live_dt: float = 0.0
## Sim cost per tick (ms, smoothed; the debug overlay's "sim ms"): measured from the frame start
## (a probe node that runs before the SimDriver) to each `ticked`, incl. the tick's event handlers.
var sim_ms_per_tick: float = 0.0
var _tick_t0: int = 0

var _has_ctx: bool = false
var _ctx: Dictionary = {}
var _empty_ctx: Dictionary = {}
var _ctx_tick := -1
var _ctx_cache: Dictionary = {}
var _ctx_world := 0
var _warm_since: float = 0.0
var _card: Control = null
var _cold: Node = null
var _pause_menu: Control = null
var _paused_why: PackedStringArray = PackedStringArray()
var _laugh_idx: int = -1
var _laugh_age: float = 99.0
var _spot_start_tick: int = -1
## Seconds since the last player input (N4: the spotlight on the next useful spot after 6 s).
var idle_s: float = 0.0
## 3D: hotspot → the Script line (pip) index of the prank rigged there (tag flights).
var _hotspot_line: Dictionary = {}
var _pending_flights: Array = []
## 3D: the entry warning into Hush's room lasts until this tick (−1 none) — OverlayRules' V2 flag.
var _entry_until: int = -1
var _keep_buf: Array = []
var _safe_set: Rect2 = Rect2()
## Frame start (µs) stamped by _FrameStart (the scripts' time, _FrameEnd).
var _frame_t0_us: int = 0
## D17 (r3d-fix-perf): set by the e2e driver while ScriptProf3D runs — this frame's own HUD-pass split (µs) in
## `prof_frame_us`: [ctx (snapshot, action context, env projections), presenter, hud.apply, input, cues, ftue,
## ov_next (the overlay context + next useful spot + N4 pool), ov_rules (OverlayRules.fill), ov_apply
## (WorldOverlays.apply)]. Off by default (no stamps taken).
var profile: bool = false
const PROF_PHASES: PackedStringArray = ["ctx", "presenter", "hud_apply", "input", "cues", "ftue", "ov_next",
	"ov_rules", "ov_apply"]
var prof_frame_us := PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
## Stamped by _AfterSim right after the SimDriver's _process (sim ticks + their `ticked` handlers).
var _after_sim_us: int = 0
var _retry_t0: int = -1
var _retrying: bool = false
var _flash_left: float = 0.0
var _end_reason: String = ""
var _ended: bool = false
var _live_input: bool = false
var _play_s: float = 0.0
var _prank_fires: int = 0
var _catches: int = 0
## "+NEW!" candidates besides the reel's reactions: `bit:<id>`, `combo:<id>` (+ their captions).
var _seen_extra: Array = []
## What the player already maxed (the why line skips those): link peak, near misses, bits, …
var _stats := {"link": 0, "near_miss": 0, "bits": 0, "meltdown": 0, "combo": 0, "embarrassed": 0}


# --- lifecycle --------------------------------------------------------------------------------

func _init() -> void:
	# in the group before _ready, so drivers (e2e, tests) can hook `ready` and see tick 0
	add_to_group("night_scene")


## Router / Boot hook (before _ready).
func setup(p: Dictionary) -> void:
	params = p.duplicate()


func _ready() -> void:
	process_priority = 10
	if params.is_empty() and get_tree().current_scene == self:
		cli_args = NightArgs.parse(OS.get_cmdline_user_args())
		cli = true
		params = {"episode": String(cli_args["episode"]), "relaxed": bool(cli_args["relaxed"]), "from": "cli",
			"skip_intro": true, "card": String(cli_args.get("card", ""))}
	episode_id = String(params.get("episode", ""))
	if episode_id == "":
		episode_id = NightArgs.DEFAULT_EPISODE
	relaxed = bool(params.get("relaxed", ViewKit.setting("relaxed", false)))
	from = String(params.get("from", "router"))
	rise_at_ms = int(params.get("rise_at_ms", 0))
	rise_cap_ms = int(params.get("rise_cap_ms", 0))
	var t0 := Time.get_ticks_msec()
	_build()
	build_ms = Time.get_ticks_msec() - t0
	DeviceLog.note("night_build_ms", build_ms)
	DeviceLog.note("night_view", view_mode)
	if world == null:
		return
	var cmds: Array = params.get("cmds", [])
	if cli and String(cli_args.get("cmds_path", "")) != "":
		cmds = NightArgs.read_cmds(String(cli_args["cmds_path"]))
	if not cmds.is_empty():
		set_replay(cmds)
	if cli and (int(cli_args.get("seek_tick", -1)) >= 0 or bool(cli_args.get("no_curtain", false)) or bool(cli_args.get("paused", false))
			or String(cli_args.get("curtain_call", "")) != "" or String(cli_args.get("open", "")) != ""):
		_start_cli_now()
		_cli_after_start.call_deferred()
	else:
		_begin_flow()


func _exit_tree() -> void:
	replay.stop()
	if phase == Phase.PLAY or phase == Phase.END:
		DeviceLog.flush()


# --- build --------------------------------------------------------------------------------------

func _build() -> void:
	# The previous Night's art that no node holds any more is freed before this one is built
	# (texture memory, s2-fix G #7).
	ViewKit.release_textures()
	var content := ViewKit.autoload("Content")
	db = content.get("db") if content != null else null
	var sw := ViewKit.soft_script("res://sim/world/sim_world.gd")
	if db == null or sw == null:
		push_error("NightScene: no ContentDB / SimWorld")
		return
	var eps: Variant = db.get("episodes")
	if eps is Dictionary and not (eps as Dictionary).has(episode_id):
		push_warning("NightScene: unknown episode '%s', playing %s" % [episode_id, PROLOGUE])
		episode_id = PROLOGUE
	world = sw.call("create", db, episode_id, {"relaxed": relaxed})
	if world == null:
		push_error("NightScene: SimWorld.create(%s) failed" % episode_id)
		return
	_has_ctx = world.has_method("action_context")
	var probe := _FrameStart.new()
	probe.night = self
	add_child(probe)
	var probe_sim := _AfterSim.new()
	probe_sim.night = self
	add_child(probe_sim)
	var probe_end := _FrameEnd.new()
	probe_end.night = self
	add_child(probe_end)
	var probe_perf := _PerfSample.new()
	probe_perf.night = self
	add_child(probe_perf)
	driver = SimDriver.new()
	add_child(driver)
	# Our tick handler runs first: it swallows `title_card` before the views see it.
	driver.ticked.connect(_on_ticked)
	driver.setup(world)
	driver.set_paused(true)
	_warm_list = NightWarm.list(episode_id)
	var ok := _build_view_3d()
	if not ok:
		world = null
		return
	input_router = InputRouter.new()
	input_router.name = "InputRouter"
	input_router.enabled = false
	# taps stay in logical screen px: NightInput resolves them on the projected hit boxes (index §7.8)
	input_router.screen_to_world = func(p: Vector2) -> Vector2: return p
	add_child(input_router)
	audio_dir = AudioDirector.new()
	add_child(audio_dir)
	audio_dir.setup(driver, cam, world_view)
	audio_dir.muted = true
	audio_dir.set_process(false)
	overlays = WorldOverlays.new()
	add_child(overlays)
	stalls_layer = CanvasLayer.new()
	stalls_layer.layer = 9
	stalls_layer.name = "StallsLayer"
	add_child(stalls_layer)
	stalls = StallsView.new()
	stalls.hidden_at_rest = true
	stalls_layer.add_child(stalls)
	audio_dir.laugh.connect(_on_audio_laugh)
	audio_dir.crowd_special.connect(stalls.special)
	hud = Hud.new()
	add_child(hud)
	if hud.has_method("attach_pip"):
		hud.call("attach_pip", pip)
	else:
		hud.set_pip_texture(pip.get_texture())
	if world_view.fx != null:
		world_view.fx.avoid_screen_fn = _caption_avoid
	var hd := ViewKit.soft_script(HAPTICS_DIRECTOR)
	if hd != null:
		haptics_dir = hd.new()
		add_child(haptics_dir)
		if haptics_dir.has_method("setup"):
			haptics_dir.call("setup", driver)
	presenter.setup(world_view.layout, world)
	_setup_overlays()
	_wire_input()
	_setup_ftue()
	curtain_layer = CanvasLayer.new()
	curtain_layer.layer = CURTAIN_LAYER
	curtain_layer.name = "CurtainLayer"
	add_child(curtain_layer)
	curtain = NightCurtain.new()
	curtain_layer.add_child(curtain)
	curtain.set_down()
	curtain.half_up.connect(_on_curtain_half_up)
	curtain.risen.connect(_on_curtain_risen)
	warmer = NightWarmer.new()
	warmer.name = "NightWarmer"
	warmer.view3d = true
	warmer.hud = hud
	warmer.cam = cam
	warmer.overlays = overlays
	warmer.octx = octx
	add_child(warmer)
	reel_log.clone_every = CLONE_EVERY
	reel_log.record_clones = false
	_apply_cli_view_flags()
	_set_phase(Phase.BUILD)




## The 3D view (r3d-view3d P0b's wiring, index §7.7–§7.9): the camera first (WorldView3D projects through it
## while it builds), then the world, the Bellows window and the gag stager.
func _build_view_3d() -> bool:
	var env := WorldEnvironment.new()
	env.name = "Environment3D"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = View3DConst.BG
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	_apply_render_settings()
	var c3 := CameraDirector3D.new()
	c3.time_source = driver
	add_child(c3)
	c3.make_current()
	cam = c3
	var wv := WorldView3D.new()
	wv.cam = c3
	add_child(wv)
	world_view = wv
	wv.warm_hint = _warm_list
	var win := String(cli_args.get("window", ""))
	if win != "":
		_set_setting("bellows_window", win)
	wv.setup(db, world.get("episode"), driver)
	if win != "":
		wv.window_mode = win
	c3.follow(wv.hush_view, _hush_lead)
	c3.set_other(wv.bellows_view)
	c3.set_keep_visible(_keep_boxes)
	var p3 := PipView3D.new()
	add_child(p3)
	p3.setup(wv, c3)
	wv.pip = p3
	pip = p3
	var st := GagStager3D.new()
	add_child(st)
	st.setup(driver, c3, wv, p3)
	stager = st
	wv.tag_flight.connect(_on_tag_flight)
	if not bool(render_cfg.get("outline", true)):
		_set_outlines(wv, false)
	return true


## 3D MSAA / render scale / outlines: NightArgs `--msaa` > Settings `msaa_3d` / `render_scale` (their defaults come
## from boot_config.json `render`) > boot_config.json; the outline switch is boot_config.json `render.outline`.
func _apply_render_settings() -> void:
	var bc := BootConfig.render()
	var ms := String(NightArgs.parse(OS.get_cmdline_user_args()).get("msaa", ""))
	if ms == "":
		ms = "2" if bool(ViewKit.setting("msaa_3d", bool(bc.get("msaa_3d", true)))) else "off"
	var scale := clampf(float(ViewKit.setting("render_scale", float(bc.get("render_scale", 1.0)))), 0.5, 1.0)
	render_cfg = {"msaa": ms, "render_scale": scale, "outline": bool(bc.get("outline", true))}
	if not is_inside_tree():
		return
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED if ms == "off" else (Viewport.MSAA_4X if ms == "4" else Viewport.MSAA_2X)
	vp.scaling_3d_scale = scale


## Outlines off (boot_config `render.outline: false`, the O2 fallback): drop every ink next pass and cull the prop ink.
func _set_outlines(root: Node, on: bool) -> void:
	if not on:
		_strip_ink(root)
		if cam != null:
			cam.cull_mask = int(cam.cull_mask) & ~View3DConst.MASK_PROP_INK


func _strip_ink(n: Node) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		if g.material_override != null:
			g.material_override.next_pass = null
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			var mi := g as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m != null:
					m.next_pass = null
	for c in n.get_children():
		_strip_ink(c)


## The world overlays, their rules' context (the Night's tables) and the tag-flight line table.
func _setup_overlays() -> void:
	overlays.setup(world_view, hud)
	var ep: Variant = world.get("episode")
	if db is ContentDB and ep is EpisodeDef:
		octx.prepare(db as ContentDB, ep as EpisodeDef, world_view.set_result, OverlayCtx.load_previews())
	_hotspot_line.clear()
	if ep is Object:
		var i := 0
		for ld in (ep as Object).get("script_lines"):
			var pk := String((ld as Object).get("prank"))
			var rp := String(octx.prank_hotspot.get(pk, "")) if pk != "" else ""
			if rp != "" and not _hotspot_line.has(rp):
				_hotspot_line[rp] = i
			i += 1


## `--no-captions` (captions and stamps hidden) and `--hud=off` (the world only) for review shots.
func _apply_cli_view_flags() -> void:
	var a := cli_args if cli else NightArgs.parse(OS.get_cmdline_user_args())
	if bool(a.get("no_captions", false)) and world_view.overlays != null:
		world_view.overlays.screen.visible = false
	if not bool(a.get("hud", true)):
		hud.visible = false
		overlays.visible = false
		stalls_layer.visible = false
		if world_view.overlays != null:
			world_view.overlays.visible = false


func _set_setting(key: String, v: Variant) -> void:
	var s := ViewKit.autoload("Settings")
	if s != null and s.has_method("set_value"):
		s.call("set_value", key, v)


## C6: the live props of Hush's room stay inside the safe rect (one reused array).
func _keep_boxes() -> Array:
	_keep_buf.clear()
	var snap := driver.snapshot()
	for id in world_view.live:
		var hs: HouseLayout.Hotspot = world_view.layout.hotspot(String(id))
		if hs != null and hs.room == snap.hush.room and not (hs.kind in ["door", "stairs", "exit"]):
			_keep_buf.append(world_view.hotspot_box(String(id)))
	return _keep_buf


var _avoid_buf: Array[Rect2] = []
## NightWarm.list(episode) computed once at build (WorldView starts its jobs early; the warmer
## works through it).
var _warm_list: Dictionary = {}


## Screen rects a pun caption must clear (s2-fix G #2): the HUD's top band — the meter and the
## Running-Gag banner — and the PiP while it shows.
func _caption_avoid() -> Array[Rect2]:
	_avoid_buf.clear()
	if hud == null:
		return _avoid_buf
	var l: Dictionary = hud.layout
	for key in [&"meter", &"banner"]:
		if l.has(key):
			_avoid_buf.append(l[key])
	if pip != null and pip.is_shown():
		_avoid_buf.append(hud.pip_rect())
	return _avoid_buf


func _wire_input() -> void:
	night_input.driver = driver
	night_input.cam = cam
	night_input.world_view = world_view
	night_input.hud = hud
	night_input.haptics = ViewKit.autoload("Haptics")
	night_input.context_fn = _context
	night_input.view3d = true
	night_input.enabled = false
	night_input.command.connect(_on_player_command)
	hud.action_down.connect(func(v: int) -> void: _intent(&"action_down", [v]))
	hud.action_up.connect(func(v: int, c: bool) -> void: _intent(&"action_up", [v, c]))
	hud.action_double_tap.connect(func(v: int) -> void: _intent(&"action_double_tap", [v]))
	hud.clarence_down.connect(func() -> void: _intent(&"clarence_down", []))
	hud.clarence_hold.connect(func() -> void: _intent(&"clarence_hold", []))
	hud.clarence_up.connect(func(ms: int) -> void: _intent(&"clarence_up", [ms]))
	hud.tray_tap.connect(func(i: int) -> void: _intent(&"tray_tap", [i]))
	hud.tray_drag.connect(func(i: int, p: Vector2) -> void: _intent(&"tray_drag", [i, p]))
	hud.pick.connect(func(item: String) -> void: _intent(&"pick", [item]))
	hud.figgis_tap.connect(func() -> void: _intent(&"figgis_tap", []))
	hud.pause_tap.connect(func() -> void: _intent(&"pause_tap", []))
	hud.overview_tap.connect(func() -> void: _intent(&"overview_tap", []))
	hud.pip_tap.connect(func() -> void: _intent(&"pip_tap", []))
	hud.pip_release.connect(func() -> void: _intent(&"pip_release", []))
	hud.meter_tap.connect(func() -> void: _intent(&"meter_tap", []))
	if hud.has_signal("bow_tap"):
		hud.bow_tap.connect(func() -> void: _intent(&"bow_tap", []))
	input_router.tapped.connect(func(p: Vector2, d: bool) -> void: _intent(&"tapped", [p, d]))
	input_router.long_pressed.connect(func(p: Vector2) -> void: _intent(&"long_pressed", [p]))
	input_router.long_released.connect(func(p: Vector2) -> void: _intent(&"long_released", [p]))
	input_router.pan.connect(func(d: Vector2) -> void: _intent(&"pan", [d]))
	input_router.pinch.connect(func(f: float, m: Vector2) -> void: _intent(&"pinch", [f, m]))


func _setup_ftue() -> void:
	var fs := ViewKit.soft_script(String(params.get("ftue_path", FTUE_DIRECTOR)))
	if fs != null:
		ftue = fs.new()
		ftue.name = "FtueDirector"
		add_child(ftue)
		if ftue.has_method("setup"):
			ftue.call("setup", {"driver": driver, "world_view": world_view, "cam": cam, "hud": hud, "fx": world_view.fx,
				"episode": episode_id, "db": db})
		if ftue.has_signal("pause_request"):
			ftue.connect("pause_request", func(on: bool) -> void: _set_pause("ftue", on, false))
		return
	cues = CueFallback.new()
	cues.setup(world, hud, world_view, cam)


func _hush_lead() -> Vector2:
	var h := driver.snapshot().hush
	return Vector2(float(h.facing) if h.moving else 0.0, 1.0 if h.running else 0.0)


func _context() -> Dictionary:
	if _has_ctx and world != null:
		# once per sim tick (the HUD, the presenter and the input read it every frame; r3d-view3d perf note)
		var tk := int(world.get("tick"))
		var wid := world.get_instance_id()
		if tk == _ctx_tick and wid == _ctx_world and not _ctx_cache.is_empty():
			return _ctx_cache
		var c: Variant = world.call("action_context")
		_ctx_tick = tk
		_ctx_world = wid
		_ctx_cache = c if c is Dictionary else _empty_ctx
		return _ctx_cache
	return _empty_ctx


## The PLAY frame's measurement (ShaderWatch first uses, Perf3D monitors) — called by `_PerfSample` after
## `_FrameEnd`, so it is not counted in the view + HUD script time it measures (index §6 row 16).
func _perf_sample(delta: float) -> void:
	if world == null or phase != Phase.PLAY or not _paused_why.is_empty():
		return
	shader_watch.frame(delta, int(world.get("tick")))
	perf3d.frame(delta, world_view)


# --- flow ---------------------------------------------------------------------------------------

func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func phase_name() -> String:
	return PHASE_NAMES[phase] if phase >= 0 and phase < PHASE_NAMES.size() else "?"


## The episode's raw dictionary (EpisodeDef.raw) or {}.
func episode_raw() -> Dictionary:
	var ep: Variant = world.get("episode") if world != null else null
	if ep is Object and (ep as Object).get("raw") is Dictionary:
		return (ep as Object).get("raw")
	return {}


func _begin_flow() -> void:
	warmer.start(_warm_list if not _warm_list.is_empty() else NightWarm.list(episode_id), world_view, pip, curtain_layer)
	var skip := bool(params.get("skip_intro", false))
	if not skip and _try_cold_open():
		return
	_after_cold_open()


func _try_cold_open() -> bool:
	var raw := episode_raw()
	if raw.get("cold_open") == null or not ResourceLoader.exists(COLD_OPEN_PLAYER):
		return false
	var s := ViewKit.soft_script(COLD_OPEN_PLAYER)
	if s == null:
		return false
	var layer := CanvasLayer.new()
	layer.layer = CURTAIN_LAYER + 1
	layer.name = "ColdOpenLayer"
	add_child(layer)
	_cold = s.new()
	layer.add_child(_cold)
	var skippable := _save_is_seen("cold:%s" % episode_id)
	var ok: Variant = _cold.call("play", episode_id, skippable) if _cold.has_method("play") else false
	if not bool(ok):
		layer.queue_free()
		_cold = null
		return false
	_set_phase(Phase.COLD_OPEN)
	_cold.connect("finished", func() -> void:
		_save_mark_seen("cold:%s" % episode_id)
		layer.queue_free()
		_cold = null
		_after_cold_open(), CONNECT_ONE_SHOT)
	return true


func _after_cold_open() -> void:
	var kind := card_kind()
	if kind == "g0":
		_card = Gate0Card.new()
		curtain_layer.add_child(_card)
		_card.connect("closed", _on_card_closed, CONNECT_ONE_SHOT)
		_set_phase(Phase.LOADING)
		return
	if kind == "loading":
		var lc := LoadingCard.new()
		var data := _loading_card_data()
		var vt: Variant = ftue.call("loading_vignette", episode_id) if ftue != null and ftue.has_method("loading_vignette") else null
		if vt is Texture2D:
			data["icon"] = vt
		lc.setup(data)
		_card = lc
		curtain_layer.add_child(lc)
		lc.closed.connect(func(_a: String) -> void: _on_card_closed(), CONNECT_ONE_SHOT)
		_set_phase(Phase.LOADING)
		return
	_enter_warm()


## "g0" (the Gate-0 3-icon card), "loading" (the rule card) or "" (none: P00, CLI, retries).
func card_kind() -> String:
	if String(params.get("card", "")) == "g0":
		return "g0"
	if bool(params.get("skip_intro", false)):
		return ""
	if episode_id == G0_EPISODE:
		return "g0" if from == "stage_door" else ""
	if episode_id == PROLOGUE:
		return ""
	var raw := episode_raw()
	return "loading" if raw.get("card") is Dictionary else ""


func _loading_card_data() -> Dictionary:
	var raw := episode_raw()
	var card: Dictionary = raw.get("card", {}) if raw.get("card") is Dictionary else {}
	var sub := UiStrings.t("loading.night", {"n": int(raw.get("index", 0))})
	return {"title": String(raw.get("title", "")), "subtitle": sub, "text": String(card.get("text", "")),
		"icon": String(card.get("icon", ""))}


func _on_card_closed(_a: Variant = null) -> void:
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null
	_enter_warm()


func _enter_warm() -> void:
	_set_phase(Phase.WARM)
	_warm_since = 0.0


func _warm_ready() -> bool:
	if warmer == null or warmer.done:
		return true
	return _warm_since >= WARM_CAP_S


## Rise now if the warm-up is done (or its cap passed) and the launch target was reached; always at
## the launch cap (Boot: 3.0 s from process start).
func _maybe_rise() -> void:
	if phase != Phase.WARM:
		return
	var now := DeviceLog.process_ms()
	if rise_cap_ms > 0 and now >= rise_cap_ms:
		start_rise()
		return
	if not _warm_ready():
		return
	if rise_at_ms > 0 and now < rise_at_ms:
		return
	start_rise()


## The curtain starts to rise: tick 0 of the sim clock is this frame (L13).
func start_rise(rise_s: float = NightCurtain.RISE_S) -> void:
	if warmer != null and not warmer.done:
		warmer.finish_now()   # the launch cap forced the rise: finish warming under the (still closed) curtain
	_set_phase(Phase.RISING)
	rise_frame = frame_n
	driver.set_paused(_is_paused_by_other())
	audio_dir.muted = false
	var a := ViewKit.autoload("Audio")
	if a != null:
		if a.has_method("play_sfx"):
			a.call("play_sfx", "curtain_rise")
		if a.has_method("music_state"):
			a.call("music_state", "curtain")
	curtain.rise(rise_s)
	if not shader_watch.armed:
		shader_watch.arm(self, warmer.warmed_keys if warmer != null else {})
	DeviceLog.mark("sim_start")
	if DeviceLog.active() and not _retrying:
		DeviceLog.note("tex_mb_by_kind", TexStats.memory_report(null).get("tracked", {}))
	curtain_rose.emit()
	if hud.has_method("flash_script") and not _retrying and episode_id != PROLOGUE and episode_id != G0_EPISODE:
		presenter.refresh_script()
		if not presenter.script_lines.is_empty():
			hud.call("flash_script", presenter.script_lines, presenter.script_loop, SCRIPT_FLASH_S)


func _is_paused_by_other() -> bool:
	return not _paused_why.is_empty()


func _on_curtain_half_up() -> void:
	if not _retrying:
		input_live_s = curtain.elapsed()
		input_live_dt = get_process_delta_time()
	_set_live_input(true)


func _on_curtain_risen() -> void:
	if phase == Phase.RISING:
		_set_phase(Phase.PLAY)
	audio_dir.set_process(true)
	if _retrying:
		_retrying = false
	else:
		DeviceLog.mark("curtain_up")


func _set_live_input(on: bool) -> void:
	_live_input = on
	var en := on and _paused_why.is_empty()
	input_router.enabled = en
	night_input.enabled = en
	if _retry_t0 >= 0 and on:
		last_retry_ms = Time.get_ticks_msec() - _retry_t0
		_retry_t0 = -1
		DeviceLog.set_retry_ms(last_retry_ms)
		retry_done.emit(last_retry_ms)


## CLI: no curtain, no card; optional seek + hold.
func _start_cli_now() -> void:
	warmer.start(_warm_list if not _warm_list.is_empty() else NightWarm.list(episode_id), world_view, pip, curtain_layer)
	warmer.finish_now()
	curtain.set_up()
	rise_frame = frame_n
	if not shader_watch.armed:
		shader_watch.arm(self, warmer.warmed_keys if warmer != null else {})
	var seek := int(cli_args.get("seek_tick", -1))
	if seek > 0:
		seek_to(seek)
	audio_dir.muted = false
	audio_dir.set_process(true)
	_set_phase(Phase.PLAY)
	var hold := bool(cli_args.get("paused", false))
	driver.set_paused(hold)
	_set_live_input(not hold)


## CLI shots: `--curtain-call=<reason>` / `--open=pause|script` after the start.
func _cli_after_start() -> void:
	var cc := String(cli_args.get("curtain_call", ""))
	if cc != "":
		_on_night_end(cc)
		return
	match String(cli_args.get("open", "")):
		"pause":
			open_pause_menu()
		"script":
			open_script_panel()
		"tbc":
			_leave("to_be_continued")


## Run the sim headless (views muted) to `tick`, then settle gags and the PiP.
func seek_to(tick: int) -> void:
	audio_dir.muted = true
	var guard := 0
	while int(world.get("tick")) < tick and not bool(world.get("ended")) and guard < 200000:
		driver.step_now()
		guard += 1
	audio_dir.muted = false
	audio_dir.clear_pending()
	stager.clear_pending()
	stager.settle_gags()
	driver.juice.reset()
	world_view.fx.clear()
	stalls.special("rest")
	world_view.advance(0.0)
	cam.snap_now()
	cam.reset_motion()
	stager.advance(0.0)
	pip.settle()
	hud.invalidate()


## Replay a command log ([[tick, cmd], …]) through the driver at the logged ticks (e2e, --cmds).
func set_replay(cmds: Array) -> void:
	replay.start(driver, cmds)


# --- per frame ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	frame_n += 1
	if world == null:
		return
	match phase:
		Phase.WARM:
			_warm_since += delta
			_maybe_rise()
		Phase.PLAY, Phase.RISING:
			_play_s += delta if _paused_why.is_empty() else 0.0
			if _paused_why.is_empty():
				idle_s += delta
	if phase <= Phase.WARM and world_view.has_method("preroll"):
		world_view.call("preroll", delta)
	if phase == Phase.RISING or phase == Phase.PLAY or phase == Phase.WARM or phase == Phase.LOADING or phase == Phase.COLD_OPEN:
		_update_hud(delta)
	if _laugh_idx >= 0:
		_laugh_age += delta
		if _laugh_age > 1.5:
			_laugh_idx = -1
	if phase == Phase.PLAY or phase == Phase.RISING:
		if not _ended and bool(world.get("ended")):
			_on_night_end(String(world.get("end_reason")))


func _update_hud(delta: float) -> void:
	var pf := profile
	var t0 := Time.get_ticks_usec() if pf else 0
	var snap := driver.snapshot()
	var ctx := _context()
	env.tick = snap.tick
	env.pip_shown = pip.is_shown()
	env.pip_escalated = pip.is_escalated()
	env.view_size = cam.view_size()
	var b := snap.bellows
	env.bellows_screen = world_view.project(world_view.actor_anchor(&"bellows", &"feet"))
	env.bellows_on_screen = world_view.bellows_on_screen()
	env.edge_lean = world_view.edge_badge_active()
	env.paused = _paused_why.has("menu") or _paused_why.has("panel")
	env.figgis_pulse = bool(ftue.call("figgis_pulse")) if ftue != null and ftue.has_method("figgis_pulse") else false
	env.can_bow = _can_bow()
	env.entry_warning = _entry_until >= 0 and snap.tick <= _entry_until
	var pc := presenter.pick_container()
	if pc != "":
		var hs: HouseLayout.Hotspot = world_view.layout.hotspot(pc)
		if hs != null:
			env.pick_screen_pos = world_view.project(world_view.anchor_of(pc, &"item"))
	var t1 := Time.get_ticks_usec() if pf else 0
	presenter.fill(model, snap, ctx, env)
	presenter.fill_r3d(model, snap, ctx, env)
	if "tray_arrows" in model:
		model.set("tray_arrows", night_input.arrows)
	var t2 := Time.get_ticks_usec() if pf else 0
	hud.apply(model)
	var t3 := Time.get_ticks_usec() if pf else 0
	_update_overlays(snap, ctx, delta)
	var t4 := Time.get_ticks_usec() if pf else 0
	night_input.advance(delta)
	var t5 := Time.get_ticks_usec() if pf else 0
	if cues != null:
		cues.suspend(cam.is_gag_active() or not _paused_why.is_empty() or map_open)
		cues.danger = env.entry_warning or model.freeze_danger != HudModel.FreezeDanger.NONE or b.reacting
		cues.idle_s = idle_s
		cues.advance(delta)
	var t6 := Time.get_ticks_usec() if pf else 0
	if ftue != null and ftue.has_method("advance"):
		ftue.call("advance", delta)
	if pf:
		var t7 := Time.get_ticks_usec()
		prof_frame_us[0] = t1 - t0
		prof_frame_us[1] = t2 - t1
		prof_frame_us[2] = t3 - t2
		prof_frame_us[3] = t5 - t4
		prof_frame_us[4] = t6 - t5
		prof_frame_us[5] = t7 - t6


## ★ earned on a Night that ends with a bow (the Prologue and Gate 0 end by themselves).
func _can_bow() -> bool:
	if episode_id == PROLOGUE or episode_id == G0_EPISODE or world == null or not world.has_method("stars"):
		return false
	var st: Array = world.call("stars")
	return st.size() > 0 and bool(st[0])


## 3D: the world overlays for this frame (OverlayRules over the snapshot; index §7.8) + the tag flights the view
## raised since the last frame; the HUD's safe rect for the camera (C6) and the anchor source.
func _update_overlays(snap: ViewSnapshot, ctx: Dictionary, _delta: float) -> void:
	if profile:
		_ov_t0 = Time.get_ticks_usec()
	var safe: Rect2 = hud.layout.get(&"safe", Rect2()) if hud.layout is Dictionary else Rect2()
	if safe.has_area() and safe != _safe_set:
		_safe_set = safe
		cam.set_safe_rect(safe)
		world_view.safe = safe
	octx.now_s = float(UiKit.now_ms()) / 1000.0
	octx.idle_s = idle_s
	octx.previews_mode = StringName(String(ViewKit.setting("previews", "always")))
	octx.entry_warning = env.entry_warning
	octx.spot_filling = snap.bellows.spot_pct > 0.0 and snap.bellows.room == snap.hush.room
	octx.reaction = snap.bellows.reacting
	octx.chase = snap.bellows.state == "CHASE"
	octx.action = ctx
	octx.hide_all = map_open or not _paused_why.is_empty() or phase == Phase.END or phase == Phase.CURTAIN_CALL
	octx.next_useful = _next_useful_cached(snap) if idle_s >= OverlayRules.IDLE_HINT_S else ""
	if cues != null and cues.sparkle_left > 0.0 and cues.sparkled != "":
		# the Prologue's sparkle cue: that spot's preview at full size while its pool is lit
		octx.next_useful = cues.sparkled
		octx.idle_s = maxf(idle_s, OverlayRules.IDLE_HINT_S)
	_update_n4_pool(octx.next_useful if idle_s >= OverlayRules.IDLE_HINT_S else "")
	var pf := profile
	var t1 := Time.get_ticks_usec() if pf else 0
	OverlayRules.fill(omodel, snap, octx)
	for f in _pending_flights:
		omodel.add_tag_flight(String(f[0]), int(f[1]))
	_pending_flights.clear()
	var t2 := Time.get_ticks_usec() if pf else 0
	overlays.apply(omodel)
	if pf:
		prof_frame_us[6] = t1 - _ov_t0
		prof_frame_us[7] = t2 - t1
		prof_frame_us[8] = Time.get_ticks_usec() - t2


var _n4_spot: String = ""
var _ov_t0: int = 0
var _n4_t: float = 0.0


## N4 (REDESIGN §4.4): after 6 s without input the next useful spot gets the spotlight pool (its preview goes to full
## size through OverlayRules); any input puts it out. Never during danger (V2).
func _update_n4_pool(spot: String) -> void:
	var danger := env.entry_warning or model.freeze_danger != HudModel.FreezeDanger.NONE or driver.snapshot().bellows.reacting
	if danger:
		spot = ""
	if spot != _n4_spot:
		if _n4_spot != "":
			world_view.sparkle(_n4_spot, 0.0)
		_n4_spot = spot
		_n4_t = 0.0
	if _n4_spot != "":
		_n4_t -= get_process_delta_time()
		if _n4_t <= 0.0:
			_n4_t = 1.0
			world_view.sparkle(_n4_spot, 1.5)


## `next_useful` at most once per NEXT_USEFUL_TICKS sim ticks (D17: it walks the Script lines and allocates; a hint
## 0.1 s late is invisible) — recomputed at once when the cached spot stops being available.
const NEXT_USEFUL_TICKS := 6
var _nu_tick: int = -1000000
var _nu_spot: String = ""


func _next_useful_cached(snap: ViewSnapshot) -> String:
	if snap.tick < _nu_tick or snap.tick - _nu_tick >= NEXT_USEFUL_TICKS \
			or (_nu_spot != "" and not _spot_available(snap, _nu_spot)):
		_nu_tick = snap.tick
		_nu_spot = next_useful(snap)
	return _nu_spot


## The hint ladder's "next useful" spot (GDD §6.4, REDESIGN §4.4 N4): the `hint.rig_point` of the first open Script
## line whose `when` activity is his current or next one; else the nearest available rig point of her room.
func next_useful(snap: ViewSnapshot) -> String:
	var ep: Variant = world.get("episode") if world != null else null
	if ep is Object and world.has_method("line_states"):
		var done := {}
		for st in world.call("line_states"):
			if st is Dictionary and bool((st as Dictionary).get("done", false)):
				done[String((st as Dictionary).get("id", ""))] = true
		var lines: Variant = (ep as Object).get("script_lines")
		if lines is Array:
			for ld in lines:
				if not (ld is Object) or done.has(String((ld as Object).get("id"))):
					continue
				var hint: Variant = (ld as Object).get("hint")
				if not (hint is Dictionary):
					continue
				var h: Dictionary = hint
				var rp := String(h.get("rig_point", "")) if h.get("rig_point") != null else ""
				var when := String(h.get("when", "")) if h.get("when") != null else ""
				if rp == "" or not _spot_available(snap, rp):
					continue
				if when == "" or when == snap.bellows.activity or when == snap.bubble_next:
					return rp
	return OverlayRules.suggest_next_useful(snap, octx)


## Available = enabled, not rigged, not spent (N2).
static func _spot_available(snap: ViewSnapshot, hs: String) -> bool:
	var st: Variant = snap.hotspots.get(hs, null)
	if not (st is Dictionary):
		return true
	var d: Dictionary = st
	return bool(d.get("enabled", true)) and not bool(d.get("rigged", false)) and not bool(d.get("spent", false))


## WorldView3D: a prank landed — its tag flies from the prop to its Script pip.
func _on_tag_flight(hotspot: String) -> void:
	_pending_flights.append([hotspot, int(_hotspot_line.get(hotspot, -1))])


# --- sim events ---------------------------------------------------------------------------------

func _on_ticked(events: Array) -> void:
	var now := Time.get_ticks_usec()
	if _tick_t0 > 0:
		sim_ms_per_tick = lerpf(sim_ms_per_tick, float(now - _tick_t0) / 1000.0, 0.05)
	_tick_t0 = now
	if phase == Phase.CURTAIN_CALL:
		return
	# `title_card` during PLAY is swallowed (the curtain call slams the title after the fall).
	var i := events.size() - 1
	while i >= 0:
		var d: Dictionary = events[i]
		if String(d.get("e", "")) == "director_cue" and String(d.get("id", "")) == "title_card":
			events.remove_at(i)
		i -= 1
	if rise_frame < 0:
		events_before_rise += events.size()
	presenter.on_events(events)
	if ftue != null and ftue.has_method("on_ticked"):
		ftue.call("on_ticked", events)
	elif cues != null:
		cues.on_events(events)
	reel_log.on_events(events, world)
	_on_ticked_3d(events)
	for ev in events:
		var d: Dictionary = ev
		var e := String(d.get("e", ""))
		match e:
			"safety_net":
				driver.set_safety_slowmo(bool(d.get("on", false)))
			"night_end":
				_on_night_end(String(d.get("reason", "")))
			"squeak":
				DeviceLog.mark("first_squeak")
			"spot_start":
				_spot_start_tick = int(d.get("t", 0))
			"caught":
				_catches += 1
				var st := int(d.get("spotted_tick", d.get("t", 0)))
				var fill := float(st - _spot_start_tick) / 60.0 if _spot_start_tick >= 0 else -1.0
				DeviceLog.catch(fill, String(d.get("cause", "")))
			"prank_fire":
				_prank_fires += 1
			"squeak_bit":
				_stats["bits"] = int(_stats["bits"]) + 1
				var bid := String(d.get("bit", d.get("id", "")))
				if bid != "":
					_seen_extra.append(["bit:%s" % bid, ""])
			"combo":
				_stats["combo"] = int(_stats["combo"]) + 1
				var cid := String(d.get("id", ""))
				var cap := ""
				var cinfo: Variant = world_view.info.call("combo_caption", cid) if world_view.info != null and world_view.info.has_method("combo_caption") else ""
				if cinfo is String:
					cap = cinfo
				_seen_extra.append(["combo:%s" % cid, cap])
			"near_miss":
				_stats["near_miss"] = int(_stats["near_miss"]) + 1
			"meltdown_start":
				_stats["meltdown"] = int(_stats["meltdown"]) + 1
			"embarrassed":
				_stats["embarrassed"] = int(_stats["embarrassed"]) + 1
			"running_gag":
				_stats["link"] = maxi(int(_stats["link"]), int(d.get("link", d.get("n", 0))))
			"reaction_accent":
				DeviceLog.mark("first_prank")
			"all_lines_done":
				_all_lines_done()
		if SimEvents.is_laugh(d):
			var kind := e
			if e == "director_cue":
				kind = String(d.get("id", ""))
			elif d.has("prank"):
				kind = "%s:%s" % [e, String(d["prank"])]
			elif d.has("bit"):
				kind = "%s:%s" % [e, String(d["bit"])]
			_laugh_idx = DeviceLog.laugh(kind, -1)
			_laugh_age = 0.0
			if e != "director_cue":
				DeviceLog.mark("first_player_laugh")


## 3D bookkeeping per tick: the entry-warning window for the overlays' V2 rule and the Gag Reel's recorded
## moments (MomentRecorder3D windows kept at each reaction).
func _on_ticked_3d(events: Array) -> void:
	var snap := driver.snapshot()
	for ev in events:
		var d: Dictionary = ev
		match String(d.get("e", "")):
			"entry_warning":
				var room := String(d.get("room", ""))
				if room == "" or room == snap.hush.room:
					_entry_until = int(d.get("t", snap.tick)) + int(d.get("eta", 60)) + 18
			"b_room":
				if String(d.get("room", "")) == snap.hush.room:
					_entry_until = -1
	reel_log.keep_3d(events, world_view.recorder if world_view != null else null)


func _on_audio_laugh(tier: int) -> void:
	stalls.react(tier)
	if _laugh_idx >= 0:
		DeviceLog.set_laugh_tier(_laugh_idx, tier)
		_laugh_idx = -1


func _all_lines_done() -> void:
	# the bow chant belongs to Nights that end with a bow (the Prologue and Gate 0 end by themselves)
	if episode_id == G0_EPISODE or episode_id == PROLOGUE:
		return
	var a := ViewKit.autoload("Audio")
	if a != null and a.has_method("crowd"):
		a.call("crowd", "bow_chant")
	stalls.special("chant")
	if world_view.has_method("sparkle"):
		world_view.call("sparkle", "hall_front_door", 8.0)


func _on_player_command(_cmd: Dictionary) -> void:
	idle_s = 0.0
	DeviceLog.mark("first_input")
	if cues != null:
		cues.on_input()


# --- intents ------------------------------------------------------------------------------------

func _intent(intent: StringName, args: Array) -> void:
	if ftue != null and ftue.has_method("on_intent") and bool(ftue.call("on_intent", intent, args)):
		return
	if cues != null:
		cues.on_input()
	idle_s = 0.0
	if map_open and _map_intent(intent, args):
		return
	match intent:
		&"action_down":
			night_input.on_action_down(int(args[0]))
		&"action_up":
			night_input.on_action_up(int(args[0]), bool(args[1]))
		&"action_double_tap":
			night_input.on_action_double_tap(int(args[0]))
		&"clarence_down":
			night_input.on_clarence_down()
		&"clarence_hold":
			night_input.on_clarence_hold()
		&"clarence_up":
			night_input.on_clarence_up(int(args[0]))
		&"tray_tap":
			night_input.on_tray_tap(int(args[0]))
		&"tray_drag":
			night_input.on_tray_drag(int(args[0]), args[1])
		&"pick":
			night_input.on_pick(String(args[0]))
		&"figgis_tap":
			if cues != null:
				cues.figgis_tap()
		&"pause_tap":
			if _live_input:
				open_pause_menu()
		&"overview_tap":
			night_input.on_overview_tap()
		&"pip_tap":
			night_input.on_pip_tap()
		&"pip_release":
			night_input.on_pip_release()
		&"meter_tap":
			if _live_input:
				open_script_panel()
		&"bow_tap":
			if _live_input and _can_bow():
				bow()
		&"tapped":
			night_input.on_tapped(args[0], bool(args[1]))
		&"long_pressed":
			night_input.on_long_pressed(args[0])
		&"long_released":
			night_input.on_long_released(args[0])
		&"pan":
			night_input.on_pan(args[0])
		&"pinch":
			night_input.on_pinch(float(args[0]), args[1])


# --- pause / back / background ------------------------------------------------------------------

## Pause the Night for `why` ("menu", "panel", "ftue", "background", "curtain"); `dim` greys the HUD.
func _set_pause(why: String, on: bool, _dim: bool = true) -> void:
	if on and not _paused_why.has(why):
		_paused_why.append(why)
	elif not on and _paused_why.has(why):
		_paused_why.remove_at(_paused_why.find(why))
	var any := not _paused_why.is_empty()
	var sim_running := phase == Phase.PLAY or phase == Phase.RISING
	if sim_running:
		driver.set_paused(any)
	var a := ViewKit.autoload("Audio")
	var hard := _paused_why.has("menu") or _paused_why.has("panel") or _paused_why.has("background")
	if a != null and a.has_method("set_paused"):
		a.call("set_paused", hard)
	if any:
		night_input.release_holds()
		if cam != null:
			cam.set_hold_offset(false)
	var only_map := map_open and _paused_why.size() == 1 and _paused_why.has("map")
	input_router.enabled = _live_input and (not any or only_map)
	night_input.enabled = input_router.enabled and not map_open


func is_paused() -> bool:
	return not _paused_why.is_empty()


## Android back / Escape: close the top panel, else open the pause menu. Never quits.
func handle_back() -> bool:
	if curtain_call != null and curtain_call.has_method("handle_back"):
		return bool(curtain_call.call("handle_back"))
	if map_open:
		close_map()
		return true
	var top := hud.top_panel() if hud != null else null
	if top != null and top.has_method("handle_back"):
		top.call("handle_back")
		return true
	if phase == Phase.PLAY and _live_input:
		open_pause_menu()
	return true


## The pause menu (Resume, Retry, Take a Bow when ★, Settings, Playbill).
func open_pause_menu() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		return
	var menu := PauseMenu.new()
	var st: Array = world.call("stars") if world.has_method("stars") else [false, false, false]
	var header := {"applause": int(world.call("applause_tenths")) / 10 if world.has_method("applause_tenths") else 0}
	var snap := driver.snapshot()
	if snap != null and snap.tomatoes_max > 0:
		header["tomatoes_left"] = snap.tomatoes_max - snap.tomatoes
		header["tomatoes_max"] = snap.tomatoes_max
	header["curtain_calls"] = st.count(true)
	menu.setup(st.size() > 0 and bool(st[0]) and _can_bow(), header)
	_pause_menu = menu
	hud.show_panel(menu)
	_set_pause("menu", true)
	model.paused = true
	menu.closed.connect(_on_pause_closed, CONNECT_ONE_SHOT)


func _on_pause_closed(action: String) -> void:
	_pause_menu = null
	match action:
		"retry":
			_set_pause("menu", false)
			retry()
		"bow":
			_set_pause("menu", false)
			bow()
		"settings":
			var sp := SettingsPanel.new()
			hud.show_panel(sp)
			sp.closed.connect(func(_a: String) -> void:
				_set_pause("menu", false)
				open_pause_menu(), CONNECT_ONE_SHOT)
		"playbill":
			_set_pause("menu", false)
			_leave("playbill")
		"hint":
			_set_pause("menu", false)
			hint()
		"map":
			_set_pause("menu", false)
			open_map()
		_:
			_set_pause("menu", false)


## The Script panel (tap on the meter; pauses).
func open_script_panel() -> void:
	var sp := ScriptPanel.new()
	presenter.refresh_script()
	sp.setup(presenter.script_lines, presenter.script_loop, presenter.lines_done, presenter.lines_total)
	hud.show_panel(sp)
	_set_pause("panel", true)
	sp.closed.connect(func(_a: String) -> void: _set_pause("panel", false), CONNECT_ONE_SHOT)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_on_background()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			pass   # coming back lands in the pause menu, never straight into play


## Backgrounding (a pulled-down notification, a call): open the pause menu, stop the sim and the
## audio, flush the device log.
func _on_background() -> void:
	DeviceLog.flush()
	if driver != null:
		CmdLog.write(episode_id, driver.cmd_log)
	if phase == Phase.PLAY or phase == Phase.RISING:
		if _live_input and (_pause_menu == null or not is_instance_valid(_pause_menu)):
			open_pause_menu()
		elif not _live_input:
			_set_pause("background", true)


# --- hint / map ------------------------------------------------------------------------------------

## The pause panel's Hint (Figgis steps 2–3): his card for the next line, and the spotlight pool on the next useful
## spot (N4) for 4 s.
func hint() -> void:
	if cues != null:
		cues.figgis_tap()
	var nu := next_useful(driver.snapshot())
	if nu != "" and world_view.has_method("sparkle"):
		world_view.call("sparkle", nu, 4.0)


## The Map (3D; the pause panel's Map): the sim stays paused, the camera dollies back to 15 m (the Overview); a tap
## on a built room peeks at it, a tap outside or Back returns to the play framing.
func open_map() -> void:
	if map_open:
		return
	map_open = true
	_set_pause("map", true)
	if not bool(cam.is_overview()):
		cam.toggle_overview()


func close_map() -> void:
	if not map_open:
		return
	map_open = false
	if bool(cam.is_overview()):
		cam.toggle_overview()
	_set_pause("map", false)


## Map taps: a built room → peek there; anything else → back to play. Swallows every gameplay intent.
func _map_intent(intent: StringName, args: Array) -> bool:
	match intent:
		&"tapped":
			var room := map_room_at(args[0])
			if room == "":
				close_map()
			else:
				var r: HouseLayout.Room = world_view.layout.room(room)
				cam.peek(Vector2((r.x0 + r.x1) * 0.5, world_view.layout.room_floor_y(room)), MAP_PEEK_S)
			return true
		&"pause_tap":
			close_map()
			return true
		&"pan", &"pinch":
			return false
	return true


## The built room under a screen point on Hush's floor ("" = none).
func map_room_at(screen_pos: Vector2) -> String:
	var wp: Vector2 = cam.screen_to_world(screen_pos)
	var fl: int = driver.snapshot().hush.floor
	for r in world_view.layout.rooms:
		var room: HouseLayout.Room = r
		if room.floor != fl or not (world_view.unlocked as PackedStringArray).has(room.id):
			continue
		if wp.x >= room.x0 and wp.x <= room.x1:
			return room.id
	return ""


# --- retry / bow ---------------------------------------------------------------------------------

## Retry in place (≤ 1.5 s from the tap to live control): a quick curtain dip, the sim + view reset
## underneath, then a short rise (tick 0 = its first frame again).
func retry() -> void:
	_retry_t0 = Time.get_ticks_msec()
	_retrying = true
	_set_live_input(false)
	night_input.release_holds()
	hud.close_panels()
	driver.set_paused(true)
	if curtain_call != null and is_instance_valid(curtain_call):
		curtain_call.queue_free()
		curtain_call = null
	hud.visible = true
	stalls_layer.visible = true
	if not curtain.is_down():
		curtain.fall(RETRY_DROP_S)
		await curtain.fallen
	reset_night()
	start_rise(RETRY_RISE_S)


## Everything retry resets (headless-testable; ≤ 300 ms).
func reset_night() -> void:
	_paused_why.clear()
	if map_open and cam != null and bool(cam.is_overview()):
		cam.toggle_overview()
	map_open = false
	var a := ViewKit.autoload("Audio")
	if a != null:
		if a.has_method("set_paused"):
			a.call("set_paused", false)
		if a.has_method("stop_all"):
			a.call("stop_all", false)
	driver.set_paused(true)
	driver.reset()
	if replay.driver != null:
		replay.rewind()
	world_view.reset()
	stager.reset()
	stager.settle_gags()
	audio_dir.clear_pending()
	pip.settle()
	presenter.reset()
	night_input.reset()
	if cues != null:
		cues.reset()
	if ftue != null and ftue.has_method("reset"):
		ftue.call("reset")
	reel_log.reset()
	hud.close_panels()
	hud.invalidate()
	cam.snap_now()
	cam.reset_motion()
	stalls.special("rest")
	_ended = false
	_end_reason = ""
	_play_s = 0.0
	_prank_fires = 0
	_catches = 0
	_seen_extra.clear()
	for k in _stats:
		_stats[k] = 0
	_spot_start_tick = -1
	rise_frame = -1
	model.paused = false
	idle_s = 0.0
	_entry_until = -1
	_pending_flights.clear()
	map_open = false
	octx.reset()
	omodel.clear()
	world_view.set_process(true)


## Take a Bow (after ★; from the pause menu or on arrival at the front door, which the sim does).
func bow() -> void:
	driver.push_cmd({"c": "bow"})


# --- the end and the curtain call ----------------------------------------------------------------

func _on_night_end(reason: String) -> void:
	if _ended:
		return
	_ended = true
	_end_reason = reason
	_set_phase(Phase.END)
	_set_live_input(false)
	night_input.release_holds()
	hud.close_panels()
	DeviceLog.mark("night_end:%s" % reason)
	DeviceLog.note("perf3d:%s" % episode_id, perf3d.summary(shader_watch))
	if overlays != null:
		overlays.visible = false
	pip.hide_now()
	night_ended.emit(reason)
	var result := collect_result()
	_save_result(result)
	CmdLog.write(episode_id, driver.cmd_log)
	DeviceLog.flush()
	result.merge(curtain_extras(result), true)
	curtain_call = CurtainCall.new()
	curtain_call.name = "CurtainCall"
	add_child(curtain_call)
	curtain_call.connect("action", _on_curtain_call_action)
	hud.visible = false
	_set_phase(Phase.CURTAIN_CALL)
	curtain_call.call("start", self, CurtainCall.kind_for(episode_id, reason), result)


## What the curtain call shows beyond the Save result: the why line, "+NEW!" chips, the title,
## the Gag Reel moments + the command log that re-stages them, Next availability, his residues.
func curtain_extras(r: Dictionary) -> Dictionary:
	var raw := episode_raw()
	var kind := CurtainCall.kind_for(episode_id, _end_reason)
	var n_pranks := 0
	var lines: Array = []
	var ep: Variant = world.get("episode")
	for st in r.get("line_states", []):
		var d: Dictionary = (st as Dictionary).duplicate()
		var ld: Variant = ep.call("line", String(d.get("id", ""))) if ep is Object and (ep as Object).has_method("line") else null
		if ld is Object:
			d["prank"] = String((ld as Object).get("prank"))
			d["text"] = String((ld as Object).get("text"))
		lines.append(d)
		n_pranks += 1
	var barks: Variant = ViewKit.json("res://data/barks.json")
	var templates: Dictionary = (barks as Dictionary).get("results", {}) if barks is Dictionary else {}
	var missed: Dictionary = (barks as Dictionary).get("missed", {}) if barks is Dictionary else {}
	var why_in := {"episode": episode_id, "prologue": kind == CurtainCall.KIND_PROLOGUE, "applause": r.get("applause", 0),
		"catches": r.get("catches", 0), "stars": r.get("stars", []), "lines": lines,
		"can": WhyMissed.offers(raw, n_pranks, true), "maxed": maxed_of(_stats)}
	var why := "" if kind == CurtainCall.KIND_GATE0 else String(WhyMissed.pick(why_in, templates, missed)["text"])
	var new_keys := PackedStringArray()
	for m in reel_log.moments:
		for k in (m as Dictionary).get("keys", []):
			if _save_mark_seen(String(k)):
				(m as Dictionary)["new"] = true
				new_keys.append(String((m as Dictionary).get("prank", "")))
	var captions := PackedStringArray()
	for se in _seen_extra:
		if _save_mark_seen(String(se[0])) and String(se[1]) != "" and not captions.has(String(se[1])):
			captions.append(String(se[1]))
	for pid in new_keys:
		var pd: Variant = null
		var pranks: Variant = db.get("pranks") if db != null else null
		if pranks is Dictionary:
			pd = (pranks as Dictionary).get(pid, null)
		var cap := String((pd as Object).get("caption")) if pd is Object else pid
		if cap != "" and not captions.has(cap):
			captions.append(cap)
	var best: Array = reel_log.best(1 if kind == CurtainCall.KIND_GATE0 else 3, bool(r.get("repeat", false)))
	var residues := PackedStringArray()
	var snap := driver.snapshot()
	if snap != null and snap.bellows != null:
		residues = snap.bellows.residues.duplicate()
	return {"why": why, "new": Array(captions), "title": String(raw.get("title", "")), "moments": best,
		"cmds": driver.cmd_log.duplicate(), "has_next": true, "residues": residues}


## The "short" why lines the player already maxed this Night (pure).
static func maxed_of(st: Dictionary) -> Dictionary:
	return {"short_link": int(st.get("link", 0)) >= 3, "short_meltdown": int(st.get("meltdown", 0)) > 0,
		"short_near_misses": int(st.get("near_miss", 0)) >= 3, "short_bits": int(st.get("bits", 0)) >= 3,
		"short_combo": int(st.get("combo", 0)) > 0, "short_embarrassed": int(st.get("embarrassed", 0)) > 0}


## The Night's result for Save + the curtain call.
func collect_result() -> Dictionary:
	var stars: Array = world.call("stars") if world.has_method("stars") else [false, false, false]
	var lines := PackedStringArray()
	var candles := PackedStringArray()
	for st in (world.call("line_states") if world.has_method("line_states") else []):
		if bool(st.get("done", false)):
			lines.append(String(st.get("id", "")))
		if bool(st.get("candle", false)):
			candles.append(String(st.get("id", "")))
	var applause := int(world.call("applause_tenths")) / 10 if world.has_method("applause_tenths") else 0
	return {"episode": episode_id, "reason": _end_reason, "stars": stars, "applause": applause, "lines": Array(lines),
		"candles": Array(candles), "encores": [], "catches": _catches, "pranks": _prank_fires,
		"play_s": int(round(_play_s)), "line_states": world.call("line_states") if world.has_method("line_states") else []}


## CLI shots (`from: cli`) never write the player's save (every sandbox shares one user:// dir).
func _save_writes() -> bool:
	return from != "cli" and not bool(params.get("no_save", false))


func _save_result(r: Dictionary) -> void:
	var sv := ViewKit.autoload("Save")
	r["repeat"] = sv != null and sv.has_method("night") and not (sv.call("night", episode_id) as Dictionary).is_empty()
	if sv == null or episode_id == G0_EPISODE or not _save_writes():
		return
	if sv.has_method("record_result"):
		sv.call("record_result", episode_id, {"stars": r["stars"], "applause": r["applause"], "lines": r["lines"],
			"candles": r["candles"], "encores": r["encores"], "catches": r["catches"], "pranks": r["pranks"],
			"play_s": r["play_s"]})
	if episode_id == PROLOGUE and sv.has_method("set_prologue_done"):
		sv.call("set_prologue_done")


func _on_curtain_call_action(action: String) -> void:
	curtain_call_action.emit(action)
	match action:
		"retry", "again":
			retry()
		"next":
			# (r3d QA Q-N1) a hidden preview Night opens behind the stage door's WIP card
			var to := BootRouting.after_next(BootRouting.next_episode(episode_id), StageDoor.previews_on(),
				_has_stage_door())
			_leave(String(to["route"]), to["params"])
		"playbill":
			_leave("playbill")
		"stage_door":
			_leave("stage_door")


## True when this build has the stage door (debug builds: the Router has its scene).
func _has_stage_door() -> bool:
	var r := ViewKit.autoload("Router")
	return r != null and r.has_method("has_scene") and bool(r.call("has_scene", "stage_door"))


## Leave the Night through the Router (or change_scene_to_file when a route is missing).
func _leave(route: String, p: Dictionary = {}) -> void:
	DeviceLog.flush()
	var r := ViewKit.autoload("Router")
	if route == "to_be_continued":
		var card := ToBeContinued.new()
		curtain_layer.add_child(card)
		card.closed.connect(func() -> void: _leave("playbill"), CONNECT_ONE_SHOT)
		return
	if route == "stage_door" and (r == null or not r.has_method("has_scene") or not bool(r.call("has_scene", "stage_door"))):
		get_tree().change_scene_to_file(StageDoor.SCENE)
		return
	if r != null and r.has_method("replace"):
		r.call("replace", route, p)


# --- save helpers ---------------------------------------------------------------------------------

func _save_is_seen(key: String) -> bool:
	var sv := ViewKit.autoload("Save")
	return sv != null and sv.has_method("is_seen") and bool(sv.call("is_seen", key))


func _save_mark_seen(key: String) -> bool:
	var sv := ViewKit.autoload("Save")
	if sv != null and not _save_writes():
		return not _save_is_seen(key)
	return sv != null and sv.has_method("mark_seen") and bool(sv.call("mark_seen", key))


## Runs before the SimDriver each frame: stamps the frame start for `sim_ms_per_tick` and the scripts' time.
class _FrameStart:
	extends Node
	var night: Node = null

	func _init() -> void:
		name = "FrameStart"
		process_priority = -101

	func _process(_d: float) -> void:
		if night != null:
			var now := Time.get_ticks_usec()
			night.set("_tick_t0", now)
			night.set("_frame_t0_us", now)


## Runs right after the SimDriver (priority −100): splits the frame's script time into the sim part (the ticks and
## their `ticked` handlers) and the view + HUD part (every later `_process`).
class _AfterSim:
	extends Node
	var night: Node = null

	func _init() -> void:
		name = "AfterSim"
		process_priority = -99

	func _process(_d: float) -> void:
		if night != null:
			night.set("_after_sim_us", Time.get_ticks_usec())


## Runs after `_FrameEnd` (priority 901): the measurement code (ShaderWatch, Perf3D) stays out of the window it measures.
class _PerfSample:
	extends Node
	var night: Node = null

	func _init() -> void:
		name = "PerfSample"
		process_priority = 901

	func _process(d: float) -> void:
		if night != null:
			night.call("_perf_sample", d)


## Runs after every other node's `_process` (the sim, the view, the HUD, the overlays): the frame's script time
## for `perf3d.script_ms_p95`, and its view + HUD part (`perf3d.view_ms_p95`, REDESIGN §6.3's "view + HUD scripts
## ≤ 4 ms/frame p95").
class _FrameEnd:
	extends Node
	var night: Node = null

	func _init() -> void:
		name = "FrameEnd"
		process_priority = 900

	func _process(_d: float) -> void:
		if night == null:
			return
		var t0 := int(night.get("_frame_t0_us"))
		if t0 > 0 and int(night.get("phase")) == 5:
			var now := Time.get_ticks_usec()
			var ts := int(night.get("_after_sim_us"))
			var sim_ms := float(ts - t0) / 1000.0 if ts >= t0 else 0.0
			(night.get("perf3d") as Perf3D).add_script_ms(float(now - t0) / 1000.0, sim_ms)
