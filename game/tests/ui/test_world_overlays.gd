## WorldOverlays (r3d-index §7.8) on FakeAnchors (2D mode): setup / apply, what each overlay node
## shows, the V6 counts it reports, protected HUD rects, tag flights into the Hud, and the pictogram
## art (every slice prank has its SVG declaring its previews.json ids).
extends TestBase

const FIXTURE := "res://tests/ui/fixtures/previews.json"

var _made: Array = []


func after_each() -> void:
	for n in _made:
		if is_instance_valid(n):
			(n as Node).free()
	_made.clear()


func _setup() -> Array:
	var fa := FakeAnchors.new()
	fa.size_override = Vector2(2400, 1080)
	fa.set_point("kitchen_honey", &"preview", Vector2(900, 420))
	fa.set_point("kitchen_honey", &"ring", Vector2(900, 560))
	fa.set_point("kitchen_kettle", &"preview", Vector2(1300, 520))
	fa.set_point("kitchen_pantry_curtain", &"eyes", Vector2(1800, 600))
	fa.set_actor(&"hush", Rect2(1000, 480, 160, 440))
	var wo := WorldOverlays.new()
	wo.size_override = Vector2(2400, 1080)
	tree.root.add_child(fa)
	tree.root.add_child(wo)
	_made.append(fa)
	_made.append(wo)
	wo.setup(fa, null)
	return [fa, wo]


func test_previews_ring_marker_and_counts() -> void:
	var s := _setup()
	var wo: WorldOverlays = s[1]
	var m := OverlayModel.new()
	var p := m.add_preview()
	p.hotspot = "kitchen_kettle"
	p.prank = "kettle_drum"
	p.pictogram = PackedStringArray(["kettle", "notes", "crack"])
	m.rig_ring.hotspot = "kitchen_honey"
	m.rig_ring.frac = 0.5
	m.rig_ring.active = true
	m.thought.hotspot = "kitchen_honey"
	m.thought.prank = "achoo_ria"
	wo.apply(m)
	assert_true(wo.previews[0].visible)
	assert_true(wo.ring.visible)
	assert_eq(wo.ring.position, Vector2(900, 560), "the ring sits on the prop, never moved")
	assert_true(wo.thought.visible)
	assert_eq(wo.shown_count, 3)
	assert_eq(wo.loud_count, 2, "thought + ring")
	# danger: marker only
	m.clear()
	m.safety_marker.hotspot = "kitchen_pantry_curtain"
	wo.apply(m)
	assert_true(wo.marker.visible)
	assert_false(wo.previews[0].visible)
	assert_false(wo.thought.visible)
	assert_eq(wo.shown_count, 1)


func test_thought_is_beside_her_head_on_its_side() -> void:
	var s := _setup()
	var wo: WorldOverlays = s[1]
	var m := OverlayModel.new()
	m.thought.hotspot = "kitchen_honey"
	m.thought.prank = "achoo_ria"
	m.thought.side = -1
	wo.apply(m)
	assert_lt(wo.thought.position.x, 1080.0, "left of her head")
	m.thought.side = 1
	wo.apply(m)
	assert_gt(wo.thought.position.x, 1080.0, "right of her head")


func test_hidden_model_hides_all() -> void:
	var s := _setup()
	var wo: WorldOverlays = s[1]
	var m := OverlayModel.new()
	var p := m.add_preview()
	p.hotspot = "kitchen_kettle"
	p.prank = "kettle_drum"
	m.hidden = true
	wo.apply(m)
	assert_false(wo.previews[0].visible)
	assert_eq(wo.shown_count, 0)


func test_every_slice_prank_has_its_pictogram_svg() -> void:
	var pv: Dictionary = (TestBase.load_json(FIXTURE) as Dictionary)["pranks"]
	var live := OverlayCtx.load_previews()
	if not live.is_empty():
		pv = live.get("pranks", live)
	for prank in pv:
		var path := PreviewArt.DIR + String(prank) + ".svg"
		assert_true(FileAccess.file_exists(path), "missing pictogram %s" % path)
		var ids := PreviewArt.declared_ids(path)
		assert_eq(ids, PackedStringArray((pv[prank] as Dictionary)["pictogram"]),
			"%s declares the previews.json ids" % path)
		assert_true(PreviewArt.texture(String(prank), ids) != null, "%s rasterises" % path)


func test_the_preview_of_the_prop_she_is_at_is_exempt_from_its_protected_rect() -> void:
	# WorldView3D protects "the prop Hush is at + its preview" FOR that preview: it must not push it away,
	# while any other preview under that rect still slides
	var s := _setup()
	var fa: FakeAnchors = s[0]
	var wo: WorldOverlays = s[1]
	fa.set_point("kitchen_sink_tap", &"preview", Vector2(960, 430))
	fa.extra_protected = [Rect2(780, 300, 300, 200)]
	var m := OverlayModel.new()
	var a := m.add_preview()
	a.hotspot = "kitchen_honey"
	a.prank = "achoo_ria"
	var b := m.add_preview()
	b.hotspot = "kitchen_sink_tap"
	b.prank = "tap_dance"
	m.at_hotspot = "kitchen_honey"
	wo.apply(m)
	var ia := wo.placer.item(&"ov_preview_0")
	var ib := wo.placer.item(&"ov_preview_1")
	assert_true(ia != null and ib != null)
	assert_eq(ia.rect, ia.want, "her prop's preview stays on its anchor")
	assert_true(not ib.visible or ib.rect != ib.want, "another preview under that rect is moved (or waits)")
	# not at the prop: the same rect pushes it too
	m.at_hotspot = ""
	wo.apply(m)
	assert_ne(wo.placer.item(&"ov_preview_0").rect, wo.placer.item(&"ov_preview_0").want)


func test_the_view_takes_the_hud_rects_itself() -> void:
	var src := _HudRectsSource.new()
	var hud := _AlwaysOn.new()
	var wo := WorldOverlays.new()
	wo.size_override = Vector2(2400, 1080)
	tree.root.add_child(wo)
	_made.append(wo)
	wo.setup(src, hud)
	wo.apply(OverlayModel.new())
	assert_eq(src.hud_rects.size(), 1, "handed over")
	assert_eq(wo.protected_now().size(), 0, "not added a second time")


class _HudRectsSource:
	extends RefCounted
	var hud_rects: Array[Rect2] = []

	func protected_rects() -> Array[Rect2]:
		return []

	func anchor_of(_h: String, _k: StringName) -> Vector3:
		return Vector3.INF

	func actor_anchor(_a: StringName, _k: StringName) -> Vector3:
		return Vector3.INF

	func project(_p: Vector3) -> Vector2:
		return Vector2.INF


class _AlwaysOn:
	extends RefCounted
	var rects: Array[Rect2] = [Rect2(0, 0, 100, 100)]

	func always_on_rects() -> Array[Rect2]:
		return rects
