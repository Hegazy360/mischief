## FxLayer — every pooled comedy / readability effect of the Night (TECH §5.7), in world space
## under World/FxWorld, plus a screen-space CanvasLayer for the Busted Cam look and the
## freeze-frame. Nothing is allocated per frame after warm-up: fixed pools of captions (3),
## stamps (4), particle emitters (8), ripples, rings, prints, props.
##
## World overlays (strip, prints, rings, ripple, badges, bubble, "?", captions, entry
## warning, sight line) live under `overlay` on visibility layer 2, so the PiP never shows
## them; particles and falling props stay on layer 1 (a payoff in the Gag-Cam PiP still flies).
## Text and markers keep a constant screen size (unit = 1 / camera zoom). Captions, stamps,
## ripples and badges run in real time (they pop during a hit-stop); rings, prints and
## falling props in view time; particles take the view rate as their speed scale.
class_name FxLayer
extends Node2D

const CAPTIONS := 3
const STAMPS := 4
const SCREEN_LAYER := 5
const SIGHT_DASH := 26.0
## Captions this size or larger are "big" puns (on a plate): one at a time per spot.
const BIG_CAPTION := 72
## A deferred caption waits until the live big one nearby is this old (s).
const CAPTION_READ_S := 0.9
const CAPTION_NEAR_PX := 900.0

var cam: CameraDirector = null:
	set(v):
		cam = v
		if bubble != null:
			bubble.cam = v
var layout: HouseLayout = null:
	set(v):
		layout = v
		if strip != null:
			strip.layout = v
## A SimDriver (view_delta / rate); null = real time.
var time_source: Node = null
var reduce_motion: bool = false

var overlay: Node2D = null
## Captions and stamps (visibility layer 1: they also read in the Gag-Cam PiP).
var texts: Node2D = null
var strip: FxStareStrip = null
var prints: FxFootprints = null
var rings: FxNoiseRings = null
var ripples: FxRipple = null
var badges: FxBadges = null
var bubble: FxThoughtBubble = null
var meter: FxSpotMeter = null
var entry: FxEntryWarning = null
var particles: FxParticlePool = null
var props: FxFallingProps = null
var screen: CanvasLayer = null
var busted: FxBustedOverlay = null
var freeze: FxFreezeFrame = null
var cane_fx: FxCane = null
var stars: FxStars = null
var wipe_fx: FxWipe = null
var _captions: Array[FxCaption] = []
var _stamps: Array[FxStamp] = []
var _next_caption := 0
# One pending (deferred) caption; a newer deferral replaces it.
var _pend_wait := -1.0
var _pend_text := ""
var _pend_pos := Vector2.ZERO
var _pend_size := 88
var _pend_follow: Node2D = null
var _pend_clamp := true
var _next_stamp := 0
var _sight: _SightLine = null
var _unit := 1.0
## Screen-space rects (viewport px) that captions must never overlap — NightScene hands in the
## HUD's top band (meter ∪ banner) and the PiP while it shows (s2-fix G #2). Returns Array[Rect2].
var avoid_screen_fn: Callable = Callable()
var _avoid_world: Array[Rect2] = []
var _no_avoid: Array[Rect2] = []


func _init() -> void:
	name = "FxWorld"
	process_priority = -30


func _ready() -> void:
	warm()


## Build every pool (idempotent; call before the first effect in tests).
func warm() -> void:
	if overlay != null:
		return
	reduce_motion = bool(ViewKit.setting("reduce_motion", reduce_motion))
	overlay = Node2D.new()
	overlay.name = "Overlay"
	overlay.visibility_layer = 2
	add_child(overlay)
	strip = FxStareStrip.new()
	strip.layout = layout
	strip.enabled = bool(ViewKit.setting("stare_strip", true))
	overlay.add_child(strip)
	prints = FxFootprints.new()
	overlay.add_child(prints)
	rings = FxNoiseRings.new()
	overlay.add_child(rings)
	entry = FxEntryWarning.new()
	overlay.add_child(entry)
	ripples = FxRipple.new()
	overlay.add_child(ripples)
	badges = FxBadges.new()
	badges.hints = String(ViewKit.setting("hints", "always"))
	overlay.add_child(badges)
	bubble = FxThoughtBubble.new()
	bubble.cam = cam
	overlay.add_child(bubble)
	meter = FxSpotMeter.new()
	meter.reduce_motion = reduce_motion
	overlay.add_child(meter)
	_sight = _SightLine.new()
	overlay.add_child(_sight)
	texts = Node2D.new()
	texts.name = "Texts"
	texts.z_index = 40
	add_child(texts)
	for i in CAPTIONS:
		var c := FxCaption.new()
		c.reduce_motion = reduce_motion
		_captions.append(c)
		texts.add_child(c)
	for i in STAMPS:
		var s := FxStamp.new()
		s.reduce_motion = reduce_motion
		_stamps.append(s)
		texts.add_child(s)
	particles = FxParticlePool.new()
	add_child(particles)
	particles.warm()
	props = FxFallingProps.new()
	add_child(props)
	cane_fx = FxCane.new()
	add_child(cane_fx)
	stars = FxStars.new()
	add_child(stars)
	screen = CanvasLayer.new()
	screen.name = "FxScreen"
	screen.layer = SCREEN_LAYER
	add_child(screen)
	busted = FxBustedOverlay.new()
	screen.add_child(busted)
	freeze = FxFreezeFrame.new()
	screen.add_child(freeze)
	wipe_fx = FxWipe.new()
	screen.add_child(wipe_fx)
	var st := ViewKit.autoload("Settings")
	if st != null and st.has_signal("changed"):
		st.connect("changed", _on_setting)


