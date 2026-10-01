## CueFallback — the no-FTUE presentation of director cues (used only while
## `res://ui/ftue/ftue_director.gd` does not exist; the FTUE director replaces it entirely).
##
## On `director_cue {id}` it looks the cue up in the episode's `director.cues`:
## * `target` + `mode` (`tap` | `hold`) → a ghost finger: HUD widgets (`clarence`, `action`, `tray`,
##   `figgis`, `meter`, `pip`, `pause`, `overview`) through `Hud.ghost_finger`, a world hotspot through
##   `Hud.ghost_finger_at` (following the hotspot while the camera moves) — until the cue's `until`
##   holds (`Conditions.eval`), with a re-pulse after `renudge_idle_s` of no input;
## * `mode: sparkle` → `WorldView3D.sparkle(target)` only (no ghost finger);
## * `card` → `Hud.show_figgis_card(icons)` from `barks.json figgis_cards`.
## `figgis_tap()` shows the next line's cue card (`barks.json line_cards["<episode>:<line>"]`).
## The Gate-0 / Prologue cues it must present: `figgis_psst`, `ghost_squeak`, `ghost_honey`,
## `ghost_hold`, `ghost_hide`, `sparkle_lever`; `laugh_*` and `title_card` are not its business.
## **3D view** (the world view has `prop_screen_rect`): the ghost finger's tip sits on the projected hit box of the spot,
## on its half away from Hush (the glove approaches from the side away from her and never covers her);
## `sparkle_lever` = `WorldView3D.sparkle` (the spotlight pool + the preview at full size).
## **Danger is sacred** (REDESIGN §2.5 / V2): while `danger` holds (NightScene: an entry warning, a "?" on her, a
## reaction) every ghost hides; a cue that arrives then is queued, and hints return DANGER_QUIET_S after it is safe.
class_name CueFallback
extends RefCounted

const WIDGETS: PackedStringArray = ["clarence", "action", "tray", "figgis", "meter", "pip", "pause", "overview"]
const CARD_SEC := 4.0
const SPARKLE_SEC := 6.0
## Hints come back this long after the last danger frame (REDESIGN §2.5).
const DANGER_QUIET_S := 1.0

var world: Object = null            ## SimWorld (Conditions.eval, episode, line_states)
var hud: Object = null              ## Hud
var world_view: Object = null       ## WorldView3D (layout, sparkle)
var cam: Object = null              ## CameraDirector3D (world_to_screen)
## The active ghost cue ({} = none).
var active: Dictionary = {}
## Ids presented so far (tests).
var shown: PackedStringArray = PackedStringArray()
## Set by NightScene every frame: danger holds (hints hide, cues queue).
var danger: bool = false
## Seconds since the last input (NightScene; informational — N4 is the overlays' + the spotlight pool's).
var idle_s: float = 0.0
## Seconds since danger last held (hints wait DANGER_QUIET_S).
var safe_s: float = 99.0
## The spot a `sparkle` cue lit and for how long more (NightScene shows its preview at full size meanwhile).
var sparkled: String = ""
var sparkle_left: float = 0.0

var _cues: Dictionary = {}
var _cards: Dictionary = {}
var _line_cards: Dictionary = {}
var _episode: String = ""
var _idle_s: float = 0.0
var _check_t: float = 0.0
var _suspended: bool = false


func setup(p_world: Object, p_hud: Object, p_world_view: Object, p_cam: Object) -> void:
	world = p_world
	hud = p_hud
	world_view = p_world_view
	cam = p_cam
	_cues.clear()
	var ep: Variant = world.get("episode") if world != null else null
	if ep is Object:
		_episode = String((ep as Object).get("id"))
		var dir: Variant = (ep as Object).get("director")
		if dir is Dictionary:
			for c in (dir as Dictionary).get("cues", []):
				if c is Dictionary:
					_cues[String((c as Dictionary).get("id", ""))] = c
	var barks: Variant = ViewKit.json("res://data/barks.json")
	if barks is Dictionary:
		_cards = (barks as Dictionary).get("figgis_cards", {})
		_line_cards = (barks as Dictionary).get("line_cards", {})
	reset()


