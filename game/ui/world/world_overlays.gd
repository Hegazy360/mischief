## WorldOverlays — the 2D overlays anchored to 3D points (CanvasLayer 8, REDESIGN_3D §4.1 + §5.8,
## r3d-index §7.8): passive previews / needs clouds, Hush's thought, item bubbles, the rig ring at the
## prop, the safety-net marker and the tag flights, placed every frame by the shared OverlayPlacer
## (§2.5) so hints never cover the action.
##
##   overlays.setup(anchor_src, hud)   # anchor_src: WorldView3D (or FakeAnchors) — §7.8 API:
##                                     #   project(Vector3) -> Vector2, anchor_of(id, kind) -> Vector3,
##                                     #   actor_anchor(actor, kind) -> Vector3, protected_rects(),
##                                     #   safe_rect(), on_screen(Vector3) -> bool
##                                     # hud: the Hud (always-on rects, Script pip targets) or null
##   overlays.warm(ctx)                # rasterise every pictogram / icon of the Night (under the curtain)
##   overlays.apply(model)             # every frame, after OverlayRules.fill — idempotent, allocation-free
##
## `placer` is shared: `r3d-view3d`'s 2D FX (his bubble, captions, stamps, entry warning, spot meter)
## `placer.request(...)` their rects between two apply() calls; apply() adds the overlays' own items,
## solves once, and every producer reads its placed `rect` / `visible` afterwards (their results are
## the ones of the latest apply, one frame behind at most).
##
## Perf (D17 / r3d-fix-perf RQ2): the placer re-solves only when an input moved > 1 px (OverlayPlacer's dirty flag);
## the face boxes gate on the character being shown (WorldView3D.character) instead of projecting its AABB again.
## `phase_us` keeps the per-phase split.
##
## Crowding rules (r3d QA Q-C1 / Q-C2, on top of §2.5):
##   * FACE BOXES — each character's head on screen (`face_box`) is a hard keep-out: no cloud, bubble,
##     marker or item covers a face, and the rig ring stays ON the prop but passes behind a face next to
##     it (a little smaller, the arc inside the face box not drawn — RigRing.set_occluders);
##   * the transient top band — the APPLAUSE meter and the RUNNING GAG fuse, while the Hud shows them
##     (`Hud.transient_rects`) — is a hard keep-out too: a preview slides clear or waits;
##   * ONE thought cloud at a time (his bubble or Hush's thought): the one nearest the action (the rig
##     point she is at, else her head) — OverlayPlacer's one-cloud rule;
##   * every item is clamped into the safe rect; its tail points at its anchor from where it lands.
##
## Round 2 (r3d QA round 2, Q2-C1 / Q2-C2 / 16(a)):
##   * ATTACHED previews — a badge never floats off its prop: it stays within DETACH_MAX (80 px at the 1080 base) of
##     its stalk (the preview anchor → the prop's top) or of the prop itself; blocked, it takes a spot BESIDE the
##     prop's top (the side away from Hush first), else it waits (OverlayPlacer.request_attached). Its tail is a
##     chain of thought-dots to the prop's top edge (`tail_target`), so the eye can follow it to its object;
##   * ONE countdown ring per target — the prop's badge carries his ring; his bubble then shows the icon only
##     (it is told through FxThoughtBubble.ring_hidden when it has that flag; a bubble without it keeps its ring
##     and the badge draws none) and the Hud's Bellows-window chip drops its ring (Hud.set_his_ring_on_prop);
##   * the first show is primed under the curtain (`warm_first_show`, called by `warm`): every placer item is
##     pooled and every overlay kind drawn once at 1 % alpha for WARM_FRAMES frames.
class_name WorldOverlays
extends CanvasLayer

const LAYER := 8
## HUD always-on hit rects are protected with this margin (§2.5).
const HUD_PAD := 48.0
## The thought sits this far beside her head (px at the 1080 base).
const THOUGHT_GAP := 24.0
## Margin round a face box and round the transient top-band HUD (px at the 1080 base; 24 keeps a 16:9 preview room
## to slide between the Script chip's +48 and the fuse instead of waiting out a whole Running Gag).
const FACE_PAD := 12.0
const TRANSIENT_PAD := 24.0
## A face box's half-width and its reach above the head top / below the head anchor, as fractions of
## the projected head span (head anchor → head top).
const FACE_HALF_W := 0.6
const FACE_UP := 0.2
const FACE_DOWN := 0.35
## The ring next to a face is drawn this much smaller (and passes behind the face).
const RING_NEAR_FACE_SCALE := 0.85
## Who has a face box.
const FACE_ACTORS: Array[StringName] = [&"hush", &"bellows"]
## ATTACHED previews (r3d QA round 2, Q2-C1): the farthest a preview may sit from its stalk (its anchor → the prop's
## top), px at the 1080 base; its BESIDE spots sit this far off the prop's side, centred BESIDE_DROP of the cloud's
## height below the prop's top.
const DETACH_MAX := 80.0
## A prop's projected rect follows its anchor for up to PROP_REFRESH frames of camera motion (re-projected sooner
## after a jump of PROP_JUMP px).
const PROP_REFRESH := 6
const PROP_JUMP := 24.0
const BESIDE_GAP := 12.0
const BESIDE_DROP := 0.15