func _on_setting(key: String, value: Variant) -> void:
	match key:
		"stare_strip":
			strip.enabled = bool(value)
		"hints":
			badges.hints = String(value)
		"reduce_motion":
			reduce_motion = bool(value)


# --- TECH §5.7 API --------------------------------------------------------------------------

## A pun caption at `world_pos` (bottom centre), `size` px (constant on screen). With
## `follow` it rides on that node (keeping its offset); `clamp` keeps it inside the main view
## (off for payoffs shown in the PiP). With `defer` it waits (one pending slot) until a big
## caption live nearby has been up CAPTION_READ_S, and returns null while pending. A big
## caption fades any older big one nearby, so puns never stack.
func caption(text: String, world_pos: Vector2, size: int = 88, follow: Node2D = null, clamp: bool = true,
		defer: bool = false) -> FxCaption:
	warm()
	if defer:
		var wait := _read_wait(world_pos)
		if wait > 0.0:
			_pend_text = text
			# Relative to the rider when there is one: he may walk on while it waits.
			_pend_pos = world_pos - follow.global_position if follow != null else world_pos
			_pend_size = size
			_pend_follow = follow
			_pend_clamp = clamp
			_pend_wait = wait
			return null
	return _show_caption(text, world_pos, size, follow, clamp)


## Seconds until the big caption near `world_pos` has been read (0 when none is live).
func _read_wait(world_pos: Vector2) -> float:
	var wait := 0.0
	for c in _captions:
		if c.active and c.font_size >= BIG_CAPTION and c.age < CAPTION_READ_S \
				and c.position.distance_to(world_pos) < CAPTION_NEAR_PX:
			wait = maxf(wait, CAPTION_READ_S - c.age)
	return wait


func _show_caption(text: String, world_pos: Vector2, size: int, follow: Node2D, clamp: bool) -> FxCaption:
	# One big pun at a time: an older big caption nearby fades as the new one stamps in.
	if size >= BIG_CAPTION:
		for o in _captions:
			if o.active and o.font_size >= BIG_CAPTION and o.position.distance_to(world_pos) < CAPTION_NEAR_PX:
				o.retire()
	var c := _captions[_next_caption]
	_next_caption = (_next_caption + 1) % CAPTIONS
	var p := _clamp_x(world_pos, 420.0) if clamp else world_pos
	c.start(text, p, size, size >= BIG_CAPTION)
	c.set_meta("clamp", clamp)
	if follow != null:
		c.ride(follow, p - follow.global_position)
	return c


## A bonus stamp; placed beside the newest live caption when one is near.
func stamp(text: String, world_pos: Vector2) -> FxStamp:
	warm()
	var p := world_pos
	var near: FxCaption = null
	for c in _captions:
		if c.active and c.age < 0.9 and c.position.distance_to(world_pos) < 700.0:
			near = c
	var live := 0
	for s in _stamps:
		if s.active and s.age < s.life - 0.3:
			live += 1
	if near != null:
		p = near.position + Vector2(near.world_width() * 0.35, 110.0 * _unit + float(live) * 92.0 * _unit)
	var st := _stamps[_next_stamp]
	_next_stamp = (_next_stamp + 1) % STAMPS
	p = _clamp_x(p, 300.0)
	st.start(text, p, 64)
	if near != null and near.follow != null and is_instance_valid(near.follow):
		st.ride(near.follow, p - near.follow.global_position)
	return st


