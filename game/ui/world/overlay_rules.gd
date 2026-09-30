## OverlayRules — which world overlays show this frame (REDESIGN_3D §4.1, §4.4 W3/N2–N4, §4.5
## V1–V6; r3d-index §7.8). Pure and allocation-free per frame: `fill` writes into the pooled
## OverlayModel from the ViewSnapshot and the OverlayCtx.
##
##   V2  danger (entry warning, a "?" filling, a chase — and a payoff / reaction): every preview,
##       thought and item bubble hides; the safety-net marker marks the nearest free hiding spot while
##       she is exposed and not yet seen (seen → FREEZE LIVE on the button is the call); hints come
##       back DANGER_COOLDOWN_S after the last danger frame. A running rig ring stays (W2).
##   V3  hidden: nothing loud — the previews of her room faded to 30 %, no thought.
##   V5  for QUIET_AFTER_S after an action completes (a rig armed, an item taken, a dive) nothing new
##       is suggested.
##   V1  at a rig point: Hush's thought (the joke, on the side away from the prop) + the ring at the
##       prop; every other preview of the room fades to 30 %.
##   V4  otherwise the passive previews (80 %) are the menu — N2: every available (unarmed, unspent)
##       rig point of her room; armed ones show the 3D tag instead, spent ones nothing; a needs cloud
##       (the missing item's grey silhouette) once she has seen its container; an item bubble over a
##       container holding tonight's item; "his ring" on the spot his next activity will trigger; the
##       combine badge when both halves of a double act are armed.
##   N4  after IDLE_HINT_S without input the "next useful" spot's preview at full size (loud).
##   Settings `previews`: always | idle_6s (passive previews only after 6 s idle) | off (none; the
##       thought, the ring and the marker stay).
##   V6  ≤ 6 overlays, ≤ 2 loud: item bubbles drop first, then the previews farthest from Hush.
class_name OverlayRules
extends RefCounted

const QUIET_AFTER_S := 1.0
const DANGER_COOLDOWN_S := 1.0
const IDLE_HINT_S := 6.0
## The N4 preview's scale (112 × 90 → 151 × 122: ≥ 150 px, loud).
const LOUD_SCALE := 1.35


## Fill `model` for this frame (see the class doc).
static func fill(model: OverlayModel, snap: ViewSnapshot, ctx: OverlayCtx) -> void:
	model.clear()
	if snap == null or ctx == null:
		return
	var h := snap.hush
	var room := h.room
	var hidden := h.state == "HIDDEN" or h.state == "DIVING" or h.hidden_spot != ""
	_track(snap, ctx, hidden)
	if ctx.hide_all or not h.present or snap.ended:
		model.hidden = true
		return
	var at := _at_hotspot(snap, ctx)
	var rigging := h.state == "RIGGING"
	# the ring at the prop: while she holds, or partial after a release (W2)
	if at != "" and rigging:
		model.rig_ring.hotspot = at
		model.rig_ring.frac = clampf(float(h.rig_pm) / 1000.0, 0.0, 1.0)
		model.rig_ring.active = true
	elif at != "" and ctx.partial_pm.has(at) and not _armed(snap, at):
		model.rig_ring.hotspot = at
		model.rig_ring.frac = clampf(float(ctx.partial_pm[at]) / 1000.0, 0.0, 1.0)
	# V2: danger is sacred
	var threat := ctx.entry_warning or ctx.spot_filling or ctx.chase or _snap_threat(snap)
	var payoff := ctx.reaction or snap.bellows.reacting
	if threat or payoff:
		ctx.danger_until_s = ctx.now_s + DANGER_COOLDOWN_S
		var seen := ctx.spot_filling or (snap.bellows.spot_pct > 0.0 and snap.bellows.room == room)
		if threat and not hidden and not seen:
			model.safety_marker.hotspot = _nearest_free_hide(snap, ctx, room)
		return
	if ctx.now_s < ctx.danger_until_s:
		return
	# V5: the consequence gets the screen
	if ctx.now_s < ctx.quiet_until_s:
		return
	var rigs := ctx.rigs_in(room)
	var passive_ok := ctx.previews_mode == OverlayCtx.MODE_ALWAYS \
		or (ctx.previews_mode == OverlayCtx.MODE_IDLE and ctx.idle_s >= IDLE_HINT_S)
	var n4 := ctx.idle_s >= IDLE_HINT_S and ctx.next_useful != "" and ctx.previews_mode != OverlayCtx.MODE_OFF
	# V1: at a rig point — the thought, the other previews faded
	var at_rig := at != "" and not hidden and not h.moving and _available(snap, at)
	if at_rig:
		var prank := _prank_at(snap, ctx, at)
		model.thought.hotspot = at
		model.thought.prank = prank
		model.thought.pictogram = _pict(ctx, prank)
		model.thought.side = _side_away(h.x, float(ctx.hotspot_cx.get(at, h.x)))
	for hs in rigs:
		if hs == at and at_rig:
			continue
		if not _available(snap, hs):
			if ctx.previews_mode != OverlayCtx.MODE_OFF and not hidden:
				_combine_badge(model, snap, ctx, hs)
			continue
		var is_n4 := n4 and hs == ctx.next_useful and not at_rig and not hidden
		if not passive_ok and not is_n4:
			continue
		if ctx.previews_mode == OverlayCtx.MODE_OFF:
			continue
		var p := model.add_preview()
		if p == null:
			break
		var prank := _prank_at(snap, ctx, hs)
		p.hotspot = hs
		p.prank = prank
		p.pictogram = _pict(ctx, prank)
		p.strength = OverlayModel.STRENGTH_FADED if (at_rig or hidden) else OverlayModel.STRENGTH_PASSIVE
		if is_n4:
			p.strength = OverlayModel.STRENGTH_FULL
			p.loud = true
		var need := String(ctx.prank_needs.get(prank, ""))
		if need != "" and not h.carrying.has(need) and ctx.seen_containers.has(String(ctx.item_source.get(need, ""))):
			p.needs_item = need
		# his ring: his next activity will trigger this spot
		var trig: PackedStringArray = ctx.trig_hotspots.get(snap.bubble_next, OverlayCtx._EMPTY)
		if snap.bubble_ring_ticks >= 0 and trig.has(hs):
			p.his_ring_ticks = snap.bubble_ring_ticks
			p.his_ring_frac = clampf(float(snap.bubble_ring_ticks) / float(maxi(1, ctx.ring_peak)), 0.0, 1.0)
	# item bubbles over containers holding tonight's item (not while hidden or at a rig point)
	if not hidden and not at_rig:
		for c in ctx.containers_in(room):
			var st: Variant = snap.hotspots.get(c, null)
			if not (st is Dictionary):
				continue
			var stock: Variant = (st as Dictionary).get("stock", [])
			if not (stock is Array or stock is PackedStringArray):
				continue
			for it in stock:
				var item := String(it)
				if ctx.tonight_items.has(item) and not h.carrying.has(item) and _item_still_needed(snap, ctx, item):
					model.add_item_bubble(c, item)
					break
	_cap(model, snap, ctx)


