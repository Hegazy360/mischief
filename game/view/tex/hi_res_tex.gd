## HiResTex — sharp cutout art on a phone (TECH §5.3, port of the reference HiResTex).
## Re-rasterises an SVG from its raw source at ART_SCALE (2×) and returns an ImageTexture
## whose size is OVERRIDDEN to the 1× size, so get_size(), offsets, rigs and every layout
## number stay identical while the pixels are 2× denser.
##
##   var tex := HiResTex.get_texture("res://art/house/props/vase.svg")          # ART_SCALE
##   var tex2 := HiResTex.get_texture(path, {"#FF7A3D": "#3AA7E0"}, 1.0)        # swaps, 1×
##
## NOTE — the name: `get` cannot be a static method name in GDScript (it overrides
## Object.get: parse error), so the function is **`HiResTex.get_texture(path, swaps := {},
## scale := -1.0)`**.
##
## * scale < 0 → the innermost begin_scope() scale (a view that builds an overview at 1×
##   wraps its build in a 1× scope), else ART_SCALE (2.0; 1.5 on phones with < 3 GB RAM).
## * scale 1 with no swaps → the imported texture (load(path)).
## * Results are cached by (path, swaps, scale). A missing raw SVG (not shipped raw in an
##   export, not an .svg) falls back to load(path) (null when that does not exist either).
## * swaps = {"#RRGGBB" (upper case): "#rrggbb"} colour replacements (case-insensitive match
##   in the source).
## * warm(paths, budget_ms) pre-rasterises on WorkerThreadPool threads and finalises the
##   finished ones on the main thread within the budget; call it once per frame until it
##   returns 0 (the number of paths still not ready).
## * request(path, swaps, scale, on_ready) never blocks: it returns the ready texture, or
##   the 1× imported one now and calls on_ready(hi_res) when warm()/pump() finalises it
##   (used for big room backgrounds so a scene setup never stalls on them).
## * rasterize(path, swaps, scale) -> Image is thread-safe; AtlasBuilder uses it to fill
##   character / room atlases (one texture page per set, TECH §5.3).
## Main-thread API (textures are created on the main thread; only Image rasterisation
## runs on worker threads).
class_name HiResTex
extends RefCounted

## Re-raster scale of every art texture (1.5 on low-memory phones).
static var ART_SCALE: float = _pick_art_scale()
## Rasterise warm() jobs on worker threads (off → warm() rasterises on the main thread
## within its budget).
static var threaded: bool = OS.get_processor_count() > 1 and (OS.has_feature("threads") or not OS.has_feature("web"))
## Largest side (px) of a re-rastered image; bigger requests step the scale down.
const MAX_SIDE := 8192

## Test hook: raw sources treated as missing (as in an export without the raw copy).
static var hidden_raw: PackedStringArray = PackedStringArray()
## Paths (globs) whose rasters are **trimmed** to their inked bounds (s2-fix G #7): the room
## foreground layers are 0–5 % ink (door jambs, the slab lip) on a full-room canvas, 138 MB at 2×
## untrimmed. get_texture() then returns an AtlasTexture of the full 1× size whose `margin` places
## the trimmed pixels, so every consumer (Sprite2D, draw_texture*, get_size()) is unchanged. Trim
## paths are always rasterised (also at 1×), so the imported full canvas is never used for them.
static var trim_globs: PackedStringArray = PackedStringArray(["res://art/house/rooms/*_fg.svg"])
## Trim only when it saves at least this share of the pixels.
const TRIM_MIN_SAVING := 0.3

static var _cache: Dictionary = {}       ## key → Texture2D (final)
static var _jobs: Dictionary = {}        ## key → _Job (queued / running)
static var _scopes: Array[float] = []
static var _orphans := PackedInt64Array()   ## task ids of jobs the main thread ran itself
static var _stats := {"rasters": 0, "hits": 0, "fallbacks": 0}
## key → Engine.get_process_frames() of the last get / hit / finalise (trim's recency guard).
static var _used: Dictionary = {}


