## Invariants — the TECH §8.6 fairness assertions over a run log (solver routes and fuzz runs).
##
##   var bad: Array[String] = Invariants.check(log)     # [] = fair
##
##  1. every `caught` has a preceding "?" that filled continuously for ≥ the episode's fill time
##     (or a `face_to_face` window ≥ 48 ticks);
##  2. every non-chase `b_room` into Hush's room has an `entry_warning` ≥ 90 ticks earlier (`b_room.chase`
##     entries and his reaction travel — `b_room` while REACTING — are exempt);
##  3. no `caught` while Hush is in an unwatched hiding spot that is not in use;
##  4. `b_next` shows each loop activity ≥ 240 ticks before he leaves a ≥ 4 s activity (unless a punchline,
##     Meltdown, chase or catch re-planned his route inside that window); every `b_detour` has a `b_next` on the
##     same tick;
##  5. determinism: replaying the command log gives the same hash (`log.replay_hash`, filled by the
##     runner via `replay_hash()`);
##  6. no soft-lock: every planner probe on the run's state succeeded (`log.softlock_probes`);
##  7. Bellows' non-chase speed ≤ 1.15 × walk; the `b_activity` sequence follows the loop order;
##  8. no `spot_start` while he is reacting or within 60 ticks after;
##  9. progress: his activity changes at least every 60 s (player-led gates excepted); every go/move answers
##     within 1 tick (movement, `hush_go`, an arrival, a pin, a rejection…); a `cmd_queued` one (held behind a
##     busy action: the climb-in, a rummage, a rig hold, the stairs, a door, the caught hold) must run the tick
##     that action ends, unless a newer go/move replaced it first;
## 10. at most one reaction at a time; applause never negative; prank bases sum to 700 tenths;
## 11. (Stage 3, only when Beryl exists) Beryl's headbutt never produces `caught`;
## 12. no `combo` the Night's `rules.combos` does not allow (`[]` = none: ruling L4).
class_name Invariants
extends RefCounted

const ENTRY_WARN_TICKS := 90
const FACE_TO_FACE_TICKS := 48
const BUBBLE_TICKS := 240
const BLIND_AFTER_TICKS := 60
const PROGRESS_TICKS := 3600
## A go/move must answer within this many ticks (TECH §3.5: the same tick; +1 for a logging boundary).
const FEEDBACK_TICKS := 1
## Hush states a queued go/move waits behind (+ the climb-in, `log.enter_ticks`, and FROZEN: a freeze held
## over the busy action keeps the queue until she unfreezes).
const HELD_STATES: PackedStringArray = ["RUMMAGE", "DIVING", "POPPING", "SQUEAKING", "RIGGING", "CAUGHT", "BOWING",
	"STAIRS", "DOOR", "FROZEN"]
const SPEED_STATES: PackedStringArray = ["ROUTINE", "DETOUR", "CURIOUS", "SEARCH"]
const PROGRESS_EVENTS: PackedStringArray = ["b_activity", "b_activity_end", "b_detour", "reaction_start",
	"reaction_end", "chase_start", "search", "meltdown_start", "exhausted", "caught", "night_end"]
## Events that tell the player a tap was taken: a start, an arrival, a rejection, or `cmd_queued`
## (the go/move is held behind a busy action — the climb-in, a rummage, a rig hold — and the view
## shows it as queued; TECH §3.5, §3.8).
const FEEDBACK_EVENTS: PackedStringArray = ["hush_go", "hush_arrive", "cmd_rejected", "cmd_queued", "pin", "rummage",
	"hide", "pop_out", "hush_room", "pick_window", "caught", "night_end", "doorstep", "freeze"]
## Events that re-plan Bellows' route inside a bubble's notice window (rule 4(b)).
const DISTURB_EVENTS: PackedStringArray = ["reaction_start", "reaction_end", "meltdown_start", "exhausted", "spotted",
	"chase_start", "chase_end", "caught", "search", "on_guard"]
