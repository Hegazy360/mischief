## CueStager — the director's `laugh_*` cues made visible (s2-view brief §4.2.13; the Prologue's
## laughs must be *seen and heard*, the solver counts them). Each staging emits
## `WorldView.cue_staged(id, kind)` (`kind`: "prop" | "clip" | "stalls" | "fx" | "none").
##
## | Cue | What the player sees |
## |---|---|
## | `laugh_vase` | from tick 0 `parlour_vase` creeps 10–14 px along the mantel on every `voice` / `sfx` event of his warm-up clip (fallback every 45 f while the sim runs, never during pre-roll); on the cue it tips (4 f) and drops behind him (8 f): hidden, `parlour_vase_smashed` shown + dust and shards |
## | `laugh_doorframe` | stars at the `parlour_kitchen` door frame + his `cue:laugh_doorframe` overlay clip (head snaps back) over the blind shuffle |
## | `laugh_relief` | the Stalls exhale (their `relief` special comes from the crowd cue via AudioDirector) — a small sweat-drop puff over Hush |
## | `laugh_picture` | `parlour_picture_frame` switches to its `falling` sprite, drops 12 f onto his head, hangs round his neck 60 f, falls off-frame + his `cue:laugh_picture` overlay |
## | `sparkle_lever`, `ghost_*`, `figgis_psst`, `card_*` | FTUE (s2-ftue; `WorldView.sparkle`) — "fx" |
## | `title_card` | nothing during PLAY (NightScene swallows it) — "none" |
class_name CueStager
extends RefCounted

const VASE := "parlour_vase"
const VASE_SMASHED := "parlour_vase_smashed"
const PICTURE := "parlour_picture_frame"
const DOORFRAME_LINK := "parlour_kitchen"
const CREEP_FALLBACK_F := 45.0
const TIP_F := 4.0
const FALL_F := 8.0
const PIC_DROP_F := 12.0
const PIC_HANG_F := 60.0
const PIC_OFF_F := 20.0

var wv: WorldView = null
## Vase creep: px moved so far, the step pattern, and the fallback clock.
var vase_px: float = 0.0
var _vase_steps := 0
var _vase_clock := 0.0
var _vase_edge := -1.0
var _vase_dir := -1.0
var _vase_phase := "" ## "" | "tip" | "fall" | "smashed"
var _vase_t := 0.0
var _pic_phase := "" ## "" | "drop" | "hang" | "off" | "gone"
var _pic_t := 0.0
var _pic_from := Vector2.ZERO
var _warmup_clip := false


func setup(w: WorldView) -> void:
	wv = w
	var hj: Variant = ViewKit.json(HouseLayout.HOUSE_JSON)
	if hj is Dictionary:
		for d in (hj as Dictionary).get("decor", []):
			if d is Dictionary and ViewKit.s((d as Dictionary).get("id", "")) == VASE:
				var sl: Variant = (d as Dictionary).get("slide", {})
				if sl is Dictionary:
					_vase_edge = float((sl as Dictionary).get("edge_x", -1.0))
					_vase_dir = float((sl as Dictionary).get("dir", -1))


func reset() -> void:
	vase_px = 0.0
	_vase_steps = 0
	_vase_clock = 0.0
	_vase_phase = ""
	_pic_phase = ""


## The vase's creep step for note `n`: alternates 10 / 14 / 12 px (the brief's 10–14 px).
static func creep_step(n: int) -> float:
	return [10.0, 14.0, 12.0][posmod(n, 3)]


## Sim events: the cues themselves.
func on_event(ev: Dictionary, snap: ViewSnapshot) -> void:
	if ViewKit.s(ev.get("e", "")) != "director_cue":
		return
	var id := ViewKit.s(ev.get("id", ""))
	match id:
		"laugh_vase":
			_vase_phase = "tip"
			_vase_t = 0.0
			wv.cue_staged.emit(id, "prop")
		"laugh_doorframe":
			var l := wv.layout.link_between("parlour", "kitchen")
			var x := l.x if l != null else snap.bellows.x
			wv.fx.stars_at(Vector2(x, wv.layout.room_floor_y("parlour") - 430.0))
			var played := _cue_clip(id)
			wv.cue_staged.emit(id, "clip" if played else "fx")
		"laugh_relief":
			wv.fx.burst("drops", wv.hush_view.head_position() + Vector2(30, -40), 5)
			wv.cue_staged.emit(id, "stalls")
		"laugh_picture":
			_pic_phase = "drop"
			_pic_t = 0.0
			var r := wv.decor.rect_of(PICTURE)
			_pic_from = r.position if r.size != Vector2.ZERO else wv.bellows_view.head_position() + Vector2(-70, -300)
			wv.decor.set_state(PICTURE, "falling")
			_cue_clip(id)
			wv.cue_staged.emit(id, "prop")
		"title_card":
			wv.cue_staged.emit(id, "none")
		_:
			if id.begins_with("laugh_"):
				wv.cue_staged.emit(id, "none")
			elif id != "":
				wv.cue_staged.emit(id, "fx")


## Play the cue's overlay clip on Bellows when it exists (`cue:<id>`); true when it played.
func _cue_clip(id: String) -> bool:
	var e: Variant = ClipMap.entry(wv.bellows_view.map, "cue:" + id, wv.bellows_view.skin)
	var clip := ClipMap.clip_of(e)
	var row := ClipRules.row("cue:" + id, "bellows")
	var exp_f := float(((row.get("len", {}) as Dictionary) if row.get("len", {}) is Dictionary else {}).get("expect_f", 0))
	wv.bellows_view.play_cue(id, exp_f if not ClipMap.clip_exists(clip) else 0.0)
	return ClipMap.clip_exists(clip)


