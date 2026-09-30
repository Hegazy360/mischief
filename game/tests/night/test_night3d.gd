## NightScene on the 3D view (brief r3d-night §5): the view switch, g0 + P00 built and played 600 frames, tick 0 on the
## rise frame, input on projected rects (go / floor move with the lane x / a struck spot answered by the "no" wobble),
## the presenter's R3D HudModel fields, the world-overlay model filled every frame, the warm-up covering every
## material, the compile / first-use detector, the curtain call's 3D bows and the Gag Reel's first frame, the
## stage-door entries, every boot_config.json key with its default and the frame-quantised checks.
extends TestBase

const SAVE_TMP := "user://test_night3d_save.json"

var _saved_path: String = ""


func before_each() -> void:
	var sv := ViewKit.autoload("Save")
	if sv != null:
		_saved_path = String(sv.get("path"))
		sv.set("path", SAVE_TMP)
		sv.call("reset")


func after_each() -> void:
	var sv := ViewKit.autoload("Save")
	if sv != null and _saved_path != "":
		sv.set("path", _saved_path)
		sv.call("load_save")
	if FileAccess.file_exists(SAVE_TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TMP))


func _make(p: Dictionary) -> NightScene:
	var ps := load(NightScene.SCENE) as PackedScene
	var n: NightScene = ps.instantiate()
	n.setup(p)
	tree.root.add_child(n)
	return n


func _frames(k: int) -> void:
	for i in k:
		await tree.process_frame


func _wait_phase(n: NightScene, ph: int, limit: int = 400) -> bool:
	for i in limit:
		if n.phase == ph:
			return true
		await tree.process_frame
	return n.phase == ph


func _free(n: Node) -> void:
	n.queue_free()
	await tree.process_frame
	await tree.process_frame


# --- boot_config.json ------------------------------------------------------------------------------------------

func test_every_boot_config_key_has_its_default() -> void:
	var d := BootConfig.merged({})
	assert_eq(d, BootConfig.DEFAULTS, "an empty file = the defaults")
	var missing := BootConfig.read("res://no/such/boot_config.json")
	assert_eq(String(missing["view"]), "3d")
	assert_eq(String(missing["start"]), "auto")
	assert_false(bool(missing["show_previews"]))
	assert_eq(String(missing["bellows_window"]), "sim")
	assert_true(bool((missing["render"] as Dictionary)["msaa_3d"]))
	assert_almost_eq(float((missing["render"] as Dictionary)["render_scale"]), 1.0)
	assert_true(bool((missing["render"] as Dictionary)["outline"]))
	var part := BootConfig.merged({"view": "2D", "render": {"render_scale": 0.2, "outline": false}, "bellows_window": "wide",
		"show_previews": "yes"})
	assert_eq(String(part["view"]), "2d", "case-insensitive view")
	assert_almost_eq(float((part["render"] as Dictionary)["render_scale"]), 0.5, 0.0001, "render scale clamped")
	assert_false(bool((part["render"] as Dictionary)["outline"]))
	assert_true(bool((part["render"] as Dictionary)["msaa_3d"]), "a missing render key keeps its default")
	assert_eq(String(part["bellows_window"]), "sim", "an invalid window mode = the default")
	assert_false(bool(part["show_previews"]), "a non-bool = the default")


func test_the_shipped_boot_config_is_the_owner_apks() -> void:
	var raw: Variant = TestBase.load_json(BootConfig.PATH)
	if not assert_true(raw is Dictionary, "boot_config.json parses"):
		return
	var r: Dictionary = raw
	for k in ["start", "view", "show_previews", "bellows_window", "render"]:
		assert_true(r.has(k), "boot_config.json has %s" % k)
	assert_eq(String(r["start"]), "stage_door")
	assert_eq(String(r["view"]), "3d")
	assert_false(bool(r["show_previews"]), "the owner APK hides the N1/N2 previews")
	for k2 in ["msaa_3d", "render_scale", "outline"]:
		assert_true((r["render"] as Dictionary).has(k2), "render.%s" % k2)


