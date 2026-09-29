## The character rigs (art-hush / art-bellows) through the rig runtime: skins with limb
## fills, prop z per socket / state sockets, pupils hidden with shut eyes, paired lids,
## `visible: false`, residue face overlays / props / limb fills / blind looks and combos,
## atlas trimming. Skips when a rig has not been delivered.
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


func _vis(part: String) -> float:
	return p.pose_buffer()[RigDef.ch(p.rig.idx(part), RigDef.C_VIS)]


func test_char_rigs_load_without_errors() -> void:
	var any := false
	for id in ["hush", "bellows", "figgis"]:
		if not FileAccess.file_exists("res://data/rigs/%s/rig.json" % id):
			continue
		any = true
		var r := RigDef.for_id(id)
		assert_eq(r.errors, PackedStringArray(), "%s rig errors" % id)
		var lib := PoseLib.for_rig(id)
		assert_eq(lib.errors, PackedStringArray(), "%s pose errors" % id)
		for f in RigLint.lint_rig(r, lib):
			assert_ne(String(f["severity"]), "error", AnimLint.format(f))
	if not any:
		skip("no character rigs delivered yet")


func test_hush_pip_skin_limbs_props_and_face() -> void:
	if _player("hush", "pip") == null:
		skip("hush rig not delivered")
		return
	var r := p.rig
	var fills := r.skin_limb_fills("pip")
	assert_false(fills.is_empty(), "pip overrides limb fills")
	for li in fills:
		assert_eq(p._limb_fill[li].to_html(false), (fills[li] as Color).to_html(false), "skin limb fill applied")
	var paths := r.all_texture_paths("pip")
	var pip_files := 0
	for q in paths:
		if q.contains("/pip/"):
			pip_files += 1
	assert_gt(pip_files, 5, "pip textures swapped in")
	if r.idx("braces_loop") >= 0:
		assert_eq(r.rest[RigDef.ch(r.idx("braces_loop"), RigDef.C_VIS)], 0.0, "visible: false honoured")
	var ci := p.props.index_of("clarence")
	if ci >= 0:
		p.props.attach(ci, "hand_r:grip")
		var code := (RigPlayer.K_PROP << 16) | ci
		assert_eq(p._item_z(code), 20, "z_by_socket: behind the glove on the grip")
		p.props.attach(ci, "torso:braces")
		assert_eq(p._item_z(code), 9, "z 9 on the braces")
	# Pupils hide while the eyes are half / shut (blink phases included).
	if r.eyes_part >= 0 and r.pupils_part >= 0 and not r.pupils_hide.is_empty():
		p.face.blinks_enabled = true
		p.face.suppressed = false
		p.face.blink_t = 0.5
		p.advance(0.0)
		assert_eq(_vis("face_pupils"), 0.0, "pupils hidden in the half-closed blink phase")


