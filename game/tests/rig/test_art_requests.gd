## The art reports' rig requests, each proven on the real rigs (s2-rig §4.2): art-hush 1a–1d
## (Pip limb fills, Clarence z per socket, pupils hidden in both blink phases / hide_with,
## `visible: false`), art-bellows 1–5 (residue look keys + combos, overlays on invisible limb
## bones, state sockets, trim + lazy look pages, the gaze map + eyes↔lids pairing), plus
## set_part_texture. Skips a rig that has not been delivered.
extends TestBase

var p: RigPlayer


func after_each() -> void:
	if is_instance_valid(p):
		p.free()


func _player(rig_id: String, skin: String = "") -> RigPlayer:
	if not FileAccess.file_exists("res://data/rigs/%s/rig.json" % rig_id):
		return null
	p = RigPlayer.new()
	p.configure_for_tools()
	tree.root.add_child(p)
	p.setup(rig_id, skin)
	p.advance(0.0)
	return p


func _ch(part: String, c: int) -> float:
	return p.pose_buffer()[RigDef.ch(p.rig.idx(part), c)]


## Position of an item code in the draw sequence (runs searched for their members).
func _seq_pos(code: int) -> int:
	p._sort_items()
	if p._layout_dirty:
		p._rebuild_layout()
	for k in p._seq.size():
		var c := p._seq[k]
		if c == code:
			return k
		if (c >> 16) == RigPlayer.K_RUN and (p._runs[c & 0xFFFF] as RigPlayer._Run).items.has(code):
			return k
	return -1


func test_1a_pip_teal_sleeves_and_denim_legs() -> void:
	if _player("hush", "pip") == null:
		skip("hush rig not delivered")
		return
	var r := p.rig
	for li in r.limbs.size():
		var lid: String = r.limbs[li].id
		var c: Color = p._limb_fill[li]
		if lid.begins_with("arm"):
			assert_true(c.g > c.r and c.b > c.r, "%s is teal (%s)" % [lid, c.to_html(false)])
		elif lid.begins_with("leg"):
			assert_true(c.b > c.r and c.b > c.g, "%s is denim (%s)" % [lid, c.to_html(false)])
	# Hush's own fills differ (the skin really swaps them).
	var hush := RigPlayer.new()
	tree.root.add_child(hush)
	hush.setup("hush")
	assert_ne(hush._limb_fill[0].to_html(false), p._limb_fill[0].to_html(false), "Pip's limb fill is not Hush's")
	hush.free()


func test_1b_clarence_behind_the_glove_and_on_the_braces() -> void:
	if _player("hush") == null:
		skip("hush rig not delivered")
		return
	var ci := p.props.index_of("clarence")
	if ci < 0:
		skip("no clarence prop")
		return
	var code := (RigPlayer.K_PROP << 16) | ci
	p.props.attach(ci, "hand_r:grip")
	p.advance(1.0 / 60.0)
	assert_eq(p._item_z(code), 20, "z_by_socket on the grip")
	var hand := (RigPlayer.K_PART << 16) | p.rig.idx("hand_r")
	var hz := int(_ch("hand_r", RigDef.C_Z))
	if hz > 20:
		assert_lt(_seq_pos(code), _seq_pos(hand), "drawn before (behind) the glove")
	p.props.attach(ci, "torso:braces")
	p.advance(1.0 / 60.0)
	assert_eq(p._item_z(code), 9, "z 9 on the braces")


