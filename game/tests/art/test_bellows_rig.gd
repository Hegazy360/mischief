## Bellows rig data: rig.json / poses.json / faces.json parse, carry the binding names (GDD §9.2, TECH §4.7),
## reference files that exist, and (soft hook) load through the rig module's RigDef + PoseLib with zero errors.
extends TestBase

const DIR := "res://data/rigs/bellows/"
const RIG_DEF := "res://view/rig/rig_def.gd"
const POSE_LIB := "res://view/rig/pose_lib.gd"

const BOUFFANT: Array[String] = ["neat", "flipped", "frazzled", "wet", "floured", "feathered", "poodle"]
const HANDS: Array[String] = ["open", "fist", "point", "grip", "wag", "conduct"]
const EYES: Array[String] = ["open", "half", "closed", "wide", "pinpoint", "angry", "spiral", "balloon", "squint", "teary"]
const BROWS: Array[String] = ["neutral", "up", "angry", "worried", "sly", "one_up"]
const MOUTHS: Array[String] = ["closed", "smile", "smug", "O_small", "O_mid", "O_big", "scream", "grit", "wavy", "open"]
const OVERLAYS: Array[String] = ["sweat", "vein", "steam_l", "steam_r", "blush"]
const PRESETS: Array[String] = ["neutral", "smug", "sing_small", "sing_mid", "sing_big", "suspicious", "shock",
	"wild_take", "furious", "sneeze_build", "sneeze_choo", "dazed", "slow_burn", "strained_grin", "sulk", "terrified",
	"asleep", "blissful"]
const RESIDUES: Array[String] = ["SOAKED", "FLOURY", "STICKY", "SQUEAKY", "FRAZZLED", "FEATHERED", "COSTUME"]
const COSTUMES: Array[String] = ["jelly_helmet", "tutu_tulle", "tutu_chandelier", "trophy_helmet", "long_johns",
	"hedge_twigs", "umbrella_stand"]
const COMBOS: Array[String] = ["dough_man", "poodle", "chicken", "mad_maestro"]
const PROPS: Array[String] = ["specs", "teacup", "newspaper", "comb", "baton", "phone_handset", "kipper_held",
	"pickled_onion", "kettle_lid", "jelly_helmet", "sausage_boa", "megaphone"]
const P0_POSES: Array[String] = ["b_stand", "b_breath_in", "b_breath_out", "b_fidget_admire", "b_strut_contact_l",
	"b_strut_pass_l", "b_strut_contact_r", "b_strut_pass_r", "b_irked_walk_a", "b_irked_walk_b", "b_stomp_a", "b_stomp_b",
	"b_turn_mid", "b_door_reach", "b_stairs_a", "b_stairs_b", "b_sing_breath", "b_sing_small", "b_sing_big", "b_tea_pour",
	"b_tea_spoon", "b_tea_sip", "b_tea_sniff", "b_jar_strain", "b_fridge_reach", "b_sink_hands", "b_sit_read",
	"b_lever_pull", "b_bellows_pump", "b_preen", "b_lean_in", "b_specs_lift", "b_phone_pompous", "b_clock_wind",
	"b_hunt_peer_l", "b_hunt_peer_r", "b_suspicious", "b_dt_away", "b_dt_back", "b_take_antic", "b_take_accent",
	"b_look_behind", "b_chase_a", "b_chase_b", "b_wheeze", "b_grab", "b_lecture_hold", "b_lecture_wag_a",
	"b_lecture_wag_b", "b_melt_stomp_up", "b_melt_stomp_down", "b_exhausted_sit", "b_slow_burn",
	"b_dignity_straighten", "b_pardon_pat", "b_bonk_door", "b_sneeze_ah1", "b_sneeze_ah2", "b_sneeze_ah3",
	"b_sneeze_false_stop", "b_sneeze_choo", "b_sneeze_recoil", "b_dazed_sit", "b_dizzy_a", "b_dizzy_b", "b_launched",
	"b_dangle", "b_slip_windmill", "b_fall_sit", "b_blind_arms_out", "b_fish_slap_recoil", "b_cling"]


func _rig() -> Dictionary:
	var d: Variant = load_json(DIR + "rig.json")
	return d if d is Dictionary else {}


func _poses() -> Dictionary:
	var d: Variant = load_json(DIR + "poses.json")
	return d if d is Dictionary else {}


func _faces() -> Dictionary:
	var d: Variant = load_json(DIR + "faces.json")
	return d if d is Dictionary else {}


