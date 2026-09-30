## The 3D view's pure rules (brief r3d-view3d §4.3–§4.8): lane placement + cheat-out, the rig clip's authored
## stage, looks / body slots, the N1 glow, C8's two window modes, the entry lead, the pooled decals and particles,
## the ClipMap 3D format (`rig:<prank>` locked to rig_pm, `bands.mid.clip` last resort) and SliceClips.build3d.
extends TestBase


func after_each() -> void:
	ClipMap.map_override3d.clear()
	ClipMap.fixture_clips3d.clear()
	CharacterView3D._stage_cache.clear()


func _actor(state: String = "ROUTINE") -> ViewSnapshot.Actor:
	var a := ViewSnapshot.Actor.new()
	a.present = true
	a.state = state
	a.facing = 1
	return a


# --- placement ---------------------------------------------------------------------------------------------

func test_hush_walks_the_lane_and_cheats_less_when_moving() -> void:
	var a := _actor("SNEAKING")
	var p := CharacterView3D.placement_for("hush", a, {}, {}, NAN)
	assert_almost_eq(float(p["z"]), View3DConst.LANE_Z, 1e-6, "lane z −1.0")
	assert_almost_eq(float(p["cheat"]), View3DConst.CHEAT_IDLE, 1e-6, "standing: 35°")
	a.moving = true
	p = CharacterView3D.placement_for("hush", a, {}, {}, NAN)
	assert_almost_eq(float(p["cheat"]), View3DConst.CHEAT_WALK, 1e-6, "walking: 20°")
	assert_true(is_nan(float(p["yaw"])))


func test_rigging_goes_to_reach_pos_never_deeper_than_minus_1_6_and_cheats_at_most_10() -> void:
	var a := _actor("RIGGING")
	a.rig_prank = "achoo_ria"
	var p := CharacterView3D.placement_for("hush", a, {"z": -1.55, "dx": 0.12, "step": "stool:kitchen_stool"}, {}, NAN)
	assert_almost_eq(float(p["z"]), -1.55, 1e-6, "reach_pos z")
	assert_almost_eq(float(p["dx"]), 0.12, 1e-6, "reach_pos dx (view-only)")
	assert_le(float(p["cheat"]), View3DConst.CHEAT_REACH_MAX, "R5d: body cheat ≤ 10° while reaching")
	p = CharacterView3D.placement_for("hush", a, {"z": -1.95}, {}, NAN)
	assert_almost_eq(float(p["z"]), View3DConst.REACH_Z_MIN, 1e-6, "clamped at −1.6")
	p = CharacterView3D.placement_for("hush", a, {}, {}, NAN)
	assert_almost_eq(float(p["z"]), View3DConst.REACH_Z, 1e-6, "no reach_pos: the default −1.6")


func test_hidden_hush_sits_at_the_spot_occupant_depth() -> void:
	var a := _actor("HIDDEN")
	a.hidden_spot = "kitchen_pantry_curtain"
	var p := CharacterView3D.placement_for("hush", a, {}, {}, -1.8)
	assert_almost_eq(float(p["z"]), -1.8, 1e-6)
	p = CharacterView3D.placement_for("hush", a, {}, {}, NAN)
	assert_almost_eq(float(p["z"]), View3DConst.LANE_Z, 1e-6, "no occupant z: the lane")


func test_bellows_stands_at_his_station_depth_and_yaw_but_reacts_on_the_lane() -> void:
	var a := _actor("ROUTINE")
	a.activity = "tea"
	var st := {"bellows_z": -1.4, "yaw": -70.0}
	var p := CharacterView3D.placement_for("bellows", a, {}, st, NAN)
	assert_almost_eq(float(p["z"]), View3DConst.BELLOWS_STATION_Z, 1e-6, "station z −1.4")
	assert_almost_eq(float(p["yaw"]), -70.0, 1e-6, "the station's yaw")
	a.moving = true
	p = CharacterView3D.placement_for("bellows", a, {}, st, NAN)
	assert_almost_eq(float(p["z"]), View3DConst.LANE_Z, 1e-6, "walking: the lane")
	a.moving = false
	a.reacting = true
	p = CharacterView3D.placement_for("bellows", a, {}, st, NAN)
	assert_almost_eq(float(p["z"]), View3DConst.LANE_Z, 1e-6, "reacting: the lane (travel handles landings)")
	a.reacting = false
	a.oneshot = "face_to_face"
	p = CharacterView3D.placement_for("bellows", a, {}, {}, NAN)
	assert_almost_eq(float(p["cheat"]), View3DConst.CHEAT_FACE_TO_FACE, 1e-6, "face to face: 5°")


