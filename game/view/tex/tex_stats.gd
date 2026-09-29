## TexStats — counts every texture page the game builds at runtime (s2-rig §4.3), so the e2e
## can prove 0 pages are built during PLAY (pre-gate row 15): AtlasBuilder (one per atlas
## page: rigs, rooms, look pages), RigPlayer's lazy look pages, HiResTex rasters and
## `s2-view`'s lazy FX textures all call `note_build(kind)`. Static; no Nodes.
##   TexStats.reset()                  # at curtain rise
##   … play …
##   assert TexStats.pages_built() == 0
## Kinds used: "atlas" (an AtlasBuilder page), "look" (a lazy residue look page: also
## counted as "atlas"), "hires" (a HiResTex raster), "fx" (view).
##
## **Memory** (s2-fix G #7): every runtime texture is also `track()`ed with its GPU bytes
## (w × h × 4, + ⅓ with mipmaps) under a *memory kind* derived from its label — `room`
## (room bg / fg), `house` (props, decor, stage), `rig` (a character's base atlas), `look`
## (look pages), `fx`, `ui`, `chars` (loose character rasters), `other`. The entries are weak,
## so a freed texture stops counting. `memory_report(root)` adds the SubViewports (PiP, Gag
## Reel, Busted Cam: w × h × 4 each) and the engine's RENDER_TEXTURE_MEM_USED total; what is
## left is `untracked` (imported textures, fonts, the window). The DebugOverlay, the device log
## and `DevShot --tex-report` print it.
class_name TexStats
extends RefCounted

static var _total: int = 0
static var _by_kind: Dictionary = {}
static var _last: Array = []   ## the last 16 {kind, label, frame}
static var _live: Array = []   ## [WeakRef, mem kind, label, bytes] per tracked texture
static var _built_bytes: Dictionary = {}   ## mem kind → bytes built since reset()
static var _ids: Dictionary = {}   ## instance ids of the tracked textures (each counted once)


## Pages / textures built since the last reset().
static func pages_built() -> int:
	return _total


## Count one texture page of `kind` ("atlas", "look", "hires", "fx", …); `label` names it
## (the atlas key or path) for the device log.
static func note_build(kind: String, label: String = "") -> void:
	_total += 1
	_by_kind[kind] = int(_by_kind.get(kind, 0)) + 1
	_last.append({"kind": kind, "label": label, "frame": Engine.get_process_frames()})
	if _last.size() > 16:
		_last.pop_front()


## Builds of one kind since the last reset().
static func built(kind: String) -> int:
	return int(_by_kind.get(kind, 0))


## {kind: count} since the last reset() (a copy).
static func by_kind() -> Dictionary:
	return _by_kind.duplicate()


## The most recent builds (≤ 16): [{kind, label, frame}] — what the device log prints when
## a page was built during PLAY.
static func recent() -> Array:
	return _last.duplicate(true)


## Start counting from zero (curtain rise; tests). Tracked live textures stay tracked.
static func reset() -> void:
	_total = 0
	_by_kind.clear()
	_last.clear()
	_built_bytes.clear()


# --- memory ------------------------------------------------------------------------------------

## GPU bytes of an RGBA8 texture of `w` × `h` (+ ⅓ for a mip chain). Pure.
static func tex_bytes(w: int, h: int, mipmaps: bool = false) -> int:
	var b := maxi(0, w) * maxi(0, h) * 4
	return b + b / 3 if mipmaps else b


## The memory kind of a texture from its build kind and label (atlas key or res:// path). Pure.
static func mem_kind(kind: String, label: String) -> String:
	if kind == "look" or label.contains(":look:"):
		return "look"
	if label.begins_with("rig:"):
		return "rig"
	if label.begins_with("room:") or label.begins_with("res://art/house/rooms/"):
		return "room"
	if label.begins_with("res://art/house/") or label.begins_with("house:"):
		return "house"
	if label.begins_with("res://art/fx/") or kind == "fx":
		return "fx"
	if label.begins_with("res://art/ui/") or label.begins_with("res://ui/") or label.begins_with("res://art/icons/"):
		return "ui"
	if label.begins_with("res://art/chars/"):
		return "chars"
	return "other"


## Track a runtime texture's memory (weakly: it stops counting once freed). `bytes` = its GPU
## size — pass `tex_bytes(img w, img h, mipmaps)` of the uploaded Image: a HiResTex texture's
## get_size() is overridden to 1×, so the texture itself cannot tell.
## `engine_bytes` (< 0: = bytes) = what RENDER_TEXTURE_MEM_USED adds for it (see track_image).
static func track(tex: Texture2D, kind: String, label: String, bytes: int, engine_bytes: int = -1) -> void:
	if tex == null or _ids.has(tex.get_instance_id()):
		return
	_ids[tex.get_instance_id()] = true
	var mk := mem_kind(kind, label)
	_live.append([weakref(tex), mk, label, bytes, engine_bytes if engine_bytes >= 0 else bytes])
	_built_bytes[mk] = int(_built_bytes.get(mk, 0)) + bytes
	if _live.size() % 256 == 0:
		_prune()


## Track an ImageTexture made from `img`: its real size (w × h × 4, + ⅓ when the image carries a
## mip chain) and what the engine's RENDER_TEXTURE_MEM_USED adds, which on the Compatibility
## renderer always includes a full mip chain (Godot 4.7 GLES3 sizes `total_data_size` with the
## mipmap flag set for every 2D texture — measured: a 1024² RGBA8 ImageTexture without mipmaps adds
## 5.33 MB to the counter while glTexImage2D uploads 4 MB). Mip-less textures therefore cost ¾ of
## what the counter says.
static func track_image(tex: Texture2D, img: Image, kind: String, label: String) -> void:
	if img == null:
		return
	track(tex, kind, label, tex_bytes(img.get_width(), img.get_height(), img.has_mipmaps()),
		tex_bytes(img.get_width(), img.get_height(), true))


