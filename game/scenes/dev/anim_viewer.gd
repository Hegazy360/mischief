## AnimViewer — the animators' bench (TECH §5.3 / §11): pick a rig and a clip (or a pose),
## play / pause / step / scrub, tier 1–3, suppressed, facing flip, residue toggles, tint, and
## watch the clip with an emulated camera punch, shake and hit-stop (so a take feels like it
## will in game). JSON (rig, poses, faces, the clip, reactions) and the rig's SVGs hot-reload
## by mtime every 0.5 s.
##
## User args (after `--`): --rig=_mannequin --clip=rx_take (name or rig/name) --pose=m_stand
##   --tier=1..3 --suppressed --frame=N --paused --facing=-1 --residue=SOAKED[,…] --tint=N
##   --speed=px/s (walks) --once (no auto-replay) --clean (character + floor only, for mute
##   GIFs) --blips (a short beep per sfx / voice event, so captures carry sync onsets)
##   --no-juice (no camera punch / shake).
## Screenshot: tools/scripts/shot.sh res://scenes/dev/AnimViewer.tscn out.png 60 rig -- --clip=loco_walk
extends Node2D

const BG_TOP := Color("#2A2342")
const BG_BOT := Color("#4B3F6B")
const FLOOR := Color("#C98B55")
const FLOOR_DARK := Color("#A96C3C")
const INK := Color("#1B2340")
const PANEL := Color(0.08, 0.07, 0.13, 0.82)
const TEXT := Color("#F4EFE3")
const DIM := Color("#B9B2CF")
const KEY_COL := Color("#FF5A6B")
const HOLD_COL := Color("#5B8CFF")
const FONT_SIZE := 30
const REPLAY_PAUSE_F := 45.0

var rig_id: String = "_mannequin"
var clip_id: String = ""
var pose_name: String = ""
var tier: int = 1
var suppressed: bool = false
var facing: int = 1
var clean: bool = false
var once: bool = false
var blips: bool = false
var juice: bool = true
var walk_speed: float = -1.0

var player: RigPlayer
var _cam: Camera2D
var _stage: Node2D
var _painter: _Painter
var _ui: CanvasLayer
var _root_ui: Control
var _title: Label
var _info: Label
var _ticker: Label
var _status: Label
var _timeline: _Timeline
var _rig_opt: OptionButton
var _clip_opt: OptionButton
var _pose_opt: OptionButton
var _play_btn: Button
var _tier_btns: Array[Button] = []
var _sup_btn: Button
var _res_btns: Array[Button] = []
var _paused: bool = false
var _hold_left: float = -1.0
var _ticker_lines: PackedStringArray = PackedStringArray()
var _mtimes: Dictionary = {}
var _reload_t: float = 0.0
var _zoom_seq: Array = []      ## [in_f, hold_f, out_f, zoom, t]
var _trauma: float = 0.0
var _shake_t: float = 0.0
var _blip_player: AudioStreamPlayer
var _blip_cache: Dictionary = {}
var _feet_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_parse_args()
	RenderingServer.set_default_clear_color(BG_TOP)
	_painter = _Painter.new()
	_painter.viewer = self
	add_child(_painter)
	_stage = Node2D.new()
	add_child(_stage)
	player = RigPlayer.new()
	player.self_hitstop = true
	_stage.add_child(player)
	player.clip_event.connect(_on_event)
	player.clip_finished.connect(_on_finished)
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_blip_player = AudioStreamPlayer.new()
	add_child(_blip_player)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_load_rig(rig_id)
	_layout()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rig="):
			rig_id = a.substr(6)
		elif a.begins_with("--clip="):
			clip_id = a.substr(7)
		elif a.begins_with("--pose="):
			pose_name = a.substr(7)
		elif a.begins_with("--tier="):
			tier = clampi(int(a.substr(7)), 1, 3)
		elif a == "--suppressed":
			suppressed = true
		elif a.begins_with("--facing="):
			facing = -1 if int(a.substr(9)) < 0 else 1
		elif a == "--clean":
			clean = true
		elif a == "--once":
			once = true
		elif a == "--blips":
			blips = true
		elif a == "--no-juice":
			juice = false
		elif a == "--paused":
			_paused = true
		elif a.begins_with("--speed="):
			walk_speed = float(a.substr(8))


