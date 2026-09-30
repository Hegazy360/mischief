## r3d-anim's 17 Hush clips on the 3D pipeline (brief §4.2 / §5): every clip of the list parses through ClipLib3D,
## its `.res` loads, matches its expected length (or loops), lints `--strict` clean and carries its audio source;
## `hush3d/map.json` keys resolve to clips that exist; the walk / run gaits match their sidecars; the statues snap on
## f 5 and hold; the rig clips are `rig_pm`, cheat ≤ 10 and staged (stage.facing); ACHOO-RIA!'s pepper pot reaches the
## PLACED reach target at the three shakes (the pot's spout — fx_pepper, riding rigidly on her glove — within 0.03 m
## of house3d.json kitchen_honey's reach_target = the jar's mouth, through RigSampler3D + the sidecar's stage) and
## ALLEGRO-GO-GO!'s right glove is on the lever's knob before the yank. A clip not made yet is a named skip.
extends TestBase

const L := preload("res://tools/anim/lint3d_rules.gd")
const CLIP_LIB := "res://view3d/char/clip_lib_3d.gd"
const OWNER := "r3d-anim"
## clip -> expected frames (-1 = a loop, any length).
const LIST := {"loco_idle": -1, "loco_walk": -1, "rig_achoo_ria": 48, "rig_step_down": 8, "act_snicker": 60,
	"act_dive": 15, "act_pop": 15, "freeze_1": 150, "freeze_2": 150, "freeze_3": 150, "freeze_4": 150,
	"act_squeak": 18, "loco_run": -1, "loco_turn": 6, "act_climb_in": 60, "rig_allegro_go_go": 48, "act_bow": -1}
## the audio-table clips (R3: the row's events copied, len_f checked) vs the retimed ones (rows in audio_rows.md)
const TABLE_AUDIO: PackedStringArray = ["act_snicker", "act_dive", "act_pop", "freeze_1", "freeze_2", "freeze_3",
	"freeze_4", "act_squeak", "loco_run", "act_climb_in"]
const SHAKES: Array[int] = [16, 26, 36]
const SPOUT_TOL_M := 0.03


func after_each() -> void:
	L.reset_caches()


static func _soft(path: String) -> Script:
	return load(path) as Script if ResourceLoader.exists(path) else null


func _sidecar(short: String) -> Variant:
	var p := "res://data/anim/hush3d/%s.json" % short
	if not FileAccess.file_exists(p):
		return null
	return TestBase.load_json(p)


func _made() -> PackedStringArray:
	var out := PackedStringArray()
	for short in LIST:
		if FileAccess.file_exists("res://data/anim/hush3d/%s.json" % short):
			out.append(String(short))
	return out


func test_every_clip_of_the_list_is_made() -> void:
	var missing := PackedStringArray()
	for short in LIST:
		if not FileAccess.file_exists("res://data/anim/hush3d/%s.json" % short):
			missing.append(String(short))
	if not missing.is_empty():
		skip("%s not made yet — %s" % [", ".join(missing), OWNER])
		return
	assert_eq(_made().size(), LIST.size(), "all 17 clips of the list exist")


func test_sidecars_load_and_lengths_match() -> void:
	var made := _made()
	if made.is_empty():
		skip("no clip of the list made yet — %s" % OWNER)
		return
	var lib := _soft(CLIP_LIB)
	for short in made:
		var sc: Dictionary = _sidecar(short)
		var id := "hush/" + short
		assert_eq(String(sc.get("clip", "")), id, "%s: clip id = its file" % short)
		assert_eq(int(sc.get("version", 0)), 2, "%s: sidecar v2" % short)
		assert_false(bool((sc.get("lint", {}) as Dictionary).get("draft", false)), "%s: FINAL (R19: no drafts)" % short)
		var a := load(String(sc.get("anim", ""))) as Animation
		if not assert_true(a != null, "%s: the .res loads as an Animation" % short):
			continue
		var n := int(sc.get("length", 0))
		assert_almost_eq(a.length * 60.0, float(n), 0.01, "%s: Animation.length = length / 60" % short)
		var want := int(LIST[short])
		if want > 0:
			assert_eq(n, want, "%s: %d f" % [short, want])
			assert_false(bool(sc.get("loop", false)), "%s: plays once" % short)
		else:
			assert_true(bool(sc.get("loop", false)), "%s: a loop" % short)
		var src: Dictionary = sc.get("source", {})
		var audio := String(src.get("audio", ""))
		assert_eq(audio, "table" if TABLE_AUDIO.has(short) else "own", "%s: audio source" % short)
		if lib != null:
			lib.call("invalidate", id)
			assert_true(lib.call("get_clip", id) != null, "%s: ClipLib3D.get_clip" % id)
			var probs: PackedStringArray = lib.call("problems", id)
			assert_eq(probs.size(), 0, "%s: ClipLib3D problems %s" % [id, str(probs)])