func _pose_names(poses: Dictionary) -> Array:
	var names: Array = (poses.get("poses", {}) as Dictionary).keys()
	for k: Variant in (poses.get("mirror_of", {}) as Dictionary).keys():
		if not names.has(k):
			names.append(k)
	return names


func test_json_parses_with_required_keys() -> void:
	var rig := _rig()
	for k: String in ["version", "rig", "height_px", "root_part", "origin", "parts", "limbs", "face", "residues",
			"combos", "tint", "props", "mirror_pairs"]:
		assert_has(rig, k, "rig.json key " + k)
	assert_eq(rig.get("rig"), "bellows")
	assert_eq(rig.get("origin"), "feet")
	assert_eq(int(rig.get("height_px", 0)), 380)
	assert_has(rig.get("parts", {}), rig.get("root_part", "?"), "root_part is a part")
	assert_has(_poses(), "poses")
	assert_has(_faces(), "presets")


func test_every_referenced_file_exists() -> void:
	var rig := _rig()
	var files: Array[String] = []
	for pn: String in rig.get("parts", {}):
		var e: Dictionary = rig["parts"][pn]
		if e.has("file"):
			files.append(e["file"])
		for t: String in e.get("tex", {}):
			files.append(e["tex"][t])
	var slots: Dictionary = rig.get("face", {}).get("slots", {})
	for s: String in slots:
		var sd: Dictionary = slots[s]
		if sd.has("file"):
			files.append(sd["file"])
		for v: String in sd.get("variants", {}):
			files.append(sd["variants"][v])
	for pn: String in rig.get("props", {}):
		var pd: Dictionary = rig["props"][pn]
		files.append(pd.get("file", ""))
		for t: String in pd.get("tex", {}):
			files.append(pd["tex"][t])
	var looks: Array = []
	for k: String in rig.get("residues", {}):
		if k == "COSTUME":
			for v: String in rig["residues"][k].get("variants", {}):
				looks.append(rig["residues"][k]["variants"][v])
		else:
			looks.append(rig["residues"][k])
	for c: String in rig.get("combos", {}):
		looks.append(rig["combos"][c])
	for lk: Dictionary in looks:
		for pn: String in lk.get("overlays", {}):
			var ov: Variant = lk["overlays"][pn]
			if ov is Array:
				for f: String in ov:
					files.append(f)
			else:
				files.append(str(ov))
	assert_gt(files.size(), 120, "file references")
	for f: String in files:
		assert_true(f.begins_with("res://") and FileAccess.file_exists(f), "file exists: " + f)


func test_parts_and_textures() -> void:
	var parts: Dictionary = _rig().get("parts", {})
	assert_ge(parts.size(), 20, "part count")
	for p: String in ["torso", "belly", "coat_tails", "cravat", "head", "bouffant", "sideburn_l", "sideburn_r"]:
		assert_has(parts, p)
	var bt: Dictionary = parts.get("bouffant", {}).get("tex", {})
	assert_eq(bt.size(), 7, "bouffant textures")
	for t in BOUFFANT:
		assert_has(bt, t, "bouffant " + t)
	for side: String in ["l", "r"]:
		var ht: Dictionary = parts.get("hand_" + side, {}).get("tex", {})
		for t in HANDS:
			assert_has(ht, t, "hand_%s %s" % [side, t])
		assert_has(parts.get("hand_" + side, {}).get("sockets", {}), "grip")
		for t: String in ["flat", "tiptoe"]:
			assert_has(parts.get("foot_" + side, {}).get("tex", {}), t)
		for t: String in ["flat", "bristle", "puffed", "wet"]:
			assert_has(parts.get("sideburn_" + side, {}).get("tex", {}), t)
	assert_eq(parts.get("belly", {}).get("spring", {}).get("channel"), "sy")
	assert_has(parts.get("head", {}).get("sockets", {}), "specs")
	assert_has(parts.get("head", {}).get("sockets", {}), "hat")
	assert_has(parts.get("torso", {}).get("sockets", {}), "chain")
	for lid: String in _rig().get("limbs", {}):
		var w: float = _rig()["limbs"][lid].get("width", 0)
		assert_between(w, 26.0, 30.0, "limb width " + lid)


