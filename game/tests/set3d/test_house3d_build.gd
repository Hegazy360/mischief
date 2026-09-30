## House3D / Prop3D / HideSpot3D at runtime (brief r3d-sets §5): every slice Night builds headless without errors
## within the budget, hit boxes, the collision check (no capsule at a reach_pos, a station or on the lane inside any
## furniture / prop), lend / return_home, the Prop3D API (idempotent), the eye card, decor, room light.
extends TestBase

const SLICE: Array[String] = ["p00_curtain_up", "g0_sneeze", "n01_throat_tea", "n02_something_fishy"]

var db: ContentDB = null


func before_each() -> void:
	if db == null:
		db = ContentDB.load_dir("res://data")


func _build(ep_id: String) -> House3D:
	var h := House3D.new()
	tree.root.add_child(h)
	h.build(SetList.for_episode(db, db.episodes[ep_id]), {}, db)
	return h


func test_every_slice_night_builds() -> void:
	for ep_id in SLICE:
		var h := _build(ep_id)
		assert_eq(h.rooms_built().size(), h.result.rooms_built().size(), "%s rooms" % ep_id)
		for id in h.result.live.keys():
			if String(h.result.live[id]) in ["rig", "take", "hide"]:
				assert_true(h.prop(id) != null, "%s: live %s has a Prop3D" % [ep_id, id])
				assert_true(h.prop(id).live, "%s: %s is live (ink + halo)" % [ep_id, id])
		for id in h.result.furniture:
			var p := h.prop(id)
			if p != null:
				assert_false(p.live and p.hotspot_id == id, "%s: furniture-role %s has no glow" % [ep_id, id])
		var cost := h.build_ms / maxf(1.0, TestBase.cpu_load_scale())
		assert_le(cost, 150.0, "%s: build %.1f ms (≤ 150 ms, load-scaled)" % [ep_id, h.build_ms])
		h.free()


func test_collisions_none_on_every_slice_night() -> void:
	for ep_id in SLICE:
		var h := _build(ep_id)
		var rep := SetCheck.run(h)
		assert_true((rep["collisions"] as Array).is_empty(), "%s collisions: %s" % [ep_id, JSON.stringify(rep["collisions"])])
		for e in rep["errors"]:
			assert_false(String(e).begins_with("collision"), "%s %s" % [ep_id, e])
		if ep_id in ["p00_curtain_up", "g0_sneeze"]:
			assert_true((rep["errors"] as Array).is_empty(), "%s errors: %s" % [ep_id, JSON.stringify(rep["errors"])])
		h.free()


func test_hotspot_box_is_rect_plus_offset_unless_hit_box() -> void:
	var h := _build("n01_throat_tea")
	var h3 := h.house3d
	for id in h.result.live.keys():
		var hd := db.house.hotspot(id)
		var e: Dictionary = (h3["hotspots"] as Dictionary).get(id, {})
		var box := h.hotspot_box(id)
		if e.get("hit_box", null) != null:
			var hb: Array = e["hit_box"]
			assert_almost_eq(box.position.x, float(hb[0]), 0.001, "%s hit_box x0" % id)
			assert_almost_eq(box.end.y, float(hb[3]), 0.001, "%s hit_box y1" % id)
		else:
			var r := SetGeo.rect_m(hd.rect)
			var vo := SetGeo.vec2(e.get("visual_offset", null))
			assert_almost_eq(box.position.x, r.position.x + vo.x, 0.001, "%s x" % id)
			assert_almost_eq(box.position.y, r.position.y + vo.y, 0.001, "%s y" % id)
			assert_almost_eq(box.size.x, r.size.x, 0.001, "%s w" % id)
	h.free()


func test_preview_band_free_of_dressing() -> void:
	for ep_id in SLICE:
		var h := _build(ep_id)
		for p in h.props():
			if not p.live or p.entry.get("preview_anchor", null) == null:
				continue
			var vis := p.home_aabb()
			var band := AABB(Vector3(vis.position.x, vis.end.y, -2.45), Vector3(vis.size.x, 0.6, 1.0))
			for did in h.result.dressing:
				var d := h.decor(did) as Prop3D
				if d == null or d.room != p.room:
					continue
				var db_ := d.home_aabb()
				assert_false(band.intersects(db_), "%s: dressing %s inside the 0.6 m preview band of %s" % [ep_id, did, p.hotspot_id])
		h.free()


func test_live_stacks_keep_a_gap() -> void:
	# stacks live in the same Night keep ≥ 0.10 m between their hit boxes (≥ 24 px at the back of the set)
	for ep_id in SLICE:
		var h := _build(ep_id)
		var live_ids: Array = h.result.live.keys()
		for i in live_ids.size():
			for j in range(i + 1, live_ids.size()):
				var a := String(live_ids[i])
				var b := String(live_ids[j])
				if not (String(h.result.live[a]) in ["rig", "take", "hide"] and String(h.result.live[b]) in ["rig", "take", "hide"]):
					continue
				if h.result.room_of(a) != h.result.room_of(b):
					continue
				var ba := h.hotspot_box(a)
				var bb := h.hotspot_box(b)
				var gx := maxf(bb.position.x - ba.end.x, ba.position.x - bb.end.x)
				var gy := maxf(bb.position.y - ba.end.y, ba.position.y - bb.end.y)
				assert_ge(maxf(gx, gy), 0.1 - 1e-4, "%s: hit boxes of %s and %s ≥ 0.10 m apart (gap x %.2f y %.2f)" % [ep_id, a, b, gx, gy])
		h.free()


