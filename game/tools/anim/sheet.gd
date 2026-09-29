## Animation sheet renderer (TECH §11) — renders with the game's own RigPlayer / RigSampler
## in SubViewports and writes PNGs an agent can LOOK at. Needs a real renderer:
##   tools/scripts/anim_sheet.sh <rig> <clip|--poses|--rig> <out_dir> [--scale=1.0]
## which runs (xvfb + opengl3, in a sandbox copy):
##   godot --path <sandbox> -s res://tools/anim/sheet.gd -- --rig=<id> --mode=rig|poses|clip
##         [--clip=<rig/name>] --out=<dir> [--scale=1.0] [--tier=1] [--suppressed]
##
## Outputs (in --out):
## * rig.png — every texture (variants, face slots, overlays, props) exploded with its pivot
##   crosshair + name; the rig at rest, at every joint's MIN limit and at its MAX limit.
## * poses.png — every pose labelled (name, tags, silhouette note) with a solid black 50 px
##   silhouette beside it; poses_phone.png — the same poses at true phone scale (0.5×: a
##   1200×540 screenshot of the 1920×1080 base), no labels but numbers.
## * <clip>_contact.png — a cell every 3 f plus every key (keys outlined red, hold-beat frames
##   blue), the events under each cell, the beat bar on top; <clip>_contact_phone.png — the
##   same cells at phone scale.
## * <clip>_onion.png — the whole clip's spacing (head top, hands, root dots per frame), then
##   one panel per beat with its frames overlaid, tinted blue (past) → red (future).
## * <clip>_curves.json — per channel values per frame + keys + beats (tools/anim/curves.py
##   plots it to <clip>_curves.png); <clip>_lint.txt — the animation lint for the clip.
## Cells are rendered by advancing a real player frame by frame (springs, smears, props and
## tier remaps show exactly as in game; blinks and breathing are off so sheets repeat).
extends SceneTree

const BG := Color("#E9E4D8")
const INK := Color("#1B2340")
const KEY_COL := Color("#D62839")
const HOLD_COL := Color("#2E6FD8")
const FLOOR_COL := Color("#8E8778")
const PHONE := 0.5

var _args: Dictionary = {}
var _out: String = ""
var _rig: RigDef
var _poses: PoseLib
var _scale: float = 1.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
		elif a.begins_with("--"):
			_args[a.substr(2)] = "true"
	_run.call_deferred()


func _run() -> void:
	var rig_id := String(_args.get("rig", "_mannequin"))
	_out = String(_args.get("out", "user://sheets"))
	_scale = float(_args.get("scale", "1.0"))
	DirAccess.make_dir_recursive_absolute(_out)
	_rig = RigDef.for_id(rig_id)
	if _rig == null:
		printerr("[sheet] rig '%s' not found" % rig_id)
		quit(2)
		return
	_poses = PoseLib.for_rig(rig_id)
	var mode := String(_args.get("mode", "poses"))
	var ok := true
	match mode:
		"rig":
			ok = await _rig_sheet()
		"poses":
			ok = await _pose_sheet()
		"residues":
			ok = await _residue_sheet()
		"all":
			ok = await _rig_sheet()
			ok = await _pose_sheet() and ok
			for cid2 in ClipLib.list(rig_id):
				ok = await _clip_sheets(cid2) and ok
		"clip":
			var cid := String(_args.get("clip", ""))
			if not cid.contains("/"):
				cid = rig_id + "/" + cid
			ok = await _clip_sheets(cid)
		_:
			printerr("[sheet] unknown mode '%s'" % mode)
			ok = false
	quit(0 if ok else 1)


# --- capture helpers ---------------------------------------------------------------------------

func _capture(content: Node, size: Vector2i, bg: Color = BG) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(clampi(size.x, 8, 16000), clampi(size.y, 8, 16000))
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var back := ColorRect.new()
	back.color = bg
	back.size = Vector2(vp.size)
	vp.add_child(back)
	vp.add_child(content)
	root.add_child(vp)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	await process_frame
	return img


func _save(img: Image, name: String) -> void:
	var p := _out.path_join(name)
	img.save_png(p)
	print("[sheet] wrote ", p)


