## Hud — the in-Night HUD (TECH §5.9, GDD §3.8): a CanvasLayer (layer 10) holding every widget,
## laid out by HudLayout on the safe-area corners, driven by `apply(model: HudModel)`.
##
## * `apply()` is idempotent and allocation-free: each field is compared with what was last shown
##   and only changed values reach the widgets (`last_changes` counts them — 0 on a repeat).
## * Intents (signals) — NightScene maps them to sim commands / camera calls:
##   action_down(verb), action_up(verb, cancelled), action_double_tap(verb), clarence_down(),
##   clarence_hold(), clarence_up(held_ms), tray_tap(i), tray_drag(i, screen_pos), pick(item),
##   figgis_tap(), pause_tap(), overview_tap(), pip_tap(), pip_release(), meter_tap().
## * Left-handed mode (Settings.left_handed or `set_left_handed`) mirrors the thumb clusters and
##   swaps the top corners. Tap-to-rig (Settings.tap_to_rig) turns holds into toggles.
## * Panels (ScriptPanel, PauseMenu, SettingsPanel, LoadingCard, ResultsScreen) are shown on top
##   with `show_panel(panel)`; the HUD itself dims while `model.paused`.
## * Teaching (s2-ftue, the no-FTUE fallback in NightScene):
##     `ghost_finger(target, mode, hold_s)` — the glove over a HUD widget;
##     `ghost_finger_at(screen_pos, mode, hold_s)` — over a fixed screen point (a world hotspot);
##     `ghost_finger_follow(fn, mode, hold_s)` — over a moving point (`fn.call() -> Vector2`,
##       re-read every frame, e.g. a hotspot while the camera pans; Vector2.INF hides the glove);
##     the world glove is clamped so all of it stays inside the safe area;
##     `show_figgis_card(icons, seconds, arrow_to)` — the cue card + an edge arrow toward an
##       off-screen target (GDD §6.4 step 2); `set_dim(on, spotlight)` — house lights down for
##       "show me" (the spotlight rect stays lit).
## * Curtain up: `flash_script(lines, loop, seconds)` — the Script slides in from the top for
##   2.5 s, non-pausing, touches outside the card pass through (`script_flash_finished`).
## * "Where does this go?": HudModel.tray_arrows → edge arrows; HudModel.edge_bubble_emote → the
##   edge bubble's emote face + pictogram puff (D1).
## * The Bellows-Cam: `attach_pip(pip_view)` hands the Hud the PipView — its texture, its
##   `shown_changed` / `pip_resized` signals drive the PipFrame (placement per HudLayout: 448 × 252
##   top-right, the escalated Gag-Cam window anchored to the same corner); while attached the
##   model's pip_visible / pip_escalated are ignored (tier and glyph still come from the model).
class_name Hud
extends CanvasLayer

signal action_down(verb: int)
signal action_up(verb: int, cancelled: bool)
signal action_double_tap(verb: int)
signal clarence_down()
signal clarence_hold()
signal clarence_up(held_ms: int)
signal tray_tap(i: int)
signal tray_drag(i: int, screen_pos: Vector2)
signal pick(item: String)
signal figgis_tap()
signal pause_tap()
signal overview_tap()
signal pip_tap()
signal pip_release()
signal meter_tap()
## A panel shown with show_panel() closed (its node is freed).
signal panel_closed(panel_name: String)
## The curtain-up Script flash (flash_script) finished or was tapped away.
signal script_flash_finished()

const LAYER := 10
## The ghost-finger "target" while it points at the world (ghost_finger_at / _follow).
const GHOST_WORLD := &"@world"

