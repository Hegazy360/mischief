## Horace Bellows' 42 Gate-0 + Prologue clips on the 3D pipeline (brief r3d-anim-bellows §5; owner r3d-anim-bellows-a,
## lines for -b / -c on request): every Bellows row of `SliceClips.build3d(["g0_sneeze", "p00_curtain_up"])` is in the
## three keys' lists; every clip that exists parses, its `.res` loads, matches its expected length (or loops where
## allowed) and lints `--strict` clean; `bellows3d/map.json` keys are schema keys and resolve; the sneeze's accent (f 94:
## face swap, cam punch 1.4, hit-stop 5, the puff, the bouffant slot, the stool swap on 95); act_tea (480 f, the lid flip
## on the spoon contact, balanced lend / return pairs with every piece home before the loop ends) and THE SIP (act_tea
## f 420 = the sneeze's f 0, so the trigger never pops); no clip keys the `arm_out` layer by hand. A clip not made yet
## is a named skip with its owning key (never a failure mid-queue; r3d-integrate requires 0 skips).
extends TestBase

const L := preload("res://tools/anim/lint3d_rules.gd")
const CLIP_LIB := "res://view3d/char/clip_lib_3d.gd"
const SLICE := "res://view/world/slice_clips.gd"
const MAP := "res://data/anim/bellows3d/map.json"
const DIR := "res://data/anim/bellows3d/%s.json"
## clip -> owning key (index §5.3).
const OWNERS := {
	"rx_sneeze_blast_a": "a", "loco_idle": "a", "loco_strut": "a", "act_tea": "a", "act_warmup": "a",
	"loco_blind_shuffle": "a", "cc_wander_on": "a", "st_bonk": "a", "beat_slow_burn": "a", "loco_turn": "a",
	"loco_irked": "a", "act_fixup_mirror": "a",
	"bit_warmup": "b", "bit_tea": "b", "st_head_turn": "b", "st_double_take": "b", "st_specs_on": "b",
	"st_suspicious": "b", "st_look": "b", "st_look_back": "b", "st_smirk": "b", "st_straighten_cravat": "b",
	"mg_hum": "b", "mg_trill": "b", "mg_conduct_air": "b", "mg_admire_reflection_horn": "b", "mg_pinkie_up": "b",
	"mg_admire_in_kettle": "b", "mg_comb_flourish": "b", "mg_cravat_tug": "b", "mg_walk_hum": "b", "mg_walk_scale": "b",
	"rx_dizzy_spin_a": "c", "cue_doorframe_bonk": "c", "cue_picture_bonk": "c", "bit_livid": "c", "loco_stomp": "c",
	"act_hunt": "c", "mg_peer_under_piano": "c", "beat_dignity_fail": "c", "beat_bow_topple": "c", "beat_tear": "c"}
const TRIGGER_F := 420


func after_each() -> void:
	L.reset_caches()


static func _soft(path: String) -> Script:
	return load(path) as Script if ResourceLoader.exists(path) else null


static func _owner(short: String) -> String:
	return "r3d-anim-bellows-%s" % OWNERS.get(short, "?")


func _sidecar(short: String) -> Variant:
	var p := DIR % short
	if not FileAccess.file_exists(p):
		return null
	return TestBase.load_json(p)


func _made() -> PackedStringArray:
	var out := PackedStringArray()
	for short in OWNERS:
		if FileAccess.file_exists(DIR % short):
			out.append(String(short))
	return out


## The Bellows rows of the 3D manifest (g0 + p00), keyed by short name; {} when SliceClips.build3d is not there.
func _manifest() -> Dictionary:
	var sc := _soft(SLICE)
	if sc == null or not sc.has_method("build3d"):
		return {}
	var rows: Array = sc.call("build3d", PackedStringArray(["g0_sneeze", "p00_curtain_up"]))
	var out := {}
	for r in rows:
		var d: Dictionary = r
		if String(d.get("rig", "")) == "bellows":
			out[String(d.get("clip", "")).get_slice("/", 1)] = d
	return out


func _events(sc: Dictionary, type: String) -> Array:
	var out: Array = []
	for e in (sc.get("events", []) as Array):
		if String((e as Dictionary).get("type", "")) == type:
			out.append(e)
	return out