func test_night_args_3d_flags() -> void:
	var a := NightArgs.parse(PackedStringArray(["--view=3d", "--msaa=off", "--no-captions", "--hud=off", "--window=lean"]))
	assert_eq(String(a["view"]), "3d")
	assert_eq(String(a["msaa"]), "off")
	assert_true(bool(a["no_captions"]))
	assert_false(bool(a["hud"]))
	assert_eq(String(a["window"]), "lean")
	var b := NightArgs.parse(PackedStringArray(["--view=4d", "--msaa=2x"]))
	assert_eq(String(b["view"]), "", "an unknown view is ignored")
	assert_eq(String(b["msaa"]), "2")
	assert_true(bool(b["hud"]), "the HUD is on by default")


# --- the view switch, build, play ------------------------------------------------------------------------------

func test_the_view_switch() -> void:
	allow_errors()
	var n2 := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "view": "2d"})
	assert_eq(n2.view_mode, "2d")
	assert_true(n2.world_view is WorldView, "2d: WorldView")
	assert_true(n2.cam is CameraDirector, "2d: CameraDirector")
	assert_true(n2.overlays == null, "2d: no world overlays")
	await _free(n2)
	var n3 := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "view": "3d"})
	assert_eq(n3.view_mode, "3d")
	assert_true(n3.world_view is WorldView3D, "3d: WorldView3D")
	assert_true(n3.cam is CameraDirector3D, "3d: CameraDirector3D")
	assert_true(n3.pip is PipView3D, "3d: the Bellows window")
	assert_true(n3.stager is GagStager3D, "3d: GagStager3D")
	assert_true(n3.overlays != null and n3.overlays.layer == WorldOverlays.LAYER, "3d: world overlays on layer 8")
	assert_true(n3.stalls.hidden_at_rest, "3d: the Stalls are hidden at rest")
	assert_true(n3.night_input.view3d, "3d: taps are screen px on projected rects")
	await _free(n3)
	var nd := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true})
	assert_eq(nd.view_mode, BootConfig.view(), "no param: boot_config.json's view")
	await _free(nd)


func test_g0_and_p00_build_and_play_600_frames_in_3d() -> void:
	allow_errors()
	for ep in ["g0_sneeze", "p00_curtain_up"]:
		var n := _make({"episode": ep, "from": "test", "skip_intro": true, "view": "3d"})
		if not assert_true(n.world != null, "%s builds" % ep):
			await _free(n)
			continue
		assert_true(await _wait_phase(n, NightScene.Phase.PLAY, 400), "%s reaches PLAY" % ep)
		await _frames(600)
		assert_gt(int(n.world.get("tick")), 300, "%s: the sim ran" % ep)
		assert_gt(n.overlays.apply_count, 300, "%s: the overlays applied every frame" % ep)
		assert_gt(n.perf3d.frames, 300, "%s: the perf sampler ran" % ep)
		assert_true(n.shader_watch.armed, "%s: the compile watch is armed at the rise" % ep)
		await _free(n)


func test_tick0_is_the_rise_frame_in_3d() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "rise_at_ms": DeviceLog.process_ms() + 600000, "view": "3d"})
	await _frames(30)
	assert_eq(n.phase, NightScene.Phase.WARM)
	assert_eq(int(n.world.get("tick")), 0, "held at tick 0 under the curtain (the view pre-rolls)")
	n.start_rise()
	var rise := n.frame_n
	await _frames(4)
	assert_le(absi(n.rise_frame - rise), 1, "tick 0 = the curtain-rise frame ± 1")
	assert_gt(int(n.world.get("tick")), 0)
	await _free(n)


# --- input on projected rects ----------------------------------------------------------------------------------

## Headless runs have a square root viewport: give the camera the 20:9 phone's logical size and let it settle.
func _phone(n: NightScene) -> void:
	n.cam.logical_size_override = Vector2(2400, 1080)
	n.cam.snap_now()
	await _frames(3)


func _rect_of(n: NightScene, id: String) -> Rect2:
	for r in n.world_view.hotspot_rects_in_view():
		if String((r as Dictionary).get("id", "")) == id:
			return (r as Dictionary)["rect"]
	return Rect2()