var anchor_src: Object = null
var hud: Object = null
var placer: OverlayPlacer = OverlayPlacer.new()
var root: Node2D
var previews: Array[PreviewCloud] = []
var thought: ThoughtCloud
var items: Array[ItemBubbleView] = []
var ring: RigRing
var marker: SafetyMarker
var flights: Array[TagFlight] = []
## World-overlay scale: the viewport height / 1080 × the tablet factor (UiScale).
var k: float = 1.0
## Test hook: a fixed viewport size.
var size_override: Vector2 = Vector2.ZERO
## Counts of the last apply (the HUD lint / e2e report: overlays on screen, loud ones).
var shown_count: int = 0
var loud_count: int = 0
var apply_count: int = 0
## Last apply's phase costs in µs: [protected rects, requests, solve, nodes] (perf probes; always filled, 4 clock reads).
var phase_us: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

## Dev probe (off unless the game runs with `--ov-dump=/abs/file.jsonl`, optionally `--ov-dump-frames=a-b`): every
## apply slower than PROBE_SLOW_US (`--ov-dump-slow=<µs>`), and every apply inside the frame window, appends one JSON line — the
## per-step µs split (`marks`), the placer's items (want / rect / anchor / visible) and its protected / hard /
## safe rects. Zero cost when off (one bool test per apply).
const PROBE_SLOW_US := 400
static var _probe_path: String = ""
static var _probe_from: int = -1
static var _probe_to: int = -1
static var _probe_slow: int = PROBE_SLOW_US
static var _probe_parsed: bool = false
var _probe_on: bool = false
var _marks := PackedInt64Array()
const _MARK_NAMES: PackedStringArray = ["protected", "hard", "thought_req", "marker_req", "previews_req", "items_req",
	"solve", "thought_out", "marker_out", "previews_out", "items_out", "ring", "flights"]

## The last apply's face boxes (FACE_ACTORS order; Rect2() = not on screen) and the one-cloud focus.
var faces: Array[Rect2] = [Rect2(), Rect2()]
var focus: Vector2 = Vector2.INF
## ONE ring per target (Q2-C1/C2), last apply: the badges may carry his countdown ring (his bubble can drop its own,
## or it is not up), and one shown badge does carry it (his bubble then shows the icon only; the Hud's Bellows-window
## chip drops its ring too — Hud.set_his_ring_on_prop).
var ring_to_badge: bool = true
var ring_on_prop: bool = false
## Hush's head x on screen this apply (INF = not shown): a badge's beside spot goes to the side away from her.
var hush_x: float = INF
## Each preview slot's prop rect on screen this apply (Rect2() = unknown / a combine badge): its tail target.
var _prop_rects: Array[Rect2] = []
## Cache of projected prop rects by hotspot: [anchor screen point, rect] (re-projected when the anchor moved).
var _prop_cache: Dictionary = {}
var _src_has_prop_rect: bool = false
var _src_has_prop_visual: bool = false
var _hud_takes_ring: bool = false
## His bubble (WorldView3D.overlays.bubble, an FxThoughtBubble; duck-typed) and whether it has `ring_hidden`.
var _bubble: CanvasItem = null
var _bubble_has_ring_flag: bool = false

## Protected rects of this frame: a fixed pool (unused slots hold FAR, which touches nothing).
var _protected: Array[Rect2] = []
## Hard keep-outs of this frame (face boxes + the shown top-band HUD): a fixed pool like _protected.
var _hard: Array[Rect2] = []
var _item_tex: Dictionary = {}
var _combine_tex: Dictionary = {}
## The anchor source has a `hud_rects` property (WorldView3D) and a Hud is bound: its protected_rects() already
## carries the HUD's always-on rects.
var _src_takes_hud: bool = false
## The anchor source hands out its CharacterView3Ds (`character(id)`, WorldView3D): a face box is gated on the
## character being shown instead of on actor_screen_rect (8 corner projections per actor per frame — RQ2).
var _src_has_character: bool = false

## Capacity of the protected-rect pool (the anchor source's ~5 + the Hud's 4 + spare) and of the hard pool
## (two faces + the meter + the fuse + spare).
const MAX_PROTECTED := 16
const MAX_HARD := 6
const FAR := Rect2(-1.0e9, -1.0e9, 1.0, 1.0)


func _init() -> void:
	layer = LAYER
	if not _probe_parsed:
		_probe_parsed = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--ov-dump="):
				_probe_path = a.substr(10)
			elif a.begins_with("--ov-dump-slow="):
				_probe_slow = int(a.substr(15))
			elif a.begins_with("--ov-dump-frames="):
				var ab := a.substr(17).split("-")
				if ab.size() == 2:
					_probe_from = int(ab[0])
					_probe_to = int(ab[1])
	_probe_on = _probe_path != ""
	_marks.resize(_MARK_NAMES.size() + 1)
	name = "WorldOverlays"
	root = Node2D.new()
	root.name = "Root"
	add_child(root)
	_protected.resize(MAX_PROTECTED)
	_protected.fill(FAR)
	_prop_rects.resize(OverlayModel.MAX_PREVIEWS)
	_prop_rects.fill(Rect2())
	_hard.resize(MAX_HARD)
	_hard.fill(FAR)
	for i in OverlayModel.MAX_PREVIEWS:
		var p := PreviewCloud.new()
		p.name = "Preview%d" % i
		p.visible = false
		previews.append(p)
		root.add_child(p)
	for i in OverlayModel.MAX_ITEMS:
		var b := ItemBubbleView.new()
		b.name = "Item%d" % i
		b.visible = false
		items.append(b)
		root.add_child(b)
	marker = SafetyMarker.new()
	marker.name = "SafetyMarker"
	marker.visible = false
	root.add_child(marker)
	ring = RigRing.new()
	ring.name = "RigRing"
	ring.visible = false
	root.add_child(ring)
	thought = ThoughtCloud.new()
	thought.name = "Thought"
	thought.visible = false
	root.add_child(thought)
	for i in OverlayModel.MAX_FLIGHTS:
		var f := TagFlight.new()
		f.name = "Flight%d" % i
		f.arrived.connect(_on_flight_arrived)
		flights.append(f)
		root.add_child(f)