func test_rig_clip_plays_with_its_authored_facing_and_cheat_at_most_10() -> void:
	# r3d-anim: a rig_* sidecar's "stage" {facing, cheat_deg}; the view plays it that way
	CharacterView3D._stage_cache["hush/rig_test"] = {"x": 14.9, "z": -1.55, "facing": -1, "cheat_deg": 25.0}
	var v := CharacterView3D.rig_stage("hush/rig_test", 1, 35.0)
	assert_eq(v.x, -1, "the prop's side")
	assert_eq(v.y, 10, "cheat clamped to 10°")
	CharacterView3D._stage_cache["hush/rig_low"] = {"facing": 1, "cheat_deg": 4.0}
	v = CharacterView3D.rig_stage("hush/rig_low", -1, 10.0)
	assert_eq(v, Vector2i(1, 4))
	CharacterView3D._stage_cache["hush/rig_plain"] = {}
	v = CharacterView3D.rig_stage("hush/rig_plain", -1, 8.0)
	assert_eq(v, Vector2i(-1, 8), "no stage block: unchanged")
	assert_eq(CharacterView3D.clip_stage(CharacterView3D.STATIC_CLIP), {}, "the static pose has none")


# --- looks + body slots ------------------------------------------------------------------------------------

func test_residue_looks_and_body_slots() -> void:
	var looks := CharacterView3D.rig_looks(PackedStringArray(["FRAZZLED"]), PackedStringArray(), true, "")
	assert_has(looks, "FRAZZLED")
	assert_has(looks, "BLINDED", "FRAZZLED + blind → BLINDED")
	looks = CharacterView3D.rig_looks(PackedStringArray(["COSTUME"]), PackedStringArray(), false, "tutu")
	assert_has(looks, "COSTUME:tutu")
	assert_eq(CharacterView3D.residue_slots(PackedStringArray(["FRAZZLED"]), true), {"bouffant": "flipped"})
	assert_eq(CharacterView3D.residue_slots(PackedStringArray(["FRAZZLED"]), false), {"bouffant": "frazzled"})
	assert_eq(CharacterView3D.residue_slots(PackedStringArray(["SOAKED"]), false), {"bouffant": "wet"})
	assert_eq(CharacterView3D.residue_slots(PackedStringArray(["FLOURED"]), false), {"bouffant": "floured"})
	assert_eq(CharacterView3D.residue_slots(PackedStringArray(), false), {})


# --- N1 glow + active spot ---------------------------------------------------------------------------------

func test_n1_glow_everything_live_in_her_room_and_the_active_spot_twice() -> void:
	var f := WorldView3D.glow_amp_for
	assert_eq(f.call(&"prank", true, true, false, false, false, false, false), View3DConst.GLOW_NORMAL, "live, her room")
	assert_eq(f.call(&"prank", false, true, false, false, false, false, false), View3DConst.GLOW_OFF, "another room: off")
	assert_eq(f.call(&"prank", true, true, false, false, false, false, true), View3DConst.GLOW_ACTIVE, "active spot 2×")
	assert_eq(f.call(&"prank", true, true, true, false, false, false, false), View3DConst.GLOW_OFF, "armed: the tag shows instead")
	assert_eq(f.call(&"prank", true, true, true, false, false, false, true), View3DConst.GLOW_ACTIVE, "armed + his next activity")
	assert_eq(f.call(&"prank", true, true, false, true, false, false, true), View3DConst.GLOW_OFF, "spent: off")
	assert_eq(f.call(&"hide", true, true, false, false, true, false, false), View3DConst.GLOW_OFF, "hidden: off")
	assert_eq(f.call(&"hide", true, false, false, false, false, false, false), View3DConst.GLOW_OFF, "disabled: off")
	assert_eq(f.call(&"exit", true, true, false, false, false, false, false), View3DConst.GLOW_OFF, "exit before ★")
	assert_eq(f.call(&"exit", true, true, false, false, false, true, false), View3DConst.GLOW_NORMAL, "exit after ★")
	assert_eq(f.call(&"door", true, true, false, false, false, true, false), View3DConst.GLOW_OFF, "doors are architecture")


