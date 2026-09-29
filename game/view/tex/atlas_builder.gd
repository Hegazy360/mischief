## AtlasBuilder — rasterises a set of SVGs (via HiResTex.rasterize) and packs them into one
## runtime atlas per character / room (TECH §5.3, GDD §9.1).
##
##   var set := AtlasBuilder.build("rig:bellows::2.00", paths)        # blocking (threads)
##   while not AtlasBuilder.warm("rig:hush:pip:2.00", paths, 4): await get_tree().process_frame
##
## * Rasterisation runs on WorkerThreadPool threads; packing, page composition and texture
##   upload run on the calling (main) thread.
## * Packer: images sorted by height (tallest first) go onto shelves; each shelf is a
##   skyline, so a shorter image fills the gap under a taller neighbour's shelf instead of
##   wasting it (a height-sorted shelf packer with skyline gap filling). Every image gets
##   PAD (2) px of padding with a 1 px edge extrude inside it (no bleeding under bilinear
##   filtering). Pages ≤ 2048² preferred, 4096² max; page sizes are trimmed to the used
##   area (multiples of 4) — the Compatibility renderer handles NPOT pages.
## * Sets are cached by key; build() with a key that exists at the same scale returns the
##   cached set.
## * All layout numbers stay in 1× px (AtlasSet.size_1x).
class_name AtlasBuilder
extends RefCounted

const PAD := 2
const EXTRUDE := 1
const PAGE_PREF := 2048
const PAGE_MAX := 4096
## Built-in images packed on every page (see AtlasSet): name → pixel size.
const BUILTINS := {"@white": Vector2i(4, 4), "@disc": Vector2i(64, 64), "@line": Vector2i(64, 4)}

## Crop transparent borders at pack time (keeps a 1 px clear margin for filtering).
static var trim: bool = true
static var _sets: Dictionary = {}    ## key → AtlasSet
static var _warm: Dictionary = {}    ## key → _Warm
static var _svg_sizes: Dictionary = {}   ## path → Vector2 (1× size from the SVG header)


## Rasterise + pack `paths` (blocking; rasterisation on worker threads). scale < 0 →
## HiResTex.resolve_scale(). Missing files are listed in AtlasSet.missing.
## `core_count` > 0: the first `core_count` paths are packed first (page 0 when they fit), so
## a character's everyday look draws from ONE page and rarely-used extras (residue overlays,
## prop states, variants) overflow onto later pages.
static func build(key: String, paths: PackedStringArray, scale: float = -1.0, swaps: Dictionary = {}, core_count: int = 0) -> AtlasSet:
	var s := HiResTex.resolve_scale(scale)
	var cached: AtlasSet = _sets.get(key, null)
	if cached != null and is_equal_approx(cached.scale, s):
		return cached
	var uniq := _unique(paths)
	var jobs := _make_jobs(uniq, swaps, s)
	if HiResTex.threaded and jobs.size() > 1:
		var gid := WorkerThreadPool.add_group_task(_run_job_i.bind(jobs), jobs.size(), -1, false, "AtlasBuilder")
		WorkerThreadPool.wait_for_group_task_completion(gid)
	else:
		for j in jobs:
			j.run()
	var set := _assemble(key, jobs, s, _core_in(uniq, paths, core_count))
	_sets[key] = set
	return set