# --- helpers ----------------------------------------------------------------------------------

## The pictogram ids of `prank` (cached in prepare; the lookup never allocates).
static func _pict(ctx: OverlayCtx, prank: String) -> PackedStringArray:
	if ctx.pictograms.has(prank):
		return ctx.pictograms[prank]
	return OverlayCtx._EMPTY

## Memory: containers seen, partial rings, the V5 window, his ring's peak.
static func _track(snap: ViewSnapshot, ctx: OverlayCtx, hidden: bool) -> void:
	var h := snap.hush
	for c in ctx.containers_in(h.room):
		ctx.seen_containers[c] = true
	if h.state == "RIGGING":
		var at := _at_hotspot(snap, ctx)
		if at != "":
			ctx.partial_pm[at] = h.rig_pm
	var armed := 0
	for hs in ctx.rig_pranks:
		if _armed(snap, hs):
			armed += 1
			if ctx.partial_pm.has(hs):
				ctx.partial_pm.erase(hs)
	var carry := h.carrying.size()
	if ctx.prev_armed >= 0 and (armed > ctx.prev_armed or carry > ctx.prev_carry or (hidden and not ctx.prev_hidden)):
		ctx.quiet_until_s = ctx.now_s + QUIET_AFTER_S
	ctx.prev_armed = armed
	ctx.prev_carry = carry
	ctx.prev_hidden = hidden
	if snap.bubble_next != ctx.prev_ring_next:
		ctx.prev_ring_next = snap.bubble_next
		ctx.ring_peak = 1
	ctx.ring_peak = maxi(ctx.ring_peak, snap.bubble_ring_ticks)


## The rig point Hush stands at: ctx.at_hotspot, else the action context's prank, else the prank
## she is rigging (snapshot).
static func _at_hotspot(snap: ViewSnapshot, ctx: OverlayCtx) -> String:
	if ctx.at_hotspot != "":
		return ctx.at_hotspot
	var pr := String(ctx.action.get("prank", ""))
	if pr != "":
		return String(ctx.prank_hotspot.get(pr, ""))
	if snap.hush.rig_prank != "":
		return String(ctx.prank_hotspot.get(snap.hush.rig_prank, ""))
	return ""


## The prank a rig point offers now: the one being rigged / in the action context, else the first
## of tonight's pranks there.
static func _prank_at(snap: ViewSnapshot, ctx: OverlayCtx, hs: String) -> String:
	var pr := String(ctx.action.get("prank", ""))
	if pr != "" and ctx.prank_hotspot.get(pr, "") == hs:
		return pr
	if snap.hush.rig_prank != "" and ctx.prank_hotspot.get(snap.hush.rig_prank, "") == hs:
		return snap.hush.rig_prank
	var list: PackedStringArray = ctx.rig_pranks.get(hs, OverlayCtx._EMPTY)
	return list[0] if not list.is_empty() else ""


