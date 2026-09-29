## CharacterView (s2-view brief §4.1): real rigs with the fixture clips — the flavour rule (a tap
## one frame after `rigged` stops the snicker), micro-gag overlays (start, stop on a state change,
## the face-preset fallback), reaction frame-lock (tier, suppressed, last beat after the settle,
## the `_ko` knock-on entry), fallback counting, the body-is-the-meter mapping table (tint,
## specs, residues, costume, combos — SOAKED + FRAZZLED with no combo stays two looks), stairs
## position monotonic across the leg.
extends TestBase

const FIX := preload("res://tests/view/view_fixtures.gd")

var _cvs: Array = []


func before_each() -> void:
	FIX.install(true)
	_cvs.clear()


func after_each() -> void:
	for cv in _cvs:
		(cv as Node).queue_free()
	_cvs.clear()
	FIX.uninstall()
	await tree.process_frame


func _cv(actor: String) -> CharacterView:
	var cv := CharacterView.new()
	cv.layout = HouseLayout.load_default()
	tree.root.add_child(cv)
	cv.setup(actor)
	_cvs.append(cv)
	return cv


func _actor(state: String) -> ViewSnapshot.Actor:
	var a := ViewSnapshot.Actor.new()
	a.present = true
	a.room = "kitchen"
	a.x = 3000.0
	a.state = state
	a.facing = 1
	return a


func _frames(cv: CharacterView, a: ViewSnapshot.Actor, n: int) -> void:
	for i in n:
		cv.apply(a, a, 0.0, 1.0 / 60.0)


# --- meter mapping (pure) -------------------------------------------------------------------

func test_residue_looks_without_a_combo_stay_two_looks() -> void:
	var looks := CharacterView.rig_looks(PackedStringArray(["FRAZZLED", "SOAKED"]), PackedStringArray(), false, "")
	assert_eq(looks, PackedStringArray(["FRAZZLED", "SOAKED"]), "L4: no combo formed → both residues stay on")
	var poodle := CharacterView.rig_looks(PackedStringArray(["FRAZZLED", "SOAKED"]), PackedStringArray(["poodle"]), false, "")
	assert_has(poodle, "COMBO:poodle", "a formed combo adds its look (the rig hides the two it replaces)")
	var gone := CharacterView.rig_looks(PackedStringArray(["SOAKED"]), PackedStringArray(["poodle"]), false, "")
	assert_false(gone.has("COMBO:poodle"), "a combo whose residue was cleared is off")


func test_costume_and_blind_sub_looks() -> void:
	var c := CharacterView.rig_looks(PackedStringArray(["COSTUME"]), PackedStringArray(), false, "jelly_helmet")
	assert_eq(c, PackedStringArray(["COSTUME", "COSTUME:jelly_helmet"]))
	var b := CharacterView.rig_looks(PackedStringArray(["FRAZZLED"]), PackedStringArray(), true, "")
	assert_has(b, "FRAZZLED:blind", "BLINDED + FRAZZLED → the flipped bouffant sub-look")


func test_specs_on_when_the_sim_says_or_livid() -> void:
	assert_eq(CharacterView.specs_state(false, 0), "dangling")
	assert_eq(CharacterView.specs_state(true, 0), "on")
	assert_eq(CharacterView.specs_state(false, 3), "on", "Livid jams the specs on")
	assert_eq(CharacterView.SIDEBURN_BY_TIER, PackedStringArray(["flat", "bristle", "bristle", "puffed"]))


func test_costume_look_comes_from_the_prank() -> void:
	var ci := ContentInfo.of(null)
	assert_eq(ci.costume_look("cold_open"), "jelly_helmet")
	assert_eq(ci.costume_look("achoo_ria"), "")
	assert_eq(ci.step_prep("achoo_ria", 0), "q")


# --- stairs --------------------------------------------------------------------------------