func test_1c_pupils_hidden_in_both_blink_phases_and_hide_with() -> void:
	if _player("hush") == null:
		skip("hush rig not delivered")
		return
	var r := p.rig
	if r.pupils_part < 0 or r.eyes_part < 0:
		skip("no pupils")
		return
	var pupils := r.names[r.pupils_part]
	p.face.blinks_enabled = true
	p.face.suppressed = false
	for bt in [0.5, 1.5, 2.5, 3.5, 4.5]:
		p.face.blink_t = bt
		p.advance(0.0)
		assert_eq(_ch(pupils, RigDef.C_VIS), 0.0, "pupils hidden at blink_t %.1f (phase %d)" % [bt, p.face.blink_phase()])
	p.face.blink_t = -1.0
	p.advance(0.0)
	assert_eq(_ch(pupils, RigDef.C_VIS), 1.0, "and back when the eyes open")
	for v in r.pupils_hide:
		p.set_slot("eyes", r.tex_names[r.eyes_part][v])
		p.advance(0.0)
		assert_eq(_ch(pupils, RigDef.C_VIS), 0.0, "pupils hidden with eyes '%s'" % [v])
	p.face.clear()


func test_1d_visible_false_in_the_rest_pose() -> void:
	if _player("hush") == null:
		skip("hush rig not delivered")
		return
	var bl := p.rig.idx("braces_loop")
	if bl < 0:
		skip("no braces_loop")
		return
	assert_eq(p.rig.rest[RigDef.ch(bl, RigDef.C_VIS)], 0.0)
	assert_eq(_seq_pos((RigPlayer.K_PART << 16) | bl), -1, "not in the draw sequence")


func test_ab1_residue_look_keys_and_combos() -> void:
	if _player("bellows") == null:
		skip("bellows rig not delivered")
		return
	var r := p.rig
	var any := false
	for k in r.residues:
		var res: RigDef.RigResidue = r.residues[k]
		if not res.face_slots.is_empty() or not res.props.is_empty() or not res.limb_fill.is_empty():
			any = true
	assert_true(any, "face_overlays / props / limb_fill parsed")
	var combos := 0
	for k2 in r.residues:
		var res2: RigDef.RigResidue = r.residues[k2]
		if not res2.combo_of.is_empty():
			combos += 1
			assert_false(res2.combo_replaces.is_empty(), "%s replaces" % k2)
			p.face.clear()
			for part_k in res2.combo_of:
				p.set_residue(part_k, true)
			assert_has(p.active_residues(), String(k2), "all of %s on → the combo" % [res2.combo_of])
			for rk in res2.combo_replaces:
				assert_false(p.active_residues().has(rk), "%s replaced" % rk)
			for part_k2 in res2.combo_of:
				p.set_residue(part_k2, false)
	assert_gt(combos, 0, "combos map parsed")
	for k3 in r.residues:
		if String(k3).ends_with(":blind"):
			return
	fail("no ':blind' sub-look parsed")


func test_ab2_overlays_on_invisible_limb_bones() -> void:
	if _player("bellows") == null:
		skip("bellows rig not delivered")
		return
	var r := p.rig
	var kind := ""
	var bone := -1
	for k in r.residues:
		var res: RigDef.RigResidue = r.residues[k]
		for oi in res.overlay_part.size():
			if r.limb_of[res.overlay_part[oi]] >= 0:
				kind = String(k)
				bone = res.overlay_part[oi]
				break
		if kind != "":
			break
	if kind == "":
		skip("no overlay on a limb bone")
		return
	p.set_residue(kind, true)
	p.advance(1.0 / 60.0)
	var o := -1
	for i in p._ov_part.size():
		if p._ov_part[i] == bone and p._res_kinds[p._ov_res[i]] == kind:
			o = i
	assert_ge(o, 0, "overlay registered")
	var code := (RigPlayer.K_OVERLAY << 16) | o
	assert_ge(_seq_pos(code), 0, "%s's overlay on %s is drawn" % [kind, r.names[bone]])
	p._sync_render()
	assert_true(p._ov_ci[o].is_valid(), "it has a canvas item")
	assert_eq(p._slot_ready[p._ov_slot[o]], 1, "its texture is on a built page")
	var want := p._part_xf(bone)
	assert_true(p._xf[bone].origin.is_equal_approx(want.origin), "drawn at the bone's transform")
	assert_eq(p._slot_draw[p._ov_slot[o]].position.is_equal_approx(-r.pivot[bone] + p._slot_rect[p._ov_slot[o]].position), true, "and pivot")