## A particle burst (TECH kinds). Returns the particles granted.
func burst(kind: String, world_pos: Vector2, amount: int = -1, dir: Vector2 = Vector2.UP) -> int:
	warm()
	return particles.burst(kind, world_pos, amount, dir)


## Tap ripple; `grey` = a rejected tap (`cmd_rejected`).
func ripple(world_pos: Vector2, grey: bool = false) -> void:
	warm()
	ripples.ripple(world_pos, grey)


## A held command (`cmd_queued`): the pulsing destination marker with its "…" badge.
func queued_marker(world_pos: Vector2) -> void:
	warm()
	ripples.queued(world_pos)


## The held command ran: back to a normal marker (the dotted path follows).
func queued_done() -> void:
	warm()
	ripples.queued_done()


func is_queued() -> bool:
	return ripples != null and ripples.is_queued()


## Figgis's cane sweeping in toward `target` (world).
func cane(target: Vector2, from_right: bool) -> void:
	warm()
	cane_fx.start(target, from_right)


## Stars orbiting a point (a bonk).
func stars_at(world_pos: Vector2) -> void:
	warm()
	stars.spin(world_pos)


## The caught sequence's ink iris wipe around a screen fraction.
func wipe(centre_frac: Vector2 = Vector2(0.5, 0.45)) -> void:
	warm()
	wipe_fx.start(centre_frac)


func path_dots(points: PackedVector2Array) -> void:
	warm()
	ripples.path_dots(points)


func noise_ring(world_pos: Vector2, radius: float, color: Color = FxNoiseRings.WHITE) -> void:
	warm()
	rings.ring(world_pos, radius, color)


func footprints(points: PackedVector2Array) -> void:
	warm()
	prints.footprints(points)


## Update the stare strip from the snapshot (`drawn_x` = his interpolated x; NAN = snapshot x).
func stare_strip(snap: ViewSnapshot, drawn_x: float = NAN) -> void:
	warm()
	strip.stare_strip(snap, snap.bellows.x if is_nan(drawn_x) else drawn_x)


## Update the thought bubble; `head_top` = world point above his head.
func thought_bubble(snap: ViewSnapshot, head_top: Vector2 = Vector2.INF) -> void:
	warm()
	var ht := head_top if head_top != Vector2.INF else Vector2(snap.bellows.x, snap.bellows.y - 390.0)
	var busy_caption := false
	for c in _captions:
		if c.active and c.font_size >= 72:
			busy_caption = true
	bubble.dim = 1.0 if busy_caption else 0.0
	bubble.quiet = quiet
	bubble.thought_bubble(snap, ht, _unit, meter.needs_space())


## Set a hotspot's badge ("" = none).
func badge(hotspot_id: String, kind: String) -> void:
	warm()
	badges.badge(hotspot_id, kind)


## Start the Busted Cam look for a replay window of `buffer` (returns its frame count).
func busted_cam(buffer: BustedCam, spotted_tick: int) -> int:
	warm()
	var n := buffer.replay_frames(spotted_tick)
	busted.set_on(n > 0)
	return n


# --- extras --------------------------------------------------------------------------------

## The "?" meter over his head.
func spot_meter(pct: float, anchor: Vector2) -> void:
	warm()
	meter.update_meter(pct, anchor, _unit)


func spot_bang() -> void:
	warm()
	meter.bang()


## Entry warning for Bellows entering `room` from `from_room` in `eta` ticks.
func entry_warning(room: String, from_room: String, eta: int) -> void:
	warm()
	entry.start(layout, room, from_room, eta)


## A prop falls from the ceiling at x onto a head at `head_y` (INF = straight to the floor).
func drop_prop(prop_name: String, x: float, ceiling_y: float, head_y: float, floor_y: float) -> void:
	warm()
	props.drop(prop_name, x, ceiling_y, head_y, floor_y)


func set_freeze_frame(on: bool, label: String = "") -> void:
	warm()
	freeze.set_on(on, label)


func end_busted() -> void:
	warm()
	busted.set_on(false)
	_sight.set_line(Vector2.ZERO, Vector2.ZERO, false)


## The dotted sight line from his eyes to Hush (Busted Cam).
func sight_line(from: Vector2, to: Vector2, on: bool = true) -> void:
	warm()
	_sight.set_line(from, to, on)


func captions_active() -> int:
	var n := 0
	for c in _captions:
		if c.active:
			n += 1
	return n


func stamps_active() -> int:
	var n := 0
	for s in _stamps:
		if s.active:
			n += 1
	return n


