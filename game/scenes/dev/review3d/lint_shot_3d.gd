## LintShot3D — the render passes the set lint and the screen-rect boards measure (brief r3d-tools-b §4.6, TECH §11.1).
##
##   tools/scripts/shot.sh res://scenes/dev/review3d/LintShot3D.tscn out.png 999999 r3d-tools-b -- \
##     --episode=<id> --room=<room> [--aspect=20x9|16x9|4x3] --pass=beauty|id|mask:<hotspot>|rects [--chars] [--x=<m>]
##     [--legend=/abs.json] [--out=/abs.png]
##   … -- --batch=all [--night=<id>,…] --out-dir=/abs/dir [--passes=beauty,id,mask,rects] [--aspects=20x9,16x9,4x3]
##
## Every job renders into its own SubViewport (height 540, width by aspect: 1200 / 960 / 720 — a 1200 × 540 phone
## shot at 20:9) through `House3D` (static merge off, so beauty and ID are pixel-aligned) + `CameraDirector3D` (the base
## framing: Hush's C1 framing of the room at the aspect's logical size, the C6 safe rect of a punch-hole phone at 20:9)
## + `RigPlayer3D` for the characters (Hush and Bellows idling on the lane, left and right of the room centre).
## Room light levels: the framed room 1.0, the other lit rooms 0.78 + 40 % desaturation, backstage 0.3 (§7.6).
## * `beauty` — the shaded frame (verb glow off, so a prop's measured colour is its own).
## * `id` — flat unshaded ID colours per region (walls, wainscot, floors per room; every live prop, furniture piece,
##   dressing / decor piece; the stage; each character) and the legend JSON `lab.py regions` reads: framed-room walls
##   `wall`, dimmed lit neighbours `wall` + `"lit": false` (their wainscot `wainscot_dim`), backstage `wall_backstage`
##   (info); live props `live_prop` (+ `"halo": true` when the prop has its verb-halo shell); neighbours' props
##   `live_prop_neighbour`; furniture `furniture`; dressing `dressing` (+ `wall`, the lamp shade `exempt` as the light
##   source); characters `character`.
## * `mask:<hotspot>` — that live prop alone, black on transparent, seen from the game camera's direction and framed to
##   fill the height (sil64.py normalises it to 64 px); a merged prop (the fridge's two zones) is one mask.
## * `rects` — the beauty frame with every live hit box (projected, labelled W×H logical px), the always-on HUD rects,
##   the Bellows window and the safe rect drawn over it, at the room's worst framing (the most screen-rect issues).
## Batch mode writes `<out-dir>/manifest.json` {jobs: [{night, room, pass, aspect, png, legend?, hotspot?, cam_x}]}
## and quits; `--shot` (shot.sh's out) receives the last frame.
extends Node

const RIG_SCRIPT := "res://view3d/char/rig_player_3d.gd"
const PALETTES := "res://art3d/set/palettes.json"
const SHOT_H := 540
const WIDTHS := {"20x9": 1200, "16x9": 960, "4x3": 720}
const CLEAR := Color(0, 0, 0, 0)
const MASK_FILL := 0.8
## Where the characters stand relative to the room centre (m): Hush left on the lane, Bellows right at his depth.
const HUSH_DX := -1.1
const BELLOWS_DX := 1.1

