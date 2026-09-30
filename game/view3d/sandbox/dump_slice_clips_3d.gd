## Prints SliceClips.build3d(g0 + P00) as markdown (docs/review/r3d-view3d/slice_clips3d.md) — a dev script:
## `tools/scripts/sandbox.sh r3d-view3d -s res://view3d/sandbox/dump_slice_clips_3d.gd -- [--out=/abs.md] [--episodes=a,b]`
extends SceneTree


func _init() -> void:
	var out := ""
	var eps := PackedStringArray(["g0_sneeze", "p00_curtain_up"])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--episodes="):
			eps = a.substr(11).split(",", false)
	var rows := SliceClips.build3d(eps)
	var have := 0
	for r in rows:
		if ClipMap.clip_exists3d(str(r["clip"])):
			have += 1
	var md := SliceClips.to_markdown(rows, "3D slice clip manifest (%s): %d rows, %d with a 3D sidecar" % [", ".join(eps), rows.size(), have])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_string(md)
	print("[slice_clips3d] rows %d have %d" % [rows.size(), have])
	quit(0)
