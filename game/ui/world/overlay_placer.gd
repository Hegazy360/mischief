## OverlayPlacer — the §2.5 placement rule for every 2D thing over the 3D world (REDESIGN_3D §2.5,
## r3d-index §7.8), shared by the HUD's world overlays and `r3d-view3d`'s 2D FX.
##
##   Priority (high → low): Bellows' bubble > Hush's thought > danger markers (the safety net) >
##   passive previews > container item bubbles > the Figgis card > captions and stamps.
##   Each item is first clamped into the safe rect. A FIXED item (his bubble) is only clamped. Any
##   other item that overlaps a protected rect or a higher (or earlier, same-priority) placed item
##   slides sideways to the nearest spot just clear of a blocker (≤ its own width, either side), then
##   up just above a blocker (≤ 150 px), then WAITS
##   (`visible = false`) until a later frame has room. Passive previews may be covered by Hush's
##   thought: they stay put and are marked `faded`.
##   `exempt_anchor`: protected rects that contain the item's own anchor point do not push it (the
##   thought at her head is not pushed off by her own +48 rect).
##
## Two ways to use it:
##   * pure: `OverlayPlacer.place(items, protected, safe)` over an Array of OverlayPlacer.Item;
##   * shared per frame: `begin_frame()`, every producer `request(id, priority, want)` → an Item it
##     keeps a reference to (pooled by id), then one `solve(protected, safe)`; read `item.rect` /
##     `item.visible` after. Items not requested this frame are skipped (and stay pooled).
## Allocation-free once the pool is warm (no arrays are built while placing).
class_name OverlayPlacer
extends RefCounted

enum Pri { BUBBLE, THOUGHT, DANGER, PREVIEW, ITEM, FIGGIS, CAPTION }
const PRI_COUNT := 7
## How far an item may slide up before it waits.
const MAX_UP := 150.0
## Sideways search steps per side (fractions of the item's width, ≤ 1.0).
const SIDE_STEPS: PackedFloat32Array = [0.25, 0.5, 0.75, 1.0]
const UP_STEPS: PackedFloat32Array = [50.0, 100.0, 150.0]
const SIGNS: PackedFloat32Array = [1.0, -1.0]
## Clearance kept from a blocker when sliding.
const GAP := 8.0


## One placeable rect.
class Item:
	extends RefCounted
	var id: StringName = &""
	var priority: int = OverlayPlacer.Pri.PREVIEW
	## Where it would like to be (screen px).
	var want: Rect2 = Rect2()
	## The point it belongs to (its anchor, screen px); used by `exempt_anchor`.
	var anchor: Vector2 = Vector2.INF
	## Only clamped, never moved (Bellows' bubble).
	var fixed: bool = false
	var exempt_anchor: bool = false
	## out: where it goes, whether it shows this frame, whether the thought covers it (previews).
	var rect: Rect2 = Rect2()
	var visible: bool = true
	var faded: bool = false
	## Registered this frame (shared use); pure `place` treats every item as active.
	var active: bool = true
	var _placed: bool = false


var _pool: Array[Item] = []
var _by_id: Dictionary = {}
## The last solve's inputs (debug / lints).
var last_protected: Array[Rect2] = []
var last_safe: Rect2 = Rect2()


## Start a frame: every pooled item becomes inactive until requested again.
func begin_frame() -> void:
	for it in _pool:
		it.active = false


## Ask for a slot this frame. Returns the pooled Item for `id` (created once).
func request(id: StringName, priority: int, want: Rect2, anchor: Vector2 = Vector2.INF,
		fixed: bool = false, exempt_anchor: bool = false) -> Item:
	var it: Item = _by_id.get(id, null)
	if it == null:
		it = Item.new()
		it.id = id
		_by_id[id] = it
		_pool.append(it)
	it.priority = priority
	it.want = want
	it.anchor = anchor
	it.fixed = fixed
	it.exempt_anchor = exempt_anchor
	it.active = true
	return it


## Place every active pooled item.
func solve(protected: Array[Rect2], safe: Rect2) -> void:
	last_protected = protected
	last_safe = safe
	place(_pool, protected, safe)


## The pooled item for `id` (null when never requested).
func item(id: StringName) -> Item:
	return _by_id.get(id, null)


## Pooled items (active or not).
func items() -> Array[Item]:
	return _pool


## Pure placement (see the class doc). `items` is an Array of OverlayPlacer.Item.
static func place(items: Array, protected: Array[Rect2], safe: Rect2) -> void:
	for it in items:
		var i: Item = it
		i._placed = false
		i.faded = false
	for pri in PRI_COUNT:
		for it in items:
			var i: Item = it
			if not i.active or i.priority != pri:
				continue
			_place_one(i, items, protected, safe)
			i._placed = true


