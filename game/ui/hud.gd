## Hud — the in-Night HUD (REDESIGN_3D §2, TECH §5.9): a CanvasLayer (layer 10) over the 3D view,
## laid out by HudLayout on the safe-area corners, driven by `apply(model: HudModel)`.
##
## * FOUR pieces are always on (REDESIGN §2.1): pause, the Script chip, Clarence / ⏩ and the action
##   button (QUIET / LIVE, §2.4). Everything else shows only when it means something (§2.2):
##     the transient Applause meter — 2.5 s after any Applause change (or until `meter_until_s`), and
##       while a Running Gag is live (the fuse under it); tomatoes inside it for 2.5 s on a catch;
##     the Bellows window (PipFrame) — exactly when the attached view (PipView3D) shows it;
##     the edge badge — he is off-screen and no window shows (or `edge_badge_lean`, R15);
##     the carried-item chips — only while Hush carries something;
##     Figgis — 4 s after a nudge (`figgis_pulse` rising), while a cue card is up, or `figgis_visible`;
##     BOW — after ★ (`bow_visible`), under the Bellows window while that is open;
##     the Overview button — only `overview_visible` (hidden in Act I);
##     the pick strip — unchanged.
## * `apply()` is idempotent and allocation-free: each field is compared with what was last shown and
##   only changed values reach the widgets (`last_changes` counts them — 0 on a repeat).
## * Intents (signals) — NightScene maps them to sim commands / camera calls:
##   action_down(verb), action_up(verb, cancelled), action_double_tap(verb), clarence_down(),
##   clarence_hold(), clarence_up(held_ms), tray_tap(i), tray_drag(i, screen_pos), pick(item),
##   figgis_tap(), pause_tap(), overview_tap(), pip_tap(), pip_release(), meter_tap() (the Script
##   chip or the meter: open the Script panel), bow_tap(), hint_tap(), map_open().
## * `debug_pieces()` / `always_on_rects()` feed the HUD lint, the screen-rect lint and the world
##   overlays' protected rects; `transient_rects()` the shown top-band pieces (meter + fuse) the world
##   overlays keep out of (r3d QA Q-C2); `fly_tag(from, line)` flies a red beret tag to a Script pip.
## * While a hold is in progress (`model.holding`, a press, the ring rising) a teaching glove on the
##   action button steps away (r3d QA Q-C1: ring + glove + icon stacked on the button) and comes back
##   if she lets go before the ring completes.
## * Left-handed mode (Settings.left_handed or `set_left_handed`) mirrors every rect but the centred
##   meter. Tap-to-rig (Settings.tap_to_rig) turns holds into toggles. Tablets ×0.8 (UiScale).
## * Panels (ScriptPanel, PauseMenu, SettingsPanel, LoadingCard, ResultsScreen) are shown on top with
##   `show_panel(panel)` (`open_pause_menu` builds the pause panel); the HUD dims while `model.paused`.
## * Teaching: `ghost_finger(target, …)` over a widget (&"clarence", &"action", &"tray" / &"tray:<i>",
##   &"figgis", &"script", &"meter", &"pip", &"pause", &"overview", &"bow"), `ghost_finger_at(pos, …)`,
##   `ghost_finger_follow(fn, …)`, `show_figgis_card(icons, s, arrow_to)`, `set_dim(on, spotlight)`,
##   `flash_script(lines, loop, s)`.
## * The Bellows window: `attach_pip(view)` hands the Hud the window view (duck-typed: get_texture(),
##   is_shown(), is_escalated(), signals shown_changed(bool), pip_resized(Vector2i)); while attached
##   the model's pip_visible / pip_escalated are ignored.
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
## R3D: the "Take a Bow ▶" chip was tapped (after ★).
signal bow_tap()
## R3D: the pause panel's Hint (Figgis steps 2–3) and Map (the Overview of tonight's set).
signal hint_tap()
signal map_open()
## R3D: a tag flight reached its Script pip (the pip pops).
signal tag_arrived(line_index: int)
## The curtain-up Script flash (flash_script) finished or was tapped away.
signal script_flash_finished()

