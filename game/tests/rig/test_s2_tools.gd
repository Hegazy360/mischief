## Stage-2 rig tooling (s2-rig §4.1.4–§4.1.5, §4.3): PoseLib's tolerant parser (unknown keys
## and wrong value types warn once and are skipped — never a crash, never a dropped preset),
## AnimViewer's flag parsing, RigPerf's args and medians.
extends TestBase

const RIG := "_mannequin"


func test_poselib_tolerates_unknown_keys_and_wrong_types() -> void:
	var r := RigDef.for_id(RIG)
	var faces := {"presets": {
		"good": {"eyes": "open", "mouth": "closed"},
		"mixed": {"eyes": "wide", "sparkle": "yes", "mouth": 7, "brows": null},
		"nested": {"eyes": ["open"], "mouth": {"v": 1}},
		"numbers": {"eyes": 3.5}},
		"gaze": {"good": [4, -2], "bad": "left", "mixed": [1]}}
	var poses := {"poses": {
		"p_ok": {"bones": {"head": {"rot": 10}}, "face": "good", "tags": ["idle", 3]},
		"p_types": {"bones": {"head": {"rot": "ten", "vis": "yes", "tex": [1], "x": 2}}, "root": {"y": "up", "sx": 1.1}},
		"p_junk": {"wiggle": true, "bones": {"torso": {"rot": 5}}, "root": [1, 2]},
		"p_not_obj": 42,
		"p_props": {"props": {"mug": {"state": "full"}}, "residues": ["SOAKED"]}}}
	var lib := PoseLib.from_dicts(r, poses, faces)
	# Every preset loads, including the ones with junk slots.
	for pr in ["good", "mixed", "nested", "numbers"]:
		assert_true(lib.has_preset(pr), "preset '%s' kept" % pr)
	var mixed: PackedInt32Array = lib.presets["mixed"]
	var eyes := r.face_slots.find("eyes")
	assert_ge(mixed[eyes], 0, "the valid slot of a mixed preset still applies")
	var brows := r.face_slots.find("brows")
	assert_eq(mixed[brows], -2, "null hides the slot")
	# Every pose resolves; the valid channels land, the junk ones are skipped.
	for pn in ["p_ok", "p_types", "p_junk", "p_not_obj", "p_props"]:
		assert_true(lib.has_pose(pn), "pose '%s' kept" % pn)
	var hi := RigDef.ROOT_CH + r.idx("head") * RigDef.STRIDE
	assert_almost_eq(lib.pose("p_types")[hi + RigDef.C_X], 2.0, 0.001, "x = 2 applied next to junk channels")
	assert_almost_eq(lib.pose("p_types")[hi + RigDef.C_ROT], r.rest[hi + RigDef.C_ROT], 0.001, "rot 'ten' skipped")
	assert_almost_eq(lib.pose("p_types")[RigDef.R_SX], 1.1, 0.001, "root sx applied next to a junk y")
	var ti := RigDef.ROOT_CH + r.idx("torso") * RigDef.STRIDE
	assert_almost_eq(lib.pose("p_junk")[ti + RigDef.C_ROT], r.rest[ti + RigDef.C_ROT] + 5.0, 0.001, "unknown key ignored, bones applied")
	assert_eq(lib.tags_of("p_ok"), PackedStringArray(["idle", "3"]), "tags stringified")
	assert_eq(lib.gaze_of("good"), Vector2(4, -2))
	assert_eq(lib.gaze_of("bad"), Vector2.ZERO, "a junk gaze is skipped")
	assert_true(lib.pose_props.has("p_props") and lib.pose_residues.has("p_props"), "pose props / residues notes kept")
	# Warned, once per key — never an error for a type problem.
	var w := "\n".join(lib.warnings)
	assert_has(w, "sparkle")
	assert_has(w, "wiggle")
	assert_has(w, "p_not_obj")
	assert_eq(w.count("'sparkle'"), 1, "warned once")
	var e := "\n".join(lib.errors)
	assert_false(e.contains("sparkle") or e.contains("wiggle") or e.contains("must be"), "type problems are warnings: %s" % e)


