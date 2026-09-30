## REDESIGN_3D §6.2 C1 — the live-hotspot mask (`SimCtx.live_hotspots`, `r3d-index.md` §7.5): per slice Night the
## live set equals REDESIGN §3.4's "Live" column; the sim refuses a struck hotspot (`cmd_rejected {c, why: "struck",
## target}`, Hush does not move), `hotspot_state().enabled` follows the mask, the Figgis hook only uses a listed
## hiding spot, and the mask is pure, deterministic and cheap (≤ 1 ms per episode).
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")
const DATA := "res://data"

## REDESIGN §3.4 "Live" (rig points with a prank tonight + containers with a tonight item + listed hiding spots),
## by room; doors, exits and stairs are architecture and are not counted.
const LIVE := {
	"p00_curtain_up": {"kitchen": ["kitchen_honey", "kitchen_pantry_curtain"],
		"parlour": ["parlour_gramophone", "parlour_piano_back"], "hall": []},
	"g0_sneeze": {"kitchen": ["kitchen_honey", "kitchen_pantry_curtain"], "parlour": [], "hall": []},
	"n01_throat_tea": {"kitchen": ["kitchen_kettle", "kitchen_honey", "kitchen_pickle_jar", "kitchen_pantry_curtain",
			"kitchen_sink_tap"], "parlour": ["parlour_piano_back", "parlour_recliner"],
		"hall": ["hall_coat_cupboard", "hall_confiscated_box"]},
	"n02_something_fishy": {"kitchen": ["kitchen_fridge_shelf", "kitchen_fridge", "kitchen_pantry_curtain"],
		"parlour": ["parlour_piano_back", "parlour_newspaper"],
		"hall": ["hall_coat_cupboard", "hall_confiscated_box", "hall_phone", "hall_mirror", "hall_clock"]},
}
## REDESIGN §3.4 counts per room (the brief's check: P00 2/2/0, N1 5/2/2, N2 3/2/5).
const COUNTS := {"p00_curtain_up": [2, 2, 0], "n01_throat_tea": [5, 2, 2], "n02_something_fishy": [3, 2, 5]}

var _db: ContentDB = null


func _real() -> ContentDB:
	if _db == null:
		_db = ContentDB.load_dir(DATA)
	if not _db.errors.is_empty():
		skip("real content has %d validation errors: %s" % [_db.errors.size(), _db.errors[0]])
		return null
	return _db


func _props_by_room(db: ContentDB, live: Dictionary) -> Dictionary:
	var out := {}
	for id in live:
		var k := String(live[id])
		if k != "rig" and k != "take" and k != "hide":
			continue
		var r := db.house.hotspot(String(id)).room
		if not out.has(r):
			out[r] = []
		(out[r] as Array).append(String(id))
	return out


func test_the_mask_is_redesign_live_column_per_slice_night() -> void:
	var db := _real()
	if db == null:
		return
	for ep_id in LIVE:
		if not assert_true(db.episodes.has(ep_id), ep_id):
			continue
		var live := SimCtx.live_hotspots(db, db.episodes[ep_id])
		var by_room := _props_by_room(db, live)
		for room in LIVE[ep_id]:
			var want: Array = (LIVE[ep_id][room] as Array).duplicate()
			var got: Array = (by_room.get(room, []) as Array).duplicate()
			want.sort()
			got.sort()
			assert_eq(got, want, "%s %s live props" % [ep_id, room])
		for room in by_room:
			assert_true((LIVE[ep_id] as Dictionary).has(room), "%s: no live prop outside the slice rooms (%s: %s)" % [ep_id, room, by_room[room]])
	for ep_id in COUNTS:
		var by := _props_by_room(db, SimCtx.live_hotspots(db, db.episodes[ep_id]))
		var n := [(by.get("kitchen", []) as Array).size(), (by.get("parlour", []) as Array).size(), (by.get("hall", []) as Array).size()]
		assert_eq(n, COUNTS[ep_id], "%s live per room kitchen/parlour/hall" % ep_id)


