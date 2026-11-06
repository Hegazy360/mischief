## PROTOTYPE 1a — "MISCHIEF RUN": the whole UI for the systems-roguelike prototype.
##
## Rig prank cards onto the six stations of Bellows' routine, then CURTAIN UP and watch the routine
## resolve left to right. Adjacent firings chain, residues stick for the Night, his temper tiers up.
## Every point is shown with the reason it was scored.
##
## Nothing here is art: the whole screen is primitives, two OFL fonts and a palette. There is no cast,
## no house, no animation clip and no sprite — which is exactly the pipeline a one-owner agent team can
## keep up with (docs/review/pivot/2026_options.md).
extends Control

const RUN := preload("res://proto/mischief_run/run.gd")
const CARD_VIEW := preload("res://proto/mischief_run/ui/card_view.gd")

const INK := Color("#0E1328")
const BG := Color("#141A33")
const CREAM := Color("#FFF4E0")
const GOLD := Color("#FFC93C")
const RED := Color("#E23B4E")
const ROOM_COL := {"parlour": Color("#C98A9B"), "kitchen": Color("#E8C86A"), "hall": Color("#8FB09A")}
## Seconds a station takes on screen: a stop where something fires gets the beat, an empty one is
## skipped through, and the end-of-round tally gets a moment to read.
const STEP_FIRED := 0.62
const STEP_EMPTY := 0.13
const STEP_END := 1.25

enum S { PLACE, RESOLVE, DRAFT, NIGHT_END, RUN_END }

var run: Run = null
var state: int = S.PLACE
var _hand_views: Array[CardView] = []
var _sel: int = -1
var _steps: Array = []
var _step_i: int = -1
var _step_t: float = 0.0
var _step_len: float = 0.0
var _flash: Array = []            ## [{text, pos, t, col, size}]
var _draft_views: Array[CardView] = []
var _msg: String = ""
var _msg_t: float = 0.0
var _track: Array[Rect2] = []
var _track_bottom: float = 0.0
var _curtain: Rect2 = Rect2()
var _shake: float = 0.0
var _font_d: Font = null
var _font_b: Font = null
## `--demo` plays itself so the loop can be captured without hands on the screen.
var _demo := false
var _demo_t := 0.0
## See CardView._tap_frame: one click arrives twice (mouse + emulated touch) in the same frame.
var _tap_frame: int = -1


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)
	CardView.load_fonts()
	_font_d = CardView.font_display
	_font_b = CardView.font_body
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	run = RUN.new()
	run.setup(_json("res://proto/mischief_run/data/cards.json"),
		_json("res://proto/mischief_run/data/encores.json"),
		int(Time.get_unix_time_from_system()) & 0x7FFFFFFF)
	_demo = OS.get_cmdline_user_args().has("--demo")
	if OS.get_cmdline_user_args().has("--clicktest"):
		_clicktest.call_deferred()
	get_viewport().size_changed.connect(_layout)
	_rebuild_hand()
	_layout()
	set_process(true)