var args: Dictionary = {}
var db: ContentDB = null
var _house: House3D = null
var _res: SetList.Result = null
var _episode_id := ""
var _chars: Dictionary = {}
var _vp: SubViewport = null
var _cam: CameraDirector3D = null
var _env: WorldEnvironment = null
var _overlay: _RectsOverlay = null
var _manifest: Array = []
var _last := ""
var _palettes: Dictionary = {}
var _grid := 16
var _cell_px := 16


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	db = ContentDB.load_dir("res://data")
	var pj: Variant = Lint3D.read_json(PALETTES)
	if pj is Dictionary:
		_palettes = (pj as Dictionary).get("palettes", {})
		_grid = int((pj as Dictionary).get("grid", 16))
		_cell_px = int((pj as Dictionary).get("cell_px", 16))
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var jobs := _jobs()
	for j in jobs:
		var jt := Time.get_ticks_msec()
		var ok: bool = await _do(j)
		print("[LintShot3D] %s %s %s %s%s -> %s (%d ms)" % [j.get("night", ""), j.get("room", ""), j.get("pass", ""),
			j.get("aspect", ""), (" " + String(j.get("hotspot", ""))) if j.has("hotspot") else "", "ok" if ok else "FAILED",
			Time.get_ticks_msec() - jt])
	if args.has("out-dir"):
		Lint3D.write_json(String(args["out-dir"]).path_join("manifest.json"), {"jobs": _manifest,
			"ms": Time.get_ticks_msec() - t0})
	var shot := String(args.get("shot", ""))
	if shot != "" and _last != "":
		var img := Image.load_from_file(_last)
		if img != null:
			img.save_png(shot)
	print("[LintShot3D] %d job(s) in %d ms" % [jobs.size(), Time.get_ticks_msec() - t0])
	get_tree().quit(0)


# --- jobs ---------------------------------------------------------------------------------------------

func _jobs() -> Array:
	var out: Array = []
	if String(args.get("batch", "")) == "":
		var j := {"night": String(args.get("episode", "p00_curtain_up")), "room": String(args.get("room", "kitchen")),
			"aspect": String(args.get("aspect", "20x9")), "pass": String(args.get("pass", "beauty")), "chars": args.has("chars"),
			"out": String(args.get("out", args.get("shot", "")))}
		if args.has("x"):
			j["x"] = float(args["x"])
		if String(j["pass"]).begins_with("mask:"):
			j["hotspot"] = String(j["pass"]).substr(5)
			j["pass"] = "mask"
		if args.has("legend"):
			j["legend"] = String(args["legend"])
		out.append(j)
		return out
	var dir := String(args.get("out-dir", "/tmp/lintshot3d"))
	var passes := PackedStringArray(String(args.get("passes", "beauty,id,mask,rects")).split(","))
	var aspects := PackedStringArray(String(args.get("aspects", "20x9,16x9,4x3")).split(","))
	var nights := Lint3D.NIGHTS if String(args.get("night", "all")) == "all" else PackedStringArray(String(args["night"]).split(","))
	for ep_id in nights:
		var ep: EpisodeDef = db.episodes.get(ep_id, null)
		if ep == null:
			continue
		var res := SetList.for_episode(db, ep)
		for rid in res.rooms_lit:
			var live := res.live_props_in(rid)
			if live.is_empty():
				continue
			var base := dir.path_join(Lint3D.label(ep_id)).path_join(rid)
			if passes.has("beauty"):
				out.append({"night": ep_id, "room": rid, "aspect": "20x9", "pass": "beauty", "chars": true, "out": base + "_beauty.png"})
			if passes.has("id"):
				out.append({"night": ep_id, "room": rid, "aspect": "20x9", "pass": "id", "chars": true, "out": base + "_id.png",
					"legend": base + "_id.json"})
			if passes.has("mask"):
				var hosts := {}
				for hid in live:
					var e: Dictionary = (SetGeo.load_house3d().get("hotspots", {}) as Dictionary).get(hid, {})
					var key := SetGeo.s(e.get("merge", "")) if SetGeo.s(e.get("merge", "")) != "" else hid
					if hosts.has(key):
						continue
					hosts[key] = true
					out.append({"night": ep_id, "room": rid, "aspect": "20x9", "pass": "mask", "hotspot": hid, "chars": false,
						"out": base + "_masks/%s.png" % hid})
			if passes.has("rects"):
				for asp in aspects:
					out.append({"night": ep_id, "room": rid, "aspect": asp, "pass": "rects", "chars": false,
						"out": base + "_rects_%s.png" % asp})
	return out