func test_bellows_residues_combos_props_lids() -> void:
	if _player("bellows") == null:
		skip("bellows rig not delivered")
		return
	var r := p.rig
	if r.residues.has("COMBO:dough_man"):
		p.set_residue("SOAKED", true)
		p.set_residue("FLOURY", true)
		var act := p.active_residues()
		assert_has(act, "COMBO:dough_man", "both residues on → the combo look")
		assert_false(act.has("SOAKED"), "combo replaces its residues")
		p.set_residue("FLOURY", false)
		assert_false(p.active_residues().has("COMBO:dough_man"))
		assert_has(p.active_residues(), "SOAKED")
		p.set_residue("SOAKED", false)
	if r.residues.has("FRAZZLED") and r.face_slots.has("singe"):
		p.set_residue("FRAZZLED", true)
		p.advance(1.0 / 60.0)
		assert_eq(_vis("face_singe"), 1.0, "face_overlays shows the singe")
		assert_true(r.residues.has("FRAZZLED:blind"), "blind sub-look parsed")
		p.set_residue("FRAZZLED", false)
	if r.residues.has("COSTUME:long_johns"):
		p.set_residue("COSTUME:long_johns", true)
		var res: RigDef.RigResidue = r.residues["COSTUME:long_johns"]
		for li in res.limb_fill:
			assert_eq(p._limb_fill[li].to_html(false), (res.limb_fill[li] as Color).to_html(false), "limb_fill recolours")
		p.set_residue("COSTUME:long_johns", false)
		for li2 in res.limb_fill:
			assert_eq(p._limb_fill[li2].to_html(false), r.limbs[li2].fill.to_html(false), "and restores")
	if r.residues.has("COSTUME:jelly_helmet"):
		p.set_residue("COSTUME:jelly_helmet", true)
		var ji := p.props.index_of("jelly_helmet")
		if ji >= 0:
			assert_eq(p.props.mode[ji], PropSim.ATTACHED, "residue prop attached")
			assert_eq(r.socket_names[p.props.socket[ji]], "head:hat")
			p.set_residue("COSTUME:jelly_helmet", false)
			assert_eq(p.props.mode[ji], PropSim.HIDDEN, "and hidden again")
	var si := p.props.index_of("specs")
	if si >= 0 and (r.props[si] as RigDef.RigProp).state_sockets.has("on"):
		p.set_prop_state("specs", "on")
		assert_eq(r.socket_names[p.props.socket[si]], "head:specs", "state_sockets re-attach")
		var head_z := int(p.pose_buffer()[RigDef.ch(r.socket_part[p.props.socket[si]], RigDef.C_Z)])
		assert_eq(p._item_z((RigPlayer.K_PROP << 16) | si), head_z + 14, "state_z_offset")
		p.set_prop_state("specs", "dangling")
		assert_eq(r.socket_names[p.props.socket[si]], "torso:chain")
	if r.lids_part >= 0 and not r.eyes_lids.is_empty():
		p.set_slot("eyes", "half")
		p.advance(1.0 / 60.0)
		assert_eq(_vis("face_lids"), 1.0, "half eyes bring their lids")
		assert_eq(int(p.pose_buffer()[RigDef.ch(r.lids_part, RigDef.C_TEX)]), r.tex_index(r.lids_part, "half"))


## Every quad in a triangle run samples the run's page, also after a residue swaps a limb end
## to a texture variant packed on another page (Bellows' tutu → tiptoe slippers, non-core).
func test_variant_on_another_page_moves_its_quad() -> void:
	if _player("bellows") == null:
		skip("bellows rig not delivered")
		return
	var r := p.rig
	print("  [atlas] bellows pages at art scale %.1f: %d" % [p.atlas.scale, p.atlas.pages.size()])
	var kinds := PackedStringArray(["(none)"])
	for k in r.residues:
		if not (r.residues[k] as RigDef.RigResidue).tex_part.is_empty():
			kinds.append(String(k))
	var checked := 0
	var off_core := 0
	for kind in kinds:
		if kind != "(none)":
			p.set_residue(kind, true)
		p.advance(1.0 / 60.0)
		p._sort_items()
		if p._layout_dirty:
			p._rebuild_layout()
		for run in p._runs:
			for code in run.items:
				if (code >> 16) == RigPlayer.K_PART:
					assert_eq(p._cur_page(code & 0xFFFF), run.page, "%s: %s drawn from its own page" % [kind, r.names[code & 0xFFFF]])
					checked += 1
					if run.page > 0:
						off_core += 1
		p._sort_items()
		assert_false(p._layout_dirty, "%s: layout settles (no rebuild every frame)" % kind)
		if kind != "(none)":
			p.set_residue(kind, false)
	assert_gt(checked, 0)
	print("  [atlas] %d limb-end quads checked, %d drawn from a non-core page" % [checked, off_core])


func test_atlas_trimming_shrinks_character_pages() -> void:
	if not FileAccess.file_exists("res://data/rigs/bellows/rig.json"):
		skip("bellows rig not delivered")
		return
	var r := RigDef.for_id("bellows")
	var paths := r.all_texture_paths()
	AtlasBuilder.trim = false
	var full := AtlasBuilder.build("test:bellows:untrimmed", paths, 1.0)
	AtlasBuilder.trim = true
	var trimmed := AtlasBuilder.build("test:bellows:trimmed", paths, 1.0)
	print("  [atlas] bellows at 1×: %d images, untrimmed %.2f MP on %d page(s), trimmed %.2f MP on %d page(s) (%.0f %% packed)" % [
		paths.size(), float(full.page_px()) / 1.0e6, full.pages.size(), float(trimmed.page_px()) / 1.0e6, trimmed.pages.size(), trimmed.pack_ratio() * 100.0])
	assert_lt(trimmed.page_px(), full.page_px() * 0.7, "trimming saves ≥ 30 % of the page area")
	AtlasBuilder.forget("test:bellows:untrimmed")
	AtlasBuilder.forget("test:bellows:trimmed")
