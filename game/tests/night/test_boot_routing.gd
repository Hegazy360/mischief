## Boot routing matrix (s2-night §4.2): boot_config start values × first launch / later launches, the
## debug-only stage door, next-episode order (never a draft), and the launch rise window.
extends TestBase

const EPS := {
	"p00_curtain_up": {"status": "final", "act": 0, "index": 0},
	"n01_throat_tea": {"status": "final", "act": 1, "index": 1},
	"n02_something_fishy": {"status": "final", "act": 1, "index": 2},
	"n03_singing_in_the_bath": {"status": "draft", "act": 1, "index": 3},
	"g0_sneeze": {"status": "draft", "act": 0, "index": 0},
}


func _r(start: String, done: bool, stars: Dictionary = {}, debug: bool = true) -> String:
	var r := BootRouting.start_for(start, done, stars, EPS, debug)
	var ep := String((r["params"] as Dictionary).get("episode", ""))
	return "%s%s" % [r["route"], ":" + ep if ep != "" else ""]


func test_matrix() -> void:
	assert_eq(_r("auto", false), "night:p00_curtain_up", "first launch → the Prologue")
	assert_eq(_r("auto", true), "night:n01_throat_tea", "later → N01 without a star")
	assert_eq(_r("auto", true, {"n01_throat_tea": [true, false, false]}), "night:n02_something_fishy")
	assert_eq(_r("auto", true, {"n01_throat_tea": [true, true, true], "n02_something_fishy": [true, false, false]}), "playbill")
	assert_eq(_r("stage_door", false), "stage_door", "the Gate-0 APK")
	assert_eq(_r("stage_door", false, {}, false), "night:p00_curtain_up", "no stage door in a release build")
	assert_eq(_r("g0_sneeze", true), "night:g0_sneeze", "an episode id")
	assert_eq(_r("nope", false), "night:p00_curtain_up", "unknown → auto")


func test_next_episode_never_a_draft() -> void:
	assert_eq(BootRouting.next_after("p00_curtain_up", EPS), "n01_throat_tea")
	assert_eq(BootRouting.next_after("n01_throat_tea", EPS), "n02_something_fishy")
	assert_eq(BootRouting.next_after("n02_something_fishy", EPS), "", "after the last slice Night: To be continued")
	assert_eq(BootRouting.next_after("g0_sneeze", EPS), "", "drafts have no next")


## (r3d QA Q-N1) Next ▶ to a slice Night that is still a hidden preview opens the stage door's WIP card on it.
func test_next_to_a_hidden_preview_opens_the_wip_card() -> void:
	var to := BootRouting.after_next("n01_throat_tea", false, true)
	assert_eq(String(to["route"]), "stage_door", "previews hidden: the stage door, not N01")
	assert_eq(String((to["params"] as Dictionary).get("wip", "")), "n01_throat_tea", "with the WIP card on N01")
	to = BootRouting.after_next("n02_something_fishy", false, true)
	assert_eq(String((to["params"] as Dictionary).get("wip", "")), "n02_something_fishy")
	to = BootRouting.after_next("n01_throat_tea", true, true)
	assert_eq(String(to["route"]), "night", "previews shown: straight on")
	assert_eq(String((to["params"] as Dictionary).get("episode", "")), "n01_throat_tea")
	to = BootRouting.after_next("n01_throat_tea", false, false)
	assert_eq(String(to["route"]), "night", "a release build (no stage door) plays it")
	assert_eq(String(BootRouting.after_next("", false, true)["route"]), "to_be_continued")
	assert_eq(String(BootRouting.after_next("n03_singing_in_the_bath", false, true)["route"]), "night",
		"a Night that is not a slice preview is never guarded")


func test_live_content_next_after_n02_is_to_be_continued() -> void:
	var t := BootRouting.episode_table()
	if t.is_empty():
		skip("no Content autoload")
		return
	# Stage 2: N03+ are drafts, so Next ▶ after N02 is the "To be continued…" card.
	var nxt := BootRouting.next_after("n02_something_fishy", t)
	assert_true(nxt == "" or String((t[nxt] as Dictionary)["status"]) == "final")


func test_read_config() -> void:
	var p := "user://test_boot_config.json"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string('{"start": "stage_door"}')
	f.close()
	assert_eq(BootRouting.read_config(p), "stage_door")
	assert_eq(BootRouting.read_config("user://missing_config.json"), "auto")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_shipped_config_is_valid() -> void:
	var v := BootRouting.read_config()
	assert_true(v == "auto" or v == "stage_door" or EPS.has(v), "boot_config.json start = %s" % v)


func test_rise_window() -> void:
	var boot: GDScript = load("res://scenes/boot/boot.gd")
	assert_eq(boot.call("rise_window", 2.3), Vector2i(2300, 3000))
	assert_eq(boot.call("rise_window", 1.0), Vector2i(2000, 3000), "never before 2.0 s")
	assert_eq(boot.call("rise_window", 9.0), Vector2i(3000, 3000))
