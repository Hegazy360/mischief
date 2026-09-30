## Overlays3D — the view's 2D FX over the 3D world (REDESIGN §5.8; brief r3d-view3d §4.6): his thought bubble (the
## next activity, 200×170 with a 112 px icon, 12 px ring, 60 px glyph, 24 px ear pips), the "?" spot meter + "!",
## the entry warning, captions and stamps, and the Busted Cam tint. They are the Stage-2 FX classes (FxThoughtBubble,
## FxSpotMeter, FxEntryWarning, FxCaption, FxStamp) drawn on a CanvasLayer inside a **lane-space** node whose
## transform maps sim px on the lane plane to logical screen px (re-fitted every frame from the camera), so their
## world-px layout and `unit` sizing carry over unchanged; anchors off the lane are projected and mapped back.
## Placement: his bubble is clamped inside the safe area below the HUD band; captions avoid the protected rects and the
## transient meter band (the placer of REDESIGN §2.5 through `OverlayPlacer` when r3d-hud's is present).
class_name Overlays3D
extends CanvasLayer

## His bubble at REDESIGN §4.2 size: the Stage-2 bubble (150×130) × 1.333 = 200×173.
const BUBBLE_SCALE := 1.333
const HUD_BAND_Y := 212.0
const CAPTIONS := 3
const STAMPS := 2

var wv: WorldView3D = null
var lane: Node2D = null
var bubble: FxThoughtBubble = null
var meter: FxSpotMeter = null
var entry: FxEntryWarning = null
var captions: Array[FxCaption] = []
var stamps: Array[FxStamp] = []
var tint: ColorRect = null
var _unit := 1.0
var _bubble_rect := Rect2()
var _cap_i := 0
var _stamp_i := 0
var _busted := false


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
	lane.add_child(bubble)
	for i in CAPTIONS:
		var c := FxCaption.new()
		c.visible = false
		lane.add_child(c)
		captions.append(c)
	for i in STAMPS:
		var s := FxStamp.new()
		s.visible = false
		lane.add_child(s)
		stamps.append(s)
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
	lane.transform = xf
	_unit = 1.0 / maxf(0.01, xa.length())


## Logical screen px → lane space (for anchors off the lane).
func to_lane(screen: Vector2) -> Vector2:
	return lane.transform.affine_inverse() * screen


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
	bubble.enabled = not in_replay and b.present and bv != null and bv.visible and wv.bellows_on_screen()
	bubble.thought_bubble(snap, top, _unit * BUBBLE_SCALE, meter.needs_space())
	# keep the bubble below the HUD band and inside the screen (REDESIGN §2.5: his bubble only clamps)
	if bubble.visible:
		var s := lane.transform * bubble.position
		var h := FxThoughtBubble.H * BUBBLE_SCALE
		var w := FxThoughtBubble.W * BUBBLE_SCALE
		var vs := wv.cam.view_size() if wv.cam != null else Vector2(2400, 1080)
		var sx := clampf(s.x, w * 0.6, vs.x - w * 0.6)
		var sy := maxf(s.y, HUD_BAND_Y + h)
		if sx != s.x or sy != s.y:
			bubble.position = to_lane(Vector2(sx, sy))
		_bubble_rect = Rect2(Vector2(sx - w * 0.5 - 70.0, sy - h), Vector2(w + 70.0, h))
	else:
		_bubble_rect = Rect2()
	bubble.tick(dt)
	entry.tick(dt, _unit)
	for c in captions:
		if c.active:
			c.tick(dt, _unit)
	for s2 in stamps:
		if s2.active:
			s2.tick(dt, _unit)
	if tint != null:
		tint.color.a = move_toward(tint.color.a, 0.18 if _busted else 0.0, dt * 1.5)


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


## A pun caption at a world point (m), e.g. above his head; returns the caption.
func caption(text: String, at: Vector3, size: int = 96) -> FxCaption:
	var c := captions[_cap_i]
	_cap_i = (_cap_i + 1) % CAPTIONS
	c.visible = true
	c.keep_in = Rect2(to_lane(Vector2(40, HUD_BAND_Y)), to_lane(wv.cam.view_size() - Vector2(40, 40)) - to_lane(Vector2(40, HUD_BAND_Y))) if wv.cam != null else Rect2()
	c.start(text, world_to_lane(at), size, true)
	return c


## A small stamp at a world point (m).
func stamp(text: String, at: Vector3, size: int = 64) -> FxStamp:
	var s := stamps[_stamp_i]
	_stamp_i = (_stamp_i + 1) % STAMPS
	s.visible = true
	s.start(text, world_to_lane(at), size)
	return s


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
