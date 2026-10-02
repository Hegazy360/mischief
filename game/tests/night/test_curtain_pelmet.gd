## The curtain call's pelmet CONTACT (r3d polish, QA3: "the pelmet seems to hover above his wig"): the pelmet's
## fabric edge rests on the top of his bouffant — taken from the real rig (the `bouffant` bone; = the head_top
## socket unsquashed), never a fixed height — the wig squashes on contact and springs back, a small dust puff, then
## the face hold.
extends TestBase


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func test_the_contact_line_is_the_valance_fabric_edge() -> void:
	# the art: solid fabric to 62 % of its height, the fringe + tassels below, the last 13 % empty
	var tex := load(CurtainApron.VALANCE_ART) as Texture2D
	if not assert_true(tex != null, "the valance art loads"):
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var h := img.get_height()
	var w := img.get_width()
	var row_cov := func(y: int) -> float:
		var n := 0
		for x in range(0, w, 4):
			if img.get_pixel(x, y).a > 0.5:
				n += 1
		return float(n) / float((w + 3) / 4)
	assert_gt(float(row_cov.call(int(h * (CurtainApron.PELMET_FABRIC_K - 0.04)))), 0.97, "solid fabric just above the line")
	assert_lt(float(row_cov.call(int(h * 0.9))), 0.02, "nothing at 90 %: the rect's bottom is not the contact")


func test_wig_squash_flattens_on_contact_and_springs_back() -> void:
	assert_eq(CurtainApron.wig_squash_at(-1.0), 1.0, "untouched before the hit")
	assert_le(CurtainApron.wig_squash_at(0.0), 0.65, "flattened on the contact frame")
	assert_le(CurtainApron.wig_squash_at(2.0), 0.65, "held flat for the accent")
	assert_gt(CurtainApron.wig_squash_at(9.0), 0.95, "springs back up")
	assert_almost_eq(CurtainApron.wig_squash_at(30.0), CurtainApron.WIG_REST, 0.001, "rests a little squashed under it")
	assert_lt(CurtainApron.WIG_REST, 1.0)
	assert_eq(CurtainApron.rock_at(-1.0), 0.0)
	assert_eq(CurtainApron.rock_at(45.0), 0.0, "the rock settles")
	var peak := 0.0
	for f in 40:
		peak = maxf(peak, absf(CurtainApron.rock_at(float(f))))
	assert_between(peak, 0.02, 0.08, "it rocks a little on his round wig")


func test_a_small_dust_puff_bursts_out_both_sides() -> void:
	var w := CurtainApron.PELMET_SIZE.x
	var left := 0
	var right := 0
	for i in CurtainApron.DUST_PUFFS:
		var d0 := CurtainApron.dust_puff(i, 0.0, w)
		var d1 := CurtainApron.dust_puff(i, 14.0, w)
		assert_gt(d0.w, 0.5, "puff %d shows on contact" % i)
		assert_gt(absf(d1.x), absf(d0.x), "puff %d billows outwards" % i)
		assert_lt(d1.y, d0.y, "and up")
		assert_le(d1.z, 40.0, "small")
		assert_gt(absf(d0.x), 50.0, "out of the sides of his wig, not over his face")
		if d0.x < 0.0:
			left += 1
		else:
			right += 1
		assert_eq(CurtainApron.dust_puff(i, CurtainApron.DUST_F, w).w, 0.0, "gone by DUST_F")
	assert_eq(left, right, "both sides")
	assert_le(CurtainApron.DUST_PUFFS, 16, "capped")


func test_the_pelmet_rests_on_the_wig_top_it_is_given() -> void:
	var a := CurtainApron.new()
	tree.root.add_child(a)
	a.start_bellows(PackedStringArray(), 5.0)
	var below := CurtainApron.PELMET_SIZE.y * (1.0 - CurtainApron.PELMET_FABRIC_K)
	for f in 330:
		a.advance(1.0 / 60.0)
		if a.bonked():
			break
	assert_true(a.bonked())
	for wig_y: float in [300.0, 420.0, 455.5]:
		var st := a.pelmet_state(Vector2(640.0, wig_y))
		assert_almost_eq(float(st["line"]), wig_y + CurtainApron.PELMET_PRESS, 0.01, "the fabric edge sits on the wig (%.0f)" % wig_y)
		assert_almost_eq(float(st["bottom"]) - float(st["line"]), below, 0.01, "the fringe hangs below the line")
	a.queue_free()
	await tree.process_frame


