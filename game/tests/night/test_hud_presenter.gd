## HudPresenter table tests (s2-night §5): verbs, rims, ⏩ mode, tray highlight, pick strip, edge
## bubble dir / label / emote, the no-action_context fallback, and the per-frame cost.
extends TestBase

var p: HudPresenter
var m: HudModel
var env: HudPresenter.HudEnv
var snap: ViewSnapshot


func before_each() -> void:
	p = HudPresenter.new()
	p.setup(HouseLayout.load_default(), null)
	m = HudModel.new()
	env = HudPresenter.HudEnv.new()
	env.view_size = Vector2(2400, 1080)
	snap = ViewSnapshot.new()
	snap.hush.present = true
	snap.hush.room = "kitchen"
	snap.hush.x = 3600
	snap.hush.state = "IDLE"
	snap.bellows.present = true
	snap.bellows.room = "kitchen"
	snap.bellows.x = 3000


func _ctx(verb: String, danger: String = "green", item: String = "", icon: String = "") -> Dictionary:
	return {"verb": verb, "danger": danger, "item_needed": item, "target_icon": icon, "ring_pm": 500}


func test_verb_table() -> void:
	var table := {"rig": HudModel.Verb.RIG, "rig_dim": HudModel.Verb.RIG_DIM, "freeze": HudModel.Verb.FREEZE,
		"pop_out": HudModel.Verb.POP_OUT, "go": HudModel.Verb.GO, "none": HudModel.Verb.FREEZE}
	for v in table:
		p.fill(m, snap, _ctx(String(v)), env)
		assert_eq(m.verb, table[v], "verb %s" % v)


func test_rig_carries_item_icon_and_ring() -> void:
	p.fill(m, snap, _ctx("rig", "green", "squeaker", "res://art/house/props/kettle.svg"), env)
	assert_eq(m.verb_item_icon, "squeaker")
	assert_eq(m.verb_target_icon, "res://art/house/props/kettle.svg")
	assert_between(m.ring_frac, 0.49, 0.51)
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(m.ring_frac, 0.0, "no ring outside RIG")


## (fix-hud R2) The Hud reads the hold from the sim (Hush RIGGING), not from the ring rising.
func test_holding_while_she_rigs() -> void:
	p.fill(m, snap, _ctx("rig", "green", "squeaker"), env)
	assert_false(m.holding, "standing at the rig point is not a hold")
	snap.hush.state = "RIGGING"
	p.fill(m, snap, _ctx("rig", "green", "squeaker"), env)
	assert_true(m.holding, "RIGGING holds")
	env.paused = true
	p.fill(m, snap, _ctx("rig", "green", "squeaker"), env)
	assert_true(m.holding, "a paused frame keeps the hold")
	env.paused = false
	snap.hush.state = "IDLE"
	p.fill(m, snap, {}, env)
	assert_false(m.holding, "let go (fallback verb path too)")


func test_rim_colours() -> void:
	for d in [["green", HudModel.Rim.GREEN], ["amber", HudModel.Rim.AMBER], ["red", HudModel.Rim.RED]]:
		p.fill(m, snap, _ctx("freeze", String(d[0])), env)
		assert_eq(m.rim, d[1], "rim %s" % d[0])


func test_ff_mode_only_while_hidden() -> void:
	snap.hush.state = "HIDDEN"
	p.fill(m, snap, _ctx("pop_out"), env)
	assert_eq(m.clarence_mode, HudModel.ClarenceMode.FF, "⏩ while hidden")
	snap.hush.state = "IDLE"
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(m.clarence_mode, HudModel.ClarenceMode.SQUEAK, "squeak otherwise")


func test_tray_highlight_marks_the_needed_item_at_a_rig_point() -> void:
	snap.hush.carrying = PackedStringArray(["honey", "squeaker"])
	p.fill(m, snap, _ctx("rig", "green", "squeaker"), env)
	assert_eq(m.tray_highlight, 1, "the squeaker slot")
	assert_eq(m.tray, PackedStringArray(["honey", "squeaker"]))
	p.fill(m, snap, _ctx("freeze", "green", "squeaker"), env)
	assert_eq(m.tray_highlight, -1, "no highlight away from a rig point")