func _do(j: Dictionary) -> bool:
	var ep_id := String(j["night"])
	if ep_id != _episode_id or _house == null:
		if not _build(ep_id):
			return false
	var aspect := String(j.get("aspect", "20x9"))
	var room := String(j["room"])
	_setup_viewport(aspect, String(j["pass"]) == "mask")
	_lights(room)
	var hud := ScreenRectLint3D.hud_rects(db.episodes[ep_id], aspect)
	_cam.set_safe_rect(hud["safe"])
	var cam_x := _frame_room(room, j, hud)
	_place_chars(room, bool(j.get("chars", false)))
	var restore: Array = []
	match String(j["pass"]):
		"id":
			restore = _apply_id(room, String(j.get("legend", "")))
		"mask":
			restore = _apply_mask(String(j.get("hotspot", "")))
			if restore.is_empty():
				return false
		"rects":
			_overlay.visible = true
			_overlay.setup(self, room, hud, aspect)
	_set_glow(String(j["pass"]) == "rects")
	for _i in 3:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	_overlay.visible = false
	_undo(restore)
	var path := String(j.get("out", ""))
	if path == "":
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	_last = path
	var row := {"night": ep_id, "room": room, "pass": j["pass"], "aspect": aspect, "png": path, "cam_x": cam_x}
	if j.has("legend"):
		row["legend"] = j["legend"]
	if j.has("hotspot"):
		row["hotspot"] = j["hotspot"]
	if String(j["pass"]) == "rects":
		row["rects"] = _overlay.last_rects
	_manifest.append(row)
	return true


# --- the stage ------------------------------------------------------------------------------------------

func _build(ep_id: String) -> bool:
	var ep: EpisodeDef = db.episodes.get(ep_id, null)
	if ep == null:
		printerr("[LintShot3D] unknown episode %s" % ep_id)
		return false
	if _vp == null:
		_vp = SubViewport.new()
		_vp.own_world_3d = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vp.msaa_3d = Viewport.MSAA_DISABLED
		add_child(_vp)
		_env = WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = View3DConst.BG
		env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_env.environment = env
		_vp.add_child(_env)
		_cam = CameraDirector3D.new()
		_vp.add_child(_cam)
		# driven by the jobs only (its own _process would keep following / drifting between the framing and the capture)
		_cam.set_process(false)
		_cam.current = true
		var cl := CanvasLayer.new()
		_vp.add_child(cl)
		_overlay = _RectsOverlay.new()
		_overlay.visible = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(_overlay)
	if _house != null:
		_house.free()
		for c in _chars.values():
			(c as Node).free()
		_chars.clear()
	_res = SetList.for_episode(db, ep)
	_house = House3D.new()
	_house.merge_static = false
	_vp.add_child(_house)
	_house.build(_res, {}, db)
	_cam.setup(db, _res)
	_episode_id = ep_id
	return true


func _setup_viewport(aspect: String, mask: bool) -> void:
	_vp.size = Vector2i(int(WIDTHS.get(aspect, 1200)), SHOT_H)
	_vp.transparent_bg = mask
	_cam.logical_size_override = View3DConst.logical_size(aspect)
	(_env.environment as Environment).background_mode = Environment.BG_CLEAR_COLOR if mask else Environment.BG_COLOR
	_overlay.size = Vector2(_vp.size)


func _lights(room: String) -> void:
	for rid in _res.rooms_lit:
		if rid == room:
			_house.snap_room_light(rid, View3DConst.LIGHT_HUSH, 0.0)
		else:
			_house.snap_room_light(rid, View3DConst.LIGHT_OTHER, View3DConst.DESAT_OTHER)
	for rid in _res.rooms_backstage:
		_house.snap_room_light(rid, View3DConst.LIGHT_BACKSTAGE, 0.0)