func test_a_tap_on_a_projected_rect_goes_there() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "view": "3d"})
	await _wait_phase(n, NightScene.Phase.PLAY)
	await _frames(5)
	await _phone(n)
	n.driver.set_paused(true)
	var r := _rect_of(n, "kitchen_honey")
	if not assert_true(r.has_area(), "the honey projects on screen: %s (hush %s, cam %s, vs %s)" % [
			n.world_view.hotspot_rects_in_view().map(func(d: Dictionary) -> String: return "%s %s" % [d["id"], d["rect"]]),
			n.driver.snapshot().hush.x, n.cam.follow_x(), n.cam.view_size()]):
		await _free(n)
		return
	assert_ge(r.size.x, 144.0, "hit box ≥ 144 px wide")
	var cmds: Array = []
	n.night_input.command.connect(func(c: Dictionary) -> void: cmds.append(c))
	var fb := [0]
	n.night_input.tap_feedback.connect(func(_a: Vector2, _b: Vector2) -> void: fb[0] += 1)
	n.night_input.enabled = true
	n.night_input.on_tapped(r.get_center(), false)
	assert_eq(cmds.size(), 1)
	if cmds.size() == 1:
		assert_eq(String(cmds[0].get("c", "")), "go")
		assert_eq(String(cmds[0].get("hotspot", "")), "kitchen_honey")
	assert_eq(fb[0], 1, "feedback in the same frame")
	await _free(n)


func test_a_floor_tap_moves_along_the_lane() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "view": "3d"})
	await _wait_phase(n, NightScene.Phase.PLAY)
	await _frames(5)
	await _phone(n)
	n.driver.set_paused(true)
	var floor := Rect2()
	for r in n.world_view.hotspot_rects_in_view():
		if String((r as Dictionary).get("id", "")) == "floor:kitchen":
			floor = (r as Dictionary)["rect"]
	if not assert_true(floor.has_area(), "the kitchen floor band projects"):
		await _free(n)
		return
	# a floor point clear of every hotspot's box and assist radius
	var hot: Array = []
	for c in n.night_input.candidates():
		if String((c as Dictionary).get("kind", "")) != "floor":
			hot.append((c as Dictionary)["rect"])
	var pick := Vector2.INF
	for i in 40:
		# from the band's centre outward (its ends touch the next room's band at the doorways)
		var off := (float(i / 2) + 0.5) / 40.0 * (1.0 if i % 2 == 0 else -1.0)
		var p := Vector2(floor.get_center().x + floor.size.x * off, floor.get_center().y)
		var clear := true
		for hr in hot:
			if TapAssist.rect_distance(p, hr) <= GestureConfig.ASSIST_PX:
				clear = false
		if clear:
			pick = p
			break
	if not assert_true(pick.is_finite(), "a clear floor point exists"):
		await _free(n)
		return
	var res: Dictionary = n.night_input.resolve(pick)
	assert_eq(String(res.get("c", "")), "move")
	assert_eq(String(res.get("room", "")), "kitchen")
	var want := int(round((n.cam.screen_to_world(pick) as Vector2).x))
	assert_le(absi(int(res.get("x", -1)) - want), 31, "x from the lane-plane hit (clamped inside the room)")
	await _free(n)


func test_a_struck_hotspot_is_never_a_target_and_the_sim_refusal_wobbles() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "view": "3d"})
	await _wait_phase(n, NightScene.Phase.PLAY)
	await _frames(60)
	var struck := "kitchen_sink_tap"
	for r in n.world_view.hotspot_rects_in_view():
		assert_ne(String((r as Dictionary).get("id", "")), struck, "a struck hotspot is not a tap candidate")
	var x0 := float(n.driver.snapshot().hush.x)
	var rej := [0]
	var grey := [false]
	var wv: WorldView3D = n.world_view
	# connected after the world view: it has answered the refusal when this runs
	n.driver.ticked.connect(func(evs: Array) -> void:
		for e in evs:
			if String((e as Dictionary).get("e", "")) == "cmd_rejected" and String((e as Dictionary).get("why", "")) == "struck":
				rej[0] += 1
				for sl in wv.decals._pops:
					var cv: Variant = sl.mat.get_shader_parameter("color")
					if sl.active and cv is Color and (cv as Color).r < 0.8 and (cv as Color).a < 0.9:
						grey[0] = true)
	n.world_view.tap_feedback(n.world_view.target_point(struck))
	n.driver.push_cmd({"c": "go", "hotspot": struck})
	await _frames(20)
	assert_eq(rej[0], 1, "the sim refuses a struck spot")
	assert_almost_eq(float(n.driver.snapshot().hush.x), x0, 60.0, "Hush does not walk there")
	assert_true(grey[0], "the grey 'no' wobble popped at the tap")
	await _free(n)