const LAYER := 10
## The ghost-finger "target" while it points at the world (ghost_finger_at / _follow).
const GHOST_WORLD := &"@world"
## Contextual timings (REDESIGN §2.2).
const METER_MS := 2500
const FIGGIS_MS := 4000
const MAX_FLIGHTS := 4

var root: Control
var pause_button: PauseButton
var script_chip: ScriptChip
var figgis: FiggisChip
var meter: ApplauseMeter
var banner: RunningGagBanner
var pip: PipFrame
var overview: OverviewButton
var tray: ItemTray
var clarence: ClarenceButton
var action: ActionButton
var edge_bubble: EdgeBubble
var bow: BowChip
var pick_strip: PickStrip
var ghost: GhostFinger
## "Where does this go?" + the Figgis card arrow (never a target).
var edge_arrows: EdgeArrows
## House lights down (set_dim), under every widget.
var dim: StageDim
## Tag flights (pooled), above the widgets.
var flights: Array[TagFlight] = []
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
## The attached Bellows window view (PipView3D, or the 2D PipView until r3d-integrate removes it),
## or null (duck-typed, see the class doc).
var pip_view: Object = null

var _safe: SafeArea
var _insets: Vector4 = Vector4.ZERO
var _ghost_target: StringName = &""
var _ghost_mode: int = 0
var _ghost_hold_s: float = -1.0
var _ghost_pos: Vector2 = Vector2.ZERO
var _ghost_fn: Callable = Callable()
var _last_tray_tap: int = -1
var _paused_shown: bool = false
# contextual timers (UiKit.now_ms clock)
var _meter_until_ms: int = -100000
var _meter_model_until_ms: int = -100000
var _figgis_until_ms: int = -100000
var _m_link: int = 0
var _m_bow: bool = false
var _m_overview: bool = false
var _m_carrying: bool = false
var _m_figgis: bool = false
var _m_edge_lean: bool = false
var _m_edge_side: int = 0
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
var _c_live := -1
var _c_fdanger := -1
var _c_item := "\u0001"
var _c_target := "\u0001"
var _c_ring := -1.0
var _c_rim := -1
var _c_cmode := -1
var _c_lure := -2
var _c_tray := PackedStringArray(["\u0001"])
var _c_hl := -2
var _c_fpulse := -1
var _c_fghost := -1
var _c_pipv := -1
var _c_piptier := -1
var _c_pipglyph := "\u0001"
var _c_pipesc := -1
var _c_pipnext := "\u0001"
var _c_pipring := -2.0
var _c_edir := Vector2(INF, INF)
var _c_elabel := "\u0001"
var _c_eicon := "\u0001"
var _c_pick := PackedStringArray(["\u0001"])
var _c_pickpos := Vector2(INF, INF)
var _c_paused := -1
var _c_emote := "\u0001"
var _c_tarrows := PackedVector2Array([Vector2(INF, INF)])
var _c_taitem := "\u0001"
var _c_pips := PackedInt32Array([-1])
var _c_pips_key := Vector3i(-1, -1, -1)
var _c_meter_until := -2.0
var _c_holding := -1
var _always_on: Array[Rect2] = []
## [meter (+ its "+n" stamp), fuse]: Rect2() while hidden (transient_rects).
var _transient: Array[Rect2] = [Rect2(), Rect2()]
## The meter's "+n" stamp reaches this far right of the pill (ApplauseMeter draws it at W + 64, 56 px).
const METER_STAMP_W := 130.0


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
	meter.visible = false
	pause_button = PauseButton.new()
	pause_button.name = "Pause"
	script_chip = ScriptChip.new()
	script_chip.name = "Script"
	figgis = FiggisChip.new()
	figgis.name = "Figgis"
	figgis.visible = false
	pip = PipFrame.new()
	pip.name = "Pip"
	overview = OverviewButton.new()
	overview.name = "Overview"
	overview.visible = false
	edge_bubble = EdgeBubble.new()
	edge_bubble.name = "EdgeBadge"
	tray = ItemTray.new()
	tray.name = "Chips"
	tray.visible = false
	clarence = ClarenceButton.new()
	clarence.name = "Clarence"
	action = ActionButton.new()
	action.name = "Action"
	bow = BowChip.new()
	bow.name = "Bow"
	pick_strip = PickStrip.new()
	pick_strip.name = "PickStrip"
	ghost = GhostFinger.new()
	ghost.name = "GhostFinger"
	dim = StageDim.new()
	dim.name = "Dim"
	edge_arrows = EdgeArrows.new()
	edge_arrows.name = "EdgeArrows"
	for w in [dim, edge_arrows, banner, meter, pause_button, script_chip, figgis, pip, overview, edge_bubble, tray,
			clarence, action, bow, pick_strip]:
		root.add_child(w)
	for i in MAX_FLIGHTS:
		var f := TagFlight.new()
		f.name = "TagFlight%d" % i
		f.arrived.connect(_on_flight_arrived)
		flights.append(f)
		root.add_child(f)
	root.add_child(ghost)
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
	_tick_contextual()


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
	script_chip.script_tap.connect(func() -> void: meter_tap.emit())
	overview.tapped.connect(func() -> void: overview_tap.emit())
	pip.pip_tap.connect(func() -> void: pip_tap.emit())
	pip.pip_release.connect(func() -> void: pip_release.emit())
	edge_bubble.pip_tap.connect(func() -> void: pip_tap.emit())
	meter.meter_tap.connect(func() -> void: meter_tap.emit())
	bow.tapped.connect(func() -> void: bow_tap.emit())


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
	var now := UiKit.now_ms()
	script_lines = m.script_lines
	script_loop = m.script_loop
	# the transient meter: 2.5 s after any Applause change (or a used tomato)
	if m.applause != _c_applause or m.lines_done != _c_done or m.lines_total != _c_total \
			or m.tomatoes_left != _c_tleft or m.tomatoes_max != _c_tmax:
		var first := _c_applause == -2147483648
		if not first and (m.applause != _c_applause or (m.tomatoes_left < _c_tleft and m.tomatoes_max > 0)):
			_meter_until_ms = now + METER_MS
		_c_applause = m.applause
		_c_done = m.lines_done
		_c_total = m.lines_total
		_c_tleft = m.tomatoes_left
		_c_tmax = m.tomatoes_max
		meter.set_values(m.applause, m.lines_done, m.lines_total, m.tomatoes_left, m.tomatoes_max)
		if first:
			meter.snap()
		n += 1
	if not is_equal_approx(m.meter_until_s, _c_meter_until):
		_c_meter_until = m.meter_until_s
		_meter_model_until_ms = int(m.meter_until_s * 1000.0) if m.meter_until_s >= 0.0 else -100000
		n += 1
	if m.link != _c_link or m.mult_pct != _c_mult or not is_equal_approx(m.fuse_frac, _c_fuse):
		_c_link = m.link
		_c_mult = m.mult_pct
		_c_fuse = m.fuse_frac
		banner.set_values(m.link, m.mult_pct, m.fuse_frac)
		n += 1
	_m_link = m.link
	# the Script chip
	var pips_changed := false
	if not m.script_pips.is_empty():
		if m.script_pips != _c_pips:
			_c_pips = m.script_pips.duplicate()
			pips_changed = true
	else:
		var key := Vector3i(m.lines_done, m.lines_total, m.script_lines.size())
		if key != _c_pips_key:
			_c_pips_key = key
			var derived := ScriptChip.pips_from_lines(m.script_lines) if not m.script_lines.is_empty() \
				else ScriptChip.pips_from_counts(m.lines_done, m.lines_total)
			if derived != _c_pips:
				_c_pips = derived
				pips_changed = true
	if pips_changed:
		script_chip.set_pips(_c_pips)
		if not layout.is_empty() and not is_equal_approx((layout[&"script"] as Rect2).size.x, script_chip.size.x * hud_scale):
			relayout()
		n += 1
	# the action button
	if m.verb_item_icon != _c_item or m.verb_target_icon != _c_target:
		_c_item = m.verb_item_icon
		_c_target = m.verb_target_icon
		action.set_icons(m.verb_item_icon, m.verb_target_icon)
		n += 1
	var live := is_live(m)
	if m.verb != _c_verb or int(live) != _c_live:
		_c_verb = m.verb
		_c_live = int(live)
		action.set_face(m.verb, live)
		n += 1
	if m.freeze_danger != _c_fdanger:
		_c_fdanger = m.freeze_danger
		action.set_freeze_danger(m.freeze_danger)
		n += 1
	if not is_equal_approx(m.ring_frac, _c_ring):
		_c_ring = m.ring_frac
		action.set_ring(m.ring_frac)
		n += 1
	if m.rim != _c_rim:
		_c_rim = m.rim
		action.set_rim(m.rim)
		n += 1
	if int(m.holding) != _c_holding:
		_c_holding = int(m.holding)
		action.set_holding(m.holding)
		n += 1
	# Clarence
	if m.clarence_mode != _c_cmode:
		_c_cmode = m.clarence_mode
		clarence.set_mode(m.clarence_mode)
		n += 1
	var lure := m.lure_ring if m.lure_ring >= 0 else (HudModel.LureRing.GREY if m.lure_grey else HudModel.LureRing.HIDDEN)
	if lure != _c_lure:
		_c_lure = lure
		clarence.set_lure_ring(lure)
		n += 1
	# the carried-item chips (only while carrying)
	if m.tray != _c_tray:
		_c_tray = m.tray.duplicate()
		tray.set_items(m.tray)
		n += 1
	if m.tray_highlight != _c_hl:
		_c_hl = m.tray_highlight
		tray.set_highlight(m.tray_highlight)
		n += 1
	_m_carrying = m.carrying or not m.tray.is_empty()
	# Figgis (4 s after a nudge rises, while a card is up, or forced)
	if int(m.figgis_pulse) != _c_fpulse:
		if m.figgis_pulse and _c_fpulse == 0:
			_figgis_until_ms = now + FIGGIS_MS
		elif m.figgis_pulse and _c_fpulse < 0:
			_figgis_until_ms = now + FIGGIS_MS
		_c_fpulse = int(m.figgis_pulse)
		figgis.set_pulse(m.figgis_pulse)
		n += 1
	if int(m.figgis_ghost) != _c_fghost:
		_c_fghost = int(m.figgis_ghost)
		figgis.set_ghost(m.figgis_ghost)
		n += 1
	_m_figgis = m.figgis_visible
	# the Bellows window
	if m.pip_frame_tier != _c_piptier:
		_c_piptier = m.pip_frame_tier
		pip.set_tier(m.pip_frame_tier)
		edge_bubble.set_tier(m.pip_frame_tier)
		n += 1
	if m.pip_glyph != _c_pipglyph:
		_c_pipglyph = m.pip_glyph
		pip.set_glyph(m.pip_glyph)
		n += 1
	if m.pip_next_icon != _c_pipnext or not is_equal_approx(m.pip_ring_frac, _c_pipring):
		_c_pipnext = m.pip_next_icon
		_c_pipring = m.pip_ring_frac
		pip.set_next(_activity_icon(m.pip_next_icon), m.pip_ring_frac)
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
	# the edge badge
	var edge_changed := pip_moved
	if m.edge_bubble_dir != _c_edir or m.edge_bubble_label != _c_elabel:
		_c_edir = m.edge_bubble_dir
		_c_elabel = m.edge_bubble_label
		edge_bubble.set_target(m.edge_bubble_dir if m.edge_badge_arrow == Vector2.ZERO else m.edge_badge_arrow,
			m.edge_bubble_label)
		edge_changed = true
		n += 1
	if m.edge_badge_icon != _c_eicon:
		_c_eicon = m.edge_badge_icon
		edge_bubble.set_next_icon(_activity_icon(m.edge_badge_icon))
		n += 1
	if m.edge_badge_lean != _m_edge_lean or m.edge_badge_side != _m_edge_side:
		_m_edge_lean = m.edge_badge_lean
		_m_edge_side = m.edge_badge_side
		edge_changed = true
		n += 1
	if m.edge_bubble_emote != _c_emote:
		_c_emote = m.edge_bubble_emote
		edge_bubble.set_emote(m.edge_bubble_emote)
		n += 1
	if edge_changed:
		_place_edge_bubble()
	# "where does this go?" arrows
	if m.tray_arrows != _c_tarrows or m.tray_arrows_item != _c_taitem:
		_c_tarrows = m.tray_arrows.duplicate()
		_c_taitem = m.tray_arrows_item
		edge_arrows.set_directions(m.tray_arrows, _tray_arrow_icon(m))
		n += 1
	# pick strip
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
	# BOW, overview
	if m.bow_visible != _m_bow:
		_m_bow = m.bow_visible
		n += 1
	if m.overview_visible != _m_overview:
		_m_overview = m.overview_visible
		n += 1
	# tag flights (consumed once)
	if not m.tag_flights.is_empty():
		for f in m.tag_flights:
			if f is Dictionary:
				var d: Dictionary = f
				var from: Variant = d.get("from", Vector2.INF)
				fly_tag(from if from is Vector2 else Vector2.INF, int(d.get("line_index", -1)))
		m.tag_flights.clear()
		n += 1
	if int(m.paused) != _c_paused:
		_c_paused = int(m.paused)
		_set_paused(m.paused)
		n += 1
	_tick_contextual()
	last_changes = n


