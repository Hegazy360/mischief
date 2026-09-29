## ClipEvents.between: f0 < f ≤ f1, sorted, loops wrap, frame-0 events fire on start.
extends TestBase


func _clip(loop: bool) -> ClipDef:
	var d := {"version": 1, "rig": "_mannequin", "length": 20, "loop": loop,
		"keys": [{"f": 0, "pose": "m_stand"}, {"f": 20, "pose": "m_stand_b"}],
		"events": [{"f": 5, "type": "sfx", "id": "b"}, {"f": 0, "type": "sfx", "id": "a"},
			{"f": 5, "type": "mark", "name": "accent"}, {"f": 19, "type": "sfx", "id": "c"}]}
	return ClipLib.from_dict(d, "_mannequin/ev", RigDef.for_id("_mannequin"), PoseLib.for_rig("_mannequin"))


func _ids(evs: Array) -> String:
	var s := PackedStringArray()
	for e in evs:
		s.append(String(e.get("id", e.get("name", ""))))
	return ",".join(s)


func test_between_semantics() -> void:
	var c := _clip(false)
	assert_eq(c.ev_f, PackedInt32Array([0, 5, 5, 19]), "sorted by frame (stable)")
	assert_eq(_ids(ClipEvents.between(c, -1.0, 0.0)), "a", "frame-0 events fire when starting")
	assert_eq(_ids(ClipEvents.between(c, 0.0, 4.9)), "")
	assert_eq(_ids(ClipEvents.between(c, 4.9, 5.0)), "b,accent", "inclusive end, file order at equal frames")
	assert_eq(_ids(ClipEvents.between(c, 5.0, 6.0)), "", "exclusive start")
	assert_eq(_ids(ClipEvents.between(c, 0.0, 20.0)), "b,accent,c")


func test_loop_wrap() -> void:
	var c := _clip(true)
	assert_eq(_ids(ClipEvents.between(c, 18.0, 1.0)), "c,a", "wraps: (18, 20) then [0, 1]")
	var out: Array = []
	assert_eq(ClipEvents.between_into(c, 3.0, 5.5, out), 2, "reusable buffer")
