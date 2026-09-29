## ClipMap — the s2-view map-key schema (brief §4.1.1): every key, its selection rule and its
## fallback, the resolution order, skins, `*` families, the merge of the animation task's map
## over the default map, and the default maps themselves.
extends TestBase

const FIX := preload("res://tests/view/view_fixtures.gd")

## Every schema key → a clip ("b/<key>"), so a test can delete one and watch the fallback.
var MAP := {
	"idle": "b/idle",
	"idle_fidgets": ["b/fidget_a", "b/fidget_b"],
	"walk": {"clip": "b/walk", "stride_px": 56, "speed_px_s": 240},
	"walk@tier2": {"clip": "b/walk_t2", "stride_px": 56, "speed_px_s": 264},
	"walk@tier3": {"clip": "b/walk_t3", "stride_px": 56, "speed_px_s": 276},
	"walk@blind": {"clip": "b/walk_blind", "stride_px": 48, "speed_px_s": 240},
	"walk@on_guard": {"clip": "b/walk_guard", "stride_px": 56, "speed_px_s": 240},
	"run": {"clip": "b/run", "stride_px": 150, "speed_px_s": 600},
	"turn": "b/turn",
	"door": "b/door",
	"stairs_up": "b/stairs_up",
	"stairs_down": "b/stairs_down",
	"reaction": "<from sim>",
	"reaction_fallback": "b/rx_generic",
	"state:chase": {"clip": "b/chase", "stride_px": 150, "speed_px_s": 600},
	"state:curious": "b/curious",
	"state:hidden": "",
	"state:meltdown": ["b/melt_a", "b/melt_b", "b/melt_c"],
	"rigging@q": "b/tinker_q",
	"rigging@s": "b/tinker_s",
	"rigging@b": "b/tinker_b",
	"state:rigging": "b/tinker",
	"activity:tea": "b/tea",
	"freeze": ["b/f1", "b/f2", "b/f3"],
	"freeze_midjob": "b/f_mid",
	"oneshot:bump": "b/bump",
	"oneshot:doorway_pause": {"clip": "b/cravat", "loop": true},
	"oneshot:head_turn": "b/head_turn",
	"oneshot:caught:lecture": ["b/lec_a", "b/lec_b", "b/lec_c"],
	"oneshot:caught:doorstep": {"clip": "b/doorstep", "then": "b/tomato"},
	"bit:*": "b/{id}",
	"mg:*": "b/mg_{id}",
	"cue:laugh_picture": "b/cue_picture",
	"flavour:snicker": "b/snicker",
	"flavour:shrug": "b/shrug",
	"skin:pip": {"oneshot:caught:lecture": ["b/broom_a", "b/broom_b", "b/broom_c"]},
}

var _have: Dictionary = {}
var _missing: Dictionary = {}
var _ctx := ClipMap.Ctx.new()


func _exists(c: String) -> bool:
	return not _missing.has(c)


func _len(c: String) -> int:
	return {"b/doorstep": 20, "b/tomato": 16}.get(c, 60)


func before_each() -> void:
	_missing.clear()
	_ctx = ClipMap.Ctx.new()
	_ctx.rig = "bellows"
	_ctx.exists_fn = _exists
	_ctx.len_fn = _len


func after_each() -> void:
	FIX.uninstall()


func _pick(a: ViewSnapshot.Actor, alpha: float = 0.0) -> ClipMap.Pick:
	var p := ClipMap.Pick.new()
	ClipMap.resolve(MAP, a, alpha, p, _ctx)
	return p


func _actor() -> ViewSnapshot.Actor:
	var a := ViewSnapshot.Actor.new()
	a.present = true
	a.state = "ROUTINE"
	return a


func test_reaction_is_frame_locked_with_tier_and_suppressed() -> void:
	var a := _actor()
	a.reacting = true
	a.react_clip = "b/rx_sneeze_blast_a"
	a.react_t = 41
	a.react_len = 165
	a.react_tier = 3
	a.react_suppressed = true
	var p := _pick(a, 0.5)
	assert_eq(p.clip, "b/rx_sneeze_blast_a")
	assert_true(p.external)
	assert_almost_eq(p.frame, 41.5, 1e-6)
	assert_false(p.loop)
	assert_eq(p.tier, 3)
	assert_true(p.suppressed)


