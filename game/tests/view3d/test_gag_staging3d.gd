## r3d-fix-gags (QA round 1, Q-G1..Q-G6, Q-V2): the staging rules that put every Prologue gag's cause and contact
## on screen — his sidestep beside the gramophone, the dive turned upstage, the vase's teeter, Hush kept clear of the
## action button at the kitchen window, cue shots that yield to a payoff's punch-in, the cue pieces' data.
extends TestBase

const HOUSE := "res://data/house/house.json"
const HOUSE3D := "res://data/house/house3d.json"
const P00_ROOMS := ["parlour", "kitchen", "hall"]


func _actor(state: String = "ROUTINE") -> ViewSnapshot.Actor:
	var a := ViewSnapshot.Actor.new()
	a.present = true
	a.state = state
	a.facing = 1
	return a


func _cam(aspect: String = "20x9", rooms: Array = P00_ROOMS) -> CameraDirector3D:
	var cam := CameraDirector3D.new()
	cam.logical_size_override = View3DConst.logical_size(aspect)
	cam.setup(load_json(HOUSE), rooms)
	return cam


func _target(x_m: float) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(x_m, 0.0, View3DConst.LANE_Z)
	return n


## Q-G1: at the gramophone he stands beside it (house3d `bellows_dx`), and the sidestep holds through the reaction
## there (the dizzy spin plays with the turntable in view); walking drops it.
func test_bellows_sidesteps_beside_his_station_and_keeps_it_through_a_reaction() -> void:
	var a := _actor("ROUTINE")
	a.activity = "warmup"
	var st := {"bellows_z": -1.4, "yaw": -55.0, "bellows_dx": 0.5}
	var p := CharacterView3D.placement_for("bellows", a, {}, st, NAN)
	assert_almost_eq(float(p["dx"]), 0.5, 1e-6, "at the station: the sidestep")
	a.reacting = true
	p = CharacterView3D.placement_for("bellows", a, {}, st, NAN)
	assert_almost_eq(float(p["dx"]), 0.5, 1e-6, "reacting there: still beside it")
	assert_almost_eq(float(p["z"]), View3DConst.LANE_Z, 1e-6, "reacting: z stays the reaction's")
	a.reacting = false
	a.moving = true
	p = CharacterView3D.placement_for("bellows", a, {}, st, NAN)
	assert_almost_eq(float(p["dx"]), 0.0, 1e-6, "walking: no sidestep")
	var h3: Dictionary = load_json(HOUSE3D)
	var g: Dictionary = (h3["stations"] as Dictionary)["st_gramophone"]
	assert_ge(float(g.get("bellows_dx", 0.0)), 0.4, "the data: st_gramophone stands him ≥ 0.4 m right of it")


## Q-V2: the dive turns her upstage (cheat < 0: away from the camera) so it reads as going INTO the spot.
func test_the_dive_turns_her_upstage_into_the_spot() -> void:
	var a := _actor("DIVING")
	a.watched_spot = "kitchen_pantry_curtain"
	var p := CharacterView3D.placement_for("hush", a, {}, {}, -2.2)
	assert_lt(float(p["cheat"]), -30.0, "diving: the body yawed away from the camera")
	assert_almost_eq(float(p["z"]), -2.2, 1e-6, "toward the occupant depth")
	a.state = "HIDDEN"
	a.hidden_spot = "kitchen_pantry_curtain"
	p = CharacterView3D.placement_for("hush", a, {}, {}, -2.2)
	assert_ge(float(p["cheat"]), 0.0, "hidden: back to the normal cheat")


## Q-G4: the vase stands still for the first notes, then teeters harder with every nudge (never past ~20°).
func test_the_vase_teeters_from_the_third_nudge_and_grows() -> void:
	var peak := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for n in range(0, 6):
		for i in 120:
			peak[n] = maxf(peak[n], absf(CueStager3D.teeter_angle(n, float(i) / 60.0)))
	assert_almost_eq(peak[0], 0.0, 1e-9, "no teeter before any note")
	assert_almost_eq(peak[2], 0.0, 1e-9, "two nudges: still")
	assert_gt(peak[3], deg_to_rad(3.0), "three nudges: it rocks")
	assert_gt(peak[5], peak[4], "every nudge rocks it harder")
	assert_lt(peak[5], deg_to_rad(20.0), "on its base, never tipped by the teeter alone")


