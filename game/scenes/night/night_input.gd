## NightInput — turns the HUD's intents and the world gestures into sim commands and camera / view
## calls (TECH §6, GDD §3.1–§3.6; the intent table of the ui report). NightScene owns one and wires
## the Hud / InputRouter signals to the `on_*` methods; `advance(dt)` runs once per frame.
##
## | Intent | Result |
## |---|---|
## | action_down(RIG) / action_up(RIG) | `rig on` / `rig off`; camera hold offset while held |
## | action_down(FREEZE) / action_up(FREEZE) | `freeze on` / `freeze off`; hold offset |
## | action_up(POP_OUT / GO, not cancelled) | `pop_out`; a double tap upgrades the walk to the pin to a run |
## | action_up(RIG_DIM, not cancelled) | the container holding the item sparkles + an edge arrow (3 s) |
## | clarence (SQUEAK mode, latched at touch-down) | tap < 500 ms → `squeak`; hold → `wheeze on` … `wheeze off` |
## | clarence (⏩ mode while hidden) | down → `SimDriver.set_ff(true)`, up → `set_ff(false)` |
## | tapped(world) | TapAssist → `go` / `move` (`run` on a double tap); hidden or frozen → `pin` |
## | long_pressed / long_released | reveal every badge 2 s; lifting over a hotspot selects it |
## | pan / pinch | camera; a drag never moves Hush |
## | pip_tap / pip_release | camera peek at Bellows, held while the finger is down |
## | tray_tap(i) | matching rig points sparkle + off-screen edge arrows 3 s |
## | tray_drag(i, pos) | go to the hotspot under the release point (rigging stays a hold) |
## | pick(item) | `pick` |
## Feedback in the frame of every accepted tap: `fx.ripple`, `fx.path_dots`, an 8 ms `Haptics.tap()`.
## **3D view** (`view3d = true`, index §7.8): world gestures arrive in logical SCREEN px; the candidates are
## WorldView3D's projected hit boxes (`hotspot_rects_in_view()` → `rect`) + its floor bands, resolved by
## `TapAssist.resolve(pos, rects, 1.0)`; a floor result's x is the lane-plane hit (`cam.screen_to_world(pos).x`,
## clamped to the room); the tapped spot pops in the same frame (`world_view.tap_feedback(pos)`: the ripple + the
## destination ring); a struck hotspot's `cmd_rejected` makes WorldView3D wobble "no" at the tap.
## Every collaborator is soft-typed (`call` / `has_method`), so tests drive it with stubs.
class_name NightInput
extends RefCounted

## Emitted for every command pushed (tests, the device's command log).
signal command(cmd: Dictionary)
## Emitted after a world tap was accepted (tests: feedback in the same frame).
signal tap_feedback(world_pos: Vector2, target: Vector2)

const REVEAL_S := 2.0
const ARROW_S := 3.0
const PEEK_HOLD_S := 1.8
const SQUEAK_MAX_MS := 500
const DOUBLE_TAP_FEEDBACK := true

var driver: Object = null            ## SimDriver (push_cmd, set_ff, snapshot)
var cam: Object = null               ## CameraDirector
var world_view: Object = null        ## WorldView (hotspot_rects_in_view, fx, layout, unlocked, …)
var hud: Object = null               ## Hud (optional: tray arrows)
var haptics: Object = null           ## Haptics autoload (optional)
## False while panels, the curtain or a cut-scene own the screen.
var enabled: bool = true
## ctx provider: returns world.action_context() or {} (container of a missing item).
var context_fn: Callable = Callable()
## 3D view: taps are screen px resolved on the projected hit boxes (see the class doc).
var view3d: bool = false

## Screen directions of off-screen targets to point at (HudModel.tray_arrows), and until when.
var arrows := PackedVector2Array()
var arrows_left: float = 0.0
## The hotspots pulsed by the last tray / RIG_DIM tap.
var pulsed := PackedStringArray()

var _action_verb: int = -1
var _clarence_ff: bool = false
var _clarence_wheeze: bool = false
var _peek_held: bool = false
var _reveal_left: float = 0.0
var _last_pin: Dictionary = {}
var _untappable: Dictionary = {}


