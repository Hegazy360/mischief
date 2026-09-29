## RigEase: every ease matches Tween.interpolate_value at 11 points; hold / pop step.
extends TestBase


func test_every_family_ease_matches_tween() -> void:
	var names := RigEase.all_names()
	assert_eq(names.size(), 3 + 8 * 3, "linear, hold, pop + 8 families × in / out / in_out")
	var checked := 0
	for n in names:
		var id := RigEase.id(n)
		assert_ge(id, 0, "ease %s resolves" % n)
		var pair := RigEase.tween_pair(id)
		if pair[0] < 0:
			continue
		for i in 11:
			var t := float(i) / 10.0
			var want: float = Tween.interpolate_value(0.0, 1.0, t, 1.0, pair[0] as Tween.TransitionType, pair[1] as Tween.EaseType)
			var got := RigEase.apply(id, t)
			if not assert_almost_eq(got, want, 0.0001, "%s at t=%.1f" % [n, t]):
				return
			checked += 1
	assert_eq(checked, 24 * 11)


func test_linear_hold_pop() -> void:
	for i in 11:
		var t := float(i) / 10.0
		assert_almost_eq(RigEase.apply(RigEase.LINEAR, t), t)
		var step := 1.0 if i == 10 else 0.0
		assert_almost_eq(RigEase.apply(RigEase.HOLD, t), step, 0.0, "hold steps at the key")
		assert_almost_eq(RigEase.apply(RigEase.POP, t), step, 0.0, "pop steps at the key")
	assert_true(RigEase.is_step(RigEase.HOLD) and RigEase.is_step(RigEase.POP))
	assert_eq(RigEase.id("wobbly"), -1, "unknown names are rejected")
	assert_eq(RigEase.name_of(RigEase.id("out_back")), "out_back")


func test_back_overshoots_once() -> void:
	# Godot's out_back peaks ≈ 1.1 near t = 0.7: the one overshoot a settle needs.
	var peak := 0.0
	for i in 101:
		peak = maxf(peak, RigEase.apply(RigEase.id("out_back"), float(i) / 100.0))
	assert_between(peak, 1.08, 1.11)