## Non-blocking build: starts the rasterisation on worker threads on the first call and
## returns false until the set is ready; the call that finds every job done packs the pages
## and uploads them (main thread, at most once). Then get_set(key) returns it. `budget_ms`
## bounds the main-thread time of calls that rasterise synchronously (no threads).
static func warm(key: String, paths: PackedStringArray, budget_ms: int = 4, scale: float = -1.0, swaps: Dictionary = {}, core_count: int = 0) -> bool:
	var s := HiResTex.resolve_scale(scale)
	var cached: AtlasSet = _sets.get(key, null)
	if cached != null and is_equal_approx(cached.scale, s):
		return true
	var w: _Warm = _warm.get(key, null)
	if w == null:
		w = _Warm.new()
		var uniq := _unique(paths)
		w.jobs = _make_jobs(uniq, swaps, s)
		w.scale = s
		w.core = _core_in(uniq, paths, core_count)
		if HiResTex.threaded:
			for j in w.jobs:
				j.task = WorkerThreadPool.add_task(j.run, false, "AtlasBuilder")
		_warm[key] = w
	var t0 := Time.get_ticks_usec()
	var all_done := true
	var did_one := false
	for j in w.jobs:
		if j.task >= 0:
			if not WorkerThreadPool.is_task_completed(j.task):
				all_done = false
				continue
			WorkerThreadPool.wait_for_task_completion(j.task)
			j.task = -1
		elif not j.done:
			if not did_one or Time.get_ticks_usec() - t0 < budget_ms * 1000:
				j.run()
				did_one = true
			else:
				all_done = false
	if not all_done:
		return false
	_warm.erase(key)
	_sets[key] = _assemble(key, w.jobs, w.scale, w.core)
	return true


## The cached set for `key` (null until built / warmed).
static func get_set(key: String) -> AtlasSet:
	return _sets.get(key, null)


## Drop one cached set (its textures are freed once nothing references them).
static func forget(key: String) -> void:
	_sets.erase(key)


## Drop every cached set (waits for running warm jobs first).
static func clear() -> void:
	for k in _warm:
		var w: _Warm = _warm[k]
		for j in w.jobs:
			if j.task >= 0:
				WorkerThreadPool.wait_for_task_completion(j.task)
	_warm.clear()
	_sets.clear()


## Authored 1× size of an SVG from its `width`/`height` (or `viewBox`) attributes, without
## rasterising it (cached). Non-SVG images: the imported texture size. ZERO when missing.
static func svg_size(path: String) -> Vector2:
	if _svg_sizes.has(path):
		return _svg_sizes[path]
	var out := Vector2.ZERO
	if path.get_extension().to_lower() == "svg" and FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var head := f.get_buffer(mini(2048, int(f.get_length()))).get_string_from_utf8()
			out = _parse_svg_size(head)
	elif path != "" and ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			out = t.get_size()
	_svg_sizes[path] = out
	return out


## Forget cached SVG header sizes (hot reload).
static func clear_svg_sizes() -> void:
	_svg_sizes.clear()


static func _parse_svg_size(head: String) -> Vector2:
	var i := head.find("<svg")
	if i < 0:
		return Vector2.ZERO
	var j := head.find(">", i)
	var tag := head.substr(i, (j - i) if j > i else 1024)
	var re := RegEx.new()
	re.compile("\\b(width|height|viewBox)\\s*=\\s*\"([^\"]*)\"")
	var w := 0.0
	var h := 0.0
	var vb := PackedFloat64Array()
	for m in re.search_all(tag):
		var k := m.get_string(1)
		var v := m.get_string(2).strip_edges()
		if k == "width":
			w = v.to_float()
		elif k == "height":
			h = v.to_float()
		else:
			for part in v.replace(",", " ").split(" ", false):
				vb.append(part.to_float())
	if (w <= 0.0 or h <= 0.0) and vb.size() == 4:
		w = vb[2]
		h = vb[3]
	return Vector2(w, h) if w > 0.0 and h > 0.0 else Vector2.ZERO


# --- packing (pure) ----------------------------------------------------------------------