## The room's base framing (Hush at the room centre, walking right) or the given camera x, or (rects) the framing
## with the most screen-rect issues. Returns the camera x.
func _frame_room(room: String, j: Dictionary, hud: Dictionary) -> float:
	var rd := db.house.room(room)
	var cx := (float(rd.x0) + float(rd.x1)) / (2.0 * View3DConst.PX_PER_M)
	var target := Node3D.new()
	var keep: Array = []
	var boxes := {}
	for id in _res.live.keys():
		boxes[String(id)] = _house.hotspot_box(String(id))
		if _res.room_of(String(id)) == room and not (String(_res.live[id]) in ["door", "stairs", "exit"]):
			keep.append(boxes[String(id)])
	_cam.set_keep_visible(func() -> Array: return keep)
	var hx := cx
	var lead := 1.0
	if String(j["pass"]) == "rects" and not j.has("x"):
		var frames := ScreenRectLint3D.sweep(_cam, rd, boxes, keep)
		var ids := _res.live_props_in(room)
		for id in _res.live.keys():
			if _res.room_of(String(id)) == room and not ids.has(String(id)):
				ids.append(String(id))
		var best := -1
		var best_d := INF
		var view := Rect2(Vector2.ZERO, _cam.view_size())
		for fr in frames:
			var n := ScreenRectLint3D.check_frame(_episode_id, room, String(j["aspect"]), fr, ids, view, hud).size()
			var d := absf(float(fr["hush_x"]) - cx)
			if n > best or (n == best and d < best_d):
				best = n
				best_d = d
				hx = float(fr["hush_x"])
				lead = float(fr["lead"])
	ScreenRectLint3D.frame_at(_cam, target, hx, rd.floor, lead)
	if j.has("x"):
		_cam.follow(target, func() -> float: return 0.0)
		target.position.x = float(j["x"])
		_cam.snap_now()
		_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	target.free()
	_cam.follow(null, Callable())
	return snappedf(_cam.aim().x, 0.01)


func _place_chars(room: String, on: bool) -> void:
	if on and _chars.is_empty() and ResourceLoader.exists(RIG_SCRIPT):
		var sc := load(RIG_SCRIPT) as Script
		for who in ["hush", "bellows"]:
			var rp: Node3D = sc.new()
			_vp.add_child(rp)
			if not bool(rp.call("setup", who)):
				rp.free()
				continue
			rp.call("play", "%s/loco_idle" % who)
			_chars[who] = rp
	var rd := db.house.room(room)
	var cx := (float(rd.x0) + float(rd.x1)) / (2.0 * View3DConst.PX_PER_M)
	var fy := View3DConst.floor_y(rd.floor)
	# the two stand on the lane in front of the set where no live prop of the room is behind them (so the colour pass
	# measures the props and the characters apart), near the room centre, ≥ 1.4 m apart, clear of the wing flats
	var hx := cx + HUSH_DX
	var bx := cx + BELLOWS_DX
	if on:
		var facts := SetLint3D.facts_for(db, db.episodes[_episode_id], _house.house3d, _res)
		var rm: Dictionary = (facts["rooms"] as Dictionary).get(room, {})
		var spans: Array = []
		for l in rm.get("live", []):
			var v: AABB = l["visual"]
			spans.append(Vector2(v.position.x, v.end.x))
		var x0 := float(rd.x0) / View3DConst.PX_PER_M + 0.7
		var x1 := float(rd.x1) / View3DConst.PX_PER_M - 0.7
		hx = _best_x(x0, x1, cx, spans, INF, 0.0)
		bx = _best_x(x0, x1, cx, spans, hx, 1.4)
	for who in _chars.keys():
		var rp: Node3D = _chars[who]
		rp.visible = on
		if who == "hush":
			rp.position = Vector3(hx, fy, View3DConst.LANE_Z)
			rp.call("set_facing", 1, false)
		else:
			rp.position = Vector3(bx, fy, View3DConst.BELLOWS_STATION_Z)
			rp.call("set_facing", -1, false)
		if rp.has_method("set_cheat"):
			rp.call("set_cheat", 35.0, 0.0)


## The lane x in [x0, x1] (0.1 m grid) with the fewest live props behind a 0.6 m wide body, then the nearest to the
## centre, at least `min_d` from `other`.
static func _best_x(x0: float, x1: float, cx: float, spans: Array, other: float, min_d: float) -> float:
	var best := cx
	var best_s := INF
	var n := maxi(0, int((x1 - x0) / 0.1))
	for i in n + 1:
		var x := x0 + 0.1 * float(i)
		if other != INF and absf(x - other) < min_d:
			continue
		var sc := 0.1 * absf(x - cx)
		for sp in spans:
			var v: Vector2 = sp
			if x + 0.3 > v.x and x - 0.3 < v.y:
				sc += 1.0
		if sc < best_s:
			best_s = sc
			best = x
	return best