func _init() -> void:
	var hj: Variant = ViewKit.json("res://data/house/house.json")
	if hj is Dictionary:
		for hs in (hj as Dictionary).get("hotspots", []):
			if hs is Dictionary and (hs as Dictionary).get("tappable", true) == false:
				_untappable[String((hs as Dictionary).get("id", ""))] = true


## Push a command to the sim (and announce it).
func push(cmd: Dictionary) -> void:
	if driver != null:
		driver.call("push_cmd", cmd)
	command.emit(cmd)


func _snap() -> ViewSnapshot:
	return driver.call("snapshot") if driver != null and driver.has_method("snapshot") else null


# --- action button --------------------------------------------------------------------------

func on_action_down(verb: int) -> void:
	if not enabled:
		return
	_action_verb = verb
	match verb:
		HudModel.Verb.RIG:
			push({"c": "rig", "on": true})
			_hold_offset(true)
		HudModel.Verb.FREEZE:
			push({"c": "freeze", "on": true})
			_hold_offset(true)


func on_action_up(verb: int, cancelled: bool) -> void:
	var v := _action_verb if _action_verb >= 0 else verb
	_action_verb = -1
	_hold_offset(false)
	match v:
		HudModel.Verb.RIG:
			push({"c": "rig", "on": false})
		HudModel.Verb.FREEZE:
			push({"c": "freeze", "on": false})
		HudModel.Verb.POP_OUT, HudModel.Verb.GO:
			if not cancelled and enabled:
				push({"c": "pop_out", "run": false})
		HudModel.Verb.RIG_DIM:
			if not cancelled and enabled:
				_pulse_container()


## A double tap on POP OUT / GO: she already popped out on the first tap; run to the pin.
func on_action_double_tap(verb: int) -> void:
	if not enabled or (verb != HudModel.Verb.POP_OUT and verb != HudModel.Verb.GO):
		return
	if _last_pin.is_empty():
		return
	var c := _last_pin.duplicate()
	c["c"] = "go" if c.has("hotspot") else "move"
	c["run"] = true
	push(c)


## Cancel a held verb (panel opened, focus lost): release what the sim holds.
func release_holds() -> void:
	if _action_verb == HudModel.Verb.RIG:
		push({"c": "rig", "on": false})
	elif _action_verb == HudModel.Verb.FREEZE:
		push({"c": "freeze", "on": false})
	_action_verb = -1
	_hold_offset(false)
	if _clarence_wheeze:
		push({"c": "wheeze", "on": false})
		_clarence_wheeze = false
	if _clarence_ff and driver != null:
		driver.call("set_ff", false)
	_clarence_ff = false
	_peek_held = false


func _hold_offset(on: bool) -> void:
	if cam != null and cam.has_method("set_hold_offset"):
		cam.call("set_hold_offset", on)


# --- Clarence / ⏩ ----------------------------------------------------------------------------

func on_clarence_down() -> void:
	if not enabled:
		return
	var s := _snap()
	_clarence_ff = s != null and s.hush.state == "HIDDEN"
	_clarence_wheeze = false
	if _clarence_ff and driver != null:
		driver.call("set_ff", true)


func on_clarence_hold() -> void:
	if not enabled or _clarence_ff:
		return
	_clarence_wheeze = true
	push({"c": "wheeze", "on": true})


func on_clarence_up(held_ms: int) -> void:
	if _clarence_ff:
		_clarence_ff = false
		if driver != null:
			driver.call("set_ff", false)
		return
	if _clarence_wheeze:
		_clarence_wheeze = false
		push({"c": "wheeze", "on": false})
		return
	if enabled and held_ms < SQUEAK_MAX_MS:
		push({"c": "squeak"})


# --- world gestures -------------------------------------------------------------------------

