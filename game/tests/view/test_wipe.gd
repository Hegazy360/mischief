## FxWipe's ink ring (s2-fix G #5): at iris 1 (the first and last frames of every wipe) the old
## half-ring polygons self-intersected and Godot logged "Invalid polygon data, triangulation
## failed" (8 engine errors per caught route). Every polygon of a full 1 → 0 → 1 sweep at 20:9,
## 16:9 and 4:3 must triangulate (the exact check RenderingServer.canvas_item_add_polygon makes).
extends TestBase

const SIZES := [Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1440, 1080)]


func test_every_iris_frame_triangulates_at_every_aspect() -> void:
	var polys := 0
	for sv in SIZES:
		var s: Vector2 = sv
		for cv in [Vector2(0.5, 0.45), Vector2(0.2, 0.3), Vector2(0.85, 0.7)]:
			var centre: Vector2 = cv
			var c := Vector2(centre.x * s.x, centre.y * s.y)
			for i in 41:
				var iris := absf(1.0 - float(i) / 20.0)   # 1 → 0 → 1
				var r: float = iris * s.length() * 0.75
				for poly in FxWipe.ring_polygons(s, c, r):
					polys += 1
					assert_gt(Geometry2D.triangulate_polygon(poly).size(), 0,
						"%s centre %s iris %.2f: a polygon fails to triangulate" % [s, centre, iris])
	assert_gt(polys, 100)


func test_open_iris_draws_nothing_and_closed_iris_covers_the_screen() -> void:
	var s := Vector2(2400, 1080)
	var c := Vector2(1200, 486)
	assert_eq(FxWipe.ring_polygons(s, c, s.length() * 0.75).size(), 0, "iris 1: nothing to draw")
	var closed := FxWipe.ring_polygons(s, c, 0.0)
	assert_eq(closed.size(), 1, "iris 0: one full-screen rect")
	var area := 0.0
	for poly in FxWipe.ring_polygons(s, c, 300.0):
		var t := Geometry2D.triangulate_polygon(poly)
		for k in range(0, t.size(), 3):
			var a := poly[t[k]]
			var b := poly[t[k + 1]]
			var d := poly[t[k + 2]]
			area += absf((b - a).cross(d - a)) * 0.5
	var screen := (s.x + 20.0) * (s.y + 20.0)
	assert_almost_eq(area, screen - PI * 300.0 * 300.0, screen * 0.01, "ink = the screen minus the iris")


func test_wipe_node_runs_a_whole_sweep() -> void:
	var w := FxWipe.new()
	w.size = Vector2(1920, 1080)
	tree.root.add_child(w)
	w.start()
	var frames := 0
	while w.active() and frames < 60:
		w._process(1.0 / 60.0)
		frames += 1
	assert_false(w.active(), "the wipe ends")
	assert_between(frames, 11, 14, "12 frames")
	w.free()