func _arg(name: String, fallback: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return fallback


# --- loading -------------------------------------------------------------------------------

func _load_rig(id: String) -> void:
	rig_id = id
	player.setup(id)
	if player.rig == null:
		_set_status("rig '%s' not found" % id)
		return
	player.set_facing(facing, false)
	for kind in _arg("residue").split(",", false):
		player.set_residue(kind, true)
	player.set_tint_tier(int(_arg("tint", "0")))
	_fill_rig_menu()
	_fill_clip_menu()
	_fill_residues()
	_snapshot_mtimes()
	if pose_name != "" and player.poses.has_pose(pose_name):
		_show_pose(pose_name)
		return
	var cid := clip_id
	if cid == "":
		var list := ClipLib.list(id)
		cid = list[0] if not list.is_empty() else ""
		for c in list:
			if c.ends_with("/loco_idle"):
				cid = c
	elif not cid.contains("/"):
		cid = id + "/" + cid
	if cid != "":
		_play(cid, int(_arg("frame", "0")))


func _play(cid: String, start: int = 0) -> void:
	clip_id = cid
	pose_name = ""
	_hold_left = -1.0
	var opts := {"tier": tier, "suppressed": suppressed, "blend_in": 0, "seed": 1}
	if walk_speed > 0.0:
		opts["speed"] = walk_speed
	player.props.reset()
	player.springs.reset()
	player.play(cid, opts)
	player.manual = true
	player.paused = false
	player.advance(0.0)
	_replay(start)
	player.manual = false
	player.paused = _paused
	_zoom_seq.clear()
	_trauma = 0.0
	_ticker_lines = PackedStringArray()
	_update_info()
	_select_clip_item(cid)
	_snapshot_mtimes()


func _show_pose(pn: String) -> void:
	pose_name = pn
	player.set_static_pose(player.poses.pose(pn))
	player.advance(0.0)
	_update_info()


## Seek to timeline frame `f` by replaying deterministically from 0 (springs, props, smears
## end up exactly as in a straight playthrough).
func seek(f: float) -> void:
	if clip_id == "" or pose_name != "":
		return
	var was := _paused
	_play(clip_id, 0)
	player.manual = true
	var target := clampf(f, 0.0, float(player.clip_length()))
	_replay(int(target))
	player.manual = false
	_paused = was
	player.paused = was


## Advance `n` frames with the self-hitstop off, so frame N of a seek is frame N of the clip
## (a hitstop would otherwise freeze the replay and land a few frames short).
func _replay(n: int) -> void:
	var hs := player.self_hitstop
	player.self_hitstop = false
	for i in n:
		player.advance(1.0 / 60.0)
	player.self_hitstop = hs


# --- per frame -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_reload_t += delta
	if _reload_t >= 0.5:
		_reload_t = 0.0
		_check_reload()
	if _hold_left >= 0.0 and not _paused:
		_hold_left -= delta * 60.0
		if _hold_left < 0.0 and clip_id != "":
			_play(clip_id, 0)
	_update_camera(delta)
	if _timeline != null:
		_timeline.queue_redraw()
	if _info != null and Engine.get_process_frames() % 4 == 0:
		_update_info()


func _update_camera(delta: float) -> void:
	var vs := get_viewport_rect().size
	var base := vs * 0.5
	var zoom := 1.0
	if juice and not _zoom_seq.is_empty():
		var z: Array = _zoom_seq
		z[4] = float(z[4]) + delta * 60.0 * player.time_scale * (0.05 if player._hitstop_f > 0.0 else 1.0)
		var t: float = z[4]
		var zin: float = z[0]
		var zh: float = z[1]
		var zo: float = z[2]
		var target: float = z[3]
		if t < zin:
			zoom = lerpf(1.0, target, RigEase.apply(RigEase.id("out_cubic"), t / maxf(1.0, zin)))
		elif t < zin + zh:
			zoom = target
		elif t < zin + zh + zo:
			zoom = lerpf(target, 1.0, RigEase.apply(RigEase.id("in_out_sine"), (t - zin - zh) / maxf(1.0, zo)))
		else:
			_zoom_seq.clear()
	var head := player.part_global_position("head") if player.rig != null else _stage.position
	var focus := base.lerp(head, clampf((zoom - 1.0) * 2.0, 0.0, 1.0))
	var off := Vector2.ZERO
	if juice and _trauma > 0.0:
		_shake_t += delta
		var s := 12.0 * _trauma * _trauma
		off = Vector2(sin(_shake_t * 157.0) * s, cos(_shake_t * 131.0) * s)
		_trauma = maxf(0.0, _trauma - 1.5 * delta)
	_cam.position = focus + off
	_cam.zoom = Vector2(zoom, zoom)


func _on_event(e: Dictionary) -> void:
	var t := String(e.get("type", ""))
	var label := _event_label(e)
	_ticker_lines.append("f%-4d %s" % [int(e.get("f", 0)), label])
	while _ticker_lines.size() > 9:
		_ticker_lines.remove_at(0)
	match t:
		"cam":
			if String(e.get("op", "")) == "punch":
				_zoom_seq = [float(e.get("in", 6)), float(e.get("hold", 30)), float(e.get("out", 20)), float(e.get("zoom", 1.2)), 0.0]
		"shake":
			_trauma = minf(1.0, _trauma + float(e.get("trauma", 0.3)))
		"sfx", "voice":
			if blips:
				_blip(String(e.get("id", e.get("bank", t))), t == "voice")


func _on_finished(id: String) -> void:
	if id == clip_id and not once and _queued_beat() == "":
		_hold_left = REPLAY_PAUSE_F


func _queued_beat() -> String:
	return player._queue_clip


static func _event_label(e: Dictionary) -> String:
	var t := String(e.get("type", ""))
	match t:
		"sfx":
			return "sfx %s" % e.get("id", "")
		"voice":
			return "voice %s" % e.get("bank", e.get("vocal", ""))
		"mark":
			return "mark %s" % e.get("name", "")
		"cam":
			return "cam %s ×%s" % [e.get("op", ""), e.get("zoom", "")]
		"hitstop":
			return "hitstop %d f" % int(e.get("frames", 0))
		"shake":
			return "shake %s" % e.get("trauma", "")
		"prop":
			return "prop %s %s" % [e.get("op", ""), e.get("prop", "")]
		"laugh":
			return "laugh %s" % e.get("tier", "")
		"spring":
			return "spring %s %s" % [e.get("part", ""), e.get("kick", "")]
		"fx":
			return "fx %s" % e.get("id", "")
	return t


func _blip(id: String, low: bool) -> void:
	var key := "%s|%s" % [id, low]
	var st: AudioStreamWAV = _blip_cache.get(key, null)
	if st == null:
		var rate := 22050
		var n := int(rate * 0.07)
		var data := PackedByteArray()
		data.resize(n * 2)
		var hz := (220.0 if low else 660.0) * pow(2.0, float(hash(id) % 12) / 12.0)
		for i in n:
			var env := exp(-float(i) / float(n) * 5.0)
			var v := int(clampf(sin(TAU * hz * float(i) / float(rate)) * env * 0.8, -1.0, 1.0) * 32767.0)
			data.encode_s16(i * 2, v)
		st = AudioStreamWAV.new()
		st.format = AudioStreamWAV.FORMAT_16_BITS
		st.mix_rate = rate
		st.data = data
		_blip_cache[key] = st
	_blip_player.stream = st
	_blip_player.play()


# --- hot reload --------------------------------------------------------------------------------

func _watched() -> PackedStringArray:
	var out := PackedStringArray()
	var rd := "%s/rigs/%s" % [RigDef.data_root, rig_id]
	for f in ["rig.json", "poses.json", "faces.json"]:
		out.append(rd.path_join(f))
	out.append("%s/anim/%s/reactions.json" % [RigDef.data_root, rig_id])
	if clip_id != "":
		out.append(ClipLib.path_of(clip_id))
	if player.rig != null:
		out.append_array(player.rig.all_texture_paths(player.skin))
	return out


func _snapshot_mtimes() -> void:
	_mtimes.clear()
	for p in _watched():
		_mtimes[p] = FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1


func _check_reload() -> void:
	var changed := PackedStringArray()
	for p in _watched():
		var mt := FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1
		if int(_mtimes.get(p, -2)) != mt:
			changed.append(p.get_file())
	if changed.is_empty():
		return
	var art := false
	for c in changed:
		if c.ends_with(".svg"):
			art = true
	RigDef.invalidate(rig_id)
	PoseLib.invalidate(rig_id)
	ClipLib.invalidate()
	ReactionTable.invalidate()
	if art:
		AtlasBuilder.clear()
		AtlasBuilder.clear_svg_sizes()
		HiResTex.clear()
	var f := player.current_frame()
	var pn := pose_name
	player.setup(rig_id)
	player.set_facing(facing, false)
	_fill_clip_menu()
	if pn != "":
		_show_pose(pn)
	elif clip_id != "":
		seek(f)
	_snapshot_mtimes()
	_set_status("reloaded %s (%s)" % [", ".join(changed), Time.get_time_string_from_system()])


# --- UI --------------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	_root_ui = Control.new()
	_root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = FONT_SIZE
	_root_ui.theme = th
	_ui.add_child(_root_ui)
	_root_ui.visible = not clean
	_title = _mk_label("", 36, TEXT)
	_root_ui.add_child(_title)
	_rig_opt = OptionButton.new()
	_rig_opt.item_selected.connect(func(i: int) -> void: _load_rig(_rig_opt.get_item_text(i)))
	_root_ui.add_child(_rig_opt)
	_clip_opt = OptionButton.new()
	_clip_opt.item_selected.connect(func(i: int) -> void: _play(_clip_opt.get_item_text(i)))
	_root_ui.add_child(_clip_opt)
	_pose_opt = OptionButton.new()
	_pose_opt.item_selected.connect(func(i: int) -> void:
		if i > 0:
			_show_pose(_pose_opt.get_item_text(i)))
	_root_ui.add_child(_pose_opt)
	_info = _mk_label("", 24, TEXT)
	_root_ui.add_child(_info)
	_ticker = _mk_label("", 22, DIM)
	_root_ui.add_child(_ticker)
	_status = _mk_label("", 20, DIM)
	_root_ui.add_child(_status)
	_timeline = _Timeline.new()
	_timeline.viewer = self
	_root_ui.add_child(_timeline)
	_play_btn = _mk_button("▶" if _paused else "❚❚", func() -> void: _toggle_pause())
	_mk_button("⟲", func() -> void: seek(0.0))
	_mk_button("◀", func() -> void:
		_set_paused(true)
		seek(maxf(0.0, player.current_frame() - 1.0)))
	_mk_button("▶", func() -> void:
		_set_paused(true)
		seek(player.current_frame() + 1.0))
	for t in 3:
		var tb := _mk_button("T%d" % (t + 1), func() -> void:
			tier = t + 1
			_play(clip_id))
		tb.toggle_mode = true
		_tier_btns.append(tb)
	_sup_btn = _mk_button("SUP", func() -> void:
		suppressed = not suppressed
		_play(clip_id))
	_sup_btn.toggle_mode = true
	_mk_button("FLIP", func() -> void:
		facing = -facing
		player.set_facing(facing, true))


func _mk_label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


var _buttons: Array[Button] = []


func _mk_button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 88)
	b.pressed.connect(fn)
	_root_ui.add_child(b)
	_buttons.append(b)
	return b