func test_poselib_survives_garbage_files() -> void:
	var r := RigDef.for_id(RIG)
	for faces in [{"presets": []}, {"presets": {"x": "open"}}, {"presets": {"y": {}}, "gaze": 5}]:
		var lib := PoseLib.from_dicts(r, {"poses": {"a": {}}, "mirror_of": "nope"}, faces)
		assert_true(lib.has_pose("a"), "pose kept with faces %s" % [faces])


func test_anim_viewer_parses_every_flag() -> void:
	var av: Script = load("res://scenes/dev/anim_viewer.gd")
	var o: Dictionary = av.call("parse_args", PackedStringArray(["--rig=bellows", "--clip=rx_sneeze_blast_a", "--skin=pip",
		"--looks=SOAKED,FRAZZLED:blind", "--residue=STICKY", "--tint=2", "--tier=3", "--suppressed", "--frame=95", "--paused",
		"--facing=-1", "--speed=240", "--overlay=mg_preen", "--overlay-at=20", "--overlay-gap=10", "--room=kitchen",
		"--x=3300", "--station=st_tea", "--rig2=hush", "--clip2=lec_dangled", "--x2=180", "--facing2=1", "--skin2=pip",
		"--looks2=TOMATO", "--pose2=h_stand", "--attach2=hand_r:grip,braces_loop:grab", "--zoom=1.5", "--once", "--clean",
		"--sound", "--blips", "--no-juice", "--prop=specs:on,stool:hidden", "--part-tex=bouffant:flipped",
		"--shot=/tmp/x.png", "--frames=60", "--bogus=1"]))
	assert_eq(o["rig"], "bellows")
	assert_eq(o["clip"], "rx_sneeze_blast_a")
	assert_eq(o["skin"], "pip")
	assert_eq(o["looks"], PackedStringArray(["SOAKED", "FRAZZLED:blind", "STICKY"]))
	assert_eq(o["tint"], 2)
	assert_eq(o["tier"], 3)
	assert_true(o["suppressed"] and o["paused"] and o["once"] and o["clean"] and o["sound"] and o["blips"])
	assert_false(o["juice"])
	assert_eq(o["frame"], 95)
	assert_eq(o["facing"], -1)
	assert_almost_eq(float(o["speed"]), 240.0)
	assert_eq(o["overlay"], "mg_preen")
	assert_eq(o["overlay_at"], 20)
	assert_eq(o["overlay_gap"], 10)
	assert_eq(o["room"], "kitchen")
	assert_almost_eq(float(o["x"]), 3300.0)
	assert_eq(o["station"], "st_tea")
	assert_eq(o["rig2"], "hush")
	assert_eq(o["clip2"], "lec_dangled")
	assert_almost_eq(float(o["x2"]), 180.0)
	assert_eq(o["facing2"], 1)
	assert_eq(o["skin2"], "pip")
	assert_eq(o["looks2"], PackedStringArray(["TOMATO"]))
	assert_eq(o["pose2"], "h_stand")
	assert_eq(o["attach2"], PackedStringArray(["hand_r:grip", "braces_loop:grab"]))
	assert_almost_eq(float(o["zoom"]), 1.5)
	assert_eq(o["props"], PackedStringArray(["specs:on", "stool:hidden"]))
	assert_eq(o["part_tex"], PackedStringArray(["bouffant:flipped"]))
	assert_eq(o["unknown"], PackedStringArray(["--bogus=1"]), "DevShot / capture flags pass; typos are reported")
	var d: Dictionary = av.call("parse_args", PackedStringArray())
	assert_eq(d["rig"], "_mannequin")
	assert_true(is_nan(float(d["x"])), "no --x: the room centre")
	assert_true(bool(av.call("parse_args", PackedStringArray(["--help"]))["help"]))
	# Every flag is in --help.
	var usage: String = av.get_script_constant_map()["USAGE"]
	for flag in ["--rig=", "--clip=", "--pose=", "--skin=", "--looks=", "--tint=", "--tier=", "--suppressed", "--frame=",
			"--paused", "--facing=", "--speed=", "--overlay=", "--overlay-at=", "--overlay-gap=", "--room=", "--x=",
			"--station=", "--rig2=", "--clip2=", "--x2=", "--facing2=", "--skin2=", "--looks2=", "--pose2=", "--attach2=",
			"--zoom=", "--once", "--clean", "--sound", "--blips", "--no-juice", "--prop=", "--part-tex=", "--help"]:
		assert_has(usage, flag, "--help lists %s" % flag)


