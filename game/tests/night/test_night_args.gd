## NightScene main-scene flags (s2-night §4.1) and the command-log normaliser.
extends TestBase


func test_parse_flags() -> void:
	var a := NightArgs.parse(PackedStringArray(["--episode=g0_sneeze", "--cmds=/tmp/x.json", "--seek-tick=600", "--paused"]))
	assert_eq(a["episode"], "g0_sneeze")
	assert_eq(a["cmds_path"], "/tmp/x.json")
	assert_eq(a["seek_tick"], 600)
	assert_true(bool(a["paused"]))
	assert_true(bool(a["given"]))
	var b := NightArgs.parse(PackedStringArray(["--shot=/x.png"]))
	assert_false(bool(b["given"]))
	assert_eq(b["seek_tick"], -1)


func test_normalise_sorts_stably_by_tick() -> void:
	var v := {"cmds": [[20, {"c": "b"}], [10, {"c": "a"}], [20, {"c": "c"}], ["bad"], [5, "not a dict"]]}
	var out := NightArgs.normalise_cmds(v)
	assert_eq(out.size(), 3)
	assert_eq(String(out[0][1]["c"]), "a")
	assert_eq(String(out[1][1]["c"]), "b", "array order kept within a tick")
	assert_eq(String(out[2][1]["c"]), "c")
	assert_eq(NightArgs.normalise_cmds([[1, {"c": "x"}]]).size(), 1, "bare list form")
