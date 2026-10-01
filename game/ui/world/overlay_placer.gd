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
##   HARD rects (r3d QA Q-C1/Q-C2): keep-outs no item may cover and no anchor exempts — every
##   character's face box and the transient top-band HUD (the APPLAUSE meter, the RUNNING GAG
##   fuse) while they show. A fixed item is still only clamped (his bubble keeps below the band).
##   ONE CLOUD: the thought clouds (Pri.BUBBLE his bubble, Pri.THOUGHT Hush's thought) show one at
##   a time — the one nearest `focus` (the action: the rig point / her head); the others WAIT.
##   With no focus the higher priority wins (his bubble).
##
## Two ways to use it:
##   * pure: `OverlayPlacer.place(items, protected, safe)` over an Array of OverlayPlacer.Item;
##   * shared per frame: `begin_frame()`, every producer `request(id, priority, want)` → an Item it
##     keeps a reference to (pooled by id), then one `solve(protected, safe, hard, focus)`; read
##     `item.rect` / `item.visible` after. Items not requested this frame are skipped (and stay pooled).
##     A producer that draws a FIXED item reads its placed `rect` (the safe-rect clamp) and `visible`
##     (the one-cloud rule) back from the latest solve.
## Allocation-free once the pool is warm (no arrays are built while placing).
##
## DIRTY FLAG (r3d-fix-perf RQ2): `solve()` re-places only when an input changed since the last real
## solve — the set of active items or one's priority / fixed / exempt flag, an active item's `want` or
## `anchor` moved more than EPS px, a protected / hard rect or the safe rect moved more than EPS px, or the
## focus did. Placement is a pure function of those inputs (no history), so on a clean frame the last results
## stand; an item whose own `want` drifted (≤ EPS) follows it by that drift (re-clamped into the safe rect), so
## a slow camera pan never shows a 1 px step. `invalidate()` forces the next solve; `solves` / `placed` count
## the calls and the real solves (perf probes, tests).
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
## Dirty-flag tolerance (px): inputs that moved no more than this since the last real solve keep its results.
const EPS := 1.0


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
	## Was requested in the frame before the last begin_frame() (debug views / lints read the last solve).
	var was_active: bool = false
	var _placed: bool = false
	## The inputs of the last real solve (the dirty flag) and the rect it placed.
	var _s_active: bool = false
	var _s_priority: int = -1
	var _s_want: Rect2 = Rect2()
	var _s_anchor: Vector2 = Vector2.INF
	var _s_fixed: bool = false
	var _s_exempt: bool = false
	var _s_rect: Rect2 = Rect2()


var _pool: Array[Item] = []
var _by_id: Dictionary = {}
## The last solve's inputs (debug / lints).
var last_protected: Array[Rect2] = []
var last_hard: Array[Rect2] = []
var last_safe: Rect2 = Rect2()
var last_focus: Vector2 = Vector2.INF
## solve() calls and the ones that placed (the rest found every input unchanged — the dirty flag).
var solves: int = 0
var placed: int = 0
## Copies of the last real solve's protected / hard rects, safe rect and focus (sized once; no per-frame allocation).
var _s_protected: Array[Rect2] = []
var _s_hard: Array[Rect2] = []
var _s_safe: Rect2 = Rect2()
var _s_focus: Vector2 = Vector2.INF
var _dirty: bool = true


## Start a frame: every pooled item becomes inactive until requested again.
func begin_frame() -> void:
	for it in _pool:
		it.was_active = it.active
		it.active = false


## Every pooled item (read-only use: debug views, lints).
func pool() -> Array[Item]:
	return _pool


## Ask for a slot this frame. Returns the pooled Item for `id` (created once).
func request(id: StringName, priority: int, want: Rect2, anchor: Vector2 = Vector2.INF,
		fixed: bool = false, exempt_anchor: bool = false) -> Item:
	var it: Item = _by_id.get(id, null)
	if it == null:
		it = Item.new()
		it.id = id
		_by_id[id] = it
		_pool.append(it)
		_dirty = true
	it.priority = priority
	it.want = want
	it.anchor = anchor
	it.fixed = fixed
	it.exempt_anchor = exempt_anchor
	it.active = true
	return it