var root: Control
var pause_button: PauseButton
var figgis: FiggisChip
var meter: ApplauseMeter
var banner: RunningGagBanner
var pip: PipFrame
var overview: OverviewButton
var tray: ItemTray
var clarence: ClarenceButton
var action: ActionButton
var edge_bubble: EdgeBubble
var pick_strip: PickStrip
var ghost: GhostFinger
## "Where does this go?" + the Figgis card arrow (never a target).
var edge_arrows: EdgeArrows
## House lights down (set_dim), under every widget.
var dim: StageDim
## Holds the curtain-up Script flash (above the widgets, below the panels).
var flash_host: Control
## The Script flash on screen (null when none).
var script_flash: ScriptPanel = null
var panel_host: Control

var left_handed: bool = false
var tap_to_rig: bool = false
## Test hooks: a fixed logical size / insets / HUD scale instead of the viewport's.
var layout_size_override: Vector2 = Vector2.ZERO
var insets_override: Vector4 = Vector4(-1, -1, -1, -1)
var hud_scale_override: float = -1.0
## Fields that changed in the last apply() (0 = nothing to do).
var last_changes: int = 0
## Total apply() calls.
var apply_count: int = 0
## The current layout (HudLayout.compute) and scale.
var layout: Dictionary = {}
var hud_scale: float = 1.0
## The last model's script data (for the Script panel).
var script_lines: Array = []
var script_loop: Array = []

## The attached PipView (attach_pip), or null.
var pip_view: PipView = null

var _safe: SafeArea
var _insets: Vector4 = Vector4.ZERO
var _ghost_target: StringName = &""
var _ghost_mode: int = 0
var _ghost_hold_s: float = -1.0
var _ghost_pos: Vector2 = Vector2.ZERO
var _ghost_fn: Callable = Callable()
var _last_tray_tap: int = -1
var _paused_shown: bool = false
# last shown values
var _c_applause := -2147483648
var _c_done := -1
var _c_total := -1
var _c_tleft := -2
var _c_tmax := -2
var _c_link := -1
var _c_mult := -1
var _c_fuse := -1.0
var _c_verb := -1
var _c_item := "\u0001"
var _c_target := "\u0001"
var _c_ring := -1.0
var _c_rim := -1
var _c_cmode := -1
var _c_lure := -1
var _c_tray := PackedStringArray(["\u0001"])
var _c_hl := -2
var _c_fpulse := -1
var _c_fghost := -1
var _c_pipv := -1
var _c_piptier := -1
var _c_pipglyph := "\u0001"
var _c_pipesc := -1
var _c_edir := Vector2(INF, INF)
var _c_elabel := "\u0001"
var _c_pick := PackedStringArray(["\u0001"])
var _c_pickpos := Vector2(INF, INF)
var _c_paused := -1
var _c_emote := "\u0001"
var _c_tarrows := PackedVector2Array([Vector2(INF, INF)])
var _c_taitem := "\u0001"


func _init() -> void:
	layer = LAYER
	name = "Hud"
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)
	banner = RunningGagBanner.new()
	banner.name = "RunningGag"
	meter = ApplauseMeter.new()
	meter.name = "Meter"
	pause_button = PauseButton.new()
	pause_button.name = "Pause"
	figgis = FiggisChip.new()
	figgis.name = "Figgis"
	pip = PipFrame.new()
	pip.name = "Pip"
	overview = OverviewButton.new()
	overview.name = "Overview"
	edge_bubble = EdgeBubble.new()
	edge_bubble.name = "EdgeBubble"
	tray = ItemTray.new()
	tray.name = "Tray"
	clarence = ClarenceButton.new()
	clarence.name = "Clarence"
	action = ActionButton.new()
	action.name = "Action"
	pick_strip = PickStrip.new()
	pick_strip.name = "PickStrip"
	ghost = GhostFinger.new()
	ghost.name = "GhostFinger"
	dim = StageDim.new()
	dim.name = "Dim"
	edge_arrows = EdgeArrows.new()
	edge_arrows.name = "EdgeArrows"
	for w in [dim, edge_arrows, banner, meter, pause_button, figgis, pip, overview, edge_bubble, tray, clarence, action,
			pick_strip, ghost]:
		root.add_child(w)
	flash_host = Control.new()
	flash_host.name = "Flash"
	flash_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_host.theme = UiKit.theme()
	add_child(flash_host)
	panel_host = Control.new()
	panel_host.name = "Panels"
	panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_host.theme = UiKit.theme()
	add_child(panel_host)
	_wire()


