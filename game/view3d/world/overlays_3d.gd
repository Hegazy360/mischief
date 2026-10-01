## Overlays3D — the view's 2D FX over the 3D world (REDESIGN §5.8; brief r3d-view3d §4.6): his thought bubble (the
## next activity, 200×170 with a 112 px icon, 12 px ring, 60 px glyph, 24 px ear pips), the "?" spot meter + "!",
## the entry warning, captions and stamps, and the Busted Cam tint. They are the Stage-2 FX classes (FxThoughtBubble,
## FxSpotMeter, FxEntryWarning, FxCaption, FxStamp) drawn on a CanvasLayer inside a **lane-space** node whose
## transform maps sim px on the lane plane to logical screen px (re-fitted every frame from the camera), so their
## world-px layout and `unit` sizing carry over unchanged; anchors off the lane are projected and mapped back.
## Captions and stamps are stamped onto the **screen** (a plain Node2D in logical px, unit 1): they pop where his head
## is when they start and stay put while the camera punches in and out.
## Placement: his bubble is clamped inside the safe area below the HUD band and hides while he reacts (the payoff
## owns the screen); captions stay below the HUD band, inside the screen, and clear of his bubble and the HUD rects.
class_name Overlays3D
extends CanvasLayer

## His bubble at REDESIGN §4.2 size: the Stage-2 bubble (150×130) × 1.333 = 200×173.
const BUBBLE_SCALE := 1.333
## His bubble's drawn extent from its position (screen px at BUBBLE_SCALE): the awareness-glyph disc + ear pips reach
## 115 local units left (153 px), the cloud's right lobe 95 units right (127 px); EDGE_PX kept from the screen edge.
const BUBBLE_LEFT_PX := 153.0
const BUBBLE_RIGHT_PX := 127.0
const EDGE_PX := 8.0
## With the glyph flipped right of the cloud (fix-perf's FxThoughtBubble.glyph_right near the left edge): the cloud's
## left lobe 55 units left (73 px), the glyph disc 155 units right (207 px).
const BUBBLE_FLIP_LEFT_PX := 73.0
const BUBBLE_FLIP_RIGHT_PX := 207.0
const HUD_BAND_Y := 212.0
## Q2-C1: the clearance of his bubble from the APPLAUSE / RUNNING GAG band (px at the 1080 base; WorldOverlays'
## TRANSIENT_PAD) and how often a missing Hud is looked up again (frames).
const BAND_PAD_PX := 24.0
const BAND_LOOKUP_F := 30
const CAPTIONS := 3
const STAMPS := 2

var wv: WorldView3D = null
var lane: Node2D = null
## Screen-space layer (logical px) for captions and stamps.
var screen: Node2D = null
var bubble: FxThoughtBubble = null
var meter: FxSpotMeter = null
var entry: FxEntryWarning = null
var captions: Array[FxCaption] = []
var stamps: Array[FxStamp] = []
var tint: ColorRect = null
var vignette: TextureRect = null
## The freeze-frame (sepia + paper border, JuiceClock.freeze_frame_changed) and the caught iris wipe (screen space).
var freeze: FxFreezeFrame = null
var wiper: FxWipe = null
var _safe := false
var _unit := 1.0
var _bubble_rect := Rect2()
var _hud: Object = null
var _hud_wait := 0
var _bubble_has_wait := false
var _bubble_can_flip := false
var _cap_i := 0
var _stamp_i := 0
var _busted := false
## caption → the actor whose head it sits beside (&"" = fixed where it started)
var _cap_actor: Array[StringName] = []
## caption → its remembered side beside the head (1 above, 2 left, 3 right, 0 not yet)
var _cap_side: Array[int] = []
## The shared §2.5 placer (r3d-hud's `WorldOverlays.placer`; NightScene wires it): his bubble is requested FIXED at
## BUBBLE priority, captions at CAPTION priority (they slide clear of everything above them or wait a frame). The
## results are read one frame behind (the HUD's overlays solve once per frame). Null = the local rules only.
var placer: OverlayPlacer = null
const CAPTION_IDS: Array[StringName] = [&"fx_caption_0", &"fx_caption_1", &"fx_caption_2"]


func _init() -> void:
	name = "Overlays3D"
	layer = 8


