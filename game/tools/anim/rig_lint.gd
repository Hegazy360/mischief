## RigLint — the rig lint (TECH §10.5): structural checks on `rigs/<id>/rig.json`,
## `poses.json` and `faces.json`, with stable rule ids (findings as in AnimLint).
##
## | id | rule |
## |---|---|
## | R01_files | every part / variant / face / overlay / prop texture exists and rasterises |
## | R02_pivots | every textured part's pivot lies inside its canvas |
## | R03_hierarchy | one root; every parent exists; no parent cycles |
## | R04_mirror | every `_l` / `_r` part has its partner; no_mirror parts exist |
## | R05_face | face anchor, slot variants and faces.json presets resolve |
## | R06_silhouette | the rest pose rendered as a 50 px silhouette is non-empty and its height is within 20 % of height_px |
## | R07_refs | limbs, sockets, springs, residues, tint and props resolve |
## | R08_poses | poses.json resolves (bases, mirrors, bones, channels, faces); poses respect joint limits (warning) |
class_name RigLint
extends RefCounted

const SIL_PX := 50
const SIL_TOL := 0.2


## Lint every rig under data/rigs (or just `rig_id`).
static func lint_all(rig_id: String = "") -> Array:
	var out: Array = []
	var ids := PackedStringArray()
	if rig_id != "":
		ids.append(rig_id)
	else:
		var d := DirAccess.open("%s/rigs" % RigDef.data_root)
		if d != null:
			for n in d.get_directories():
				if FileAccess.file_exists("%s/rigs/%s/rig.json" % [RigDef.data_root, n]):
					ids.append(n)
		ids.sort()
	for i in ids:
		out.append_array(lint_rig(RigDef.for_id(i), PoseLib.for_rig(i)))
	return out


## Every rule on one rig (+ its poses when given).
static func lint_rig(rig: RigDef, lib: PoseLib = null) -> Array:
	var out: Array = []
	if rig == null:
		return out
	var file := rig.path
	for e in rig.errors:
		out.append(AnimLint.finding(_rule_of(e), file, -1, e))
	for w in rig.warnings:
		out.append(AnimLint.finding(_rule_of(w), file, -1, w, "warning"))
	if rig.names.is_empty():
		return out
	_files(rig, file, out)
	_pivots(rig, file, out)
	_mirror_offsets(rig, file, out)
	if lib != null:
		for e2 in lib.errors:
			var r := "R05_face" if e2.contains("preset") or e2.contains("faces") else "R08_poses"
			out.append(AnimLint.finding(r, lib.path if not e2.contains("faces.json") else lib.faces_path, -1, e2))
		for w2 in lib.warnings:
			out.append(AnimLint.finding("R08_poses", lib.path, -1, w2, "warning"))
		_pose_limits(rig, lib, out)
	_silhouette(rig, lib, file, out)
	return out


static func _rule_of(msg: String) -> String:
	if msg.contains("missing") or msg.contains("readable SVG"):
		if msg.contains("face slot"):
			return "R05_face"
		return "R01_files"
	if msg.contains("parent") or msg.contains("root") or msg.contains("cycle"):
		return "R03_hierarchy"
	if msg.contains("mirror"):
		return "R04_mirror"
	if msg.contains("face"):
		return "R05_face"
	return "R07_refs"


static func _files(rig: RigDef, file: String, out: Array) -> void:
	var seen := {}
	for p in rig.all_texture_paths():
		if seen.has(p):
			continue
		seen[p] = true
		if not FileAccess.file_exists(p):
			continue   # already reported by RigDef
		var img := HiResTex.rasterize(p, {}, 0.25)
		if img == null or img.is_empty():
			out.append(AnimLint.finding("R01_files", file, -1, "%s does not rasterise (broken SVG?)" % p))


static func _pivots(rig: RigDef, file: String, out: Array) -> void:
	for p in rig.names.size():
		if not rig.is_textured(p):
			continue
		var piv := rig.pivot[p]
		for v in rig.tex_sizes[p].size():
			var s: Vector2 = rig.tex_sizes[p][v]
			if s == Vector2.ZERO:
				continue
			if piv.x < 0.0 or piv.y < 0.0 or piv.x > s.x or piv.y > s.y:
				out.append(AnimLint.finding("R02_pivots", file, -1, "part '%s' pivot %s is outside its %s canvas (%dx%d)" % [
					rig.names[p], piv, rig.tex_names[p][v], int(s.x), int(s.y)]))
				break