func _ready() -> void:
	_safe = SafeArea.new()
	_safe.name = "SafeArea"
	add_child(_safe)
	_safe.changed.connect(_on_insets)
	get_viewport().size_changed.connect(relayout)
	var s := get_node_or_null(^"/root/Settings")
	if s != null and s.has_method("get_value"):
		left_handed = bool(s.call("get_value", "left_handed", false))
		set_tap_to_rig(bool(s.call("get_value", "tap_to_rig", false)))
		if s.has_signal("changed"):
			s.connect("changed", _on_setting)
	# debug shots of the real scene: `-- --left-handed` mirrors without touching the user's settings
	if OS.is_debug_build() and UiKit.has_flag("--left-handed"):
		left_handed = true
	_insets = _safe.current
	relayout()


func _process(_delta: float) -> void:
	if _ghost_target != &"":
		_place_ghost()


func _wire() -> void:
	action.action_down.connect(_on_action_down)
	action.action_up.connect(func(v: int, c: bool) -> void: action_up.emit(v, c))
	action.action_double_tap.connect(func(v: int) -> void: action_double_tap.emit(v))
	clarence.clarence_down.connect(func() -> void: clarence_down.emit())
	clarence.clarence_hold.connect(func() -> void: clarence_hold.emit())
	clarence.clarence_up.connect(func(ms: int) -> void: clarence_up.emit(ms))
	tray.tray_tap.connect(_on_tray_tap)
	tray.tray_drag.connect(func(i: int, p: Vector2) -> void: tray_drag.emit(i, p))
	pick_strip.pick.connect(func(item: String) -> void: pick.emit(item))
	figgis.figgis_tap.connect(func() -> void: figgis_tap.emit())
	pause_button.tapped.connect(func() -> void: pause_tap.emit())
	overview.tapped.connect(func() -> void: overview_tap.emit())
	pip.pip_tap.connect(func() -> void: pip_tap.emit())
	pip.pip_release.connect(func() -> void: pip_release.emit())
	edge_bubble.pip_tap.connect(func() -> void: pip_tap.emit())
	meter.meter_tap.connect(func() -> void: meter_tap.emit())


func _on_action_down(v: int) -> void:
	clarence.last_action_down_ms = UiKit.now_ms()
	action_down.emit(v)


func _on_tray_tap(i: int) -> void:
	_last_tray_tap = i
	tray_tap.emit(i)


# --- the model --------------------------------------------------------------------------------

