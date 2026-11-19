## Prop spans — measures where each container / rig point prop is VISIBLE (alpha > 0.5) from its real
## imported idle texture, as per-column opaque spans in world px (docs/research/animation.md, phase 2).
## tools/anim/grab_points.py turns them into reach grab points: a canvas bounding box is not enough
## (the kettle's box runs 95 px in front of Hush, but only its thin spout does).
##   tools/scripts/sandbox.sh <sb> -s res://tools/anim/prop_spans.gd -- --out=/abs/spans.json [--step=8]
## Output: {hotspot id: {use_x, facing, kind, vis: [x, y, w, h], cols: [[x, y_top, y_bottom], ...]}}.
extends SceneTree


func _initialize() -> void:
	var out_path := ""
	var step_px := 8.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--step="):
			step_px = maxf(1.0, float(a.substr(7)))
	if out_path == "":
		printerr("[prop_spans] --out=/abs/path.json is required")
		quit(2)
		return
	var house: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/house/house.json"))
	if not (house is Dictionary):
		printerr("[prop_spans] house.json did not parse")
		quit(2)
		return
	var out := {}
	for hv in (house as Dictionary).get("hotspots", []):
		var hd: Dictionary = hv
		if not (String(hd.get("kind", "")) in ["container", "rig_point"]) or not hd.has("art_pos"):
			continue
		var path := String((hd.get("art", {}) as Dictionary).get("idle", ""))
		var tex: Texture2D = load(path) if path != "" else null
		if tex == null:
			printerr("[prop_spans] %s: no idle texture" % hd["id"])
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var ur := img.get_used_rect()
		var ap := Vector2(float(hd["art_pos"][0]), float(hd["art_pos"][1]))
		var asz := Vector2(float(hd["art_size"][0]), float(hd["art_size"][1]))
		var k := asz / Vector2(img.get_width(), img.get_height())
		var vis := Rect2(ap + Vector2(ur.position) * k, Vector2(ur.size) * k)
		var cols := []
		var step := maxi(1, int(step_px / k.x))
		for x in range(ur.position.x, ur.end.x, step):
			var y0 := -1
			var y1 := -1
			for y in range(ur.position.y, ur.end.y, 2):
				if img.get_pixel(x, y).a > 0.5:
					if y0 < 0:
						y0 = y
					y1 = y
			if y0 >= 0:
				cols.append([snappedf(ap.x + float(x) * k.x, 1.0), snappedf(ap.y + float(y0) * k.y, 1.0), snappedf(ap.y + float(y1) * k.y, 1.0)])
		out[String(hd["id"])] = {"use_x": hd["use_x"], "facing": hd["facing"], "kind": hd["kind"],
			"vis": [vis.position.x, vis.position.y, vis.size.x, vis.size.y], "cols": cols}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("[prop_spans] cannot write %s" % out_path)
		quit(2)
		return
	f.store_string(JSON.stringify(out, "", true))
	f.close()
	print("[prop_spans] %d props → %s" % [out.size(), out_path])
	quit()