## Force the next apply() to push every field again (after a retry / relayout).
func invalidate() -> void:
	_c_applause = -2147483648
	_c_holding = -1
	_c_verb = -1
	_c_live = -1
	_c_tray = PackedStringArray(["\u0001"])
	_c_pick = PackedStringArray(["\u0001"])
	_c_edir = Vector2(INF, INF)
	_c_pipv = -1
	_c_paused = -1
	_c_emote = "\u0001"
	_c_tarrows = PackedVector2Array([Vector2(INF, INF)])
	_c_taitem = "\u0001"
	_c_pips = PackedInt32Array([-1])
	_c_pips_key = Vector3i(-1, -1, -1)
	_meter_until_ms = -100000
	_figgis_until_ms = -100000


## True when the action button's face is LIVE for `m` (REDESIGN §2.4): every verb but FREEZE, and
## FREEZE while it matters (`freeze_danger` > 0 or `verb_live`).
static func is_live(m: HudModel) -> bool:
	if m.verb != HudModel.Verb.FREEZE:
		return true
	return m.freeze_danger > 0 or m.verb_live


## The contextual pieces' visibility for now (called from apply and every frame).
func _tick_contextual() -> void:
	var now := UiKit.now_ms()
	var meter_on := now < _meter_until_ms or now < _meter_model_until_ms or _m_link > 0 or meter.tomatoes_showing()
	if meter.visible != meter_on:
		meter.visible = meter_on
		if meter_on:
			meter.queue_redraw()
	var fig_on := _m_figgis or figgis.card_visible() or now < _figgis_until_ms or figgis.ghost_on
	if figgis.visible != fig_on:
		figgis.visible = fig_on
	if tray.visible != _m_carrying:
		tray.visible = _m_carrying
	if overview.visible != _m_overview:
		overview.visible = _m_overview
	if bow.visible != _m_bow:
		bow.set_shown(_m_bow)
		_place_bow()