## Mirrored poses swap partner angles; partners whose joints sit at different offsets then
## land in different places (a mirrored walk's planted foot jumps).
static func _mirror_offsets(rig: RigDef, file: String, out: Array) -> void:
	for i in rig.names.size():
		var j := rig.mirror_idx[i]
		if j <= i:
			continue
		if rig.offset[i].distance_to(rig.offset[j]) > 1.0 and rig.limb_of[i] >= 0 and rig.names[i].contains("leg"):
			out.append(AnimLint.finding("R04_mirror", file, -1, "mirror partners %s / %s have different offsets %s / %s: mirrored poses (walks) will not land the feet in the same place" % [
				rig.names[i], rig.names[j], rig.offset[i], rig.offset[j]], "warning"))


static func _pose_limits(rig: RigDef, lib: PoseLib, out: Array) -> void:
	for pn in lib.names:
		var pose := lib.pose(pn)
		for p in rig.names.size():
			var v := pose[RigDef.ch(p, RigDef.C_ROT)]
			if v < rig.rot_min[p] - 0.01 or v > rig.rot_max[p] + 0.01:
				out.append(AnimLint.finding("R08_poses", lib.path, -1, "pose '%s': %s rot %.1f outside [%.0f, %.0f]" % [
					pn, rig.names[p], v, rig.rot_min[p], rig.rot_max[p]], "warning"))


## Rasterises the rest pose's alpha on the CPU (parts + limb strokes) at SIL_PX per
## height_px and measures it.
static func _silhouette(rig: RigDef, lib: PoseLib, file: String, out: Array) -> void:
	var pose := rig.rest
	if lib != null:
		for pn in lib.names:
			if lib.tags_of(pn).has("stand") or pn.ends_with("_stand"):
				pose = lib.pose(pn)
				break
	var xf: Array[Transform2D] = []
	RigSampler.solve(rig, pose, xf)
	var sil := silhouette(rig, pose, xf, float(SIL_PX) / rig.height_px)
	var filled: int = sil["filled"]
	if filled < 30:
		out.append(AnimLint.finding("R06_silhouette", file, -1, "rest silhouette at %d px is empty (%d px filled)" % [SIL_PX, filled]))
		return
	var h: float = sil["height_1x"]
	if absf(h - rig.height_px) > rig.height_px * SIL_TOL:
		out.append(AnimLint.finding("R06_silhouette", file, -1, "rest silhouette is %.0f px tall but height_px is %.0f (±%d%%)" % [h, rig.height_px, int(SIL_TOL * 100.0)]))


## CPU silhouette of a solved pose at `scale` (px per 1× px): {"image": Image (L8),
## "filled": int, "rect": Rect2 (1× px), "height_1x": float}. Pure (no renderer).
static func silhouette(rig: RigDef, pose: PackedFloat32Array, xf: Array[Transform2D], scale: float) -> Dictionary:
	var box := RigBounds.bbox(rig, pose, xf, 0.0).grow(4.0)
	var w := maxi(1, ceili(box.size.x * scale))
	var h := maxi(1, ceili(box.size.y * scale))
	var img := Image.create_empty(w, h, false, Image.FORMAT_L8)
	var parts: Array = []
	for p in rig.names.size():
		if not RigBounds.part_visible(rig, pose, p):
			continue
		var v := clampi(int(pose[RigDef.ch(p, RigDef.C_TEX)]), 0, rig.tex_files[p].size() - 1)
		var src := HiResTex.rasterize(rig.tex_files[p][v], {}, 1.0)
		if src == null:
			continue
		parts.append([xf[p].affine_inverse(), src, rig.pivot[p]])
	var limb_pts: Array = []
	var cpts := PackedVector2Array()
	cpts.resize(LineLimb.SAMPLES)
	for l in rig.limbs:
		var lb: RigDef.RigLimb = l
		var js := PackedVector2Array()
		for j in lb.joints:
			js.append(xf[j].origin)
		LineLimb.curve(js, js.size(), cpts)
		limb_pts.append([cpts.duplicate(), lb.width * 0.5 + lb.outline])
	var filled := 0
	var top := INF
	var bottom := -INF
	for y in h:
		for x in w:
			var q := box.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / scale
			var on := false
			for pa in parts:
				var local: Vector2 = (pa[0] as Transform2D) * q + (pa[2] as Vector2)
				var im: Image = pa[1]
				var ix := int(local.x)
				var iy := int(local.y)
				if ix >= 0 and iy >= 0 and ix < im.get_width() and iy < im.get_height() and im.get_pixel(ix, iy).a > 0.5:
					on = true
					break
			if not on:
				for lp in limb_pts:
					var pts: PackedVector2Array = lp[0]
					var r: float = lp[1]
					for k in pts.size() - 1:
						if _seg_dist(q, pts[k], pts[k + 1]) <= r:
							on = true
							break
					if on:
						break
			if on:
				img.set_pixel(x, y, Color.WHITE)
				filled += 1
				top = minf(top, q.y)
				bottom = maxf(bottom, q.y)
	return {"image": img, "filled": filled, "rect": box, "height_1x": (bottom - top) if filled > 0 else 0.0}


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
