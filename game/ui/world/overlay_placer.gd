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
##   ATTACHED (r3d QA round 2, Q2-C1: a badge pushed ~200 px off its gramophone read as "which icon goes with which
##   object?"): an item with `max_detach` > 0 never lands farther than that from its prop — the STALK (the segment
##   from its `anchor`, the preview anchor above the prop, down to `anchor_to`, the prop's top) or the prop's rect
##   `prop_rect` itself (no prop rect: the anchor alone). Its spots, in order: its own; a sideways slide that keeps the anchor above it (still over its prop); the two BESIDE
##   spots the producer gives (`alt_a`, `alt_b`: left / right of the prop's top, the tail then points sideways at
##   it); any other slide / up spot within `max_detach`; else it waits. `detach` reads back the placed distance,
##   `side` where it went (0 its own spot / slid / up, −1 / +1 beside).
##   (`request_attached` takes the prop rect and derives `anchor_to` = the point of its top edge under the anchor.)
##
## Two ways to use it:
##   * pure: `OverlayPlacer.place(items, protected, safe)` over an Array of OverlayPlacer.Item;
##   * shared per frame: `begin_frame()`, every producer `request(id, priority, want)` → an Item it
##     keeps a reference to (pooled by id), then one `solve(protected, safe, hard, focus)`; read
##     `item.rect` / `item.visible` after. Items not requested this frame are skipped (and stay pooled).
##     A producer that draws a FIXED item reads its placed `rect` (the safe-rect clamp) and `visible`
##     (the one-cloud rule) back from the latest solve.
## Allocation-free once the pool is warm (no arrays are built while placing). Each item's search only looks at the
## blockers near it (`_collect`: the rects that meet its reach — one width either side, MAX_UP above, its beside
## spots), so a waiting item costs a handful of rect tests, not (protected + hard + items)² (D17 / QA 16(a)).
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
	## ATTACHED: > 0 = the most px the placed rect may lie from its stalk `anchor` → `anchor_to` (0 = anywhere the
	## slide / up rule allows). `anchor_to`: the prop's top under the anchor (INF = the anchor alone).
	var max_detach: float = 0.0
	var anchor_to: Vector2 = Vector2.INF
	var prop_rect: Rect2 = Rect2()
	## The two BESIDE spots (screen rects: left / right of the prop) tried before waiting; Rect2() = none.
	var alt_a: Rect2 = Rect2()
	var alt_b: Rect2 = Rect2()
	## out: where it goes, whether it shows this frame, whether the thought covers it (previews).
	var rect: Rect2 = Rect2()
	## out: the placed rect's distance from `anchor` (0 = touches it; INF = no anchor) and the spot kind
	## (0 its own / slid / up, −1 beside left = alt_a, +1 beside right = alt_b).
	var detach: float = 0.0
	var side: int = 0
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
	var _s_detach_max: float = 0.0
	var _s_prop_rect: Rect2 = Rect2()
	var _s_alt_a: Rect2 = Rect2()
	var _s_alt_b: Rect2 = Rect2()
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
	it.max_detach = 0.0
	it.anchor_to = Vector2.INF
	it.prop_rect = Rect2()
	it.alt_a = Rect2()
	it.alt_b = Rect2()
	it.active = true
	return it


## `request` + the ATTACHED rule: stays within `max_detach` px of `anchor`, else tries `alt_a` / `alt_b` (beside the
## prop), else waits.
func request_attached(id: StringName, priority: int, want: Rect2, anchor: Vector2, prop_rect: Rect2,
		max_detach: float, alt_a: Rect2, alt_b: Rect2, exempt_anchor: bool = false) -> Item:
	var it := request(id, priority, want, anchor, false, exempt_anchor)
	it.max_detach = max_detach
	it.prop_rect = prop_rect
	if prop_rect.has_area() and anchor.is_finite():
		it.anchor_to = Vector2(clampf(anchor.x, prop_rect.position.x, prop_rect.end.x), prop_rect.position.y)
	it.alt_a = alt_a
	it.alt_b = alt_b
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
		if not is_equal_approx(it.max_detach, it._s_detach_max) or not _near_rect(it.alt_a, it._s_alt_a) \
				or not _near_rect(it.alt_b, it._s_alt_b) or not _near_rect(it.prop_rect, it._s_prop_rect):
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
		it._s_detach_max = it.max_detach
		it._s_prop_rect = it.prop_rect
		it._s_alt_a = it.alt_a
		it._s_alt_b = it.alt_b
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