## ART_SCALE for this device: 2.0, or 1.5 when the phone reports < 3 GB of RAM.
static func _pick_art_scale() -> float:
	var mi := OS.get_memory_info()
	var phys := int(mi.get("physical", -1))
	if phys > 0 and phys < 3 * 1024 * 1024 * 1024:
		return 1.5
	return 2.0


## Scale for a view: 1.0 for overview framing / GIF clips (no mipmaps, so a 2× texture
## shrunk below 1× would alias), else ART_SCALE.
static func scale_for(overview: bool) -> float:
	return 1.0 if overview else ART_SCALE


## Default scale for get_texture() calls with scale < 0 until end_scope() (nestable).
## A view that builds an overview wraps the build in a 1× scope, so every load done during
## the build follows the overview rule without knowing about it.
static func begin_scope(scale: float) -> void:
	_scopes.append(scale if scale > 0.0 else ART_SCALE)


static func end_scope() -> void:
	if not _scopes.is_empty():
		_scopes.pop_back()


## The scale a call with `scale` resolves to.
static func resolve_scale(scale: float = -1.0) -> float:
	if scale > 0.0:
		return scale
	return _scopes[_scopes.size() - 1] if not _scopes.is_empty() else ART_SCALE


## Cache key of (path, swaps, scale). Pure.
static func cache_key(path: String, swaps: Dictionary, scale: float) -> String:
	var k := path + "|" + str(snappedf(scale, 0.001))
	if not swaps.is_empty():
		var parts := PackedStringArray()
		for s in swaps:
			parts.append(String(s).to_upper() + "=" + String(swaps[s]).to_upper())
		parts.sort()
		k += "|" + "|".join(parts)
	return k


## Texture of an SVG at `scale` (see the class doc). Blocks until it is rasterised (a warm
## job already running for it is waited for, not repeated).
static func get_texture(path: String, swaps: Dictionary = {}, scale: float = -1.0) -> Texture2D:
	var s := resolve_scale(scale)
	var k := cache_key(path, swaps, s)
	if _jobs.has(k):
		_finish(k, true)
	var hit: Variant = _cache.get(k, null)
	if hit != null:
		_stats["hits"] = int(_stats["hits"]) + 1
		_used[k] = Engine.get_process_frames()
		return hit
	var tex := _make(path, swaps, s)
	if tex != null:
		_cache[k] = tex
		_used[k] = Engine.get_process_frames()
	return tex


## Non-blocking variant: the ready texture, else the 1× imported texture now (null if
## none) and `on_ready.call(tex)` later from warm()/pump() when the hi-res one is done.
## `on_ready` is skipped when its object was freed meanwhile.
static func request(path: String, swaps: Dictionary, scale: float, on_ready: Callable) -> Texture2D:
	var s := resolve_scale(scale)
	var k := cache_key(path, swaps, s)
	var hit: Variant = _cache.get(k, null)
	if hit != null:
		_used[k] = Engine.get_process_frames()
		return hit
	if not _wants_raster(path, swaps, s):
		return get_texture(path, swaps, s)
	var job := _enqueue(k, path, swaps, s)
	if on_ready.is_valid():
		job.waiters.append(on_ready)
	return _fallback(path)


## True when (path, swaps, scale) is rasterised and cached (no pending job).
static func is_ready(path: String, swaps: Dictionary = {}, scale: float = -1.0) -> bool:
	var k := cache_key(path, swaps, resolve_scale(scale))
	return _cache.has(k) and not _jobs.has(k)


## Pre-rasterise `paths` (Strings, or {path, swaps, scale} Dictionaries) in the background
## and finalise finished ones for up to `budget_ms` of main-thread time. Call once per
## frame until it returns 0. Paths that do not exist count as done. Without threads it
## rasterises synchronously, at least one per call.
static func warm(paths: Array, budget_ms: int = 8) -> int:
	var t0 := Time.get_ticks_usec()
	var budget := budget_ms * 1000
	var did_sync := false
	for item in paths:
		var p := _item_path(item)
		var sw := _item_swaps(item)
		var s := resolve_scale(_item_scale(item))
		var k := cache_key(p, sw, s)
		if _cache.has(k) or _jobs.has(k):
			continue
		if not _wants_raster(p, sw, s):
			var t := _make(p, sw, s)
			if t != null:
				_cache[k] = t
				_used[k] = Engine.get_process_frames()
		elif threaded:
			_enqueue(k, p, sw, s)
		elif not did_sync or Time.get_ticks_usec() - t0 < budget:
			did_sync = true
			get_texture(p, sw, s)
	_pump(budget - (Time.get_ticks_usec() - t0))
	var left := 0
	for item in paths:
		var p2 := _item_path(item)
		var sw2 := _item_swaps(item)
		var s2 := resolve_scale(_item_scale(item))
		if not _wants_raster(p2, sw2, s2):
			continue
		var k2 := cache_key(p2, sw2, s2)
		if _jobs.has(k2) or not _cache.has(k2):
			left += 1
	return left