func test_stairs_position_is_monotonic_along_the_diagonal() -> void:
	var prev := ViewSnapshot.Actor.new()
	var cur := ViewSnapshot.Actor.new()
	for a in [prev, cur]:
		(a as ViewSnapshot.Actor).present = true
		(a as ViewSnapshot.Actor).leg_kind = "stairs"
		(a as ViewSnapshot.Actor).leg_from_x = 1050.0
		(a as ViewSnapshot.Actor).leg_to_x = 1450.0
		(a as ViewSnapshot.Actor).leg_from_y = -700.0
		(a as ViewSnapshot.Actor).leg_to_y = 0.0
	var last := Vector2(-INF, -INF)
	for pm in range(0, 1001, 50):
		prev.leg_pm = maxi(0, pm - 50)
		cur.leg_pm = pm
		for alpha in [0.0, 0.5, 1.0]:
			var p := CharacterView.stage_position(prev, cur, alpha)
			assert_ge(p.x, last.x - 0.001, "x never goes back")
			assert_ge(p.y, last.y - 0.001, "coming down: y never goes back up")
			last = p
	assert_almost_eq(last.x, 1450.0, 0.01)
	assert_almost_eq(last.y, 0.0, 0.01)


# --- flavour rule ---------------------------------------------------------------------------

func test_a_tap_one_frame_after_rigged_stops_the_snicker() -> void:
	var cv := _cv("hush")
	assert_true(cv.uses_rig, "the real Hush rig loads (never a puppet)")
	var a := _actor("IDLE")
	_frames(cv, a, 3)
	cv.on_event({"e": "rigged", "prank": "achoo_ria"})
	_frames(cv, a, 1)
	assert_eq(cv.pick().key, "flavour:snicker", "rigged → the snicker")
	assert_eq(cv.current_clip(), "hush/fx_snicker")
	var walk := _actor("WALK")
	walk.moving = true
	walk.speed_px_s = 400.0
	_frames(cv, walk, 1)
	assert_eq(cv.ctx.flavour, "", "the flavour is gone on the very next frame")
	assert_ne(cv.pick().key, "flavour:snicker")


func test_snicker_then_glance_then_idle() -> void:
	var cv := _cv("hush")
	var a := _actor("IDLE")
	_frames(cv, a, 2)
	cv.on_event({"e": "rigged", "prank": "achoo_ria"})
	var seen := {}
	for i in 200:
		_frames(cv, a, 1)
		seen[cv.pick().key] = true
	assert_true(seen.has("flavour:snicker") and seen.has("flavour:glance"), "snicker → glance (then_key)")
	assert_eq(cv.pick().key, "idle")


func test_shrug_is_an_overlay_and_stops_on_a_state_change() -> void:
	var cv := _cv("hush")
	var a := _actor("IDLE")
	_frames(cv, a, 2)
	cv.on_event({"e": "cmd_rejected", "c": "go", "why": "busy"})
	_frames(cv, a, 2)
	assert_eq(cv.pick().ov_key, "flavour:shrug")
	assert_eq(cv.overlay_clip(), "hush/fx_shrug")
	assert_eq(cv.pick().key, "idle", "the base keeps playing under the shrug")
	_frames(cv, _actor("RIGGING"), 1)
	assert_eq(cv.overlay_clip(), "", "stopped within one frame of the state change")


func test_idle_fidget_after_three_seconds() -> void:
	var cv := _cv("hush")
	var a := _actor("IDLE")
	_frames(cv, a, 170)
	assert_eq(cv.pick().key, "idle")
	_frames(cv, a, 20)
	assert_eq(cv.pick().key, "idle_fidgets", "idle ≥ 3 s → a fidget")


# --- micro-gags -----------------------------------------------------------------------------

func test_micro_gag_overlay_plays_over_the_activity_and_stops_on_state_change() -> void:
	var cv := _cv("bellows")
	var a := _actor("ROUTINE")
	a.activity = "tea"
	_frames(cv, a, 2)
	assert_eq(cv.current_clip(), "bellows/fx_act_tea")
	cv.on_event({"e": "micro_gag", "id": "pinkie_up", "activity": "tea", "room": "kitchen", "x": 2940, "len": 48, "emote": "yum"})
	_frames(cv, a, 3)
	assert_eq(cv.pick().ov_key, "mg:pinkie_up")
	assert_eq(cv.overlay_clip(), "bellows/fx_mg", "mg:* → the overlay")
	assert_eq(cv.current_clip(), "bellows/fx_act_tea", "the tea loop keeps playing underneath")
	_frames(cv, _actor("CURIOUS"), 1)
	assert_eq(cv.overlay_clip(), "", "any state change stops it")