# --- settings -------------------------------------------------------------------------------

## Mirror every rect (but the centred meter) for left-handed play.
func set_left_handed(on: bool) -> void:
	if on == left_handed:
		return
	left_handed = on
	relayout()


## Tap-to-rig: action holds become toggles.
func set_tap_to_rig(on: bool) -> void:
	tap_to_rig = on
	action.set_tap_to_rig(on)


## The Bellows window texture (the view's get_texture()).
func set_pip_texture(tex: Texture2D) -> void:
	pip.set_texture(tex)


## Take over the Bellows window: show `view.get_texture()` in the PipFrame and follow its
## `shown_changed` / `pip_resized` signals (placement, escalation). Passing null detaches.
func attach_pip(view: Object) -> void:
	if pip_view == view:
		return
	if pip_view != null and is_instance_valid(pip_view):
		if pip_view.is_connected("shown_changed", _on_pip_shown):
			pip_view.disconnect("shown_changed", _on_pip_shown)
		if pip_view.is_connected("pip_resized", _on_pip_resized):
			pip_view.disconnect("pip_resized", _on_pip_resized)
	pip_view = view
	if view == null:
		pip.set_texture(null)
		return
	pip.set_texture(view.call("get_texture") as Texture2D)
	if view.has_signal("shown_changed"):
		view.connect("shown_changed", _on_pip_shown)
	if view.has_signal("pip_resized"):
		view.connect("pip_resized", _on_pip_resized)
	pip.set_escalated(bool(view.call("is_escalated")) if view.has_method("is_escalated") else false)
	pip.set_shown(bool(view.call("is_shown")) if view.has_method("is_shown") else false)
	_place_pip()
	_place_edge_bubble()