static func _item_path(item: Variant) -> String:
	return String((item as Dictionary).get("path", "")) if item is Dictionary else String(item)


static func _item_swaps(item: Variant) -> Dictionary:
	if item is Dictionary and (item as Dictionary).get("swaps", null) is Dictionary:
		return (item as Dictionary)["swaps"]
	return {}


static func _item_scale(item: Variant) -> float:
	return float((item as Dictionary).get("scale", -1.0)) if item is Dictionary else -1.0


## Finalise finished background jobs (any path) within `budget_ms`; returns jobs left.
static func pump(budget_ms: int = 4) -> int:
	_pump(budget_ms * 1000)
	return _jobs.size()


## Jobs queued or running.
static func pending_count() -> int:
	return _jobs.size()


## Drop every cached texture (waits for running jobs first).
static func clear() -> void:
	for k in _jobs.keys():
		var j: _Job = _jobs[k]
		if j.task >= 0:
			WorkerThreadPool.wait_for_task_completion(j.task)
	for t in _orphans:
		WorkerThreadPool.wait_for_task_completion(t)
	_orphans.clear()
	_jobs.clear()
	_cache.clear()
	_used.clear()


## Drop cached textures nothing else references any more (no Sprite2D / TextureRect /
## other cache holds them), except the `keep` paths. Call it before warming a new scene,
## so a long session keeps only the current scene's 2× art in memory. Returns how many were
## dropped.
## `recent_frames` > 0 also keeps whatever was fetched in the last `recent_frames` frames:
## widgets that draw a texture in `_draw()` hold no reference to it, so a screen that has
## just been built (the map's nodes, Home's art) would otherwise lose the textures its
## canvas commands still point at (they rendered as blank squares) when a trim runs right
## after its route change.
static func trim(keep: Array = [], recent_frames: int = 0) -> int:
	var keep_paths := {}
	for it in keep:
		keep_paths[_item_path(it)] = true
	var now := Engine.get_process_frames()
	var drop: Array = []
	for k in _cache:
		if _jobs.has(k):
			continue
		if recent_frames > 0 and now - int(_used.get(k, -(1 << 40))) < recent_frames:
			continue
		var tex: Variant = _cache[k]
		if not (tex is ImageTexture or tex is AtlasTexture):
			continue
		if keep_paths.has(String(k).get_slice("|", 0)):
			continue
		# References when nothing else uses it: the dictionary, the `tex` local and the cast
		# temporary = 3.
		if (tex as RefCounted).get_reference_count() <= 3:
			drop.append(k)
	for k in drop:
		_cache.erase(k)
		_used.erase(k)
	return drop.size()


## {rasters, hits, fallbacks, cached, pending} (tests / perf logs).
static func stats() -> Dictionary:
	var d := _stats.duplicate()
	d["cached"] = _cache.size()
	d["pending"] = _jobs.size()
	return d


## Colour swap on SVG source text (case-insensitive `#RRGGBB` match). Pure.
static func swap_colors(src: String, swaps: Dictionary) -> String:
	if swaps.is_empty():
		return src
	var alts := PackedStringArray()
	for k in swaps:
		alts.append(String(k).trim_prefix("#"))
	var re := RegEx.new()
	re.compile("(?i)#(" + "|".join(alts) + ")\\b")
	var out := ""
	var last := 0
	for m in re.search_all(src):
		out += src.substr(last, m.get_start() - last)
		out += String(swaps.get("#" + m.get_string(1).to_upper(), m.get_string()))
		last = m.get_end()
	out += src.substr(last)
	return out


