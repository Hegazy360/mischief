## HudOn3D — the R3D HUD + world overlays over the REAL 3D view (brief r3d-hud §6 review shots): ViewSandbox3D's
## wiring (SimDriver → WorldView3D → CameraDirector3D → PipView3D → AudioDirector → Stalls) with the Hud, the
## Stage-2 HudPresenter and OverlayRules → WorldOverlays on WorldView3D's §7.8 anchor source. A stand-in for
## NightScene3D until r3d-night lands: the R3D HudModel fields the Night presenter will own (verb_live,
## freeze_danger, script_pips, carrying, bow/figgis/overview flags, edge badge, next-activity chip) are filled
## here from the snapshot with the simplest honest rule.
##
## User args (after `--`): everything ViewSandbox3D takes (`--sim --episode=<id> --cmds=/abs.json`, `--window=sim|lean`,
## `--stand-ins`, …) plus
##   --at=<tick>      seek there AFTER the HUD is wired (use this instead of the sandbox's --seek: the events on the
##                    way reach the presenter and the entry-warning tracker)
##   --idle-s=<s>     pretend the player has not touched the screen for this long (N4 loud previews at ≥ 6 s)
##   --no-overlays    the HUD alone     --no-hud    the overlays alone
##   --perf           print `[hudperf]` (Hud.apply + OverlayRules.fill + WorldOverlays.apply µs, median / p95)
##                    once 240 frames have been measured
extends Node

const SANDBOX := "res://view3d/sandbox/ViewSandbox3D.tscn"

var sb: Node = null
var hud: Hud = null
var overlays: WorldOverlays = null
var model := HudModel.new()
var omodel := OverlayModel.new()
var octx := OverlayCtx.new()
var presenter := HudPresenter.new()
var env := HudPresenter.HudEnv.new()
var idle_s: float = 0.0
var want_overlays: bool = true
var want_hud: bool = true
var perf: bool = false
var _us_hud := PackedFloat32Array()
var _us_rules := PackedFloat32Array()
var _us_ov := PackedFloat32Array()
var _us_prot := PackedFloat32Array()
var _us_ph: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
var _printed := false
var _world: Object = null
## The sim's "entry_warning" event into Hush's room: warning until this tick (eta + 0.3 s), -1 = none.
var _entry_until: int = -1


func _init() -> void:
	# after the sandbox (a child) has stepped the sim and the views this frame
	process_priority = 100


func _ready() -> void:
	idle_s = float(UiKit.flag_value("--idle-s")) if UiKit.flag_value("--idle-s") != "" else 0.0
	want_overlays = not UiKit.has_flag("--no-overlays")
	want_hud = not UiKit.has_flag("--no-hud")
	perf = UiKit.has_flag("--perf")
	var ps := load(SANDBOX) as PackedScene
	if ps == null:
		push_error("HudOn3D: %s missing" % SANDBOX)
		return
	sb = ps.instantiate()
	add_child(sb)
	var old: Variant = sb.get("_hud")
	if old is CanvasItem or old is CanvasLayer:
		old.set("visible", false)
	_world = sb.get("world")
	var wv: WorldView3D = sb.get("world_view")
	var drv: SimDriver = sb.get("driver")
	hud = Hud.new()
	add_child(hud)
	hud.visible = want_hud
	hud.attach_pip(sb.get("pip"))
	overlays = WorldOverlays.new()
	add_child(overlays)
	overlays.setup(wv, hud)
	var db: ContentDB = _world.get("db") if _world != null and "db" in _world else null
	var ep: EpisodeDef = _world.get("episode") if _world != null and "episode" in _world else null
	if db != null and ep != null:
		octx.prepare(db, ep)
		overlays.warm(octx)
	presenter.setup(wv.layout, _world)
	drv.ticked.connect(presenter.on_events)
	drv.ticked.connect(_on_events)
	# seek here (not with the sandbox's --seek) so the presenter and the entry warning see the events on the way
	var at := int(UiKit.flag_value("--at", "-1"))
	if at > 0 and sb.has_method("_seek"):
		sb.call("_seek", at)