func _on_pip_shown(on: bool) -> void:
	pip.set_shown(on)
	_place_pip()
	_place_edge_bubble()


func _on_pip_resized(new_size: Vector2i) -> void:
	pip.set_escalated(new_size.x > PipFrame.SIZE_NORMAL.x + 1)
	_place_pip()


## Show the overview toggle in its "zoomed out" state.
func set_overview(on: bool) -> void:
	overview.set_overview(on)


## Figgis ladder step 2 (GDD §6.4): a cue card of icons for `seconds` — Figgis appears holding up his
## card; with `arrow_to` (a screen point) an arrow points at it for the same time — an edge arrow
## while it is off screen, a bobbing arrow above it while on screen.
func show_figgis_card(icons: PackedStringArray, seconds: float = FiggisChip.CARD_SEC,
		arrow_to: Vector2 = Vector2.INF) -> void:
	figgis.show_card(icons, seconds)
	_tick_contextual()
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
	_tick_contextual()


## Fly a red beret tag from `from` (screen px, the prop's tag socket; INF = the screen centre) to
## Script pip `line_index` (0.6 s); the pip pops on arrival (`tag_arrived`).
func fly_tag(from: Vector2, line_index: int) -> void:
	var start := from if from.is_finite() else viewport_size() * 0.5
	var to := script_pip_center(line_index)
	for f in flights:
		if not f.running:
			f.start(start, to, line_index)
			return
	# every flight busy: land it at once
	_on_flight_arrived(line_index)