## Wire to the world view (its camera, layout and characters).
func setup(w: WorldView3D) -> void:
	wv = w
	lane = Node2D.new()
	lane.name = "LaneSpace"
	add_child(lane)
	entry = FxEntryWarning.new()
	lane.add_child(entry)
	meter = FxSpotMeter.new()
	lane.add_child(meter)
	bubble = FxThoughtBubble.new()
	_bubble_has_wait = "waiting" in bubble
	_bubble_can_flip = "glyph_right" in bubble
	lane.add_child(bubble)
	screen = Node2D.new()
	screen.name = "ScreenSpace"
	add_child(screen)
	for i in CAPTIONS:
		var c := FxCaption.new()
		c.visible = false
		screen.add_child(c)
		captions.append(c)
		_cap_actor.append(&"")
		_cap_side.append(0)
	for i in STAMPS:
		var s := FxStamp.new()
		s.visible = false
		screen.add_child(s)
		stamps.append(s)
	# "safe": a soft navy vignette while Hush hides (REDESIGN §4.4; the world also desaturates 20 %)
	vignette = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(View3DConst.INK, 0.0))
	g.set_color(1, Color(View3DConst.INK, 0.55))
	g.set_offset(0, 0.55)
	g.set_offset(1, 1.0)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 128
	vignette.texture = gt
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	add_child(vignette)
	freeze = FxFreezeFrame.new()
	add_child(freeze)
	wiper = FxWipe.new()
	add_child(wiper)
	tint = ColorRect.new()
	tint.color = Color(0.85, 0.1, 0.12, 0.0)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tint)


## The lane-space affine at the camera's aim point (sim px on the lane → logical px).
func _fit_lane() -> void:
	if wv == null or wv.cam == null:
		return
	var cam := wv.cam
	var c := cam.aim()
	var cp := Vector2(c.x * View3DConst.PX_PER_M, -c.y * View3DConst.PX_PER_M)
	var a := cam.world_to_screen(cp)
	var bx := cam.world_to_screen(cp + Vector2(100.0, 0.0))
	var by := cam.world_to_screen(cp + Vector2(0.0, 100.0))
	var xa := (bx - a) / 100.0
	var ya := (by - a) / 100.0
	var xf := Transform2D(xa, ya, Vector2.ZERO)
	xf.origin = a - xf.basis_xform(cp)
	# only a moved camera re-transforms the lane layer (every overlay under it follows)
	if not xf.is_equal_approx(lane.transform):
		lane.transform = xf
		_lane_inv = xf.affine_inverse()
	_unit = 1.0 / maxf(0.01, xa.length())


## The lane layer's inverse transform (screen → lane), refreshed by _fit_lane.
var _lane_inv := Transform2D.IDENTITY


## Logical screen px → lane space (for anchors off the lane).
func to_lane(screen: Vector2) -> Vector2:
	return _lane_inv * screen


## The world point `p` (m) in lane space.
func world_to_lane(p: Vector3) -> Vector2:
	return to_lane(wv.project(p))