## Bind the anchor source (WorldView3D / FakeAnchors) and optionally the Hud.
func setup(p_anchor_src: Object, p_hud: Object = null) -> void:
	anchor_src = p_anchor_src
	hud = p_hud
	_src_takes_hud = anchor_src != null and hud != null and "hud_rects" in anchor_src and hud.has_method("always_on_rects")
	_src_has_character = anchor_src != null and anchor_src.has_method("character") and "cam" in anchor_src
	_src_has_prop_rect = anchor_src != null and anchor_src.has_method("prop_screen_rect")
	_src_has_prop_visual = anchor_src != null and anchor_src.has_method("prop") and "cam" in anchor_src
	_hud_takes_ring = hud != null and hud.has_method("set_his_ring_on_prop")
	_bubble = null
	_bubble_has_ring_flag = false
	_prop_cache.clear()


## Rasterise every pictogram, item icon and needs silhouette of the Night once (call under the
## curtain; nothing is built during PLAY afterwards).
func warm(ctx: OverlayCtx) -> void:
	if ctx == null:
		return
	for pr in ctx.pictograms:
		PreviewArt.texture(String(pr), ctx.pictograms[pr])
	for it in ctx.tonight_items:
		_item_icon(String(it))
	for pr in ctx.combines:
		for e in ctx.combines[pr]:
			if e is Dictionary:
				_combine_icon(String((e as Dictionary).get("badge", "")))
	# the HUD's activity icons of tonight (his next activity in the Bellows window / edge badge, the action
	# button's target): rasterised here, not on first sight during PLAY (a cold SVG raster costs ~1 ms in
	# Hud.apply — D17 spike hunt)
	if ctx.episode != null:
		for le in ctx.episode.loop:
			if le != null and le.activity != "":
				UiIcons.activity(le.activity)
	for act in ctx.trig_hotspots:
		UiIcons.activity(String(act))
	warm_first_show(ctx)


## Frames the first-show primer keeps one overlay of every kind drawn (nearly transparent) under the curtain.
const WARM_FRAMES := 2
var warm_left: int = 0
var _warm_applies: int = 0


## The first show of every overlay kind, under the curtain (QA round 2, 16(a): WorldOverlays.apply at its first busy
## frames, t255–263, 0.88–1.11 ms in 3 of 3 rendered runs — D18.2 deterministic): every pooled placer item is made
## and solved once (no Item is created during PLAY), and one preview (with his ring, a needs slot and its "?"), a
## loud preview, a combine badge, the thought, an item bubble, the rig ring (behind a face) and the safety marker are
## set up and drawn for WARM_FRAMES frames at 1 % alpha, then hidden again. The next apply() owns them as usual.
func warm_first_show(ctx: OverlayCtx = null) -> void:
	var vs := view_size()
	var kk := (vs.y / 1080.0) * UiScale.factor_for(vs)
	var c := vs * 0.5
	var pict: Texture2D = null
	var need: Texture2D = null
	var badge: Texture2D = null
	if ctx != null:
		for pr in ctx.pictograms:
			pict = PreviewArt.texture(String(pr), ctx.pictograms[pr])
			break
		for it in ctx.tonight_items:
			need = _item_icon(String(it))
			break
		for pr in ctx.combines:
			for e in ctx.combines[pr]:
				if e is Dictionary:
					badge = _combine_icon(String((e as Dictionary).get("badge", "")))
	if pict == null:
		pict = PreviewArt.texture(PreviewArt.UNKNOWN)
	for i in previews.size():
		var node := previews[i]
		match i % 3:
			0:
				node.set_data(pict, OverlayModel.STRENGTH_PASSIVE, need, 0.5, null, false, kk)
			1:
				node.set_data(pict, OverlayModel.STRENGTH_FULL, null, -1.0, null, true, kk)
			_:
				node.set_data(null, OverlayModel.STRENGTH_FULL, null, -1.0, badge, false, kk)
		node.set_tail(Vector2(40.0, 160.0) * kk)
		_warm_node(node, c)
	for b in items:
		b.set_data(need if need != null else pict, kk)
		_warm_node(b, c)
	thought.set_data(pict, Vector2.DOWN, kk)
	_warm_node(thought, c)
	var occ: Array[Rect2] = [Rect2(c, Vector2(60, 60) * kk)]
	ring.set_occluders(occ)
	ring.set_data(0.5, true, kk)
	_warm_node(ring, c)
	marker.set_scale_k(kk)
	_warm_node(marker, c)
	# every pooled placer item, requested and solved once (ATTACHED previews with their beside spots)
	placer.begin_frame()
	var sz := Vector2(146, 146) * kk
	placer.request(&"ov_thought", OverlayPlacer.Pri.THOUGHT, Rect2(c - sz, sz), c, false, true)
	placer.request(&"ov_marker", OverlayPlacer.Pri.DANGER, Rect2(c, sz), c)
	for i in OverlayModel.MAX_PREVIEWS:
		var a := Vector2(vs.x * (0.1 + 0.1 * float(i)), vs.y * 0.4)
		placer.request_attached(_preview_id(i), OverlayPlacer.Pri.PREVIEW, Rect2(a - Vector2(sz.x * 0.5, sz.y), sz), a,
			Rect2(a + Vector2(-40, 100) * kk, Vector2(80, 120) * kk), DETACH_MAX * kk, Rect2(a - Vector2(sz.x + 20, 0), sz),
			Rect2(a + Vector2(20, 0), sz))
	for i in OverlayModel.MAX_ITEMS:
		var a := Vector2(vs.x * (0.2 + 0.2 * float(i)), vs.y * 0.7)
		placer.request(_item_id(i), OverlayPlacer.Pri.ITEM, Rect2(a - Vector2(sz.x * 0.5, sz.y), sz), a)
	placer.invalidate()
	placer.solve(_protected, _safe_rect(vs), _hard, Vector2.INF)
	placer.begin_frame()
	placer.invalidate()
	warm_left = WARM_FRAMES
	_warm_applies = 0
	set_process(true)