## The screen centre of Script pip `i` (the tag flight's target).
func script_pip_center(i: int) -> Vector2:
	return script_chip.position + script_chip.pip_center(i) * script_chip.scale


func _on_flight_arrived(line_index: int) -> void:
	script_chip.pop(line_index)
	tag_arrived.emit(line_index)


## A ghost glove tapping (Mode.TAP) or holding (Mode.HOLD) over a HUD widget `target`:
## &"clarence", &"action", &"tray" / &"tray:<i>", &"figgis", &"script", &"meter", &"pip", &"pause",
## &"overview", &"bow"; &"" hides it. `hold_s` = how long the HOLD ring takes to fill.
func ghost_finger(target: StringName, mode: int = GhostFinger.Mode.TAP, hold_s: float = -1.0) -> void:
	_ghost_fn = Callable()
	_ghost_target = target
	_ghost_mode = mode
	_ghost_hold_s = hold_s
	if target == &"":
		ghost.stop()
		return
	_place_ghost()


## The ghost glove over a fixed screen point (logical px, e.g. a world hotspot's screen centre),
## clamped so the whole glove stays inside the safe area.
func ghost_finger_at(screen_pos: Vector2, mode: int = GhostFinger.Mode.TAP, hold_s: float = -1.0) -> void:
	_ghost_fn = Callable()
	_ghost_pos = screen_pos
	_ghost_target = GHOST_WORLD
	_ghost_mode = mode
	_ghost_hold_s = hold_s
	_place_ghost()


## The ghost glove over a moving point: `fn.call()` returns its screen position every frame;
## Vector2.INF (or an invalid callable) hides the glove until it returns a point again.
func ghost_finger_follow(fn: Callable, mode: int = GhostFinger.Mode.TAP, hold_s: float = -1.0) -> void:
	_ghost_fn = fn
	_ghost_target = GHOST_WORLD
	_ghost_mode = mode
	_ghost_hold_s = hold_s
	_place_ghost()


