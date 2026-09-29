## HouseArt — tonight's prop and decor art packed into shared atlas pages (s2-fix G #8 / #9).
##
## One page texture holds a whole band of props instead of one texture per prop, so the house draws
## in a few batched draw calls in the main view and the PiP (38 prop + 13 decor textures → 1–3
## pages), and the SVGs are rasterised on worker threads (AtlasBuilder) instead of one at a time on
## the main thread during the NightScene build. Per-path art scales share the pages (AtlasBuilder
## `scales`): tonight's rooms at ART_SCALE or their `raster` hint, the unlit set and the outlines at
## 1×, rooms no camera can frame not at all (WorldView.room_art_scales).
##
##   HouseArt.prepare(layout, room_scales)        # WorldView._build, before the PropViews
##   var t := HouseArt.tex(path, want_scale)      # a Texture2D of the authored 1× size, or null
##
## `tex()` returns a RegionTex — a Texture2D whose get_size() is the art's authored 1× canvas and
## whose draw calls map onto its (trimmed) page region, so Sprite2D, draw_texture_rect and every
## layout number stay unchanged — only when the path was packed at `want_scale`; callers fall back
## to ViewKit / HiResTex otherwise (ViewSandbox, a room backdrop built outside a Night).
class_name HouseArt
extends RefCounted

## The prepared sets (one per room) and the per-path tables.
static var set_key: String = ""
static var _sets: Dictionary = {}       ## AtlasBuilder key → AtlasSet
static var _set_of: Dictionary = {}     ## path → its set's key
static var _scale_of: Dictionary = {}   ## path → packed art scale
static var _tex: Dictionary = {}        ## path → RegionTex