func test_ab3_state_sockets_move_the_specs() -> void:
	if _player("bellows") == null:
		skip("bellows rig not delivered")
		return
	var si := p.props.index_of("specs")
	if si < 0 or not (p.rig.props[si] as RigDef.RigProp).state_sockets.has("on"):
		skip("no specs state sockets")
		return
	p.set_prop_state("specs", "on")
	assert_eq(p.rig.socket_names[p.props.socket[si]], "head:specs")
	p.advance(1.0 / 60.0)
	var head_z := int(_ch("head", RigDef.C_Z))
	assert_eq(p._item_z((RigPlayer.K_PROP << 16) | si), head_z + int((p.rig.props[si] as RigDef.RigProp).state_z_offset.get("on", 0)))
	p.set_prop_state("specs", "dangling")
	assert_eq(p.rig.socket_names[p.props.socket[si]], "torso:chain")


func test_ab4_lazy_look_pages() -> void:
	if not FileAccess.file_exists("res://data/rigs/bellows/rig.json"):
		skip("bellows rig not delivered")
		return
	var r := RigDef.for_id("bellows")
	var kind := ""
	for k in ["FLOURY", "FEATHERED", "SOAKED"]:
		if r.residues.has(k) and not r.look_texture_paths(k).is_empty():
			kind = k
			break
	if kind == "":
		skip("no residue with its own textures")
		return
	var s := HiResTex.resolve_scale(-1.0)
	AtlasBuilder.forget(RigPlayer.look_atlas_key("bellows", "", s, kind))
	TexStats.reset()
	_player("bellows")
	var base_pages := TexStats.pages_built()
	assert_false(p.look_ready(kind), "%s is not built at setup" % kind)
	for q in r.look_texture_paths(kind):
		assert_false(p.atlas.has(q), "%s is not in the base atlas" % q.get_file())
	p.set_residue(kind, true)
	assert_true(p.look_ready(kind), "built on its first set_residue")
	assert_gt(TexStats.pages_built(), base_pages, "and counted by TexStats")
	assert_gt(TexStats.built("look"), 0)
	p.advance(1.0 / 60.0)
	p._sync_render()
	for o in p._ov_part.size():
		if p._res_kinds[p._ov_res[o]] == kind:
			assert_eq(p._slot_ready[p._ov_slot[o]], 1, "overlay slot filled")
	# A second player shares the cached page (no new build).
	var n0 := TexStats.pages_built()
	var p2 := RigPlayer.new()
	tree.root.add_child(p2)
	p2.setup("bellows")
	p2.set_residue(kind, true)
	assert_eq(TexStats.pages_built(), n0, "the look page is shared")
	p2.free()
	# The base atlas is the everyday look only: ≤ 12 MB at 2× (mipmaps included).
	if is_equal_approx(s, 2.0):
		assert_le(p.atlas.memory_bytes(), 12 * 1024 * 1024, "Bellows base atlas %.1f MB" % (float(p.atlas.memory_bytes()) / 1048576.0))
	print("  [atlas] bellows base %.1f MB at %.1f× (%d pages), all looks off" % [float(p.atlas.memory_bytes()) / 1048576.0, s, p.atlas.pages.size()])


