## RigDef3D (r3d-index §7.3): the fixture descriptor loads clean; every validation rule fires on a descriptor broken
## in exactly that way, naming the file and key; variants and the pip fallback resolve.
extends TestBase

const Env := preload("res://tests/rig3d/fixtures/fix_env.gd")


func before_each() -> void:
	Env.push()


func after_each() -> void:
	Env.pop()


func _parse(d: Dictionary) -> RigDef3D:
	var def := RigDef3D.new()
	def.rig_id = "fix"
	def.path = "fixture.json"
	def.parse(d)
	return def


func _has_error(def: RigDef3D, needle: String) -> bool:
	for e in def.errors:
		if e.contains(needle):
			return true
	return false


func test_fixture_loads_clean() -> void:
	var def := RigDef3D.load("fix")
	assert_true(def.is_valid(), "errors: %s" % [def.errors])
	assert_eq(def.rig_id, "fix")
	assert_eq(def.bone_names.size(), 27, "bones read from the scene")
	assert_has(def.sockets, "grip_r")
	assert_eq((def.sockets["grip_r"] as RigDef3D.Socket).bone, "hand_r")
	assert_eq((def.props["cup"] as RigDef3D.Prop).home_socket, "grip_r", "the default state's socket is home")
	assert_eq((def.props["pepper_pot"] as RigDef3D.Prop).default_state, "hidden")
	assert_eq(def.slot_default["bouffant"], "neat", "the null variant is the default")
	assert_eq(def.cell_index("eyes", "open"), 8)
	assert_eq(def.cell_index("eyes", "none"), -1)
	assert_eq(def.presets["happy"]["blush"], "on", "2D-style overlay slots are kept for the face driver")
	assert_eq(def.mirrored("brows", "sly"), "sly_m")
	assert_eq(def.mirrored("extra_a", "tear"), "tear_m", "plain cell keys apply to any layer that has the mirror cell")
	assert_eq(def.mirrored("eyes", "open"), "open")
	assert_eq(def.cheat_deg("walk"), 20.0)
	assert_eq(def.tint_tiers.size(), 4)
	assert_true(RigDef3D.exists("fix"))
	assert_false(RigDef3D.exists("nobody"))


func test_cached_and_variants() -> void:
	var a := RigDef3D.load("fix")
	assert_true(a == RigDef3D.load("fix"), "cached per rig")
	var hb := RigDef3D.load("fix", "head_b")
	assert_true(hb.is_valid(), "variant errors: %s" % [hb.errors])
	assert_eq(hb.variant, "head_b")
	assert_eq(hb.head_scale, 1.2, "the variant file is rig3d_head_b.json")
	var pip := RigDef3D.load("fix", "pip")
	assert_eq(pip.variant, "", "a pip skin request loads the base descriptor (R7)")
	var missing := RigDef3D.load("nobody")
	assert_false(missing.is_valid())
	assert_true(_has_error(missing, "file not found"), "%s" % [missing.errors])


