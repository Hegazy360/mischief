## Art-hush data checks: Hush (+ Pip skin), Clarence, Figgis and the Stalls load cleanly and keep the
## binding names (TECH §4.7 / §14, GDD §1.2 / §9.2). The RigDef / PoseLib check is a soft hook: it runs
## when the rig system exists (res://view/rig/rig_def.gd) and is skipped otherwise.
extends TestBase

const HUSH := "res://data/rigs/hush/"
const FIGGIS := "res://data/rigs/figgis/"
const STALLS := "res://data/rigs/stalls/stalls.json"
const RIG_DEF := "res://view/rig/rig_def.gd"
const POSE_LIB := "res://view/rig/pose_lib.gd"

const PARTS: Array[String] = ["pelvis", "torso", "head", "beret", "hand_l", "hand_r", "foot_l", "foot_r",
	"arm_upper_l", "arm_upper_r", "arm_lower_l", "arm_lower_r", "leg_upper_l", "leg_upper_r",
	"leg_lower_l", "leg_lower_r"]
const GLOVES: Array[String] = ["wall", "point", "pinch", "fist", "open", "thumbs_up", "shush", "wave"]
const EYES: Array[String] = ["open", "half", "closed", "wide", "happy", "worried", "squint", "wink"]
const BROWS: Array[String] = ["neutral", "up", "worried", "sly", "determined"]
const MOUTHS: Array[String] = ["smile", "grin", "O", "shh", "grimace", "wavy", "laugh", "puffed"]
const PRESETS: Array[String] = ["neutral", "grin", "snicker", "shock", "fear", "hold_breath", "smug", "wince",
	"determined", "sad", "busted", "wink", "statue"]
const POSES: Array[String] = ["h_stand", "h_breath_in", "h_breath_out", "h_fidget_look", "h_tip_contact_l",
	"h_tip_pass_l", "h_tip_contact_r", "h_tip_pass_r", "h_run_contact_l", "h_run_pass_l", "h_run_contact_r",
	"h_run_pass_r", "h_turn_mid", "h_door_reach", "h_stairs_a", "h_stairs_b", "h_rummage_a", "h_rummage_b",
	"h_pickup", "h_tinker_q_a", "h_tinker_q_b", "h_tinker_s_a", "h_tinker_s_b", "h_tinker_b_a", "h_tinker_b_b",
	"h_brow_wipe", "h_snicker_a", "h_snicker_b", "h_glance_stalls", "h_dive_antic", "h_dive", "h_pop_out",
	"h_freeze_1", "h_freeze_2", "h_freeze_3", "h_freeze_4", "h_freeze_5", "h_freeze_6", "h_freeze_7",
	"h_freeze_8", "h_squeak", "h_climb_a", "h_climb_b", "h_busted", "h_dangled_a", "h_dangled_b",
	"h_doorstep_sit", "h_tomato_splat", "h_bow_a", "h_bow_b", "h_wink", "h_victory"]


func _hush() -> Dictionary:
	var d: Variant = load_json(HUSH + "rig.json")
	return d if d is Dictionary else {}


func test_json_files_parse() -> void:
	for p in [HUSH + "rig.json", HUSH + "poses.json", HUSH + "faces.json", FIGGIS + "rig.json",
			FIGGIS + "poses.json", FIGGIS + "faces.json", STALLS]:
		assert_true(load_json(p) is Dictionary, "%s parses to an object" % p)


func test_required_keys() -> void:
	var rig := _hush()
	for k in ["version", "rig", "height_px", "root_part", "origin", "parts", "limbs", "face", "props", "skins",
			"mirror_pairs"]:
		assert_has(rig, k, "rig.json has %s" % k)
	assert_eq(rig.get("rig", ""), "hush")
	assert_eq(rig.get("root_part", ""), "pelvis")
	assert_eq(int(rig.get("height_px", 0)), 340)
	var poses: Dictionary = load_json(HUSH + "poses.json")
	assert_has(poses, "poses")
	var faces: Dictionary = load_json(HUSH + "faces.json")
	assert_has(faces, "presets")