## Show `m`. Idempotent: identical values change nothing (see `last_changes`).
func apply(m: HudModel) -> void:
	apply_count += 1
	var n := 0
	script_lines = m.script_lines
	script_loop = m.script_loop
	if m.applause != _c_applause or m.lines_done != _c_done or m.lines_total != _c_total \
			or m.tomatoes_left != _c_tleft or m.tomatoes_max != _c_tmax:
		_c_applause = m.applause
		_c_done = m.lines_done
		_c_total = m.lines_total
		_c_tleft = m.tomatoes_left
		_c_tmax = m.tomatoes_max
		meter.set_values(m.applause, m.lines_done, m.lines_total, m.tomatoes_left, m.tomatoes_max)
		n += 1
	if m.link != _c_link or m.mult_pct != _c_mult or not is_equal_approx(m.fuse_frac, _c_fuse):
		_c_link = m.link
		_c_mult = m.mult_pct
		_c_fuse = m.fuse_frac
		banner.set_values(m.link, m.mult_pct, m.fuse_frac)
		n += 1
	if m.verb_item_icon != _c_item or m.verb_target_icon != _c_target:
		_c_item = m.verb_item_icon
		_c_target = m.verb_target_icon
		action.set_icons(m.verb_item_icon, m.verb_target_icon)
		n += 1
	if m.verb != _c_verb:
		_c_verb = m.verb
		action.set_verb(m.verb)
		n += 1
	if not is_equal_approx(m.ring_frac, _c_ring):
		_c_ring = m.ring_frac
		action.set_ring(m.ring_frac)
		n += 1
	if m.rim != _c_rim:
		_c_rim = m.rim
		action.set_rim(m.rim)
		n += 1
	if m.clarence_mode != _c_cmode:
		_c_cmode = m.clarence_mode
		clarence.set_mode(m.clarence_mode)
		n += 1
	if int(m.lure_grey) != _c_lure:
		_c_lure = int(m.lure_grey)
		clarence.set_lure_grey(m.lure_grey)
		n += 1
	if m.tray != _c_tray:
		_c_tray = m.tray.duplicate()
		tray.set_items(m.tray)
		n += 1
	if m.tray_highlight != _c_hl:
		_c_hl = m.tray_highlight
		tray.set_highlight(m.tray_highlight)
		n += 1
	if int(m.figgis_pulse) != _c_fpulse:
		_c_fpulse = int(m.figgis_pulse)
		figgis.set_pulse(m.figgis_pulse)
		n += 1
	if int(m.figgis_ghost) != _c_fghost:
		_c_fghost = int(m.figgis_ghost)
		figgis.set_ghost(m.figgis_ghost)
		n += 1
	if m.pip_frame_tier != _c_piptier:
		_c_piptier = m.pip_frame_tier
		pip.set_tier(m.pip_frame_tier)
		n += 1
	if m.pip_glyph != _c_pipglyph:
		_c_pipglyph = m.pip_glyph
		pip.set_glyph(m.pip_glyph)
		n += 1
	var pip_moved := false
	if pip_view == null and int(m.pip_escalated) != _c_pipesc:
		_c_pipesc = int(m.pip_escalated)
		pip.set_escalated(m.pip_escalated)
		pip_moved = true
		n += 1
	if pip_view == null and int(m.pip_visible) != _c_pipv:
		_c_pipv = int(m.pip_visible)
		pip.set_shown(m.pip_visible)
		pip_moved = true
		n += 1
	if pip_moved:
		_place_pip()
	var edge_changed := pip_moved
	if m.edge_bubble_dir != _c_edir or m.edge_bubble_label != _c_elabel:
		_c_edir = m.edge_bubble_dir
		_c_elabel = m.edge_bubble_label
		edge_bubble.set_target(m.edge_bubble_dir, m.edge_bubble_label)
		edge_changed = true
		n += 1
	if m.edge_bubble_emote != _c_emote:
		_c_emote = m.edge_bubble_emote
		edge_bubble.set_emote(m.edge_bubble_emote)
		n += 1
	if edge_changed:
		_place_edge_bubble()
	if m.tray_arrows != _c_tarrows or m.tray_arrows_item != _c_taitem:
		_c_tarrows = m.tray_arrows.duplicate()
		_c_taitem = m.tray_arrows_item
		edge_arrows.set_directions(m.tray_arrows, _tray_arrow_icon(m))
		n += 1
	if m.pick_strip_items != _c_pick or m.pick_strip_pos != _c_pickpos:
		var items_changed := m.pick_strip_items != _c_pick
		_c_pick = m.pick_strip_items.duplicate()
		_c_pickpos = m.pick_strip_pos
		if m.pick_strip_items.is_empty():
			pick_strip.close()
		elif items_changed:
			pick_strip.open(m.pick_strip_items)
		_place_pick_strip()
		n += 1
	if int(m.paused) != _c_paused:
		_c_paused = int(m.paused)
		_set_paused(m.paused)
		n += 1
	last_changes = n


