## GagStager on the FakeWorld timeline: ACHOO-RIA! at 680 (accent 772) → the camera approaches,
## punches in with a hit-stop on the accent, a caption pops, the Stalls laugh at T3;
## TIME'S UP (off screen while Hush rigs) goes to the escalated PiP; the first-time approach
## slow-mo fires before the prank.
extends TestBase

const DT := 1.0 / 60.0

var _sb: ViewSandbox = null


func before_each() -> void:
	_sb = ViewSandbox.new()
	_sb.scenario = "full"
	tree.root.add_child(_sb)
	await tree.process_frame
	_sb.set_process(false)


func after_each() -> void:
	_sb.queue_free()
	await tree.process_frame


func _until_tick(t: int, max_frames: int = 4000) -> void:
	var n := 0
	while _sb.driver.snapshot().tick < t and n < max_frames:
		_sb._process(DT)
		n += 1


func test_achoo_gag_punches_with_hitstop_and_caption() -> void:
	_sb._seek(640)
	var kinds: Array = []
	_until_tick(682)
	assert_true(_sb.cam.is_gag_active(), "gag requested at reaction_start")
	assert_eq(_sb.cam.gag_phase(), CameraDirector.GagPhase.APPROACH)
	# The accent: the sim's reaction_accent (FakeWorld tick 772) or — with the real rig clip — the
	# clip's own cam / hitstop keys on its accent frame (a couple of frames either side).
	var n := 0
	var hit := false
	while _sb.driver.snapshot().tick < 782 and n < 400:
		_sb._process(DT)
		n += 1
		hit = hit or String(_sb.driver.juice.last_kind()) == "hit_big"
	assert_true(hit, "5-frame hit-stop at the accent")
	assert_ne(_sb.cam.gag_phase(), CameraDirector.GagPhase.APPROACH, "punched in")
	for i in 14:
		_sb._process(DT)
	assert_almost_eq(_sb.cam.current_zoom() / _sb.cam.base_zoom(), 1.4, 0.03, "reactions.json cam.zoom 1.4")
	assert_ge(_sb.world_view.fx.captions_active(), 1, "ACHOO-RIA! caption")
	assert_eq(_sb.stalls.tier(), 3, "T3 laugh (+35 Applause)")


func test_first_time_approach_slowmo() -> void:
	_sb._seek(640)
	var saw := false
	var n := 0
	while _sb.driver.snapshot().tick < 680 and n < 400:
		_sb._process(DT)
		n += 1
		saw = saw or String(_sb.driver.juice.last_kind()) == "approach_slowmo"
	assert_true(saw, "0.5× over the last 24 frames before a first-time prank")


func test_off_screen_gag_goes_to_the_pip_while_rigging() -> void:
	_sb._seek(1190)
	_until_tick(1205)
	assert_true(_sb.pip.is_escalated(), "TIME'S UP in the hall while Hush rigs in the kitchen")
	assert_true(_sb.pip.is_shown())


func test_clip_cam_keys_only_time_his_reaction() -> void:
	_sb._seek(300)
	_sb._process(DT)
	assert_false(_sb.cam.is_gag_active())
	# Outside a reaction (a stand-in's take, Hush's poses): no framing.
	_sb.stager.on_clip_event({"type": "cam", "op": "punch", "zoom": 1.4, "actor": "bellows"})
	_sb.stager.on_clip_event({"type": "cam", "op": "punch", "zoom": 1.4, "actor": "hush"})
	assert_false(_sb.cam.is_gag_active(), "clip cam keys never start a gag on their own")
	# During ACHOO-RIA!'s approach his clip's cam key punches the sim-requested gag.
	_sb._seek(690)
	_sb._process(DT)
	assert_eq(_sb.cam.gag_phase(), CameraDirector.GagPhase.APPROACH)
	_sb.stager.on_clip_event({"type": "cam", "op": "punch", "actor": "hush"})
	assert_eq(_sb.cam.gag_phase(), CameraDirector.GagPhase.APPROACH, "Hush's clip does not punch")
	_sb.stager.on_clip_event({"type": "cam", "op": "punch", "actor": "bellows"})
	assert_ne(_sb.cam.gag_phase(), CameraDirector.GagPhase.APPROACH, "his reaction clip punches")
