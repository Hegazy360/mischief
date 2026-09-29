## AtlasSet — one packed texture set built by AtlasBuilder (TECH §5.3): every image of a
## character (parts, face slots, residue overlays, props) or of a room's props in as few
## pages as possible (usually one), so a whole character draws from ONE texture and its rects
## batch into few draw calls.
##
## Layout numbers stay in 1× px: `size_1x(path)` is the art's authored size, while
## `region(path)` is the pixel rect on the page (scale × larger). Draw a part with
## `draw_texture_rect_region(set.page(path), Rect2(-pivot, set.size_1x(path)), set.region(path))`.
##
## Every page also carries three tiny built-in images for vertex-drawn geometry (rubber-hose
## limbs are textured triangle strips): `@white` (opaque), `@disc` (an anti-aliased round cap)
## and `@line` (a stroke profile: opaque in the middle, 1-texel soft edges at u = 0 and 1).
class_name AtlasSet
extends RefCounted

const WHITE := "@white"
const DISC := "@disc"
const LINE := "@line"

## The key it was built under (AtlasBuilder cache key).
var key: String = ""
## Raster scale of the pages (ART_SCALE unless built at another scale).
var scale: float = 1.0
## One texture per page.
var pages: Array[Texture2D] = []
## Page pixel sizes (same order as pages).
var page_sizes: Array[Vector2i] = []
## Paths that could not be rasterised (missing / broken files). They have no region.
var missing: PackedStringArray = PackedStringArray()
## Sum of the placed images' pixel areas (unpadded, built-ins excluded).
var used_px: int = 0
## Sum of the placed images' padded cell areas (built-ins included).
var padded_px: int = 0

var _page: Dictionary = {}     ## path → page index (built-ins: "<name>#<page>")
var _region: Dictionary = {}   ## path → Rect2 in page pixels
var _size: Dictionary = {}     ## path → Vector2 (1× px)
var _cell: Dictionary = {}     ## path → Rect2i padded cell (tests: overlap / padding checks)
var _trim: Dictionary = {}     ## path → Rect2 (1× px) of the kept pixels inside the canvas


## True when `path` was packed.
func has(path: String) -> bool:
	return _region.has(path)


## Pixel rect of `path` on its page (Rect2() when missing).
func region(path: String) -> Rect2:
	return _region.get(path, Rect2())


## The page texture holding `path` (null when missing).
func page(path: String) -> Texture2D:
	var i := page_index(path)
	return pages[i] if i >= 0 and i < pages.size() else null


## Page index of `path` (-1 when missing).
func page_index(path: String) -> int:
	return int(_page.get(path, -1))


## Authored (1×) size of `path` (Vector2.ZERO when missing).
func size_1x(path: String) -> Vector2:
	return _size.get(path, Vector2.ZERO)


## Where the packed (trimmed) pixels sit inside the authored canvas, in 1× px: draw a part
## with `Rect2(-pivot + r.position, r.size)` where `r = draw_rect(path)`. Transparent borders
## are cropped at pack time (Bellows' residue overlays share full part canvases).
func draw_rect(path: String) -> Rect2:
	return _trim.get(path, Rect2(Vector2.ZERO, size_1x(path)))


## Normalised UV rect of `path` on its page.
func uv_rect(path: String) -> Rect2:
	var i := page_index(path)
	if i < 0:
		return Rect2()
	var r: Rect2 = _region[path]
	var ps := Vector2(page_sizes[i])
	return Rect2(r.position / ps, r.size / ps)


## Region of a built-in image (WHITE / DISC / LINE) on page `page_i`.
func builtin_region(name: String, page_i: int) -> Rect2:
	return _region.get("%s#%d" % [name, page_i], Rect2())


## Normalised UV rect of a built-in image on page `page_i`, inset by half a texel so bilinear
## filtering never reads the neighbouring padding.
func builtin_uv(name: String, page_i: int) -> Rect2:
	var r := builtin_region(name, page_i)
	if r.size == Vector2.ZERO or page_i < 0 or page_i >= page_sizes.size():
		return Rect2()
	var ps := Vector2(page_sizes[page_i])
	var inset := Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE)
	return Rect2(inset.position / ps, inset.size / ps)


## Padded cell (page px) of `path` — tests check cells never overlap.
func cell(path: String) -> Rect2i:
	return _cell.get(path, Rect2i())


## Every packed path (built-ins excluded), sorted.
func paths() -> PackedStringArray:
	var out := PackedStringArray()
	for p in _region:
		if not String(p).begins_with("@"):
			out.append(String(p))
	out.sort()
	return out


## Total page area in pixels.
func page_px() -> int:
	var t := 0
	for s in page_sizes:
		t += s.x * s.y
	return t


## Packing efficiency: padded cell area / page area (0..1).
func pack_ratio() -> float:
	var t := page_px()
	return float(padded_px) / float(t) if t > 0 else 0.0


## Image efficiency: unpadded image area / page area (0..1).
func image_ratio() -> float:
	var t := page_px()
	return float(used_px) / float(t) if t > 0 else 0.0


## Internal: record one placed image (AtlasBuilder).
func _put(path: String, page_i: int, region_px: Rect2, cell_px: Rect2i, size_1x_px: Vector2, trim_1x: Rect2 = Rect2()) -> void:
	_page[path] = page_i
	_region[path] = region_px
	_cell[path] = cell_px
	_size[path] = size_1x_px
	_trim[path] = trim_1x if trim_1x.size != Vector2.ZERO else Rect2(Vector2.ZERO, size_1x_px)