## A packed image as a Texture2D of its authored 1× size (draws its page region; trimmed borders
## stay transparent). Allocation-free after creation; draws only when the owner redraws.
class RegionTex extends Texture2D:
	var page: Texture2D = null
	## Page px of the kept (trimmed) pixels.
	var src: Rect2 = Rect2()
	## 1× rect of the kept pixels inside the authored canvas.
	var trim: Rect2 = Rect2()
	var size_1x: Vector2 = Vector2.ONE

	func _get_width() -> int:
		return maxi(1, roundi(size_1x.x))

	func _get_height() -> int:
		return maxi(1, roundi(size_1x.y))

	func _has_alpha() -> bool:
		return true

	func _is_pixel_opaque(_x: int, _y: int) -> bool:
		return true

	func _draw(ci: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
		_draw_rect_region(ci, Rect2(pos, size_1x), Rect2(Vector2.ZERO, size_1x), modulate, transpose, true)

	func _draw_rect(ci: RID, rect: Rect2, _tile: bool, modulate: Color, transpose: bool) -> void:
		_draw_rect_region(ci, rect, Rect2(Vector2.ZERO, size_1x), modulate, transpose, true)

	func _draw_rect_region(ci: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
		if page == null:
			return
		var s := src_rect if src_rect.size.x != 0.0 and src_rect.size.y != 0.0 else Rect2(Vector2.ZERO, size_1x)
		var c := s.intersection(trim)
		if c.size.x <= 0.0 or c.size.y <= 0.0 or trim.size.x <= 0.0 or trim.size.y <= 0.0:
			return
		var k := rect.size / s.size
		var dest := Rect2(rect.position + (c.position - s.position) * k, c.size * k)
		var ps := src.size / trim.size
		page.draw_rect_region(ci, dest, Rect2(src.position + (c.position - trim.position) * ps, c.size * ps), modulate, transpose, clip_uv)


## The (path → [art scale, room]) plan of tonight's props and decor. `room_scales` = WorldView's
## room_art_scales() (−1 ART_SCALE, > 0 that scale, ViewKit.NO_ART none). Pure.
static func plan(layout: HouseLayout, room_scales: Dictionary) -> Dictionary:
	var out := {}
	var art := HiResTex.ART_SCALE
	for hs in layout.hotspots:
		var rs := float(room_scales.get(hs.room, -1.0))
		if rs == ViewKit.NO_ART:
			continue
		var locked := rs > 0.0
		for k in hs.art:
			var ks := String(k)
			var p: Variant = hs.art[k]
			if not (p is String) or String(p) == "" or not String(p).ends_with(".svg"):
				continue
			if not (PropView.STATES.has(ks) or ks.begins_with("rigged_")):
				continue
			if locked and not PropView.LOCKED_STATES.has(ks):
				continue
			var sc := 1.0 if ks == "outline" or locked else (minf(hs.raster, art) if hs.raster > 0.0 else art)
			_add(out, String(p), sc, hs.room)
	for d in layout.decor:
		var ds := float(room_scales.get(d.room, -1.0))
		if ds == ViewKit.NO_ART:
			continue
		var dsc := ViewKit.LOCKED_SCALE if ds > 0.0 else (minf(d.raster, art) if d.raster > 0.0 else art)
		for k in d.art:
			var dp: Variant = d.art[k]
			if dp is String and String(dp).ends_with(".svg"):
				_add(out, String(dp), dsc, d.room)
		for f in d.frames:
			if String(f).ends_with(".svg"):
				_add(out, String(f), dsc, d.room)
	return out


static func _add(out: Dictionary, path: String, sc: float, room: String) -> void:
	var prev: Variant = out.get(path, null)
	if prev is Array:
		out[path] = [maxf(float(prev[0]), sc), String(prev[1])]
	else:
		out[path] = [sc, room]


## Pack tonight's plan (blocking; rasterised on worker threads): one set per room, so the props
## and decor a view shows side by side share a page (a page switch breaks a batch). Reuses the
## sets whose room plan did not change (retry, the next Night in the same rooms).
static func prepare(layout: HouseLayout, room_scales: Dictionary) -> void:
	var p := plan(layout, room_scales)
	var by_room := {}
	for path in p:
		var room := String(p[path][1])
		if not by_room.has(room):
			by_room[room] = []
		(by_room[room] as Array).append(path)
	var keep := {}
	_scale_of.clear()
	var todo: Array = []
	for room in by_room:
		var paths: Array = by_room[room]
		paths.sort()
		var sig := PackedStringArray()
		var pk := PackedStringArray()
		var scales := {}
		for path in paths:
			var sc := float(p[path][0])
			sig.append("%s=%s" % [path, snappedf(sc, 0.001)])
			pk.append(String(path))
			scales[path] = sc
			_scale_of[path] = sc
		var key := "house:%s:%d:%s" % [room, hash(",".join(sig)), snappedf(HiResTex.ART_SCALE, 0.01)]
		keep[key] = true
		if not _sets.has(key):
			# every room's page builds at once on worker threads (packing included)
			AtlasBuilder.start(key, pk, HiResTex.ART_SCALE, {}, 0, scales)
			todo.append([key, pk, scales])
		for path in paths:
			_set_of[path] = key
	for t in todo:
		var got := AtlasBuilder.finish(String(t[0]))
		_sets[t[0]] = got if got != null else AtlasBuilder.build(String(t[0]), t[1], HiResTex.ART_SCALE, {}, 0, t[2])
	for old in _sets.keys():
		if not keep.has(old):
			_sets.erase(old)
			AtlasBuilder.forget(old)
	for path in _set_of.keys():
		if not keep.has(_set_of[path]):
			_set_of.erase(path)
	_tex.clear()
	set_key = ",".join(PackedStringArray(keep.keys()))


## The packed texture of `path` when it was packed at `want_scale` (≤ 0 = any packed scale); null
## otherwise.
static func tex(path: String, want_scale: float = -1.0) -> Texture2D:
	var key := String(_set_of.get(path, ""))
	var set: AtlasSet = _sets.get(key, null)
	if set == null or not set.has(path):
		return null
	if want_scale > 0.0 and not is_equal_approx(float(_scale_of.get(path, -1.0)), want_scale):
		return null
	var hit: Variant = _tex.get(path, null)
	if hit != null:
		return hit
	var t := RegionTex.new()
	t.page = set.page(path)
	t.src = set.region(path)
	t.trim = set.draw_rect(path)
	t.size_1x = set.size_1x(path)
	_tex[path] = t
	return t


## The art scale PropView / DecorSet ask for: 1× for outlines and the unlit set, else the raster
## hint (≤ ART_SCALE) or ART_SCALE. Pure.
static func want_scale(raster: float, locked: bool, outline: bool = false) -> float:
	if outline or locked:
		return 1.0
	return minf(raster, HiResTex.ART_SCALE) if raster > 0.0 else HiResTex.ART_SCALE


## Forget every set (tests / hot reload).
static func clear() -> void:
	for k in _sets:
		AtlasBuilder.forget(k)
	_sets.clear()
	_set_of.clear()
	_tex.clear()
	_scale_of.clear()
	set_key = ""


## Texture memory of the packed pages in bytes.
static func memory_bytes() -> int:
	var b := 0
	for k in _sets:
		b += (_sets[k] as AtlasSet).memory_bytes()
	return b


## Pages in use (tests / perf).
static func page_count() -> int:
	var n := 0
	for k in _sets:
		n += (_sets[k] as AtlasSet).pages.size()
	return n
