## MockWorld — a deterministic, scripted stand-in for SimWorld implementing the TECH §3.4 surface
## the solver uses (tick, step, drain_events, clone, hush/bellows fields, prank_state, line_states,
## stars, applause_tenths, hotspot_state, bubble, bellows_path_preview, state_hash).
## Behaviour is deliberately trivial but reads the same JSON as the solver (house, items, pranks,
## activities, episode), so executor, personas, metrics, invariants and planner can be unit-tested
## before the real sim exists. One floor; rooms are contiguous x ranges.
## - Hush tiptoes 400 / runs 720 sub-px per tick; containers rummage 36 ticks then open a 180-tick
##   pick window; hiding spots dive in 15 ticks; rig points: arrive. `go` while hidden is rejected.
## - Bellows walks his loop at 240 sub-px/tick, performs `dur_s`, fires RIGGED `use` pranks at their
##   mark (a 120-tick reaction, accent at 60, knock-on into a rigged B at the accent), warns 90 ticks
##   before entering Hush's room (pausing at the doorway if needed).
## - Sight: same room, facing her, ≤ 600 px moving / ≤ 250 px frozen, not while reacting (+60).
##   "?" +1 visible / −2 not; full → spotted → caught (240-tick hold, items home, −50).
extends RefCounted

const SUB := 60
const TIPTOE := 400
const RUN := 720
const B_WALK := 240
const RX_LEN := 120
const RX_ACCENT := 60

enum PrankState { LOCKED, AVAILABLE, IN_PROGRESS, RIGGED, FIRED, LANDED }


class MockHush extends RefCounted:
	enum State { IDLE, WALK, RUN, STAIRS, DOOR, RUMMAGE, PICK_WINDOW, RIGGING, DIVING, HIDDEN, POPPING, FROZEN, SQUEAKING, CAUGHT, BOWING }
	var room: String = ""
	var floor: int = 0
	var x_sub: int = 0
	var facing: int = 1
	var state: int = State.IDLE
	var hidden_spot: String = ""
	var watched_spot: String = ""
	var frozen: bool = false
	var carrying: Array = []
	var rig_prank: String = ""
	var rig_step: int = 0
	var pin: String = ""
	var queued: Dictionary = {}
	var at_hotspot: String = ""   ## mirrors the world's `_at` (like SimHush.at_hotspot)

	func copy() -> MockHush:
		var h := MockHush.new()
		h.room = room; h.floor = floor; h.x_sub = x_sub; h.facing = facing; h.state = state
		h.hidden_spot = hidden_spot; h.watched_spot = watched_spot; h.frozen = frozen
		h.carrying = carrying.duplicate(); h.rig_prank = rig_prank; h.rig_step = rig_step
		h.pin = pin; h.queued = queued.duplicate(true); h.at_hotspot = at_hotspot
		return h


class MockBellows extends RefCounted:
	enum State { ROUTINE, DETOUR, CURIOUS, SPOTTED, CHASE, SEARCH, REACTING, MELTDOWN, EXHAUSTED, CAUGHT_HOLD }
	var room: String = ""
	var floor: int = 0
	var x_sub: int = 0
	var facing: int = -1
	var state: int = State.ROUTINE
	var activity_id: String = ""
	var activity_t: int = 0
	var activity_len: int = 0
	var specs_on: bool = false
	var tier: int = 0
	var spot_meter: int = 0
	var spot_fill: int = 60

	func copy() -> MockBellows:
		var b := MockBellows.new()
		b.room = room; b.floor = floor; b.x_sub = x_sub; b.facing = facing; b.state = state
		b.activity_id = activity_id; b.activity_t = activity_t; b.activity_len = activity_len
		b.specs_on = specs_on; b.tier = tier; b.spot_meter = spot_meter; b.spot_fill = spot_fill
		return b