## Retry: hide everything.
func reset() -> void:
	_hide_ghost()
	active = {}
	shown = PackedStringArray()
	_idle_s = 0.0
	danger = false
	safe_s = 99.0
	sparkled = ""
	sparkle_left = 0.0


## The cue definition for an id ({} when unknown).
func cue(id: String) -> Dictionary:
	return _cues.get(id, {})


## Per-tick events.
func on_events(events: Array) -> void:
	for ev in events:
		var d: Dictionary = ev
		if String(d.get("e", "")) == "director_cue":
			present(String(d.get("id", "")))


## Present one cue by id.
func present(id: String) -> void:
	var c := cue(id)
	if c.is_empty() or id.begins_with("laugh_") or id == "title_card":
		return
	shown.append(id)
	var card := String(c.get("card", "")) if c.get("card") != null else ""
	if card != "":
		_show_card(card)
	var target := String(c.get("target", "")) if c.get("target") != null else ""
	var mode := String(c.get("mode", "tap"))
	if target == "":
		return
	if mode == "sparkle":
		if world_view != null and world_view.has_method("sparkle"):
			world_view.call("sparkle", target, SPARKLE_SEC)
		sparkled = target
		sparkle_left = SPARKLE_SEC
		return
	if _until_holds(c):
		return
	_hide_ghost()
	active = c
	_idle_s = 0.0
	if not danger and safe_s >= DANGER_QUIET_S and not _suspended:
		_show_ghost()


func _show_card(key: String) -> void:
	var entry: Variant = _cards.get(key, null)
	var icons := PackedStringArray()
	if entry is Dictionary:
		for i in (entry as Dictionary).get("icons", []):
			icons.append(String(i))
	if icons.is_empty() or hud == null or not hud.has_method("show_figgis_card"):
		return
	hud.call("show_figgis_card", icons, CARD_SEC)


func _mode_of(c: Dictionary) -> int:
	return GhostFinger.Mode.HOLD if String(c.get("mode", "tap")) == "hold" else GhostFinger.Mode.TAP


func _is_widget(target: String) -> bool:
	return WIDGETS.has(target) or target.begins_with("tray:")


func _show_ghost() -> void:
	if active.is_empty() or hud == null:
		return
	var target := String(active.get("target", ""))
	if _is_widget(target):
		hud.call("ghost_finger", StringName(target), _mode_of(active))
	else:
		_place_world_ghost()


## Screen point (logical px) of a hotspot's top centre, or INF when unknown / off-screen.
func hotspot_screen_point(id: String) -> Vector2:
	var layout: HouseLayout = world_view.get("layout") if world_view != null else null
	var hs := layout.hotspot(id) if layout != null else null
	if hs == null or cam == null:
		return Vector2.INF
	if world_view.has_method("prop_screen_rect"):
		return ghost_tip_3d(world_view.call("prop_screen_rect", id), _hush_screen_x(),
			cam.call("view_size") if cam.has_method("view_size") else Vector2(2400, 1080))
	var p := Vector2(hs.rect.get_center().x, hs.rect.position.y + hs.rect.size.y * 0.35)
	return cam.call("world_to_screen", p)


## 3D (pure): the ghost tip on a projected hit box `r`, on its half away from Hush (screen x `hush_x`), 40 % down;
## INF when the box is off screen.
static func ghost_tip_3d(r: Rect2, hush_x: float, view: Vector2) -> Vector2:
	if not r.has_area() or not r.intersects(Rect2(Vector2.ZERO, view)):
		return Vector2.INF
	var side := 1.0 if r.get_center().x >= hush_x else -1.0
	return Vector2(r.get_center().x + side * r.size.x * 0.22, r.position.y + r.size.y * 0.4)


func _hush_screen_x() -> float:
	if world_view != null and world_view.has_method("actor_screen_rect"):
		var hr: Rect2 = world_view.call("actor_screen_rect", &"hush")
		if hr.has_area():
			return hr.get_center().x
	return 0.0