# --- C8 window modes ---------------------------------------------------------------------------------------

func test_window_never_while_he_is_on_screen_and_lean_closes_adjacency() -> void:
	var w := PipView3D.want_window
	assert_false(w.call(true, true, &"room", false, false), "on screen: never")
	assert_false(w.call(false, false, &"", false, false), "the sim says no")
	assert_true(w.call(false, true, &"adjacent", false, false), "sim mode: adjacency opens it")
	assert_false(w.call(false, true, &"adjacent", true, false), "lean: adjacency alone → the edge badge")
	assert_true(w.call(false, true, &"adjacent", true, true), "lean: a reaction / emote-less gag opens it")
	assert_true(w.call(false, true, &"room", true, false), "lean: other reasons still open it")


func test_share_inside_is_the_on_screen_fraction() -> void:
	var s := Rect2(0, 0, 2400, 1080)
	assert_almost_eq(WorldView3D.share_inside(Rect2(100, 100, 200, 400), s), 1.0, 1e-6)
	assert_almost_eq(WorldView3D.share_inside(Rect2(2300, 100, 200, 400), s), 0.5, 1e-6)
	assert_almost_eq(WorldView3D.share_inside(Rect2(2500, 100, 200, 400), s), 0.0, 1e-6)
	assert_almost_eq(WorldView3D.share_inside(Rect2(), s), 0.0, 1e-6)


func test_entry_lead_adds_the_doorway_pause() -> void:
	assert_eq(WorldView3D.entry_lead(30, {"pause": 45}), 75)
	assert_eq(WorldView3D.entry_lead(30, {"doorway_pause": 10}), 40)
	assert_eq(WorldView3D.entry_lead(200, {}), 200, "a long eta needs no extra pause")
	assert_eq(WorldView3D.entry_lead(10, {}), maxi(10, WorldView3D.ENTRY_LEAD_TICKS), "short eta: at least the lead")


# --- pooled decals + particles -----------------------------------------------------------------------------

func test_decals_are_pooled_and_expire() -> void:
	var d := Decals3D.new()
	var n0 := d.get_child_count()
	for i in 20:
		d.ring(Vector3(float(i), 0, -1), 2.5, Color.WHITE, 0.8)
	assert_eq(d.active_rings(), Decals3D.RING_POOL, "20 rings → the pool of 8")
	for i in 10:
		d.pop(Vector3(1, 0, -1), i % 2 == 0)
		d.pin(Vector3(2, 0, -1))
	d.pool_on("kitchen_honey", Vector3(15, 0, -1.2))
	d.pool_on("kitchen_honey", Vector3(15, 0, -1.2))
	d.pool_on("kitchen_kettle", Vector3(17, 0, -1.2))
	d.pool_on("kitchen_sink_tap", Vector3(18, 0, -1.2))
	assert_true(d.pool_visible("kitchen_honey"))
	assert_true(d.pool_visible("kitchen_kettle"))
	assert_false(d.pool_visible("kitchen_sink_tap"), "two pools at most")
	assert_eq(d.get_child_count(), n0, "nothing allocated after _init")
	for i in 60:
		d.advance(1.0 / 60.0)
	assert_eq(d.active_rings(), 0, "rings fade within 0.8 s")
	d.destination(Vector3(16, 0, -1), Vector3(13, 0, -1))
	assert_true(d.destination_visible())
	d.destination_done()
	for i in 30:
		d.advance(1.0 / 60.0)
	assert_false(d.destination_visible(), "the ring pops away on arrival")
	d.ghost_ring(Vector3(15, 0, -1))
	assert_true(d.ghost_visible())
	d.stare_strip(true, 10.0, -1.0, 2.5, 1.0, 0.0, false)
	assert_true(d.strip_visible())
	d.clear()
	assert_false(d.ghost_visible())
	assert_false(d.strip_visible())
	assert_false(d.pool_visible("kitchen_honey"))
	d.free()


