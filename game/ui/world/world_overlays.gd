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
class_name WorldOverlays
extends CanvasLayer

const LAYER := 8
## HUD always-on hit rects are protected with this margin (§2.5).
const HUD_PAD := 48.0
## The thought sits this far beside her head (px at the 1080 base).
const THOUGHT_GAP := 24.0

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

## Protected rects of this frame: a fixed pool (unused slots hold FAR, which touches nothing).
var _protected: Array[Rect2] = []
var _item_tex: Dictionary = {}
var _combine_tex: Dictionary = {}

## Capacity of the protected-rect pool (the anchor source's ~5 + the Hud's 4 + spare).
const MAX_PROTECTED := 16
const FAR := Rect2(-1.0e9, -1.0e9, 1.0, 1.0)


func _init() -> void:
	layer = LAYER
	name = "WorldOverlays"
	root = Node2D.new()
	root.name = "Root"
	add_child(root)
	_protected.resize(MAX_PROTECTED)
	_protected.fill(FAR)
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
	var vs := view_size()
	k = (vs.y / 1080.0) * UiScale.factor_for(vs)
	shown_count = 0
	loud_count = 0
	_build_protected(vs)
	var safe := _safe_rect(vs)
	var src_ok := anchor_src != null and is_instance_valid(anchor_src)
	var hidden := model.hidden or not src_ok
	# --- requests (the placer's own items)
	var tpos := Vector2.INF
	if not hidden and model.thought.hotspot != "":
		var head := _actor_screen(&"hush", &"head")
		if head.is_finite():
			var sz := thought.box_size()
			var side := float(model.thought.side)
			var c := head + Vector2(side * (sz.x * 0.5 + THOUGHT_GAP * k), -sz.y * 0.45)
			placer.request(&"ov_thought", OverlayPlacer.Pri.THOUGHT, Rect2(c - sz * 0.5, sz), head, false, true)
			tpos = head
	if not hidden and model.safety_marker.hotspot != "":
		var p := _anchor_screen(model.safety_marker.hotspot, &"eyes")
		if not p.is_finite():
			p = _anchor_screen(model.safety_marker.hotspot, &"preview")
		if p.is_finite():
			var sz := marker.box_size()
			placer.request(&"ov_marker", OverlayPlacer.Pri.DANGER, Rect2(p - sz * 0.5, sz), p)
	for i in OverlayModel.MAX_PREVIEWS:
		if hidden or i >= model.preview_count:
			continue
		var pv := model.previews[i]
		var kind := &"tag" if pv.pictogram.is_empty() and pv.combines_badge != "" else &"preview"
		var p := _anchor_screen(pv.hotspot, kind)
		if not p.is_finite():
			continue
		var node := previews[i]
		node.set_data(_pict(pv), pv.strength, _item_icon(pv.needs_item) if pv.needs_item != "" else null,
			pv.his_ring_frac, _combine_icon(pv.combines_badge) if pv.pictogram.is_empty() else null, pv.loud, k)
		var sz := node.box_size()
		var want := Rect2(p - Vector2(sz.x * 0.5, sz.y), sz)
		if kind == &"tag":
			want = Rect2(p + Vector2(24.0 * k, -sz.y * 0.5), sz)
		placer.request(_preview_id(i), OverlayPlacer.Pri.PREVIEW, want, p)
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
	placer.solve(_protected, safe)
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
	var mk := placer.item(&"ov_marker")
	marker.visible = mk != null and mk.active and mk.visible
	marker.set_process(marker.visible)
	if marker.visible:
		marker.position = mk.rect.get_center()
		marker.set_scale_k(k)
		shown_count += 1
		loud_count += 1
	for i in OverlayModel.MAX_PREVIEWS:
		var it := placer.item(_preview_id(i))
		var node := previews[i]
		var on := it != null and it.active and it.visible and i < model.preview_count and not hidden
		node.visible = on
		if on:
			var c := it.rect.get_center()
			node.position = c
			node.tail_dir = (it.anchor - c).normalized() if it.anchor.is_finite() else Vector2.DOWN
			node.modulate.a = 0.45 if it.faded else 1.0
			shown_count += 1
			if model.previews[i].loud:
				loud_count += 1
	for i in OverlayModel.MAX_ITEMS:
		var it := placer.item(_item_id(i))
		var on := it != null and it.active and it.visible and i < model.item_count and not hidden
		items[i].visible = on
		if on:
			items[i].position = it.rect.get_center()
			shown_count += 1
	# the ring sits ON the prop (never moved by the placer)
	if not hidden and model.rig_ring.hotspot != "":
		var p := _anchor_screen(model.rig_ring.hotspot, &"ring")
		if p.is_finite():
			ring.visible = true
			ring.position = p
			ring.set_data(model.rig_ring.frac, model.rig_ring.active, k)
			shown_count += 1
			loud_count += 1
		else:
			ring.clear()
	else:
		ring.clear()
	# tag flights (consumed once)
	for i in model.flight_count:
		var f := model.tag_flights[i]
		_start_flight(f.hotspot, f.line_index)
	model.flight_count = 0
	placer.begin_frame()


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
	if hud != null and is_instance_valid(hud) and hud.has_method("always_on_rects"):
		var hr: Variant = hud.call("always_on_rects")
		if hr is Array:
			for r in hr:
				if r is Rect2 and n < MAX_PROTECTED:
					_protected[n] = (r as Rect2).grow(HUD_PAD)
					n += 1
	for i in range(n, MAX_PROTECTED):
		_protected[i] = FAR


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
