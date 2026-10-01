## The curtain call's step tables (s2-night §4.3): durations per kind, first vs repeat viewing, the
## Prologue sequence with the title card after the fall, and the kind for an episode / end reason.
extends TestBase


func _ids(kind: String, rep: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	for s in CurtainCall.steps(kind, rep):
		out.append(String((s as Dictionary)["id"]))
	return out


func test_night_first_viewing() -> void:
	assert_eq(_ids("night"), PackedStringArray(["fall", "bow", "results", "reel"]))
	assert_between(CurtainCall.total_s("night", false), 12.7, 12.8)
	assert_le(CurtainCall.total_s("night", false), 16.0, "≤ 16 s on a first viewing")


func test_night_repeat_viewing() -> void:
	assert_between(CurtainCall.total_s("night", true), 7.4, 7.5)
	assert_le(CurtainCall.total_s("night", true), 12.0, "≤ 12 s on a repeat viewing")
	var st: Array = CurtainCall.steps("night", true)
	assert_eq(float(st[1]["s"]), 0.8, "a shorter bow")
	assert_eq(float(st[3]["s"]), 4.0, "best 1 + new")


func test_prologue_title_after_the_fall() -> void:
	assert_eq(_ids("prologue"), PackedStringArray(["fall", "bow", "title", "results", "reel"]))
	assert_between(CurtainCall.total_s("prologue"), 10.3, 10.5)


func test_gate0_is_short() -> void:
	assert_eq(_ids("gate0"), PackedStringArray(["fall", "reel"]))
	assert_le(CurtainCall.total_s("gate0"), 6.0)


func test_kind_for() -> void:
	assert_eq(CurtainCall.kind_for("g0_sneeze", "g0_done"), "gate0")
	assert_eq(CurtainCall.kind_for("p00_curtain_up", "prologue_done"), "prologue")
	assert_eq(CurtainCall.kind_for("n01_throat_tea", "bow"), "night")
	assert_eq(CurtainCall.variant_for("gate0"), "gate0")
	assert_eq(CurtainCall.variant_for("prologue"), "prologue")


# --- Bellows' bit (r3d QA2 Q2-G7): set-up before the hit, a 4 f drop, a ≥ 30 f face hold inside the reel step ---

func test_bit_plan_fits_every_reel_step() -> void:
	for dur in [4.0, 5.0, 8.0]:
		var p := CurtainApron.bit_plan(dur)
		assert_le(float(p["end"]), dur + 0.001, "the face hold ends inside the reel step (%s s)" % dur)
		assert_ge(float(p["end"]) - float(p["hit"]), 0.5, "≥ 30 f hold after the hit (%s s)" % dur)
		assert_ge(float(p["drop"]) - float(p["wobble"]), 0.5, "the wobble (the set-up) is ≥ 30 f before the drop")
		assert_almost_eq(float(p["hit"]) - float(p["drop"]), float(CurtainApron.BIT_DROP_F) / 60.0, 0.001,
			"a fast drop: %d f" % CurtainApron.BIT_DROP_F)
		assert_le(CurtainApron.BIT_DROP_F, 4, "accent ≤ 4 f")
		assert_lt(float(p["walk"]), float(p["take"]))
		assert_lt(float(p["take"]), float(p["wobble"]), "the slow burn sits between the take and the wobble")
	var pro := CurtainApron.bit_plan(CurtainCall.steps(CurtainCall.KIND_PROLOGUE)[4]["s"])
	assert_almost_eq(float(pro["end"]), 5.0, 0.01, "the Prologue reel step (5 s) ends on his hold")


func test_bit_stages_centre_left_clear_of_the_inset_and_buttons() -> void:
	# REDESIGN / QA2: x 300–650 px of a 1200 px screen; the reel inset and Next sit right, Retry bottom-left
	var vs := Vector2(2400, 1080)
	var x := CurtainApron.BIT_MARK_X * vs.x
	assert_between(x / vs.x * 1200.0, 300.0, 650.0, "his mark is centre-left")
	var pel := Rect2(x - CurtainApron.PELMET_SIZE.x * 0.5, 0.0, CurtainApron.PELMET_SIZE.x, 600.0)
	var reel := Rect2(vs.x - 48.0 - ResultsScreen.REEL.x, 170.0, ResultsScreen.REEL.x, ResultsScreen.REEL.y).grow(14.0)
	var nxt := Rect2(vs.x - 48.0 - ResultsScreen.NEXT_SIZE.x, vs.y - 40.0 - ResultsScreen.NEXT_SIZE.y, ResultsScreen.NEXT_SIZE.x,
		ResultsScreen.NEXT_SIZE.y)
	var rty := Rect2(48.0, vs.y - 40.0 - ResultsScreen.SMALL_SIZE.y, ResultsScreen.SMALL_SIZE.x, ResultsScreen.SMALL_SIZE.y)
	assert_false(pel.intersects(reel), "the pelmet's column is clear of the Gag Reel inset")
	assert_false(pel.intersects(nxt), "and of Next ▶")
	assert_false(pel.intersects(rty), "and of Retry")
	assert_lt(CurtainApron.HUSH_MARK_X, CurtainApron.TITLE_X, "Hush bows left of the title card")


func test_pelmet_wobbles_then_drops_onto_his_head() -> void:
	var a := CurtainApron.new()
	tree.root.add_child(a)
	a.start_bellows(PackedStringArray(), 5.0)
	var head := Vector2(672.0, 530.0)
	var p := a.bit
	var seen_wobble := false
	var rots := 0
	var hit_frame := -1
	var drop_frame := -1
	for f in 330:
		a.advance(1.0 / 60.0)
		var st := a.pelmet_state(head)
		if a.bit_t < float(p["wobble"]):
			assert_false(bool(st["on"]), "no pelmet before its set-up (f %d)" % f)
		elif a.bit_t < float(p["drop"]):
			seen_wobble = true
			assert_true(bool(st["ropes"]), "it hangs on its ropes while it wobbles")
			assert_le(float(st["bottom"]), CurtainApron.PELMET_HANG_Y + 20.0, "high above his head")
			if absf(float(st["rot"])) > 0.02:
				rots += 1
		elif drop_frame < 0:
			drop_frame = f
		if a.bonked() and hit_frame < 0:
			hit_frame = f
			assert_almost_eq(float(st["bottom"]), head.y + CurtainApron.PELMET_SINK, 0.01, "it lands on his head")
	assert_true(seen_wobble, "the set-up shows")
	assert_gt(rots, 10, "it visibly wobbles")
	assert_between(hit_frame - drop_frame, 3, 5, "the drop takes ~4 frames (%d)" % (hit_frame - drop_frame))
	assert_true(a.bit_done(), "the hold is done by the end of the step")
	assert_lt(CurtainApron.squash_at(1.0), 0.9, "he is squashed on contact")
	assert_eq(CurtainApron.squash_at(30.0), 1.0, "and settled")
	a.queue_free()
	await tree.process_frame


func test_a_tap_drops_the_pelmet_at_once() -> void:
	var a := CurtainApron.new()
	tree.root.add_child(a)
	a.start_bellows(PackedStringArray(), 5.0)
	for f in 30:
		a.advance(1.0 / 60.0)
	a.bonk()
	var n := 0
	while not a.bonked() and n < 20:
		a.advance(1.0 / 60.0)
		n += 1
	assert_between(n, 3, 5, "the skip drops it in ~4 frames (%d)" % n)
	assert_false(a.bit_done(), "the face hold still runs")
	for f in 61:
		a.advance(1.0 / 60.0)
	assert_true(a.bit_done())
	a.queue_free()
	await tree.process_frame