func _warm_node(n: CanvasItem, at: Vector2) -> void:
	if n is Node2D:
		(n as Node2D).position = at
	n.modulate.a = 0.01
	n.visible = true
	n.queue_redraw()


func _process(_delta: float) -> void:
	if warm_left <= 0:
		set_process(false)
		return
	warm_left -= 1
	if warm_left > 0:
		return
	_end_primer()


## The primer is done: hide everything it showed (apply() shows what the model asks for from here on).
func _end_primer() -> void:
	warm_left = 0
	for node in previews:
		node.visible = false
		node.modulate.a = 1.0
	for b in items:
		b.visible = false
		b.modulate.a = 1.0
	thought.set_data(null, Vector2.DOWN, k)
	thought.modulate.a = 1.0
	ring.clear()
	ring.modulate.a = 1.0
	var none: Array[Rect2] = []
	ring.set_occluders(none)
	marker.visible = false
	marker.modulate.a = 1.0
	set_process(false)


## The viewport's logical size.
func view_size() -> Vector2:
	if size_override != Vector2.ZERO:
		return size_override
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1920, 1080)


## Show `model` (see the class doc).
func apply(model: OverlayModel) -> void:
	apply_count += 1
	if warm_left > 0:
		# the first-show primer owns the nodes for its frames (under the curtain); a primer whose frames never come
		# (no _process) gives them back after WARM_FRAMES + 1 applies
		_warm_applies += 1
		if _warm_applies <= WARM_FRAMES + 1:
			return
		_end_primer()
	var vs := view_size()
	k = (vs.y / 1080.0) * UiScale.factor_for(vs)
	shown_count = 0
	loud_count = 0
	var pf := _probe_on
	var t0 := Time.get_ticks_usec()
	if pf:
		_marks[0] = t0
	_build_protected(vs)
	if pf:
		_mark(1)
	var src_ok := anchor_src != null and is_instance_valid(anchor_src)
	_build_hard(src_ok)
	if pf:
		_mark(2)
	var t1 := Time.get_ticks_usec()
	var safe := _safe_rect(vs)
	var hidden := model.hidden or not src_ok
	# her head on screen, projected once per apply (the one-cloud focus, her thought, the beside side)
	var hh := _actor_screen(&"hush", &"head") if src_ok else Vector2.INF
	# the one-cloud focus: the rig point she is at, else her head
	focus = Vector2.INF
	if src_ok and model.at_hotspot != "":
		focus = _anchor_screen(model.at_hotspot, &"ring")
	if src_ok and not focus.is_finite():
		focus = hh
	# ONE countdown ring per target (Q2-C1/C2): the prop's badge carries his ring and his bubble shows the icon only
	# (FxThoughtBubble.ring_hidden); a bubble that cannot drop its ring keeps it, and the badge then shows none
	var bub := _his_bubble() if src_ok else null
	var bub_up := bub != null and bub.visible
	var bub_can_hide := bub != null and _bubble_has_ring_flag
	ring_to_badge = bub_can_hide or not bub_up
	ring_on_prop = false
	hush_x = hh.x if hh.is_finite() else INF
	# --- requests (the placer's own items)
	var tpos := Vector2.INF
	if not hidden and model.thought.hotspot != "":
		var head := hh
		if head.is_finite():
			var sz := thought.box_size()
			var side := float(model.thought.side)
			# beside her face box (not on it), on its side
			var fx := head.x + side * (sz.x * 0.5 + THOUGHT_GAP * k)
			var fb := faces[0]
			if fb.has_area():
				fx = (fb.end.x if side > 0.0 else fb.position.x) + side * (sz.x * 0.5 + THOUGHT_GAP * k * 0.5)
			var c := Vector2(fx, head.y - sz.y * 0.45)
			placer.request(&"ov_thought", OverlayPlacer.Pri.THOUGHT, Rect2(c - sz * 0.5, sz), head, false, true)
			tpos = head
	if pf:
		_mark(3)
	if not hidden and model.safety_marker.hotspot != "":
		var p := _anchor_screen(model.safety_marker.hotspot, &"eyes")
		if not p.is_finite():
			p = _anchor_screen(model.safety_marker.hotspot, &"preview")
		if p.is_finite():
			var sz := marker.box_size()
			placer.request(&"ov_marker", OverlayPlacer.Pri.DANGER, Rect2(p - sz * 0.5, sz), p)
	if pf:
		_mark(4)
	for i in OverlayModel.MAX_PREVIEWS:
		if hidden or i >= model.preview_count:
			continue
		var pv := model.previews[i]
		var kind := &"tag" if pv.pictogram.is_empty() and pv.combines_badge != "" else &"preview"
		var p := _anchor_screen(pv.hotspot, kind)
		if not p.is_finite():
			continue
		var node := previews[i]
		# ONE ring per target: the badge carries his countdown unless his bubble must keep it (see ring_to_badge)
		var ring := pv.his_ring_frac if ring_to_badge else -1.0
		node.set_data(_pict(pv), pv.strength, _item_icon(pv.needs_item) if pv.needs_item != "" else null,
			ring, _combine_icon(pv.combines_badge) if pv.pictogram.is_empty() else null, pv.loud, k)
		var sz := node.box_size()
		var want := Rect2(p - Vector2(sz.x * 0.5, sz.y), sz)
		var exempt := pv.hotspot == model.at_hotspot and pv.hotspot != ""
		if kind == &"tag":
			want = Rect2(p + Vector2(24.0 * k, -sz.y * 0.5), sz)
			_prop_rects[i] = Rect2()
			# the preview of the prop Hush is at: the view protects that prop + its preview FOR it
			placer.request(_preview_id(i), OverlayPlacer.Pri.PREVIEW, want, p, false, exempt)
			continue
		# ATTACHED (Q2-C1): within DETACH_MAX of its stalk (the anchor → the prop's top), else beside the prop, else wait
		var pr := _prop_rect(pv.hotspot, p)
		_prop_rects[i] = pr
		var alt_l := Rect2()
		var alt_r := Rect2()
		if pr.has_area():
			var cy := pr.position.y + sz.y * BESIDE_DROP - sz.y * 0.5
			alt_l = Rect2(Vector2(pr.position.x - BESIDE_GAP * k - sz.x, cy), sz)
			alt_r = Rect2(Vector2(pr.end.x + BESIDE_GAP * k, cy), sz)
			# the side away from Hush first (her approach stays clear), else the one toward the screen's middle
			var hx := hush_x
			var away_left := (hx > pr.get_center().x) if is_finite(hx) else (pr.get_center().x > vs.x * 0.5)
			if not away_left:
				var tmp := alt_l
				alt_l = alt_r
				alt_r = tmp
		placer.request_attached(_preview_id(i), OverlayPlacer.Pri.PREVIEW, want, p, pr, DETACH_MAX * k, alt_l, alt_r,
			exempt)
	if pf:
		_mark(5)
	for i in OverlayModel.MAX_ITEMS:
		if hidden or i >= model.item_count:
			continue
		var ib := model.item_bubbles[i]
		var p := _anchor_screen(ib.hotspot, &"item")
		if not p.is_finite():
			p = _anchor_screen(ib.hotspot, &"preview")
		if not p.is_finite():
			continue
		items[i].set_data(_item_icon(ib.item), k)
		var sz := items[i].box_size()
		placer.request(_item_id(i), OverlayPlacer.Pri.ITEM, Rect2(p - Vector2(sz.x * 0.5, sz.y), sz), p)
	if pf:
		_mark(6)
	var t2 := Time.get_ticks_usec()
	placer.solve(_protected, safe, _hard, focus)
	var t3 := Time.get_ticks_usec()
	if pf:
		_mark(7)
	# --- results → nodes
	var th := placer.item(&"ov_thought")
	if th != null and th.active and th.visible:
		thought.position = th.rect.get_center()
		thought.set_data(PreviewArt.texture(model.thought.prank, model.thought.pictogram),
			(tpos - thought.position).normalized(), k)
		shown_count += 1
		loud_count += 1
	else:
		thought.set_data(null, Vector2.DOWN, k)
	if pf:
		_mark(8)
	var mk := placer.item(&"ov_marker")
	marker.visible = mk != null and mk.active and mk.visible
	marker.set_process(marker.visible)
	if marker.visible:
		marker.position = mk.rect.get_center()
		marker.set_scale_k(k)
		shown_count += 1
		loud_count += 1
	if pf:
		_mark(9)
	for i in OverlayModel.MAX_PREVIEWS:
		var it := placer.item(_preview_id(i))
		var node := previews[i]
		var on := it != null and it.active and it.visible and i < model.preview_count and not hidden
		node.visible = on
		if on:
			var c := it.rect.get_center()
			node.position = c
			# the tail runs to the prop itself (its top edge, nearest the cloud), not to the empty air above it — unless
			# that chain would run through another overlay (it would read as joining the two): the short tail then
			var tgt := tail_target(c, _prop_rects[i], it.anchor, k)
			node.set_tail(Vector2.ZERO if _tail_crosses(it, c, tgt) else tgt - c)
			node.modulate.a = 0.45 if it.faded else 1.0
			shown_count += 1
			if model.previews[i].loud:
				loud_count += 1
			if node.ring_frac >= 0.0:
				ring_on_prop = true
	if bub_can_hide:
		bub.set(&"ring_hidden", ring_on_prop)
	if hud != null and _hud_takes_ring:
		hud.call("set_his_ring_on_prop", ring_on_prop)
	if pf:
		_mark(10)
	for i in OverlayModel.MAX_ITEMS:
		var it := placer.item(_item_id(i))
		var on := it != null and it.active and it.visible and i < model.item_count and not hidden
		items[i].visible = on
		if on:
			items[i].position = it.rect.get_center()
			shown_count += 1
	if pf:
		_mark(11)
	# the ring sits ON the prop (never moved by the placer) — stepping aside from a face (Q-C1)
	if not hidden and model.rig_ring.hotspot != "":
		var p := _anchor_screen(model.rig_ring.hotspot, &"ring")
		if p.is_finite():
			var sc := ring_scale_near(p, RigRing.outer_radius() * k, faces)
			ring.visible = true
			ring.position = p
			ring.set_occluders(faces)
			ring.set_data(model.rig_ring.frac, model.rig_ring.active, k * sc)
			shown_count += 1
			loud_count += 1
		else:
			ring.clear()
	else:
		ring.clear()
	if pf:
		_mark(12)
	# tag flights (consumed once)
	for i in model.flight_count:
		var f := model.tag_flights[i]
		_start_flight(f.hotspot, f.line_index)
	model.flight_count = 0
	if pf:
		_mark(13)
		_probe_dump(model, safe)
	placer.begin_frame()
	phase_us[0] = t1 - t0
	phase_us[1] = t2 - t1
	phase_us[2] = t3 - t2
	phase_us[3] = Time.get_ticks_usec() - t3