func test_face_slots() -> void:
	var slots: Dictionary = _rig().get("face", {}).get("slots", {})
	var eyes: Dictionary = slots.get("eyes", {}).get("variants", {})
	var brows: Dictionary = slots.get("brows", {}).get("variants", {})
	var mouth: Dictionary = slots.get("mouth", {}).get("variants", {})
	assert_ge(eyes.size(), 10)
	assert_ge(brows.size(), 6)
	assert_ge(mouth.size(), 10)
	for e in EYES:
		assert_has(eyes, e, "eyes " + e)
	for b in BROWS:
		assert_has(brows, b, "brows " + b)
	for m in MOUTHS:
		assert_has(mouth, m, "mouth " + m)
	assert_eq(slots.get("pupils", {}).get("range"), [6, 4])
	for o in OVERLAYS:
		assert_true(slots.get(o, {}).get("overlay", false), "overlay " + o)
		assert_eq(slots.get(o, {}).get("default"), "none", "overlay %s hidden at rest" % o)


func test_presets() -> void:
	var presets: Dictionary = _faces().get("presets", {})
	assert_ge(presets.size(), 16)
	var slots: Dictionary = _rig().get("face", {}).get("slots", {})
	for p in PRESETS:
		assert_has(presets, p, "preset " + p)
	for n: String in presets:
		var pr: Dictionary = presets[n]
		for s: String in ["eyes", "brows", "mouth"]:
			assert_has(slots.get(s, {}).get("variants", {}), pr.get(s, "?"), "%s.%s" % [n, s])
		for s: String in pr:
			assert_has(slots, s, "%s: %s is a face slot" % [n, s])


func test_poses() -> void:
	var poses := _poses()
	var names := _pose_names(poses)
	assert_ge(names.size(), 50, "pose count")
	for p in P0_POSES:
		assert_has(names, p, "pose " + p)
	var parts: Dictionary = _rig().get("parts", {})
	var presets: Dictionary = _faces().get("presets", {})
	for n: String in poses.get("poses", {}):
		var pd: Dictionary = poses["poses"][n]
		for b: String in pd.get("bones", {}):
			assert_has(parts, b, "%s bone %s" % [n, b])
		if pd.has("face"):
			assert_has(presets, pd["face"], "%s face" % n)
		if pd.has("base"):
			assert_has(names, pd["base"], "%s base" % n)
		var tags: Array = pd.get("tags", [])
		if tags.has("take") or tags.has("reaction"):
			assert_ne(str(pd.get("silhouette", "")), "", "%s silhouette note" % n)


func test_residues_costumes_combos() -> void:
	var rig := _rig()
	var res: Dictionary = rig.get("residues", {})
	for r in RESIDUES:
		assert_has(res, r, "residue " + r)
	var variants: Dictionary = res.get("COSTUME", {}).get("variants", {})
	for c in COSTUMES:
		assert_has(variants, c, "costume " + c)
	for c in COSTUMES:
		assert_has(res, "COSTUME:" + c, "flat residue key COSTUME:" + c)
	var combos: Dictionary = rig.get("combos", {})
	for c in COMBOS:
		assert_has(combos, c, "combo " + c)
		assert_has(res, "COMBO:" + c, "flat residue key COMBO:" + c)
		assert_eq((combos.get(c, {}).get("of", []) as Array).size(), 2, c + " is two residues")
	assert_eq(res.get("SOAKED", {}).get("tex", {}).get("bouffant"), "wet")
	assert_eq(combos.get("poodle", {}).get("tex", {}).get("bouffant"), "poodle")
	for p in PROPS:
		assert_has(rig.get("props", {}), p, "prop " + p)
	var tint: Dictionary = rig.get("tint", {})
	assert_eq((tint.get("tiers", []) as Array).size(), 4, "4 temper tints")
	for p: String in ["head", "hand_l", "hand_r"]:
		assert_has(tint.get("parts", []), p)


func test_rig_module_loads_without_errors() -> void:
	if not ResourceLoader.exists(RIG_DEF) or not ResourceLoader.exists(POSE_LIB):
		skip("rig module (view/rig/rig_def.gd, pose_lib.gd) not built yet")
		return
	var rd: Script = load(RIG_DEF) as Script
	var pl: Script = load(POSE_LIB) as Script
	if rd == null or pl == null:
		fail("rig module scripts failed to load")
		return
	var rig: Variant = rd.call("load", DIR + "rig.json")
	if not assert_true(rig != null, "RigDef.load(bellows) returned a RigDef"):
		return
	_assert_no_errors(rig, "RigDef")
	var lib: Variant = pl.call("load", rig, DIR + "poses.json", DIR + "faces.json")
	if not assert_true(lib != null, "PoseLib.load(bellows) returned a PoseLib"):
		return
	_assert_no_errors(lib, "PoseLib")