## Packs padded cells for `sizes` (pixel sizes, padding NOT included) into pages. Returns
## {"pages": Array[Vector2i] (page sizes), "place": PackedInt32Array [page, x, y] per item
## (x, y = the image's top-left inside its padded cell), "cells": PackedInt32Array
## [x, y, w, h] per item (the padded cell)}. `reserve` sizes (built-ins) are placed first on
## every page and reported under "reserved": Array (per page, PackedInt32Array [x, y] per
## reserve item). Pure (tests call it directly).
static func pack(sizes: Array[Vector2i], reserve: Array[Vector2i] = [], page_pref: int = PAGE_PREF, page_max: int = PAGE_MAX, priority: int = 0) -> Dictionary:
	var n := sizes.size()
	var all: Array[Vector2i] = sizes.duplicate()
	all.append_array(reserve)
	# Orderings tried (the height-sorted shelf order first; the densest page wins).
	var orders: Array = []
	for mode in 4:
		var o := range(n + reserve.size())
		o.sort_custom(func(a: int, b: int) -> bool:
			# Priority items (core looks, built-ins) before extras; then the ordering key.
			var pa := a < priority or a >= n
			var pb := b < priority or b >= n
			if pa != pb:
				return pa
			var ka := _order_key(all[a], mode)
			var kb := _order_key(all[b], mode)
			if ka != kb:
				return ka > kb
			if all[a].y != all[b].y:
				return all[a].y > all[b].y
			return a < b)
		orders.append(o)
	var place := PackedInt32Array()
	place.resize(n * 3)
	var cells := PackedInt32Array()
	cells.resize(n * 4)
	var pages: Array[Vector2i] = []
	var reserved: Array = []
	var left_set := {}
	for i in n:
		left_set[i] = true
	var guard := 0
	while not left_set.is_empty() and guard < 64:
		guard += 1
		var best: Dictionary = {}
		var best_score := -1.0
		for o2 in orders:
			var items: Array = []
			var big := false
			for it in o2:
				if left_set.has(it) or it >= n:
					items.append(it)
					if it < n and (sizes[it].x + 2 * PAD > page_pref or sizes[it].y + 2 * PAD > page_pref):
						big = true
			var limit := page_max if big else page_pref
			var cand := _best_page(all, [], items, limit)
			if cand.is_empty():
				continue
			var placed_n := 0
			for pk in cand["placed"]:
				if int(pk) < n:
					placed_n += 1
			var area := float((cand["size"] as Vector2i).x * (cand["size"] as Vector2i).y)
			var score := float(placed_n) * 1.0e9 - area
			if score > best_score:
				best_score = score
				best = cand
		var page_i := pages.size()
		var real_placed := 0
		if not best.is_empty():
			for pk2 in best["placed"]:
				if int(pk2) < n:
					real_placed += 1
		if best.is_empty() or real_placed == 0:
			# Nothing fits (an item larger than page_max): place it alone, clipped.
			var it2: int = left_set.keys()[0]
			left_set.erase(it2)
			place[it2 * 3] = page_i
			place[it2 * 3 + 1] = PAD
			place[it2 * 3 + 2] = PAD
			cells[it2 * 4 + 2] = sizes[it2].x + 2 * PAD
			cells[it2 * 4 + 3] = sizes[it2].y + 2 * PAD
			pages.append(Vector2i(mini(page_max, sizes[it2].x + 2 * PAD), mini(page_max, sizes[it2].y + 2 * PAD)))
			reserved.append(PackedInt32Array())
			continue
		pages.append(best["size"])
		var placed: Dictionary = best["placed"]
		var res := PackedInt32Array()
		for r_i in reserve.size():
			var rc: Variant = placed.get(n + r_i, null)
			res.append((rc as Vector2i).x if rc != null else -1)
			res.append((rc as Vector2i).y if rc != null else -1)
		reserved.append(res)
		for it in placed:
			if int(it) >= n:
				continue
			var c: Vector2i = placed[it]
			place[it * 3] = page_i
			place[it * 3 + 1] = c.x + PAD
			place[it * 3 + 2] = c.y + PAD
			cells[it * 4] = c.x
			cells[it * 4 + 1] = c.y
			cells[it * 4 + 2] = sizes[it].x + 2 * PAD
			cells[it * 4 + 3] = sizes[it].y + 2 * PAD
			left_set.erase(it)
	return {"pages": pages, "place": place, "cells": cells, "reserved": reserved}