# --- the presenter's R3D fields --------------------------------------------------------------------------------

func test_presenter_fills_the_r3d_hud_fields() -> void:
	var p := HudPresenter.new()
	p.setup(null, null)
	var m := HudModel.new()
	var snap := ViewSnapshot.new()
	var env := HudPresenter.HudEnv.new()
	snap.hush.present = true
	snap.hush.room = "kitchen"
	snap.hush.state = "IDLE"
	snap.bellows.present = true
	snap.bellows.room = "kitchen"
	snap.bellows.spot_pct = 0.4
	p.fill_r3d(m, snap, {}, env)
	assert_eq(m.freeze_danger, HudModel.FreezeDanger.FILLING, "a ? filling on her")
	assert_true(m.verb_live, "FREEZE is LIVE in danger")
	snap.bellows.spot_pct = 0.0
	p.fill_r3d(m, snap, {}, env)
	assert_eq(m.freeze_danger, HudModel.FreezeDanger.EXPOSED, "he is in her room")
	snap.hush.state = "HIDDEN"
	p.fill_r3d(m, snap, {}, env)
	assert_eq(m.freeze_danger, HudModel.FreezeDanger.NONE, "hidden = safe")
	snap.hush.state = "IDLE"
	snap.bellows.room = "parlour"
	env.entry_warning = true
	p.fill_r3d(m, snap, {}, env)
	assert_eq(m.freeze_danger, HudModel.FreezeDanger.EXPOSED, "his entry warning into her room")
	env.entry_warning = false
	p.fill_r3d(m, snap, {}, env)
	assert_eq(m.freeze_danger, HudModel.FreezeDanger.NONE)
	assert_false(m.verb_live, "FREEZE with no danger is QUIET")
	snap.hush.carrying = PackedStringArray(["squeaker"])
	env.can_bow = true
	env.overview_allowed = true
	m.pip_visible = true
	snap.bubble_icon = "tea"
	snap.bubble_ring_ticks = 300
	p.fill_r3d(m, snap, {}, env)
	assert_true(m.carrying, "the carried-item chips")
	assert_true(m.bow_visible, "BOW after ★")
	assert_true(m.overview_visible)
	assert_eq(m.pip_next_icon, "tea", "the window's next-activity chip")
	assert_almost_eq(m.pip_ring_frac, 1.0, 0.001, "the countdown ring starts full")
	snap.bubble_ring_ticks = 150
	p.fill_r3d(m, snap, {}, env)
	assert_almost_eq(m.pip_ring_frac, 0.5, 0.001, "and runs down")
	m.edge_bubble_dir = Vector2(-1, 0)
	env.edge_lean = true
	p.fill_r3d(m, snap, {}, env)
	assert_eq(m.edge_badge_side, -1, "the edge badge on his side")
	assert_true(m.edge_badge_lean, "standing in for the window (lean)")
	assert_eq(m.meter_until_s, -1.0, "the meter's timing is the Hud's")
	p.on_events([{"e": "lure", "t": 100}])
	env.tick = 200
	p.fill(m, snap, {}, env)
	p.fill_r3d(m, snap, {}, env)
	assert_eq(m.lure_ring, HudModel.LureRing.ON, "a lure in the last 60 s shows the ring")


func test_the_hint_ladder_picks_the_next_useful_spot() -> void:
	allow_errors()
	var n := _make({"episode": "p00_curtain_up", "from": "test", "skip_intro": true, "view": "3d"})
	await _wait_phase(n, NightScene.Phase.PLAY)
	await _frames(3)
	var snap := n.driver.snapshot()
	var nu := n.next_useful(snap)
	assert_true(nu in ["kitchen_honey", "parlour_gramophone"], "a Script line's hint rig point: %s" % nu)
	n.idle_s = 7.0
	await _frames(3)
	assert_ne(n.octx.next_useful, "", "N4: after 6 s idle the overlays get the next useful spot")
	await _free(n)