func test_lint_strict_clean() -> void:
	var made := _made()
	if made.is_empty():
		skip("no clip of the list made yet — %s" % OWNER)
		return
	for short in made:
		var fs: Array = L.make_strict(L.lint_clip_id("hush/" + short))
		var errs := PackedStringArray()
		for f in fs:
			if String((f as Dictionary)["severity"]) == "error":
				errs.append(L.format(f))
		assert_eq(errs.size(), 0, "hush/%s lints --strict clean: %s" % [short, "\n".join(errs)])


## The Hush rows of the 3D manifest (g0 + p00), keyed by short name; {} when SliceClips.build3d is not there.
func _manifest() -> Dictionary:
	var sc := _soft("res://view/world/slice_clips.gd")
	if sc == null or not sc.has_method("build3d"):
		return {}
	var rows: Array = sc.call("build3d", PackedStringArray(["g0_sneeze", "p00_curtain_up"]))
	var out := {}
	for r in rows:
		var d: Dictionary = r
		if String(d.get("rig", "")) == "hush":
			out[String(d.get("clip", "")).get_slice("/", 1)] = d
	return out


func test_manifest_rows_of_mine_exist_and_match() -> void:
	var man := _manifest()
	if man.is_empty():
		skip("SliceClips.build3d not available — r3d-view3d")
		return
	var n := 0
	for short in man:
		if not LIST.has(short):
			continue           # r3d-anim-hush-b's rows: its own test
		n += 1
		var v: Variant = _sidecar(String(short))
		if not assert_true(v != null, "manifest row hush/%s is made" % short):
			continue
		var sc: Dictionary = v
		var row: Dictionary = man[short]
		var want := int(row.get("expect_f", -1))
		var tol := int(row.get("tol_f", 0))
		var len_f := int(sc.get("length", 0))
		if want > 0 and not (bool(sc.get("loop", false)) and bool(row.get("loop_ok", false))):
			assert_between(len_f, want - tol, want + tol, "hush/%s: %d f (manifest %d ± %d)" % [short, len_f, want, tol])
		if bool(sc.get("loop", false)):
			assert_true(bool(row.get("loop_ok", true)) or want <= 0, "hush/%s: a loop where the manifest allows one" % short)
	assert_gt(n, 10, "the g0 + p00 manifest asks for my Hush clips")