static func _place_one(i: Item, items: Array, protected: Array[Rect2], safe: Rect2) -> void:
	var r := clamp_into(i.want, safe)
	i.rect = r
	i.visible = true
	if i.fixed or _free(i, r, items, protected):
		if not i.fixed:
			_free(i, r, items, protected)   # refresh `faded` for the final spot
		return
	# 1. sideways: the nearest spot just clear of a blocker, ≤ one width away (either side)
	var max_dx := r.size.x
	var best := INF
	var best_x := 0.0
	for pass_i in 2:
		var n := protected.size() if pass_i == 0 else items.size()
		for j in n:
			var o := _blocker(i, r, items, protected, pass_i, j)
			if not o.has_area():
				continue
			for k in 2:
				var cx := o.end.x + GAP if k == 0 else o.position.x - r.size.x - GAP
				var dx := absf(cx - r.position.x)
				if dx > max_dx or dx >= best:
					continue
				var c := clamp_into(Rect2(Vector2(cx, r.position.y), r.size), safe)
				if absf(c.position.x - r.position.x) <= max_dx and _free(i, c, items, protected):
					best = dx
					best_x = c.position.x
	if best < INF:
		i.rect = Rect2(Vector2(best_x, r.position.y), r.size)
		_free(i, i.rect, items, protected)
		return
	for f in SIDE_STEPS:
		for sgn in SIGNS:
			var c := clamp_into(Rect2(r.position + Vector2(r.size.x * f * sgn, 0.0), r.size), safe)
			if _free(i, c, items, protected):
				i.rect = c
				return
	# 2. up: just above a blocker, ≤ MAX_UP
	var best_up := INF
	for pass_i in 2:
		var n := protected.size() if pass_i == 0 else items.size()
		for j in n:
			var o := _blocker(i, r, items, protected, pass_i, j)
			if not o.has_area():
				continue
			var cy := o.position.y - r.size.y - GAP
			var dy := r.position.y - cy
			if dy <= 0.0 or dy > MAX_UP or dy >= best_up or cy < safe.position.y:
				continue
			var c := Rect2(Vector2(r.position.x, cy), r.size)
			if _free(i, c, items, protected):
				best_up = dy
	if best_up < INF:
		i.rect = Rect2(r.position - Vector2(0.0, best_up), r.size)
		_free(i, i.rect, items, protected)
		return
	for up in UP_STEPS:
		var c := Rect2(r.position - Vector2(0.0, up), r.size)
		if c.position.y < safe.position.y:
			break
		if _free(i, c, items, protected):
			i.rect = c
			return
	# 3. wait
	i.visible = false


## The `j`-th protected rect (pass 0) or placed item rect (pass 1) when it blocks `r` for `i`;
## Rect2() otherwise.
static func _blocker(i: Item, r: Rect2, items: Array, protected: Array[Rect2], pass_i: int, j: int) -> Rect2:
	if pass_i == 0:
		var p := protected[j]
		if not r.intersects(p):
			return Rect2()
		if i.exempt_anchor and i.anchor.is_finite() and p.has_point(i.anchor):
			return Rect2()
		return p
	var o: Item = items[j]
	if o == i or not o.active or not o._placed or not o.visible or not r.intersects(o.rect):
		return Rect2()
	if i.priority == Pri.PREVIEW and o.priority == Pri.THOUGHT:
		return Rect2()
	return o.rect


## True when `r` clears every protected rect (except the exempt ones) and every placed item above.
static func _free(i: Item, r: Rect2, items: Array, protected: Array[Rect2]) -> bool:
	for p in protected:
		if not r.intersects(p):
			continue
		if i.exempt_anchor and i.anchor.is_finite() and p.has_point(i.anchor):
			continue
		return false
	var covered := false
	for it in items:
		var o: Item = it
		if o == i or not o.active or not o._placed or not o.visible:
			continue
		if not r.intersects(o.rect):
			continue
		if i.priority == Pri.PREVIEW and o.priority == Pri.THOUGHT:
			covered = true   # previews may sit under the thought: they fade instead
			continue
		return false
	i.faded = covered
	return true


## `r` moved (not resized) to lie inside `safe` (top-left wins when it is bigger).
static func clamp_into(r: Rect2, safe: Rect2) -> Rect2:
	var x := clampf(r.position.x, safe.position.x, maxf(safe.position.x, safe.end.x - r.size.x))
	var y := clampf(r.position.y, safe.position.y, maxf(safe.position.y, safe.end.y - r.size.y))
	return Rect2(Vector2(x, y), r.size)


## Protected rects grown by `pad` (e.g. the HUD's always-on hit rects + 48) appended to `out`.
static func append_grown(out: Array[Rect2], rects: Array[Rect2], pad: float) -> void:
	for r in rects:
		out.append(r.grow(pad))