func _set_glow(on: bool) -> void:
	for p in _house.props():
		if p.live:
			p.set_glow(Prop3D.verb_color(p.verb), 1.0 if on else 0.0)


# --- ID pass --------------------------------------------------------------------------------------------

## Flat ID colours + the legend (lab.py regions). Returns the restore list.
func _apply_id(room: String, legend_path: String) -> Array:
	var restore: Array = []
	var legend: Array = []
	var used := {}
	var h3 := _house.house3d
	for rid in _house.rooms_built():
		var shell := _house.room_shell(rid)
		if shell == null:
			continue
		var framed := rid == room
		var backstage := _res.rooms_backstage.has(rid)
		var cells: Array = _palettes.get(rid, [])
		for n in shell.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if shell.from_glb() and not cells.is_empty():
				var img := Image.create(_grid * _cell_px, _grid * _cell_px, false, Image.FORMAT_RGBA8)
				img.fill(_id_region("%s_arch" % rid, "architecture", rid, legend, used))
				for ci in cells.size():
					var reg := _arch_region(rid, String(cells[ci]), framed, backstage)
					var col := _id_region(reg[0], reg[1], rid, legend, used, reg[2])
					img.fill_rect(Rect2i((ci % _grid) * _cell_px, int(ci / _grid) * _cell_px, _cell_px, _cell_px), col)
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_texture = ImageTexture.create_from_image(img)
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				restore.append(_override(mi, m))
				continue
			var nm := String(mi.name)
			var cell := "other"
			if nm == "back_wall":
				cell = "wall"
			elif nm == "wainscot":
				cell = "wainscot"
			elif nm.begins_with("floor_"):
				cell = "floor_a"
			var reg2 := _arch_region(rid, cell, framed, backstage)
			restore.append(_override(mi, _flat(_id_region(reg2[0], reg2[1], rid, legend, used, reg2[2]))))
	for p in _house.props():
		var cls := "furniture"
		var extra := {}
		if p.live:
			cls = "live_prop" if p.room == room else "live_prop_neighbour"
			var has_halo := false
			for c in p.find_children("*_halo", "MeshInstance3D", true, false):
				has_halo = true
			if has_halo and SetGeo.s(p.entry.get("halo", "")) != "":
				extra["halo"] = true
		var col := _id_region(p.hotspot_id, cls, p.room, legend, used, extra)
		restore.append_array(_override_all(p, col))
	var dr3: Dictionary = h3.get("dressing", {})
	var dc3: Dictionary = h3.get("decor", {})
	for pid in _res.dressing + _res.decor + _res.furniture_pieces:
		var d := _house.decor(pid)
		if not (d is Prop3D):
			continue
		var pr := d as Prop3D
		var is_dress := _res.dressing.has(pid) or bool((dc3.get(pid, {}) as Dictionary).get("dressing", false))
		var cls2 := "furniture"
		var extra2 := {}
		if is_dress:
			cls2 = "dressing" if pr.room == room else "dressing_dim"
			extra2["wall"] = pr.room + "_wall"
			var prim := SetGeo.s((dr3.get(pid, dc3.get(pid, {})) as Dictionary).get("primitive", ""))
			if prim == "lamp":
				extra2["exempt"] = "the light source (REDESIGN §3.7)"
		elif _res.decor.has(pid):
			cls2 = "decor"
		restore.append_array(_override_all(pr, _id_region(pid, cls2, pr.room, legend, used, extra2)))
	var stage_col := _id_region("stage", "architecture", "", legend, used)
	for n2 in _house.get_children():
		if String(n2.name) == "Stage":
			for mi2 in n2.find_children("*", "MeshInstance3D", true, false):
				restore.append(_override(mi2, _flat(stage_col)))
	for who in _chars.keys():
		var ch: Node3D = _chars[who]
		if ch.visible:
			restore.append_array(_override_all(ch, _id_region(who, "character", "", legend, used)))
	(_env.environment as Environment).background_color = Color.BLACK
	restore.append({"env_bg": View3DConst.BG})
	if legend_path != "":
		Lint3D.write_json(legend_path, {"regions": legend, "room": room, "night": _episode_id})
	return restore