func test_the_manifest_rows_are_the_three_lists() -> void:
	var m := _manifest()
	if m.is_empty():
		skip("SliceClips.build3d not available — r3d-view3d")
		return
	for short in m:
		assert_true(OWNERS.has(short), "manifest row bellows/%s is on a key's list (index §5.3)" % short)
	assert_eq(OWNERS.size(), 42, "42 Bellows clips in the three lists")


func test_every_clip_of_the_42_is_made() -> void:
	var missing := {}
	for short in OWNERS:
		if not FileAccess.file_exists(DIR % short):
			var o := _owner(String(short))
			var have: PackedStringArray = missing.get(o, PackedStringArray())
			have.append(String(short))
			missing[o] = have
	if not missing.is_empty():
		var parts := PackedStringArray()
		for o in missing:
			parts.append("%s: %s" % [o, ", ".join(missing[o])])
		skip("not made yet — " + "; ".join(parts))
		return
	assert_eq(_made().size(), 42, "all 42 exist")


func test_sidecars_load_and_lengths_match() -> void:
	var made := _made()
	if made.is_empty():
		skip("no Bellows 3D clip made yet — r3d-anim-bellows-a")
		return
	var man := _manifest()
	var lib := _soft(CLIP_LIB)
	for short in made:
		var sc: Dictionary = _sidecar(short)
		var id := "bellows/" + short
		assert_eq(String(sc.get("clip", "")), id, "%s: clip id = its file" % short)
		assert_eq(int(sc.get("version", 0)), 2, "%s: sidecar v2" % short)
		var a := load(String(sc.get("anim", ""))) as Animation
		if not assert_true(a != null, "%s: the .res loads as an Animation" % short):
			continue
		var n := int(sc.get("length", 0))
		assert_almost_eq(a.length * 60.0, float(n), 0.01, "%s: Animation.length = length / 60" % short)
		if man.has(short):
			var row: Dictionary = man[short]
			var want := int(row.get("expect_f", -1))
			var tol := int(row.get("tol_f", 0))
			if want > 0 and not (bool(sc.get("loop", false)) and bool(row.get("loop_ok", false))):
				assert_between(n, want - tol, want + tol, "%s: %d f (manifest %d ± %d)" % [short, n, want, tol])
		if lib != null:
			lib.call("invalidate", id)
			assert_true(lib.call("get_clip", id) != null, "%s: ClipLib3D.get_clip" % id)
			var probs: PackedStringArray = lib.call("problems", id)
			assert_eq(probs.size(), 0, "%s: ClipLib3D problems %s" % [id, str(probs)])


func test_lint_strict_clean() -> void:
	var made := _made()
	if made.is_empty():
		skip("no Bellows 3D clip made yet — r3d-anim-bellows-a")
		return
	for short in made:
		var fs: Array = L.make_strict(L.lint_clip_id("bellows/" + short))
		var errs := PackedStringArray()
		for f in fs:
			if String((f as Dictionary)["severity"]) == "error":
				errs.append(L.format(f))
		assert_eq(errs.size(), 0, "bellows/%s lints --strict clean: %s" % [short, "\n".join(errs)])


func test_no_clip_keys_arm_out_by_hand() -> void:
	var made := _made()
	if made.is_empty():
		skip("no Bellows 3D clip made yet — r3d-anim-bellows-a")
		return
	for short in made:
		var src: Dictionary = (_sidecar(short) as Dictionary).get("source", {})
		var layers: Array = src.get("layers", []) if src.get("layers", null) is Array else []
		assert_false(layers.has("arm_out"), "%s: arm_out is the pipeline's default layer, never the clip's" % short)