## Drive the real input path with synthetic clicks and report what actually happened, so "it does not
## react to my clicks" can never be guesswork again.
##   tools/scripts/shot.sh res://proto/mischief_run/MischiefRun.tscn /tmp/x.png 90 proto -- --clicktest
func _clicktest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var fails := 0
	print("[clicktest] viewport=%s  hand=%d  track=%d" % [str(get_viewport_rect().size),
		_hand_views.size(), _track.size()])
	for i in _hand_views.size():
		var v := _hand_views[i]
		print("   [card %d] pos=%s size=%s filter=%d vis=%s top=%s" % [i, str(v.position), str(v.size),
			v.mouse_filter, str(v.visible), str(v.is_inside_tree())])
	print("   [root] size=%s filter=%d  track0=%s" % [str(size), mouse_filter, str(_track[0])])
	if _hand_views.is_empty() or _track.is_empty():
		print("[clicktest] FAIL nothing laid out")
		get_tree().quit(1)
		return
	# 1. tap a card -> it should become the selection
	await _click(_hand_views[0].position + _hand_views[0].size * 0.5)
	print("[clicktest] after card tap: _sel=%d (want 0)" % _sel)
	if _sel != 0:
		fails += 1
	# 2. tap the same card again -> it should deselect
	await _click(_hand_views[0].position + _hand_views[0].size * 0.5)
	print("[clicktest] after second tap: _sel=%d (want -1)" % _sel)
	if _sel != -1:
		fails += 1
	# 3. select, then tap a station -> the prank should be rigged there
	await _click(_hand_views[0].position + _hand_views[0].size * 0.5)
	var nerve_before := run.nerve
	await _click(_track[2].get_center())
	print("[clicktest] after station tap: board[2]='%s' nerve %d->%d" % [run.board[2], nerve_before, run.nerve])
	if run.board[2] == "":
		fails += 1
	# 4. tap the rigged station -> it should come back to the hand
	await _click(_track[2].get_center())
	print("[clicktest] after take-back: board[2]='%s' hand=%d" % [run.board[2], run.hand.size()])
	if run.board[2] != "":
		fails += 1
	# 5. rig one and raise the curtain -> it should start resolving
	await _click(_hand_views[0].position + _hand_views[0].size * 0.5)
	await _click(_track[0].get_center())
	await _click(_curtain.get_center())
	print("[clicktest] after CURTAIN UP: state=%d (want %d = RESOLVE)" % [state, S.RESOLVE])
	if state != S.RESOLVE:
		fails += 1
	print("[clicktest] %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)


## One click through the real input stack: a mouse press/release, which `emulate_touch_from_mouse`
## also turns into a screen touch — exactly what a finger or a trackpad produces.
func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		# push straight into the viewport in ITS OWN coordinates: Input.parse_input_event() treats the
		# position as window pixels and then applies the stretch, which lands the click somewhere else.
		get_viewport().push_input(ev, true)
		await get_tree().process_frame
	await get_tree().process_frame


func _json(path: String) -> Dictionary:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("cannot read %s" % path)
		return {}
	return j.data


# --- layout --------------------------------------------------------------------------------------

func _layout() -> void:
	var vs := get_viewport_rect().size
	size = vs
	# the routine across the middle
	var n := Run.N_STATIONS
	var tw: float = minf(292.0, (vs.x - 140.0) / float(n) - 16.0)
	var th: float = minf(tw * 0.98, vs.y * 0.26)
	var total := float(n) * (tw + 16.0) - 16.0
	var x0 := (vs.x - total) * 0.5
	var y := vs.y * 0.17
	_track_bottom = y + th
	_track.clear()
	for i in n:
		_track.append(Rect2(x0 + float(i) * (tw + 14.0), y, tw, th))
	# the hand along the bottom
	var hv := _hand_views.size()
	if hv > 0:
		var cw := CardView.W
		var gap: float = minf(18.0, maxf(-40.0, (vs.x - 200.0 - float(hv) * cw) / float(maxi(1, hv - 1))))
		var hw := float(hv) * cw + float(hv - 1) * gap
		var hx := (vs.x - hw) * 0.5
		var hy := vs.y - CardView.H - 26.0
		for i in hv:
			_hand_views[i].position = Vector2(hx + float(i) * (cw + gap), hy)
	_curtain = Rect2(vs.x - 320.0, vs.y - CardView.H - 110.0, 286.0, 72.0)
	for i in _draft_views.size():
		var dw := float(_draft_views.size()) * (CardView.W + 40.0) - 40.0
		_draft_views[i].position = Vector2((vs.x - dw) * 0.5 + float(i) * (CardView.W + 40.0),
			vs.y * 0.5 - CardView.H * 0.5)
	queue_redraw()


func _rebuild_hand() -> void:
	for v in _hand_views:
		v.queue_free()
	_hand_views.clear()
	_sel = -1
	for i in run.hand.size():
		var v: CardView = CARD_VIEW.new()
		add_child(v)
		v.setup(run.hand[i], run.cards.get(run.hand[i], {}))
		v.tapped.connect(_on_card_tapped)
		_hand_views.append(v)
	_update_dim()
	_layout()


func _update_dim() -> void:
	for i in _hand_views.size():
		var v := _hand_views[i]
		v.dimmed = state != S.PLACE or run.cost_of(v.card_id) > run.nerve
		v.selected = i == _sel
		v.lift = 26.0 if i == _sel else 0.0
		v.queue_redraw()


# --- input ---------------------------------------------------------------------------------------

func _on_card_tapped(v: CardView) -> void:
	if state == S.DRAFT:
		var di := _draft_views.find(v)
		if di >= 0:
			run.take_draft(di)
			_clear_draft()
			state = S.PLACE
			_rebuild_hand()
		return
	if state != S.PLACE:
		return
	var i := _hand_views.find(v)
	_sel = -1 if i == _sel else i
	_update_dim()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var at := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			at = m.position
	if at == Vector2.INF or int(Engine.get_process_frames()) == _tap_frame:
		return
	_tap_frame = int(Engine.get_process_frames())
	match state:
		S.PLACE:
			_tap_place(at)
		S.NIGHT_END:
			run.next_night()
			state = S.PLACE
			_rebuild_hand()
		S.RUN_END:
			_ready()
		S.RESOLVE:
			_step_t = _step_len    # tap to hurry the show along
	queue_redraw()


func _tap_place(at: Vector2) -> void:
	for i in _track.size():
		if not _track[i].has_point(at):
			continue
		if run.board[i] != "":
			run.unplace(i)
			_rebuild_hand()
			return
		if _sel < 0:
			_say("Pick a prank first")
			return
		var why := run.place(_sel, i)
		if why != "":
			_say(why)
			return
		_rebuild_hand()
		return
	if _curtain.has_point(at):
		_begin_resolve()


func _say(t: String) -> void:
	_msg = t
	_msg_t = 1.6


# --- resolution ----------------------------------------------------------------------------------

func _begin_resolve() -> void:
	var rigged := 0
	for c in run.board:
		if c != "":
			rigged += 1
	if rigged == 0:
		_say("Rig at least one prank")
		return
	_steps = run.resolve()
	_step_i = -1
	_step_t = 1.0
	_step_len = 0.0
	state = S.RESOLVE
	_sel = -1
	_update_dim()


func _process(delta: float) -> void:
	if _demo:
		_run_demo(delta)
	_msg_t = maxf(0.0, _msg_t - delta)
	_shake = maxf(0.0, _shake - delta * 2.4)
	for f in _flash:
		f["t"] = float(f["t"]) + delta
	_flash = _flash.filter(func(f): return float(f["t"]) < 1.0)
	if state == S.RESOLVE:
		_step_t += delta
		if _step_t >= _step_len:
			_step_t = 0.0
			_step_i += 1
			if _step_i >= _steps.size():
				_after_resolve()
			else:
				var s: Dictionary = _steps[_step_i]
				_step_len = STEP_END if bool(s.get("end", false)) else \
					(STEP_FIRED if bool(s.get("fired", false)) else STEP_EMPTY)
				_show_step(s)
	queue_redraw()


## Autoplay: rig whatever fits, left to right, then raise the curtain.
func _run_demo(delta: float) -> void:
	_demo_t -= delta
	if _demo_t > 0.0:
		return
	_demo_t = 0.3
	match state:
		S.PLACE:
			for h in run.hand.size():
				if run.cost_of(run.hand[h]) > run.nerve:
					continue
				for p in Run.N_STATIONS:
					if run.board[p] == "" and run.place(h, p) == "":
						_rebuild_hand()
						return
			_begin_resolve()
		S.DRAFT:
			if not _draft_views.is_empty():
				_on_card_tapped(_draft_views[0])
		S.NIGHT_END:
			run.next_night()
			state = S.PLACE
			_rebuild_hand()
		S.RUN_END:
			_demo_t = 3.0


func _show_step(s: Dictionary) -> void:
	if not bool(s.get("fired", false)):
		return
	var vs := get_viewport_rect().size
	var pos: int = int(s.get("pos", -1))
	var at := Vector2(vs.x * 0.5, vs.y * 0.17 - 60.0)
	if pos >= 0 and pos < _track.size():
		at = _track[pos].position + Vector2(_track[pos].size.x * 0.5, -26.0)
	_flash.append({"text": "+%d" % int(s["gain"]), "pos": at, "t": 0.0, "col": GOLD, "size": 56})
	_shake = minf(1.0, float(int(s["gain"])) / 45.0)


func _after_resolve() -> void:
	var outcome := run.finish_round()
	match outcome:
		"draft":
			_open_draft()
		"night_won":
			state = S.NIGHT_END
		"won", "lost":
			state = S.RUN_END
	if outcome == "draft":
		return
	_rebuild_hand()


func _open_draft() -> void:
	state = S.DRAFT
	_clear_draft()
	for id: String in run.draft_options():
		var v: CardView = CARD_VIEW.new()
		add_child(v)
		if id.begins_with("enc:"):
			var e: Dictionary = run.encores_db.get(id.substr(4), {})
			v.setup(id, {"name": str(e.get("name", "")), "glyph": str(e.get("glyph", "")),
				"base": 0, "cost": 0, "text": "ENCORE — " + str(e.get("text", ""))})
		else:
			v.setup(id, run.cards.get(id, {}))
		v.tapped.connect(_on_card_tapped)
		_draft_views.append(v)
	_layout()


func _clear_draft() -> void:
	for v in _draft_views:
		v.queue_free()
	_draft_views.clear()


# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	var vs := get_viewport_rect().size
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 7.0
	draw_set_transform(jitter, 0.0, Vector2.ONE)
	_draw_header(vs)
	_draw_track()
	_draw_nerve(vs)
	if state == S.PLACE:
		_draw_button(_curtain, "CURTAIN UP", GOLD, INK)
	if state == S.RESOLVE:
		_draw_step_panel(vs)
	for f in _flash:
		var t := float(f["t"])
		var a: float = clampf(1.0 - t / 1.0, 0.0, 1.0)
		var p: Vector2 = f["pos"] as Vector2 + Vector2(0, -86.0 * t)
		var col: Color = f["col"]
		col.a = a
		draw_string(_font_d, p - Vector2(100, 0), str(f["text"]), HORIZONTAL_ALIGNMENT_CENTER, 200,
			int(f["size"]), col)
	if _msg_t > 0.0:
		var mc := CREAM
		mc.a = clampf(_msg_t, 0.0, 1.0)
		draw_string(_font_b, Vector2(0, vs.y - CardView.H - 148.0), _msg,
			HORIZONTAL_ALIGNMENT_CENTER, vs.x, 26, mc)
	if state == S.DRAFT:
		_draw_overlay_title(vs, "TAKE ONE", "A new prank for the deck, or an Encore that changes the rules.")
	elif state == S.NIGHT_END:
		_draw_night_end(vs)
	elif state == S.RUN_END:
		_draw_run_end(vs)


## During the replay the headline numbers follow the step being shown, not the finished total —
## the whole point of the resolve is watching it climb.
func _shown_applause() -> int:
	if state == S.RESOLVE and _step_i >= 0 and _step_i < _steps.size():
		return int((_steps[_step_i] as Dictionary).get("applause_after", run.applause))
	if state == S.RESOLVE and _step_i < 0 and not _steps.is_empty():
		return int((_steps[0] as Dictionary).get("applause_after", 0)) - int((_steps[0] as Dictionary).get("gain", 0))
	return run.applause


func _shown_temper() -> int:
	if state == S.RESOLVE and _step_i >= 0 and _step_i < _steps.size():
		return int((_steps[_step_i] as Dictionary).get("temper_after", run.temper))
	return run.temper


func _shown_tier() -> int:
	if state == S.RESOLVE and _step_i >= 0 and _step_i < _steps.size():
		return int((_steps[_step_i] as Dictionary).get("tier_after", run.tier()))
	return run.tier()


func _draw_header(vs: Vector2) -> void:
	var shown_ap := _shown_applause()
	draw_rect(Rect2(0, 0, vs.x, 128), Color("#0E1328"), true)
	draw_string(_font_d, Vector2(34, 54), "NIGHT %d" % run.night, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, CREAM)
	draw_string(_font_b, Vector2(34, 92), "round %d of %d" % [run.round_i, Run.ROUNDS_PER_NIGHT],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#8E97BF"))
	# applause
	var mid := vs.x * 0.5
	draw_string(_font_d, Vector2(mid - 300, 56), "%d" % shown_ap, HORIZONTAL_ALIGNMENT_RIGHT, 300, 48, GOLD)
	draw_string(_font_b, Vector2(mid + 14, 52), "/ %d APPLAUSE" % run.target,
		HORIZONTAL_ALIGNMENT_LEFT, 300, 26, Color("#8E97BF"))
	var bw := 420.0
	var bx := mid - bw * 0.5
	draw_rect(Rect2(bx, 74, bw, 14), Color("#2B3566"), true)
	var f: float = clampf(float(shown_ap) / float(maxi(1, run.target)), 0.0, 1.0)
	draw_rect(Rect2(bx, 74, bw * f, 14), GOLD, true)
	# temper
	var tx := vs.x - 330.0
	var tier: int = _shown_tier()
	var tier_cols: Array[Color] = [Color("#8FB09A"), Color("#E8C86A"), Color("#E8884A"), RED]
	var tcol: Color = tier_cols[tier]
	draw_string(_font_d, Vector2(tx, 50), Run.TIER_NAMES[tier], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, tcol)
	draw_string(_font_b, Vector2(tx, 50), "TEMPER %d" % _shown_temper(), HORIZONTAL_ALIGNMENT_RIGHT, 296, 20,
		Color("#8E97BF"))
	for i in 4:
		var on := i <= tier
		draw_rect(Rect2(tx + float(i) * 76.0, 66, 68, 12),
			tcol if on else Color("#2B3566"), true)
	# residues + encores
	var rx := tx
	var ry := 96.0
	for r in run.residues:
		var w := float(r.length()) * 11.0 + 24.0
		draw_rect(Rect2(rx, ry, w, 26), Color("#2B3566"), true)
		draw_string(_font_b, Vector2(rx, ry + 19), r, HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color("#9FD0FF"))
		rx += w + 8.0
	var ex := 34.0
	for e in run.encores:
		var ed: Dictionary = run.encores_db.get(e, {})
		draw_rect(Rect2(ex, 100, 34, 34), GOLD, true)
		draw_string(_font_d, Vector2(ex, 126), str(ed.get("glyph", "")), HORIZONTAL_ALIGNMENT_CENTER, 34, 24, INK)
		ex += 40.0


func _draw_track() -> void:
	# the routine reads as a path he walks: a rail through the tiles, numbered stops
	if _track.size() > 1:
		var y0: float = _track[0].position.y + _track[0].size.y * 0.5
		draw_line(Vector2(_track[0].get_center().x, y0),
			Vector2(_track[_track.size() - 1].get_center().x, y0), Color("#232C56"), 10.0)
		draw_string(_font_b, Vector2(_track[0].position.x, _track[0].position.y - 18.0),
			"HIS ROUTINE  →", HORIZONTAL_ALIGNMENT_LEFT, 400, 20, Color("#5A648F"))
	for i in _track.size():
		var r := _track[i]
		var st := run.station_at(i)
		var room := str(st["room"])
		var rc: Color = ROOM_COL.get(room, CREAM)
		var active := state == S.RESOLVE and _step_i == i
		var done := state == S.RESOLVE and _step_i > i
		var id := run.board[i]
		# tile
		draw_rect(r.grow(5.0), GOLD if active else Color("#2B3566"), true)
		draw_rect(r, Color("#1C2444") if id == "" else Color("#39406E"), true)
		# room strip
		draw_rect(Rect2(r.position, Vector2(r.size.x, 9)), rc, true)
		draw_string(_font_b, r.position + Vector2(0, 34), str(st["name"]),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, rc)
		draw_circle(r.position + Vector2(20, 22), 13.0, Color("#232C56"))
		draw_string(_font_b, r.position + Vector2(7, 28), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 26, 16,
			Color("#8E97BF"))
		if id == "":
			draw_string(_font_b, r.position + Vector2(0, r.size.y * 0.58), "empty",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color("#49527F"))
		else:
			var cd: Dictionary = run.cards.get(id, {})
			draw_string(_font_d, r.position + Vector2(0, r.size.y * 0.56), str(cd.get("glyph", "")),
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 46, CREAM)
			draw_string(_font_b, r.position + Vector2(4, r.size.y - 16.0), str(cd.get("name", "")),
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 15, CREAM if not done else Color("#7E86AE"))
		# the marker that walks the routine while it resolves
		if active:
			var p := r.position + Vector2(r.size.x * 0.5, r.size.y + 30.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -16), p + Vector2(15, 6),
				p + Vector2(-15, 6)]), GOLD)


