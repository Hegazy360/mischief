## Real icons everywhere (s2-ui §4.2.11): every item the tray / action button / pick strip can show
## and every activity the Script loop / bubble can show resolves to real art (never the "?" box),
## and the glyph / badge files the view's FxArt looks for exist under res://art/ui/.
extends TestBase


func _ids(path: String, key: String) -> PackedStringArray:
	var d: Variant = load_json(path)
	var out := PackedStringArray()
	if not (d is Dictionary):
		return out
	var sec: Variant = (d as Dictionary).get(key, d)
	if sec is Dictionary:
		for k in sec:
			if String(k) != "version":
				out.append(String(k))
	elif sec is Array:
		for e in sec:
			if e is Dictionary and (e as Dictionary).has("id"):
				out.append(String(e["id"]))
	return out


func test_every_item_has_real_art() -> void:
	var fallback := UiIcons.get_icon(&"item_fallback")
	var ids := _ids("res://data/items.json", "items")
	assert_gt(ids.size(), 10, "items.json read")
	for id in ids:
		var t := UiIcons.item(id)
		assert_true(t != null, "item %s" % id)
		assert_ne(t, fallback, "item %s shows its own icon, not the ? box" % id)


func test_every_activity_has_real_art() -> void:
	var fallback := UiIcons.get_icon(&"script")
	var d: Variant = load_json("res://data/activities.json")
	var acts: Variant = (d as Dictionary).get("activities", d) if d is Dictionary else {}
	assert_true(acts is Dictionary and not (acts as Dictionary).is_empty(), "activities.json read")
	for id in acts:
		if String(id) == "version":
			continue
		var a: Variant = acts[id]
		var icon := String((a as Dictionary).get("icon", "")) if a is Dictionary else ""
		var t := UiIcons.activity(icon if icon != "" else String(id))
		assert_true(t != null, "activity %s" % id)
		assert_ne(t, fallback, "activity %s shows its own icon" % id)


func test_view_glyph_and_badge_ids_match_the_files() -> void:
	for g in ["specs_off", "specs_on", "blinded", "asleep", "stars"]:
		assert_true(FileAccess.file_exists("res://art/ui/glyph_%s.svg" % g), "glyph_%s.svg (FxArt.glyph)" % g)
		assert_true(UiIcons.glyph(g) != null)
	for b in FxArt.BADGE_FILES.values():
		assert_true(FileAccess.file_exists("res://art/ui/%s.svg" % b), "%s.svg (FxArt.BADGE_FILES)" % b)
	for kind in ["gold", "hide", "in_use", "needs"]:
		assert_true(UiIcons.badge(kind) != null, "badge " + kind)


func test_stage2_ui_art_exists() -> void:
	for id in ["behind_you", "bellows_livid", "clarence_hold", "clock_fast", "arrow", "ghost_finger", "figgis_chip"]:
		assert_true(UiIcons.get_icon(StringName(id)) != null, "art/ui/%s.svg" % id)
	for e in EdgeBubble.EMOTES:
		assert_true(FileAccess.file_exists("res://art/ui/emote_%s.svg" % e), "emote_%s.svg" % e)
		assert_true(FileAccess.file_exists("res://art/ui/puff_%s.svg" % e), "puff_%s.svg" % e)
