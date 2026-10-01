## NightWarm.list (s2-night §4.2) for P00, N01, N02: rigs, rooms, looks (residues respect rules.combos),
## FX, fonts, audio.
extends TestBase


func test_lists_exist_for_the_slice() -> void:
	for ep in ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy", "g0_sneeze"]:
		var l := NightWarm.list(ep)
		assert_false(l.is_empty(), "%s has a warm list" % ep)
		assert_eq(l["rigs"], PackedStringArray(["hush", "bellows"]))
		assert_gt((l["rooms"] as PackedStringArray).size(), 0, "%s rooms" % ep)
		assert_gt((l["props"] as PackedStringArray).size(), 0, "%s props" % ep)
		assert_has(l["fx"], "roses", "the curtain call's roses")
		assert_eq((l["fonts"] as Array).size(), 3, "captions 88, stamps 64, HUD 48")
		assert_true(bool(l["pip"]))


func test_sneeze_night_warms_frazzled() -> void:
	var l := NightWarm.list("g0_sneeze")
	var looks: PackedStringArray = (l["looks"] as Dictionary)["bellows"]
	assert_has(looks, "FRAZZLED", "the CHOO's residue page is built under the curtain")


func test_combos_respect_rules() -> void:
	for ep in ["n01_throat_tea", "n02_something_fishy"]:
		var raw: Variant = ViewKit.json("res://data/episodes/%s.json" % ep)
		var rules: Dictionary = (raw as Dictionary).get("rules", {})
		var l := NightWarm.list(ep)
		if rules.get("combos") is Array and (rules["combos"] as Array).is_empty():
			assert_eq((l["combos"] as PackedStringArray).size(), 0, "%s: combos [] → none warmed" % ep)
			for k in (l["looks"] as Dictionary)["bellows"]:
				assert_false(String(k).begins_with("COMBO:"), "%s: no combo look" % ep)


func test_every_basic_residue_and_lazy_textures_are_warmed() -> void:
	var l := NightWarm.list("g0_sneeze")
	var looks: PackedStringArray = (l["looks"] as Dictionary)["bellows"]
	assert_has(looks, "SOAKED", "landings leave residues no prank lists (the sink)")
	assert_has(looks, "BLINDED", "the blinded look (3D: the flipped bouffant)")
	assert_has((l["looks"] as Dictionary)["hush"], "TOMATO", "Hush's doorstep tomato")
	assert_has((l["looks"] as Dictionary)["hush"], "CARRY_KIPPER", "her carries (rig3d.json)")
	var tex: PackedStringArray = l["textures"]
	assert_has(tex, "res://art/ui/glyph_stars.svg", "the dizzy glyph")
	assert_has(tex, "res://art/icons/activities/tea.svg", "thought-bubble icons")
	for p in tex:
		assert_true(p.ends_with(".svg"), p)


## D17 (r3d-fix-perf): the action button's RIG icons of tonight's pranks are on the warm list (the first rig point
## she reached rasterised them in Hud.apply, ~2 ms at the same tick every run), and the warmer rasterises them.
func test_hud_icons_cover_tonights_rig_points() -> void:
	var l := NightWarm.list("p00_curtain_up")
	var hi: Dictionary = l.get("hud_icons", {})
	var targets: PackedStringArray = hi.get("targets", PackedStringArray())
	assert_has(targets, "res://art/house/props/honey_jar.svg", "the sneeze's rig point (kitchen_honey)")
	for t in targets:
		assert_true(String(t).begins_with("res://") and ResourceLoader.exists(String(t)), "%s exists" % t)
	var n1 := NightWarm.list("n01_throat_tea")
	assert_gt(((n1.get("hud_icons", {}) as Dictionary).get("items", PackedStringArray()) as PackedStringArray).size(), 0,
		"N01 has pranks that need an item")
	var w := NightWarmer.new()
	w.list = l
	w._warm_ui_icons()
	assert_eq(w.hud_icons_warmed, targets.size() + (hi.get("items", PackedStringArray()) as PackedStringArray).size())
	w.free()


## D17 (r3d-fix-perf): the edge badge's tier faces and emote faces are loaded under the curtain (a tier rise at a
## reaction accent loaded a portrait inside Hud.apply, 2.4–3.0 ms at the same tick every run).
func test_edge_badge_faces_are_warmed() -> void:
	var h := Hud.new()
	var w := NightWarmer.new()
	w.list = {}
	w.hud = h
	w._warm_ui_icons()
	assert_eq(w.edge_faces_warmed, EdgeBubble.TIER_FACES.size() + EdgeBubble.EMOTES.size())
	for fn in EdgeBubble.TIER_FACES:
		assert_true(h.edge_bubble._faces.has(fn), "tier face %s cached" % fn)
	var t0 := Time.get_ticks_usec()
	h.edge_bubble.set_tier(3)
	assert_lt(Time.get_ticks_usec() - t0, 500, "a tier change after the warm loads nothing")
	w.free()
	h.free()


func test_detour_icons_and_the_hud_first_show_are_warmed() -> void:
	var h := Hud.new()
	var w := NightWarmer.new()
	w.list = {}
	w.hud = h
	var ids := NightWarmer.detour_ids()
	assert_has(ids, "exit", "his exit (t3237) is a detour of the data")
	assert_has(ids, "fixup_mirror", "the knock-on's fix-up (t1447) too")
	w._warm_ui_icons()
	assert_eq(w.activity_icons_warmed, ids.size(), "every detour icon rasterised under the curtain")
	for id in ids:
		assert_true(UiIcons._cache.has("res://art/icons/activities/%s.svg@%s" % [id, UiIcons.RASTER_SCALE]), id)
	assert_eq(h.warm_left, Hud.WARM_FRAMES, "the HUD's contextual pieces are shown for the warm frames")
	w.free()
	h.free()


func test_unknown_episode_is_empty() -> void:
	assert_true(NightWarm.list("nope").is_empty())


func test_devshot_sequence_extension() -> void:
	var ds: GDScript = load("res://autoload/dev_shot.gd")
	assert_eq(int(ds.call("seq_frames_needed", 0, 12, 60)), 721)
	assert_eq(int(ds.call("seq_frames_needed", 30, 4, 24)), 127)
	assert_eq(int(ds.call("seq_frames_needed", 0, 10, 0)), 0)