## Clear every transient effect (retry).
func clear() -> void:
	warm()
	for c in _captions:
		c.stop()
	_pend_wait = -1.0
	_pend_follow = null
	for s in _stamps:
		s.stop()
	particles.clear()
	props.clear()
	entry.stop()
	ripples.clear()
	rings.clear()
	cane_fx.stop()
	stars.clear()
	end_busted()
	set_freeze_frame(false)


func unit() -> float:
	return _unit


func _process(delta: float) -> void:
	advance(delta)


## True while the camera holds a gag on him: the bubble and "?" step aside.
var quiet: bool = false


## One frame (public for tests).
func advance(real_dt: float) -> void:
	if overlay == null:
		return
	var vdt := real_dt
	var rate := 1.0
	if time_source != null and time_source.has_method("view_delta"):
		vdt = float(time_source.call("view_delta"))
		rate = float(time_source.call("rate")) if time_source.has_method("rate") else 1.0
	_unit = 1.0 / maxf(0.2, cam.current_zoom()) if cam != null else 1.0
	var view := cam.visible_world_rect() if cam != null else Rect2()
	if _pend_wait >= 0.0:
		_pend_wait -= real_dt
		if _pend_wait < 0.0:
			var f: Node2D = _pend_follow if _pend_follow != null and is_instance_valid(_pend_follow) else null
			var at := f.global_position + _pend_pos if f != null else _pend_pos
			_show_caption(_pend_text, at, _pend_size, f, _pend_clamp)
			_pend_follow = null
	_update_avoid()
	for c in _captions:
		var clamp_c := c.active and bool(c.get_meta("clamp", true))
		c.keep_in = view if clamp_c else Rect2()
		c.avoid = _avoid_world if clamp_c else _no_avoid
		c.tick(real_dt, _unit)
	for s in _stamps:
		s.keep_in = view if s.active else Rect2()
		s.tick(real_dt, _unit)
	ripples.tick(real_dt, _unit)
	badges.tick(real_dt, _unit)
	bubble.tick(real_dt)
	meter.tick(real_dt)
	rings.tick(vdt, _unit)
	prints.tick(vdt)
	strip.tick(real_dt)
	entry.tick(vdt, _unit)
	props.tick(vdt)
	cane_fx.tick(vdt, _unit)
	stars.tick(vdt, _unit)
	_sight.tick(real_dt, _unit)
	particles.set_speed(clampf(rate, 0.0, 3.0))


## The avoid rects in world space for this frame's camera (only while a caption is live).
func _update_avoid() -> void:
	_avoid_world.clear()
	if not avoid_screen_fn.is_valid() or not is_inside_tree():
		return
	var live := false
	for c in _captions:
		live = live or c.active
	if not live:
		return
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var rects: Variant = avoid_screen_fn.call()
	if rects is Array:
		for r in rects:
			if r is Rect2 and (r as Rect2).has_area():
				_avoid_world.append(inv * (r as Rect2))


func _clamp_x(p: Vector2, half_w: float) -> Vector2:
	if cam == null:
		return p
	var r := cam.visible_world_rect()
	var hw := half_w * _unit
	if r.size.x <= hw * 2.0:
		return p
	return Vector2(clampf(p.x, r.position.x + hw, r.end.x - hw), p.y)


## The dotted sight line (Busted Cam): dashes from his eyes to her.
class _SightLine extends Node2D:
	var _a := Vector2.ZERO
	var _b := Vector2.ZERO
	var _on := false
	var _t := 0.0
	var _unit := 1.0

	func _init() -> void:
		z_index = 36

	func set_line(a: Vector2, b: Vector2, on: bool) -> void:
		_a = a
		_b = b
		_on = on
		queue_redraw()

	func tick(dt: float, unit: float) -> void:
		if _on:
			_t += dt
			_unit = unit
			queue_redraw()

	func _draw() -> void:
		if not _on:
			return
		var d := _a.distance_to(_b)
		if d < 1.0:
			return
		var dir := (_b - _a) / d
		var dash := FxLayer.SIGHT_DASH * _unit
		var off := fmod(_t * 160.0, dash * 2.0)
		var s := -dash * 2.0 + off
		while s < d:
			var s0 := maxf(0.0, s)
			var s1 := minf(d, s + dash)
			if s1 > s0:
				draw_line(_a + dir * s0, _a + dir * s1, ViewKit.INK, 12.0 * _unit)
				draw_line(_a + dir * s0, _a + dir * s1, Color("#E23B4E"), 6.0 * _unit)
			s += dash * 2.0
		draw_circle(_b, 16.0 * _unit, Color("#E23B4E", 0.6))