## Tap candidates for TapAssist: 2D — the hotspots in view (their world rects) + one floor band per open room
## (world px); 3D — the projected hit boxes and floor bands (logical screen px).
func candidates() -> Array:
	if view3d:
		return screen_candidates()
	var out: Array = []
	if world_view == null:
		return out
	var layout: HouseLayout = world_view.get("layout")
	var rects: Array = world_view.call("hotspot_rects_in_view") if world_view.has_method("hotspot_rects_in_view") else []
	for r in rects:
		var d: Dictionary = r
		var id := String(d.get("id", ""))
		if _untappable.has(id):
			continue
		var hs: HouseLayout.Hotspot = layout.hotspot(id) if layout != null else null
		var c := {"id": id, "kind": String(d.get("kind", "hotspot")), "rect": d.get("world_rect", d.get("rect", Rect2())),
			"room": hs.room if hs != null else "", "priority": int(d.get("priority", 2))}
		if d.has("enabled"):
			c["enabled"] = d["enabled"]
		if d.has("stack"):
			c["stack"] = d["stack"]
		out.append(c)
	if layout != null:
		var open: Variant = world_view.get("unlocked")
		for room in layout.rooms:
			if open is PackedStringArray and not (open as PackedStringArray).has(room.id):
				continue
			var fy := layout.floor_y(room.floor)
			out.append({"id": "floor_" + room.id, "kind": "floor", "room": room.id,
				"rect": Rect2(room.x0, fy - layout.interior_h, room.x1 - room.x0, layout.interior_h + layout.slab_h)})
	return out


var _screen_out: Array = []


## 3D: the projected hit boxes (logical screen px) + the floor bands, one reused array.
func screen_candidates() -> Array:
	_screen_out.clear()
	if world_view == null or not world_view.has_method("hotspot_rects_in_view"):
		return _screen_out
	for r in world_view.call("hotspot_rects_in_view"):
		var d: Dictionary = r
		var id := String(d.get("id", ""))
		if _untappable.has(id):
			continue
		var c := {"id": id, "kind": String(d.get("kind", "hotspot")), "rect": d.get("rect", Rect2()),
			"room": String(d.get("room", "")), "priority": int(d.get("priority", 2))}
		if d.has("enabled"):
			c["enabled"] = d["enabled"]
		if d.has("stack"):
			c["stack"] = d["stack"]
		_screen_out.append(c)
	return _screen_out


func _zoom() -> float:
	if view3d:
		return 1.0
	return float(cam.call("current_zoom")) if cam != null and cam.has_method("current_zoom") else 1.0


## Resolve a tap (2D: world px; 3D: logical screen px) to a command dictionary ({} = nothing there).
func resolve(pos: Vector2) -> Dictionary:
	var r := TapAssist.resolve(pos, candidates(), _zoom())
	if view3d and String(r.get("c", "")) == "move":
		r["x"] = lane_x(pos, String(r.get("room", "")))
	return r


## 3D: the sim x (px) of the lane point under a screen point, clamped inside the room.
func lane_x(screen_pos: Vector2, room: String) -> int:
	var x := screen_pos.x
	if cam != null and cam.has_method("screen_to_world"):
		x = (cam.call("screen_to_world", screen_pos) as Vector2).x
	var layout: HouseLayout = world_view.get("layout") if world_view != null else null
	var rr: HouseLayout.Room = layout.room(room) if layout != null and room != "" else null
	if rr != null:
		x = clampf(x, rr.x0 + 30.0, rr.x1 - 30.0)
	return int(round(x))


func on_tapped(world_pos: Vector2, is_double: bool) -> void:
	if not enabled:
		return
	var r := resolve(world_pos)
	if r.is_empty():
		return
	var s := _snap()
	var pin := s != null and (s.hush.state == "HIDDEN" or s.hush.state == "FROZEN")
	var cmd := {}
	if pin:
		cmd = {"c": "pin", "hotspot": r["hotspot"]} if r["c"] == "go" else {"c": "pin", "room": r["room"], "x": r["x"]}
		_last_pin = cmd.duplicate()
		_last_pin.erase("c")
	else:
		cmd = r.duplicate()
		cmd.erase("kind")
		cmd.erase("assisted")
		if cmd["c"] == "go":
			cmd.erase("room")
		cmd["run"] = is_double
	push(cmd)
	_feedback(world_pos, _target_point(r), s)