func _fill_rig_menu() -> void:
	_rig_opt.clear()
	var d := DirAccess.open("%s/rigs" % RigDef.data_root)
	var ids := PackedStringArray()
	if d != null:
		for n in d.get_directories():
			if FileAccess.file_exists("%s/rigs/%s/rig.json" % [RigDef.data_root, n]):
				ids.append(n)
	ids.sort()
	for i in ids.size():
		_rig_opt.add_item(ids[i])
		if ids[i] == rig_id:
			_rig_opt.select(i)


func _fill_clip_menu() -> void:
	_clip_opt.clear()
	for c in ClipLib.list(rig_id):
		_clip_opt.add_item(c)
	_select_clip_item(clip_id)
	_pose_opt.clear()
	_pose_opt.add_item("pose…")
	if player.poses != null:
		for pn in player.poses.names:
			_pose_opt.add_item(pn)


func _select_clip_item(cid: String) -> void:
	for i in _clip_opt.item_count:
		if _clip_opt.get_item_text(i) == cid:
			_clip_opt.select(i)


func _fill_residues() -> void:
	for b in _res_btns:
		_buttons.erase(b)
		b.queue_free()
	_res_btns.clear()
	if player.rig == null:
		return
	var kinds := PackedStringArray(player.rig.residues.keys())
	kinds.sort()
	for k in kinds:
		var kind := String(k)
		var b := _mk_button(kind.substr(0, 4), func() -> void: pass)
		b.toggle_mode = true
		b.set_pressed_no_signal(player.has_residue(kind))
		b.toggled.connect(func(on: bool) -> void: player.set_residue(kind, on))
		_res_btns.append(b)
	_layout()


