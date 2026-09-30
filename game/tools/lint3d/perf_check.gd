## PerfCheck3D — the 3D frame budget of REDESIGN §6.3 / index §6 row 16 on the e2e reports' `perf3d` blocks
## (`tools/scripts/perf3d.sh <e2e report.json>…`; the block is `r3d-night`'s Perf3D.summary, index §7.10).
##
## Budgets (desktop proxy): draw calls p95 ≤ 150 and max ≤ 250 · triangles max ≤ 150k · CPUParticles3D emitters max
## ≤ 8 · texture memory ≤ 250 MB · `shader_compiles_play` == 0 · view + HUD script time p95 ≤ 4 ms (the block's
## `view_ms_p95` when it has one — index §6 row 16 budgets the view + HUD scripts; `script_ms_p95` = view + HUD + sim
## otherwise, with `sim_ms_p95` reported as info). One table row per report; any breach is an error (exit 1). A report
## without a `perf3d` block (a headless or 2D run) is a SKIP.
class_name PerfCheck3D
extends RefCounted

## key → [limit, comparison ("<=" | "=="), owner, label].
const BUDGETS := {
	"draw_calls_p95": [150.0, "<=", "r3d-view3d", "draw calls p95"],
	"draw_calls_max": [250.0, "<=", "r3d-view3d", "draw calls max"],
	"tris_max": [150000.0, "<=", "r3d-view3d", "triangles max"],
	"emitters_max": [8.0, "<=", "r3d-view3d", "emitters max"],
	"tex_mb_max": [250.0, "<=", "r3d-night", "texture MB"],
	"shader_compiles_play": [0.0, "==", "r3d-night", "shader compiles in PLAY"],
	"script_ms_p95": [4.0, "<=", "r3d-view3d", "script ms p95"],
}
## The column order of the table.
const COLUMNS: PackedStringArray = ["draw_calls_p95", "draw_calls_max", "tris_max", "emitters_max", "tex_mb_max",
	"shader_compiles_play", "script_ms_p95"]


## Checks one report (`name` = its file stem). Returns {issues: Array, row: Dictionary}.
static func check(report: Dictionary, name: String) -> Dictionary:
	var issues: Array = []
	var row := {"report": name, "episode": String(report.get("episode", "")), "scenario": String(report.get("scenario", name))}
	var p: Variant = report.get("perf3d", null)
	if typeof(p) != TYPE_DICTIONARY or (p as Dictionary).is_empty():
		issues.append(Lint3D.skip("perf", "perf3d", "%s has no perf3d block (run e2e.sh with --perf-log, rendered)" % name,
			"r3d-night", row["episode"]))
		row["status"] = "SKIP"
		return {"issues": issues, "row": row}
	var pd: Dictionary = p
	var ok := true
	for key in COLUMNS:
		var b: Array = BUDGETS[key]
		var src := key
		if key == "script_ms_p95" and pd.has("view_ms_p95"):
			src = "view_ms_p95"
		if not pd.has(src):
			issues.append(Lint3D.skip("perf", key, "%s perf3d has no %s" % [name, key], "r3d-night", row["episode"]))
			row[key] = null
			continue
		var v := float(pd[src])
		row[key] = v
		var limit := float(b[0])
		var breach := v != limit if String(b[1]) == "==" else v > limit
		if breach:
			ok = false
			var det := ""
			if key == "shader_compiles_play" and pd.has("compile_detail"):
				det = JSON.stringify(Lint3D.to_json((pd["compile_detail"] as Dictionary).get("first_use", [])))
			elif key == "script_ms_p95" and is_equal_approx(v, float(pd.get("process_ms_p95", -1.0))):
				det = "equals process_ms_p95: the report's script timer fell back to the process time (render + GPU wait on the proxy)"
			if src != key:
				det = "view + HUD scripts (%s)" % src
			issues.append(Lint3D.issue("perf", key, Lint3D.ERROR, row["episode"], "", name, v, "%s %s" % [b[1], b[0]],
				String(b[2]), det))
	if pd.has("view_ms_p95"):
		row["script_source"] = "view_ms_p95"
		issues.append(Lint3D.issue("perf", "script_split", Lint3D.INFO, row["episode"], "", name,
			"view + HUD %s ms, sim %s ms, all scripts %s ms (p95)" % [pd.get("view_ms_p95"), pd.get("sim_ms_p95", "?"),
			pd.get("script_ms_p95", "?")], "view + HUD ≤ 4 ms", "r3d-view3d / r3d-hud", "the budget judges view + HUD"))
	row["status"] = "PASS" if ok else "FAIL"
	return {"issues": issues, "row": row}


## The markdown table of the checked rows.
static func table(rows: Array) -> String:
	var hdr := PackedStringArray(["report", "status"])
	for key in COLUMNS:
		hdr.append(String((BUDGETS[key] as Array)[3]) + " (%s %s)" % [(BUDGETS[key] as Array)[1], (BUDGETS[key] as Array)[0]])
	var out := "| " + " | ".join(hdr) + " |\n|" + "---|".repeat(hdr.size()) + "\n"
	for r in rows:
		var d: Dictionary = r
		var cells := PackedStringArray([String(d.get("report", "")), String(d.get("status", ""))])
		for key in COLUMNS:
			cells.append("—" if d.get(key, null) == null else Lint3D.fmt(d[key]))
		out += "| " + " | ".join(cells) + " |\n"
	return out