## Force the next apply() to push every field again (after a retry / relayout).
func invalidate() -> void:
	_c_applause = -2147483648
	_c_verb = -1
	_c_tray = PackedStringArray(["\u0001"])
	_c_pick = PackedStringArray(["\u0001"])
	_c_edir = Vector2(INF, INF)
	_c_pipv = -1
	_c_paused = -1
	_c_emote = "\u0001"
	_c_tarrows = PackedVector2Array([Vector2(INF, INF)])
	_c_taitem = "\u0001"


# --- settings -------------------------------------------------------------------------------

## Mirror the thumb clusters (and top corners) for left-handed play.
func set_left_handed(on: bool) -> void:
	if on == left_handed:
		return
	left_handed = on
	relayout()


## Tap-to-rig: action holds become toggles.
func set_tap_to_rig(on: bool) -> void:
	tap_to_rig = on
	action.set_tap_to_rig(on)


## The PiP SubViewport texture (PipView.get_texture()).
func set_pip_texture(tex: Texture2D) -> void:
	pip.set_texture(tex)


## Take over the Bellows-Cam: show `view.get_texture()` in the PipFrame and follow its
## `shown_changed` / `pip_resized` signals (placement, escalation). Passing null detaches.
func attach_pip(view: PipView) -> void:
	if pip_view == view:
		return
	if pip_view != null and is_instance_valid(pip_view):
		if pip_view.shown_changed.is_connected(_on_pip_shown):
			pip_view.shown_changed.disconnect(_on_pip_shown)
		if pip_view.pip_resized.is_connected(_on_pip_resized):
			pip_view.pip_resized.disconnect(_on_pip_resized)
	pip_view = view
	if view == null:
		pip.set_texture(null)
		return
	pip.set_texture(view.get_texture())
	view.shown_changed.connect(_on_pip_shown)
	view.pip_resized.connect(_on_pip_resized)
	pip.set_escalated(view.is_escalated())
	pip.set_shown(view.is_shown())
	_place_pip()
	_place_edge_bubble()


func _on_pip_shown(on: bool) -> void:
	pip.set_shown(on)
	_place_pip()
	_place_edge_bubble()


func _on_pip_resized(new_size: Vector2i) -> void:
	pip.set_escalated(new_size.x > PipFrame.SIZE_NORMAL.x)
	_place_pip()


## Show the overview toggle in its "zoomed out" state.
func set_overview(on: bool) -> void:
	overview.set_overview(on)


## Figgis ladder step 2 (GDD §6.4): a cue card of icons (UiIcons.card keys / item ids / paths —
## e.g. `UiIcons.card_set(key)`) for `seconds`, Figgis holding up his card; with `arrow_to` (a
## screen point, e.g. the target hotspot's centre) an arrow points at it for the same time — an
## edge arrow while it is off screen, a bobbing arrow above it while on screen.
func show_figgis_card(icons: PackedStringArray, seconds: float = FiggisChip.CARD_SEC,
		arrow_to: Vector2 = Vector2.INF) -> void:
	figgis.show_card(icons, seconds)
	# the off-screen arrow carries the card's target (its last icon) at its tail
	var tail: Texture2D = null
	if arrow_to != Vector2.INF:
		for i in range(icons.size() - 1, -1, -1):
			if icons[i] != "" and icons[i] != "arrow":
				tail = UiIcons.card(icons[i])
				break
	edge_arrows.point_at(arrow_to, seconds, tail)


## Hide the cue card and its arrow now.
func hide_figgis_card() -> void:
	figgis.hide_card()
	edge_arrows.point_at(Vector2.INF)


## A ghost glove tapping (Mode.TAP) or holding (Mode.HOLD) over a HUD widget `target`:
## &"clarence", &"action", &"tray" / &"tray:<i>", &"figgis", &"meter", &"pip", &"pause",
## &"overview"; &"" hides it. `hold_s` = how long the HOLD ring takes to fill (the prep tier being
## taught: Q 0.8, S 1.5, B 2.5 s; ≤ 0 keeps the last, default 1.5).
func ghost_finger(target: StringName, mode: int = GhostFinger.Mode.TAP, hold_s: float = -1.0) -> void:
	_ghost_fn = Callable()
	_ghost_target = target
	_ghost_mode = mode
	_ghost_hold_s = hold_s
	if target == &"":
		ghost.stop()
		return
	_place_ghost()