## Blockers near the item being placed (`_collect`): rects it may not touch, and rects that only fade it (Hush's
## thought over a preview). Static scratch pools, grown once, reused for every item (no per-frame allocation).
static var _nb: Array[Rect2] = []
static var _nb_n: int = 0
static var _fade: Array[Rect2] = []
static var _fade_n: int = 0


static func _place_one(i: Item, items: Array, protected: Array[Rect2], hard: Array[Rect2], safe: Rect2) -> void:
	var r := clamp_into(i.want, safe)
	i.rect = r
	i.visible = true
	i.side = 0
	i.detach = _detach(i, r)
	if i.fixed:
		return
	_collect(i, r, items, protected, hard)
	if _free_near(i, r):
		return
	var max_dx := r.size.x
	if i.max_detach > 0.0 and i.anchor.is_finite():
		# ATTACHED: a slide that keeps its anchor above it (still over its prop), then beside the prop
		var best_a := INF
		var best_ax := 0.0
		for j in _nb_n:
			var o := _nb[j]
			if not r.intersects(o):
				continue
			for k in 2:
				var cx := o.end.x + GAP if k == 0 else o.position.x - r.size.x - GAP
				var dx := absf(cx - r.position.x)
				if dx > max_dx or dx >= best_a:
					continue
				var c := clamp_into(Rect2(Vector2(cx, r.position.y), r.size), safe)
				if c.position.x <= i.anchor.x and c.end.x >= i.anchor.x and _free_near(i, c):
					best_a = dx
					best_ax = c.position.x
		if best_a < INF:
			_take(i, Rect2(Vector2(best_ax, r.position.y), r.size), 0)
			return
		for k in 2:
			var alt := i.alt_a if k == 0 else i.alt_b
			if not alt.has_area():
				continue
			var c := clamp_into(alt, safe)
			if _free_near(i, c) and _attached(i, c):
				_take(i, c, -1 if k == 0 else 1)
				return
	# 1. sideways: the nearest spot just clear of a near blocker, ≤ one width away (either side), still attached
	var best := INF
	var best_x := 0.0
	for j in _nb_n:
		var o := _nb[j]
		if not r.intersects(o):
			continue
		for k in 2:
			var cx := o.end.x + GAP if k == 0 else o.position.x - r.size.x - GAP
			var dx := absf(cx - r.position.x)
			if dx > max_dx or dx >= best:
				continue
			var c := clamp_into(Rect2(Vector2(cx, r.position.y), r.size), safe)
			if absf(c.position.x - r.position.x) <= max_dx and _free_near(i, c) and _attached(i, c):
				best = dx
				best_x = c.position.x
	if best < INF:
		_take(i, Rect2(Vector2(best_x, r.position.y), r.size), 0)
		return
	# (an ATTACHED item skips the fixed step lists: its exact spots above are the ones that keep it by its prop)
	var stepped := i.max_detach <= 0.0
	for f in SIDE_STEPS:
		if not stepped:
			break
		for sgn in SIGNS:
			var c := clamp_into(Rect2(r.position + Vector2(r.size.x * f * sgn, 0.0), r.size), safe)
			if _free_near(i, c):
				_take(i, c, 0)
				return
	# 2. up: just above a near blocker, ≤ MAX_UP, still attached
	var best_up := INF
	for j in _nb_n:
		var o := _nb[j]
		if not r.intersects(o):
			continue
		var cy := o.position.y - r.size.y - GAP
		var dy := r.position.y - cy
		if dy <= 0.0 or dy > MAX_UP or dy >= best_up or cy < safe.position.y:
			continue
		var c := Rect2(Vector2(r.position.x, cy), r.size)
		if _free_near(i, c) and _attached(i, c):
			best_up = dy
	if best_up < INF:
		_take(i, Rect2(r.position - Vector2(0.0, best_up), r.size), 0)
		return
	for up in UP_STEPS:
		if not stepped:
			break
		var c := Rect2(r.position - Vector2(0.0, up), r.size)
		if c.position.y < safe.position.y:
			break
		if _free_near(i, c):
			_take(i, c, 0)
			return
	# 3. wait
	i.visible = false
	i.faded = false


static func _take(i: Item, r: Rect2, side: int) -> void:
	i.rect = r
	i.side = side
	i.detach = _detach(i, r)
	_free_near(i, r)   # refresh `faded` for the final spot