## Clip events: every warm-up note (voice / sfx of his `act_warmup` clip) nudges the vase.
func on_clip_event(ev: Dictionary) -> void:
	if ViewKit.s(ev.get("actor", "")) != "bellows" or _vase_phase != "":
		return
	var t := ViewKit.s(ev.get("type", ""))
	if (t == "voice" or t == "sfx") and ViewKit.s(ev.get("clip", wv.bellows_view.current_clip())).contains("warmup"):
		_creep()


func _creep() -> void:
	if not wv.decor.has(VASE):
		return
	var step := CueStager.creep_step(_vase_steps)
	_vase_steps += 1
	vase_px += step
	# Never past the mantel edge before the cue: it teeters there.
	if _vase_edge > 0.0:
		var d := wv.layout.decor_item(VASE)
		if d != null:
			var room_left := d.pos.x + 16.0 + _vase_dir * vase_px
			if _vase_dir < 0.0 and room_left < _vase_edge:
				vase_px = maxf(0.0, d.pos.x + 16.0 - _vase_edge)
	wv.decor.set_offset(VASE, Vector2(_vase_dir * vase_px, 0))
	wv.decor.wobble(VASE)
	_vase_clock = 0.0


## Per frame (view time).
func advance(snap: ViewSnapshot, dt: float) -> void:
	var f := dt * 60.0
	var warm := snap.bellows.activity == "warmup" and not snap.bellows.moving
	_warmup_clip = warm and ClipMap.clip_exists(wv.bellows_view.current_clip()) and wv.bellows_view.current_clip().contains("warmup")
	if _vase_phase == "" and warm and snap.tick > 0 and not _warmup_clip:
		_vase_clock += f
		if _vase_clock >= CREEP_FALLBACK_F:
			_creep()
	_advance_vase(f)
	_advance_picture(f)


func _advance_vase(f: float) -> void:
	if _vase_phase == "" or _vase_phase == "smashed":
		return
	var s := wv.decor.sprite(VASE)
	var d := wv.layout.decor_item(VASE)
	if s == null or d == null:
		_vase_phase = "smashed"
		return
	_vase_t += f
	var base := d.pos + Vector2(_vase_dir * vase_px, 0)
	var piv := Vector2(16, 100)
	if _vase_phase == "tip":
		var ang := _vase_dir * deg_to_rad(70.0) * clampf(_vase_t / TIP_F, 0.0, 1.0)
		s.rotation = ang
		s.position = base + piv - piv.rotated(ang)
		if _vase_t >= TIP_F:
			_vase_phase = "fall"
			_vase_t = 0.0
	elif _vase_phase == "fall":
		var u := clampf(_vase_t / FALL_F, 0.0, 1.0)
		var floor_y := wv.layout.room_floor_y(d.room) - 8.0
		s.rotation = _vase_dir * deg_to_rad(70.0 + 110.0 * u)
		s.position = base + Vector2(_vase_dir * 30.0 * u, (floor_y - base.y - d.size.y * 0.5) * u * u)
		if _vase_t >= FALL_F:
			_vase_phase = "smashed"
			s.visible = false
			s.rotation = 0.0
			wv.decor.set_visible(VASE_SMASHED, true)
			var r := wv.decor.rect_of(VASE_SMASHED)
			var at := r.get_center() if r.size != Vector2.ZERO else Vector2(base.x, floor_y)
			wv.fx.burst("dust", at, 14)
			wv.fx.burst("sparkles", at + Vector2(0, -20), 8)


func _advance_picture(f: float) -> void:
	if _pic_phase == "" or _pic_phase == "gone":
		return
	var s := wv.decor.sprite(PICTURE)
	var d := wv.layout.decor_item(PICTURE)
	if s == null or d == null:
		_pic_phase = "gone"
		return
	_pic_t += f
	var neck := wv.bellows_view.socket_transform("torso:neck").origin
	if neck == wv.bellows_view.global_position:
		neck = wv.bellows_view.head_position() + Vector2(0, 70)
	var hole := Vector2(70, 90)
	match _pic_phase:
		"drop":
			var u := clampf(_pic_t / PIC_DROP_F, 0.0, 1.0)
			s.position = _pic_from.lerp(neck - hole, u * u)
			if _pic_t >= PIC_DROP_F:
				_pic_phase = "hang"
				_pic_t = 0.0
				wv.fx.stars_at(wv.bellows_view.head_position())
		"hang":
			s.position = neck - hole + Vector2(0, sin(_pic_t * 0.4) * 3.0)
			s.rotation = sin(_pic_t * 0.25) * 0.08
			if _pic_t >= PIC_HANG_F:
				_pic_phase = "off"
				_pic_t = 0.0
		"off":
			var u2 := clampf(_pic_t / PIC_OFF_F, 0.0, 1.0)
			s.position = neck - hole + Vector2(60.0 * u2, 500.0 * u2 * u2)
			s.rotation = 0.9 * u2
			if _pic_t >= PIC_OFF_F:
				_pic_phase = "gone"
				s.visible = false
				s.rotation = 0.0


## Debug / tests: the vase / picture phases.
func vase_phase() -> String:
	return _vase_phase


func picture_phase() -> String:
	return _pic_phase