func test_live_kinds_and_architecture() -> void:
	var db := _real()
	if db == null:
		return
	var n1 := SimCtx.live_hotspots(db, db.episodes["n01_throat_tea"])
	assert_eq(n1.get("kitchen_honey"), "rig")
	assert_eq(n1.get("hall_confiscated_box"), "take")
	assert_eq(n1.get("kitchen_pantry_curtain"), "hide")
	assert_eq(n1.get("hall_front_door"), "exit", "exits as today")
	assert_false(n1.has("stairs_foot"), "the stairs are roped off in Act I (they lead to the unbuilt landing)")
	assert_false(n1.has("kitchen_back_door"), "the back door is closed in Act I (REDESIGN §3.4)")
	assert_false(n1.has("kitchen_window"), "the kitchen window entry stays untappable")
	var fx := U.world_patched("fx_act1", func(ep: Dictionary) -> void: (ep["rooms"] as Array).append("landing"))
	assert_true(fx.ctx.is_live(fx.db.house.hotspot("stairs_foot").idx), "stairs to a room she may enter are live")
	for struck in ["kitchen_table", "parlour_chaise_back", "parlour_gramophone", "parlour_newspaper", "kitchen_pantry_shelf",
			"kitchen_fridge", "parlour_bellows", "parlour_chandelier", "hall_clock_case", "landing_airing_cupboard"]:
		assert_false(n1.has(struck), "N1: %s is struck" % struck)
	var p00 := SimCtx.live_hotspots(db, db.episodes["p00_curtain_up"])
	assert_false(p00.has("kitchen_sink_tap"), "P00: the sink is the sneeze landing, not a rig point (TAP DANCE is only a knock-on)")
	for id in p00:
		assert_ne(db.house.hotspot(String(id)).room, "hall", "P00: the hall is backstage (%s)" % id)
	var n2 := SimCtx.live_hotspots(db, db.episodes["n02_something_fishy"])
	assert_false(n2.has("hall_clock_case"), "N2: the in-use clock case is struck (C2)")


func test_absent_hides_means_every_hiding_spot_of_the_rooms() -> void:
	var db := _real()
	if db == null:
		return
	var draft: EpisodeDef = db.episodes.get("n03_singing_in_the_bath", null)
	if draft == null or draft.has_hides:
		skip("n03 draft missing or already lists hides")
		return
	var live := SimCtx.live_hotspots(db, draft)
	var ctx := SimCtx.build(db, draft, {})
	for h in db.house.hotspots:
		if h.kind == HotspotDef.HIDING and h.tappable and ctx.hush_allowed(h.room_idx) and not ctx.is_backstage(h.room_idx):
			assert_eq(live.get(h.id), "hide", "%s live without a hides list" % h.id)


func test_go_to_a_struck_hotspot_is_refused_and_hush_stays() -> void:
	var db := _real()
	if db == null:
		return
	var w := SimWorld.create(db, "n01_throat_tea", {})
	U.run(w, 2)
	var x0 := w.hush.x_sub
	var r0 := w.hush.room
	var evs := U.step(w, [SimCmd.go("kitchen_table")])
	var rej := U.first(evs, SimEvents.CMD_REJECTED)
	assert_eq(str(rej.get("c", "")), "go")
	assert_eq(str(rej.get("why", "")), "struck")
	assert_eq(str(rej.get("target", "")), "kitchen_table")
	assert_true(U.first(evs, SimEvents.HUSH_GO).is_empty(), "no hush_go")
	U.run(w, 30)
	assert_eq(w.hush.x_sub, x0, "Hush does not move")
	assert_eq(w.hush.room, r0)
	# a running go and a queued one are refused the same way (never queued behind a busy action)
	evs = U.step(w, [SimCmd.go("parlour_chaise_back", true)])
	assert_eq(str(U.first(evs, SimEvents.CMD_REJECTED).get("why", "")), "struck")
	assert_true(U.first(evs, SimEvents.CMD_QUEUED).is_empty())


func test_pin_on_a_struck_hotspot_is_refused() -> void:
	var db := _real()
	if db == null:
		return
	var w := SimWorld.create(db, "n01_throat_tea", {})
	U.run(w, 2)
	var log: Array = []
	assert_true(U.walk_to(w, "kitchen_pantry_curtain", 1500, log))
	assert_true(U.run_until_pred(w, func(x: SimWorld) -> bool: return x.hush.state == SimHush.HIDDEN, 120, log))
	var evs := U.step(w, [SimCmd.pin_hotspot("kitchen_table")])
	var rej := U.first(evs, SimEvents.CMD_REJECTED)
	assert_eq(str(rej.get("c", "")), "pin")
	assert_eq(str(rej.get("why", "")), "struck")
	assert_eq(str(rej.get("target", "")), "kitchen_table")
	assert_eq(w.hush.pin_hs, -1, "no pin set")
	evs = U.step(w, [SimCmd.go("kitchen_table")])
	assert_eq(str(U.first(evs, SimEvents.CMD_REJECTED).get("why", "")), "struck", "a go while hidden (a pin) too")
	assert_true(U.first(evs, SimEvents.PIN).is_empty())
	evs = U.step(w, [SimCmd.pin_hotspot("kitchen_sink_tap")])
	assert_false(U.first(evs, SimEvents.PIN).is_empty(), "a live hotspot still pins")