## What a queued go/move does the tick it runs.
const RAN_EVENTS: PackedStringArray = ["hush_go", "hush_arrive", "cmd_rejected", "pin", "caught", "night_end", "rummage",
	"hush_room"]
const MAX_PER_RULE := 5


## All violations of `log` ("rule N: …" strings; [] = fair).
static func check(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	out.append_array(rule1_spot_window(log))
	out.append_array(rule2_entry_warning(log))
	out.append_array(rule3_safe_hiding(log))
	out.append_array(rule4_bubble(log))
	out.append_array(rule5_determinism(log))
	out.append_array(rule6_softlock(log))
	out.append_array(rule7_speed_and_loop(log))
	out.append_array(rule8_blind_reacting(log))
	out.append_array(rule9_progress(log))
	out.append_array(rule10_reactions_applause(log))
	out.append_array(rule11_headbutt(log))
	out.append_array(rule12_combos(log))
	return out


static func _t(t: int) -> String:
	return "t=%d (%.2f s)" % [t, t / 60.0]


static func _cap(arr: Array[String], rule: int, extra: int) -> Array[String]:
	if extra > 0:
		arr.append("rule %d: … and %d more" % [rule, extra])
	return arr


## Rule 1: every catch had a fair "?" window.
static func rule1_spot_window(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	for ev in log.events_named("caught"):
		var tc := int(ev.get("t", 0))
		var cause := SolverData.sv(ev.get("cause", ""))
		# Face-to-face (Mirror, Mirror / in-use spot): a ≥ 48-tick window.
		var f2f: Variant = null
		for fe in log.events_named("face_to_face"):
			var ft := int(fe.get("t", 0))
			if ft <= tc and tc - ft <= 600:
				f2f = fe
		if f2f != null or cause == "face_to_face":
			var ft2 := int((f2f as Dictionary).get("t", tc)) if f2f != null else tc
			if tc - ft2 < FACE_TO_FACE_TICKS:
				out.append("rule 1: caught at %s only %d ticks after face_to_face (< %d)" % [_t(tc), tc - ft2, FACE_TO_FACE_TICKS])
			continue
		var sp := int(ev.get("spotted_tick", -1))
		if sp < 0:
			for se in log.events_named("spotted"):
				if int(se.get("t", 0)) <= tc:
					sp = int(se.get("t", 0))
		if sp < 0:
			out.append("rule 1: caught at %s (%s) with no preceding 'spotted'" % [_t(tc), cause])
			continue
		var t0 := _last_zero_before(log, sp - 1)
		if t0 < 0:
			for ss in log.events_named("spot_start"):
				if int(ss.get("t", 0)) <= sp:
					t0 = int(ss.get("t", 0)) - 1
		if t0 < 0:
			out.append("rule 1: caught at %s: no '?' window found before spotted at %s" % [_t(tc), _t(sp)])
			continue
		var win := sp - t0
		if win < log.fill_ticks - 1:
			out.append("rule 1: caught at %s: '?' filled in %d ticks (< fill %d) before spotted at %s" % [
				_t(tc), win, log.fill_ticks, _t(sp)])
	return out


## Last sampled tick ≤ t where the spot meter was 0 (−1 if unknown). Callers pass spotted − 1:
## the meter may already be reset on the spotted tick itself.
static func _last_zero_before(log: SolverLog, t: int) -> int:
	var i := log.index_of_tick(t)
	if i < 0:
		return -1
	while i >= 0:
		if log.spot[i] == 0:
			return log.ticks[i]
		i -= 1
	return log.ticks[0] - 1 if log.size() > 0 else -1


## Rule 2: no ambush — warnings ≥ 90 ticks before every non-chase entry into Hush's room.
static func rule2_entry_warning(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	var extra := 0
	var prev_room_t := log.start_tick - 1
	for ev in log.events:
		if SolverData.sv(ev.get("e", "")) != "b_room":
			continue
		var t := int(ev.get("t", 0))
		var room := SolverData.sv(ev.get("room", ""))
		var i := log.index_of_tick(t)
		var ip := log.index_of_tick(t - 1)
		var from_t := prev_room_t
		prev_room_t = t
		if i < 0:
			continue
		if log.name_of(log.hush_room[i]) != room:
			continue
		if log.name_of(log.hush_state[i]) in ["CAUGHT", "BOWING"]:
			continue
		# a chase entry (the event says so; older logs: the sampled state) is exempt, and so is his reaction
		# travel (a punchline that carries him into her room: REACTING on either side of the step)
		var chase := bool(ev["chase"]) if ev.has("chase") else \
			(log.name_of(log.b_state[i]) == "CHASE" or (ip >= 0 and log.name_of(log.b_state[ip]) == "CHASE"))
		if chase:
			continue
		if log.name_of(log.b_state[i]) == "REACTING" or (ip >= 0 and log.name_of(log.b_state[ip]) == "REACTING"):
			continue
		var warned := false
		for w in log.events_named("entry_warning", {"room": room}):
			var wt := int(w.get("t", 0))
			if wt > from_t and wt <= t - ENTRY_WARN_TICKS:
				warned = true
				break
		if not warned:
			if out.size() < MAX_PER_RULE:
				var got := -1
				for w in log.events_named("entry_warning", {"room": room}):
					var wt2 := int(w.get("t", 0))
					if wt2 > from_t and wt2 <= t:
						got = t - wt2
				out.append("rule 2: Bellows entered %s (Hush's room) at %s with %s" % [room, _t(t),
					"no entry_warning" if got < 0 else "a warning only %d ticks earlier (< %d)" % [got, ENTRY_WARN_TICKS]])
			else:
				extra += 1
	return _cap(out, 2, extra)


## Rule 3: an unwatched hiding spot that is not in use is 100 % safe.
static func rule3_safe_hiding(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	for ev in log.events_named("caught"):
		var tc := int(ev.get("t", 0))
		var i := log.index_of_tick(tc - 1)
		if i < 0:
			continue
		var spot := log.name_of(log.hush_hidden[i])
		if spot == "" or log.hush_watched[i] == 1:
			continue
		var in_use_act := SolverData.sv(log.in_use.get(spot, ""))
		if in_use_act != "" and log.name_of(log.b_activity[i]) == in_use_act:
			continue
		out.append("rule 3: caught at %s while hidden unseen in %s (not in use)" % [_t(tc), spot])
	return out


## Rule 4: the bubble shows the next loop activity ≥ 4 s ahead; detours show the same tick.
static func rule4_bubble(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	var extra := 0
	# (a) every b_detour has a b_next on the same tick — unless it queued behind a detour the bubble
	# already shows (the bubble's `next` is the FIRST queued detour, TECH §3.7.1).
	var nexts_all := log.events_named("b_next")
	for d in log.events_named("b_detour"):
		var t := int(d.get("t", 0))
		var same := false
		var prev: Variant = null
		for n in nexts_all:
			var nt := int(n.get("t", 0))
			if nt == t:
				same = true
				break
			if nt < t:
				prev = n
		if not same and prev != null:
			var pid := SolverData.sv((prev as Dictionary).get("id", ""))
			var pending := bool((prev as Dictionary).get("detour", false)) or SolverData.is_detour(pid)
			if pending:
				for a in log.events_named("b_activity", {"id": pid}):
					if int(a.get("t", 0)) >= int((prev as Dictionary).get("t", 0)) and int(a.get("t", 0)) < t:
						pending = false
			same = pending
		if not same:
			if out.size() < MAX_PER_RULE:
				out.append("rule 4: b_detour %s at %s without a b_next on the same tick" % [d.get("kind", "?"), _t(t)])
			else:
				extra += 1
	# (b) ≥ 240 ticks of notice before he leaves a ≥ 4 s loop activity.
	var acts: Array = []   # [id, t_start, t_end]
	for ev in log.events:
		var e := SolverData.sv(ev.get("e", ""))
		var id := SolverData.sv(ev.get("id", ""))
		if SolverData.is_detour(id):
			continue
		if e == "b_activity":
			acts.append([id, int(ev.get("t", 0)), -1])
		elif e == "b_activity_end" and not acts.is_empty() and acts[acts.size() - 1][0] == id and acts[acts.size() - 1][2] < 0:
			acts[acts.size() - 1][2] = int(ev.get("t", 0))
	var nexts := log.events_named("b_next")
	# a punchline, a Meltdown, a chase or a catch inside the notice window re-plans his route (a resumable
	# activity he never gets back to): the 240-tick notice restarts from it
	var disturb := PackedInt32Array()
	for ev in log.events:
		if DISTURB_EVENTS.has(SolverData.sv(ev.get("e", ""))):
			disturb.append(int(ev.get("t", 0)))
	for k in range(0, acts.size() - 1):
		var cur: Array = acts[k]
		var nxt: Array = acts[k + 1]
		var te: int = cur[2]
		if te < 0 or te - int(cur[1]) < BUBBLE_TICKS:
			continue
		if nxt[0] == cur[0]:
			continue   # resumed activity
		var disturbed := false
		for dt in disturb:
			if dt > te - BUBBLE_TICKS and dt <= te:
				disturbed = true
				break
		if disturbed:
			continue
		var last_n: Variant = null
		for n in nexts:
			if int(n.get("t", 0)) <= te:
				last_n = n
		if last_n == null:
			out.append("rule 4: no b_next before %s left %s at %s" % ["Bellows", cur[0], _t(te)])
			continue
		var ln: Dictionary = last_n
		if bool(ln.get("detour", false)) or SolverData.is_detour(SolverData.sv(ln.get("id", ""))):
			continue   # a detour (fix-up, lure, search) comes first: route changes are rule 4(a)
		if SolverData.sv(ln.get("id", "")) != SolverData.sv(nxt[0]):
			if out.size() < MAX_PER_RULE:
				out.append("rule 4: the bubble showed '%s' but he went from %s to '%s' at %s" % [ln.get("id", ""), cur[0], nxt[0], _t(te)])
			else:
				extra += 1
		elif te - int(ln.get("t", 0)) < BUBBLE_TICKS:
			if out.size() < MAX_PER_RULE:
				out.append("rule 4: '%s' shown only %d ticks before he left %s at %s (< %d)" % [nxt[0], te - int(ln.get("t", 0)), cur[0], _t(te), BUBBLE_TICKS])
			else:
				extra += 1
	return _cap(out, 4, extra)


## Rule 5: same commands → same hash.
static func rule5_determinism(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	if log.replay_hash != null and int(log.replay_hash) != log.final_hash:
		out.append("rule 5: replaying %d commands gave hash %d, the run gave %d (non-deterministic)" % [
			log.cmds.size(), int(log.replay_hash), log.final_hash])
	return out


## Rule 6: every soft-lock probe succeeded.
static func rule6_softlock(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	for p in log.softlock_probes:
		if not bool(p.get("ok", false)):
			out.append("rule 6: soft-lock at %s: %s" % [_t(int(p.get("t", 0))), p.get("why", "planner could not finish the required lines")])
	return out


## Rule 7: speed ≤ 115 % of walk outside chases; activities in loop order.
static func rule7_speed_and_loop(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	var limit := log.b_walk_sub * 115 / 100 + 1
	var bad := 0
	var worst := 0
	var worst_t := 0
	for i in range(1, log.size()):
		if log.ticks[i] != log.ticks[i - 1] + 1 or log.b_room[i] != log.b_room[i - 1]:
			continue
		if not (log.name_of(log.b_state[i]) in SPEED_STATES) or not (log.name_of(log.b_state[i - 1]) in SPEED_STATES):
			continue
		var d := absi(log.b_x_sub[i] - log.b_x_sub[i - 1])
		if d > limit:
			bad += 1
			if d > worst:
				worst = d
				worst_t = log.ticks[i]
	if bad > 0:
		out.append("rule 7: Bellows moved faster than 115 %% of walk on %d tick(s) (worst %d sub-px/tick > %d at %s)" % [
			bad, worst, limit, _t(worst_t)])
	# Loop order.
	var loop := log.loop
	if loop.is_empty():
		return out
	var p := 0
	var loops := 0
	var last_id := ""
	for ev in log.events_named("b_activity"):
		var id := SolverData.sv(ev.get("id", ""))
		if SolverData.is_detour(id):
			continue
		var matched := false
		for _guard in loop.size():
			var entry: Dictionary = loop[p]
			if SolverData.sv(entry.get("a", "")) == id:
				matched = true
				p += 1
				if p >= loop.size():
					p = 0
					loops += 1
				break
			var once := bool(entry.get("once", false)) or bool(entry.get("first_loop_only", false))
			if once and loops > 0:
				p = (p + 1) % loop.size()
				continue
			break
		if not matched:
			if id == last_id:
				continue   # a resumed activity
			out.append("rule 7: activity '%s' at %s breaks the loop order (expected '%s')" % [
				id, _t(int(ev.get("t", 0))), (loop[p] as Dictionary).get("a", "")])
			break
		last_id = id
	return out


## Rule 8: blind while reacting and for 60 ticks after.
static func rule8_blind_reacting(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	var intervals: Array = []   # [t0, t1]
	var open_t := -1
	for ev in log.events:
		var e := SolverData.sv(ev.get("e", ""))
		var t := int(ev.get("t", 0))
		if (e == "reaction_start" or e == "meltdown_start") and open_t < 0:
			open_t = t
		elif (e == "reaction_end" or e == "exhausted") and open_t >= 0:
			intervals.append([open_t, t])
			open_t = -1
	if open_t >= 0:
		intervals.append([open_t, 1 << 30])
	for ev in log.events_named("spot_start"):
		var by := SolverData.sv(ev.get("by", "bellows"))
		if by != "bellows" and by != "":
			continue
		var t := int(ev.get("t", 0))
		for iv in intervals:
			if t >= int(iv[0]) and t < int(iv[1]) + BLIND_AFTER_TICKS:
				out.append("rule 8: spot_start at %s during a reaction or < %d ticks after it (%s..%s)" % [
					_t(t), BLIND_AFTER_TICKS, _t(int(iv[0])), _t(int(iv[1]))])
				break
		if out.size() >= MAX_PER_RULE:
			break
	return out


## Rule 9: Bellows makes progress; Hush's movement commands give feedback.
static func rule9_progress(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	# (a) activity progress every 60 s (uncapped player-led gates excepted).
	var last := log.start_tick
	var ticks_prog := PackedInt32Array()
	for ev in log.events:
		if PROGRESS_EVENTS.has(SolverData.sv(ev.get("e", ""))):
			ticks_prog.append(int(ev.get("t", 0)))
	ticks_prog.append(log.last_tick())
	for t in ticks_prog:
		if t - last > PROGRESS_TICKS:
			var i := log.index_of_tick(last + 1)
			var act := log.name_of(log.b_activity[i]) if i >= 0 else ""
			if not log.gated.has(act):
				out.append("rule 9: no Bellows progress for %.1f s from %s (activity '%s')" % [(t - last) / 60.0, _t(last), act])
				break
		last = t
	# (b) every go/move answers within 1 tick; a queued one runs the tick the busy action ends.
	var extra := 0
	var prev_key := ""
	var last_arrive := ""
	var ev_i := 0
	var moves: Array = []   # ticks of every go/move (superseding)
	for c in log.cmds:
		var k0 := SolverData.sv((c[1] as Dictionary).get("c", ""))
		if k0 == "go" or k0 == "move":
			moves.append(int(c[0]))
	var by_t := {}          # tick → [event names]
	for ev in log.events:
		var et := int(ev.get("t", 0))
		if not by_t.has(et):
			by_t[et] = []
		(by_t[et] as Array).append(SolverData.sv(ev.get("e", "")))
	for c in log.cmds:
		var t: int = c[0]
		var cmd: Dictionary = c[1]
		while ev_i < log.events.size() and int(log.events[ev_i].get("t", 0)) < t:
			var e0: Dictionary = log.events[ev_i]
			if SolverData.sv(e0.get("e", "")) == "hush_arrive":
				last_arrive = SolverData.sv(e0.get("hotspot", ""))
			elif SolverData.sv(e0.get("e", "")) in ["hush_go", "caught", "pop_out"]:
				last_arrive = ""
			ev_i += 1
		var kind := SolverData.sv(cmd.get("c", ""))
		if kind != "go" and kind != "move":
			continue
		var key := "%s|%s|%s|%s" % [kind, cmd.get("hotspot", ""), cmd.get("room", ""), cmd.get("x", "")]
		if key == prev_key:
			continue   # a repeat of the same tap (the view still ripples)
		prev_key = key
		if kind == "go" and SolverData.sv(cmd.get("hotspot", "")) == last_arrive:
			continue
		var i0 := log.index_of_tick(t)
		if kind == "move" and i0 >= 0 and log.name_of(log.hush_room[i0]) == SolverData.sv(cmd.get("room", "")) \
				and absi(log.hush_x[i0] - int(cmd.get("x", 0))) <= 2:
			continue
		var t_end := t + FEEDBACK_TICKS
		var queued := false
		var answered := false
		for u in range(t, t_end + 1):
			for en in by_t.get(u, []):
				if en == "cmd_queued":
					queued = true
				elif FEEDBACK_EVENTS.has(en):
					answered = true
		if not answered and not queued and _moved(log, i0, t_end):
			answered = true
		if answered:
			continue
		if t_end > log.last_tick():
			continue   # the run ended inside the window
		if queued:
			var why := _queued_ran(log, t, moves, by_t)
			if why == "":
				continue
			if out.size() < MAX_PER_RULE + 1:
				out.append("rule 9: %s at %s was queued but %s" % [JSON.stringify(cmd), _t(t), why])
			else:
				extra += 1
			continue
		if out.size() < MAX_PER_RULE + 1:
			out.append("rule 9: %s at %s produced no movement, arrival, rejection or cmd_queued within %d tick(s)" % [
				JSON.stringify(cmd), _t(t), FEEDBACK_TICKS])
		else:
			extra += 1
	return _cap(out, 9, extra)


## "" when the go/move queued at `t` ran the tick Hush's busy action ended (or a newer go/move replaced it
## first, or the run ended while she was still busy); else why not.
static func _queued_ran(log: SolverLog, t: int, moves: Array, by_t: Dictionary) -> String:
	var next_cmd := 1 << 30
	for mt in moves:
		if int(mt) > t:
			next_cmd = int(mt)
			break
	var i := log.index_of_tick(t)
	if i < 0:
		return ""
	var j := i + 1
	while j < log.size():
		var u := log.ticks[j]
		if u >= next_cmd:
			return ""   # replaced by a newer tap before it could run
		# it ran (or was answered) this tick — also on a tick that ends busy again (she starts off and is caught)
		for en in by_t.get(u, []):
			if RAN_EVENTS.has(en):
				return ""
		var held := u < log.enter_ticks or HELD_STATES.has(log.name_of(log.hush_state[j]))
		if not held:
			if log.hush_x[j] != log.hush_x[j - 1] or log.hush_room[j] != log.hush_room[j - 1]:
				return ""
			return "did not run when her busy action ended at %s" % _t(u)
		j += 1
	return ""


## True when Hush's position changed between sample `i0` and tick `t1`.
static func _moved(log: SolverLog, i0: int, t1: int) -> bool:
	if i0 < 0:
		return false
	var j := i0
	while j < log.size() and log.ticks[j] <= t1:
		if log.hush_x[j] != log.hush_x[i0] or log.hush_room[j] != log.hush_room[i0]:
			return true
		j += 1
	return false


## Rule 10: one punchline at a time; applause ≥ 0; bases sum to 700.
static func rule10_reactions_applause(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	var open: Array = []
	for ev in log.events:
		var e := SolverData.sv(ev.get("e", ""))
		var p := SolverData.sv(ev.get("prank", ""))
		match e:
			"knock_on":
				open.erase(SolverData.sv(ev.get("a", "")))
			"reaction_start":
				if not open.is_empty():
					out.append("rule 10: reaction %s started at %s while %s was still playing" % [p, _t(int(ev.get("t", 0))), open[0]])
				open.append(p)
			"reaction_end":
				open.erase(p)
			"applause":
				if int(ev.get("total", 0)) < 0:
					out.append("rule 10: applause total %d < 0 at %s" % [int(ev.get("total", 0)), _t(int(ev.get("t", 0)))])
	for i in log.size():
		if log.applause[i] < 0:
			out.append("rule 10: applause %d < 0 at %s" % [log.applause[i], _t(log.ticks[i])])
			break
	if log.bases_sum >= 0 and log.bases_sum != 700:
		out.append("rule 10: prank-line bases sum to %d tenths, not 700" % log.bases_sum)
	return out


## Rule 11 (Stage 3): Beryl's headbutt is never a catch.
static func rule11_headbutt(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	if not log.has_beryl:
		return out
	var butts: Array = []
	for h in log.events_named("headbutt"):
		if SolverData.sv(h.get("target", "")) == "hush":
			butts.append(int(h.get("t", 0)))
	for ev in log.events_named("caught"):
		var t := int(ev.get("t", 0))
		var by := SolverData.sv(ev.get("by", ""))
		var cause := SolverData.sv(ev.get("cause", ""))
		var near := false
		for bt in butts:
			if t >= bt and t - bt <= 30:
				near = true
		if by == "beryl" or cause.contains("headbutt") or near:
			out.append("rule 11: Beryl's headbutt produced a catch at %s" % _t(t))
	return out


## Rule 12 (ruling L4): no combo the Night does not allow (`log.combos_allowed`: null = all, else the ids).
static func rule12_combos(log: SolverLog) -> Array[String]:
	var out: Array[String] = []
	if not (log.combos_allowed is PackedStringArray or log.combos_allowed is Array):
		return out
	var allowed: Array = Array(log.combos_allowed)
	for ev in log.events_named("combo"):
		var id := SolverData.sv(ev.get("id", ""))
		if not allowed.has(id):
			out.append("rule 12: combo '%s' at %s on a Night whose rules.combos is %s" % [id, _t(int(ev.get("t", 0))),
				JSON.stringify(allowed)])
			if out.size() >= MAX_PER_RULE:
				break
	return out


## Replay `log.cmds` on a fresh world from `factory` for as many ticks as the run had; returns the
## final state hash (for rule 5). Returns −1 when the factory gives no world.
static func replay_hash(factory: Callable, log: SolverLog) -> int:
	var w: Object = factory.call()
	if w == null:
		return -1
	var by_tick := log.cmds_by_tick()
	var start := int(w.get("tick"))
	var end_t := log.last_tick()
	var t := start
	while t < end_t:
		var cmds: Array = by_tick.get(t + 1, [])
		w.call("step", cmds)
		w.call("drain_events")
		t = int(w.get("tick"))
		if bool(w.get("ended")):
			break
	return int(w.call("state_hash"))


## The sim's own fairness counters (`world.invariant_counters`, config.invariants) that are
## non-zero, as "sim: <counter> = n" violations.
static func sim_counters(world: Object) -> Array[String]:
	var out: Array[String] = []
	if world == null:
		return out
	var c: Variant = world.get("invariant_counters")
	if c is Dictionary:
		var keys: Array = (c as Dictionary).keys()
		keys.sort()
		for k in keys:
			if int(c[k]) != 0:
				out.append("sim: invariant counter %s = %d" % [k, int(c[k])])
	return out
