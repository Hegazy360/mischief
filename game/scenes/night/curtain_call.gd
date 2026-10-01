## CurtainCall — the end of a Night as a NightScene phase (GDD §6.2, s2-night §4.3, ruling L7): the
## curtain falls, Hush steps out on the apron and bows under a rain of roses, the ResultsScreen counts
## the Applause up (stamps, the one why-missed line, "+NEW!" chips), then the Gag Reel replays the
## Night's best moments while Bellows wanders on in his residue along the lower stage band, does a
## double take, a slow burn, and the curtain valance drops on his head.
##
## Step tables (seconds; `steps(kind, repeat)` is the pure source the tests check):
## | kind | steps |
## |---|---|
## | night (first) | fall 0.8 · bow 1.6 · results ≤ 2.4 · reel ≤ 8.0 → ≤ 12.8 |
## | night (repeat: Save already has a result) | fall 0.8 · bow 0.8 · results ≤ 1.9 · reel ≤ 4.0 → ≤ 7.5 |
## | prologue | fall 0.8 · bow 1.6 · title 1.5 (0.3 drop + squash, bulbs, `title_slam`, 1.2 hold) · results 1.5 · reel ≤ 5.0 → ≈ 10.4 |
## | gate0 | fall 0.8 · reel ≤ 5.0 (the ResultsScreen with Again ▶ / Stage door is up from the first frame) |
## **Every button is live from the first frame of the call**: until the ResultsScreen shows, proxy
## buttons sit exactly where its Next ▶ / Retry will be (same look, same size), so a thumb resting on
## Next ▶ never waits. A tap anywhere else skips the current step (the ResultsScreen's own skip
## during its count-up; a Gag Reel moment during the reel).
## `action(a)`: next | retry | playbill (night, prologue) · again | stage_door (gate0).
## **3D view** (the NightScene's `view_mode == "3d"`): the 2D red curtain falls as before; the bows are 3D
## (CurtainBows3D: a transparent SubViewport composited in front of the curtain, under the roses / title / valance);
## the Gag Reel is GagReel3D (the recorded moments re-staged in a SubViewport), primed on the call's first frame so
## its slot is never empty.
class_name CurtainCall
extends Node

signal action(a: String)
signal step_changed(step: String)
## Every step ran (the call now waits for a button).
signal finished()

const LAYER := 21
const KIND_NIGHT := "night"
const KIND_PROLOGUE := "prologue"
const KIND_GATE0 := "gate0"
const TITLE_ART := "res://art/house/stage/title_card.svg"
const VALANCE_ART := "res://art/house/stage/curtain_valance.svg"
const ROSES := 28
## Apron scale of the characters (world px → screen px) and the lower stage band.
const APRON_SCALE := 0.8
const BAND_SCALE := 0.55
const HUSH_BOW := "hush/act_bow"
const BELLOWS_CLIPS: PackedStringArray = ["bellows/cc_wander_on", "bellows/st_double_take", "bellows/beat_slow_burn",
	"bellows/st_bonk"]

## Pure step table: [{id, s}] for a kind (+ repeat viewing).
static func steps(kind: String, repeat: bool = false) -> Array:
	match kind:
		KIND_GATE0:
			return [{"id": "fall", "s": 0.8}, {"id": "reel", "s": 5.0}]
		KIND_PROLOGUE:
			return [{"id": "fall", "s": 0.8}, {"id": "bow", "s": 1.6}, {"id": "title", "s": 1.5},
				{"id": "results", "s": 1.5}, {"id": "reel", "s": 5.0}]
	if repeat:
		return [{"id": "fall", "s": 0.8}, {"id": "bow", "s": 0.8}, {"id": "results", "s": 1.9}, {"id": "reel", "s": 4.0}]
	return [{"id": "fall", "s": 0.8}, {"id": "bow", "s": 1.6}, {"id": "results", "s": 2.4}, {"id": "reel", "s": 8.0}]


## Unskipped length of a kind's call (s).
static func total_s(kind: String, repeat: bool = false) -> float:
	var t := 0.0
	for s in steps(kind, repeat):
		t += float((s as Dictionary)["s"])
	return t


## The call for an episode / end reason.
static func kind_for(episode_id: String, reason: String) -> String:
	if reason == "g0_done" or episode_id == "g0_sneeze":
		return KIND_GATE0
	if reason == "prologue_done" or episode_id == "p00_curtain_up":
		return KIND_PROLOGUE
	return KIND_NIGHT


## ResultsScreen variant for a kind.
static func variant_for(kind: String) -> String:
	return "gate0" if kind == KIND_GATE0 else ("prologue" if kind == KIND_PROLOGUE else "night")