## True when the raw SVG source is readable (exports must ship the raw .svg next to the import).
static func raw_exists(path: String) -> bool:
	return FileAccess.file_exists(path) and not hidden_raw.has(path)


## Rasterise an SVG file at `scale` (with swaps) into an Image; null on failure.
## Thread-safe (used by the worker jobs).
static func rasterize(path: String, swaps: Dictionary, scale: float) -> Image:
	if not raw_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	if not swaps.is_empty():
		bytes = swap_colors(bytes.get_string_from_utf8(), swaps).to_utf8_buffer()
	var img := Image.new()
	if img.load_svg_from_buffer(bytes, scale) != OK or img.is_empty():
		return null
	var big := maxi(img.get_width(), img.get_height())
	if big > MAX_SIDE:
		var s2 := scale * float(MAX_SIDE) / float(big) * 0.99
		img = Image.new()
		if img.load_svg_from_buffer(bytes, s2) != OK or img.is_empty():
			return null
		img.set_meta("scale", s2)
	return img


# --- internals ---------------------------------------------------------------------------

## A queued / running rasterisation.
class _Job extends RefCounted:
	var key: String
	var path: String
	var swaps: Dictionary
	var scale: float
	var task: int = -1
	var img: Image = null
	var waiters: Array[Callable] = []
	var _started := false
	var _lock := Mutex.new()

	## True for the one thread (worker or main) that gets to rasterise this job.
	func claim() -> bool:
		_lock.lock()
		var mine := not _started
		_started = true
		_lock.unlock()
		return mine

	## Worker entry: skip when the main thread already took the job (it needed it first).
	func run() -> void:
		if claim():
			img = HiResTex.rasterize(path, swaps, scale)


static func _wants_raster(path: String, swaps: Dictionary, s: float) -> bool:
	if path.get_extension().to_lower() != "svg" or not raw_exists(path):
		return false
	if wants_trim(path):
		return true
	return not (is_equal_approx(s, 1.0) and swaps.is_empty() and ResourceLoader.exists(path))


## True when `path` matches trim_globs (its raster is trimmed to its inked bounds).
static func wants_trim(path: String) -> bool:
	for g in trim_globs:
		if path.match(g):
			return true
	return false