func test_binding_parts_and_counts() -> void:
	var parts: Dictionary = _hush().get("parts", {})
	assert_ge(parts.size(), 18, "at least 18 parts")
	for n in PARTS:
		assert_has(parts, n, "binding part %s" % n)
	for side in ["l", "r"]:
		var tex: Dictionary = (parts.get("hand_" + side, {}) as Dictionary).get("tex", {})
		assert_eq(tex.size(), 8, "hand_%s has 8 glove textures" % side)
		for g in GLOVES:
			assert_has(tex, g, "hand_%s glove %s" % [side, g])
		var ft: Dictionary = (parts.get("foot_" + side, {}) as Dictionary).get("tex", {})
		assert_has(ft, "flat")
		assert_has(ft, "tiptoe")
	var sp: Dictionary = (parts.get("beret", {}) as Dictionary).get("spring", {})
	assert_eq(sp.get("channel", ""), "rot")
	assert_eq(int(sp.get("k", 0)), 180)
	assert_eq(int(sp.get("c", 0)), 9)
	assert_eq(int(sp.get("clamp", 0)), 25)
	for sock in ["hand_r:grip", "hand_l:grip", "torso:braces", "head:hat"]:
		var bits := String(sock).split(":")
		var socks: Dictionary = (parts.get(bits[0], {}) as Dictionary).get("sockets", {})
		assert_has(socks, bits[1], "socket %s" % sock)


func test_face_slots() -> void:
	var slots: Dictionary = (_hush().get("face", {}) as Dictionary).get("slots", {})
	for pair in [["eyes", EYES], ["brows", BROWS], ["mouth", MOUTHS]]:
		var v: Dictionary = (slots.get(pair[0], {}) as Dictionary).get("variants", {})
		for n in pair[1]:
			assert_has(v, n, "%s variant %s" % [pair[0], n])
	assert_eq((slots.get("pupils", {}) as Dictionary).get("range", []), [6, 4], "pupil range")
	for o in ["blush", "sweat", "tear"]:
		assert_has(slots, o, "overlay slot %s" % o)


func test_poses_and_presets() -> void:
	var pd: Dictionary = load_json(HUSH + "poses.json")
	var poses: Dictionary = pd.get("poses", {})
	var mirror: Dictionary = pd.get("mirror_of", {})
	assert_ge(poses.size() + mirror.size(), 40, "at least 40 poses")
	for n in POSES:
		assert_true(poses.has(n) or mirror.has(n), "pose %s" % n)
	var parts: Dictionary = _hush().get("parts", {})
	for n in poses:
		var bones: Dictionary = (poses[n] as Dictionary).get("bones", {})
		for b in bones:
			assert_has(parts, b, "pose %s part %s exists" % [n, b])
	var presets: Dictionary = (load_json(HUSH + "faces.json") as Dictionary).get("presets", {})
	assert_ge(presets.size(), 12, "at least 12 face presets")
	for n in PRESETS:
		assert_has(presets, n, "preset %s" % n)


func test_every_file_exists() -> void:
	var paths := _collect_paths(_hush())
	assert_gt(paths.size(), 60, "rig references its textures")
	for p in paths:
		assert_true(FileAccess.file_exists(p), "file %s" % p)
	for p in _collect_paths(load_json(FIGGIS + "rig.json")):
		assert_true(FileAccess.file_exists(p), "figgis file %s" % p)


func test_pip_skin_parity() -> void:
	var pip: Dictionary = (_hush().get("skins", {}) as Dictionary).get("pip", {})
	var files: Dictionary = pip.get("files", {})
	assert_gt(files.size(), 20, "pip redraws the look")
	for base in files:
		var sk := String(files[base])
		assert_eq(sk.get_file(), String(base).get_file(), "pip keeps the file name of %s" % base)
		assert_true(FileAccess.file_exists(sk), "pip file %s" % sk)
		assert_eq(_svg_size(sk), _svg_size(String(base)), "pip canvas matches %s" % base)
	assert_eq(String(pip.get("dir", "")), "res://art/chars/hush/pip/")
	for lid in ["arm_l", "arm_r", "leg_l", "leg_r"]:
		assert_has(pip.get("limbs", {}), lid, "pip limb colour %s" % lid)