func test_wig_top_from_the_rig_and_its_squash() -> void:
	allow_errors()
	var b := CurtainBows3D.new()
	tree.root.add_child(b)
	await _frames(2)
	if not assert_true(b.bellows != null and bool(b.bellows.get("ok")), "Bellows' rig builds"):
		b.queue_free()
		await tree.process_frame
		return
	b.pose_bellows(CurtainApron.BIT_MARK_X, "bellows/st_bonk", 1, 70.0, false, 0)
	await _frames(4)
	var top := b.wig_top_world()
	var sock: Vector3 = b.bellows.call("top_global")
	assert_true(top.is_finite(), "his wig top is known")
	assert_lt(top.distance_to(sock), 0.06, "unsquashed, the crown is the head_top socket (%s vs %s)" % [top, sock])
	var s1 := b.wig_top_screen()
	var sk: Skeleton3D = b.bellows.get("skeleton")
	var bi := sk.find_bone(CurtainBows3D.WIG_BONE)
	var seen := [0.0]
	var probe := func() -> void: seen[0] = sk.get_bone_pose_scale(bi).y
	sk.skeleton_updated.connect(probe)
	b.set_wig_squash(0.6)
	await _frames(3)
	sk.skeleton_updated.disconnect(probe)
	assert_almost_eq(float(seen[0]), 0.6, 0.05, "the modifier squashes the bouffant bone (%.3f)" % float(seen[0]))
	# the same frame, unsquashed (the skeleton restores the animated poses after skinning, so this is the clip's pose)
	var top2 := b.wig_top_world()
	var unsq := sk.global_transform * (sk.get_bone_global_pose(bi) * Vector3(0.0, CurtainBows3D.WIG_TOP_M, 0.0))
	var want := (CurtainBows3D.WIG_TOP_M + CurtainBows3D.WIG_PIVOT_M) * 0.4
	assert_almost_eq(unsq.distance_to(top2), want, 0.005, "the squashed crown is %.3f m lower" % want)
	assert_lt(top2.y, unsq.y, "down")
	var s2 := b.wig_top_screen()
	var s_unsq := b.cam.unproject_position(unsq) * b.size / Vector2(b.vp.size)
	assert_gt(s2.y - s_unsq.y, 8.0, "on screen the wig top comes down (%.1f px)" % (s2.y - s_unsq.y))
	assert_lt(absf(s1.x - s2.x), 200.0, "same wig (%.0f / %.0f)" % [s1.x, s2.x])
	b.set_wig_squash(1.0)
	b.hide_bellows()
	assert_eq(b.wig_squash(), 1.0, "hidden: the wig is itself again")
	b.queue_free()
	await tree.process_frame


func test_in_the_bit_the_pelmet_lands_on_his_squashed_wig() -> void:
	allow_errors()
	var b := CurtainBows3D.new()
	var a := CurtainApron.new()
	a.bows = b
	tree.root.add_child(b)
	tree.root.add_child(a)
	await _frames(2)
	if not assert_true(b.bellows != null and bool(b.bellows.get("ok")), "Bellows' rig builds"):
		a.queue_free()
		b.queue_free()
		await tree.process_frame
		return
	a.start_bellows(PackedStringArray(), 5.0)
	var hit_seen := false
	for f in 330:
		a.advance(1.0 / 60.0)
		await tree.process_frame
		if a.bonked() and not hit_seen:
			hit_seen = true
			await tree.process_frame
			assert_le(b.wig_squash(), 0.65, "the wig is flattened on contact")
			var wig := b.wig_top_screen()
			var st := a.pelmet_state(wig)
			assert_almost_eq(float(st["line"]), wig.y + CurtainApron.PELMET_PRESS, 0.5, "the fabric edge is ON his wig")
			assert_almost_eq(float(st["x"]), wig.x, 0.5, "centred on it")
	assert_true(hit_seen, "the pelmet hit")
	assert_almost_eq(b.wig_squash(), CurtainApron.WIG_REST, 0.001, "it stays on, the wig a little squashed")
	a.queue_free()
	b.queue_free()
	await tree.process_frame


func test_a_residue_wig_variant_uses_its_own_bounds_and_squashes() -> void:
	allow_errors()
	var b := CurtainBows3D.new()
	tree.root.add_child(b)
	await _frames(2)
	if not assert_true(b.bellows != null and bool(b.bellows.get("ok")), "Bellows' rig builds"):
		b.queue_free()
		await tree.process_frame
		return
	b.pose_bellows(CurtainApron.BIT_MARK_X, "bellows/loco_idle", 1, 35.0)
	b.bellows.call("set_body_slot", "bouffant", "frazzled", &"residue")
	await _frames(4)
	var sock: Vector3 = b.bellows.call("top_global")
	var top := b.wig_top_world()
	assert_true(top.is_finite(), "the variant's top is known")
	assert_lt(top.distance_to(sock), 0.2, "the frazzled wig's crown is near his head top (%s vs %s)" % [top, sock])
	b.set_wig_squash(0.6)
	var top2 := b.wig_top_world()
	assert_gt(top.y - top2.y, 0.08, "it squashes too (%.3f m)" % (top.y - top2.y))
	var held := 0
	for n in b.bellows.find_children("Att_bouffant*", "Node3D", true, false):
		if (n as Node3D).visible and absf((n as Node3D).transform.basis.get_scale().y - 0.6) < 0.01:
			held += 1
	assert_eq(held, 1, "the shown variant's holder carries the squash")
	b.set_wig_squash(1.0)
	b.queue_free()
	await tree.process_frame