func _target_point(r: Dictionary) -> Vector2:
	var layout: HouseLayout = world_view.get("layout") if world_view != null else null
	if layout == null:
		return Vector2.ZERO
	if String(r.get("c", "")) == "go":
		var hs := layout.hotspot(String(r.get("hotspot", "")))
		if hs != null:
			return Vector2(hs.use_x, layout.room_floor_y(hs.room))
	return Vector2(float(r.get("x", 0)), layout.room_floor_y(String(r.get("room", ""))))


func _feedback(world_pos: Vector2, target: Vector2, s: ViewSnapshot) -> void:
	if view3d:
		_feedback_3d(world_pos, target, s)
		return
	var fx: Object = world_view.get("fx") if world_view != null else null
	if fx != null:
		fx.call("ripple", world_pos)
		if s != null and target != Vector2.ZERO:
			var from := Vector2(s.hush.x, s.hush.y)
			var hv: Variant = world_view.get("hush_view")
			if hv is Node2D:
				from = (hv as Node2D).global_position
			fx.call("path_dots", PackedVector2Array([from + Vector2(0, -6), target + Vector2(0, -6)]))
	if haptics != null and haptics.has_method("tap"):
		haptics.call("tap")
	tap_feedback.emit(world_pos, target)


## 3D: the tapped spot pops at the tap (≤ 1 frame) and the destination ring + dotted path go down on the floor.
func _feedback_3d(screen_pos: Vector2, target: Vector2, s: ViewSnapshot) -> void:
	if world_view != null and world_view.has_method("tap_feedback"):
		world_view.call("tap_feedback", screen_pos)
	var fx: Object = world_view.get("fx") if world_view != null else null
	if fx != null and s != null and target != Vector2.ZERO:
		fx.call("path_dots", PackedVector2Array([Vector2(s.hush.x, s.hush.y), target]))
	if haptics != null and haptics.has_method("tap"):
		haptics.call("tap")
	tap_feedback.emit(screen_pos, target)


func on_long_pressed(_world_pos: Vector2) -> void:
	if not enabled:
		return
	_reveal(true)
	_reveal_left = REVEAL_S
	if haptics != null and haptics.has_method("tap"):
		haptics.call("tap")


## Lifting over a hotspot selects it (an exact hit only; the floor is not a selection).
func on_long_released(world_pos: Vector2) -> void:
	if not enabled:
		return
	var r := resolve(world_pos)
	if r.is_empty() or String(r.get("c", "")) != "go" or bool(r.get("assisted", false)):
		return
	on_tapped(world_pos, false)


func _reveal(on: bool) -> void:
	if world_view != null and world_view.has_method("reveal_badges"):
		world_view.call("reveal_badges", on)


func on_pan(screen_delta: Vector2) -> void:
	if enabled and cam != null:
		cam.call("pan_by", screen_delta)


func on_pinch(factor: float, mid: Vector2) -> void:
	if enabled and cam != null:
		cam.call("pinch", factor, mid)


# --- PiP, overview, tray, pick ------------------------------------------------------------------

func on_pip_tap() -> void:
	if not enabled:
		return
	_peek_held = true
	_peek()


func on_pip_release() -> void:
	_peek_held = false


func _bellows_focus() -> Vector2:
	var bv: Variant = world_view.get("bellows_view") if world_view != null else null
	if bv is Node2D:
		return (bv as Node2D).global_position + Vector2(0, -200)
	var s := _snap()
	return Vector2(s.bellows.x, s.bellows.y - 200.0) if s != null else Vector2.ZERO


func _peek() -> void:
	if cam != null and cam.has_method("peek"):
		cam.call("peek", _bellows_focus(), PEEK_HOLD_S, _bellows_focus)


func on_overview_tap() -> void:
	if not enabled or cam == null:
		return
	cam.call("toggle_overview")
	if hud != null and hud.has_method("set_overview"):
		hud.call("set_overview", bool(cam.call("is_overview")))


func on_pick(item: String) -> void:
	if enabled:
		push({"c": "pick", "item": item})


## Tray slot tap: "where does this go?" — the rig points that take this item sparkle; off-screen
## ones get edge arrows for 3 s.
func on_tray_tap(i: int) -> void:
	if not enabled:
		return
	var s := _snap()
	if s == null or i < 0 or i >= s.hush.carrying.size():
		return
	_point_at(rig_points_for_item(s.hush.carrying[i]))