## The ghost glove's current target (&"" = hidden; GHOST_WORLD = a world point).
func ghost_target() -> StringName:
	return _ghost_target


## The glove's fingertip for a screen point: clamped so the glove and its ripple / HOLD ring stay
## inside the safe area (pure; tests).
func ghost_clamp(p: Vector2) -> Vector2:
	var vs := viewport_size()
	var s := maxf(_insets.x, _insets.z)
	var safe := Rect2(s, _insets.y, vs.x - 2.0 * s, vs.y - _insets.y - _insets.w)
	var half := maxf(ghost.size.x * 0.5, GhostFinger.TIP_REACH)
	var x := clampf(p.x, safe.position.x + half, maxf(safe.position.x + half, safe.end.x - half))
	var y := clampf(p.y, safe.position.y + ghost.size.y,
		maxf(safe.position.y + ghost.size.y, safe.end.y - GhostFinger.TIP_REACH))
	return Vector2(x, y)


## House lights down (FTUE "show me"): dims the world under every HUD widget; `spotlight` (screen
## rect) stays lit — call again each frame to move it. Off fades back up.
func set_dim(on: bool, spotlight: Rect2 = Rect2()) -> void:
	dim.set_dim(on, spotlight)


## Curtain up (GDD §2.2): the Script slides in from the top for `seconds` (non-pausing; touches
## outside the card pass through; a tap on the card slides it away early), then
## `script_flash_finished`. Replaces a flash already showing. Returns the ScriptPanel (flash mode).
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


## An activity icon (id or res:// path; "" = null).
static func _activity_icon(id: String) -> Texture2D:
	if id == "":
		return null
	return UiIcons.texture(id) if id.begins_with("res://") else UiIcons.activity(id)


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


## R3D: build and show the pause panel (Resume · Retry · Take a Bow · Hint · Map · Settings · Playbill,
## header = PauseMenu.header). Its `closed(action)` works as before; "hint" and "map" are also
## re-emitted as `hint_tap` / `map_open`.
func open_pause_menu(can_bow: bool, header: Dictionary = {}) -> PauseMenu:
	var m := PauseMenu.new()
	m.name = "PauseMenu"
	m.setup(can_bow, header)
	show_panel(m)
	m.closed.connect(_on_pause_action, CONNECT_ONE_SHOT)
	return m


func _on_pause_action(action_id: String) -> void:
	if action_id == "hint":
		hint_tap.emit()
	elif action_id == "map":
		map_open.emit()


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
	layout = HudLayout.compute(vs, ins, left_handed, hud_scale, script_chip.pill_width())
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
	_put(script_chip, layout[&"script"], k)
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
	bow.scale = k
	_place_pip()
	_place_edge_bubble()
	_place_pick_strip()
	_place_bow()
	_cache_always_on()
	for p in panel_host.get_children():
		(p as Control).size = vs
		if p.has_method("set_insets"):
			p.call("set_insets", ins)
	if _ghost_target != &"":
		_place_ghost()


## Global hit rects of every visible touch target (layout tests, tap-assist exclusion).
func target_rects() -> Dictionary:
	var out := {}
	var pairs := {&"pause": pause_button, &"script": script_chip, &"figgis": figgis, &"meter": meter, &"pip": pip,
		&"overview": overview, &"tray": tray, &"clarence": clarence, &"action": action, &"edge_bubble": edge_bubble,
		&"pick_strip": pick_strip, &"bow": bow}
	for key in pairs:
		var c: Control = pairs[key]
		if c.visible:
			out[key] = Rect2(c.position, c.size * c.scale)
	return out