## The ghost glove over a fixed screen point (logical px, e.g. a world hotspot's screen centre from
## `WorldView.hotspot_rects_in_view()`), clamped so the whole glove stays inside the safe area.
func ghost_finger_at(screen_pos: Vector2, mode: int = GhostFinger.Mode.TAP, hold_s: float = -1.0) -> void:
	_ghost_fn = Callable()
	_ghost_pos = screen_pos
	_ghost_target = GHOST_WORLD
	_ghost_mode = mode
	_ghost_hold_s = hold_s
	_place_ghost()


## The ghost glove over a moving point: `fn.call()` returns its screen position (Vector2) every
## frame — e.g. a hotspot while the camera pans; Vector2.INF (or an invalid callable) hides the glove
## until it returns a point again. Clamped like ghost_finger_at.
func ghost_finger_follow(fn: Callable, mode: int = GhostFinger.Mode.TAP, hold_s: float = -1.0) -> void:
	_ghost_fn = fn
	_ghost_target = GHOST_WORLD
	_ghost_mode = mode
	_ghost_hold_s = hold_s
	_place_ghost()


## The ghost glove's current target (&"" = hidden; GHOST_WORLD = a world point).
func ghost_target() -> StringName:
	return _ghost_target


## The glove's fingertip for a screen point: clamped so the glove (120 × 150 above its tip) and
## its tap ripple / HOLD ring round the tip (GhostFinger.TIP_REACH) stay inside the safe area
## (pure; tests).
func ghost_clamp(p: Vector2) -> Vector2:
	var vs := viewport_size()
	var s := maxf(_insets.x, _insets.z)
	var safe := Rect2(s, _insets.y, vs.x - 2.0 * s, vs.y - _insets.y - _insets.w)
	var half := maxf(ghost.size.x * 0.5, GhostFinger.TIP_REACH)
	var x := clampf(p.x, safe.position.x + half, maxf(safe.position.x + half, safe.end.x - half))
	var y := clampf(p.y, safe.position.y + ghost.size.y,
		maxf(safe.position.y + ghost.size.y, safe.end.y - GhostFinger.TIP_REACH))
	return Vector2(x, y)


## House lights down (FTUE "show me"): dims the world and the Stalls under every HUD widget;
## `spotlight` (screen rect) stays lit — call again each frame to move it. Off fades back up.
func set_dim(on: bool, spotlight: Rect2 = Rect2()) -> void:
	dim.set_dim(on, spotlight)


## Curtain up (GDD §2.2): the Script slides in from the top under the meter for `seconds`
## (non-pausing; the game keeps running and touches outside the card pass through; a tap on the
## card slides it away early), then `script_flash_finished`. Replaces a flash already showing.
## `lines` / `loop` as HudModel.script_lines / script_loop. Returns the ScriptPanel (flash mode).
func flash_script(lines: Array, loop: Array, seconds: float = 2.5) -> ScriptPanel:
	if script_flash != null and is_instance_valid(script_flash):
		script_flash.queue_free()
	var p := ScriptPanel.new()
	p.name = "ScriptFlash"
	p.flash_mode = true
	p.flash_s = maxf(0.8, seconds)
	p.setup(lines, loop)
	flash_host.add_child(p)
	p.position = Vector2.ZERO
	p.size = viewport_size()
	p.set_insets(_insets)
	p.closed.connect(_on_flash_closed.bind(p), CONNECT_ONE_SHOT)
	script_flash = p
	return p