func test_particles_reuse_eight_emitters() -> void:
	var fx := Fx3D.new()
	for i in 20:
		fx.burst(["dust", "pepper", "sparkles", "no_such_kind"][i % 4], Vector3(float(i), 1, -1))
	assert_eq(fx.get_child_count(), Fx3D.MAX_EMITTERS)
	assert_le(fx.live_emitters(), Fx3D.MAX_EMITTERS)
	assert_eq(fx.bursts, 20)
	fx.clear()
	assert_eq(fx.live_emitters(), 0)
	fx.free()


func test_materials_register_for_the_warm_pass() -> void:
	var before := MaterialWarm3D.total_registered()
	var d := Decals3D.new()
	assert_gt(MaterialWarm3D.total_registered(), before, "decal materials registered")
	var probe := ShaderMaterial.new()
	probe.shader = load(View3DConst.SH_DECAL)
	assert_true(MaterialWarm3D.has(probe, &"decal"), "the decal shader's warm key")
	assert_gt(MaterialWarm3D.count(), 0)
	d.free()


# --- ClipMap 3D format -------------------------------------------------------------------------------------

func _ctx3d(actions: Dictionary) -> ClipMap.Ctx:
	var c := ClipMap.Ctx.new()
	c.rig = "hush"
	c.format3d = true
	c.exists_fn = ClipMap.clip_exists3d
	c.len_fn = ClipMap.clip_length3d
	c.rig_actions = actions
	return c


## Fictional ids (real sidecars land in data/anim/hush3d/ while this suite runs).
const ACTIONS := {"tiers": {"q": 48, "s": 90, "b": 150},
	"bands": {"mid": {"clip": "hush/rig_zz_mid"}, "high": {"clip": "hush/rig_zz_high"}},
	"pranks": {"zz_own": {"tier": "s", "band": "high", "clip": "hush/rig_zz_own"},
		"zz_band": {"tier": "q", "band": "mid", "clip": null}}}


func test_rig_prank_row_is_frame_locked_to_rig_pm() -> void:
	ClipMap.fixture_clips3d = {"hush/rig_zz_own": 91, "hush/rig_zz_mid": 49, "hush/rig_zz_high": 49, "hush/zz_idle": 60}
	var map := {"idle": "hush/zz_idle"}
	ClipMap.add_rig_rows(map, ACTIONS)
	assert_eq(ClipMap.clip_of(map["rig:zz_own"]), "hush/rig_zz_own", "its own clip")
	assert_eq(ClipMap.clip_of(map["rig:zz_band"]), "hush/rig_zz_mid", "no own clip → its band's")
	var a := _actor("RIGGING")
	a.rig_prank = "zz_own"
	a.rig_pm = 500
	var p := ClipMap.Pick.new()
	ClipMap.resolve(map, a, 0.0, p, _ctx3d(ACTIONS))
	assert_eq(p.clip, "hush/rig_zz_own")
	assert_true(p.external, "locked to the sim")
	assert_almost_eq(p.frame, 45.0, 1e-4, "rig_pm 500 ‰ of 91 frames")
	assert_eq(p.wanted, "", "no fallback")


func test_missing_rig_clip_falls_back_to_band_mid_and_is_counted() -> void:
	ClipMap.fixture_clips3d = {"hush/rig_zz_mid": 49, "hush/zz_idle": 60}
	var map := {"idle": "hush/zz_idle"}
	ClipMap.add_rig_rows(map, ACTIONS)
	var a := _actor("RIGGING")
	a.rig_prank = "zz_own"
	a.rig_pm = 1000
	var p := ClipMap.Pick.new()
	ClipMap.resolve(map, a, 0.0, p, _ctx3d(ACTIONS))
	assert_eq(p.clip, "hush/rig_zz_mid", "bands.mid.clip = the last resort")
	assert_eq(p.wanted, "hush/rig_zz_own", "the wanted clip is recorded (a fallback count)")
	assert_almost_eq(p.frame, 48.0, 1e-4)