func test_pick_strip_from_pick_window() -> void:
	p.on_events([{"e": "pick_window", "t": 10, "container": "hall_confiscated_box", "items": ["squeaker", "pepper"]}])
	snap.hush.state = "PICK_WINDOW"
	env.pick_screen_pos = Vector2(640, 300)
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(m.pick_strip_container, "hall_confiscated_box")
	assert_eq(m.pick_strip_items, PackedStringArray(["squeaker", "pepper"]))
	assert_eq(m.pick_strip_pos, Vector2(640, 300), "strip at the container's top centre")
	p.on_events([{"e": "pick", "t": 20, "item": "squeaker"}])
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(m.pick_strip_container, "", "closed after the pick")
	assert_eq(m.pick_strip_pos, Vector2.ZERO)


func test_edge_bubble_upstairs() -> void:
	snap.bellows.room = "bedroom"
	snap.bellows.floor = 1
	env.bellows_on_screen = false
	env.bellows_screen = Vector2(1200, -400)
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(m.edge_bubble_dir, Vector2(0, -1))
	assert_eq(m.edge_bubble_label, UiStrings.t("hud.edge_upstairs"))


func test_edge_bubble_rooms_to_the_right() -> void:
	snap.hush.room = "hall"
	snap.hush.x = 900
	snap.bellows.room = "kitchen"
	env.bellows_on_screen = false
	env.bellows_screen = Vector2(4000, 700)
	p.fill(m, snap, _ctx("freeze"), env)
	var d := HouseLayout.load_default().room_distance("hall", "kitchen")
	assert_gt(m.edge_bubble_dir.x, 0.5, "points right")
	var want := UiStrings.t("hud.edge_room_right") if d == 1 else UiStrings.t("hud.edge_rooms_right", {"n": d})
	assert_eq(m.edge_bubble_label, want)


func test_edge_bubble_hidden_while_he_is_on_screen_or_in_the_pip() -> void:
	snap.bellows.room = "parlour"
	env.bellows_on_screen = true
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(m.edge_bubble_dir, Vector2.ZERO)
	env.bellows_on_screen = false
	env.pip_shown = true
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(m.edge_bubble_dir, Vector2.ZERO, "the PiP shows him instead")


func test_edge_bubble_emote_from_micro_gag_for_its_len() -> void:
	if not ("edge_bubble_emote" in m):
		skip("HudModel.edge_bubble_emote not landed (s2-ui)")
		return
	snap.bellows.room = "parlour"
	env.bellows_on_screen = false
	env.bellows_screen = Vector2(-300, 700)
	p.on_events([{"e": "micro_gag", "t": 100, "id": "mg_admire", "vis": "edge", "emote": "sing", "len": 60}])
	env.tick = 130
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(String(m.get("edge_bubble_emote")), "sing")
	env.tick = 170
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(String(m.get("edge_bubble_emote")), "", "gone after its len")
	p.on_events([{"e": "micro_gag", "t": 200, "id": "mg_x", "vis": "room", "emote": "hum", "len": 60}])
	env.tick = 210
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(String(m.get("edge_bubble_emote")), "", "only vis == edge beats")


func test_fallback_verb_without_action_context() -> void:
	snap.hush.state = "HIDDEN"
	p.fill(m, snap, {}, env)
	assert_eq(m.verb, HudModel.Verb.POP_OUT)
	p.on_events([{"e": "pin", "t": 5}])
	p.fill(m, snap, {}, env)
	assert_eq(m.verb, HudModel.Verb.GO, "GO ▶ with a pin")
	snap.hush.state = "IDLE"
	p.on_events([{"e": "pop_out", "t": 6}])
	p.fill(m, snap, {}, env)
	assert_eq(m.verb, HudModel.Verb.FREEZE)


func test_applause_link_and_fuse() -> void:
	snap.applause_tenths = 425
	snap.link = 2
	snap.fuse_ticks = 300
	p.fill(m, snap, _ctx("freeze"), env)
	assert_eq(m.applause, 42)
	assert_eq(m.mult_pct, 150)
	assert_eq(m.fuse_frac, 1.0, "full at the peak")
	snap.fuse_ticks = 150
	p.fill(m, snap, _ctx("freeze"), env)
	assert_between(m.fuse_frac, 0.49, 0.51)


func test_fill_costs_under_0_2_ms() -> void:
	var ctx := _ctx("rig", "amber", "squeaker")
	snap.hush.carrying = PackedStringArray(["squeaker"])
	p.fill(m, snap, ctx, env)
	var t0 := Time.get_ticks_usec()
	for i in 2000:
		env.tick = i
		p.fill(m, snap, ctx, env)
	var per := float(Time.get_ticks_usec() - t0) / 2000.0
	assert_lt(per, 200.0, "HudPresenter.fill %.1f µs/frame" % per)
