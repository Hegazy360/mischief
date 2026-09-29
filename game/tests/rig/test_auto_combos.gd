## RigPlayer.auto_combos (s2-fix G #11, ruling L4): with auto_combos off (how CharacterView runs
## every rig in the game) SOAKED + FRAZZLED stay two looks — no COMBO:poodle on N01 / N02, where
## `rules.combos` is [] — and only an explicit set_residue("COMBO:<id>", true) (the sim's `combo`
## event) shows the combo. With it on (tools, AnimViewer) the combo still forms by itself.
extends TestBase

var p: RigPlayer = null


func before_each() -> void:
	p = RigPlayer.new()
	p.configure_for_tools()
	tree.root.add_child(p)
	p.setup("bellows")


func after_each() -> void:
	if is_instance_valid(p):
		p.free()


func test_auto_combos_off_keeps_both_residues() -> void:
	p.auto_combos = false
	p.set_residue("SOAKED", true)
	p.set_residue("FRAZZLED", true)
	p.advance(1.0 / 60.0)
	var on := p.active_residues()
	assert_false(on.has("COMBO:poodle"), "no derived combo: %s" % [on])
	assert_has(on, "SOAKED")
	assert_has(on, "FRAZZLED")


func test_explicit_combo_still_shows_and_replaces() -> void:
	p.auto_combos = false
	p.set_residue("SOAKED", true)
	p.set_residue("FRAZZLED", true)
	p.set_residue("COMBO:poodle", true)
	var on := p.active_residues()
	assert_has(on, "COMBO:poodle", "the sim's combo event shows it")
	assert_false(on.has("SOAKED"), "and it replaces its residues")


func test_auto_combos_on_derives_the_combo() -> void:
	assert_true(p.auto_combos, "default on (tools)")
	p.set_residue("SOAKED", true)
	p.set_residue("FRAZZLED", true)
	assert_has(p.active_residues(), "COMBO:poodle")
	p.auto_combos = false
	assert_false(p.active_residues().has("COMBO:poodle"), "switching it off drops the derived combo at once")


func test_character_view_turns_it_off() -> void:
	var cv := CharacterView.new()
	tree.root.add_child(cv)
	cv.setup("bellows")
	if not cv.uses_rig:
		cv.free()
		skip("bellows rig did not load")
		return
	assert_false(bool(cv.rig.get("auto_combos")), "CharacterView sets auto_combos = false")
	cv.free()