## [region name, class, extra] of an architecture palette cell.
func _arch_region(rid: String, cell: String, framed: bool, backstage: bool) -> Array:
	var kind := ""
	if cell == "wall":
		kind = "wall"
	elif cell == "wainscot":
		kind = "wainscot"
	elif cell.begins_with("floor_"):
		kind = "floor"
	if kind == "":
		return ["%s_arch" % rid, "architecture", {}]
	if backstage:
		return ["%s_%s" % [rid, kind], "%s_backstage" % kind, {}]
	if framed:
		return ["%s_%s" % [rid, kind], kind, {}]
	if kind == "wainscot":
		return ["%s_wainscot" % rid, "wainscot_dim", {}]
	return ["%s_%s" % [rid, kind], kind, {"lit": false}]


func _id_region(region: String, cls: String, room: String, legend: Array, used: Dictionary, extra: Dictionary = {}) -> Color:
	if used.has(region):
		return used[region]
	var col := id_color(used.size() + 1)
	used[region] = col
	var row := {"color": "#" + col.to_html(false).to_upper(), "name": region, "class": cls}
	if room != "":
		row["room"] = room
	for k in extra.keys():
		row[k] = extra[k]
	legend.append(row)
	return col


## Well-separated 8-bit ID colours that survive the sRGB round trip (5 levels per channel, never black).
static func id_color(i: int) -> Color:
	var lv := [50, 100, 150, 200, 250]
	return Color8(lv[i % 5], lv[int(i / 5.0) % 5], lv[int(i / 25.0) % 5])


# --- mask pass ------------------------------------------------------------------------------------------

## Hides everything but the prop of `hotspot` (black, unshaded) and frames it from the game camera's direction.
func _apply_mask(hotspot: String) -> Array:
	var p := _house.prop(hotspot)
	if p == null:
		printerr("[LintShot3D] no prop for %s" % hotspot)
		return []
	var restore: Array = []
	for c in _vp.get_children():
		if c is Node3D and c != _cam and c != _house:
			restore.append({"node": c, "visible": (c as Node3D).visible})
			(c as Node3D).visible = false
	for c2 in _house.get_children():
		if c2 is Node3D and c2 != p:
			restore.append({"node": c2, "visible": (c2 as Node3D).visible})
			(c2 as Node3D).visible = false
	var black := _flat(Color.BLACK)
	for n in p.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if String(mi.name).ends_with("_ink") or String(mi.name).ends_with("_halo"):
			restore.append({"node": mi, "visible": mi.visible})
			mi.visible = false
		else:
			restore.append(_override(mi, black))
	# frame it: the game camera's direction to the prop, the visual filling MASK_FILL of the height
	var box := p.home_aabb()
	var c3 := box.get_center()
	var from := _cam.global_position
	var dir := (c3 - from).normalized()
	var half := maxf(box.size.y, maxf(box.size.x, box.size.z) * float(SHOT_H) / float(_vp.size.x)) * 0.5
	var d := half / tan(deg_to_rad(_cam.fov * 0.5)) / MASK_FILL + box.size.z * 0.5
	var saved := _cam.global_transform
	restore.append({"cam": saved})
	_cam.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), c3 - dir * d)
	return restore


# --- overrides ------------------------------------------------------------------------------------------

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _override(mi: GeometryInstance3D, m: Material) -> Dictionary:
	var r := {"node": mi, "override": mi.material_override}
	mi.material_override = m
	return r


## Flat colour on every mesh under `root`; ink / halo shells hidden.
func _override_all(root: Node, col: Color) -> Array:
	var out: Array = []
	var m := _flat(col)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if String(mi.name).ends_with("_ink") or String(mi.name).ends_with("_halo"):
			out.append({"node": mi, "visible": mi.visible})
			mi.visible = false
			continue
		out.append(_override(mi, m))
	return out


func _undo(restore: Array) -> void:
	for i in range(restore.size() - 1, -1, -1):
		var r: Dictionary = restore[i]
		if r.has("env_bg"):
			(_env.environment as Environment).background_color = r["env_bg"]
		elif r.has("cam"):
			_cam.global_transform = r["cam"]
		elif r.has("override"):
			(r["node"] as GeometryInstance3D).material_override = r["override"]
		elif r.has("visible"):
			(r["node"] as Node3D).visible = bool(r["visible"])


