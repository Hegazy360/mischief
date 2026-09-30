## s2-sim §4.3 — command feedback (owner check #6): every Hush command, in every Hush state, answers within the
## same tick with a movement start, `hush_go`, `hush_arrive`, `pin`, `freeze`, `rig_start` / `rig_pause`, `squeak`,
## `cmd_queued` or `cmd_rejected` (or the thing it asks for: `pick`, `pop_out`, the end). A silent command is a bug.
## Two presses repeat the state she is visibly in and count as their own feedback (like a repeated `go`): RIG while
## rigging, FREEZE while frozen. Releases (`rig` / `freeze` / `wheeze` `on: false`) end a press whose feedback was given
## at press time; they answer when they release something (`rig_pause`, `freeze {on: false}`). BOWING ends the Night
## (commands after the end are not applied), and `hint_used` is the hint ladder's bookkeeping, not a tap on Hush.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")

const FEEDBACK: PackedStringArray = ["hush_go", "hush_arrive", "pin", "freeze", "rig_start", "rig_pause", "squeak",
	"cmd_queued", "cmd_rejected", "pick", "pop_out", "night_end"]
## Presses that repeat what she is visibly doing.
const IDEMPOTENT := {"RIGGING": ["rig_on"], "FROZEN": ["freeze_on"]}


## Bellows loops the tea in the kitchen (far away); Hush starts in the hall.
func _base(patch: Callable = Callable()) -> SimWorld:
	return U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["tea"], "kitchen", 2900, "hall", 900).call(ep)
		(ep["rooms"] as Array).append("landing")
		if patch.is_valid():
			patch.call(ep))


func _cmds() -> Dictionary:
	return {"go_far": SimCmd.go("parlour_recliner"), "go_struck": SimCmd.go("parlour_gramophone"), "go_box": SimCmd.go("hall_confiscated_box"),
		"move": SimCmd.move("parlour", 2000), "move_run": SimCmd.move("parlour", 2000, true), "pick": SimCmd.pick("squeaker"),
		"rig_on": SimCmd.rig(true), "freeze_on": SimCmd.freeze(true), "squeak": SimCmd.squeak(), "wheeze_on": SimCmd.wheeze(true),
		"pin_room": SimCmd.pin("parlour", 2000), "pin_hotspot": SimCmd.pin_hotspot("parlour_piano_back"),
		"pop_out": SimCmd.pop_out(), "bow": SimCmd.bow(), "unknown": {"c": "dance"}}


## Drive `w` into state `st` with `cmds` then wait; returns true when reached.
func _drive(w: SimWorld, cmds: Array, st: int, max_ticks: int = 900) -> bool:
	U.step(w, cmds)
	return U.run_until_pred(w, func(x: SimWorld) -> bool: return x.hush.state == st, max_ticks)


## Worlds with Hush in each state: name → SimWorld.
func _state_worlds() -> Dictionary:
	var out := {}
	var idle := _base()
	U.run(idle, 2)
	out["IDLE"] = idle
	var walk := _base()
	if _drive(walk, [SimCmd.go("parlour_recliner")], SimHush.WALK):
		U.run(walk, 3)
		out["WALK"] = walk
	var run := _base()
	if _drive(run, [SimCmd.go("parlour_recliner", true)], SimHush.RUN):
		out["RUN"] = run
	var stairs := _base()
	if _drive(stairs, [SimCmd.go("stairs_foot")], SimHush.STAIRS):
		out["STAIRS"] = stairs
	var door := _base()
	if _drive(door, [SimCmd.move("porch", 300)], SimHush.DOOR):
		out["DOOR"] = door
	var rum := _base()
	if _drive(rum, [SimCmd.go("hall_confiscated_box")], SimHush.RUMMAGE):
		out["RUMMAGE"] = rum
	var pw := _base()
	if _drive(pw, [SimCmd.go("hall_confiscated_box")], SimHush.PICK_WINDOW):
		out["PICK_WINDOW"] = pw
	var rig := U.quiet_world()
	if U.walk_to(rig, "kitchen_honey") and _drive(rig, [SimCmd.rig(true)], SimHush.RIGGING, 5):
		out["RIGGING"] = rig
	var dive := _base()
	if _drive(dive, [SimCmd.go("hall_coat_cupboard")], SimHush.DIVING):
		out["DIVING"] = dive
	var hid := _base()
	if _drive(hid, [SimCmd.go("hall_coat_cupboard")], SimHush.HIDDEN):
		out["HIDDEN"] = hid
	var pop := _base()
	if _drive(pop, [SimCmd.go("hall_coat_cupboard")], SimHush.HIDDEN) and _drive(pop, [SimCmd.pop_out()], SimHush.POPPING, 2):
		out["POPPING"] = pop
	var fr := _base()
	if _drive(fr, [SimCmd.freeze(true)], SimHush.FROZEN, 2):
		out["FROZEN"] = fr
	var sq := _base()
	if _drive(sq, [SimCmd.squeak()], SimHush.SQUEAKING, 2):
		out["SQUEAKING"] = sq
	var cg := _base()
	U.run(cg, 2)
	cg.hush.on_caught(cg)
	out["CAUGHT"] = cg
	var ent := _base(func(ep: Dictionary) -> void: ep["hush"]["enter"] = {"at_s": 0.0, "busy_s": 5.0})
	U.run(ent, 2)
	if ent.hush.entering:
		out["entering"] = ent
	return out


