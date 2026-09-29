## Pun captions never collide with the HUD's top band (s2-fix G #2): the ACHOO-RIA! pun was
## clipped under the RUNNING GAG banner during the sneeze punch-in. At 20:9, 16:9, 4:3 and with
## notch insets, at zoom 1.0 and the 1.4× punch-in, every frame of the stamp-in and hold keeps
## the caption's drawn rect clear of meter ∪ banner ∪ PiP; a caption pushed onto the head moves
## beside it.
extends TestBase

const SIZES := [Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1440, 1080)]
const INSETS := [Vector4(0, 0, 0, 0), Vector4(96, 0, 96, 0), Vector4(0, 72, 0, 40)]
const CAM := Vector2(3000, -500)
const DT := 1.0 / 60.0

var c: FxCaption = null


func before_each() -> void:
	c = FxCaption.new()
	tree.root.add_child(c)


func after_each() -> void:
	if is_instance_valid(c):
		c.free()


## world → screen for a camera at CAM with `zoom` on a viewport of `vp`.
static func _xf(vp: Vector2, zoom: float) -> Transform2D:
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0, vp * 0.5 - CAM * zoom)


static func _band(vp: Vector2, ins: Vector4, pip_on: bool) -> Array[Rect2]:
	var l := HudLayout.compute(vp, ins, false, 1.0)
	var out: Array[Rect2] = [l[&"meter"], l[&"banner"]]
	if pip_on:
		out.append(l[&"pip"])
	return out


## Runs one caption for 60 frames; returns the number of frames it overlapped a HUD rect.
func _run(vp: Vector2, ins: Vector4, zoom: float, anchor_screen: Vector2, pip_on: bool) -> int:
	var xf := _xf(vp, zoom)
	var inv := xf.affine_inverse()
	var screen_avoid := _band(vp, ins, pip_on)
	var world_avoid: Array[Rect2] = []
	for r in screen_avoid:
		world_avoid.append(inv * r)
	var view := inv * Rect2(Vector2.ZERO, vp)
	c.start("ACHOO-RIA!", inv * anchor_screen, 88, true)
	var bad := 0
	for i in 60:
		c.keep_in = view
		c.avoid = world_avoid
		c.tick(DT, 1.0 / zoom)
		if not c.active:
			break
		var rel := c.world_rect_rel(c.scale.x)
		var r := Rect2(c.position + rel.position, rel.size)
		for a in world_avoid:
			if r.intersects(a):
				bad += 1
				break
	return bad


func test_caption_clears_the_top_band_at_every_aspect_inset_and_zoom() -> void:
	var cases := 0
	for vp in SIZES:
		for ins in INSETS:
			for zoom in [1.0, 1.4]:
				for ax in [0.5, 0.35, 0.7]:
					for ay in [120.0, 220.0, 330.0]:
						var a := Vector2(vp.x * ax, ay)
						var bad := _run(vp, ins, zoom, a, false)
						cases += 1
						assert_eq(bad, 0, "vp %s insets %s zoom %.1f anchor %s: %d frames under the band" % [vp, ins, zoom, a, bad])
	assert_gt(cases, 100)


func test_caption_clears_the_pip_while_it_shows() -> void:
	for vp in SIZES:
		var l := HudLayout.compute(vp, Vector4.ZERO, false, 1.0)
		var pip: Rect2 = l[&"pip"]
		var a := Vector2(pip.get_center().x, pip.end.y - 20.0)
		assert_eq(_run(vp, Vector4.ZERO, 1.4, a, true), 0, "vp %s: caption under the PiP" % vp)


func test_a_caption_below_the_band_is_not_moved() -> void:
	var vp := Vector2(2400, 1080)
	var xf := _xf(vp, 1.0)
	var inv := xf.affine_inverse()
	var a := inv * Vector2(1200, 700)
	c.start("ACHOO-RIA!", a, 88, true)
	var world_avoid: Array[Rect2] = []
	for r in _band(vp, Vector4.ZERO, false):
		world_avoid.append(inv * r)
	for i in 20:
		c.avoid = world_avoid
		c.keep_in = inv * Rect2(Vector2.ZERO, vp)
		c.tick(DT, 1.0)
	assert_almost_eq(c.position.x, a.x, 0.01)
	assert_almost_eq(c.position.y, a.y, 0.01, "free space above his head: the caption stays where it was put")


func test_pushed_onto_the_head_it_moves_beside_it() -> void:
	# A band right above the anchor: pushing the caption below it would cover the head.
	var rel := Rect2(-300, -200, 600, 220)
	var head := FxCaption.HEAD_ZONE
	var p := Vector2(1000, 300)
	var band: Array[Rect2] = [Rect2(700, 0, 600, 250)]
	var keep := Rect2(0, 0, 2400, 1080)
	var q := FxCaption.place(p, rel, band, keep, head, 16.0)
	var r := Rect2(q + rel.position, rel.size)
	assert_false(r.intersects(band[0].grow(16.0)), "clear of the band")
	assert_false(r.intersects(Rect2(p + head.position, head.size)), "clear of his head (beside it)")
	assert_true(keep.encloses(r), "still on screen")