## Drag an item onto a hotspot = walk there (rigging stays a hold).
func on_tray_drag(_i: int, screen_pos: Vector2) -> void:
	if not enabled or cam == null:
		return
	var wp: Vector2 = screen_pos if view3d else cam.call("screen_to_world", screen_pos)
	var r := resolve(wp)
	if r.is_empty() or String(r.get("c", "")) != "go":
		return
	on_tapped(wp, false)


## RIG dimmed: the container that holds the needed item pulses (edge arrow if off-screen).
func _pulse_container() -> void:
	var ctx: Dictionary = context_fn.call() if context_fn.is_valid() else {}
	var cont := String(ctx.get("container", ""))
	var s := _snap()
	if cont == "" and s != null:
		var need := String(ctx.get("item_needed", ""))
		if need == "":
			need = _needed_here(s)
		cont = container_for_item(s, need)
	if cont != "":
		_point_at(PackedStringArray([cont]))


func _needed_here(s: ViewSnapshot) -> String:
	for id in s.hotspots:
		var st: Dictionary = s.hotspots[id]
		if String(st.get("kind", "")) != "rig_point":
			continue
		var layout: HouseLayout = world_view.get("layout")
		var hs := layout.hotspot(String(id)) if layout != null else null
		if hs != null and hs.room == s.hush.room and absf(hs.use_x - s.hush.x) < 60.0:
			return String(st.get("needs_item", ""))
	return ""


## A container in tonight's rooms whose stock holds `item` ("" when none).
func container_for_item(s: ViewSnapshot, item: String) -> String:
	if item == "":
		return ""
	var best := ""
	for id in s.hotspots:
		var st: Dictionary = s.hotspots[id]
		if String(st.get("kind", "")) == "container" and bool(st.get("enabled", true)):
			var stock: Variant = st.get("stock", [])
			if (stock is Array or stock is PackedStringArray) and item in stock:
				if best == "" or String(id) < best:
					best = String(id)
	return best


## Rig points of tonight's pranks whose next step needs `item`.
func rig_points_for_item(item: String) -> PackedStringArray:
	var out := PackedStringArray()
	var s := _snap()
	if s == null:
		return out
	for id in s.hotspots:
		var st: Dictionary = s.hotspots[id]
		if String(st.get("kind", "")) == "rig_point" and String(st.get("needs_item", "")) == item and bool(st.get("enabled", false)):
			out.append(String(id))
	out.sort()
	return out


func _point_at(ids: PackedStringArray) -> void:
	pulsed = ids
	arrows.clear()
	if world_view == null:
		return
	var layout: HouseLayout = world_view.get("layout")
	var vis: Rect2 = cam.call("visible_world_rect") if cam != null and cam.has_method("visible_world_rect") else Rect2()
	for id in ids:
		if world_view.has_method("sparkle"):
			world_view.call("sparkle", id, ARROW_S)
		var hs := layout.hotspot(id) if layout != null else null
		if hs == null or cam == null:
			continue
		if not vis.intersects(hs.rect):
			var sp: Vector2 = cam.call("world_to_screen", hs.rect.get_center())
			var vs: Vector2 = cam.call("view_size") if cam.has_method("view_size") else Vector2(1920, 1080)
			arrows.append((sp - vs * 0.5).normalized())
	arrows_left = ARROW_S if not ids.is_empty() else 0.0


# --- per frame ------------------------------------------------------------------------------------

func advance(dt: float) -> void:
	if _peek_held:
		_peek()
	if _reveal_left > 0.0:
		_reveal_left -= dt
		if _reveal_left <= 0.0:
			_reveal(false)
	if arrows_left > 0.0:
		arrows_left -= dt
		if arrows_left <= 0.0:
			arrows.clear()
			pulsed = PackedStringArray()


## Forget per-Night state (retry).
func reset() -> void:
	release_holds()
	_last_pin = {}
	arrows.clear()
	arrows_left = 0.0
	_reveal_left = 0.0
	_reveal(false)
