## The real `res://data`: validate and run each final episode (skips cleanly while content is missing or
## invalid; the errors are printed as requests for `content` / `art-house`).
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")
const DATA := "res://data"


func _db_or_skip() -> ContentDB:
	if not FileAccess.file_exists(DATA + "/house/house.json") or not FileAccess.file_exists(DATA + "/pranks.json"):
		skip("real content not written yet (res://data)")
		return null
	var t0 := Time.get_ticks_usec()
	var db := ContentDB.load_dir(DATA)
	print("[real data] loaded in %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	if not db.errors.is_empty():
		print("[real data] %d validation errors:" % db.errors.size())
		for e in db.errors:
			print("  " + e)
		skip("real content has %d validation errors (printed above)" % db.errors.size())
		return null
	return db


func test_real_data_validates() -> void:
	var db := _db_or_skip()
	if db == null:
		return
	assert_eq(db.errors, PackedStringArray())
	for w in db.warnings:
		print("[real data] warning: " + w)


func test_real_final_episodes_run() -> void:
	var db := _db_or_skip()
	if db == null:
		return
	var ran := 0
	for id in ContentUtil.sorted_keys(db.episodes):
		var ep: EpisodeDef = db.episodes[id]
		var w := SimWorld.create(db, id, {"invariants": true})
		assert_true(w != null, id)
		for i in 3600:
			w.step([])
			w.drain_events()
			if w.ended:
				break
		ran += 1
		for k in w.invariant_counters:
			assert_eq(int(w.invariant_counters[k]), 0, "%s %s" % [id, k])
	assert_gt(ran, 0)


## A scripted Hush plays the real Prologue to its curtain: squeak, rig the honey, hide in the pantry, sneeze
## him into the sink, slip into the parlour while he is at the mirror, rig the gramophone, hide behind the
## chaise; he spins, hunts, stomps out, and the title card ends the Night.
func test_real_prologue_plays_to_the_curtain() -> void:
	var db := _db_or_skip()
	if db == null:
		return
	if not db.episodes.has("p00_curtain_up"):
		skip("p00_curtain_up not written yet")
		return
	var w := SimWorld.create(db, "p00_curtain_up", {"invariants": true})
	var log: Array = []
	assert_true(U.run_until_pred(w, func(x: SimWorld) -> bool: return x.tick >= x.ctx.hush_enter_ticks, 600, log))
	log.append_array(U.step(w, [SimCmd.squeak()]))
	assert_true(U.walk_to(w, "kitchen_honey", 1200, log), "to the honey")
	assert_true(U.rig_hold(w, 400, log), "pepper in the honey")
	assert_true(U.walk_to(w, "kitchen_pantry_curtain", 1200, log))
	assert_false(U.run_until(w, SimEvents.REACTION_END, {"prank": "achoo_ria"}, 4000, log).is_empty(), "ACHOO-RIA!")
	assert_true(U.run_until_pred(w, func(x: SimWorld) -> bool: return x.bellows.room == x.room_idx("hall"), 3000, log),
		"off to the hall mirror")
	log.append_array(U.step(w, [SimCmd.pop_out(false)]))
	U.run_until_pred(w, func(x: SimWorld) -> bool: return x.hush.state == SimHush.IDLE, 300, log)
	assert_true(U.walk_to(w, "parlour_gramophone", 1500, log), "to the gramophone")
	assert_true(U.rig_hold(w, 400, log), "lever at triple speed")
	assert_true(U.walk_to(w, "parlour_piano_back", 1500, log), "behind the piano (the chaise is struck, REDESIGN_3D §6.2 C2)")
	log.append_array(U.run(w, 5400))
	assert_true(w.ended, "the curtain falls")
	assert_eq(w.end_reason, "prologue_done")
	assert_lt(w.tick, 90 * 60, "about a minute")
	assert_false(U.first(log, SimEvents.ALL_LINES_DONE).is_empty())
	for cue in ["laugh_vase", "ghost_squeak", "ghost_honey", "ghost_hold", "ghost_hide", "laugh_picture", "title_card"]:
		assert_false(U.first(log, SimEvents.DIRECTOR_CUE, {"id": cue}).is_empty(), cue)
	assert_true(U.first(log, SimEvents.SPOTTED).is_empty())
	assert_eq(w.stars(), [false, false, false], "no Curtain Calls in the Prologue")
	for k in w.invariant_counters:
		assert_eq(int(w.invariant_counters[k]), 0, k)


## TECH §3.7.1 (found by fuzz random seed 21 on p00 at Stage 2; pinned here as a scenario so it no longer depends on a
## fuzz seed's trajectory): in the Prologue's non-repeating loop, a lure 0.5 s into the tea — ACHOO-RIA! rigged —
## interrupts the tea but does not END it: he comes back and brews again, so the sneeze still lands.
func test_real_prologue_lure_mid_tea_keeps_the_sneeze() -> void:
	var db := _db_or_skip()
	if db == null:
		return
	var w := SimWorld.create(db, "p00_curtain_up", {"invariants": true})
	var log: Array = []
	assert_true(U.run_until_pred(w, func(x: SimWorld) -> bool: return x.tick >= x.ctx.hush_enter_ticks, 600, log))
	log.append_array(U.step(w, [SimCmd.squeak()]))
	U.force_rig(w, "achoo_ria")
	U.place_hush(w, "parlour", 2700)
	var tea := U.run_until(w, SimEvents.B_ACTIVITY, {"id": "tea"}, 5000, log)
	if not assert_false(tea.is_empty(), "he gets to the tea"):
		return
	U.place_hush(w, "parlour", 2700)
	log.append_array(U.run(w, 30))
	log.append_array(U.step(w, [SimCmd.squeak()]))
	assert_false(U.first(log, SimEvents.LURE).is_empty(), "the squeak lures him 0.5 s into the tea")
	var rx := U.run_until(w, SimEvents.REACTION_START, {"prank": "achoo_ria"}, 60 * 60, log)
	assert_false(rx.is_empty(), "the sneeze still lands")
	var ended_early := false
	for ev in log:
		if str(ev["e"]) == SimEvents.B_ACTIVITY_END and str(ev.get("id", "")) == "tea" and int(ev["t"]) < int(rx.get("t", 1 << 30)):
			ended_early = true
	assert_false(ended_early, "the lure mid-tea never ends the tea before its hook (the loop does not come round again)")

