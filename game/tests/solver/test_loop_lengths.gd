## Loop lengths of the real episodes, measured the way GDD §4.1 defines them: the planner's idle probe (Hush
## hidden, walking included). Act I MUST be ≤ 60 s (GDD §2.4 rule 5; docs/LEVELS.md §6 decision 1); the later
## Acts are reported against their bands so a retune shows up in the log.
extends TestBase

## Night 4 is the Act's two-floor finale: 30 s of its loop is stairs and corridors, so it has a 65 s allowance
## (GDD §2.4 rule 5).
const ACT1 := {"n01_throat_tea": 60.0, "n02_something_fishy": 60.0, "n03_singing_in_the_bath": 60.0, "n04_the_big_sulk": 65.0}
const BANDS := {
	"n05_enter_beryl": [80.0, 95.0], "n06_behind_you": [80.0, 95.0], "n07_kidding_around": [80.0, 95.0],
	"n08_companys_coming": [90.0, 120.0], "n09_tutu_much": [90.0, 120.0], "n10_it_takes_two": [90.0, 120.0],
	"gala_the_comeback": [90.0, 120.0]}


func _loop_s(data: SolverData, db: Object, ep: String) -> float:
	var pl := Planner.new(data, ep, Callable(), {"budget_ms": 1000})
	# Three loops; the steady-state length is the last pair of starts (Night 1's first loop carries a 25 s gate).
	var p := pl.predict(SolverHooks.make_world(db, ep), 3, 60 * 500)
	var first := SolverData.sv((p["activities"][0] as Dictionary).get("id", "")) if not (p["activities"] as Array).is_empty() else ""
	var starts := PackedInt32Array()
	for a in p["activities"]:
		if SolverData.sv(a.get("id", "")) == first:
			starts.append(int(a["t"]))
	if starts.size() < 2:
		return -1.0
	return (starts[starts.size() - 1] - starts[starts.size() - 2]) / 60.0


func test_act1_loops_meet_the_rule() -> void:
	if SolverHooks.sim_missing_reason() != "":
		skip("real sim missing")
		return
	var data := SolverData.load_dir("res://data")
	var db := SolverHooks.load_db("res://data")
	for ep in ACT1:
		var s := _loop_s(data, db, ep)
		print("loop %s = %.1f s" % [ep, s])
		assert_gt(s, 0.0, "%s: no second loop start" % ep)
		assert_le(s, float(ACT1[ep]), "%s loop %.1f s (Act I rule: ≤ %.0f s with Hush idle)" % [ep, s, ACT1[ep]])


func test_later_acts_report_their_loops() -> void:
	if SolverHooks.sim_missing_reason() != "":
		skip("real sim missing")
		return
	var data := SolverData.load_dir("res://data")
	var db := SolverHooks.load_db("res://data")
	for ep in BANDS:
		var s := _loop_s(data, db, ep)
		var band: Array = BANDS[ep]
		var flag := "" if s >= float(band[0]) and s <= float(band[1]) else "  <-- outside %s-%s s band" % [band[0], band[1]]
		print("loop %s = %.1f s%s" % [ep, s, flag])
		assert_gt(s, 0.0, "%s: no second loop start" % ep)