## Available = the sim lists it enabled, not rigged, not spent (N2).
static func _available(snap: ViewSnapshot, hs: String) -> bool:
	var st: Variant = snap.hotspots.get(hs, null)
	if not (st is Dictionary):
		return true   # no state yet (first frames): assume available
	var d: Dictionary = st
	return bool(d.get("enabled", true)) and not bool(d.get("rigged", false)) and not bool(d.get("spent", false))


static func _armed(snap: ViewSnapshot, hs: String) -> bool:
	var st: Variant = snap.hotspots.get(hs, null)
	return st is Dictionary and bool((st as Dictionary).get("rigged", false))


## An item is still worth showing while some unarmed, unspent rig point of tonight needs it.
static func _item_still_needed(snap: ViewSnapshot, ctx: OverlayCtx, item: String) -> bool:
	for pr in ctx.prank_needs:
		if ctx.prank_needs[pr] == item and _available(snap, String(ctx.prank_hotspot.get(pr, ""))):
			return true
	return false


## Snapshot signs of danger: he is chasing, or a "?" fills on her in her room.
static func _snap_threat(snap: ViewSnapshot) -> bool:
	var b := snap.bellows
	if b.state == "CHASE" or b.state == "SPOTTED":
		return true
	return b.room == snap.hush.room and b.spot_pct > 0.0


## The nearest free live hiding spot in `room` to Hush ("" = none).
static func _nearest_free_hide(snap: ViewSnapshot, ctx: OverlayCtx, room: String) -> String:
	var best := ""
	var best_d := INF
	for hs in ctx.hides_in(room):
		var st: Variant = snap.hotspots.get(hs, null)
		if st is Dictionary and (bool((st as Dictionary).get("occupant", false)) or not bool((st as Dictionary).get("enabled", true))):
			continue
		var d := absf(float(ctx.hotspot_x.get(hs, 0.0)) - snap.hush.x)
		if d < best_d:
			best_d = d
			best = hs
	return best


## The thought sits on the side of her head away from the prop.
static func _side_away(hush_x: float, prop_x: float) -> int:
	if absf(hush_x - prop_x) < 1.0:
		return 1
	return 1 if hush_x > prop_x else -1


## HOT & COLD: both halves armed → a small badge by the first half's tag.
static func _combine_badge(model: OverlayModel, snap: ViewSnapshot, ctx: OverlayCtx, hs: String) -> void:
	if not _armed(snap, hs):
		return
	var list: PackedStringArray = ctx.rig_pranks.get(hs, OverlayCtx._EMPTY)
	for pr in list:
		var cb: Variant = ctx.combines.get(pr, null)
		if not (cb is Array):
			continue
		for e in cb:
			if not (e is Dictionary):
				continue
			var other := String((e as Dictionary).get("with", ""))
			var ohs := String(ctx.prank_hotspot.get(other, ""))
			if ohs != "" and _armed(snap, ohs):
				var p := model.add_preview()
				if p == null:
					return
				p.hotspot = hs
				p.prank = pr
				p.pictogram = OverlayCtx._EMPTY
				p.strength = OverlayModel.STRENGTH_FULL
				p.combines_badge = String((e as Dictionary).get("badge", ""))
				return


## V6: ≤ MAX_ON_SCREEN overlays, ≤ MAX_LOUD loud. Item bubbles go first, then the previews farthest
## from Hush (swap-remove; the pools keep their objects).
static func _cap(model: OverlayModel, snap: ViewSnapshot, ctx: OverlayCtx) -> void:
	while model.overlay_count() > OverlayModel.MAX_ON_SCREEN and model.item_count > 0:
		model.item_count -= 1
	while model.overlay_count() > OverlayModel.MAX_ON_SCREEN and model.preview_count > 0:
		_drop_farthest_preview(model, snap, ctx, false)
	while model.loud_count() > OverlayModel.MAX_LOUD and _drop_farthest_preview(model, snap, ctx, true):
		pass


static func _drop_farthest_preview(model: OverlayModel, snap: ViewSnapshot, ctx: OverlayCtx, loud_only: bool) -> bool:
	var worst := -1
	var worst_d := -1.0
	for i in model.preview_count:
		var p := model.previews[i]
		if loud_only and not p.loud:
			continue
		var d := absf(float(ctx.hotspot_x.get(p.hotspot, 0.0)) - snap.hush.x)
		if d > worst_d:
			worst_d = d
			worst = i
	if worst < 0:
		return false
	if loud_only:
		# a loud preview is demoted, not dropped
		model.previews[worst].loud = false
		model.previews[worst].strength = OverlayModel.STRENGTH_PASSIVE
		return true
	var last := model.preview_count - 1
	if worst != last:
		var tmp := model.previews[worst]
		model.previews[worst] = model.previews[last]
		model.previews[last] = tmp
	model.preview_count -= 1
	return true