func test_map_keys_are_schema_keys_and_resolve() -> void:
	var m: Variant = TestBase.load_json(MAP)
	if not assert_true(m is Dictionary, "bellows3d/map.json parses"):
		return
	var md: Dictionary = m
	assert_eq(String(md.get("rig", "")), "bellows", "map rig")
	var pending := PackedStringArray()
	for k: String in md:
		if ClipMap.META_KEYS.has(k):
			continue
		var fam := k.get_slice(":", 0) + ":*" if k.contains(":") else k
		assert_true(ClipMap.SCHEMA_KEYS.has(k) or ClipMap.SCHEMA_KEYS.has(fam), "map key %s is a schema key" % k)
		var e: Variant = md[k]
		var clip := String(e) if e is String else (String((e as Dictionary).get("clip", "")) if e is Dictionary else "")
		if clip == "" or clip == ClipMap.FROM_SIM:
			continue
		var short := clip.get_slice("/", 1)
		if FileAccess.file_exists(DIR % short):
			continue
		pending.append("%s → %s (%s)" % [k, clip, _owner(short)])
	var w: Variant = md.get("walk", null)
	if assert_true(w is Dictionary, "a walk entry"):
		assert_eq(int((w as Dictionary).get("speed_px_s", 0)), 240, "the strut at 240 px/s = 1.2 m/s (GDD §4.1)")
		assert_almost_eq(float((w as Dictionary).get("speed_m_s", 0.0)), 1.2, 0.001, "walk speed_m_s")
		var ws: Variant = _sidecar("loco_strut")
		if ws is Dictionary:
			assert_almost_eq(float((ws as Dictionary).get("speed_m_s", 0.0)), 1.2, 0.001, "loco_strut speed_m_s = the map's")
			assert_almost_eq(float((ws as Dictionary).get("stride_m", 0.0)), 0.64, 0.001, "loco_strut stride 0.64 m")
	if not pending.is_empty():
		skip("map rows whose clip is not made yet: " + "; ".join(pending))


func test_the_sneeze() -> void:
	var v: Variant = _sidecar("rx_sneeze_blast_a")
	if v == null:
		skip("rx_sneeze_blast_a not made yet — r3d-anim-bellows-a")
		return
	var sc: Dictionary = v
	assert_eq(int(sc["length"]), 165, "165 f (reactions.json sneeze_blast_a)")
	assert_eq(String(sc.get("lock", "")), "sim", "frame-locked to the sim")
	var beats: Dictionary = sc.get("beats", {})
	assert_eq(int((beats.get("accent", [0, 0]) as Array)[0]), 94, "accent beat at f94")
	var pops: Array = (sc.get("lint", {}) as Dictionary).get("pop_frames", [])
	var pop94 := false
	for pf in pops:
		pop94 = pop94 or int(pf) == 94
	assert_true(pop94, "the CHOO pops on f94 (lint.pop_frames %s)" % str(pops))
	var face_ok := false
	for fe in (sc.get("face", []) as Array):
		if int((fe as Dictionary).get("f", -1)) == 94 and String((fe as Dictionary).get("preset", "")) == "sneeze_choo":
			face_ok = true
	assert_true(face_ok, "sneeze_choo face on f94")
	var punch := false
	for e in _events(sc, "cam"):
		if String((e as Dictionary).get("op", "")) == "punch" and int((e as Dictionary)["f"]) == 94:
			punch = is_equal_approx(float((e as Dictionary).get("zoom", 0.0)), 1.4)
	assert_true(punch, "cam punch 1.4 on f94")
	var hs := false
	for e2 in _events(sc, "hitstop"):
		hs = hs or (int((e2 as Dictionary)["f"]) == 94 and int((e2 as Dictionary).get("frames", 0)) == 5)
	assert_true(hs, "hit-stop 5 on f94")
	var puff := false
	for e3 in _events(sc, "fx"):
		puff = puff or (int((e3 as Dictionary)["f"]) == 94 and String((e3 as Dictionary).get("id", "")) == "choo_puff")
	assert_true(puff, "the choo_puff on f94")
	var look := false
	for e4 in _events(sc, "look"):
		var st: Dictionary = (e4 as Dictionary).get("set", {})
		look = look or (int((e4 as Dictionary)["f"]) == 94 and String(st.get("bouffant", "")) == "flipped")
	assert_true(look, "look bouffant: flipped on f94 (the body slot)")
	var decor_hidden := false
	for e5 in _events(sc, "decor"):
		var d5: Dictionary = e5
		decor_hidden = decor_hidden or (int(d5["f"]) == 95 and String(d5.get("id", "")) == "kitchen_stool" and d5.get("visible", true) == false)
	assert_true(decor_hidden, "the set's kitchen_stool hidden on f95")
	var stool := false
	for e6 in _events(sc, "prop"):
		var d6: Dictionary = e6
		stool = stool or (int(d6["f"]) == 95 and String(d6.get("op", "")) == "show" and String(d6.get("prop", "")) == "stool")
	assert_true(stool, "the ride-along stool attachment shown on f95")
	var marks := {}
	for e7 in _events(sc, "mark"):
		marks[String((e7 as Dictionary).get("name", ""))] = int((e7 as Dictionary)["f"])
	assert_eq(int(marks.get("knock_on", -1)), 112, "knock_on mark f112")
	assert_eq(int(marks.get("release", -1)), 165, "release mark f165")
	assert_eq(_events(sc, "laugh").size(), 0, "laughs are event-level, not in the clip")