func test_every_command_in_every_state_gives_feedback_the_same_tick() -> void:
	var worlds := _state_worlds()
	for need in ["IDLE", "WALK", "RUN", "STAIRS", "DOOR", "RUMMAGE", "PICK_WINDOW", "RIGGING", "DIVING", "HIDDEN", "POPPING",
			"FROZEN", "SQUEAKING", "CAUGHT", "entering"]:
		assert_true(worlds.has(need), "reached state %s" % need)
	var cmds := _cmds()
	var checked := 0
	for sname in worlds:
		var base: SimWorld = worlds[sname]
		for cname in cmds:
			var w := base.clone()
			var room0 := w.hush.room
			var x0 := w.hush.x_sub
			var evs := U.step(w, [cmds[cname]])
			var names := PackedStringArray()
			var ok := false
			for ev in evs:
				names.append(str(ev["e"]))
				if FEEDBACK.has(str(ev["e"])):
					ok = true
			if w.hush.room != room0 or w.hush.x_sub != x0:
				ok = true   # she visibly moves this tick
			if not ok and (IDEMPOTENT.get(sname, []) as Array).has(cname):
				ok = true
			assert_true(ok, "%s in %s: silent (events %s)" % [cname, sname, names])
			checked += 1
	assert_ge(checked, 15 * 14)


func test_releases_answer_when_they_release_something() -> void:
	var w := U.quiet_world()
	assert_true(U.walk_to(w, "kitchen_honey"))
	U.step(w, [SimCmd.rig(true)])
	U.run(w, 5)
	var evs := U.step(w, [SimCmd.rig(false)])
	assert_false(U.first(evs, SimEvents.RIG_PAUSE).is_empty(), "rig release → rig_pause")
	U.step(w, [SimCmd.freeze(true)])
	evs = U.step(w, [SimCmd.freeze(false)])
	assert_false(U.first(evs, SimEvents.FREEZE, {"on": false}).is_empty(), "freeze release → freeze {on: false}")


func test_cmd_queued_targets_are_anchors() -> void:
	var w := _base()
	_drive(w, [SimCmd.go("hall_confiscated_box")], SimHush.RUMMAGE)
	var evs := U.step(w, [SimCmd.go("parlour_recliner")])
	var q := U.first(evs, SimEvents.CMD_QUEUED)
	assert_eq(str(q.get("c", "")), "go")
	assert_eq(str(q.get("why", "")), "busy")
	assert_eq(str(q.get("target", "")), "parlour_recliner", "a go anchors on its hotspot")
	evs = U.step(w, [SimCmd.move("parlour", 2000)])
	q = U.first(evs, SimEvents.CMD_QUEUED)
	assert_eq(str(q.get("target", "")), "parlour:2000", "a move anchors on <room>:<x>")
	# the newest queued command runs the tick the busy action ends
	var log: Array = []
	U.run_until_pred(w, func(x: SimWorld) -> bool: return x.hush.state != SimHush.RUMMAGE, 300, log)
	var t_end := w.tick
	var go := U.first(log, SimEvents.HUSH_GO)
	assert_eq(int(go.get("t", -1)), t_end, "the queued move starts the tick the rummage ends")
	assert_eq(str(go.get("target", "")), "parlour")


func test_climb_in_queues_movement_and_rejects_the_rest() -> void:
	var w := _base(func(ep: Dictionary) -> void: ep["hush"]["enter"] = {"at_s": 0.0, "busy_s": 2.0})
	var evs := U.step(w, [SimCmd.go("parlour_recliner")])
	var q := U.first(evs, SimEvents.CMD_QUEUED)
	assert_eq(str(q.get("why", "")), "entering")
	assert_eq(str(q.get("target", "")), "parlour_recliner")
	evs = U.step(w, [SimCmd.squeak()])
	assert_eq(str(U.first(evs, SimEvents.CMD_REJECTED).get("why", "")), "entering")
	var log: Array = []
	var go := U.run_until(w, SimEvents.HUSH_GO, {}, 300, log)
	assert_eq(int(go.get("t", -1)), w.ctx.hush_enter_ticks, "runs the tick the climb-in ends")


func test_pop_out_mid_dive_pops_out_when_the_dive_ends() -> void:
	var w := _base()
	_drive(w, [SimCmd.go("hall_coat_cupboard")], SimHush.DIVING)
	var evs := U.step(w, [SimCmd.pop_out()])
	var q := U.first(evs, SimEvents.CMD_QUEUED)
	assert_eq(str(q.get("c", "")), "pop_out")
	assert_eq(str(q.get("target", "")), "hall_coat_cupboard")
	var log: Array = []
	var pop := U.run_until(w, SimEvents.POP_OUT, {}, 120, log)
	assert_false(pop.is_empty(), "she pops out")
	assert_eq(int(U.first(log, SimEvents.HIDE).get("t", -1)), int(pop["t"]), "the tick the dive ends")


func test_frozen_or_hidden_go_sets_a_pin() -> void:
	var w := _base()
	_drive(w, [SimCmd.freeze(true)], SimHush.FROZEN, 2)
	var evs := U.step(w, [SimCmd.go("parlour_recliner")])
	assert_false(U.first(evs, SimEvents.PIN).is_empty(), "frozen: a go pins the destination")
	var h := _base()
	_drive(h, [SimCmd.go("hall_coat_cupboard")], SimHush.HIDDEN)
	evs = U.step(h, [SimCmd.move("parlour", 2000)])
	assert_eq(str(U.first(evs, SimEvents.PIN).get("room", "")), "parlour", "hidden: a move pins it")