## Tells the solver to use its fallback condition evaluator on this world.
var solver_fallback_conditions := true
var tick: int = 0
var ended: bool = false
var end_reason: String = ""
var hush: MockHush
var bellows: MockBellows
var beryl: Variant = null
var delphine: Variant = null
var episode: Dictionary = {}
var db: Variant = null

var data: SolverData
var ep_id: String = ""
var _events: Array = []
var _applause: int = 0
var _prank: Dictionary = {}          ## id -> PrankState
var _rig_ticks: Dictionary = {}      ## id -> ticks rigged on the current step
var _steps_done: Dictionary = {}     ## id -> steps completed
var _lines: Dictionary = {}          ## line id -> done
var _stock: Dictionary = {}          ## container -> Array of items
var _target: Dictionary = {}         ## {x_sub, hotspot, run}
var _timer: int = 0                  ## busy timer (rummage, dive, caught)
var _at: String = ""                 ## hotspot Hush stands at
var _pick_until: int = -1
var _rig_on: bool = false
var _loop_i: int = 0
var _b_phase: int = 0                ## 0 walk, 1 perform
var _b_pause: int = 0
var _warned: bool = false
var _rx: Dictionary = {}             ## {prank, t}
var _blind_until: int = -1
var _peak: int = 0
var _fired_this_visit: Array = []
var _bases: Dictionary = {}
var _caught_count: int = 0


## A fresh world for `ep` from `p_data` (config ignored).
static func create(p_data: SolverData, p_ep: String, _config: Dictionary = {}) -> Object:
	var w = load("res://tests/solver/fixtures/mock_world.gd").new()
	w._setup(p_data, p_ep)
	return w


func _setup(p_data: SolverData, p_ep: String) -> void:
	data = p_data
	ep_id = p_ep
	episode = data.episode(p_ep)
	hush = MockHush.new()
	bellows = MockBellows.new()
	var hs: Dictionary = episode.get("hush", {}).get("start", {})
	hush.room = SolverData.sv(hs.get("room", "kitchen"))
	hush.x_sub = int(hs.get("x", 3800)) * SUB
	var bs: Dictionary = episode.get("bellows", {}).get("start", {})
	bellows.room = SolverData.sv(bs.get("room", "parlour"))
	bellows.x_sub = int(bs.get("x", 1700)) * SUB
	bellows.spot_fill = data.spot_fill_ticks(p_ep)
	for p in data.episode_pranks(p_ep):
		_prank[p] = PrankState.AVAILABLE
	for l in data.script_lines(p_ep):
		_lines[SolverData.sv(l.get("id", ""))] = false
	for it in data.sorted_ids("items"):
		var src := data.item_source(it)
		if not _stock.has(src):
			_stock[src] = []
		(_stock[src] as Array).append(it)
	_bases = data.line_bases(p_ep)
	_start_walk()


func _emit(e: String, payload: Dictionary = {}) -> void:
	var ev := {"e": e, "t": tick}
	ev.merge(payload)
	_events.append(ev)


# --- API ------------------------------------------------------------------------------------

func drain_events() -> Array:
	var out := _events
	_events = []
	return out


func applause_tenths() -> int:
	return _applause


func prank_state(id: String) -> int:
	return int(_prank.get(id, PrankState.LOCKED))


func line_states() -> Array:
	var out: Array = []
	for l in data.script_lines(ep_id):
		var id := SolverData.sv(l.get("id", ""))
		out.append({"id": id, "done": bool(_lines.get(id, false)), "req": bool(l.get("req", false)),
			"big_number": bool(l.get("big_number", false)), "sealed": false, "candle": false})
	return out


func stars() -> Array:
	var req_ok := true
	var all_ok := true
	for l in line_states():
		if not l["done"]:
			all_ok = false
			if l["req"]:
				req_ok = false
	return [req_ok, all_ok, _applause >= 1000]


func link() -> int:
	return 0


func tomatoes() -> int:
	return _caught_count


func tomatoes_max() -> int:
	return -1