func test_clarence_and_hidden() -> void:
	var rig := _hush()
	var cl: Dictionary = (rig.get("props", {}) as Dictionary).get("clarence", {})
	for st in ["limp", "squeezed", "stretched", "smitten"]:
		assert_has(cl.get("tex", {}), st, "clarence state %s" % st)
	assert_eq(cl.get("socket", ""), "torso:braces")
	assert_true(FileAccess.file_exists(String((rig.get("hidden", {}) as Dictionary).get("file", ""))),
		"hidden_eyes.svg")


func test_figgis_and_stalls() -> void:
	var fr: Dictionary = load_json(FIGGIS + "rig.json")
	for n in ["hood", "head", "ear_l", "ear_r", "specs", "hand_l", "hand_r"]:
		assert_has(fr.get("parts", {}), n, "figgis part %s" % n)
	var fp: Dictionary = (load_json(FIGGIS + "faces.json") as Dictionary).get("presets", {})
	for n in ["psst", "point", "shh", "proud"]:
		assert_has(fp, n, "figgis preset %s" % n)
	var st: Dictionary = load_json(STALLS)
	var heads: Array = st.get("heads", [])
	assert_eq(heads.size(), 24, "24 Stalls heads")
	for h in heads:
		var hd: Dictionary = h
		assert_between(int(hd.get("h", 0)), 40, 110, "head %s height" % hd.get("id", "?"))
		for fr_name in ["rest", "laugh", "lean"]:
			var f := String((hd.get("frames", {}) as Dictionary).get(fr_name, ""))
			assert_true(FileAccess.file_exists(f), "stalls %s %s" % [hd.get("id", "?"), fr_name])
	assert_eq((st.get("tumble", []) as Array).size(), 4, "4 tumble frames")


func test_rig_system_loads_hush_and_figgis() -> void:
	if not ResourceLoader.exists(RIG_DEF) or not ResourceLoader.exists(POSE_LIB):
		skip("rig system (view/rig/rig_def.gd, pose_lib.gd) not built yet")
		return
	var rd: Script = load(RIG_DEF)
	var pl: Script = load(POSE_LIB)
	for base in [HUSH, FIGGIS]:
		var rig: Variant = rd.call("load", base + "rig.json")
		assert_true(rig != null, "RigDef.load %s" % base)
		if rig == null:
			continue
		var errs: PackedStringArray = rig.get("errors")
		assert_eq(errs.size(), 0, "RigDef errors for %s: %s" % [base, errs])
		var lib: Variant = pl.call("load", rig, base + "poses.json", base + "faces.json")
		var perrs: PackedStringArray = lib.get("errors")
		assert_eq(perrs.size(), 0, "PoseLib errors for %s: %s" % [base, perrs])
		if base == HUSH:
			assert_ge((lib.get("names") as PackedStringArray).size(), 40, "PoseLib resolves every Hush pose")


# --- helpers ---------------------------------------------------------------------------------------
func _collect_paths(rig: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not (rig is Dictionary):
		return out
	var r: Dictionary = rig
	for n in r.get("parts", {}):
		var p: Dictionary = r["parts"][n]
		if p.has("file"):
			out.append(String(p["file"]))
		for t in p.get("tex", {}):
			out.append(String(p["tex"][t]))
	for sn in (r.get("face", {}) as Dictionary).get("slots", {}):
		var s: Dictionary = r["face"]["slots"][sn]
		if s.has("file"):
			out.append(String(s["file"]))
		for v in s.get("variants", {}):
			out.append(String(s["variants"][v]))
	for pn in r.get("props", {}):
		for st in (r["props"][pn] as Dictionary).get("tex", {}):
			out.append(String(r["props"][pn]["tex"][st]))
	for rn in r.get("residues", {}):
		for pn2 in (r["residues"][rn] as Dictionary).get("overlays", {}):
			out.append(String(r["residues"][rn]["overlays"][pn2]))
	for k in ["file", "whites", "blink", "pupils"]:
		var hid: Dictionary = r.get("hidden", {})
		if hid.has(k):
			out.append(String(hid[k]))
	return out


func _svg_size(p: String) -> Vector2i:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return Vector2i.ZERO
	var head := f.get_buffer(256).get_string_from_utf8()
	var re := RegEx.new()
	re.compile("width=\"(\\d+)\" height=\"(\\d+)\"")
	var m := re.search(head)
	return Vector2i(int(m.get_string(1)), int(m.get_string(2))) if m else Vector2i.ZERO