var night: Node = null
var kind: String = KIND_NIGHT
var result: Dictionary = {}
var repeat: bool = false
var table: Array = []
var step_i: int = -1
var step_t: float = 0.0
## Real seconds since start (tests, the e2e length).
var elapsed: float = 0.0
## Seconds each step actually took (skips included).
var step_times: Dictionary = {}
var done: bool = false
var layer: CanvasLayer = null
var apron: CurtainApron = null
var results: ResultsScreen = null
## The Gag Reel (GagReel3D).
var reel: Node = null
## The 3D bows.
var bows: CurtainBows3D = null
var proxy_next: UiButton = null
var proxy_retry: UiButton = null
## Tests: the step never ends on its own (only skip()).
var hold_steps: bool = false

var _catcher: Control = null
var _acted: bool = false


func _init() -> void:
	name = "CurtainCall"


## Begin the call on `p_night` (NightScene) with the Night's `p_result` (NightScene.collect_result +
## `repeat`, `why`, `new`, `title`, `moments`, `cmds`).
func start(p_night: Node, p_kind: String, p_result: Dictionary) -> void:
	night = p_night
	kind = p_kind
	result = p_result
	repeat = bool(result.get("repeat", false))
	table = steps(kind, repeat)
	layer = CanvasLayer.new()
	layer.layer = LAYER
	layer.name = "CurtainCallLayer"
	add_child(layer)
	bows = CurtainBows3D.new()
	layer.add_child(bows)
	apron = CurtainApron.new()
	apron.bows = bows
	layer.add_child(apron)
	_prime_reel()
	_catcher = _TapCatcher.new()
	_catcher.call_ref = skip
	layer.add_child(_catcher)
	if kind == KIND_GATE0:
		_show_results()
	else:
		_make_proxies()
	_audio_call("crowd", ["t2"])
	_audio_call("music_state", ["results"])
	_next_step()


## A tap: skip the current step.
func skip() -> void:
	if done or step_i < 0 or step_i >= table.size():
		return
	var id := step_id()
	if id == "reel" and reel != null and bool(reel.get("playing")):
		reel.call("skip")
		return
	if id == "results" and results != null and not results.is_finished():
		results.skip()
		return
	_next_step()


## The current step id ("" before start / after the end).
func step_id() -> String:
	return String((table[step_i] as Dictionary)["id"]) if step_i >= 0 and step_i < table.size() else ""


## Back: the ResultsScreen's back action once it shows, else skip.
func handle_back() -> bool:
	if results != null and is_instance_valid(results):
		results.handle_back()
	else:
		skip()
	return true


## Press a button by action (tests, e2e): next | retry | playbill | again | stage_door.
func press(a: String) -> void:
	_emit_action(a)


func _process(delta: float) -> void:
	if step_i < 0 or done:
		if apron != null:
			apron.advance(delta)
		return
	elapsed += delta
	step_t += delta
	apron.advance(delta)
	var id := step_id()
	var dur := float((table[step_i] as Dictionary)["s"])
	match id:
		"results":
			if results != null and results.is_finished() and step_t >= 0.3:
				_next_step()
				return
		"reel":
			apron.bellows_t = step_t / maxf(0.1, dur)
			if reel != null and not bool(reel.get("playing")) and step_t > 0.05:
				_next_step()
				return
	if not hold_steps and step_t >= dur:
		_next_step()


func _next_step() -> void:
	if step_i >= 0 and step_i < table.size():
		step_times[step_id()] = snappedf(step_t, 0.01)
		_end_step(step_id())
	step_i += 1
	step_t = 0.0
	if step_i >= table.size():
		done = true
		finished.emit()
		step_changed.emit("")
		return
	var id := step_id()
	_begin_step(id)
	step_changed.emit(id)


func _begin_step(id: String) -> void:
	match id:
		"fall":
			var c: Variant = night.get("curtain") if night != null else null
			if c is NightCurtain:
				(c as NightCurtain).fall(float((table[step_i] as Dictionary)["s"]))
			_audio_call("play_sfx", ["curtain_fall"])
		"bow":
			apron.show_hush(true, float((table[step_i] as Dictionary)["s"]))
			apron.rain_roses()
			_audio_call("crowd", ["t3"])
			UiKit.haptic(&"accent")
		"title":
			apron.slam_title()
			_audio_call("sting", ["title_slam"])
			UiKit.haptic(&"stomp")
		"results":
			apron.show_hush(false, 0.0)
			_show_results()
		"reel":
			apron.show_hush(false, 0.0)
			apron.show_title(false)
			if kind != KIND_GATE0:
				apron.start_bellows(result.get("residues", PackedStringArray()))
			_start_reel(float((table[step_i] as Dictionary)["s"]))


func _end_step(id: String) -> void:
	match id:
		"fall":
			var c: Variant = night.get("curtain") if night != null else null
			if c is NightCurtain and (c as NightCurtain).is_animating():
				(c as NightCurtain).set_down()
		"reel":
			if reel != null and bool(reel.get("playing")):
				reel.call("stop")
			apron.bonk()