func test_the_map_is_the_overview_with_room_peeks() -> void:
	allow_errors()
	var n := _make({"episode": "p00_curtain_up", "from": "test", "skip_intro": true, "view": "3d"})
	await _wait_phase(n, NightScene.Phase.PLAY)
	await _phone(n)
	var t0 := int(n.world.get("tick"))
	n.open_map()
	assert_true(n.map_open)
	assert_true(n.cam.is_overview(), "the 15 m overview")
	assert_true(n.driver.is_paused(), "the sim stays paused")
	assert_true(n.input_router.enabled, "the map takes taps")
	assert_false(n.night_input.enabled, "gameplay taps do not")
	await _frames(20)
	assert_eq(int(n.world.get("tick")), t0, "no tick while the map is open")
	# a tap on the parlour peeks at it
	var vs: Vector2 = n.cam.view_size()
	var room := ""
	var tap := Vector2.ZERO
	for i in 24:
		var p := Vector2(vs.x * (float(i) + 0.5) / 24.0, vs.y * 0.6)
		if n.map_room_at(p) == "parlour":
			room = "parlour"
			tap = p
			break
	if assert_eq(room, "parlour", "the parlour is on the map"):
		n._intent(&"tapped", [tap, false])
		await _frames(2)
		assert_true(n.cam.is_peeking(), "a tap on a room peeks at it")
		assert_true(n.map_open, "the map stays open while peeking")
	assert_true(n.handle_back(), "Back closes the map")
	assert_false(n.map_open)
	assert_false(n.cam.is_overview(), "back to the play framing")
	await _frames(5)
	assert_gt(int(n.world.get("tick")), t0, "play resumes")
	await _free(n)


# --- warm-up and the compile detector --------------------------------------------------------------------------

func test_the_warm_up_covers_every_material_of_the_night() -> void:
	allow_errors()
	MaterialWarm3D.clear()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "view": "3d"})
	await _wait_phase(n, NightScene.Phase.PLAY)
	await _frames(5)
	assert_true(n.warmer.done, "warmed")
	assert_true(n.warmer.ran.has("materials") and n.warmer.ran.has("materials_done"), "the 3D material steps ran")
	assert_ge(n.warmer.materials_drawn, MaterialWarm3D.count(), "every registered (shader, kind) drawn")
	assert_gt(n.warmer.instanced_drawn, 0, "the particle materials' instanced variant drawn")
	# every shader in the Night's tree is known to the watch (drawn under the curtain)
	var unknown := PackedStringArray()
	_collect_unknown(n.world_view, n.shader_watch.known, unknown)
	assert_eq(unknown.size(), 0, "materials the warm-up missed: %s" % [unknown])
	# the lazily built freeze plinth (first freeze in PLAY) is warmed too
	if ResourceLoader.exists(NightWarmer.LAZY_SCENES[0]):
		var lazy := (load(NightWarmer.LAZY_SCENES[0]) as PackedScene).instantiate()
		var missed := PackedStringArray()
		_collect_unknown(lazy, n.shader_watch.known, missed)
		lazy.free()
		assert_eq(missed.size(), 0, "the plinth's shaders are in the warmed set: %s" % [missed])
	await _frames(70)
	assert_eq(n.shader_watch.compiles_play(), 0, "no shader first used in PLAY: %s" % [n.shader_watch.first_use])
	await _free(n)


func _collect_unknown(nd: Node, known: Dictionary, out: PackedStringArray) -> void:
	if nd is GeometryInstance3D:
		var g := nd as GeometryInstance3D
		var inst := g is CPUParticles3D or g is MultiMeshInstance3D
		var mats: Array = []
		if g.material_override != null:
			mats.append(g.material_override)
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			for i in (g as MeshInstance3D).mesh.get_surface_count():
				var m := (g as MeshInstance3D).get_active_material(i)
				if m != null:
					mats.append(m)
		for m2 in mats:
			var k := ShaderWatch.shader_key(m2, inst and m2 == g.material_override)
			if k != "" and not known.has(k) and not out.has(k):
				out.append(k)
	for c in nd.get_children():
		_collect_unknown(c, known, out)