static func _order_key(s: Vector2i, mode: int) -> int:
	match mode:
		1:
			return s.x * s.y
		2:
			return maxi(s.x, s.y)
		3:
			return s.x
	return s.y


## Tries page widths from the widest item up to `limit` and keeps the smallest page area
## (all items placed when possible, else the most area placed at width = limit).
static func _best_page(sizes: Array[Vector2i], reserve: Array[Vector2i], items: Array, limit: int) -> Dictionary:
	var min_w := 16
	var total := 0
	for it in items:
		min_w = maxi(min_w, sizes[it].x + 2 * PAD)
		total += (sizes[it].x + 2 * PAD) * (sizes[it].y + 2 * PAD)
	for r in reserve:
		min_w = maxi(min_w, r.x + 2 * PAD)
		total += (r.x + 2 * PAD) * (r.y + 2 * PAD)
	min_w = mini(_ceil_to(min_w, 4), limit)
	var max_w := mini(limit, maxi(min_w, _ceil_to(int(sqrt(float(total)) * 2.2), 4)))
	var widths: Array[int] = []
	var w := min_w
	while w <= max_w:
		widths.append(w)
		w += 16
	if widths.is_empty() or widths[widths.size() - 1] != limit:
		widths.append(limit)
	var best: Dictionary = {}
	var best_area := -1
	var best_placed := -1
	for pw in widths:
		var r := _skyline(sizes, reserve, items, pw, limit)
		var placed: Dictionary = r["placed"]
		var h: int = mini(limit, _ceil_to(int(r["height"]), 4))
		var area := pw * h
		var complete := placed.size() == items.size()
		if complete:
			if best_placed < items.size() or area < best_area or (area == best_area and absi(pw - h) < absi(best["size"].x - best["size"].y)):
				best = {"size": Vector2i(pw, h), "placed": placed, "reserved": r["reserved"]}
				best_area = area
				best_placed = placed.size()
		elif best_placed < items.size() and placed.size() > best_placed:
			best = {"size": Vector2i(pw, h), "placed": placed, "reserved": r["reserved"]}
			best_area = area
			best_placed = placed.size()
	if best.is_empty() or best_placed < items.size():
		return best
	# Refine ±16 px around the best width in 4 px steps.
	var bw: int = (best["size"] as Vector2i).x
	var fw := maxi(min_w, bw - 16)
	while fw <= mini(limit, bw + 16):
		if fw != bw:
			var r2 := _skyline(sizes, reserve, items, fw, limit)
			var placed2: Dictionary = r2["placed"]
			var h2: int = mini(limit, _ceil_to(int(r2["height"]), 4))
			if placed2.size() == items.size() and fw * h2 < best_area:
				best = {"size": Vector2i(fw, h2), "placed": placed2, "reserved": r2["reserved"]}
				best_area = fw * h2
		fw += 4
	return best


