## Save autoload (TECH §7): atomic write, reload, merge rules, migration, corrupt / future files.
extends TestBase

const SAVE_SCRIPT := "res://autoload/save.gd"
const DIR := "user://test_ui_save"

var path: String = ""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	path = "%s/save_%d.json" % [DIR, Time.get_ticks_usec()]


func after_each() -> void:
	for suffix in ["", ".tmp", ".bak", ".corrupt", ".v7"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _new_save() -> Node:
	var s: Node = (load(SAVE_SCRIPT) as GDScript).new()
	s.set("path", path)
	s.call("load_save")
	return s


func _write(text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_fresh_save_defaults() -> void:
	var s := _new_save()
	assert_eq(s.get("last_load"), "fresh")
	assert_false(bool(s.call("prologue_done")))
	var n: Dictionary = s.call("night", "n01_throat_tea")
	assert_eq(n, {"played": 0, "stars": [false, false, false], "best_applause": 0, "lines": [], "candles": [],
		"encores": []})
	s.free()


func test_record_result_writes_atomically_and_reloads() -> void:
	var s := _new_save()
	s.call("record_result", "n01_throat_tea", {"stars": [true, false, false], "applause": 64,
		"lines": ["kettle", "tap"], "candles": ["tap"], "catches": 2, "pranks": 3, "play_s": 300})
	assert_true(FileAccess.file_exists(path), "written (outside the tree: immediately)")
	assert_false(FileAccess.file_exists(path + ".tmp"), "the temp file was renamed away")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(d is Dictionary and int((d as Dictionary)["version"]) == 1, "valid JSON v1 on disk")
	s.free()
	var s2 := _new_save()
	assert_eq(s2.get("last_load"), "loaded")
	var n: Dictionary = s2.call("night", "n01_throat_tea")
	assert_eq(n["played"], 1)
	assert_eq(n["stars"], [true, false, false])
	assert_eq(n["best_applause"], 64)
	assert_eq(n["lines"], ["kettle", "tap"])
	assert_eq(n["candles"], ["tap"])
	assert_eq(s2.call("stats"), {"catches": 2, "pranks": 3, "play_s": 300})
	s2.free()


func test_merge_rules() -> void:
	var s := _new_save()
	s.call("record_result", "n02", {"stars": [true, false, true], "applause": 101, "lines": ["a", "b"], "candles": ["b"]})
	var n: Dictionary = s.call("record_result", "n02", {"stars": [false, true, false], "applause": 80,
		"lines": ["b", "c"], "candles": ["c"], "encores": ["e1"]})
	assert_eq(n["played"], 2)
	assert_eq(n["stars"], [true, true, true], "stars only grow")
	assert_eq(n["best_applause"], 101, "best applause is the max")
	assert_eq(n["lines"], ["a", "b", "c"], "lines union")
	assert_eq(n["candles"], ["c"], "b was done without a hint this time: its candle clears; c keeps one")
	assert_eq(n["encores"], ["e1"])
	var n3: Dictionary = s.call("record_result", "n02", {"lines": ["a"], "candles": ["a"]})
	assert_false((n3["candles"] as Array).has("a"), "a line once done cleanly never gets a candle")
	s.free()


func test_mark_seen_reports_new_once() -> void:
	var s := _new_save()
	assert_true(bool(s.call("mark_seen", "rx:achoo_ria:t1:a")), "first time → +NEW!")
	assert_false(bool(s.call("mark_seen", "rx:achoo_ria:t1:a")), "second time → not new")
	assert_true(bool(s.call("is_seen", "rx:achoo_ria:t1:a")))
	assert_false(bool(s.call("is_seen", "bit:bit_tea")))
	s.call("set_prologue_done")
	s.free()
	var s2 := _new_save()
	assert_true(bool(s2.call("is_seen", "rx:achoo_ria:t1:a")), "seen persists")
	assert_true(bool(s2.call("prologue_done")), "prologue_done persists")
	s2.free()


func test_debounced_in_tree() -> void:
	var s := _new_save()
	tree.root.add_child(s)
	var before := int(s.get("save_count"))
	s.call("mark_seen", "k1")
	s.call("mark_seen", "k2")
	assert_true(bool(s.call("is_pending")), "in the tree, writes wait for the 0.5 s debounce")
	assert_eq(int(s.get("save_count")), before, "nothing written yet")
	s.call("flush")
	assert_eq(int(s.get("save_count")), before + 1, "one write for both changes")
	assert_false(bool(s.call("is_pending")))
	s.queue_free()


func test_migrates_a_versionless_file() -> void:
	_write('{"prologue_done": true, "nights": {"n01_throat_tea": {"stars": 2, "best": 77, "lines": ["kettle"]}}, "seen": ["bit:bit_tea"]}')
	var s := _new_save()
	assert_eq(s.get("last_load"), "migrated")
	var n: Dictionary = s.call("night", "n01_throat_tea")
	assert_eq(n["stars"], [true, true, false], "int star count → array")
	assert_eq(n["best_applause"], 77, "best → best_applause")
	assert_eq(n["lines"], ["kettle"])
	assert_true(bool(s.call("is_seen", "bit:bit_tea")), "seen list → dict")
	assert_true(bool(s.call("prologue_done")))
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(int((d as Dictionary)["version"]), 1, "rewritten as v1")
	s.free()


func test_corrupt_file_is_backed_up_and_play_continues() -> void:
	_write("{ this is not json")
	var s := _new_save()
	assert_eq(s.get("last_load"), "corrupt")
	assert_true(FileAccess.file_exists(path + ".corrupt"), "the corrupt file is kept for inspection")
	assert_eq(FileAccess.get_file_as_string(path + ".corrupt"), "{ this is not json")
	assert_eq((s.call("night", "x") as Dictionary)["played"], 0, "fresh progress")
	assert_true(JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary, "a clean file replaced it")
	s.free()


func test_corrupt_file_falls_back_to_the_backup() -> void:
	var s := _new_save()
	s.call("record_result", "n01", {"applause": 50})
	s.call("record_result", "n01", {"applause": 60})   # second write keeps the first as .bak
	s.free()
	assert_true(FileAccess.file_exists(path + ".bak"), "previous good copy kept")
	_write("garbage")
	var s2 := _new_save()
	assert_eq(s2.get("last_load"), "backup")
	assert_eq((s2.call("night", "n01") as Dictionary)["played"], 1, "restored from .bak (one play behind)")
	s2.free()


func test_future_version_is_kept_aside() -> void:
	_write('{"version": 7, "nights": {}, "something_new": true}')
	var s := _new_save()
	assert_eq(s.get("last_load"), "future")
	assert_true(FileAccess.file_exists(path + ".v7"), "a newer build's save is copied aside, never destroyed")
	assert_eq(int((JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary)["version"]), 1)
	s.free()


func test_pure_migrate_sanitises() -> void:
	var script := load(SAVE_SCRIPT) as GDScript
	var out: Dictionary = script.call("migrate", {"nights": {"a": {"played": -3, "stars": [1, 0, "x", true]},
		"b": "junk"}, "stats": {"catches": -1, "pranks": 2}})
	assert_eq((out["nights"] as Dictionary).keys(), ["a"], "non-dict records dropped")
	assert_eq(out["nights"]["a"]["played"], 0, "negative clamped")
	assert_eq(out["nights"]["a"]["stars"], [true, false, false], "3 stars max; non-bool junk is false")
	assert_eq(out["stats"], {"catches": 0, "pranks": 2, "play_s": 0})