func test_the_detector_fires_on_an_unwarmed_material() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var w := ShaderWatch.new()
	w.arm(root)
	assert_eq(w.compiles_play(), 0)
	# a material registered after the rise
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() { ALBEDO = vec3(0.3, 0.9, 0.1); }\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	MaterialWarm3D.register(m, &"test_unwarmed")
	w.frame(1.0 / 60.0, 10)
	assert_eq(w.compiles_play(), 1, "a registry key first seen in PLAY counts")
	assert_eq(String((w.first_use[0] as Dictionary).get("source", "")), "registry")
	# a visible instance with a never-seen shader, found by the periodic scan
	var sh2 := Shader.new()
	sh2.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() { ALBEDO = vec3(0.9, 0.1, 0.5); }\n"
	var m2 := ShaderMaterial.new()
	m2.shader = sh2
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = m2
	root.add_child(mi)
	w.scan(11)
	assert_eq(w.compiles_play(), 2, "a scene shader first visible in PLAY counts")
	w.scan(12)
	assert_eq(w.compiles_play(), 2, "each shader counts once")
	assert_eq(String((w.first_use[1] as Dictionary).get("node", "?")), String(root.get_path_to(mi)), "the record names the node")
	# BaseMaterial3D: one generated shader per feature set, shared — a new colour is not a compile, a new mode is
	var sm_a := StandardMaterial3D.new()
	sm_a.grow = true
	sm_a.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var sm_b := StandardMaterial3D.new()
	sm_b.grow = true
	sm_b.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm_b.albedo_color = Color.RED
	var sm_c := StandardMaterial3D.new()
	sm_c.grow = true
	sm_c.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm_c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	assert_eq(ShaderWatch.shader_key(sm_a, false), ShaderWatch.shader_key(sm_b, false), "same features, same shader")
	assert_ne(ShaderWatch.shader_key(sm_a, false), ShaderWatch.shader_key(sm_c, false), "a new mode is a new shader")
	var n0 := w.compiles_play()
	for mat: StandardMaterial3D in [sm_a, sm_b, sm_c]:
		var mb := MeshInstance3D.new()
		mb.mesh = QuadMesh.new()
		mb.material_override = mat
		root.add_child(mb)
	w.scan(13)
	assert_eq(w.compiles_play(), n0 + 2, "sm_a and sm_c are first uses; sm_b shares sm_a's shader")
	# hitches: frames far over the running median
	for i in 20:
		w.frame(1.0 / 60.0, 20 + i)
	w.frame(0.2, 99)
	assert_eq(w.hitches.size(), 1, "a 200 ms frame among 16 ms ones is a hitch")
	MaterialWarm3D.clear()
	root.queue_free()
	await tree.process_frame


# --- curtain call, Gag Reel ------------------------------------------------------------------------------------

func test_g0_curtain_call_has_3d_bows_and_again() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "view": "3d"})
	await _wait_phase(n, NightScene.Phase.PLAY)
	await _frames(5)
	n._on_night_end("g0_done")
	await _frames(3)
	var cc: CurtainCall = n.curtain_call
	if not assert_true(cc != null, "the curtain call runs"):
		await _free(n)
		return
	assert_true(cc.view3d, "over the 3D view")
	assert_true(cc.bows is CurtainBows3D, "the bows are 3D")
	assert_eq(cc.apron.hush, null, "no 2D rig is loaded for the bows")
	assert_true(cc.results != null, "Gate 0's results (Again ▶ / Stage door) from the first frame")
	var got := [-1]
	n.retry_done.connect(func(ms: int) -> void: got[0] = ms)
	cc.press("again")
	for i in 240:
		if got[0] >= 0:
			break
		await tree.process_frame
	assert_between(got[0], 0, 1500, "Again ▶ → live control %d ms" % got[0])
	assert_true(n.world_view.is_processing(), "the world view runs again after the call")
	await _free(n)


