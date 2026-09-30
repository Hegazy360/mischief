## StageLighting3D + MaterialWarm3D + View3DConst (REDESIGN §5.3, R3D index §7.6).
extends TestBase


func test_room_levels_follow_the_rules() -> void:
	var lit := PackedStringArray(["parlour", "kitchen"])
	var back := PackedStringArray(["hall"])
	var t := StageLighting3D.levels_for(lit, back, "kitchen", "parlour", true)
	assert_almost_eq(t["kitchen"][0], 1.0, 0.0001, "Hush's room 1.0")
	assert_almost_eq(t["parlour"][0], 0.9, 0.0001, "Bellows' room 0.9")
	assert_almost_eq(t["parlour"][1], 0.0, 0.0001)
	assert_almost_eq(t["hall"][0], 0.3, 0.0001, "backstage 0.3")
	var t2 := StageLighting3D.levels_for(PackedStringArray(["porch", "hall", "parlour", "kitchen"]), PackedStringArray(), "kitchen", "kitchen", true)
	assert_almost_eq(t2["parlour"][0], 0.78, 0.0001, "other built room 0.78")
	assert_almost_eq(t2["parlour"][1], 0.4, 0.0001, "+40 % desaturation")
	assert_almost_eq(t2["kitchen"][0], 1.0, 0.0001)


func test_backstage_room_holding_bellows_is_lit_at_0_9() -> void:
	# P00: Bellows' FRAZZLED mirror fix-up in the dark hall must read in the Bellows window (index §7.6)
	var t := StageLighting3D.levels_for(PackedStringArray(["parlour", "kitchen"]), PackedStringArray(["hall"]), "kitchen", "hall", true)
	assert_almost_eq(t["hall"][0], 0.9, 0.0001, "the backstage hall with Bellows in it")
	assert_almost_eq(t["hall"][1], 0.0, 0.0001)


func test_room_dimming_off_lights_every_built_room() -> void:
	var t := StageLighting3D.levels_for(PackedStringArray(["parlour", "kitchen"]), PackedStringArray(["hall"]), "kitchen", "", false)
	assert_almost_eq(t["parlour"][0], 1.0, 0.0001)
	assert_almost_eq(t["parlour"][1], 0.0, 0.0001)
	assert_almost_eq(t["hall"][0], 0.3, 0.0001, "backstage stays dark")


func test_levels_ease_over_0_4_s_and_bellows_never_below_0_9() -> void:
	var sl := StageLighting3D.new()
	sl.setup_rooms(PackedStringArray(["parlour", "kitchen"]), PackedStringArray(["hall"]))
	sl.set_rooms_of("kitchen", "hall")
	sl.snap_now()
	assert_almost_eq(sl.level("hall"), 0.9, 0.0001)
	assert_ge(sl.bellows_level(), 0.9)
	sl.set_rooms_of("kitchen", "kitchen")
	sl.advance(0.2)
	var mid := sl.level("hall")
	assert_between(mid, 0.31, 0.89, "mid-ease")
	sl.advance(0.21)
	assert_almost_eq(sl.level("hall"), 0.3, 0.0001, "done within 0.4 s")
	assert_ge(sl.bellows_level(), 0.9, "his stage_light ≥ 0.9 even in a dim room")
	sl.set_rooms_of("parlour", "kitchen")
	sl.advance(1.0)
	assert_almost_eq(sl.level("kitchen"), 0.9, 0.0001)
	assert_almost_eq(sl.hush_level(), 1.0, 0.0001, "Hush follows her room")
	sl.free()


func test_room_light_changed_signal_fires_while_easing() -> void:
	var sl := StageLighting3D.new()
	sl.setup_rooms(PackedStringArray(["parlour", "kitchen"]), PackedStringArray())
	sl.set_rooms_of("kitchen", "")
	sl.snap_now()
	var seen := {}
	sl.room_light_changed.connect(func(room: String, lv: float, _d: float) -> void: seen[room] = lv)
	sl.set_rooms_of("parlour", "")
	sl.advance(0.5)
	assert_has(seen, "kitchen")
	assert_almost_eq(float(seen["kitchen"]), 0.78, 0.0001)
	sl.free()


func test_material_warm_registers_every_material_once_per_key() -> void:
	MaterialWarm3D.clear()
	var sh: Shader = load(View3DConst.SH_SET)
	var a := ShaderMaterial.new()
	a.shader = sh
	var b := ShaderMaterial.new()
	b.shader = sh
	var c := ShaderMaterial.new()
	c.shader = load(View3DConst.SH_CHAR)
	var ink := ShaderMaterial.new()
	ink.shader = load(View3DConst.SH_OUTLINE)
	c.next_pass = ink
	MaterialWarm3D.register(a, &"set")
	MaterialWarm3D.register(b, &"set")
	MaterialWarm3D.register(c, &"char")
	MaterialWarm3D.register(a, &"decal")
	assert_eq(MaterialWarm3D.total_registered(), 4, "every register() counted")
	assert_eq(MaterialWarm3D.count(), 3, "one entry per (shader, kind, pass chain)")
	assert_true(MaterialWarm3D.has(b, &"set"))
	assert_true(MaterialWarm3D.key_of(c, &"char").contains("outline.gdshader"), "the next pass is part of the key")
	MaterialWarm3D.clear()
	assert_eq(MaterialWarm3D.count(), 0)


func test_every_shader_file_of_the_contract_exists() -> void:
	for p in [View3DConst.SH_CHAR, View3DConst.SH_SET, View3DConst.SH_PROP, View3DConst.SH_OUTLINE,
			View3DConst.SH_OUTLINE_PROP, View3DConst.SH_HALO, View3DConst.SH_DECAL, View3DConst.SH_FX]:
		assert_true(ResourceLoader.exists(p), p)
	assert_true(FileAccess.file_exists("res://art3d/shaders/stage_light.gdshaderinc"))


func test_units_and_layers() -> void:
	assert_almost_eq(View3DConst.x_m(3000.0), 15.0, 0.0001)
	assert_almost_eq(View3DConst.floor_y(1), 3.5, 0.0001)
	assert_eq(View3DConst.floor_of_y(3.4), 1)
	assert_eq(View3DConst.floor_of_y(0.2), 0)
	assert_eq(View3DConst.MASK_PIP & View3DConst.MASK_PROP_INK, 0, "the window never shows prop ink")
	assert_eq(View3DConst.MASK_PIP & View3DConst.MASK_DECAL, 0, "nor decals")
	assert_eq(View3DConst.MASK_PIP & View3DConst.MASK_MAIN_ONLY, 0, "nor MAIN_ONLY FX")
	assert_eq(View3DConst.verb_color(&"hide"), Color("#5C9EFF"))
