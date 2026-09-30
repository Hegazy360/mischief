## The 3D clip pipeline's output (r3d-anim §5): every `data/anim/hush3d/*.json` sidecar parses through ClipLib3D
## (r3d-rig), its `.res` loads, `length / 60 == Animation.length`, the loop mode matches, event types are known, sound
## ids exist, face presets exist in the rig; the lint's own sampler agrees with RigSampler3D (the player's). The lint
## fixtures (game/tests/anim3d/fixtures) are held to the same structure.
extends TestBase

const L := preload("res://tools/anim/lint3d_rules.gd")
const CLIP_LIB := "res://view3d/char/clip_lib_3d.gd"
const SAMPLER := "res://view3d/char/rig_sampler_3d.gd"
const FX := "res://tests/anim3d/fixtures/"
const RIGS: PackedStringArray = ["hush"]


static func _soft(path: String) -> Script:
	return load(path) as Script if ResourceLoader.exists(path) else null


func after_each() -> void:
	L.reset_caches()


## Clip ids with a sidecar under data/anim/<rig>3d/.
func _ids(rig: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("res://data/anim/%s3d" % rig)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json") and not ["map.json", "rig_actions.json"].has(f):
			out.append("%s/%s" % [rig, f.get_basename()])
	out.sort()
	return out


func _check_structure(sc: Dictionary, file: String) -> void:
	assert_eq(int(sc.get("version", 0)), 2, "%s: sidecar version 2" % file)
	assert_eq(String(sc.get("format", "")), "anim3d", file)
	assert_eq(int(sc.get("fps", 0)), 60, file)
	var ap := String(sc.get("anim", ""))
	assert_true(ResourceLoader.exists(ap), "%s: its anim %s exists" % [file, ap])
	var a := load(ap) as Animation
	if not assert_true(a != null, "%s: the .res loads as an Animation" % file):
		return
	assert_almost_eq(a.length * 60.0, float(int(sc["length"])), 0.01, "%s: Animation.length = length / 60" % file)
	var want := Animation.LOOP_LINEAR if bool(sc.get("loop", false)) else Animation.LOOP_NONE
	assert_eq(a.loop_mode, want, "%s: loop mode = the sidecar's loop" % file)
	var sounds := L.sound_ids()
	for e in (sc.get("events", []) as Array):
		var ev: Dictionary = e
		assert_has(L.EVENT_TYPES, String(ev.get("type", "")), "%s: event type %s known" % [file, ev.get("type", "")])
		if ["sfx", "voice"].has(String(ev.get("type", ""))):
			assert_true(sounds.has(String(ev.get("id", ""))), "%s: sound id %s in sfx_map.json" % [file, ev.get("id", "")])
	var presets := L._face_presets(String(sc.get("rig", "hush")))
	if not presets.is_empty():
		for fe in (sc.get("face", []) as Array):
			if (fe as Dictionary).has("preset"):
				assert_true(presets.has(String((fe as Dictionary)["preset"])), "%s: face preset %s in the rig" % [file, (fe as Dictionary)["preset"]])


func test_every_hush3d_sidecar_is_well_formed() -> void:
	var n := 0
	for rig in RIGS:
		for id in _ids(rig):
			var p := "res://data/anim/%s3d/%s.json" % [rig, id.get_slice("/", 1)]
			var sc: Variant = TestBase.load_json(p)
			if not assert_true(sc is Dictionary, "%s parses" % p):
				continue
			assert_eq(String((sc as Dictionary).get("clip", "")), id, "%s: clip id = its file" % p)
			_check_structure(sc, p)
			n += 1
	if n == 0:
		skip("no hush3d clip baked yet (r3d-anim A1)")


func test_sidecars_load_through_cliplib3d() -> void:
	var lib := _soft(CLIP_LIB)
	if lib == null:
		skip("ClipLib3D not built yet — r3d-rig")
		return
	var ids := PackedStringArray()
	for rig in RIGS:
		ids.append_array(_ids(rig))
	if ids.is_empty():
		skip("no hush3d clip baked yet (r3d-anim A1)")
		return
	for id in ids:
		lib.call("invalidate", id)
		var def: Variant = lib.call("get_clip", id)
		if not assert_true(def != null, "%s: ClipLib3D.get_clip" % id):
			continue
		var probs: PackedStringArray = lib.call("problems", id)
		assert_eq(probs.size(), 0, "%s: ClipLib3D problems %s" % [id, str(probs)])
		assert_true(lib.call("animation", id) != null, "%s: ClipLib3D.animation" % id)


func test_lint_fixtures_are_well_formed() -> void:
	var d := DirAccess.open(FX + "sidecars")
	if not assert_true(d != null, "fixture sidecars exist"):
		return
	var n := 0
	for f in d.get_files():
		if f.ends_with(".json"):
			var sc: Variant = TestBase.load_json(FX + "sidecars/" + f)
			if assert_true(sc is Dictionary, f):
				_check_structure(sc, f)
				n += 1
	assert_ge(n, 17, "every lint fixture")


func test_lint_sampler_agrees_with_rig_sampler_3d() -> void:
	var sampler := _soft(SAMPLER)
	if sampler == null:
		skip("RigSampler3D not built yet — r3d-rig")
		return
	var ids := _ids("hush")
	if ids.is_empty():
		skip("no hush3d clip baked yet (r3d-anim A1)")
		return
	var id := ids[0]
	var sc: Dictionary = TestBase.load_json("res://data/anim/hush3d/%s.json" % id.get_slice("/", 1))
	var rig := L.rig_skeleton("res://art3d/chars/hush/hush.glb")
	if not assert_true(bool(rig.get("ok", false)), str(rig.get("error", ""))):
		return
	var n := int(sc["length"])
	var s := L.sample(rig, load(String(sc["anim"])) as Animation, n)
	var index: Dictionary = rig["index"]
	for f in [0, n / 3, (2 * n) / 3]:
		var theirs: Dictionary = sampler.call("sample", "hush", id, float(f))
		if not assert_false(theirs.is_empty(), "RigSampler3D samples %s" % id):
			return
		var gp: Dictionary = theirs["global_pos"]
		for bone in ["foot_l", "hand_r", "Head", "pelvis"]:
			var mine: Vector3 = ((s["glob"] as Array)[f][int(index[bone])] as Transform3D).origin
			var other: Vector3 = gp[bone]
			assert_lt(mine.distance_to(other), 0.002, "%s f%d %s: lint %s vs RigSampler3D %s" % [id, f, bone, mine, other])