func _toggle_pause() -> void:
	_set_paused(not _paused)


func _set_paused(on: bool) -> void:
	_paused = on
	player.paused = on
	_play_btn.text = "▶" if on else "❚❚"


func _set_status(t: String) -> void:
	if _status != null:
		_status.text = t


func _layout() -> void:
	var vs := get_viewport_rect().size
	_feet_pos = Vector2(vs.x * (0.34 if not clean else 0.5), vs.y * (0.72 if not clean else 0.84))
	_stage.position = _feet_pos
	if _root_ui == null:
		return
	var m := 24.0
	var px := vs.x * 0.62
	_title.position = Vector2(m, m)
	_rig_opt.position = Vector2(px, 84)
	_rig_opt.custom_minimum_size = Vector2(250, 72)
	_clip_opt.position = Vector2(px + 262, 84)
	_clip_opt.custom_minimum_size = Vector2(420, 72)
	_pose_opt.position = Vector2(px + 694, 84)
	_pose_opt.custom_minimum_size = Vector2(minf(260.0, vs.x - px - 694 - m), 72)
	_info.position = Vector2(px, 176)
	_info.size = Vector2(vs.x - px - m, 0)
	_ticker.position = Vector2(px, vs.y * 0.5)
	_status.position = Vector2(m, vs.y - 40)
	_timeline.position = Vector2(m, vs.y - 236)
	_timeline.size = Vector2(vs.x - 2.0 * m, 110)
	var bx := m
	var by := vs.y - 116
	for b in _buttons:
		b.position = Vector2(bx, by)
		b.size = b.custom_minimum_size
		bx += b.custom_minimum_size.x + 12.0


