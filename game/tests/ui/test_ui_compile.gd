## Every UI-owned script parses and instantiates; strings.json is valid and every key the UI
## asks for exists; every icon in res://art/ui rasterises.
extends TestBase

const SCRIPTS := [
	"res://autoload/settings.gd", "res://autoload/save.gd", "res://autoload/haptics.gd", "res://autoload/router.gd",
	"res://autoload/support/safe_area.gd", "res://autoload/support/ui_scale.gd",
	"res://autoload/support/fade_transition.gd", "res://autoload/support/curtain_transition.gd",
	"res://autoload/support/coming_soon_screen.gd", "res://autoload/support/safe_file.gd",
	"res://ui/theme/ui_kit.gd", "res://ui/theme/ui_icons.gd", "res://ui/theme/ui_strings.gd",
	"res://ui/input/gesture_config.gd", "res://ui/input/input_router.gd", "res://ui/input/tap_assist.gd",
	"res://ui/widgets/touch_widget.gd", "res://ui/widgets/hud_button.gd", "res://ui/widgets/pause_button.gd",
	"res://ui/widgets/overview_button.gd", "res://ui/widgets/action_button.gd", "res://ui/widgets/clarence_button.gd",
	"res://ui/widgets/tray.gd", "res://ui/widgets/applause_meter.gd", "res://ui/widgets/tomatoes.gd",
	"res://ui/widgets/running_gag_banner.gd", "res://ui/widgets/figgis_chip.gd", "res://ui/widgets/pip_frame.gd",
	"res://ui/widgets/edge_bubble.gd", "res://ui/widgets/pick_strip.gd", "res://ui/widgets/ghost_finger.gd",
	"res://ui/widgets/ui_button.gd", "res://ui/panels/ui_panel.gd", "res://ui/panels/script_panel.gd",
	"res://ui/panels/pause_menu.gd", "res://ui/panels/settings_panel.gd", "res://ui/panels/loading_card.gd",
	"res://ui/panels/results_screen.gd", "res://ui/hud.gd", "res://ui/hud_model.gd", "res://ui/hud_layout.gd",
	"res://ui/demo/ui_demo.gd",
]
const ICONS := [
	"verb_freeze", "verb_pop_out", "pin", "play", "hand_rig", "ff", "clarence", "pause", "overview", "overview_back",
	"figgis_chip", "script", "tomato", "tomato_splat", "star", "star_empty", "rose", "candle", "ribbon", "wax_seal",
	"stamp_beret", "stamp_tick", "arrow", "ghost_finger", "tray", "gear", "retry", "lock", "item_fallback",
	"bellows_face", "glyph_specs_off", "glyph_specs_on", "glyph_blinded", "glyph_asleep", "glyph_stars",
	"badge_gold", "badge_hide", "badge_in_use", "badge_needs",
]


func test_scripts_load() -> void:
	for p in SCRIPTS:
		var s := load(p) as Script
		assert_true(s != null and s.can_instantiate(), "script loads: %s" % p)


func test_strings_json_valid() -> void:
	var d: Variant = TestBase.load_json("res://data/ui/strings.json")
	assert_true(d is Dictionary, "strings.json parses")
	if not (d is Dictionary):
		return
	assert_eq(int((d as Dictionary).get("version", 0)), 1, "strings.json version 1")
	UiStrings.reload()
	for k in ["hud.running_gag", "pause.resume", "pause.bow", "results.next", "settings.relaxed", "loading.tap_to_start",
			"script.title", "router.coming_soon", "hud.edge_upstairs"]:
		assert_true(UiStrings.has(k), "string key %s" % k)
	assert_eq(UiStrings.t("hud.mult", {"m": "1.5"}), "×1.5")
	assert_eq(UiStrings.t("no.such.key"), "no.such.key", "unknown keys fall back to the key")


func test_every_icon_rasterises() -> void:
	UiIcons.clear_cache()
	for id in ICONS:
		var t := UiIcons.get_icon(StringName(id))
		assert_true(t != null, "icon %s" % id)
		if t != null:
			assert_ge(t.get_width(), 128, "icon %s is rasterised at ≥ 2× a 64 px canvas" % id)


func test_icon_aliases_and_fallbacks() -> void:
	assert_true(UiIcons.glyph("zz") != null, "glyph alias zz → asleep")
	assert_true(UiIcons.glyph("specs_on") != null)
	assert_true(UiIcons.badge("red") != null, "badge alias red → in_use")
	assert_true(UiIcons.item("no_such_item_xyz") != null, "missing item → neutral fallback")
	assert_true(UiIcons.activity("no_such_activity_xyz") != null, "missing activity → fallback")
	assert_true(UiIcons.card("freeze") != null, "card key freeze")