func test_curtain_bows_place_the_actors_on_the_lip() -> void:
	var b := CurtainBows3D.new()
	b.no_rigs = true
	tree.root.add_child(b)
	await tree.process_frame
	var p := b.lip_point(0.5, CurtainBows3D.FEET_Y, 0.0)
	assert_almost_eq(p.x, 0.0, 0.001, "centre")
	assert_almost_eq(p.y, 0.0, 0.001, "feet on y 0 at FEET_Y")
	var q := b.lip_point(0.0, CurtainBows3D.FEET_Y, 0.0)
	assert_lt(q.x, -1.0, "the left edge is metres to the left")
	assert_false(b.visible, "nothing on: nothing rendered")
	b.pose_hush(0.5, "hush/act_bow", 1, 85.0)
	assert_true(b.visible and b.vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Hush on: the lip renders")
	b.hide_hush()
	assert_false(b.visible)
	b.queue_free()
	await tree.process_frame


func test_the_gag_reel_shows_its_first_frame_at_once() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "view": "3d"})
	await _wait_phase(n, NightScene.Phase.PLAY)
	await _frames(40)
	var rec: MomentRecorder3D = n.world_view.recorder
	var t1: int = rec.last_tick()
	var id := rec.keep(maxi(0, t1 - 30), t1, "gag:test", 5)
	var moments := [{"rec": id, "prank": "achoo_ria", "start": maxi(0, t1 - 18), "end": t1, "accent": t1 - 5, "applause": 5}]
	var reel := GagReel3D.new()
	n.add_child(reel)
	reel.prime(n, moments)
	assert_true(reel.primed, "primed on the call's first frame")
	assert_eq(reel.frames_shown, 1, "frame 1 is posed before the reel step")
	assert_eq(reel.viewport.render_target_update_mode, SubViewport.UPDATE_ONCE, "and rendered once: the slot is never empty")
	assert_false(n.world_view.is_processing(), "the world view is held while the reel poses it")
	reel.start(n, moments, 2.0)
	await _frames(10)
	assert_true(reel.playing)
	assert_gt(reel.frames_shown, 5, "it plays the recorded frames")
	reel.stop()
	assert_true(n.world_view.is_processing(), "handed back")
	await _free(n)


# --- the stage door ---------------------------------------------------------------------------------------------