## Place every active pooled item (`hard`: the keep-outs nothing may cover; `focus`: the one-cloud
## rule's point, INF = by priority). Skipped when nothing changed since the last real solve (the dirty flag,
## see the class doc).
func solve(protected: Array[Rect2], safe: Rect2, hard: Array[Rect2] = [], focus: Vector2 = Vector2.INF) -> void:
	last_protected = protected
	last_hard = hard
	last_safe = safe
	last_focus = focus
	solves += 1
	if not _dirty and not _inputs_changed(protected, safe, hard, focus):
		# clean: the last results stand; items follow their own sub-EPS drift
		for it in _pool:
			if it.active and it.visible and not it.fixed:
				it.rect = clamp_into(Rect2(it._s_rect.position + (it.want.position - it._s_want.position), it._s_rect.size),
					safe)
			elif it.active and it.fixed:
				it.rect = clamp_into(it.want, safe)
		return
	_dirty = false
	placed += 1
	place(_pool, protected, safe, hard, focus)
	_keep_inputs(protected, safe, hard, focus)


## Force the next solve() to place (a producer whose results must be fresh, tests).
func invalidate() -> void:
	_dirty = true


## True when any input of solve() differs from the last real solve's by more than EPS (see the class doc).
func _inputs_changed(protected: Array[Rect2], safe: Rect2, hard: Array[Rect2], focus: Vector2) -> bool:
	if protected.size() != _s_protected.size() or hard.size() != _s_hard.size():
		return true
	if not _near_rect(safe, _s_safe) or not _near_point(focus, _s_focus):
		return true
	for j in protected.size():
		if not _near_rect(protected[j], _s_protected[j]):
			return true
	for j in hard.size():
		if not _near_rect(hard[j], _s_hard[j]):
			return true
	for it in _pool:
		if it.active != it._s_active:
			return true
		if not it.active:
			continue
		if it.priority != it._s_priority or it.fixed != it._s_fixed or it.exempt_anchor != it._s_exempt:
			return true
		if not _near_rect(it.want, it._s_want) or not _near_point(it.anchor, it._s_anchor):
			return true
	return false


func _keep_inputs(protected: Array[Rect2], safe: Rect2, hard: Array[Rect2], focus: Vector2) -> void:
	if _s_protected.size() != protected.size():
		_s_protected.resize(protected.size())
	for j in protected.size():
		_s_protected[j] = protected[j]
	if _s_hard.size() != hard.size():
		_s_hard.resize(hard.size())
	for j in hard.size():
		_s_hard[j] = hard[j]
	_s_safe = safe
	_s_focus = focus
	for it in _pool:
		it._s_active = it.active
		if not it.active:
			continue
		it._s_priority = it.priority
		it._s_want = it.want
		it._s_anchor = it.anchor
		it._s_fixed = it.fixed
		it._s_exempt = it.exempt_anchor
		it._s_rect = it.rect


## Within EPS on every edge (pure).
static func _near_rect(a: Rect2, b: Rect2) -> bool:
	return absf(a.position.x - b.position.x) <= EPS and absf(a.position.y - b.position.y) <= EPS \
		and absf(a.size.x - b.size.x) <= EPS and absf(a.size.y - b.size.y) <= EPS


## Within EPS (pure); INF (no point) only matches INF.
static func _near_point(a: Vector2, b: Vector2) -> bool:
	if not a.is_finite() or not b.is_finite():
		return a.is_finite() == b.is_finite()
	return absf(a.x - b.x) <= EPS and absf(a.y - b.y) <= EPS


## The pooled item for `id` (null when never requested).
func item(id: StringName) -> Item:
	return _by_id.get(id, null)


## Pooled items (active or not).
func items() -> Array[Item]:
	return _pool


## Pure placement (see the class doc). `items` is an Array of OverlayPlacer.Item; `hard` = the
## keep-outs nothing may cover (face boxes, the shown top-band HUD); `focus` = the one-cloud point.
static func place(items: Array, protected: Array[Rect2], safe: Rect2, hard: Array[Rect2] = [],
		focus: Vector2 = Vector2.INF) -> void:
	for it in items:
		var i: Item = it
		i._placed = false
		i.faded = false
	var cloud := cloud_winner(items, focus)
	for pri in PRI_COUNT:
		for it in items:
			var i: Item = it
			if not i.active or i.priority != pri:
				continue
			if is_cloud(i) and i != cloud:
				# one thought cloud at a time: the others wait (clamped, so a reader gets a sane rect)
				i.rect = clamp_into(i.want, safe)
				i.visible = false
				i._placed = true
				continue
			_place_one(i, items, protected, hard, safe)
			i._placed = true


## True for the thought clouds (his bubble, Hush's thought): one shows at a time.
static func is_cloud(i: Item) -> bool:
	return i.priority == Pri.BUBBLE or i.priority == Pri.THOUGHT