func test_ab4_warm_looks_respects_its_budget() -> void:
	if not FileAccess.file_exists("res://data/rigs/bellows/rig.json"):
		skip("bellows rig not delivered")
		return
	var r := RigDef.for_id("bellows")
	var s := HiResTex.resolve_scale(-1.0)
	var keys := PackedStringArray()
	for k in ["SOAKED", "FRAZZLED", "STICKY", "COSTUME:jelly_helmet"]:
		if r.residues.has(k):
			keys.append(k)
			AtlasBuilder.forget(RigPlayer.look_atlas_key("bellows", "", s, k))
	_player("bellows")
	assert_false(p.looks_ready(keys), "nothing warmed yet")
	var calls := 0
	var done := false
	var worst_ms := 0.0
	while not done and calls < 2000:
		var t0 := Time.get_ticks_usec()
		done = p.warm_looks(keys, 4.0)
		worst_ms = maxf(worst_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
		calls += 1
		if not done:
			await tree.process_frame
	assert_true(done, "every look warmed (%d calls)" % calls)
	assert_true(p.looks_ready(keys))
	print("  [warm] %d looks in %d calls, worst call %.1f ms (budget 4 ms + at most one page upload)" % [keys.size(), calls, worst_ms])
	# Rasterising and packing run on worker threads; a call uploads at most one finished page
	# (loose ceiling: shared machines).
	assert_lt(worst_ms, 40.0, "no call rasterises or packs a look on this thread")
	var n0 := TexStats.pages_built()
	for k2 in keys:
		p.set_residue(k2, true)
	assert_eq(TexStats.pages_built(), n0, "warmed looks build nothing on set_residue")


func test_ab5_gaze_is_the_resting_look_and_eyes_bring_their_lids() -> void:
	if _player("bellows") == null:
		skip("bellows rig not delivered")
		return
	var r := p.rig
	if p.poses.gaze.is_empty() or r.pupils_part < 0:
		skip("no gaze map")
		return
	var preset := String(p.poses.gaze.keys()[0])
	var g: Vector2 = p.poses.gaze_of(preset)
	var pupils := r.names[r.pupils_part]
	p.set_face("neutral" if p.poses.has_preset("neutral") else preset)
	p.advance(0.0)
	var x0 := _ch(pupils, RigDef.C_X)
	var y0 := _ch(pupils, RigDef.C_Y)
	p.set_face(preset)
	p.advance(0.0)
	var base := p.rig.rest
	var bx := base[RigDef.ch(r.pupils_part, RigDef.C_X)]
	var by := base[RigDef.ch(r.pupils_part, RigDef.C_Y)]
	assert_almost_eq(_ch(pupils, RigDef.C_X) - bx, clampf(g.x, -r.pupil_range.x * 1.5, r.pupil_range.x * 1.5), 0.01, "gaze x of %s" % preset)
	assert_almost_eq(_ch(pupils, RigDef.C_Y) - by, clampf(g.y, -r.pupil_range.y * 1.5, r.pupil_range.y * 1.5), 0.01, "gaze y of %s" % preset)
	assert_true(x0 != _ch(pupils, RigDef.C_X) or y0 != _ch(pupils, RigDef.C_Y) or g == Vector2.ZERO, "the gaze moves the pupils")
	if r.lids_part >= 0 and not r.eyes_lids.is_empty():
		var ev: String = r.tex_names[r.eyes_part][int(r.eyes_lids.keys()[0])]
		p.set_slot("eyes", ev)
		p.advance(0.0)
		assert_eq(_ch(r.names[r.lids_part], RigDef.C_VIS), 1.0, "eyes '%s' bring their lids" % ev)


func test_set_part_texture_beats_residues_not_clips() -> void:
	if _player("bellows") == null:
		skip("bellows rig not delivered")
		return
	var bi := p.rig.idx("bouffant")
	if bi < 0 or p.rig.tex_index(bi, "flipped") < 0:
		skip("no bouffant flipped")
		return
	p.set_part_texture("bouffant", "flipped")
	p.advance(0.0)
	assert_eq(int(_ch("bouffant", RigDef.C_TEX)), p.rig.tex_index(bi, "flipped"), "override applied")
	if p.rig.residues.has("SOAKED"):
		p.set_residue("SOAKED", true)
		p.advance(0.0)
		assert_eq(int(_ch("bouffant", RigDef.C_TEX)), p.rig.tex_index(bi, "flipped"), "beats the residue swap")
	p.set_part_texture("bouffant", "")
	p.advance(0.0)
	assert_ne(int(_ch("bouffant", RigDef.C_TEX)), p.rig.tex_index(bi, "flipped"), "cleared")