func test_3d_never_resolves_the_2d_rigging_tiers() -> void:
	ClipMap.fixture_clips3d = {"hush/rig_zz_mid": 49, "hush/tinker_q": 40, "hush/tinker": 40}
	var map := {"rigging@q": "hush/tinker_q", "state:rigging": "hush/tinker"}
	var a := _actor("RIGGING")
	a.rig_prank = ""
	a.rig_pm = 0
	var p := ClipMap.Pick.new()
	ClipMap.resolve(map, a, 0.0, p, _ctx3d(ACTIONS))
	assert_eq(p.clip, "hush/rig_zz_mid", "no rigging@ / state:rigging in 3D")


func test_real_rig_actions_give_every_prank_a_clip() -> void:
	var ra := ClipMap.rig_actions()
	if ra.is_empty():
		skip("rig_actions.json not landed")
		return
	var pr: Dictionary = ra.get("pranks", {})
	assert_gt(pr.size(), 0)
	for pk in pr:
		assert_ne(ClipMap.rig_clip_of(ra, String(pk)), "", "%s has a rig clip (own or band)" % pk)
	assert_ne(ClipMap.band_mid_clip(ra), "", "bands.mid.clip exists")


func test_slice_clips_build3d_manifest() -> void:
	var rows := SliceClips.build3d(PackedStringArray(["g0_sneeze", "p00_curtain_up"]))
	assert_between(float(rows.size()), 55.0, 90.0, "the g0 + P00 3D manifest (70 at landing)")
	var seen := {}
	var rig_rows := 0
	for r in rows:
		var clip := str(r["clip"])
		assert_false(seen.has(clip), "no duplicate %s" % clip)
		seen[clip] = true
		assert_false(clip.begins_with("figgis/"), "no Figgis rows in 3D (a HUD chip)")
		for k in str(r.get("keys", "")).split(", ", false):
			assert_false(str(k).begins_with("rigging@") or str(k) == "state:rigging", "no 2D rigging rows: %s" % k)
			if str(k).begins_with("rig:"):
				rig_rows += 1
	assert_gt(rig_rows, 0, "rig:<prank> rows present")
	print("[test_view3d_rules] build3d rows %d (rig rows %d)" % [rows.size(), rig_rows])


# --- caught / recorder ------------------------------------------------------------------------------------

func test_caught_phases_and_the_braces_attach() -> void:
	assert_eq(CaughtStager3D.phase_of("caught:lecture"), "lecture")
	assert_eq(CaughtStager3D.phase_of("caught:doorstep"), "doorstep")
	assert_eq(CaughtStager3D.phase_of("bump"), "")
	# her braces socket lands on his grip: her origin moves by (grip − braces)
	var o := CaughtStager3D.attach_origin(Vector3(10.4, 1.3, -1.0), Vector3(10.0, 0.9, -1.1), Vector3(10.0, 0.0, -1.0))
	assert_almost_eq(o.x, 10.4, 1e-5)
	assert_almost_eq(o.y, 0.4, 1e-5)
	assert_almost_eq(o.z, -0.9, 1e-5)


func test_moment_recorder_keeps_windows_without_allocating() -> void:
	var r := MomentRecorder3D.new()
	r.setup(null)
	var snap := ViewSnapshot.new()
	for t in 500:
		snap.tick = t
		r.record(snap)
	assert_eq(r.count(), MomentRecorder3D.CAP, "the ring holds CAP frames")
	assert_eq(r.last_tick(), 499)
	assert_eq(r.ring_frame(0).tick, 100, "the oldest frame")
	var id := r.keep(300, 360, "busted")
	var m := r.moment(id)
	assert_eq(m.count(), 61, "ticks 300…360")
	assert_false(m.open)
	var id2 := r.keep(490, 520, "gag:achoo_ria", 40)
	var m2 := r.moment(id2)
	assert_true(m2.open, "a window into the future stays open")
	for t2 in range(500, 530):
		snap.tick = t2
		r.record(snap)
	assert_false(m2.open)
	assert_eq(m2.count(), 31)
	assert_eq(m2.frame_at_tick(505).tick, 505)
	for k in 10:
		r.keep(0, 10, "x%d" % k, k)
	assert_eq(r.kept(), MomentRecorder3D.POOL, "8 pooled Moments; the lowest applause is evicted")
	r.clear()
	assert_eq(r.count(), 0)
	assert_eq(r.kept(), 0)


