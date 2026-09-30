## ClipLib3D / ClipDef3D (ruling R2, r3d-index §7.2): id → path mapping, sidecar parsing (typed fields, events sorted
## with clip / rig / f, marks, face timeline), validation, the Animation's loop mode from the sidecar, directory scan,
## registration and hot reload.
extends TestBase

const Env := preload("res://tests/rig3d/fixtures/fix_env.gd")


func before_each() -> void:
	Env.push()


func after_each() -> void:
	Env.pop()


func test_path_mapping() -> void:
	assert_eq(ClipLib3D.path_of("fix/rx_take"), "res://tests/rig3d/fixtures/data/anim/fix3d/rx_take.json")
	var i := ClipLib3D.search_roots.find(Env.ROOT)
	ClipLib3D.search_roots.remove_at(i)
	assert_eq(ClipLib3D.path_of("hush/loco_walk"), "res://data/anim/hush3d/loco_walk.json", "the contract's example path")
	ClipLib3D.search_roots.append(Env.ROOT)


func test_parse_sidecar() -> void:
	var c := ClipLib3D.get_clip("fix/rx_take")
	if not assert_true(c != null, "fixture clip loads"):
		return
	assert_true(c.is_valid(), "%s" % [c.errors])
	assert_eq(c.id, "fix/rx_take")
	assert_eq(c.rig_id, "fix")
	assert_eq(c.name, "rx_take")
	assert_eq(c.length, 90)
	assert_eq(c.lock, "sim")
	assert_eq(c.beats["hold"], Vector2i(33, 69))
	assert_eq(c.mark("accent"), 30)
	assert_eq(c.mark("release"), 90)
	assert_eq(c.mark("nope"), -1)
	assert_eq(c.cheat_deg, 30.0)
	assert_eq(c.face_entries.size(), 4)
	assert_eq(c.face_presets[3], "sly", "an entry with only slots keeps the previous preset")
	assert_eq(c.face_index_at(29.9), 0)
	assert_eq(c.face_index_at(30.0), 1)
	for i in c.ev_f.size() - 1:
		assert_le(c.ev_f[i], c.ev_f[i + 1], "events sorted by frame")
	for e in c.events:
		assert_eq(e["clip"], "fix/rx_take", "events carry the clip id")
		assert_eq(e["rig"], "fix")
	assert_true(ClipLib3D.get_clip("fix/rx_take") == c, "cached")
	assert_eq(ClipLib3D.length("fix/rx_take"), 90)
	assert_eq(ClipLib3D.length("fix/nope"), -1)
	assert_true(ClipLib3D.get_clip("fix/nope") == null)
	assert_false(ClipLib3D.exists("fix/nope"))
	assert_true(ClipLib3D.exists("fix/rx_take"))


func test_loop_mode_comes_from_the_sidecar() -> void:
	var walk := ClipLib3D.animation("fix/loco_walk")
	var take := ClipLib3D.animation("fix/rx_take")
	if not assert_true(walk != null and take != null, "fixture anims load"):
		return
	assert_eq(walk.loop_mode, Animation.LOOP_LINEAR, "loop: true → linear loop")
	assert_eq(take.loop_mode, Animation.LOOP_NONE)
	var w := ClipLib3D.get_clip("fix/loco_walk")
	assert_eq(w.stride_m, 1.6)
	assert_eq(w.speed_m_s, 1.2)
	assert_true(w.loop)
	assert_true(ClipLib3D.problems("fix/loco_walk").is_empty(), "%s" % [ClipLib3D.problems("fix/loco_walk")])


func test_overlay_defaults() -> void:
	var o := ClipLib3D.get_clip("fix/mg_wave")
	assert_eq(o.layer, "overlay")
	assert_eq(o.mask, "upper")


func test_validation() -> void:
	var bad := ClipDef3D.from_dict("fix/bad", {"version": 2, "format": "anim3d", "clip": "fix/bad", "rig": "fix",
		"anim": "res://x.res", "length": 30, "fps": 30, "layer": "sideways", "mask": "toes", "lock": "clock",
		"beats": {"hold": [20, 40]}, "events": [{"f": 45, "type": "sfx", "id": "x"}, {"f": 3, "type": "explode"},
		{"f": 5, "type": "smear"}, {"type": "sfx"}], "face": [{"f": 10, "preset": "a"}, {"f": 4, "preset": "b"}]}, "bad.json")
	var want := ["fps: must be 60", "layer: unknown 'sideways'", "mask: unknown 'toes'", "lock: unknown 'clock'",
		"beats.hold: [20, 40] outside", "events[0].f: frame 45 outside", "events[1].type: unknown 'explode'",
		"events[3]: needs f and type", "face[1].f: timeline not sorted"]
	for w in want:
		var hit := false
		for e in bad.errors:
			hit = hit or e.contains(w)
		assert_true(hit, "wanted '%s' in %s" % [w, bad.errors])
	var warned := false
	for w2 in bad.warnings:
		warned = warned or w2.contains("smear")
	assert_true(warned, "smear is a warning (dropped in 3D)")
	var zero := ClipDef3D.from_dict("fix/zero", {"anim": "res://x.res", "length": 0}, "z.json")
	assert_false(zero.is_valid())


func test_clips_of_scans_the_folder() -> void:
	var ids := ClipLib3D.clips_of("fix")
	for want in ["fix/rx_take", "fix/rx_sneeze", "fix/loco_walk", "fix/loco_idle", "fix/mg_wave", "fix/beat_suppressed", "fix/beat_slow_burn"]:
		assert_has(ids, want)
	assert_eq(ids.size(), 7, "%s" % [ids])


func test_register_in_memory() -> void:
	var def := ClipDef3D.from_dict("fix/mem", {"anim": "memory", "length": 12, "loop": true}, "")
	var a := Animation.new()
	a.length = 0.2
	ClipLib3D.register(def, a)
	assert_true(ClipLib3D.exists("fix/mem"))
	assert_true(ClipLib3D.animation("fix/mem") == a)
	assert_eq(a.loop_mode, Animation.LOOP_LINEAR, "register conforms the loop mode too")
	assert_has(ClipLib3D.clips_of("fix"), "fix/mem")
