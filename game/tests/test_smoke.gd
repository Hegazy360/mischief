## Smoke test: the project boots and is configured for landscape.
extends TestBase


func test_landscape_base_resolution() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 1920)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 1080)


func test_boot_scene_loads() -> void:
	var packed := load("res://scenes/boot/Boot.tscn") as PackedScene
	assert_true(packed != null, "Boot.tscn loads")