func _assert_no_errors(obj: Variant, what: String) -> void:
	if obj is Object:
		var o: Object = obj
		if o.has_method("get_errors"):
			assert_eq((o.call("get_errors") as Array).size(), 0, what + " errors: %s" % [o.call("get_errors")])
		elif "errors" in o:
			var errs: Variant = o.get("errors")
			if errs is Array or errs is PackedStringArray:
				assert_eq((errs as Array).size() if errs is Array else (errs as PackedStringArray).size(), 0,
					what + " errors: %s" % [errs])


# --- Stage 2 (s2-anim-bellows Phase G): rig keys, the stool, the sip cup, the sneeze poses ------------------

func test_rig_requests_breath_look_masks() -> void:
	var rig := _rig()
	var parts: Dictionary = rig.get("parts", {})
	var br: Dictionary = rig.get("breath", {})
	assert_eq(br.get("part"), "belly", "breathing on the belly (rig request RIG-11)")
	assert_almost_eq(float(br.get("amp", 0)), 0.025, 0.0001)
	assert_almost_eq(float(br.get("period_s", 0)), 4.0, 0.0001)
	var lk: Dictionary = rig.get("look", {})
	assert_eq(lk.get("part"), "head", "look on the head (RIG-12)")
	assert_eq(int(lk.get("max_deg", 0)), 20)
	var masks: Dictionary = rig.get("masks", {})
	for m: String in ["upper", "arms", "head"]:
		assert_has(masks, m, "mask " + m)
	var slots: Dictionary = rig.get("face", {}).get("slots", {})
	for m: String in masks:
		for p: String in masks[m]:
			var ok := parts.has(p) or (p.begins_with("face_") and slots.has(p.substr(5)))
			assert_true(ok, "mask %s: %s is a part or face slot" % [m, p])
	var upper: Array = masks.get("upper", [])
	for p: String in ["head", "nose", "bouffant", "sideburn_r", "sideburn_l", "cravat", "arm_upper_r", "hand_r",
			"arm_upper_l", "hand_l", "face_eyes", "face_mouth"]:
		assert_has(upper, p, "upper mask has " + p)
	for p: String in ["torso", "belly", "leg_upper_r", "leg_upper_l", "foot_r", "foot_l", "coat_tails"]:
		assert_false(upper.has(p), "upper mask never touches " + p)


func test_stool_prop_matches_the_house_stool() -> void:
	var rig := _rig()
	var st: Dictionary = rig.get("props", {}).get("stool", {})
	assert_false(st.is_empty(), "stool prop")
	assert_eq(st.get("states"), ["under", "flying"], "stool states")
	assert_eq(st.get("socket"), "torso:seat")
	assert_true(bool(st.get("hidden", false)), "hidden until the sneeze shows it")
	assert_has(rig.get("parts", {}).get("torso", {}).get("sockets", {}), "seat")
	var house: Variant = load_json("res://data/house/house.json")
	var decor := {}
	if house is Dictionary:
		for d: Dictionary in (house as Dictionary).get("decor", []):
			if String(d.get("id", "")) == "kitchen_stool":
				decor = d
	if decor.is_empty():
		skip("house.json has no kitchen_stool decor")
		return
	# same canvas as the house decor (s2-art contract 94 x 163): the prop drawn by a facing -1 rig covers the decor
	assert_eq(st.get("size"), [int(decor["size"][0]), int(decor["size"][1])], "prop canvas = decor canvas")
	# the socket puts the stool's cushion (seat pivot) under the barrel's seat point: pivot - seat = 68 px
	var seat: Array = (decor.get("pivots", {}) as Dictionary).get("seat", [47, 6])
	assert_almost_eq(float(st["pivot"][0]), float(seat[0]), 0.01, "pivot on the centre line")
	var tsock: Array = rig["parts"]["torso"]["sockets"]["seat"]
	var tpiv: Array = rig["parts"]["torso"]["pivot"]
	assert_almost_eq(float(tsock[1]) - float(tpiv[1]), 25.0 + float(st["pivot"][1]) - float(seat[1]), 0.1,
		"torso:seat = barrel bottom + (stool pivot - cushion)")
	for s: String in ["under", "flying"]:
		assert_true(FileAccess.file_exists(String(st["tex"][s])), "stool " + s + " texture")