func _update_info() -> void:
	if player.rig == null:
		return
	for t in _tier_btns.size():
		_tier_btns[t].button_pressed = tier == t + 1
	_sup_btn.button_pressed = suppressed
	if pose_name != "":
		_title.text = "AnimViewer — %s · pose %s" % [rig_id, pose_name]
		var tg := ", ".join(player.poses.tags_of(pose_name))
		_info.text = "pose %s\ntags: %s\nface: %s\n%s" % [pose_name, tg, player.poses.face_of(pose_name), player.poses.silhouettes.get(pose_name, "")]
		_ticker.text = ""
		return
	var plan := player.plan()
	if plan == null:
		return
	var c := plan.clip
	_title.text = "AnimViewer — %s" % c.id
	var lines := PackedStringArray()
	lines.append("frame %.1f / %d%s" % [player.current_frame(), plan.length, "  (loop)" if plan.loop else ""])
	lines.append("tier %d%s%s" % [plan.tier, "  suppressed" if plan.suppressed else "", "  → " + plan.last_beat.get_file() if plan.last_beat != "" else ""])
	var bl := PackedStringArray()
	for bn in c.beats:
		var b: Vector2i = c.beats[bn]
		bl.append("%s %d–%d" % [bn, plan.timeline_frame(b.x), plan.timeline_frame(b.y)])
	if not bl.is_empty():
		lines.append(", ".join(bl))
	if c.stride_px > 0.0:
		lines.append("stride %d px / %d f = %.0f px/s natural" % [int(c.stride_px), c.length, c.stride_px / (float(c.length) / 60.0)])
	lines.append("keys %d · events %d · blend in %d / out %d%s" % [c.key_f.size(), plan.events.size(), c.blend_in, c.blend_out, "  · plant" if c.plant else ""])
	lines.append("playing: %s" % player.current_clip().get_file())
	_info.text = "\n".join(lines)
	_ticker.text = "events\n" + "\n".join(_ticker_lines)