func test_map_keys_resolve_to_clips() -> void:
	var p := "res://data/anim/hush3d/map.json"
	if not FileAccess.file_exists(p):
		skip("hush3d/map.json not written yet — %s" % OWNER)
		return
	var m: Dictionary = TestBase.load_json(p)
	assert_eq(String(m.get("rig", "")), "hush", "map.json is Hush's")
	var n := 0
	for k in m:
		if ["version", "rig", "doc", "stand_in"].has(String(k)):
			continue
		var ids := PackedStringArray()
		var v: Variant = m[k]
		if v is String:
			ids.append(String(v))
		elif v is Array:
			for x in v:
				ids.append(String(x))
		elif v is Dictionary:
			var c: Variant = (v as Dictionary).get("clip", "")
			if c is Array:
				for x in c:
					ids.append(String(x))
			else:
				ids.append(String(c))
		for id in ids:
			if id == "":
				continue       # "state:hidden": "" = no clip (the view hides her)
			n += 1
			assert_true(FileAccess.file_exists("res://data/anim/hush3d/%s.json" % id.get_slice("/", 1)),
				"map.json %s -> %s exists" % [k, id])
	assert_gt(n, 20, "map.json lists the slice's clips")
	var walk: Dictionary = m.get("walk", {})
	var run: Dictionary = m.get("run", {})
	for pair in [[walk, "loco_walk"], [run, "loco_run"]]:
		var row: Dictionary = pair[0]
		var sc: Variant = _sidecar(String(pair[1]))
		if sc is Dictionary:
			assert_almost_eq(float(row.get("speed_m_s", 0)), float((sc as Dictionary).get("speed_m_s", -1)), 0.001,
				"%s: map speed = the sidecar's" % pair[1])
			assert_almost_eq(float(row.get("stride_m", 0)), float((sc as Dictionary).get("stride_m", -1)), 0.001,
				"%s: map stride = the sidecar's" % pair[1])
			assert_almost_eq(float(row.get("speed_px_s", 0)), float(row.get("speed_m_s", 0)) * 200.0, 0.01,
				"%s: px/s = m/s x 200" % pair[1])
	assert_almost_eq(float(walk.get("speed_m_s", 0)), 2.0, 0.001, "the sneak: 2.0 m/s (REDESIGN §5.5)")
	assert_almost_eq(float(walk.get("stride_m", 0)), 1.8, 0.001, "the sneak: stride 1.80 m (a 54 f cycle)")
	assert_almost_eq(float(run.get("speed_m_s", 0)), 3.6, 0.001, "the run: 3.6 m/s")


func test_statues_snap_on_5_and_hold() -> void:
	var n := 0
	for i in range(1, 5):
		var v: Variant = _sidecar("freeze_%d" % i)
		if v == null:
			continue
		n += 1
		var sc: Dictionary = v
		var clack := false
		for e in (sc.get("events", []) as Array):
			var ev: Dictionary = e
			if String(ev.get("type", "")) == "sfx" and String(ev.get("id", "")) == "freeze_clack":
				clack = int(ev.get("f", -1)) == 5
		assert_true(clack, "freeze_%d: freeze_clack at f 5 (table)" % i)
		var holds: Array = (sc.get("lint", {}) as Dictionary).get("freeze_holds", [])
		if assert_eq(holds.size(), 1, "freeze_%d: one freeze hold" % i):
			assert_eq(int((holds[0] as Array)[0]), 5, "freeze_%d: held from the snap" % i)
			assert_eq(int((holds[0] as Array)[1]), 150, "freeze_%d: to the end" % i)
	if n == 0:
		skip("freeze_1..4 not made yet — %s" % OWNER)


func test_rig_clips_are_staged() -> void:
	var n := 0
	for short in ["rig_achoo_ria", "rig_allegro_go_go"]:
		var v: Variant = _sidecar(short)
		if v == null:
			continue
		n += 1
		var sc: Dictionary = v
		assert_eq(String(sc.get("lock", "")), "rig_pm", "%s: rig_pm" % short)
		assert_le(float(sc.get("cheat_deg", 99)), 10.0, "%s: cheat ≤ 10 while reaching" % short)
		var st: Variant = sc.get("stage", null)
		if assert_true(st is Dictionary, "%s: carries its stage" % short):
			assert_true(absi(int((st as Dictionary).get("facing", 0))) == 1, "%s: a facing" % short)
	var ach: Variant = _sidecar("rig_achoo_ria")
	if ach is Dictionary:
		var step: Variant = (ach as Dictionary).get("step", null)
		if assert_true(step is Dictionary, "rig_achoo_ria: the stool step is recorded"):
			var sd: Dictionary = step
			assert_eq(String(sd.get("kind", "")), "stool", "Bellows' stool")
			assert_eq(String(sd.get("id", "")), "kitchen_stool", "the stool decor")
			assert_almost_eq(float(sd.get("h", 0)), 0.55, 0.001, "seat 0.55 m")
			var sup: Array = sd.get("support", [])
			assert_almost_eq(float((sup[sup.size() - 1] as Array)[1]), 0.0, 0.0001, "ends on the floor")
		var kinds := {}
		for e in ((ach as Dictionary).get("events", []) as Array):
			var ev: Dictionary = e
			kinds["%s:%s" % [ev.get("type", ""), ev.get("id", ev.get("op", ev.get("part", "")))]] = true
		for k in ["prop:show", "prop:hide", "set_part:pepper_pot", "fx:pepper_stream", "sfx:pepper_shake", "decor:kitchen_stool"]:
			assert_true(kinds.has(k), "rig_achoo_ria: event %s" % k)
	if n == 0:
		skip("rig clips not made yet — %s" % OWNER)