func _process(_delta: float) -> void:
	if sb == null:
		return
	var drv: SimDriver = sb.get("driver")
	var wv: WorldView3D = sb.get("world_view")
	var pip: PipView3D = sb.get("pip")
	var snap := drv.snapshot()
	var ctx: Dictionary = _world.call("action_context") if _world != null and _world.has_method("action_context") else {}
	env.pip_shown = pip.is_shown()
	env.pip_escalated = pip.is_escalated()
	env.view_size = hud.get_viewport().get_visible_rect().size
	env.bellows_on_screen = wv.bellows_on_screen()
	env.bellows_screen = wv.project(wv.actor_anchor(&"bellows", &"feet"))
	env.tick = snap.tick
	presenter.fill(model, snap, ctx, env)
	_fill_r3d(snap, ctx)
	var t0 := Time.get_ticks_usec()
	hud.apply(model)
	var t1 := Time.get_ticks_usec()
	octx.now_s = float(snap.tick) / 60.0
	octx.idle_s = idle_s
	octx.previews_mode = _previews_mode()
	octx.entry_warning = snap.tick <= _entry_until
	octx.spot_filling = snap.bellows.spot_pct > 0.0 and snap.bellows.room == snap.hush.room
	octx.reaction = snap.bellows.reacting
	octx.action = ctx
	octx.next_useful = OverlayRules.suggest_next_useful(snap, octx) if idle_s >= OverlayRules.IDLE_HINT_S else ""
	octx.hide_all = not want_overlays
	OverlayRules.fill(omodel, snap, octx)
	var t2 := Time.get_ticks_usec()
	overlays.apply(omodel)
	var t3 := Time.get_ticks_usec()
	if perf and snap.tick > 0:
		var t4 := Time.get_ticks_usec()
		wv.protected_rects()
		_us_prot.append(float(Time.get_ticks_usec() - t4))
		for i in 4:
			_us_ph[i].append(float(overlays.phase_us[i]))
		_us_hud.append(float(t1 - t0))
		_us_rules.append(float(t2 - t1))
		_us_ov.append(float(t3 - t2))
		if _us_hud.size() >= 240 and not _printed:
			_printed = true
			print("[hudperf] %s" % JSON.stringify({
				"frames": _us_hud.size(), "hud_apply_us": _stats(_us_hud), "rules_fill_us": _stats(_us_rules),
				"overlays_apply_us": _stats(_us_ov), "of_which_view_protected_rects_us": _stats(_us_prot),
				"phases_protected_requests_solve_nodes": [_stats(_us_ph[0]), _stats(_us_ph[1]), _stats(_us_ph[2]), _stats(_us_ph[3])], "shown": overlays.shown_count, "loud": overlays.loud_count,
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))


## The R3D fields NightScene3D's presenter will own (see the class doc) — simplest rules from the snapshot.
func _fill_r3d(snap: ViewSnapshot, ctx: Dictionary) -> void:
	var h := snap.hush
	var b := snap.bellows
	var same_room := b.present and b.room == h.room
	var hidden := h.state == "HIDDEN" or h.hidden_spot != ""
	model.freeze_danger = HudModel.FreezeDanger.NONE
	if not hidden and same_room and b.spot_pct > 0.0:
		model.freeze_danger = HudModel.FreezeDanger.FILLING
	elif not hidden and (same_room or snap.tick <= _entry_until):
		model.freeze_danger = HudModel.FreezeDanger.EXPOSED
	model.verb_live = model.verb != HudModel.Verb.FREEZE or model.freeze_danger != HudModel.FreezeDanger.NONE \
		or h.state == "FROZEN" or h.frozen
	model.carrying = not h.carrying.is_empty()
	model.figgis_visible = false
	model.overview_visible = false
	model.bow_visible = false
	model.pip_next_icon = snap.bubble_icon if model.pip_visible else ""
	model.pip_ring_frac = -1.0
	if snap.bubble_ring_ticks >= 0:
		model.pip_ring_frac = clampf(float(snap.bubble_ring_ticks) / 600.0, 0.0, 1.0)
	model.edge_badge_side = 0 if model.edge_bubble_dir == Vector2.ZERO else (1 if model.edge_bubble_dir.x >= 0.0 else -1)
	model.edge_badge_icon = snap.bubble_icon
	var _unused := ctx


func _on_events(events: Array) -> void:
	var drv: SimDriver = sb.get("driver")
	var snap := drv.snapshot()
	for ev in events:
		var d: Dictionary = ev
		match str(d.get("e", "")):
			"entry_warning":
				var room := str(d.get("room", ""))
				if room == "" or room == snap.hush.room:
					_entry_until = snap.tick + int(d.get("eta", 60)) + 18
			"b_room":
				if str(d.get("room", "")) != snap.hush.room:
					_entry_until = -1


func _previews_mode() -> StringName:
	var st := get_node_or_null("/root/Settings")
	if st != null and st.has_method("get_value"):
		return StringName(str(st.call("get_value", "previews")))
	return OverlayCtx.MODE_ALWAYS


static func _stats(a: PackedFloat32Array) -> Dictionary:
	var s := a.duplicate()
	s.sort()
	return {"median": snappedf(s[s.size() / 2], 0.1), "p95": snappedf(s[int(s.size() * 0.95)], 0.1),
		"max": snappedf(s[s.size() - 1], 0.1)}