func _on_flash_closed(_action: String, p: ScriptPanel) -> void:
	if is_instance_valid(p):
		p.queue_free()
	if script_flash == p:
		script_flash = null
		script_flash_finished.emit()


func _tray_arrow_icon(m: HudModel) -> Texture2D:
	if m.tray_arrows.is_empty():
		return null
	var id := m.tray_arrows_item
	if id == "" and _last_tray_tap >= 0 and _last_tray_tap < m.tray.size():
		id = m.tray[_last_tray_tap]
	return UiIcons.item(id) if id != "" else null


# --- panels ---------------------------------------------------------------------------------

## Show a panel (a full-screen Control with a `closed` signal) above the HUD. Returns it.
func show_panel(panel: Control) -> Control:
	panel_host.add_child(panel)
	panel.position = Vector2.ZERO
	panel.size = viewport_size()
	if panel.has_method("set_insets"):
		panel.call("set_insets", _insets)
	if panel.has_signal("closed"):
		panel.connect("closed", func(_a: Variant = null) -> void: _on_panel_closed(panel), CONNECT_ONE_SHOT)
	return panel


## Close every open panel.
func close_panels() -> void:
	for c in panel_host.get_children():
		c.queue_free()


## The open panel on top (null when none).
func top_panel() -> Control:
	var n := panel_host.get_child_count()
	return panel_host.get_child(n - 1) as Control if n > 0 else null


func _on_panel_closed(panel: Control) -> void:
	if is_instance_valid(panel):
		var nm := String(panel.name)
		panel.queue_free()
		panel_closed.emit(nm)


# --- layout ---------------------------------------------------------------------------------

## The logical size the HUD lays out in.
func viewport_size() -> Vector2:
	if layout_size_override != Vector2.ZERO:
		return layout_size_override
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1920, 1080)


## Recompute every rect and move the widgets.
func relayout() -> void:
	var vs := viewport_size()
	var ins := insets_override if insets_override.x >= 0.0 else _insets
	_insets = ins
	if hud_scale_override > 0.0:
		hud_scale = hud_scale_override
	elif layout_size_override != Vector2.ZERO or not is_inside_tree():
		hud_scale = UiScale.factor_for(vs)
	else:
		hud_scale = UiScale.factor(get_viewport())
	layout = HudLayout.compute(vs, ins, left_handed, hud_scale)
	root.size = vs
	panel_host.size = vs
	flash_host.size = vs
	dim.position = Vector2.ZERO
	dim.size = vs
	edge_arrows.position = Vector2.ZERO
	edge_arrows.size = vs
	edge_arrows.k = hud_scale
	edge_arrows.safe = layout[&"safe"]
	edge_arrows.zone = layout[&"arrow_zone"]
	edge_arrows.queue_redraw()
	if script_flash != null and is_instance_valid(script_flash):
		script_flash.size = vs
		script_flash.set_insets(ins)
	var k := Vector2(hud_scale, hud_scale)
	_put(pause_button, layout[&"pause"], k)
	_put(figgis, layout[&"figgis"], k)
	figgis.flip = left_handed
	figgis.queue_redraw()
	_put(meter, layout[&"meter"], k)
	_put(banner, layout[&"banner"], k)
	_put(tray, layout[&"tray"], k)
	_put(clarence, layout[&"clarence"], k)
	_put(action, layout[&"action"], k)
	edge_bubble.scale = k
	pick_strip.scale = k
	overview.scale = k
	_place_pip()
	_place_edge_bubble()
	_place_pick_strip()
	for p in panel_host.get_children():
		(p as Control).size = vs
		if p.has_method("set_insets"):
			p.call("set_insets", ins)
	if _ghost_target != &"":
		_place_ghost()


## Global hit rects of every visible touch target (layout tests, tap-assist exclusion).
func target_rects() -> Dictionary:
	var out := {}
	var pairs := {&"pause": pause_button, &"figgis": figgis, &"meter": meter, &"pip": pip, &"overview": overview,
		&"tray": tray, &"clarence": clarence, &"action": action, &"edge_bubble": edge_bubble, &"pick_strip": pick_strip}
	for key in pairs:
		var c: Control = pairs[key]
		if c.visible:
			out[key] = Rect2(c.position, c.size * c.scale)
	return out


