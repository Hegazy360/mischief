## NightScene — one playable Night: the sim, view, HUD, input and audio wired together (TECH §5.1).
## It owns no gameplay rules: the SimWorld decides, the view shows, this scene connects them and runs
## the Night's flow (s2-night §4.1–§4.4):
##
##   BUILD → COLD OPEN (FTUE hook) → LOADING (the rule card / the Gate-0 card) → WARM (under the curtain)
##   → RISING (tick 0 = the curtain-rise frame, input live at half up) → PLAY → END (the curtain falls)
##   → CURTAIN CALL (bow, roses, results, Gag Reel) → Next Night ▶ / Retry / Playbill (Again ▶ / Stage door
##   for Gate 0).
##
## Scene tree (built in `_build`, TECH §5.1): SimDriver · World (WorldView) · CameraDirector (+ JuiceClock)
## · InputRouter · AudioDirector · PipView · GagStager · Stalls (layer 9) · Hud (layer 10) ·
## HapticsDirector (soft) · FtueDirector (soft) · Curtain (layer 20).
##
## Hooks: `setup(params)` before `_ready` — `{episode, relaxed, from, rise_at_ms, card, skip_intro, cmds}`;
## `handle_back() -> bool` (closes the top panel, else opens the pause menu; never quits).
## As the main scene (debug) it reads the NightArgs flags: `--episode --cmds --seek-tick --paused
## --relaxed --no-curtain`.
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
const FTUE_DIRECTOR := "res://ui/ftue/ftue_director.gd"
const COLD_OPEN_PLAYER := "res://ui/ftue/cold_open_player.gd"
const HAPTICS_DIRECTOR := "res://view/haptics_director.gd"
const CONDITIONS := "res://sim/systems/conditions.gd"
const G0_EPISODE := "g0_sneeze"
const PROLOGUE := "p00_curtain_up"
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
var world_view: WorldView = null
var cam: CameraDirector = null
var input_router: InputRouter = null
var audio_dir: AudioDirector = null
var pip: PipView = null
var stager: GagStager = null
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

## Engine ms of the first allowed rise (Boot passes the launch target; 0 = as soon as ready).
var rise_at_ms: int = 0
## Tick-0 bookkeeping for the sim clock contract (tests / e2e).
var rise_frame: int = -1
var frame_n: int = 0
var events_before_rise: int = 0
## Retry measurement.
var last_retry_ms: int = -1

var _has_ctx: bool = false
var _ctx: Dictionary = {}
var _empty_ctx: Dictionary = {}
var _warm_since: float = 0.0
var _card: Control = null
var _cold: Node = null
var _pause_menu: Control = null
var _paused_why: PackedStringArray = PackedStringArray()
var _laugh_idx: int = -1
var _laugh_age: float = 99.0
var _spot_start_tick: int = -1
var _retry_t0: int = -1
var _retrying: bool = false
var _flash_left: float = 0.0
var _end_reason: String = ""
var _ended: bool = false
var _live_input: bool = false
var _play_s: float = 0.0
var _prank_fires: int = 0
var _catches: int = 0


# --- lifecycle --------------------------------------------------------------------------------

## Router / Boot hook (before _ready).
func setup(p: Dictionary) -> void:
	params = p.duplicate()


func _ready() -> void:
	process_priority = 10
	add_to_group("night_scene")
	if params.is_empty() and get_tree().current_scene == self:
		cli_args = NightArgs.parse(OS.get_cmdline_user_args())
		cli = true
		params = {"episode": String(cli_args["episode"]), "relaxed": bool(cli_args["relaxed"]), "from": "cli",
			"skip_intro": true}
	episode_id = String(params.get("episode", ""))
	if episode_id == "":
		episode_id = NightArgs.DEFAULT_EPISODE
	relaxed = bool(params.get("relaxed", ViewKit.setting("relaxed", false)))
	from = String(params.get("from", "router"))
	rise_at_ms = int(params.get("rise_at_ms", 0))
	_build()
	if world == null:
		return
	var cmds: Array = params.get("cmds", [])
	if cli and String(cli_args.get("cmds_path", "")) != "":
		cmds = NightArgs.read_cmds(String(cli_args["cmds_path"]))
	if not cmds.is_empty():
		set_replay(cmds)
	if cli and (int(cli_args.get("seek_tick", -1)) >= 0 or bool(cli_args.get("no_curtain", false)) or bool(cli_args.get("paused", false))):
		_start_cli_now()
	else:
		_begin_flow()


func _exit_tree() -> void:
	replay.stop()
	if phase == Phase.PLAY or phase == Phase.END:
		DeviceLog.flush()


# --- build --------------------------------------------------------------------------------------