func hotspot_state(id: String) -> Dictionary:
	var h := data.hotspot(id)
	return {"kind": SolverData.sv(h.get("kind", "")), "enabled": true, "stock": _stock.get(id, []),
		"occupant": hush.hidden_spot == id, "in_use_next": false, "spent": false,
		"rigged": false, "needs_item": "", "seen": true}


func bubble() -> Dictionary:
	return {"next": _next_activity(), "icon": "", "ring_ticks": -1, "glyph": "", "ear_pips": 0}


func bellows_path_preview(ticks: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var rooms := data.sorted_ids("rooms")
	var x := bellows.x_sub
	var tx := _station_x(_cur_activity()) * SUB
	var n := ticks / 10
	for i in n:
		if _b_phase == 0 and not bellows.state == MockBellows.State.REACTING:
			var d := tx - x
			x += clampi(d, -B_WALK * 10, B_WALK * 10)
		out.append(rooms.find(_room_at(x / SUB)))
		out.append(x)
	return out


func state_hash() -> int:
	var parts := [tick, hush.x_sub, hush.state, bellows.x_sub, bellows.state, _applause, _loop_i, bellows.spot_meter,
		_b_phase, bellows.activity_t]
	for p in data.sorted_ids("pranks"):
		parts.append(int(_prank.get(p, 0)))
	var h := 2166136261
	for v in parts:
		h = ((h ^ (int(v) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
	return h


func clone() -> Object:
	var w = load("res://tests/solver/fixtures/mock_world.gd").new()
	w.data = data
	w.ep_id = ep_id
	w.episode = episode
	w.tick = tick
	w.ended = ended
	w.end_reason = end_reason
	w.hush = hush.copy()
	w.bellows = bellows.copy()
	w._events = _events.duplicate(true)
	w._applause = _applause
	w._prank = _prank.duplicate()
	w._rig_ticks = _rig_ticks.duplicate()
	w._steps_done = _steps_done.duplicate()
	w._lines = _lines.duplicate()
	w._stock = _stock.duplicate(true)
	w._target = _target.duplicate()
	w._timer = _timer
	w._at = _at
	w._pick_until = _pick_until
	w._rig_on = _rig_on
	w._loop_i = _loop_i
	w._b_phase = _b_phase
	w._b_pause = _b_pause
	w._warned = _warned
	w._rx = _rx.duplicate()
	w._blind_until = _blind_until
	w._peak = _peak
	w._fired_this_visit = _fired_this_visit.duplicate()
	w._bases = _bases
	w._caught_count = _caught_count
	return w


# --- step -------------------------------------------------------------------------------------

func step(cmds: Array) -> void:
	if ended:
		return
	tick += 1
	for c in cmds:
		_apply(c)
	_update_hush()
	_update_bellows()
	_senses()
	hush.at_hotspot = _at


func _reject(c: String, why: String) -> void:
	_emit("cmd_rejected", {"c": c, "why": why})


func _busy() -> bool:
	return hush.state in [MockHush.State.RUMMAGE, MockHush.State.DIVING, MockHush.State.RIGGING]


func _apply(cmd: Dictionary) -> void:
	var c := SolverData.sv(cmd.get("c", ""))
	if hush.state == MockHush.State.CAUGHT:
		_reject(c, "caught")
		return
	match c:
		"go", "move":
			if hush.state == MockHush.State.HIDDEN:
				_reject(c, "hidden")
				return
			if _busy():
				hush.queued = cmd.duplicate()
				return
			_start_go(cmd)
		"pick":
			var it := SolverData.sv(cmd.get("item", ""))
			var stock: Array = _stock.get(_at, [])
			if _at == "" or data.hotspot_kind(_at) != "container" or not stock.has(it):
				_reject("pick", "not here")
				return
			stock.erase(it)
			hush.carrying.append(it)
			_emit("pick", {"item": it})
		"rig":
			if not bool(cmd.get("on", false)):
				_rig_on = false
				if hush.state == MockHush.State.RIGGING:
					hush.state = MockHush.State.IDLE
					if not hush.queued.is_empty():
						var q := hush.queued
						hush.queued = {}
						_start_go(q)
				return
			var p := _prank_at(_at)
			if p == "":
				_reject("rig", "not at a rig point")
				return
			var idx := int(_steps_done.get(p, 0))
			var need := data.step_needs(p, idx)
			if need != "" and not hush.carrying.has(need):
				_reject("rig", "needs %s" % need)
				return
			_rig_on = true
			hush.state = MockHush.State.RIGGING
			hush.rig_prank = p
			hush.rig_step = idx
			_prank[p] = PrankState.IN_PROGRESS
			_emit("rig_start", {"prank": p, "step": idx})
		"freeze":
			hush.frozen = bool(cmd.get("on", false))
			if hush.frozen:
				hush.state = MockHush.State.FROZEN
			elif hush.state == MockHush.State.FROZEN:
				hush.state = MockHush.State.IDLE
			_emit("freeze", {"on": hush.frozen})
		"squeak":
			var heard := bellows.room == hush.room
			_emit("squeak", {"room": hush.room, "x": hush.x_sub / SUB, "heard": heard})
			if heard and bellows.state != MockBellows.State.REACTING:
				_emit("squeak_bit", {"bit": "bit_" + bellows.activity_id, "score": 20})
		"pin":
			hush.pin = SolverData.sv(cmd.get("hotspot", ""))
			_emit("pin", {"room": hush.room, "x": hush.x_sub / SUB})
		"pop_out":
			if hush.state != MockHush.State.HIDDEN:
				_reject("pop_out", "not hidden")
				return
			var spot := hush.hidden_spot
			hush.hidden_spot = ""
			hush.watched_spot = ""
			hush.state = MockHush.State.IDLE
			_at = spot
			_emit("pop_out", {"spot": spot})
			if hush.pin != "":
				var pin := hush.pin
				hush.pin = ""
				_start_go({"c": "go", "hotspot": pin, "run": bool(cmd.get("run", false))})
		"bow":
			if not stars()[0]:
				_reject("bow", "no star")
				return
			ended = true
			end_reason = "bow"
			_emit("night_end", {"reason": "bow"})
		_:
			_reject(c, "unknown")


func _start_go(cmd: Dictionary) -> void:
	var c := SolverData.sv(cmd.get("c", ""))
	var run := bool(cmd.get("run", false))
	if c == "go":
		var hs := SolverData.sv(cmd.get("hotspot", ""))
		if not data.has_hotspot(hs):
			_reject("go", "unknown hotspot")
			return
		if _at == hs and hush.state in [MockHush.State.IDLE, MockHush.State.PICK_WINDOW, MockHush.State.FROZEN]:
			return   # same target as current = no-op
		_target = {"x_sub": data.hotspot_x(hs) * SUB, "hotspot": hs, "run": run}
		_emit("hush_go", {"target": hs, "run": run})
	else:
		var r := data.room(SolverData.sv(cmd.get("room", "")))
		if r.is_empty():
			_reject("move", "unknown room")
			return
		var x := clampi(int(cmd.get("x", 0)), int(r["x0"]), int(r["x1"]) - 1)
		_target = {"x_sub": x * SUB, "hotspot": "", "run": run}
		_emit("hush_go", {"target": "%s:%d" % [r["id"], x], "run": run})
	_at = ""
	hush.frozen = false
	hush.state = MockHush.State.RUN if run else MockHush.State.WALK


func _prank_at(hs: String) -> String:
	for p in data.sorted_ids("pranks"):
		if not _prank.has(p):
			continue
		var idx := int(_steps_done.get(p, 0))
		if idx < data.prank_steps(p).size() and data.rig_point(p, idx) == hs and _prank[p] in [PrankState.AVAILABLE, PrankState.IN_PROGRESS]:
			return p
	return ""


func _room_at(x: int) -> String:
	for r in data.house.get("rooms", []):
		if x >= int(r["x0"]) and x < int(r["x1"]):
			return SolverData.sv(r["id"])
	return "porch" if x < 0 else "kitchen"


func _update_hush() -> void:
	match hush.state:
		MockHush.State.CAUGHT:
			_timer -= 1
			if _timer <= 0:
				hush.state = MockHush.State.IDLE
				hush.x_sub = 350 * SUB
				hush.room = "porch"
				_emit("doorstep")
			return
		MockHush.State.RUMMAGE:
			_timer -= 1
			if _timer <= 0:
				hush.state = MockHush.State.PICK_WINDOW
				_pick_until = tick + 180
				var ids := PackedStringArray()
				for it in _stock.get(_at, []):
					ids.append(String(it))
				_emit("pick_window", {"container": _at, "items": ",".join(ids)})
				_run_queue()
			return
		MockHush.State.DIVING:
			_timer -= 1
			if _timer <= 0:
				hush.state = MockHush.State.HIDDEN
				hush.hidden_spot = _at
				var watched := _visible_now()
				hush.watched_spot = _at if watched else ""
				_emit("hide", {"spot": _at, "watched": watched})
				_run_queue()
			return
		MockHush.State.RIGGING:
			var p := hush.rig_prank
			_rig_ticks[p] = int(_rig_ticks.get(p, 0)) + 1
			if int(_rig_ticks[p]) >= data.step_prep_ticks(p, hush.rig_step):
				_rig_ticks[p] = 0
				var need := data.step_needs(p, hush.rig_step)
				if need != "":
					hush.carrying.erase(need)
				_steps_done[p] = hush.rig_step + 1
				_emit("rig_step_done", {"prank": p, "step": hush.rig_step})
				hush.state = MockHush.State.IDLE
				if int(_steps_done[p]) >= data.prank_steps(p).size():
					_prank[p] = PrankState.RIGGED
					_emit("rigged", {"prank": p})
				_run_queue()
			return
		MockHush.State.PICK_WINDOW:
			if tick >= _pick_until:
				hush.state = MockHush.State.IDLE
		MockHush.State.WALK, MockHush.State.RUN:
			var sp := RUN if hush.state == MockHush.State.RUN else TIPTOE
			var d: int = int(_target["x_sub"]) - hush.x_sub
			if d != 0:
				hush.facing = signi(d)
			hush.x_sub += clampi(d, -sp, sp)
			var r := _room_at(hush.x_sub / SUB)
			if r != hush.room:
				hush.room = r
				_emit("hush_room", {"room": r})
			if hush.x_sub == int(_target["x_sub"]):
				var hs := SolverData.sv(_target["hotspot"])
				_at = hs
				hush.state = MockHush.State.IDLE
				if hs != "":
					_emit("hush_arrive", {"hotspot": hs})
					match data.hotspot_kind(hs):
						"container":
							hush.state = MockHush.State.RUMMAGE
							_timer = 36
							_emit("rummage", {"container": hs})
						"hiding":
							hush.state = MockHush.State.DIVING
							_timer = 15


func _run_queue() -> void:
	if not hush.queued.is_empty() and not _busy() and hush.state != MockHush.State.HIDDEN:
		var q := hush.queued
		hush.queued = {}
		_start_go(q)


# --- Bellows ---------------------------------------------------------------------------------

func _loop() -> Array:
	return data.loop_ids(ep_id)


func _cur_activity() -> String:
	var l := _loop()
	return l[_loop_i % l.size()] if not l.is_empty() else ""


func _next_activity() -> String:
	var l := _loop()
	return l[(_loop_i + 1) % l.size()] if not l.is_empty() else ""


func _station_x(act: String) -> int:
	var st := data.station(SolverData.sv(data.activities.get(act, {}).get("station", "")))
	return int(st.get("stand_x", st.get("x", 0)))


func _start_walk() -> void:
	_b_phase = 0
	_warned = false
	bellows.activity_id = _cur_activity()
	bellows.activity_t = 0
	bellows.activity_len = int(round(float(data.activities.get(bellows.activity_id, {}).get("dur_s", 5)) * 60.0))
	_fired_this_visit = []


func _update_bellows() -> void:
	if bellows.state == MockBellows.State.REACTING:
		_update_reaction()
		return
	if _b_phase == 0:
		if _b_pause > 0:
			_b_pause -= 1
			return
		var tx := _station_x(bellows.activity_id) * SUB
		var d := tx - bellows.x_sub
		if d != 0:
			bellows.facing = signi(d)
		# Entry warning into Hush's room.
		var hroom := hush.room
		if not _warned and hroom != bellows.room and hush.state != MockHush.State.CAUGHT:
			var eta := _eta_to(hroom, tx)
			if eta >= 0 and eta <= 91:
				_warned = true
				_emit("entry_warning", {"room": hroom, "eta": eta})
				if eta < 91:
					_b_pause = 91 - eta
					_emit("doorway_pause", {"ticks": _b_pause})
					return
		bellows.x_sub += clampi(d, -B_WALK, B_WALK)
		var r := _room_at(bellows.x_sub / SUB)
		if r != bellows.room:
			bellows.room = r
			_warned = false
			_emit("b_room", {"room": r})
		if bellows.x_sub == tx:
			_b_phase = 1
			var fac := int(data.activities.get(bellows.activity_id, {}).get("facing", bellows.facing))
			bellows.facing = fac
			_emit("b_activity", {"id": bellows.activity_id})
			_emit("b_next", {"id": _next_activity(), "detour": false})
		return
	bellows.activity_t += 1
	for p in data.sorted_ids("pranks"):
		if not _prank.has(p) or int(_prank[p]) != PrankState.RIGGED or _fired_this_visit.has(p):
			continue
		var tr := data.trigger(p)
		if SolverData.sv(tr.get("type", "")) != "use" or SolverData.sv(tr.get("activity", "")) != bellows.activity_id:
			continue
		if bellows.activity_t == int(round(float(tr.get("mark_s", 0.0)) * 60.0)):
			_fire(p, "use")
			return
	if bellows.activity_t >= bellows.activity_len:
		_emit("b_activity_end", {"id": bellows.activity_id})
		_loop_i += 1
		_start_walk()


## Ticks until he crosses into `room` walking toward tx (−1 never).
func _eta_to(room: String, tx: int) -> int:
	var r := data.room(room)
	if r.is_empty():
		return -1
	var x0 := int(r["x0"]) * SUB
	var x1 := int(r["x1"]) * SUB
	var bx := bellows.x_sub
	if tx >= x0 and bx < x0:
		return (x0 - bx + B_WALK - 1) / B_WALK
	if tx < x1 and bx >= x1:
		return (bx - x1 + 1 + B_WALK - 1) / B_WALK
	return -1


func _fire(p: String, trig: String) -> void:
	_prank[p] = PrankState.FIRED
	_fired_this_visit.append(p)
	_emit("prank_fire", {"prank": p, "trigger": trig, "link": 1, "tier": 1, "witnessed": false})
	_emit("reaction_start", {"prank": p, "archetype": "", "variant": 0, "tier": 1, "suppressed": false, "len": RX_LEN, "entry": ""})
	bellows.state = MockBellows.State.REACTING
	_rx = {"prank": p, "t": 0}


func _update_reaction() -> void:
	_rx["t"] = int(_rx["t"]) + 1
	var p := SolverData.sv(_rx["prank"])
	if int(_rx["t"]) == RX_ACCENT:
		_emit("reaction_accent", {"prank": p})
		_score(p)
		var b := data.knock_on_target(p)
		if b != "" and int(_prank.get(b, 0)) == PrankState.RIGGED:
			_emit("knock_on", {"a": p, "b": b})
			_prank[p] = PrankState.LANDED
			_land_lines(p)
			_fire(b, "knock_on")
			_rx["knocked_from"] = p
			return
	if int(_rx["t"]) >= RX_LEN:
		_emit("reaction_end", {"prank": p})
		_prank[p] = PrankState.LANDED
		_land_lines(p)
		if _rx.has("knocked_from"):
			for l in data.script_lines(ep_id):
				if SolverData.sv(l.get("kind", "")) == "double_act":
					var da: Dictionary = data.double_acts.get(SolverData.sv(l.get("double_act", "")), {})
					if SolverData.sv(da.get("a", "")) == SolverData.sv(_rx["knocked_from"]) and SolverData.sv(da.get("b", "")) == p:
						_mark_line(SolverData.sv(l["id"]))
		bellows.state = MockBellows.State.ROUTINE
		_blind_until = tick + 60
		_rx = {}
		var resume := bool(data.trigger(p).get("resume", false))
		if not resume or _b_phase == 0:
			_emit("b_activity_end", {"id": bellows.activity_id})
			_loop_i += 1
			_start_walk()


func _score(p: String) -> void:
	for l in data.script_lines(ep_id):
		if SolverData.sv(l.get("kind", "")) == "prank" and SolverData.sv(l.get("prank", "")) == p:
			var d := int(_bases.get(SolverData.sv(l["id"]), 0))
			_applause += d
			_emit("applause", {"delta": d, "total": _applause, "kind": "gag", "label": p})


func _land_lines(p: String) -> void:
	for l in data.script_lines(ep_id):
		if SolverData.sv(l.get("kind", "")) == "prank" and SolverData.sv(l.get("prank", "")) == p:
			_mark_line(SolverData.sv(l["id"]))


func _mark_line(id: String) -> void:
	if not bool(_lines.get(id, false)):
		_lines[id] = true
		_emit("line_done", {"line": id})


# --- senses ---------------------------------------------------------------------------------

func _visible_now() -> bool:
	if bellows.state == MockBellows.State.REACTING or tick < _blind_until:
		return false
	if hush.state in [MockHush.State.HIDDEN, MockHush.State.CAUGHT] or hush.room != bellows.room:
		return false
	var dx := hush.x_sub - bellows.x_sub
	if dx != 0 and signi(dx) != bellows.facing:
		return false
	var rng := 250 if hush.frozen else 600
	return absi(dx) <= rng * SUB


func _senses() -> void:
	if hush.state == MockHush.State.CAUGHT:
		bellows.spot_meter = 0
		return
	var vis := _visible_now() or (hush.state == MockHush.State.HIDDEN and hush.watched_spot != "")
	var before := bellows.spot_meter
	if vis:
		bellows.spot_meter += 1
		if before == 0:
			_emit("spot_start", {"by": "bellows"})
	else:
		bellows.spot_meter = maxi(0, bellows.spot_meter - 2)
	_peak = maxi(_peak, bellows.spot_meter)
	if before > 0 and bellows.spot_meter == 0:
		if _peak * 2 >= bellows.spot_fill:
			_emit("near_miss", {"by": "bellows"})
		_peak = 0
	if bellows.spot_meter >= bellows.spot_fill:
		_emit("spotted", {"by": "bellows"})
		var sp := tick
		bellows.spot_meter = 0
		_peak = 0
		_caught(sp)


func _caught(spotted_tick: int) -> void:
	_emit("caught", {"cause": "grab", "spotted_tick": spotted_tick, "by": "bellows"})
	_caught_count += 1
	for it in hush.carrying:
		_emit("item_home", {"item": it})
		var src := data.item_source(String(it))
		if not _stock.has(src):
			_stock[src] = []
		(_stock[src] as Array).append(it)
	hush.carrying = []
	hush.hidden_spot = ""
	hush.watched_spot = ""
	hush.frozen = false
	hush.queued = {}
	_rig_on = false
	_at = ""
	hush.state = MockHush.State.CAUGHT
	_timer = 240
	_applause = maxi(0, _applause - 50)
	_emit("applause", {"delta": -50, "total": _applause, "kind": "catch", "label": ""})