func test_knock_on_entry_plays_the_ko_variant_when_it_exists() -> void:
	var a := _actor()
	a.reacting = true
	a.react_clip = "b/rx_drench_a"
	a.react_t = 48
	a.react_entry = 48
	assert_eq(_pick(a).clip, "b/rx_drench_a_ko", "entry > 0 → _ko")
	_missing["b/rx_drench_a_ko"] = true
	var p := _pick(a)
	assert_eq(p.clip, "b/rx_drench_a", "no _ko authored → the plain clip")
	assert_eq(p.wanted, "", "_ko is optional: not a fallback")
	a.react_entry = 0
	_missing.clear()
	assert_eq(_pick(a).clip, "b/rx_drench_a", "no knock-on → never _ko")


func test_last_beat_plays_after_the_settle() -> void:
	var a := _actor()
	a.reacting = true
	a.react_clip = "b/rx_take"
	a.react_len = 190
	a.react_base_len = 120
	a.react_last_beat = "b/beat_slow_burn"
	a.react_t = 119
	assert_eq(_pick(a).clip, "b/rx_take")
	a.react_t = 120
	var p := _pick(a, 0.25)
	assert_eq(p.clip, "b/beat_slow_burn", "the beat starts on the settle's last frame")
	assert_almost_eq(p.frame, 0.25, 1e-6, "beat frame = react_t − base length")
	assert_eq(p.key, "reaction:last_beat")
	_missing["b/beat_slow_burn"] = true
	p = _pick(a)
	assert_eq(p.clip, "b/rx_take", "missing beat → hold the reaction")
	assert_eq(p.wanted, "b/beat_slow_burn", "and it is counted")


func test_missing_reaction_uses_the_fallback_and_is_counted() -> void:
	_missing["b/rx_not_authored"] = true
	var a := _actor()
	a.reacting = true
	a.react_clip = "b/rx_not_authored"
	var p := _pick(a)
	assert_eq(p.clip, "b/rx_generic")
	assert_eq(p.key, "reaction_fallback")
	assert_eq(p.wanted, "b/rx_not_authored")
	_missing["b/rx_generic"] = true
	p = _pick(a)
	assert_eq(p.clip, "b/idle", "no fallback either → the ordinary resolution (never nothing)")


func test_oneshot_base_rows_are_frame_locked() -> void:
	var a := _actor()
	a.oneshot = "bump"
	a.oneshot_t = 31
	a.oneshot_len = 82
	a.moving = true
	var p := _pick(a, 0.5)
	assert_eq(p.clip, "b/bump")
	assert_eq(p.key, "oneshot:bump")
	assert_true(p.external)
	assert_almost_eq(p.frame, 31.5, 1e-6)
	assert_false(p.loop)


func test_oneshot_loop_row_loops_for_its_length() -> void:
	var a := _actor()
	a.oneshot = "doorway_pause"
	a.oneshot_t = 45
	a.oneshot_len = 70
	var p := _pick(a)
	assert_eq(p.clip, "b/cravat")
	assert_true(p.loop, "the pause (1–90 ticks) loops the cravat straighten")
	assert_almost_eq(p.frame, 45.0, 1e-6)


func test_oneshot_overlay_rows_go_to_the_overlay_layer() -> void:
	var a := _actor()
	a.activity = "tea"
	a.oneshot = "head_turn"
	a.oneshot_t = 12
	var p := _pick(a)
	assert_eq(p.clip, "b/tea", "the activity keeps playing underneath")
	assert_eq(p.ov_clip, "b/head_turn")
	assert_almost_eq(p.ov_frame, 12.0, 1e-6)