func test_anim_viewer_resolves_clip_args() -> void:
	var av: Script = load("res://scenes/dev/anim_viewer.gd")
	assert_eq(av.call("resolve_clip", "rx_take", RIG), "_mannequin/rx_take")
	assert_eq(av.call("resolve_clip", "bellows/rx_x", RIG), "bellows/rx_x")
	assert_eq(av.call("resolve_clip", "res://tests/rig/fixtures/real/bellows_mg_preen.json", "bellows"), "bellows/_fx_mg_preen",
		"a fixture file registers under its clip id")
	assert_true(ClipLib.get_clip("bellows/_fx_mg_preen") != null)
	ClipLib.invalidate("bellows/_fx_mg_preen")


func test_anim_viewer_room_backdrop_and_decor() -> void:
	var rb: Script = load("res://scenes/dev/room_backdrop.gd")
	var ids: PackedStringArray = rb.call("room_ids")
	if not ids.has("kitchen"):
		skip("house.json has no kitchen")
		return
	var back: Node2D = rb.new()
	assert_true(back.call("setup", "kitchen", false))
	assert_gt(float(back.x1), float(back.x0), "room extent")
	assert_false(back.call("setup", "no_such_room", false), "unknown room")
	back.call("setup", "kitchen", false)
	back.call("set_decor_visible", "kitchen_stool", false)
	assert_false(back.call("decor_visible", "kitchen_stool"))
	back.call("set_decor_visible", "kitchen_stool", true)
	assert_true(back.call("decor_visible", "kitchen_stool"))
	back.free()


func test_rig_perf_args_and_medians() -> void:
	var rp: Script = load("res://scenes/dev/rig_perf.gd")
	var o: Dictionary = rp.call("parse_args", PackedStringArray(["--rig=bellows", "--clip=rx_sneeze_blast_a", "--n=3",
		"--perf-log", "--warmup=10", "--looks=SOAKED"]))
	assert_eq(o["rig"], "bellows")
	assert_eq(o["clip"], "rx_sneeze_blast_a")
	assert_eq(o["n"], 3)
	assert_true(o["perf_log"])
	assert_eq(o["warmup"], 10)
	assert_eq(o["looks"], PackedStringArray(["SOAKED"]))
	var v := PackedFloat32Array([5.0, 1.0, 3.0, 2.0, 4.0, 100.0])
	assert_almost_eq(float(rp.call("median", v, 5)), 3.0, 0.0001, "odd count")
	assert_almost_eq(float(rp.call("median", v, 6)), 3.5, 0.0001, "even count")
	assert_almost_eq(float(rp.call("quantile", v, 6, 0.95)), 100.0, 0.0001)
	assert_eq(rp.call("resolve_clips", RIG, "rx_take", PackedStringArray()), PackedStringArray(["_mannequin/rx_take"]))
	var dflt: PackedStringArray = rp.call("resolve_clips", RIG, "", PackedStringArray())
	assert_true(dflt.has("_mannequin/loco_walk") and dflt.has("_mannequin/rx_take"), "default walk + take")
