## ReachMatrix (docs/research/animation.md phase 4): every container / rig point × facing through the real
## RigPlayer. The reach never adds an elbow pop over the authored clip; most props are reached or touched;
## the only props left short are the known very-high ones (the list below is the contract — a new "short"
## is a regression, a prop leaving it is progress to record).
extends TestBase

## Props too high for tiptoe + stretch + hop (they need a stool / climb clip — a later phase).
const KNOWN_SHORT: PackedStringArray = ["hall_clock", "parlour_chandelier", "garden_spotlight",
	"kitchen_pantry_shelf", "bathroom_cabinet", "landing_boiler_valve", "dressing_trophy_shelf"]


func test_hush_reach_matrix() -> void:
	var rows := ReachMatrix.run("hush", tree.root)
	assert_eq(rows.size(), 80, "40 props × 2 facings")
	var sum := ReachMatrix.summary(rows)
	var short := PackedStringArray()
	for r in rows:
		var where := "%s facing %d" % [r["hotspot"], r["facing"]]
		assert_ne(r["status"], "pop", "%s: a joint jumps %.0f°/f vs %.0f°/f authored — the reach snapped" % [where, r["max_joint_deg"], r["base_joint_deg"]])
		if r["status"] == "short":
			short.append(String(r["hotspot"]))
			assert_has(KNOWN_SHORT, r["hotspot"], "%s is short by %.0f px and not on the known-short list" % [where, r["best_px"]])
		elif r["status"] == "reached":
			assert_lt(float(r["best_px"]), ReachMatrix.REACHED_PX + 0.01)
	var ok := int(sum.get("reached", 0)) + int(sum.get("touch", 0))
	assert_ge(ok, 62, "at least 62 of 80 cells reached or touched (%s)" % JSON.stringify(sum))
	print("[reach_matrix] %s; short: %s" % [JSON.stringify(sum), ", ".join(short)])