func test_squeak_bit_replaces_the_activity_and_falls_back_to_it() -> void:
	var a := _actor()
	a.activity = "tea"
	a.oneshot = "bit:bit_tea"
	a.oneshot_t = 10
	var p := _pick(a)
	assert_eq(p.clip, "b/bit_tea", "bit:* expands with {id}")
	assert_eq(p.key, "bit:bit_tea")
	_missing["b/bit_tea"] = true
	p = _pick(a)
	assert_eq(p.clip, "b/tea", "missing bit clip → activity")
	assert_eq(p.wanted, "b/bit_tea")


func test_lecture_variant_and_the_pip_skin() -> void:
	var a := _actor()
	a.state = "CAUGHT_HOLD"
	a.oneshot = "caught:lecture"
	a.oneshot_var = 2
	a.oneshot_t = 5
	assert_eq(_pick(a).clip, "b/lec_c", "variant 2 → lec_c")
	_ctx.skin = "pip"
	assert_eq(_pick(a).clip, "b/broom_c", "skin:pip overrides the entry")


func test_then_clip_follows_the_first_on_the_same_clock() -> void:
	var a := _actor()
	a.oneshot = "caught:doorstep"
	a.oneshot_t = 10
	assert_eq(_pick(a).clip, "b/doorstep")
	a.oneshot_t = 24
	var p := _pick(a)
	assert_eq(p.clip, "b/tomato", "after the doorstep's 20 frames: the tomato")
	assert_almost_eq(p.frame, 4.0, 1e-6)


func test_unmapped_oneshot_is_counted_and_falls_through() -> void:
	var a := _actor()
	a.activity = "tea"
	a.oneshot = "face_to_face"
	var p := _pick(a)
	assert_eq(p.clip, "b/tea")
	assert_eq(p.wanted, "oneshot:face_to_face", "a one-shot the sim demands with no map key")


func test_state_order_rigging_tiers_and_hidden() -> void:
	var a := _actor()
	a.state = "RIGGING"
	_ctx.rig_tier = "s"
	assert_eq(_pick(a).clip, "b/tinker_s", "rigging@<tier> first")
	_missing["b/tinker_s"] = true
	assert_eq(_pick(a).clip, "b/tinker", "then state:rigging")
	a.state = "HIDDEN"
	var p := _pick(a)
	assert_true(p.hidden)
	assert_eq(p.clip, "")
	a.state = "MELTDOWN"
	_ctx.state_var = 1
	assert_eq(_pick(a).clip, "b/melt_b", "a list value is picked by the variant")


func test_state_without_stride_is_skipped_while_moving() -> void:
	var a := _actor()
	a.state = "CURIOUS"
	a.moving = true
	a.speed_px_s = 240.0
	assert_eq(_pick(a).clip, "b/walk", "CURIOUS walking to the noise walks")
	a.moving = false
	assert_eq(_pick(a).clip, "b/curious")
	a.state = "CHASE"
	a.moving = true
	a.running = true
	a.speed_px_s = 600.0
	var p := _pick(a)
	assert_eq(p.clip, "b/chase", "a locomotion state entry plays while moving")
	assert_true(p.stride)


func test_activity_then_freeze_then_door_and_stairs() -> void:
	var a := _actor()
	a.activity = "tea"
	assert_eq(_pick(a).clip, "b/tea")
	a.activity = "pickles"
	assert_eq(_pick(a).clip, "b/idle", "no key, no activities.json clip → idle")
	_ctx.activity_clip_fn = func(id: String) -> String: return "b/act_" + id
	assert_eq(_pick(a).clip, "b/act_pickles", "activities.json clip when the map has no key")
	a.activity = ""
	a.state = "FROZEN"
	a.freeze_pose_seed = 4
	assert_eq(_pick(a).clip, "b/f2", "seed % 3")
	a.rig_pm = 400
	assert_eq(_pick(a).clip, "b/f_mid", "caught mid-job")
	_missing["b/f_mid"] = true
	assert_eq(_pick(a).clip, "b/f2", "freeze_midjob → freeze")
	a.state = "DOOR"
	a.rig_pm = 0
	a.leg_kind = "door"
	assert_eq(_pick(a).clip, "b/door")
	_missing["b/door"] = true
	assert_eq(_pick(a).clip, "b/walk", "door → walk")
	a.leg_kind = "stairs"
	a.leg_up = true
	assert_eq(_pick(a).clip, "b/stairs_up")
	a.leg_up = false
	assert_eq(_pick(a).clip, "b/stairs_down")