func test_micro_gag_fallback_is_the_emote_face_for_len() -> void:
	var cv := _cv("bellows")
	var m: Dictionary = (ClipMap.map_override["bellows"] as Dictionary).duplicate()
	m.erase("mg:*")
	cv.map = m
	var a := _actor("ROUTINE")
	a.activity = "tea"
	_frames(cv, a, 1)
	cv.on_event({"e": "micro_gag", "id": "pinkie_up", "len": 30, "emote": "yum"})
	_frames(cv, a, 2)
	assert_eq(cv.fallback_face(), "blissful", "yum → the blissful face preset")
	assert_eq(cv.clip_fallbacks, 1, "counted once")
	_frames(cv, a, 40)
	assert_eq(cv.fallback_face(), "", "cleared after len")


# --- reactions ------------------------------------------------------------------------------

func test_reaction_is_frame_locked_with_tier_and_the_last_beat_after_the_settle() -> void:
	var cv := _cv("bellows")
	var a := _actor("REACTING")
	a.reacting = true
	a.react_clip = "bellows/rx_fx_take_a"
	a.react_tier = 2
	a.react_t = 40
	a.react_len = 120 + 40
	a.react_base_len = 120
	a.react_last_beat = "bellows/fx_beat"
	cv.apply(a, a, 0.5, 1.0 / 60.0)
	assert_eq(cv.current_clip(), "bellows/rx_fx_take_a")
	assert_almost_eq(cv.current_frame(), 40.5, 0.001, "frame = react_t + alpha")
	assert_eq(cv.pick().tier, 2)
	a.react_t = 125
	cv.apply(a, a, 0.0, 1.0 / 60.0)
	assert_eq(cv.current_clip(), "bellows/fx_beat", "the sim's last beat after the settle")
	assert_almost_eq(cv.current_frame(), 5.0, 0.001, "the beat's frame starts at base_len")


func test_knock_on_entry_plays_the_ko_variant() -> void:
	var cv := _cv("bellows")
	var a := _actor("REACTING")
	a.reacting = true
	a.react_clip = "bellows/rx_fx_take_a"
	a.react_entry = 28
	a.react_t = 28
	a.react_len = 120
	cv.apply(a, a, 0.0, 1.0 / 60.0)
	assert_eq(cv.current_clip(), "bellows/rx_fx_take_a_ko", "entry > 0 → <clip>_ko")


func test_missing_reaction_clip_falls_back_and_is_counted_once() -> void:
	var cv := _cv("bellows")
	var a := _actor("REACTING")
	a.reacting = true
	a.react_clip = "bellows/rx_not_authored_a"
	a.react_len = 120
	for i in 10:
		a.react_t = i
		cv.apply(a, a, 0.0, 1.0 / 60.0)
	assert_eq(cv.pick().key, "reaction_fallback")
	assert_eq(cv.clip_fallbacks, 1, "one fallback per occurrence, not per frame")
	assert_eq(int(cv.fallback_by_clip.get("bellows/rx_not_authored_a", 0)), 1)
	assert_eq(cv.puppets, 0, "never a puppet when the rig loads")


func test_one_shot_bump_is_frame_locked_to_the_sim() -> void:
	var cv := _cv("bellows")
	var a := _actor("ROUTINE")
	a.oneshot = "bump"
	a.oneshot_t = 30
	a.oneshot_len = 82
	cv.apply(a, a, 0.25, 1.0 / 60.0)
	assert_eq(cv.current_clip(), "bellows/fx_bump")
	assert_almost_eq(cv.current_frame(), 30.25, 0.001)


## Hush is not drawn in the room before her climb-in starts, and the climb-in never flips (it is
## authored facing +1) — s2-fix G #14: the Prologue's first frames showed her standing by the
## window ~100 ticks before `act_climb_in`.
func test_hush_hidden_before_the_climb_in_and_never_flipped_during_it() -> void:
	var cv := _cv("hush")
	if not cv.uses_rig:
		skip("hush rig did not load")
		return
	var a := _actor("IDLE")
	a.entering = true
	a.oneshot = ""
	a.facing = -1
	cv.apply(a, a, 0.0, 1.0 / 60.0)
	assert_false(cv.rig.visible, "entering, climb-in not started yet: not drawn")
	a.oneshot = "enter"
	a.oneshot_t = 10
	for i in 8:
		cv.apply(a, a, 0.0, 1.0 / 60.0)
	assert_true(cv.rig.visible, "the climb-in plays")
	assert_eq(int(cv.rig.call("facing")), 1, "the climb-in keeps its authored facing +1")
	a.entering = false
	a.oneshot = ""
	for i in 12:
		cv.apply(a, a, 0.0, 1.0 / 60.0)
	assert_eq(int(cv.rig.call("facing")), -1, "after it, the sim's facing again")