## Q-G4 / Q-G3: the cue pieces read at phone size (the vase at the live-prop ×1.5, the picture gilt) and the lints'
## boxes match.
func test_the_cue_pieces_are_big_and_bright() -> void:
	var h3: Dictionary = load_json(HOUSE3D)
	var dec: Dictionary = h3["decor"]
	var vase: Dictionary = dec["parlour_vase"]
	assert_ge(float(vase.get("scale", 1.0)), 1.5, "the vase ×1.5")
	var vb: Array = vase["box"]
	assert_ge(float(vb[4]) - float(vb[1]), 0.8, "its box is the scaled vase (≥ 0.8 m tall)")
	var pic: Dictionary = dec["parlour_picture_frame"]
	var c := Color(str(pic.get("color", "#000000")))
	assert_gt(c.s, 0.5, "the picture's frame is gilt (saturated), not the wall's mauve")


## Q-G5: after her climb-in at the kitchen window (the stage end) Hush never stands under the action button: the
## camera goes up to 1 m past the C2 limit to clear her, and a live box keeps its place.
func test_hush_stays_clear_of_the_action_button_at_the_stage_end() -> void:
	var cam := _cam("20x9")
	var vs := cam.view_size()
	cam.set_safe_rect(Rect2(Vector2.ZERO, vs))
	var hud := cam.hud_rects()
	assert_eq(hud.size(), 4, "the four always-on rects")
	if hud.size() < 4:
		cam.free()
		return
	var action: Rect2 = hud[3]
	var t := _target(19.0)
	cam.follow(t, func() -> float: return 0.0)
	cam.snap_now()
	cam.advance(1.0 / 60.0, 1.0 / 60.0)
	var r := cam.project_aabb(AABB(Vector3(19.0 - 0.35, 0.0, View3DConst.LANE_Z), Vector3(0.7, 1.6, 0.01)))
	assert_false(r.intersects(action), "Hush at the window clear of the action button (her %s, button %s)" % [r, action])
	assert_ge(r.position.x, 0.0, "and inside the screen")
	# in the middle of the kitchen nothing changes: the C1 framing holds
	t.position.x = 16.5
	cam.snap_now()
	cam.advance(1.0 / 60.0, 1.0 / 60.0)
	var r2 := cam.project_aabb(AABB(Vector3(16.5 - 0.35, 0.0, View3DConst.LANE_Z), Vector3(0.7, 1.6, 0.01)))
	assert_false(r2.intersects(action), "mid-kitchen: clear as before")
	t.free()
	cam.free()


## A cue shot (priority ≤ 5) yields at once to a payoff's punch-in; two cue shots still queue.
func test_a_cue_shot_yields_to_a_reaction_punch_in() -> void:
	var cam := _cam("20x9")
	var t := _target(10.0)
	cam.follow(t, func() -> float: return 0.0)
	cam.snap_now()
	cam.advance(1.0 / 60.0, 1.0 / 60.0)
	var shot := cam.request_gag(Vector3(9.0, 1.35, -1.0), 1.2, 8, 600, 20, CueStager3D.SHOT_PRIORITY)
	cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_eq(cam.active_gag_id(), shot, "the cue shot runs")
	var other := cam.request_gag(Vector3(9.5, 1.35, -1.0), 1.2, 8, 600, 20, CueStager3D.SHOT_PRIORITY)
	assert_eq(cam.active_gag_id(), shot, "an equal cue shot queues")
	var punch := cam.request_gag(Vector3(10.0, 1.2, -1.0), 1.4, 11, 90, 21, 10)
	assert_eq(cam.active_gag_id(), punch, "the reaction's punch-in replaces it at once")
	cam.cancel_gag(other)
	t.free()
	cam.free()


## Q-G2: the bonked wing flat rocks on its base, its top away from him (he walks left → it tips left), and settles
## within WING_F frames.
func test_the_bonked_frame_rocks_away_from_him_and_settles() -> void:
	var peak := 0.0
	var first_sign := 0.0
	for i in int(CueStager3D.WING_F):
		var th := CueStager3D.wing_angle(float(i) + 0.5, -1.0)
		peak = maxf(peak, absf(th))
		if first_sign == 0.0 and absf(th) > 1e-4:
			first_sign = signf(th)
	assert_gt(peak, deg_to_rad(1.0), "it visibly rocks")
	assert_le(peak, deg_to_rad(CueStager3D.WING_DEG) + 1e-6, "never more than WING_DEG")
	assert_eq(first_sign, 1.0, "walking left into it: the top tips left first (+z rotation)")
	assert_almost_eq(CueStager3D.wing_angle(CueStager3D.WING_F, -1.0), 0.0, 1e-9, "settled")
	assert_eq(signf(CueStager3D.wing_angle(2.0, 1.0)), -signf(CueStager3D.wing_angle(2.0, -1.0)), "mirrored by facing")