func test_walk_variants_and_their_fallbacks() -> void:
	var a := _actor()
	a.moving = true
	a.speed_px_s = 120.0
	var p := _pick(a)
	assert_eq(p.clip, "b/walk")
	assert_almost_eq(p.speed, 0.5, 1e-6, "walk rate follows speed")
	a.tier = 2
	assert_eq(_pick(a).clip, "b/walk_t2")
	a.tier = 3
	assert_eq(_pick(a).clip, "b/walk_t3")
	_missing["b/walk_t3"] = true
	assert_eq(_pick(a).clip, "b/walk_t2", "tier3 → tier2")
	a.tier = 0
	a.on_guard = true
	assert_eq(_pick(a).clip, "b/walk_guard")
	_missing["b/walk_guard"] = true
	assert_eq(_pick(a).clip, "b/walk", "on_guard → walk (tier 0)")
	a.blinded = true
	assert_eq(_pick(a).clip, "b/walk_blind", "blinded first")
	a.running = true
	assert_eq(_pick(a).clip, "b/run")
	_missing["b/run"] = true
	assert_eq(_pick(a).clip, "b/walk_blind", "run → walk")


func test_turn_flavour_fidget_idle() -> void:
	var a := _actor()
	_ctx.turn_f = 2.0
	var p := _pick(a)
	assert_eq(p.clip, "b/turn")
	assert_true(p.external)
	assert_false(p.loop)
	_ctx.turn_f = -1.0
	_ctx.flavour = "snicker"
	_ctx.flavour_f = 7.0
	p = _pick(a)
	assert_eq(p.clip, "b/snicker")
	assert_almost_eq(p.frame, 7.0, 1e-6)
	_ctx.flavour = ""
	_ctx.fidget_i = 1
	assert_eq(_pick(a).clip, "b/fidget_b")
	_ctx.fidget_i = -1
	assert_eq(_pick(a).clip, "b/idle")
	a.state = "WALK"
	a.moving = true
	_ctx.flavour = "snicker"
	assert_eq(_pick(a).clip, "b/walk", "a flavour never plays over a move")


func test_overlay_priority_cue_mg_flavour_and_face_fallback() -> void:
	var a := _actor()
	a.activity = "tea"
	_ctx.mg = "hum"
	_ctx.mg_emote = "hum"
	_ctx.ov_flavour = "shrug"
	var p := _pick(a)
	assert_eq(p.ov_clip, "b/mg_hum", "mg:* expands with {id}")
	_ctx.cue = "laugh_picture"
	assert_eq(_pick(a).ov_clip, "b/cue_picture", "cue over mg")
	_ctx.cue = ""
	_missing["b/mg_hum"] = true
	p = _pick(a)
	assert_eq(p.ov_clip, "", "missing micro-gag clip: no overlay")
	assert_eq(p.ov_face, "hum", "the emote's face preset instead")
	assert_eq(p.ov_wanted, "b/mg_hum", "and it is counted")
	_ctx.mg = ""
	assert_eq(_pick(a).ov_clip, "b/shrug")
	a.reacting = true
	a.react_clip = "b/rx_take"
	assert_eq(_pick(a).ov_clip, "", "reactions stop overlays")


func test_fx_rows_carry_their_effect() -> void:
	var a := _actor()
	a.state = "CAUGHT_HOLD"
	a.oneshot = "caught:wipe"
	var p := _pick(a)
	assert_eq(p.fx, "wipe", "the wipe is an FX row")
	assert_eq(p.clip, "b/idle")


