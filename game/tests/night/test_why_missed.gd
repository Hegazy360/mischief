## The curtain call's why-missed line: first match in the fixed order (s2-night §4.3), on scripted results.
extends TestBase

const T := {"missed_required": "R {done}/{total} {missed}", "missed_optional": "O {missed}", "missed_big_number": "BN {missed}",
	"big_number_open": "BO {missed}", "short_link": "L {n}", "short_meltdown": "M {n}", "short_near_misses": "NM {n}",
	"short_bits": "B {n}", "short_combo": "C {n}", "short_embarrassed": "E {n}", "catches": "K {c} {lost}",
	"standing_ovation": "S {n}", "prologue": "P"}
const MISSED := {"kettle_drum": "sung a duet with his kettle", "n01:bn": "sneezed into the sink"}


func _line(id: String, done: bool, req: bool = false, bn: bool = false, sealed: bool = false, prank: String = "") -> Dictionary:
	return {"id": id, "done": done, "req": req, "big_number": bn, "sealed": sealed, "prank": prank, "text": id}


func _r(lines: Array, applause: int = 120, catches: int = 0, can: Dictionary = {}, maxed: Dictionary = {}) -> Dictionary:
	return {"episode": "n01", "applause": applause, "catches": catches, "lines": lines, "can": can, "maxed": maxed}


func test_order_table() -> void:
	var all_can := {"short_link": true, "short_meltdown": true, "short_near_misses": true, "short_bits": true,
		"short_combo": true, "short_embarrassed": true}
	var rows := [
		[_r([_line("kettle", false, true, false, false, "kettle_drum"), _line("x", false)]), "missed_required"],
		[_r([_line("kettle", true, true), _line("bn", false, false, true, true)]), "missed_big_number"],
		[_r([_line("kettle", true, true), _line("bn", false, false, true, false)]), "big_number_open"],
		[_r([_line("kettle", true, true), _line("opt", false), _line("bn", true, false, true)]), "missed_optional"],
		[_r([_line("kettle", true, true)], 80, 0, all_can), "short_link"],
		[_r([_line("kettle", true, true)], 80, 0, all_can, {"short_link": true}), "short_meltdown"],
		[_r([_line("kettle", true, true)], 80, 0, {"short_bits": true, "short_combo": true}), "short_bits"],
		[_r([_line("kettle", true, true)], 80, 0, {"short_combo": true, "short_embarrassed": true}), "short_combo"],
		[_r([_line("kettle", true, true)], 80, 0, {"short_embarrassed": true}), "short_embarrassed"],
		[_r([_line("kettle", true, true)], 80, 2, {}), "catches"],
		[_r([_line("kettle", true, true)], 130, 2, all_can), "catches"],
		[_r([_line("kettle", true, true)], 130, 0, all_can), "standing_ovation"],
	]
	for row in rows:
		assert_eq(WhyMissed.pick_key(row[0]), row[1])


func test_prologue_always_prologue() -> void:
	var r := _r([_line("a", false, true)])
	r["prologue"] = true
	assert_eq(WhyMissed.pick_key(r), "prologue")


func test_fill_uses_the_missed_phrases() -> void:
	var r := _r([_line("kettle", false, true, false, false, "kettle_drum"), _line("bn", false, false, true, true)])
	var out := WhyMissed.pick(r, T, MISSED)
	assert_eq(out["key"], "missed_required")
	assert_eq(out["text"], "R 0/2 sung a duet with his kettle")
	var r2 := _r([_line("kettle", true, true), _line("bn", false, false, true, true)])
	assert_eq(WhyMissed.pick(r2, T, MISSED)["text"], "BN sneezed into the sink", "episode:line key")
	var r3 := _r([_line("kettle", true, true)], 80, 3, {})
	assert_eq(WhyMissed.pick(r3, T, MISSED)["text"], "K 3 15", "catch cost")


func test_offers_respect_rules() -> void:
	var o := WhyMissed.offers({"rules": {"combos": [], "senses": false}}, 3, true)
	assert_false(bool(o["short_combo"]), "no combo where rules.combos is []")
	assert_false(bool(o["short_near_misses"]), "no near misses with senses off")
	assert_false(bool(o["short_embarrassed"]), "no Delphine")
	var o2 := WhyMissed.offers({"rules": {}, "cast": {"delphine": {"x": 1}}}, 3, true)
	assert_true(bool(o2["short_combo"]))
	assert_true(bool(o2["short_embarrassed"]))


func test_real_templates_exist_for_every_key() -> void:
	var b: Variant = ViewKit.json("res://data/barks.json")
	var t: Dictionary = (b as Dictionary).get("results", {}) if b is Dictionary else {}
	for k in ["missed_required", "missed_optional", "missed_big_number", "big_number_open", "catches", "standing_ovation",
			"prologue"] + Array(WhyMissed.SHORT_ORDER):
		assert_true(t.has(k), "barks.json results.%s" % k)