## The distance from the stalk (`i.anchor` → `i.anchor_to`, or the anchor alone) to `r` (0 when they touch; 0 without
## an anchor) — pure.
static func _detach(i: Item, r: Rect2) -> float:
	if not i.anchor.is_finite():
		return 0.0
	if not i.anchor_to.is_finite():
		return point_rect_distance(i.anchor, r)
	var d := segment_rect_distance(i.anchor, i.anchor_to, r)
	if i.prop_rect.has_area():
		d = minf(d, rect_rect_distance(i.prop_rect, r))
	return d


## The gap between two rects (0 when they touch or overlap) — pure.
static func rect_rect_distance(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(dx * dx + dy * dy)


## Distance from the segment `a`–`b` to the rect `r` (0 when it touches or crosses it) — pure; tests and lints.
static func segment_rect_distance(a: Vector2, b: Vector2, r: Rect2) -> float:
	if segment_hits_rect(a, b, r):
		return 0.0
	var d := minf(point_rect_distance(a, r), point_rect_distance(b, r))
	for ci in 4:
		var q := Vector2(r.end.x if (ci & 1) == 1 else r.position.x, r.end.y if (ci & 2) == 2 else r.position.y)
		d = minf(d, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
	return d


## Liang–Barsky: does the segment `a`–`b` meet `r`? (no allocation: the clip window rides in a Vector2)
static func segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t := Vector2(0.0, 1.0)
	t = _clip(-d.x, a.x - r.position.x, t)
	t = _clip(d.x, r.end.x - a.x, t)
	t = _clip(-d.y, a.y - r.position.y, t)
	t = _clip(d.y, r.end.y - a.y, t)
	return t.x <= t.y


static func _clip(pp: float, qq: float, t: Vector2) -> Vector2:
	if is_zero_approx(pp):
		return t if qq >= 0.0 else Vector2(1.0, 0.0)
	var u := qq / pp
	if pp < 0.0:
		return Vector2(maxf(t.x, u), t.y)
	return Vector2(t.x, minf(t.y, u))


## Distance from `p` to the nearest point of `r` (0 inside) — pure; tests and lints.
static func point_rect_distance(p: Vector2, r: Rect2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_to(p)


static func _attached(i: Item, r: Rect2) -> bool:
	if i.max_detach <= 0.0 or not i.anchor.is_finite():
		return true
	# the cheap test first: next to the prop itself
	if i.prop_rect.has_area() and rect_rect_distance(i.prop_rect, r) <= i.max_detach + 0.01:
		return true
	return _detach(i, r) <= i.max_detach + 0.01


## Fill the near-blocker pools for `i`, whose spot starts at `r`: every protected rect (except one holding its exempt
## anchor), hard rect and placed item above it that meets its reach (one width either side, MAX_UP above, its
## beside spots); a placed thought only fades a preview.
static func _collect(i: Item, r: Rect2, items: Array, protected: Array[Rect2], hard: Array[Rect2]) -> void:
	_nb_n = 0
	_fade_n = 0
	var reach := r.grow_individual(r.size.x + GAP, MAX_UP + GAP, r.size.x + GAP, GAP)
	if i.alt_a.has_area():
		reach = reach.merge(i.alt_a)
	if i.alt_b.has_area():
		reach = reach.merge(i.alt_b)
	for p in protected:
		if not reach.intersects(p):
			continue
		if i.exempt_anchor and i.anchor.is_finite() and p.has_point(i.anchor):
			continue
		_push(p)
	for hr in hard:
		if reach.intersects(hr):
			_push(hr)
	for it in items:
		var o: Item = it
		if o == i or not o.active or not o._placed or not o.visible or not reach.intersects(o.rect):
			continue
		if i.priority == Pri.PREVIEW and o.priority == Pri.THOUGHT:
			if _fade_n >= _fade.size():
				_fade.resize(_fade_n + 8)
			_fade[_fade_n] = o.rect
			_fade_n += 1
			continue
		_push(o.rect)


static func _push(r: Rect2) -> void:
	if _nb_n >= _nb.size():
		_nb.resize(_nb_n + 16)
	_nb[_nb_n] = r
	_nb_n += 1


## True when `r` clears every near blocker (`_collect` ran for `i`); sets `i.faded` when the thought covers it.
static func _free_near(i: Item, r: Rect2) -> bool:
	for j in _nb_n:
		if r.intersects(_nb[j]):
			return false
	var covered := false
	for j in _fade_n:
		if r.intersects(_fade[j]):
			covered = true
			break
	i.faded = covered
	return true


## True when `r` clears every protected rect (except the exempt ones), every hard rect and every
## placed item above (the full scan — tests and lints; placing uses the near pools).
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