func _make_proxies() -> void:
	var vs := _view_size()
	var s := _safe_rect(vs)
	var nx := UiButton.make(_label_next(), ResultsScreen.NEXT_SIZE, UiKit.GOLD, UiKit.GOLD_SHADE, UiIcons.get_icon(&"play"))
	nx.name = "ProxyNext"
	nx.icon_after = true
	nx.font_size = 64
	nx.icon_px = 84.0
	nx.radius = 44.0
	nx.position = Vector2(s.end.x - 48.0 - ResultsScreen.NEXT_SIZE.x, s.end.y - 40.0 - ResultsScreen.NEXT_SIZE.y)
	nx.disabled = kind == KIND_NIGHT and not bool(result.get("has_next", true))
	nx.pressed.connect(func() -> void: _emit_action("next"))
	layer.add_child(nx)
	proxy_next = nx
	var rt := UiButton.make(_s("curtain.retry", "results.retry"), ResultsScreen.SMALL_SIZE, UiKit.CREAM, UiKit.CREAM_SHADE,
		UiIcons.get_icon(&"retry"))
	rt.name = "ProxyRetry"
	rt.hit_pad = Vector2(0, 12)
	rt.position = Vector2(s.position.x + 48.0, s.end.y - 40.0 - ResultsScreen.SMALL_SIZE.y)
	rt.pressed.connect(func() -> void: _emit_action("retry"))
	layer.add_child(rt)
	proxy_retry = rt


func _label_next() -> String:
	if kind == KIND_PROLOGUE:
		return _s("curtain.night1", "results.next")
	if kind == KIND_GATE0:
		return _s("curtain.again", "curtain.again")
	return _s("curtain.next_night", "results.next")


func _free_proxies() -> void:
	for b in [proxy_next, proxy_retry]:
		if b != null and is_instance_valid(b):
			(b as Node).queue_free()
	proxy_next = null
	proxy_retry = null


func _show_results() -> void:
	if results != null:
		return
	var rs := ResultsScreen.new()
	rs.name = "ResultsScreen"
	rs.setup({"variant": variant_for(kind), "applause": int(result.get("applause", 0)),
		"stars": result.get("stars", [false, false, false]), "why": String(result.get("why", "")),
		"new": result.get("new", []), "has_next": bool(result.get("has_next", true)),
		"night_title": String(result.get("title", "")), "repeat": repeat})
	layer.add_child(rs)
	var vs := _view_size()
	rs.position = Vector2.ZERO
	rs.size = vs
	rs.set_insets(SafeArea.insets(get_viewport()) if is_inside_tree() else Vector4.ZERO)
	if reel != null and reel.has_method("get_texture"):
		rs.set_gag_reel_texture(reel.call("get_texture"))
	rs.closed.connect(_emit_action)
	rs.skip_requested.connect(_on_results_skip)
	results = rs
	_free_proxies()
	# the tap catcher now lives under the panel (the panel's scrim takes the taps)
	if _catcher != null:
		_catcher.visible = false


func _on_results_skip(st: int) -> void:
	if st == ResultsScreen.Step.DONE:
		if step_id() == "reel" and reel != null and bool(reel.get("playing")):
			reel.call("skip")
		elif step_id() == "results":
			_next_step()


func _start_reel(budget: float) -> void:
	var moments: Array = result.get("moments", [])
	if night == null or moments.is_empty():
		return
	if reel == null:
		reel = GagReel3D.new()
		add_child(reel)
	reel.call("start", night, moments, budget, result.get("cmds", []))
	if results != null:
		results.set_gag_reel_texture(reel.call("get_texture"))


## 3D: the reel's first frame is rendered on the call's first frame (no empty box when the slot appears).
func _prime_reel() -> void:
	var moments: Array = result.get("moments", [])
	if moments.is_empty():
		return
	var r := GagReel3D.new()
	add_child(r)
	r.prime(night, moments)
	reel = r


func _emit_action(a: String) -> void:
	if _acted:
		return
	_acted = true
	if reel != null and (bool(reel.get("playing")) or bool(reel.get("primed"))):
		reel.call("stop")
	action.emit(a)


func _audio_call(m: String, args: Array) -> void:
	var au := ViewKit.autoload("Audio")
	if au != null and au.has_method(m):
		au.callv(m, args)


func _s(key: String, fallback_key: String) -> String:
	return UiStrings.t(key) if UiStrings.has(key) else UiStrings.t(fallback_key)


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)


func _safe_rect(vs: Vector2) -> Rect2:
	var ins := SafeArea.insets(get_viewport()) if is_inside_tree() else Vector4.ZERO
	return Rect2(ins.x, ins.y, vs.x - ins.x - ins.z, vs.y - ins.y - ins.w)


## A full-screen touch catcher: a tap anywhere (not on a button) skips the step.
class _TapCatcher:
	extends Control
	var call_ref: Callable = Callable()
	var _down: int = -1

	func _init() -> void:
		name = "TapCatcher"
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			accept_event()
			if st.pressed:
				_down = st.index
			elif st.index == _down:
				_down = -1
				if call_ref.is_valid():
					call_ref.call()
		elif event is InputEventMouse or event is InputEventScreenDrag:
			accept_event()