func _place_world_ghost() -> void:
	var p := hotspot_screen_point(String(active.get("target", "")))
	if p == Vector2.INF:
		return
	if hud.has_method("ghost_finger_at"):
		hud.call("ghost_finger_at", p, _mode_of(active))
	else:
		var g: Variant = hud.get("ghost")
		if g is Control:
			var host: Control = (g as Control).get_parent()
			var local := p
			if host != null:
				local = host.get_global_transform_with_canvas().affine_inverse() * p
			(g as Control).call("show_at", local, _mode_of(active))


func _hide_ghost() -> void:
	if hud != null and hud.has_method("ghost_finger"):
		hud.call("ghost_finger", &"")
	if hud != null:
		var g: Variant = hud.get("ghost")
		if g is Control and (g as Control).has_method("stop"):
			(g as Control).call("stop")


func _until_holds(c: Dictionary) -> bool:
	var u: Variant = c.get("until", null)
	if u == null or world == null:
		return false
	var cs := ViewKit.soft_script("res://sim/systems/conditions.gd")
	if cs == null:
		return false
	return bool(cs.call("eval", world, u))


## Something the player did (resets the idle re-nudge clock).
func on_input() -> void:
	_idle_s = 0.0


## Hide / restore the ghost while a gag punch-in or a panel owns the screen.
func suspend(on: bool) -> void:
	if on == _suspended:
		return
	_suspended = on
	if on:
		_hide_ghost()
	elif not active.is_empty() and not danger and safe_s >= DANGER_QUIET_S:
		_show_ghost()


## Per frame: dismiss the ghost once `until` holds; follow world targets; re-nudge when idle; hide in danger.
func advance(dt: float) -> void:
	if sparkle_left > 0.0:
		sparkle_left -= dt
		if sparkle_left <= 0.0:
			sparkled = ""
	if danger:
		if safe_s > 0.0 and not active.is_empty():
			_hide_ghost()
		safe_s = 0.0
		return
	var was_quiet := safe_s < DANGER_QUIET_S
	safe_s += dt
	if was_quiet:
		if safe_s >= DANGER_QUIET_S and not active.is_empty() and not _suspended:
			_show_ghost()
		return
	if active.is_empty() or _suspended:
		return
	_check_t -= dt
	if _check_t <= 0.0:
		_check_t = 0.1
		if _until_holds(active):
			_hide_ghost()
			active = {}
			return
	if not _is_widget(String(active.get("target", ""))):
		_place_world_ghost()
	_idle_s += dt
	var renudge := float(active.get("renudge_idle_s", 0.0)) if active.get("renudge_idle_s") != null else 0.0
	if renudge > 0.0 and _idle_s >= renudge:
		_idle_s = 0.0
		_show_card("figgis_psst")
		_show_ghost()


## Figgis chip tapped: the next useful line's cue card (first unfinished required line, then
## optional lines, then the Big Number once unsealed).
func figgis_tap() -> void:
	var key := next_line_card_key()
	if key == "":
		return
	var entry: Variant = _line_cards.get(key, null)
	var icons := PackedStringArray()
	if entry is Dictionary:
		for i in (entry as Dictionary).get("icons", []):
			icons.append(String(i))
	if not icons.is_empty() and hud != null and hud.has_method("show_figgis_card"):
		hud.call("show_figgis_card", icons, CARD_SEC)


## `line_cards` key of the next useful line ("" when every line is done / none has a card).
func next_line_card_key() -> String:
	if world == null or not world.has_method("line_states"):
		return ""
	var states: Array = world.call("line_states")
	for pass_i in 3:
		for st in states:
			var s: Dictionary = st
			if bool(s.get("done", false)):
				continue
			var req := bool(s.get("req", false))
			var bn := bool(s.get("big_number", false))
			var want := (pass_i == 0 and req and not bn) or (pass_i == 1 and not req and not bn) \
					or (pass_i == 2 and bn and not bool(s.get("sealed", true)))
			if not want:
				continue
			var key := "%s:%s" % [_episode, String(s.get("id", ""))]
			if _line_cards.has(key):
				return key
	return ""
