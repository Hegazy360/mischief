## The curtain call's step tables (s2-night §4.3): durations per kind, first vs repeat viewing, the
## Prologue sequence with the title card after the fall, and the kind for an episode / end reason.
extends TestBase


func _ids(kind: String, rep: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	for s in CurtainCall.steps(kind, rep):
		out.append(String((s as Dictionary)["id"]))
	return out


func test_night_first_viewing() -> void:
	assert_eq(_ids("night"), PackedStringArray(["fall", "bow", "results", "reel"]))
	assert_between(CurtainCall.total_s("night", false), 12.7, 12.8)
	assert_le(CurtainCall.total_s("night", false), 16.0, "≤ 16 s on a first viewing")


func test_night_repeat_viewing() -> void:
	assert_between(CurtainCall.total_s("night", true), 7.4, 7.5)
	assert_le(CurtainCall.total_s("night", true), 12.0, "≤ 12 s on a repeat viewing")
	var st: Array = CurtainCall.steps("night", true)
	assert_eq(float(st[1]["s"]), 0.8, "a shorter bow")
	assert_eq(float(st[3]["s"]), 4.0, "best 1 + new")


func test_prologue_title_after_the_fall() -> void:
	assert_eq(_ids("prologue"), PackedStringArray(["fall", "bow", "title", "results", "reel"]))
	assert_between(CurtainCall.total_s("prologue"), 10.3, 10.5)


func test_gate0_is_short() -> void:
	assert_eq(_ids("gate0"), PackedStringArray(["fall", "reel"]))
	assert_le(CurtainCall.total_s("gate0"), 6.0)


func test_kind_for() -> void:
	assert_eq(CurtainCall.kind_for("g0_sneeze", "g0_done"), "gate0")
	assert_eq(CurtainCall.kind_for("p00_curtain_up", "prologue_done"), "prologue")
	assert_eq(CurtainCall.kind_for("n01_throat_tea", "bow"), "night")
	assert_eq(CurtainCall.variant_for("gate0"), "gate0")
	assert_eq(CurtainCall.variant_for("prologue"), "prologue")