## Skyline bottom-left placement of padded cells inside `pw` × `limit`. Returns
## {"placed": {item: Vector2i}, "reserved": PackedInt32Array, "height": int}.
static func _skyline(sizes: Array[Vector2i], reserve: Array[Vector2i], items: Array, pw: int, limit: int) -> Dictionary:
	var sx := PackedInt32Array([0])     # segment x
	var sy := PackedInt32Array([0])     # segment top y (the used height under it)
	var sw := PackedInt32Array([pw])    # segment width
	var placed := {}
	var res := PackedInt32Array()
	var height := 0
	var all: Array = []
	for r_i in reserve.size():
		all.append(-1 - r_i)
	all.append_array(items)
	for it in all:
		var cw: int
		var ch: int
		if it < 0:
			cw = reserve[-1 - it].x + 2 * PAD
			ch = reserve[-1 - it].y + 2 * PAD
		else:
			cw = sizes[it].x + 2 * PAD
			ch = sizes[it].y + 2 * PAD
		var best_i := -1
		var best_y := 1 << 30
		var best_x := 0
		for i in sx.size():
			var x := sx[i]
			if x + cw > pw:
				break
			# Highest segment top under [x, x + cw).
			var y := 0
			var j := i
			var span := 0
			while span < cw and j < sx.size():
				y = maxi(y, sy[j])
				span += sw[j]
				j += 1
			if y + ch > limit:
				continue
			if y < best_y or (y == best_y and x < best_x):
				best_y = y
				best_x = x
				best_i = i
		if best_i < 0:
			if it < 0:
				res.append(-1)
				res.append(-1)
			continue
		# Insert the new segment and cut the ones it covers.
		var nx := best_x
		var ntop := best_y + ch
		var end_x := nx + cw
		var nsx := PackedInt32Array()
		var nsy := PackedInt32Array()
		var nsw := PackedInt32Array()
		var inserted := false
		for i in sx.size():
			var s0 := sx[i]
			var s1 := sx[i] + sw[i]
			if s1 <= nx or s0 >= end_x:
				if s0 >= end_x and not inserted:
					nsx.append(nx)
					nsy.append(ntop)
					nsw.append(cw)
					inserted = true
				nsx.append(s0)
				nsy.append(sy[i])
				nsw.append(sw[i])
				continue
			if s0 < nx:
				nsx.append(s0)
				nsy.append(sy[i])
				nsw.append(nx - s0)
			if not inserted:
				nsx.append(nx)
				nsy.append(ntop)
				nsw.append(cw)
				inserted = true
			if s1 > end_x:
				nsx.append(end_x)
				nsy.append(sy[i])
				nsw.append(s1 - end_x)
		if not inserted:
			nsx.append(nx)
			nsy.append(ntop)
			nsw.append(cw)
		# Merge neighbours of equal height.
		sx = PackedInt32Array()
		sy = PackedInt32Array()
		sw = PackedInt32Array()
		for i in nsx.size():
			var last := sx.size() - 1
			if last >= 0 and sy[last] == nsy[i]:
				sw[last] += nsw[i]
			else:
				sx.append(nsx[i])
				sy.append(nsy[i])
				sw.append(nsw[i])
		height = maxi(height, ntop)
		if it < 0:
			res.append(nx)
			res.append(best_y)
		else:
			placed[it] = Vector2i(nx, best_y)
	return {"placed": placed, "reserved": res, "height": height}


static func _ceil_to(v: int, m: int) -> int:
	return ((v + m - 1) / m) * m


# --- assembly --------------------------------------------------------------------------------

## One rasterisation job.
class _Job extends RefCounted:
	var path: String
	var swaps: Dictionary
	var scale: float
	var img: Image = null
	var size_1x: Vector2 = Vector2.ZERO
	var trim_px: Vector2i = Vector2i.ZERO   ## top-left of the kept pixels in the full raster
	var full_px: Vector2i = Vector2i.ZERO
	var task: int = -1
	var done: bool = false

	func run() -> void:
		if done:
			return
		img = AtlasBuilder.rasterize_one(path, swaps, scale)
		if img != null and AtlasBuilder.trim:
			full_px = img.get_size()
			var used := img.get_used_rect()
			if used.size.x <= 0 or used.size.y <= 0:
				used = Rect2i(0, 0, 1, 1)
			used = used.grow(1).intersection(Rect2i(Vector2i.ZERO, full_px))
			if used.size != full_px:
				img = img.get_region(used)
			trim_px = used.position
		elif img != null:
			full_px = img.get_size()
		done = true


## A warm() in progress.
class _Warm extends RefCounted:
	var jobs: Array = []
	var scale: float = 1.0
	var core: Dictionary = {}