func test_lend_and_return_keep_world_transforms_and_state() -> void:
	var h := _build("p00_curtain_up")
	var socket := Node3D.new()
	tree.root.add_child(socket)
	socket.global_position = Vector3(14.7, 1.1, -1.3)
	var kettle := h.prop("kitchen_kettle")
	if not assert_true(kettle != null, "the kettle is on stage in P00 (tea station)"):
		return
	var home := kettle.global_transform
	var honey := h.prop("kitchen_honey")
	honey.set_state(&"armed")
	honey.show_tag(true, false)
	var got := h.lend("set:kitchen_kettle", socket, 6)
	assert_true(got == kettle)
	assert_true(kettle.global_transform.origin.is_equal_approx(home.origin), "no pop on the first frame")
	for i in 8:
		kettle.advance(1.0 / 60.0)
	assert_true(kettle.global_transform.origin.distance_to(socket.global_position) < 0.001, "in the socket after 6 frames")
	h.lend("set:kitchen_honey", socket, 6)
	for i in 8:
		honey.advance(1.0 / 60.0)
	assert_eq(honey.state(), &"armed", "the lent jar keeps its armed look")
	assert_true(honey.tag_shown(), "and its tag")
	h.return_home("set:kitchen_kettle", 6)
	for i in 8:
		kettle.advance(1.0 / 60.0)
	assert_true(kettle.global_transform.origin.distance_to(home.origin) < 0.001, "home again")
	assert_true(kettle.get_parent() == h, "re-parented home")
	h.return_all()
	for i in 8:
		honey.advance(1.0 / 60.0)
	assert_false(honey.is_lent())
	socket.free()
	h.free()


func test_prop3d_api_is_idempotent() -> void:
	var h := _build("p00_curtain_up")
	var p := h.prop("kitchen_honey")
	p.set_state(&"armed")
	p.set_state(&"armed")
	assert_eq(p.state(), &"armed")
	p.set_rig_progress(0.5)
	assert_almost_eq(p.rig_progress(), 0.5, 1e-6)
	p.set_rig_progress(2.0)
	assert_almost_eq(p.rig_progress(), 1.0, 1e-6, "clamped")
	p.set_glow(Color("#FFC838"), 1.0)
	p.set_glow(Color("#FFC838"), 1.0)
	assert_almost_eq(p.glow_amp(), 1.0, 1e-6)
	p.show_tag(true, true)
	p.show_tag(true, true)
	assert_true(p.tag_shown())
	p.tag_wiggle()
	for i in 60:
		p.advance(1.0 / 60.0)
	p.set_state(&"spent")
	assert_almost_eq(p.glow_amp(), 0.0, 1e-6, "spent: glow off")
	p.show_tag(false)
	assert_false(p.tag_shown())
	p.set_part("pepper_pot", false)
	assert_false(p.part_visible("pepper_pot"))
	p.set_part("pepper_pot", true)
	assert_true(p.part_visible("pepper_pot"))
	p.play("lid_flip")
	for i in 40:
		p.advance(1.0 / 60.0)
	assert_eq(p.playing(), "", "the trigger anim finished")
	var kettle := h.prop("kitchen_kettle")
	kettle.set_glow(Color("#FFC838"), 1.0)
	assert_almost_eq(kettle.glow_amp(), 0.0, 1e-6, "a furniture-role hotspot never glows")
	h.free()


func test_hide_spot_eyes() -> void:
	var h := _build("p00_curtain_up")
	var hs := h.prop("kitchen_pantry_curtain") as HideSpot3D
	if not assert_true(hs != null, "the pantry curtain is a HideSpot3D"):
		return
	assert_false(hs.eyes_visible())
	hs.set_occupied(true)
	hs.set_occupied(true)
	assert_true(hs.eyes_visible())
	hs.eyes_look(Vector2(1.0, 0.0))
	assert_almost_eq(hs.look_dir().x, 1.0, 1e-6)
	hs.eyes_blink()
	for i in 20:
		hs.advance(1.0 / 60.0)
	hs.set_occupied(false)
	assert_false(hs.eyes_visible())
	var eyes := hs.anchor(&"eyes")
	assert_true(h.hotspot_box("kitchen_pantry_curtain").grow(0.01).has_point(Vector3(eyes.x, eyes.y, h.hotspot_box("kitchen_pantry_curtain").get_center().z)),
		"the eye card sits inside the hiding spot's box")
	h.free()