func _put(c: Control, r: Rect2, k: Vector2) -> void:
	c.scale = k
	c.position = r.position


func _place_pip() -> void:
	if layout.is_empty():
		return
	var esc := pip.escalated
	var r: Rect2 = layout[&"pip_escalated"] if esc else layout[&"pip"]
	pip.position = r.position
	var sz := pip.frame_size()
	pip.scale = Vector2(r.size.x / sz.x, r.size.y / sz.y)
	var ov: Rect2 = layout[&"overview_escalated"] if (esc and pip.shown) else layout[&"overview"]
	overview.position = ov.position


## The PipFrame's on-screen rect (its hit box) as placed now.
func pip_rect() -> Rect2:
	return Rect2(pip.position, pip.size * pip.scale)


func _place_edge_bubble() -> void:
	if layout.is_empty():
		return
	var on := _c_edir != Vector2.ZERO and _c_edir.x != INF and not pip.shown
	edge_bubble.visible = on
	if on:
		edge_bubble.position = HudLayout.edge_bubble_pos(layout, _c_edir, EdgeBubble.HIT * hud_scale)


func _place_pick_strip() -> void:
	if layout.is_empty() or not pick_strip.visible:
		return
	var sz := pick_strip.size * hud_scale
	pick_strip.position = HudLayout.pick_strip_pos(layout, _c_pickpos, sz)


func _ghost_tip(target: StringName) -> Vector2:
	var s := String(target)
	if s.begins_with("tray:"):
		var i := int(s.substr(5))
		var r := ItemTray.slot_rect(clampi(i, 0, 3))
		return tray.position + (r.get_center() + Vector2(0, -10)) * tray.scale
	var c: Control = null
	match target:
		&"clarence": c = clarence
		&"action": c = action
		&"tray": c = tray
		&"figgis": c = figgis
		&"meter": c = meter
		&"pip": c = pip
		&"pause": c = pause_button
		&"overview": c = overview
	if c == null:
		return viewport_size() * 0.5
	return c.position + c.size * c.scale * 0.5


func _place_ghost() -> void:
	if _ghost_target == &"":
		return
	var tip: Vector2
	if _ghost_target == GHOST_WORLD:
		var p := _ghost_pos
		if _ghost_fn.is_valid():
			var v: Variant = _ghost_fn.call()
			p = v if v is Vector2 else Vector2.INF
		elif not _ghost_fn.is_null():
			p = Vector2.INF   # the followed object is gone
		if not p.is_finite():
			if ghost.visible:
				ghost.stop()
			return
		_ghost_pos = p
		tip = ghost_clamp(p)
	else:
		# widgets: the fingertip just below-right of the centre, so the glove never hides the icon
		tip = _ghost_tip(_ghost_target) + Vector2(10, 18)
	ghost.show_at(tip, _ghost_mode, _ghost_hold_s)


func _set_paused(on: bool) -> void:
	_paused_shown = on
	# the widgets fade, not the root: the dim (set_dim) keeps its own strength while paused
	for w in [banner, pause_button, figgis, meter, pip, overview, tray, clarence, action, edge_bubble, pick_strip]:
		(w as CanvasItem).modulate = Color(1, 1, 1, 0.45) if on else Color.WHITE
		var tw := w as TouchWidget
		if tw == null:
			continue
		tw.interactive = not on
		if on:
			tw.release_touch()


func _on_insets(v: Vector4) -> void:
	_insets = v
	relayout()


func _on_setting(key: String, value: Variant) -> void:
	if key == "left_handed":
		set_left_handed(bool(value))
	elif key == "tap_to_rig":
		set_tap_to_rig(bool(value))