## Background, floor and a 100 px grid (world space).
class _Painter extends Node2D:
	var viewer: Node2D

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var vs: Vector2 = viewer.get_viewport_rect().size
		var feet: Vector2 = viewer._feet_pos
		var big := Rect2(-vs.x, -vs.y, vs.x * 3.0, vs.y * 3.0)
		draw_rect(big, BG_TOP)
		var steps := 12
		for i in steps:
			var t := float(i) / float(steps)
			draw_rect(Rect2(big.position.x, feet.y - vs.y + vs.y * t, big.size.x, vs.y / float(steps) + 1.0), BG_TOP.lerp(BG_BOT, t))
		for gx in range(-10, 30):
			var x := feet.x + float(gx) * 100.0
			draw_line(Vector2(x, feet.y - vs.y), Vector2(x, feet.y), Color(1, 1, 1, 0.05), 2.0)
		for gy in range(1, 10):
			var y := feet.y - float(gy) * 100.0
			draw_line(Vector2(big.position.x, y), Vector2(big.end.x, y), Color(1, 1, 1, 0.05), 2.0)
		draw_rect(Rect2(big.position.x, feet.y, big.size.x, vs.y), FLOOR)
		draw_rect(Rect2(big.position.x, feet.y, big.size.x, 14), FLOOR_DARK)
		draw_line(Vector2(big.position.x, feet.y), Vector2(big.end.x, feet.y), INK, 4.0)
		# Contact shadow under the character.
		var pl: RigPlayer = viewer.player
		var sx: float = pl.position.x + feet.x
		draw_set_transform(Vector2(sx, feet.y + 4), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, 90.0, Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The scrub bar: beats, keys, events, playhead. Click / drag to scrub.
class _Timeline extends Control:
	var viewer: Node2D

	func _gui_input(ev: InputEvent) -> void:
		var pos := Vector2.INF
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			pos = (ev as InputEventMouseButton).position
		elif ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			pos = (ev as InputEventMouseMotion).position
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			pos = (ev as InputEventScreenTouch).position
		elif ev is InputEventScreenDrag:
			pos = (ev as InputEventScreenDrag).position
		if pos != Vector2.INF:
			var plan: PlayPlan = viewer.player.plan()
			if plan != null:
				viewer._set_paused(true)
				viewer.seek(clampf(pos.x / size.x, 0.0, 1.0) * float(plan.length))
			accept_event()

	func _draw() -> void:
		var plan: PlayPlan = viewer.player.plan()
		draw_rect(Rect2(Vector2.ZERO, size), PANEL)
		if plan == null:
			return
		var ln := float(maxi(1, plan.length))
		var c := plan.clip
		var font := get_theme_default_font()
		var cols := {"anticipation": Color("#F2B33D"), "accent": KEY_COL, "hold": HOLD_COL, "settle": Color("#2FA39A")}
		for bn in c.beats:
			var b: Vector2i = c.beats[bn]
			var x0 := size.x * float(plan.timeline_frame(b.x)) / ln
			var x1 := size.x * float(plan.timeline_frame(b.y)) / ln
			draw_rect(Rect2(x0, 6, maxf(2.0, x1 - x0), 40), Color(cols.get(bn, Color("#9A8FB0")), 0.8))
			draw_string(font, Vector2(x0 + 6, 36), String(bn), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
		if plan.tail != null:
			var xt := size.x * float(plan.tail_start) / ln
			draw_rect(Rect2(xt, 6, size.x - xt, 40), Color("#7A5CA0", 0.8))
			draw_string(font, Vector2(xt + 6, 36), "suppressed", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT)
		for k in c.key_f:
			var xk := size.x * float(plan.timeline_frame(k)) / ln
			draw_line(Vector2(xk, 50), Vector2(xk, 78), KEY_COL, 3.0)
		for e in plan.ev_f:
			draw_circle(Vector2(size.x * float(e) / ln, 92), 5.0, TEXT)
		var pl: RigPlayer = viewer.player
		var xp: float = size.x * pl.current_frame() / ln
		draw_line(Vector2(xp, 0), Vector2(xp, size.y), Color.WHITE, 4.0)
		draw_string(font, Vector2(minf(xp + 8, size.x - 120), size.y - 6), "f %d" % int(pl.current_frame()), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