func _build() -> void:
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
	driver = SimDriver.new()
	add_child(driver)
	# Our tick handler runs first: it swallows `title_card` before the views see it.
	driver.ticked.connect(_on_ticked)
	driver.setup(world)
	driver.set_paused(true)
	cam = CameraDirector.new()
	cam.time_source = driver
	world_view = WorldView.new()
	world_view.cam = cam
	add_child(world_view)
	world_view.setup(db, world.get("episode"), driver)
	add_child(cam)
	cam.setup(world_view.layout)
	cam.stage_x_range = world_view.lit_x_range()
	cam.make_current()
	cam.follow(world_view.hush_view, _hush_lead)
	input_router = InputRouter.new()
	input_router.name = "InputRouter"
	input_router.enabled = false
	add_child(input_router)
	pip = PipView.new()
	add_child(pip)
	pip.target = world_view.bellows_view
	stager = GagStager.new()
	add_child(stager)
	stager.setup(driver, cam, world_view, pip)
	audio_dir = AudioDirector.new()
	add_child(audio_dir)
	audio_dir.setup(driver, cam, world_view)
	audio_dir.muted = true
	audio_dir.set_process(false)
	stalls_layer = CanvasLayer.new()
	stalls_layer.layer = 9
	stalls_layer.name = "StallsLayer"
	add_child(stalls_layer)
	stalls = StallsView.new()
	stalls_layer.add_child(stalls)
	audio_dir.laugh.connect(_on_audio_laugh)
	audio_dir.crowd_special.connect(stalls.special)
	hud = Hud.new()
	add_child(hud)
	if hud.has_method("attach_pip"):
		hud.call("attach_pip", pip)
	else:
		hud.set_pip_texture(pip.get_texture())
	var hd := ViewKit.soft_script(HAPTICS_DIRECTOR)
	if hd != null:
		haptics_dir = hd.new()
		add_child(haptics_dir)
		if haptics_dir.has_method("setup"):
			haptics_dir.call("setup", driver)
	presenter.setup(world_view.layout, world)
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
	add_child(warmer)
	reel_log.clone_every = CLONE_EVERY
	_set_phase(Phase.BUILD)


func _wire_input() -> void:
	night_input.driver = driver
	night_input.cam = cam
	night_input.world_view = world_view
	night_input.hud = hud
	night_input.haptics = ViewKit.autoload("Haptics")
	night_input.context_fn = _context
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
	input_router.tapped.connect(func(p: Vector2, d: bool) -> void: _intent(&"tapped", [p, d]))
	input_router.long_pressed.connect(func(p: Vector2) -> void: _intent(&"long_pressed", [p]))
	input_router.long_released.connect(func(p: Vector2) -> void: _intent(&"long_released", [p]))
	input_router.pan.connect(func(d: Vector2) -> void: _intent(&"pan", [d]))
	input_router.pinch.connect(func(f: float, m: Vector2) -> void: _intent(&"pinch", [f, m]))


func _setup_ftue() -> void:
	var fs := ViewKit.soft_script(FTUE_DIRECTOR)
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
	return Vector2(float(h.facing), 1.0 if h.running else 0.0)


func _context() -> Dictionary:
	if _has_ctx and world != null:
		var c: Variant = world.call("action_context")
		return c if c is Dictionary else _empty_ctx
	return _empty_ctx


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
	warmer.start(NightWarm.list(episode_id), world_view, pip, curtain_layer)
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
		lc.setup(_loading_card_data())
		var vt: Variant = ftue.call("loading_vignette", episode_id) if ftue != null and ftue.has_method("loading_vignette") else null
		if vt is Texture2D and lc.has_method("set_icon_texture"):
			lc.call("set_icon_texture", vt)
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


## Rise now if the warm-up is done (or its cap passed) and the launch target was reached.
func _maybe_rise() -> void:
	if phase != Phase.WARM:
		return
	if not _warm_ready():
		return
	if rise_at_ms > 0 and Time.get_ticks_msec() < rise_at_ms and _warm_since < WARM_CAP_S:
		return
	start_rise()


## The curtain starts to rise: tick 0 of the sim clock is this frame (L13).
func start_rise(rise_s: float = NightCurtain.RISE_S) -> void:
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
	DeviceLog.mark("sim_start")
	curtain_rose.emit()
	if hud.has_method("flash_script") and not _retrying and episode_id != PROLOGUE and episode_id != G0_EPISODE:
		presenter.refresh_script()
		if not presenter.script_lines.is_empty():
			hud.call("flash_script", presenter.script_lines, presenter.script_loop, SCRIPT_FLASH_S)


func _is_paused_by_other() -> bool:
	return not _paused_why.is_empty()