func _label(text: String, pos: Vector2, size: int = 16, col: Color = INK, width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if width > 0.0:
		l.size = Vector2(width, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _player() -> RigPlayer:
	var p := RigPlayer.new()
	p.configure_for_tools()
	p.setup(_rig.id)
	return p


func _posed(pose: PackedFloat32Array) -> RigPlayer:
	var p := _player()
	p.springs_enabled = false
	p.smears_enabled = false
	p.set_static_pose(pose)
	p.advance(0.0)
	return p


## A player advanced from frame 0 to `frame` of `clip_id` (opts as RigPlayer.play), placed at
## `pos` / `scl` BEFORE simulating (launched props remember where they left from).
func _at_frame(clip_id: String, frame: int, opts: Dictionary, pos: Vector2 = Vector2.ZERO, scl: float = 1.0) -> RigPlayer:
	var p := _player()
	p.position = pos
	p.scale = Vector2(scl, scl)
	p.play(clip_id, opts)
	p.advance(0.0)
	for i in frame:
		p.advance(1.0 / 60.0)
	return p


## A Node2D that draws with a callable (outlines, dots, bars).
class Painter extends Node2D:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


func _painter(fn: Callable) -> Painter:
	var p := Painter.new()
	p.fn = fn
	return p


# --- rig sheet ---------------------------------------------------------------------------------

func _rig_sheet() -> bool:
	var stage := Node2D.new()
	var set := AtlasBuilder.build("sheet:%s" % _rig.id, _rig.all_texture_paths(), 2.0)
	var x := 20.0
	var y := 60.0
	var row_h := 0.0
	var width := 2400.0
	stage.add_child(_label("rig %s — %d parts (%d face slots), %d limbs, height %d px; red + = pivot, blue ● = socket" % [
		_rig.id, _rig.names.size(), _rig.face_slots.size(), _rig.limbs.size(), int(_rig.height_px)], Vector2(20, 14), 24))
	var items: Array = []   # [label, path, pivot, part index]
	for p in _rig.names.size():
		for v in _rig.tex_files[p].size():
			items.append(["%s:%s" % [_rig.names[p], _rig.tex_names[p][v]], _rig.tex_files[p][v], _rig.pivot[p], p])
	for k in _rig.residues:
		var res: RigDef.RigResidue = _rig.residues[k]
		for j in res.overlay_file.size():
			items.append(["%s overlay on %s" % [k, _rig.names[res.overlay_part[j]]], res.overlay_file[j], _rig.pivot[res.overlay_part[j]], res.overlay_part[j]])
	for pr in _rig.props:
		var prd: RigDef.RigProp = pr
		for j2 in prd.state_files.size():
			items.append(["prop %s:%s" % [prd.id, prd.states[j2]], prd.state_files[j2], prd.pivot, -1])
	for it in items:
		var path: String = it[1]
		var sz := set.size_1x(path)
		var cw := maxf(sz.x, 150.0) + 24.0
		if x + cw > width:
			x = 20.0
			y += row_h + 40.0
			row_h = 0.0
		var spr := Sprite2D.new()
		spr.texture = set.page(path)
		spr.region_enabled = true
		spr.region_rect = set.region(path)
		spr.scale = Vector2.ONE / set.scale
		spr.centered = false
		spr.position = Vector2(x, y) + set.draw_rect(path).position
		stage.add_child(spr)
		var piv: Vector2 = it[2]
		var part_i: int = it[3]
		var ox := x
		var oy := y
		var socks: Array = []
		if part_i >= 0:
			for s in _rig.socket_names.size():
				if _rig.socket_part[s] == part_i:
					socks.append(Vector2(_rig.socket_xf[s].x, _rig.socket_xf[s].y))
		stage.add_child(_painter(func(n: Node2D) -> void:
			n.draw_rect(Rect2(ox, oy, sz.x, sz.y), Color(0, 0, 0, 0.25), false, 1.0)
			var c := Vector2(ox, oy) + piv
			n.draw_line(c - Vector2(9, 0), c + Vector2(9, 0), KEY_COL, 2.5)
			n.draw_line(c - Vector2(0, 9), c + Vector2(0, 9), KEY_COL, 2.5)
			for so in socks:
				n.draw_circle(Vector2(ox, oy) + so, 5.0, HOLD_COL)))
		stage.add_child(_label("%s\n%dx%d" % [it[0], int(sz.x), int(sz.y)], Vector2(x, y + sz.y + 2), 13, INK, cw - 4.0))
		x += cw
		row_h = maxf(row_h, sz.y + 30.0)
	y += row_h + 60.0
	# Rest / min / max limit poses.
	var cell := _rig.height_px * 1.35
	var poses_row := [["rest", _rig.rest], ["min limits", _limit_pose(true)], ["max limits", _limit_pose(false)]]
	for i in poses_row.size():
		var px := 40.0 + float(i) * cell * 1.2 + cell * 0.5
		var base_y := y + cell
		var p2 := _posed(poses_row[i][1])
		p2.position = Vector2(px, base_y)
		stage.add_child(_floor_line(px, base_y, cell))
		stage.add_child(p2)
		stage.add_child(_joint_marks(p2, Vector2(px, base_y)))
		stage.add_child(_label(String(poses_row[i][0]), Vector2(px - cell * 0.4, base_y + 10), 20))
	var h := int(y + cell + 60)
	var img := await _capture(stage, Vector2i(int(width), h))
	_save(img, "rig.png")
	return true


func _limit_pose(lo: bool) -> PackedFloat32Array:
	var p := _rig.rest.duplicate()
	for i in _rig.names.size():
		var v := _rig.rot_min[i] if lo else _rig.rot_max[i]
		if absf(v) < RigDef.NO_LIMIT:
			p[RigDef.ch(i, RigDef.C_ROT)] = v
	return p


func _floor_line(x: float, y: float, w: float) -> Painter:
	return _painter(func(n: Node2D) -> void:
		n.draw_line(Vector2(x - w * 0.5, y), Vector2(x + w * 0.5, y), FLOOR_COL, 2.0))


func _joint_marks(p: RigPlayer, at: Vector2) -> Painter:
	var xf := p.part_transforms().duplicate()
	var r := _rig
	return _painter(func(n: Node2D) -> void:
		for i in r.names.size():
			var o: Vector2 = at + (xf[i] as Transform2D).origin
			n.draw_circle(o, 3.5, KEY_COL)
			if r.parent[i] >= 0:
				n.draw_line(at + (xf[r.parent[i]] as Transform2D).origin, o, Color(KEY_COL, 0.5), 1.5))


# --- pose sheet --------------------------------------------------------------------------------

## Horizontal span (unscaled px, feet at x = 0) of each pose: every pose is centred on its own
## span and the cells are as wide as the widest one (Bellows' belly, a lunge), capped at 1.6×
## the character height, so neighbours do not overlap.
func _pose_spans() -> PackedVector2Array:
	var out := PackedVector2Array()
	for n in _poses.names:
		var p := _posed(_poses.pose(n))
		var b := p.get_bounds()
		out.append(Vector2(b.position.x, b.end.x))
		p.free()
	return out


func _widest(spans: PackedVector2Array) -> float:
	var w := 0.0
	for sp in spans:
		w = maxf(w, sp.y - sp.x)
	return minf(w, _rig.height_px * 1.6)


func _pose_sheet() -> bool:
	var names := _poses.names
	var spans := _pose_spans()
	var cell_w := maxf(_rig.height_px * 0.95, _widest(spans) + 16.0) * _scale
	var cell_h := _rig.height_px * 1.7 * _scale + 70.0
	var cols := maxi(1, int(3400.0 / (cell_w + 60.0)))
	var stage := Node2D.new()
	stage.add_child(_label("%s poses (%d) — each with a solid 50 px silhouette; errors: %d" % [_rig.id, names.size(), _poses.errors.size()], Vector2(20, 10), 26))
	for i in names.size():
		var cx := 20.0 + float(i % cols) * (cell_w + 60.0)
		var cy := 60.0 + float(i / cols) * cell_h
		var feet := Vector2(cx + cell_w * 0.5 - (spans[i].x + spans[i].y) * 0.5 * _scale, cy + _rig.height_px * 1.45 * _scale)
		var p := _posed(_poses.pose(names[i]))
		p.position = feet
		p.scale = Vector2(_scale, _scale)
		stage.add_child(_floor_line(cx + cell_w * 0.5, feet.y, cell_w))
		stage.add_child(p)
		var sil := _posed(_poses.pose(names[i]))
		var ss := 50.0 / _rig.height_px
		sil.scale = Vector2(ss, ss)
		sil.modulate = Color.BLACK
		sil.position = Vector2(cx + cell_w + 20.0, feet.y)
		stage.add_child(sil)
		var tg := ", ".join(_poses.tags_of(names[i]))
		var note := String(_poses.silhouettes.get(names[i], ""))
		stage.add_child(_label("%d %s" % [i, names[i]], Vector2(cx, feet.y + 4), 18))
		stage.add_child(_label("[%s] %s" % [tg, note], Vector2(cx, feet.y + 26), 12, Color(INK, 0.8), cell_w + 50.0))
	var rows := (names.size() + cols - 1) / cols
	var w := int(40.0 + float(cols) * (cell_w + 60.0))
	var h := int(80.0 + float(rows) * cell_h)
	_save(await _capture(stage, Vector2i(w, h)), "poses.png")
	# Phone scale: characters at 0.5×, index numbers only.
	var pstage := Node2D.new()
	var pw := maxf(_rig.height_px * 0.7, _widest(spans) + 12.0) * PHONE
	var pcols := maxi(1, int(2300.0 / pw))
	var ptop := _rig.height_px * 0.3 * PHONE  # room above the first row for jumps and flying hats
	for i in names.size():
		var fx := 20.0 + float(i % pcols) * pw + pw * 0.5 - (spans[i].x + spans[i].y) * 0.5 * PHONE
		var fy := 20.0 + ptop + float(i / pcols + 1) * (_rig.height_px * 1.4 * PHONE + 18.0)
		var p := _posed(_poses.pose(names[i]))
		p.scale = Vector2(PHONE, PHONE)
		p.position = Vector2(fx, fy)
		pstage.add_child(p)
		pstage.add_child(_label(str(i), Vector2(fx - 8, fy + 1), 12))
	var prows := (names.size() + pcols - 1) / pcols
	_save(await _capture(pstage, Vector2i(int(40.0 + float(pcols) * pw), int(40.0 + ptop + float(prows) * (_rig.height_px * 1.4 * PHONE + 18.0)))), "poses_phone.png")
	return true


# --- residue sheet -----------------------------------------------------------------------------

## residues.png: the stand pose with every residue look (sub-looks and combos included).
func _residue_sheet() -> bool:
	var kinds := PackedStringArray(_rig.residues.keys())
	kinds.sort()
	kinds.insert(0, "(none)")
	var pose := _rig.rest
	for pn in _poses.names:
		if _poses.tags_of(pn).has("idle") or pn.ends_with("_stand"):
			pose = _poses.pose(pn)
			break
	var cell_w := _rig.height_px * 0.95 * _scale
	var cell_h := _rig.height_px * 1.5 * _scale + 50.0
	var cols := maxi(1, int(3400.0 / (cell_w + 20.0)))
	var stage := Node2D.new()
	stage.add_child(_label("%s residue looks (%d)" % [_rig.id, kinds.size() - 1], Vector2(20, 10), 26))
	for i in kinds.size():
		var cx := 20.0 + float(i % cols) * (cell_w + 20.0)
		var cy := 60.0 + float(i / cols) * cell_h
		var feet := Vector2(cx + cell_w * 0.5, cy + _rig.height_px * 1.3 * _scale)
		var p := _player()
		p.springs_enabled = false
		p.smears_enabled = false
		if i > 0:
			p.set_residue(kinds[i], true)
		p.set_static_pose(pose)
		p.advance(0.0)
		p.scale = Vector2(_scale, _scale)
		p.position = feet
		stage.add_child(_floor_line(feet.x, feet.y, cell_w))
		stage.add_child(p)
		stage.add_child(_label(kinds[i], Vector2(cx, feet.y + 4), 16, INK, cell_w))
	var rows := (kinds.size() + cols - 1) / cols
	_save(await _capture(stage, Vector2i(int(40.0 + float(cols) * (cell_w + 20.0)), int(80.0 + float(rows) * cell_h))), "residues.png")
	return true


# --- clip sheets -------------------------------------------------------------------------------

func _clip_opts() -> Dictionary:
	var o := {}
	if _args.has("tier"):
		o["tier"] = int(_args["tier"])
	if _args.has("suppressed"):
		o["suppressed"] = true
	return o


func _clip_sheets(cid: String) -> bool:
	var clip := ClipLib.get_clip(cid)
	if clip == null:
		printerr("[sheet] clip '%s' not found" % cid)
		return false
	var opts := _clip_opts()
	var plan := PlayPlan.build(clip, opts)
	var tag := clip.short_name()
	if opts.has("tier"):
		tag += "_t%d" % int(opts["tier"])
	if opts.has("suppressed"):
		tag += "_sup"
	await _contact(clip, plan, opts, tag)
	await _onion(clip, plan, opts, tag)
	_curves(clip, plan, tag)
	_lint(clip, tag)
	return true


func _cell_frames(clip: ClipDef, plan: PlayPlan) -> PackedInt32Array:
	var fs := {}
	var f := 0
	while f <= plan.length:
		fs[f] = true
		f += 3
	for k in clip.key_f:
		fs[plan.timeline_frame(k)] = true
	if plan.tail != null:
		for k2 in plan.tail.key_f:
			fs[plan.tail_start + k2] = true
	fs[plan.length] = true
	var out := PackedInt32Array(fs.keys())
	out.sort()
	var clipped := PackedInt32Array()
	for v in out:
		if v <= plan.length:
			clipped.append(v)
	return clipped


func _is_key(clip: ClipDef, plan: PlayPlan, f: int) -> bool:
	for k in clip.key_f:
		if plan.timeline_frame(k) == f:
			return true
	if plan.tail != null:
		for k2 in plan.tail.key_f:
			if plan.tail_start + k2 == f:
				return true
	return false


func _in_hold(plan: PlayPlan, clip: ClipDef, f: int) -> bool:
	var h := clip.beat("hold")
	if h.x < 0:
		return false
	return f >= plan.timeline_frame(h.x) and f <= plan.timeline_frame(h.y)


func _events_text(plan: PlayPlan, f0: int, f1: int) -> String:
	var parts := PackedStringArray()
	for i in plan.events.size():
		var ef := plan.ev_f[i]
		if ef > f0 and ef <= f1:
			parts.append(_ev_label(plan.events[i]))
	return "\n".join(parts)


static func _ev_label(e: Dictionary) -> String:
	var t := String(e.get("type", ""))
	match t:
		"sfx", "voice":
			return "%s:%s" % [t, e.get("id", e.get("vocal", e.get("bank", "")))]
		"mark":
			return "mark:%s" % e.get("name", "")
		"hitstop":
			return "hitstop %df" % int(e.get("frames", 0))
		"cam":
			return "cam %s %s" % [e.get("op", ""), e.get("zoom", "")]
		"shake":
			return "shake %s" % e.get("trauma", "")
		"prop":
			return "prop %s %s" % [e.get("op", ""), e.get("prop", "")]
		"laugh":
			return "laugh %s" % e.get("tier", "")
		"face":
			return "face:%s" % e.get("preset", e.get("id", ""))
		"spring":
			return "spring %s" % e.get("part", "")
	return "%s %s" % [t, e.get("id", "")]


## Horizontal reach (unscaled character px, feet at x = 0) of the body and of every visible prop
## over the whole play: a launched mug may land well beside the character, and a contact cell
## must be wide enough that each prop stays in its own cell.
func _x_extent(clip_id: String, opts: Dictionary, n: int) -> Vector2:
	var p := _player()
	get_root().add_child(p)
	p.play(clip_id, opts)
	p.advance(0.0)
	var lo := INF
	var hi := -INF
	for f in n + 1:
		if f > 0:
			p.advance(1.0 / 60.0)
		var b := p.get_bounds()
		lo = minf(lo, b.position.x)
		hi = maxf(hi, b.end.x)
		for i in p.props.count:
			if p.props.mode[i] == PropSim.HIDDEN:
				continue
			var x := (p._char_xf() * p._prop_xf(i).origin).x
			var r := maxf(p.props.radius[i], 12.0)
			lo = minf(lo, x - r)
			hi = maxf(hi, x + r)
	p.free()
	return Vector2(lo, hi)


func _contact(clip: ClipDef, plan: PlayPlan, opts: Dictionary, tag: String) -> void:
	var frames := _cell_frames(clip, plan)
	var s := _scale * 0.62
	var cell_w := _rig.height_px * 0.85 * s
	# Widen the cells (and shift the feet) when a prop travels outside the default cell.
	var ext := _x_extent(clip.id, opts, plan.length)
	var feet_dx := cell_w * 0.5
	if ext.x * s < -cell_w * 0.5 + 8.0 or ext.y * s > cell_w * 0.5 - 8.0:
		cell_w = maxf(cell_w, (ext.y - ext.x) * s + 16.0)
		feet_dx = clampf(cell_w * 0.5, 8.0 - ext.x * s, cell_w - 8.0 - ext.y * s)
	var char_h := _rig.height_px * 1.9 * s
	var cell_h := char_h + 118.0
	var cols := maxi(1, int(3000.0 / cell_w))
	var stage := Node2D.new()
	var top := 96.0
	stage.add_child(_label("%s  %d f%s  tier %d%s — red = key, blue = hold beat; events under each cell" % [
		clip.id, plan.length, " loop" if plan.loop else "", plan.tier, " suppressed" if plan.suppressed else ""], Vector2(14, 8), 24))
	stage.add_child(_beat_bar(clip, plan, Rect2(14, 44, float(cols) * cell_w - 28.0, 34)))
	var prev := -1
	for i in frames.size():
		var f := frames[i]
		var cx := 10.0 + float(i % cols) * cell_w
		var cy := top + float(i / cols) * cell_h
		var feet := Vector2(cx + feet_dx, cy + char_h * 0.92)
		var p := _at_frame(clip.id, f, opts, feet, s)
		stage.add_child(_floor_line(cx + cell_w * 0.5, feet.y, cell_w - 6.0))
		stage.add_child(p)
		var key := _is_key(clip, plan, f)
		var hold := _in_hold(plan, clip, f)
		var r := Rect2(cx + 2, cy, cell_w - 4, char_h)
		stage.add_child(_painter(func(n: Node2D) -> void:
			if key:
				n.draw_rect(r, KEY_COL, false, 4.0)
			elif hold:
				n.draw_rect(r, HOLD_COL, false, 3.0)
			else:
				n.draw_rect(r, Color(0, 0, 0, 0.15), false, 1.0)))
		stage.add_child(_label("f%d%s" % [f, " key" if key else ""], Vector2(cx + 6, cy + 4), 15, KEY_COL if key else INK))
		var ev := _events_text(plan, prev, f)
		if ev != "":
			stage.add_child(_label(ev, Vector2(cx + 4, cy + char_h + 2), 10, INK, cell_w - 6.0))
		prev = f
	var rows := (frames.size() + cols - 1) / cols
	var w := int(20.0 + float(cols) * cell_w)
	var h := int(top + float(rows) * cell_h + 10.0)
	_save(await _capture(stage, Vector2i(w, h)), "%s_contact.png" % tag)
	# Phone scale copy: the same cells at 0.5×.
	var ps := PHONE
	var pcw := _rig.height_px * 0.6 * ps
	var pdx := pcw * 0.5
	if ext.x * ps < -pcw * 0.5 + 4.0 or ext.y * ps > pcw * 0.5 - 4.0:
		pcw = maxf(pcw, (ext.y - ext.x) * ps + 8.0)
		pdx = clampf(pcw * 0.5, 4.0 - ext.x * ps, pcw - 4.0 - ext.y * ps)
	var pch := _rig.height_px * 1.75 * ps
	var pcols := maxi(1, int(2300.0 / pcw))
	var pstage := Node2D.new()
	for i in frames.size():
		var f2 := frames[i]
		var fx := 10.0 + float(i % pcols) * pcw + pdx
		var fy := 10.0 + float(i / pcols) * (pch + 16.0) + pch * 0.9
		var p2 := _at_frame(clip.id, f2, opts, Vector2(fx, fy), ps)
		pstage.add_child(p2)
		pstage.add_child(_label(str(f2), Vector2(fx - 10, fy + 1), 11, KEY_COL if _is_key(clip, plan, f2) else INK))
	var prows := (frames.size() + pcols - 1) / pcols
	_save(await _capture(pstage, Vector2i(int(20.0 + float(pcols) * pcw), int(20.0 + float(prows) * (pch + 16.0)))), "%s_contact_phone.png" % tag)


func _beat_bar(clip: ClipDef, plan: PlayPlan, r: Rect2) -> Painter:
	var ln := float(maxi(1, plan.length))
	var beats: Array = []
	var cols := {"anticipation": Color("#F2B33D"), "accent": KEY_COL, "hold": HOLD_COL, "settle": Color("#2FA39A")}
	for bn in clip.beats:
		var b: Vector2i = clip.beats[bn]
		beats.append([String(bn), plan.timeline_frame(b.x), plan.timeline_frame(b.y)])
	var keys := PackedInt32Array()
	for k in clip.key_f:
		keys.append(plan.timeline_frame(k))
	var evs := plan.ev_f.duplicate()
	var tail_s := plan.tail_start
	var font := ThemeDB.fallback_font
	return _painter(func(n: Node2D) -> void:
		n.draw_rect(r, Color(1, 1, 1, 0.8))
		for b in beats:
			var x0: float = r.position.x + r.size.x * float(b[1]) / ln
			var x1: float = r.position.x + r.size.x * float(b[2]) / ln
			var c: Color = cols.get(b[0], Color("#9A8FB0"))
			n.draw_rect(Rect2(x0, r.position.y, maxf(2.0, x1 - x0), r.size.y * 0.6), Color(c, 0.75))
			n.draw_string(font, Vector2(x0 + 3, r.position.y + 16), "%s %d-%d" % [b[0], b[1], b[2]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		if tail_s >= 0:
			var xt: float = r.position.x + r.size.x * float(tail_s) / ln
			n.draw_rect(Rect2(xt, r.position.y, r.end.x - xt, r.size.y * 0.6), Color("#7A5CA0", 0.55))
		for k in keys:
			var xk: float = r.position.x + r.size.x * float(k) / ln
			n.draw_line(Vector2(xk, r.position.y + r.size.y * 0.6), Vector2(xk, r.end.y), KEY_COL, 2.0)
		for e in evs:
			var xe: float = r.position.x + r.size.x * float(e) / ln
			n.draw_circle(Vector2(xe, r.end.y - 3), 3.0, INK)
		n.draw_rect(r, INK, false, 1.5))


func _onion(clip: ClipDef, plan: PlayPlan, opts: Dictionary, tag: String) -> void:
	# Track head top, hands and root per frame (character space) with one player.
	var p := _player()
	p.play(clip.id, opts)
	p.advance(0.0)
	var t_head := PackedVector2Array()
	var t_hr := PackedVector2Array()
	var t_hl := PackedVector2Array()
	var t_root := PackedVector2Array()
	var hand_r := _rig.idx("hand_r")
	var hand_l := _rig.idx("hand_l")
	for f in plan.length + 1:
		var xf := p.part_transforms()
		t_head.append(RigBounds.head_top(_rig, p.pose_buffer(), xf))
		t_hr.append(xf[hand_r].origin if hand_r >= 0 else Vector2.ZERO)
		t_hl.append(xf[hand_l].origin if hand_l >= 0 else Vector2.ZERO)
		t_root.append(xf[_rig.root_index].origin)
		p.advance(1.0 / 60.0)
	p.free()
	var tracks := {"head": t_head, "hand_r": t_hr, "hand_l": t_hl, "root": t_root}
	var panels: Array = [["whole clip", 0, plan.length]]
	var order := ["anticipation", "accent", "hold", "settle"]
	var names: Array = []
	for bn in order:
		if clip.beats.has(bn):
			names.append(bn)
	for bn2 in clip.beats:
		if not names.has(bn2):
			names.append(bn2)
	for bn3 in names:
		var b: Vector2i = clip.beats[bn3]
		panels.append([String(bn3), plan.timeline_frame(b.x), plan.timeline_frame(b.y)])
	if plan.tail != null:
		panels.append(["suppressed tail", plan.tail_start, plan.length])
	var s := _scale * 0.9
	var pw := _rig.height_px * 1.5 * s
	var ph := _rig.height_px * 2.0 * s + 60.0
	var cols := mini(panels.size(), 4)
	var stage := Node2D.new()
	stage.add_child(_label("%s onion — blue = earlier, red = later; dots = spacing (head top ●, hands ■, root ◆) — dense dots then a gap = a snap" % clip.id, Vector2(14, 8), 22))
	for i in panels.size():
		var cx := 10.0 + float(i % cols) * pw
		var cy := 48.0 + float(i / cols) * ph
		var feet := Vector2(cx + pw * 0.45, cy + _rig.height_px * 1.8 * s)
		var f0: int = panels[i][1]
		var f1: int = panels[i][2]
		if i > 0 and f1 < plan.length and f1 > f0:
			f1 -= 1   # beats are [start, end): the end frame belongs to the next beat
		stage.add_child(_floor_line(feet.x, feet.y, pw - 10.0))
		if i > 0:
			var n := maxi(1, f1 - f0)
			var step := 1 if n <= 40 else 2
			var fr := f0
			while fr <= f1:
				var t := float(fr - f0) / float(n)
				var q := _at_frame(clip.id, fr, opts, feet, s)
				var c := Color(0.2, 0.35, 1.0).lerp(Color(1.0, 0.15, 0.1), t)
				q.modulate = Color(c.r * 0.5 + 0.5, c.g * 0.5 + 0.5, c.b * 0.5 + 0.5, 0.2 if fr != f1 and fr != f0 else 0.6)
				stage.add_child(q)
				fr += step
		stage.add_child(_spacing(tracks, f0, f1, feet, s))
		stage.add_child(_label("%s  f%d–%d (%d f)" % [panels[i][0], f0, f1, f1 - f0], Vector2(cx + 8, cy + 2), 18))
	var rows := (panels.size() + cols - 1) / cols
	_save(await _capture(stage, Vector2i(int(20.0 + float(cols) * pw), int(56.0 + float(rows) * ph))), "%s_onion.png" % tag)


func _spacing(tracks: Dictionary, f0: int, f1: int, at: Vector2, s: float) -> Painter:
	var tr := tracks.duplicate(true)
	return _painter(func(n: Node2D) -> void:
		var span := float(maxi(1, f1 - f0))
		for k in tr:
			var pts: PackedVector2Array = tr[k]
			var prevp := Vector2.INF
			for f in range(f0, mini(f1, pts.size() - 1) + 1):
				var t := float(f - f0) / span
				var c := Color(0.15, 0.3, 1.0).lerp(Color(1.0, 0.1, 0.05), t)
				var q := at + pts[f] * s
				if prevp != Vector2.INF:
					n.draw_line(prevp, q, Color(c, 0.5), 1.5)
				match String(k):
					"head":
						n.draw_circle(q, 4.0, c)
					"root":
						n.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -5), q + Vector2(5, 0), q + Vector2(0, 5), q + Vector2(-5, 0)]), c)
					_:
						n.draw_rect(Rect2(q - Vector2(3.5, 3.5), Vector2(7, 7)), c)
				prevp = q)