func test_captions_sit_above_or_beside_the_head_never_over_the_face() -> void:
	var screen := Rect2(40, 0, 2320, 1040)
	var box := Vector2(620, 130)
	# room above the head under the HUD band: centred above it
	var head := Rect2(1100, 520, 180, 200)
	var a := Overlays3D.caption_anchor(head, box, screen, 212.0)
	assert_almost_eq(a.x, head.get_center().x, 0.5)
	assert_le(a.y, head.position.y, "the text's bottom above the head")
	assert_ge(a.y - box.y, 212.0, "below the HUD band")
	# head up near the band (a punch-in): beside it, the text box clear of the head rect
	for hx in [300.0, 1100.0, 2000.0]:
		var hd := Rect2(hx, 260, 220, 260)
		var b := Overlays3D.caption_anchor(hd, box, screen, 212.0)
		var r := Rect2(b - Vector2(box.x * 0.5, box.y), box)
		assert_false(r.intersects(hd), "beside the head at x %.0f, not over it" % hx)
		assert_ge(r.position.y, 212.0 - 0.5, "below the HUD band")
		assert_true(screen.encloses(r), "inside the screen at x %.0f" % hx)


class FakeSet extends RefCounted:
	var calls: PackedStringArray = PackedStringArray()

	func lend(id: String, _to: Node3D, frames: int = 6) -> Node3D:
		calls.append("lend %s %d" % [id, frames])
		return null

	func return_home(id: String, frames: int = 6) -> void:
		calls.append("home %s %d" % [id, frames])


func test_hand_offs_lend_and_a_clip_switch_returns_what_it_does_not_keep() -> void:
	var wv := WorldView3D.new()
	var bv := CharacterView3D.new()
	var fs := FakeSet.new()
	wv.set3d = fs
	wv.bellows_view = bv
	bv._clip = "bellows/act_tea"
	wv._return_on_switch("bellows", bv)
	wv._handoff("bellows", "lend", "kitchen_kettle", "grip_r", 6)
	wv._handoff("bellows", "lend", "kitchen_honey", "grip_l", 4)
	assert_eq(wv.lent_pieces("bellows").size(), 2)
	wv._handoff("bellows", "return", "kitchen_kettle", "grip_r", 5)
	assert_eq(wv.lent_pieces("bellows"), PackedStringArray(["kitchen_honey"]), "home on its named frame")
	wv._handoff("bellows", "lend", "kitchen_kettle", "grip_r", 6)
	# the next clip keeps the jar (sidecar `keeps`), so only the kettle goes home
	CharacterView3D._stage_cache["bellows/act_tea_sip"] = {"keeps": PackedStringArray(["kitchen_honey"])}
	bv._clip = "bellows/act_tea_sip"
	wv._return_on_switch("bellows", bv)
	assert_eq(wv.lent_pieces("bellows"), PackedStringArray(["kitchen_honey"]))
	assert_has(fs.calls, "home kitchen_kettle 6")
	# a switch to a clip that keeps nothing returns the rest
	CharacterView3D._stage_cache["bellows/loco_walk"] = {"keeps": PackedStringArray()}
	bv._clip = "bellows/loco_walk"
	wv._return_on_switch("bellows", bv)
	assert_eq(wv.lent_pieces("bellows").size(), 0)
	assert_has(fs.calls, "home kitchen_honey 6")
	bv.free()
	wv.free()


func test_a_caption_keeps_its_side_while_it_fits() -> void:
	var screen := Rect2(40, 0, 2320, 1040)
	var box := Vector2(620, 130)
	# the head near the band, more room on the right: it goes right …
	var r := Overlays3D.caption_place(Rect2(900, 260, 220, 260), box, screen, 212.0)
	assert_eq(int(r.z), 3, "right (more room)")
	# … and stays right as the head drifts right, even once the left has more room
	r = Overlays3D.caption_place(Rect2(1400, 260, 220, 260), box, screen, 212.0, int(r.z))
	assert_eq(int(r.z), 3, "kept right")
	# only when the right no longer fits does it switch
	r = Overlays3D.caption_place(Rect2(1900, 260, 220, 260), box, screen, 212.0, int(r.z))
	assert_eq(int(r.z), 2, "switched left when the right ran out")