func _draw_nerve(vs: Vector2) -> void:
	var y := vs.y - CardView.H - 84.0
	draw_string(_font_b, Vector2(34, y), "NERVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#8E97BF"))
	var full := Run.BASE_NERVE + run._enc("nerve")
	for i in full:
		var c := RED if i < run.nerve else Color("#2B3566")
		draw_circle(Vector2(118.0 + float(i) * 34.0, y - 7.0), 13.0, c)


func _draw_button(r: Rect2, label: String, bg: Color, fg: Color) -> void:
	draw_rect(r.grow(4.0), INK, true)
	draw_rect(r, bg, true)
	draw_string(_font_d, r.position + Vector2(0, r.size.y * 0.68), label,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, fg)


## The running explanation: every part of the number that just landed.
func _draw_step_panel(vs: Vector2) -> void:
	if _step_i < 0 or _step_i >= _steps.size():
		return
	var s: Dictionary = _steps[_step_i]
	var parts: Array = s.get("parts", [])
	if parts.is_empty() and not bool(s.get("end", false)):
		return
	var shown: Array = parts.slice(0, 4)
	var w := 620.0
	var h := 80.0 + float(shown.size()) * 28.0
	var r := Rect2((vs.x - w) * 0.5, _track_bottom + 46.0, w, h)
	draw_rect(r.grow(4.0), GOLD, true)
	draw_rect(r, Color("#1C2444"), true)
	var title := "END OF THE ROUND" if bool(s.get("end", false)) else \
		"%s — %s" % [str(s.get("station", "")), str(run.cards.get(str(s.get("card", "")), {}).get("name", ""))]
	draw_string(_font_d, r.position + Vector2(16, 34), title, HORIZONTAL_ALIGNMENT_LEFT, w - 32, 24, CREAM)
	var y := 62.0
	for p in shown:
		var amt := int(p[1])
		draw_string(_font_b, r.position + Vector2(16, y), str(p[0]), HORIZONTAL_ALIGNMENT_LEFT, w - 140, 20,
			Color("#8E97BF"))
		if amt != 0:
			draw_string(_font_b, r.position + Vector2(w - 140, y), "%+d" % amt, HORIZONTAL_ALIGNMENT_RIGHT,
				124, 20, GOLD if amt > 0 else RED)
		y += 28.0
	var mult := int(s.get("mult", 100))
	var foot := ""
	if mult != 100:
		foot += "CHAIN ×%.1f   " % (float(mult) / 100.0)
	if int(s.get("repeat", 1)) > 1:
		foot += "FIRES ×%d   " % int(s["repeat"])
	if int(s.get("temper_bonus", 0)) > 0:
		foot += "TEMPER +%d   " % int(s["temper_bonus"])
	if foot != "":
		draw_string(_font_b, r.position + Vector2(16, y), foot, HORIZONTAL_ALIGNMENT_LEFT, w - 32, 19, Color("#9FD0FF"))


func _draw_overlay_title(vs: Vector2, title: String, sub: String) -> void:
	draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0.055, 0.075, 0.16, 0.86), true)
	draw_string(_font_d, Vector2(0, vs.y * 0.22), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 56, GOLD)
	draw_string(_font_b, Vector2(0, vs.y * 0.22 + 42.0), sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 24,
		Color("#8E97BF"))


func _draw_night_end(vs: Vector2) -> void:
	_draw_overlay_title(vs, "CURTAIN!", "Night %d cleared with %d Applause. Tap to go on." % [run.night, run.applause])


func _draw_run_end(vs: Vector2) -> void:
	var t := "THAT'S THE SHOW" if run.won else "THEY WALKED OUT"
	var sub := "You got through all three Nights. Tap to start again." if run.won else \
		"Night %d: %d of %d Applause. Tap to start again." % [run.night, run.applause, run.target]
	_draw_overlay_title(vs, t, sub)