func _curves(clip: ClipDef, plan: PlayPlan, tag: String) -> void:
	var buf := _rig.rest.duplicate()
	var chans := {}
	var names := PackedStringArray()
	var idx := PackedInt32Array()
	for r in RigDef.ROOT_CH:
		names.append("root.%s" % RigDef.ROOT_CHANNELS[r])
		idx.append(r)
	for p in _rig.names.size():
		for c in [RigDef.C_ROT, RigDef.C_X, RigDef.C_Y, RigDef.C_SX, RigDef.C_SY, RigDef.C_ALPHA]:
			names.append("%s.%s" % [_rig.names[p], RigDef.CHANNELS[c]])
			idx.append(RigDef.ch(p, c))
	var frames := plan.length + 1
	var flat := PackedFloat32Array()
	flat.resize(frames * names.size())
	for f in frames:
		plan.sample(float(f), buf)
		for i in names.size():
			flat[f * names.size() + i] = buf[idx[i]]
	for i in names.size():
		var s := PackedFloat32Array()
		for f2 in frames:
			s.append(flat[f2 * names.size() + i])
		var lo := INF
		var hi := -INF
		for v in s:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		if hi - lo > 0.01:
			var arr: Array = []
			for v2 in s:
				arr.append(snappedf(v2, 0.001))
			chans[names[i]] = arr
	var keys: Array = []
	for k in clip.key_f.size():
		keys.append({"f": plan.timeline_frame(clip.key_f[k]), "pose": clip.key_pose_name[k], "ease": RigEase.name_of(clip.key_ease[k])})
	var beats := {}
	for bn in clip.beats:
		var b: Vector2i = clip.beats[bn]
		beats[bn] = [plan.timeline_frame(b.x), plan.timeline_frame(b.y)]
	var events: Array = []
	for i2 in plan.events.size():
		events.append({"f": plan.ev_f[i2], "label": _ev_label(plan.events[i2])})
	var doc := {"clip": clip.id, "length": plan.length, "loop": plan.loop, "tier": plan.tier, "suppressed": plan.suppressed,
		"keys": keys, "beats": beats, "events": events, "channels": chans}
	var p2 := _out.path_join("%s_curves.json" % tag)
	var fa := FileAccess.open(p2, FileAccess.WRITE)
	fa.store_string(JSON.stringify(doc, " "))
	fa.close()
	print("[sheet] wrote ", p2)


func _lint(clip: ClipDef, tag: String) -> void:
	var res := AnimLint.lint_clip(clip)
	var lines := PackedStringArray()
	for f in res:
		lines.append(AnimLint.format(f))
	var text := "%s: %d error(s), %d warning(s)\n%s\n" % [clip.id, AnimLint.error_count(res), res.size() - AnimLint.error_count(res), "\n".join(lines)]
	var p := _out.path_join("%s_lint.txt" % tag)
	var fa := FileAccess.open(p, FileAccess.WRITE)
	fa.store_string(text)
	fa.close()
	print("[sheet] wrote ", p)