func test_decor_and_landings() -> void:
	var h := _build("p00_curtain_up")
	assert_true(h.decor("kitchen_stool") != null, "the stool by its decor id")
	h.set_decor_visible("kitchen_stool", false)
	assert_false(h.decor("kitchen_stool").visible)
	h.set_decor_visible("kitchen_stool", true)
	h.play_decor("kitchen_stool", "wobble")
	assert_eq((h.decor("kitchen_stool") as Prop3D).playing(), "wobble")
	assert_true(h.decor("parlour_vase") != null, "the vase (laugh_vase cue prop)")
	h.play_decor("parlour_vase", "smash")
	assert_false(h.decor("parlour_vase").visible)
	assert_true(h.decor("parlour_vase_smashed") != null and h.decor("parlour_vase_smashed").visible, "the smashed vase shows")
	var sink := h.landing_box("kitchen.sink")
	assert_true(sink.size.x > 0.3, "the sink basin box")
	var lp := h.landing_point("kitchen.sink")
	assert_true(sink.has_point(lp["pos"]), "the sink landing point is inside its box")
	var rp := h.reach_pos("kitchen_honey")
	assert_eq(String(rp["step"]), "stool:kitchen_stool")
	assert_true(absf(float(rp["x"]) - 15.0) <= 0.23, "Hush stands on the stool's seat (15.0 ± 0.23)")
	assert_true(h.floor_band("kitchen").size.x > 5.0)
	assert_gt(h.furniture_boxes().size(), 3, "furniture boxes")
	h.free()


func test_room_light_tweens() -> void:
	var h := _build("p00_curtain_up")
	assert_almost_eq(h.room_light("hall").x, 0.3, 1e-4, "backstage hall at 0.3")
	h.set_room_light("parlour", 0.78, 0.4)
	h.advance(0.2)
	var mid := h.room_light("parlour")
	assert_true(mid.x < 1.0 and mid.x > 0.78, "mid-tween %.3f" % mid.x)
	h.advance(0.3)
	assert_almost_eq(h.room_light("parlour").x, 0.78, 1e-4)
	assert_almost_eq(h.room_light("parlour").y, 0.4, 1e-4)
	h.set_room_light("hall", 0.9, 0.0)
	h.advance(0.5)
	assert_almost_eq(h.room_light("hall").x, 0.9, 1e-4, "a backstage room holding Bellows lit at 0.9")
	h.free()


func test_one_material_per_room_set_when_glb() -> void:
	var h := _build("p00_curtain_up")
	var any := false
	for rid in h.rooms_built():
		var shell := h.room_shell(rid)
		if shell.from_glb():
			any = true
			assert_eq(h.room_material_count(rid), 1, "%s: one set material" % rid)
	if not any:
		skip("room .glb sets not built yet (greybox) — r3d-sets P1")
	h.free()


func test_static_draws_per_room_within_budget() -> void:
	# brief §7: ≤ 3 static draw calls per room (the arch + tonight's static pieces merged into one mesh)
	var any := false
	for ep_id in ["p00_curtain_up", "g0_sneeze", "n01_throat_tea", "n02_something_fishy"]:
		var h := _build(ep_id)
		for rid in h.rooms_built():
			if not h.room_shell(rid).from_glb():
				continue
			any = true
			assert_true(h.static_draws(rid) <= 3, "%s %s: %d static draws (≤ 3)" % [ep_id, rid, h.static_draws(rid)])
		h.free()
	if not any:
		skip("room .glb sets not built yet (greybox)")


func test_static_merge_keeps_piece_api() -> void:
	var h := _build("n01_throat_tea")
	if not h.room_shell("kitchen").from_glb():
		skip("room .glb sets not built yet (greybox)")
		h.free()
		return
	var merged := h.merged_pieces()
	assert_has(merged, "kitchen_window", "a static dressing piece is merged")
	assert_false(merged.has("kitchen_pans"), "a quake prop tonight stays its own mesh")
	assert_false(merged.has("kitchen_stool"), "the stool wobbles: not merged")
	assert_true(h.decor("kitchen_window") != null, "a merged piece keeps its node (API)")
	assert_true(h.landing_box("parlour.log_basket").size.x > 0.2, "the merged log basket keeps its landing box")
	# the merged mesh uses the room material, so the room light still drives it
	assert_eq(h.room_material_count("kitchen"), 1)
	h.free()
	var h2 := House3D.new()
	h2.merge_static = false
	tree.root.add_child(h2)
	var ep: EpisodeDef = db.episodes["n01_throat_tea"]
	h2.build(SetList.for_episode(db, ep), {}, db)
	assert_true(h2.merged_pieces().is_empty(), "merge_static = false keeps every piece")
	h2.free()


func test_lit_room_triangles_within_budget() -> void:
	# brief §7: ≤ 25k triangles per lit room (ink + halo passes counted)
	for ep_id in ["p00_curtain_up", "g0_sneeze", "n01_throat_tea", "n02_something_fishy"]:
		var h := _build(ep_id)
		for rid in h.result.rooms_lit:
			var t := h.room_tris(rid)
			assert_true(t > 0 and t <= 25000, "%s %s: %d tris (≤ 25k)" % [ep_id, rid, t])
		h.free()