func _on_curtain_half_up() -> void:
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
	warmer.start(NightWarm.list(episode_id), world_view, pip, curtain_layer)
	warmer.finish_now()
	curtain.set_up()
	rise_frame = frame_n
	var seek := int(cli_args.get("seek_tick", -1))
	if seek > 0:
		seek_to(seek)
	audio_dir.muted = false
	audio_dir.set_process(true)
	_set_phase(Phase.PLAY)
	var hold := bool(cli_args.get("paused", false))
	driver.set_paused(hold)
	_set_live_input(not hold)


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
	var snap := driver.snapshot()
	var ctx := _context()
	env.tick = snap.tick
	env.pip_shown = pip.is_shown()
	env.pip_escalated = pip.is_escalated()
	env.view_size = cam.view_size()
	var b := snap.bellows
	env.bellows_screen = cam.world_to_screen(Vector2(b.x, b.y - 190.0))
	env.bellows_on_screen = cam.visible_world_rect().intersects(Rect2(b.x - 90.0, b.y - 390.0, 180.0, 390.0))
	env.paused = _paused_why.has("menu") or _paused_why.has("panel")
	env.figgis_pulse = bool(ftue.call("figgis_pulse")) if ftue != null and ftue.has_method("figgis_pulse") else false
	var pc := presenter.pick_container()
	if pc != "":
		var hs := world_view.layout.hotspot(pc)
		if hs != null:
			env.pick_screen_pos = cam.world_to_screen(Vector2(hs.rect.get_center().x, hs.rect.position.y))
	presenter.fill(model, snap, ctx, env)
	if "tray_arrows" in model:
		model.set("tray_arrows", night_input.arrows)
	hud.apply(model)
	night_input.advance(delta)
	if cues != null:
		cues.suspend(cam.is_gag_active() or not _paused_why.is_empty())
		cues.advance(delta)
	if ftue != null and ftue.has_method("advance"):
		ftue.call("advance", delta)


# --- sim events ---------------------------------------------------------------------------------

func _on_ticked(events: Array) -> void:
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


func _on_audio_laugh(tier: int) -> void:
	stalls.react(tier)
	if _laugh_idx >= 0:
		DeviceLog.set_laugh_tier(_laugh_idx, tier)
		_laugh_idx = -1


func _all_lines_done() -> void:
	var a := ViewKit.autoload("Audio")
	if a != null and a.has_method("crowd"):
		a.call("crowd", "bow_chant")
	stalls.special("chant")
	if world_view.has_method("sparkle"):
		world_view.call("sparkle", "hall_front_door", 8.0)


func _on_player_command(_cmd: Dictionary) -> void:
	DeviceLog.mark("first_input")
	if cues != null:
		cues.on_input()


# --- intents ------------------------------------------------------------------------------------

func _intent(intent: StringName, args: Array) -> void:
	if ftue != null and ftue.has_method("on_intent") and bool(ftue.call("on_intent", intent, args)):
		return
	if cues != null:
		cues.on_input()
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
	input_router.enabled = _live_input and not any
	night_input.enabled = input_router.enabled


func is_paused() -> bool:
	return not _paused_why.is_empty()


## Android back / Escape: close the top panel, else open the pause menu. Never quits.
func handle_back() -> bool:
	if curtain_call != null and curtain_call.has_method("handle_back"):
		return bool(curtain_call.call("handle_back"))
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
	menu.setup(st.size() > 0 and bool(st[0]))
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
	if phase == Phase.PLAY or phase == Phase.RISING:
		if _live_input and (_pause_menu == null or not is_instance_valid(_pause_menu)):
			open_pause_menu()
		elif not _live_input:
			_set_pause("background", true)


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
	curtain.fall(RETRY_DROP_S)
	await curtain.fallen
	reset_night()
	start_rise(RETRY_RISE_S)


## Everything retry resets (headless-testable; ≤ 300 ms).
func reset_night() -> void:
	_paused_why.clear()
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
	_spot_start_tick = -1
	rise_frame = -1
	model.paused = false


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
	night_ended.emit(reason)
	var result := collect_result()
	_save_result(result)
	DeviceLog.flush()
	curtain_call = CurtainCall.new()
	curtain_call.name = "CurtainCall"
	add_child(curtain_call)
	curtain_call.connect("action", _on_curtain_call_action)
	curtain_call.call("start", self, CurtainCall.kind_for(episode_id, reason), result)
	_set_phase(Phase.CURTAIN_CALL)


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


func _save_result(r: Dictionary) -> void:
	var sv := ViewKit.autoload("Save")
	if sv == null or episode_id == G0_EPISODE:
		return
	r["repeat"] = sv.has_method("night") and not (sv.call("night", episode_id) as Dictionary).is_empty()
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
			var nxt := BootRouting.next_episode(episode_id)
			if nxt == "":
				_leave("to_be_continued")
			else:
				_leave("night", {"episode": nxt, "from": "night"})
		"playbill":
			_leave("playbill")
		"stage_door":
			_leave("stage_door")


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
	return sv != null and sv.has_method("mark_seen") and bool(sv.call("mark_seen", key))