## World point of a model-space point for a clip's sidecar stage (the view places her at (x, 0, z), yawed
## facing × (90 − cheat) about +y; the rig faces +z at yaw 0).
static func _to_world(stage: Dictionary, p: Vector3) -> Vector3:
	var yaw := float(stage.get("facing", 1)) * (90.0 - float(stage.get("cheat_deg", 0.0)))
	return Basis(Vector3.UP, deg_to_rad(yaw)) * p + Vector3(float(stage.get("x", 0)), 0.0, float(stage.get("z", 0)))


## The placed reach target (and the full reach record) of a house3d.json rig hotspot.
func _reach(hid: String) -> Dictionary:
	var db := ContentDB.load_dir("res://data")
	var h3 := SetGeo.load_house3d()
	var h := db.house.hotspot(hid)
	var hs3: Dictionary = h3.get("hotspots", {})
	if h == null or not hs3.has(hid):
		return {}
	return SetGeo.reach_info(h.rect, hs3[hid], float(h.use_sub) / 12000.0, SetGeo.reach_cfg(h3))


func test_achoo_pepper_pot_on_the_placed_target_at_the_shakes() -> void:
	var v: Variant = _sidecar("rig_achoo_ria")
	if v == null:
		skip("rig_achoo_ria not made yet — %s" % OWNER)
		return
	var info := _reach("kitchen_honey")
	if not assert_false(info.is_empty(), "kitchen_honey is placed in house3d.json"):
		return
	var target: Vector3 = info["target"]
	var stage: Dictionary = (v as Dictionary).get("stage", {})
	var stand: Vector3 = info["stand"]
	assert_almost_eq(float(stage.get("x", 0)), stand.x, 0.001, "staged at the placed reach_pos x")
	assert_almost_eq(float(stage.get("z", 0)), stand.z, 0.001, "staged at the placed reach_pos z")
	var s := RigSampler3D.for_rig("hush")
	if not assert_true(s.ok, "the hush rig samples"):
		return
	for f in SHAKES:
		assert_true(s.pose_at("hush/rig_achoo_ria", float(f)), "posed at f %d" % f)
		var spout := _to_world(stage, s.global_pos("fx_pepper"))
		var d := spout.distance_to(target)
		assert_le(d, SPOUT_TOL_M, "shake f %d: the pot's spout %.3f m from the placed reach target %s (≤ %.2f)" % [f, d, str(target), SPOUT_TOL_M])
		# ... held in her glove: the grip socket is 0.215 m up the pot from the spout
		var hand := s.global_xf("hand_r")
		var grip := _to_world(stage, hand * Vector3(-0.03, 0.09, 0.004))
		assert_between(grip.distance_to(spout), 0.19, 0.24, "shake f %d: the glove holds the pot" % f)
		assert_gt(grip.y, spout.y, "shake f %d: the pot is tipped, holes down" % f)


func test_allegro_glove_on_the_knob_before_the_yank() -> void:
	var v: Variant = _sidecar("rig_allegro_go_go")
	if v == null:
		skip("rig_allegro_go_go not made yet — %s" % OWNER)
		return
	var info := _reach("parlour_gramophone")
	if not assert_false(info.is_empty(), "parlour_gramophone is placed in house3d.json"):
		return
	var target: Vector3 = info["target"]
	var stage: Dictionary = (v as Dictionary).get("stage", {})
	var s := RigSampler3D.for_rig("hush")
	if not assert_true(s.ok, "the hush rig samples"):
		return
	for f in [14, 16]:
		s.pose_at("hush/rig_allegro_go_go", float(f))
		var grip := _to_world(stage, s.global_xf("hand_r") * Vector3(-0.03, 0.09, 0.004))
		assert_le(grip.distance_to(target), 0.03, "f %d: the right glove on the red knob (%.3f m)" % [f, grip.distance_to(target)])