func test_teacup_sip_state_and_stage2_faces() -> void:
	var tc: Dictionary = _rig().get("props", {}).get("teacup", {})
	assert_eq(tc.get("states"), ["held", "sip"], "teacup held / sip (mirrored: handle forward, mouth clear)")
	var presets: Dictionary = _faces().get("presets", {})
	for p: String in ["sneeze_build3", "sneeze_gasp", "sip", "relief", "dazed_open", "kiss", "trill", "sly_smile", "hum"]:
		assert_has(presets, p, "preset " + p)


func test_sneeze_and_stool_poses() -> void:
	var names := _pose_names(_poses())
	for p: String in ["b_stool_sit", "b_stool_sip", "b_stool_ahh", "b_stool_ah1", "b_stool_ah2", "b_stool_ah3",
			"b_stool_relief", "b_stool_resip", "b_stool_hup", "b_stool_choo", "b_fly_a", "b_fly_b", "b_sink_land",
			"b_sink_sit", "b_sink_sip", "b_sink_dunk", "b_sink_pop", "b_blind_land", "b_blind_stand", "b_idle_lapel",
			"b_strut_0", "b_strut_m0", "b_shuffle_0", "b_shuffle_m0", "b_bonk_flat", "b_blind_bonk", "b_turn_hmph"]:
		assert_has(names, p, "pose " + p)
	# the sip / "Ahhh" poses hand the stool socket to the decor: dead upright root and torso
	var poses: Dictionary = _poses().get("poses", {})
	for p: String in ["b_stool_sip", "b_stool_ahh"]:
		var pd: Dictionary = poses.get(p, {})
		assert_eq(float(pd.get("root", {}).get("rot", 99)), 0.0, p + " root rot 0")
		assert_eq(float(pd.get("bones", {}).get("torso", {}).get("rot", 0)), 0.0, p + " torso rot 0")


func test_sneeze_accent_changes_the_silhouette() -> void:
	## The CHOO is no longer a flat lunge: HUP (tall, compact, f93) -> CHOO -> blown back (f97, the accent's end)
	## changes the bounding box by >= 15 % (GDD §9.3, lint A18; validate.py checks the HUP -> CHOO ink bbox too).
	var c := ClipLib.get_clip("bellows/rx_sneeze_blast_a")
	if c == null:
		skip("the sneeze clip is not authored")
		return
	var rig := c.rig
	var a := rig.rest.duplicate()
	var b := rig.rest.duplicate()
	RigSampler.sample(c, float(c.beat("accent").x - 1), a)
	RigSampler.sample(c, float(c.beat("accent").y), b)
	var xa: Array[Transform2D] = []
	var xb: Array[Transform2D] = []
	RigSampler.solve(rig, a, xa)
	RigSampler.solve(rig, b, xb)
	var ba := RigBounds.bbox(rig, a, xa)
	var bb := RigBounds.bbox(rig, b, xb)
	var ch := maxf(absf(bb.size.x - ba.size.x) / ba.size.x, absf(bb.size.y - ba.size.y) / ba.size.y)
	ch = maxf(ch, absf(bb.get_area() - ba.get_area()) / ba.get_area())
	assert_ge(ch, 0.15, "anticipation -> accent bbox change %.0f %%" % (ch * 100.0))


func test_tiptoe_slippers_stay_on_the_floor() -> void:
	## RIG-13: the tutu costumes swap flat -> tiptoe slippers on any pose. The tiptoe slipper is drawn on pointe
	## with its tip at the flat sole's depth (tools/art/bellows/parts_body.py FOOT_SOLE; validate.py checks the
	## planted poses), on the same canvas as the flat one, so the lint's sole line is the same for both.
	var rig := _rig()
	for side: String in ["r", "l"]:
		var fp: Dictionary = rig.get("parts", {}).get("foot_" + side, {})
		assert_has(fp.get("tex", {}), "tiptoe")
		assert_eq(_svg_size(String(fp["tex"]["flat"])), _svg_size(String(fp["tex"]["tiptoe"])),
			"foot_%s flat / tiptoe share one canvas" % side)


func _svg_size(path: String) -> String:
	var t := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("width=\"([0-9.]+)\" height=\"([0-9.]+)\"")
	var m := re.search(t)
	return "%sx%s" % [m.get_string(1), m.get_string(2)] if m != null else ""