func _ids(menu: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for m in menu:
		out.append(String(m[0]))
	return out


func test_stage_door_entries() -> void:
	var plain := _ids(StageDoor.menu3d(0.0, false))
	assert_true(plain.has("gate0") and plain.has("prologue") and plain.has("cast"), "Gate 0, the Prologue, Cast")
	assert_false(plain.has("g0_head_b"), "no head buttons without the head_b variant")
	assert_false(plain.has("night1_preview") or plain.has("night1"), "N1/N2 hidden by default")
	assert_false(plain.has("hush_pip"), "no Pip toggle in 3D (R7)")
	var heads := StageDoor.menu3d(1.2, false)
	var hid := _ids(heads)
	assert_true(hid.has("g0_head_b") and hid.has("g0_head_scaled"), "both head buttons with head_b")
	for m in heads:
		if String(m[0]) == "g0_head_scaled":
			var label := StageDoor.label(String(m[1]), m[2])
			assert_true(label.contains("×1.2"), "the scale in the label: %s" % label)
			assert_false(label.contains(" A") or label.contains(" B "), "never head A / B")
		if String(m[0]) == "g0_head_b":
			assert_true(StageDoor.label(String(m[1])).contains("B's head"))
	var prev := _ids(StageDoor.menu3d(1.2, true))
	assert_true(prev.has("night1_preview") and prev.has("night2_preview"), "previews when show_previews is on")
	assert_eq(StageDoor.head_label(1.2), "1.2")
	assert_eq(StageDoor.head_label(1.25), "1.25")
	assert_eq(StageDoor.head_label(1.0), "1")


func test_stage_door_previews_open_behind_the_wip_card() -> void:
	var sd := StageDoor.new()
	sd.dry_run = true
	tree.root.add_child(sd)
	await tree.process_frame
	var got: Array = []
	sd.launched.connect(func(what: String, p: Dictionary) -> void: got.append([what, p]))
	sd.press("night1_preview")
	assert_true(sd.wip_card != null, "the WIP card first")
	assert_eq(String(got[0][0]), "wip")
	sd.press("gate0")
	assert_eq(got.size(), 1, "the menu is blocked behind the card")
	sd.press("wip_play")
	assert_eq(String(got[got.size() - 1][0]), "night")
	assert_eq(String((got[got.size() - 1][1] as Dictionary).get("episode", "")), "n01_throat_tea", "then N1 plays")
	assert_true(sd.wip_card == null)
	sd.press("g0_head_scaled")
	assert_eq(String(ViewKit.setting("hush_head", "?")), "head_b", "the scaled head for this Gate 0")
	sd.press("g0_head_b")
	assert_eq(String(ViewKit.setting("hush_head", "?")), "", "B's head")
	sd.queue_free()
	await tree.process_frame


# --- the e2e report + quantised checks ------------------------------------------------------------------------

func test_a_frame_quantised_check() -> void:
	assert_true(E2eScenarios.within_quantised(0.35, 0.3, 0.4), "0.35 s passes max(0.3, one 400 ms frame)")
	assert_false(E2eScenarios.within_quantised(0.45, 0.3, 0.4), "0.45 s fails it")
	assert_false(E2eScenarios.within_quantised(0.35, 0.3, 0.016), "at 60 fps the threshold holds")
	assert_true(E2eScenarios.within_quantised(1.5, 1.5, 0.016))


func test_perf3d_splits_the_scripts_into_sim_and_view() -> void:
	var p := Perf3D.new()
	for i in 40:
		p.add_script_ms(5.0, 2.0)
	p.add_script_ms(1.0, 3.0)   # a sim stamp past the frame's end is clamped to the frame
	var s := p.summary()
	assert_almost_eq(float(s["script_ms_p95"]), 5.0, 0.01)
	assert_almost_eq(float(s["sim_ms_p95"]), 2.0, 0.01)
	assert_almost_eq(float(s["view_ms_p95"]), 3.0, 0.01, "view + HUD = the frame's scripts minus the sim")


func test_retired_n02_scenarios_are_gone_and_strict_scope() -> void:
	assert_false(E2eScenarios.is_route("n02_face_to_face"))
	assert_false(E2eScenarios.is_route("n02_face_to_face_lost"))
	assert_true(E2eScenarios.thresholds("g0_sneeze").has("fallbacks_max"), "g0 fallbacks fail --strict")
	assert_true(E2eScenarios.thresholds("prologue_ideal").has("fallbacks_max"), "P00 fallbacks fail --strict")
	assert_false(E2eScenarios.thresholds("n01_ideal").has("fallbacks_max"), "N01 fallbacks are info (R9)")
	assert_eq(int(E2eScenarios.thresholds("g0_sneeze").get("shader_compiles_play_max", -1)), 0)


func test_the_probe_report_has_the_3d_fields() -> void:
	allow_errors()
	var n := _make({"episode": "g0_sneeze", "from": "test", "skip_intro": true, "view": "3d"})
	var probe := E2eProbe.new()
	tree.root.add_child(probe)
	probe.attach(n)
	await _wait_phase(n, NightScene.Phase.PLAY)
	await _frames(70)
	var s := probe.summary()
	for k in ["view", "fallback_counts", "hud_pieces", "overlays", "visibility", "pip_on_share", "pip_longest_s", "pip_windows",
			"frame_ms_p50", "frame_ms_p95", "perf3d", "cue_staged", "doubles", "laugh_cues"]:
		assert_true(s.has(k), "report field %s" % k)
	assert_eq(String(s["view"]), "3d")
	assert_gt((s["hud_pieces"] as Array).size(), 0, "HUD pieces sampled every 30 PLAY frames")
	assert_gt(((s["visibility"] as Dictionary)["rows"] as Array).size(), 0, "a visibility row per tick")
	for k2 in ["draw_calls_p95", "draw_calls_max", "tris_max", "emitters_max", "tex_mb_max", "shader_compiles_play", "script_ms_p95", "view_ms_p95", "sim_ms_p95"]:
		assert_true((s["perf3d"] as Dictionary).has(k2), "perf3d.%s" % k2)
	assert_between(float(s["pip_on_share"]), 0.0, 1.0)
	probe.queue_free()
	await _free(n)