# --- the rects board overlay ------------------------------------------------------------------------------

class _RectsOverlay:
	extends Control
	var shot: Node = null
	var room := ""
	var hud: Dictionary = {}
	var aspect := "20x9"
	## The drawn rects (logical px) of the last frame: {id: [x, y, w, h]}.
	var last_rects: Dictionary = {}

	func setup(p_shot: Node, p_room: String, p_hud: Dictionary, p_aspect: String) -> void:
		shot = p_shot
		room = p_room
		hud = p_hud
		aspect = p_aspect
		queue_redraw()

	func _draw() -> void:
		if shot == null:
			return
		var cam: CameraDirector3D = shot.get("_cam")
		var house: House3D = shot.get("_house")
		var res: SetList.Result = shot.get("_res")
		var k := size.y / cam.view_size().y
		var font := ThemeDB.fallback_font
		var view := Rect2(Vector2.ZERO, cam.view_size())
		var safe: Rect2 = hud.get("safe", view)
		draw_rect(Rect2(safe.position * k, safe.size * k), Color(1, 1, 1, 0.5), false, 1.0)
		for n in (hud.get("always_on", {}) as Dictionary).keys():
			var r: Rect2 = hud["always_on"][n]
			draw_rect(Rect2(r.position * k, r.size * k), Color(1, 1, 1, 0.22), true)
			draw_rect(Rect2(r.position * k, r.size * k), Color(1, 1, 1, 0.8), false, 1.5)
			draw_string(font, r.position * k + Vector2(4, 14), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
		var pip: Rect2 = hud.get("pip", Rect2())
		if pip.has_area():
			draw_rect(Rect2(pip.position * k, pip.size * k), Color(0.4, 0.9, 1.0, 0.9), false, 2.0)
			draw_string(font, pip.position * k + Vector2(4, 14), "Bellows window", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.4, 0.9, 1.0))
		last_rects.clear()
		var rects := {}
		for id in res.live.keys():
			var r2 := cam.project_aabb(house.hotspot_box(String(id)))
			if r2.intersects(view):
				rects[String(id)] = r2
		var ids := PackedStringArray()
		for id in rects.keys():
			if res.room_of(id) == room:
				ids.append(id)
		var fr := {"cam_x": snappedf(cam.aim().x, 0.01), "rects": rects, "px_per_m_back": cam.px_per_m_at(View3DConst.BACK_WALL_Z)}
		var bad := {}
		for i in ScreenRectLint3D.check_frame("", room, aspect, fr, ids, view, hud):
			var d: Dictionary = i
			if String(d["level"]) == Lint3D.ERROR:
				for s in String(d["subject"]).split("|"):
					bad[s] = true
		for id in rects.keys():
			var r3: Rect2 = rects[id]
			last_rects[id] = [snappedf(r3.position.x, 0.1), snappedf(r3.position.y, 0.1), snappedf(r3.size.x, 0.1), snappedf(r3.size.y, 0.1)]
			var col := Prop3D.verb_color(String(res.live[id]))
			if bad.has(id):
				col = Color(1.0, 0.2, 0.2)
			var rr := Rect2(r3.position * k, r3.size * k)
			draw_rect(rr, Color(col, 0.18 if res.room_of(id) == room else 0.08), true)
			draw_rect(rr, Color(col, 0.95), false, 3.0 if bad.has(id) else 2.0)
			var lbl := "%s %d×%d" % [id.trim_prefix("kitchen_").trim_prefix("parlour_").trim_prefix("hall_"), int(r3.size.x), int(r3.size.y)]
			draw_string(font, rr.position + Vector2(4, 16), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8))
			draw_string(font, rr.position + Vector2(3, 15), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
		draw_string(font, Vector2(8, size.y - 10), "%s  %s  cam x %.2f  (%s)" % [Lint3D.label(String(shot.get("_episode_id"))),
			room, cam.aim().x, aspect], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