func test_merge_data_map_wins_key_by_key() -> void:
	var base := {"idle": "d/idle", "walk": "d/walk", "skin:pip": {"a": "d/a", "b": "d/b"}}
	var over := {"idle": "x/idle", "skin:pip": {"a": "x/a"}}
	var m := ClipMap.merge(base, over)
	assert_eq(m["idle"], "x/idle")
	assert_eq(m["walk"], "d/walk")
	assert_eq(m["skin:pip"]["a"], "x/a")
	assert_eq(m["skin:pip"]["b"], "d/b")


func test_default_maps_use_the_schema() -> void:
	for rig in ["hush", "bellows", "_mannequin"]:
		var m := ClipMap.load_map(rig)
		assert_true(m.has("idle"), "%s map has idle" % rig)
	var h := ClipMap.load_map("hush")
	assert_eq((h["freeze"] as Array).size(), 8, "8 freeze poses")
	for k in ["stairs_up", "stairs_down", "door", "rigging@q", "rigging@s", "rigging@b", "oneshot:enter",
			"oneshot:caught:busted", "oneshot:caught:lecture", "oneshot:caught:doorstep", "flavour:snicker",
			"flavour:glance", "flavour:shrug", "flavour:pickup", "freeze_midjob", "idle_fidgets", "skin:pip"]:
		assert_true(h.has(k), "hush default map has %s" % k)
	for k2 in ["state:stairs", "state:door", "state:caught_hold"]:
		assert_false(h.has(k2), "hush: %s is replaced by the schema keys" % k2)
	var b := ClipMap.load_map("bellows")
	for k3 in ["walk@tier2", "walk@tier3", "walk@blind", "turn", "door", "stairs_up", "stairs_down", "bit:*", "mg:*",
			"oneshot:head_turn", "oneshot:doorway_pause", "oneshot:bump", "oneshot:bump_look", "oneshot:curious_stop",
			"oneshot:curious_look", "oneshot:chase_wheeze", "oneshot:stun", "oneshot:face_to_face", "oneshot:fizzle",
			"oneshot:specs_on", "oneshot:look_back", "oneshot:caught:grab", "oneshot:caught:lecture",
			"oneshot:caught:doorstep", "cue:laugh_doorframe", "cue:laugh_picture", "skin:pip"]:
		assert_true(b.has(k3), "bellows default map has %s" % k3)
	assert_false(b.has("state:caught_hold"), "the caught rows replace state:caught_hold")
	assert_false(b.has("state:curious"), "CURIOUS walks, then its one-shots play")


func test_every_map_key_is_in_the_schema() -> void:
	for rig in ["hush", "bellows"]:
		var m := ClipMap.load_map(rig)
		for k in m:
			var ks := ViewKit.s(k)
			if ClipMap.META_KEYS.has(ks):
				continue
			var fam := ks.get_slice(":", 0) + ":*" if ks.contains(":") else ks
			assert_true(ClipMap.SCHEMA_KEYS.has(ks) or ClipMap.SCHEMA_KEYS.has(fam), "%s: '%s' is a schema key" % [rig, ks])


func test_fixture_maps_resolve_on_real_fixture_clips() -> void:
	FIX.install()
	var bm := ClipMap.load_map("bellows")
	assert_eq(ViewKit.s(bm.get("idle", "")), "bellows/fx_idle", "the fixture map is live")
	var a := _actor()
	a.oneshot = "bump"
	a.oneshot_t = 10
	var p := ClipMap.Pick.new()
	var c := ClipMap.Ctx.new()
	c.rig = "bellows"
	ClipMap.resolve(bm, a, 0.0, p, c)
	assert_eq(p.clip, "bellows/fx_bump")
	assert_eq(ClipMap.clip_length("bellows/fx_bump"), 82, "fixture st_bump is the sim's 82 ticks")
	assert_not_null_clip("bellows/fx_bump")


func assert_not_null_clip(id: String) -> void:
	var c := ClipLib.get_clip(id)
	assert_true(c != null, "%s loads through ClipLib" % id)
	if c != null:
		assert_eq(c.errors.size(), 0, "%s: %s" % [id, ", ".join(c.errors)])