func test_hotspot_state_enabled_follows_the_mask() -> void:
	var db := _real()
	if db == null:
		return
	var w := SimWorld.create(db, "n01_throat_tea", {})
	for id in ["kitchen_table", "parlour_chaise_back", "parlour_gramophone", "kitchen_pantry_shelf"]:
		assert_false(bool(w.hotspot_state(id)["enabled"]), "%s struck → disabled" % id)
	for id in ["kitchen_pantry_curtain", "parlour_piano_back", "hall_coat_cupboard", "hall_confiscated_box", "kitchen_honey"]:
		assert_true(bool(w.hotspot_state(id)["enabled"]), "%s live → enabled" % id)
	var p := SimWorld.create(db, "p00_curtain_up", {})
	assert_false(bool(p.hotspot_state("kitchen_sink_tap")["enabled"]), "P00 sink tap struck")
	assert_true(bool(p.hotspot_state("parlour_gramophone")["enabled"]))


func test_the_figgis_hook_only_uses_a_listed_spot() -> void:
	var db := _real()
	if db == null:
		return
	var w := SimWorld.create(db, "p00_curtain_up", {})
	U.run(w, w.ctx.hush_enter_ticks + 2)
	U.place_hush(w, "kitchen", 3450)   # on top of the struck kitchen table
	w.hush.at_hotspot = -1
	w.senses.figgis_hook(w)
	assert_eq(w.hush.state, SimHush.HIDDEN)
	assert_eq(db.house.hotspots[w.hush.hidden_spot].id, "kitchen_pantry_curtain", "the nearest LISTED spot, not the table")
	var w2 := SimWorld.create(db, "p00_curtain_up", {})
	U.run(w2, w2.ctx.hush_enter_ticks + 2)
	U.place_hush(w2, "parlour", 2554)   # at the struck chaise
	w2.senses.figgis_hook(w2)
	assert_eq(db.house.hotspots[w2.hush.hidden_spot].id, "parlour_piano_back")


func test_the_mask_is_pure_deterministic_and_cheap() -> void:
	var db := _real()
	if db == null:
		return
	for ep_id in ["p00_curtain_up", "g0_sneeze", "n01_throat_tea", "n02_something_fishy"]:
		var ep: EpisodeDef = db.episodes[ep_id]
		var a := SimCtx.live_hotspots(db, ep)
		var b := SimCtx.live_hotspots(db, ep)
		assert_eq(a, b, "%s: same result twice" % ep_id)
		var n := 20
		var t0 := Time.get_ticks_usec()
		for i in n:
			SimCtx.live_hotspots(db, ep)
		var us := float(Time.get_ticks_usec() - t0) / n
		assert_lt(us, 1000.0 * TestBase.cpu_load_scale(), "%s: live_hotspots %.0f µs ≤ 1 ms" % [ep_id, us])
		var w := SimWorld.create(db, ep_id, {})
		for id in a:
			assert_true(w.ctx.is_live(db.house.hotspot(String(id)).idx), "%s: %s in the world's mask" % [ep_id, id])
		var live_n := 0
		for v in w.ctx.live_mask:
			live_n += v
		assert_eq(live_n, a.size(), "%s: the world's mask has exactly the live set" % ep_id)


func test_fixture_worlds_without_hides_keep_every_spot() -> void:
	var w := U.world("fx_act1")
	for h in w.db.house.hotspots:
		if h.kind == HotspotDef.HIDING and w.ctx.hush_allowed(h.room_idx) and h.tappable:
			assert_true(w.ctx.is_live(h.idx), "fixture %s live (no hides list)" % h.id)
	var p := U.world_patched("fx_act1", func(ep: Dictionary) -> void: ep["hides"] = ["kitchen_pantry_curtain"])
	assert_false(p.ctx.is_live(p.db.house.hotspot("kitchen_table").idx), "a hides list strikes the others")
	assert_true(p.ctx.is_live(p.db.house.hotspot("kitchen_pantry_curtain").idx))
