## RigPlayer across world resets (s2-fix G #17): Gate 0 loops Again ▶ on the phone, and each retry
## runs CharacterView.reset → RigPlayer.reset_layers() and a fresh play(). 20 × (reset_layers + play
## base + play overlay + a few frames) must not grow the object count (≤ 2 after warm-up): looks,
## materials, canvas items and plans are reused, not rebuilt per reset.
extends TestBase

const CLIPS := ["bellows/loco_idle", "bellows/rx_sneeze_blast_a", "bellows/loco_strut"]


func _cycle(p: RigPlayer, i: int) -> void:
	p.reset_layers()
	p.play(String(CLIPS[i % CLIPS.size()]), {"seed": i})
	p.play("bellows/mg_pinkie_up", {"layer": "overlay"})
	for f in 8:
		p.advance(1.0 / 60.0)


func test_twenty_resets_do_not_grow_objects() -> void:
	var p := RigPlayer.new()
	p.manual = true
	tree.root.add_child(p)
	p.setup("bellows")
	if p.rig == null:
		p.free()
		skip("bellows rig did not load")
		return
	for w in 6:
		_cycle(p, w)
	var o0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var counts: Array = []
	for i in 20:
		_cycle(p, i)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_COUNT) - o0))
	print("  [objects] per reset: %s" % [counts])
	assert_le(Performance.get_monitor(Performance.OBJECT_COUNT) - o0, 2.0, "20 resets: %s" % [counts])
	p.free()


func _cv_cycle(cv: CharacterView, i: int) -> void:
	cv.reset()
	var a := ViewSnapshot.Actor.new()
	a.present = true
	a.room = "kitchen"
	a.x = 3000.0
	a.facing = 1 if i % 2 == 0 else -1
	a.state = "idle" if i % 3 != 1 else "walk"
	a.moving = a.state == "walk"
	a.speed_px_s = 120.0 if a.moving else 0.0
	a.tier = i % 4
	if i % 2 == 1:
		a.residues = PackedStringArray(["SOAKED"])
	for f in 8:
		cv.apply(a, a, 0.0, 1.0 / 60.0)


func test_character_view_resets_do_not_grow_objects() -> void:
	var cv := CharacterView.new()
	cv.layout = HouseLayout.load_default()
	tree.root.add_child(cv)
	cv.setup("bellows")
	if not cv.uses_rig:
		cv.free()
		skip("bellows rig did not load")
		return
	for w in 6:
		_cv_cycle(cv, w)
	var o0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var counts: Array = []
	for i in 20:
		_cv_cycle(cv, i)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_COUNT) - o0))
	print("  [objects] CharacterView per reset: %s" % [counts])
	assert_le(Performance.get_monitor(Performance.OBJECT_COUNT) - o0, 2.0, "20 resets: %s" % [counts])
	cv.free()