func _mark(i: int) -> void:
	_marks[i] = Time.get_ticks_usec()


## The dev probe's line (see `PROBE_SLOW_US`; allocates — probe runs only).
func _probe_dump(model: OverlayModel, safe: Rect2) -> void:
	var fr := Engine.get_process_frames()
	var total := _marks[_MARK_NAMES.size()] - _marks[0]
	var in_win := _probe_from >= 0 and fr >= _probe_from and fr <= _probe_to
	if total < _probe_slow and not in_win:
		return
	var steps := {}
	for i in _MARK_NAMES.size():
		steps[_MARK_NAMES[i]] = _marks[i + 1] - _marks[i]
	var its := []
	for it in placer.pool():
		if not it.active:
			continue
		its.append({"id": String(it.id), "pri": it.priority, "want": _r4(it.want), "rect": _r4(it.rect),
			"anchor": [it.anchor.x, it.anchor.y] if it.anchor.is_finite() else null, "visible": it.visible,
			"faded": it.faded, "fixed": it.fixed, "side": it.side, "detach": snappedf(it.detach, 0.1),
			"prop": _r4(it.prop_rect), "alt_a": _r4(it.alt_a), "alt_b": _r4(it.alt_b)})
	var prot := []
	for r in _protected:
		if r != FAR:
			prot.append(_r4(r))
	var hard := []
	for r in _hard:
		if r != FAR:
			hard.append(_r4(r))
	var tick := -1
	if anchor_src != null and is_instance_valid(anchor_src) and anchor_src.has_method("_snap"):
		var sn: Variant = anchor_src.call("_snap")
		if sn is ViewSnapshot:
			tick = (sn as ViewSnapshot).tick
	var line := {"frame": fr, "tick": tick, "apply": apply_count, "total_us": total, "steps": steps, "items": its,
		"protected": prot, "hard": hard, "safe": _r4(safe), "k": k, "previews": model.preview_count,
		"thought": model.thought.prank, "ring": model.rig_ring.hotspot, "marker": model.safety_marker.hotspot,
		"item_bubbles": model.item_count}
	var f := FileAccess.open(_probe_path, FileAccess.READ_WRITE if FileAccess.file_exists(_probe_path) else FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(JSON.stringify(line))
		f.close()


static func _r4(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]


## Start a tag flight from `hotspot`'s projected tag socket to Script pip `line_index` (the Hud's
## `script_pip_center`, else the Script chip's corner). With a Hud attached the Hud flies it (above
## the chip); otherwise this layer does.
func _start_flight(hotspot: String, line_index: int) -> void:
	var from := _anchor_screen(hotspot, &"tag")
	if not from.is_finite():
		from = view_size() * 0.5
	if hud != null and is_instance_valid(hud) and hud.has_method("fly_tag"):
		hud.call("fly_tag", from, line_index)
		return
	var to := Vector2(260, 72) * k
	for f in flights:
		if not f.running:
			f.start(from, to, line_index)
			return


func _on_flight_arrived(_line: int) -> void:
	pass


func _pict(pv: OverlayModel.Preview) -> Texture2D:
	if pv.pictogram.is_empty() and pv.combines_badge != "":
		return null
	return PreviewArt.texture(pv.prank, pv.pictogram)


func _item_icon(item: String) -> Texture2D:
	if item == "":
		return null
	if _item_tex.has(item):
		return _item_tex[item]
	var t := UiIcons.item(item)
	_item_tex[item] = t
	return t


## The combine badge's target icon ("to_sink" → the sink tap).
func _combine_icon(badge: String) -> Texture2D:
	if badge == "":
		return null
	if _combine_tex.has(badge):
		return _combine_tex[badge]
	var p := PreviewArt.DIR + "badge_" + badge + ".svg"
	var t := UiIcons.texture(p) if FileAccess.file_exists(p) else UiIcons.get_icon(&"arrow")
	_combine_tex[badge] = t
	return t


const _PREVIEW_IDS: Array[StringName] = [&"ov_preview_0", &"ov_preview_1", &"ov_preview_2", &"ov_preview_3",
	&"ov_preview_4", &"ov_preview_5", &"ov_preview_6", &"ov_preview_7"]
const _ITEM_IDS: Array[StringName] = [&"ov_item_0", &"ov_item_1", &"ov_item_2", &"ov_item_3"]


static func _preview_id(i: int) -> StringName:
	return _PREVIEW_IDS[i]


static func _item_id(i: int) -> StringName:
	return _ITEM_IDS[i]


func _anchor_screen(hotspot: String, kind: StringName) -> Vector2:
	var v: Variant = anchor_src.call("anchor_of", hotspot, kind)
	if not (v is Vector3) or not (v as Vector3).is_finite():
		return Vector2.INF
	if anchor_src.has_method("on_screen") and not bool(anchor_src.call("on_screen", v)):
		return Vector2.INF
	var p: Variant = anchor_src.call("project", v)
	return p if p is Vector2 else Vector2.INF


func _actor_screen(actor: StringName, kind: StringName) -> Vector2:
	var v: Variant = anchor_src.call("actor_anchor", actor, kind)
	if not (v is Vector3) or not (v as Vector3).is_finite():
		return Vector2.INF
	var p: Variant = anchor_src.call("project", v)
	return p if p is Vector2 else Vector2.INF


func _build_protected(_vs: Vector2) -> void:
	var n := 0
	if anchor_src != null and is_instance_valid(anchor_src) and anchor_src.has_method("protected_rects"):
		var pr: Variant = anchor_src.call("protected_rects")
		if pr is Array:
			for r in pr:
				if r is Rect2 and n < MAX_PROTECTED:
					_protected[n] = r
					n += 1
	# WorldView3D takes the HUD's rects itself (`hud_rects`, grown by its own pad): hand them over, don't add twice
	if _src_takes_hud:
		anchor_src.set("hud_rects", hud.call("always_on_rects"))
	elif hud != null and is_instance_valid(hud) and hud.has_method("always_on_rects"):
		var hr: Variant = hud.call("always_on_rects")
		if hr is Array:
			for r in hr:
				if r is Rect2 and n < MAX_PROTECTED:
					_protected[n] = (r as Rect2).grow(HUD_PAD)
					n += 1
	for i in range(n, MAX_PROTECTED):
		_protected[i] = FAR


## His thought bubble (WorldView3D.overlays.bubble — an FxThoughtBubble), found once; null on other anchor sources.
func _his_bubble() -> CanvasItem:
	if _bubble != null and is_instance_valid(_bubble):
		return _bubble
	_bubble = null
	if not ("overlays" in anchor_src):
		return null
	var ov: Variant = anchor_src.get("overlays")
	if not (ov is Object) or not is_instance_valid(ov) or not ("bubble" in (ov as Object)):
		return null
	var b: Variant = (ov as Object).get("bubble")
	if b is CanvasItem:
		_bubble = b
		_bubble_has_ring_flag = "ring_hidden" in _bubble
	return _bubble


## `hotspot`'s prop on screen — its VISUAL bounds (WorldView3D: the Prop3D's home AABB through the camera; the hit
## box `prop_screen_rect` is padded for thumbs and reaches well above a small prop), else the source's
## prop_screen_rect, else Rect2(). Not re-projected every frame: while the camera pans the cached rect follows the
## anchor `a`; it is projected again after PROP_REFRESH frames or a jump of PROP_JUMP px (a cut, a punch-in).
func _prop_rect(hotspot: String, a: Vector2) -> Rect2:
	if not _src_has_prop_rect:
		return Rect2()
	var c: Variant = _prop_cache.get(hotspot, null)
	if c is Array:
		var ca: Array = c
		var d := a - (ca[0] as Vector2)
		if d.length_squared() < 0.25:
			return ca[1]
		if int(ca[2]) < PROP_REFRESH and d.length_squared() < PROP_JUMP * PROP_JUMP:
			var moved := Rect2((ca[1] as Rect2).position + d, (ca[1] as Rect2).size)
			ca[0] = a
			ca[1] = moved
			ca[2] = int(ca[2]) + 1
			return moved
	var r := Rect2()
	if _src_has_prop_visual:
		var pv: Variant = anchor_src.call("prop", hotspot)
		var cam: Variant = anchor_src.get("cam")
		if pv is Object and (pv as Object).has_method("home_aabb") and cam is Object \
				and (cam as Object).has_method("project_aabb"):
			var rv: Variant = (cam as Object).call("project_aabb", (pv as Object).call("home_aabb"))
			if rv is Rect2:
				r = rv
	if not r.has_area():
		var v: Variant = anchor_src.call("prop_screen_rect", hotspot)
		r = v if v is Rect2 else Rect2()
	if c is Array:
		(c as Array)[0] = a
		(c as Array)[1] = r
		(c as Array)[2] = 0
	else:
		_prop_cache[hotspot] = [a, r, 0]
	return r


## True when the chain from `c` to `tgt` would meet another shown overlay of this solve (not `own`).
func _tail_crosses(own: OverlayPlacer.Item, c: Vector2, tgt: Vector2) -> bool:
	for o in placer.pool():
		if o == own or not o.active or not o.visible:
			continue
		if o.rect.has_point(tgt) or OverlayPlacer.segment_hits_rect(c, tgt, o.rect):
			return true
	return false


## Where a preview's tail ends (pure; tests): on its prop's top edge, the point nearest the cloud centre `c` (a few px
## inside the edge), else its anchor `a`.
static func tail_target(c: Vector2, pr: Rect2, a: Vector2, kk: float) -> Vector2:
	if not pr.has_area():
		return a if a.is_finite() else c + Vector2(0.0, 60.0 * kk)
	var inset := minf(10.0 * kk, pr.size.x * 0.25)
	return Vector2(clampf(c.x, pr.position.x + inset, pr.end.x - inset), pr.position.y + minf(6.0 * kk, pr.size.y * 0.25))


## The face box of `actor` on screen (Rect2() when absent / off screen): the head anchor → head top
## span, FACE_HALF_W of it to each side, FACE_UP above the top, FACE_DOWN below the head anchor, plus
## FACE_PAD. Works on WorldView3D and on FakeAnchors (both modes).
func face_box(actor: StringName) -> Rect2:
	if anchor_src == null or not is_instance_valid(anchor_src):
		return Rect2()
	if not _actor_shown(actor):
		return Rect2()
	var hs := _actor_screen(actor, &"head")
	var ts := _actor_screen(actor, &"top")
	if not hs.is_finite() or not ts.is_finite():
		return Rect2()
	return face_rect(hs, ts, FACE_PAD * k)


## `actor` is on stage: WorldView3D — its CharacterView3D is shown and a camera projects (exactly when its
## actor_screen_rect is not empty, without projecting the AABB's 8 corners); other sources — actor_screen_rect has area.
func _actor_shown(actor: StringName) -> bool:
	if _src_has_character:
		if anchor_src.get("cam") == null:
			return false
		var cv: Variant = anchor_src.call("character", String(actor))
		return cv is Node3D and (cv as Node3D).visible
	if anchor_src.has_method("actor_screen_rect"):
		var ar: Variant = anchor_src.call("actor_screen_rect", actor)
		return ar is Rect2 and (ar as Rect2).has_area()
	return true


## A face box from the projected head anchor `hs` and head top `ts` (pure; tests).
static func face_rect(hs: Vector2, ts: Vector2, pad: float) -> Rect2:
	var span := maxf(hs.distance_to(ts), 1.0)
	var r := Rect2(hs, Vector2.ZERO).expand(ts)
	var half := span * FACE_HALF_W
	return r.grow_individual(half, span * FACE_UP, half, span * FACE_DOWN).grow(pad)


## The rig ring's scale at the prop `p` (outer radius `r`): RING_NEAR_FACE_SCALE when it would run into a
## face box (it then passes behind that face), else 1 — pure; tests.
static func ring_scale_near(p: Vector2, r: float, face_boxes: Array[Rect2]) -> float:
	for fb in face_boxes:
		if fb.has_area() and _circle_hits(p, r, fb):
			return RING_NEAR_FACE_SCALE
	return 1.0


static func _circle_hits(c: Vector2, r: float, b: Rect2) -> bool:
	var q := Vector2(clampf(c.x, b.position.x, b.end.x), clampf(c.y, b.position.y, b.end.y))
	return q.distance_squared_to(c) < r * r


## The hard keep-outs of the last apply (FAR slots excluded; allocates — tests / lints only).
func hard_now() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in _hard:
		if r != FAR:
			out.append(r)
	return out


## Face boxes + the Hud's shown transient top-band rects (+ TRANSIENT_PAD) into the hard pool.
func _build_hard(src_ok: bool) -> void:
	var n := 0
	for i in FACE_ACTORS.size():
		var fb := face_box(FACE_ACTORS[i]) if src_ok else Rect2()
		faces[i] = fb
		if fb.has_area() and n < MAX_HARD:
			_hard[n] = fb
			n += 1
	if hud != null and is_instance_valid(hud) and hud.has_method("transient_rects"):
		var tr: Variant = hud.call("transient_rects")
		if tr is Array:
			for r in tr:
				if r is Rect2 and (r as Rect2).has_area() and n < MAX_HARD:
					_hard[n] = (r as Rect2).grow(TRANSIENT_PAD * k)
					n += 1
	for i in range(n, MAX_HARD):
		_hard[i] = FAR


## The protected rects of the last apply (FAR slots excluded; allocates — tests / lints only).
func protected_now() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in _protected:
		if r != FAR:
			out.append(r)
	return out


func _safe_rect(vs: Vector2) -> Rect2:
	if anchor_src != null and is_instance_valid(anchor_src) and anchor_src.has_method("safe_rect"):
		var r: Variant = anchor_src.call("safe_rect")
		if r is Rect2 and (r as Rect2).has_area():
			return r
	return Rect2(Vector2.ZERO, vs)