static func _run_job_i(i: int, jobs: Array) -> void:
	(jobs[i] as _Job).run()


## The set of core paths (the first `core_count` of `paths`).
static func _core_in(_uniq: PackedStringArray, paths: PackedStringArray, core_count: int) -> Dictionary:
	var out := {}
	for i in mini(core_count, paths.size()):
		out[paths[i]] = true
	return out


static func _unique(paths: PackedStringArray) -> PackedStringArray:
	var seen := {}
	var out := PackedStringArray()
	for p in paths:
		if p != "" and not seen.has(p):
			seen[p] = true
			out.append(p)
	return out


static func _make_jobs(paths: PackedStringArray, swaps: Dictionary, s: float) -> Array:
	var jobs: Array = []
	for p in paths:
		var j := _Job.new()
		j.path = p
		j.swaps = swaps
		j.scale = s
		j.size_1x = svg_size(p)
		jobs.append(j)
	return jobs


## Rasterise one image at `scale` (SVG via HiResTex.rasterize; other images from their
## imported texture at 1×, then resized). Thread-safe for SVGs. The result has its alpha
## edges fixed (no dark fringes under filtering) and is RGBA8.
static func rasterize_one(path: String, swaps: Dictionary, scale: float) -> Image:
	var img: Image = null
	if path.get_extension().to_lower() == "svg":
		img = HiResTex.rasterize(path, swaps, scale)
	elif ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			img = t.get_image()
			if img != null and not is_equal_approx(scale, 1.0):
				img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.fix_alpha_edges()
	return img