func advance(snap: ViewSnapshot, dt: float) -> void:
	if wv == null:
		return
	_fit_lane()
	var in_replay := wv.is_replaying()
	var b := snap.bellows
	var bv := wv.bellows_view
	var top := world_to_lane(bv.top_world()) if bv != null else Vector2.ZERO
	meter.update_meter(b.spot_pct if not in_replay else 0.0, top + Vector2(0, -34.0 * _unit), _unit)
	meter.tick(dt)
	# his bubble belongs to him on screen (off screen the Bellows window / edge badge carry the next activity)
	bubble.enabled = not in_replay and b.present and not b.reacting and bv != null and bv.visible and wv.bellows_on_screen()
	bubble.thought_bubble(snap, top, _unit * BUBBLE_SCALE, meter.needs_space())
	# keep the bubble below the HUD band and inside the screen (REDESIGN §2.5: his bubble only clamps)
	if bubble.visible:
		var s := lane.transform * bubble.position
		var h := FxThoughtBubble.H * BUBBLE_SCALE
		var w := FxThoughtBubble.W * BUBBLE_SCALE
		var vs := wv.cam.view_size() if wv.cam != null else Vector2(2400, 1080)
		var sx := s.x
		var sy := maxf(s.y, HUD_BAND_Y + h)
		if sy - s.y > 40.0:
			# no room above his head under the HUD band: beside his head, behind his facing (the 2D rule)
			var side := -float(b.facing) if b.facing != 0 else 1.0
			sx = s.x + side * (w * 0.5 + 70.0)
			if sx < BUBBLE_LEFT_PX + EDGE_PX or sx > vs.x - BUBBLE_RIGHT_PX - EDGE_PX:
				sx = s.x - side * (w * 0.5 + 70.0)
		# the drawn extent stays on screen (fix-hud R1): glyph disc + ear pips left of the cloud, or — where the
		# bubble can flip them (FxThoughtBubble.glyph_right) — right of it at the left edge
		var flip := _bubble_can_flip and bool(bubble.get(&"glyph_right"))
		var lo := (BUBBLE_FLIP_LEFT_PX if _bubble_can_flip else BUBBLE_LEFT_PX) + EDGE_PX
		var hi := vs.x - (BUBBLE_FLIP_RIGHT_PX if flip else BUBBLE_RIGHT_PX) - EDGE_PX
		sx = clampf(sx, lo, maxf(lo, hi))
		if sx != s.x or sy != s.y:
			bubble.position = to_lane(Vector2(sx, sy))
		var l_px := BUBBLE_FLIP_LEFT_PX if flip else BUBBLE_LEFT_PX
		var r_px := BUBBLE_FLIP_RIGHT_PX if flip else BUBBLE_RIGHT_PX
		# Q2-C1 (r3d-fix-gags2): the APPLAUSE / RUNNING GAG band (the Hud's transient rects + BAND_PAD_PX) is a
		# keep-out while it shows — beside his head when that side is clear of it, else below the band
		var pad := BAND_PAD_PX * vs.y / 1080.0
		var tb := _band_bottom(sx - l_px - pad, sx + r_px + pad, pad)
		if tb > sy - h:
			var side2 := -float(b.facing) if b.facing != 0 else 1.0
			var alt := clampf(s.x + side2 * (w * 0.5 + 70.0), lo, maxf(lo, hi))
			if _band_bottom(alt - l_px - pad, alt + r_px + pad, pad) <= sy - h:
				sx = alt
			else:
				sy = tb + h
			bubble.position = to_lane(Vector2(sx, sy))
		_bubble_rect = Rect2(Vector2(sx - l_px, sy - h), Vector2(l_px + r_px, h))
	else:
		_bubble_rect = Rect2()
	# the one-cloud rule (§2.5): when the last solve kept his bubble waiting (Hush's thought is the action), it fades
	# out on a flag of its own (the bubble's `waiting`, else its self_modulate; `quiet` is the gag holds')
	var it: OverlayPlacer.Item = placer.item(&"fx_bubble") if placer != null else null
	var wait := it != null and (it.active or it.was_active) and not it.visible
	if _bubble_has_wait:
		bubble.set(&"waiting", wait)
	else:
		bubble.self_modulate.a = move_toward(bubble.self_modulate.a, 0.0 if wait else 1.0, dt * 6.0)
	# a cue shot's close-up on him (the bonk, the picture) is his face's: the bubble steps out of it
	bubble.quiet = wv.cues != null and wv.cues.wants_quiet_bubble()
	bubble.tick(dt)
	entry.tick(dt, _unit)
	if placer != null and _bubble_rect.size.x > 0.0:
		placer.request(&"fx_bubble", OverlayPlacer.Pri.BUBBLE, _bubble_rect, Vector2.INF, true)
	for ci in captions.size():
		var c := captions[ci]
		if c.active:
			if _cap_actor[ci] != &"":
				c._anchor = _caption_anchor_for(c, _cap_actor[ci], ci)
			var shown := true
			if placer != null:
				shown = _place_shared(c, CAPTION_IDS[ci])
			c.tick(dt, 1.0)
			if not shown:
				c.modulate.a = 0.0
	for s2 in stamps:
		if s2.active:
			s2.tick(dt, 1.0)
	if tint != null:
		tint.color.a = move_toward(tint.color.a, 0.18 if _busted else 0.0, dt * 1.5)
	if vignette != null:
		vignette.modulate.a = move_toward(vignette.modulate.a, 1.0 if _safe else 0.0, dt / 0.4)


## The lowest edge (+ `pad`) of the Hud's transient top-band rects that overlap the span [x0, x1] (screen px); -1
## when none shows there (or no Hud).
func _band_bottom(x0: float, x1: float, pad: float) -> float:
	var hud := _band_hud()
	if hud == null:
		return -1.0
	return Overlays3D.band_bottom_of(hud.call("transient_rects"), x0, x1, pad)


