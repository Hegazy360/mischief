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