static func _builtin_image(name: String) -> Image:
	var sz: Vector2i = BUILTINS[name]
	var img := Image.create_empty(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	match name:
		"@white":
			img.fill(Color.WHITE)
		"@disc":
			var c := Vector2(sz) * 0.5
			var r := float(sz.x) * 0.5 - 1.0
			for y in sz.y:
				for x in sz.x:
					var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
					img.set_pixel(x, y, Color(1, 1, 1, clampf(r - d + 0.5, 0.0, 1.0)))
		"@line":
			for x in sz.x:
				# u = 0 and 1 are the stroke edges: 1.5 texels of soft edge on each side.
				var e := minf(float(x) + 0.5, float(sz.x) - float(x) - 0.5)
				var a := clampf(e / 1.5, 0.0, 1.0)
				for y in sz.y:
					img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _assemble(key: String, jobs: Array, s: float, core: Dictionary = {}) -> AtlasSet:
	var set := AtlasSet.new()
	set.key = key
	set.scale = s
	var imgs: Array[Image] = []
	var sizes: Array[Vector2i] = []
	var job_of: Array[_Job] = []
	var n_core := 0
	# Core images first (their indices < n_core get packing priority).
	for pass_i in 2:
		for j in jobs:
			var jb: _Job = j
			if core.has(jb.path) != (pass_i == 0):
				continue
			if jb.img == null:
				if pass_i == 0 or not core.has(jb.path):
					set.missing.append(jb.path)
				continue
			imgs.append(jb.img)
			sizes.append(jb.img.get_size())
			job_of.append(jb)
			if pass_i == 0:
				n_core += 1
	var reserve: Array[Vector2i] = []
	var reserve_names: PackedStringArray = PackedStringArray()
	for bn in BUILTINS:
		reserve.append(BUILTINS[bn])
		reserve_names.append(String(bn))
	var packed := pack(sizes, reserve, PAGE_PREF, PAGE_MAX, n_core)
	var page_sizes: Array[Vector2i] = []
	page_sizes.assign(packed["pages"])
	var place: PackedInt32Array = packed["place"]
	var cells: PackedInt32Array = packed["cells"]
	var page_imgs: Array[Image] = []
	for ps in page_sizes:
		page_imgs.append(Image.create_empty(maxi(1, ps.x), maxi(1, ps.y), false, Image.FORMAT_RGBA8))
	for pi in page_sizes.size():
		var res: PackedInt32Array = (packed["reserved"] as Array)[pi]
		for ri in reserve_names.size():
			var bx := res[ri * 2]
			var by := res[ri * 2 + 1]
			if bx < 0:
				continue
			var bimg := _builtin_image(reserve_names[ri])
			var at := Vector2i(bx + PAD, by + PAD)
			_blit_extruded(page_imgs[pi], bimg, at)
			var bs := bimg.get_size()
			set._put("%s#%d" % [reserve_names[ri], pi], pi, Rect2(Vector2(at), Vector2(bs)),
				Rect2i(bx, by, bs.x + 2 * PAD, bs.y + 2 * PAD), Vector2(bs))
			set.padded_px += (bs.x + 2 * PAD) * (bs.y + 2 * PAD)
	for i in imgs.size():
		var pg := place[i * 3]
		var at2 := Vector2i(place[i * 3 + 1], place[i * 3 + 2])
		_blit_extruded(page_imgs[pg], imgs[i], at2)
		var jb2 := job_of[i]
		var used_scale := float(imgs[i].get_meta("scale", s))
		var s1 := jb2.size_1x
		if s1 == Vector2.ZERO:
			s1 = Vector2(jb2.full_px) / used_scale
		# 1× placement of the kept pixels inside the canvas (full raster px → 1× px).
		var k := Vector2(s1.x / float(maxi(1, jb2.full_px.x)), s1.y / float(maxi(1, jb2.full_px.y)))
		var trim_1x := Rect2(Vector2(jb2.trim_px) * k, Vector2(imgs[i].get_size()) * k)
		set._put(jb2.path, pg, Rect2(Vector2(at2), Vector2(imgs[i].get_size())),
			Rect2i(cells[i * 4], cells[i * 4 + 1], cells[i * 4 + 2], cells[i * 4 + 3]), s1, trim_1x)
		set.used_px += imgs[i].get_width() * imgs[i].get_height()
		set.padded_px += cells[i * 4 + 2] * cells[i * 4 + 3]
		jb2.img = null
	for pi2 in page_imgs.size():
		set.pages.append(ImageTexture.create_from_image(page_imgs[pi2]))
	set.page_sizes = page_sizes
	return set


## Blit `src` at `at` and extrude its 1 px border into the padding.
static func _blit_extruded(dst: Image, src: Image, at: Vector2i) -> void:
	var w := src.get_width()
	var h := src.get_height()
	dst.blit_rect(src, Rect2i(0, 0, w, h), at)
	if EXTRUDE <= 0:
		return
	var dw := dst.get_width()
	var dh := dst.get_height()
	if at.y - 1 >= 0:
		dst.blit_rect(src, Rect2i(0, 0, w, 1), Vector2i(at.x, at.y - 1))
	if at.y + h < dh:
		dst.blit_rect(src, Rect2i(0, h - 1, w, 1), Vector2i(at.x, at.y + h))
	if at.x - 1 >= 0:
		dst.blit_rect(src, Rect2i(0, 0, 1, h), Vector2i(at.x - 1, at.y))
	if at.x + w < dw:
		dst.blit_rect(src, Rect2i(w - 1, 0, 1, h), Vector2i(at.x + w, at.y))
	if at.x - 1 >= 0 and at.y - 1 >= 0:
		dst.set_pixel(at.x - 1, at.y - 1, src.get_pixel(0, 0))
	if at.x + w < dw and at.y - 1 >= 0:
		dst.set_pixel(at.x + w, at.y - 1, src.get_pixel(w - 1, 0))
	if at.x - 1 >= 0 and at.y + h < dh:
		dst.set_pixel(at.x - 1, at.y + h, src.get_pixel(0, h - 1))
	if at.x + w < dw and at.y + h < dh:
		dst.set_pixel(at.x + w, at.y + h, src.get_pixel(w - 1, h - 1))