static func _fallback(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			TexStats.track(t, "imported", path, TexStats.tex_bytes(t.get_width(), t.get_height(), false),
				TexStats.tex_bytes(t.get_width(), t.get_height(), true))
		return t
	return null


## Build the final texture now (main thread).
static func _make(path: String, swaps: Dictionary, s: float) -> Texture2D:
	if not _wants_raster(path, swaps, s):
		_stats["fallbacks"] = int(_stats["fallbacks"]) + 1
		return _fallback(path)
	return _to_texture(rasterize(path, swaps, s), s, path)


static func _to_texture(img: Image, s: float, path: String) -> Texture2D:
	if img == null:
		_stats["fallbacks"] = int(_stats["fallbacks"]) + 1
		return _fallback(path)
	var used := float(img.get_meta("scale", s))
	var base := Vector2i(maxi(1, roundi(img.get_width() / used)), maxi(1, roundi(img.get_height() / used)))
	if wants_trim(path):
		var tt := _trimmed(img, used, base, path)
		if tt != null:
			return tt
	var tex := ImageTexture.create_from_image(img)
	if base != img.get_size():
		tex.set_size_override(base)
	_stats["rasters"] = int(_stats["rasters"]) + 1
	TexStats.note_build("hires", path)
	TexStats.track_image(tex, img, "hires", path)
	return tex


## The inked bounds of `img` (+ 1 clear px for filtering), aligned so they are whole 1× px, as an
## AtlasTexture of the full 1× size `base` (null when trimming saves < TRIM_MIN_SAVING).
static func _trimmed(img: Image, used: float, base: Vector2i, path: String) -> Texture2D:
	var k := align_px(used)
	if k <= 0:
		return null
	var r := img.get_used_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		r = Rect2i(0, 0, 1, 1)
	r = r.grow(1).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var x0 := (r.position.x / k) * k
	var y0 := (r.position.y / k) * k
	var x1 := mini(img.get_width(), ((r.end.x + k - 1) / k) * k)
	var y1 := mini(img.get_height(), ((r.end.y + k - 1) / k) * k)
	var cw := x1 - x0
	var ch := y1 - y0
	if float(cw * ch) > float(img.get_width() * img.get_height()) * (1.0 - TRIM_MIN_SAVING):
		return null
	var crop := img.get_region(Rect2i(x0, y0, cw, ch))
	var inner := ImageTexture.create_from_image(crop)
	var size1 := Vector2i(maxi(1, roundi(cw / used)), maxi(1, roundi(ch / used)))
	inner.set_size_override(size1)
	var at := AtlasTexture.new()
	at.atlas = inner
	at.region = Rect2(Vector2.ZERO, Vector2(size1))
	var off := Vector2(roundf(x0 / used), roundf(y0 / used))
	at.margin = Rect2(off, (Vector2(base) - Vector2(size1)).max(Vector2.ZERO))
	_stats["rasters"] = int(_stats["rasters"]) + 1
	_stats["trimmed"] = int(_stats.get("trimmed", 0)) + 1
	TexStats.note_build("hires", path)
	TexStats.track_image(inner, crop, "hires", path)
	return at


## The pixel step at `scale` that is a whole number of 1× px (2 at 2×, 3 at 1.5×, 1 at 1×); 0
## when no step ≤ 8 is.
static func align_px(scale: float) -> int:
	for k in range(1, 9):
		var v := float(k) / scale
		if absf(v - roundf(v)) < 0.0001:
			return k
	return 0


static func _enqueue(k: String, path: String, swaps: Dictionary, s: float) -> _Job:
	var j: _Job = _jobs.get(k, null)
	if j != null:
		return j
	j = _Job.new()
	j.key = k
	j.path = path
	j.swaps = swaps.duplicate()
	j.scale = s
	_jobs[k] = j
	if threaded:
		# Bind the job as an argument: the pool's Callable then holds a strong reference, so a
		# job the main thread claimed and dropped (_finish → an orphan task) is still alive
		# when its queued worker task starts (a bare `j.run` Callable only held the object id
		# → "call 'claim' on a null instance" in the worker).
		j.task = WorkerThreadPool.add_task(_run_job.bind(j), false, "HiResTex")
	return j


## Worker entry (the job is bound, see _enqueue).
static func _run_job(j: _Job) -> void:
	j.run()


## Finalise job `k`: wait for it (or rasterise it here when it never ran), create the
## texture, cache it and call its waiters.
static func _finish(k: String, block: bool) -> bool:
	var j: _Job = _jobs.get(k, null)
	if j == null:
		return true
	if j.task >= 0:
		if not block and not WorkerThreadPool.is_task_completed(j.task):
			return false
		if block and j.claim():
			# Not started yet (queued behind other jobs): rasterise it here instead of idling;
			# the worker skips it and its task id is collected later.
			j.img = HiResTex.rasterize(j.path, j.swaps, j.scale)
			_orphans.append(j.task)
		else:
			WorkerThreadPool.wait_for_task_completion(j.task)
	else:
		j.run()
	_jobs.erase(k)
	var tex := _to_texture(j.img, j.scale, j.path)
	j.img = null
	if tex != null:
		_cache[k] = tex
		_used[k] = Engine.get_process_frames()
		for w in j.waiters:
			if w.is_valid():
				w.call(tex)
	return true


## Finalise finished jobs for up to `budget_us` of main-thread time (the first one always).
static func _pump(budget_us: int) -> void:
	if not _orphans.is_empty():
		var keep := PackedInt64Array()
		for t in _orphans:
			if WorkerThreadPool.is_task_completed(t):
				WorkerThreadPool.wait_for_task_completion(t)
			else:
				keep.append(t)
		_orphans = keep
	if _jobs.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var done_any := false
	for k in _jobs.keys():
		if done_any and (Time.get_ticks_usec() - t0 >= budget_us or not threaded):
			break
		var j: _Job = _jobs[k]
		if j.task >= 0 and not WorkerThreadPool.is_task_completed(j.task):
			continue
		_finish(k, false)
		done_any = true