## Q-G5 / Q-G1 / Q-G2: the sound ring swells from a ring facing the camera, the spin's dust is a floor whirl, the
## bonk's contact a big star; a point burst after a ring burst goes back to a point (the pool is shared).
func test_ring_and_whirl_bursts_and_the_pool_resets_them() -> void:
	var fx := Fx3D.new()
	tree.root.add_child(fx)
	for k in ["squeak_ring", "spin_dust", "disc_whirl", "impact", "plaster", "sweat", "thunk_stars", "bonk_stars"]:
		assert_true(Fx3D.KINDS.has(k), "kind %s" % k)
	fx.burst("squeak_ring", Vector3(1.0, 1.0, -1.0))
	var p: CPUParticles3D = fx.get_child(0)
	assert_eq(p.emission_shape, CPUParticles3D.EMISSION_SHAPE_RING, "the squeak ring emits on a ring")
	assert_eq(p.emission_ring_axis, Vector3(0.0, 0.0, 1.0), "facing the camera")
	assert_gt(p.radial_accel_max, 0.0, "it swells outward")
	fx.burst("spin_dust", Vector3.ZERO)
	var q: CPUParticles3D = fx.get_child(1)
	assert_eq(q.emission_ring_axis, Vector3.UP, "the spin's dust on a floor ring")
	assert_gt(q.tangential_accel_max, 0.0, "swept round it")
	for i in Fx3D.MAX_EMITTERS - 1:
		fx.burst("dust", Vector3.ZERO)
	assert_eq(p.emission_shape, CPUParticles3D.EMISSION_SHAPE_POINT, "reused for a point burst: a point again")
	assert_almost_eq(p.radial_accel_max, 0.0, 1e-9, "no radial pull left over")
	fx.get_parent().remove_child(fx)
	fx.free()


## fix-hud R1: his bubble's drawn extent (glyph disc + pips on the left, the cloud's lobe on the right) stays on
## screen — the clamp numbers match what FxThoughtBubble draws at BUBBLE_SCALE.
func test_the_bubble_clamp_covers_its_drawn_extent() -> void:
	var s := Overlays3D.BUBBLE_SCALE
	assert_almost_eq(Overlays3D.BUBBLE_LEFT_PX, 115.0 * s, 1.0, "glyph disc: 115 local units left")
	assert_almost_eq(Overlays3D.BUBBLE_RIGHT_PX, 95.0 * s, 1.0, "cloud lobe: 95 local units right")
	assert_ge(Overlays3D.EDGE_PX, 8.0, "kept 8 px from the edge")
	assert_almost_eq(Overlays3D.BUBBLE_FLIP_LEFT_PX, 55.0 * s, 1.0, "flipped: the cloud's left lobe 55 units left")
	assert_almost_eq(Overlays3D.BUBBLE_FLIP_RIGHT_PX, 155.0 * s, 1.0, "flipped: the glyph disc 155 units right")


## Q-G6: the near-miss beat is timed off his hunt running out (the relief cue): he peers at her gap first, her eyes
## duck after, and nothing happens while he is not hunting.
func test_the_near_miss_beat_is_timed_off_the_hunt() -> void:
	var b := _actor("ROUTINE")
	b.activity = "hunt"
	b.activity_len = 600
	b.activity_t = 400
	assert_eq(CueStager3D.hunt_left(b), 200, "200 ticks of hunt left")
	assert_gt(CueStager3D.RELIEF_GAZE_LEFT, CueStager3D.RELIEF_DUCK_LEFT, "he turns to the gap before her eyes duck")
	b.activity_t = 700
	assert_eq(CueStager3D.hunt_left(b), 0, "never negative")
	b.activity = "warmup"
	assert_gt(CueStager3D.hunt_left(b), 100000, "not hunting: no beat")


## D17: a clip's sidecar is parsed under the curtain (WorldView3D.warm_clips -> CharacterView3D.warm_sidecar), into
## the one JSON cache CharacterView3D (stage / keeps) and GagStager3D (events) both read — never first in PLAY.
func test_warm_sidecar_fills_the_shared_json_cache() -> void:
	var cid := "hush/rig_high"
	var path := ClipMap.sidecar_path(cid)
	if not assert_true(path != "" and FileAccess.file_exists(path), "the sidecar exists: %s" % path):
		return
	CharacterView3D._stage_cache.erase(cid)
	ViewKit._json_cache.erase(path)
	CharacterView3D.warm_sidecar(cid)
	assert_true(ViewKit._json_cache.has(path), "parsed once into ViewKit's cache")
	assert_true(CharacterView3D._stage_cache.has(cid), "and its stage / keeps bits cached")
