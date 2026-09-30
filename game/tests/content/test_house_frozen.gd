## REDESIGN_3D §6.2 C3 — `house.json` does not change in R3D (x positions, rects, stations and ids stay; the 3D
## view reads them as they are and adds depth in `house3d.json`). Its SHA-256 and `cold_sets.json`'s are pinned
## to 67c7276's; a change is a request to the orchestrator, never an edit (ruling R3). The two slice stacks that
## stay live keep their ≥ 24 px gaps (kettle under the honey in Night 1, the fridge shelf over its door in Night 2).
extends TestBase

const PINNED := {
	"res://data/house/house.json": "33287f5eb63fd7a9e658da5ecac8dff37cff1172a6e5e9d0d61306857a000fe0",
	"res://data/house/cold_sets.json": "302e35a2ea1998ee06a6c69732399e9e4c706ab3177641354380579e9d46abad",
}
## [upper, lower] live stacks of the slice (REDESIGN §3.3) and the Night that keeps both live.
const STACKS := [["kitchen_honey", "kitchen_kettle", "n01_throat_tea"], ["kitchen_fridge_shelf", "kitchen_fridge", "n02_something_fishy"]]
const MIN_GAP_PX := 24


func test_house_and_cold_sets_are_byte_identical_to_67c7276() -> void:
	for path in PINNED:
		if not assert_true(FileAccess.file_exists(path), path):
			continue
		assert_eq(FileAccess.get_sha256(path), PINNED[path], "%s is frozen (REDESIGN_3D §6.2 C3, ruling R3)" % path)


func test_the_two_live_slice_stacks_keep_their_gaps() -> void:
	var h: Variant = TestBase.load_json("res://data/house/house.json")
	if not assert_true(h is Dictionary, "house.json"):
		return
	var rects := {}
	for hs in (h as Dictionary).get("hotspots", []):
		rects[String(hs.get("id", ""))] = hs.get("rect", [])
	var db := ContentDB.load_dir("res://data")
	for st in STACKS:
		var up: Array = rects.get(st[0], [])
		var lo: Array = rects.get(st[1], [])
		if not assert_true(up.size() == 4 and lo.size() == 4, "%s / %s rects" % [st[0], st[1]]):
			continue
		# rect = [x, y, w, h], y relative to the floor line (negative up): the upper rect's bottom is y + h
		var gap := float(lo[1]) - (float(up[1]) + float(up[3]))
		assert_ge(gap, MIN_GAP_PX, "%s over %s: %.0f px apart" % [st[0], st[1], gap])
		if db.errors.is_empty() and db.episodes.has(st[2]):
			var live := SimCtx.live_hotspots(db, db.episodes[st[2]])
			assert_true(live.has(st[0]) and live.has(st[1]), "%s: both halves of the stack are live" % st[2])
