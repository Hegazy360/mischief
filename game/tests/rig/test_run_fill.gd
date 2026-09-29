## RigPlayer's triangle runs write only positions for a steady quad (s2-fix G #10): after any
## number of frames — smears, hidden parts, texture swaps — every run's vertices, uvs and colours
## equal a from-scratch rewrite of the same pose.
extends TestBase


func _sync(p: RigPlayer) -> void:
	if not p._discrete_same():
		p._sort_items()
	if p._layout_dirty:
		p._rebuild_layout()
	p._sync_render()


func test_steady_writes_match_a_full_rewrite() -> void:
	var p := RigPlayer.new()
	p.manual = true
	tree.root.add_child(p)
	p.setup("bellows")
	if p.rig == null:
		p.free()
		skip("bellows rig did not load")
		return
	p.play("bellows/rx_sneeze_blast_a", {"loop": true})
	var checked := 0
	for f in 240:
		p.advance(1.0 / 60.0)
		if f == 60:
			p.set_facing(-1, true)
		if f == 120:
			p.set_residue("SOAKED", true)
		_sync(p)
		if f % 20 != 19:
			continue
		for r in p._runs:
			var run: RigPlayer._Run = r
			var pts := run.pts.duplicate()
			var uvs := run.uvs.duplicate()
			var cols := run.cols.duplicate()
			run.qstate.fill(0)
			p._fill_run(run, Transform2D.IDENTITY)
			for v in pts.size():
				assert_true(pts[v].is_equal_approx(run.pts[v]), "frame %d vertex %d: %s vs %s" % [f, v, pts[v], run.pts[v]])
				assert_true(uvs[v].is_equal_approx(run.uvs[v]), "frame %d uv %d" % [f, v])
				assert_true(cols[v].is_equal_approx(run.cols[v]), "frame %d colour %d" % [f, v])
			checked += 1
	assert_gt(checked, 0, "bellows has triangle runs")
	p.free()
