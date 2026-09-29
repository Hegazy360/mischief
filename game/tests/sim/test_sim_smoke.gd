## Smoke: fixtures load, each fixture episode runs 3,600 ticks without errors.
extends TestBase


func test_fixtures_load_clean() -> void:
	var db := SimTestUtil.db()
	assert_eq(db.errors, PackedStringArray(), "fixture errors")
	assert_true(db.episodes.has("fx_act1"))


func test_episodes_run() -> void:
	for ep in ["fx_prologue", "fx_act1", "fx_meltdown"]:
		var w := SimTestUtil.world(ep)
		assert_true(w != null, ep)
		if w == null:
			continue
		var log := SimTestUtil.run(w, 3600)
		assert_gt(log.size(), 0, ep + " emits events")
