## Soft integration check: the real game/data loads through the sim's ContentDB with no validation errors.
## Skips cleanly while `sim` is still building ContentDB (TECH §13 soft hook).
extends TestBase

const _DB := "res://sim/content/content_db.gd"


func test_real_data_validates_in_content_db() -> void:
	if not ResourceLoader.exists(_DB):
		skip("sim ContentDB not built yet")
		return
	var script := load(_DB) as Script
	if script == null or not script.has_method("load_dir"):
		skip("ContentDB has no load_dir yet")
		return
	var db: Object = script.call("load_dir", "res://data")
	if db == null:
		fail("ContentDB.load_dir returned null")
		return
	var errs: PackedStringArray = PackedStringArray()
	if "errors" in db:
		errs.append_array(db.get("errors"))
	if db.has_method("validate"):
		errs.append_array(db.call("validate"))
	var mine: Array[String] = []
	for e in errs:
		# house.json findings belong to art-house; everything else is content's to fix
		if not String(e).begins_with("house.json"):
			mine.append(String(e))
	for e in errs:
		print("  [content] ContentDB: ", e)
	assert_eq(mine.size(), 0, "ContentDB validation errors on content files")
	if db.has_method("validate_warnings"):
		for w in db.call("validate_warnings"):
			print("  [content] ContentDB warning: ", w)