## The thought cloud that shows: the active one nearest `focus` (its anchor, else its wanted
## centre); with no focus (INF) the higher priority (his bubble). Null when none is requested.
static func cloud_winner(items: Array, focus: Vector2) -> Item:
	var best: Item = null
	var best_d := INF
	for it in items:
		var i: Item = it
		if not i.active or not is_cloud(i):
			continue
		var d := float(i.priority)
		if focus.is_finite():
			var p := i.anchor if i.anchor.is_finite() else i.want.get_center()
			d = p.distance_squared_to(focus)
		if best == null or d < best_d or (is_equal_approx(d, best_d) and i.priority < best.priority):
			best = i
			best_d = d
	return best


static func _place_one(i: Item, items: Array, protected: Array[Rect2], hard: Array[Rect2], safe: Rect2) -> void:
	var r := clamp_into(i.want, safe)
	i.rect = r
	i.visible = true
	if i.fixed or _free(i, r, items, protected, hard):
		if not i.fixed:
			_free(i, r, items, protected, hard)   # refresh `faded` for the final spot
		return
	# 1. sideways: the nearest spot just clear of a blocker, ≤ one width away (either side)
	var max_dx := r.size.x
	var best := INF
	var best_x := 0.0
	for pass_i in 3:
		for j in _pass_size(pass_i, items, protected, hard):
			var o := _blocker(i, r, items, protected, hard, pass_i, j)
			if not o.has_area():
				continue
			for k in 2:
				var cx := o.end.x + GAP if k == 0 else o.position.x - r.size.x - GAP
				var dx := absf(cx - r.position.x)
				if dx > max_dx or dx >= best:
					continue
				var c := clamp_into(Rect2(Vector2(cx, r.position.y), r.size), safe)
				if absf(c.position.x - r.position.x) <= max_dx and _free(i, c, items, protected, hard):
					best = dx
					best_x = c.position.x
	if best < INF:
		i.rect = Rect2(Vector2(best_x, r.position.y), r.size)
		_free(i, i.rect, items, protected, hard)
		return
	for f in SIDE_STEPS:
		for sgn in SIGNS:
			var c := clamp_into(Rect2(r.position + Vector2(r.size.x * f * sgn, 0.0), r.size), safe)
			if _free(i, c, items, protected, hard):
				i.rect = c
				return
	# 2. up: just above a blocker, ≤ MAX_UP
	var best_up := INF
	for pass_i in 3:
		for j in _pass_size(pass_i, items, protected, hard):
			var o := _blocker(i, r, items, protected, hard, pass_i, j)
			if not o.has_area():
				continue
			var cy := o.position.y - r.size.y - GAP
			var dy := r.position.y - cy
			if dy <= 0.0 or dy > MAX_UP or dy >= best_up or cy < safe.position.y:
				continue
			var c := Rect2(Vector2(r.position.x, cy), r.size)
			if _free(i, c, items, protected, hard):
				best_up = dy
	if best_up < INF:
		i.rect = Rect2(r.position - Vector2(0.0, best_up), r.size)
		_free(i, i.rect, items, protected, hard)
		return
	for up in UP_STEPS:
		var c := Rect2(r.position - Vector2(0.0, up), r.size)
		if c.position.y < safe.position.y:
			break
		if _free(i, c, items, protected, hard):
			i.rect = c
			return
	# 3. wait
	i.visible = false


static func _pass_size(pass_i: int, items: Array, protected: Array[Rect2], hard: Array[Rect2]) -> int:
	match pass_i:
		0:
			return protected.size()
		1:
			return items.size()
	return hard.size()


## The `j`-th protected rect (pass 0), placed item rect (pass 1) or hard rect (pass 2) when it
## blocks `r` for `i`; Rect2() otherwise.
static func _blocker(i: Item, r: Rect2, items: Array, protected: Array[Rect2], hard: Array[Rect2], pass_i: int,
		j: int) -> Rect2:
	if pass_i == 0:
		var p := protected[j]
		if not r.intersects(p):
			return Rect2()
		if i.exempt_anchor and i.anchor.is_finite() and p.has_point(i.anchor):
			return Rect2()
		return p
	if pass_i == 2:
		var hr := hard[j]
		return hr if r.intersects(hr) else Rect2()
	var o: Item = items[j]
	if o == i or not o.active or not o._placed or not o.visible or not r.intersects(o.rect):
		return Rect2()
	if i.priority == Pri.PREVIEW and o.priority == Pri.THOUGHT:
		return Rect2()
	return o.rect


## True when `r` clears every protected rect (except the exempt ones), every hard rect and every
## placed item above.
static func _free(i: Item, r: Rect2, items: Array, protected: Array[Rect2], hard: Array[Rect2] = []) -> bool:
	for p in protected:
		if not r.intersects(p):
			continue
		if i.exempt_anchor and i.anchor.is_finite() and p.has_point(i.anchor):
			continue
		return false
	for hr in hard:
		if r.intersects(hr):
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