## The lowest edge (+ `pad`) of the shown rects in `rects` that overlap [x0, x1] horizontally (within `pad`); -1 when
## none. Pure.
static func band_bottom_of(rects: Variant, x0: float, x1: float, pad: float) -> float:
	var out := -1.0
	if rects is Array:
		for r in rects:
			if r is Rect2 and (r as Rect2).has_area():
				var rr: Rect2 = r
				if rr.position.x - pad < x1 and rr.end.x + pad > x0:
					out = maxf(out, rr.end.y + pad)
	return out


## The Night's Hud (NightScene's `hud`, up the tree) for its transient band rects; null in a sandbox without one.
## Looked up again every BAND_LOOKUP_F frames until found (the scene wires the Hud after the world view).
func _band_hud() -> Object:
	if _hud != null and is_instance_valid(_hud):
		return _hud
	_hud = null
	_hud_wait -= 1
	if _hud_wait > 0:
		return null
	_hud_wait = BAND_LOOKUP_F
	var n: Node = get_parent()
	while n != null:
		if "hud" in n:
			var h: Variant = n.get("hud")
			if h is Object and is_instance_valid(h) and (h as Object).has_method("transient_rects"):
				_hud = h
				return _hud
		n = n.get_parent()
	return null


## His bubble's screen rect (the protected set; empty when hidden).
func bubble_rect() -> Rect2:
	return _bubble_rect


func entry_warning(snap: ViewSnapshot, lead_ticks: int) -> void:
	var from := snap.bellows.room
	for r in snap.path_rooms:
		if r != snap.hush.room:
			from = r
		else:
			break
	entry.own_legs = wv.bellows_view != null and wv.bellows_view.uses_rig
	entry.start(wv.layout, snap.hush.room, from, lead_ticks)


func entry_stop() -> void:
	entry.stop()


func spot_bang() -> void:
	meter.bang()


## The screen point (logical px) a caption / stamp of `size` px anchored at world point `at` starts at: projected,
## then kept below the HUD band and inside the screen (the anchor is the text's bottom centre).
func screen_anchor(at: Vector3, size: int) -> Vector2:
	var vs := wv.cam.view_size() if wv != null and wv.cam != null else Vector2(2400, 1080)
	var p := wv.project(at) if wv != null and wv.cam != null else vs * 0.5
	var top := HUD_BAND_Y + float(size) * 1.3
	p.y = clampf(p.y, top, vs.y - 80.0)
	p.x = clampf(p.x, 80.0 + float(size) * 2.5, vs.x - 80.0 - float(size) * 2.5)
	return p


## Where a caption box (w, h; its anchor = bottom centre) goes next to a head's screen rect: above it when that
## clears the HUD band, else beside it on the side with room (never over the face), inside `screen`.
static func caption_anchor(head: Rect2, box: Vector2, screen: Rect2, band_y: float, gap: float = 24.0) -> Vector2:
	var r := Overlays3D.caption_place(head, box, screen, band_y, 0, gap)
	return Vector2(r.x, r.y)


## `caption_anchor` with a remembered side (`prefer`: 1 above, 2 left, 3 right, 0 none): the preferred side is kept
## while it still fits, so a caption does not hop from side to side as the head moves. Returns (x, y, side).
static func caption_place(head: Rect2, box: Vector2, screen: Rect2, band_y: float, prefer: int = 0, gap: float = 24.0) -> Vector3:
	var hw := box.x * 0.5
	var above := Vector2(head.get_center().x, head.position.y - gap)
	var fits_above := above.y - box.y >= band_y
	var room_l := head.position.x - gap - screen.position.x
	var room_r := screen.end.x - head.end.x - gap
	var side := 0
	if prefer == 1 and fits_above:
		side = 1
	elif prefer == 2 and room_l >= box.x:
		side = 2
	elif prefer == 3 and room_r >= box.x:
		side = 3
	elif fits_above:
		side = 1
	elif room_l >= box.x and (room_l >= room_r or room_r < box.x):
		side = 2
	elif room_r >= box.x:
		side = 3
	else:
		side = 2 if room_l > room_r else 3
	if side == 1:
		return Vector3(clampf(above.x, screen.position.x + hw, screen.end.x - hw), above.y, 1)
	var y := clampf(head.get_center().y + box.y * 0.5, band_y + box.y, screen.end.y - 20.0)
	var x := head.position.x - gap - hw if side == 2 else head.end.x + gap + hw
	return Vector3(clampf(x, screen.position.x + hw, screen.end.x - hw), y, side)