func test_tea_hand_offs_and_lid_flip() -> void:
	var v: Variant = _sidecar("act_tea")
	if v == null:
		skip("act_tea not made yet — r3d-anim-bellows-a")
		return
	var sc: Dictionary = v
	assert_eq(int(sc["length"]), 480, "act_tea 480 f (the audio table's row)")
	assert_true(bool(sc.get("loop", false)), "act_tea loops")
	var lid := false
	for e in _events(sc, "set_anim"):
		lid = lid or (String((e as Dictionary).get("hotspot", "")) == "kitchen_honey" and String((e as Dictionary).get("anim", "")) == "lid_flip")
	assert_true(lid, "the honey jar's lid flips on the spoon contact (set_anim lid_flip)")
	var lent := {}
	var n := int(sc["length"])
	var props := _events(sc, "prop")
	props.sort_custom(func(a, b): return int(a["f"]) < int(b["f"]))
	for e2 in props:
		var d: Dictionary = e2
		var pid := String(d.get("prop", ""))
		if not pid.begins_with("set:"):
			continue
		var op := String(d.get("op", ""))
		if op == "lend":
			assert_false(lent.has(pid), "%s lent twice without a return" % pid)
			lent[pid] = int(d["f"])
		elif op == "return":
			assert_true(lent.has(pid), "%s returned at f%d without a lend" % [pid, int(d["f"])])
			assert_le(int(d["f"]) + int(d.get("frames", 6)), n, "%s is home by the loop's end" % pid)
			lent.erase(pid)
	assert_eq(lent.size(), 0, "every lent piece goes home (%s)" % str(lent.keys()))
	for want in ["set:kitchen_kettle", "set:kitchen_honey"]:
		var seen := false
		for e3 in props:
			seen = seen or String((e3 as Dictionary).get("prop", "")) == want
		assert_true(seen, "%s comes to his hand (R5e)" % want)


## THE SIP: act_tea at ACHOO-RIA!'s trigger frame is the sneeze's frame 0 on every body bone (≤ 1.5°).
func test_the_sip_is_continuous_into_the_sneeze() -> void:
	var t: Variant = _sidecar("act_tea")
	var s: Variant = _sidecar("rx_sneeze_blast_a")
	if t == null or s == null:
		skip("act_tea / rx_sneeze_blast_a not both made yet — r3d-anim-bellows-a")
		return
	var at := load(String((t as Dictionary)["anim"])) as Animation
	var an := load(String((s as Dictionary)["anim"])) as Animation
	if not assert_true(at != null and an != null, "both .res load"):
		return
	var tea_rot := {}
	for i in at.get_track_count():
		if at.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			tea_rot[String(at.track_get_path(i)).get_slice(":", 1)] = at.rotation_track_interpolate(i, float(TRIGGER_F) / 60.0)
	var ual := L.ual_bones()
	var worst := 0.0
	var worst_b := ""
	for j in an.get_track_count():
		if an.track_get_type(j) != Animation.TYPE_ROTATION_3D:
			continue
		var b := String(an.track_get_path(j)).get_slice(":", 1)
		if not ual.has(b) or not tea_rot.has(b):
			continue
		var d := rad_to_deg((tea_rot[b] as Quaternion).angle_to(an.rotation_track_interpolate(j, 0.0)))
		if d > worst:
			worst = d
			worst_b = b
	assert_le(worst, 1.5, "act_tea f%d = rx_sneeze_blast_a f0 (worst %s %.2f°)" % [TRIGGER_F, worst_b, worst])