func test_every_rule_fires_on_a_broken_descriptor() -> void:
	var cases := [
		["scene", func(d: Dictionary) -> void: d["scene"] = "res://tests/rig3d/fixtures/nope.tscn", "scene: 'res://tests/rig3d/fixtures/nope.tscn' does not exist"],
		["socket bone", func(d: Dictionary) -> void: d["sockets"]["grip_r"]["bone"] = "hand_x", "sockets.grip_r.bone: bone 'hand_x' does not exist"],
		["role bone", func(d: Dictionary) -> void: d["bones"]["head"] = "Noggin", "bones.head: bone 'Noggin'"],
		["prop state socket", func(d: Dictionary) -> void: d["props"]["cup"]["states"]["held"] = "grip_x", "props.cup.states.held: socket 'grip_x'"],
		["prop default", func(d: Dictionary) -> void: d["props"]["cup"]["default"] = "juggled", "props.cup.default"],
		["prop bone", func(d: Dictionary) -> void: d["props"]["cup"]["bone"] = "prop_x", "props.cup.bone: bone 'prop_x'"],
		["attachment scene", func(d: Dictionary) -> void: d["attachments"]["stool"]["scene"] = "res://nope.tscn", "attachments.stool.scene"],
		["attachment bone", func(d: Dictionary) -> void: d["attachments"]["stool"]["bone"] = "seat_x", "attachments.stool.bone: bone 'seat_x'"],
		["slot attachment", func(d: Dictionary) -> void: d["slots"]["bouffant"]["flipped"] = "wig", "slots.bouffant.flipped: attachment 'wig'"],
		["look swap variant", func(d: Dictionary) -> void: d["looks"]["BLINDED"]["swap"]["bouffant"] = "mohawk", "looks.BLINDED.swap.bouffant: variant 'mohawk'"],
		["look swap slot", func(d: Dictionary) -> void: d["looks"]["BLINDED"]["swap"] = {"hat": "flipped"}, "looks.BLINDED.swap.hat: slot does not exist"],
		["look show", func(d: Dictionary) -> void: d["looks"]["RIDE"]["show"] = ["pony"], "looks.RIDE: attachment 'pony'"],
		["look hide bone", func(d: Dictionary) -> void: d["looks"]["BALD"]["hide_bones"] = ["hair_x"], "looks.BALD.hide_bones: bone 'hair_x'"],
		["jiggle bone", func(d: Dictionary) -> void: d["jiggle"][0]["bones"] = ["tassel"], "jiggle[0].bones: bone 'tassel'"],
		["face cell grid", func(d: Dictionary) -> void: d["face"]["cells"]["eyes"]["open"] = 64, "face.cells.eyes.open: cell 64 outside the 8x8 grid"],
		["face layer", func(d: Dictionary) -> void: d["face"]["layers"] = ["brows", "whiskers"], "unknown layer 'whiskers'"],
		["preset cell", func(d: Dictionary) -> void:
			d["face"].erase("presets")
			d["face"]["preset_table"] = {"neutral": {"eyes": "open", "mouth": "smile"}, "odd": {"eyes": "cross", "mouth": "smile"}},
			"face.presets.odd.eyes: cell 'cross' does not exist"],
		["blink cell", func(d: Dictionary) -> void: d["face"]["blink"]["blinkable"] = ["open", "starry"], "face.blink.blinkable: eyes cell 'starry'"],
		["colour", func(d: Dictionary) -> void: d["tint"]["livid"] = "beetroot", "tint.livid: 'beetroot' is not a #RRGGBB colour"],
	]
	for c in cases:
		var d := Env.rig_dict()
		(c[1] as Callable).call(d)
		var def := _parse(d)
		assert_false(def.is_valid(), "%s: expected an error" % c[0])
		assert_true(_has_error(def, String(c[2])), "%s: wanted '%s' in %s" % [c[0], c[2], def.errors])
		for e in def.errors:
			assert_true(e.begins_with("fixture.json: "), "errors name the file: %s" % e)


func test_unknown_keys_warn() -> void:
	var d := Env.rig_dict()
	d["colour_scheme"] = "loud"
	var def := _parse(d)
	assert_true(def.is_valid())
	var found := false
	for w in def.warnings:
		found = found or w.contains("colour_scheme")
	assert_true(found, "unknown key warned: %s" % [def.warnings])


func test_real_cast_descriptors_when_present() -> void:
	var n := 0
	for rig in ["hush", "bellows"]:
		if not RigDef3D.exists(rig):
			continue
		n += 1
		var def := RigDef3D.load(rig)
		assert_true(def.is_valid(), "%s descriptor: %s" % [rig, def.errors])
		assert_gt(def.bone_names.size(), 60, "%s is on the UAL skeleton" % rig)
	if n == 0:
		skip("cast rigs not landed yet — r3d-cast-hush / r3d-cast-bellows")


func test_outline_default_is_d7() -> void:
	var d := Env.rig_dict()
	(d["material"] as Dictionary).erase("outline_px")
	var rd := _parse(d)
	assert_almost_eq(rd.outline_px, View3DConst.OUTLINE_CHAR_PX, 0.0001, "no outline_px → D7's character width")