## The screen rect (logical px) of an actor's head (hair included).
func head_rect(actor: StringName) -> Rect2:
	var cv := wv.character(String(actor)) if wv != null else null
	if cv == null or wv.cam == null:
		return Rect2()
	var h := cv.head_world()
	var t := cv.top_world()
	var box := AABB(Vector3(h.x - 0.32, h.y - 0.3, h.z - 0.3), Vector3(0.64, maxf(0.6, t.y + 0.05 - (h.y - 0.3)), 0.6))
	return wv.cam.project_aabb(box)


func _caption_anchor_for(c: FxCaption, actor: StringName, ci: int = -1) -> Vector2:
	var hr := head_rect(actor)
	if hr.size.x <= 0.0:
		return c._anchor
	var vs := wv.cam.view_size()
	var box := Vector2(c.world_width(), float(c.font_size) * 1.35)
	var prefer := _cap_side[ci] if ci >= 0 else 0
	var r := Overlays3D.caption_place(hr, box, Rect2(Vector2(40, 0), vs - Vector2(80, 40)), HUD_BAND_Y, prefer)
	if ci >= 0:
		_cap_side[ci] = int(r.z)
	return Vector2(r.x, r.y)


## The shared placer's verdict for a caption (last frame's solve): move its anchor to the placed rect, or hold it
## invisible while it waits; then request this frame's wanted rect.
func _place_shared(c: FxCaption, id: StringName) -> bool:
	var w := c.world_width()
	var h := float(c.font_size) * 1.35
	var want := c._anchor
	var shown := true
	var it := placer.item(id)
	if it != null and it.rect.size.x > 0.0:
		shown = it.visible
		if it.visible:
			c._anchor = Vector2(it.rect.get_center().x, it.rect.end.y)
	placer.request(id, OverlayPlacer.Pri.CAPTION, Rect2(want - Vector2(w * 0.5, h), Vector2(w, h)), want)
	return shown


## A pun caption at a world point (m), e.g. above his head; `actor` = the character whose head it sits beside
## (re-placed every frame, never over the face); &"" keeps it where it started. Returns the caption.
func caption(text: String, at: Vector3, size: int = 96, actor: StringName = &"") -> FxCaption:
	var ci := _cap_i
	var c := captions[_cap_i]
	_cap_i = (_cap_i + 1) % CAPTIONS
	_cap_actor[ci] = actor
	_cap_side[ci] = 0
	c.visible = true
	var vs := wv.cam.view_size() if wv != null and wv.cam != null else Vector2(2400, 1080)
	c.keep_in = Rect2(Vector2(40, HUD_BAND_Y), vs - Vector2(80, HUD_BAND_Y + 40))
	c.avoid.clear()
	if _bubble_rect.size.x > 0.0:
		c.avoid.append(_bubble_rect)
	if wv != null:
		for r in wv.hud_rects:
			c.avoid.append(r)
	c.start(text, screen_anchor(at, size), size, true)
	if actor != &"":
		c._anchor = _caption_anchor_for(c, actor, ci)
	return c


## A small stamp at a world point (m).
func stamp(text: String, at: Vector3, size: int = 64) -> FxStamp:
	var s := stamps[_stamp_i]
	_stamp_i = (_stamp_i + 1) % STAMPS
	s.visible = true
	s.start(text, screen_anchor(at, size), size)
	return s


## The freeze-frame on / off (wire to `JuiceClock.freeze_frame_changed`).
func freeze_frame(on: bool, label: String = "") -> void:
	if freeze != null:
		freeze.set_on(on, label)


## The caught sequence's iris wipe around a screen point (0–1 of the view).
func wipe(centre_frac: Vector2 = Vector2(0.5, 0.45)) -> void:
	if wiper != null:
		wiper.start(centre_frac)


## Hush is hidden: the "safe" vignette eases in (0.4 s) and out.
func set_safe(on: bool) -> void:
	_safe = on


func busted(on: bool) -> void:
	_busted = on


func clear() -> void:
	entry.stop()
	for c in captions:
		if c.active:
			c.retire()
		c.visible = false
	for s in stamps:
		if s.active:
			s.retire()
		s.visible = false
	_busted = false
	if tint != null:
		tint.color.a = 0.0
