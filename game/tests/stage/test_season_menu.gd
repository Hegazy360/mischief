## The front-end prototype (res://proto/season/Season.tscn): it opens on the title screen, and the
## menu buttons move between the title, Scenes, Settings, an Act, its pause menu and back — as a
## player tapping them would (through _activate, the same path a tap takes). Saving is switched off.
extends TestBase

const SCENE := "res://proto/season/Season.tscn"


func _season() -> Control:
	var s: Control = (load(SCENE) as PackedScene).instantiate()
	s.set("_save_enabled", false)
	tree.root.add_child(s)
	return s


func test_opens_on_the_title_and_menus_navigate() -> void:
	var fps := Engine.max_fps
	var s := _season()
	assert_eq(s.get("_state"), "title", "opens on the title screen")
	s.call("_activate", "settings")
	assert_eq(s.get("_state"), "settings")
	s.call("_activate", "sound")
	assert_false(bool((s.get("_settings") as Dictionary)["sound"]), "sound toggles off")
	s.call("_activate", "back")
	assert_eq(s.get("_state"), "title")
	s.call("_activate", "scenes")
	assert_eq(s.get("_state"), "playbill")
	s.call("_activate", "poster:2")
	assert_eq(s.get("_state"), "playbill", "a locked poster does nothing")
	s.call("_activate", "poster:0")
	assert_eq(s.get("_state"), "act", "the first poster plays Act I")
	s.call("_activate", "pause")
	assert_eq(s.get("_state"), "paused")
	var show: Node = s.get("_show")
	assert_eq(show.process_mode, Node.PROCESS_MODE_DISABLED, "the Act stops while paused")
	s.call("_activate", "resume")
	assert_eq(s.get("_state"), "act")
	assert_eq(show.process_mode, Node.PROCESS_MODE_INHERIT)
	s.call("_activate", "menu")
	assert_eq(s.get("_state"), "title", "Main menu leaves the Act")
	assert_eq(s.get("_show"), null)
	s.queue_free()
	Engine.max_fps = fps


func test_curtain_call_unlocks_the_next_scene() -> void:
	var fps := Engine.max_fps
	var s := _season()
	s.call("_activate", "play")
	assert_eq(int(s.get("_cur")), 0, "a fresh PLAY starts Act I")
	assert_false(bool(s.call("_unlocked", 1)), "Act II locked before Act I's Curtain Call")
	var show: Node = s.get("_show")
	show.call("skip_to_card")
	for i in 240:
		show._process(1.0 / 60.0)
		s._process(1.0 / 60.0)
	assert_eq(s.get("_state"), "call", "the Curtain Call buttons come up")
	assert_true(bool(s.call("_unlocked", 1)), "Act II unlocked")
	s.call("_activate", "next")
	assert_eq(int(s.get("_cur")), 1, "Next plays Act II")
	assert_eq(int(s.call("_next_unseen")), 1, "Continue would resume at Act II")
	s.queue_free()
	Engine.max_fps = fps