## Sum of the engine-counter bytes of the tracked textures still alive.
static func live_engine_bytes() -> int:
	_prune()
	var b := 0
	for e in _live:
		b += int(e[4])
	return b


static func _prune() -> void:
	var keep: Array = []
	_ids.clear()
	for e in _live:
		var o: Object = (e[0] as WeakRef).get_ref()
		if o != null:
			keep.append(e)
			_ids[o.get_instance_id()] = true
	_live = keep


## {mem kind: bytes} of the tracked textures still alive.
static func live_bytes_by_kind() -> Dictionary:
	_prune()
	var out := {}
	for e in _live:
		out[e[1]] = int(out.get(e[1], 0)) + int(e[3])
	return out


## {mem kind: bytes} built since the last reset() (freed ones included).
static func built_bytes_by_kind() -> Dictionary:
	return _built_bytes.duplicate()


## The `n` biggest live tracked textures: [{kind, label, mb}].
static func biggest(n: int = 8) -> Array:
	_prune()
	var rows := _live.duplicate()
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[3]) > int(b[3]))
	var out: Array = []
	for i in mini(n, rows.size()):
		out.append({"kind": rows[i][1], "label": rows[i][2], "mb": snappedf(float(rows[i][3]) / 1048576.0, 0.01)})
	return out


## Textures that nodes under `root` show (`texture` properties) but nobody tracked — imported
## textures loaded with load(), mostly: [{label, px, mb}], biggest first (a debugging aid for
## `--tex-report`: it reads each texture's image, so never call it per frame).
static func scan_untracked(root: Node, n: int = 12) -> Array:
	_prune()
	var known := {}
	for e in _live:
		var o: Object = (e[0] as WeakRef).get_ref()
		if o != null:
			known[o.get_instance_id()] = true
	var seen := {}
	_scan(root, known, seen)
	var rows: Array = seen.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["mb"]) > float(b["mb"]))
	return rows.slice(0, n)


static func _scan(node: Node, known: Dictionary, seen: Dictionary) -> void:
	var t: Variant = node.get("texture") if node is CanvasItem else null
	if t is AtlasTexture and (t as AtlasTexture).atlas != null:
		t = (t as AtlasTexture).atlas   # a trimmed HiResTex raster: its page is what is tracked
	if t is Texture2D and not known.has((t as Texture2D).get_instance_id()) and not seen.has((t as Texture2D).get_instance_id()):
		var tex := t as Texture2D
		var img: Image = tex.get_image() if not (tex is ViewportTexture) and not (tex is AtlasTexture) else null
		var w := img.get_width() if img != null else tex.get_width()
		var h := img.get_height() if img != null else tex.get_height()
		var mips := img.has_mipmaps() if img != null else false
		seen[tex.get_instance_id()] = {"label": tex.resource_path if tex.resource_path != "" else "%s:%s" % [tex.get_class(), node.name],
			"px": [w, h], "mb": snappedf(float(tex_bytes(w, h, mips)) / 1048576.0, 0.01)}
	for c in node.get_children():
		_scan(c, known, seen)


## Every SubViewport under `root` that renders: [{name, size, mb}] (RGBA8 colour buffer).
static func viewports(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	_collect_vps(root, out)
	return out


static func _collect_vps(n: Node, out: Array) -> void:
	if n is SubViewport:
		var vp := n as SubViewport
		if vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			out.append({"name": String(vp.get_parent().name) + "/" + String(vp.name) if vp.get_parent() != null else String(vp.name),
				"size": [vp.size.x, vp.size.y], "mb": snappedf(float(tex_bytes(vp.size.x, vp.size.y)) / 1048576.0, 0.01)})
	for c in n.get_children():
		_collect_vps(c, out)


## The texture-memory breakdown (MB): {total, tracked: {kind: mb}, viewports: [...],
## viewports_mb, untracked} — `total` is the engine's RENDER_TEXTURE_MEM_USED (0 headless).
static func memory_report(root: Node) -> Dictionary:
	var total := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var kinds := live_bytes_by_kind()
	var tracked := {}
	var sum := 0.0
	for k in kinds:
		var mb := float(kinds[k]) / 1048576.0
		tracked[k] = snappedf(mb, 0.1)
		sum += mb
	var vps := viewports(root)
	var vmb := 0.0
	for v in vps:
		vmb += float((v as Dictionary)["mb"])
	var eng := float(live_engine_bytes()) / 1048576.0
	return {"total": snappedf(total, 0.1), "tracked": tracked, "tracked_sum": snappedf(sum, 0.1),
		"tracked_engine_sum": snappedf(eng, 0.1), "viewports": vps, "viewports_mb": snappedf(vmb, 0.1),
		"untracked": snappedf(maxf(0.0, total - eng - vmb), 0.1) if total > 0.0 else -1.0}


## One line per memory kind, biggest first ("room 61.2 MB"), for the overlay / device log.
static func memory_lines(rep: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var tr: Dictionary = rep.get("tracked", {})
	var ks := tr.keys()
	ks.sort_custom(func(a: Variant, b: Variant) -> bool: return float(tr[a]) > float(tr[b]))
	for k in ks:
		out.append("%s %.1f" % [k, float(tr[k])])
	out.append("vp %.1f" % float(rep.get("viewports_mb", 0.0)))
	if float(rep.get("untracked", -1.0)) >= 0.0:
		out.append("untracked %.1f" % float(rep["untracked"]))
	out.append("(tracked actual %.1f, counter %.1f)" % [float(rep.get("tracked_sum", 0.0)), float(rep.get("tracked_engine_sum", 0.0))])
	return out
