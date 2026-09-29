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
	assert_has(looks, "FRAZZLED:blind", "the blind variant page")
	assert_has((l["looks"] as Dictionary)["hush"], "TOMATO", "Hush's doorstep tomato")
	var tex: PackedStringArray = l["textures"]
	assert_has(tex, "res://art/ui/glyph_stars.svg", "the dizzy glyph")
	assert_has(tex, "res://art/icons/activities/tea.svg", "thought-bubble icons")
	for p in tex:
		assert_true(p.ends_with(".svg"), p)


func test_unknown_episode_is_empty() -> void:
	assert_true(NightWarm.list("nope").is_empty())


func test_devshot_sequence_extension() -> void:
	var ds: GDScript = load("res://autoload/dev_shot.gd")
	assert_eq(int(ds.call("seq_frames_needed", 0, 12, 60)), 721)
	assert_eq(int(ds.call("seq_frames_needed", 30, 4, 24)), 127)
	assert_eq(int(ds.call("seq_frames_needed", 0, 10, 0)), 0)