## Every HUD piece on screen now, for the HUD lint and the screen-rect lint (REDESIGN §2.1, r3d-index
## §7.10): Array of {name: String, rect: Rect2 (global hit rect), always_on: bool, persistent: bool}.
## always_on = pause, script, clarence, action. `persistent` = contextual but able to stay up without
## the player acting (the chips while carrying, the Bellows window, the meter + fuse during a Running
## Gag, BOW); the rest are short-lived (the 2.5 s meter, Figgis's 4 s, the edge badge, the pick strip).
## Allocates (debug / lints only).
func debug_pieces() -> Array:
	var out: Array = []
	for row in _piece_table():
		var c: Control = row[1]
		if c == null or not c.visible:
			continue
		out.append({"name": String(row[0]), "rect": Rect2(c.position, c.size * c.scale), "always_on": bool(row[2]),
			"persistent": bool(row[3])})
	return out


## The global hit rects of the four always-on pieces — the protected rects the world overlays keep
## 48 px clear of (§2.5). Cached at every relayout (the same array each call: no allocation per frame;
## do not modify it).
func always_on_rects() -> Array[Rect2]:
	return _always_on


## The transient top-band pieces on screen now (r3d QA Q-C2): [the APPLAUSE meter with its "+n" stamp,
## the RUNNING GAG fuse] as global rects, Rect2() while hidden. The world overlays treat them as hard
## keep-outs. The same array every call (no allocation; do not modify it).
func transient_rects() -> Array[Rect2]:
	_transient[0] = Rect2(meter.position, Vector2(meter.size.x + METER_STAMP_W, meter.size.y) * meter.scale) \
		if meter.visible else Rect2()
	_transient[1] = Rect2(banner.position, banner.size * banner.scale) if banner.visible else Rect2()
	return _transient


func _cache_always_on() -> void:
	_always_on.resize(4)
	_always_on[0] = Rect2(pause_button.position, pause_button.size * pause_button.scale)
	_always_on[1] = Rect2(script_chip.position, script_chip.size * script_chip.scale)
	_always_on[2] = Rect2(clarence.position, clarence.size * clarence.scale)
	_always_on[3] = Rect2(action.position, action.size * action.scale)


## [name, control, always_on, persistent] for every piece the Hud owns.
func _piece_table() -> Array:
	return [
		["pause", pause_button, true, true],
		["script", script_chip, true, true],
		["clarence", clarence, true, true],
		["action", action, true, true],
		["meter", meter, false, _m_link > 0],
		["banner", banner, false, true],
		["figgis", figgis, false, false],
		["pip", pip, false, true],
		["overview", overview, false, false],
		["chips", tray, false, true],
		["bow", bow, false, true],
		["edge_badge", edge_bubble, false, false],
		["pick_strip", pick_strip, false, false],
	]


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
	_place_bow()


## The PipFrame's on-screen rect (its hit box) as placed now.
func pip_rect() -> Rect2:
	return Rect2(pip.position, pip.size * pip.scale)


func _place_bow() -> void:
	if layout.is_empty():
		return
	var r: Rect2 = layout[&"bow_low"] if pip.shown else layout[&"bow"]
	bow.position = r.position


func _place_edge_bubble() -> void:
	if layout.is_empty():
		return
	var has_dir := _c_edir != Vector2.ZERO and _c_edir.x != INF
	var on := (has_dir and not pip.shown) or _m_edge_lean
	edge_bubble.visible = on
	if on:
		var d := _c_edir if has_dir else Vector2.RIGHT
		edge_bubble.position = HudLayout.edge_badge_rect(layout, _m_edge_side, d).position


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
		&"script": c = script_chip
		&"meter": c = meter
		&"pip": c = pip
		&"pause": c = pause_button
		&"overview": c = overview
		&"bow": c = bow
	if c == null:
		return viewport_size() * 0.5
	return c.position + c.size * c.scale * 0.5


## True when the glove would sit on the action button while its hold is in progress (it steps away).
func ghost_yields() -> bool:
	return _ghost_target == &"action" and action.is_holding()


func _place_ghost() -> void:
	if _ghost_target == &"":
		return
	if ghost_yields():
		if ghost.visible:
			ghost.stop()
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
	for w in [banner, pause_button, script_chip, figgis, meter, pip, overview, tray, clarence, action, edge_bubble,
			bow, pick_strip]:
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
